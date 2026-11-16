import XCTest
@testable import EmulatorDomain

final class PlayStationTests: XCTestCase {
    private func storage() throws -> LibraryStorage {
        let s = LibraryStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try s.prepare()
        addTeardownBlock { try? FileManager.default.removeItem(at: s.root) }
        return s
    }
    private var homebrew: URL { URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/EmuDen-PS1-Demo.exe") }
    private func cue(in storage: LibraryStorage, text: String = "FILE \"Track 01.bin\" BINARY\n TRACK 01 MODE2/2352\n INDEX 01 00:00:00\n") throws -> URL {
        let folder = storage.root.appendingPathComponent("Disc", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(text.utf8).write(to: folder.appendingPathComponent("My Game.cue"))
        try Data(repeating: 0x51, count: 2352 * 20).write(to: folder.appendingPathComponent("Track 01.bin"))
        return folder
    }
    func testLegacyCatalogKeepsThreeDSSavesAndPlatform() throws {
        let s = try storage(), game = Game(title: "Existing", fileName: "old.3ds")
        try s.write([game])
        let decoded = try s.read()[0]
        XCTAssertNil(decoded.platform); XCTAssertEqual(decoded.console, .threeDS)
        XCTAssertEqual(s.nativeSaveDirectory(decoded), s.systemDirectory)
    }
    func testOriginalExecutableImportsAndRoundTripsAsPS1() throws {
        let s = try storage(), games = try s.importBatch([homebrew])
        XCTAssertEqual(games.count, 1); XCTAssertEqual(games[0].console, .ps1)
        XCTAssertNil(games[0].programID); XCTAssertEqual(games[0].system, "PlayStation")
        XCTAssertEqual(try Data(contentsOf: homebrew), try Data(contentsOf: s.gameURL(games[0])))
        try s.write(games); XCTAssertEqual(try s.read(), games)
        XCTAssertNotEqual(s.nativeSaveDirectory(games[0]), s.systemDirectory)
    }
    func testCueFolderCopiesEveryTrackAndPreservesReferences() throws {
        let s = try storage(), folder = try cue(in: s)
        let games = try s.importBatch([folder]); XCTAssertEqual(games.count, 1)
        let game = games[0], target = s.gameAssetsURL(game)
        XCTAssertEqual(try PlayStationCue(url: s.gameURL(game)).files, ["Track 01.bin"])
        XCTAssertEqual(try Data(contentsOf: target.appendingPathComponent("Track 01.bin")), try Data(contentsOf: folder.appendingPathComponent("Track 01.bin")))
    }
    func testCueMultipleSelectionDoesNotImportTracksAsSeparateGames() throws {
        let s = try storage(), folder = try cue(in: s)
        let games = try s.importBatch([folder.appendingPathComponent("Track 01.bin"), folder.appendingPathComponent("My Game.cue")])
        XCTAssertEqual(games.count, 1)
        XCTAssertThrowsError(try s.importBatch([folder.appendingPathComponent("My Game.cue")]))
    }
    func testCueTraversalAndSymlinkTracksAreRejected() throws {
        let s = try storage(), folder = try cue(in: s, text: "FILE \"../escape.bin\" BINARY\n")
        XCTAssertThrowsError(try s.importBatch([folder]))
        try Data("FILE \"Track 01.bin\" BINARY\n".utf8).write(to: folder.appendingPathComponent("My Game.cue"))
        let track = folder.appendingPathComponent("Track 01.bin")
        try FileManager.default.removeItem(at: track)
        try FileManager.default.createSymbolicLink(at: track, withDestinationURL: homebrew)
        XCTAssertThrowsError(try s.importBatch([folder]))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: s.gamesDirectory.path).isEmpty)
    }
    func testBadPSXHeaderAndUnsupportedBatchRollBack() throws {
        let s = try storage(), invalid = s.root.appendingPathComponent("bad.exe")
        var data = try Data(contentsOf: homebrew); data[0x13] = 0
        try data.write(to: invalid); XCTAssertThrowsError(try s.importGame(invalid))
        let unsupported = s.root.appendingPathComponent("unknown.bin")
        try Data("not a disc".utf8).write(to: unsupported)
        XCTAssertThrowsError(try s.importBatch([homebrew, unsupported]))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: s.gamesDirectory.path).isEmpty)
    }
    func testCHDVersionFiveIsRecognizedAndOtherVersionsRejected() throws {
        let s = try storage(), file = s.root.appendingPathComponent("Disc.chd")
        var header = Data(repeating: 0, count: 124); header.replaceSubrange(0..<8, with: Data("MComprHD".utf8)); header[15] = 5
        try header.write(to: file)
        XCTAssertEqual(try s.importGame(file).console, .ps1)
        header[15] = 4; try header.write(to: file); XCTAssertThrowsError(try s.importGame(file))
    }
    func testSaveHistoryIsSeparatePerDiscCoreAndBIOSRevision() throws {
        let s = try storage(), first = try s.importGame(homebrew), second = try s.importGame(homebrew)
        let a = SaveStateStore(saves: s.savesDirectory, game: s.gameURL(first), platform: .ps1)
        let b = SaveStateStore(saves: s.savesDirectory, game: s.gameURL(second), platform: .ps1)
        let threeDS = SaveStateStore(saves: s.savesDirectory, game: s.gameURL(first))
        XCTAssertNotEqual(a.directory, b.directory); XCTAssertNotEqual(a.directory, threeDS.directory)
        try a.write(Data(repeating: 42, count: 4096), slot: .quick)
        XCTAssertNil(b.date(.quick))
        let ps1 = s.savesDirectory.appendingPathComponent("PlayStation")
        try FileManager.default.createDirectory(at: ps1, withIntermediateDirectories: true)
        try Data(UUID().uuidString.utf8).write(to: ps1.appendingPathComponent(".bios-revision"))
        let updated = SaveStateStore(saves: s.savesDirectory, game: s.gameURL(first), platform: .ps1)
        XCTAssertNotEqual(a.directory, updated.directory); XCTAssertTrue(updated.hasOlderSnapshots)
        XCTAssertEqual(try a.read(.quick), Data(repeating: 42, count: 4096))
        XCTAssertEqual(threeDS.directory, SaveStateStore(saves: s.savesDirectory, game: s.gameURL(first)).directory)
    }
    func testInvalidBIOSDoesNotInstallOrInvalidateStates() throws {
        let s = try storage(), file = s.root.appendingPathComponent("scph5501.bin")
        try Data(repeating: 0, count: 524288).write(to: file)
        XCTAssertThrowsError(try s.importPS1BIOS(file))
        XCTAssertTrue(s.ps1BIOSNames.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: s.ps1BIOSDirectory.path))
    }
    func testCatalogCannotRoutePS1GameOutsideItsImportFolder() throws {
        let s = try storage()
        let game = Game(title: "Bad path", fileName: "../outside.cue", platform: .ps1)
        try s.write([game]); XCTAssertThrowsError(try s.read())
        XCTAssertTrue(FileManager.default.fileExists(atPath: s.root.appendingPathComponent("library.json").path))
    }
}
