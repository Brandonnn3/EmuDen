import Foundation
import UIKit
import ImageIO

actor ArtworkStore {
    private let directory: URL
    private let kind: ArtworkKind
    private let cache = NSCache<NSString, UIImage>()
    private var requests = [UUID: (id: UUID, name: String, task: Task<UIImage?, Never>)]()
    private var retryAfter = [UUID: Date]()
    private var fetchingEnabled = ArtworkNetwork.isEnabled()
    private let session: URLSession

    init(directory: URL, kind: ArtworkKind = .cover) {
        self.directory = directory; self.kind = kind
        cache.totalCostLimit = 24 * 1024 * 1024; cache.countLimit = 48
        session = URLSession(configuration: ArtworkNetwork.configuration())
    }
    func setFetchingEnabled(_ enabled: Bool) {
        fetchingEnabled = enabled
        if !enabled {
            for (id, request) in requests { request.task.cancel(); retryAfter[id] = nil }
            requests.removeAll()
        }
    }
    func image(for game: Game, refresh: Bool = false) async -> UIImage? {
        if refresh { await ArtworkResources.catalog?.refresh(force: true) }
        if let chosen = await preferredImage(for: game, refresh: refresh) { return chosen }
        let key = (game.id.uuidString + "|" + game.artworkName) as NSString
        if !refresh, let image = cache.object(forKey: key) { return image }
        if let previous = requests[game.id], previous.name != game.artworkName {
            previous.task.cancel(); requests[game.id] = nil
        }
        let request: (id: UUID, name: String, task: Task<UIImage?, Never>)
        if let pending = requests[game.id] { request = pending }
        else {
            request = (UUID(), game.artworkName, Task { await self.load(game, refresh: refresh) })
            requests[game.id] = request
        }
        let image = await request.task.value
        guard requests[game.id]?.id == request.id else {
            return customImage(for: game) ?? cache.object(forKey: key)
        }
        requests[game.id] = nil
        if let image { cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4)) }
        return image
    }
    func customImage(for game: Game) -> UIImage? {
        guard FileManager.default.fileExists(atPath: file(game, "custom").path) else { return nil }
        return readImage(file(game, "user.png")) ?? readImage(file(game, "png"))
    }
    func customScene(for game: Game) -> UIImage? { customImage(for: game) }
    func cachedImage(for game: Game) async -> UIImage? {
        if let image = customImage(for: game) { return image }
        if let result = await ArtworkResources.catalog?.cachedImage(for: game, kind: kind),
           let image = Self.decode(result.data, maxSize: kind == .scene ? 768 : 384) { return image }
        let savedName = try? String(contentsOf: file(game, "name"), encoding: .utf8)
        return savedName == nil || savedName == game.artworkName ? readImage(file(game, "png")) : nil
    }
    func hasKnownImage(for game: Game) async -> Bool {
        // Availability only; the image loader still validates and decodes the file.
        if FileManager.default.fileExists(atPath: file(game, "custom").path) { return true }
        let savedName = try? String(contentsOf: file(game, "name"), encoding: .utf8)
        if (savedName == nil || savedName == game.artworkName), FileManager.default.fileExists(atPath: file(game, "png").path) { return true }
        if await ArtworkResources.catalog?.cachedImage(for: game, kind: kind) != nil { return true }
        guard fetchingEnabled else { return false }
        return await ArtworkResources.catalog?.hasAsset(for: game, kind: kind) == true
    }
    func preferredImage(for game: Game, refresh: Bool = false) async -> UIImage? {
        if let custom = customImage(for: game) { return custom }
        guard let catalog = ArtworkResources.catalog, let result = await catalog.image(for: game, kind: kind, force: refresh) else { return nil }
        let key = ("pack:" + result.asset.sha256) as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let image = Self.decode(result.data, maxSize: kind == .scene ? 2048 : 1024,
                                      expected: CGSize(width: CGFloat(result.asset.width), height: CGFloat(result.asset.height))),
              kind == .cover || highResolution(image) else { return nil }
        cache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * 4))
        return image
    }
    func importScene(_ url: URL, for game: Game) throws { try importImage(url, for: game) }
    func importImage(_ url: URL, for game: Game) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= 16 * 1024 * 1024 else { throw SceneImageError.invalidImage }
        let data = try Data(contentsOf: url)
        guard data.count <= 16 * 1024 * 1024, let image = Self.decode(data, maxSize: kind == .scene ? 2048 : 1024),
              let png = image.pngData() else { throw SceneImageError.invalidImage }
        try prepareDirectory()
        invalidate(game)
        try png.write(to: file(game, "user.png"), options: .atomic)
        try Data().write(to: file(game, "custom"), options: .atomic)
        NotificationCenter.default.post(name: Notification.Name("EmuDenArtworkUpdated"), object: nil)
    }
    func storeScene(_ image: UIImage, for game: Game) throws {
        guard kind == .scene, highResolution(image), customImage(for: game) == nil else { return }
        guard let data = image.pngData(), let decoded = Self.decode(data, maxSize: 2048), let png = decoded.pngData() else { return }
        try prepareDirectory(); invalidate(game)
        try png.write(to: file(game, "png"), options: .atomic)
        try Data(game.artworkName.utf8).write(to: file(game, "name"), options: .atomic)
        excludeAutomaticImageFromBackup(game)
    }
    func reset(_ game: Game, clearCustom: Bool) throws {
        invalidate(game)
        // Keep user images when resetting; migrate build 11's shared PNG before refreshing it.
        if FileManager.default.fileExists(atPath: file(game, "custom").path),
           !FileManager.default.fileExists(atPath: file(game, "user.png").path),
           FileManager.default.fileExists(atPath: file(game, "png").path) {
            try FileManager.default.copyItem(at: file(game, "png"), to: file(game, "user.png"))
        }
        for ext in ["png", "name"] + (clearCustom ? ["custom"] : []) {
            let url = file(game, ext)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
    }
    private func invalidate(_ game: Game) {
        requests[game.id]?.task.cancel(); requests[game.id] = nil
        retryAfter[game.id] = nil; cache.removeAllObjects()
    }
    private func file(_ game: Game, _ ext: String) -> URL { directory.appendingPathComponent(game.id.uuidString + "." + ext) }
    private func readImage(_ url: URL) -> UIImage? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= 32 * 1024 * 1024,
              let data = try? Data(contentsOf: url) else { return nil }
        return Self.decode(data, maxSize: kind == .scene ? 2048 : 1024)
    }
    private func load(_ game: Game, refresh: Bool) async -> UIImage? {
        let savedName = try? String(contentsOf: file(game, "name"), encoding: .utf8)
        let saved = savedName == nil || savedName == game.artworkName ? readImage(file(game, "png")) : nil
        let usable = saved.flatMap { kind == .cover || highResolution($0) ? $0 : nil }
        if !refresh, let usable { return usable }
        // Native-resolution Libretro snapshots are too small for hero backgrounds.
        guard kind == .cover, fetchingEnabled, !Task.isCancelled,
              refresh || (retryAfter[game.id] ?? .distantPast) < Date(),
              let url = ArtworkResources.covers.url(for: game.artworkName) else { return usable }
        retryAfter[game.id] = Date().addingTimeInterval(3600)
        do {
            let (bytes, response) = try await session.bytes(from: url)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.expectedContentLength <= 4 * 1024 * 1024 else { return usable }
            var data = Data()
            for try await byte in bytes {
                if data.count % 16384 == 0 { try Task.checkCancellation() }
                guard data.count < 4 * 1024 * 1024 else { return usable }
                data.append(byte)
            }
            try Task.checkCancellation()
            guard fetchingEnabled, let image = Self.decode(data, maxSize: 1024), let png = image.pngData() else { return usable }
            try prepareDirectory()
            try png.write(to: file(game, "png"), options: .atomic)
            try Data(game.artworkName.utf8).write(to: file(game, "name"), options: .atomic)
            excludeAutomaticImageFromBackup(game)
            NotificationCenter.default.post(name: Notification.Name("EmuDenArtworkUpdated"), object: nil)
            return image
        } catch { return usable }
    }
    private func highResolution(_ image: UIImage) -> Bool {
        ArtworkScenePolicy.isHighResolution(width: image.cgImage?.width ?? 0, height: image.cgImage?.height ?? 0)
    }
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let values = try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else { throw SceneImageError.invalidImage }
        var folder = directory, backup = URLResourceValues(); backup.isExcludedFromBackup = false
        try? folder.setResourceValues(backup)
    }
    private func excludeAutomaticImageFromBackup(_ game: Game) {
        var url = file(game, "png"), values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
    static func decode(_ data: Data, maxSize: Int, expected: CGSize? = nil) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...8192).contains(width), (1...8192).contains(height), width * height <= 32 * 1024 * 1024,
              expected == nil || expected == CGSize(width: CGFloat(width), height: CGFloat(height)),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: maxSize,
                kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum SceneImageError: LocalizedError {
    case invalidImage
    var errorDescription: String? { "Choose a regular JPEG, PNG or HEIF image smaller than 16 MB. Very large images aren’t supported." }
}
