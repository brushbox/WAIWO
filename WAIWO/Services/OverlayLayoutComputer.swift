import Foundation

/// The single output of the layout reducer: what the overlay panel should look like.
struct OverlayLayout: Equatable {
    enum AnimationHint: Equatable {
        /// Apply instantly (repositioning moves, first placement).
        case none
        /// Animated frame change (input mode enter/exit).
        case move
        /// Animated opacity change (proximity dimming).
        case fade
    }

    var frame: CGRect
    var opacity: CGFloat
    var animation: AnimationHint
}

/// A display the overlay can live on.
struct ScreenInfo: Equatable {
    var id: UInt32?
    var visibleFrame: CGRect
}

/// Everything the reducer accumulates between events.
struct LayoutState: Equatable {
    struct PreInputSnapshot: Equatable {
        var frame: CGRect
        var opacity: CGFloat
    }

    var cursorPosition: CGPoint = .zero
    var focusedWindowFrame: CGRect?
    var currentPosition: CGPoint?
    var currentScreenID: UInt32?
    var isMouseOverWindow = false
    var opacity: CGFloat = 1.0
    var isInputMode = false
    var preInput: PreInputSnapshot?
    var inputFrame: CGRect?
    var isAnimating = false
    var pending: OverlayLayout?
}

enum LayoutEvent: Equatable {
    case cursorMoved(CGPoint)
    case focusedWindowChanged(CGRect?)
    case tick
    case cycleScreen
    case enterInput(OverlayLayoutComputer.InputKind)
    case exitInput
    case animationStarted
    case animationCompleted
}

/// Pure reducer owning overlay frame + opacity across display and input modes.
/// Adapters feed it events and apply the returned `OverlayLayout` to the panel;
/// no AppKit crosses this seam.
enum OverlayLayoutComputer {
    enum InputKind: Equatable {
        case todo
        case journal

        var inputHeight: CGFloat { self == .todo ? 80 : 160 }
    }

    static let displaySize = CGSize(width: 400, height: 60)
    static let inputWidth: CGFloat = 400
    static let minProximityOpacity: CGFloat = 0.05

    static let cursorAvoidanceRadius: CGFloat = 1000
    static let cursorRepulsionExponent: CGFloat = 0.5
    static let cursorRepulsionScaling: CGFloat = 106_000
    static let maxPushStrength: CGFloat = 1000
    static let minEdgeInsetFraction: CGFloat = 0.04
    static let lazyThreshold: CGFloat = 100

    // MARK: - Reducer

    static func reduce(
        _ state: inout LayoutState,
        event: LayoutEvent,
        screens: [ScreenInfo]
    ) -> OverlayLayout? {
        switch event {
        case .animationStarted:
            state.isAnimating = true
            return nil

        case .animationCompleted:
            state.isAnimating = false
            let flushed = state.pending
            state.pending = nil
            return flushed

        case .cursorMoved(let point):
            state.cursorPosition = point
            guard !state.isInputMode, let position = state.currentPosition else { return nil }
            let frame = CGRect(origin: position, size: displaySize)
            state.isMouseOverWindow = frame.contains(point)
            let opacity = proximityOpacity(for: state, frame: frame)
            state.opacity = opacity
            return deliver(OverlayLayout(frame: frame, opacity: opacity, animation: .fade), &state)

        case .focusedWindowChanged(let frame):
            state.focusedWindowFrame = frame
            return repositionOutput(&state, screens: screens)

        case .tick:
            return repositionOutput(&state, screens: screens)

        case .cycleScreen:
            guard screens.count > 1 else { return nil }
            let currentIdx = screens.firstIndex(where: { $0.id == state.currentScreenID }) ?? 0
            let next = screens[(currentIdx + 1) % screens.count]
            state.currentScreenID = next.id
            state.currentPosition = nil
            return repositionOutput(&state, screens: screens)

        case .enterInput(let kind):
            guard !state.isInputMode, let screen = targetScreen(&state, screens: screens) else { return nil }
            state.isInputMode = true
            state.pending = nil
            if let position = state.currentPosition {
                state.preInput = LayoutState.PreInputSnapshot(
                    frame: CGRect(origin: position, size: displaySize),
                    opacity: state.opacity
                )
            } else {
                state.preInput = nil
            }
            let height = kind.inputHeight
            let visible = screen.visibleFrame
            let centred = CGRect(
                x: visible.midX - inputWidth / 2,
                y: visible.midY - height / 2,
                width: inputWidth,
                height: height
            )
            state.inputFrame = centred
            return OverlayLayout(frame: centred, opacity: 1.0, animation: .move)

        case .exitInput:
            guard state.isInputMode else { return nil }
            state.isInputMode = false
            state.pending = nil
            let restored: OverlayLayout
            if let pre = state.preInput {
                let frame = CGRect(
                    x: pre.frame.origin.x,
                    y: pre.frame.origin.y + (pre.frame.height - displaySize.height),
                    width: pre.frame.width,
                    height: displaySize.height
                )
                restored = OverlayLayout(frame: frame, opacity: pre.opacity, animation: .move)
            } else {
                // Fallback when input was entered before any positioning happened:
                // anchor to the input frame's top edge at full opacity.
                let base = state.inputFrame ?? CGRect(origin: .zero, size: displaySize)
                let frame = CGRect(
                    x: base.origin.x,
                    y: base.origin.y + (base.height - displaySize.height),
                    width: inputWidth,
                    height: displaySize.height
                )
                restored = OverlayLayout(frame: frame, opacity: 1.0, animation: .move)
            }
            state.preInput = nil
            state.inputFrame = nil
            state.currentPosition = restored.frame.origin
            state.opacity = restored.opacity
            return restored
        }
    }

