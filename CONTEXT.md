# WAIWO

A macOS menu-bar app that surfaces the top unchecked TODO from an Obsidian daily note in an always-on-top floating overlay.

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