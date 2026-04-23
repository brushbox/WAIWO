import Testing
import Foundation
@testable import WAIWO

struct PositionerLogicTests {
    @Test func prefersPositionFarFromFocusedWindow() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        let focusedWindowFrame = CGRect(x: 0, y: 500, width: 960, height: 580)
        let cursorPosition = CGPoint(x: 480, y: 700)

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            focusedWindowFrame: focusedWindowFrame,
            cursorPosition: cursorPosition
        )

        // Should be placed away from the focused window (right side of screen)
        #expect(result.x > screenBounds.midX)
    }

    @Test func clampsToScreenBounds() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        let focusedWindowFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let cursorPosition = CGPoint(x: 960, y: 540)

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            focusedWindowFrame: focusedWindowFrame,
            cursorPosition: cursorPosition
        )

        #expect(result.x >= screenBounds.minX)
        #expect(result.y >= screenBounds.minY)
        #expect(result.x + overlaySize.width <= screenBounds.maxX)
        #expect(result.y + overlaySize.height <= screenBounds.maxY)
    }

    @Test func repelsFromCursor() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        let focusedWindowFrame: CGRect? = nil
        let cursorNear = CGPoint(x: 160, y: 40)

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            focusedWindowFrame: focusedWindowFrame,
            cursorPosition: cursorNear
        )

        let distFromCursor = hypot(
            result.x + overlaySize.width / 2 - cursorNear.x,
            result.y + overlaySize.height / 2 - cursorNear.y
        )
        #expect(distFromCursor > 150)
    }
}
