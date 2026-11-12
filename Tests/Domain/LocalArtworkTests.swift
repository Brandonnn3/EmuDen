import XCTest
@testable import EmulatorDomain

final class LocalArtworkTests: XCTestCase {
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
