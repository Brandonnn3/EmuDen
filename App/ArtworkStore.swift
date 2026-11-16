import Foundation
import UIKit
import ImageIO

actor ArtworkStore {
    private let directory: URL
    private let kind: ArtworkKind

    init(directory: URL, kind: ArtworkKind = .cover) {
        self.directory = directory; self.kind = kind
    }
    func image(for game: Game) -> UIImage? {
        if let custom = customImage(for: game) { return custom }
        if kind == .cover, catalogCoverPreferred(game), let imported = readImage(file(game, "catalog.jpg")) { return imported }
        if kind == .cover, let box = readImage(file(game, "boxart")) { return box }
        if let imported = readImage(file(game, "catalog.jpg")) { return imported }
        return kind == .scene ? readImage(file(game, "preview.png")) : nil
    }
    func hasImportedImage(for game: Game, matching asset: ArtworkPackAsset?) -> Bool {
        LocalArtworkFiles.hasCurrentOrCustomImage(for: game.id, matching: asset, in: directory)
    }
    @discardableResult func importCatalogImage(_ image: ArtworkPackImage, for game: Game, coverIsSceneFallback: Bool = false) throws -> Bool {
        guard !hasImportedImage(for: game, matching: image.asset) else { return false }
        guard image.asset.accepts(image.data), Self.decode(image.data, maxSize: kind == .scene ? 2048 : 1024,
                          expected: CGSize(width: image.asset.width, height: image.asset.height)) != nil else { throw SceneImageError.invalidImage }
        try prepareDirectory()
        try image.data.write(to: file(game, "catalog.jpg"), options: .atomic)
        _ = try updateCatalogCoverPriority(for: game, asset: image.asset, isSceneFallback: coverIsSceneFallback)
        NotificationCenter.default.post(name: Notification.Name("EmuDenArtworkUpdated"), object: nil)
        return true
    }
    @discardableResult func updateCatalogCoverPriority(for game: Game, asset: ArtworkPackAsset, isSceneFallback: Bool) throws -> Bool {
        guard kind == .cover, LocalArtworkFiles.customImage(for: game.id, in: directory) == nil,
              LocalArtworkFiles.hasCurrentOrCustomImage(for: game.id, matching: asset, in: directory) else { return false }
        let previous = catalogCoverPreferred(game)
        try prepareDirectory()
        try Data([isSceneFallback ? 0 : 1]).write(to: file(game, "catalog-preferred"), options: .atomic)
        return previous != !isSceneFallback
    }
    private func catalogCoverPreferred(_ game: Game) -> Bool {
        let marker = file(game, "catalog-preferred")
        guard let values = try? marker.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true, values.fileSize == 1,
              let data = try? Data(contentsOf: marker) else { return true }
        return data != Data([0])
    }
    func hasBoxCover(for game: Game, from url: URL) -> Bool {
        if LocalArtworkFiles.customImage(for: game.id, in: directory) != nil { return true }
        if catalogCoverPreferred(game), readImage(file(game, "catalog.jpg")) != nil { return true }
        let marker = file(game, "box-url")
        guard let values = try? marker.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, (1...4096).contains(size),
              let saved = try? String(contentsOf: marker, encoding: .utf8) else { return false }
        return saved == url.absoluteString && readImage(file(game, "boxart")) != nil
    }
    @discardableResult func importBoxCover(_ data: Data, from url: URL, for game: Game) throws -> Bool {
        guard kind == .cover, customImage(for: game) == nil else { return false }
        guard data.count <= 4 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (256...4096).contains(width), (256...4096).contains(height),
              Self.decode(data, maxSize: 1024) != nil else { throw SceneImageError.invalidImage }
        try prepareDirectory()
        try data.write(to: file(game, "boxart"), options: .atomic)
        try Data(url.absoluteString.utf8).write(to: file(game, "box-url"), options: .atomic)
        NotificationCenter.default.post(name: Notification.Name("EmuDenArtworkUpdated"), object: nil)
        return true
    }
    func customImage(for game: Game) -> UIImage? {
        LocalArtworkFiles.customImage(for: game.id, in: directory).flatMap(readImage)
    }
    func cachedImage(for game: Game) -> UIImage? { image(for: game) }
    func hasKnownImage(for game: Game) -> Bool {
        LocalArtworkFiles.customImage(for: game.id, in: directory) != nil ||
            (kind == .cover && FileManager.default.fileExists(atPath: file(game, "boxart").path)) ||
            FileManager.default.fileExists(atPath: file(game, "catalog.jpg").path) ||
            (kind == .scene && FileManager.default.fileExists(atPath: file(game, "preview.png").path))
    }
    func preferredImage(for game: Game) -> UIImage? {
        kind == .cover ? image(for: game) : (customImage(for: game) ?? readImage(file(game, "catalog.jpg")))
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
        try png.write(to: file(game, "user.png"), options: .atomic)
        try Data().write(to: file(game, "custom"), options: .atomic)
        NotificationCenter.default.post(name: Notification.Name("EmuDenArtworkUpdated"), object: nil)
    }
    func storeScene(_ image: UIImage, for game: Game) throws {
        guard kind == .scene, highResolution(image), customImage(for: game) == nil,
              let data = image.pngData(), let decoded = Self.decode(data, maxSize: 2048), let png = decoded.pngData() else { return }
        try prepareDirectory()
        // Keep user-captured previews distinct from older downloaded caches.
        try png.write(to: file(game, "preview.png"), options: .atomic)
        var url = file(game, "preview.png"), values = URLResourceValues(); values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
    func reset(_ game: Game, clearCustom: Bool) throws {
        for ext in ["preview.png"] + (clearCustom ? ["user.png", "custom", "catalog.jpg", "catalog-preferred", "boxart", "box-url"] : []) {
            let url = file(game, ext)
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }
        // Older downloaded PNGs remain on disk but are never selected without a user-import marker.
    }
    private func file(_ game: Game, _ ext: String) -> URL { directory.appendingPathComponent(game.id.uuidString + "." + ext) }
    private func readImage(_ url: URL) -> UIImage? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 0, size <= 32 * 1024 * 1024,
              let data = try? Data(contentsOf: url) else { return nil }
        return Self.decode(data, maxSize: kind == .scene ? 2048 : 1024)
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
