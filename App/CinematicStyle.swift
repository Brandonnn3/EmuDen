import SwiftUI

enum ConsoleMotion {
    static func response(_ reduced: Bool) -> Animation? { reduced ? nil : .spring(response: 0.42, dampingFraction: 0.86) }
    static func scene(_ reduced: Bool) -> Animation? { reduced ? nil : .easeInOut(duration: 0.38) }
}

struct ConsolePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.965 : 1)
            .brightness(configuration.isPressed ? 0.035 : 0)
            .opacity(enabled ? 1 : 0.4)
            .animation(ConsoleMotion.response(reduceMotion), value: configuration.isPressed)
    }
}

private struct CinematicGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let radius: CGFloat
    let interactive: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: radius))
                .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.22), lineWidth: 1) }
        } else if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .clear.interactive() : .clear, in: RoundedRectangle(cornerRadius: radius))
                .overlay {
                    RoundedRectangle(cornerRadius: radius).strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.15), .white.opacity(0.12), .white.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                        .allowsHitTesting(false)
                }
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay { RoundedRectangle(cornerRadius: radius).strokeBorder(.white.opacity(0.18), lineWidth: 1) }
        }
    }
}

struct CinematicGlassGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @ViewBuilder var body: some View {
        if #available(iOS 26.0, *) { GlassEffectContainer(spacing: 12, content: content) }
        else { content() }
    }
}

private struct CinematicEntrance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let delay: Double
    func body(content: Content) -> some View {
        content.opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .blur(radius: appeared || reduceMotion ? 0 : 3)
            .onAppear {
                withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.9).delay(delay)) { appeared = true }
            }
    }
}

extension View {
    func cinematicGlass(radius: CGFloat = 24, interactive: Bool = false) -> some View {
        modifier(CinematicGlass(radius: radius, interactive: interactive))
    }
    func cinematicEntrance(delay: Double = 0) -> some View { modifier(CinematicEntrance(delay: delay)) }
    func cinematicCard() -> some View { modifier(CinematicCard()) }
}

private struct CinematicCard: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content.padding(20).background {
            RoundedRectangle(cornerRadius: 24)
                .fill(reduceTransparency ? AnyShapeStyle(Color(white: 0.09)) : AnyShapeStyle(.ultraThinMaterial))
                .overlay { RoundedRectangle(cornerRadius: 24).fill(.black.opacity(reduceTransparency ? 0 : 0.07)) }
                .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.23), lineWidth: 0.75) }
        }
    }
}

