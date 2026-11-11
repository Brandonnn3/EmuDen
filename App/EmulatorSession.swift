import SwiftUI
import GameController
import AVFoundation
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
    @Published private(set) var performance = [FrameSample]()
    @Published private(set) var shaderStage: String?
    @Published private(set) var shaderProgress = -1.0
    @Published var frames = 0
    @Published var input = "Ready for input"
    @Published var controllerName: String?
    @Published private(set) var hasController = false
    @Published private(set) var stateBusy = false
    @Published private(set) var quickDate: Date?
    @Published private(set) var resumeDate: Date?
    @Published private(set) var hasOlderSnapshots = false
    @Published var offerResume = false
    @Published var notice: String?
    let bridge = EmulatorBridge()
    private var observers = [NSObjectProtocol]()
    private var controllers = [GCController]()
    private var touchButtons = Set<UInt32>()
    private var controllerButtons = Set<UInt32>()
    private var closed = false
    private var stateStore: SaveStateStore?
    private var wantsResume = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var preferences = PlayerPreferences()
    private var quality = AutomaticQuality(ceiling: 1)
#if targetEnvironment(simulator)
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
    init(diagnostic: Bool) { self.diagnostic = diagnostic }
    isolated deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        // Keep the bridge alive on its core queue until outstanding GPU transfers finish.
        if !closed { bridge.stop {} }
    }
    func start(url: URL?, saves: URL, preferences: PlayerPreferences = PlayerPreferences(), onBoot: @escaping () -> Void) {
        guard observers.isEmpty else { return }
        updateGraphics(preferences)
        if let url {
            stateStore = SaveStateStore(saves: saves, game: url)
            hasOlderSnapshots = stateStore?.hasOlderSnapshots ?? false
            refreshStates()
            wantsResume = resumeDate != nil && !ProcessInfo.processInfo.arguments.contains("--fresh-start")
        }
        haptic.prepare()
#if targetEnvironment(simulator)
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
            self.frames += 1
            self.checkResumeOffer()
            let w = CGFloat(cg.width), h = CGFloat(cg.height)
            if let top = cg.cropping(to: CGRect(x: 0, y: 0, width: w, height: h / 2)),
               let bottom = cg.cropping(to: CGRect(x: w * 0.1, y: h / 2, width: w * 0.8, height: h / 2)) {
                self.top = UIImage(cgImage: top); self.bottom = UIImage(cgImage: bottom)
            }
#if targetEnvironment(simulator)
            self.runGolfRegressionFrame()
#endif
        }
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
            self.performance.append(sample)
            if self.performance.count > 60 { self.performance.removeFirst(self.performance.count - 60) }
            if self.preferences.automaticQuality, !self.booting, !self.paused, !self.closing, !self.stateBusy,
               let resolution = self.quality.next(sample) {
                self.bridge.configureResolution(resolution, asyncShaders: self.preferences.asyncShaders,
                    textureSampling: self.preferences.sampling.rawValue, prepareShaders: self.preferences.prepareShaders)
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
        connectControllers()
        guard let url else { booting = false; return }
        bridge.startROM(url.path, saveDirectory: saves.path) { [weak self] error in
            Task { @MainActor in
                self?.booting = false
                if let error { self?.message = error }
                else {
                    onBoot()
                    self?.checkResumeOffer()
                }
            }
        }
    }
    func updateGraphics(_ preferences: PlayerPreferences) {
        self.preferences = preferences.normalized
        quality = AutomaticQuality(ceiling: self.preferences.resolution)
        bridge.configureResolution(self.preferences.resolution, asyncShaders: self.preferences.asyncShaders,
            textureSampling: self.preferences.sampling.rawValue, prepareShaders: self.preferences.prepareShaders)
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
        bridge.setButton(id, pressed: touchButtons.contains(id) || controllerButtons.contains(id))
        if pressed { input = "\(label) pressed" }
    }
    func analog(x: Float, y: Float) {
        guard !paused, !closing else { return }
        bridge.setAnalogX(x, y: y)
        if abs(x) > 0.1 || abs(y) > 0.1 { input = String(format: "Circle pad %.1f, %.1f", x, y) }
    }
    func touch(x: CGFloat, y: CGFloat, pressed: Bool) {
        guard !paused, !closing else { return }
        bridge.setTouchX(Float(0.1 + 0.8 * x), y: Float(0.5 + 0.5 * y), pressed: pressed)
        if pressed { input = "Touch \(Int(x * 320)), \(Int(y * 240))" }
    }
    func setPaused(_ value: Bool) {
        paused = value; bridge.setPaused(value)
        if value { touchButtons.removeAll(); controllerButtons.removeAll() }
    }
    private func refreshStates() {
        quickDate = stateStore?.date(.quick); resumeDate = stateStore?.date(.resume)
    }
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
        stateBusy = true
        let wasPaused = paused; setPaused(true)
        var success = false
        do {
            let data: Data = try await withCheckedThrowingContinuation { continuation in
                bridge.captureState { data, error in
                    if let data { continuation.resume(returning: data) }
                    else { continuation.resume(throwing: NSError(domain: "EmuDen.State", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: error ?? "State capture failed."])) }
                }
            }
            try await Task.detached(priority: .userInitiated) { try store.write(data, slot: slot) }.value
            refreshStates(); notice = slot == .quick ? "Quick save ready" : "Resume point saved"
            success = true
        } catch { message = error.localizedDescription }
        stateBusy = false
        setPaused(wasPaused)
        return success
    }
    func load(_ slot: SaveStateStore.Slot) async {
        guard !stateBusy, !booting, !closed, let store = stateStore else { return }
        stateBusy = true
        let wasPaused = paused; setPaused(true)
        do {
            let data = try await Task.detached(priority: .userInitiated) { try store.read(slot) }.value
            let error: String? = await withCheckedContinuation { continuation in
                bridge.restoreState(data) { continuation.resume(returning: $0) }
            }
            if let error { message = error }
            else { notice = slot == .quick ? "Quick save loaded" : "Session resumed" }
        } catch { message = error.localizedDescription }
        stateBusy = false
        setPaused(wasPaused)
    }
    func background() {
        setPaused(true)
        guard !stateBusy, !booting, !closed else { return }
        var task = UIBackgroundTaskIdentifier.invalid
        task = UIApplication.shared.beginBackgroundTask(withName: "Save emulation session") {
            if task != .invalid { UIApplication.shared.endBackgroundTask(task); task = .invalid }
        }
        Task {
            await save(.resume)
            if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
        }
    }
    func releaseTouchControls() {
        for id in touchButtons { bridge.setButton(id, pressed: controllerButtons.contains(id)) }
        touchButtons.removeAll()
        bridge.setAnalogX(0, y: 0)
        bridge.setTouchX(0, y: 0, pressed: false)
    }
    private func connectControllers() {
        for c in controllers { c.extendedGamepad?.valueChangedHandler = nil; c.extendedGamepad?.buttonMenu.pressedChangedHandler = nil }
        for id in controllerButtons { bridge.setButton(id, pressed: touchButtons.contains(id)) }
        controllerButtons.removeAll(); bridge.setAnalogX(0, y: 0)
        let arguments = ProcessInfo.processInfo.arguments
        let preview = diagnostic && (arguments.contains("--touch-controls-preview") || arguments.contains("--controller-preview"))
        controllers = preview ? [] : Array(GCController.controllers().filter { $0.extendedGamepad != nil }.prefix(1))
        hasController = !controllers.isEmpty
        controllerName = controllers.first.map { $0.vendorName ?? "Game controller" }
        if diagnostic && ProcessInfo.processInfo.arguments.contains("--controller-preview") {
            hasController = true; controllerName = "Controller preview"
        }
        for controller in controllers {
            controller.handlerQueue = .main
            guard let pad = controller.extendedGamepad else { continue }
            pad.valueChangedHandler = { [weak self] pad, _ in
                guard let self else { return }
                // Physical positions match Nintendo: right=A, bottom=B, top=X, left=Y.
                let bindings: [(GCControllerButtonInput, UInt32, String)] = [
                    (pad.buttonB,8,"A"), (pad.buttonA,0,"B"), (pad.buttonY,9,"X"), (pad.buttonX,1,"Y"),
                    (pad.leftShoulder,10,"L"), (pad.rightShoulder,11,"R"), (pad.leftTrigger,12,"ZL"), (pad.rightTrigger,13,"ZR"),
                    (pad.dpad.up,4,"Up"), (pad.dpad.down,5,"Down"), (pad.dpad.left,6,"Left"), (pad.dpad.right,7,"Right")]
                for (button,id,label) in bindings { self.button(id,label,button.isPressed,controller:true) }
                if let options = pad.buttonOptions { self.button(2,"Select",options.isPressed,controller:true) }
                self.analog(x: pad.leftThumbstick.xAxis.value, y: -pad.leftThumbstick.yAxis.value)
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
        for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
        for c in controllers { c.extendedGamepad?.valueChangedHandler = nil; c.extendedGamepad?.buttonMenu.pressedChangedHandler = nil }
        bridge.frameHandler = nil; bridge.messageHandler = nil; bridge.statisticsHandler = nil
        bridge.performanceHandler = nil; bridge.shaderProgressHandler = nil
        bridge.stop { completion() }
    }
}
