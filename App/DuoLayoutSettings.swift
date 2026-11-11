import SwiftUI
import GameController

struct DuoLayoutSettingsView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("controllerPresentation") private var presentation = "shell"
    @State private var opened = false
    @State private var scene: UIImage?
    @State private var connected = !GCController.controllers().isEmpty
    var controllerConnected = false
    var topPreview: UIImage?
    var bottomPreview: UIImage?

    var body: some View {
        NavigationStack {
            GeometryReader { area in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        CinematicPageHeading(title: "Duo layout", subtitle: "", symbol: "rectangle.split.1x2", onClose: { menuAudio.play(.back); dismiss() }, closeID: "duoLayoutDone")
                            .cinematicEntrance()
                        let wide = area.size.width >= 650
                        let layout = wide ? AnyLayout(HStackLayout(alignment: .center, spacing: 30)) : AnyLayout(VStackLayout(spacing: 20))
                        layout {
                            OpeningConsolePreview(opened: opened, expanded: presentation == "panels", top: topPreview ?? scene, bottom: bottomPreview)
                                .frame(maxWidth: wide ? 400 : .infinity).frame(height: wide ? min(460, max(300, area.size.height - 170)) : 300)
                                .accessibilityElement(children: .ignore).accessibilityLabel("Opening console preview")
                                .accessibilityValue(opened ? "Open" : "Closed").accessibilityIdentifier("openingConsolePreview")
                            layoutOptions
                        }.cinematicEntrance(delay: 0.04)
                    }.padding(24).frame(maxWidth: 960).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
            .background { CinematicScene(game: library.featuredGame, subdued: true).ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
        }.tint(.white).statusBarHidden(true)
            .task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 180))
                guard !Task.isCancelled else { return }
                menuAudio.play(.unfold)
                withAnimation(reduceMotion ? nil : .spring(response: 1.0, dampingFraction: 0.86)) { opened = true }
            }
            .task(id: "\(library.featuredGame?.id.uuidString ?? "none")-\(library.sceneRevision)") {
                guard topPreview == nil, let game = library.featuredGame else { return }
                if game.useConsoleBackground == true { scene = ArtworkResources.consoleImage(.threeDS); return }
                if let chosen = await library.scenes.preferredImage(for: game) { scene = chosen; return }
                if CinematicArt.match(game.artworkName) == .golf { scene = CinematicArt.golfScene; return }
                if CinematicArt.match(game.artworkName) == .zelda { scene = CinematicArt.forestScene; return }
                let captured = await library.scenes.image(for: game)
                if let captured { scene = captured }
                else { scene = ArtworkResources.consoleImage(.threeDS) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in connected = !GCController.controllers().isEmpty }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in connected = !GCController.controllers().isEmpty }
    }

    private var layoutOptions: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                Text(controllerConnected || connected ? "Controller connected" : "Ready for your controller").font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Circle().fill(controllerConnected || connected ? .green : .white.opacity(0.3)).frame(width: 6, height: 6)
            }.foregroundStyle(.white.opacity(0.9)).padding(15).cinematicGlass(radius: 28)
            Text("Screen layout").font(.headline)
            HStack(spacing: 12) {
                layoutChoice("Console skin", value: "shell", symbol: "rectangle.split.1x2", detail: "Original screen proportions in a graphite console shell.")
                layoutChoice("Fill display", value: "panels", symbol: "rectangle.split.2x1", detail: "Expand both screens across the active display. On the inner display, each stays on its side of the fold. Picture proportions may change.")
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("Touch controls hide automatically", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium)).foregroundStyle(ConsoleTheme.blue)
                Text("The lower touch screen expands when your controller takes over. You can still touch it directly.")
                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
            }.cinematicCard()
            Text(presentation == "shell" ? "Original screen proportions in a graphite console shell." : "Fills the outer display or both sides of the inner display. The picture’s proportions may change.")
                .font(.caption).foregroundStyle(ConsoleTheme.quiet).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func layoutChoice(_ title: String, value: String, symbol: String, detail: String) -> some View {
        Button {
            guard presentation != value else { return }
            menuAudio.play(.focus)
            withAnimation(ConsoleMotion.response(reduceMotion)) { presentation = value }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 40, weight: .light)).frame(height: 48)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).frame(minHeight: 118).padding(12)
                .cinematicGlass(radius: 20, interactive: true)
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(presentation == value ? 0.95 : 0.08), lineWidth: presentation == value ? 3 : 1) }
                .foregroundStyle(.white)
        }.buttonStyle(ConsolePressStyle()).accessibilityLabel(title).accessibilityHint(detail).accessibilityAddTraits(presentation == value ? .isSelected : [])
    }
}

