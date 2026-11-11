// Normalize the original glass EmuDen artwork to an opaque 1024px App Store icon.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let master = root.appendingPathComponent("Docs/Branding/EmuDen-Icon-Master.png")
let output = CommandLine.arguments.dropFirst().first
    ?? root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png").path
guard let source = CGImageSourceCreateWithURL(master as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil), image.width == image.height else {
    fatalError("Missing square icon master: \(master.path)")
}
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .high
context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let url = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination), "Could not write app icon")
print("Exported opaque EmuDen icon: \(output)")
