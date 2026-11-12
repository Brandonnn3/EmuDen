import Foundation
import ImageIO
import CoreGraphics

// Lossless opaque PNG exports of actual Simulator captures, without rescaling.
let input = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let rows = try JSONSerialization.jsonObject(with: Data(contentsOf: input.appendingPathComponent("manifest.json"))) as! [[String: Any]]
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var exported = [[String: Any]]()
for row in rows {
    for attachment in row["attachments"] as! [[String: Any]] {
        let file = attachment["exportedFileName"] as! String
        guard file.hasSuffix(".png") else { continue }
        let title = attachment["suggestedHumanReadableName"] as! String
        let name: String
        if title.contains("Library with licensed homebrew") { name = "01-library.png" }
        else if title.contains("Console layout and screen options") { name = "02-console-layout.png" }
        else if title.contains("Homebrew play and save controls") { name = "03-play-and-saves.png" }
        else { continue }
        let source = CGImageSourceCreateWithURL(input.appendingPathComponent(file) as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let space = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        precondition(space.model == .rgb)
        let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                bytesPerRow: image.width * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let target = output.appendingPathComponent(name)
        let dest = CGImageDestinationCreateWithURL(target as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(dest))
        let bytes = try Data(contentsOf: target)
        precondition(bytes[25] == 2, "App Store requires RGB PNG without alpha")
        exported.append(["file": name, "rawFile": file, "title": title, "width": image.width,
                         "height": image.height, "device": attachment["deviceId"]!, "rescaled": false,
                         "content": "Actual app and licensed Homebrew Menu; no commercial ROM artwork"])
    }
}
precondition(!exported.isEmpty)
let data = try JSONSerialization.data(withJSONObject: exported, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("captures.json"))
print("Exported \(exported.count) opaque screenshots at original pixel dimensions.")