    // MARK: - Positioning math

    static func defaultOrigin(screenBounds: CGRect, overlaySize: CGSize) -> CGPoint {
        let padX = screenBounds.width * minEdgeInsetFraction
        let padY = screenBounds.height * minEdgeInsetFraction
        return CGPoint(
            x: screenBounds.maxX - overlaySize.width - padX,
            y: screenBounds.maxY - overlaySize.height - padY
        )
    }

    static func bestPosition(
        screenBounds: CGRect,
        overlaySize: CGSize,
        currentPosition: CGPoint?,
        focusedWindowFrame: CGRect?,
        cursorPosition: CGPoint
    ) -> CGPoint {
        var origin = currentPosition ?? defaultOrigin(screenBounds: screenBounds, overlaySize: overlaySize)

        let overlayCenter = CGPoint(
            x: origin.x + overlaySize.width / 2,
            y: origin.y + overlaySize.height / 2
        )

        // Cursor repulsion
        let cursorDist = hypot(
            overlayCenter.x - cursorPosition.x,
            overlayCenter.y - cursorPosition.y
        )
        if cursorDist < cursorAvoidanceRadius {
            let raw = cursorRepulsionScaling / pow(cursorDist, cursorRepulsionExponent)
            let pushStrength = min(raw, maxPushStrength)
            let dx = overlayCenter.x - cursorPosition.x
            let dy = overlayCenter.y - cursorPosition.y
            let dist = max(cursorDist, 1)
            let nx = dx / dist
            let ny = dy / dist
            origin.x += nx * pushStrength
            origin.y += ny * pushStrength
        }

        // Focus window separation
        if let fwf = focusedWindowFrame {
            let overlayRect = CGRect(origin: origin, size: overlaySize)
            if overlayRect.intersects(fwf) {
                let fwCenter = CGPoint(x: fwf.midX, y: fwf.midY)
                let ox = origin.x + overlaySize.width / 2
                let oy = origin.y + overlaySize.height / 2
                let dx = ox - fwCenter.x
                let dy = oy - fwCenter.y
                let dist = max(hypot(dx, dy), 1)
                let nx = dx / dist
                let ny = dy / dist
                let overlapX: CGFloat
                let overlapY: CGFloat
                if dx > 0 {
                    overlapX = overlayRect.maxX - fwf.minX
                } else {
                    overlapX = fwf.maxX - overlayRect.minX
                }
                if dy > 0 {
                    overlapY = overlayRect.maxY - fwf.minY
                } else {
                    overlapY = fwf.maxY - overlayRect.minY
                }
                let pushAmount = max(overlapX, overlapY) + 20
                origin.x += nx * pushAmount
                origin.y += ny * pushAmount
            }
        }

        // Clamp to screen bounds
        let padX = screenBounds.width * minEdgeInsetFraction
        let padY = screenBounds.height * minEdgeInsetFraction
        origin.x = min(max(origin.x, screenBounds.minX + padX), screenBounds.maxX - overlaySize.width - padX)
        origin.y = min(max(origin.y, screenBounds.minY + padY), screenBounds.maxY - overlaySize.height - padY)

        // Lazy gate
        if let current = currentPosition {
            let movement = hypot(origin.x - current.x, origin.y - current.y)
            if movement < lazyThreshold {
                return current
            }
        }

        return origin
    }

    // MARK: - Private helpers

    /// Queue any display-mode layout while an animation is in flight; latest wins.
    /// Input transitions bypass the queue (handled in their own cases).
    private static func deliver(_ layout: OverlayLayout, _ state: inout LayoutState) -> OverlayLayout? {
        if state.isAnimating {
            state.pending = layout
            return nil
        }
        return layout
    }

    private static func repositionOutput(_ state: inout LayoutState, screens: [ScreenInfo]) -> OverlayLayout? {
        guard !state.isInputMode, let screen = targetScreen(&state, screens: screens) else { return nil }

        let origin = bestPosition(
            screenBounds: screen.visibleFrame,
            overlaySize: displaySize,
            currentPosition: state.currentPosition,
            focusedWindowFrame: state.focusedWindowFrame,
            cursorPosition: state.cursorPosition
        )

        if origin == state.currentPosition { return nil }

        state.currentPosition = origin
        let frame = CGRect(origin: origin, size: displaySize)
        state.isMouseOverWindow = frame.contains(state.cursorPosition)
        let opacity = proximityOpacity(for: state, frame: frame)
        state.opacity = opacity
        return deliver(OverlayLayout(frame: frame, opacity: opacity, animation: .none), &state)
    }

    private static func targetScreen(_ state: inout LayoutState, screens: [ScreenInfo]) -> ScreenInfo? {
        guard !screens.isEmpty else { return nil }
        if let current = state.currentScreenID, let screen = screens.first(where: { $0.id == current }) {
            return screen
        }
        let first = screens[0]
        state.currentScreenID = first.id
        return first
    }

    private static func proximityOpacity(for state: LayoutState, frame: CGRect) -> CGFloat {
        if state.isMouseOverWindow { return 0 }
        let distance = distanceToRect(state.cursorPosition, frame)
        if distance <= 0 { return minProximityOpacity }
        if distance >= cursorAvoidanceRadius { return 1.0 }
        let t = distance / cursorAvoidanceRadius
        return minProximityOpacity + (1.0 - minProximityOpacity) * t
    }

    private static func distanceToRect(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
        let closestX = max(rect.minX, min(point.x, rect.maxX))
        let closestY = max(rect.minY, min(point.y, rect.maxY))
        return hypot(point.x - closestX, point.y - closestY)
    }
}
