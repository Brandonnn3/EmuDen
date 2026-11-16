import XCTest
@testable import EmulatorDomain

final class GameNamingTests: XCTestCase {
    func testRenamingPreservesFilesSavesArtworkAndLinksAcrossRestart() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let store = LibraryStorage(root: root); try store.prepare()
        let original = Game(id: UUID(uuidString:"C0370000-0000-4000-8000-000000000001")!, title: "Sonic Riders.nkit", fileName: "C0370000-0000-4000-8000-000000000001/disc.iso", artworkTitle: "Sonic Riders", platform: .gamecube)
        let source = store.gameURL(original); try fm.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true); try Data("original owned QA disc bytes".utf8).write(to: source)
        let saves = root.appendingPathComponent("Saves"); try fm.createDirectory(at: saves, withIntermediateDirectories: true)
        let marker = saves.appendingPathComponent("native-save"); try Data([1,2,3]).write(to: marker)
        let renamed = try original.renamed("  Sonic Riders  ")
        XCTAssertEqual(renamed.id, original.id); XCTAssertEqual(renamed.fileName, original.fileName)
        XCTAssertEqual(renamed.title, original.title); XCTAssertEqual(renamed.artworkTitle, original.artworkTitle)
        XCTAssertEqual(renamed.displayName, "Sonic Riders")
        XCTAssertEqual(EmuDenLink.game(renamed.id), EmuDenLink.game(original.id))
        XCTAssertEqual(try Data(contentsOf: source), Data("original owned QA disc bytes".utf8))
        XCTAssertEqual(try Data(contentsOf: marker), Data([1,2,3]))
        try store.write([renamed]); XCTAssertEqual(try store.read(), [renamed])
        let encoded = try JSONEncoder().encode(renamed)
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: encoded), renamed)
        XCTAssertFalse(Game.isValidDisplayName(" \n ")); XCTAssertFalse(Game.isValidDisplayName("a\nb"))
        XCTAssertFalse(Game.isValidDisplayName(String(repeating: "x", count: 161)))
        XCTAssertTrue(Game.isValidDisplayName("ソニック 🏁")); XCTAssertThrowsError(try original.renamed(""))
    }
    func testOlderGameMetadataAndCustomAlphabeticalOrder() throws {
        let old = Game(title: "Zulu", fileName: "a.3dsx")
        var data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String:Any]
        data.removeValue(forKey: "customTitle")
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: JSONSerialization.data(withJSONObject: data)).displayName, "Zulu")
        let renamed = try old.renamed("Alpha")
        let middle = Game(title: "Middle", fileName: "b.3dsx")
        XCTAssertEqual(LibraryOrder.alphabetical.sorted([middle, renamed]).map(\.id), [renamed.id,middle.id])
    }
    func testCompoundNKitImportNameDoesNotChangeDiscOrCanonicalMatching() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let store = LibraryStorage(root: root.appendingPathComponent("library")); try store.prepare()
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/EmuDen-GC-Demo.dol")
        // Import validation stays covered by the generated-disc tests; titles must stay independent of file paths.
        let source = root.appendingPathComponent("Sonic_Riders.NKIT.dol"); try fm.copyItem(at: fixture, to: source)
        let game = try store.importGame(source, allowGameCube: true)
        XCTAssertEqual(game.title, "Sonic Riders.NKIT", "Only compound disc formats strip the NKit suffix")
        XCTAssertEqual(try Data(contentsOf: store.gameURL(game)), try Data(contentsOf: fixture))
    }
}
