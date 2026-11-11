import Foundation

public enum ArtworkKind: String, Sendable {
    case cover = "Named_Boxarts"
    case scene = "Named_Snaps"
}

public enum ArtworkScenePolicy {
    public static func isHighResolution(width: Int, height: Int) -> Bool {
        min(width, height) >= 720 && max(width, height) >= 1280
    }
}

public enum ArtworkCoverPolicy {
    public static func frontWidth(width: Int, height: Int) -> Int {
        guard width > 0, height > 0 else { return 0 }
        let ratio = Double(width) / Double(height)
        // The Libretro 3DS retail scans place a vertical case strip beside a square front.
        return (1.08...1.16).contains(ratio) ? height : width
    }
}

public struct ArtworkIdentityCatalog: Sendable {
    public let titles: [String: String]
    public init(titles: [String: String]) { self.titles = titles }
    public func name(for game: Game, covers: ArtworkCatalog) -> String {
        if let choice = game.artworkTitle, !choice.isEmpty { return choice }
        if let id = game.programID?.uppercased(), let name = titles[id], covers.match(name) != nil { return name }
        return game.title
    }
}

public enum ThreeDSProgramID {
    public static func read(_ url: URL) -> String? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let file = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? file.close() }
        do {
            let size = try file.seekToEnd()
            try file.seek(toOffset: 0)
            var header = try file.read(upToCount: 0x200) ?? Data()
            if magic(header) == "NCSD" {
                guard let units = little(header, at: 0x120, count: 4), units > 0,
                      let length = little(header, at: 0x124, count: 4), length > 0 else { return nil }
                let offset = units * 0x200
                guard size >= 0x200, offset >= 0x200, offset <= size - 0x200 else { return nil }
                try file.seek(toOffset: offset)
                header = try file.read(upToCount: 0x200) ?? Data()
            }
            guard magic(header) == "NCCH", let id = little(header, at: 0x118, count: 8), id != 0, id != .max else { return nil }
            return String(format: "%016llX", id)
        } catch { return nil }
    }
    private static func magic(_ data: Data) -> String? {
        guard data.count >= 0x104 else { return nil }
        return String(data: data.subdata(in: 0x100..<0x104), encoding: .ascii)
    }
    private static func little(_ data: Data, at offset: Int, count: Int) -> UInt64? {
        guard data.count >= offset + count else { return nil }
        return (0..<count).reduce(UInt64(0)) { $0 | UInt64(data[offset + $1]) << ($1 * 8) }
    }
}

public struct ArtworkCatalog: Decodable, Sendable {
    public let files: [String]
    private let exact: [String: String]
    private let grouped: [String: [String]]
    private enum CodingKeys: String, CodingKey { case files }
    public init(files: [String]) {
        self.files = files
        var exact = [String: String]()
        for file in files {
            let key = (file as NSString).deletingPathExtension.lowercased()
            if exact[key] == nil { exact[key] = file }
        }
        self.exact = exact; grouped = Dictionary(grouping: files, by: Self.base)
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(files: try values.decode([String].self, forKey: .files))
    }

    public func search(_ query: String, limit: Int = 60) -> [String] {
        let query = Self.base(query)
        return grouped.filter { query.isEmpty || $0.key.contains(query) }
            .compactMap { $0.value.sorted { Self.score($0, for: "") == Self.score($1, for: "") ? $0 < $1 : Self.score($0, for: "") > Self.score($1, for: "") }.first }
            .sorted { Self.score($0, for: "") == Self.score($1, for: "") ? $0 < $1 : Self.score($0, for: "") > Self.score($1, for: "") }
            .prefix(max(0, limit)).map { $0 }
    }

    public func match(_ title: String) -> String? {
        let name = Self.safeName(title)
        if let exact = exact[name.lowercased()] { return exact }
        let base = Self.base(name)
        guard !base.isEmpty else { return nil }
        let candidates = grouped[base] ?? []
        return candidates.sorted {
            let left = Self.score($0, for: name), right = Self.score($1, for: name)
            return left == right ? $0 < $1 : left > right
        }.first
    }

    public func url(for title: String, kind: ArtworkKind = .cover) -> URL? {
        guard let file = match(title), !file.contains("/"), !file.contains("\\"), file.hasSuffix(".png") else { return nil }
        // The thumbnail server resolves shared covers; raw GitHub URLs return symlink text.
        return URL(string: "https://thumbnails.libretro.com/Nintendo%20-%20Nintendo%203DS/")!
            .appendingPathComponent(kind.rawValue, isDirectory: true)
            .appendingPathComponent(file)
    }

    private static func safeName(_ title: String) -> String {
        var name = title
        if ["3ds", "cci", "cxi", "app", "3dsx", "elf", "png"].contains((name as NSString).pathExtension.lowercased()) {
            name = (name as NSString).deletingPathExtension
        }
        return name.map { "&*/:`<>?\\|\"".contains($0) ? "_" : String($0) }.joined()
    }

    public static func matchKey(_ title: String) -> String { base(title) }

    private static func base(_ title: String) -> String {
        let name = safeName(title).components(separatedBy: " (").first ?? title
        let words = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .split(separator: " ").map(String.init)
        // DAT names place the article at the end ("Legend of Zelda, The").
        return words.filter { $0 != "the" && $0 != "and" }.joined(separator: " ")
    }

    private static func score(_ file: String, for name: String) -> Int {
        let candidate = (file as NSString).deletingPathExtension
        if candidate.caseInsensitiveCompare(name) == .orderedSame { return 1000 }
        let tags = ["USA", "Europe", "Japan", "Korea", "Taiwan", "World", "Rev 1", "Rev 2"]
        var score = 0
        for tag in tags {
            if name.localizedCaseInsensitiveContains("(\(tag))") {
                score += candidate.localizedCaseInsensitiveContains("(\(tag))") ? 100 : -100
            }
        }
        if !name.contains("(Rev "), candidate.contains("(Rev ") { score -= 10 }
        if !tags.prefix(6).contains(where: { name.contains("(\($0))") }), candidate.contains("(USA)") { score += 5 }
        return score
    }
}
