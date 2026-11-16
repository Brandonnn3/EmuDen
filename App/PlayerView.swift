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
    @State private var editingControls = false
    @State private var editingWasPaused = false
    @State private var controlLayoutKey = ""
    @AppStorage("touchControlLayouts") private var touchLayouts = Data()
    @State private var showingSettings = false
    @State private var showingGameMenu = false
    @State private var showingLayout = false
    @State private var showingSaveHistory = false
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
    @State private var viewport = CGSize.zero
    private var headerPinned: Bool {
        launch.diagnostic || session.booting || session.paused || session.closing || session.stateBusy ||
        editingControls || showingGameMenu || showingSettings || showingLayout || showingSaveHistory || session.offerResume || session.message != nil ||
        scenePhase != .active || UIAccessibility.isVoiceOverRunning
    }
    private var controlsVisible: Bool { showControls && !session.hasController }
    private var immersive: Bool { (!controlsVisible && controllerPresentation == "panels") || (session.hasController && viewport.width > viewport.height * 1.25) }
    private var fillPicture: Bool { preferences.sizing == .fill || (preferences.sizing == .automatic && immersive) }
    init(launch: Launch, saves: URL, onPreview: @escaping (UIImage) -> Void = { _ in }, onBoot: @escaping () -> Void) {
        self.launch = launch; self.saves = saves; self.onBoot = onBoot; self.onPreview = onPreview
        _session = StateObject(wrappedValue: EmulatorSession(diagnostic: launch.diagnostic, platform: launch.platform))
    }
    var body: some View {
        GeometryReader { geometry in
            let horizontal = geometry.size.width > geometry.size.height * 1.25
            Group {
                if launch.platform != .threeDS, (launch.platform == .ps1 ? preferences.ps1Folded : preferences.gameCubeFolded), let division = foldDivision(in: geometry) {
                    singleScreenFolded(size: geometry.size, division: division)
                } else if launch.platform == .threeDS, let division = foldDivision(in: geometry) {
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
                            Text(session.shaderStage.map { "Preparing graphics · " + $0 } ?? "Starting \(launch.platform.name)…").font(.subheadline)
                        }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).accessibilityIdentifier("graphicsPreparation")
                    }
                }
                .overlay { if session.closing { ProgressView("Closing game…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
                .overlay { if session.stateBusy && !session.savingState && !session.closing { ProgressView("Updating save state…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)) } }
                .overlay(alignment: .top) {
                    if session.savingState || session.notice != nil {
                        HStack(spacing: 7) {
                            if session.savingState { ProgressView().controlSize(.mini) }
                            else { Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint) }
                            Text(session.savingState ? "Saving…" : (session.notice ?? "")).font(.caption.weight(.semibold))
                        }.padding(.horizontal, 12).padding(.vertical, 8).background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 64).allowsHitTesting(false).accessibilityIdentifier("saveBanner")
                            .transition(.opacity)
                    }
                }
                .onChange(of: geometry.size, initial: true) { _, size in if controlsVisible { session.releaseTouchControls() }; viewport = size }
                .overlay(alignment: .top) { if editingControls { controlEditorBar.padding(.top, 8) } }
        }
        .ignoresSafeArea(.container, edges: immersive ? .all : [])
        .animation(ConsoleMotion.response(reduceMotion), value: controlsVisible)
        .overlay { if showingGameMenu { gameMenu.transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.97))) } }
        .animation(ConsoleMotion.response(reduceMotion), value: showingGameMenu)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if let url = launch.url {
                currentGame = library.games.first { library.storage.gameURL($0) == url } ?? Game(title: launch.title, fileName: url.lastPathComponent, programID: launch.platform == .threeDS ? ThreeDSProgramID.read(url) : nil, platform: launch.platform)
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
            else if phase == .inactive { session.suspend() }
            else if phase == .active { session.foreground(); if editingControls { session.setPaused(true) } }
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
            if !visible {
                closingMenu = false
                if !session.closing && !editingControls { Task { @MainActor in
                    if scenePhase == .active { session.setPaused(menuWasPaused) } else { session.suspend() }
                } }
            }
        }
        .onChange(of: scenePhase) { _, phase in menuAudio.setActive(showingGameMenu && phase == .active) }
        .onChange(of: session.offerResume) { _, offered in showingResumePrompt = offered }
        .onChange(of: session.message) { _, message in showingSessionMessage = message != nil }
        .alert("Resume your session?", isPresented: $showingResumePrompt) {
            Button("Resume session") { Task {
                session.offerResume = false
                if let latest = session.saveHistory.first { await session.load(latest, resuming: true) }
                session.setPaused(false)
            } }
            Button("Start normally") { Task { @MainActor in session.offerResume = false; session.setPaused(false) } }
        } message: { Text("Your latest snapshot is from \(session.saveHistory.first?.date.formatted(date: .abbreviated, time: .shortened) ?? "your last session"). Earlier points are in the pause menu's Save history. Your game's own saves are kept separately.") }
        .alert("EmuDen message", isPresented: $showingSessionMessage) {
            Button("OK") { Task { @MainActor in session.message = nil } }
            Button("Return without resume point") { Task { @MainActor in session.message = nil; session.closeWithoutState { dismiss() } } }
        } message: { Text(session.message ?? "") }
    }
    private func controlCanvas(size: CGSize, area: CGRect, startArea: CGRect, mode: String) -> some View {
        TouchControls(session: session, size: size, area: area, startArea: startArea, mode: mode, editing: editingControls)
            .onAppear { controlLayoutKey = launch.platform.rawValue + "." + mode }
            .onChange(of: mode) { _, value in controlLayoutKey = launch.platform.rawValue + "." + value }
    }
    private func standardPlayer(horizontal: Bool, insets: EdgeInsets) -> some View {
        GeometryReader { geometry in
            let size = geometry.size
            let bounds = CGRect(origin: .zero, size: size)
            let controlHeight = min(340.0, size.height * 0.49)
            let video = !controlsVisible ? bounds : (horizontal ? CGRect(x: 150, y: 0, width: max(0, size.width - 300), height: max(0, size.height - 48)) : CGRect(x: 12, y: 0, width: max(0, size.width - 24), height: max(0, size.height - controlHeight - 48)))
            let area = horizontal ? CGRect(x: 4, y: 48, width: size.width - 8, height: max(0, size.height - 104)) : CGRect(x: 4, y: video.maxY + 4, width: size.width - 8, height: controlHeight - 4)
            let start = CGRect(x: 0, y: size.height - 48, width: size.width, height: 44)
            ZStack(alignment: .topLeading) {
                screens(horizontal: horizontal).frame(width: video.width, height: video.height).position(x: video.midX, y: video.midY)
                if controlsVisible { controlCanvas(size: size, area: area, startArea: start, mode: horizontal ? "landscape" : "portrait") }
            }.frame(width: size.width, height: size.height)
                .background { if !immersive { ConsoleShell(top: false) } }
                .overlay(alignment: .top) {
                    if !editingControls { toolbar.padding(.horizontal, horizontal ? 18 : 16).padding(.top, 12 + (immersive ? insets.top : 0)) }
                }
        }
    }
    private func singleScreenFolded(size: CGSize, division: CGRect) -> some View {
        let layout = DuoLayout(size: size, division: division, controls: false, immersive: true)
        let top = DuoLayout.fit(aspect: 4.0 / 3, in: layout.topPanel)
        let panel = layout.bottomPanel
        let ps1 = launch.platform == .ps1
        let blank = !ps1 && preferences.gameCubePanelBlank
        let fps = ps1 ? preferences.ps1PanelFPS : preferences.gameCubePanelFPS
        let saves = ps1 ? preferences.ps1PanelSaves : preferences.gameCubePanelSaves
        let speed = ps1 && preferences.ps1PanelSpeed
        let prefix = ps1 ? "ps1" : "gameCube"
        let touch = editingControls || (!blank && controlsVisible && (ps1 ? preferences.ps1PanelTouch : preferences.gameCubePanelTouch))
        let quickHeight: CGFloat = !blank && !editingControls && (ps1 || !touch) && (speed || fps || saves) ? (touch ? min(112, panel.height * 0.27) : panel.height) : 0
        let area = CGRect(x: 4, y: quickHeight + 8, width: max(0, panel.width - 8), height: max(0, panel.height - quickHeight - 60))
        return ZStack(alignment: .topLeading) {
            screen(image: session.top, bottom: false).frame(width: top.width, height: top.height).position(x: top.midX, y: top.midY)
            ZStack(alignment: .topLeading) {
                Color.black.allowsHitTesting(false)
                if quickHeight > 0 {
                    ScrollView {
                        VStack(spacing: 8) {
                            if speed { playbackSpeedControl }
                            if fps { HStack { Label("Frame rate", systemImage: "waveform.path.ecg"); Spacer(); frameRate }.font(.subheadline).accessibilityIdentifier(prefix + "PanelFrameRate") }
                            if saves {
                                HStack(spacing: 12) {
                                    Button { Task { await session.save(.quick) } } label: {
                                        Label("Quick Save", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                                    }.background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier(prefix + "PanelSave")
                                    Button { Task { await session.load(.quick) } } label: {
                                        Label("Quick Load", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                                    }.background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14)).disabled(session.quickDate == nil).accessibilityIdentifier(prefix + "PanelLoad")
                                }.font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8).buttonStyle(ConsolePressStyle()).disabled(session.stateBusy || session.closing)
                            }
                        }.padding(.horizontal, 20).padding(.vertical, 8).frame(maxWidth: 620).frame(maxWidth: .infinity)
                    }.frame(height: quickHeight)
                }
                if touch {
                    // Touch controls never belong to the quick-settings ScrollView.
                    controlCanvas(size: panel.size, area: area, startArea: CGRect(x: 0, y: panel.height - 48, width: panel.width, height: 44), mode: division.width > division.height ? "tabletop" : "book")
                }
            }.frame(width: panel.width, height: panel.height).position(x: panel.midX, y: panel.midY).accessibilityElement(children: .contain).accessibilityIdentifier(prefix + "QuickPanel")
            if !editingControls { toolbar.frame(width: max(0, layout.topPanel.width - 32), height: 44).position(x: layout.topPanel.midX, y: layout.topPanel.minY + 34) }
        }.frame(width: size.width, height: size.height)
    }
    private var controlEditorBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 20) {
                Text("Move controls").font(.headline)
                Spacer()
                Button("Reset") {
                    var layouts = ControlLayouts.decode(touchLayouts); layouts.layouts.removeValue(forKey: controlLayoutKey); touchLayouts = layouts.encoded()
                }.accessibilityIdentifier("resetTouchLayout")
                Button("Done") { editingControls = false; session.releaseTouchControls(); session.setPaused(editingWasPaused) }.fontWeight(.bold).accessibilityIdentifier("finishTouchLayout")
            }
            Text("Drag each button or stick. Saved for this console and orientation.").font(.caption).foregroundStyle(.secondary)
        }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20)).padding(.horizontal, 12)
    }
    private func foldDivision(in geometry: GeometryProxy) -> CGRect? {
        // UI test fixtures exercise both fold axes without depending on Device Hub's pose controls.
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--duo-tabletop-preview") {
            return CGRect(x: 0, y: geometry.size.height / 2 - 10, width: geometry.size.width, height: 20)
        }
