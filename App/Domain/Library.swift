import Foundation

enum LibraryOrder: String, CaseIterable {
    case recentlyAdded, alphabetical
    var title: String { self == .recentlyAdded ? "Recently added" : "A–Z" }
    func sorted(_ games: [Game]) -> [Game] {
        games.sorted { left, right in
            if self == .recentlyAdded, left.added != right.added { return left.added > right.added }
            let order = left.displayName.localizedStandardCompare(right.displayName)
            return order == .orderedSame ? left.id.uuidString < right.id.uuidString : order == .orderedAscending
        }
    }
}
import CryptoKit

public struct PlayStationCue: Sendable {
    public let files: [String]
    public init(url: URL) throws {
        let v = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard v.isRegularFile == true, v.isSymbolicLink != true, let size = v.fileSize, size > 0, size <= 65536 else { throw ImportError.invalidCue }
        let data = try Data(contentsOf: url)
        guard data.count <= 65536, let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw ImportError.invalidCue }
        let pattern = try NSRegularExpression(pattern: "^FILE\\s+(?:\"([^\"]+)\"|([^\\s]+))\\s+BINARY\\s*$", options: .caseInsensitive)
        var names = [String]()
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.uppercased().hasPrefix("FILE") else { continue }
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = pattern.firstMatch(in: trimmed, range: range),
                  let r = Range(match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1), in: trimmed) else { throw ImportError.invalidCue }
            let name = String(trimmed[r])
            guard name.count <= 200, !name.isEmpty, !name.hasPrefix("."),
                  !name.contains("/"), !name.contains("\\"), !name.contains(":"), !name.contains("\0"),
                  name.lowercased().hasSuffix(".bin"), name != "disc.cue" else { throw ImportError.invalidCue }
            if !names.contains(name) { names.append(name) }
        }
        guard !names.isEmpty, names.count <= 99 else { throw ImportError.invalidCue }
        files = names
    }
}

public enum GameCubeDOL {
    // Only executable sections in GameCube MEM1 are accepted.
    public static func validate(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, (256...32 * 1024 * 1024).contains(size) else { throw ImportError.invalidDOL }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let header = try file.read(upToCount: 256) ?? Data()
        try validate(header: header, size: UInt64(size))
    }
    fileprivate static func validate(header: Data, size: UInt64) throws {
        guard header.count == 256 else { throw ImportError.invalidDOL }
        func word(_ offset: Int) -> UInt64 {
            header[offset..<offset + 4].reduce(0) { ($0 << 8) | UInt64($1) }
        }
        func memoryRange(_ address: UInt64, _ count: UInt64) -> Range<UInt64>? {
            let base = address & 0xE0000000
            guard [0, 0x80000000, 0xC0000000].contains(base) else { return nil }
            let physical = address & 0x1FFFFFFF
            guard physical + count <= 0x01800000 else { return nil }
            return physical..<physical + count
        }
        var text = [Range<UInt64>]()
        for section in 0..<18 {
            let offset = word(section * 4), address = word(0x48 + section * 4), count = word(0x90 + section * 4)
            guard count > 0 else { continue }
            // Pinned Dolphin's DolReader reads each section rounded up to 32 bytes.
            let aligned = (count + 31) & ~UInt64(31)
            guard offset >= 256, offset + aligned <= size,
                  let range = memoryRange(address, aligned) else { throw ImportError.invalidDOL }
            if section < 7 { text.append(range.lowerBound..<range.lowerBound + count) }
        }
        let entry = word(0xE0)
        guard entry % 4 == 0, let entryRange = memoryRange(entry, 4),
              text.contains(where: { $0.contains(entryRange.lowerBound) && entryRange.upperBound <= $0.upperBound }) else { throw ImportError.invalidDOL }
        if word(0xDC) > 0, memoryRange(word(0xD8), word(0xDC)) == nil { throw ImportError.invalidDOL }
    }
}

