import XCTest
@testable import EmulatorDomain

final class ArtworkIdentityTests: XCTestCase {
    private func file(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".cci")
        try data.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func ncch() -> Data {
        var header = Data(repeating: 0, count: 0x200)
        header.replaceSubrange(0x100..<0x104, with: Data("NCCH".utf8))
        header.replaceSubrange(0x118..<0x120, with: [0, 0xce, 0x0c, 0, 0, 0, 4, 0])
        return header
    }
    func testDirectAndCartridgeContainersUseTheProgramID() throws {
        XCTAssertEqual(ThreeDSProgramID.read(try file(ncch())), "00040000000CCE00")
        var cart = Data(repeating: 0, count: 0x200)
        cart.replaceSubrange(0x100..<0x104, with: Data("NCSD".utf8))
        cart.replaceSubrange(0x108..<0x110, with: Array(repeating: 0xff, count: 8))
        cart[0x120] = 1; cart[0x124] = 1
        cart.append(ncch())
        XCTAssertEqual(ThreeDSProgramID.read(try file(cart)), "00040000000CCE00")
    }
    func testTruncatedInvalidAndOutOfBoundsContainersAreIgnored() throws {
        XCTAssertNil(ThreeDSProgramID.read(try file(Data(ncch().prefix(0x11f)))))
        XCTAssertNil(ThreeDSProgramID.read(try file(Data("3DSXhomebrew".utf8))))
        var cart = ncch(); cart.replaceSubrange(0x100..<0x104, with: Data("NCSD".utf8))
        cart.replaceSubrange(0x120..<0x124, with: Array(repeating: 0xff, count: 4)); cart[0x124] = 1
        XCTAssertNil(ThreeDSProgramID.read(try file(cart)))
        var zero = ncch(); zero.replaceSubrange(0x118..<0x120, with: Array(repeating: 0, count: 8))
        XCTAssertNil(ThreeDSProgramID.read(try file(zero)))
    }
    func testRenamedGamesUseIdentityAndManualChoicesTakePriority() {
        let names = ArtworkCatalog(files: ["Donkey Kong Country Returns 3D (USA).png", "Tomodachi Life (USA).png"])
        let identities = ArtworkIdentityCatalog(titles: ["00040000000CCE00": "Donkey Kong Country Returns 3D"])
        var game = Game(title: "Renamed cartridge", fileName: "a.cci", programID: "00040000000cce00")
        XCTAssertEqual(identities.name(for: game, covers: names), "Donkey Kong Country Returns 3D")
        game.artworkTitle = "Tomodachi Life"
        XCTAssertEqual(identities.name(for: game, covers: names), "Tomodachi Life")
        game.artworkTitle = nil; game.programID = "not-in-catalog"
        XCTAssertEqual(identities.name(for: game, covers: names), game.title)
        XCTAssertEqual(identities.name(for: game, covers: ArtworkCatalog(files: [])), game.title)
    }
    func testOldLibraryAndNewArtworkPreferencesRoundTrip() throws {
        let data = Data("[{\"id\":\"AA000000-0000-0000-0000-000000000001\",\"title\":\"Old game\",\"fileName\":\"a.3dsx\",\"added\":0}]".utf8)
        var games = try JSONDecoder().decode([Game].self, from: data)
        XCTAssertNil(games[0].artworkTitle); XCTAssertNil(games[0].programID); XCTAssertNil(games[0].useConsoleBackground)
        games[0].artworkTitle = "Tomodachi Life"; games[0].useConsoleBackground = true
        XCTAssertEqual(try JSONDecoder().decode([Game].self, from: JSONEncoder().encode(games)), games)
        XCTAssertEqual(games[0].fileName, "a.3dsx")
    }
    func testNativeScreenshotsAreRejectedAsHeroesWhileHDImagesPass() {
        XCTAssertFalse(ArtworkScenePolicy.isHighResolution(width: 400, height: 240))
        XCTAssertFalse(ArtworkScenePolicy.isHighResolution(width: 1024, height: 1024))
        XCTAssertFalse(ArtworkScenePolicy.isHighResolution(width: 2048, height: 240))
        XCTAssertTrue(ArtworkScenePolicy.isHighResolution(width: 1280, height: 720))
        XCTAssertTrue(ArtworkScenePolicy.isHighResolution(width: 720, height: 1280))
        XCTAssertFalse(ArtworkScenePolicy.isHighResolution(width: -1, height: 0))
    }
    func testArtworkSearchDeduplicatesRegionsAndHandlesPunctuation() {
        let names = ArtworkCatalog(files: ["Tomodachi Life (USA).png", "Tomodachi Life (Europe).png", "Mario _ Luigi - Dream Team (USA).png"])
        XCTAssertEqual(names.search("tomodachi"), ["Tomodachi Life (USA).png"])
        XCTAssertEqual(names.search("Mario & Luigi"), ["Mario _ Luigi - Dream Team (USA).png"])
        XCTAssertTrue(names.search("unknown").isEmpty)
        XCTAssertTrue(names.search("", limit: 0).isEmpty)
    }
    func testRetailCaseStripIsRemovedWithoutTrimmingPortraitArt() {
        XCTAssertEqual(ArtworkCoverPolicy.frontWidth(width: 512, height: 456), 456)
        XCTAssertEqual(ArtworkCoverPolicy.frontWidth(width: 600, height: 900), 600)
        XCTAssertEqual(ArtworkCoverPolicy.frontWidth(width: 512, height: 512), 512)
        XCTAssertEqual(ArtworkCoverPolicy.frontWidth(width: 0, height: 512), 0)
    }
}
