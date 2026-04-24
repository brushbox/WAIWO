# What Am I Working On (WAIWO)

## Rationale

Work is full of interruptions. New requests come in all the time.
I lose track unless I keep them in some sort of todo list.
Even then the pace can be overwhelming and I ask myself "what am I working on".
Go an find the todo list - or vaguely recall what was the most important.

My focus is shattered and I flit from task to task, sometimes accomplishing very little.

Tracking my todo in Obsidian daily notes is useful, but not quite enough.

I still end up asking myself "What am I working on?"

This app helps quickly answer that question.

### Features

- always on top display of the top 3 incomplete todo list items
- mouse avoiding behaviour - tries to stay visible, but get out of the way of your work.
- hotkey to toggle visibility, for those times you don't want it visile (screen sharing, etc).
- hides when in "Reduce Interruptions" Focus state.
- reads todo from the latest Obsidian daily note
- tracks changes and updates display
- taskbar icon and menu items
- can start at login
- recognises links and renders menu items that you can click on

## TODO

- add preferences
  - choose hotkey
  - select path to daily notes folder

## How I have Obsidian set up

- daily notes in <Vault>/Areas/Daily Notes/yyyy-mm-dd.md
- I use trhe [Rollover Daily Todos](https://github.com/lumoe/obsidian-rollover-daily-todos) plugin
  - this keeps cleaning up my todos from daily notes: moving incomplete tasks to the next day's note, leaving completed ones behind
  - it's a great tool for being able to look back on what you have actually done over the last <n> days, weeks, months.

## How do I use this?

Right now you will need to build your own executable using XCode.
- edit the [code](WAIWO/WAIWOApp.swift) to refer to the location of your Obsidian Daily Notes.
- ensure your Daily Notes filenames match the format (yyyy-mm-dd.md)
  - or update the logic to find your notes
- You may need to copy the executable into your Applications folder for full functionality.
