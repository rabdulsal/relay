import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var isPresented: Bool

    @State private var token       = ""
    @State private var resolving   = false
    @State private var resolveError: String? = nil
    @State private var showAdvanced = false

    // Advanced / self-hosted fields
    @State private var advancedURL = ""
    @State private var advancedKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // ── Header ────────────────────────────────────────────────────────
            HStack {
                Text("Connect Relay")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !showAdvanced {
                hostedSection
            } else {
                advancedSection
            }

            // ── Toggle advanced ───────────────────────────────────────────────
            Button(showAdvanced ? "← Use Relay Token" : "Self-hosted / advanced ↓") {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showAdvanced.toggle()
                    resolveError = nil
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(.secondary)

            // ── Privacy link ──────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Privacy Policy") { PrivacyPolicyWindow.open() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            token       = store.relayToken
            advancedURL = store.apiURL
            advancedKey = store.apiKey
            DispatchQueue.main.async { NSApp.keyWindow?.makeKey() }
        }
    }

    // ── Hosted section (RELAY_TOKEN) ──────────────────────────────────────────

    private var hostedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Relay Token", systemImage: "key.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                SecureField("rt_xxxxxxxxxxxxxxxx", text: $token)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))

                Text("Get your token at tryrelayapp.com/get-started")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if let err = resolveError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            if !store.agentName.isEmpty, !store.relayToken.isEmpty, resolveError == nil {
                Label("Connected as \(store.agentName)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }

            HStack {
                if store.isConnected {
                    Button("Disconnect") {
                        store.relayToken = ""
                        store.apiKey     = ""
                        store.agentName  = ""
                        store.apiURL     = "https://tryrelayapp.com"
                        store.tasks      = []
                        token            = ""
                        isPresented      = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                }
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)

                Button {
                    Task { await connectToken() }
                } label: {
                    if resolving {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7).frame(width: 12, height: 12)
                            Text("Connecting…")
                        }
                    } else {
                        Text("Connect")
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || resolving)
            }
        }
    }

    // ── Advanced / self-hosted section ────────────────────────────────────────

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Backend URL", systemImage: "server.rack")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                TextField("https://your-relay.onrender.com", text: $advancedURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("API Key", systemImage: "key")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                SecureField("x-api-key", text: $advancedKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save & Connect") {
                    store.relayToken = ""
                    store.agentName  = ""
                    store.apiURL             = advancedURL.trimmingCharacters(in: .whitespaces)
                    store.apiKey             = advancedKey.trimmingCharacters(in: .whitespaces)
                    store.startPolling()
                    Task { await store.refresh() }
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(advancedURL.isEmpty || advancedKey.isEmpty)
            }
        }
    }

    // ── Token resolution ──────────────────────────────────────────────────────

    private func connectToken() async {
        resolving    = true
        resolveError = nil
        let t = token.trimmingCharacters(in: .whitespaces)

        do {
            let (apiKey, apiURL, agentName) = try await resolveRelayToken(t)
            store.relayToken = t
            store.agentName  = agentName
            store.apiKey     = apiKey
            store.apiURL     = apiURL
            store.startPolling()
            Task { await store.refresh() }
            isPresented = false
        } catch {
            resolveError = error.localizedDescription
        }
        resolving = false
    }
}

// ── Token resolution helper ───────────────────────────────────────────────────

private let hostedURL = "https://tryrelayapp.com"

struct ResolveResponse: Decodable {
    let api_key:    String
    let api_url:    String
    let agent_name: String
}

func resolveRelayToken(_ token: String) async throws -> (apiKey: String, apiURL: String, agentName: String) {
    guard let url = URL(string: "\(hostedURL)/auth/resolve") else {
        throw URLError(.badURL)
    }
    var req = URLRequest(url: url, timeoutInterval: 10)
    req.setValue(token, forHTTPHeaderField: "x-relay-token")
    let (data, res) = try await URLSession.shared.data(for: req)
    guard (res as? HTTPURLResponse)?.statusCode == 200 else {
        throw NSError(domain: "Relay", code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Invalid or expired token — check your Relay Token and try again."])
    }
    let decoded = try JSONDecoder().decode(ResolveResponse.self, from: data)
    return (decoded.api_key, decoded.api_url, decoded.agent_name)
}
