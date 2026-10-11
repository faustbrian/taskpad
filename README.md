# TaskPad

A native Mac task pad with one fixed sheet. Pick your slot count, fill those
slots, and decide what deserves another day. No projects, backlog, accounts,
calendar or history browser.

## Build and run

Requires macOS 14+ and Xcode 15+ (Swift 5.9+). Builds for this Mac's architecture.

```sh
./scripts/build.sh
open build/TaskPad.app
./scripts/test.sh
```

The release app is ad-hoc signed for local use; no developer account or server
is needed. Open `Package.swift` in Xcode to develop. Build/test scripts remove
their disposable build and module caches; the final app stays in `build/`.

## A fixed sheet

Settings (**⌘,**) sets 1–100 slots, default 30. Every slot is present, including
empty ones. There is no Add task button, overflow list or automatic second
sheet. Clearing a task leaves its slot. Completed tasks stay in place.
Lowering the limit removes blank slots only and rejects a change that would
lose filled items. Raising it appends blanks.

Click a row to focus it, then type to edit at the end of its existing text;
Return also opens the editor. Double-click defaults to editing, or can be
configured to toggle completion instead. Reserved row shortcuts still
take precedence until editing starts. A resting row stays
one ruled line with an ellipsis for longer content. Focus expands it to whole
ruled lines, at most five, anchored to the same top inset. New input is bounded
at five visual lines and 500 Unicode characters, including pasted text.
Changing font/window width never silently truncates saved content; a focused
editor can scroll text that no longer fits. Daily notes are separate and are
hidden by default. Hiding them does not erase their text.

Inline Markdown supports **bold**, *italic*, ~~strikethrough~~, `code` and links.
Editing shows source; resting rows render it. Open a rendered link by clicking
it. Priority and effort are independently optional, both off by default. Enable
them in Appearance to reveal their badges, flat menu choices and repeating-rule
controls. Turning them off preserves saved values and gives the text its space
back. Right-click a row for ink and any enabled metadata choices. Priority
0 means none; 9 is highest. Display priorities as numbers or repeated `!` marks
without changing their levels. No action icons occupy the rows.

| Action | Keyboard |
| --- | --- |
| Focus next / previous slot, wrapping | Tab / ⇧Tab or ↓ / ↑ |
| Start editing at the end of the focused slot | Type text (digits too when priority is off) |
| Edit focused slot / finish editing | Return |
| Finish editing | Escape |
| Insert newline | ⇧Return |
| Move directly to another editor, wrapping | Tab / ⇧Tab while editing |
| Toggle done / pending; advance only when becoming done, without wrapping | Space |
| Toggle done / pending without moving | ← |
| Open focused row's context menu | → |
| Set focused row priority (when enabled) | 0–9 |
| Clear focused slot | Delete or ⌘Delete |
| Reorder selected slot | Drag and drop, or ⌘⌥↑ / ⌘⌥↓ |
| Undo / redo | ⌘Z / ⌘⇧Z |
| Edit enabled daily notes | ⌘⇧N |
| Settings | ⌘, |

Digits, spaces and arrows retain ordinary text-editing behavior in an editor.
Task and note editing use native copy/paste and undo/redo. Reordering moves
identity, content, completion, priority, effort, ink and repeating-task metadata
together; it does not sort by priority or completion.

## Settings and paper

Settings opens in its own resizable window with a System Settings-style sidebar
and grouped panes. Choose System (default), Light or Dark for the whole app,
including Settings and the new-day sheet. System follows macOS automatically.
Changes remain a draft across categories until Save; Cancel or closing the
window discards that draft. Reopening starts from the current saved settings.
You can still use the pad while Settings is open; its task shortcuts do not
intercept text entry in Settings. Settings and theme save as one recoverable
change, with Retry Save available in the window after a failed save. Submitted
unsaved changes are retained for recovery, not discarded by closing Settings.

Karst is the default. The other themes are Anoto, Things, Todoist, TickTick,
Linear and Raycast. Each has a coordinated light and dark palette:
aesthetic alternatives with identical functions, no commercial logos and no
animations. Karst uses solid black completed circles; Anoto uses blue checked
squares, ivory paper and a red margin with a clear text gutter.

Choose any installed font family and 10–32 point size; the default is Apple's
system San Francisco font. Missing fonts fall back safely to the system font.
Schedule and priority text scale with the chosen size. Completed tasks retain
their ink contrast, and Increase Contrast strengthens checkboxes and selection.

