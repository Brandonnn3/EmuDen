import SwiftUI

enum ConsoleTheme {
    static let ink = Color(red: 0.025, green: 0.033, blue: 0.037)
    static let blue = Color(red: 0.83, green: 0.94, blue: 0.91)
    static let coral = Color(red: 0.94, green: 0.83, blue: 0.79)
    static let quiet = Color.white.opacity(0.65)
}

// Static ambience leaves the GPU available for the game and system glass effects.
struct ConsoleBackdrop: View {
    let moving: Bool
    var body: some View {
        ZStack {
            ConsoleTheme.ink
            RadialGradient(colors: [Color(red: 0.10, green: 0.19, blue: 0.19).opacity(0.7), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 750)
            RadialGradient(colors: [Color(red: 0.08, green: 0.12, blue: 0.16).opacity(0.6), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 550)
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}
