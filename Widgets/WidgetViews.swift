import SwiftUI
import WidgetKit
import ImageIO

struct EmuDenWidgetContent: View {
    let library: WidgetLibrary
    let directory: URL?
    var recent = false
    var compact = false
    var fullColor = true
    private var foreground: Color { fullColor ? .white : .primary }
    var body: some View {
        GeometryReader { area in
            ZStack(alignment: .topLeading) {
                if fullColor {
                    Color(red: 0.025, green: 0.045, blue: 0.09)
                    if !recent, let game = library.games.first { artwork(game, scene: true).frame(width: area.size.width, height: area.size.height).clipped() }
                    LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.15), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                    LinearGradient(colors: [.black.opacity(0.62), .clear], startPoint: .leading, endPoint: .trailing)
                }
                VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller").widgetAccentable()
                        Text("EmuDen").fontWeight(.semibold)
                        Spacer(minLength: 2)
                        if !compact { Text(recent ? "RECENT" : "JUMP BACK IN").font(.system(size: 8, weight: .semibold)).tracking(1.5).opacity(0.65) }
                    }.font(.system(size: 11, weight: .medium))
                    if library.games.isEmpty {
                        Spacer(minLength: 0)
                        Image(systemName: "rectangle.split.1x2").font(.system(size: 28, weight: .light)).widgetAccentable()
                        Text("Ready, player one.").font(.system(size: compact ? 17 : 22, weight: .semibold))
                        Text("Open EmuDen to add your games.").font(.caption).opacity(0.75)
                        Spacer(minLength: 0)
                    } else if recent {
                        if area.size.height > 260, let game = library.games.first {
                            Link(destination: game.link) {
                                ZStack(alignment: .bottomLeading) {
                                    artwork(game, scene: true)
                                    LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                                    Label(game.title, systemImage: "play.fill").font(.system(size: 14, weight: .semibold)).lineLimit(2).padding(12).foregroundStyle(.white)
                                }.frame(width: area.size.width - 34, height: area.size.height * 0.35).clipped().clipShape(RoundedRectangle(cornerRadius: 17))
                            }
                        }
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(Array(library.games.prefix(area.size.height > 260 ? 4 : 3))) { game in
                                let count = min(library.games.count, area.size.height > 260 ? 4 : 3)
                                let cardWidth = max(1, (area.size.width - 34 - CGFloat(max(0, count - 1)) * 10) / CGFloat(max(1, count)))
                                Link(destination: game.link) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        artwork(game).frame(width: cardWidth, height: max(45, area.size.height > 260 ? area.size.height * 0.30 : area.size.height - 75))
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(foreground.opacity(0.15), lineWidth: 1) }
                                        Text(game.title).font(.system(size: 10, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                                    }.frame(width: cardWidth, alignment: .leading)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    } else if let game = library.games.first {
                        Spacer(minLength: 0)
                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("NINTENDO 3DS").font(.system(size: 8, weight: .medium)).tracking(1.5).opacity(0.72)
                                Text(game.title).font(.system(size: compact ? 16 : 21, weight: .semibold)).lineLimit(compact ? 3 : 2).minimumScaleFactor(0.85)
                                Label("Play", systemImage: "play.fill").font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(foreground.opacity(fullColor ? 0.16 : 0.12), in: Capsule()).widgetAccentable()
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            if !compact { artwork(game).frame(width: 65, height: 88).clipShape(RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(4)).shadow(color: .black.opacity(0.25), radius: 9, y: 5) }
                        }
                    }
                }.frame(width: max(1, area.size.width - (compact ? 30 : 34)), alignment: .leading).padding(compact ? 15 : 17)
            }.foregroundStyle(foreground).frame(width: area.size.width, height: area.size.height).clipped()
        }.accessibilityElement(children: recent ? .contain : .combine)
    }
    @ViewBuilder private func artwork(_ game: WidgetGame, scene: Bool = false) -> some View {
        if let directory, let image = Self.image(game.imageURL(in: directory, scene: scene)) {
            Image(uiImage: image).resizable().widgetAccentedRenderingMode(.fullColor).scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: fullColor ? [Color(red: 0.12, green: 0.26, blue: 0.42), Color(red: 0.025, green: 0.06, blue: 0.13)] : [.clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "gamecontroller").font(.system(size: 25, weight: .light)).foregroundStyle(foreground.opacity(0.6)).widgetAccentable()
            }
        }
    }
    private static func image(_ url: URL) -> UIImage? {
        guard let v = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              v.isRegularFile == true, v.isSymbolicLink != true, let bytes = v.fileSize, (1...768 * 1024).contains(bytes),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = p[kCGImagePropertyPixelWidth] as? Int, let h = p[kCGImagePropertyPixelHeight] as? Int,
              (1...1024).contains(w), (1...1024).contains(h),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 512, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}
