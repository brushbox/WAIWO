import Testing
import Foundation
@testable import WAIWO

// MARK: - Positioning math (migrated from PositionerLogicTests)

struct OverlayPositionMathTests {
    @Test func staysWhenCursorIsFar() {
        let screenBounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let overlaySize = CGSize(width: 300, height: 60)
        let startPos = CGPoint(x: 1500, y: 700)
        let cursorFar = CGPoint(x: 300, y: 300)

        let result = OverlayLayoutComputer.bestPosition(
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
        let startPos = CGPoint(x: 1000, y: 500)
        let overlayCenter = CGPoint(
            x: startPos.x + overlaySize.width / 2,
            y: startPos.y + overlaySize.height / 2
        )
        let cursorClose = CGPoint(
            x: overlayCenter.x - 50,
            y: overlayCenter.y - 50
        )

        let result = OverlayLayoutComputer.bestPosition(
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

        let result = OverlayLayoutComputer.bestPosition(
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

        let result = OverlayLayoutComputer.bestPosition(
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

        let result = OverlayLayoutComputer.bestPosition(
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

// MARK: - Reducer

struct OverlayLayoutReducerTests {
    let screen = ScreenInfo(id: 1, visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
    var screens: [ScreenInfo] { [screen] }

    func positionedState(
        at position: CGPoint = CGPoint(x: 1000, y: 500),
        cursor: CGPoint = CGPoint(x: 100, y: 100)
    ) -> LayoutState {
        var state = LayoutState()
        state.currentPosition = position
        state.currentScreenID = 1
        state.cursorPosition = cursor
        return state
    }

    // MARK: tick / positioning

    @Test func firstTickPlacesAtDefaultOriginInstantly() {
        var state = LayoutState()
        state.cursorPosition = CGPoint(x: 100, y: 100)

        let layout = OverlayLayoutComputer.reduce(&state, event: .tick, screens: screens)

        #expect(layout != nil)
        #expect(layout?.animation == OverlayLayout.AnimationHint.none)
        #expect(state.currentPosition == layout?.frame.origin)
        #expect(state.currentScreenID == 1)
    }

    @Test func tickWithNoMovementEmitsNothing() {
        var state = positionedState()
        _ = OverlayLayoutComputer.reduce(&state, event: .tick, screens: screens)
        let second = OverlayLayoutComputer.reduce(&state, event: .tick, screens: screens)
        #expect(second == nil)
    }

    @Test func lazyGateSuppressesSmallMoves() {
        var state = positionedState(at: CGPoint(x: 1500, y: 700), cursor: CGPoint(x: 300, y: 300))
        let layout = OverlayLayoutComputer.reduce(&state, event: .tick, screens: screens)
        #expect(layout == nil)
        #expect(state.currentPosition == CGPoint(x: 1500, y: 700))
    }

    @Test func focusedWindowChangeRepositionsAwayFromWindow() {
        var state = positionedState(at: CGPoint(x: 800, y: 400))
        let windowFrame = CGRect(x: 700, y: 300, width: 300, height: 200)

        let layout = OverlayLayoutComputer.reduce(
            &state, event: .focusedWindowChanged(windowFrame), screens: screens
        )

        #expect(state.focusedWindowFrame == windowFrame)
        #expect(layout != nil)
        #expect(!layout!.frame.intersects(windowFrame))
    }

    // MARK: cursor proximity

    @Test func cursorFarGivesFullOpacity() {
        var state = positionedState(at: CGPoint(x: 1500, y: 900))

        let layout = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 100, y: 100)), screens: screens
        )

        #expect(layout?.opacity == 1.0)
        #expect(layout?.animation == .fade)
    }

    @Test func cursorNearDimsProportionally() {
        var state = positionedState(at: CGPoint(x: 1000, y: 500))

        let layout = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 1000, y: 1000)), screens: screens
        )

        let opacity = layout!.opacity
        #expect(opacity > OverlayLayoutComputer.minProximityOpacity)
        #expect(opacity < 1.0)
    }

    @Test func cursorInsideOverlayHidesIt() {
        var state = positionedState(at: CGPoint(x: 1000, y: 500))

        let layout = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 1050, y: 520)), screens: screens
        )

