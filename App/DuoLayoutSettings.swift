import SwiftUI
import GameController

struct DuoLayoutSettingsView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("controllerPresentation") private var presentation = "shell"
    @AppStorage("screenSizing") private var sizing = "automatic"
    @AppStorage("ps1Folded") private var ps1Folded = true
    @AppStorage("gameCubeFolded") private var gameCubeFolded = true
    @State private var opened = false
    @State private var scene: UIImage?
    @State private var connected = !GCController.controllers().isEmpty
    @State private var animationCycle = 0
    var system: ConsoleSystem = .threeDS
    var controllerConnected = false
    var topPreview: UIImage?
    var bottomPreview: UIImage?
    private var previewGame: Game? {
        library.featuredGame.flatMap { $0.console.rawValue == system.rawValue ? $0 : nil } ?? library.sortedGames.first { $0.console.rawValue == system.rawValue }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { area in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        CinematicPageHeading(title: "Duo layout", subtitle: system.name, symbol: system.symbol, onClose: { menuAudio.play(.back); dismiss() }, closeID: "duoLayoutDone")
                            .cinematicEntrance()
                        let wide = area.size.width >= 650
                        let layout = wide ? AnyLayout(HStackLayout(alignment: .center, spacing: 30)) : AnyLayout(VStackLayout(spacing: 20))
                        layout {
                            Group {
                                if system == .threeDS { OpeningConsolePreview(opened: opened, expanded: presentation == "panels", top: topPreview ?? scene, bottom: bottomPreview) }
                                else { ConnectingControllerPreview(system: system, connected: opened, image: topPreview ?? scene) }
                            }
                                .frame(maxWidth: wide ? 400 : .infinity).frame(height: wide ? min(460, max(300, area.size.height - 170)) : 300)
                                .accessibilityElement(children: .ignore).accessibilityLabel(system == .threeDS ? "Opening console preview" : "\(system.name) controller connection preview")
                                .accessibilityValue(opened ? "Open" : "Closed").accessibilityIdentifier("openingConsolePreview")
                            VStack(alignment: .leading, spacing: 16) {
                                if system == .threeDS { layoutOptions } else { singleScreenOptions }
                                Button { animationCycle += 1 } label: { Label("Replay animation", systemImage: "arrow.clockwise").font(.subheadline.weight(.medium)).frame(minHeight: 44) }
                                    .accessibilityIdentifier("replayControllerAnimation")
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.cinematicEntrance(delay: 0.04)
                    }.padding(24).frame(maxWidth: 960).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
            .background { CinematicScene(game: previewGame, system: system, subdued: true).ignoresSafeArea() }
            .toolbar(.hidden, for: .navigationBar)
        }.tint(.white).statusBarHidden(true)
            .task(id: animationCycle) {
                opened = false
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 180))
                guard !Task.isCancelled else { return }
                menuAudio.play(.unfold)
                withAnimation(reduceMotion ? nil : .spring(response: 1.0, dampingFraction: 0.86)) { opened = true }
            }
            .task(id: "\(system.rawValue)-\(previewGame?.id.uuidString ?? "none")-\(library.sceneRevision)") {
                let platform = system
                guard topPreview == nil, let game = previewGame else { scene = ArtworkResources.consoleImage(platform); return }
                if game.useConsoleBackground == true { scene = ArtworkResources.consoleImage(platform); return }
                if let chosen = await library.scenes.preferredImage(for: game) { scene = chosen; return }
                let captured = await library.scenes.image(for: game)
                if let captured { scene = captured }
                else { scene = ArtworkResources.consoleImage(platform) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in connected = !GCController.controllers().isEmpty }
            .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)) { _ in connected = !GCController.controllers().isEmpty }
    }

    private var singleScreenOptions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(controllerConnected || connected ? "Controller connected" : "Ready for your controller", systemImage: "gamecontroller.fill")
                .font(.subheadline.weight(.medium)).foregroundStyle(system.color).padding(16).cinematicGlass(radius: 24)
            Text("\(system.name), on your display.").font(.title2.weight(.semibold))
            Text("A single screen, room to play. Your controller takes over as touch controls fade away. Drag the controller preview to tilt it.")
                .font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
            VStack(alignment: .leading, spacing: 14) {
                Picker("Default picture sizing", selection: $sizing) {
                    Text("Follow layout").tag("automatic")
                    Text("Original proportions").tag("original")
                    Text("Fill display").tag("fill")
                }.accessibilityIdentifier("duoSingleScreenSizing")
                Text("Original keeps the game's 4:3 shape. Follow layout fills controller layouts. Per-game Graphics settings take priority.")
                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                if system == .ps1 || system == .gamecube {
                    Divider()
                    if system == .ps1 { Toggle("Move video above the fold", isOn: $ps1Folded).accessibilityIdentifier("duoPS1Folded") }
                    else { Toggle("Move video above the fold", isOn: $gameCubeFolded).accessibilityIdentifier("duoGameCubeFolded") }
                    Text("Use Graphics settings → Controls to choose the lower panel's quick controls, or leave it blank.")
                        .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                }
            }.cinematicCard()
        }
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
            if !expanded {
                ControlStickVisual(color: Color(white: 0.66)).frame(width: width * 0.115, height: width * 0.115).offset(x: -width * 0.413, y: -height * 0.22)
                ZStack {
                    RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.11)).frame(width: width * 0.10, height: width * 0.035)
                    RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.11)).frame(width: width * 0.035, height: width * 0.10)
                }.shadow(color: .black.opacity(0.8), radius: 1, y: 2).offset(x: -width * 0.413, y: height * 0.23)
                ForEach(Array(["X", "Y", "A", "B"].enumerated()), id: \.offset) { index, label in
                    RaisedControlCap(label: label, color: Color(white: 0.20)).frame(width: width * 0.053, height: width * 0.053)
                        .offset(x: width * 0.413 + (index == 1 ? -width * 0.050 : index == 2 ? width * 0.050 : 0), y: index == 0 ? -height * 0.09 : index == 3 ? height * 0.075 : -height * 0.008)
                }
            }
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

