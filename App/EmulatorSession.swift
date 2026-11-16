import SwiftUI
import GameController
import AVFoundation
import CoreMotion
#if targetEnvironment(simulator)
import Vision
#endif

@MainActor
final class EmulatorSession: ObservableObject {
    @Published var top: UIImage?
    @Published var bottom: UIImage?
    @Published var message: String?
    @Published var booting = true
    @Published var paused = false
    @Published var closing = false
    @Published var fps: Double = 0
    @Published private(set) var playbackSpeed = 1.0
    @Published private(set) var motionStatus: String?
    @Published private(set) var performance = [FrameSample]()
    @Published private(set) var shaderStage: String?
    @Published private(set) var shaderProgress = -1.0
    @Published var frames = 0
    @Published var input = "Ready for input"
    @Published var controllerName: String?
    @Published private(set) var hasController = false
    @Published private(set) var stateBusy = false
    @Published private(set) var savingState = false
    @Published private(set) var quickDate: Date?
    @Published private(set) var resumeDate: Date?
    @Published private(set) var saveHistory = [SaveStateStore.Entry]()
    @Published private(set) var hasOlderSnapshots = false
    @Published var offerResume = false
    @Published var notice: String?
    let bridge = EmulatorBridge()
    private var observers = [NSObjectProtocol]()
    private var controllers = [GCController]()
    private var motion: CMMotionManager?
    private var touchButtons = Set<UInt32>()
    private var controllerButtons = Set<UInt32>()
    private var analogButtons = Set<UInt32>()
    private var closed = false
    private var stateStore: SaveStateStore?
    private var wantsResume = false
    private var autosaveClock = StateAutosaveClock()
    private var backgroundSave: Task<Void, Never>?
    private var inBackground = false
    private var backgroundSaveRequested = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var preferences = PlayerPreferences()
    private var quality = AutomaticQuality(ceiling: 1)
#if targetEnvironment(simulator)
    @Published private var nativeQADescription = ""
    private var nativeQAPressed = false
    private var nativeQAReleased = false
    private var nativeQASaveStart: UInt32?
    private var nativeQASavedCounter: UInt32?
    private var nativeQARestored = false
    private var touchStickSeen = 0
    private var qaController: GCVirtualController?
    private var controllerQAStage = 0
    private var controllerQAFrame = 0
    private var controllerQABaseline: Data?
    private var controllerQAResult: String?
    private var regressionDirectory: URL?
    private var regressionLoadedAt: Int?
    private var regressionFinished = false
    private var regressionInitialStateLoaded = false
    private var dkStage = "menu"
    private var dkReleaseAt = 0
    private var dkButton: UInt32 = 8
    private struct SceneInput: Decodable {
        let frame: Int
        var button: UInt32?
        var down: Bool?
        var x: Float?
        var y: Float?
        var capture: Bool?
        var resolution: Int?
        var sampling: String?
    }
    private var sceneInputs = [SceneInput]()
    private var sceneLimit = 0
#endif
    let diagnostic: Bool
    var frameDescription: String {
        var value = "\(frames) frames received"
#if targetEnvironment(simulator)
        if let controllerQAResult { value += " · " + controllerQAResult }
        value += nativeQADescription
        if platform == .threeDS, ProcessInfo.processInfo.arguments.contains("--motion-interface-test") {
            value += " · MotionQA \(bridge.motionTestStatus)"
        }
        if platform == .ps1, let cg = top?.cgImage {
            if ProcessInfo.processInfo.arguments.contains("--ps1-analog-test") { value += " · " + bridge.playStationInputStatus }
            value += " · Video \(cg.width)x\(cg.height) · Core FPS \(Int(performance.last?.coreFPS.rounded() ?? 0)) · Speed \(playbackSpeed)"
        }
#endif
        return value
    }
    let platform: GamePlatform
    init(diagnostic: Bool, platform: GamePlatform = .threeDS) { self.diagnostic = diagnostic; self.platform = platform }
    isolated deinit {
        motion?.stopDeviceMotionUpdates()
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        // Keep the bridge alive on its core queue until outstanding GPU transfers finish.
        if !closed { bridge.stop {} }
    }
    func start(url: URL?, saves: URL, preferences: PlayerPreferences = PlayerPreferences(), onBoot: @escaping () -> Void) {
        guard observers.isEmpty else { return }
        updateGraphics(preferences)
        if let url {
            stateStore = SaveStateStore(saves: saves, game: url, platform: platform)
            hasOlderSnapshots = stateStore?.hasOlderSnapshots ?? false
            refreshStates()
            wantsResume = !saveHistory.isEmpty && !ProcessInfo.processInfo.arguments.contains("--fresh-start")
        }
        haptic.prepare()
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--autosave-test") { autosaveClock.interval = 5 }
        if ProcessInfo.processInfo.arguments.contains("--golf-regression") {
            regressionDirectory = saves.appendingPathComponent("GolfRegression")
            try? FileManager.default.createDirectory(at: regressionDirectory!, withIntermediateDirectories: true)
        }
        if ProcessInfo.processInfo.arguments.contains("--dk-regression") {
            regressionDirectory = saves.appendingPathComponent("DKRegression")
            try? FileManager.default.createDirectory(at: regressionDirectory!, withIntermediateDirectories: true)
        }
        if ProcessInfo.processInfo.arguments.contains("--scene-regression"),
           let script = ProcessInfo.processInfo.environment["EMUDEN_SCENE_SCRIPT"],
           let data = try? Data(contentsOf: URL(fileURLWithPath: script)), data.count <= 65536,
           let inputs = try? JSONDecoder().decode([SceneInput].self, from: data) {
            sceneInputs = inputs
            sceneLimit = min(12000, max(120, Int(ProcessInfo.processInfo.environment["EMUDEN_SCENE_FRAMES"] ?? "1800") ?? 1800))
            regressionDirectory = saves.appendingPathComponent("SceneRegression")
            try? FileManager.default.createDirectory(at: regressionDirectory!, withIntermediateDirectories: true)
        }
#endif
        bridge.frameHandler = { [weak self] image in
            guard let self, let cg = image.cgImage else { return }
            if self.platform == .gamecube { self.top = image; return }
            self.frames += 1
            self.checkResumeOffer()
            let w = CGFloat(cg.width), h = CGFloat(cg.height)
            if self.platform == .ps1 { self.top = image; self.bottom = nil }
            else if let top = cg.cropping(to: CGRect(x: 0, y: 0, width: w, height: h / 2)),
               let bottom = cg.cropping(to: CGRect(x: w * 0.1, y: h / 2, width: w * 0.8, height: h / 2)) {
                self.top = UIImage(cgImage: top); self.bottom = UIImage(cgImage: bottom)
            }
#if targetEnvironment(simulator)
            self.runGolfRegressionFrame()
            self.runControllerQA(image)
#endif
        }
        bridge.nativeFrameHandler = { [weak self] total in
            guard let self, !self.closed else { return }
            self.frames = Int(total)
            self.checkResumeOffer()
        }
#if targetEnvironment(simulator)
        bridge.nativeDiagnosticHandler = { [weak self] value in
            guard let self else { return }
            if ProcessInfo.processInfo.arguments.contains("--gamecube-qa-status"),
               let data = try? JSONSerialization.data(withJSONObject:value,options:.prettyPrinted) {
                try? data.write(to:FileManager.default.temporaryDirectory.appendingPathComponent("gamecube-qa.json"),options:.atomic)
            }
            guard value["marker"]?.uint32Value == 0x454D5544 else { return }
            self.runGameCubeControllerQA(value)
            let pressed = value["pad"]!.uint32Value & 0x01000000 != 0 && value["pixel"]!.uint32Value == 0xB060B090
            if pressed { self.nativeQAPressed = true }
            if self.nativeQAPressed && !pressed && value["pixel"]!.uint32Value == 0x307030A0 { self.nativeQAReleased = true }
            if value["event"]?.intValue == 3 { self.nativeQASaveStart = value["counter"]?.uint32Value }
            if value["event"]?.intValue == 1 { self.nativeQASavedCounter = value["counter"]?.uint32Value }
            if value["event"]?.intValue == 2, let start = self.nativeQASaveStart,
               let end = self.nativeQASavedCounter, let restored = value["counter"]?.uint32Value {
                self.nativeQARestored = restored &- start <= end &- start
            }
            self.nativeQADescription = " · PowerPC boot verified" + (self.nativeQAReleased ? " · A press/release verified" : "") +
                (self.nativeQARestored ? " · Snapshot counter restored" : "") +
                ((value["audioPeak"]?.intValue ?? 0) > 0 && (value["audioOutputPeak"]?.intValue ?? 0) > 0 ? " · Audio PCM verified" : "") +
                " · PCM \(value["audioFrames"]?.uint64Value ?? 0), peak \(value["audioPeak"]?.uint32Value ?? 0), output \(value["audioOutputPeak"]?.uint32Value ?? 0)"
            if ProcessInfo.processInfo.arguments.contains("--boot-gamecube-gx-card") {
                self.nativeQADescription += String(format:" · Native card %08x",value["counter"]?.uint32Value ?? 0)
            }
            if ProcessInfo.processInfo.arguments.contains("--touch-excursion-test") {
                let high = value["pad"]?.uint32Value ?? 0, low = value["padLow"]?.uint32Value ?? 0
                let x = (high >> 8) & 255, y = high & 255, cx = low >> 24, cy = (low >> 16) & 255
                if x < 40 || x > 215 || y < 40 || y > 215 { self.touchStickSeen |= 1 }
                if cx < 40 || cx > 215 || cy < 40 || cy > 215 { self.touchStickSeen |= 2 }
                self.nativeQADescription += " · Touch SI \(self.touchStickSeen) · Center \((120...136).contains(x) && (120...136).contains(y) && (120...136).contains(cx) && (120...136).contains(cy))"
            }
            self.nativeQADescription += " · GFX \(value["resolution"]?.intValue ?? 0)x \(value["efbWidth"]?.intValue ?? 0)×\(value["efbHeight"]?.intValue ?? 0) filter\(value["filtering"]?.intValue ?? 0) AF\(value["anisotropy"]?.intValue ?? -1)"
        }
#endif
        bridge.messageHandler = { [weak self] text in self?.message = text }
        bridge.statisticsHandler = { [weak self] value in self?.fps = value }
        bridge.shaderProgressHandler = { [weak self] stage, progress in
            self?.shaderStage = stage; self?.shaderProgress = progress
        }
        bridge.performanceHandler = { [weak self] data in
            guard let self else { return }
            let sample = FrameSample(fps: data["fps"]?.doubleValue ?? 0, coreFPS: data["coreFPS"]?.doubleValue ?? 0,
                targetFPS: data["targetFPS"]?.doubleValue ?? 60, meanMS: data["meanMS"]?.doubleValue ?? 0,
                worstMS: data["worstMS"]?.doubleValue ?? 0, thermal: data["thermal"]?.intValue ?? 0,
                resolution: data["resolution"]?.intValue ?? 1)
#if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--profile-frontend") {
                let file = FileManager.default.temporaryDirectory.appendingPathComponent("frontend-" + self.platform.rawValue + ".json")
                var rows = ((try? Data(contentsOf: file)).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [[String: NSNumber]]) ?? []
                if rows.count < 120 { rows.append(data); if let bytes = try? JSONSerialization.data(withJSONObject: rows) { try? bytes.write(to: file, options: .atomic) } }
            }
#endif
            self.performance.append(sample)
            self.bridge.setPresentationRate(UInt(self.preferences.presentation.limit(thermal: sample.thermal)))
            if self.performance.count > 60 { self.performance.removeFirst(self.performance.count - 60) }
            let automatic = self.platform == .threeDS ? self.preferences.automaticQuality : self.preferences.ps1AutomaticQuality
            if self.platform != .gamecube, automatic, self.playbackSpeed == 1, !self.booting, !self.paused, !self.closing, !self.stateBusy,
               let resolution = self.quality.next(sample) {
                if self.platform == .ps1 {
                    self.bridge.configurePlayStationResolution(resolution, dithering: self.preferences.ps1Dithering, textureFix: self.preferences.ps1TextureFix)
                } else {
                    self.bridge.configureResolution(resolution, asyncShaders: self.preferences.asyncShaders,
                        textureSampling: self.preferences.sampling.rawValue, prepareShaders: self.preferences.prepareShaders)
                }
            }
            let defaults = UserDefaults.standard
            let enabled = defaults.object(forKey: "automaticResumeSaves") == nil || defaults.bool(forKey: "automaticResumeSaves")
            if self.autosaveClock.due(now: ProcessInfo.processInfo.systemUptime,
                active: !self.booting && !self.paused && !self.closing && !self.stateBusy && !self.inBackground && self.frames > 0 && self.stateStore != nil,
                enabled: enabled) {
                Task { await self.save(.resume) }
            }
        }
        let center = NotificationCenter.default
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.connectControllers() }
            })
        }
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setPaused(true) }
        })
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.suspend() }
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.background() }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.foreground() }
        })
        connectControllers()
        guard let url else { booting = false; return }
        let nativeSaves: URL
        switch platform {
        case .threeDS: nativeSaves = saves
        case .ps1: nativeSaves = saves.appendingPathComponent("PlayStation/\(url.deletingLastPathComponent().lastPathComponent)")
        case .gamecube: nativeSaves = saves.appendingPathComponent("GameCube/\(url.deletingLastPathComponent().lastPathComponent)")
        }
        let systemData = platform == .ps1 ? saves.appendingPathComponent("PlayStation/BIOS") : saves
        bridge.startROM(url.path, saveDirectory: nativeSaves.path, systemDirectory: systemData.path, core: platform.rawValue) { [weak self] error in
            Task { @MainActor in
                self?.booting = false
                if let error { self?.message = error }
                else {
                    onBoot()
                    self?.checkResumeOffer()
                    self?.updateMotion()
#if targetEnvironment(simulator)
                    self?.startControllerQA()
#endif
                }
            }
        }
    }
    func updateGraphics(_ preferences: PlayerPreferences) {
        self.preferences = preferences.normalized
        bridge.setPresentationRate(UInt(self.preferences.presentation.limit(thermal: ProcessInfo.processInfo.thermalState.rawValue)))
        if platform == .ps1 {
            quality = AutomaticQuality(ceiling: self.preferences.ps1Resolution)
            bridge.setPlayStationAnalogEnabled(self.preferences.ps1Analog)
            releaseTouchControls()
            bridge.configurePlayStationResolution(self.preferences.ps1Resolution, dithering: self.preferences.ps1Dithering, textureFix: self.preferences.ps1TextureFix)
            return
        }
        if platform == .gamecube {
            let filtering = self.preferences.gameCubeSampling == .crisp ? 1 : (self.preferences.gameCubeSampling == .smooth ? 2 : 0)
            bridge.configureGameCubeResolution(self.preferences.gameCubeResolution, filtering: filtering, anisotropy: self.preferences.gameCubeAnisotropy)
            return
        }
        guard platform == .threeDS else { return }
        quality = AutomaticQuality(ceiling: self.preferences.resolution)
        bridge.configureResolution(self.preferences.resolution, asyncShaders: self.preferences.asyncShaders,
            textureSampling: self.preferences.sampling.rawValue, prepareShaders: self.preferences.prepareShaders)
        updateMotion()
    }
    func setPlaybackSpeed(_ value: Double) {
        guard platform == .ps1 else { return }
        playbackSpeed = value == 1.5 || value == 2 ? value : 1
        bridge.setPlaybackSpeed(playbackSpeed)
    }
    private func updateMotion() {
        guard platform == .threeDS else { return }
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--motion-interface-test") {
            bridge.setMotionHardwareAvailable(true)
            let active = preferences.motionControls && !booting && !paused && !closing && !closed && !inBackground
            bridge.setMotionEnabled(active)
            if active { bridge.setMotionAccelerationX(0.25, y: 0, z: -0.75, rotationX: 0.1, rotationY: 0.2, rotationZ: 0.3) }
            motionStatus = "Simulator sensor fixture"
            return
        }
