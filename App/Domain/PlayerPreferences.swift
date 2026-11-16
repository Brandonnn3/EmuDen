import Foundation

enum AgeEligibilityError: Error { case timedOut }

@MainActor final class AgeEligibilityRequest {
    private var continuation: CheckedContinuation<Bool, Error>?
    private var request: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    func value(timeout: Duration = .seconds(15), operation: @escaping @MainActor () async throws -> Bool) async throws -> Bool {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                request = Task {
                    do { finish(.success(try await operation())) }
                    catch { finish(.failure(error)) }
                }
                deadline = Task {
                    do { try await Task.sleep(for: timeout) } catch { return }
                    finish(.failure(AgeEligibilityError.timedOut))
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }
    private func finish(_ result: Result<Bool, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        request?.cancel(); deadline?.cancel(); request = nil; deadline = nil
        continuation.resume(with: result)
    }
}
import CryptoKit

struct PlayerPreferences: Codable, Equatable, Sendable {
    enum Sampling: String, Codable, CaseIterable, Sendable {
        case game = "GameControlled", crisp = "NearestNeighbor", smooth = "Linear"
        var title: String { switch self { case .game: "Game default"; case .crisp: "Crisp"; case .smooth: "Smooth" } }
    }
    enum Sizing: String, Codable, CaseIterable, Sendable {
        case automatic, original, fill
        var title: String { switch self { case .automatic: "Follow layout"; case .original: "Original proportions"; case .fill: "Fill screen regions" } }
    }
    enum Presentation: String, Codable, CaseIterable, Sendable {
        case automatic, full, reduced
        var title: String { switch self { case .automatic: "Automatic"; case .full: "Game rate"; case .reduced: "30 fps" } }
        func limit(thermal: Int) -> Int { self == .reduced || (self == .automatic && thermal >= 2) ? 30 : 0 }
    }
    enum Preset: String, CaseIterable { case performance = "Performance", balanced = "Balanced", sharp = "Sharp" }
    var resolution = 1
    var asyncShaders = true
    var prepareShaders = false
    var sampling = Sampling.game
    var sizing = Sizing.automatic
    var screenBalance = 0.5
    var automaticQuality = false
    var ps1Analog = false
    var ps1Resolution = 1
    var ps1Dithering = true
    var ps1Smooth = false
    var ps1TextureFix = true
    var ps1AutomaticQuality = false
    var presentation = Presentation.automatic
    var gameCubeResolution = 1
    var gameCubeSampling = Sampling.game
    var gameCubeAnisotropy = 0
    var ps1Folded = true
    var ps1PanelSpeed = true
    var ps1PanelFPS = true
    var ps1PanelSaves = true
    var ps1PanelTouch = true
    var gameCubeFolded = true
    var gameCubePanelFPS = true
    var gameCubePanelSaves = true
    var gameCubePanelTouch = true
    var gameCubePanelBlank = false
    var motionControls = true
    var normalized: Self {
        var value = self
        value.resolution = (1...3).contains(resolution) ? resolution : 1
        value.ps1Resolution = ps1Resolution == 2 ? 2 : 1
        value.gameCubeResolution = (1...4).contains(gameCubeResolution) ? gameCubeResolution : 1
        value.gameCubeAnisotropy = [0, 1, 2, 4, 8, 16].contains(gameCubeAnisotropy) ? gameCubeAnisotropy : 0
        value.screenBalance = screenBalance.isFinite ? min(0.65, max(0.35, screenBalance)) : 0.5
        return value
    }
    init() {}
    private enum CodingKeys: String, CodingKey {
        case resolution, asyncShaders, prepareShaders, sampling, sizing, screenBalance, automaticQuality
        case ps1Resolution, ps1Folded, ps1PanelSpeed, ps1PanelFPS, ps1PanelSaves, ps1PanelTouch
        case ps1Dithering, ps1Smooth, ps1TextureFix, gameCubeResolution, gameCubeSampling, gameCubeAnisotropy
        case motionControls, ps1Analog
        case presentation, ps1AutomaticQuality, gameCubeFolded, gameCubePanelFPS, gameCubePanelSaves, gameCubePanelTouch, gameCubePanelBlank
    }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resolution = try c.decodeIfPresent(Int.self, forKey: .resolution) ?? resolution
        asyncShaders = try c.decodeIfPresent(Bool.self, forKey: .asyncShaders) ?? asyncShaders
        prepareShaders = try c.decodeIfPresent(Bool.self, forKey: .prepareShaders) ?? prepareShaders
        sampling = try c.decodeIfPresent(Sampling.self, forKey: .sampling) ?? sampling
        sizing = try c.decodeIfPresent(Sizing.self, forKey: .sizing) ?? sizing
        screenBalance = try c.decodeIfPresent(Double.self, forKey: .screenBalance) ?? screenBalance
        automaticQuality = try c.decodeIfPresent(Bool.self, forKey: .automaticQuality) ?? automaticQuality
        ps1Analog = try c.decodeIfPresent(Bool.self, forKey: .ps1Analog) ?? ps1Analog
        ps1Resolution = try c.decodeIfPresent(Int.self, forKey: .ps1Resolution) ?? ps1Resolution
        ps1Dithering = try c.decodeIfPresent(Bool.self, forKey: .ps1Dithering) ?? ps1Dithering
        ps1Smooth = try c.decodeIfPresent(Bool.self, forKey: .ps1Smooth) ?? ps1Smooth
        ps1TextureFix = try c.decodeIfPresent(Bool.self, forKey: .ps1TextureFix) ?? ps1TextureFix
        ps1AutomaticQuality = try c.decodeIfPresent(Bool.self, forKey: .ps1AutomaticQuality) ?? ps1AutomaticQuality
        presentation = try c.decodeIfPresent(Presentation.self, forKey: .presentation) ?? presentation
        gameCubeResolution = try c.decodeIfPresent(Int.self, forKey: .gameCubeResolution) ?? gameCubeResolution
        gameCubeSampling = try c.decodeIfPresent(Sampling.self, forKey: .gameCubeSampling) ?? gameCubeSampling
        gameCubeAnisotropy = try c.decodeIfPresent(Int.self, forKey: .gameCubeAnisotropy) ?? gameCubeAnisotropy
        ps1Folded = try c.decodeIfPresent(Bool.self, forKey: .ps1Folded) ?? ps1Folded
        ps1PanelSpeed = try c.decodeIfPresent(Bool.self, forKey: .ps1PanelSpeed) ?? ps1PanelSpeed
        ps1PanelFPS = try c.decodeIfPresent(Bool.self, forKey: .ps1PanelFPS) ?? ps1PanelFPS
        ps1PanelSaves = try c.decodeIfPresent(Bool.self, forKey: .ps1PanelSaves) ?? ps1PanelSaves
        ps1PanelTouch = try c.decodeIfPresent(Bool.self, forKey: .ps1PanelTouch) ?? ps1PanelTouch
        gameCubeFolded = try c.decodeIfPresent(Bool.self, forKey: .gameCubeFolded) ?? gameCubeFolded
        gameCubePanelFPS = try c.decodeIfPresent(Bool.self, forKey: .gameCubePanelFPS) ?? gameCubePanelFPS
        gameCubePanelSaves = try c.decodeIfPresent(Bool.self, forKey: .gameCubePanelSaves) ?? gameCubePanelSaves
        gameCubePanelTouch = try c.decodeIfPresent(Bool.self, forKey: .gameCubePanelTouch) ?? gameCubePanelTouch
        gameCubePanelBlank = try c.decodeIfPresent(Bool.self, forKey: .gameCubePanelBlank) ?? gameCubePanelBlank
        motionControls = try c.decodeIfPresent(Bool.self, forKey: .motionControls) ?? motionControls
        self = normalized
    }
    init(defaults: UserDefaults) {
        resolution = defaults.object(forKey: "resolutionFactor") == nil ? 1 : defaults.integer(forKey: "resolutionFactor")
        asyncShaders = defaults.object(forKey: "asyncShaderCompilation") == nil ? true : defaults.bool(forKey: "asyncShaderCompilation")
        prepareShaders = defaults.bool(forKey: "prepareCachedShaders")
        sampling = Sampling(rawValue: defaults.string(forKey: "textureSampling") ?? "") ?? .game
        sizing = Sizing(rawValue: defaults.string(forKey: "screenSizing") ?? "") ?? .automatic
        screenBalance = defaults.object(forKey: "screenBalance") == nil ? 0.5 : defaults.double(forKey: "screenBalance")
        automaticQuality = defaults.bool(forKey: "automaticQuality")
        ps1Analog = defaults.bool(forKey: "ps1Analog")
        ps1Resolution = defaults.object(forKey: "ps1Resolution") == nil ? 1 : defaults.integer(forKey: "ps1Resolution")
        ps1Dithering = defaults.object(forKey: "ps1Dithering") == nil || defaults.bool(forKey: "ps1Dithering")
        ps1Smooth = defaults.bool(forKey: "ps1Smooth")
        ps1TextureFix = defaults.object(forKey: "ps1TextureFix") == nil || defaults.bool(forKey: "ps1TextureFix")
        ps1AutomaticQuality = defaults.bool(forKey: "ps1AutomaticQuality")
        presentation = Presentation(rawValue: defaults.string(forKey: "framePresentation") ?? "") ?? .automatic
        gameCubeResolution = defaults.object(forKey: "gameCubeResolution") == nil ? 1 : defaults.integer(forKey: "gameCubeResolution")
        gameCubeSampling = Sampling(rawValue: defaults.string(forKey: "gameCubeSampling") ?? "") ?? .game
        gameCubeAnisotropy = defaults.integer(forKey: "gameCubeAnisotropy")
        ps1Folded = defaults.object(forKey: "ps1Folded") == nil || defaults.bool(forKey: "ps1Folded")
        ps1PanelSpeed = defaults.object(forKey: "ps1PanelSpeed") == nil || defaults.bool(forKey: "ps1PanelSpeed")
        ps1PanelFPS = defaults.object(forKey: "ps1PanelFPS") == nil || defaults.bool(forKey: "ps1PanelFPS")
        ps1PanelSaves = defaults.object(forKey: "ps1PanelSaves") == nil || defaults.bool(forKey: "ps1PanelSaves")
        ps1PanelTouch = defaults.object(forKey: "ps1PanelTouch") == nil || defaults.bool(forKey: "ps1PanelTouch")
        gameCubeFolded = defaults.object(forKey: "gameCubeFolded") == nil || defaults.bool(forKey: "gameCubeFolded")
        gameCubePanelFPS = defaults.object(forKey: "gameCubePanelFPS") == nil || defaults.bool(forKey: "gameCubePanelFPS")
        gameCubePanelSaves = defaults.object(forKey: "gameCubePanelSaves") == nil || defaults.bool(forKey: "gameCubePanelSaves")
        gameCubePanelTouch = defaults.object(forKey: "gameCubePanelTouch") == nil || defaults.bool(forKey: "gameCubePanelTouch")
        gameCubePanelBlank = defaults.bool(forKey: "gameCubePanelBlank")
        motionControls = defaults.object(forKey: "motionControls") == nil || defaults.bool(forKey: "motionControls")
        self = normalized
    }
    func saveDefaults(_ defaults: UserDefaults) {
        let p = normalized
        defaults.set(p.resolution, forKey: "resolutionFactor")
        defaults.set(p.asyncShaders, forKey: "asyncShaderCompilation")
        defaults.set(p.prepareShaders, forKey: "prepareCachedShaders")
        defaults.set(p.sampling.rawValue, forKey: "textureSampling")
        defaults.set(p.sizing.rawValue, forKey: "screenSizing")
        defaults.set(p.screenBalance, forKey: "screenBalance")
        defaults.set(p.automaticQuality, forKey: "automaticQuality")
        defaults.set(p.ps1Analog, forKey: "ps1Analog")
        defaults.set(p.ps1Resolution, forKey: "ps1Resolution")
        defaults.set(p.ps1Dithering, forKey: "ps1Dithering")
        defaults.set(p.ps1Smooth, forKey: "ps1Smooth")
        defaults.set(p.ps1TextureFix, forKey: "ps1TextureFix")
        defaults.set(p.ps1AutomaticQuality, forKey: "ps1AutomaticQuality")
        defaults.set(p.presentation.rawValue, forKey: "framePresentation")
        defaults.set(p.gameCubeResolution, forKey: "gameCubeResolution")
        defaults.set(p.gameCubeSampling.rawValue, forKey: "gameCubeSampling")
        defaults.set(p.gameCubeAnisotropy, forKey: "gameCubeAnisotropy")
        defaults.set(p.ps1Folded, forKey: "ps1Folded")
        defaults.set(p.ps1PanelSpeed, forKey: "ps1PanelSpeed")
        defaults.set(p.ps1PanelFPS, forKey: "ps1PanelFPS")
        defaults.set(p.ps1PanelSaves, forKey: "ps1PanelSaves")
        defaults.set(p.ps1PanelTouch, forKey: "ps1PanelTouch")
        defaults.set(p.gameCubeFolded, forKey: "gameCubeFolded")
        defaults.set(p.gameCubePanelFPS, forKey: "gameCubePanelFPS")
        defaults.set(p.gameCubePanelSaves, forKey: "gameCubePanelSaves")
        defaults.set(p.gameCubePanelTouch, forKey: "gameCubePanelTouch")
        defaults.set(p.gameCubePanelBlank, forKey: "gameCubePanelBlank")
        defaults.set(p.motionControls, forKey: "motionControls")
    }
    mutating func apply(_ preset: Preset, for platform: GamePlatform) {
        switch platform {
        case .threeDS:
            resolution = preset == .performance ? 1 : (preset == .balanced ? 2 : 3)
            asyncShaders = true; automaticQuality = preset == .balanced; sampling = .game
        case .ps1:
            ps1Resolution = preset == .performance ? 1 : 2
            ps1AutomaticQuality = preset == .balanced; ps1Dithering = preset != .performance
            ps1Smooth = preset == .sharp; ps1TextureFix = true
        case .gamecube:
            gameCubeResolution = preset == .performance ? 1 : (preset == .balanced ? 2 : 3)
            gameCubeSampling = .game; gameCubeAnisotropy = preset == .performance ? 0 : (preset == .balanced ? 2 : 8)
        }
    }
}

