import SwiftUI

struct PlayerView: View {
    let launch: Launch
    let saves: URL
    let onBoot: () -> Void
    let onPreview: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var menuAudio: MenuAudio
    @EnvironmentObject private var library: GameLibrary
    @StateObject private var session: EmulatorSession
    @State private var showControls = true
    @State private var showingSettings = false
    @State private var showingGameMenu = false
    @State private var showingLayout = false
    @State private var closingMenu = false
    @State private var showingResumePrompt = false
    @State private var showingSessionMessage = false
    @State private var menuWasPaused = false
    @State private var headerVisible = true
    @State private var headerTask: Task<Void, Never>?
    @AppStorage("controllerPresentation") private var controllerPresentation = "shell"
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("showFrameGraph") private var showGraph = false
    @State private var preferences = PlayerPreferences()
    @State private var currentGame: Game?
    @State private var pendingWidgetSwitch = false
    private var headerPinned: Bool {
        launch.diagnostic || session.booting || session.paused || session.closing || session.stateBusy ||
        showingGameMenu || showingSettings || showingLayout || session.offerResume || session.message != nil ||
        scenePhase != .active || UIAccessibility.isVoiceOverRunning
    }
    private var controlsVisible: Bool { showControls && !session.hasController }
    private var immersive: Bool { !controlsVisible && controllerPresentation == "panels" }
    private var fillPicture: Bool { preferences.sizing == .fill || (preferences.sizing == .automatic && immersive) }
    init(launch: Launch, saves: URL, onPreview: @escaping (UIImage) -> Void = { _ in }, onBoot: @escaping () -> Void) {
        self.launch = launch; self.saves = saves; self.onBoot = onBoot; self.onPreview = onPreview
        _session = StateObject(wrappedValue: EmulatorSession(diagnostic: launch.diagnostic))
    }
    var body: some View {
        GeometryReader { geometry in
            let horizontal = geometry.size.width > geometry.size.height * 1.25
            Group {
                if let division = foldDivision(in: geometry) {
                    duoPlayer(size: geometry.size, division: division)
                } else {
                    standardPlayer(horizontal: horizontal, insets: geometry.safeAreaInsets)
                }
            }
                .allowsHitTesting(!showingGameMenu)
                .accessibilityHidden(showingGameMenu)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.background)
                .overlay {
                    if session.booting {
                        VStack(spacing: 12) {
                            if session.shaderProgress >= 0 { ProgressView(value: session.shaderProgress).frame(width: 210) }
                            else { ProgressView() }
                            Text(session.shaderStage.map { "Preparing graphics · " + $0 } ?? "Starting Azahar…").font(.subheadline)
                        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).accessibilityIdentifier("graphicsPreparation")
                    }
                }
                .overlay { if session.closing { ProgressView("Closing game…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
                .overlay { if session.stateBusy && !session.closing { ProgressView("Updating save state…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
                .overlay(alignment: .bottom) {
                    if let notice = session.notice {
                        Text(notice).font(.subheadline.bold()).padding(14).background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 12).allowsHitTesting(false)
                    }
                }
        }
        .ignoresSafeArea(.container, edges: immersive ? .all : [])
        .overlay { if showingGameMenu { gameMenu.transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.97))) } }
        .animation(ConsoleMotion.response(reduceMotion), value: showingGameMenu)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if let url = launch.url {
                currentGame = library.games.first { library.storage.gameURL($0) == url } ?? Game(title: launch.title, fileName: url.lastPathComponent, programID: ThreeDSProgramID.read(url))
            }
            refreshPreferences()
            session.start(url: launch.url, saves: saves, preferences: preferences, onBoot: onBoot)
        }
        .onDisappear { headerTask?.cancel(); UIApplication.shared.isIdleTimerDisabled = false; menuAudio.setActive(false) }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EmuDenWidgetSwitchGame"))) { _ in
            pendingWidgetSwitch = true; finishWidgetSwitch()
        }
        .onChange(of: session.stateBusy) { _, _ in finishWidgetSwitch() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { rememberScene(); session.background() }
            else if phase == .inactive { session.setPaused(true) }
        }
        .task(id: session.notice) {
            guard session.notice != nil else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { session.notice = nil }
        }
        .onChange(of: controlsVisible) { _, _ in session.releaseTouchControls() }
        .onChange(of: headerPinned, initial: true) { _, _ in resetHeaderTimer() }
        .onChange(of: showingGameMenu) { _, visible in
            menuAudio.setActive(visible && scenePhase == .active)
            if !visible { closingMenu = false; if !session.closing { Task { @MainActor in session.setPaused(menuWasPaused) } } }
        }
        .onChange(of: scenePhase) { _, phase in menuAudio.setActive(showingGameMenu && phase == .active) }
        .onChange(of: session.offerResume) { _, offered in showingResumePrompt = offered }
        .onChange(of: session.message) { _, message in showingSessionMessage = message != nil }
        .alert("Resume your session?", isPresented: $showingResumePrompt) {
            Button("Resume session") { Task { session.offerResume = false; await session.load(.resume); session.setPaused(false) } }
            Button("Start normally") { Task { @MainActor in session.offerResume = false; session.setPaused(false) } }
        } message: { Text("A resume point is available from \(session.resumeDate?.formatted(date: .abbreviated, time: .shortened) ?? "your last session"). Your game's own saves are also kept separately.") }
        .alert("EmuDen message", isPresented: $showingSessionMessage) {
            Button("OK") { Task { @MainActor in session.message = nil } }
            Button("Return without resume point") { Task { @MainActor in session.message = nil; session.closeWithoutState { dismiss() } } }
        } message: { Text(session.message ?? "") }
    }
    private func standardPlayer(horizontal: Bool, insets: EdgeInsets) -> some View {
        VStack(spacing: horizontal ? 8 : 16) {
                if horizontal {
                    HStack(spacing: 18) {
                        if controlsVisible { leftControls.frame(width: 124) }
                        screens(horizontal: true).frame(maxWidth: .infinity, maxHeight: .infinity)
                        if controlsVisible { rightControls.frame(width: 136) }
                    }
                } else {
                    screens(horizontal: false).frame(maxHeight: .infinity)
                    if controlsVisible {
                        HStack(alignment: .center) { leftControls; Spacer(minLength: 12); rightControls }.frame(maxWidth: 640)
                    }
                }
                if controlsVisible { startControls.frame(height: 44) }
            }.padding(.horizontal, immersive ? 0 : (horizontal ? 18 : 22)).padding(.vertical, immersive ? 0 : 12)
            .background { if !immersive { ConsoleShell(top: false) } }
            .overlay(alignment: .top) {
                toolbar.padding(.leading, (horizontal ? 18 : 22) + (immersive ? insets.leading : 0))
                    .padding(.trailing, (horizontal ? 18 : 22) + (immersive ? insets.trailing : 0))
                    .padding(.top, 12 + (immersive ? insets.top : 0))
            }
    }
    private func foldDivision(in geometry: GeometryProxy) -> CGRect? {
        // UI test fixtures exercise both fold axes without depending on Device Hub's pose controls.
        if launch.diagnostic && ProcessInfo.processInfo.arguments.contains("--duo-tabletop-preview") {
            return CGRect(x: 0, y: geometry.size.height / 2 - 10, width: geometry.size.width, height: 20)
        }
        if launch.diagnostic && ProcessInfo.processInfo.arguments.contains("--duo-book-preview") {
            return CGRect(x: geometry.size.width / 2 - 10, y: 0, width: 20, height: geometry.size.height)
        }
        if #available(iOS 27.1, *),
           let region = geometry.reservedRegions(kind: .division, options: .includeInactive, layoutDirectionBehavior: .fixed).first {
            return region.frame.inset(by: UIEdgeInsets(top: -region.margins.top, left: -region.margins.leading,
                                                     bottom: -region.margins.bottom, right: -region.margins.trailing))
        }
        return nil
    }
    private func duoPlayer(size: CGSize, division: CGRect) -> some View {
        let layout = DuoLayout(size: size, division: division, controls: controlsVisible, immersive: immersive)
        let topArea = immersive ? layout.topPanel : CGRect(x: layout.topPanel.minX + 28, y: layout.topPanel.minY + 68,
                             width: max(0, layout.topPanel.width - 56), height: max(0, layout.topPanel.height - 94))
        let top = fillPicture ? topArea : DuoLayout.fit(aspect: 5.0 / 3, in: topArea)
        let bottom = fillPicture ? layout.bottomScreenArea : DuoLayout.fit(aspect: 4.0 / 3, in: layout.bottomScreenArea)
        return ZStack(alignment: .topLeading) {
            if !immersive {
                ConsoleShell(top: true).frame(width: layout.topPanel.width, height: layout.topPanel.height)
                    .position(x: layout.topPanel.midX, y: layout.topPanel.midY)
                ConsoleShell(top: false).frame(width: layout.bottomPanel.width, height: layout.bottomPanel.height)
                    .position(x: layout.bottomPanel.midX, y: layout.bottomPanel.midY)
                Capsule().fill(LinearGradient(colors: [.black, .gray.opacity(0.6), .black], startPoint: .top, endPoint: .bottom))
                    .frame(width: division.width > division.height ? size.width * 0.84 : 14,
                           height: division.width > division.height ? 14 : size.height * 0.84)
                    .position(x: division.midX, y: division.midY).accessibilityHidden(true)
            }
            screen(image: session.top, bottom: false)
                .frame(width: top.width, height: top.height).position(x: top.midX, y: top.midY)
            screen(image: session.bottom, bottom: true)
                .frame(width: bottom.width, height: bottom.height).position(x: bottom.midX, y: bottom.midY)
            toolbar.frame(width: max(0, layout.topPanel.width - 32), height: 44)
                .position(x: layout.topPanel.midX, y: layout.topPanel.minY + 34)
            if controlsVisible {
                HStack {
                    Group {
                        if layout.controlsArea.height < 286 { compactLeftControls }
                        else { leftControls }
                    }.frame(width: 124)
                    Spacer(minLength: 12)
                    rightControls.frame(width: 136)
                }.frame(width: layout.controlsArea.width, height: layout.controlsArea.height)
                    .position(x: layout.controlsArea.midX, y: layout.controlsArea.midY)
                startControls.frame(width: layout.startArea.width, height: layout.startArea.height)
                    .position(x: layout.startArea.midX, y: layout.startArea.midY)
            }
        }.frame(width: size.width, height: size.height)
            .overlay { if session.paused { Label("Paused", systemImage: "pause.fill").padding(20).background(.regularMaterial, in: Capsule()) } }
    }
    private var startControls: some View {
        HStack(spacing: 28) {
            ControlButton(label: "SELECT", id: 2, session: session, small: true)
            ControlButton(label: "START", id: 3, session: session, small: true)
        }
    }
    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: close) { Image(systemName: "chevron.down").frame(width: 44, height: 44).cinematicGlass(radius: 24, interactive: true) }
                .accessibilityLabel("Return to library").accessibilityIdentifier("playerBack")
            VStack(alignment: .leading, spacing: 3) {
                Text(launch.title).font(.subheadline.bold()).lineLimit(1)
                Text(launch.diagnostic ? "INPUT & DISPLAY TEST" : "3DS · METAL GPU").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 4)
            Button { withAnimation(ConsoleMotion.response(reduceMotion)) { showControls.toggle() } } label: { Image(systemName: session.hasController ? "gamecontroller.fill" : "gamecontroller").contentTransition(.symbolEffect(.replace)).frame(width: 44, height: 44) }
                .accessibilityLabel(session.hasController ? "Controller connected" : "Toggle touch controls").disabled(session.hasController)
            Button { session.setPaused(!session.paused) } label: { Image(systemName: session.paused ? "play.fill" : "pause.fill").contentTransition(.symbolEffect(.replace)).frame(width: 44, height: 44) }
                .accessibilityLabel(session.paused ? "Resume" : "Pause")
            Button {
                menuWasPaused = session.paused; session.setPaused(true); menuAudio.setActive(true); menuAudio.play(.open); showingGameMenu = true
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).cinematicGlass(radius: 24, interactive: true) }
                .accessibilityLabel("Game menu")
        }.foregroundStyle(.white).buttonStyle(ConsolePressStyle()).disabled(session.closing || session.stateBusy)
            .padding(.horizontal, 6).background(.ultraThinMaterial, in: Capsule())
            .simultaneousGesture(TapGesture().onEnded { _ in wakeHeader() })
            .accessibilityElement(children: .contain).accessibilityIdentifier("playerHeader")
            .opacity(headerVisible ? 1 : 0)
            .allowsHitTesting(headerVisible)
            .accessibilityHidden(!headerVisible)
    }
    private var frameRate: some View {
        Text(String(format: "%.1f FPS", session.fps)).font(.system(size: 10, design: .monospaced))
            .foregroundStyle(Palette.accent)
    }
    private func wakeHeader() {
        withAnimation(reduceMotion ? .none : .easeOut(duration: 0.2)) { resetHeaderTimer() }
    }
    private func resetHeaderTimer() {
        headerTask?.cancel(); headerVisible = true
        guard !headerPinned else { return }
        headerTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            guard !Task.isCancelled, !headerPinned else { return }
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.25)) { headerVisible = false }
        }
    }
    private var gameMenu: some View {
        GeometryReader { area in
            ZStack {
                ConsoleTheme.ink.ignoresSafeArea()
                if let image = session.top {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: area.size.width, height: area.size.height).clipped().opacity(0.72).ignoresSafeArea()
                }
                Color.black.opacity(0.25).ignoresSafeArea()
                ScrollView {
                    CinematicGlassGroup {
                        VStack(spacing: 12) {
                            Text("Paused").font(.system(size: 26, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 6)
                                .overlay(alignment: .trailing) {
                                    Menu {
                                        Button("Player Settings", systemImage: "slider.horizontal.3") { menuAudio.play(.open); showingSettings = true }
                                        Button("Load Resume Point", systemImage: "clock.arrow.circlepath") { performState(.resume, load: true) }.disabled(session.resumeDate == nil || session.booting)
                                    } label: { Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44) }
                                        .accessibilityLabel("More game options").accessibilityIdentifier("moreGameOptions")
                                }
                            Button(action: resumeGameMenu) { CinematicActionLabel(title: "Resume", symbol: "play.fill", primary: true) }.accessibilityLabel("Resume game")
                            Button { performState(.quick, load: false) } label: { CinematicActionLabel(title: "Quick save", symbol: "square.and.arrow.down", disclosure: false) }
                                .cinematicGlass(radius: 28, interactive: true).accessibilityLabel("Quick Save").disabled(session.booting || launch.diagnostic)
                            Button { performState(.quick, load: true) } label: { CinematicActionLabel(title: "Quick load", symbol: "square.and.arrow.up", disclosure: false) }
                                .cinematicGlass(radius: 28, interactive: true).accessibilityLabel("Quick Load").disabled(session.quickDate == nil || session.booting)
                            Button { menuAudio.play(.open); showingLayout = true } label: { CinematicActionLabel(title: "Screen layout", symbol: "rectangle.split.1x2") }
                                .cinematicGlass(radius: 28, interactive: true).accessibilityIdentifier("openGameDuoLayout")
                            Button { menuAudio.play(.back); close() } label: { CinematicActionLabel(title: "Return to library", symbol: "arrow.uturn.backward", disclosure: false) }
                                .cinematicGlass(radius: 28, interactive: true)
                                .accessibilityIdentifier("gameMenuBack")
                            if session.stateBusy || session.closing { ProgressView(session.closing ? "Closing game…" : "Updating save state…").font(.caption) }
                        }.padding(20).cinematicGlass(radius: 28)
                            .frame(width: min(390, max(220, area.size.width - 40)))
                            .disabled(session.stateBusy || session.closing || closingMenu).buttonStyle(ConsolePressStyle())
                    }.frame(maxWidth: .infinity).frame(minHeight: area.size.height).padding(.vertical, 12)
                }.scrollIndicators(.hidden)
            }.frame(width: area.size.width, height: area.size.height).clipped()
                .sheet(isPresented: $showingSettings, onDismiss: { refreshPreferences(); session.updateGraphics(preferences) }) {
                    PlayerSettingsView(game: currentGame, isPlaying: !launch.diagnostic, controllerConnected: session.hasController, topPreview: session.top, bottomPreview: session.bottom)
                }
                .fullScreenCover(isPresented: $showingLayout) { DuoLayoutSettingsView(controllerConnected: session.hasController, topPreview: session.top, bottomPreview: session.bottom) }
        }.tint(.white).accessibilityAddTraits(.isModal)
    }
    private func resumeGameMenu() {
        closingMenu = true
        let delay = menuAudio.play(.back)
        Task { @MainActor in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            showingGameMenu = false
        }
    }

    private func performState(_ slot: SaveStateStore.Slot, load: Bool) {
        menuAudio.play(.confirm)
        Task {
            if load { await session.load(slot) } else { await session.save(slot) }
            guard session.message == nil else { return }
            let delay = menuAudio.play(.save)
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            showingGameMenu = false
        }
    }
    private func screens(horizontal: Bool) -> some View {
        GeometryReader { area in
            if immersive || preferences.sizing != .automatic || preferences.screenBalance != 0.5 {
                let regions = DuoLayout.expandedScreens(in: area.size, horizontal: horizontal, balance: preferences.screenBalance)
                let frames = (top: fillPicture ? regions.top : DuoLayout.fit(aspect: 5.0 / 3, in: regions.top),
                              bottom: fillPicture ? regions.bottom : DuoLayout.fit(aspect: 4.0 / 3, in: regions.bottom))
                ZStack(alignment: .topLeading) {
                    screen(image: session.top, bottom: false).frame(width: frames.top.width, height: frames.top.height)
                        .position(x: frames.top.midX, y: frames.top.midY)
                    screen(image: session.bottom, bottom: true).frame(width: frames.bottom.width, height: frames.bottom.height)
                        .position(x: frames.bottom.midX, y: frames.bottom.midY)
                }.frame(width: area.size.width, height: area.size.height)
            } else if horizontal {
                let scale = max(0, min((area.size.width - 12) / 720, area.size.height / 240))
                HStack(spacing: 12) {
                    screen(image: session.top, bottom: false).frame(width: 400 * scale, height: 240 * scale)
                    screen(image: session.bottom, bottom: true).frame(width: 320 * scale, height: 240 * scale)
                }.frame(width: area.size.width, height: area.size.height)
            } else {
                let scale = max(0, min(area.size.width / 400, (area.size.height - 12) / 480))
                VStack(spacing: 12) {
                    screen(image: session.top, bottom: false).frame(width: 400 * scale, height: 240 * scale)
                    screen(image: session.bottom, bottom: true).frame(width: 320 * scale, height: 240 * scale)
                }.frame(width: area.size.width, height: area.size.height)
            }
        }.overlay { if session.paused { Label("Paused", systemImage: "pause.fill").font(.headline).padding(20).background(.regularMaterial, in: Capsule()) } }
    }
    private func screen(image: UIImage?, bottom: Bool) -> some View {
        ZStack {
            Color.black
            if let image {
                Image(uiImage: image).resizable().interpolation(.none)
                    .accessibilityLabel(bottom ? "3DS bottom screen" : "3DS top screen")
                    .accessibilityIdentifier(bottom ? "bottomScreen" : "topScreen")
                    .accessibilityValue("\(session.frames) frames received")
            }
            else if launch.diagnostic {
                LinearGradient(colors: bottom ? [Color(red: 0.08, green: 0.16, blue: 0.18), .black] : [Color(red: 0.18, green: 0.27, blue: 0.12), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                GeometryReader { area in
                    VStack(spacing: 8) {
                        if area.size.height > 110 {
                            Image(systemName: bottom ? "hand.tap" : "gamecontroller").font(.system(size: 28, weight: .light)).foregroundStyle(Palette.accent)
                        }
                        Text(bottom ? session.input : "Ready, player one.").font(.headline).lineLimit(1).minimumScaleFactor(0.6)
                        if area.size.height > 100 {
                            Text(bottom ? "Touch this screen or press a control" : (session.controllerName ?? "Touch controls ready"))
                                .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                        }
                    }.padding(12).frame(width: area.size.width, height: area.size.height)
                }
            } else { Text(bottom ? "TOUCH SCREEN" : "TOP SCREEN").font(.system(size: 10, design: .monospaced)).tracking(2).foregroundStyle(Palette.muted) }
        }
        .clipShape(RoundedRectangle(cornerRadius: immersive ? 0 : 8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(bottom ? "bottomScreenRegion" : "topScreenRegion")
        .overlay {
            if !immersive {
                RoundedRectangle(cornerRadius: 8).stroke(.black, lineWidth: 5)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.15), lineWidth: 1) }
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if bottom {
                TouchSurface { point, down in session.touch(x: point.x, y: point.y, pressed: down) }
                    .accessibilityLabel("3DS touch screen")
            } else {
                Button(action: wakeHeader) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain).accessibilityLabel("Show game controls").accessibilityIdentifier("showPlayerControls")
                    .accessibilityValue(headerVisible ? "Controls visible" : "Controls hidden")
            }
        }
        .overlay(alignment: .topTrailing) {
            if !bottom && showGraph && !launch.diagnostic {
                FrameTimeGraph(samples: session.performance).equatable().padding(.horizontal, 12).padding(.top, headerVisible ? 64 : 12)
            } else if !bottom && showFPS && !launch.diagnostic {
                Button(action: wakeHeader) {
                    frameRate.padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.black.opacity(0.65), in: Capsule())
                }.buttonStyle(.plain).padding(.horizontal, 12).padding(.top, headerVisible ? 64 : 12)
                    .accessibilityLabel("Show game controls").accessibilityValue(String(format: "%.1f FPS", session.fps))
                    .accessibilityIdentifier("frameRate")
            }
        }
    }
    private func refreshPreferences() {
        preferences = PlayerPreferences(defaults: .standard)
        if let name = currentGame?.fileName, let custom = try? PlayerProfileStore(root: library.storage.root).read(name) { preferences = custom }
    }
    private func finishWidgetSwitch() {
        guard pendingWidgetSwitch, !session.stateBusy else { return }
        pendingWidgetSwitch = false; close()
    }
    private var leftControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) { ControlButton(label: "L", id: 10, session: session, small: true); ControlButton(label: "ZL", id: 12, session: session, small: true) }
            AnalogPad(session: session).frame(width: 86, height: 86)
            directionPad
        }
    }
    private var compactLeftControls: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                VStack(spacing: 0) {
                    ControlButton(label: "L", id: 10, session: session, small: true)
                    ControlButton(label: "ZL", id: 12, session: session, small: true)
                }
                AnalogPad(session: session).frame(width: 64, height: 64)
            }
            directionPad
        }
    }
    private var directionPad: some View {
        VStack(spacing: 0) {
            ControlButton(label: "↑", id: 4, session: session, size: 36)
            HStack(spacing: 20) { ControlButton(label: "←", id: 6, session: session, size: 36); ControlButton(label: "→", id: 7, session: session, size: 36) }
            ControlButton(label: "↓", id: 5, session: session, size: 36)
        }
    }
    private var rightControls: some View {
        VStack(spacing: 24) {
            HStack(spacing: 8) { ControlButton(label: "ZR", id: 13, session: session, small: true); ControlButton(label: "R", id: 11, session: session, small: true) }
            VStack(spacing: 0) {
                ControlButton(label: "X", id: 9, session: session)
                HStack(spacing: 28) { ControlButton(label: "Y", id: 1, session: session); ControlButton(label: "A", id: 8, session: session) }
                ControlButton(label: "B", id: 0, session: session)
            }
            if session.controllerName != nil { Image(systemName: "gamecontroller.fill").foregroundStyle(Palette.accent).font(.caption) }
        }
    }
    private func rememberScene() { if !launch.diagnostic, session.frames >= 120, let image = session.top { onPreview(image) } }
    private func close() { rememberScene(); session.close { dismiss() } }
}