public enum GameCubeDisc {
    public static func validate(_ url: URL) throws {
        let ciso = url.pathExtension.lowercased() == "ciso"
        func invalid(_ reason: String) -> ImportError { .invalidGCDiscDetail(reason) }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
              let count = values.fileSize, (0x2460...(0x57058000 + (ciso ? 0x1008000 : 0))).contains(count) else { throw invalid("The selected image is not a regular file of a supported size.") }
        let physicalSize = UInt64(count), file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        func rawRead(_ offset: UInt64, _ count: Int) throws -> Data {
            guard offset + UInt64(count) <= physicalSize else { throw invalid("The image ends before the referenced disc data. Make sure the file is fully downloaded.") }
            try file.seek(toOffset: offset)
            let bytes = try file.read(upToCount: count) ?? Data()
            guard bytes.count == count else { throw invalid("The file provider did not return all the requested data. Download the file locally and retry.") }
            return bytes
        }
        var size = physicalSize, blockSize: UInt64 = 0, blocks = [Int]()
        if ciso {
            // Pinned Dolphin CISOBlob: 32KiB header, little-endian block size,
            // 0/1 sparse-block map. This is not PSP's different CSO container.
            let header = try rawRead(0, 0x8000)
            guard header.prefix(4) == Data("CISO".utf8) else { throw invalid("The file does not contain a Dolphin CISO header. Renaming another format to .ciso does not convert it.") }
            blockSize = header[4..<8].enumerated().reduce(0) { $0 | UInt64($1.element) << ($1.offset * 8) }
            guard (2048...0x1000000).contains(blockSize), blockSize & (blockSize - 1) == 0 else { throw invalid("Unsupported CISO block size: \(blockSize) bytes. PSP CSO is a different format.") }
            guard header.dropFirst(8).allSatisfy({ $0 <= 1 }) else { throw invalid("The CISO block map contains invalid entries.") }
            var stored = 0
            blocks = header.dropFirst(8).map { byte in
                guard byte == 1 else { return -1 }
                defer { stored += 1 }; return stored
            }
            // Dolphin ignores trailing padding; individual reads still enforce file bounds.
            guard stored > 0, physicalSize > 0x8000 + UInt64(stored - 1) * blockSize else { throw invalid("The CISO block map references data missing from this file.") }
            size = min(0x57058000, UInt64(blocks.count) * blockSize)
        }
        func read(_ offset: UInt64, _ count: Int) throws -> Data {
            guard offset + UInt64(count) <= size else { throw invalid("The disc header points outside the supported GameCube address range.") }
            if !ciso { return try rawRead(offset, count) }
            var result = Data(), position = offset, remaining = count
            while remaining > 0 {
                let block = Int(position / blockSize), within = position % blockSize
                let length = min(remaining, Int(blockSize - within))
                if blocks[block] < 0 { result.append(Data(repeating: 0, count: length)) }
                else { result.append(try rawRead(0x8000 + UInt64(blocks[block]) * blockSize + within, length)) }
                position += UInt64(length); remaining -= length
            }
            return result
        }
        func word(_ bytes: Data, _ offset: Int) -> UInt64 {
            bytes[offset..<offset + 4].reduce(0) { ($0 << 8) | UInt64($1) }
        }
        let header = try read(0, 0x460)
        guard word(header, 0x18) != 0x5d1c9ea3 else { throw invalid("The disc identifies itself as Wii software; this player supports GameCube only.") }
        guard word(header, 0x1c) == 0xc2339f3d else { throw invalid("The decoded image does not contain a GameCube disc header. This may be a different CISO variant or an incomplete image.") }
        guard header.prefix(6).allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }) else { throw invalid("The GameCube disc identifier is invalid.") }
        let fst = word(header, 0x424), fstSize = word(header, 0x428)
        guard fst >= 0x2460, fst % 4 == 0, (12...64 * 1024 * 1024).contains(fstSize), fst + fstSize <= size else { throw invalid("The filesystem table address or size is outside the disc.") }
        let root = try read(fst, 12), nodes = word(root, 8)
        guard root[0] == 1, nodes > 0, nodes * 12 <= fstSize else { throw invalid("The filesystem root cannot be read from the decoded disc.") }
        let loader = try read(0x2440, 32)
        let entry = word(loader, 0x10), loaderSize = word(loader, 0x14) + word(loader, 0x18)
        guard loaderSize > 0, loaderSize <= 6 * 1024 * 1024, 0x2460 + loaderSize <= size,
              entry % 4 == 0, entry >= 0x81200000, entry - 0x81200000 < loaderSize else { throw invalid("The GameCube apploader entry or size is invalid.") }
        // Disc boot uses its apploader's load table, not the standalone DOL reader.
    }
}

