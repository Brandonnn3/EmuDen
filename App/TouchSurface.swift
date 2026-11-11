import SwiftUI

/// UIKit delivers touch-down immediately, without SwiftUI's drag recognition delay.
struct TouchSurface: UIViewRepresentable {
    var changed: (CGPoint, Bool) -> Void
    func makeUIView(context: Context) -> ImmediateTouchView {
        let view = ImmediateTouchView(); view.changed = changed
        return view
    }
    func updateUIView(_ view: ImmediateTouchView, context: Context) { view.changed = changed }
    static func dismantleUIView(_ view: ImmediateTouchView, coordinator: ()) { view.release() }
}

final class ImmediateTouchView: UIView {
    var changed: ((CGPoint, Bool) -> Void)?
    private var activeTouch: UITouch?
    private var last = CGPoint.zero
    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    private func send(_ touch: UITouch, down: Bool) {
        let point = touch.location(in: self)
        last = CGPoint(x: min(1, max(0, point.x / max(1, bounds.width))),
                       y: min(1, max(0, point.y / max(1, bounds.height))))
        changed?(last, down)
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch; send(touch, down: true)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        send(touch, down: true)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        send(touch, down: false); activeTouch = nil
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { release() }
    func release() {
        if activeTouch != nil { changed?(last, false); activeTouch = nil }
    }
    override func didMoveToWindow() { if window == nil { release() } }
}
