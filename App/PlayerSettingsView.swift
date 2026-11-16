import SwiftUI
import UniformTypeIdentifiers

struct PlayerSettingsView: View {
    @EnvironmentObject private var library: GameLibrary
    @EnvironmentObject private var menuAudio: MenuAudio
    @Environment(\.dismiss) private var dismiss
    @AppStorage("buttonHaptics") private var buttonHaptics = true
    @AppStorage("showFPS") private var showFPS = false
    @AppStorage("showFrameGraph") private var showGraph = false
    @AppStorage("automaticResumeSaves") private var automaticResumeSaves = true
    @State private var section = "Graphics"
    @State private var selectedSystem = ConsoleSystem.threeDS
    @State private var showingDuo = false
    @State private var importingBIOS = false
    @State private var biosNames = [String]()
    @State private var preferences = PlayerPreferences()
    @State private var custom = false
    @State private var loaded = false
    @State private var cacheBytes: Int64 = 0
    @State private var confirmingReset = false
    @State private var error: String?
    var game: Game?
    var isPlaying = false
    var controllerConnected = false
    var topPreview: UIImage?
    var bottomPreview: UIImage?
    var motionStatus: String?
    var initialSystem: ConsoleSystem = .threeDS
    private var settingsPlatform: GamePlatform? { game?.console ?? GamePlatform(rawValue: selectedSystem.rawValue) }
    private var profiles: PlayerProfileStore { PlayerProfileStore(root: library.storage.root) }
    private var editable: Bool { game == nil || custom }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CinematicPageHeading(title: "Graphics settings", subtitle: game?.displayName ?? "Default settings for your games", symbol: "slider.horizontal.3", onClose: { menuAudio.play(.back); dismiss() }, closeID: "playerSettingsDone")
                    .padding(.horizontal, 24).padding(.top, 24).frame(maxWidth: 740).frame(maxWidth: .infinity).cinematicEntrance()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if game == nil {
                            Picker("Console", selection: $selectedSystem) {
                                ForEach(ConsoleSystem.visibleSystems) { Text($0.name).tag($0) }
                            }.accessibilityIdentifier("graphicsConsole").cinematicCard()
                        }
                        Picker("Settings category", selection: $section) {
                            Text("Graphics").tag("Graphics")
                            Text("Controls").tag("Controls")
                            Text("Saves & system").tag("Saves & system")
                        }.pickerStyle(.segmented).accessibilityIdentifier("graphicsCategory")
                        if game != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                Toggle("Customize this game", isOn: $custom).accessibilityIdentifier("customizeGame")
                                Text(custom ? "These choices belong to this game. Your app defaults stay separate." : "Using app defaults. Turn this on to keep a different setup for this game.")
                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }.cinematicCard()
                        }
                        if section == "Graphics", let platform = settingsPlatform {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Quick setup", systemImage: "slider.horizontal.3").font(.headline)
                                HStack(spacing: 10) {
                                    ForEach(PlayerPreferences.Preset.allCases, id: \.self) { preset in
                                        Button(preset.rawValue) { preferences.apply(preset, for: platform) }
                                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                            .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                                            .accessibilityIdentifier("graphicsPreset-" + preset.rawValue)
                                    }
                                }
                                Text("Performance keeps native resolution. Balanced adds detail; Sharp favors clarity and uses more power. You can refine any choice below.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }.disabled(!editable).cinematicCard()
                        }
                        if section == "Graphics" && settingsPlatform == .threeDS {
                        VStack(alignment: .leading, spacing: 18) {
                            Label("3DS graphics", systemImage: "sparkles.tv").font(.headline)
                            ResolutionSetting(value: $preferences.resolution)
                            Toggle("Reduce shader pauses", isOn: $preferences.asyncShaders)
                            Text("Build new effects in the background. Some objects may briefly appear late.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            Divider()
                            Picker("Texture appearance", selection: $preferences.sampling) {
                                ForEach(PlayerPreferences.Sampling.allCases, id: \.self) { Text($0.title).tag($0) }
                            }.accessibilityIdentifier("textureSampling")
                            Text("Game default preserves the game's own choices. Crisp keeps hard edges; Smooth softens texture sampling.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            Toggle("Automatic quality", isOn: $preferences.automaticQuality).accessibilityIdentifier("automaticQuality")
                            Text("Uses your resolution as a ceiling. Lowers it after sustained slowdown or heat and recovers gradually, down to 1×. A single shader pause won’t trigger a change.")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            if isPlaying { Text("Graphics changes apply when you resume. A resolution change can briefly rebuild graphics.").font(.caption).foregroundStyle(ConsoleTheme.quiet) }
                        }.disabled(!editable).cinematicCard().cinematicEntrance(delay: 0.04)
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Shader cache", systemImage: "square.stack.3d.up").font(.headline)
                            Toggle("Prepare known shaders before play", isOn: $preferences.prepareShaders).disabled(!editable).accessibilityIdentifier("prepareShaders")
                            Text("Trades a longer startup for finishing cached effects before play, with visible progress. Applies the next time you open a game. New effects still need to be learned.")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            if let id = game?.programID {
                                HStack { Text("This game's cache"); Spacer(); Text(ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file)).monospacedDigit().foregroundStyle(ConsoleTheme.quiet) }.font(.subheadline)
                                Button("Reset this game's shader cache", role: .destructive) { confirmingReset = true }
                                    .accessibilityIdentifier("resetShaderCache").disabled(isPlaying || cacheBytes == 0)
                                Text(isPlaying ? "Close the game before resetting its cache." : "Reset only if graphics misbehave. Your saves and Mii resources stay in place. The cache rebuilds as you play.")
                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                    .accessibilityValue(id)
                            } else { Text("Open a game's settings from its cover to inspect its cache.").font(.caption).foregroundStyle(ConsoleTheme.quiet) }
                        }.cinematicCard().cinematicEntrance(delay: 0.08)
                        }
                        if settingsPlatform == .ps1 {
                            if section == "Graphics" { VStack(alignment: .leading, spacing: 16) {
                                Label("PlayStation graphics", systemImage: "sparkles.tv").font(.headline)
                                Picker("Internal resolution", selection: $preferences.ps1Resolution) {
                                    Text("1× · Original").tag(1)
                                    Text("2× · Enhanced").tag(2)
                                }.pickerStyle(.segmented).accessibilityIdentifier("ps1Resolution")
                                Text("2× renders supported 3D scenes at twice the original resolution. High-resolution game modes and most 2D artwork keep their original detail. Uses more power; switch to 1× if a game slows down or has visual issues.")
                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Toggle("Automatic quality", isOn: $preferences.ps1AutomaticQuality).accessibilityIdentifier("ps1AutomaticQuality")
                                Text("Uses your resolution as a ceiling. Falls back to 1× after sustained slowdown or heat, then restores 2× gradually. Pauses adjustments during fast-forward.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Toggle("Smooth display scaling", isOn: $preferences.ps1Smooth).accessibilityIdentifier("ps1Smooth")
                                Text("Softens the final picture as it fits the display. Turn off for crisp pixels. This does not add internal rendering detail.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Toggle("Color dithering", isOn: $preferences.ps1Dithering).accessibilityIdentifier("ps1Dithering")
                                Text("Preserves the console's pattern for smoother color gradients. Turn off if you prefer cleaner flat colors.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Toggle("2× texture alignment fix", isOn: $preferences.ps1TextureFix).disabled(preferences.ps1Resolution != 2).accessibilityIdentifier("ps1TextureFix")
                                Text("Helps texture alignment in enhanced resolution. Try turning it off if a game shows texture seams.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                if isPlaying { Text("Applies when you resume.").font(.caption).foregroundStyle(ConsoleTheme.quiet) }
                            }.disabled(!editable).cinematicCard() }
                            if section == "Controls" { VStack(alignment: .leading, spacing: 14) {
                                Toggle("Analog controller", isOn: $preferences.ps1Analog).accessibilityIdentifier("ps1Analog")
                                Text("Enables both analog sticks for compatible games. Leave off for titles that require the original digital controller; the left stick then acts as a D-pad. Changing this reconnects the emulated controller.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Divider()
                                Label("Folded PlayStation layout", systemImage: "rectangle.split.1x2").font(.headline)
                                Toggle("Move video above the fold", isOn: $preferences.ps1Folded).accessibilityIdentifier("ps1Folded")
                                Text("Bend the inner display to move the game to one side of the fold. Unfold it to return to full-screen play. A connected controller keeps touch buttons hidden.")
                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Group {
                                    Toggle("Speed control", isOn: $preferences.ps1PanelSpeed).accessibilityIdentifier("ps1PanelSpeed")
                                    Toggle("FPS readout", isOn: $preferences.ps1PanelFPS).accessibilityIdentifier("ps1PanelFPS")
                                    Toggle("Quick Save and Quick Load", isOn: $preferences.ps1PanelSaves).accessibilityIdentifier("ps1PanelSaves")
                                    Toggle("Touch controls", isOn: $preferences.ps1PanelTouch).accessibilityIdentifier("ps1PanelTouch")
                                }.disabled(!preferences.ps1Folded)
                                Text("Turn off all four to leave the lower panel blank. Playback speed offers 1×, 1.5× and 2×; fast-forward also raises audio pitch. Actual speed depends on the game and available performance.")
                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }.disabled(!editable).cinematicCard() }
                            if section == "Saves & system" { VStack(alignment: .leading, spacing: 14) {
                                Label("PlayStation BIOS", systemImage: "opticaldisc").font(.headline)
                                Text(biosNames.isEmpty ? "Using built-in HLE BIOS" : "Console BIOS ready: " + biosNames.joined(separator: ", ")).font(.subheadline)
                                Text("HLE can run many games. For better compatibility, import your own SCPH-5500, 5501 or 5502 BIOS dump. Memory cards are separate for each game; no firmware is bundled or downloaded.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Button("Import PlayStation BIOS", systemImage: "square.and.arrow.down") { importingBIOS = true }.disabled(isPlaying).accessibilityIdentifier("importPS1BIOS")
                                if isPlaying { Text("Return to the library before importing BIOS.").font(.caption).foregroundStyle(ConsoleTheme.quiet) }
                            }.cinematicCard() }
                        }
                        if section == "Graphics" && settingsPlatform == .gamecube {
                            VStack(alignment:.leading,spacing:12) {
                                Label("GameCube graphics",systemImage:"cube").font(.headline)
                                Picker("Internal resolution", selection: $preferences.gameCubeResolution) {
                                    ForEach(1...4, id: \.self) { Text($0 == 1 ? "1× · Native" : "\($0)×").tag($0) }
                                }.pickerStyle(.segmented).accessibilityIdentifier("gameCubeResolution")
                                Text("Renders GameCube geometry at up to four times native resolution. Higher settings use more GPU power and may slow some games. Start at 2× and lower it if needed; source artwork keeps its original detail.")
                                    .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Picker("Texture appearance", selection: $preferences.gameCubeSampling) {
                                    ForEach(PlayerPreferences.Sampling.allCases, id: \.self) { Text($0.title).tag($0) }
                                }.accessibilityIdentifier("gameCubeSampling")
                                Picker("Anisotropic filtering", selection: $preferences.gameCubeAnisotropy) {
                                    Text("Game default").tag(0)
                                    ForEach([1, 2, 4, 8, 16], id: \.self) { Text("\($0)×").tag($0) }
                                }.accessibilityIdentifier("gameCubeAnisotropy")
                                Text("Keeps textured surfaces clearer at an angle. Crisp texture sampling can reduce the effect. Graphics changes apply when you resume.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }.disabled(!editable).cinematicCard()
                        }
                        if section == "Graphics" { VStack(alignment: .leading, spacing: 16) {
                            Label("Screen appearance", systemImage: "rectangle.split.1x2").font(.headline)
                            Picker("Picture sizing", selection: $preferences.sizing) {
                                ForEach(PlayerPreferences.Sizing.allCases, id: \.self) { Text((settingsPlatform == .ps1 || settingsPlatform == .gamecube) && $0 == .fill ? "Fill screen" : $0.title).tag($0) }
                            }.accessibilityIdentifier("pictureSizing")
                            if settingsPlatform == .ps1 || settingsPlatform == .gamecube { Text("Automatic fills controller layouts. Original preserves the game's 4:3 proportions. Touch controls have their own space beside the picture in landscape.").font(.caption).foregroundStyle(ConsoleTheme.quiet) }
                            if settingsPlatform == .threeDS || settingsPlatform == .ps1 {
                                Divider()
                                Picker("Display frame rate", selection: $preferences.presentation) {
                                    ForEach(PlayerPreferences.Presentation.allCases, id: \.self) { Text($0.title).tag($0) }
                                }.accessibilityIdentifier("framePresentation")
                                Text("30 fps reduces display updates and image copying; game speed, audio and input continue normally. Automatic follows the game, switching to 30 fps when the system reports high heat. This does not raise a game's frame rate.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }
                            if settingsPlatform == nil || settingsPlatform == .threeDS {
                            HStack { Text("Top screen balance"); Spacer(); Text(preferences.screenBalance.formatted(.percent.precision(.fractionLength(0)))).foregroundStyle(ConsoleTheme.quiet) }.font(.subheadline)
                            Slider(value: $preferences.screenBalance, in: 0.35...0.65, step: 0.05).accessibilityLabel("Top screen balance").accessibilityIdentifier("screenBalance")
                            Text("Balance adjusts flat layouts. The inner display keeps each screen on its side of the fold. Original proportions may leave borders; Fill stretches each screen.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }
                        }.disabled(!editable).cinematicCard().cinematicEntrance(delay: 0.12) }
                        if section == "Saves & system" { VStack(alignment: .leading, spacing: 16) {
                            Label("Save history", systemImage: "clock.arrow.circlepath").font(.headline)
                            Toggle("Automatic save points", isOn: $automaticResumeSaves).accessibilityIdentifier("automaticResumeSaves")
                            Text("Keeps a resume point every five minutes of active play. Capturing a point briefly pauses the game. Backgrounding or closing a game also saves a resume point. Keep using the game's own save feature too.")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            Text("The pause menu's Save history keeps your latest 10 Quick Saves and 3 automatic points per game. These settings apply to every game.")
                                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        }.cinematicCard().cinematicEntrance(delay: 0.16) }
                        if section == "Graphics" { VStack(alignment: .leading, spacing: 16) {
                            Label("Performance readouts", systemImage: "waveform.path.ecg").font(.headline)
                            Toggle("Show FPS", isOn: $showFPS).accessibilityIdentifier("showFPS")
                            Toggle("Show frame-time graph", isOn: $showGraph).accessibilityIdentifier("showFrameGraph")
                            Text("The optional graph shows core frame time, the worst frame each second, emulation speed and the system's heat status. These display choices apply to every game.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                        }.cinematicCard() }
                        if section == "Controls" && settingsPlatform == .gamecube {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Folded GameCube layout", systemImage: "rectangle.split.1x2").font(.headline)
                                Toggle("Move video above the fold", isOn: $preferences.gameCubeFolded).accessibilityIdentifier("gameCubeFolded")
                                Text("Bend the inner display to keep the game above the fold, including with a connected controller. Unfold to return to the full display.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                Group {
                                    Toggle("Blank lower panel", isOn: $preferences.gameCubePanelBlank).accessibilityIdentifier("gameCubePanelBlank")
                                    Group {
                                        Toggle("FPS readout", isOn: $preferences.gameCubePanelFPS).accessibilityIdentifier("gameCubePanelFPS")
                                        Toggle("Quick Save and Quick Load", isOn: $preferences.gameCubePanelSaves).accessibilityIdentifier("gameCubePanelSaves")
                                        Toggle("Touch controls", isOn: $preferences.gameCubePanelTouch).accessibilityIdentifier("gameCubePanelTouch")
                                    }.disabled(preferences.gameCubePanelBlank)
                                }.disabled(!preferences.gameCubeFolded)
                                Text("With a controller, choose the quick controls below the game, or leave it completely blank. Touch play keeps that space for buttons. Quick Saves are separate from the game's memory card.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                            }.disabled(!editable).cinematicCard()
                        }
                        if section == "Controls" {
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Touch controls & layout", systemImage: "hand.draw").font(.headline)
                                Toggle("Button haptics", isOn: $buttonHaptics)
                                Text("Open Game menu → More → Customize controls while playing to drag each button or stick. Positions are saved by console and orientation. Reset restores that layout’s defaults.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                if settingsPlatform == .threeDS {
                                    Toggle("Motion controls", isOn: $preferences.motionControls).disabled(!editable).accessibilityIdentifier("motionControls")
                                    Text(motionStatus ?? "Use this phone’s gyroscope and accelerometer for supported 3DS games. Motion follows the display orientation and stops while paused or in the background.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
                                }
                                Button { menuAudio.play(.open); showingDuo = true } label: { CinematicSettingRow(title: "Duo layout", detail: "Console skin and controller display", symbol: "rectangle.split.1x2") }.accessibilityIdentifier("openPlayerDuoLayout")
                            }.cinematicCard()
                        }
                    }.padding(24).frame(maxWidth: 740).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden).accessibilityIdentifier("playerSettingsScroll")
            }.background { CinematicScene(game: game, system: ConsoleSystem(rawValue: (settingsPlatform ?? .threeDS).rawValue) ?? .threeDS, subdued: true).ignoresSafeArea() }
                .toolbar(.hidden, for: .navigationBar)
        }.tint(ConsoleTheme.blue).buttonStyle(ConsolePressStyle()).statusBarHidden(true)
            .onAppear(perform: load)
            .onChange(of: preferences) { _, _ in persist() }
            .onChange(of: showFPS) { _, _ in menuAudio.play(.focus) }
            .onChange(of: showGraph) { _, _ in menuAudio.play(.focus) }
            .onChange(of: automaticResumeSaves) { _, _ in menuAudio.play(.focus) }
            .onChange(of: buttonHaptics) { _, _ in menuAudio.play(.focus) }
            .onChange(of: custom) { _, enabled in
                guard loaded, let game else { return }
                do {
                    try profiles.write(enabled ? preferences : nil, for: game.fileName)
                    if !enabled { preferences = PlayerPreferences(defaults: .standard) }
                    menuAudio.play(.focus)
                } catch { self.error = error.localizedDescription }
            }
            .fileImporter(isPresented: $importingBIOS, allowedContentTypes: [.data]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    try library.storage.importPS1BIOS(url); biosNames = library.storage.ps1BIOSNames
                } catch { self.error = error.localizedDescription }
            }
            .sheet(isPresented: $showingDuo) { DuoLayoutSettingsView(system: ConsoleSystem(rawValue: (settingsPlatform ?? .threeDS).rawValue) ?? .threeDS, controllerConnected: controllerConnected, topPreview: topPreview, bottomPreview: bottomPreview) }
            .confirmationDialog("Reset this game's shader cache?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Reset shader cache", role: .destructive) {
                    guard !isPlaying, let id = game?.programID else { return }
                    do { try ShaderCache(saves: library.storage.savesDirectory).reset(id); cacheBytes = 0 }
                    catch { self.error = error.localizedDescription }
                }
            } message: { Text("Only this game's learned graphics are removed. Startup and first visits may pause again while they rebuild.") }
            .alert("Couldn't update settings", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    private func load() {
        guard !loaded else { return }
        selectedSystem = initialSystem
        biosNames = library.storage.ps1BIOSNames
        preferences = PlayerPreferences(defaults: .standard)
        do {
            if let game, let profile = try profiles.read(game.fileName) { preferences = profile; custom = true }
            if let id = game?.programID { cacheBytes = try ShaderCache(saves: library.storage.savesDirectory).size(for: id) }
        } catch { self.error = error.localizedDescription }
        loaded = true
    }
    private func persist() {
        guard loaded, editable else { return }
        do {
            if let game { try profiles.write(preferences, for: game.fileName) }
            else { preferences.saveDefaults(.standard) }
        } catch { self.error = error.localizedDescription }
    }
}

struct ResolutionSetting: View {
    @EnvironmentObject private var menuAudio: MenuAudio
    @AppStorage("resolutionFactor") private var storedResolution = 1
    var value: Binding<Int>?
    private var resolution: Binding<Int> {
        value ?? Binding(get: { (1...3).contains(storedResolution) ? storedResolution : 1 }, set: { storedResolution = $0; menuAudio.play(.focus) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Internal resolution", selection: resolution) {
                Text("1× · Best performance").tag(1).accessibilityIdentifier("resolution-1")
                Text("2× · Sharper").tag(2).accessibilityIdentifier("resolution-2")
                Text("3× · Sharpest").tag(3).accessibilityIdentifier("resolution-3")
            }.pickerStyle(.menu).frame(minHeight: 44).accessibilityIdentifier("internalResolution")
                .accessibilityValue(resolution.wrappedValue == 1 ? "1× · Best performance" : (resolution.wrappedValue == 2 ? "2× · Sharper" : "3× · Sharpest"))
            Text("1× is native 3DS resolution. Higher settings sharpen 3D graphics and use more GPU power.").font(.caption).foregroundStyle(ConsoleTheme.quiet)
        }.font(.subheadline)
    }
}

struct FrameTimeGraph: View, Equatable {
    let samples: [FrameSample]
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let s = samples.last {
                HStack { Text(String(format: "%.1f FPS", s.fps)); Spacer(); Text("\(s.resolution)× · \(Int(s.speed * 100))% speed") }.font(.system(size: 10, weight: .medium, design: .monospaced))
                GeometryReader { area in
                    let ceiling = max(34, samples.map(\.worstMS).max() ?? 34), budget = 1000 / max(1, s.targetFPS)
                    Path { path in
                        let y = area.size.height * (1 - min(1, budget / ceiling))
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: area.size.width, y: y))
                    }.stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    Path { path in
                        for (i, sample) in samples.enumerated() {
                            let point = CGPoint(x: area.size.width * Double(i) / Double(max(1, samples.count - 1)), y: area.size.height * (1 - min(1, max(0, sample.worstMS) / ceiling)))
                            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                    }.stroke(ConsoleTheme.blue, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }.frame(height: 32)
                Text(String(format: "%.1f ms avg · %.0f ms peak · %@", s.meanMS, s.worstMS, s.heat)).font(.system(size: 9, design: .monospaced))
            } else { Text("Collecting frame times…").font(.caption2) }
        }.foregroundStyle(.white).padding(10).frame(width: 235)
            .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .combine).accessibilityIdentifier("frameTimeGraph").allowsHitTesting(false)
    }
}
