import SwiftUI

struct ArtworkCatalogView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    @State private var boxLink = ""
    @State private var checking = false
    @State private var source: ArtworkCatalogSource?
    @State private var plan: ArtworkImportPlan?
    @State private var message: String?
    @State private var checkTask: Task<Void, Never>?
    @FocusState private var linkFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                CinematicPageHeading(title: "Artwork catalogs", subtitle: "One link. Your whole library.", onClose: {
                    menuAudio.play(.back); dismiss()
                }, closeID: "artworkCatalogDone")
                VStack(alignment: .leading, spacing: 14) {
                    Label("Original game covers", systemImage: "rectangle.portrait").font(.headline)
                    Text("Connect a box-art collection once to fill games that need covers. Existing portrait covers and your backgrounds are kept.")
                        .font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
                    TextField("https://example.com/3DS/Named_Boxarts/", text: $boxLink)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .padding(14).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("boxArtworkLink")
                    Button { menuAudio.play(.save); library.connectBoxCovers(boxLink) } label: {
                        CinematicActionLabel(title: library.boxArtImporting ? "Finding original covers…" : "Use original covers", symbol: "arrow.down.circle", primary: true)
                    }.disabled(library.boxArtImporting || boxLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("connectBoxCovers")
                    Text("Use a compatible Named_Boxarts folder link. The cover artwork fills each rounded tile, with the 3DS case strip removed. Your manually chosen covers are kept.")
                        .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    if let host = library.boxArtSourceURL?.host {
                        Text("Cover source: \(host)").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        Button("Disconnect cover source", role: .destructive) { library.disconnectBoxCovers() }
                            .frame(minHeight: 44).accessibilityIdentifier("disconnectBoxCovers")
                    }
                    if library.boxArtImporting {
                        ProgressView()
                        Button("Stop cover downloads", role: .cancel) { library.cancelBoxCovers() }.frame(minHeight: 44)
                    }
                    if let status = library.boxArtStatus {
                        Text(status).font(.subheadline).foregroundStyle(ConsoleTheme.quiet).accessibilityIdentifier("boxArtworkStatus")
                    }
                }.cinematicCard()
                VStack(alignment: .leading, spacing: 14) {
                    Label("Connect a collection", systemImage: "link").font(.headline)
                    Text("Add a compatible collection to find covers and backgrounds for Nintendo 3DS, PlayStation and GameCube games automatically.")
                        .font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
                    TextField("https://example.com/artwork/catalog.json", text: $link)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .submitLabel(.go).focused($linkFocused).onSubmit(check)
                        .padding(14).background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("artworkCatalogLink")
                    Button(action: check) {
                        CinematicActionLabel(title: checking ? "Checking catalog…" : "Find matching artwork", symbol: "sparkle.magnifyingglass", primary: true)
                    }.disabled(checking || library.artworkImporting || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("previewArtworkCatalog")
                    Text("Use a catalog.json link or its collection folder. Ordinary web pages and game download links aren’t artwork catalogs.")
                        .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                }.cinematicCard()
                if let source, let plan {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Ready for your library", systemImage: "photo.stack").font(.headline)
                        Text("\(plan.coverCount) cover\(plan.coverCount == 1 ? "" : "s") · \(plan.sceneCount) background\(plan.sceneCount == 1 ? "" : "s")")
                            .font(.title3.bold()).accessibilityIdentifier("artworkCatalogMatches")
                        Text(source.url.host ?? "").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        ForEach(plan.items) { item in
                            HStack {
                                Text(item.game.displayName).lineLimit(2)
                                Spacer()
                                if item.cover { Image(systemName: "rectangle.portrait") }
                                if item.scene { Image(systemName: "photo") }
                            }.font(.subheadline).padding(.vertical, 4)
                        }
                        if plan.items.isEmpty { Text("Your artwork from this catalog is up to date.").font(.subheadline) }
                        if plan.unmatchedGames > 0 {
                            Text("\(plan.unmatchedGames) games have no match. Their current artwork stays in place.")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        }
                        Button {
                            linkFocused = false; menuAudio.play(.save); library.fillArtwork(from: source)
                        } label: {
                            CinematicActionLabel(title: "Use catalog & fill artwork", symbol: "arrow.down.circle", primary: true)
                        }.disabled(library.artworkImporting).accessibilityIdentifier("fillArtworkCatalog")
                        Text("Portrait covers from this catalog take priority over automatic box scans. Box scans fill missing covers or scene-crop placeholders. Your manually chosen images and console-background preferences are kept.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    }.cinematicCard()
                }
                if library.artworkImporting {
                    VStack(alignment: .leading, spacing: 12) {
                        ProgressView(value: library.artworkImportProgress).accessibilityIdentifier("artworkCatalogProgress")
                        Button("Stop", role: .cancel) { library.cancelArtworkImport() }.frame(minHeight: 44)
                    }.cinematicCard()
                }
                if let message { Text(message).foregroundStyle(ConsoleTheme.quiet).accessibilityIdentifier("artworkCatalogError") }
                if let status = library.artworkImportStatus {
                    Text(status).font(.subheadline).foregroundStyle(ConsoleTheme.quiet).accessibilityIdentifier("artworkCatalogStatus")
                }
                if let connected = library.artworkSourceURL {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Connected catalog", systemImage: "checkmark.circle").font(.headline)
                        Text(connected.absoluteString).font(.caption).textSelection(.enabled)
                        Button("Disconnect catalog", role: .destructive) { library.disconnectArtworkSource(); menuAudio.play(.back) }
                            .frame(minHeight: 44).accessibilityIdentifier("disconnectArtworkCatalog")
                        Text("Disconnecting stops future downloads. Images already saved remain available offline.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    }.cinematicCard()
                }
                Text("Only connect collections you trust and have permission to use. The selected host receives your IP address and requests for matching images; EmuDen doesn’t upload your game files, saves or complete library. No catalog is supplied by default.")
                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity).cinematicEntrance()
        }.scrollIndicators(.hidden).accessibilityElement(children: .contain).accessibilityIdentifier("artworkCatalogScroll")
            .foregroundStyle(.white).tint(.white).buttonStyle(ConsolePressStyle())
            .background { CinematicScene(game: library.featuredGame, subdued: true).ignoresSafeArea() }
            .onAppear {
                link = library.artworkSourceURL?.absoluteString ?? ""
                boxLink = library.boxArtSourceURL?.absoluteString ?? ""
            }
            .onDisappear { checkTask?.cancel() }
            .onChange(of: link) { _, _ in checkTask?.cancel(); checking = false; source = nil; plan = nil; message = nil }
            .onChange(of: library.artworkImporting) { old, new in
                if old && !new, let source { checkTask = Task { plan = await library.artworkPlan(for: source) } }
            }
            .onChange(of: library.boxArtSourceURL) { _, _ in
                if let source { checkTask = Task { plan = await library.artworkPlan(for: source) } }
            }
    }
    private func check() {
        guard !checking, !library.artworkImporting else { return }
        linkFocused = false; menuAudio.play(.search); message = nil; source = nil; plan = nil; checking = true
        let text = link
        checkTask = Task { @MainActor in
            do {
                let result = try await RemoteArtworkCatalog.loadSource(text)
                let matches = await library.artworkPlan(for: result)
                guard !Task.isCancelled else { return }
                source = result; plan = matches
            } catch { if !Task.isCancelled { message = error.localizedDescription } }
            if !Task.isCancelled { checking = false }
        }
    }
}
