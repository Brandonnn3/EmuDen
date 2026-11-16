import XCTest
@testable import EmulatorDomain

final class MotionAxesTests: XCTestCase {
    func testUprightGravityIsTheSameInEachDisplayOrientation() {
        for (turns, gravity) in [SIMD3(0.0, -1, 0), SIMD3(-1.0, 0, 0), SIMD3(0.0, 1, 0), SIMD3(1.0, 0, 0)].enumerated() {
            XCTAssertEqual(MotionAxes.threeDS(gravity, quarterTurns: turns), SIMD3(0, 0, -1))
            XCTAssertEqual(MotionAxes.threeDS(SIMD3(0, 0, -1), quarterTurns: turns), SIMD3(0, -1, 0))
        }
    }
    func testGyroscopeAxesRetainTheirRadiansAndMatchPinnedCoreCoordinates() {
        let expected = [SIMD3(-1.0, 3, 2), SIMD3(2.0, 3, 1), SIMD3(1.0, 3, -2), SIMD3(-2.0, 3, -1)]
        for (turns, vector) in expected.enumerated() {
            XCTAssertEqual(MotionAxes.threeDS(SIMD3(1, 2, 3), quarterTurns: turns), vector)
        }
        XCTAssertEqual(MotionAxes.threeDS(SIMD3(0.5, 0, 0), quarterTurns: 0), SIMD3(-0.5, 0, 0))
        XCTAssertEqual(MotionAxes.threeDS(SIMD3(.nan, 0, 0), quarterTurns: 0), .zero)
    }
}
