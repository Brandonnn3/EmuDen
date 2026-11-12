import SwiftUI

enum ArtworkResources {
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
        guard let url = Bundle.main.url(forResource: "Console-" + system.rawValue, withExtension: "png", subdirectory: "CinematicArt"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
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
