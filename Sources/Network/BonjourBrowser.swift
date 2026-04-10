import Foundation
import Network

/// Simple Bonjour browser that scans `_http._tcp` and resolves each to host + port.
/// Used so the receiver UI can show "here are the Macs on your network broadcasting a stream".
/// All mutable state is only touched on the private serial `queue`, so the class is
/// safe to mark `@unchecked Sendable` for Swift 6 strict-concurrency callers.
final class BonjourBrowser: @unchecked Sendable {
    var onUpdate: (@Sendable ([DiscoveredService]) -> Void)?

    private var browser: NWBrowser?
    private var connections: [NWEndpoint: NWConnection] = [:]
    private var results: [String: DiscoveredService] = [:]
    private let queue = DispatchQueue(label: "bonjour.browser")

    func start() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: params)

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.queue.async {
                self?.handle(results: Array(results))
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
        for c in connections.values { c.cancel() }
        connections.removeAll()
    }

    private func handle(results: [NWBrowser.Result]) {
        for result in results {
            guard case let .service(name, type, _, _) = result.endpoint else { continue }
            let id = "\(name).\(type)"
            if self.results[id] != nil { continue }

            // Kick off a lightweight connection just to resolve host/port, then drop it.
            let conn = NWConnection(to: result.endpoint, using: .tcp)
            self.connections[result.endpoint] = conn
            conn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready, .waiting:
                    if case let .hostPort(host, port) = conn.currentPath?.remoteEndpoint ?? conn.endpoint {
                        let hostStr = Self.hostString(host)
                        let svc = DiscoveredService(
                            id: id,
                            name: name,
                            type: type,
                            host: hostStr,
                            port: Int(port.rawValue)
                        )
                        self.results[id] = svc
                        self.onUpdate?(Array(self.results.values).sorted { $0.name < $1.name })
                    }
                    conn.cancel()
                    self.connections.removeValue(forKey: result.endpoint)
                case .failed, .cancelled:
                    self.connections.removeValue(forKey: result.endpoint)
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    private static func hostString(_ host: NWEndpoint.Host) -> String {
        switch host {
        case .ipv4(let addr): return "\(addr)"
        case .ipv6(let addr): return "\(addr)"
        case .name(let n, _): return n
        @unknown default: return ""
        }
    }
}
