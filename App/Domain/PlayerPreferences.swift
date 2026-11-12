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
    var resolution = 1
    var asyncShaders = true
    var prepareShaders = false
    var sampling = Sampling.game
    var sizing = Sizing.automatic
    var screenBalance = 0.5
    var automaticQuality = false
    var normalized: Self {
        var value = self
        value.resolution = (1...3).contains(resolution) ? resolution : 1
        value.screenBalance = screenBalance.isFinite ? min(0.65, max(0.35, screenBalance)) : 0.5
        return value
    }
    init() {}
    init(defaults: UserDefaults) {
        resolution = defaults.object(forKey: "resolutionFactor") == nil ? 1 : defaults.integer(forKey: "resolutionFactor")
        asyncShaders = defaults.object(forKey: "asyncShaderCompilation") == nil ? true : defaults.bool(forKey: "asyncShaderCompilation")
        prepareShaders = defaults.bool(forKey: "prepareCachedShaders")
        sampling = Sampling(rawValue: defaults.string(forKey: "textureSampling") ?? "") ?? .game
        sizing = Sizing(rawValue: defaults.string(forKey: "screenSizing") ?? "") ?? .automatic
        screenBalance = defaults.object(forKey: "screenBalance") == nil ? 0.5 : defaults.double(forKey: "screenBalance")
        automaticQuality = defaults.bool(forKey: "automaticQuality")
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