#endif
        if motion == nil { motion = CMMotionManager() }
        guard let motion else { return }
        let available = motion.isDeviceMotionAvailable
        bridge.setMotionHardwareAvailable(available)
        let active = preferences.motionControls && !booting && !paused && !closing && !closed && !inBackground && available
        bridge.setMotionEnabled(active)
        guard active else {
            motion.stopDeviceMotionUpdates()
            motionStatus = !preferences.motionControls ? "Motion controls off" : (available ? "Sensors available · paused" : "Motion sensors unavailable on this device")
            return
        }
        guard !motion.isDeviceMotionActive else { return }
        motionStatus = "Connecting motion sensors…"
        motion.deviceMotionUpdateInterval = 1.0 / 60
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, error in
            if error != nil {
                Task { @MainActor [weak self] in
                    self?.motion?.stopDeviceMotionUpdates(); self?.bridge.setMotionEnabled(false)
                    self?.motionStatus = "Motion updates unavailable. Check motion access in iOS Settings."
                }
                return
            }
            guard let sample else { return }
            let acceleration = SIMD3(sample.gravity.x + sample.userAcceleration.x,
                                     sample.gravity.y + sample.userAcceleration.y,
                                     sample.gravity.z + sample.userAcceleration.z)
            let rotation = SIMD3(sample.rotationRate.x, sample.rotationRate.y, sample.rotationRate.z)
            Task { @MainActor [weak self] in
                guard let self, !paused, !closing, !closed, !inBackground, preferences.motionControls else { return }
                let orientation = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                    .first { $0.activationState == .foregroundActive }?.interfaceOrientation ?? .portrait
                let turns: Int
                switch orientation {
                case .landscapeRight: turns = 1
                case .portraitUpsideDown: turns = 2
                case .landscapeLeft: turns = 3
                default: turns = 0
                }
                let a = MotionAxes.threeDS(acceleration, quarterTurns: turns)
                let r = MotionAxes.threeDS(rotation, quarterTurns: turns)
                bridge.setMotionAccelerationX(Float(a.x), y: Float(a.y), z: Float(a.z),
                    rotationX: Float(r.x), rotationY: Float(r.y), rotationZ: Float(r.z))
                if motionStatus != "Gyroscope and accelerometer ready" { motionStatus = "Gyroscope and accelerometer ready" }
            }
        }
    }
    func button(_ id: UInt32, _ label: String, _ pressed: Bool, controller: Bool = false) {
        guard !paused, !closing else { return }
        if controller { if pressed { controllerButtons.insert(id) } else { controllerButtons.remove(id) } }
        else {
            if pressed {
                let firstPress = touchButtons.insert(id).inserted
                if firstPress && UserDefaults.standard.object(forKey: "buttonHaptics") as? Bool != false {
                    haptic.impactOccurred(intensity: 0.65); haptic.prepare()
                }
            } else { touchButtons.remove(id) }
        }
        bridge.setButton(id, pressed: touchButtons.contains(id) || controllerButtons.contains(id) || analogButtons.contains(id))
        if pressed { input = "\(label) pressed" }
    }
    func analog(x: Float, y: Float) {
        guard !paused, !closing else { return }
        bridge.setAnalogX(x, y: y)
        if platform == .ps1 && !preferences.ps1Analog {
            let next = Set<UInt32>([(4, y < -0.4), (5, y > 0.4), (6, x < -0.4), (7, x > 0.4)].compactMap { $0.1 ? $0.0 : nil })
            let changed = analogButtons.union(next); analogButtons = next
            for id in changed { bridge.setButton(id, pressed: next.contains(id) || touchButtons.contains(id) || controllerButtons.contains(id)) }
        }
        if abs(x) > 0.1 || abs(y) > 0.1 { input = String(format: "Circle pad %.1f, %.1f", x, y) }
    }
    func secondaryAnalog(x: Float, y: Float) {
        guard !paused, !closing else { return }
        if platform == .gamecube { bridge.setGameCubeCStickX(x, y: y) }
        if platform == .ps1 { bridge.setRightAnalogX(x, y: y) }
    }
    func touch(x: CGFloat, y: CGFloat, pressed: Bool) {
        guard !paused, !closing else { return }
        bridge.setTouchX(Float(0.1 + 0.8 * x), y: Float(0.5 + 0.5 * y), pressed: pressed)
        if pressed { input = "Touch \(Int(x * 320)), \(Int(y * 240))" }
    }
    func setPaused(_ value: Bool) {
        paused = value; bridge.setPaused(value)
        updateMotion()
        if value { touchButtons.removeAll(); controllerButtons.removeAll(); analogButtons.removeAll() }
    }
    private func refreshStates() {
        quickDate = stateStore?.date(.quick); resumeDate = stateStore?.date(.resume)
        saveHistory = stateStore?.entries ?? []
    }
    func previewData(_ entry: SaveStateStore.Entry) -> Data? { stateStore?.previewData(entry) }
    func suspend() { inBackground = true; setPaused(true) }
    func foreground() { inBackground = false; backgroundSaveRequested = false }
    private func checkResumeOffer() {
        if wantsResume && !booting && frames > 0 {
            wantsResume = false; setPaused(true); offerResume = true
        }
    }
