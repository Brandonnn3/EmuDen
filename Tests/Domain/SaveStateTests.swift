import XCTest
@testable import EmulatorDomain

final class SaveStateTests: XCTestCase {
    func testSlotsAreAtomicSeparateAndStableAcrossLaunches() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = URL(fileURLWithPath: "/old-container/Games/one.cci")
        let store = SaveStateStore(saves: root, game: game)
        let state = Data(repeating: 42, count: 512)
        try store.write(state, slot: .quick)
        try store.write(Data(repeating: 17, count: 256), slot: .resume)
        XCTAssertThrowsError(try store.write(Data(), slot: .quick))
        XCTAssertEqual(try store.read(.quick), state)
        XCTAssertNotEqual(try store.read(.resume), state)
        XCTAssertEqual(store.directory, SaveStateStore(saves: root, game: URL(fileURLWithPath: "/new-container/Games/one.cci")).directory)
        XCTAssertNotEqual(store.directory, SaveStateStore(saves: root, game: URL(fileURLWithPath: "/Games/two.cci")).directory)
        XCTAssertNotNil(store.date(.quick))
        XCTAssertFalse(store.hasOlderSnapshots)
    }
    func testDamagedAndTruncatedFilesAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SaveStateStore(saves: root, game: URL(fileURLWithPath: "/game.cci"))
        try store.write(Data(repeating: 1, count: 512), slot: .quick)
        var data = try Data(contentsOf: store.url(.quick)); data[100] ^= 1
        try data.write(to: store.url(.quick))
        XCTAssertThrowsError(try store.read(.quick))
        try Data().write(to: store.url(.quick))
        XCTAssertThrowsError(try store.read(.quick))
    }
    func testNewSystemResourcesKeepOldSnapshotsButDoNotOfferThem() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = URL(fileURLWithPath: "/Games/golf.3ds")
        let before = SaveStateStore(saves: root, game: game)
        let data = Data(repeating: 7, count: 512)
        try before.write(data, slot: .resume)
        try Data(UUID().uuidString.utf8).write(to: root.appendingPathComponent(".system-resource-revision"))
        let after = SaveStateStore(saves: root, game: game)
        XCTAssertNotEqual(before.directory, after.directory)
        XCTAssertNil(after.date(.resume))
        XCTAssertTrue(after.hasOlderSnapshots)
        XCTAssertEqual(try before.read(.resume), data)
        XCTAssertTrue(after.directory.path.contains(SaveStateStore.coreGeneration))
    }
}
