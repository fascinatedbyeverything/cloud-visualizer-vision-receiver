import SwiftUI

@main
struct CloudVisualizerReceiverApp: App {
    @State private var state = ReceiverState()

    /// THE CONTROL HALF. Owned here so it survives window open/close — a
    /// dropped subscription mid-show would leave the panel showing stale
    /// values with no visible reason.
    @State private var link = ControlLink()

    var body: some Scene {
        WindowGroup {
            MainWindow(state: state, link: link)
        }
        .defaultSize(width: 520, height: 640)

        // The controller is its OWN window so it can sit beside you in the
        // immersive space while the sphere plays — a sheet over the viewer
        // would be dismissed the moment the space takes focus.
        WindowGroup(id: "controls") {
            ControlPanelView(link: link)
        }
        .defaultSize(width: 460, height: 760)

        ImmersiveSpace(id: "immersive") {
            ImmersiveSphereView(state: state)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
