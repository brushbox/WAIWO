# WAIWO v1 Design Spec

## Overview

WAIWO (What Am I Working On) is a native macOS app that displays the user's current top TODO item from their Obsidian daily note in a floating, always-on-top overlay that stays out of the way of active work.

## Architecture

Four main components, data flowing one direction: NoteWatcher -> AppController -> OverlayWindow, with WindowPositioner independently driving the overlay's frame.

### 1. NoteWatcher

**Directory monitoring:**
- Watches `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Pete/Areas/Daily Notes/` using FSEvents
- On startup and on any file change event, scans for the right note

**Note selection logic:**
1. Look for today's date file (e.g., `2026-04-23.md`)
2. If not found, find the most recent `.md` file by date in the filename
3. Set an `isStale` flag when using a non-today note

**Filename parsing:**
- Expects `YYYY-MM-DD.md` format

**TODO extraction:**
- Read the file contents
- Find the first line matching `- [ ] ` (unchecked markdown checkbox)
- Strip the prefix, expose the text
- Re-parse on every file change event so completions are picked up immediately

**Edge cases:**
- No daily notes exist: show "No TODOs found" state
- All items checked: show "All done!" state
- File being synced via iCloud: debounce (200ms) to avoid partial reads

### 2. WindowPositioner

**Display selection:**
- On focused app change (`NSWorkspace.didActivateApplicationNotification`), get the focused app's main window screen via Accessibility APIs
- If multiple displays exist, prefer a display that does not contain the focused window
- If only one display, position on that display away from the focused window

**Positioning on a display:**
- Divide the display's visible frame (minus menu bar/dock) into candidate positions
- Score each position by distance from the focused window's frame
- Among top candidates, apply cursor repulsion

**Cursor repulsion:**
- Global mouse-moved event monitor updates cursor position
- A timer (~10-15Hz) checks distance between overlay and cursor
- If cursor is within a threshold (~150pt), apply a smooth push in the opposite direction
- Spring/decay animation for organic feel

**Constraints:**
- Overlay always stays fully on-screen (clamped to display bounds)
- Animate across displays rather than teleporting
- Repositioning pauses when the app is hidden

**Accessibility APIs caveat:**
- Reading other apps' window frames requires Accessibility permission
- Prompt on first launch; fall back to cursor-only avoidance if not granted

### 3. OverlayWindow

**Window type:**
- `NSPanel` with `.nonactivatingPanel`, `.floating`, `.fullSizeContentView`
- `canBecomeKey = false` (never steals focus)
- `isMovableByWindowBackground = false` (managed by WindowPositioner)
- Window level: `.floating`

**Visual design:**
- Solid rounded-rect card, ~300pt wide, height fits content
- Dark background with white text (adapts to light/dark mode)
- TODO text at ~16pt system font, medium weight
- When `isStale`: small label below text (e.g., "from Apr 22") in muted/warning color

**States:**
- Active TODO: task text + optional stale indicator
- All done: "All done!" message
- No notes found: "No daily notes found"

No buttons or interaction on the overlay itself.

### 4. AppController

**Menu bar:**
- `MenuBarExtra` with an icon
- Menu items:
  - Toggle show/hide
  - "Currently showing: [truncated TODO text]" (informational, disabled)
  - Separator
  - "Start at Login" toggle
  - Quit

**Global hotkey:**
- `Option-Cmd-T` to toggle visibility
- System-wide registration

**Focus mode integration:**
- Observe `NSDoNotDisturbEnabled` via `DistributedNotificationCenter`
- When any Focus mode is active, automatically hide the overlay
- When Focus mode ends, restore previous visibility state

**Launch at login:**
- `SMAppService` for login item registration

## Technology

- Swift / SwiftUI for UI, AppKit (NSPanel) for the floating window
- FSEvents for file watching
- Accessibility APIs for focused window detection
- Native macOS APIs throughout (no third-party dependencies)

## Out of Scope (v1)

- Fading list of upcoming TODOs
- Settings UI / preferences window
- Customizable note paths
- Multiple vault support
