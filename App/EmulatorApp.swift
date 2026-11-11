import SwiftUI

@main
struct EmulatorApp: App {
    @StateObject private var library = GameLibrary()
    @StateObject private var menuAudio = MenuAudio()
    var body: some Scene {
        WindowGroup {
            LibraryView().environmentObject(library).environmentObject(menuAudio).preferredColorScheme(.dark).tint(Palette.accent)
        }
    }
}

enum Palette {
    static let background = Color(red: 0.035, green: 0.043, blue: 0.05)
    static let surface = Color(red: 0.075, green: 0.086, blue: 0.098)
    static let accent = ConsoleTheme.blue
    static let muted = Color(red: 0.56, green: 0.60, blue: 0.63)
}