struct CinematicScene: View {
    @EnvironmentObject private var library: GameLibrary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let game: Game?
    var system: ConsoleSystem = .threeDS
    var subdued = false
    @State private var image: UIImage?
    @State private var customScene = false
    @State private var loadedKey = ""
    @State private var consoleKey = ""
    private var sceneKey: String { "\(game?.id.uuidString ?? "none")-\(game?.artworkName ?? "none")-\(game?.useConsoleBackground == true)" }
    private var hasGameBackground: Bool {
        guard let game, game.useConsoleBackground != true else { return false }
        return (loadedKey == sceneKey && image != nil) || CinematicArt.match(game.artworkName)?.hasHero == true
    }
    private var showsConsole: Bool {
        game == nil || game?.useConsoleBackground == true || (loadedKey == sceneKey && consoleKey == sceneKey && !hasGameBackground)
    }
    var body: some View {
        GeometryReader { area in
            ZStack {
                Color.black
                if showsConsole {
                    ConsoleSceneBackground(system: system).blur(radius: subdued ? 8 : 0).opacity(subdued ? 0.75 : 1).transition(.opacity)
                }
                if game?.useConsoleBackground != true {
                    if let game, let art = CinematicArt.match(game.artworkName), art.hasHero, !(loadedKey == sceneKey && customScene) {
                        ApprovedHeroArt(art: art).blur(radius: subdued ? 8 : 0).opacity(subdued ? 0.75 : 1).id(art).transition(.opacity)
                    } else if loadedKey == sceneKey, let image {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: area.size.width, height: area.size.height).clipped()
                            .blur(radius: subdued ? 8 : 0).opacity(subdued ? 0.65 : 1).id(image).transition(.opacity)
                    }
                }
                LinearGradient(stops: [
                    .init(color: .black.opacity(subdued ? 0.18 : 0.05), location: 0),
                    .init(color: .clear, location: 0.28),
                    .init(color: ConsoleTheme.ink.opacity(subdued ? 0.75 : 0.78), location: 0.63),
                    .init(color: ConsoleTheme.ink.opacity(0.98), location: 1)
                ], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [.black.opacity(subdued ? 0.12 : 0.16), .clear], startPoint: .leading, endPoint: .trailing)
                if !subdued {
                    RadialGradient(colors: [Color(red: 0.12, green: 0.28, blue: 0.19).opacity(0.55), .clear], center: .bottom, startRadius: 0, endRadius: area.size.width * 0.65)
                }
            }.frame(width: area.size.width, height: area.size.height).clipped()
                .animation(ConsoleMotion.scene(reduceMotion), value: image)
        }.allowsHitTesting(false).accessibilityHidden(true)
        .task(id: "\(sceneKey)-\(library.sceneRevision)-\(library.artworkFetchingEnabled)") {
            let key = sceneKey
            if loadedKey != key { image = nil; customScene = false; consoleKey = ""; loadedKey = key }
            guard let game, game.useConsoleBackground != true else { return }
            let known = await library.scenes.hasKnownImage(for: game)
            guard !Task.isCancelled, loadedKey == key else { return }
            consoleKey = known ? "" : key
            #if targetEnvironment(simulator)
            if known, let delay = Double(ProcessInfo.processInfo.environment["EMUDEN_TEST_SCENE_DELAY"] ?? ""), delay > 0 {
                do { try await Task.sleep(for: .seconds(min(delay, 45))) } catch { return }
            }
            #endif
            let custom = await library.scenes.preferredImage(for: game)
            guard !Task.isCancelled, loadedKey == key else { return }
            if let custom { image = custom; customScene = true; consoleKey = ""; return }
            if CinematicArt.match(game.artworkName)?.hasHero == true { image = nil; customScene = false; return }
            let scene = await library.scenes.image(for: game)
            guard !Task.isCancelled, loadedKey == key else { return }
            image = scene; customScene = false; consoleKey = scene == nil ? key : ""
        }
    }
}

struct CinematicPageHeading: View {
    let title: String
    let subtitle: String
    var symbol = "sparkles"
    var onClose: (() -> Void)?
    var closeID = "pageDone"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("EmuDen").font(.system(size: 18, weight: .bold))
                Spacer()
                if let onClose {
                    Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).frame(width: 44, height: 44).cinematicGlass(radius: 24, interactive: true) }.accessibilityLabel("Done").accessibilityIdentifier(closeID)
                }
            }
            Text(title).font(.system(.largeTitle, design: .default).weight(.bold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CinematicActionLabel: View {
    let title: String
    let symbol: String
    var primary = false
    var disclosure = true
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).frame(width: 24)
            Text(title).font(.system(.subheadline, design: .default).weight(.semibold))
            Spacer(minLength: 0)
            if !primary && disclosure { Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).opacity(0.5) }
        }.padding(.horizontal, 20).frame(minHeight: 52)
            .foregroundStyle(primary ? ConsoleTheme.ink : .white)
            .background { if primary { Capsule().fill(.white) } }
            .contentShape(Capsule())
    }
}

struct CinematicSettingRow: View {
    let title: String
    let detail: String
    let symbol: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 21, weight: .regular)).frame(width: 32).foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(.subheadline, design: .default).weight(.semibold)).foregroundStyle(.white)
                Text(detail).font(.caption).foregroundStyle(ConsoleTheme.quiet).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(ConsoleTheme.quiet)
        }.padding(.vertical, 10).frame(minHeight: 56).contentShape(Rectangle())
    }
}
