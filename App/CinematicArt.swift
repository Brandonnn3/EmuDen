import SwiftUI

enum ArtworkResources {
    static let catalog: RemoteArtworkCatalog? = {
        guard let url = Bundle.main.url(forResource: "Artwork-Pack", withExtension: "json", subdirectory: "CinematicArt"),
              let data = try? Data(contentsOf: url), let pack = try? JSONDecoder().decode(ArtworkPack.self, from: data),
              let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 2; config.timeoutIntervalForResource = 20
        return RemoteArtworkCatalog(seed: pack, directory: caches.appendingPathComponent("EmuDenArtwork", isDirectory: true), session: URLSession(configuration: config))
    }()
    static let covers: ArtworkCatalog = {
        guard let url = Bundle.main.url(forResource: "3ds-artwork-index", withExtension: "json"), let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(ArtworkCatalog.self, from: data) else { return ArtworkCatalog(files: []) }
        return catalog
    }()
    static let identities: ArtworkIdentityCatalog = {
        guard let url = Bundle.main.url(forResource: "Title-IDs", withExtension: "json", subdirectory: "CinematicArt"),
              let data = try? Data(contentsOf: url), let titles = try? JSONDecoder().decode([String: String].self, from: data) else { return ArtworkIdentityCatalog(titles: [:]) }
        return ArtworkIdentityCatalog(titles: titles)
    }()
    private static let consoleCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>(); cache.countLimit = 2; return cache
    }()
    static func consoleImage(_ system: ConsoleSystem) -> UIImage? {
        let key = system.rawValue as NSString
        if let image = consoleCache.object(forKey: key) { return image }
        guard let image = CinematicArt.image("Console-" + system.rawValue) else { return nil }
        consoleCache.setObject(image, forKey: key)
        return image
    }
}

extension Game {
    var artworkName: String { ArtworkResources.identities.name(for: self, covers: ArtworkResources.covers) }
}

struct ConsoleSceneBackground: View {
    var system: ConsoleSystem = .threeDS
    var body: some View {
        GeometryReader { area in
            if let image = ArtworkResources.consoleImage(system) {
                ZStack(alignment: .top) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: area.size.width, height: area.size.height).clipped().blur(radius: 28)
                    Image(uiImage: image).resizable().aspectRatio(contentMode: area.size.height > area.size.width ? .fit : .fill)
                        .frame(width: area.size.width, height: area.size.height, alignment: .top).clipped()
                }.frame(width: area.size.width, height: area.size.height).clipped()
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Illustration regions from the exact approved Option A artwork. UI is always native.
enum CinematicArt: Int, CaseIterable {
    case golf, zelda, animalCrossing, darkMoon
    var hasHero: Bool { self == .golf || self == .zelda }
    private static let names = ["Mario Golf - World Tour.png", "Legend of Zelda, The - Ocarina of Time 3D.png", "Animal Crossing - New Leaf.png", "Luigi's Mansion - Dark Moon.png"]
    private static let catalog = ArtworkCatalog(files: names)
    static func match(_ title: String) -> Self? {
        guard let name = catalog.match(title), let index = names.firstIndex(of: name) else { return nil }
        return Self(rawValue: index)
    }
    var wideRegion: CGRect {
        [CGRect(x: 53, y: 603, width: 343, height: 248), CGRect(x: 422, y: 603, width: 316, height: 248),
         CGRect(x: 766, y: 603, width: 320, height: 248), CGRect(x: 1116, y: 603, width: 328, height: 248)][rawValue]
    }
    var portraitRegion: CGRect {
        [CGRect(x: 39, y: 949, width: 244, height: 341), CGRect(x: 304, y: 955, width: 218, height: 331),
         CGRect(x: 544, y: 955, width: 213, height: 331), CGRect(x: 782, y: 955, width: 218, height: 331)][rawValue]
    }
    static func image(_ name: String) -> UIImage? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "CinematicArt").flatMap { UIImage(contentsOfFile: $0.path) }
    }
    static let wideSheet = image("Approved-A-Wide")
    static let portraitSheet = image("Approved-A-Portrait")
    static let golfScene = image("Golf-Scene-Wide")
    static let forestScene = image("Forest-Scene-Wide")
}

struct ApprovedCoverArt: View {
    let art: CinematicArt
    var wide = false
    var body: some View {
        ArtworkRegion(image: wide ? CinematicArt.wideSheet : CinematicArt.portraitSheet,
                      sourceSize: wide ? CGSize(width: 1495, height: 1052) : CGSize(width: 1024, height: 1536),
                      region: wide ? art.wideRegion : art.portraitRegion)
    }
}

// Sampling illustration regions avoids changing the approved images or rendering baked UI.
struct ArtworkRegion: View {
    let image: UIImage?
    let sourceSize: CGSize
    let region: CGRect
    var alignment: UnitPoint = .center
    var body: some View {
        Canvas { context, size in
            if let image {
                let scale = max(size.width / region.width, size.height / region.height)
                let destination = CGRect(x: -region.minX * scale - (region.width * scale - size.width) * alignment.x,
                                         y: -region.minY * scale - (region.height * scale - size.height) * alignment.y,
                                         width: sourceSize.width * scale, height: sourceSize.height * scale)
                context.clip(to: Path(CGRect(origin: .zero, size: size)))
                context.draw(Image(uiImage: image), in: destination)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct ApprovedHeroArt: View {
    let art: CinematicArt
    var body: some View {
        GeometryReader { area in
            let portrait = area.size.height > area.size.width * 1.1
            ZStack(alignment: .top) {
                if art == .animalCrossing || art == .darkMoon {
                    ArtworkRegion(image: CinematicArt.portraitSheet, sourceSize: CGSize(width: 1024, height: 1536),
                                  region: art == .animalCrossing ? CGRect(x: 544, y: 1060, width: 213, height: 226) : CGRect(x: 782, y: 1035, width: 218, height: 250))
                } else if let image = art == .golf ? CinematicArt.golfScene : CinematicArt.forestScene {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: area.size.width, height: area.size.height).clipped()
                }
                if portrait, art == .golf {
                    let scale = area.size.width / 1024
                    ArtworkRegion(image: CinematicArt.portraitSheet, sourceSize: CGSize(width: 1024, height: 1536),
                                  region: CGRect(x: 0, y: 112, width: 1024, height: 490))
                        .frame(height: 490 * scale).padding(.top, 112 * scale)
                        .mask {
                            VStack(spacing: 0) {
                                Color.clear.frame(height: 112 * scale)
                                LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.05),
                                                       .init(color: .white, location: 0.90), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                                    .frame(height: 490 * scale)
                                    .overlay(alignment: .topLeading) {
                                        // Exclude the concept's baked labels while preserving the golfer's feet and club.
                                        ZStack {
                                            Path(CGRect(x: -24 * scale, y: 412 * scale, width: 318 * scale, height: 102 * scale))
                                                .fill(.black).blur(radius: 12 * scale)
                                            Path { path in
                                                path.addRect(CGRect(x: 0, y: 436 * scale, width: 270 * scale, height: 54 * scale))
                                                path.addRect(CGRect(x: 0, y: 478 * scale, width: 500 * scale, height: 12 * scale))
                                            }.fill(.black)
                                        }.compositingGroup().blendMode(.destinationOut)
                                    }.compositingGroup()
                                Spacer(minLength: 0)
                            }
                        }
                }
            }.frame(width: area.size.width, height: area.size.height).clipped()
        }.accessibilityHidden(true)
    }
}