private struct ControlButton: View {
    let label: String
    let id: UInt32
    @ObservedObject var session: EmulatorSession
    var small = false
    var size: CGFloat = 44
    @State private var held = false
    var body: some View {
        Text(label).font(.system(size: small ? 10 : 15, weight: .bold, design: .rounded))
            .frame(width: small ? 54 : size, height: small ? 28 : size)
            .foregroundStyle(held ? Palette.background : .white.opacity(0.8))
            .background {
                RoundedRectangle(cornerRadius: small ? 8 : size / 2)
                    .fill(LinearGradient(colors: held ? [Color.black, Color(white: 0.16)] : [Color(white: 0.28), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { RoundedRectangle(cornerRadius: small ? 8 : size / 2).stroke(.white.opacity(held ? 0.05 : 0.24), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.8), radius: held ? 0 : 2, y: held ? 0 : 3)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .overlay { TouchSurface { _, down in held = down; session.button(id, label, down) }.accessibilityHidden(true) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label).accessibilityAddTraits(.isButton)
            .accessibilityAction { session.button(id,label,true); session.button(id,label,false) }
    }
}

private struct AnalogPad: View {
    @ObservedObject var session: EmulatorSession
    @State private var offset = CGSize.zero
    var body: some View {
        GeometryReader { geometry in
        let diameter = min(geometry.size.width, geometry.size.height)
        ZStack {
            Circle().fill(.black).overlay { Circle().stroke(.white.opacity(0.07), lineWidth: 1) }
            Circle().fill(Palette.surface).frame(width: diameter * 0.628, height: diameter * 0.628).overlay { Circle().stroke(.white.opacity(0.1), lineWidth: 1) }.offset(offset)
        }.contentShape(Circle())
            .overlay {
                TouchSurface { point, down in
                    if down {
                        let x = Float((point.x - 0.5) / 0.372), y = Float((point.y - 0.5) / 0.372)
                        let distance = max(1, hypot(x, y))
                        session.analog(x: x / distance, y: y / distance)
                        offset = CGSize(width: CGFloat(x / distance) * diameter * 0.267, height: CGFloat(y / distance) * diameter * 0.267)
                    } else { offset = .zero; session.analog(x: 0, y: 0) }
                }.clipShape(Circle())
            }
            .accessibilityLabel("Circle pad")
        }
    }
}

private struct ConsoleShell: View {
    let top: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 26)
            .fill(LinearGradient(colors: [Color(white: 0.19), Color(white: 0.08), Color(white: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.17), lineWidth: 1) }
            .overlay {
                if top {
                    GeometryReader { area in
                        Circle().fill(.black).frame(width: 7, height: 7)
                            .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
                            .position(x: area.size.width / 2, y: 11)
                        ForEach([CGFloat(13), max(13, area.size.width - 13)], id: \.self) { x in
                            VStack(spacing: 5) {
                                ForEach(0..<6, id: \.self) { _ in
                                    HStack(spacing: 4) { Circle().frame(width: 2, height: 2); Circle().frame(width: 2, height: 2) }
                                }
                            }.foregroundStyle(.black.opacity(0.8)).position(x: x, y: area.size.height * 0.52)
                        }
                    }
                } else {
                    VStack { Spacer(); HStack(spacing: 6) {
                        Circle().fill(Color.blue.opacity(0.9)).frame(width: 3, height: 3)
                        Text("EMUDEN").font(.system(size: 7, weight: .bold, design: .rounded)).tracking(2).foregroundStyle(.white.opacity(0.25))
                    }.padding(.bottom, 8) }
                }
            }.accessibilityHidden(true).allowsHitTesting(false)
    }
}