#if targetEnvironment(simulator)
    // Exercise a real game without depending on the Simulator UI test runner's launch handshake.
    private func runGolfRegressionFrame() {
        guard regressionDirectory != nil, !regressionFinished else { return }
        if ProcessInfo.processInfo.arguments.contains("--dk-regression") { runDKRegressionFrame(); return }
        if sceneLimit > 0 {
            if ProcessInfo.processInfo.arguments.contains("--scene-from-quick"), !regressionInitialStateLoaded {
                guard frames >= 60, !booting else { return }
                regressionInitialStateLoaded = true
                setPaused(true)
                Task {
                    await load(.quick)
                    if message == nil { frames = 0; setPaused(false) }
                    else { finishRegression(passed: false) }
                }
                return
            }
            for action in sceneInputs where action.frame == frames {
                if let resolution = action.resolution, (1...3).contains(resolution) {
                    var next = preferences; next.resolution = resolution; updateGraphics(next)
                }
                if let sampling = action.sampling.flatMap(PlayerPreferences.Sampling.init(rawValue:)) {
                    var next = preferences; next.sampling = sampling; updateGraphics(next)
                }
                if let id = action.button { button(id, "Scene test", action.down ?? false) }
                else if let x = action.x, let y = action.y { touch(x: CGFloat(x), y: CGFloat(y), pressed: action.down ?? false) }
                if action.capture == true { captureRegressionImages() }
            }
            if frames % 60 == 0 { captureRegressionImages() }
            if ProcessInfo.processInfo.arguments.contains("--scene-state-regression") {
                if frames == sceneLimit { regressionRoundTrip() }
                if let restored = regressionLoadedAt, frames >= restored + 120 { finishRegression(passed: message == nil) }
            } else if frames >= sceneLimit { finishRegression(passed: message == nil) }
            return
        }
        let castle = ProcessInfo.processInfo.arguments.contains("--castle-regression")
        if (180...1020).contains(frames), (frames - 180) % 120 == 0 { button(8, "A", true) }
        if (183...1023).contains(frames), (frames - 183) % 120 == 0 { button(8, "A", false) }
        if castle {
            if frames == 390 { button(6, "Left", true) }
            if frames == 394 { button(6, "Left", false) }
        } else {
            if frames == 720 { touch(x: 0.8875, y: 0.7125, pressed: true) }
            if frames == 723 { touch(x: 0.8875, y: 0.7125, pressed: false) }
        }
        if frames == 1080 { analog(x: 0, y: -1) }
        if frames == 1140 { analog(x: 0, y: 0) }
        if frames % 120 == 0 || frames == 750 || frames == 990 || frames == 1150 { captureRegressionImages() }
        if frames == 1200 {
            regressionRoundTrip()
        }
        if let restored = regressionLoadedAt, frames >= restored + 120 { finishRegression(passed: true) }
    }
    private func runDKRegressionFrame() {
        if frames == dkReleaseAt { button(dkButton, "DK test", false) }
        if dkStage == "ready" {
            if let restored = regressionLoadedAt, frames >= restored + 120 { finishRegression(passed: message == nil) }
            return
        }
        guard frames >= 90, frames % 45 == 0 else { return }
        if frames >= 5000 { message = "Donkey Kong test could not reach the tee."; finishRegression(passed: false); return }
        func text(_ image: UIImage?) -> String {
            guard let cg = image?.cgImage else { return "" }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cg).perform([request])
            return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").uppercased().filter { $0.isLetter || $0.isNumber }
        }
        let title = text(top), controls = text(bottom)
        print("DK CHECK stage=\(dkStage) frame=\(frames) top=\(title) bottom=\(controls)")
        captureRegressionImages()
        func pulse(_ id: UInt32) {
            dkButton = id; button(id, "DK test", true); dkReleaseAt = frames + 3
        }
        switch dkStage {
        case "menu":
            if title.contains("SELECTCHARACTER") { dkStage = "character" }
            else { pulse(8) }
        case "character":
            if title.contains("DONKEY") { pulse(8); dkStage = "tee" }
            else { pulse(7) }
        default:
            if controls.contains("STARTSHOT") || (controls.contains("EASY") && controls.contains("NORMAL")) {
                dkStage = "ready"; regressionRoundTrip()
            } else { pulse(8) }
        }
    }
    private func regressionRoundTrip() {
        Task {
            if await save(.quick) {
                await load(.quick)
                if message == nil { regressionLoadedAt = frames }
                else { finishRegression(passed: false) }
            } else { finishRegression(passed: false) }
        }
    }
    private func captureRegressionImages() {
        guard let directory = regressionDirectory else { return }
        try? top?.pngData()?.write(to: directory.appendingPathComponent("top-\(frames).png"), options: .atomic)
        try? bottom?.pngData()?.write(to: directory.appendingPathComponent("bottom-\(frames).png"), options: .atomic)
    }
    private func finishRegression(passed: Bool) {
        guard let directory = regressionDirectory else { return }
        regressionFinished = true; captureRegressionImages(); setPaused(true)
        let report: [String: Any] = ["passed": passed, "frames": frames, "fps": fps, "message": message ?? ""]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted) {
            try? data.write(to: directory.appendingPathComponent("result.json"), options: .atomic)
        }
    }
