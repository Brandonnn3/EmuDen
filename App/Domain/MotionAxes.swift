import Foundation

enum MotionAxes {
    // Match pinned Azahar's Android transform; quarter turns are counterclockwise from portrait.
    static func threeDS(_ value: SIMD3<Double>, quarterTurns: Int) -> SIMD3<Double> {
        guard value.x.isFinite, value.y.isFinite, value.z.isFinite else { return .zero }
        switch quarterTurns {
        case 1: return SIMD3(value.y, value.z, value.x)
        case 2: return SIMD3(value.x, value.z, -value.y)
        case 3: return SIMD3(-value.y, value.z, -value.x)
        default: return SIMD3(-value.x, value.z, value.y)
        }
    }
}
