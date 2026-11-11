import AVFAudio
import SwiftUI

/// Shares the system audio session with the emulator, but never plays over it.
@MainActor
final class MenuAudio: ObservableObject {
    enum Cue: String, CaseIterable { case focus, confirm, back, launch, planned, search, open, unfold, save }
    @Published var enabled: Bool { didSet {
        UserDefaults.standard.set(enabled, forKey: "menuSoundsEnabled")
        if !enabled { stopPlayers() }
    } }
    @Published var volume: Double { didSet {
        UserDefaults.standard.set(volume, forKey: "menuSoundsVolume")
    } }
    private var players: [Cue: AVAudioPlayer] = [:]
    private var active = false
    private var sessionReady = false
    private var previousSession: (AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)?
    private var preparing = false
    private var activationGeneration = 0
    private var pendingCue: Cue?
    private var lastFocus = -Double.infinity
    private let selection = UISelectionFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .soft)

    init() {
        let defaults = UserDefaults.standard
        enabled = defaults.object(forKey: "menuSoundsEnabled") as? Bool ?? true
        let savedVolume = defaults.object(forKey: "menuSoundsVolume") as? Double ?? 0.35
        volume = savedVolume.isFinite ? min(1, max(0, savedVolume)) : 0.35
        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav", subdirectory: "MenuAudio") else { continue }
            players[cue] = try? AVAudioPlayer(contentsOf: url)
        }
    }

    func setActive(_ value: Bool) {
        guard value != active else { return }
        active = value
        if value, enabled, volume > 0 { prepareSession() }
        else if !value {
            stopPlayers()
            sessionReady = false
            preparing = false; activationGeneration += 1; pendingCue = nil
            if let previousSession {
                try? AVAudioSession.sharedInstance().setCategory(previousSession.0, mode: previousSession.1, options: previousSession.2)
                self.previousSession = nil
            }
            // Do not deactivate the shared session: the core is about to own it.
        }
    }

    @discardableResult
    func play(_ cue: Cue) -> TimeInterval {
        guard active else { return 0 }
        let now = ProcessInfo.processInfo.systemUptime
        if cue == .focus {
            guard now - lastFocus >= 0.075 else { return 0 }
            lastFocus = now
        }
        if UserDefaults.standard.object(forKey: "buttonHaptics") as? Bool ?? true {
            if cue == .focus { selection.selectionChanged() }
            else { impact.impactOccurred(intensity: cue == .unfold ? 0.35 : 0.55) }
        }
        guard enabled, volume > 0, let player = players[cue] else { return 0 }
        guard prepareSession() else {
            pendingCue = cue
            return cue == .launch ? player.duration + 0.15 : 0
        }
        return playReady(cue)
    }

    private func playReady(_ cue: Cue) -> TimeInterval {
        guard active, enabled, volume > 0, let player = players[cue] else { return 0 }
        if cue != .focus { for (key, other) in players where key != cue { other.stop() } }
        player.currentTime = 0
        player.volume = Float(min(1, max(0, volume)))
        return player.play() ? player.duration : 0
    }

    private func stopPlayers() {
        for player in players.values { player.stop(); player.currentTime = 0 }
    }

    @discardableResult
    private func prepareSession() -> Bool {
        if sessionReady { return true }
        if preparing { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            if previousSession == nil { previousSession = (session.category, session.mode, session.categoryOptions) }
            try session.setCategory(.ambient, mode: .default)
            if #available(iOS 27.0, *) {
                preparing = true; activationGeneration += 1
                let generation = activationGeneration
                session.activate(options: []) { [weak self] activated, _ in
                    Task { @MainActor in
                        guard let self, self.active, generation == self.activationGeneration else { return }
                        self.preparing = false; self.sessionReady = activated
                        guard activated else { self.pendingCue = nil; return }
                        for player in self.players.values { player.prepareToPlay() }
                        if let cue = self.pendingCue { self.pendingCue = nil; _ = self.playReady(cue) }
                    }
                }
                return false
            }
            try session.setActive(true)
            for player in players.values { player.prepareToPlay() }
            sessionReady = true
            return true
        } catch { return false }
    }
}

struct MenuAudioSettings: View {
    @EnvironmentObject private var audio: MenuAudio
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Label("Sound & feel", systemImage: "waveform").font(.headline).foregroundStyle(.white)
            Toggle("Button sounds", isOn: $audio.enabled).accessibilityIdentifier("menuSoundsEnabled")
                .onChange(of: audio.enabled) { _, enabled in if enabled { audio.play(.confirm) } }
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.1").accessibilityHidden(true)
                Slider(value: $audio.volume, in: 0...1, onEditingChanged: { editing in if !editing { audio.play(.confirm) } })
                    .accessibilityLabel("Menu sound volume")
                Text(audio.volume, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit()).frame(width: 36)
            }.foregroundStyle(ConsoleTheme.quiet).disabled(!audio.enabled)
            Button { audio.play(.confirm) } label: { Label("Preview chime", systemImage: "play.circle").frame(minHeight: 44) }.buttonStyle(ConsolePressStyle())
                .disabled(!audio.enabled || audio.volume == 0).accessibilityIdentifier("previewMenuSound")
            Text("Original glass tones and soft tactile feedback. Sounds follow Silent Mode and pause during gameplay.")
                .font(.caption).foregroundStyle(ConsoleTheme.quiet)
        }.tint(ConsoleTheme.blue)
    }
}
