import SwiftUI
import AVFoundation
import Combine

/// Hardcoded one-tap presets for known Macs on the local network. Edit this list to add
/// new machines (e.g. a Mac Studio). The URL format assumes MediaMTX defaults: LL-HLS on
/// port 8888 with stream key "live".
struct StreamPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let host: String
    var url: String {
        "http://\(host):8888/live/index.m3u8"
    }
}

let knownPresets: [StreamPreset] = [
    StreamPreset(id: "mbp", name: "MacBook Pro (this Mac)", host: "fascintated-2.local"),
]

@Observable
@MainActor
final class ReceiverState {
    /// The URL the user has entered / picked. Kept as a String for direct TextField binding.
    var streamURLString: String = ""

    /// Static one-tap presets the UI can show as buttons.
    let presets: [StreamPreset] = knownPresets

    /// Last known working URL, persisted across launches.
    var lastURLString: String {
        get { UserDefaults.standard.string(forKey: "lastStreamURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "lastStreamURL") }
    }

    /// Live player used by VideoMaterial on the sphere.
    let player: AVPlayer

    /// Current connection status, shown in the UI.
    var status: String = "Idle"

    /// Discovered Bonjour services on the local network (friendly names).
    var discovered: [DiscoveredService] = []

    /// Bonjour browser — scans for local HTTP servers (common HLS entry point).
    private let browser = BonjourBrowser()

    init() {
        // Low-latency playback configuration
        let player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = false
        self.player = player

        // Pre-fill with last-used URL, or fall back to the first known preset on first launch
        let saved = UserDefaults.standard.string(forKey: "lastStreamURL") ?? ""
        self.streamURLString = saved.isEmpty ? (knownPresets.first?.url ?? "") : saved

        // Start Bonjour browsing so discovered streams show up in the UI
        browser.onUpdate = { [weak self] services in
            Task { @MainActor in
                self?.discovered = services
            }
        }
        browser.start()
    }

    /// Load the current URL into the player and begin playback.
    func connect() {
        let trimmed = streamURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            status = "Invalid URL"
            return
        }

        // Build a fresh item every time so switching URLs is clean
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetPreferPreciseDurationAndTimingKey": true
        ])
        let item = AVPlayerItem(asset: asset)
        // Cap to 4K so oversized HLS variants don't choke the pipeline
        item.preferredMaximumResolution = CGSize(width: 3840, height: 1920)
        item.preferredForwardBufferDuration = 1.0

        player.replaceCurrentItem(with: item)
        player.play()

        status = "Connecting to \(url.host ?? trimmed)…"
        lastURLString = trimmed
    }

    func disconnect() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        status = "Disconnected"
    }
}

/// A Bonjour-discovered local network service.
struct DiscoveredService: Identifiable, Hashable, Sendable {
    let id: String      // name + type
    let name: String
    let type: String
    let host: String?
    let port: Int?

    /// Most likely HLS URL for this host (if any). Users can edit the path after.
    var guessURL: String? {
        guard let host, let port else { return nil }
        return "http://\(host):\(port)/stream.m3u8"
    }
}
