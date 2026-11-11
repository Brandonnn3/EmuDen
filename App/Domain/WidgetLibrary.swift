import Foundation

struct WidgetGame: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    var link: URL { URL(string: "emuden://play/" + id.uuidString)! }
    func imageURL(in directory: URL, scene: Bool = false) -> URL {
        directory.appendingPathComponent(id.uuidString + (scene ? "-scene.jpg" : "-cover.jpg"))
    }
}
struct WidgetLibrary: Codable, Equatable, Sendable {
    static let groupID = "group.com.brandonaleman.Emulator"
    static let continueKind = "EmuDenContinue", recentKind = "EmuDenRecent"
    var games: [WidgetGame]
    var updated: Date
    static let empty = WidgetLibrary(games: [], updated: .distantPast)
    static func gameID(from url: URL) -> UUID? {
        guard url.scheme == "emuden", url.host == "play", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil,
              url.pathComponents.count == 2 else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
    static func read(from directory: URL) -> Self? {
        let file = directory.appendingPathComponent("library.json")
        guard let v = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              v.isRegularFile == true, v.isSymbolicLink != true, let size = v.fileSize, (1...32768).contains(size),
              let data = try? Data(contentsOf: file), let value = try? JSONDecoder().decode(Self.self, from: data),
              value.games.count <= 4, Set(value.games.map(\.id)).count == value.games.count,
              value.games.allSatisfy({ !$0.title.isEmpty && $0.title.count <= 240 }) else { return nil }
        return value
    }
    func write(to directory: URL) throws {
        guard games.count <= 4, Set(games.map(\.id)).count == games.count,
              games.allSatisfy({ !$0.title.isEmpty && $0.title.count <= 240 }) else { throw CocoaError(.fileWriteInvalidFileName) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard try directory.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw CocoaError(.fileWriteInvalidFileName) }
        try JSONEncoder().encode(self).write(to: directory.appendingPathComponent("library.json"), options: .atomic)
    }
}
