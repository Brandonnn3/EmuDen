import GameController
import SwiftUI

@MainActor
final class ConsoleMenuInput: ObservableObject {
    enum Command { case left, right, confirm, back, settings, previousSystem, nextSystem }
    @Published private(set) var connected = false
    @Published private(set) var confirmGlyph = "a.circle.fill"
    @Published private(set) var settingsGlyph = "y.circle.fill"
    private var controllers = [GCController]()
    private var direction = 0
    private var action: ((Command) -> Void)?

    func start(action: @escaping (Command) -> Void) {
        stop()
        self.action = action
        controllers = GCController.controllers().filter { $0.extendedGamepad != nil }
        let available = !controllers.isEmpty
        let confirm = controllers.first?.extendedGamepad?.buttonA.sfSymbolsName ?? "a.circle.fill"
        let settings = controllers.first?.extendedGamepad?.buttonY.sfSymbolsName ?? "y.circle.fill"
        if connected != available { connected = available }
        if confirmGlyph != confirm { confirmGlyph = confirm }
        if settingsGlyph != settings { settingsGlyph = settings }
        for controller in controllers {
            controller.handlerQueue = .main
            guard let pad = controller.extendedGamepad else { continue }
            // Own the element callbacks; the player uses the profile callback separately.
            pad.dpad.valueChangedHandler = { [weak self] _, x, _ in self?.move(x) }
            pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, _ in self?.move(x) }
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.action?(.confirm) } }
            pad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.action?(.back) } }
            pad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.action?(.settings) } }
            pad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.action?(.previousSystem) } }
            pad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.action?(.nextSystem) } }
        }
    }

    func stop() {
        action = nil; direction = 0
        for controller in controllers {
            guard let pad = controller.extendedGamepad else { continue }
            pad.dpad.valueChangedHandler = nil
            pad.leftThumbstick.valueChangedHandler = nil
            pad.buttonA.pressedChangedHandler = nil
            pad.buttonB.pressedChangedHandler = nil
            pad.buttonY.pressedChangedHandler = nil
            pad.leftShoulder.pressedChangedHandler = nil
            pad.rightShoulder.pressedChangedHandler = nil
        }
        controllers.removeAll()
    }

    private func move(_ x: Float) {
        let next = x < -0.55 ? -1 : x > 0.55 ? 1 : 0
        guard next != direction else { return }
        direction = next
        if next != 0 { action?(next < 0 ? .left : .right) }
    }
}