struct PlayerProfileStore: Sendable {
    let directory: URL
    init(root: URL) { directory = root.appendingPathComponent("PlayerProfiles", isDirectory: true) }
    func url(for fileName: String) -> URL {
        let key = SHA256.hash(data: Data(fileName.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(key + ".json")
    }
    func read(_ fileName: String) throws -> PlayerPreferences? {
        if FileManager.default.fileExists(atPath: directory.path), try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true { throw ImportError.unsafeFile }
        let file = url(for: fileName)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let v = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard v.isRegularFile == true, v.isSymbolicLink != true, let size = v.fileSize, (1...8192).contains(size) else { throw ImportError.unsafeFile }
        return try JSONDecoder().decode(PlayerPreferences.self, from: Data(contentsOf: file)).normalized
    }
    func write(_ preferences: PlayerPreferences?, for fileName: String) throws {
        if FileManager.default.fileExists(atPath: directory.path), try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true { throw ImportError.unsafeFile }
        let file = url(for: fileName)
        if let preferences {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(preferences.normalized).write(to: file, options: .atomic)
        } else if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}

struct FrameSample: Equatable, Sendable {
    let fps: Double
    let coreFPS: Double
    let targetFPS: Double
    let meanMS: Double
    let worstMS: Double
    let thermal: Int
    let resolution: Int
    var speed: Double { targetFPS > 0 ? coreFPS / targetFPS : 0 }
    var heat: String { switch thermal { case 1: "Warm"; case 2: "Hot"; case 3: "Very hot"; default: "Normal" } }
}

// One sample per second; isolated compilation stalls must not trigger resolution changes.
struct AutomaticQuality: Sendable {
    private(set) var resolution: Int
    private(set) var ceiling: Int
    private var poor = 0, healthy = 0, sinceChange = 0
    init(ceiling: Int) { self.ceiling = min(3, max(1, ceiling)); resolution = self.ceiling }
    mutating func next(_ sample: FrameSample) -> Int? {
        guard sample.speed.isFinite, sample.meanMS.isFinite, sample.worstMS.isFinite, sample.targetFPS > 0 else { return nil }
        sinceChange += 1
        let budget = 1000 / sample.targetFPS
        poor = sample.thermal >= 2 || (sample.speed < 0.92 && sample.meanMS > budget * 0.9) ? poor + 1 : 0
        healthy = sample.thermal == 0 && sample.speed >= 0.98 && sample.meanMS < budget * 0.7 && sample.worstMS < budget * 2 ? healthy + 1 : 0
        if resolution > 1, sinceChange >= 15, poor >= 5 {
            resolution -= 1; poor = 0; healthy = 0; sinceChange = 0; return resolution
        }
        if resolution < ceiling, sinceChange >= 45, healthy >= 30 {
            resolution += 1; poor = 0; healthy = 0; sinceChange = 0; return resolution
        }
        return nil
    }
}

struct ShaderCache: Sendable {
    let saves: URL
    private func files(_ id: String) throws -> [URL] {
        guard id.count == 16, id.allSatisfy({ $0.isHexDigit && $0.isASCII }) else { return [] }
        let fm = FileManager.default
        var base = saves.resolvingSymlinksInPath()
        for component in ["Azahar", "shaders", "vulkan"] {
            base.appendPathComponent(component, isDirectory: true)
            if fm.fileExists(atPath: base.path), try base.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true { throw ImportError.unsafeFile }
        }
        var files = [URL]()
        for folder in ["transferable", "pipeline"] {
            let dir = base.appendingPathComponent(folder, isDirectory: true)
            guard fm.fileExists(atPath: dir.path) else { continue }
            guard try dir.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ImportError.unsafeFile }
            for file in try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) {
                let name = file.lastPathComponent.uppercased(), key = id.uppercased()
                let transferable = ["VS", "FS", "GS", "PL"].contains { name == key + "_" + $0 + ".VKCH" || name == key + "_" + $0 + "_TEMP.VKCH" }
                let suffix = String(name.dropFirst(17).dropLast(4))
                let pipeline = name.hasPrefix(key + "-") && ((name.hasSuffix(".BIN") && !suffix.isEmpty && suffix.allSatisfy({ $0.isHexDigit && $0.isASCII })) || name == key + "-LOADING.FLAG")
                guard folder == "transferable" ? transferable : pipeline else { continue }
                let v = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard v.isRegularFile == true, v.isSymbolicLink != true else { throw ImportError.unsafeFile }
                files.append(file)
            }
        }
        return files
    }
    func size(for id: String) throws -> Int64 {
        try files(id).reduce(0) { $0 + Int64(try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
    }
    func reset(_ id: String) throws {
        // Stage every selected file before deletion so an interrupted move can roll back.
        let fm = FileManager.default, selected = try files(id)
        guard !selected.isEmpty else { return }
        let staging = saves.appendingPathComponent(".shader-reset-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        var moved = [(URL, URL)]()
        do {
            for (i, source) in selected.enumerated() {
                let target = staging.appendingPathComponent(String(i))
                try fm.moveItem(at: source, to: target); moved.append((source, target))
            }
        } catch {
            for (source, target) in moved.reversed() { try? fm.moveItem(at: target, to: source) }
            throw error
        }
        try fm.removeItem(at: staging)
    }
}