#endif
        if launch.diagnostic && ProcessInfo.processInfo.arguments.contains("--duo-tabletop-preview") {
            return CGRect(x: 0, y: geometry.size.height / 2 - 10, width: geometry.size.width, height: 20)
        }
        if launch.diagnostic && ProcessInfo.processInfo.arguments.contains("--duo-book-preview") {
            return CGRect(x: geometry.size.width / 2 - 10, y: 0, width: 20, height: geometry.size.height)
        }
        if #available(iOS 27.1, *),
           let region = geometry.reservedRegions(kind: .division, options: launch.platform == .threeDS ? .includeInactive : [], layoutDirectionBehavior: .fixed).first {
            return DuoLayout.usableDivision(region.frame.inset(by: UIEdgeInsets(top: -region.margins.top, left: -region.margins.leading,
                                                     bottom: -region.margins.bottom, right: -region.margins.trailing)), in: geometry.size)
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
            if !editingControls { toolbar.frame(width: max(0, layout.topPanel.width - 32), height: 44)
                .position(x: layout.topPanel.midX, y: layout.topPanel.minY + 34) }
            if controlsVisible {
                controlCanvas(size: size, area: layout.controlsArea, startArea: layout.startArea, mode: division.width > division.height ? "tabletop" : "book")
            }
        }.frame(width: size.width, height: size.height)
            .overlay { if session.paused { Label("Paused", systemImage: "pause.fill").padding(20).background(.regularMaterial, in: Capsule()) } }
    }
    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: close) { Image(systemName: "chevron.down").frame(width: 44, height: 44).cinematicGlass(radius: 24, interactive: true) }
                .accessibilityLabel("Return to library").accessibilityIdentifier("playerBack")
            VStack(alignment: .leading, spacing: 3) {
                Text(launch.title).font(.subheadline.bold()).lineLimit(1)
                Text(launch.diagnostic ? "INPUT & DISPLAY TEST" : (launch.platform == .ps1 ? "PS1 · INTERPRETER" : (launch.platform == .gamecube ? "GAMECUBE · EXPERIMENTAL" : "3DS · METAL GPU"))).font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
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
    private var playbackSpeedControl: some View {
        HStack(spacing: 6) {
            ForEach([1.0, 1.5, 2.0], id: \.self) { speed in
                Button {
                    menuAudio.play(.focus); session.setPlaybackSpeed(speed)
                } label: {
                    Text("\(speed.formatted())×").font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.white.opacity(session.playbackSpeed == speed ? 0.2 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                }.accessibilityIdentifier("ps1Speed-\(speed)")
                    .accessibilityValue(session.playbackSpeed == speed ? "Selected" : "")
                    .accessibilityAddTraits(session.playbackSpeed == speed ? .isSelected : [])
            }
        }.buttonStyle(ConsolePressStyle()).padding(4)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain).accessibilityLabel("Playback speed").accessibilityIdentifier("ps1PlaybackSpeed")
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
                                        Button("Graphics settings", systemImage: "slider.horizontal.3") { menuAudio.play(.open); showingSettings = true }
                                        Button("Customize controls", systemImage: "hand.draw") {
                                            editingWasPaused = menuWasPaused; showControls = true; session.releaseTouchControls()
                                            showingGameMenu = false; editingControls = true; session.setPaused(true)
                                        }.disabled(session.hasController).accessibilityIdentifier("customizeTouchControls")
                                        Button("Load Resume Point", systemImage: "clock.arrow.circlepath") { performState(.resume, load: true) }.disabled(session.resumeDate == nil || session.booting)
                                    } label: { Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold)).frame(width: 44, height: 44) }
                                        .accessibilityLabel("More game options").accessibilityIdentifier("moreGameOptions")
                                }
                            if launch.platform == .ps1 { playbackSpeedControl }
                            Button(action: resumeGameMenu) { CinematicActionLabel(title: "Resume", symbol: "play.fill", primary: true) }.accessibilityLabel("Resume game")
                            Button { performState(.quick, load: false) } label: { CinematicActionLabel(title: "Quick save", symbol: "square.and.arrow.down", disclosure: false) }
                                .cinematicGlass(radius: 28, interactive: true).accessibilityLabel("Quick Save").disabled(session.booting || launch.diagnostic)
                            Button { performState(.quick, load: true) } label: { CinematicActionLabel(title: "Quick load", symbol: "square.and.arrow.up", disclosure: false) }
                                .cinematicGlass(radius: 28, interactive: true).accessibilityLabel("Quick Load").disabled(session.quickDate == nil || session.booting)
                            Button { menuAudio.play(.open); showingSaveHistory = true } label: { CinematicActionLabel(title: "Save history", symbol: "clock.arrow.circlepath") }
                                .cinematicGlass(radius: 28, interactive: true).accessibilityIdentifier("openSaveHistory").disabled(session.booting || launch.diagnostic)
                            if launch.platform == .threeDS { Button { menuAudio.play(.open); showingLayout = true } label: { CinematicActionLabel(title: "Screen layout", symbol: "rectangle.split.1x2") }
                                .cinematicGlass(radius: 28, interactive: true).accessibilityIdentifier("openGameDuoLayout")
                            }
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
                    PlayerSettingsView(game: currentGame, isPlaying: !launch.diagnostic, controllerConnected: session.hasController, topPreview: session.top, bottomPreview: session.bottom, motionStatus: session.motionStatus)
                }
                .sheet(isPresented: $showingSaveHistory) {
                    SaveStateHistoryView(session: session) { entry in
                        showingSaveHistory = false; closingMenu = true; menuAudio.play(.confirm)
                        Task {
                            await session.load(entry)
                            closingMenu = false
                            if session.message == nil { menuAudio.play(.save); showingGameMenu = false }
                        }
                    }
                }
                .fullScreenCover(isPresented: $showingLayout) { DuoLayoutSettingsView(system: ConsoleSystem(rawValue: launch.platform.rawValue) ?? .threeDS, controllerConnected: session.hasController, topPreview: session.top, bottomPreview: session.bottom) }
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
        if !load {
            showingGameMenu = false
            session.setPaused(menuWasPaused)
        }
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
            if launch.platform != .threeDS {
                let rect = fillPicture ? CGRect(origin: .zero, size: area.size) : DuoLayout.fit(aspect: 4.0 / 3, in: CGRect(origin: .zero, size: area.size))
                screen(image: session.top, bottom: false).frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            } else if immersive || preferences.sizing != .automatic || preferences.screenBalance != 0.5 {
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
            if launch.platform == .gamecube {
                NativeGameCubeSurface(bridge: session.bridge)
                    .accessibilityLabel("GameCube screen")
                    .accessibilityIdentifier("topScreen")
                    .accessibilityValue(session.frameDescription)
            } else if let image {
                Image(uiImage: image).resizable().interpolation(launch.platform == .ps1 && preferences.ps1Smooth ? .medium : .none)
                    .accessibilityLabel(launch.platform == .ps1 ? "PlayStation screen" : (bottom ? "3DS bottom screen" : "3DS top screen"))
                    .accessibilityIdentifier(bottom ? "bottomScreen" : "topScreen")
                    .accessibilityValue(session.frameDescription)
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
    private func rememberScene() { if !launch.diagnostic, session.frames >= 120, let image = session.top { onPreview(image) } }
    private func close() { session.close { rememberScene(); dismiss() } }
}

private struct NativeGameCubeSurface: UIViewRepresentable {
    let bridge: EmulatorBridge
    func makeUIView(context: Context) -> Surface { Surface(bridge: bridge) }
    func updateUIView(_ view: Surface, context: Context) { view.setNeedsLayout() }
    static func dismantleUIView(_ view: Surface, coordinator: ()) {
        if view.bridge.nativeLayer.superlayer === view.layer { view.bridge.nativeLayer.removeFromSuperlayer() }
    }
    final class Surface: UIView {
        let bridge: EmulatorBridge
        init(bridge: EmulatorBridge) {
            self.bridge = bridge
            super.init(frame: .zero)
            backgroundColor = .black; isAccessibilityElement = true
            bridge.nativeLayer.removeFromSuperlayer()
            layer.addSublayer(bridge.nativeLayer)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() {
            super.layoutSubviews()
            let metal = bridge.nativeLayer
            let scale = window?.screen.scale ?? traitCollection.displayScale
            let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
            let changed = metal.drawableSize != size
            CATransaction.begin(); CATransaction.setDisableActions(true)
            metal.frame = bounds; metal.contentsScale = scale; metal.drawableSize = size
            CATransaction.commit()
            if changed { bridge.nativeSurfaceChanged() }
        }
    }
}

private struct SaveStateHistoryView: View {
    @ObservedObject var session: EmulatorSession
    let onLoad: (SaveStateStore.Entry) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var menuAudio: MenuAudio
    @State private var selected: SaveStateStore.Entry?
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CinematicPageHeading(title: "Save history", subtitle: "Return to an earlier moment", symbol: "clock.arrow.circlepath", onClose: { menuAudio.play(.back); dismiss() }, closeID: "saveHistoryDone")
                    .padding(24).frame(maxWidth: 740).frame(maxWidth: .infinity)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Snapshots restore the whole session, including the game's save memory at that moment. The game's own Save / Continue feature is separate. Keep using it too.")
                            .font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
                        ForEach(SaveStateStore.Slot.allCases, id: \.self) { slot in
                            let entries = session.saveHistory.filter { $0.slot == slot }
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Label(slot == .quick ? "Quick Saves" : "Automatic points", systemImage: slot == .quick ? "bookmark.fill" : "clock.fill").font(.headline)
                                    Spacer()
                                    Text("\(entries.count) / \(slot == .quick ? 10 : 3)").font(.caption).monospacedDigit().foregroundStyle(ConsoleTheme.quiet)
                                }
                                if entries.isEmpty {
                                    Text(slot == .quick ? "Choose Quick Save in the pause menu to keep a moment here." : "A point is kept when you close or background the game, and every five minutes of active play when enabled.")
                                        .font(.subheadline).foregroundStyle(ConsoleTheme.quiet)
                                }
                                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                    Button { menuAudio.play(.focus); selected = entry } label: {
                                        HStack(spacing: 14) {
                                            SaveStateThumbnail(data: session.previewData(entry)).frame(width: 100, height: 60).clipShape(RoundedRectangle(cornerRadius: 12))
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(entry.date.formatted(date: .abbreviated, time: .standard)).font(.subheadline.weight(.semibold))
                                                Text(index == 0 ? "Latest · \(ByteCountFormatter.string(fromByteCount: Int64(entry.bytes), countStyle: .file))" : ByteCountFormatter.string(fromByteCount: Int64(entry.bytes), countStyle: .file))
                                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                            }.frame(maxWidth: .infinity, alignment: .leading)
                                            Image(systemName: "arrow.uturn.backward").foregroundStyle(ConsoleTheme.quiet)
                                        }.padding(12).cinematicGlass(radius: 18, interactive: true)
                                    }.accessibilityIdentifier("saveHistory-\(slot.rawValue)-\(index)")
                                        .accessibilityValue(entry.date.formatted(date: .abbreviated, time: .standard))
                                }
                            }.cinematicCard()
                        }
                        if session.hasOlderSnapshots {
                            Label("Older snapshots are preserved on disk, but can't be restored with the current core or imported system resources. In-game saves remain available.", systemImage: "info.circle")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet).cinematicCard()
                        }
                        Text("Keeps the latest 10 manual and 3 automatic points per game. Older points are replaced as new ones are saved. Removing the app may remove local saves.")
                            .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                    }.padding(24).frame(maxWidth: 740).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }.background {
                ConsoleTheme.ink.ignoresSafeArea()
                if let image = session.top { Image(uiImage: image).resizable().scaledToFill().blur(radius: 35).opacity(0.2).ignoresSafeArea() }
            }.toolbar(.hidden, for: .navigationBar)
        }.foregroundStyle(.white).tint(ConsoleTheme.blue).buttonStyle(ConsolePressStyle()).statusBarHidden(true)
            .confirmationDialog("Load this save point?", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
                if let selected { Button("Load save point") { onLoad(selected); self.selected = nil } }
            } message: { Text("This replaces the current session with the selected snapshot. Other snapshots stay in your history.") }
    }
}

private struct SaveStateThumbnail: View {
    let data: Data?
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
            if let data, let image = ArtworkStore.decode(data, maxSize: 320) { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(systemName: "bookmark").font(.title2).foregroundStyle(ConsoleTheme.quiet) }
        }.accessibilityHidden(true)
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

