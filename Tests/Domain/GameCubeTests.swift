import XCTest
@testable import EmulatorDomain

final class GameCubeTests: XCTestCase {
    private var homebrew: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/EmuDen-GC-Demo.dol")
    }
    private func storage() throws -> LibraryStorage {
        let storage = LibraryStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try storage.prepare()
        addTeardownBlock { try? FileManager.default.removeItem(at: storage.root) }
        return storage
    }
    private func put(_ value: UInt32, at offset: Int, in data: inout Data) {
        var big = value.bigEndian
        withUnsafeBytes(of: &big) { data.replaceSubrange(offset..<offset + 4, with: $0) }
    }
    private func disc() throws -> Data {
        var data = Data(repeating: 0, count: 0x30000)
        data.replaceSubrange(0..<6, with: Data("EDNEHB".utf8))
        for (offset, value): (Int, UInt32) in [(0x1c, 0xc2339f3d), (0x420, 0x5000),
            (0x424, 0x4000), (0x428, 32), (0x2450, 0x81200000), (0x2454, 32),
            (0x4000, 0x01000000), (0x4008, 1)] { put(value, at: offset, in: &data) }
        let dol = try Data(contentsOf: homebrew)
        data.replaceSubrange(0x5000..<0x5000 + dol.count, with: dol)
        return data
    }
    func testUncompressedISOAndGCMAreGatedAndRoundTrip() throws {
        let s = try storage(), data = try disc()
        for ext in ["iso", "gcm"] {
            let file = s.root.appendingPathComponent("Original.\(ext)")
            try data.write(to: file)
            XCTAssertThrowsError(try s.importGame(file))
            let game = try s.importGame(file, allowGameCube: true)
            XCTAssertEqual(game.console, .gamecube)
            XCTAssertEqual(game.fileName, "\(game.id.uuidString)/disc.\(ext)")
            XCTAssertEqual(try Data(contentsOf: s.gameURL(game)), data)
            try s.write([game]); XCTAssertEqual(try s.read(), [game])
        }
    }
    func testNKitCompoundDiscExtensionKeepsAReadableTitleAndOriginalBytes() throws {
        let s = try storage(), data = try disc()
        for name in ["Sonic_Riders.nkit.iso", "Sonic_Riders.NKIT.ISO", "Sonic_Riders.nkit.gcm"] {
            let file = s.root.appendingPathComponent(name); try data.write(to: file)
            let game = try s.importGame(file, allowGameCube: true)
            XCTAssertEqual(game.title, "Sonic Riders")
            XCTAssertEqual(try Data(contentsOf: s.gameURL(game)), data)
        }
    }
    func testWrongConsoleAndOutOfBoundsDiscBootDataAreRejected() throws {
        let s = try storage(), file = s.root.appendingPathComponent("bad.iso"), original = try disc()
        for (offset, value): (Int, UInt32) in [(0x18, 0x5d1c9ea3), (0x1c, 0),
            (0x424, 0xffffffff), (0x428, 0xffffffff),
            (0x2450, 0x80000000), (0x2450, 0x81200001), (0x2454, 0xffffffff),
            (0x2458, 0xffffffff), (0x4008, 0xffffffff)] {
            var data = original; put(value, at: offset, in: &data); try data.write(to: file)
            XCTAssertThrowsError(try s.importGame(file, allowGameCube: true), "Offset \(offset)")
        }
        try original.prefix(0x245f).write(to: file)
        XCTAssertThrowsError(try s.importGame(file, allowGameCube: true))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: s.gamesDirectory.path).isEmpty)
    }
    func testDiscSymlinkAndFailedMixedBatchKeepExistingGames() throws {
        let s = try storage(), existing = try s.importGame(homebrew, allowGameCube: true)
        let file = s.root.appendingPathComponent("Original.gcm"), link = s.root.appendingPathComponent("link.iso")
        try disc().write(to: file)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        XCTAssertThrowsError(try s.importGame(link, allowGameCube: true))
        let bad = s.root.appendingPathComponent("Wii.iso"); try Data(repeating: 0, count: 0x30000).write(to: bad)
        XCTAssertThrowsError(try s.importBatch([file, bad], allowGameCube: true))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: s.gamesDirectory.path), [existing.id.uuidString])
    }
    func testOriginalHomebrewImportsOnlyWithExplicitGateAndRoundTrips() throws {
        let s = try storage()
        XCTAssertThrowsError(try s.importBatch([homebrew]))
        let game = try XCTUnwrap(s.importBatch([homebrew], allowGameCube: true).first)
        XCTAssertEqual(game.console, .gamecube)
        XCTAssertEqual(try Data(contentsOf: s.gameURL(game)), try Data(contentsOf: homebrew))
        try s.write([game]); XCTAssertEqual(try s.read(), [game])
        XCTAssertEqual(s.gameAssetsURL(game).lastPathComponent, game.id.uuidString)
        XCTAssertEqual(s.nativeSaveDirectory(game), s.savesDirectory.appendingPathComponent("GameCube/\(game.id.uuidString)", isDirectory: true))
    }
    func testMalformedSectionsEntryAndBSSAreRejectedWithoutCopies() throws {
        let s = try storage(), original = try Data(contentsOf: homebrew)
        let file = s.root.appendingPathComponent("bad.dol")
        func put(_ value: UInt32, at offset: Int, in data: inout Data) {
            var big = value.bigEndian
            withUnsafeBytes(of: &big) { data.replaceSubrange(offset..<offset + 4, with: $0) }
        }
        for (offset, value): (Int, UInt32) in [(0x00, 0xFFFFFFF0), (0x48, 0x817FFFF0),
                                               (0x90, 0xFFFFFFFF), (0xE0, 0x80100000),
                                               (0xE0, 0x80003101), (0xD8, 0x90000000)] {
            var data = original; put(value, at: offset, in: &data); try data.write(to: file)
            XCTAssertThrowsError(try s.importGame(file, allowGameCube: true), "Header at \(offset)")
        }
        try original.prefix(255).write(to: file)
        XCTAssertThrowsError(try s.importGame(file, allowGameCube: true))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: s.gamesDirectory.path).isEmpty)
    }
    func testSymlinkAndBatchFailureRollBackOnlyNewGameFolders() throws {
        let s = try storage(), existing = try s.importGame(homebrew, allowGameCube: true)
        let link = s.root.appendingPathComponent("linked.dol")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: homebrew)
        XCTAssertThrowsError(try s.importGame(link, allowGameCube: true))
        let invalid = s.root.appendingPathComponent("bad.dol")
        try Data(repeating: 0, count: 256).write(to: invalid)
        XCTAssertThrowsError(try s.importBatch([homebrew, invalid], allowGameCube: true))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: s.gamesDirectory.path), [existing.id.uuidString])
    }
    func testSaveHistoryIsPerGamePerCoreAndUnaffectedByThreeDSResourceImports() throws {
        let s = try storage(), a = try s.importGame(homebrew, allowGameCube: true), b = try s.importGame(homebrew, allowGameCube: true)
        let state = SaveStateStore(saves: s.savesDirectory, game: s.gameURL(a), platform: .gamecube)
        XCTAssertNotEqual(state.directory, SaveStateStore(saves: s.savesDirectory, game: s.gameURL(b), platform: .gamecube).directory)
        XCTAssertNotEqual(state.directory, SaveStateStore(saves: s.savesDirectory, game: s.gameURL(a), platform: .ps1).directory)
        XCTAssertNotEqual(state.directory, SaveStateStore(saves: s.savesDirectory, game: s.gameURL(a)).directory)
        let data = Data(repeating: 7, count: 4096)
        try state.write(data, slot: .quick)
        try Data(UUID().uuidString.utf8).write(to: s.systemRevisionURL)
        let unchanged = SaveStateStore(saves: s.savesDirectory, game: s.gameURL(a), platform: .gamecube)
        XCTAssertEqual(state.directory, unchanged.directory)
        XCTAssertEqual(try unchanged.read(.quick), data)
    }
}
