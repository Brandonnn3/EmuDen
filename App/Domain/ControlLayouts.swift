import Foundation
import CoreGraphics

struct ControlPosition: Codable, Equatable {
    var x: Double
    var y: Double
    func point(in size: CGSize, control: CGSize) -> CGPoint {
        CGPoint(x: min(max(control.width / 2, x * size.width), max(control.width / 2, size.width - control.width / 2)),
                y: min(max(control.height / 2, y * size.height), max(control.height / 2, size.height - control.height / 2)))
    }
    static func clamped(_ point: CGPoint, in size: CGSize, control: CGSize) -> Self {
        let safe = Self(x: point.x.isFinite ? point.x / max(1, size.width) : 0.5,
                        y: point.y.isFinite ? point.y / max(1, size.height) : 0.5)
        let p = safe.point(in: size, control: control)
        return Self(x: p.x / max(1, size.width), y: p.y / max(1, size.height))
    }
}

/// Positions are separate for each console and each flat/folded orientation.
struct ControlLayouts: Codable, Equatable {
    var layouts: [String: [String: ControlPosition]] = [:]
    static let modes = ["portrait", "landscape", "tabletop", "book"]
    static let controls = Set((0...15).map(String.init) + ["stick", "rightStick"])
    static func decode(_ data: Data) -> Self {
        guard data.count <= 65_536, let value = try? JSONDecoder().decode(Self.self, from: data), value.layouts.count <= 12 else { return Self() }
        for (key, positions) in value.layouts {
            guard ["3ds", "ps1", "gamecube"].contains(where: { console in modes.contains { key == console + "." + $0 } }), positions.count <= 18,
                  positions.allSatisfy({ controls.contains($0.key) && $0.value.x.isFinite && $0.value.y.isFinite && (0...1).contains($0.value.x) && (0...1).contains($0.value.y) }) else { return Self() }
        }
        return value
    }
    func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
}
