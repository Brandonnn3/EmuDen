import SwiftUI
import UniformTypeIdentifiers
import WidgetKit
import CryptoKit

@MainActor
final class GameLibrary: ObservableObject {
    @Published var games = [Game]()
    @Published var mii: MiiStatus
    @Published private(set) var miiAvatar: UIImage?
    @Published var busy = false
    @Published private(set) var activity = "Preparing your library…"
    @Published var error: String?
    @Published var artworkRevision = 0
    @Published var sceneRevision = 0
    @Published var featuredGameID: UUID?
    @Published private(set) var coreReady = false
    @Published private(set) var artworkSourceURL: URL?
    @Published private(set) var artworkImporting = false
    @Published private(set) var artworkImportProgress = 0.0
    @Published private(set) var artworkImportStatus: String?
    @Published private(set) var boxArtSourceURL: URL?
    @Published private(set) var boxArtImporting = false
    @Published private(set) var boxArtStatus: String?
    private var boxArtSource: BoxArtworkSource?
    private var boxArtTask: Task<Void, Never>?
    private var artworkSource: ArtworkCatalogSource?
    private var artworkImportTask: Task<Void, Never>?
    private var activeArtworkCatalog: RemoteArtworkCatalog?
    private var catalogReadable = true
    private var widgetTask: Task<Void, Never>?
    let storage: LibraryStorage
    let artwork: ArtworkStore
    let scenes: ArtworkStore
    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storage = LibraryStorage(root: documents)
        artwork = ArtworkStore(directory: documents.appendingPathComponent("Artwork", isDirectory: true))
        scenes = ArtworkStore(directory: documents.appendingPathComponent("Scenes", isDirectory: true), kind: .scene)
        mii = storage.inspectMii()
        artworkSource = ArtworkCatalogSource.read(from: documents.appendingPathComponent("artwork-source.json"))
        artworkSourceURL = artworkSource?.url
        boxArtSource = BoxArtworkSource.read(from: documents.appendingPathComponent("box-art-source.txt"))
        boxArtSourceURL = boxArtSource?.url
        do { try storage.prepare(); games = try storage.read() }
        catch { self.error = error.localizedDescription; catalogReadable = false }
        let avatar = documents.appendingPathComponent("profile-avatar.jpg")
        if let v = try? avatar.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
           v.isRegularFile == true, v.isSymbolicLink != true, let size = v.fileSize, size <= 1024 * 1024,
           let data = try? Data(contentsOf: avatar) { miiAvatar = ArtworkStore.decode(data, maxSize: 256) }
    }
    func importAvatar(_ url: URL) async {
        do {
            let data = try await Task.detached(priority: .userInitiated) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let v = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard v.isRegularFile == true, v.isSymbolicLink != true, let size = v.fileSize, size > 0, size <= 16 * 1024 * 1024 else { throw SceneImageError.invalidImage }
                let original = try Data(contentsOf: url)
                guard original.count <= 16 * 1024 * 1024, let image = ArtworkStore.decode(original, maxSize: 256),
                      let data = image.jpegData(compressionQuality: 0.9), data.count <= 1024 * 1024 else { throw SceneImageError.invalidImage }
                return data
            }.value
            try data.write(to: storage.root.appendingPathComponent("profile-avatar.jpg"), options: .atomic)
            miiAvatar = UIImage(data: data)
        } catch { self.error = error.localizedDescription }
    }
    func resetAvatar() {
        do {
            let file = storage.root.appendingPathComponent("profile-avatar.jpg")
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            miiAvatar = nil
        } catch { self.error = error.localizedDescription }
    }
    var sortedGames: [Game] {
        games.sorted { ($0.lastPlayed ?? $0.added) > ($1.lastPlayed ?? $1.added) }
    }
    var featuredGame: Game? { games.first { $0.id == featuredGameID } ?? sortedGames.first }
    func refreshWidgets() {
        guard catalogReadable else { return }
        widgetTask?.cancel()
        widgetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetLibrary.groupID) else { return }
            let directory = group.appendingPathComponent(WidgetLibrary.directoryName, isDirectory: true)
            let recent = Array(sortedGames.prefix(4))
            let snapshot = WidgetLibrary(games: recent.map { WidgetGame(id: $0.id, title: String(($0.customTitle ?? $0.artworkName).prefix(240)), platform: $0.console.rawValue) }, updated: Date())
            let previous = WidgetLibrary.read(from: directory)
            var changed = previous?.games != snapshot.games
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                for game in recent {
                    for scene in [false, true] {
                        var image = scene ? await scenes.cachedImage(for: game) : await artwork.cachedImage(for: game)
                        guard !Task.isCancelled else { return }
                        if scene, game.useConsoleBackground == true || image == nil { image = ArtworkResources.consoleImage(ConsoleSystem(rawValue: game.console.rawValue) ?? .threeDS) }
                        let item = WidgetGame(id: game.id, title: game.title), file = item.imageURL(in: directory, scene: scene)
                        guard let image else {
                            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file); changed = true }
                            continue
                        }
                        let limit: CGFloat = scene ? 768 : 384
                        let scale = min(1, limit / max(image.size.width, image.size.height))
                        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                        let reduced = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
                        guard let jpeg = reduced.jpegData(compressionQuality: 0.86), jpeg.count <= 768 * 1024 else { continue }
                        if (try? Data(contentsOf: file)) != jpeg { try jpeg.write(to: file, options: .atomic); changed = true }
                    }
                }
                guard !Task.isCancelled, changed else { return }
                try snapshot.write(to: directory)
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetLibrary.continueKind)
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetLibrary.recentKind)
                for item in previous?.games ?? [] where !snapshot.games.contains(where: { $0.id == item.id }) {
                    for scene in [false, true] { try? FileManager.default.removeItem(at: item.imageURL(in: directory, scene: scene)) }
                }
            } catch { /* Optional widget snapshots must never interrupt playing or saving. */ }
        }
    }
    func rememberScene(_ image: UIImage, for game: Game) {
        Task {
            do { try await scenes.storeScene(image, for: game); sceneRevision += 1 }
            catch { /* A preview must never interfere with closing or saving a game. */ }
        }
    }
    func importScene(_ url: URL, for game: Game) async {
        do {
            try await scenes.importScene(url, for: game)
            try updateArtwork(game) { $0.useConsoleBackground = false }
            sceneRevision += 1
        }
        catch { self.error = error.localizedDescription }
    }
    func importCover(_ url: URL, for game: Game) async {
        do { try await artwork.importImage(url, for: game); artworkRevision += 1 }
        catch { self.error = error.localizedDescription }
    }
    func artworkPlan(for source: ArtworkCatalogSource, games selection: [Game]? = nil) async -> ArtworkImportPlan {
        let selection = selection ?? games
        var covers = Set<UUID>(), backgrounds = Set<UUID>()
        for game in selection {
            let entry = source.pack.match(game)
            if boxArtSource != nil, entry?.coverIsSceneFallback == true { covers.insert(game.id) }
            else if await artwork.hasImportedImage(for: game, matching: entry?.cover) { covers.insert(game.id) }
            if await scenes.hasImportedImage(for: game, matching: entry?.scene) { backgrounds.insert(game.id) }
        }
        return ArtworkImportPlan(pack: source.pack, games: selection, protectedCovers: covers, protectedScenes: backgrounds)
    }
    func fillArtwork(from source: ArtworkCatalogSource) {
        guard !artworkImporting, catalogReadable else { return }
        do { try source.write(to: storage.root.appendingPathComponent("artwork-source.json")) }
        catch { artworkImportStatus = "Couldn’t remember this catalog. \(error.localizedDescription)"; return }
        artworkSource = source; artworkSourceURL = source.url
        artworkImporting = true; artworkImportProgress = 0; artworkImportStatus = "Checking your artwork…"
        artworkImportTask = Task { @MainActor in
            let key = SHA256.hash(data: Data(source.url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
            let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("SelectedArtworkCatalog/" + key)
            let catalog = RemoteArtworkCatalog(seed: source.pack, directory: cache)
            activeArtworkCatalog = catalog
            var processed = Set<UUID>(), saved = 0, failed = 0, unmatched = 0
            // Re-read the library so games added during a fill join the same pass.
            while !Task.isCancelled, let game = games.first(where: { !processed.contains($0.id) }) {
                processed.insert(game.id)
                if let entry = source.pack.match(game), let asset = entry.cover {
                    do {
                        if try await artwork.updateCatalogCoverPriority(for: game, asset: asset, isSceneFallback: entry.coverIsSceneFallback == true) { artworkRevision += 1 }
                    } catch { failed += 1 }
                }
                let plan = await artworkPlan(for: source, games: [game])
                unmatched += plan.unmatchedGames
                if let item = plan.items.first {
                    artworkImportStatus = "Adding artwork for \(game.title)…"
                    for kind in [ArtworkKind.cover, .scene] where kind == .cover ? item.cover : item.scene {
                        guard !Task.isCancelled else { break }
                        guard let image = await catalog.image(for: game, kind: kind, force: true),
                              image.asset == source.pack.match(game)?.asset(kind) else {
                            if !Task.isCancelled { failed += 1 }; continue
                        }
                        guard !Task.isCancelled else { break }
                        // A manual choice made while downloading must still win.
                        if kind == .scene, games.first(where: { $0.id == game.id })?.useConsoleBackground == true { continue }
                        do {
                            let store = kind == .cover ? artwork : scenes
                            if try await store.importCatalogImage(image, for: game, coverIsSceneFallback: source.pack.match(game)?.coverIsSceneFallback == true) {
                                saved += 1
                                if kind == .cover { artworkRevision += 1 } else { sceneRevision += 1 }
                            }
                        } catch { failed += 1 }
                    }
                }
                artworkImportProgress = Double(processed.count) / Double(max(1, games.count))
            }
            let cancelled = Task.isCancelled
            await catalog.setFetchingEnabled(false)
            activeArtworkCatalog = nil; artworkImporting = false; artworkImportTask = nil
            if cancelled { artworkImportStatus = "Stopped. Artwork already saved is kept." }
            else {
                artworkImportProgress = 1
                artworkImportStatus = "Saved \(saved) image\(saved == 1 ? "" : "s")."
                    + (failed > 0 ? " \(failed) unavailable; check the link and retry to fill the remaining images." : "")
                    + (unmatched > 0 ? " \(unmatched) game\(unmatched == 1 ? "" : "s") without a catalog match keep their existing artwork." : "")
            }
            refreshWidgets()
            if !cancelled { fillBoxCovers() }
        }
    }
    func cancelArtworkImport() {
        artworkImportTask?.cancel()
        cancelBoxCovers()
        if let catalog = activeArtworkCatalog { Task { await catalog.setFetchingEnabled(false) } }
    }
    func cancelBoxCovers() { boxArtTask?.cancel() }
    func connectBoxCovers(_ text: String) {
        guard !boxArtImporting, catalogReadable else { return }
        do {
            let source = try BoxArtworkSource(text)
            try Data(source.url.absoluteString.utf8).write(to: storage.root.appendingPathComponent("box-art-source.txt"), options: .atomic)
            boxArtSource = source; boxArtSourceURL = source.url
            fillBoxCovers()
        } catch { boxArtStatus = error.localizedDescription }
    }
    func fillBoxCovers() {
        guard !boxArtImporting, catalogReadable, let source = boxArtSource else { return }
        boxArtImporting = true; boxArtStatus = "Finding original covers…"
        boxArtTask = Task { @MainActor in
            let session = URLSession(configuration: ArtworkNetwork.configuration())
            defer { session.invalidateAndCancel() }
            var processed = Set<UUID>(), saved = 0, failed = 0, unmatched = 0
            while !Task.isCancelled, let game = games.first(where: { $0.console == .threeDS && !processed.contains($0.id) }) {
                processed.insert(game.id)
                guard let url = source.imageURL(for: game.artworkName, catalog: ArtworkResources.covers) else { unmatched += 1; continue }
                if await artwork.hasBoxCover(for: game, from: url) { continue }
                boxArtStatus = "Finding cover for \(game.title)…"
                guard let data = await RemoteArtworkCatalog.download(url, session: session, limit: 4 * 1024 * 1024) else {
                    if !Task.isCancelled { failed += 1 }; continue
                }
                guard !Task.isCancelled, boxArtSource == source else { break }
                do {
                    if try await artwork.importBoxCover(data, from: url, for: game) { saved += 1; artworkRevision += 1 }
                } catch { failed += 1 }
            }
            boxArtImporting = false; boxArtTask = nil
            if boxArtSource == nil { boxArtStatus = "Cover source disconnected. Saved covers are kept." }
            else if Task.isCancelled { boxArtStatus = "Stopped. Saved covers are kept." }
            else {
                boxArtStatus = "Saved \(saved) original cover\(saved == 1 ? "" : "s")."
                    + (failed > 0 ? " \(failed) unavailable; retry when connected." : "")
                    + (unmatched > 0 ? " \(unmatched) games have no matching cover." : "")
            }
            refreshWidgets()
        }
    }
    func disconnectBoxCovers() {
        do {
            let file = storage.root.appendingPathComponent("box-art-source.txt")
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            cancelBoxCovers(); boxArtSource = nil; boxArtSourceURL = nil
            boxArtStatus = "Cover source disconnected. Saved covers are kept."
        } catch { boxArtStatus = error.localizedDescription }
    }
    func disconnectArtworkSource() {
        do {
            let file = storage.root.appendingPathComponent("artwork-source.json")
            if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
            artworkImportTask?.cancel()
            if let catalog = activeArtworkCatalog { Task { await catalog.setFetchingEnabled(false) } }
            artworkSource = nil; artworkSourceURL = nil
            if !artworkImporting { artworkImportStatus = "Catalog disconnected. Saved artwork is kept." }
        } catch { artworkImportStatus = "Couldn’t disconnect this catalog. \(error.localizedDescription)" }
    }
    func setConsoleBackground(_ enabled: Bool, for game: Game) {
        do { try updateArtwork(game) { $0.useConsoleBackground = enabled }; sceneRevision += 1 }
        catch { self.error = error.localizedDescription }
    }
    func resetArtwork(_ game: Game) async {
        do {
            try updateArtwork(game) { $0.artworkTitle = nil; $0.useConsoleBackground = nil }
            try await artwork.reset(game, clearCustom: true)
            try await scenes.reset(game, clearCustom: true)
        } catch { self.error = error.localizedDescription }
        artworkRevision += 1; sceneRevision += 1
    }
    private func updateArtwork(_ game: Game, change: (inout Game) -> Void) throws {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        var updated = games; change(&updated[i])
        try storage.write(updated); games = updated
    }
    func prepareEmulationData() async {
        guard !coreReady, !busy else { return }
        activity = "Preparing your library…"
        busy = true
        let storage = storage
        do {
            try await Task.detached(priority: .userInitiated) { try storage.prepareCoreUpgrade() }.value
            coreReady = true
        } catch { self.error = "Couldn’t prepare a backup for the new 3DS core. Your data is unchanged. \(error.localizedDescription)" }
        busy = false
    }
    func importGames(_ urls: [URL], allowGameCube requestedGameCube: Bool? = nil) async {
        guard !busy, catalogReadable else { return }
        activity = "Adding your games…"; busy = true
        let storage = storage
        let allowGameCube = requestedGameCube ?? ConsoleSystem.gameCubeAvailable
        let oldGames = games
        do {
            games = try await Task.detached(priority: .userInitiated) {
                var imported = [Game]()
                let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
                defer { for url in scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    imported = try storage.importBatch(urls, allowGameCube: allowGameCube)
                    let all = oldGames + imported
                    try storage.write(all)
                    return all
                } catch {
                    for game in imported { try? FileManager.default.removeItem(at: storage.gameAssetsURL(game)) }
                    throw error
                }
            }.value
        } catch { self.error = error.localizedDescription }
        busy = false
        if let source = artworkSource, !artworkImporting { fillArtwork(from: source) }
        fillBoxCovers()
    }
    func renameGame(_ game: Game, name: String) {
        guard !busy, catalogReadable, let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        guard Game.isValidDisplayName(name) else { error = "Choose a name from 1 to 160 characters without line breaks."; return }
        do {
            var updated = games; updated[i] = try updated[i].renamed(name)
            try storage.write(updated); games = updated; refreshWidgets()
        } catch { self.error = "Couldn’t rename the game. " + error.localizedDescription }
    }
    func deleteGame(_ game: Game) async {
        guard !busy, catalogReadable else { return }
        cancelArtworkImport(); boxArtTask?.cancel()
        activity = "Deleting game…"; busy = true
        let storage = storage
        do { games = try await Task.detached(priority: .userInitiated) { try storage.deleteGame(id: game.id) }.value }
        catch {
            if let current = try? storage.read() { games = current }
            self.error = error.localizedDescription
        }
        busy = false; refreshWidgets()
    }
    func importSystem(_ url: URL, miiArchive: Bool = false) async {
        guard !busy else { return }; activity = "Setting up system data…"; busy = true
        let storage = storage
        do {
            try await Task.detached(priority: .userInitiated) {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if miiArchive { try storage.importMiiArchive(url) }
                else { try storage.importSystemData(url) }
            }.value
            mii = storage.inspectMii()
        } catch { self.error = error.localizedDescription }
        busy = false
    }
    func played(_ game: Game) {
        guard catalogReadable, let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i].lastPlayed = Date()
        do { try storage.write(games) } catch { self.error = error.localizedDescription }
    }

}

struct Launch: Identifiable {
    let id = UUID()
    let title: String
    let url: URL?
    var platform: GamePlatform = .threeDS
    var diagnostic: Bool { url == nil }
}
