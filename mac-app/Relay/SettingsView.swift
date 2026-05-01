import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var isPresented: Bool

    @State private var url = ""
    @State private var key = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Relay Settings")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Backend URL", systemImage: "server.rack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("https://your-relay.onrender.com", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("API Key", systemImage: "key")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                SecureField("x-api-key", text: $key)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save & Connect") {
                    store.apiURL = url.trimmingCharacters(in: .whitespaces)
                    store.apiKey = key.trimmingCharacters(in: .whitespaces)
                    store.startPolling()
                    Task { await store.refresh() }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(url.isEmpty || key.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            url = store.apiURL
            key = store.apiKey
            // Keep the popover from dismissing when text fields take focus
            DispatchQueue.main.async {
                NSApp.keyWindow?.makeKey()
            }
        }
    }
}
