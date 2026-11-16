import XCTest
@testable import EmulatorDomain

final class PlayerPreferencesTests: XCTestCase {
    func testOlderProfilesMigrateWithoutLosingThreeDSChoices() throws {
        let data = Data(#"{"resolution":3,"asyncShaders":false,"prepareShaders":true,"sampling":"Linear","sizing":"original","screenBalance":0.6,"automaticQuality":true}"#.utf8)
        let p = try JSONDecoder().decode(PlayerPreferences.self, from: data)
        XCTAssertEqual(p.resolution, 3); XCTAssertFalse(p.asyncShaders); XCTAssertTrue(p.prepareShaders)
        XCTAssertEqual(p.sampling, .smooth); XCTAssertEqual(p.sizing, .original)
        XCTAssertEqual(p.screenBalance, 0.6); XCTAssertTrue(p.automaticQuality)
        XCTAssertEqual(p.ps1Resolution, 1); XCTAssertTrue(p.ps1Folded)
        XCTAssertTrue(p.motionControls)
        XCTAssertTrue(p.ps1PanelSpeed && p.ps1PanelFPS && p.ps1PanelSaves && p.ps1PanelTouch)
        XCTAssertTrue(p.ps1Dithering && p.ps1TextureFix); XCTAssertFalse(p.ps1Smooth)
        XCTAssertEqual(p.gameCubeResolution, 1); XCTAssertEqual(p.gameCubeSampling, .game); XCTAssertEqual(p.gameCubeAnisotropy, 0)
    }
    func testConsoleGraphicsRoundTripAndBoundsPreserveOtherConsoles() throws {
        let suite = "EmuDen-Graphics-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var p = PlayerPreferences()
        p.resolution = 3; p.ps1Resolution = 2; p.ps1Dithering = false; p.ps1Smooth = true; p.ps1TextureFix = false
        p.gameCubeResolution = 4; p.gameCubeSampling = .smooth; p.gameCubeAnisotropy = 16
        p.saveDefaults(defaults)
        XCTAssertEqual(PlayerPreferences(defaults: defaults), p)
        XCTAssertEqual(try JSONDecoder().decode(PlayerPreferences.self, from: JSONEncoder().encode(p)), p)
        p.gameCubeResolution = 99; p.gameCubeAnisotropy = 3
        XCTAssertEqual(p.normalized.gameCubeResolution, 1); XCTAssertEqual(p.normalized.gameCubeAnisotropy, 0)
        XCTAssertEqual(p.normalized.resolution, 3); XCTAssertEqual(p.normalized.ps1Resolution, 2)
        for anisotropy in [0, 1, 2, 4, 8, 16] {
            p.gameCubeAnisotropy = anisotropy; XCTAssertEqual(p.normalized.gameCubeAnisotropy, anisotropy)
        }
    }
    func testPolishPreferencesMigrateAndPersistIndependently() throws {
        let old = try JSONDecoder().decode(PlayerPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(old.presentation, .automatic); XCTAssertFalse(old.ps1AutomaticQuality)
        XCTAssertTrue(old.gameCubeFolded && old.gameCubePanelFPS && old.gameCubePanelSaves && old.gameCubePanelTouch)
        XCTAssertFalse(old.gameCubePanelBlank)
        let suite = "EmuDen-Polish-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var p = old; p.presentation = .reduced; p.ps1AutomaticQuality = true
        p.gameCubePanelBlank = true; p.gameCubePanelFPS = false; p.gameCubePanelTouch = false; p.gameCubeFolded = false
        p.saveDefaults(defaults)
        XCTAssertEqual(PlayerPreferences(defaults: defaults), p)
        XCTAssertEqual(try JSONDecoder().decode(PlayerPreferences.self, from: JSONEncoder().encode(p)), p)
        XCTAssertTrue(p.ps1Folded && p.ps1PanelFPS && p.ps1PanelTouch)
        XCTAssertEqual(PlayerPreferences.Presentation.automatic.limit(thermal: 1), 0)
        XCTAssertEqual(PlayerPreferences.Presentation.automatic.limit(thermal: 2), 30)
        XCTAssertEqual(PlayerPreferences.Presentation.full.limit(thermal: 3), 0)
        XCTAssertEqual(PlayerPreferences.Presentation.reduced.limit(thermal: 0), 30)
    }
    func testGraphicsPresetsOnlyChangeTheSelectedConsole() {
        for preset in PlayerPreferences.Preset.allCases {
            var p = PlayerPreferences(); p.motionControls = false; p.ps1Analog = true; p.gameCubePanelBlank = true
            p.apply(preset, for: .threeDS)
            XCTAssertEqual(p.resolution, preset == .performance ? 1 : (preset == .balanced ? 2 : 3))
            XCTAssertEqual(p.ps1Resolution, 1); XCTAssertEqual(p.gameCubeResolution, 1)
            let threeDS = p.resolution
            p.apply(preset, for: .ps1)
            XCTAssertEqual(p.ps1Resolution, preset == .performance ? 1 : 2)
            XCTAssertEqual(p.ps1AutomaticQuality, preset == .balanced)
            XCTAssertEqual(p.resolution, threeDS); XCTAssertEqual(p.gameCubeResolution, 1)
            p.apply(preset, for: .gamecube)
            XCTAssertEqual(p.gameCubeResolution, preset == .performance ? 1 : (preset == .balanced ? 2 : 3))
            XCTAssertEqual(p.gameCubeAnisotropy, preset == .performance ? 0 : (preset == .balanced ? 2 : 8))
            XCTAssertTrue(p.ps1Analog && p.gameCubePanelBlank); XCTAssertFalse(p.motionControls)
            XCTAssertEqual(p, p.normalized)
        }
    }
    func testAdaptiveQualityUsesCoreSpeedWhenDisplayIsLimited() {
        var quality = AutomaticQuality(ceiling: 2)
        let limited = FrameSample(fps: 30, coreFPS: 60, targetFPS: 60, meanMS: 4, worstMS: 8, thermal: 0, resolution: 2)
        for _ in 0..<90 { XCTAssertNil(quality.next(limited)) }
        XCTAssertEqual(quality.resolution, 2)
    }
    func testLibrarySortUsesImportDateRatherThanLastPlayedAndHasStableTies() {
        let old = Game(title: "Zulu", fileName: "z.exe", lastPlayed: Date(timeIntervalSince1970: 100), added: Date(timeIntervalSince1970: 1), platform: .ps1)
        let recent = Game(title: "alpha", fileName: "a.dol", added: Date(timeIntervalSince1970: 2), platform: .gamecube)
        let second = Game(title: "Bravo", fileName: "b.3dsx", added: Date(timeIntervalSince1970: 3))
        XCTAssertEqual(LibraryOrder.recentlyAdded.sorted([old, recent, second]).map(\.id), [second.id, recent.id, old.id])
        XCTAssertEqual(LibraryOrder.alphabetical.sorted([old, second, recent]).map(\.id), [recent.id, second.id, old.id])
        let tie = Game(title: "alpha", fileName: "tie.dol", added: recent.added, platform: .gamecube)
        XCTAssertEqual(LibraryOrder.alphabetical.sorted([recent, tie]).map(\.id), LibraryOrder.alphabetical.sorted([tie, recent]).map(\.id))
    }
    func testPlayStationPreferencesRoundTripAndBlankPanelAreIndependent() throws {
        let suite = "EmuDen-PS1-" + UUID().uuidString, defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var p = PlayerPreferences(); p.ps1Resolution = 2; p.motionControls = false
        p.ps1PanelSpeed = false; p.ps1PanelFPS = false; p.ps1PanelSaves = false; p.ps1PanelTouch = false
        p.saveDefaults(defaults)
        XCTAssertEqual(PlayerPreferences(defaults: defaults), p)
        XCTAssertEqual(try JSONDecoder().decode(PlayerPreferences.self, from: JSONEncoder().encode(p)), p)
        XCTAssertEqual(p.resolution, 1); XCTAssertTrue(p.ps1Folded)
        p.ps1Resolution = 3; XCTAssertEqual(p.normalized.ps1Resolution, 1)
    }
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
