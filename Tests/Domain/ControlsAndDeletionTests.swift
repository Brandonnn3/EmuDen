import XCTest
@testable import EmulatorDomain

final class ControlsAndDeletionTests: XCTestCase {
    func testControlLayoutSurvivesRestartAndKeepsConsoleAndPoseSeparate() throws {
        var layouts = ControlLayouts()
        layouts.layouts["gamecube.tabletop"] = ["stick": ControlPosition(x: 0.2, y: 0.7), "0": ControlPosition(x: 0.82, y: 0.45)]
        layouts.layouts["ps1.portrait"] = ["rightStick": ControlPosition(x: 0.75, y: 0.9)]
        let restored = ControlLayouts.decode(layouts.encoded())
        XCTAssertEqual(restored, layouts)
        XCTAssertNil(restored.layouts["3ds.tabletop"])
        XCTAssertNil(restored.layouts["gamecube.landscape"])
        let frame = restored.layouts["gamecube.tabletop"]!["stick"]!.point(in: CGSize(width: 600, height: 400), control: CGSize(width: 84, height: 84))
        XCTAssertEqual(frame.x, 120); XCTAssertEqual(frame.y, 280)
        let rotated = restored.layouts["gamecube.tabletop"]!["0"]!.point(in: CGSize(width: 300, height: 200), control: CGSize(width: 66, height: 66))
        XCTAssertEqual(rotated.x, 246, accuracy: 0.001); XCTAssertEqual(rotated.y, 90, accuracy: 0.001)
    }
    func testControlPositionsClampWholeHitTargetsAndRejectMalformedStorage() {
        let size = CGSize(width: 300, height: 240), control = CGSize(width: 84, height: 84)
        for point in [CGPoint(x: -1000, y: 2000), CGPoint(x: Double.nan, y: Double.infinity)] {
            let saved = ControlPosition.clamped(point, in: size, control: control)
            let center = saved.point(in: size, control: control)
            XCTAssertGreaterThanOrEqual(center.x, 42); XCTAssertLessThanOrEqual(center.x, 258)
            XCTAssertGreaterThanOrEqual(center.y, 42); XCTAssertLessThanOrEqual(center.y, 198)
        }
        for text in ["broken", "{\"layouts\":{\"gc.hack\":{}}}", "{\"layouts\":{\"ps1.portrait\":{\"0\":{\"x\":-1,\"y\":0.5}}}}", "{\"layouts\":{\"3ds.portrait\":{\"unknown\":{\"x\":0.1,\"y\":0.5}}}}"] {
            XCTAssertTrue(ControlLayouts.decode(Data(text.utf8)).layouts.isEmpty)
        }
        XCTAssertTrue(ControlLayouts.decode(Data(repeating: 32, count: 65_537)).layouts.isEmpty)
        XCTAssertFalse(PlayerPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!).ps1Analog)
        let old = try? JSONDecoder().decode(PlayerPreferences.self, from: Data("{\"resolution\":2}".utf8))
        XCTAssertEqual(old?.ps1Analog, false)
        var analog = PlayerPreferences(); analog.ps1Analog = true
        XCTAssertEqual(try? JSONDecoder().decode(PlayerPreferences.self, from: JSONEncoder().encode(analog)).ps1Analog, true)
    }
    private func storage() throws -> LibraryStorage {
        let s = LibraryStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try s.prepare(); addTeardownBlock { try? FileManager.default.removeItem(at: s.root) }; return s
    }
    func testDeleteOnlyImportedGameAndCompanionsPreservesSourceSavesAndOtherGames() throws {
        let s = try storage(), fm = FileManager.default
        let source = s.root.appendingPathComponent("original.3dsx"), bytes = Data("3DSXoriginal homebrew".utf8)
        try bytes.write(to: source)
        let first = try s.importGame(source)
        let psID = UUID(), folder = s.gamesDirectory.appendingPathComponent(psID.uuidString)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("CUE".utf8).write(to: folder.appendingPathComponent("disc.cue"))
        try Data("BIN".utf8).write(to: folder.appendingPathComponent("track01.bin"))
        let second = Game(id: psID, title: "Original PS1 fixture", fileName: psID.uuidString + "/disc.cue", platform: .ps1)
        let save = s.nativeSaveDirectory(second).appendingPathComponent("card.mcd")
        try fm.createDirectory(at: save.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("save marker".utf8).write(to: save)
        let shared3DS = s.systemDirectory.appendingPathComponent("keep.dat")
        try Data("3DS save".utf8).write(to: shared3DS)
        try s.write([first, second])
        XCTAssertEqual(try s.deleteGame(id: second.id), [first])
        XCTAssertFalse(fm.fileExists(atPath: folder.path))
        XCTAssertEqual(try Data(contentsOf: save), Data("save marker".utf8))
        XCTAssertEqual(try Data(contentsOf: s.gameURL(first)), bytes)
        XCTAssertEqual(try s.deleteGame(id: first.id), [])
        XCTAssertFalse(fm.fileExists(atPath: s.gameURL(first).path))
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        XCTAssertEqual(try Data(contentsOf: shared3DS), Data("3DS save".utf8))
        XCTAssertEqual(try s.deleteGame(id: UUID()), [])
    }
    func testUnsafeOrCorruptDeleteCannotTouchExternalFiles() throws {
        let s = try storage(), fm = FileManager.default
        let source = s.root.appendingPathComponent("original.3dsx")
        try Data("3DSXsafe".utf8).write(to: source)
        let game = try s.importGame(source); try s.write([game])
        try fm.removeItem(at: s.gameURL(game))
        try fm.createSymbolicLink(at: s.gameURL(game), withDestinationURL: source)
        XCTAssertThrowsError(try s.deleteGame(id: game.id))
        XCTAssertEqual(try s.read(), [game])
        XCTAssertEqual(try Data(contentsOf: source), Data("3DSXsafe".utf8))
        let catalog = s.root.appendingPathComponent("library.json")
        try Data("broken catalog".utf8).write(to: catalog)
        XCTAssertThrowsError(try s.deleteGame(id: game.id))
        XCTAssertEqual(try Data(contentsOf: catalog), Data("broken catalog".utf8))
    }
    func testFailedCatalogWriteRestoresStagedImportedCopy() throws {
        let s = try storage(), fm = FileManager.default
        let source = s.root.appendingPathComponent("rollback.3dsx")
        try Data("3DSXrollback".utf8).write(to: source)
        let game = try s.importGame(source); try s.write([game])
        let original = try Data(contentsOf: s.gameURL(game))
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: s.root.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: s.root.path) }
        XCTAssertThrowsError(try s.deleteGame(id: game.id))
        XCTAssertEqual(try s.read(), [game])
        XCTAssertEqual(try Data(contentsOf: s.gameURL(game)), original)
        XCTAssertFalse(try fm.contentsOfDirectory(atPath: s.gamesDirectory.path).contains { $0.hasPrefix(".delete-") })
    }
    func testDeleteDoesNotRemoveAnAssetStillUsedByAnotherEntry() throws {
        let s = try storage(), source = s.root.appendingPathComponent("shared.3dsx")
        try Data("3DSXsafe".utf8).write(to: source)
        let a = try s.importGame(source)
        let b = Game(title: "Second entry", fileName: a.fileName)
        try s.write([a,b]); XCTAssertEqual(try s.deleteGame(id: a.id), [b])
        XCTAssertTrue(FileManager.default.fileExists(atPath: s.gameURL(b).path))
    }
}
