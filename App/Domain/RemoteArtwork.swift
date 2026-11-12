import Foundation
import CryptoKit

enum ArtworkNetwork {
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: "onlineArtworkEnabled") && defaults.bool(forKey: "hasArtworkChoice")
    }
    static func configuration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        return config
    }
}

public struct ArtworkPackAsset: Codable, Equatable, Sendable {
    public let path: String
    public let sha256: String
    public let bytes: Int
    public let width: Int
    public let height: Int

    fileprivate func valid(key: String, kind: ArtworkKind) -> Bool {
        let name = kind == .cover ? "cover" : "scene"
        let prefix = "images/\(key)/\(name)-"
        guard path.hasPrefix(prefix), path.hasSuffix(".jpg"),
              path.dropFirst(prefix.count).dropLast(4).range(of: "^[0-9a-f]{12}$", options: .regularExpression) != nil,
              sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil,
              path == prefix + sha256.prefix(12) + ".jpg",
              (1...4 * 1024 * 1024).contains(bytes), (320...4096).contains(width), (320...4096).contains(height) else { return false }
        let ratio = Double(width) / Double(height)
        return kind == .cover ? (0.6...0.76).contains(ratio) && height >= 960
            : (1.3...2.4).contains(ratio) && ArtworkScenePolicy.isHighResolution(width: width, height: height)
    }
    fileprivate func accepts(_ data: Data) -> Bool {
        data.count == bytes && SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() == sha256
    }
}

public struct ArtworkPackGame: Decodable, Sendable {
    public let key: String
    public let title: String
    public let aliases: [String]
    public let programIDs: [String]
    public let cover: ArtworkPackAsset?
    public let scene: ArtworkPackAsset?
    public func asset(_ kind: ArtworkKind) -> ArtworkPackAsset? { kind == .cover ? cover : scene }
}

public struct ArtworkPack: Decodable, Sendable {
    public let version: Int
    public let baseURL: URL
    public let games: [ArtworkPackGame]
    private let ids: [String: Int]
    private let names: [String: Int]
    private enum CodingKeys: String, CodingKey { case schema, version, baseURL, games }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        baseURL = try values.decode(URL.self, forKey: .baseURL)
        games = try values.decode([ArtworkPackGame].self, forKey: .games)
        guard try values.decode(Int.self, forKey: .schema) == 1, version > 0,
              baseURL.scheme == "https", baseURL.host?.isEmpty == false,
              baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil,
              baseURL.port == nil || baseURL.port == 443, baseURL.absoluteString.hasSuffix("/"),
              (1...1000).contains(games.count) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid artwork catalog"))
        }
        var ids = [String: Int](), names = [String: Int](), keys = Set<String>()
        for (index, game) in games.enumerated() {
            guard game.key.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil,
                  game.key.count <= 80, keys.insert(game.key).inserted,
                  !game.title.isEmpty, game.title.count <= 200, game.aliases.count <= 32, game.programIDs.count <= 32,
                  game.cover?.valid(key: game.key, kind: .cover) != false, game.scene?.valid(key: game.key, kind: .scene) != false else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid artwork entry"))
            }
            for id in game.programIDs {
                guard id.range(of: "^00040000[0-9A-F]{8}$", options: .regularExpression) != nil,
                      ids[id] == nil || ids[id] == index else {
                    throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid or ambiguous title ID"))
                }
                ids[id] = index
            }
            for title in [game.title] + game.aliases {
                let key = ArtworkCatalog.matchKey(title)
                guard !key.isEmpty, title.count <= 200, names[key] == nil || names[key] == index else {
                    throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Ambiguous artwork title"))
                }
                names[key] = index
            }
        }
        self.ids = ids; self.names = names
    }
    public func match(_ game: Game) -> ArtworkPackGame? {
        if let title = game.artworkTitle, !title.isEmpty { return names[ArtworkCatalog.matchKey(title)].map { games[$0] } }
        if let id = game.programID?.uppercased(), let index = ids[id] { return games[index] }
        return names[ArtworkCatalog.matchKey(game.title)].map { games[$0] }
    }
}

public struct ArtworkPackImage: Sendable {
    public let data: Data
    public let asset: ArtworkPackAsset
}