private struct ConnectingControllerPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let system: ConsoleSystem
    let connected: Bool
    let image: UIImage?
    @State private var tilt = CGSize.zero

    var body: some View {
        GeometryReader { area in
            let width = min(330, min(area.size.width - 24, (area.size.height - 50) / 1.10))
            VStack(spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [Color(white: 0.36), Color(white: 0.06), Color(white: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(.white.opacity(0.3), lineWidth: 1) }
                    Group {
                        if let image { Image(uiImage: image).resizable().scaledToFit() }
                        else {
                            ZStack {
                                LinearGradient(colors: [system.color.opacity(0.3), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: system.symbol).font(.system(size: 40, weight: .ultraLight)).foregroundStyle(system.color)
                            }
                        }
                    }.frame(width: width - 18, height: width * 0.54 - 18).background(.black).clipShape(RoundedRectangle(cornerRadius: 9))
                    Capsule().fill(connected ? system.color : .white.opacity(0.2)).frame(width: 16, height: 2).offset(y: width * 0.27 - 4)
                }.frame(width: width, height: width * 0.54)
                    .rotation3DEffect(.degrees(connected || reduceMotion ? -5 : 16), axis: (x: 1, y: 0, z: 0), perspective: 0.3)
                    .shadow(color: .black.opacity(0.5), radius: 14, y: 10)
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: 45, y: 0))
                        p.addCurve(to: CGPoint(x: 45, y: 42), control1: CGPoint(x: 65, y: 12), control2: CGPoint(x: 25, y: 30))
                    }.trim(from: 0, to: connected || reduceMotion ? 1 : 0)
                        .stroke(LinearGradient(colors: [system.color.opacity(0.9), Color(white: 0.2)], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.38)).frame(width: 13, height: 5).offset(y: -19)
                }.frame(width: 90, height: 42).opacity(connected || reduceMotion ? 1 : 0)
                SolidControllerPreview(system: system, tilt: reduceMotion ? .zero : tilt)
                    .frame(width: width, height: width * 0.56)
                    .rotationEffect(.degrees(connected || reduceMotion ? 0 : -9))
                    .offset(y: connected || reduceMotion ? 0 : 40).opacity(connected || reduceMotion ? 1 : 0)
                    .shadow(color: system.color.opacity(0.15), radius: 20, y: 8)
                    .gesture(DragGesture(minimumDistance: 3).onChanged {
                        tilt = CGSize(width: min(45, max(-45, $0.translation.width)), height: min(35, max(-35, $0.translation.height)))
                    }.onEnded { _ in withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.7)) { tilt = .zero } })
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct DuoControllerArtwork: View {
    let system: ConsoleSystem
    private var cube: Bool { system == .gamecube }
    var body: some View {
        GeometryReader { area in
            let w = area.size.width, h = area.size.height
            ZStack {
                HStack {
                    Capsule().frame(width: w * 0.21, height: h * 0.12)
                    Spacer()
                    Capsule().frame(width: w * 0.21, height: h * 0.12)
                }.foregroundStyle(cube ? Color(red: 0.35, green: 0.32, blue: 0.52) : Color(white: 0.22)).padding(.horizontal, w * 0.12).offset(y: -h * 0.4)
                ControllerBodyShape(cube: cube).fill(LinearGradient(colors: cube ? [Color(red: 0.43, green: 0.4, blue: 0.72), Color(red: 0.2, green: 0.18, blue: 0.39), Color(red: 0.31, green: 0.28, blue: 0.53)] : [Color(white: 0.8), Color(white: 0.48), Color(white: 0.64)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { ControllerBodyShape(cube: cube).stroke(LinearGradient(colors: [.white.opacity(0.65), .black.opacity(0.65)], startPoint: .top, endPoint: .bottom), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.7), radius: 6, y: 7)
                if cube {
                    stick(size: w * 0.135, color: Color(white: 0.7)).position(x: w * 0.25, y: h * 0.37)
                    dpad(size: w * 0.12).position(x: w * 0.34, y: h * 0.73)
                    stick(size: w * 0.115, color: Color(red: 0.94, green: 0.76, blue: 0.2)).position(x: w * 0.64, y: h * 0.74)
                    face("A", size: w * 0.14, color: Color(red: 0.24, green: 0.72, blue: 0.54)).position(x: w * 0.8, y: h * 0.4)
                    face("B", size: w * 0.075, color: Color(red: 0.86, green: 0.23, blue: 0.25)).position(x: w * 0.68, y: h * 0.57)
                    Capsule().fill(Color(white: 0.65)).frame(width: w * 0.09, height: h * 0.11).rotationEffect(.degrees(-28)).position(x: w * 0.78, y: h * 0.16)
                    Capsule().fill(Color(white: 0.65)).frame(width: w * 0.09, height: h * 0.11).rotationEffect(.degrees(-55)).position(x: w * 0.92, y: h * 0.35)
                    face("", size: w * 0.045, color: Color(white: 0.55)).position(x: w * 0.51, y: h * 0.4)
                } else {
                    dpad(size: w * 0.17).position(x: w * 0.23, y: h * 0.37)
                    stick(size: w * 0.12, color: Color(white: 0.19)).position(x: w * 0.4, y: h * 0.72)
                    stick(size: w * 0.12, color: Color(white: 0.19)).position(x: w * 0.6, y: h * 0.72)
                    psButton("triangle", color: .mint, size: w * 0.09).position(x: w * 0.77, y: h * 0.18)
                    psButton("circle", color: .pink, size: w * 0.09).position(x: w * 0.87, y: h * 0.37)
                    psButton("xmark", color: Color(red: 0.55, green: 0.65, blue: 0.95), size: w * 0.09).position(x: w * 0.77, y: h * 0.56)
                    psButton("square", color: Color(red: 0.9, green: 0.58, blue: 0.8), size: w * 0.09).position(x: w * 0.67, y: h * 0.37)
                    HStack(spacing: w * 0.04) {
                        Capsule().frame(width: w * 0.035, height: h * 0.045)
                        Image(systemName: "play.fill").font(.system(size: w * 0.03))
                    }.foregroundStyle(Color(white: 0.16)).position(x: w * 0.5, y: h * 0.38)
                }
                Capsule().fill(cube ? .white.opacity(0.4) : Color.orange.opacity(0.7)).frame(width: w * 0.055, height: 2).position(x: w * 0.5, y: h * 0.18)
            }
        }
    }
    private func stick(size: CGFloat, color: Color) -> some View {
        Circle().fill(.black.opacity(0.65)).frame(width: size * 1.35, height: size * 1.35)
            .overlay { Circle().fill(LinearGradient(colors: [color, color.opacity(0.6), .black.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: size, height: size).overlay { Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1).padding(3) }.shadow(color: .black.opacity(0.55), radius: 2, y: 3) }
    }
    private func dpad(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).frame(width: size * 0.34, height: size)
            RoundedRectangle(cornerRadius: 2).frame(width: size, height: size * 0.34)
        }.foregroundStyle(LinearGradient(colors: [Color(white: 0.2), Color(white: 0.06)], startPoint: .top, endPoint: .bottom))
            .shadow(color: .white.opacity(0.15), radius: 0.5, y: -1).shadow(color: .black.opacity(0.65), radius: 1.5, y: 2)
    }
    private func face(_ text: String, size: CGFloat, color: Color) -> some View {
        Circle().fill(LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: size, height: size)
            .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.75) }
            .overlay { Text(text).font(.system(size: size * 0.35, weight: .medium)).foregroundStyle(.black.opacity(0.65)) }
            .shadow(color: .black.opacity(0.6), radius: 1.5, y: 2)
    }
    private func psButton(_ symbol: String, color: Color, size: CGFloat) -> some View {
        face("", size: size, color: Color(white: 0.15))
            .overlay { Image(systemName: symbol).font(.system(size: size * 0.48, weight: .semibold)).foregroundStyle(color) }
    }
}

