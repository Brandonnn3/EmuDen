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
    func testSystemAgeBandMatchesFourPlusRating() {
        XCTAssertTrue(RegionalAgeAccess.isAllowedAgeBand(lowerBound: 4, upperBound: 12))
        XCTAssertTrue(RegionalAgeAccess.isAllowedAgeBand(lowerBound: 13, upperBound: 17))
        XCTAssertTrue(RegionalAgeAccess.isAllowedAgeBand(lowerBound: 18, upperBound: nil))
        XCTAssertFalse(RegionalAgeAccess.isAllowedAgeBand(lowerBound: nil, upperBound: nil))
        XCTAssertFalse(RegionalAgeAccess.isAllowedAgeBand(lowerBound: nil, upperBound: 99))
        XCTAssertFalse(RegionalAgeAccess.isAllowedAgeBand(lowerBound: 3, upperBound: 3))
        XCTAssertFalse(RegionalAgeAccess.isAllowedAgeBand(lowerBound: 4, upperBound: 3))
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
