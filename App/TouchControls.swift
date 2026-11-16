import SwiftUI

struct TouchControls: View {
    let session: EmulatorSession
    let size: CGSize
    let area: CGRect
    let startArea: CGRect
    let mode: String
    let editing: Bool
    @AppStorage("touchControlLayouts") private var saved = Data()
    @State private var origin: CGPoint?
    @State private var dragging: String?
    private var key: String { session.platform.rawValue + "." + mode }
    private struct Item: Identifiable {
        let id: String
        let label: String
        let name: String
        let size: CGSize
        let point: CGPoint
        var color = Color(white: 0.22)
        var text = Color.white
    }
    private var items: [Item] {
        let gc = session.platform == .gamecube, ps = session.platform == .ps1
        let left = area.minX + min(82, area.width * 0.23), right = area.maxX - min(82, area.width * 0.23)
        let h = area.height, y = area.minY
        let faceY = y + h * (gc ? 0.40 : 0.39)
        let dpadY = y + h * (gc ? 0.73 : 0.39)
        let stickY = y + h * (gc ? 0.29 : 0.79)
        var result: [Item] = []
        func button(_ id: Int, _ label: String, _ name: String, _ x: CGFloat, _ cy: CGFloat, _ w: CGFloat = 44, _ bh: CGFloat = 44, _ color: Color = Color(white: 0.22), _ text: Color = .white) {
            result.append(Item(id: String(id), label: label, name: name, size: CGSize(width: w, height: bh), point: CGPoint(x: x, y: cy), color: color, text: text))
        }
        button(10, ps ? "L1" : "L", ps ? "L1" : "L", left - (gc ? 0 : 28), y + 22, gc ? 68 : 50)
        if !gc { button(12, ps ? "L2" : "ZL", ps ? "L2" : "ZL", left + 28, y + 22, 50) }
        button(11, ps ? "R1" : "R", ps ? "R1" : "R", right + (gc ? 0 : 28), y + 22, gc ? 68 : 50)
        if !gc { button(13, ps ? "R2" : "ZR", ps ? "R2" : "ZR", right - 28, y + 22, 50) }
        // Each direction is its own touch target, so diagonals and face-button chords remain independent.
        button(4, "↑", "Up", left, dpadY - 43)
        button(6, "←", "Left", left - 43, dpadY)
        button(7, "→", "Right", left + 43, dpadY)
        button(5, "↓", "Down", left, dpadY + 43)
        if gc {
            button(0, "A", "A", right, faceY + 13, 66, 66, Color(red: 0.13, green: 0.68, blue: 0.39), .black.opacity(0.8))
            button(8, "B", "B", right - 56, faceY + 48, 44, 44, Color(red: 0.86, green: 0.20, blue: 0.24))
            button(1, "X", "X", right + 57, faceY - 27, 44, 62, Color(white: 0.64), .black.opacity(0.8))
            button(9, "Y", "Y", right - 13, faceY - 42, 62, 44, Color(white: 0.64), .black.opacity(0.8))
            button(12, "Z", "Z", right + 55, y + 22, 44, 44, Color(red: 0.44, green: 0.34, blue: 0.84))
        } else {
            button(9, ps ? "△" : "X", ps ? "Triangle" : "X", right, faceY - 47, 48, 48, Color(white: 0.20), ps ? .mint : .white)
            button(1, ps ? "□" : "Y", ps ? "Square" : "Y", right - 47, faceY, 48, 48, Color(white: 0.20), ps ? .pink : .white)
            button(8, ps ? "○" : "A", ps ? "Circle" : "A", right + 47, faceY, 48, 48, Color(white: 0.20), ps ? .red : .white)
            button(0, ps ? "×" : "B", ps ? "Cross" : "B", right, faceY + 47, 48, 48, Color(white: 0.20), ps ? .cyan : .white)
        }
        let stickSize: CGFloat = gc ? 84 : 78
        result.append(Item(id: "stick", label: "", name: ps ? "Left analog stick" : "Circle pad", size: CGSize(width: stickSize, height: stickSize), point: CGPoint(x: left, y: stickY)))
        if ps || gc {
            result.append(Item(id: "rightStick", label: gc ? "C" : "", name: gc ? "C-stick" : "Right analog stick", size: CGSize(width: gc ? 66 : 78, height: gc ? 66 : 78), point: CGPoint(x: right, y: y + h * 0.80), color: gc ? .yellow : Color(white: 0.22)))
        }
        if session.platform == .threeDS {
            // The Circle Pad sits above the D-pad on 3DS.
            if let index = result.firstIndex(where: { $0.id == "stick" }) {
                let old = result[index]
                result[index] = Item(id: old.id, label: "", name: old.name, size: old.size, point: CGPoint(x: left, y: y + h * 0.28))
                for i in result.indices where ["4", "5", "6", "7"].contains(result[i].id) {
                    let b = result[i]
                    result[i] = Item(id: b.id, label: b.label, name: b.name, size: b.size, point: CGPoint(x: b.point.x, y: b.point.y + h * 0.34), color: b.color, text: b.text)
                }
            }
        }
        if !gc { button(2, "SELECT", "Select", startArea.midX - 44, startArea.midY, 70) }
        button(3, "START", "Start", startArea.midX + (gc ? 0 : 44), startArea.midY, gc ? 58 : 70)
        return result
    }
    private func center(_ item: Item, positions cached: [String: ControlPosition]? = nil) -> CGPoint {
        let positions = cached ?? ControlLayouts.decode(saved).layouts[key] ?? [:]
        return (positions[item.id] ?? ControlPosition.clamped(item.point, in: size, control: item.size)).point(in: size, control: item.size)
    }
    var body: some View {
        let positions = ControlLayouts.decode(saved).layouts[key] ?? [:]
        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                Group {
                    if editing {
                        visual(item, held: false).overlay { RoundedRectangle(cornerRadius: 16).stroke(.cyan.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4])) }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("touchCanvas")).onChanged { value in
                                if dragging != item.id { dragging = item.id; origin = center(item) }
                                let start = origin ?? center(item)
                                move(item, to: CGPoint(x: start.x + value.translation.width, y: start.y + value.translation.height))
                            }.onEnded { _ in origin = nil; dragging = nil })
                            .accessibilityLabel("Move " + item.name).accessibilityIdentifier("move-" + item.id)
                            .accessibilityAction(named: "Move left") { nudge(item, x: -12, y: 0) }
                            .accessibilityAction(named: "Move right") { nudge(item, x: 12, y: 0) }
                            .accessibilityAction(named: "Move up") { nudge(item, x: 0, y: -12) }
                            .accessibilityAction(named: "Move down") { nudge(item, x: 0, y: 12) }
                    } else if item.id == "stick" || item.id == "rightStick" {
                        StickControl(session: session, secondary: item.id == "rightStick", name: item.name, color: item.color, label: item.label)
                    } else if let id = UInt32(item.id) {
                        ImmediateControlButton(session: session, id: id, label: item.label, name: item.name, color: item.color, text: item.text)
                    }
                }.frame(width: item.size.width, height: item.size.height).position(center(item, positions: positions))
            }
        }.frame(width: size.width, height: size.height).coordinateSpace(name: "touchCanvas")
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("touchControlCanvas")
    }
    private func visual(_ item: Item, held: Bool) -> some View {
        RaisedControlCap(label: item.label.isEmpty ? "◉" : item.label, color: item.color, text: item.text, held: held)
    }
    private func move(_ item: Item, to point: CGPoint) {
        var value = ControlLayouts.decode(saved)
        value.layouts[key, default: [:]][item.id] = ControlPosition.clamped(point, in: size, control: item.size)
        saved = value.encoded()
    }
    private func nudge(_ item: Item, x: CGFloat, y: CGFloat) { let p = center(item); move(item, to: CGPoint(x: p.x + x, y: p.y + y)) }
}

