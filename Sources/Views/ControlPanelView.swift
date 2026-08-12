import SwiftUI

// THE CONTROLLER SURFACE — reach into the show from inside it.
//
// Every control here maps to a leaf X5 Live Reframe already accepts on
// udp/9050 (TaoControlRouter), so nothing is a headset-only feature: the same
// leaf is reachable from the Loupedeck, from a Max device, and from this panel,
// and they all end at the same setter.
//
// Sliders read `link.value(leaf)` — the MAC's value, arriving at 10 Hz — not a
// local @State copy. So the panel tracks a preset load, a Loupedeck move, or a
// take replaying its automation, live. During a drag the leaf is HELD so the
// feed cannot fight the finger.

struct ControlPanelView: View {
    @Bindable var link: ControlLink

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                GroupBox("Connection") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("Mac host", text: $link.host)
                                .textFieldStyle(.roundedBorder)
                            Button(link.isConnected ? "Disconnect" : "Connect") {
                                link.isConnected ? link.disconnect() : link.connect()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        HStack(spacing: 8) {
                            Circle()
                                .fill(link.isConnected ? .green : .secondary)
                                .frame(width: 9, height: 9)
                            Text(link.status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(6)
                }

                GroupBox("Transport") {
                    HStack(spacing: 12) {
                        Button {
                            link.fire("master.play")
                        } label: {
                            Label(link.value("master.play") > 0.5 ? "Playing" : "Play",
                                  systemImage: link.value("master.play") > 0.5
                                      ? "pause.circle.fill" : "play.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Button {
                            link.fire("master.stop")
                        } label: {
                            Label("Stop", systemImage: "stop.circle")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            link.fire("take.record")
                        } label: {
                            Label("Take", systemImage: "record.circle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .controlSize(.large)
                    .padding(6)
                }

                // THE REFRAME — the one you actually want in the headset, because
                // you are looking at the result while you move it.
                GroupBox("Reframe") {
                    VStack(spacing: 4) {
                        param("Pan",        "reframe.pan",        0.5)
                        param("Tilt",       "reframe.tilt",       0.5)
                        param("Roll",       "reframe.roll",       0.5)
                        param("FOV",        "reframe.fov",        0.5)
                        param("Distortion", "reframe.distortion", 0)
                    }
                    .padding(6)
                }

                GroupBox("Text") {
                    VStack(spacing: 4) {
                        param("Opacity",  "text.opacity", 1)
                        param("Scale",    "text.scale",   0.43)
                        param("X",        "text.x",       0.5)
                        param("Y",        "text.y",       0.5)
                        param("Hue",      "text.hue",     0.5)
                        param("Sat",      "text.sat",     0.33)
                        param("Bright",   "text.bright",  0.5)
                        param("Blur",     "text.blur",    0)
                        param("Glow",     "text.glow",    0)
                        param("Grain",    "text.grain",   0)
                        param("Cycle",    "text.cycle",   0.5)
                    }
                    .padding(6)
                }

                GroupBox("Video") {
                    param("Opacity", "video.opacity", 1)
                        .padding(6)
                }
            }
            .padding(20)
        }
    }

    /// One parameter row. The binding's getter is the MAC's value; the setter
    /// writes it straight back out. There is no local mirror to drift.
    @ViewBuilder
    private func param(_ title: String, _ leaf: String, _ fallback: Float) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.callout)
                Spacer()
                Text(String(format: "%.2f", link.value(leaf, default: fallback)))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(link.value(leaf, default: fallback)) },
                    set: { link.send(leaf: leaf, value: Float($0)) }),
                in: 0...1,
                onEditingChanged: { editing in
                    editing ? link.beginEdit(leaf) : link.endEdit(leaf)
                })
        }
    }
}
