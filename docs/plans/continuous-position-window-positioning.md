# Continuous Position Window Positioning

## Motivation

Remove the 4-corner discrete model. Overlay positions continuously — it sits still when cursor is far, pushes away proportionally when cursor approaches, and stays where it lands until forced to move.

---

## File: `WAIWO/Services/WindowPositioner.swift`

### Remove

- `Corner` enum
- `originForCorner(...)`
- `bestCorner(...)`
- `scoreCorner(...)`

### Replace with `PositionerLogic`

**New constants:**
```swift
static let cursorAvoidanceRadius: CGFloat = 200
static let minEdgeInsetFraction: CGFloat = 0.04
static let lazyThreshold: CGFloat = 20
```

**`defaultOrigin(screenBounds:overlaySize:) -> CGPoint`**
Returns top-right corner with edge insets. Only used when no prior position exists.

**`bestPosition(screenBounds:overlaySize:currentPosition:focusedWindowFrame:cursorPosition:) -> CGPoint`**

Algorithm:

1. **Start** from `currentPosition ?? defaultOrigin(...)`
2. **Cursor repulsion:** compute overlay center, cursor distance. If `< cursorAvoidanceRadius`, compute push direction (normalized vector away from cursor) × magnitude `(avoidanceRadius - dist) * 0.5`. Apply as offset to origin.
3. **Focus window separation:** if overlay rect intersects focused window rect, compute overlap push (away from focused window center by overlap amount + 20px).
4. **Clamp:** keep overlay fully inside `screenBounds` with 4% edge padding.
5. **Lazy gate:** if net movement from input `currentPosition` < `lazyThreshold`, return `currentPosition` unchanged.

### `WindowPositioner` changes

**Drop:** `currentCorner`, `currentScreenNumber`

**Add:** `var currentPosition: CGPoint?`

**`reposition()` updated:**
- Determine target screen (prefer display user isn't on — same logic, unchanged)
- If target screen changed → reset `currentPosition = nil` so it re-defaults to top-right on the new screen
- Pass `currentPosition` to `bestPosition`
- If result differs from `currentPosition` → fade-move (same animation as today)
- Update `currentPosition`
- Remove corner/screen-number comparison guard (replaced by lazy threshold inside `bestPosition`)

**`reposition()` guard condition changes:**
```
if result == currentPosition { return }  // lazy gate in PositionerLogic already handles small moves
```

---

## File: `WAIWOTests/PositionerLogicTests.swift`

### Replace tests

| Test | What it verifies |
|------|-----------------|
| `staysWhenCursorIsFar` | Cursor 300px from overlay center, no focused window → result == starting position |
| `repelsFromCursor` | Cursor 50px from overlay center → overlay center moves to ≥ 190px from cursor |
| `movesProportionallyAsCursorApproaches` | Cursor 100px from overlay center → overlay moves but not maximally (distance in proportional range, not maximum possible) |
| `clampsToScreenBounds` | Overlay pushed past edge → gets clamped inside bounds |
| `prefersDifferentPositionWhenOverlappingFocusedWindow` | Overlay overlapping focused window → result shifts away |

---

## Files with no changes

- `AccessibilityHelper.swift`
- `OverlayPanelController.swift`
- `OverlayPanel.swift`
- `NoteWatcher.swift`, `NoteFinder.swift`, `NoteParser.swift`, `NoteWriter.swift`, `JournalWriter.swift`
- `HotkeyConfig.swift`, `PathConfig.swift`
- `SettingsView.swift`, `WAIWOApp.swift`

---

## Edge cases handled

- **No prior position** → defaults to top-right of target screen
- **Single screen** → stays on that screen, repels from cursor normally
- **Multi screen** → picks a screen the user isn't on (same as today), positions there
- **Screen change** → resets position to default for new screen
- **Cursor outside avoidance radius** → zero cursor impact, overlay stays put
- **Tiny movements (< 20px)** → filtered out by lazy gate, no animation
- **Cursor at equal distance from multiple positions** → stays at current position (stay bonus is implicit via lazy gate + starting from currentPosition)
