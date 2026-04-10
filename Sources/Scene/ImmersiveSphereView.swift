import SwiftUI
import RealityKit
import AVFoundation
import simd

/// Dumb passthrough 360° sphere — textbook equirect viewer.
///
/// Any orientation correction (yaw/pitch/roll, mirror, etc.) belongs upstream in the
/// source — Cloud Visualizer's Sphere Rotate shader (v5.2+), eBoSuite, Ableton, or
/// wherever. The receiver displays exactly what OBS sends, mapped onto the inside of
/// a 50m sphere using the standard inverted-sphere technique.
struct ImmersiveSphereView: View {
    let state: ReceiverState

    var body: some View {
        RealityView { content in
            let mesh = MeshResource.generateSphere(radius: 50)
            let material = VideoMaterial(avPlayer: state.player)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.scale = SIMD3<Float>(-1, 1, 1) // standard inside-out trick
            // Initial viewing orientation: +90° around Y (was -90°, +180° from there)
            // so the equirect seam sits behind the user on startup.
            entity.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0))
            entity.name = "skybox"
            content.add(entity)
        }
    }
}
