import SwiftUI

struct MainWindow: View {
    @Bindable var state: ReceiverState
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var immersiveOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cloud Receiver")
                .font(.largeTitle.bold())
            Text("Live 360° stream from your Mac, eBoSuite, or Ableton Syphon output.")
                .font(.callout)
                .foregroundStyle(.secondary)

            GroupBox("Stream URL") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("http://your-mac.local:8080/stream.m3u8", text: $state.streamURLString)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    HStack {
                        Button("Connect") { state.connect() }
                            .buttonStyle(.borderedProminent)
                            .disabled(state.streamURLString.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button("Disconnect") { state.disconnect() }

                        Spacer()

                        Text(state.status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            }

            GroupBox("Discovered on local network") {
                if state.discovered.isEmpty {
                    Text("Scanning for Bonjour HTTP services…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.discovered) { svc in
                            Button {
                                if let u = svc.guessURL {
                                    state.streamURLString = u
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(svc.name).font(.body)
                                        if let host = svc.host, let port = svc.port {
                                            Text("\(host):\(port)")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(6)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button(immersiveOpen ? "Exit Immersive" : "Enter Immersive") {
                    Task {
                        if immersiveOpen {
                            await dismissImmersiveSpace()
                            immersiveOpen = false
                        } else {
                            let result = await openImmersiveSpace(id: "immersive")
                            if case .opened = result { immersiveOpen = true }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Spacer()
            }
        }
        .padding(30)
    }
}