        #expect(state.isMouseOverWindow)
        #expect(layout?.opacity == 0)
    }

    @Test func cursorLeavingOverlayRestoresGradedOpacity() {
        var state = positionedState(at: CGPoint(x: 1000, y: 500))
        _ = OverlayLayoutComputer.reduce(&state, event: .cursorMoved(CGPoint(x: 1050, y: 520)), screens: screens)

        let layout = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 100, y: 100)), screens: screens
        )

        #expect(!state.isMouseOverWindow)
        #expect(layout!.opacity > 0)
    }

    @Test func cursorMoveBeforeFirstPositionEmitsNothing() {
        var state = LayoutState()
        let layout = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 500, y: 500)), screens: screens
        )
        #expect(layout == nil)
        #expect(state.cursorPosition == CGPoint(x: 500, y: 500))
    }

    // MARK: input mode

    @Test func enterInputCentresOnScreenAtFullOpacity() {
        var state = positionedState()
        state.opacity = 0.4

        let layout = OverlayLayoutComputer.reduce(&state, event: .enterInput(.journal), screens: screens)

        #expect(state.isInputMode)
        #expect(layout?.opacity == 1.0)
        #expect(layout?.animation == .move)
        #expect(layout?.frame.midX == screen.visibleFrame.midX)
        #expect(layout?.frame.height == 160)
        #expect(state.preInput?.opacity == 0.4)
    }

    @Test func todoInputIsShorterThanJournal() {
        var state = positionedState()
        let layout = OverlayLayoutComputer.reduce(&state, event: .enterInput(.todo), screens: screens)
        #expect(layout?.frame.height == 80)
    }

    @Test func exitInputRestoresPreInputFrameAndOpacity() {
        var state = positionedState(at: CGPoint(x: 1200, y: 600))
        state.opacity = 0.7
        _ = OverlayLayoutComputer.reduce(&state, event: .enterInput(.todo), screens: screens)

        let layout = OverlayLayoutComputer.reduce(&state, event: .exitInput, screens: screens)

        #expect(!state.isInputMode)
        #expect(layout?.frame.origin == CGPoint(x: 1200, y: 600))
        #expect(layout?.frame.size == OverlayLayoutComputer.displaySize)
        #expect(layout?.opacity == 0.7)
        #expect(state.currentPosition == CGPoint(x: 1200, y: 600))
    }

    @Test func exitInputWithoutPreInputFallsBackToInputFrameTopEdge() {
        // Documents quirk (a): input entered before any positioning restores to a
        // frame derived from the input frame at full opacity.
        var state = LayoutState()
        state.currentScreenID = 1
        let enter = OverlayLayoutComputer.reduce(&state, event: .enterInput(.journal), screens: screens)
        #expect(state.preInput == nil)

        let layout = OverlayLayoutComputer.reduce(&state, event: .exitInput, screens: screens)

        #expect(layout?.opacity == 1.0)
        #expect(layout?.frame.height == OverlayLayoutComputer.displaySize.height)
        #expect(layout?.frame.maxY == enter?.frame.maxY)
    }

    @Test func cursorAndTickAreSuppressedDuringInput() {
        var state = positionedState()
        _ = OverlayLayoutComputer.reduce(&state, event: .enterInput(.todo), screens: screens)

        let cursor = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 900, y: 900)), screens: screens
        )
        let tick = OverlayLayoutComputer.reduce(&state, event: .tick, screens: screens)

        #expect(cursor == nil)
        #expect(tick == nil)
    }

    @Test func duplicateEnterInputIsIgnored() {
        var state = positionedState()
        _ = OverlayLayoutComputer.reduce(&state, event: .enterInput(.todo), screens: screens)
        let second = OverlayLayoutComputer.reduce(&state, event: .enterInput(.todo), screens: screens)
        #expect(second == nil)
    }

    @Test func exitInputWithoutInputModeIsIgnored() {
        var state = positionedState()
        let layout = OverlayLayoutComputer.reduce(&state, event: .exitInput, screens: screens)
        #expect(layout == nil)
    }

    // MARK: animation queueing (fixes quirks b and c)

    @Test func displayLayoutsQueueDuringAnimationLatestWins() {
        var state = positionedState(at: CGPoint(x: 1500, y: 900))
        _ = OverlayLayoutComputer.reduce(&state, event: .animationStarted, screens: screens)

        let first = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 1400, y: 850)), screens: screens
        )
        let second = OverlayLayoutComputer.reduce(
            &state, event: .cursorMoved(CGPoint(x: 100, y: 100)), screens: screens
        )
        #expect(first == nil)
        #expect(second == nil)

        let flushed = OverlayLayoutComputer.reduce(&state, event: .animationCompleted, screens: screens)
        #expect(flushed != nil)
        #expect(flushed?.opacity == 1.0)
    }

    @Test func completionWithNothingPendingEmitsNothing() {
        var state = positionedState()
        _ = OverlayLayoutComputer.reduce(&state, event: .animationStarted, screens: screens)
        let flushed = OverlayLayoutComputer.reduce(&state, event: .animationCompleted, screens: screens)
        #expect(flushed == nil)
        #expect(!state.isAnimating)
    }

    @Test func enterInputBypassesQueueAndClearsPending() {
        var state = positionedState(at: CGPoint(x: 1500, y: 900))
        _ = OverlayLayoutComputer.reduce(&state, event: .animationStarted, screens: screens)
        _ = OverlayLayoutComputer.reduce(&state, event: .cursorMoved(CGPoint(x: 100, y: 100)), screens: screens)
        #expect(state.pending != nil)

        let layout = OverlayLayoutComputer.reduce(&state, event: .enterInput(.todo), screens: screens)

        #expect(layout != nil)
        #expect(state.pending == nil)
    }

    // MARK: screens

    @Test func cycleScreenMovesToNextAndResetsPosition() {
        let two = [
            ScreenInfo(id: 1, visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)),
            ScreenInfo(id: 2, visibleFrame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)),
        ]
        var state = positionedState()

        let layout = OverlayLayoutComputer.reduce(&state, event: .cycleScreen, screens: two)

        #expect(state.currentScreenID == 2)
        #expect(layout != nil)
        #expect(two[1].visibleFrame.contains(layout!.frame))
    }

    @Test func cycleScreenWithSingleScreenIsIgnored() {
        var state = positionedState()
        let layout = OverlayLayoutComputer.reduce(&state, event: .cycleScreen, screens: screens)
        #expect(layout == nil)
        #expect(state.currentScreenID == 1)
    }

    @Test func missingScreenFallsBackToFirst() {
        var state = positionedState()
        state.currentScreenID = 99
        state.currentPosition = nil

        let layout = OverlayLayoutComputer.reduce(&state, event: .tick, screens: screens)

        #expect(layout != nil)
        #expect(state.currentScreenID == 1)
    }

    @Test func noScreensEmitsNothing() {
        var state = positionedState()
        let layout = OverlayLayoutComputer.reduce(&state, event: .tick, screens: [])
        #expect(layout == nil)
    }
}
