# WAIWO

A macOS menu-bar app that surfaces the top unchecked TODO from an Obsidian daily note in an always-on-top floating overlay.

## Features

- **Overlay** — floating window shows top unchecked TODO from latest daily note. Auto-updates on file change. Stale-date badge when note isn't today's.
- **Toggle overlay** — ⌥⌘T
- **Add TODO** — ⌥⌘N. Prepends `- [ ] text` to latest daily note.
- **Add Journal Entry** — ⌥⌘⇧J. Appends timestamped entry to today's journal file. Creates file if missing.
- **Mark Top TODO as Done** — ⌥⌘D. Rewrites first `- [ ]` to `- [x]` in latest daily note. Silent no-op if nothing to check.
- **Start at Login** — toggle in menu bar.
- **Focus Mode** — overlay auto-hides during system Focus sessions, restores on exit.

All writes go directly to disk. `NoteWatcher` picks up filesystem changes automatically.

## Language

**Daily Note**:
A dated markdown file (`yyyy-MM-dd.md`) in an Obsidian vault's daily notes directory. WAIWO reads from and writes to these files directly on disk — no Obsidian integration via URL schemes.
_Avoid_: Journal entry (use "journal entry" only for the specific content type, not the file)

**Latest Daily Note**:
The most recent daily note that exists on disk (today's or a past day). The TODO hotkeys target this note, not necessarily today's. If no daily notes exist at all, the TODO operation is an error.
_Avoid_: Today's note (when context is about the write target, not the display target)

**Daily Journal**:
A separate folder outside the daily notes directory containing dated markdown journal entries (`yyyy-MM-dd.md`), distinct from daily note TODO tracking. Written by the journal entry hotkey. May later be reconciled with daily notes content.

_Flags_: Not yet wired into settings/preferences. Path will be a hardcoded constant initially, same pattern as `dailyNotesPath`.

**Write Target**:
All writes go directly to the markdown file on disk, not via Obsidian's URL scheme. The app already reads this way, and `NoteWatcher` picks up filesystem changes automatically.

**Settings**:
A standard macOS preferences window (Cmd+,) exposed via SwiftUI's `Settings` scene. Hotkeys are configurable through click-to-record capture cells with conflict validation. Stored in `UserDefaults` via `@AppStorage`-like per-value scalars.

**Overlay Layout**:
The single source of truth for what the overlay panel should look like: frame + opacity + animation hint. Computed by the pure reducer `OverlayLayoutComputer` from events (cursor moves, ticks, input mode enter/exit, screen cycling); `OverlayController` feeds it AppKit events and `OverlayPanelController` applies the result to the NSPanel. Layout decisions never live in the adapters.
_Avoid_: "window position"/"panel opacity" as separate concerns — they are one layout.

**Hotkey Action**:
One of four named actions (Toggle Overlay, Add TODO, Add Journal Entry, Mark Top TODO as Done). Each has a default key code and modifier mask stored in `HotkeyConfig`.
_Avoid_: Hardcoded key constants; always read from `HotkeyConfig`.