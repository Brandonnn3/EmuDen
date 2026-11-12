import Foundation

enum EmuDenLink {
    static let host = "emuden-support.headyopossum2.chatgpt.site"
    enum Destination: Equatable { case library, homebrew, game(UUID) }
    static var homebrew: URL { URL(string: "https://\(host)/play/?demo=homebrew")! }
    static func game(_ id: UUID) -> URL { URL(string: "https://\(host)/play/?game=" + id.uuidString)! }
    static func destination(_ url: URL) -> Destination? {
        guard url.user == nil, url.password == nil, url.port == nil, url.fragment == nil,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if url.scheme == "emuden", url.query == nil {
            if url.host == "library", url.path.isEmpty { return .library }
            if url.host == "demo", url.path == "/homebrew" { return .homebrew }
            guard url.host == "play", url.pathComponents.count == 2,
                  let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return .game(id)
        }
        guard url.scheme == "https", url.host == host,
              ["/play", "/play/"].contains(parts.percentEncodedPath),
              let items = parts.queryItems, items.count == 1 else { return nil }
        if items[0].name == "demo", items[0].value == "homebrew" { return .homebrew }
        guard items[0].name == "game", let value = items[0].value, value.count == 36,
              let id = UUID(uuidString: value) else { return nil }
        return .game(id)
    }
}

struct WidgetGame: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    var link: URL { EmuDenLink.game(id) }
    func imageURL(in directory: URL, scene: Bool = false) -> URL {
        directory.appendingPathComponent(id.uuidString + (scene ? "-scene.jpg" : "-cover.jpg"))
    }
}
struct WidgetLibrary: Codable, Equatable, Sendable {
    static let directoryName = "LocalArtworkWidgetLibrary"
    static let groupID = "group.com.brandonaleman.Emulator"
    static let continueKind = "EmuDenContinue", recentKind = "EmuDenRecent"
    var games: [WidgetGame]
    var updated: Date
    static let empty = WidgetLibrary(games: [], updated: .distantPast)
    static func gameID(from url: URL) -> UUID? {
        if case let .game(id) = EmuDenLink.destination(url) { return id }
        return nil
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
