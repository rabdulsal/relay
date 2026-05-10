import SwiftUI
import AppKit

// ── Privacy policy window opener ──────────────────────────────────────────────

enum PrivacyPolicyWindow {
    static func open() {
        if let existing = NSApp.windows.first(where: { $0.title == "Privacy Policy" }) {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view     = NSHostingView(rootView: PrivacyPolicyView())
        let window   = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
            styleMask:   [.titled, .closable, .resizable, .miniaturizable],
            backing:     .buffered,
            defer:       false
        )
        window.title          = "Privacy Policy"
        window.contentView    = view
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// ── Privacy policy content ────────────────────────────────────────────────────

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.system(size: 22, weight: .bold))

                Text("Last updated: May 2025")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                section(
                    title: "Overview",
                    body: """
Relay is a Mac menu bar app that displays tasks from your Relay backend. \
We are committed to protecting your privacy. This policy explains what \
information the app collects, how it is used, and your rights.
"""
                )

                section(
                    title: "Information We Collect",
                    body: """
Relay stores the following data locally on your device only:

• Relay Token — used to authenticate with your Relay backend
• API Key — resolved from your token, used to fetch tasks
• Backend URL — the address of your Relay backend
• Agent name — a display label for your connection

None of this information is transmitted to any party other than your \
own Relay backend server.
"""
                )

                section(
                    title: "How Your Information Is Used",
                    body: """
Your credentials are used solely to:

• Authenticate requests to your Relay backend
• Fetch and display task data from your backend
• Poll for updates every 30 seconds

Relay does not collect analytics, usage data, crash reports, or any \
personally identifiable information.
"""
                )

                section(
                    title: "Data Storage",
                    body: """
All credentials are stored using macOS UserDefaults (NSUserDefaults) \
in the app's sandboxed container on your device. They are never written \
to iCloud, shared with third parties, or sent to Salaam Solutions servers.
"""
                )

                section(
                    title: "Third-Party Services",
                    body: """
Relay connects only to the backend URL you configure. By default this \
is https://tryrelayapp.com — a service hosted on \
Render.com. If you self-host your backend, only your server is contacted. \
Please review the privacy policies of any hosting provider you use.
"""
                )

                section(
                    title: "Children's Privacy",
                    body: """
Relay is not directed at children under 13. We do not knowingly collect \
any information from children.
"""
                )

                section(
                    title: "Changes to This Policy",
                    body: """
We may update this policy from time to time. Updates will be reflected \
in the app and on our website. Continued use of the app after changes \
constitutes acceptance of the revised policy.
"""
                )

                section(
                    title: "Contact",
                    body: "Questions? Contact us at: rabdulsalaam@gmail.com"
                )
            }
            .padding(28)
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            Text(body)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
