import XCTest
@testable import EmulatorDomain

final class LibraryTests: XCTestCase {
    func fixture() throws -> LibraryStorage {
        let storage = LibraryStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try storage.prepare()
        addTeardownBlock { try? FileManager.default.removeItem(at: storage.root) }
        return storage
    }
    func testGameImportCopiesAndPersistsWithoutChangingSource() throws {
        let storage = try fixture()
        let source = storage.root.appendingPathComponent("A_Test.3dsx")
        let data = Data("3DSXtest-homebrew".utf8); try data.write(to: source)
        let game = try storage.importGame(source)
        XCTAssertEqual(game.title, "A Test")
        XCTAssertEqual(try Data(contentsOf: storage.gameURL(game)), data)
        XCTAssertEqual(try Data(contentsOf: source), data)
        try storage.write([game]); XCTAssertEqual(try storage.read(), [game])
    }
    func testInvalidAndUnsupportedGamesAreRejected() throws {
        let storage = try fixture()
        for name in ["bad.3ds", "archive.zip", "installer.cia"] {
            let url = storage.root.appendingPathComponent(name)
            try Data("garbage".utf8).write(to: url)
            XCTAssertThrowsError(try storage.importGame(url))
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.gamesDirectory.path), [])
    }
    func testCorruptCatalogIsPreservedAndReported() throws {
        let storage = try fixture(), data = Data("broken".utf8)
        let url = storage.root.appendingPathComponent("library.json")
        try data.write(to: url)
        XCTAssertThrowsError(try storage.read())
        XCTAssertEqual(try Data(contentsOf: url), data)
    }
    func testMiiRequiresAnArchiveHeaderAtTheExpectedTitle() throws {
        let storage = try fixture()
        let folder = storage.systemDirectory.appendingPathComponent("nand/00000000000000000000000000000000/title/0004009b/00010202/content")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let archive = folder.appendingPathComponent("00000000.app")
        try Data("not an archive".utf8).write(to: archive)
        XCTAssertFalse(storage.inspectMii().archiveFound)
        try miiFixture().write(to: archive)
        XCTAssertTrue(storage.inspectMii().archiveFound)
        XCTAssertFalse(storage.inspectMii().databaseFound)
        try Data([0]).write(to: storage.systemDirectory.appendingPathComponent("nand/CFL_DB.dat"))
        XCTAssertTrue(storage.inspectMii().databaseFound)
    }
    func testSystemImportMergesAndPreservesSDCardSaves() throws {
        let storage = try fixture(), fm = FileManager.default
        let source = storage.root.appendingPathComponent("dump")
        try fm.createDirectory(at: source.appendingPathComponent("nand"), withIntermediateDirectories: true)
        try Data("new".utf8).write(to: source.appendingPathComponent("nand/new.app"))
        try fm.createDirectory(at: storage.systemDirectory.appendingPathComponent("nand"), withIntermediateDirectories: true)
        try Data("old".utf8).write(to: storage.systemDirectory.appendingPathComponent("nand/existing.app"))
        try fm.createDirectory(at: storage.systemDirectory.appendingPathComponent("sdmc"), withIntermediateDirectories: true)
        let save = storage.systemDirectory.appendingPathComponent("sdmc/save.dat")
        try Data("save".utf8).write(to: save)
        try storage.importSystemData(source)
        XCTAssertEqual(try Data(contentsOf: save), Data("save".utf8))
        XCTAssertTrue(fm.fileExists(atPath: storage.systemDirectory.appendingPathComponent("nand/existing.app").path))
        XCTAssertTrue(fm.fileExists(atPath: storage.systemDirectory.appendingPathComponent("nand/new.app").path))
    }
    func testUnsafeSystemImportLeavesActiveDataIntact() throws {
        let storage = try fixture(), fm = FileManager.default
        let source = storage.root.appendingPathComponent("dump/nand")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: source.appendingPathComponent("escape"), withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))
        try fm.createDirectory(at: storage.systemDirectory.appendingPathComponent("nand"), withIntermediateDirectories: true)
        let old = storage.systemDirectory.appendingPathComponent("nand/existing.app")
        try Data("keep".utf8).write(to: old)
        XCTAssertThrowsError(try storage.importSystemData(source))
        XCTAssertEqual(try Data(contentsOf: old), Data("keep".utf8))
    }
    func testExistingSymlinksAreRejectedBeforeMerging() throws {
        let storage = try fixture(), fm = FileManager.default
        let source = storage.root.appendingPathComponent("dump/nand")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try Data([1]).write(to: source.appendingPathComponent("new.app"))
        let existing = storage.systemDirectory.appendingPathComponent("nand")
        try fm.createDirectory(at: existing, withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: existing.appendingPathComponent("escape"), withDestinationURL: URL(fileURLWithPath: "/etc/hosts"))
        XCTAssertThrowsError(try storage.importSystemData(source))
        XCTAssertFalse(fm.fileExists(atPath: existing.appendingPathComponent("new.app").path))
    }
    func testUnrecognizedSystemFolderIsRejected() throws {
        let storage = try fixture()
        XCTAssertThrowsError(try storage.importSystemData(storage.gamesDirectory))
    }
    func testDirectMiiArchiveValidatesTitleEncryptionAndLengthBeforeReplacing() throws {
        let storage = try fixture()
        let source = storage.root.appendingPathComponent("mii.app")
        var data = miiFixture()
        try data.write(to: source); try storage.importMiiArchive(source)
        XCTAssertTrue(storage.inspectMii().archiveFound)
        let destination = storage.systemDirectory.appendingPathComponent("nand/00000000000000000000000000000000/title/0004009b/00010202/content/00000000.app")
        let original = try Data(contentsOf: destination)
        data[0x118] = 3; try data.write(to: source)
        XCTAssertThrowsError(try storage.importMiiArchive(source))
        data[0x118] = 2; data[0x18f] = 0; try data.write(to: source)
        XCTAssertThrowsError(try storage.importMiiArchive(source))
        data[0x18f] = 4; data[0x1b4] = 5; try data.write(to: source)
        XCTAssertThrowsError(try storage.importMiiArchive(source))
        XCTAssertEqual(try Data(contentsOf: destination), original)
        try original.write(to: source); try storage.importMiiArchive(source)
        XCTAssertEqual(try Data(contentsOf: destination), original)
    }
    private func miiFixture() -> Data {
        var data = Data(repeating: 0, count: 1024)
        data.replaceSubrange(0x100..<0x104, with: Data("NCCH".utf8))
        data.replaceSubrange(0x118..<0x120, with: [0x02, 0x02, 0x01, 0x00, 0x9b, 0x00, 0x04, 0x00])
        data[0x104] = 2; data[0x18f] = 4; data[0x1b0] = 1; data[0x1b4] = 1
        return data
    }
    func testInstallerImportsOnlyCompleteUniqueMiiResources() throws {
        let storage = try fixture(), source = storage.root.appendingPathComponent("resource-installer.3dsx")
        let mii = miiFixture()
        var installer = Data("3DSX".utf8); installer.append(Data(repeating: 0, count: 72)); installer.append(mii)
        try installer.write(to: source); try storage.importMiiArchive(source)
        XCTAssertTrue(storage.inspectMii().archiveFound)
        let destination = storage.systemDirectory.appendingPathComponent("nand/00000000000000000000000000000000/title/0004009b/00010202/content/00000000.app")
        XCTAssertEqual(try Data(contentsOf: destination), mii)
        let revision = try Data(contentsOf: storage.systemRevisionURL)
        try installer.dropLast().write(to: source)
        XCTAssertThrowsError(try storage.importMiiArchive(source))
        installer.append(mii); try installer.write(to: source)
        XCTAssertThrowsError(try storage.importMiiArchive(source))
        XCTAssertEqual(try Data(contentsOf: destination), mii)
        XCTAssertEqual(try Data(contentsOf: storage.systemRevisionURL), revision)
    }
    func testCoreUpgradeBacksUpNativeSavesOnceWithoutChangingActiveData() throws {
        let storage = try fixture(), fm = FileManager.default
        let nativeSave = storage.systemDirectory.appendingPathComponent("sdmc/progress.dat")
        try fm.createDirectory(at: nativeSave.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("progress before upgrade".utf8).write(to: nativeSave)
        try storage.prepareCoreUpgrade()
        let backup = storage.savesDirectory.appendingPathComponent("Backups/Before-FastInterp/sdmc/progress.dat")
        XCTAssertEqual(try Data(contentsOf: backup), try Data(contentsOf: nativeSave))
        try Data("new progress".utf8).write(to: nativeSave)
        try storage.prepareCoreUpgrade()
        XCTAssertEqual(try Data(contentsOf: backup), Data("progress before upgrade".utf8))
        XCTAssertEqual(try Data(contentsOf: nativeSave), Data("new progress".utf8))
    }
    func testActualLocalMiiInstallerExtractsThePreviouslyVerifiedArchive() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let installer = root.appendingPathComponent("build/Downloads/MiiTest/errfix.3dsx")
        let expected = root.appendingPathComponent("build/MiiTest/downloaded-mii.app")
        guard FileManager.default.fileExists(atPath: installer.path), FileManager.default.fileExists(atPath: expected.path) else { throw XCTSkip("Local user-requested resource test files are not distributed") }
        let storage = try fixture()
        try storage.importMiiArchive(installer)
        let imported = storage.systemDirectory.appendingPathComponent("nand/00000000000000000000000000000000/title/0004009b/00010202/content/00000000.app")
        XCTAssertEqual(try Data(contentsOf: imported), try Data(contentsOf: expected))
        XCTAssertTrue(storage.inspectMii().archiveFound)
    }
}
