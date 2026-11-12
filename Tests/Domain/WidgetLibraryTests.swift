import XCTest
@testable import EmulatorDomain
final class WidgetLibraryTests: XCTestCase {
    func testDeepLinkOnlyAcceptsAnExactGameIdentifier() {
        let game = WidgetGame(id: UUID(), title: "A game")
        XCTAssertEqual(WidgetLibrary.gameID(from: game.link), game.id)
        XCTAssertEqual(WidgetLibrary.gameID(from: URL(string: "emuden://play/" + game.id.uuidString)!), game.id)
        for text in ["https://play/" + game.id.uuidString, "emuden://play/../../file", "emuden://other/" + game.id.uuidString, game.link.absoluteString + "&file=a", game.link.absoluteString + "#a", "emuden://user@play/" + game.id.uuidString, "emuden://play:80/" + game.id.uuidString, game.link.absoluteString + "&game=" + game.id.uuidString, "https://\(EmuDenLink.host).example/play/?game=" + game.id.uuidString] { XCTAssertNil(WidgetLibrary.gameID(from: URL(string: text)!)) }
        XCTAssertEqual(EmuDenLink.destination(EmuDenLink.homebrew), .homebrew)
        XCTAssertEqual(EmuDenLink.destination(URL(string: "emuden://library")!), .library)
        XCTAssertNil(EmuDenLink.destination(URL(string: "https://\(EmuDenLink.host)/play/?demo=other")!))
        XCTAssertNil(EmuDenLink.destination(URL(string: "https://\(EmuDenLink.host)/play/?game=../../outside")!))
    }
    func testUnratedSoftwareRequiresAnExplicitAdultDeclaration() {
        XCTAssertFalse(ImportedGameAccess.stored("").allowsImportedGames)
        XCTAssertFalse(ImportedGameAccess.stored("unexpected").allowsImportedGames)
        XCTAssertFalse(ImportedGameAccess.under18.allowsImportedGames)
        XCTAssertFalse(ImportedGameAccess.undecided.allowsImportedGames)
        XCTAssertTrue(ImportedGameAccess.adult.allowsImportedGames)
    }
    func testSystemAgeBandMustExcludeMinors() {
        XCTAssertTrue(ImportedGameAccess.isAdultAgeBand(lowerBound: 18, upperBound: nil))
        XCTAssertTrue(ImportedGameAccess.isAdultAgeBand(lowerBound: 21, upperBound: 30))
        XCTAssertFalse(ImportedGameAccess.isAdultAgeBand(lowerBound: nil, upperBound: nil))
        XCTAssertFalse(ImportedGameAccess.isAdultAgeBand(lowerBound: nil, upperBound: 99))
        XCTAssertFalse(ImportedGameAccess.isAdultAgeBand(lowerBound: 17, upperBound: 99))
        XCTAssertFalse(ImportedGameAccess.isAdultAgeBand(lowerBound: 21, upperBound: 17))
    }
    func testSnapshotContainsOnlyMetadataAndReadsAtomically() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = WidgetGame(id: UUID(), title: "A title")
        let snapshot = WidgetLibrary(games: [game], updated: Date(timeIntervalSince1970: 1))
        try snapshot.write(to: root)
        XCTAssertEqual(WidgetLibrary.read(from: root), snapshot)
        let data = try Data(contentsOf: root.appendingPathComponent("library.json"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["games", "updated"]))
        XCTAssertEqual(game.imageURL(in: root).deletingLastPathComponent().path, root.path)
        XCTAssertEqual(game.imageURL(in: root, scene: true).pathExtension, "jpg")
        let duplicated = WidgetLibrary(games: [game, game], updated: Date())
        XCTAssertThrowsError(try duplicated.write(to: root))
        XCTAssertEqual(WidgetLibrary.read(from: root), snapshot)
        try Data("not json".utf8).write(to: root.appendingPathComponent("library.json")); XCTAssertNil(WidgetLibrary.read(from: root))
    }
}
