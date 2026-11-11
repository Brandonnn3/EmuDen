import Foundation
import CryptoKit

struct SaveStateStore: Sendable {
    enum Slot: String, Sendable, CaseIterable { case quick, resume }
    struct Entry: Identifiable, Equatable, Sendable {
        let url: URL
        let slot: Slot
        let date: Date
        let bytes: Int
        var id: String { url.lastPathComponent }
        var previewURL: URL { url.deletingPathExtension().appendingPathExtension("jpg") }
    }
    enum StateError: LocalizedError {
        case invalid, replaced
        var errorDescription: String? {
            switch self {
            case .invalid: "This save state is incomplete or damaged. Your in-game saves and other snapshots are unchanged."
            case .replaced: "This save point changed while the history was open. Reopen Save history to choose it again. Other snapshots and in-game saves are unchanged."
            }
        }
    }
    static let maximumSize = 256 * 1024 * 1024
    static let coreGeneration = "azahar-2127-fastinterp"
    private static let magic = Data("EMUDEN01".utf8)
    let directory: URL
    private let savesRoot: URL
    private let previousCoreDirectory: URL
    init(saves: URL, game: URL) {
        savesRoot = saves.standardizedFileURL
        let key = SHA256.hash(data: Data(game.lastPathComponent.utf8)).map { String(format: "%02x", $0) }.joined()
        previousCoreDirectory = saves.appendingPathComponent("SaveStates/\(key)", isDirectory: true)
        let revisionFile = saves.appendingPathComponent(".system-resource-revision")
        let revision = (try? String(contentsOf: revisionFile, encoding: .utf8)).flatMap(UUID.init(uuidString:))?.uuidString ?? "original"
        // Older core snapshots remain on disk; native game saves use the existing Azahar folder.
        directory = saves.appendingPathComponent("SaveStates/\(Self.coreGeneration)/\(key)/\(revision)", isDirectory: true)
    }
    var hasOlderSnapshots: Bool {
        let fm = FileManager.default
        func containsState(_ folder: URL) -> Bool {
            Slot.allCases.contains { fm.fileExists(atPath: folder.appendingPathComponent($0.rawValue + ".emustate").path) }
        }
        if containsState(previousCoreDirectory) { return true }
        let siblings = (try? fm.contentsOfDirectory(at: directory.deletingLastPathComponent(), includingPropertiesForKeys: nil)) ?? []
        return siblings.contains { $0.lastPathComponent != directory.lastPathComponent && containsState($0) }
    }
    func url(_ slot: Slot) -> URL { directory.appendingPathComponent(slot.rawValue + ".emustate") }
    private var historyDirectory: URL { directory.appendingPathComponent("History", isDirectory: true) }
    var entries: [Entry] {
        guard (try? checkDirectories(directory)) != nil else { return [] }
        var result = Slot.allCases.compactMap { entry(at: url($0), slot: $0) }
        if (try? checkDirectories(historyDirectory)) != nil {
            let files = (try? FileManager.default.contentsOfDirectory(at: historyDirectory, includingPropertiesForKeys: nil)) ?? []
            result += files.compactMap { file in
                let parts = file.deletingPathExtension().lastPathComponent.split(separator: "-", maxSplits: 2)
                guard file.pathExtension == "emustate", parts.count == 3, parts[1].count == 13,
                      parts[1].allSatisfy(\.isNumber), UUID(uuidString: String(parts[2])) != nil,
                      let slot = Slot(rawValue: String(parts[0])) else { return nil }
                return entry(at: file, slot: slot)
            }
        }
        return result.sorted { $0.date == $1.date ? $0.id > $1.id : $0.date > $1.date }
    }
    func date(_ slot: Slot) -> Date? {
        entry(at: url(slot), slot: slot)?.date
    }
    func write(_ data: Data, slot: Slot, preview: Data? = nil) throws {
        guard data.count >= 256, data.count <= Self.maximumSize else { throw StateError.invalid }
        var file = Self.magic
        file.append(contentsOf: SHA256.hash(data: data)); file.append(data)
        try checkDirectories(directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try checkDirectories(historyDirectory)
        try FileManager.default.createDirectory(at: historyDirectory, withIntermediateDirectories: true)
        if let previous = entry(at: url(slot), slot: slot) {
            let name = "\(slot.rawValue)-\(Int64(previous.date.timeIntervalSince1970 * 1000))-\(UUID().uuidString).emustate"
            let archived = historyDirectory.appendingPathComponent(name)
            do { try FileManager.default.linkItem(at: previous.url, to: archived) }
            catch { try FileManager.default.copyItem(at: previous.url, to: archived) }
            if let image = previewData(previous) { try? image.write(to: archived.deletingPathExtension().appendingPathExtension("jpg"), options: .atomic) }
        }
        let existing = try? url(slot).resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        guard existing?.isSymbolicLink != true, existing?.isRegularFile != false else { throw StateError.invalid }
        try file.write(to: url(slot), options: .atomic)
        let picture = url(slot).deletingPathExtension().appendingPathExtension("jpg")
        if let preview, !preview.isEmpty, preview.count <= 512 * 1024 { try? preview.write(to: picture, options: .atomic) }
        else { try? FileManager.default.removeItem(at: picture) }
        let keep = slot == .quick ? 9 : 2
        for old in entries.filter({ $0.slot == slot && $0.url.deletingLastPathComponent().standardizedFileURL.path == historyDirectory.standardizedFileURL.path }).dropFirst(keep) {
            try? FileManager.default.removeItem(at: old.url)
            try? FileManager.default.removeItem(at: old.previewURL)
        }
    }
    func read(_ slot: Slot) throws -> Data {
        try readFile(url(slot))
    }
    func read(_ entry: Entry) throws -> Data {
        guard entries.contains(entry) else { throw StateError.replaced }
        return try readFile(entry.url)
    }
    func previewData(_ entry: Entry) -> Data? {
        let parent = entry.url.deletingLastPathComponent().standardizedFileURL.path
        guard parent == directory.standardizedFileURL.path || parent == historyDirectory.standardizedFileURL.path,
              (try? checkDirectories(entry.url.deletingLastPathComponent())) != nil,
              let values = try? entry.previewURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize,
              size > 0, size <= 512 * 1024 else { return nil }
        return try? Data(contentsOf: entry.previewURL)
    }
    private func entry(at file: URL, slot: Slot) -> Entry? {
        guard let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey]),
              values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize,
              size >= 296, size <= Self.maximumSize + 40, let date = values.contentModificationDate else { return nil }
        return Entry(url: file, slot: slot, date: date, bytes: size)
    }
    private func checkDirectories(_ folder: URL) throws {
        let target = folder.standardizedFileURL
        guard target.path.hasPrefix(savesRoot.path + "/") else { throw StateError.invalid }
        var part = savesRoot
        for component in [""] + Array(target.pathComponents.dropFirst(savesRoot.pathComponents.count)) {
            if !component.isEmpty { part.appendPathComponent(component) }
            if let values = try? part.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) {
                guard values.isSymbolicLink != true, values.isDirectory == true else { throw StateError.invalid }
            }
        }
    }
    private func readFile(_ fileURL: URL) throws -> Data {
        try checkDirectories(fileURL.deletingLastPathComponent())
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size >= 296, size <= Self.maximumSize + 40 else { throw StateError.invalid }
        let file = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        guard file.prefix(8) == Self.magic else { throw StateError.invalid }
        let data = Data(file.dropFirst(40))
        guard Data(SHA256.hash(data: data)) == file.subdata(in: 8..<40) else { throw StateError.invalid }
        return data
    }
}

/// Counts active play only; long background gaps and state operations do not advance the timer.
struct StateAutosaveClock {
    var interval: TimeInterval = 300
    private var previous: TimeInterval?
    private var wasActive = false
    private var elapsed: TimeInterval = 0
    mutating func saved() { elapsed = 0; previous = nil; wasActive = false }
    mutating func due(now: TimeInterval, active: Bool, enabled: Bool) -> Bool {
        defer { previous = now; wasActive = active && enabled }
        guard active, enabled, let previous, wasActive else { return false }
        guard now >= previous else { elapsed = 0; return false }
        elapsed += min(now - previous, 2)
        guard elapsed >= interval else { return false }
        elapsed = 0; return true
    }
}
