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
                        // Stop + save in ONE gesture, auto-named "VP <date>" —
                        // the set-building loop: perform, tap, it is kept.
                        Button {
                            link.fire("take.autosave")
                        } label: {
                            Label("Save Take", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .controlSize(.large)
                    .padding(6)
                }

                // THE LANES — set-style leaves (v>0.5 = play): each button
                // sends the OPPOSITE of the Mac's broadcast state, and the
                // label follows the feed, so it can never drift from the Mac.
                GroupBox("Lanes") {
                    HStack(spacing: 12) {
                        laneToggle("Tao",   "tao.play")
                        laneToggle("Music", "music.play")
                        laneToggle("Video", "video.play")
                    }
                    .controlSize(.large)
                    .padding(6)
                }

                // RECORD — the same ProRes takes the Mac's buttons drive
                // (Chris 2026-08-17: "i need to be able to record the takes in
                // here as well and save them all").
                GroupBox("Record") {
                    HStack(spacing: 12) {
                        fireToggle("4K Reframe", "prores.record")
                        fireToggle("Square",     "prores.square")
                        fireToggle("360",        "prores.equirect")
                        Button {
                            link.fire("preset.autosave")
                        } label: {
                            Label("Save Preset", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .controlSize(.large)
                    .padding(6)
                }

                // LOOKS — the sequencer, from inside the sphere.
                GroupBox("Looks") {
                    HStack(spacing: 12) {
                        Button {
                            link.fire("looks.go")
                        } label: {
                            Label("Next Look", systemImage: "forward.frame")
                                .frame(maxWidth: .infinity)
                        }
                        laneToggle("Run", "looks.run")
                    }
                    .controlSize(.large)
                    .padding(6)
                }

                // PRESETS — index loads (the router picks name #⌊v·count⌋).
                // Slider arms the index locally; LOAD fires it once — a live
                // slider here would load a preset per drag tick.
                GroupBox("Presets") {
                    VStack(spacing: 6) {
                        presetLoadRow("Overall", "preset.load")
                        presetLoadRow("Video",   "preset.video.load")
                        presetLoadRow("Text",    "preset.text.load")
                        presetLoadRow("Audio",   "preset.audio.load")
                        presetLoadRow("Layout",  "preset.layout.load")
                    }
                    .padding(6)
                }

                // THE 6K FEED ITSELF — start/stop the Mac's direct send from
                // in here, so entering the sphere is one gesture, no Mac trip.
                GroupBox("Stream") {
                    laneToggle("Vision Pro 6K Send", "stream.vp")
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

                // THE FULL SURFACE — every registry parameter the Mac's state
                // feed broadcasts, grouped by prefix and rendered as sliders.
                // Nothing is listed by hand: a parameter registered on the Mac
                // tomorrow (a new motex pair, a new shader input) appears here
                // on the next feed tick. Same law as the registry itself.
                dynamicGroup("Motex",       prefix: "motex.")
                dynamicGroup("ISF Shaders", prefix: "isf.")
                dynamicGroup("Audio Mix",   prefix: "mix.")
                dynamicGroup("Spatial",     prefix: "spatial.")
            }
            .padding(20)
        }
    }

    /// A set-style toggle (leaf takes 1/0): shows the MAC's broadcast state,
    /// sends its opposite. No local mirror to drift.
    @ViewBuilder
    private func laneToggle(_ title: String, _ leaf: String) -> some View {
        let on = link.value(leaf) > 0.5
        Button {
            link.send(leaf: leaf, value: on ? 0 : 1)
        } label: {
            Label(title, systemImage: on ? "stop.circle.fill" : "play.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(on ? .green : nil)
    }

    /// A fire-style toggle (router flips on any v>0.5). All three ProRes modes
    /// share ONE recorder on the Mac, so every button reads the one broadcast
    /// `prores.record` truth: recording in any mode lights all three, and
    /// tapping any of them stops it — same as the Mac's own buttons.
    @ViewBuilder
    private func fireToggle(_ title: String, _ leaf: String) -> some View {
        let on = link.value("prores.record") > 0.5
        Button {
            link.fire(leaf)
        } label: {
            Label(title, systemImage: on ? "record.circle.fill" : "record.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(on ? .red : nil)
    }

    /// Armed index + one-shot LOAD for the router's index-load leaves.
    @ViewBuilder
    private func presetLoadRow(_ title: String, _ leaf: String) -> some View {
        PresetLoadRow(title: title, leaf: leaf, link: link)
    }

    /// One collapsible group of sliders for every received leaf under `prefix`.
    @ViewBuilder
    private func dynamicGroup(_ title: String, prefix: String) -> some View {
        let leaves = link.values.keys.filter { $0.hasPrefix(prefix) }.sorted()
        if !leaves.isEmpty {
            GroupBox {
                DisclosureGroup("\(title)  (\(leaves.count))") {
                    VStack(spacing: 4) {
                        ForEach(leaves, id: \.self) { leaf in
                            param(String(leaf.dropFirst(prefix.count)), leaf,
                                  link.value(leaf))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(6)
            }
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

/// One preset index-load row: the slider ARMS an index fraction locally;
/// LOAD sends it once. (The router resolves ⌊v·count⌋ against its preset
/// list — a live-bound slider would fire a load on every drag tick.)
private struct PresetLoadRow: View {
    let title: String
    let leaf: String
    let link: ControlLink
    @State private var armed: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout)
                .frame(width: 64, alignment: .leading)
            Slider(value: $armed, in: 0...1)
            Text(String(format: "%.2f", armed))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40)
            Button("Load") {
                link.send(leaf: leaf, value: Float(armed))
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