/// A small HTTPS index and images fetched on demand. User-selected images live elsewhere.
public actor RemoteArtworkCatalog {
    private var pack: ArtworkPack
    private let seed: ArtworkPack
    private let directory: URL
    private let session: URLSession
    private var enabled: Bool
    private var refreshed = Date.distantPast
    private var refreshRequest: (id: UUID, task: Task<Data?, Never>)?
    private var requests = [String: (id: UUID, task: Task<Data?, Never>)]()
    private var retryAfter = [String: Date]()
    private static let manifestLimit = 512 * 1024

    public init(seed: ArtworkPack, directory: URL, session: URLSession? = nil, initiallyEnabled: Bool = true) {
        self.seed = seed; self.directory = directory
        self.session = session ?? URLSession(configuration: ArtworkNetwork.configuration())
        enabled = initiallyEnabled
        if let data = Self.read(directory.appendingPathComponent("catalog.json"), limit: Self.manifestLimit),
           let cached = try? JSONDecoder().decode(ArtworkPack.self, from: data), cached.baseURL == seed.baseURL, cached.version >= seed.version {
            pack = cached
        } else { pack = seed }
    }
    public func setFetchingEnabled(_ active: Bool) {
        enabled = active
        if !active {
            refreshRequest?.task.cancel(); refreshRequest = nil; refreshed = .distantPast
            for (key, request) in requests { request.task.cancel(); retryAfter[key] = nil }
            requests.removeAll()
        }
    }
    public func hasAsset(for game: Game, kind: ArtworkKind) -> Bool {
        pack.match(game)?.asset(kind) != nil
    }
    public func cachedImage(for game: Game, kind: ArtworkKind) -> ArtworkPackImage? {
        guard let entry = pack.match(game), let asset = entry.asset(kind) else { return nil }
        if let bytes = cached(asset) { return ArtworkPackImage(data: bytes, asset: asset) }
        return previous(entry.key + (kind == .cover ? "-cover.json" : "-scene.json"), key: entry.key, kind: kind)
    }
    @discardableResult public func refresh(force: Bool = false) async -> Bool {
        guard enabled, !Task.isCancelled, refreshRequest == nil,
              force || Date().timeIntervalSince(refreshed) >= 6 * 3600 else { return false }
        refreshed = Date()
        let id = UUID(), session = session, url = seed.baseURL.appendingPathComponent("catalog.json")
        let task = Task { await Self.download(url, session: session, limit: Self.manifestLimit) }
        refreshRequest = (id, task)
        let data = await task.value
        guard refreshRequest?.id == id else { return false }
        refreshRequest = nil
        guard enabled, let data, let next = try? JSONDecoder().decode(ArtworkPack.self, from: data),
              next.baseURL == seed.baseURL, next.version > pack.version else { return false }
        do {
            try prepareDirectory()
            try data.write(to: directory.appendingPathComponent("catalog.json"), options: .atomic)
            pack = next
            return true
        } catch { return false }
    }
    public func image(for game: Game, kind: ArtworkKind, force: Bool = false) async -> ArtworkPackImage? {
        guard let entry = pack.match(game), let asset = entry.asset(kind), !Task.isCancelled else { return nil }
        let slot = entry.key + (kind == .cover ? "-cover.json" : "-scene.json")
        if let data = cached(asset) { return ArtworkPackImage(data: data, asset: asset) }
        guard enabled, force || (retryAfter[asset.sha256] ?? .distantPast) < Date() else { return previous(slot, key: entry.key, kind: kind) }
        let request: (id: UUID, task: Task<Data?, Never>)
        if let existing = requests[asset.sha256] { request = existing }
        else {
            let url = seed.baseURL.appendingPathComponent(asset.path), session = session
            request = (UUID(), Task { await Self.download(url, session: session, limit: asset.bytes) })
            requests[asset.sha256] = request
        }
        let bytes = await request.task.value
        guard requests[asset.sha256]?.id == request.id else { return previous(slot, key: entry.key, kind: kind) }
        requests[asset.sha256] = nil
        guard enabled, let bytes, asset.accepts(bytes) else {
            if enabled { retryAfter[asset.sha256] = Date().addingTimeInterval(300) }
            return previous(slot, key: entry.key, kind: kind)
        }
        do {
            try prepareDirectory()
            try bytes.write(to: imageURL(asset), options: .atomic)
            try JSONEncoder().encode(asset).write(to: directory.appendingPathComponent(slot), options: .atomic)
            NotificationCenter.default.post(name: Notification.Name("EmuDenArtworkUpdated"), object: nil)
            return ArtworkPackImage(data: bytes, asset: asset)
        } catch { return previous(slot, key: entry.key, kind: kind) }
    }
    private func cached(_ asset: ArtworkPackAsset) -> Data? {
        guard let data = Self.read(imageURL(asset), limit: asset.bytes), asset.accepts(data) else { return nil }
        return data
    }
    private func previous(_ slot: String, key: String, kind: ArtworkKind) -> ArtworkPackImage? {
        guard let bytes = Self.read(directory.appendingPathComponent(slot), limit: 4096),
              let asset = try? JSONDecoder().decode(ArtworkPackAsset.self, from: bytes), asset.valid(key: key, kind: kind),
              let image = cached(asset) else { return nil }
        return ArtworkPackImage(data: image, asset: asset)
    }
    private func imageURL(_ asset: ArtworkPackAsset) -> URL { directory.appendingPathComponent(asset.sha256 + ".jpg") }
    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else { throw CocoaError(.fileWriteInvalidFileName) }
        var folder = directory, backup = URLResourceValues(); backup.isExcludedFromBackup = true
        try? folder.setResourceValues(backup)
    }
    private static func read(_ url: URL, limit: Int) -> Data? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize, size > 0, size <= limit,
              let data = try? Data(contentsOf: url), data.count <= limit else { return nil }
        return data
    }
    private static func download(_ url: URL, session: URLSession, limit: Int) async -> Data? {
        do {
            try Task.checkCancellation()
            var request = URLRequest(url: url); request.timeoutInterval = 20; request.cachePolicy = .reloadIgnoringLocalCacheData
            request.httpShouldHandleCookies = false
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  response.url?.scheme == "https", response.url?.host == url.host, response.url?.port == url.port,
                  response.expectedContentLength <= Int64(limit) else { return nil }
            var data = Data()
            for try await byte in bytes {
                if data.count % 16384 == 0 { try Task.checkCancellation() }
                guard data.count < limit else { return nil }
                data.append(byte)
            }
            try Task.checkCancellation()
            return data
        } catch { return nil }
    }
}