#endif
    @discardableResult func save(_ slot: SaveStateStore.Slot) async -> Bool {
        guard !stateBusy, !closed else { return false }
        guard !booting, frames > 0, let store = stateStore else { return true }
        stateBusy = true; savingState = true
        var success = false
        do {
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                bridge.captureState { data, error in
                    if let data { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: NSError(domain: "EmuDen.State", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: error ?? "State capture failed."])) }
                }
            }
            let preview: Data? = top.map { image in
                let format = UIGraphicsImageRendererFormat(); format.scale = 1
                let size = CGSize(width: 320, height: 192)
                return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.75)
            } ?? nil
            try await Task.detached(priority: .userInitiated) {
#if targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("--save-feedback-test") { try await Task.sleep(for: .seconds(2)) }
#endif
                try store.write(data, slot: slot, preview: preview)
            }.value
            refreshStates(); autosaveClock.saved(); notice = slot == .quick ? "Quick save ready" : "Resume point saved"
            success = true
        } catch { message = error.localizedDescription }
        stateBusy = false; savingState = false
        return success
    }
    func load(_ slot: SaveStateStore.Slot) async {
        await restore(slot: slot, entry: nil)
    }
    func load(_ entry: SaveStateStore.Entry, resuming: Bool = false) async {
        await restore(slot: entry.slot, entry: entry, resuming: resuming)
    }
    private func restore(slot: SaveStateStore.Slot, entry: SaveStateStore.Entry?, resuming: Bool = false) async {
        guard !stateBusy, !booting, !closed, let store = stateStore else { return }
        stateBusy = true
        let wasPaused = paused; setPaused(true)
        do {
            let data = try await Task.detached(priority: .userInitiated) {
                if let entry { return try store.read(entry) }
                return try store.read(slot)
            }.value
            let error: String? = await withCheckedContinuation { continuation in
                bridge.restoreState(data) { continuation.resume(returning: $0) }
            }
            if let error { message = error }
            else {
                autosaveClock.saved()
                notice = resuming || slot == .resume ? "Session resumed" : (entry == nil ? "Quick save loaded" : "Save point loaded")
            }
        } catch { message = error.localizedDescription }
        stateBusy = false
        setPaused(wasPaused || inBackground)
    }
    func background() {
        inBackground = true
        setPaused(true)
        guard !booting, !closed, !closing, !backgroundSaveRequested, backgroundSave == nil else { return }
        backgroundSaveRequested = true
        var task = UIBackgroundTaskIdentifier.invalid
        task = UIApplication.shared.beginBackgroundTask(withName: "Save emulation session") {
            self.backgroundSave?.cancel()
            if task != .invalid { UIApplication.shared.endBackgroundTask(task); task = .invalid }
        }
        backgroundSave = Task {
            // Finish an in-flight Quick Save/load before capturing the background resume point.
            for _ in 0..<100 where stateBusy && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
            }
            if !Task.isCancelled && !closed && !closing { await save(.resume) }
            if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
            backgroundSave = nil
        }
    }
    func releaseTouchControls() {
        for id in touchButtons { bridge.setButton(id, pressed: controllerButtons.contains(id)) }
        touchButtons.removeAll()
        for id in analogButtons { bridge.setButton(id, pressed: controllerButtons.contains(id)) }
        analogButtons.removeAll()
        bridge.setAnalogX(0, y: 0); bridge.setRightAnalogX(0, y: 0)
        if platform == .gamecube { bridge.setGameCubeCStickX(0, y: 0) }
        bridge.setTouchX(0, y: 0, pressed: false)
    }
    private func connectControllers() {
        for c in controllers { c.extendedGamepad?.valueChangedHandler = nil; c.extendedGamepad?.buttonMenu.pressedChangedHandler = nil }
        for id in controllerButtons.union(analogButtons) { bridge.setButton(id, pressed: touchButtons.contains(id)) }
        controllerButtons.removeAll(); analogButtons.removeAll(); bridge.setAnalogX(0, y: 0); bridge.setRightAnalogX(0, y: 0)
        if platform == .gamecube { bridge.setGameCubeCStickX(0, y: 0); bridge.setGameCubeTriggerLeft(0, right: 0) }
        let arguments = ProcessInfo.processInfo.arguments
        let previewRequested = arguments.contains("--touch-controls-preview") || arguments.contains("--controller-preview")
#if targetEnvironment(simulator)
        let preview = previewRequested
#else
        let preview = diagnostic && previewRequested
#endif
        var available = GCController.controllers()
#if targetEnvironment(simulator)
        if let controller = qaController?.controller { available = [controller] }
#endif
        controllers = preview ? [] : Array(available.filter { $0.extendedGamepad != nil }.prefix(1))
        hasController = !controllers.isEmpty
        controllerName = controllers.first.map { $0.vendorName ?? "Game controller" }
        if preview && arguments.contains("--controller-preview") {
            hasController = true; controllerName = "Controller preview"
        }
        for controller in controllers {
            controller.handlerQueue = .main
            guard let pad = controller.extendedGamepad else { continue }
            pad.valueChangedHandler = { [weak self] pad, _ in
                guard let self, !self.paused, !self.closing else { return }
                // Physical positions match Nintendo: right=A, bottom=B, top=X, left=Y.
                let bindings: [(GCControllerButtonInput, UInt32, String)] = self.platform == .gamecube ? [
                    (pad.buttonA,0,"A"), (pad.buttonB,8,"B"), (pad.buttonY,1,"X"), (pad.buttonX,9,"Y"),
                    (pad.rightShoulder,12,"Z"),
                    (pad.dpad.up,4,"Up"), (pad.dpad.down,5,"Down"), (pad.dpad.left,6,"Left"), (pad.dpad.right,7,"Right")] : [
                    (pad.buttonB,8,"A"), (pad.buttonA,0,"B"), (pad.buttonY,9,"X"), (pad.buttonX,1,"Y"),
                    (pad.leftShoulder,10,"L"), (pad.rightShoulder,11,"R"), (pad.leftTrigger,12,"ZL"), (pad.rightTrigger,13,"ZR"),
                    (pad.dpad.up,4,"Up"), (pad.dpad.down,5,"Down"), (pad.dpad.left,6,"Left"), (pad.dpad.right,7,"Right")]
                for (button,id,label) in bindings { self.button(id,label,button.isPressed,controller:true) }
                if self.platform != .gamecube, let options = pad.buttonOptions { self.button(2,"Select",options.isPressed,controller:true) }
                self.analog(x: pad.leftThumbstick.xAxis.value, y: -pad.leftThumbstick.yAxis.value)
                if self.platform == .ps1 {
                    if let left = pad.leftThumbstickButton { self.button(14, "L3", left.isPressed, controller: true) }
                    if let right = pad.rightThumbstickButton { self.button(15, "R3", right.isPressed, controller: true) }
                }
                if self.platform == .ps1 { self.secondaryAnalog(x: pad.rightThumbstick.xAxis.value, y: -pad.rightThumbstick.yAxis.value) }
                if self.platform == .gamecube {
                    self.secondaryAnalog(x: pad.rightThumbstick.xAxis.value, y: -pad.rightThumbstick.yAxis.value)
                    self.bridge.setGameCubeTriggerLeft(pad.leftTrigger.value, right: pad.rightTrigger.value)
                    self.button(10,"L",pad.leftTrigger.value >= 0.95 || pad.leftShoulder.isPressed,controller:true)
                    self.button(11,"R",pad.rightTrigger.value >= 0.95,controller:true)
                }
            }
            pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in self?.button(3,"Start",pressed,controller:true) }
        }
    }
    func close(completion: @escaping () -> Void) {
        guard !closed, !closing, !stateBusy else { return }; closing = true
        Task {
            let saved = await save(.resume)
            if !saved {
                // A failed state capture leaves the session open so the player can save in-game.
                closing = false; return
            }
            finishClose(completion: completion)
        }
    }
    func closeWithoutState(completion: @escaping () -> Void) {
        guard !closed, !stateBusy else { return }
        closing = true; finishClose(completion: completion)
    }
    private func finishClose(completion: @escaping () -> Void) {
        closed = true
        motion?.stopDeviceMotionUpdates(); bridge.setMotionEnabled(false)
        for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
        for c in controllers { c.extendedGamepad?.valueChangedHandler = nil; c.extendedGamepad?.buttonMenu.pressedChangedHandler = nil }
#if targetEnvironment(simulator)
        qaController?.disconnect(); qaController = nil
        bridge.nativeDiagnosticHandler = nil
#endif
        bridge.frameHandler = nil; bridge.nativeFrameHandler = nil; bridge.messageHandler = nil; bridge.statisticsHandler = nil
        bridge.performanceHandler = nil; bridge.shaderProgressHandler = nil
        bridge.stop { completion() }
    }
