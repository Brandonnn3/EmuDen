import SwiftUI
import UniformTypeIdentifiers

struct ArtworkEditorView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    let game: Game
    @State private var importing = false
    @State private var importKind: ArtworkKind = .cover
    @State private var matching = false
    @State private var query = ""
    @State private var updating = false
    @State private var resetting = false
    @State private var importNotice: String?
    @FocusState private var queryFocused: Bool
    private var current: Game { library.games.first { $0.id == game.id } ?? game }
    private var results: [String] { ArtworkResources.covers.search(query) }
    var body: some View {
        GeometryReader { area in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CinematicPageHeading(title: matching ? "Match game" : "Game artwork", subtitle: "", onClose: { menuAudio.play(.back); if matching { matching = false } else { dismiss() } }, closeID: "artworkDone")
                    if !matching {
                    let layout = area.size.width > 650 ? AnyLayout(HStackLayout(alignment: .top, spacing: 28)) : AnyLayout(VStackLayout(spacing: 20))
                    layout {
                        VStack(spacing: 12) {
                            GameArtwork(game: current).aspectRatio(0.71, contentMode: .fit).frame(width: area.size.width > 650 ? 195 : 135)
                                .clipShape(RoundedRectangle(cornerRadius: 18)).overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.5)) }
                            Text(displayName(current.title)).font(.headline).multilineTextAlignment(.center).lineLimit(3)
                        }.frame(maxWidth: area.size.width > 650 ? 240 : .infinity)
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Cover image", systemImage: "photo.stack").font(.headline)
                                Button { pick(.cover) } label: { CinematicActionLabel(title: "Choose cover image", symbol: "photo", primary: true) }.accessibilityIdentifier("importCoverImage")
                                Button {
                                    menuAudio.play(.open); matching.toggle()
                                    query = current.artworkName.components(separatedBy: " (").first ?? current.artworkName
                                } label: { CinematicSettingRow(title: "Match another game", detail: "Correct an artwork match", symbol: "magnifyingglass") }.accessibilityIdentifier("chooseArtworkMatch")
                                Text("Matched to: \(displayName(current.artworkName))").font(.caption).foregroundStyle(ConsoleTheme.quiet).accessibilityIdentifier("artworkMatchedTitle")
                            }.cinematicCard()
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Background", systemImage: "photo.on.rectangle").font(.headline)
                                Button { pick(.scene) } label: { CinematicActionLabel(title: "Choose background image", symbol: "photo", primary: true) }.accessibilityIdentifier("importBackgroundImage")
                                Toggle("Console background", isOn: Binding(get: { current.useConsoleBackground == true }, set: { library.setConsoleBackground($0, for: current); menuAudio.play(.focus) }))
                                    .font(.subheadline).accessibilityIdentifier("consoleBackground")
                                Text("A console scene is used automatically when a game has no suitable background. Your chosen images stay on this device.")
                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }.cinematicCard()
                            Button { resetting = true; menuAudio.play(.open) } label: { Label("Restore automatic artwork", systemImage: "arrow.counterclockwise").font(.subheadline).frame(minHeight: 44) }.accessibilityIdentifier("resetArtwork")
                            if let importNotice { Label(importNotice, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(ConsoleTheme.blue).accessibilityIdentifier("artworkImportComplete") }
                        }.frame(maxWidth: .infinity)
                    }
                    }
                    if matching {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                TextField("Find a game", text: $query).focused($queryFocused).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityLabel("Find artwork")
                                if !query.isEmpty {
                                    Button { query = ""; queryFocused = true; menuAudio.play(.focus) } label: { Image(systemName: "xmark.circle.fill").frame(width: 28, height: 36) }.accessibilityLabel("Clear artwork search")
                                }
                            }.padding(16).cinematicGlass(radius: 24, interactive: true)
                            if results.isEmpty { Text("No matching title. You can choose a cover image from Files.").font(.subheadline).foregroundStyle(ConsoleTheme.quiet) }
                            LazyVStack(spacing: 0) {
                                ForEach(results, id: \.self) { title in
                                    Button {
                                        menuAudio.play(.confirm)
                                        run { await library.chooseArtwork(displayName(title), for: current); matching = false }
                                    } label: {
                                        HStack {
                                            Text(displayName(title)).font(.subheadline).multilineTextAlignment(.leading)
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption)
                                        }.frame(minHeight: 48).contentShape(Rectangle())
                                    }.accessibilityLabel("Use artwork for \(displayName(title))")
                                    Divider()
                                }
                            }
                        }.cinematicCard().accessibilityIdentifier("artworkMatches")
                    }
                }.padding(24).frame(maxWidth: 1000).frame(maxWidth: .infinity).cinematicEntrance()
            }.scrollIndicators(.hidden)
        }.foregroundStyle(.white).tint(.white).statusBarHidden(true).buttonStyle(ConsolePressStyle())
            .background { CinematicScene(game: current, subdued: true).ignoresSafeArea() }
            .onAppear { menuAudio.setActive(true) }
            .task(id: matching) {
                if matching { try? await Task.sleep(for: .milliseconds(180)) }
                if !Task.isCancelled { queryFocused = matching }
            }
            .disabled(updating)
            .overlay { if updating { ProgressView().padding(24).cinematicGlass() } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in
                switch result {
                case .success(let url):
                    run {
                        if importKind == .cover { await library.importCover(url, for: current) }
                        else { await library.importScene(url, for: current) }
                        if library.error == nil { importNotice = importKind == .cover ? "Cover image saved" : "Background image saved"; menuAudio.play(.save) }
                    }
                case .failure(let error): library.error = error.localizedDescription
                }
            }
            .confirmationDialog("Restore automatic artwork?", isPresented: $resetting, titleVisibility: .visible) {
                Button("Restore automatic artwork") { run { await library.resetArtwork(current) } }
                Button("Cancel", role: .cancel) { }
            } message: { Text("This resets this game’s artwork choices. Your games and saves are kept.") }
            .alert("Artwork needs attention", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
                Button("OK") { library.error = nil }
            } message: { Text(library.error ?? "") }
    }
    private func displayName(_ title: String) -> String {
        ["png", "3ds", "cci", "cxi", "app", "3dsx", "elf", "axf"].contains((title as NSString).pathExtension.lowercased()) ? (title as NSString).deletingPathExtension : title
    }
    private func pick(_ kind: ArtworkKind) { importKind = kind; importNotice = nil; menuAudio.play(.open); importing = true }
    private func run(_ operation: @escaping @MainActor () async -> Void) {
        updating = true
        Task { await operation(); updating = false }
    }
}
