import SwiftUI
import RealityKit
import AVFoundation

/// Displays the AVPlayer feed on an inverted 50m sphere — the proven 8K@60fps path on Vision Pro.
/// This is identical in pattern to the working macOS/visionOS sphere, just pointed at a network
/// AVPlayer instead of a local file. Anything that feeds a standard HLS stream works: NDI→OBS,
/// eBoSuite Syphon, Ableton Syphon — all routed through a Mac-side Syphon→HLS bridge.
struct ImmersiveSphereView: View {
    let state: ReceiverState

    var body: some View {
        RealityView { content in
            let mesh = MeshResource.generateSphere(radius: 50)
            let material = VideoMaterial(avPlayer: state.player)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.scale = SIMD3<Float>(-1, 1, 1) // inside-out — render on interior
            entity.name = "skybox"
            content.add(entity)
        }
    }
}
