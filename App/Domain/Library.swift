import Foundation

public struct Game: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public let fileName: String
    public var lastPlayed: Date?
    public let added: Date
    public var programID: String?
    public var artworkTitle: String?
    public var useConsoleBackground: Bool?
    public var system: String { "Nintendo 3DS" }
    public init(id: UUID = UUID(), title: String, fileName: String, lastPlayed: Date? = nil, added: Date = Date(), programID: String? = nil, artworkTitle: String? = nil, useConsoleBackground: Bool? = nil) {
        self.id = id; self.title = title; self.fileName = fileName
        self.lastPlayed = lastPlayed; self.added = added
        self.programID = programID; self.artworkTitle = artworkTitle; self.useConsoleBackground = useConsoleBackground
    }
}

public enum ImportError: LocalizedError {
    case unsupported, invalidROM, unsafeFile, invalidSystemFolder, invalidMiiArchive, corruptCatalog
    public var errorDescription: String? {
        switch self {
        case .unsupported: return "Choose a decrypted .3ds, .cci, .cxi, .app, .3dsx or .elf game. CIA installation is not included in this build."
        case .invalidROM: return "This file does not contain a recognized 3DS header. Choose an extracted, decrypted game or 3DS homebrew executable."
        case .unsafeFile: return "The selected folder contains a symbolic link or an unsupported file. Export a regular folder and try again."
        case .invalidSystemFolder: return "Choose the folder containing nand and/or sysdata from your own 3DS emulator user directory. The nand folder itself also works."
        case .invalidMiiArchive: return "This file doesn’t contain a complete, decrypted Mii resource archive. Choose your Mii .app archive or a resource installer such as errfix.3dsx. A saved Mii database (CFL_DB.dat) alone does not contain the face models."
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
        : "Some games need Mii face models. Import a Mii .app archive or errfix.3dsx below to replace the guest face. This supplies the models; it doesn’t create or choose your personal Mii."
    }
}

public struct LibraryStorage: Sendable {
    public let root: URL
    public var gamesDirectory: URL { root.appendingPathComponent("Games", isDirectory: true) }
    public var savesDirectory: URL { root.appendingPathComponent("Saves", isDirectory: true) }
    public var systemDirectory: URL { savesDirectory.appendingPathComponent("Azahar", isDirectory: true) }
    public var systemRevisionURL: URL { savesDirectory.appendingPathComponent(".system-resource-revision") }
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
            for i in games.indices where games[i].programID == nil && games[i].fileName == (games[i].fileName as NSString).lastPathComponent {
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
    public func importGame(_ source: URL) throws -> Game {
        let ext = source.pathExtension.lowercased()
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