private struct ImmediateControlButton: View {
    let session: EmulatorSession
    let id: UInt32
    let label: String
    let name: String
    let color: Color
    let text: Color
    @State private var held = false
    var body: some View {
        RaisedControlCap(label: label, color: color, text: text, held: held)
            .overlay { TouchSurface { _, down in held = down; session.button(id, name, down) } }
            .accessibilityElement(children: .ignore).accessibilityLabel(name).accessibilityIdentifier("control-\(id)")
            .accessibilityAddTraits(.isButton).accessibilityValue(held ? "Pressed" : "Released")
            .accessibilityAction { session.button(id, name, true); session.button(id, name, false) }
    }
}

private struct StickControl: View {
    let session: EmulatorSession
    let secondary: Bool
    let name: String
    let color: Color
    let label: String
    @State private var offset = CGSize.zero
    var body: some View {
        GeometryReader { geometry in
            let radius = geometry.size.width * 0.27
            ControlStickVisual(color: color, label: label, offset: offset).overlay {
                // This fixed UIView owns its touch until release, even outside the stick's border.
                TouchSurface { point, down in
                    let rawX = Float((point.x - 0.5) / 0.372), rawY = Float((point.y - 0.5) / 0.372)
                    let distance = max(1, hypot(rawX, rawY))
                    let x: Float = down ? rawX / distance : 0, y: Float = down ? rawY / distance : 0
                    offset = CGSize(width: CGFloat(x) * radius, height: CGFloat(y) * radius)
                    if secondary { session.secondaryAnalog(x: x, y: y) } else { session.analog(x: x, y: y) }
                }
            }.accessibilityElement(children: .ignore).accessibilityLabel(name).accessibilityIdentifier(secondary ? "rightAnalogStick" : "leftAnalogStick")
                .accessibilityValue(offset == .zero ? "Neutral" : "Active")
        }
    }
}


