import SwiftUI

@main
struct CloudVisualizerReceiverApp: App {
    @State private var state = ReceiverState()

    var body: some Scene {
        WindowGroup {
            MainWindow(state: state)
        }
        .defaultSize(width: 520, height: 640)

        ImmersiveSpace(id: "immersive") {
            ImmersiveSphereView(state: state)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
