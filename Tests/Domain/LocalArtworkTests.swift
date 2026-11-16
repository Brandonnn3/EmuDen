import XCTest
import CryptoKit
@testable import EmulatorDomain

final class LocalArtworkTests: XCTestCase {
    func testChangedCatalogImagesRefreshWhileCurrentAndManualImagesAreKept() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID(), old = Data("old cover".utf8), fresh = Data("new cover".utf8)
        let file = directory.appendingPathComponent(id.uuidString + ".catalog.jpg")
        let digest = SHA256.hash(data: fresh).map { String(format: "%02x", $0) }.joined()
        let asset = ArtworkPackAsset(path: "images/homebrew/cover-\(digest.prefix(12)).jpg", sha256: digest,
                                     bytes: fresh.count, width: 1024, height: 1536)
        XCTAssertFalse(LocalArtworkFiles.hasCurrentOrCustomImage(for: id, matching: asset, in: directory))
        try old.write(to: file)
        XCTAssertFalse(LocalArtworkFiles.hasCurrentOrCustomImage(for: id, matching: asset, in: directory), "Same-size old artwork must not hide an update")
        XCTAssertEqual(try Data(contentsOf: file), old, "Checking an update must retain the offline fallback")
        try fresh.write(to: file)
        XCTAssertTrue(LocalArtworkFiles.hasCurrentOrCustomImage(for: id, matching: asset, in: directory))
        try FileManager.default.removeItem(at: file)
        let target = directory.appendingPathComponent("target.jpg"); try fresh.write(to: target)
        try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
        XCTAssertFalse(LocalArtworkFiles.hasCurrentOrCustomImage(for: id, matching: asset, in: directory))
        try FileManager.default.removeItem(at: file)
        try Data(repeating: 0, count: 4 * 1024 * 1024 + 1).write(to: file)
        XCTAssertFalse(LocalArtworkFiles.hasCurrentOrCustomImage(for: id, matching: asset, in: directory))
        try Data().write(to: directory.appendingPathComponent(id.uuidString + ".custom"))
        try old.write(to: directory.appendingPathComponent(id.uuidString + ".user.png"))
        XCTAssertTrue(LocalArtworkFiles.hasCurrentOrCustomImage(for: id, matching: asset, in: directory), "A manual choice made during download must win")
    }
    func testOldDownloadedImagesAreIgnoredAndExplicitImportsSurvive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let old = directory.appendingPathComponent(id.uuidString + ".png")
        let marker = directory.appendingPathComponent(id.uuidString + ".custom")
        let chosen = directory.appendingPathComponent(id.uuidString + ".user.png")
        try Data([1]).write(to: old)
        XCTAssertNil(LocalArtworkFiles.customImage(for: id, in: directory))
        XCTAssertTrue(FileManager.default.fileExists(atPath: old.path))
        try Data().write(to: marker)
        XCTAssertEqual(LocalArtworkFiles.customImage(for: id, in: directory), old)
        try Data([2]).write(to: chosen)
        XCTAssertEqual(LocalArtworkFiles.customImage(for: id, in: directory), chosen)
        try FileManager.default.removeItem(at: marker)
        try FileManager.default.createSymbolicLink(at: marker, withDestinationURL: chosen)
        XCTAssertNil(LocalArtworkFiles.customImage(for: id, in: directory))
    }
}
