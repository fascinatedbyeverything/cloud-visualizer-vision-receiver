import Foundation
import Network
import Observation

// THE TWO-WAY CONTROLLER — Vision Pro ⇄ Mac, over the app's own OSC port.
//
// Chris 2026-08-12: "a version that is viewer with a two way controller for
// parameters".
//
// The receiver already plays the Mac's live 360 stream. This adds the control
// half, so the headset is not just a window — you can reach into the show from
// inside it and the panel keeps tracking the Mac while you do.
//
//   headset → Mac    /tao/<leaf> <float 0…1>        drives the real control
//   Mac → headset    /tao/state/<leaf> <float 0…1>  10 Hz, so the panel tracks
//
// THE ADDRESS SPACE IS NOT NEW. `/tao/<leaf>` is exactly what X5 Live Reframe's
// TaoOSCReceiver already accepts on udp/9050 and hands to TaoControlRouter —
// the same funnel the Loupedeck drives through MIDI CC. So every leaf here is a
// control that already exists and is already tested; nothing on the Mac had to
// be invented to make the headset work, only the reply half (TaoOSCStateFeed).
//
// PORT 9050 is this app's allocation in the suite registry (FF 9010/11 · Roto
// 9020/21 · Tao 9030 · Captions 9040/41 · X5 Live Reframe 9050/51). The reply
// arrives on THIS connection's own source port, so there is nothing to
// configure and no second listener.

@Observable
@MainActor
final class ControlLink {

    /// Host to control. Defaults to the same Mac the stream comes from.
    var host: String = UserDefaults.standard.string(forKey: "controlHost")
        ?? "fascintated-2.local"
    static let port: UInt16 = 9050

    private(set) var isConnected = false
    private(set) var status = "Not connected"

    /// Live parameter values, keyed by leaf. Written by the Mac's state feed,
    /// read by the sliders. A slider shows the APP's value, not a local copy —
    /// that is what makes it two-way rather than two one-way paths.
    private(set) var values: [String: Float] = [:]

    /// Leaves the user is currently dragging. While a leaf is held, incoming
    /// state for it is ignored — otherwise the 10 Hz feed fights the finger and
    /// the control stutters backwards. Released on drag end.
    private var held: Set<String> = []

    private var conn: NWConnection?
    private var subscribeTimer: Timer?

    // MARK: - Connect

    func connect() {
        disconnect()
        UserDefaults.standard.set(host, forKey: "controlHost")
        let ep = NWEndpoint.hostPort(host: NWEndpoint.Host(host),
                                     port: NWEndpoint.Port(rawValue: Self.port)!)
        let c = NWConnection(to: ep, using: .udp)
        c.stateUpdateHandler = { [weak self] st in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch st {
                case .ready:
                    self.isConnected = true
                    self.status = "Controlling \(self.host):\(Self.port)"
                    self.send(leaf: "subscribe", value: 1)
                    self.startSubscribeKeepalive()
                case .failed(let e):
                    self.isConnected = false
                    self.status = "Control failed: \(e.localizedDescription)"
                case .cancelled:
                    self.isConnected = false
                default: break
                }
            }
        }
        conn = c
        c.start(queue: .main)
        receive(on: c)
    }

    func disconnect() {
        subscribeTimer?.invalidate(); subscribeTimer = nil
        if let c = conn { send(leaf: "subscribe", value: 0); c.cancel() }
        conn = nil
        isConnected = false
        status = "Not connected"
    }

    /// UDP has no session. If the Mac app restarts, its subscriber list is
    /// empty and the panel would silently stop tracking — so re-announce every
    /// few seconds. Cheap: one 20-byte datagram.
    private func startSubscribeKeepalive() {
        subscribeTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.send(leaf: "subscribe", value: 1) }
        }
        t.tolerance = 1
        subscribeTimer = t
    }

    // MARK: - Send

    /// Drive a control on the Mac. `value` is 0…1 — the router does every
    /// scale, so the headset never needs to know a parameter's real range.
    func send(leaf: String, value: Float) {
        guard let c = conn else { return }
        c.send(content: Self.encode(address: "/tao/" + leaf, value: value),
               completion: .idempotent)
    }

    /// Called by a slider while dragging: sends, and holds off the state feed
    /// for that leaf so the value cannot be yanked back mid-gesture.
    func beginEdit(_ leaf: String) { held.insert(leaf) }
    func endEdit(_ leaf: String)   { held.remove(leaf) }

    func value(_ leaf: String, default d: Float = 0) -> Float { values[leaf] ?? d }

    /// A momentary button (transport, take record): 1 then 0.
    func fire(_ leaf: String) {
        send(leaf: leaf, value: 1)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            self.send(leaf: leaf, value: 0)
        }
    }

    // MARK: - Receive state

    private func receive(on c: NWConnection) {
        c.receiveMessage { [weak self] data, _, _, error in
            if let data {
                // The Mac packs the whole snapshot into ONE datagram, so walk
                // every message in it rather than parsing only the first.
                for (addr, val) in Self.parseAll(data) {
                    guard addr.hasPrefix("/tao/state/") else { continue }
                    let leaf = String(addr.dropFirst("/tao/state/".count))
                    Task { @MainActor [weak self] in
                        guard let self, !self.held.contains(leaf) else { return }
                        self.values[leaf] = val
                    }
                }
            }
            // isComplete is per-datagram on UDP and must not end the read loop.
            if error != nil { return }
            Task { @MainActor [weak self] in
                guard let self, let c = self.conn, c.state != .cancelled else { return }
                self.receive(on: c)
            }
        }
    }

    // MARK: - OSC 1.0

    nonisolated static func encode(address: String, value: Float) -> Data {
        var out = Data()
        func pad(_ d: inout Data) { while d.count % 4 != 0 { d.append(0) } }
        out.append(contentsOf: Array(address.utf8)); out.append(0); pad(&out)
        out.append(contentsOf: Array(",f".utf8));    out.append(0); pad(&out)
        var be = value.bitPattern.bigEndian
        withUnsafeBytes(of: &be) { out.append(contentsOf: $0) }
        return out
    }

    /// Parse every `address ,f float` message packed in one datagram.
    nonisolated static func parseAll(_ data: Data) -> [(String, Float)] {
        let b = [UInt8](data)
        var out: [(String, Float)] = []
        var i = 0
        func padded(_ n: Int) -> Int { (n + 3) & ~3 }
        while i < b.count {
            guard let zero = b[i...].firstIndex(of: 0) else { break }
            guard let address = String(bytes: b[i..<zero], encoding: .utf8) else { break }
            var j = padded(zero + 1)
            guard j + 3 < b.count, b[j] == UInt8(ascii: ",") else { break }
            guard let tagEnd = b[j...].firstIndex(of: 0) else { break }
            let tags = String(bytes: b[(j + 1)..<tagEnd], encoding: .utf8) ?? ""
            j = padded(tagEnd + 1)
            guard tags == "f", j + 4 <= b.count else { break }
            let raw = (UInt32(b[j]) << 24) | (UInt32(b[j + 1]) << 16)
                    | (UInt32(b[j + 2]) << 8) | UInt32(b[j + 3])
            out.append((address, Float(bitPattern: raw)))
            i = j + 4
        }
        return out
    }
}
