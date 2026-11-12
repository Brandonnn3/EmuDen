import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

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
    @Published private(set) var artworkFetchingEnabled = ArtworkNetwork.isEnabled()
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
            let directory = group.appendingPathComponent("WidgetLibrary", isDirectory: true)
            let recent = Array(sortedGames.prefix(4))
            let snapshot = WidgetLibrary(games: recent.map { WidgetGame(id: $0.id, title: String($0.artworkName.prefix(240))) }, updated: Date())
            let previous = WidgetLibrary.read(from: directory)
            var changed = previous?.games != snapshot.games
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if artworkFetchingEnabled {
                    for game in recent {
                        for scene in [false, true] {
                            guard artworkFetchingEnabled else { break }
                            var image = scene ? await scenes.cachedImage(for: game) : await artwork.cachedImage(for: game)
                            guard !Task.isCancelled else { return }
                            guard artworkFetchingEnabled else { break }
                            if scene, game.useConsoleBackground == true { image = ArtworkResources.consoleImage(.threeDS) }
                            if image == nil, let art = CinematicArt.match(game.artworkName) {
                                if scene { image = art == .golf ? CinematicArt.golfScene : (art == .zelda ? CinematicArt.forestScene : nil) }
                                else { image = ImageRenderer(content: ApprovedCoverArt(art: art).frame(width: 192, height: 270)).uiImage }
                            }
                            guard artworkFetchingEnabled, let image else { continue }
                            let limit: CGFloat = scene ? 768 : 384
                            let scale = min(1, limit / max(image.size.width, image.size.height))
                            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                            let reduced = UIGraphicsImageRenderer(size: CGSize(width: image.size.width * scale, height: image.size.height * scale), format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: CGSize(width: image.size.width * scale, height: image.size.height * scale))) }
                            guard let jpeg = reduced.jpegData(compressionQuality: 0.86), jpeg.count <= 768 * 1024 else { continue }
                            let item = WidgetGame(id: game.id, title: game.title), file = item.imageURL(in: directory, scene: scene)
                            if (try? Data(contentsOf: file)) != jpeg { try jpeg.write(to: file, options: .atomic); changed = true }
                        }
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
    func setArtworkFetchingEnabled(_ enabled: Bool) {
        guard artworkFetchingEnabled != enabled else { return }
        artworkFetchingEnabled = enabled
        Task {
            await ArtworkResources.catalog?.setFetchingEnabled(enabled)
            await artwork.setFetchingEnabled(enabled); await scenes.setFetchingEnabled(enabled)
            if enabled { await refreshArtworkCatalog() }
            if enabled, artworkFetchingEnabled { artworkRevision += 1; sceneRevision += 1 }
        }
    }
    func refreshArtworkCatalog() async {
        guard artworkFetchingEnabled else { return }
        if await ArtworkResources.catalog?.refresh() == true, artworkFetchingEnabled { artworkRevision += 1; sceneRevision += 1 }
    }
    func chooseArtwork(_ title: String, for game: Game) async {
        do {
            try updateArtwork(game) { $0.artworkTitle = title }
            try await artwork.reset(game, clearCustom: true)
            try await scenes.reset(game, clearCustom: false)
        } catch { self.error = error.localizedDescription }
        artworkRevision += 1; sceneRevision += 1
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
    func importGames(_ urls: [URL]) async {
        guard !busy, catalogReadable else { return }
        activity = "Adding your games…"; busy = true
        let storage = storage
        let oldGames = games
        do {
            games = try await Task.detached(priority: .userInitiated) {
                var imported = [Game]()
                do {
                    for url in urls {
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        imported.append(try storage.importGame(url))
                    }
                    let all = oldGames + imported
                    try storage.write(all)
                    return all
                } catch {
                    for game in imported { try? FileManager.default.removeItem(at: storage.gameURL(game)) }
                    throw error
                }
            }.value
        } catch { self.error = error.localizedDescription }
        busy = false
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
    func refreshArtwork(_ game: Game) async {
        let image = await artwork.image(for: game, refresh: true)
        artworkRevision += 1
        if image == nil { error = "No cover was found. Check your connection and use the game's full name when importing it. Covers are provided by the Libretro thumbnail collection." }
    }
}

struct Launch: Identifiable {
    let id = UUID()
    let title: String
    let url: URL?
    var diagnostic: Bool { url == nil }
}
