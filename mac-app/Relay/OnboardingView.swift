import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: TaskStore
    @Binding var isPresented: Bool
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────────
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // ── Step content ──────────────────────────────────────────────────
            Group {
                switch step {
                case 0:  stepWelcome
                case 1:  stepHowItWorks
                default: stepConnect
                }
            }
            .animation(.easeInOut(duration: 0.2), value: step)

            // ── Progress dots + nav ───────────────────────────────────────────
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(i == step ? RelayTheme.blue : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                HStack(spacing: 10) {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if step < 2 {
                        Button("Next →") { step += 1 }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // ── Step 0: Welcome ───────────────────────────────────────────────────────

    private var stepWelcome: some View {
        VStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(RelayTheme.blue)
                .padding(.top, 8)

            Text("Welcome to Relay")
                .font(.system(size: 18, weight: .bold))

            Text("Shared working memory for your AI agents.\nEvery agent, every machine — in sync.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }

    // ── Step 1: How it works ──────────────────────────────────────────────────

    private var stepHowItWorks: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How it works")
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            featureRow(icon: "cpu",
                       title: "Agents post tasks",
                       body:  "Claude Code and other agents register tasks as they work — status, priority, blockers.")

            featureRow(icon: "eye",
                       title: "You see everything",
                       body:  "This menu bar app shows a live view: what's in progress, what's blocked, what needs you.")

            featureRow(icon: "bell.badge",
                       title: "Blocked = alert",
                       body:  "When an agent is stuck, it surfaces here instantly so you can unblock it.")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func featureRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(RelayTheme.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(body)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // ── Step 2: Connect ───────────────────────────────────────────────────────

    private var stepConnect: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(RelayTheme.blue)
                .padding(.top, 8)

            Text("Connect your account")
                .font(.system(size: 15, weight: .bold))

            Text("You'll need a Relay Token. Get one free at the link below — just sign up and copy your token.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Get your free token →") {
                NSWorkspace.shared.open(URL(string: "https://tryrelayapp.com/get-started")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(RelayTheme.blue)

            Divider()

            Button("Enter token in Settings") {
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("relay.openSettings")
}
