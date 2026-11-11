import Foundation
import CryptoKit

struct SaveStateStore: Sendable {
    enum Slot: String, Sendable, CaseIterable { case quick, resume }
    enum StateError: LocalizedError {
        case invalid
        var errorDescription: String? { "This save state is incomplete or damaged. Your in-game saves and other state slot are unchanged." }
    }
    static let maximumSize = 256 * 1024 * 1024
    static let coreGeneration = "azahar-2127-fastinterp"
    private static let magic = Data("EMUDEN01".utf8)
    let directory: URL
    private let previousCoreDirectory: URL
    init(saves: URL, game: URL) {
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
    func date(_ slot: Slot) -> Date? {
        (try? url(slot).resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
    func write(_ data: Data, slot: Slot) throws {
        guard data.count >= 256, data.count <= Self.maximumSize else { throw StateError.invalid }
        var file = Self.magic
        file.append(contentsOf: SHA256.hash(data: data)); file.append(data)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try file.write(to: url(slot), options: .atomic)
    }
    func read(_ slot: Slot) throws -> Data {
        let fileURL = url(slot)
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
