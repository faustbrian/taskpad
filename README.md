# Taskpad

A native Mac task pad: one sheet, up to 30 tasks, and a clean start when
you decide what to carry into a new day. No projects, backlog or history UI.

## Build and run

Requires macOS 14 or later and Xcode 15 or later (Swift 5.9+).
The current build is for your Mac's architecture.

```sh
./scripts/build.sh
open build/Taskpad.app
```

The script builds a release executable, packages `build/Taskpad.app` and
ad-hoc signs it for local use. No developer account or server is required.
You can also open `Package.swift` in Xcode to work on the app.

```sh
./scripts/test.sh
```

Build and test scripts use disposable, task-owned build/module caches and
remove them on exit. The finished app stays in `build/` (not tracked by Git).

## Use

Choose **Karst** or **Notepad** using the small header menu. Both themes
use paper-like light palettes even when macOS uses dark appearance.
Your chosen theme and window geometry are remembered.

Add tasks with the plus row, **⌘N**, or **Return** when no task is selected.
Double-click a task to edit it, or
focus its row and press Return. The checkbox marks it complete without
moving it. Its action menu contains priorities, ink colors, movement and
deletion. Completed tasks count toward the 30-item limit.

Tasks and daily notes render inline **bold**, *italic*, ~~strikethrough~~,
`code`, and [links](https://www.apple.com). Editing shows the original
Markdown. Long text wraps; a long active editor can scroll.

| Action | Keyboard |
| --- | --- |
| Add task | ⌘N or Return when no task is selected |
| Finish editing | Return or Escape |
| Insert newline while editing | ⇧Return |
| Move between controls | Tab / ⇧Tab |
| Move between focused task rows | ↑ / ↓ |
| Edit focused task | Return or ⌘E |
| Complete / uncomplete focused task | Space or ⌘Return |
| Delete focused task | Delete or ⌘Delete |
| Reorder selected task | ⌘⌥↑ / ⌘⌥↓ |
| Edit daily notes | ⌘⇧N |
| Undo / redo | ⌘Z / ⌘⇧Z |

New blank task rows count toward capacity while editing. Finishing an empty
row removes it; an unfinished edit is saved and remains editable on reopening.

## Start a new day

On launch or activation on a later local calendar date, one short decision
asks for optional closing notes, the unfinished tasks worth carrying, and
whether to copy daily notes. Nothing is selected by default. Closing notes
always stay with the archived sheet.

**Start today** archives the old sheet and replaces it. **Not yet** preserves
the old sheet and the saved decision draft; **Continue** returns to it.
Normal sheet editing waits until the decision is complete. There is no
midnight timer, automatic carry-over, yesterday column or archive browser.
Skipping several days moves directly to today. Earlier clock dates never
replace a newer sheet.

## Local data

Normal launches save to:

```text
~/Library/Application Support/Taskpad/active.json
~/Library/Application Support/Taskpad/Archives/<date>-<sheet-id>.md
```

Archives contain a readable checklist, daily notes, closing notes and JSON
metadata preserving exact text, IDs, ordering, completion, priority and color.
Rollover writes the complete archive first, then atomically replaces the
active file. An interrupted attempt keeps the prior sheet and draft, and
retry uses the same archive filename rather than duplicating it.

Save failures are shown with a retry action and retain the unsaved candidate
in memory; quitting asks before discarding them. Unreadable data is not
replaced with an empty sheet. Back up the
data directory if you want to keep its contents elsewhere; there is no sync.

For isolated development smoke tests, `TASKPAD_DATA_DIR` selects a disposable
data directory. A separately packaged smoke app may set the equivalent
`TaskpadSmokeDataDirectory` Info.plist key. Ordinary app builds set neither.

## Themes

Native-app screenshots are in `docs/screenshots/`.

- Karst: narrow white pad, dark binding/header, gray ruling, circular checks.
- Notepad: a single ivory sheet, red margin, soft ruling, square checks and
  the system Noteworthy font (with a standard-font fallback).

No animations or commercial logos are used.
