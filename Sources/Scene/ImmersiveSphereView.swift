import SwiftUI
import RealityKit
import AVFoundation
import simd

/// Displays the AVPlayer feed on an inverted 50m sphere — the proven 8K@60fps path on Vision Pro.
/// Uses a custom-built sphere mesh with reversed triangle winding and flipped U coordinates so
/// the texture renders correctly from the inside without the horizontal mirror that the
/// standard `scale(-1, 1, 1)` trick introduces.
struct ImmersiveSphereView: View {
    let state: ReceiverState

    var body: some View {
        RealityView { content in
            let mesh = Self.makeInsideOutSphere(radius: 50) ?? MeshResource.generateSphere(radius: 50)
            let material = VideoMaterial(avPlayer: state.player)
            let entity = ModelEntity(mesh: mesh, materials: [material])
            // 270° around Y (was 90°, +180° from there)
            entity.orientation = simd_quatf(angle: 3 * .pi / 2, axis: SIMD3<Float>(0, 1, 0))
            entity.name = "skybox"
            content.add(entity)
        }
    }

    /// UV sphere with reversed triangle winding (so back faces render from inside) and
    /// U coordinates flipped (so the texture is not mirrored from inside). Eliminates
    /// the negative-scale hack that caused horizontal motion to appear reversed.
    private static func makeInsideOutSphere(radius: Float, segments: Int = 96, rings: Int = 48) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []

        for r in 0...rings {
            let v = Float(r) / Float(rings)
            let theta = v * .pi
            let sinTheta = sin(theta)
            let cosTheta = cos(theta)

            for s in 0...segments {
                let u = Float(s) / Float(segments)
                let phi = u * 2 * .pi
                let cosPhi = cos(phi)
                let sinPhi = sin(phi)

                let dir = SIMD3<Float>(sinTheta * cosPhi, cosTheta, sinTheta * sinPhi)
                positions.append(dir * radius)
                normals.append(-dir) // inward-facing normals
                uvs.append(SIMD2<Float>(1.0 - u, v)) // flipped U to compensate for reversed winding
            }
        }

        let stride = segments + 1
        for r in 0..<rings {
            for s in 0..<segments {
                let a = UInt32(r * stride + s)
                let b = UInt32(r * stride + s + 1)
                let c = UInt32((r + 1) * stride + s)
                let d = UInt32((r + 1) * stride + s + 1)
                // Reversed winding (CW instead of standard CCW) so back faces render
                indices.append(a); indices.append(c); indices.append(b)
                indices.append(b); indices.append(c); indices.append(d)
            }
        }

        var desc = MeshDescriptor()
        desc.positions = MeshBuffers.Positions(positions)
        desc.normals = MeshBuffers.Normals(normals)
        desc.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        desc.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [desc])
    }
}
