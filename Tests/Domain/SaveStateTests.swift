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
    func testHistoryKeepsTenManualAndThreeAutomaticPointsIndependently() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let game = URL(fileURLWithPath: "/Games/one.cci")
        let store = SaveStateStore(saves: root, game: game)
        let native = root.appendingPathComponent("Azahar/sdmc/native-save.bin")
        try FileManager.default.createDirectory(at: native.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([9, 8, 7]).write(to: native)
        for slot in SaveStateStore.Slot.allCases {
            for index in 1...(slot == .quick ? 14 : 7) {
                try store.write(Data(repeating: UInt8(index), count: 512), slot: slot, preview: Data([UInt8(index)]))
                try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_800_000_000 + Double(index))], ofItemAtPath: store.url(slot).path)
            }
        }
        let relaunched = SaveStateStore(saves: root, game: game)
        for slot in SaveStateStore.Slot.allCases {
            let entries = relaunched.entries.filter { $0.slot == slot }
            XCTAssertEqual(entries.count, slot == .quick ? 10 : 3)
            XCTAssertEqual(try entries.map { try relaunched.read($0).first! }, slot == .quick ? Array((5...14).reversed()).map(UInt8.init) : [7, 6, 5])
            for entry in entries { XCTAssertEqual(relaunched.previewData(entry)?.first, try relaunched.read(entry).first) }
        }
        XCTAssertEqual(try Data(contentsOf: native), Data([9, 8, 7]))
    }
    func testExistingSingleSlotBecomesHistoryWithoutLosingIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SaveStateStore(saves: root, game: URL(fileURLWithPath: "/one.cci"))
        try store.write(Data(repeating: 1, count: 512), slot: .quick)
        try FileManager.default.removeItem(at: store.directory.appendingPathComponent("History"))
        try store.write(Data(repeating: 2, count: 512), slot: .quick)
        XCTAssertEqual(store.entries.count, 2)
        let older = try XCTUnwrap(store.entries.first { $0.url != store.url(.quick) })
        XCTAssertEqual(try store.read(older), Data(repeating: 1, count: 512))
        XCTAssertEqual(try store.read(.quick), Data(repeating: 2, count: 512))
        XCTAssertThrowsError(try store.write(Data(), slot: .quick))
        XCTAssertEqual(store.entries.count, 2)
    }
    func testAReplacedLatestPointCannotSilentlyLoadADifferentSnapshot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SaveStateStore(saves: root, game: URL(fileURLWithPath: "/one.cci"))
        try store.write(Data(repeating: 1, count: 512), slot: .resume)
        let selected = try XCTUnwrap(store.entries.first)
        try store.write(Data(repeating: 2, count: 1024), slot: .resume)
        XCTAssertThrowsError(try store.read(selected))
        let archived = try XCTUnwrap(store.entries.first { $0.url != store.url(.resume) })
        XCTAssertEqual(try store.read(archived), Data(repeating: 1, count: 512))
        XCTAssertEqual(try store.read(.resume), Data(repeating: 2, count: 1024))
    }
    func testForeignEntriesAndLinkedDirectoriesCannotReadOrOverwriteOutsideSaves() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let saves = root.appendingPathComponent("Saves"), outside = root.appendingPathComponent("Outside")
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let store = SaveStateStore(saves: saves, game: URL(fileURLWithPath: "/one.cci"))
        let foreign = SaveStateStore.Entry(url: outside.appendingPathComponent("quick.emustate"), slot: .quick, date: .now, bytes: 512)
        XCTAssertThrowsError(try store.read(foreign))
        try FileManager.default.createSymbolicLink(at: saves.appendingPathComponent("SaveStates"), withDestinationURL: outside)
        XCTAssertThrowsError(try store.write(Data(repeating: 1, count: 512), slot: .quick))
        XCTAssertEqual(store.entries.count, 0)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: outside.path), [])
    }
    func testCorruptHistoryIsRejectedAndOversizedPreviewIsIgnored() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SaveStateStore(saves: root, game: URL(fileURLWithPath: "/one.cci"))
        try store.write(Data(repeating: 1, count: 512), slot: .quick, preview: Data(repeating: 1, count: 512 * 1024 + 1))
        XCTAssertNil(store.previewData(try XCTUnwrap(store.entries.first)))
        try store.write(Data(repeating: 2, count: 512), slot: .quick)
        let older = try XCTUnwrap(store.entries.first { $0.url != store.url(.quick) })
        var damaged = try Data(contentsOf: older.url); damaged[100] ^= 1
        try damaged.write(to: older.url, options: .atomic)
        XCTAssertThrowsError(try store.read(older))
        XCTAssertEqual(try store.read(.quick), Data(repeating: 2, count: 512))
    }
    func testAutosaveClockCountsOnlyActivePlayAndResetsAfterSave() {
        XCTAssertEqual(StateAutosaveClock().interval, 300)
        var clock = StateAutosaveClock(interval: 3)
        XCTAssertFalse(clock.due(now: 0, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 1, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 2, active: false, enabled: true))
        XCTAssertFalse(clock.due(now: 100, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 101, active: true, enabled: true))
        XCTAssertTrue(clock.due(now: 102, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 103, active: true, enabled: true))
        clock.saved()
        XCTAssertFalse(clock.due(now: 104, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 105, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 106, active: true, enabled: false))
        XCTAssertFalse(clock.due(now: 200, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 201, active: true, enabled: true))
        XCTAssertTrue(clock.due(now: 202, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 1, active: true, enabled: true))
        XCTAssertFalse(clock.due(now: 2, active: true, enabled: true))
    }
}
