// Simulator-only original images exercise the real importer without a public host.
#if DEBUG && targetEnvironment(simulator)
import Foundation
import UIKit
import CryptoKit

final class ArtworkCatalogQAProtocol: URLProtocol, @unchecked Sendable {
    private static let responses: [String: Data] = {
        var files = [String: Data](), games = [[String: Any]](), consoleGames = [[String: Any]]()
        for index in 1...4 {
            let key = "catalog-homebrew-\(index)"
            var entry: [String: Any] = ["key": key, "title": "Catalog Homebrew \(index)", "aliases": [], "programIDs": [String(format: "000400000012%02X00", 0x33 + index)]]
            for kind in ["cover", "scene"] {
                let size = kind == "cover" ? CGSize(width: 1024, height: 1536) : CGSize(width: 1536, height: 1024)
                let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                    UIColor(red: index == 1 ? 0.16 : (index == 2 ? 0.45 : CGFloat(index) * 0.2), green: 0.3, blue: 0.65, alpha: 1).setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    UIColor.white.setFill(); context.fill(CGRect(x: size.width * 0.55, y: 160, width: 220, height: 480))
                }
                let data = image.jpegData(compressionQuality: 0.85)!
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                let path = "images/\(key)/\(kind)-\(digest.prefix(12)).jpg"
                files["/" + path] = data
                entry[kind] = ["path": path, "sha256": digest, "bytes": data.count, "width": Int(size.width), "height": Int(size.height)]
            }
            if index <= 2 { games.append(entry) }
            else {
                entry["platform"] = index == 3 ? "ps1" : "gamecube"
                entry["programIDs"] = [] as [String]
                consoleGames.append(entry)
            }
        }
        files["/catalog.json"] = try! JSONSerialization.data(withJSONObject: ["schema": 1, "version": 1, "baseURL": "https://artwork-test.example/", "games": games, "consoleGames": consoleGames])
        for (index, title) in ["Mario Golf: World Tour", "Detective Pikachu", "Kingdom Hearts 3D: Dream Drop Distance", "WarioWare Gold", "Dragon Ball Fusions"].enumerated() {
            guard let name = ArtworkResources.covers.match(title) else { continue }
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            let image = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 456), format: format).image { context in
                UIColor(red: CGFloat(index + 1) * 0.13, green: 0.3, blue: 0.6, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 512, height: 456))
                UIColor.white.setFill(); context.fill(CGRect(x: 466, y: 0, width: 46, height: 456))
            }
            files["/Named_Boxarts/" + name] = image.pngData()!
        }
        return files
    }()
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "artwork-test.example" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if ProcessInfo.processInfo.environment["EMUDEN_TEST_ARTWORK_OFFLINE"] == "1" {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)); return
        }
        guard let url = request.url else { return }
        let data = Self.responses[url.path]
        let response = HTTPURLResponse(url: url, statusCode: data == nil ? 404 : 200, httpVersion: nil,
                                       headerFields: ["Content-Length": String(data?.count ?? 0)])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}
#endif
