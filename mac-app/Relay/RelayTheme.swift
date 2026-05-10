import SwiftUI

enum RelayTheme {
    // ── Brand colors ──────────────────────────────────────────────────────────
    static let blue = Color(red: 0.239, green: 0.494, blue: 0.961)
    static let pink = Color(red: 0.941, green: 0.176, blue: 0.353)

    // ── Semantic mappings ─────────────────────────────────────────────────────
    static let urgent    = pink
    static let high      = pink.opacity(0.75)
    static let medium    = blue
    static let active    = blue
    static let blocked   = pink
    static let done      = Color.green

    // ── Gradient (used in header rule and accent elements) ────────────────────
    static let brandGradient = LinearGradient(
        colors: [blue, pink],
        startPoint: .leading,
        endPoint: .trailing
    )
}