// A composited clamshell keeps the opening animation light; no continuously running 3D scene.
struct OpeningConsolePreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let opened: Bool
    var expanded = false
    var top: UIImage?
    var bottom: UIImage?
    var body: some View {
        GeometryReader { area in
            let width = min(380, max(120, min(area.size.width - 28, area.size.height / 1.25)))
            let panelHeight = width * 0.61
            VStack(spacing: 6) {
                ConsolePreviewLid(angle: opened || reduceMotion ? -8 : -176, width: width, height: panelHeight, expanded: expanded, image: top)
                    .zIndex(2)
                consoleBase(width: width, height: panelHeight)
                    .rotation3DEffect(.degrees(18), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.35)
            }
            .overlay(alignment: .center) {
                Capsule().fill(LinearGradient(colors: [.black, Color(white: 0.36), .black], startPoint: .top, endPoint: .bottom))
                    .frame(width: width * 0.90, height: 7).offset(y: -1).zIndex(3)
            }
            .shadow(color: .black.opacity(0.5), radius: 22, x: 0, y: 20)
            .frame(width: area.size.width, height: area.size.height, alignment: .center)
            .animation(ConsoleMotion.response(reduceMotion), value: expanded)
        }.allowsHitTesting(false)
    }

    private func consoleBase(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            PreviewConsoleShell()
            Group {
                if let bottom { Image(uiImage: bottom).resizable().aspectRatio(contentMode: expanded ? .fill : .fit) }
                else { ConsoleMapPreview() }
            }.frame(width: width * (expanded ? 0.92 : 0.65), height: height * (expanded ? 0.87 : 0.76))
                .background(.black).clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.8), lineWidth: 3) }
            VStack {
                Spacer()
                HStack(spacing: 5) {
                    Circle().fill(Color.blue.opacity(0.85)).frame(width: 3, height: 3)
                    Text("EMUDEN").font(.system(size: 5, weight: .semibold)).tracking(2).foregroundStyle(.white.opacity(0.3))
                }.padding(.bottom, 7)
            }
        }.frame(width: width, height: height)
    }
}

private struct ConsolePreviewLid: View, Animatable {
    var angle: Double
    let width: CGFloat
    let height: CGFloat
    let expanded: Bool
    let image: UIImage?
    var animatableData: Double { get { angle } set { angle = newValue } }
    var body: some View {
        ZStack {
            PreviewConsoleShell()
            if angle > -90 {
                Group {
                    if let image { Image(uiImage: image).resizable().aspectRatio(contentMode: expanded ? .fill : .fit) }
                    else {
                        ZStack {
                            LinearGradient(colors: [Color(red: 0.12, green: 0.27, blue: 0.25), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                            Image(systemName: "gamecontroller.fill").font(.system(size: 30, weight: .light)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }.frame(width: width * (expanded ? 0.92 : 0.79), height: height * (expanded ? 0.87 : 0.75))
                    .background(.black).clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.black.opacity(0.85), lineWidth: 3) }
                Circle().fill(.black).frame(width: 4, height: 4).offset(y: -height * 0.445)
                HStack { speaker; Spacer(); speaker }.padding(.horizontal, 9)
            } else {
                Text("EmuDen").font(.system(size: 16, weight: .semibold, design: .default)).foregroundStyle(.white.opacity(0.2))
                    .rotation3DEffect(.degrees(180), axis: (x: 1, y: 0, z: 0))
            }
        }.frame(width: width, height: height)
            .rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.35)
    }
    private var speaker: some View {
        VStack(spacing: 4) { ForEach(0..<5) { _ in HStack(spacing: 3) { Circle().frame(width: 2, height: 2); Circle().frame(width: 2, height: 2) } } }.foregroundStyle(.black)
    }
}

private struct PreviewConsoleShell: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(LinearGradient(colors: [Color(white: 0.27), Color(white: 0.10), Color(white: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .black, .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5) }
    }
}

private struct ConsoleMapPreview: View {
    var body: some View {
        GeometryReader { area in
            ZStack {
                Color(red: 0.56, green: 0.66, blue: 0.42)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: area.size.height * 0.3))
                    p.addCurve(to: CGPoint(x: area.size.width, y: area.size.height * 0.74), control1: CGPoint(x: area.size.width * 0.7, y: -20), control2: CGPoint(x: area.size.width * 0.2, y: area.size.height))
                }.stroke(Color(red: 0.31, green: 0.63, blue: 0.72), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                ForEach(0..<5) { i in
                    Image(systemName: "tree.fill").font(.system(size: 12)).foregroundStyle(Color(red: 0.2, green: 0.39, blue: 0.25))
                        .position(x: area.size.width * CGFloat([0.16, 0.35, 0.78, 0.65, 0.83][i]), y: area.size.height * CGFloat([0.76, 0.23, 0.3, 0.8, 0.66][i]))
                }
                Image(systemName: "location.north.fill").font(.system(size: 12)).foregroundStyle(.white).shadow(radius: 2)
            }
        }
    }
}
