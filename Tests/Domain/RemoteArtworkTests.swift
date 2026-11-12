import XCTest
import CryptoKit
@testable import EmulatorDomain

@MainActor final class RemoteArtworkTests: XCTestCase {
    func testArtworkTransportDoesNotPersistCookiesCredentialsOrHTTPCache() {
        let config = ArtworkNetwork.configuration()
        XCTAssertFalse(config.httpShouldSetCookies)
        XCTAssertEqual(config.httpCookieAcceptPolicy, .never)
        XCTAssertNil(config.httpCookieStorage)
        XCTAssertNil(config.urlCredentialStorage)
        XCTAssertNil(config.urlCache)
    }
    func testNetworkingRequiresAnAffirmativeArtworkChoice() throws {
        let name = "EmuDenArtworkChoice-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertFalse(ArtworkNetwork.isEnabled(in: defaults))
        defaults.set(true, forKey: "onlineArtworkEnabled")
        XCTAssertFalse(ArtworkNetwork.isEnabled(in: defaults))
        defaults.set(true, forKey: "hasArtworkChoice")
        XCTAssertTrue(ArtworkNetwork.isEnabled(in: defaults))
        defaults.set(false, forKey: "onlineArtworkEnabled")
        XCTAssertFalse(ArtworkNetwork.isEnabled(in: defaults))
    }
    func testDisabledCatalogDoesNotRequestBeforeConsent() async throws {
        let json = manifest(), transport = session(), bytes = Data("first image".utf8)
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: try directory(), session: transport, initiallyEnabled: false)
        let image = await catalog.image(for: game, kind: .scene)
        let refreshed = await catalog.refresh(force: true)
        XCTAssertNil(image); XCTAssertFalse(refreshed); XCTAssertEqual(ArtworkProtocol.count, 0)
        ArtworkProtocol.reply(path(json, "scene"), data: bytes)
        await catalog.setFetchingEnabled(true)
        let accepted = await catalog.image(for: game, kind: .scene)
        XCTAssertEqual(accepted?.data, bytes); XCTAssertEqual(ArtworkProtocol.count, 1)
    }
    private let root = URL(string: "https://artwork.example/")!
    private let game = Game(title: "Renamed", fileName: "a.cci", programID: "00040000000CCE00")
    private func asset(_ bytes: Data, key: String = "donkey-kong", scene: Bool = false) -> [String: Any] {
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return ["path": "images/\(key)/\(scene ? "scene" : "cover")-\(digest.prefix(12)).jpg", "sha256": digest,
                "bytes": bytes.count, "width": scene ? 1536 : 1024, "height": scene ? 1024 : 1536]
    }
    private func manifest(version: Int = 1, bytes: Data = Data("first image".utf8)) -> [String: Any] {
        ["schema": 1, "version": version, "baseURL": root.absoluteString, "games": [[
            "key": "donkey-kong", "title": "Donkey Kong Country Returns 3D", "aliases": ["Donkey Kong Country Returns 3D"],
            "programIDs": ["00040000000CCE00"], "cover": asset(bytes), "scene": asset(bytes, scene: true)
        ]]]
    }
    private func encode(_ json: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: json) }
    private func pack(_ json: [String: Any]) throws -> ArtworkPack { try JSONDecoder().decode(ArtworkPack.self, from: encode(json)) }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("EmuDen-Artwork-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func session() -> URLSession {
        ArtworkProtocol.reset()
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ArtworkProtocol.self]
        return URLSession(configuration: config)
    }
    private func path(_ json: [String: Any], _ kind: String = "cover") -> String {
        let entry = (json["games"] as! [[String: Any]])[0]
        return "/" + ((entry[kind] as! [String: Any])["path"] as! String)
    }
    func testIDsNamesAndExplicitChoicesHaveStrictPrecedence() throws {
        let catalog = try pack(manifest())
        XCTAssertEqual(catalog.match(game)?.key, "donkey-kong")
        var renamed = game; renamed.programID = nil; renamed.title = "Donkey Kong Country Returns 3D (USA).cci"
        XCTAssertNotNil(catalog.match(renamed))
        renamed.title = "Donkey Kong Country Returns 3D 2"; XCTAssertNil(catalog.match(renamed))
        var override = game; override.artworkTitle = "Another game"
        XCTAssertNil(catalog.match(override), "An explicit artwork choice must override the ROM ID")
    }
    func testWidgetCacheReadsNeverDownloadAndRejectChangedBytes() async throws {
        let json = manifest(), folder = try directory(), transport = session(), bytes = Data("first image".utf8)
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        let missing = await catalog.cachedImage(for: game, kind: .cover)
        XCTAssertNil(missing); XCTAssertEqual(ArtworkProtocol.count, 0)
        ArtworkProtocol.reply(path(json), data: bytes)
        _ = await catalog.image(for: game, kind: .cover)
        let cached = await catalog.cachedImage(for: game, kind: .cover)
        XCTAssertEqual(cached?.data, bytes); XCTAssertEqual(ArtworkProtocol.count, 1)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let image = try XCTUnwrap(files.first { $0.pathExtension == "jpg" })
        try Data("damaged".utf8).write(to: image)
        let damaged = await catalog.cachedImage(for: game, kind: .cover)
        XCTAssertNil(damaged); XCTAssertEqual(ArtworkProtocol.count, 1)
    }
    func testActualCollectionSeedDecodesAndIdentifiesEveryEntry() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/CinematicArt/Artwork-Pack.json"))
        let actual = try JSONDecoder().decode(ArtworkPack.self, from: data)
        XCTAssertGreaterThanOrEqual(actual.games.count, 28)
        XCTAssertEqual(actual.games.filter { $0.scene != nil }.count, actual.games.count)
        XCTAssertGreaterThanOrEqual(actual.games.filter { $0.cover != nil }.count, 24)
        for entry in actual.games {
            XCTAssertEqual(actual.match(Game(title: entry.title, fileName: "test.cci"))?.key, entry.key)
            for id in entry.programIDs {
                XCTAssertEqual(actual.match(Game(title: "Renamed", fileName: "test.cci", programID: id))?.key, entry.key)
            }
        }
    }
    func testSceneAvailabilityUsesMetadataWithoutDownloadingAndFollowsUpdates() async throws {
        let transport = session(), folder = try directory(), json = manifest()
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        let known = await catalog.hasAsset(for: game, kind: .scene)
        XCTAssertTrue(known)
        var unmatched = game; unmatched.artworkTitle = "Unknown homebrew"
        let unknown = await catalog.hasAsset(for: unmatched, kind: .scene)
        XCTAssertFalse(unknown); XCTAssertEqual(ArtworkProtocol.count, 0)
        await catalog.setFetchingEnabled(false)
        let offlineKnown = await catalog.hasAsset(for: game, kind: .scene)
        XCTAssertTrue(offlineKnown, "Known artwork must not flash a console scene while its cache is read offline")
        await catalog.setFetchingEnabled(true)
        var next = manifest(version: 2)
        var games = next["games"] as! [[String: Any]]; games[0]["scene"] = NSNull(); next["games"] = games
        ArtworkProtocol.reply("/catalog.json", data: try encode(next))
        let refreshed = await catalog.refresh(force: true); XCTAssertTrue(refreshed)
        let removed = await catalog.hasAsset(for: game, kind: .scene)
        let cover = await catalog.hasAsset(for: game, kind: .cover)
        XCTAssertFalse(removed); XCTAssertTrue(cover); XCTAssertEqual(ArtworkProtocol.count, 1)
    }
    func testManifestRejectsUnsafeURLsPathsDimensionsAndAmbiguousIDs() throws {
        let original = manifest()
        for url in ["http://artwork.example/", "https://user:password@artwork.example/", "https://artwork.example/?token=1", "https://artwork.example:8443/"] {
            var bad = original; bad["baseURL"] = url; XCTAssertThrowsError(try pack(bad))
        }
        for badPath in ["../outside.jpg", "https://other.example/a.jpg", "images/donkey-kong/cover-%2e%2e.jpg"] {
            var bad = original, entries = bad["games"] as! [[String: Any]], cover = entries[0]["cover"] as! [String: Any]
            cover["path"] = badPath; entries[0]["cover"] = cover; bad["games"] = entries
            XCTAssertThrowsError(try pack(bad))
        }
        var bad = original, entries = bad["games"] as! [[String: Any]], scene = entries[0]["scene"] as! [String: Any]
        scene["width"] = 400; scene["height"] = 240; entries[0]["scene"] = scene; bad["games"] = entries
        XCTAssertThrowsError(try pack(bad))
        entries = original["games"] as! [[String: Any]]; var other = entries[0]; other["key"] = "other"
        other["title"] = "Other"; other["aliases"] = ["Other"]
        other["cover"] = asset(Data("other".utf8), key: "other"); other["scene"] = asset(Data("other".utf8), key: "other", scene: true)
        entries.append(other); bad = original; bad["games"] = entries
        XCTAssertThrowsError(try pack(bad))
    }
    func testSceneOnlyEntryCanKeepTheExistingCoverFallback() async throws {
        var json = manifest(), entries = json["games"] as! [[String: Any]]
        entries[0]["cover"] = NSNull(); json["games"] = entries
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: try directory(), session: session())
        XCTAssertNil(try pack(json).match(game)?.cover)
        let image = await catalog.image(for: game, kind: .cover)
        XCTAssertNil(image); XCTAssertEqual(ArtworkProtocol.count, 0)
    }
    func testUnavailableArtworkUsesTheExistingConsoleFallbackWithoutRequests() async throws {
        var json = manifest(), entries = json["games"] as! [[String: Any]]
        entries[0]["cover"] = NSNull(); entries[0]["scene"] = NSNull(); json["games"] = entries
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: try directory(), session: session())
        let cover = await catalog.image(for: game, kind: .cover), scene = await catalog.image(for: game, kind: .scene)
        XCTAssertNil(cover); XCTAssertNil(scene); XCTAssertEqual(ArtworkProtocol.count, 0)
    }
    func testImagesDownloadOnceAndRemainAvailableOfflineAfterRelaunch() async throws {
        let json = manifest(), bytes = Data("first image".utf8), folder = try directory(), transport = session()
        ArtworkProtocol.reply(path(json), data: bytes)
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        let first = await catalog.image(for: game, kind: .cover)
        XCTAssertEqual(first?.data, bytes); XCTAssertEqual(ArtworkProtocol.count, 1)
        let again = await catalog.image(for: game, kind: .cover)
        XCTAssertEqual(again?.data, bytes); XCTAssertEqual(ArtworkProtocol.count, 1)
        let restarted = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        await restarted.setFetchingEnabled(false)
        let offline = await restarted.image(for: game, kind: .cover)
        XCTAssertEqual(offline?.data, bytes); XCTAssertEqual(ArtworkProtocol.count, 1)
    }
    func testCorruptAndOversizedResponsesAreNotCached() async throws {
        let json = manifest(), transport = session(), folder = try directory()
        ArtworkProtocol.reply(path(json), data: Data("wrong bytes".utf8))
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        let corrupt = await catalog.image(for: game, kind: .cover)
        XCTAssertNil(corrupt)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        ArtworkProtocol.reply(path(json), data: Data(repeating: 1, count: 100))
        let another = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        let oversized = await another.image(for: game, kind: .cover)
        XCTAssertNil(oversized)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        ArtworkProtocol.reply(path(json), data: Data("first image".utf8))
        let attempts = ArtworkProtocol.count
        let throttled = await catalog.image(for: game, kind: .cover)
        XCTAssertNil(throttled); XCTAssertEqual(ArtworkProtocol.count, attempts)
        let explicitRetry = await catalog.image(for: game, kind: .cover, force: true)
        XCTAssertNotNil(explicitRetry); XCTAssertEqual(ArtworkProtocol.count, attempts + 1)
    }
    func testRefreshPreservesOldImageOnFailureAndCachesNewManifest() async throws {
        let json = manifest(), old = Data("first image".utf8), fresh = Data("replacement".utf8), next = manifest(version: 2, bytes: fresh)
        let transport = session(), folder = try directory()
        ArtworkProtocol.reply(path(json), data: old)
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        _ = await catalog.image(for: game, kind: .cover)
        ArtworkProtocol.reply("/catalog.json", data: try encode(next))
        let refreshed = await catalog.refresh(force: true); XCTAssertTrue(refreshed)
        let stale = await catalog.image(for: game, kind: .cover)
        XCTAssertEqual(stale?.data, old, "Keep the previous successful image when its update fails")
        let restarted = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        ArtworkProtocol.reply(path(next), data: fresh)
        let upgraded = await restarted.image(for: game, kind: .cover)
        XCTAssertEqual(upgraded?.data, fresh, "A cached newer manifest must be used after relaunch")
        ArtworkProtocol.reply("/catalog.json", data: try encode(json))
        let rolledBack = await restarted.refresh(force: true); XCTAssertFalse(rolledBack)
        var foreign = next; foreign["version"] = 3; foreign["baseURL"] = "https://another.example/"
        ArtworkProtocol.reply("/catalog.json", data: try encode(foreign))
        let redirected = await restarted.refresh(force: true); XCTAssertFalse(redirected)
    }
    func testGameplayPausePreventsImageAndManifestRequests() async throws {
        let transport = session(), json = manifest()
        ArtworkProtocol.reply(path(json), data: Data("first image".utf8))
        ArtworkProtocol.reply("/catalog.json", data: try encode(manifest(version: 2)))
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: try directory(), session: transport)
        await catalog.setFetchingEnabled(false)
        let image = await catalog.image(for: game, kind: .cover), refreshed = await catalog.refresh(force: true)
        XCTAssertNil(image); XCTAssertFalse(refreshed); XCTAssertEqual(ArtworkProtocol.count, 0)
        await catalog.setFetchingEnabled(true)
        let resumed = await catalog.image(for: game, kind: .cover)
        XCTAssertNotNil(resumed); XCTAssertEqual(ArtworkProtocol.count, 1)
    }
    func testGameplayPauseCancelsAnInFlightDownload() async throws {
        let transport = session(), json = manifest(), folder = try directory()
        ArtworkProtocol.reply(path(json), data: Data("first image".utf8), hold: true)
        let catalog = RemoteArtworkCatalog(seed: try pack(json), directory: folder, session: transport)
        let pending = Task { await catalog.image(for: game, kind: .cover) }
        for _ in 0..<100 {
            if ArtworkProtocol.count > 0 { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(ArtworkProtocol.count, 1)
        await catalog.setFetchingEnabled(false)
        let image = await pending.value
        XCTAssertNil(image); XCTAssertGreaterThan(ArtworkProtocol.cancellations, 0)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }
}

private final class ArtworkProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies = [String: (data: Data, hold: Bool)]()
    nonisolated(unsafe) private static var requests = 0
    nonisolated(unsafe) private static var cancelled = 0
    static func reset() { lock.lock(); defer { lock.unlock() }; replies = [:]; requests = 0; cancelled = 0 }
    static func reply(_ path: String, data: Data, hold: Bool = false) { lock.lock(); defer { lock.unlock() }; replies[path] = (data, hold) }
    static var count: Int { lock.lock(); defer { lock.unlock() }; return requests }
    static var cancellations: Int { lock.lock(); defer { lock.unlock() }; return cancelled }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasSuffix("example") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self.requests += 1; let reply = Self.replies[request.url!.path]; Self.lock.unlock()
        if reply?.hold == true { return }
        let body = reply?.data ?? Data()
        let response = HTTPURLResponse(url: request.url!, statusCode: reply == nil ? 404 : 200, httpVersion: nil, headerFields: ["Content-Length": "\(body.count)"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { Self.lock.lock(); defer { Self.lock.unlock() }; Self.cancelled += 1 }
}