enum RegionalAgeAccess {
    static let minimumAge = 4
    static func isAllowedAgeBand(lowerBound: Int?, upperBound: Int?) -> Bool {
        guard let lowerBound, lowerBound >= minimumAge else { return false }
        return upperBound.map { $0 >= lowerBound } ?? true
    }
}

public enum GamePlatform: String, Codable, Sendable {
    case threeDS = "3ds", ps1, gamecube
    public var name: String { switch self { case .threeDS: "Nintendo 3DS"; case .ps1: "PlayStation"; case .gamecube: "GameCube" } }
}

public struct Game: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var customTitle: String?
    public var displayName: String { customTitle ?? title }
    public let fileName: String
    public var lastPlayed: Date?
    public let added: Date
    public var programID: String?
    public var artworkTitle: String?
    public var useConsoleBackground: Bool?
    public var platform: GamePlatform?
    public var console: GamePlatform { platform ?? .threeDS }
    public var system: String { console.name }
    public static func isValidDisplayName(_ name: String) -> Bool {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && text.count <= 160 && !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }
    public func renamed(_ name: String) throws -> Game {
        guard Self.isValidDisplayName(name) else { throw CocoaError(.fileWriteInvalidFileName) }
        var value = self; value.customTitle = name.trimmingCharacters(in: .whitespacesAndNewlines); return value
    }
    public init(id: UUID = UUID(), title: String, fileName: String, lastPlayed: Date? = nil, added: Date = Date(), programID: String? = nil, artworkTitle: String? = nil, useConsoleBackground: Bool? = nil, platform: GamePlatform? = nil) {
        self.id = id; self.title = title; self.fileName = fileName
        self.lastPlayed = lastPlayed; self.added = added
        self.programID = programID; self.artworkTitle = artworkTitle; self.useConsoleBackground = useConsoleBackground
        self.platform = platform
    }
}

public enum ImportError: LocalizedError {
    case unsupported, invalidROM, unsafeFile, invalidSystemFolder, invalidMiiArchive, corruptCatalog, invalidPS1, invalidCue, invalidBIOS, invalidDOL, invalidGCDisc
    case invalidGCDiscDetail(String)
    public var errorDescription: String? {
        switch self {
        case .unsupported: return "Choose a decrypted 3DS game, or a PlayStation .chd, .cue with its .bin tracks, or PS-X .exe homebrew, or a GameCube .dol, .iso, .gcm or .ciso. For a PS1 disc with several tracks, select its folder or select the .cue and all referenced .bin files together."
        case .invalidPS1: return "This file is not a supported PlayStation CHD or PS-X executable. Choose an unmodified game dump you have the right to use."
        case .invalidDOL: return "This file is not a supported GameCube MEM1 homebrew DOL. GameCube support is still experimental."
        case .invalidGCDisc: return "Choose a valid GameCube .iso, .gcm or Dolphin-format .ciso file. Wii discs, PSP CSO files and other compressed formats are not supported by this importer."
        case .invalidGCDiscDetail(let reason): return "Couldn’t import this GameCube image. \(reason)"
        case .invalidCue: return "Select a folder containing one .cue and its .bin tracks, or select the .cue and all its .bin files together. Track names must be plain filenames, and every referenced track must be present."
        case .invalidBIOS: return "Choose an unmodified SCPH-5500, SCPH-5501 or SCPH-5502 BIOS dump from your PlayStation. The file must be 512 KB. No BIOS is included or downloaded by EmuDen."
        case .invalidROM: return "This file does not contain a recognized 3DS header. Choose an extracted, decrypted game or 3DS homebrew executable."
        case .unsafeFile: return "The selected folder contains a symbolic link or an unsupported file. Export a regular folder and try again."
        case .invalidSystemFolder: return "Choose the folder containing nand and/or sysdata from your own 3DS emulator user directory. The nand folder itself also works."
        case .invalidMiiArchive: return "This file doesn’t contain a complete, decrypted Mii resource archive. Choose a Mii resource archive you have the right to use. A saved Mii database (CFL_DB.dat) alone does not contain the face models."
        case .corruptCatalog: return "The game library could not be read. Your games have been preserved. Restore library.json before importing more games."
        }
    }
}

