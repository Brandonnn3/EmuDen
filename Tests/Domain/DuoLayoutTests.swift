import XCTest
import CoreGraphics
@testable import EmulatorDomain

final class DuoLayoutTests: XCTestCase {
    func testScreenBalancePartitionsEveryPixelAndPreservesDefaultLandscapeRatio() {
        for size in [CGSize(width: 466, height: 678), CGSize(width: 678, height: 466)] {
            let horizontal = size.width > size.height
            for balance in [0.35, 0.5, 0.65, Double.nan] {
                let frames = DuoLayout.expandedScreens(in: size, horizontal: horizontal, balance: balance)
                XCTAssertEqual(frames.top.union(frames.bottom), CGRect(origin: .zero, size: size))
                XCTAssertLessThanOrEqual(frames.top.intersection(frames.bottom).width * frames.top.intersection(frames.bottom).height, 0)
                if !horizontal, balance.isFinite { XCTAssertEqual(frames.top.height, size.height * balance, accuracy: 0.001) }
                if horizontal, balance == 0.5 { XCTAssertEqual(frames.top.width / frames.bottom.width, 1.25, accuracy: 0.001) }
            }
        }
    }
    func testExpandedOuterDisplayHasNoUnusedMarginsOrGapInEitherOrientation() {
        for size in [CGSize(width: 466, height: 678), CGSize(width: 678, height: 466), CGSize(width: 430, height: 932)] {
            let horizontal = size.width > size.height * 1.25
            let frames = DuoLayout.expandedScreens(in: size, horizontal: horizontal)
            let display = CGRect(origin: .zero, size: size)
            XCTAssertEqual(frames.top.union(frames.bottom), display)
            XCTAssertFalse(frames.top.intersects(frames.bottom))
            if horizontal {
                XCTAssertEqual(frames.top.maxX, frames.bottom.minX)
                XCTAssertEqual(frames.top.height, size.height); XCTAssertEqual(frames.bottom.height, size.height)
            } else {
                XCTAssertEqual(frames.top.maxY, frames.bottom.minY)
                XCTAssertEqual(frames.top.width, size.width); XCTAssertEqual(frames.bottom.width, size.width)
            }
        }
    }
    func testImmersiveControllerLayoutUsesEachWholePanelWithoutCrossingFold() {
        let fold = CGRect(x: 0, y: 430, width: 626, height: 30)
        let layout = DuoLayout(size: CGSize(width: 626, height: 890), division: fold, controls: false, immersive: true)
        XCTAssertEqual(layout.topPanel.maxY, fold.minY)
        XCTAssertEqual(layout.bottomPanel.minY, fold.maxY)
        XCTAssertEqual(layout.bottomScreenArea, layout.bottomPanel)
        XCTAssertFalse(layout.bottomScreenArea.intersects(fold))
    }
    func testFlatDeviceKeepsScreensAlignedToInactiveFold() {
        let layout = DuoLayout(size: CGSize(width: 890, height: 626), division: CGRect(x: 445, y: 0, width: 0, height: 626), controls: false)
        XCTAssertEqual(layout.topPanel.maxX, 435)
        XCTAssertEqual(layout.bottomPanel.minX, 455)
        XCTAssertTrue(layout.bottomScreenArea.width.isFinite)
    }
    func testTabletopScreensStayOnTheirOwnSideOfTheFold() {
        let fold = CGRect(x: 0, y: 430, width: 626, height: 30)
        let layout = DuoLayout(size: CGSize(width: 626, height: 890), division: fold, controls: true)
        XCTAssertLessThan(layout.topPanel.maxY, fold.minY)
        XCTAssertGreaterThan(layout.bottomPanel.minY, fold.maxY)
        XCTAssertTrue(layout.controlsBesideScreen)
        XCTAssertFalse(layout.bottomScreenArea.intersects(fold))
    }
    func testBookOrientationFollowsVerticalFold() {
        let fold = CGRect(x: 430, y: 0, width: 30, height: 626)
        let layout = DuoLayout(size: CGSize(width: 890, height: 626), division: fold, controls: true)
        XCTAssertLessThan(layout.topPanel.maxX, fold.minX)
        XCTAssertGreaterThan(layout.bottomPanel.minX, fold.maxX)
        XCTAssertFalse(layout.controlsBesideScreen)
        XCTAssertLessThanOrEqual(layout.bottomScreenArea.maxY, layout.controlsArea.minY)
    }
    func testControllerConnectionEnlargesTouchScreenWithoutStretching() {
        for (size, fold) in [(CGSize(width: 626, height: 890), CGRect(x: 0, y: 435, width: 626, height: 20)),
                             (CGSize(width: 890, height: 626), CGRect(x: 435, y: 0, width: 20, height: 626))] {
            let touch = DuoLayout(size: size, division: fold, controls: true)
            let controller = DuoLayout(size: size, division: fold, controls: false)
            let small = DuoLayout.fit(aspect: 4.0 / 3, in: touch.bottomScreenArea)
            let large = DuoLayout.fit(aspect: 4.0 / 3, in: controller.bottomScreenArea)
            XCTAssertGreaterThan(large.width, small.width)
            XCTAssertEqual(large.width / large.height, 4.0 / 3, accuracy: 0.001)
            XCTAssertTrue(controller.bottomPanel.contains(large))
        }
    }
}
