import Foundation
import CoreGraphics

/// Screen regions follow the system's fold, including when the device rotates.
struct DuoLayout {
    let topPanel: CGRect
    let bottomPanel: CGRect
    let controlsBesideScreen: Bool
    let bottomScreenArea: CGRect
    let controlsArea: CGRect
    let startArea: CGRect

    init(size: CGSize, division: CGRect, controls: Bool, immersive: Bool = false) {
        // Inactive fold regions have zero thickness, so preserve their position.
        let minX = max(0, min(size.width, division.minX)), maxX = max(0, min(size.width, division.maxX))
        let minY = max(0, min(size.height, division.minY)), maxY = max(0, min(size.height, division.maxY))
        let fold = CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
        let gap: CGFloat = immersive ? 0 : 10
        if division.height >= division.width {
            topPanel = CGRect(x: 0, y: 0, width: max(0, fold.minX - gap), height: size.height)
            bottomPanel = CGRect(x: min(size.width, fold.maxX + gap), y: 0,
                                 width: max(0, size.width - fold.maxX - gap), height: size.height)
        } else {
            topPanel = CGRect(x: 0, y: 0, width: size.width, height: max(0, fold.minY - gap))
            bottomPanel = CGRect(x: 0, y: min(size.height, fold.maxY + gap),
                                 width: size.width, height: max(0, size.height - fold.maxY - gap))
        }
        let content = immersive ? bottomPanel : CGRect(x: bottomPanel.minX + min(16, bottomPanel.width / 2), y: bottomPanel.minY + min(12, bottomPanel.height / 2),
                             width: max(0, bottomPanel.width - 32), height: max(0, bottomPanel.height - 24))
        controlsBesideScreen = controls && content.width >= 400 && content.width >= content.height * 1.25
        startArea = controls ? CGRect(x: content.minX, y: content.maxY - 44, width: content.width, height: 44) : .zero
        if controlsBesideScreen {
            controlsArea = CGRect(x: content.minX, y: content.minY, width: content.width, height: max(0, content.height - 48))
            bottomScreenArea = CGRect(x: content.minX + 132, y: content.minY,
                                      width: max(0, content.width - 276), height: max(0, content.height - 48))
        } else if controls {
            let height = min(286, max(0, content.height - 132))
            controlsArea = CGRect(x: content.minX, y: startArea.minY - height - 4, width: content.width, height: height)
            bottomScreenArea = CGRect(x: content.minX, y: content.minY,
                                      width: content.width, height: max(0, controlsArea.minY - content.minY - 12))
        } else {
            controlsArea = .zero
            bottomScreenArea = content
        }
    }
    static func fit(aspect: CGFloat, in area: CGRect) -> CGRect {
        let width = max(0, min(area.width, area.height * aspect))
        let height = width / aspect
        return CGRect(x: area.midX - width / 2, y: area.midY - height / 2, width: width, height: height)
    }
    static func expandedScreens(in size: CGSize, horizontal: Bool, balance: Double = 0.5) -> (top: CGRect, bottom: CGRect) {
        let width = max(0, size.width), height = max(0, size.height)
        let share = balance.isFinite ? min(0.65, max(0.35, balance)) : 0.5
        if horizontal {
            let split = width * (5 * share) / (5 * share + 4 * (1 - share))
            return (CGRect(x: 0, y: 0, width: split, height: height),
                    CGRect(x: split, y: 0, width: width - split, height: height))
        }
        let split = height * share
        return (CGRect(x: 0, y: 0, width: width, height: split),
                CGRect(x: 0, y: split, width: width, height: height - split))
    }
}