public struct MiiStatus: Equatable, Sendable {
    public let archiveFound: Bool
    public let databaseFound: Bool
    public var title: String { archiveFound ? "Original Mii faces ready" : "Using the guest face" }
    public var detail: String {
        archiveFound
        ? "Mii face resources are installed. After a new import, games start normally once so old resume points cannot restore the guest face. Your in-game saves are kept. A personal Mii database is separate; compatibility varies by game."
        : "Some games need Mii face models. Import an authorized Mii resource archive to replace the guest face. This supplies the models; it doesn’t create or choose your personal Mii."
    }
}

public struct LibraryStorage: Sendable {
    public let root: URL
    public var gamesDirectory: URL { root.appendingPathComponent("Games", isDirectory: true) }
    public var savesDirectory: URL { root.appendingPathComponent("Saves", isDirectory: true) }
    public var systemDirectory: URL { savesDirectory.appendingPathComponent("Azahar", isDirectory: true) }
    public var systemRevisionURL: URL { savesDirectory.appendingPathComponent(".system-resource-revision") }
    public var ps1BIOSDirectory: URL { savesDirectory.appendingPathComponent("PlayStation/BIOS", isDirectory: true) }
    public var ps1BIOSNames: [String] {
        ["scph5500.bin", "scph5501.bin", "scph5502.bin"].filter { FileManager.default.fileExists(atPath: ps1BIOSDirectory.appendingPathComponent($0).path) }
    }
    public init(root: URL) { self.root = root }
    public func prepare() throws {
        for url in [root, gamesDirectory, systemDirectory] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    public func prepareCoreUpgrade() throws {
        let marker = savesDirectory.appendingPathComponent(".core-generation")
        if (try? String(contentsOf: marker, encoding: .utf8)) == SaveStateStore.coreGeneration { return }
        let fm = FileManager.default
        let backup = savesDirectory.appendingPathComponent("Backups/Before-FastInterp", isDirectory: true)
        if fm.fileExists(atPath: backup.path), !fm.fileExists(atPath: backup.appendingPathComponent(".emuden-backup-complete").path) {
            throw CocoaError(.fileWriteFileExists)
        }
        if !fm.fileExists(atPath: backup.path), !(try fm.contentsOfDirectory(atPath: systemDirectory.path)).isEmpty {
            let staging = savesDirectory.appendingPathComponent(".core-backup-\(UUID().uuidString)")
            defer { try? fm.removeItem(at: staging) }
            try fm.copyItem(at: systemDirectory, to: staging)
            try Data("2126 backup".utf8).write(to: staging.appendingPathComponent(".emuden-backup-complete"), options: .atomic)
            try fm.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.moveItem(at: staging, to: backup)
        }
        try Data(SaveStateStore.coreGeneration.utf8).write(to: marker, options: .atomic)
    }
    public func read() throws -> [Game] {
        let url = root.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            var games = try JSONDecoder().decode([Game].self, from: Data(contentsOf: url))
            guard Set(games.map(\.id)).count == games.count else { throw ImportError.corruptCatalog }
            for game in games {
                let path = game.fileName
                guard !path.isEmpty, !path.contains("\\"), !path.contains("\0") else { throw ImportError.corruptCatalog }
                if game.console != .threeDS {
                    let extensions = game.console == .ps1 ? ["chd", "cue", "exe"] : ["dol", "iso", "gcm", "ciso"]
                    guard extensions.contains((path as NSString).pathExtension),
                          path == "\(game.id.uuidString)/disc.\((path as NSString).pathExtension)" else { throw ImportError.corruptCatalog }
                } else {
                    guard path == (path as NSString).lastPathComponent, path != ".", path != ".." else { throw ImportError.corruptCatalog }
                }
            }
            for i in games.indices where games[i].console == .threeDS && games[i].programID == nil && games[i].fileName == (games[i].fileName as NSString).lastPathComponent {
                games[i].programID = ThreeDSProgramID.read(gameURL(games[i]))
            }
            return games
        }
        catch { throw ImportError.corruptCatalog }
    }
    public func write(_ games: [Game]) throws {
        try JSONEncoder().encode(games).write(to: root.appendingPathComponent("library.json"), options: .atomic)
    }
    public func gameURL(_ game: Game) -> URL { gamesDirectory.appendingPathComponent(game.fileName) }
    public func importGame(_ source: URL, companions: [URL] = [], allowGameCube: Bool = false) throws -> Game {
        let ext = source.pathExtension.lowercased()
        if ["dol", "iso", "gcm", "ciso"].contains(ext), allowGameCube {
            if ext == "dol" { try GameCubeDOL.validate(source) } else { try GameCubeDisc.validate(source) }
            let id = UUID(), folder = gamesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
            var title = source.deletingPathExtension().lastPathComponent
            if ["iso", "gcm"].contains(ext), title.lowercased().hasSuffix(".nkit") { title = String(title.dropLast(5)) }
            let game = Game(id: id, title: title.replacingOccurrences(of: "_", with: " "), fileName: "\(id.uuidString)/disc.\(ext)", platform: .gamecube)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
                try FileManager.default.copyItem(at: source, to: gameURL(game))
            } catch { try? FileManager.default.removeItem(at: folder); throw error }
            return game
        }
        if ["chd", "cue", "exe"].contains(ext) { return try importPlayStation(source, companions: companions) }
        guard ["3ds", "cci", "cxi", "app", "3dsx", "elf", "axf"].contains(ext) else { throw ImportError.unsupported }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ImportError.unsafeFile }
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        let header = try handle.read(upToCount: 0x104) ?? Data()
        let magic = Array(header.prefix(4))
        let containerMagic = String(data: header.dropFirst(0x100).prefix(4), encoding: .ascii)
        guard magic == Array("3DSX".utf8) || magic == [0x7f, 0x45, 0x4c, 0x46] || containerMagic == "NCSD" || containerMagic == "NCCH" else { throw ImportError.invalidROM }
        let id = UUID()
        let game = Game(id: id, title: source.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " "), fileName: "\(id.uuidString).\(ext)", programID: ThreeDSProgramID.read(source))
        do { try FileManager.default.copyItem(at: source, to: gameURL(game)) }
        catch { try? FileManager.default.removeItem(at: gameURL(game)); throw error }
        return game
    }
    public func importBatch(_ sources: [URL], allowGameCube: Bool = false) throws -> [Game] {
        let fm = FileManager.default
        var inputs = [URL]()
        for source in sources {
            let values = try source.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true else { throw ImportError.unsafeFile }
            if values.isDirectory == true {
                let children = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
                let cues = children.filter { $0.pathExtension.lowercased() == "cue" }
                guard cues.count == 1 else { throw ImportError.invalidCue }
                let cue = try PlayStationCue(url: cues[0])
                inputs.append(cues[0])
                inputs += cue.files.map { source.appendingPathComponent($0) }
            } else { inputs.append(source) }
        }
        let cues = try inputs.filter { $0.pathExtension.lowercased() == "cue" }.map { try PlayStationCue(url: $0) }
        let trackNames = Set(cues.flatMap(\.files))
        let games = inputs.filter { !(trackNames.contains($0.lastPathComponent) && $0.pathExtension.lowercased() == "bin") }
        var imported = [Game]()
        do {
            for source in games { imported.append(try importGame(source, companions: inputs, allowGameCube: allowGameCube)) }
            return imported
        } catch {
            for game in imported { try? fm.removeItem(at: gameAssetsURL(game)) }
            throw error
        }
    }
    public func gameAssetsURL(_ game: Game) -> URL {
        game.console == .threeDS ? gameURL(game) : gameURL(game).deletingLastPathComponent()
    }
    public func deleteGame(id: UUID) throws -> [Game] {
        let fm = FileManager.default
        let games = try read()
        guard let game = games.first(where: { $0.id == id }) else { return games }
        for folder in [root, gamesDirectory, gameAssetsURL(game)] where fm.fileExists(atPath: folder.path) {
            guard try folder.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw ImportError.unsafeFile }
        }
        let asset = gameAssetsURL(game)
        let staging = gamesDirectory.appendingPathComponent(".delete-\(UUID().uuidString)")
        let moved = !games.contains { $0.id != id && gameAssetsURL($0) == asset } && fm.fileExists(atPath: asset.path)
        if moved { try fm.moveItem(at: asset, to: staging) }
        let remaining = games.filter { $0.id != id }
        do { try write(remaining) }
        catch {
            if moved { try fm.moveItem(at: staging, to: asset) }
            throw error
        }
        if moved { try fm.removeItem(at: staging) }
        return remaining
    }
    public func nativeSaveDirectory(_ game: Game) -> URL {
        switch game.console {
        case .threeDS: systemDirectory
        case .ps1: savesDirectory.appendingPathComponent("PlayStation/\(game.id.uuidString)", isDirectory: true)
        case .gamecube: savesDirectory.appendingPathComponent("GameCube/\(game.id.uuidString)", isDirectory: true)
        }
    }
    public func importPS1BIOS(_ source: URL) throws {
        let v = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard v.isRegularFile == true, v.isSymbolicLink != true, v.fileSize == 524288 else { throw ImportError.invalidBIOS }
        let data = try Data(contentsOf: source)
        guard data.count == 524288 else { throw ImportError.invalidBIOS }
        let hashes = ["8dd7d5296a650fac7319bce665a6a53c": "scph5500.bin", "490f666e1afb15b7362b406ed1cea246": "scph5501.bin", "32736f17079d0b2b7024407c39bd3050": "scph5502.bin"]
        let hash = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard let name = hashes[hash] else { throw ImportError.invalidBIOS }
        let fm = FileManager.default
        for folder in [savesDirectory, ps1BIOSDirectory.deletingLastPathComponent(), ps1BIOSDirectory] {
            if fm.fileExists(atPath: folder.path) {
                let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values.isDirectory == true, values.isSymbolicLink != true else { throw ImportError.unsafeFile }
            }
        }
        try fm.createDirectory(at: ps1BIOSDirectory, withIntermediateDirectories: true)
        let destination = ps1BIOSDirectory.appendingPathComponent(name)
        guard (try? destination.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink != true else { throw ImportError.unsafeFile }
        if (try? Data(contentsOf: destination)) == data { return }
        // A fresh epoch keeps HLE snapshots separate; native memory cards stay in place.
        try Data(UUID().uuidString.utf8).write(to: savesDirectory.appendingPathComponent("PlayStation/.bios-revision"), options: .atomic)
        try data.write(to: destination, options: .atomic)
    }
    private func importPlayStation(_ source: URL, companions: [URL]) throws -> Game {
        let fm = FileManager.default, ext = source.pathExtension.lowercased()
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ImportError.unsafeFile }
        let file = try FileHandle(forReadingFrom: source)
        defer { try? file.close() }
        let header = try file.read(upToCount: 0x800) ?? Data()
        if ext == "chd" {
            guard header.count >= 124, header.starts(with: Data("MComprHD".utf8)),
                  header[12..<16].elementsEqual([0, 0, 0, 5]) else { throw ImportError.invalidPS1 }
        } else if ext == "exe" {
            func word(_ offset: Int) -> UInt32 { (0..<4).reduce(0) { $0 | UInt32(header[offset + $1]) << ($1 * 8) } }
            guard header.count == 0x800, header.starts(with: Data("PS-X EXE".utf8)),
                  let size = values.fileSize, size > 0x800, size <= 2 * 1024 * 1024 + 0x800,
                  word(0x18) >= 0x80000000, word(0x18) < 0x80200000,
                  word(0x1c) > 0, UInt64(word(0x18)) + UInt64(word(0x1c)) <= 0x80200000,
                  word(0x10) >= word(0x18), UInt64(word(0x10)) < UInt64(word(0x18)) + UInt64(word(0x1c)),
                  Int(word(0x1c)) <= size - 0x800 else { throw ImportError.invalidPS1 }
        }
        let cue = ext == "cue" ? try PlayStationCue(url: source) : nil
        var tracks = [URL]()
        for name in cue?.files ?? [] {
            let matches = Set(companions.filter { $0.lastPathComponent == name })
            guard matches.count == 1, let track = matches.first else { throw ImportError.invalidCue }
            let v = try track.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard v.isRegularFile == true, v.isSymbolicLink != true, let size = v.fileSize, size > 0 else { throw ImportError.unsafeFile }
            tracks.append(track)
        }
        let id = UUID(), folder = gamesDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        let game = Game(id: id, title: source.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " "),
                        fileName: "\(id.uuidString)/disc.\(ext)", platform: .ps1)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: false)
            try fm.copyItem(at: source, to: gameURL(game))
            for track in tracks { try fm.copyItem(at: track, to: folder.appendingPathComponent(track.lastPathComponent)) }
        } catch { try? fm.removeItem(at: folder); throw error }
        return game
    }
    public func inspectMii() -> MiiStatus {
        let fm = FileManager.default
        let nand = systemDirectory.appendingPathComponent("nand")
        var archive = false, database = false
        guard let walker = fm.enumerator(at: nand, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]) else {
            return MiiStatus(archiveFound: false, databaseFound: false)
        }
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]), values.isSymbolicLink != true else { walker.skipDescendants(); continue }
            guard values.isRegularFile == true else { continue }
            if url.lastPathComponent.lowercased() == "cfl_db.dat" { database = true }
            let components = url.pathComponents.map { $0.lowercased() }
            guard components.contains("0004009b"), components.contains("00010202"), components.contains("content"), url.pathExtension.lowercased() == "app" else { continue }
            if let size = values.fileSize, size <= 32 * 1024 * 1024,
               let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               (try? Self.miiArchive(in: data)) != nil { archive = true }
        }
        return MiiStatus(archiveFound: archive, databaseFound: database)
    }
    public func importMiiArchive(_ source: URL) throws {
        let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ImportError.unsafeFile }
        guard let size = values.fileSize, (0x200...32 * 1024 * 1024).contains(size) else { throw ImportError.invalidMiiArchive }
        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        guard data.count <= 32 * 1024 * 1024 else { throw ImportError.invalidMiiArchive }
        let archive = try Self.miiArchive(in: data)
        let folder = systemDirectory.appendingPathComponent("nand/00000000000000000000000000000000/title/0004009b/00010202/content", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("00000000.app")
        let staging = folder.appendingPathComponent(".mii-import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        try archive.write(to: staging, options: .atomic)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: staging)
        } else { try FileManager.default.moveItem(at: staging, to: destination) }
        try markSystemResourcesChanged()
    }
    private static func miiArchive(in data: Data) throws -> Data {
        func validated(at start: Int) -> Data? {
            guard start >= 0, start <= data.count - 0x200 else { return nil }
            func units(_ offset: Int) -> UInt64 {
                (0..<4).reduce(UInt64(0)) { $0 | UInt64(data[start + offset + $1]) << (8 * $1) } * 512
            }
            let size = units(0x104), romfsOffset = units(0x1b0), romfsSize = units(0x1b4)
            guard data.subdata(in: start + 0x100..<start + 0x104) == Data("NCCH".utf8),
                  Array(data[start + 0x118..<start + 0x120]) == [0x02, 0x02, 0x01, 0x00, 0x9b, 0x00, 0x04, 0x00],
                  data[start + 0x18f] & 4 != 0, size >= 0x200, size <= UInt64(data.count - start),
                  romfsOffset >= 0x200, romfsSize > 0, romfsOffset + romfsSize <= size else { return nil }
            return data.subdata(in: start..<start + Int(size))
        }
        if data.prefix(4) != Data("3DSX".utf8) {
            guard let archive = validated(at: 0) else { throw ImportError.invalidMiiArchive }
            return archive
        }
        // Read only the requested data container; never execute the supplied installer.
        var searchStart = 0, found: Data?
        while searchStart < data.count,
              let range = data.range(of: Data("NCCH".utf8), in: searchStart..<data.count) {
            if let candidate = validated(at: range.lowerBound - 0x100) {
                guard found == nil else { throw ImportError.invalidMiiArchive }
                found = candidate
            }
            searchStart = range.upperBound
        }
        guard let found else { throw ImportError.invalidMiiArchive }
        return found
    }
    private func markSystemResourcesChanged() throws {
        try Data(UUID().uuidString.utf8).write(to: systemRevisionURL, options: .atomic)
    }
    public func importSystemData(_ source: URL) throws {
        let fm = FileManager.default
        let names = ["nand", "sysdata"]
        let selectedName = source.lastPathComponent.lowercased()
        let inputs: [(String, URL)] = names.compactMap { name in
            let url = selectedName == name ? source : source.appendingPathComponent(name)
            var directory: ObjCBool = false
            return fm.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue ? (name, url) : nil
        }
        guard !inputs.isEmpty else { throw ImportError.invalidSystemFolder }
        let staging = root.appendingPathComponent("SystemImport-\(UUID().uuidString)")
        let backup = root.appendingPathComponent("SystemBackup-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        // Stage a merged copy before moving anything in the active data directory.
        for name in names {
            let existing = systemDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: existing.path) { try Self.merge(existing, into: staging.appendingPathComponent(name)) }
        }
        for (name, input) in inputs { try Self.merge(input, into: staging.appendingPathComponent(name)) }
        try fm.createDirectory(at: backup, withIntermediateDirectories: true)
        var movedOld = [String](), movedNew = [String]()
        do {
            for name in names where fm.fileExists(atPath: staging.appendingPathComponent(name).path) {
                let destination = systemDirectory.appendingPathComponent(name)
                if fm.fileExists(atPath: destination.path) {
                    try fm.moveItem(at: destination, to: backup.appendingPathComponent(name)); movedOld.append(name)
                }
                try fm.moveItem(at: staging.appendingPathComponent(name), to: destination); movedNew.append(name)
            }
        } catch {
            for name in movedNew { try? fm.removeItem(at: systemDirectory.appendingPathComponent(name)) }
            for name in movedOld { try? fm.moveItem(at: backup.appendingPathComponent(name), to: systemDirectory.appendingPathComponent(name)) }
            // Keep the backup if rollback failed; never discard the last copy of user data.
            throw error
        }
        try? fm.removeItem(at: backup)
        try markSystemResourcesChanged()
    }
    private static func merge(_ source: URL, into destination: URL) throws {
        let fm = FileManager.default
        let values = try source.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey])
        guard values.isSymbolicLink != true else { throw ImportError.unsafeFile }
        if values.isDirectory == true {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            for child in try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
                try merge(child, into: destination.appendingPathComponent(child.lastPathComponent))
            }
        } else if values.isRegularFile == true {
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            try fm.copyItem(at: source, to: destination)
        } else { throw ImportError.unsafeFile }
    }
}