private struct ControllerBodyShape: Shape {
    let cube: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.23, y: 0.04))
        p.addCurve(to: CGPoint(x: 0.08, y: 0.29), control1: CGPoint(x: 0.15, y: 0.02), control2: CGPoint(x: 0.08, y: 0.14))
        p.addCurve(to: CGPoint(x: 0.025, y: 0.79), control1: CGPoint(x: 0.04, y: 0.49), control2: CGPoint(x: 0.015, y: 0.64))
        p.addCurve(to: CGPoint(x: 0.16, y: 0.98), control1: CGPoint(x: 0.02, y: 0.95), control2: CGPoint(x: 0.08, y: 1.03))
        p.addCurve(to: CGPoint(x: 0.35, y: cube ? 0.7 : 0.75), control1: CGPoint(x: 0.25, y: 0.92), control2: CGPoint(x: 0.28, y: 0.77))
        p.addCurve(to: CGPoint(x: 0.65, y: cube ? 0.7 : 0.75), control1: CGPoint(x: 0.44, y: cube ? 0.55 : 0.91), control2: CGPoint(x: 0.56, y: cube ? 0.55 : 0.91))
        p.addCurve(to: CGPoint(x: 0.84, y: 0.98), control1: CGPoint(x: 0.72, y: 0.77), control2: CGPoint(x: 0.75, y: 0.92))
        p.addCurve(to: CGPoint(x: 0.975, y: 0.79), control1: CGPoint(x: 0.92, y: 1.03), control2: CGPoint(x: 0.98, y: 0.95))
        p.addCurve(to: CGPoint(x: 0.92, y: 0.29), control1: CGPoint(x: 0.985, y: 0.64), control2: CGPoint(x: 0.96, y: 0.49))
        p.addCurve(to: CGPoint(x: 0.77, y: 0.04), control1: CGPoint(x: 0.92, y: 0.14), control2: CGPoint(x: 0.85, y: 0.02))
        p.addCurve(to: CGPoint(x: 0.23, y: 0.04), control1: CGPoint(x: 0.61, y: 0.08), control2: CGPoint(x: 0.39, y: 0.08))
        p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
    }
}
