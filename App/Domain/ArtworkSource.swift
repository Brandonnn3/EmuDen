import Foundation

public struct BoxArtworkSource: Equatable, Sendable {
    public let url: URL
    public init(_ text: String) throws {
        let manifest = try ArtworkCatalogSource.catalogURL(text)
        let folder = manifest.deletingLastPathComponent()
        guard manifest.lastPathComponent == "catalog.json", folder.lastPathComponent == "Named_Boxarts" else {
            throw ArtworkSourceError.invalidBoxFolder
        }
        url = folder
    }
    public func imageURL(for title: String, catalog: ArtworkCatalog) -> URL? {
        guard let name = catalog.match(title), name.count <= 300, name.hasSuffix(".png"),
              !name.hasPrefix("."), !name.contains("/"), !name.contains("\\"), !name.contains("\0") else { return nil }
        return url.appendingPathComponent(name)
    }
    public static func read(from file: URL) -> Self? {
        guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, (1...2048).contains(size),
              let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        return try? Self(text)
    }
}

public enum ArtworkSourceError: LocalizedError {
    case invalidLink, unavailable, invalidCatalog, invalidBoxFolder
    public var errorDescription: String? {
        switch self {
        case .invalidLink: return "Enter an HTTPS artwork catalog link without a login, query or fragment. A collection folder link also works."
        case .unavailable: return "The artwork catalog couldn’t be downloaded. Check the link and connection; the catalog must be readable without signing in."
        case .invalidCatalog: return "This link doesn’t contain a compatible artwork catalog. Its images must use the same site and folder as the catalog."
        case .invalidBoxFolder: return "Enter the HTTPS link to a compatible Named_Boxarts folder containing original game-cover PNGs."
        }
    }
}

public struct ArtworkCatalogSource: Codable, Sendable {
    public let url: URL
    public let pack: ArtworkPack
    private let manifest: Data
    private enum CodingKeys: String, CodingKey { case url, manifest }

    public static func catalogURL(_ text: String) throws -> URL {
        guard var url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.absoluteString.count <= 2048,
              url.port == nil || url.port == 443 else { throw ArtworkSourceError.invalidLink }
        if url.pathExtension.lowercased() != "json" { url.appendPathComponent("catalog.json") }
        return url
    }
    public init(url: URL, manifest: Data) throws {
        guard try Self.catalogURL(url.absoluteString) == url, !manifest.isEmpty, manifest.count <= 512 * 1024,
              let pack = try? JSONDecoder().decode(ArtworkPack.self, from: manifest),
              pack.baseURL == url.deletingLastPathComponent() else { throw ArtworkSourceError.invalidCatalog }
        self.url = url; self.pack = pack; self.manifest = manifest
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(url: values.decode(URL.self, forKey: .url), manifest: values.decode(Data.self, forKey: .manifest))
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(url, forKey: .url); try values.encode(manifest, forKey: .manifest)
    }
    public static func read(from url: URL) -> Self? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, (1...768 * 1024).contains(size),
              let data = try? Data(contentsOf: url), data.count <= 768 * 1024 else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    public func write(to url: URL) throws { try JSONEncoder().encode(self).write(to: url, options: .atomic) }
}

public struct ArtworkImportItem: Identifiable, Sendable {
    public var id: UUID { game.id }
    public let game: Game
    public let cover: Bool
    public let scene: Bool
}

public struct ArtworkImportPlan: Sendable {
    public let items: [ArtworkImportItem]
    public let unmatchedGames: Int
    public var coverCount: Int { items.filter(\.cover).count }
    public var sceneCount: Int { items.filter(\.scene).count }
    public init(pack: ArtworkPack, games: [Game], protectedCovers: Set<UUID> = [], protectedScenes: Set<UUID> = []) {
        var items = [ArtworkImportItem](), unmatched = 0
        for game in games {
            guard let entry = pack.match(game) else { unmatched += 1; continue }
            let cover = entry.cover != nil && !protectedCovers.contains(game.id)
            let scene = entry.scene != nil && !protectedScenes.contains(game.id) && game.useConsoleBackground != true
            if cover || scene { items.append(ArtworkImportItem(game: game, cover: cover, scene: scene)) }
        }
        self.items = items; unmatchedGames = unmatched
    }
}
