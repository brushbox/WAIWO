import Testing
import Foundation
@testable import WAIWO

struct PositionerLogicTests {
    @Test func staysWhenCursorIsFar() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        let startPos = CGPoint(x: 1500, y: 700)
        let cursorFar = CGPoint(x: 300, y: 300)

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            currentPosition: startPos,
            focusedWindowFrame: nil,
            cursorPosition: cursorFar
        )

        #expect(result == startPos)
    }

    @Test func repelsFromCursor() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        // Away from screen edges so clamping doesn't interfere
        let startPos = CGPoint(x: 1000, y: 500)
        let overlayCenter = CGPoint(
            x: startPos.x + overlaySize.width / 2,
            y: startPos.y + overlaySize.height / 2
        )
        let cursorClose = CGPoint(
            x: overlayCenter.x - 50,
            y: overlayCenter.y - 50
        )

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            currentPosition: startPos,
            focusedWindowFrame: nil,
            cursorPosition: cursorClose
        )

        let resultCenter = CGPoint(
            x: result.x + overlaySize.width / 2,
            y: result.y + overlaySize.height / 2
        )
        let distFromCursor = hypot(
            resultCenter.x - cursorClose.x,
            resultCenter.y - cursorClose.y
        )
        #expect(distFromCursor >= 240)
    }

    @Test func movesProportionallyAsCursorApproaches() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        let startPos = CGPoint(x: 1500, y: 700)
        let overlayCenter = CGPoint(
            x: startPos.x + overlaySize.width / 2,
            y: startPos.y + overlaySize.height / 2
        )
        let cursorNear = CGPoint(
            x: overlayCenter.x - 100,
            y: overlayCenter.y - 100
        )

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            currentPosition: startPos,
            focusedWindowFrame: nil,
            cursorPosition: cursorNear
        )

        let resultCenter = CGPoint(
            x: result.x + overlaySize.width / 2,
            y: result.y + overlaySize.height / 2
        )
        let distFromCursor = hypot(
            resultCenter.x - cursorNear.x,
            resultCenter.y - cursorNear.y
        )

        #expect(result != startPos)
        #expect(distFromCursor < 1000)
    }

    @Test func clampsToScreenBounds() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            currentPosition: nil,
            focusedWindowFrame: nil,
            cursorPosition: CGPoint(x: 0, y: 1000)
        )

        #expect(result.x >= screenBounds.minX)
        #expect(result.y >= screenBounds.minY)
        #expect(result.x + overlaySize.width <= screenBounds.maxX)
        #expect(result.y + overlaySize.height <= screenBounds.maxY)
    }

    @Test func prefersDifferentPositionWhenOverlappingFocusedWindow() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        let startPos = CGPoint(x: 800, y: 400)
        let cursorAway = CGPoint(x: 100, y: 100)

        let focusedWindowFrame = CGRect(x: 700, y: 300, width: 300, height: 200)

        let result = PositionerLogic.bestPosition(
            screenBounds: screenBounds,
            overlaySize: overlaySize,
            currentPosition: startPos,
            focusedWindowFrame: focusedWindowFrame,
            cursorPosition: cursorAway
        )

        let overlayRect = CGRect(origin: result, size: overlaySize)
        #expect(!overlayRect.intersects(focusedWindowFrame))
    }
}