Header and footer have independently configurable visibility, brand, heading,
date and count. Branding is off by default; footer and notes are hidden.
Hide both sections for a list-only window. Settings remains reachable through
the app menu and **⌘,** when editing today's sheet. Resolve a waiting new-day
decision before changing settings. The window title is editable too.

Empty date format uses the system locale. Custom dates use Foundation patterns
such as `EEE, d MMM` or `yyyy/MM/dd`. Text and count formats support `{date}`,
`{used}`, `{limit}`, `{completed}`, `{remaining}`; unknown tokens stay literal.
For example `{used} out of {limit} slots taken`. Filled completed rows count
as used; blank/whitespace slots do not. Theme and window geometry persist.

## Optional effort

Effort is disabled by default and never creates extra slots or a separate workflow.
Enable it and choose its scale in Appearance; assign or clear it from the row
context menu. Disabling it hides all effort controls and badges without erasing
estimates from tasks or repeating rules.
Fibonacci is the default, with five values; extended scales add two more.

| Scale | Values | Extended values |
| --- | --- | --- |
| Exponential | 1, 2, 4, 8, 16 | 32, 64 |
| Fibonacci | 1, 2, 3, 5, 8 | 13, 21 |
| Linear | 1, 2, 3, 4, 5 | 6, 7 |
| T-Shirt | XS, S, M, L, XL | XXL, XXXL |

Changing scale preserves relative size: M becomes Fibonacci 3 or Exponential 4.
Turning extension off restricts new assignments, not existing large estimates;
their current value remains visible and clearable. Effort moves, undoes,
archives and carries with its task. Repeating rules can specify an effort
that each fresh daily occurrence inherits. T-Shirt numerical equivalents
follow Fibonacci.

## A new day

Launch/activation/wake on a later local date detects one transition, never a
midnight timer. Skipped days go directly to today; backward dates do not
replace a newer sheet. Carry-over defaults to **Ask**:

- **Ask:** choose unfinished manual tasks, optional enabled daily notes, and
  closing reflection; nothing selected by default. Cancel retains the draft.
- **Auto:** carry unfinished nonblank manual tasks and daily notes if enabled.
- **Never:** carry no previous task or note; start with fresh slots.

The previous complete sheet is archived before replacement. Closing reflection
belongs only to the archive. Scheduled occurrences are not carried: their
rules create today's occurrences. If Auto plus scheduled tasks would overflow,
the previous sheet and all decisions remain safe and a selection asks what
fits. Completed and blank manual entries never carry.

## Repeating tasks

Create weekday/time rules in Settings. For example, Monday–Friday at 07:30:
“Merge develop into main”. Each eligible day gets one pending, pin-marked row
with its time, visible all day, even before 07:30. There are no notifications.
Occurrences use ordinary slots and can be edited, completed or reordered.
They are freshly placed first on the next eligible day, not duplicated on
reopening. Distinct rules may have the same text.

A new due rule cannot evict work from a full sheet. Rule changes update its
current occurrence; ordinary font/layout settings preserve occurrence edits.
Clearing an occurrence clears today only. Removing a rule preserves today's
text as a manual task rather than deleting work. Rule changes take effect only
when saved in Settings; Cancel does not publish them.

## Local files and failures

```text
~/Library/Application Support/TaskPad/active.json
~/Library/Application Support/TaskPad/Archives/<date>-<sheet-id>.md
```

Archives are human-readable Markdown with complete JSON sheet metadata.
Rollover writes the archive first, then atomically replaces `active.json`.
Retry reuses the archive identity. Unreadable/unsupported data is never silently
reset. Failed edits remain visibly unsaved with Retry; quitting warns before
discarding them. This development revision has no legacy data migration.

`TASKPAD_DATA_DIR` can select isolated development storage. A separate smoke
bundle can use `TaskPadSmokeDataDirectory` in its Info.plist; ordinary builds
set neither. Native screenshots are in `docs/screenshots/`.

The release bundle includes a multi-resolution TaskPad icon. Its source can be
regenerated with `swift scripts/make-icon.swift <output.iconset>` followed by
`iconutil -c icns <output.iconset>`. Use a disposable output directory.

The [requirements audit](docs/requirements.md) maps the requested behavior to
the implementation and its verification boundaries.