// The visual moves inside a fixed hit target, so pressing and dragging never shifts touch ownership.
struct RaisedControlCap: View {
    let label: String
    var color = Color(white: 0.24)
    var text = Color.white
    var held = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { area in
            let depth = min(5, area.size.height * 0.11)
            ZStack(alignment: .top) {
                Capsule().fill(Color(white: 0.055)).overlay { Capsule().stroke(.black.opacity(0.8), lineWidth: 1) }
                    .offset(y: depth)
                Capsule().fill(color.gradient)
                    .overlay { Capsule().fill(LinearGradient(colors: [.white.opacity(0.30), .clear, .black.opacity(0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)) }
                    .overlay { Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2) }
                    .overlay { Capsule().inset(by: 3).stroke(.white.opacity(0.08), lineWidth: 1) }
                    .overlay {
                        Text(label).font(.system(size: min(area.size.width * 0.40, label.count > 3 ? 10 : 22), weight: .bold, design: .rounded))
                            .foregroundStyle(text).shadow(color: .black.opacity(0.35), radius: 0, y: 1)
                    }
                    .offset(y: held ? depth : 0)
            }.frame(height: max(0, area.size.height - depth))
                .shadow(color: .black.opacity(held ? 0.3 : 0.6), radius: held ? 1 : 3, y: held ? 1 : 4)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: held)
        }.allowsHitTesting(false)
    }
}

struct ControlStickVisual: View {
    var color = Color(white: 0.32)
    var label = ""
    var offset = CGSize.zero
    var body: some View {
        GeometryReader { area in
            let cap = min(area.size.width, area.size.height) * 0.63
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(white: 0.035), Color(white: 0.12)], startPoint: .top, endPoint: .bottom))
                    .overlay { Circle().strokeBorder(LinearGradient(colors: [.black, .white.opacity(0.24)], startPoint: .top, endPoint: .bottom), lineWidth: 3) }
                    .overlay { Circle().inset(by: 6).stroke(.black.opacity(0.6), lineWidth: 2) }
                Circle().fill(.black.opacity(0.9)).frame(width: cap * 0.65).offset(y: 4).offset(offset)
                Circle().fill(color.gradient)
                    .overlay { Circle().fill(LinearGradient(colors: [.white.opacity(0.25), .clear, .black.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)) }
                    .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5) }
                    .overlay { Circle().inset(by: 5).stroke(.black.opacity(0.4), lineWidth: 1.2) }
                    .overlay { Circle().inset(by: 8).stroke(.white.opacity(0.12), lineWidth: 1) }
                    .overlay { Text(label).font(.system(size: cap * 0.33, weight: .bold, design: .rounded)).foregroundStyle(.black.opacity(0.7)) }
                    .frame(width: cap, height: cap).shadow(color: .black.opacity(0.8), radius: 3, y: 4).offset(offset)
            }
        }.allowsHitTesting(false)
    }
}
