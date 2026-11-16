import XCTest
@testable import EmulatorDomain

final class MultiConsoleArtworkTests: XCTestCase {
    private func entry(_ key: String, platform: String? = nil) -> [String: Any] {
        var result: [String: Any] = ["key": key, "title": "Shared Title", "aliases": ["Shared Alias"], "programIDs": []]
        if let platform { result["platform"] = platform }
        for kind in ["cover", "scene"] {
            result[kind] = ["path": "images/\(key)/\(kind)-aaaaaaaaaaaa.jpg", "sha256": String(repeating: "a", count: 64),
                            "bytes": 10, "width": kind == "cover" ? 1024 : 1536, "height": kind == "cover" ? 1536 : 1024]
        }
        return result
    }
    private func manifest(_ consoles: [[String: Any]], legacy: [[String: Any]]? = nil) -> [String: Any] {
        ["schema": 1, "version": 15, "baseURL": "https://artwork.example/", "games": legacy ?? [entry("legacy")], "consoleGames": consoles]
    }
    private func pack(_ json: [String: Any]) throws -> ArtworkPack {
        try JSONDecoder().decode(ArtworkPack.self, from: JSONSerialization.data(withJSONObject: json))
    }
    func testSameTitlesAndExplicitChoicesStayWithinTheirConsole() throws {
        let source = try pack(manifest([entry("ps1-shared", platform: "ps1"), entry("gc-shared", platform: "gamecube")]))
        for (platform, expected) in [(GamePlatform.threeDS, "legacy"), (.ps1, "ps1-shared"), (.gamecube, "gc-shared")] {
            var game = Game(title: "Shared Alias (USA)", fileName: "homebrew", programID: "0004000000123400", platform: platform)
            XCTAssertEqual(source.match(game)?.key, expected)
            game.artworkTitle = "Shared Title"; XCTAssertEqual(source.match(game)?.key, expected)
            game.artworkTitle = "Missing choice"; XCTAssertNil(source.match(game))
        }
    }
    func testConsoleExtensionRequiresExplicitSupportedPlatformAndNoThreeDSTitleIDs() throws {
        for platform in [nil, "3ds", "wii", "PS1"] as [String?] {
            XCTAssertThrowsError(try pack(manifest([entry("extra", platform: platform)])))
        }
        var extra = entry("extra", platform: "ps1"); extra["programIDs"] = ["0004000000123400"]
        XCTAssertThrowsError(try pack(manifest([extra])))
        XCTAssertThrowsError(try pack(manifest([], legacy: [entry("wrong", platform: "gamecube")])))
        XCTAssertThrowsError(try pack(manifest([entry("one", platform: "ps1"), entry("two", platform: "ps1")])))
        var unsafe = entry("unsafe", platform: "gamecube")
        var asset = unsafe["cover"] as! [String: Any]; asset["path"] = "../cover-aaaaaaaaaaaa.jpg"; unsafe["cover"] = asset
        XCTAssertThrowsError(try pack(manifest([unsafe])))
    }
    func testImportPlanIncludesAllConsolesAndPreservesCustomImagesAndBackgroundPreferences() throws {
        let source = try pack(manifest([entry("ps1-shared", platform: "ps1"), entry("gc-shared", platform: "gamecube")]))
        let threeDS = Game(title: "Shared Title", fileName: "test.cci")
        let ps1 = Game(title: "Shared Title", fileName: "test.chd", platform: .ps1)
        let gc = Game(title: "Shared Title", fileName: "test.iso", useConsoleBackground: true, platform: .gamecube)
        let unknown = Game(title: "Missing", fileName: "missing.iso", platform: .gamecube)
        let plan = ArtworkImportPlan(pack: source, games: [threeDS, ps1, gc, unknown], protectedCovers: [ps1.id])
        XCTAssertEqual(plan.items.count, 3); XCTAssertEqual(plan.coverCount, 2); XCTAssertEqual(plan.sceneCount, 2)
        XCTAssertEqual(plan.unmatchedGames, 1)
        XCTAssertFalse(try XCTUnwrap(plan.items.first { $0.id == ps1.id }).cover)
        XCTAssertFalse(try XCTUnwrap(plan.items.first { $0.id == gc.id }).scene)
    }
    func testPublishedCollectionMatchesAllSeventySevenEntriesAndAllAliases() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/Artwork-Catalog-15.json")
        let source = try JSONDecoder().decode(ArtworkPack.self, from: Data(contentsOf: file))
        XCTAssertEqual(source.games.count, 77)
        XCTAssertEqual(source.games.filter { $0.console == .ps1 }.count, 15)
        XCTAssertEqual(source.games.filter { $0.console == .gamecube }.count, 15)
        let threeDS = try XCTUnwrap(source.games.first { $0.console == .threeDS })
        XCTAssertNil(source.match(Game(title: "Unknown", fileName: "test", programID: threeDS.programIDs.first, platform: .ps1)))
        for entry in source.games {
            for title in [entry.title] + entry.aliases {
                let game = Game(title: title, fileName: "fixture", platform: entry.console)
                XCTAssertEqual(source.match(game)?.key, entry.key, title)
            }
        }
    }
}
