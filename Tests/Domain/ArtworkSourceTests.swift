import XCTest
@testable import EmulatorDomain

final class ArtworkSourceTests: XCTestCase {
    func testBoxArtFolderMatchesOriginalNamesAndRejectsUnsafeSources() throws {
        let source = try BoxArtworkSource("https://covers.example/3DS/Named_Boxarts/")
        let names = ArtworkCatalog(files: ["Mario Golf - World Tour (USA).png", "Mario _ Luigi - Dream Team (USA).png"])
        XCTAssertEqual(source.imageURL(for: "Mario Golf: World Tour", catalog: names)?.lastPathComponent, "Mario Golf - World Tour (USA).png")
        XCTAssertEqual(source.imageURL(for: "Mario & Luigi: Dream Team", catalog: names)?.host, "covers.example")
        XCTAssertNil(source.imageURL(for: "Not a game", catalog: names))
        XCTAssertNil(source.imageURL(for: "../outside", catalog: ArtworkCatalog(files: ["../outside.png"])))
        for text in ["http://covers.example/Named_Boxarts/", "file:///tmp/Named_Boxarts/", "https://u:p@covers.example/Named_Boxarts/",
                     "https://covers.example/Named_Boxarts/?token=x", "https://covers.example/Named_Boxarts/#x", "https://covers.example/collection/",
                     "https://covers.example/Named_Boxarts/image.png", "https://covers.example:8443/Named_Boxarts/"] {
            XCTAssertThrowsError(try BoxArtworkSource(text), text)
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("source.txt")
        try Data(source.url.absoluteString.utf8).write(to: file)
        XCTAssertEqual(BoxArtworkSource.read(from: file), source)
        let link = folder.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertNil(BoxArtworkSource.read(from: link))
        try Data(repeating: 32, count: 2049).write(to: file)
        XCTAssertNil(BoxArtworkSource.read(from: file))
    }
    private let root = URL(string: "https://artwork.example/collection/")!
    private func manifest(base: String? = nil) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schema": 1, "version": 1, "baseURL": base ?? root.absoluteString, "games": [[
            "key": "homebrew", "title": "Original Homebrew", "aliases": ["Homebrew Test"], "programIDs": ["0004000000123400"],
            "cover": ["path": "images/homebrew/cover-" + String(repeating: "a", count: 12) + ".jpg", "sha256": String(repeating: "a", count: 64), "bytes": 1024, "width": 1024, "height": 1536],
            "scene": ["path": "images/homebrew/scene-" + String(repeating: "b", count: 12) + ".jpg", "sha256": String(repeating: "b", count: 64), "bytes": 1024, "width": 1536, "height": 1024]
        ]]])
    }
    func testLinkAcceptsCollectionFoldersAndJSONWithoutPermittingCredentials() throws {
        for text in [root.absoluteString, "  " + root.absoluteString + " \n", root.appendingPathComponent("catalog.json").absoluteString] {
            XCTAssertEqual(try ArtworkCatalogSource.catalogURL(text), root.appendingPathComponent("catalog.json"))
        }
        for text in ["http://artwork.example/", "file:///tmp/catalog.json", "https://user:secret@artwork.example/", "https://artwork.example/?token=x", "https://artwork.example/#section", "https://artwork.example:8443/", "not a link"] {
            XCTAssertThrowsError(try ArtworkCatalogSource.catalogURL(text))
        }
    }
    func testSourceRequiresItsOwnDirectoryAndRejectsHTMLAndOversizedManifests() throws {
        let url = root.appendingPathComponent("catalog.json")
        XCTAssertThrowsError(try ArtworkCatalogSource(url: url, manifest: manifest(base: "https://another.example/")))
        XCTAssertThrowsError(try ArtworkCatalogSource(url: url, manifest: manifest(base: "https://artwork.example/elsewhere/")))
        XCTAssertThrowsError(try ArtworkCatalogSource(url: url, manifest: Data("<html>not a catalog</html>".utf8)))
        XCTAssertThrowsError(try ArtworkCatalogSource(url: url, manifest: Data(repeating: 32, count: 512 * 1024 + 1)))
    }
    func testIDAndNameMatchingProtectsImagesAndConsolePreferences() throws {
        let source = try ArtworkCatalogSource(url: root.appendingPathComponent("catalog.json"), manifest: manifest())
        let renamed = Game(title: "Renamed game", fileName: "game.3ds", programID: "0004000000123400")
        var byName = Game(title: "Homebrew Test (USA).3ds", fileName: "two.3ds"); byName.useConsoleBackground = true
        let unknown = Game(title: "Unknown", fileName: "three.3ds")
        let plan = ArtworkImportPlan(pack: source.pack, games: [renamed, byName, unknown], protectedCovers: [renamed.id])
        XCTAssertEqual(plan.items.count, 2); XCTAssertEqual(plan.coverCount, 1); XCTAssertEqual(plan.sceneCount, 1)
        XCTAssertEqual(plan.unmatchedGames, 1)
        XCTAssertFalse(plan.items[0].cover); XCTAssertTrue(plan.items[0].scene)
        XCTAssertTrue(plan.items[1].cover); XCTAssertFalse(plan.items[1].scene)
        let protected = ArtworkImportPlan(pack: source.pack, games: [renamed], protectedCovers: [renamed.id], protectedScenes: [renamed.id])
        XCTAssertTrue(protected.items.isEmpty)
    }
    func testRememberedCatalogSurvivesRelaunchAndRejectsSymlinks() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("source.json")
        XCTAssertNil(ArtworkCatalogSource.read(from: file))
        let source = try ArtworkCatalogSource(url: root.appendingPathComponent("catalog.json"), manifest: manifest())
        try source.write(to: file)
        let restored = try XCTUnwrap(ArtworkCatalogSource.read(from: file))
        XCTAssertEqual(restored.url, source.url); XCTAssertEqual(restored.pack.games.count, 1)
        let link = directory.appendingPathComponent("link.json")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertNil(ArtworkCatalogSource.read(from: link))
        try Data("bad JSON".utf8).write(to: file)
        XCTAssertNil(ArtworkCatalogSource.read(from: file))
    }
    func testRedirectsCannotContactADifferentHostOrDowngradeHTTPS() {
        let policy = ArtworkRedirectPolicy(origin: root)
        XCTAssertTrue(policy.allowed(root.appendingPathComponent("images/test.jpg")))
        XCTAssertFalse(policy.allowed(URL(string: "https://different.example/image.jpg")!))
        XCTAssertFalse(policy.allowed(URL(string: "http://artwork.example/image.jpg")!))
        XCTAssertFalse(policy.allowed(URL(string: "https://artwork.example:8443/image.jpg")!))
        XCTAssertFalse(policy.allowed(URL(string: "https://user:secret@artwork.example/image.jpg")!))
    }
}