#if targetEnvironment(simulator)
    private func startControllerQA() {
        let arguments = ProcessInfo.processInfo.arguments
        guard (platform == .ps1 && arguments.contains("--ps1-controller-test")) ||
            (platform == .gamecube && arguments.contains("--gamecube-controller-test")) else { return }
        let configuration = GCVirtualController.Configuration()
        configuration.elements = [GCInputButtonA, GCInputButtonB, GCInputButtonX, GCInputButtonY, GCInputDirectionPad, GCInputLeftThumbstick]
        if platform == .gamecube { configuration.elements.formUnion([GCInputRightThumbstick, GCInputLeftTrigger, GCInputRightTrigger, GCInputLeftShoulder, GCInputRightShoulder]) }
        configuration.isHidden = true
        let controller = GCVirtualController(configuration: configuration); qaController = controller
        Task { [weak self] in
            do {
                try await controller.connect()
                guard let self, !closed else { controller.disconnect(); return }
                connectControllers()
            } catch { self?.controllerQAResult = "Controller input failed to connect" }
        }
    }
    private func runControllerQA(_ image: UIImage) {
        guard platform == .ps1, let virtual = qaController, controllerQAResult == nil, frames >= 120,
              virtual.controller != nil || controllerQAStage == 4,
              let pixels = image.cgImage?.dataProvider?.data else { return }
        let data = pixels as Data
        guard frames >= controllerQAFrame else { return }
        func check(_ passed: Bool) -> Bool {
            if !passed { controllerQAResult = "Controller input failed at step \(controllerQAStage)" }
            return passed
        }
        switch controllerQAStage {
        case 0:
            controllerQABaseline = data
            virtual.setValue(1, forButtonElement: GCInputButtonA)
        case 1:
            guard check(data != controllerQABaseline) else { return }
            virtual.setValue(0, forButtonElement: GCInputButtonA)
        case 2:
            guard check(data == controllerQABaseline) else { return }
            virtual.setPosition(CGPoint(x: 0, y: 1), forDirectionPadElement: GCInputLeftThumbstick)
        case 3:
            guard check(data != controllerQABaseline) else { return }
            virtual.disconnect(); connectControllers()
        case 4:
            guard check(data == controllerQABaseline) else { return }
            controllerQAResult = "Controller input passed"
        default: return
        }
        controllerQAStage += 1; controllerQAFrame = frames + 30
    }
    private func runGameCubeControllerQA(_ value: [String: NSNumber]) {
        guard platform == .gamecube, let virtual = qaController, controllerQAResult == nil,
              virtual.controller != nil || controllerQAStage == 7 else { return }
        let high = value["pad"]?.uint32Value ?? 0, low = value["padLow"]?.uint32Value ?? 0
        let x = (high >> 8) & 255, y = high & 255, cx = low >> 24, cy = (low >> 16) & 255
        let left = (low >> 8) & 255, right = low & 255
        func centered(_ n: UInt32) -> Bool { (120...136).contains(n) }
        func check(_ condition: Bool) -> Bool {
            if !condition { controllerQAResult = String(format:"GameCube input failed step %d: %08x/%08x",controllerQAStage,high,low) }
            return condition
        }
        switch controllerQAStage {
        case 0: bridge.setAnalogX(-0.7, y: 0.3)
        case 1:
            guard check(x < 100 && y < 128) else { return }
            secondaryAnalog(x: 0.5, y: -0.6); bridge.setGameCubeTriggerLeft(0.35, right: 0.65)
        case 2:
            guard check(cx > 144 && cy > 144 && left > 32 && left < 150 && right > left + 20 && right < 240 && high & 0x00600000 == 0) else { return }
            bridge.setAnalogX(.nan, y: 0); bridge.setGameCubeCStickX(3, y: -3); bridge.setGameCubeTriggerLeft(-2, right: 3)
        case 3:
            guard check(centered(x) && centered(y) && cx > 240 && cy > 240 && left == 0 && right == 255) else { return }
            setPaused(true); setPaused(false)
        case 4:
            guard check(centered(x) && centered(y) && centered(cx) && centered(cy) && low & 0xffff == 0) else { return }
            virtual.setPosition(CGPoint(x: -0.7,y: -0.3), forDirectionPadElement: GCInputLeftThumbstick)
            virtual.setPosition(CGPoint(x: 0.5,y: 0.6), forDirectionPadElement: GCInputRightThumbstick)
            virtual.setValue(0.35, forButtonElement: GCInputLeftTrigger); virtual.setValue(0.65, forButtonElement: GCInputRightTrigger)
        case 5:
            guard check(x < 100 && y < 128 && cx > 144 && cy > 144 && left > 32 && left < 150 && right > left + 20 && right < 240 && high & 0x00600000 == 0) else { return }
            virtual.setValue(1, forButtonElement: GCInputLeftTrigger); virtual.setValue(1, forButtonElement: GCInputRightTrigger)
        case 6:
            guard check(high & 0x00600000 == 0x00600000 && left == 255 && right == 255) else { return }
            virtual.disconnect(); connectControllers()
        case 7:
            guard check(centered(x) && centered(y) && centered(cx) && centered(cy) && low & 0xffff == 0 && high & 0x00600000 == 0) else { return }
            controllerQAResult = "GameCube full input passed"
        default: return
        }
        controllerQAStage += 1
    }
#endif
}
