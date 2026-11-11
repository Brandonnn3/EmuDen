import XCTest
@testable import EmulatorDomain

final class PlayerPreferencesTests: XCTestCase {
    func testLaunchArgumentStringsUseTheSameTypedDefaultsAsSettings() {
        let suite = "EmuDen-Arguments-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("3", forKey: "resolutionFactor"); defaults.set("NO", forKey: "asyncShaderCompilation"); defaults.set("0.6", forKey: "screenBalance")
        let preferences = PlayerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.resolution, 3); XCTAssertFalse(preferences.asyncShaders); XCTAssertEqual(preferences.screenBalance, 0.6)
    }
    func testDefaultsAndPerGameProfilesRemainIndependentAndBounded() throws {
        let suite = "EmuDen-Test-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var global = PlayerPreferences(); global.resolution = 3; global.sampling = .smooth; global.saveDefaults(defaults)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let profiles = PlayerProfileStore(root: root)
        var golf = global; golf.resolution = 2; golf.automaticQuality = true
        try profiles.write(golf, for: "golf.3ds")
        XCTAssertEqual(try profiles.read("golf.3ds"), golf)
        XCTAssertNil(try profiles.read("dark-moon.cci"))
        XCTAssertEqual(PlayerPreferences(defaults: defaults), global)
        try profiles.write(nil, for: "golf.3ds"); XCTAssertNil(try profiles.read("golf.3ds"))
        golf.resolution = 50; golf.screenBalance = .infinity
        try profiles.write(golf, for: "../../escape.3ds")
        XCTAssertEqual(try profiles.read("../../escape.3ds")?.resolution, 1)
        XCTAssertEqual(try profiles.read("../../escape.3ds")?.screenBalance, 0.5)
        XCTAssertEqual(profiles.url(for: "../../escape.3ds").deletingLastPathComponent(), profiles.directory)
    }
    func testCorruptAndLinkedProfilesAreRejectedWithoutChangingFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlayerProfileStore(root: root)
        try store.write(PlayerPreferences(), for: "a")
        try Data("broken".utf8).write(to: store.url(for: "a"))
        XCTAssertThrowsError(try store.read("a")); XCTAssertEqual(try Data(contentsOf: store.url(for: "a")), Data("broken".utf8))
        try FileManager.default.createSymbolicLink(at: store.url(for: "b"), withDestinationURL: store.url(for: "a"))
        XCTAssertThrowsError(try store.read("b"))
    }
    private func sample(speed: Double = 1, mean: Double = 8, worst: Double = 12, heat: Int = 0) -> FrameSample {
        FrameSample(fps: 60 * speed, coreFPS: 60 * speed, targetFPS: 60, meanMS: mean, worstMS: worst, thermal: heat, resolution: 3)
    }
    func testAutomaticQualityIgnoresIsolatedHitchesAndRecoversGradually() {
        var automatic = AutomaticQuality(ceiling: 3)
        for i in 0..<60 { XCTAssertNil(automatic.next(i == 20 ? sample(speed: 0.3, mean: 45, worst: 1500) : sample())) }
        XCTAssertEqual(automatic.resolution, 3)
        for _ in 0..<4 { XCTAssertNil(automatic.next(sample(speed: 0.8, mean: 20, worst: 30))) }
        XCTAssertEqual(automatic.next(sample(speed: 0.8, mean: 20, worst: 30)), 2)
        for _ in 0..<44 { XCTAssertNil(automatic.next(sample())) }
        XCTAssertEqual(automatic.next(sample()), 3)
        for _ in 0..<60 { XCTAssertNil(automatic.next(sample())) }
        XCTAssertEqual(automatic.resolution, 3)
    }
    func testAutomaticQualityHonorsHeatCooldownAndNativeFloor() {
        var automatic = AutomaticQuality(ceiling: 2)
        for _ in 0..<14 { XCTAssertNil(automatic.next(sample(heat: 2))) }
        XCTAssertEqual(automatic.next(sample(heat: 2)), 1)
        for _ in 0..<90 { XCTAssertNil(automatic.next(sample(heat: 2))) }
        XCTAssertEqual(automatic.resolution, 1)
        var native = AutomaticQuality(ceiling: 1)
        for _ in 0..<60 { XCTAssertNil(native.next(sample(speed: 0.1, mean: 200))) }
    }
    func testShaderResetOnlyRemovesExactTitlesAndLeavesSavesAndOtherFiles() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let id = "00040000000DCD00"
        let paths = ["Azahar/shaders/vulkan/transferable/\(id)_vs.vkch", "Azahar/shaders/vulkan/pipeline/\(id)-106B1234.bin", "Azahar/shaders/vulkan/pipeline/\(id)-loading.flag", "Azahar/shaders/vulkan/pipeline/\(id)-notes.bin", "Azahar/shaders/vulkan/transferable/00040000000DCD01_vs.vkch", "Azahar/nand/Mii.app", "SaveStates/quick.emustate", "Azahar/sdmc/save.bin"]
        for path in paths { let p = root.appendingPathComponent(path); try fm.createDirectory(at: p.deletingLastPathComponent(), withIntermediateDirectories: true); try Data([1, 2, 3]).write(to: p) }
        let cache = ShaderCache(saves: root)
        XCTAssertEqual(try cache.size(for: id), 9)
        try cache.reset(id.lowercased())
        for (i, path) in paths.enumerated() { XCTAssertEqual(fm.fileExists(atPath: root.appendingPathComponent(path).path), i >= 3, path) }
        XCTAssertEqual(try cache.size(for: "../../nand"), 0)
    }
    func testShaderResetRefusesSymlinkedCacheFolders() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root.appendingPathComponent("Azahar"), withIntermediateDirectories: true)
        try fm.createDirectory(at: root.appendingPathComponent("Personal"), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: root.appendingPathComponent("Azahar/shaders"), withDestinationURL: root.appendingPathComponent("Personal"))
        XCTAssertThrowsError(try ShaderCache(saves: root).reset("00040000000DCD00"))
    }
}
