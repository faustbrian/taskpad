# TaskPad requirements audit

Reviewed 11 October 2026. The requested features below are implemented. This
is a requirement-level audit, not a claim of exhaustive testing on every Mac.
The original “Notepad” theme is now **Anoto**; no legacy migration is included.

## Fixed pad and interactions

| Requirement | Result and evidence |
| --- | --- |
| Consistent TaskPad naming | Package, executable, app entry point, source/test directories, bundle display name and default text use TaskPad. No Taskpad or Notepad source references remain. The existing lowercase repository directory and bundle identifier are technical identifiers. |
| Configurable item limit; exactly that many prefilled slots; no Add task | 1–100, default 30. Native settings saved 20 and rendered all 20 slots. SlotRevisionTests covers fresh 30 and configured 20; TaskPadTests covers growth and rejection of destructive shrink. Completed tasks still occupy slots. |
| Tab and arrows wrap | Native Up from slot 1 reached 20; Down/Tab returned to 1; Shift-Tab reached 20. InteractionTests also checks round-robin selection and blank editing. |
| Space/Left completion; Right menu; 0–9 priority | Space advances to the immediate next fixed slot only when becoming done; last/only slot never wraps. Left and done→pending Space retain focus. Hosted native responder tests prove successor ownership, including rapid Space→typing before SwiftUI installs the next responder. Native checks verified completion and last-slot retention. Editors retain text-entry keys. |
| Configurable double-click | Edit by default; optionally toggle exactly once without advancing. Native checks cover text, blank slots and passive badges in both modes. A blank-hit failure was reproduced and fixed by giving the non-checkbox resting surface a rectangular target. Native editor double-click still selects words; checkbox double-click remains two ordinary clicks. Save/Cancel retains/discards the preference. |
| Configurable priority presentation | Numbers by default, or exactly N exclamation marks for levels 1–9; zero has no badge. All ten literal labels pass core assertions, raw levels persist unchanged, and native marks/context choices were inspected. |
| Optional effort and extended scales | Exponential, Fibonacci, Linear and T-Shirt match all seven literal requested labels and numeric equivalents. Fibonacci/default extension off; estimates unset. Shared flat menu and repeating-rule editor support assign/clear and retained extended values. Scale changes preserve relative size; extension off restricts new assignments without erasing existing values. Real store tests cover reorder, durable reopen, archive, selected manual carry and fresh scheduled defaults; model tests cover Undo/Redo and invalid assignments. |
| Priority and ink are top-level quick actions; no row menu icons | Native context menu exposes all ten priorities and ink choices directly. Rows have no three-dot button or down chevron. Right-click and Right use the same menu. |
| Drag and drop | Native drag moved a completed, blue, priority-9 scheduled task from slot 1 to 4. Its complete JSON row and every identity were preserved, with 20 total slots. Native Undo restored the exact full state. Core reorder and app undo tests cover these contracts. |
| Markdown and bounded multiline content | Inline Markdown renders at rest; native Anoto/Karst checks showed bold and completion styling. Resting rows truncate to one line; focus expands in whole ruled-line increments, capped at five, without changing top inset. New input is limited to five visual lines and 500 characters. InteractionTests exercises real native text measurement, five/six lines, wrapped paste and replacement bounds. Existing text is preserved when font or window width changes. |

## Appearance and minimal chrome

| Requirement | Result and evidence |
| --- | --- |
| Karst default; Anoto, Things, Todoist, TickTick | All five choices are present and persist. Theme load tests cover each. Native theme screenshots are linked below; the current native sweep rechecked Karst and Anoto. These are visual themes, not integrations with those products. |
| Karst solid black completed circle | Native completed row showed a solid black circle with no tick. |
| Anoto blue check, clear red-margin gutter | Native completed row showed a blue checked square. The red margin is at x=52 and text begins at x=68, leaving 16 points of clearance. |
| Consistent typography, spacing and focused padding | Shared font/layout metrics govern every theme. Native 18-point Maple Mono NF checks showed 41-point ruled rows and unchanged first-line position when a two-line task received focus. Only the row's height expands. |
| Configurable font and size; Apple system default | Installed font-family picker includes Maple Mono NF; native Save applied it at 18 points. Default is system San Francisco at 16 points; allowed size is 10–32. Native measurement/fallback tests cover unavailable fonts. |
| Notes optional and off by default | Defaults test verifies off. Native hide removed the notes section without erasing its stored text. Disabled notes also removed rollover reflection/carry-notes controls and did not carry hidden notes. |
| No distracting branding; hide individual parts or entire header/footer | Branding defaults off; footer defaults hidden. Native changes produced a date/count-only header, then a list-only window with header, footer and notes hidden. Settings remained reachable through ⌘,. |
| Configurable title, heading, motto, date and counts | Settings exposes window title, separate header/footer brand and heading/motto text, each visibility switch, date visibility and count visibility/format. Native cross-category Save persisted the custom title, footer, date and count text. Cancel restored the exact unchanged durable state. |
| Locale date default; customizable text/count format | Empty date format uses the system locale. Native yyyy/MM/dd and “{used} out of {limit} slots taken” rendered correctly. Date/count formatting is covered by core tests; unknown tokens stay literal. Supported tokens: {date}, {used}, {limit}, {completed}, {remaining}. |
| Settings like System Settings; no clipped top | Sidebar categories and grouped native forms replace the tabs. Final 780×680 native screenshots show 28-point top clearance in both appearances. All five categories, scrolling through long repeating-rule lists, and pinned Save/Cancel were inspected. Invalid shrink showed a visible error without changing the saved configuration. |

## Daily lifecycle and scheduled tasks

| Requirement | Result and evidence |
| --- | --- |
| Carry-over Auto / Ask / Never, default Ask | Defaults and all three paths pass core tests. Auto overflow preserves work and asks what fits; Never creates a fresh sheet while still placing due rules. |
| Review previous list, optional notes, archive, clean slate or selected carry | Native Ask with notes disabled showed only unfinished manual choices, none selected initially. Not yet retained a selection. Start today archived the exact complete previous sheet, carried only the selected manual row, placed a fresh pending scheduled row, and filled the other 18 slots with blanks. All/none/notes-only/reflection and archive retry paths pass core tests. There is no history browser. |
| Repeating weekday/time tasks, visible all day and emphasized | Weekday/time rules consume fixed slots, show a pin and time, and start pending each eligible day. Native editing changed the occurrence to 08:30 while preserving its identity. Clearing today and saving unrelated settings did not resurrect the text or delete the rule; the next-day native sweep created a fresh occurrence. Weekday eligibility, reopening deduplication, capacity and next-day reset pass core tests. No notifications or calendar view. |
| Recoverable saves and clean retry | A real filesystem failure originally lost the selected theme on Retry. Settings and theme now form one candidate. The regression fails on the old behavior and passes after the fix; native failure/retry durably saved both selected title and Karst. Validation failure does not publish either. |

## Verification and boundaries

- `./scripts/test.sh`: 50 tests passed (22 core, 28 app).
- `./scripts/build.sh`: release bundle built and ad-hoc signed for this Mac.
- Native checks used isolated disposable storage, not the user's task data.
- Settings is an independent, resizable native window with draft Save/Cancel;
  the Apple styling does not introduce navigation history or extra workflows.
- Settings/editing is temporarily disabled while a new-day decision is waiting;
  Continue resolves that decision. Hidden chrome does not block Settings.
- Native checks ran on the current Apple Silicon Mac. macOS 14 hardware,
  Intel builds, notarization, hosted CI and actual power-loss testing were not
  performed. VoiceOver-specific development and verification were explicitly
  removed from scope by the user; ordinary native accessibility semantics remain.

## Native polish pass

Checks used a separate bundle identity and disposable data on the current Mac.
The original user data and installed project skill files were not changed.

| Polish contract | Fresh evidence |
| --- | --- |
| Independent adaptable Settings | Native standard window, not a sheet. Compact 640×480 content and large 900×740 content keep title and actions visible; every category remains accessible through its scrollable form. Repeated ⌘, uses the same window. Cancel/reopen starts with accepted values, not the discarded draft. A native layout regression fails against the prior fixed 780×680 view and passes now. |
| Save recovery in Settings | A real blocked atomic-write path shows Retry Save next to the error. Repeated failure preserves last-good bytes. Repairing the fixture and retrying durably saves the complete Anoto/theme and title candidate without changing the sheet. |
| Separate-window keyboard and Undo ownership | Native ⌘Return in Settings no longer toggles a task. SettingsTests covers pad edits while the draft is open, isolation from pad Undo, and saving without restoring stale tasks. |
| Quiet dependent controls | Hidden header/footer parts disable their dependent text fields without erasing text. Entire disabled sections disable their child controls; the shared date-format field stays usable. Copy is shortened and token help is collapsed. |
| Row readability and fixed rhythm | All five themes inspected at 16 points. Compact Karst at 10-point Maple Mono and Anoto at 32 points preserve the completion shape, readable time/priority and text gutter. Multiline focus and native editing retain the first-line inset. Completed text is no longer faded; priority/time use shared scalable metrics. |
| Type without Enter | Native row events start the editor and retain the initiating letter and rapid following spaces/digits, without replacing existing text. Hosted responder regressions cover append, native initial-character Undo, finished-edit Undo/Redo, fixed identities, durable text, same-slot Tab at a one-slot limit, buffered command handoff, and the 499/500-character and five-visual-line bounds. Native checks cover ordinary typing, Shift punctuation, Option dead-key accents, priority/completion shortcuts, wrap navigation and the flat Right-arrow menu. |
| Stationary editing text and caret | A rendered-pixel regression reproduced a one-point downward shift. Resting/editor/typed/resting glyph rows now match at 10/16/32 points in System and the installed Maple Mono NF; multiline glyphs advance by exactly one ruled pitch. Native captures check Karst/System16, Karst/Maple10 and Anoto/Maple32. The editor uses natural font-height glyphs and caret with ruled inter-line spacing, not a row-height paragraph/caret. Notes remain editable. |
| Minimal navigation and reordering | Adjacent visible selections do not recenter the viewport; off-screen selection and 1↔30 wrap work. A native drag moved the exact scheduled row from slot 1 through 7 to off-screen slot 19, retaining all 30 identities; two Undo actions restored the entire durable state exactly. Dragging does not add slots. |
| Native appearance and Increase Contrast | Fresh light/dark Settings captures and an actual Increase Contrast capture show stronger outlines and selection. Original Dark appearance and disabled Increase Contrast/Reduce Transparency were restored. |
| Finished app resource | Release bundle includes a signed multi-resolution TaskPad.icns (16 through 1024 pixels). Finder's preview displays the icon. Bundle modification time now refreshes on rebuild so resource changes are discoverable. |
| Dock and accessibility scope | The user’s 11 October native Dock screenshot confirms the TaskPad icon. VoiceOver-specific work/testing is out of scope by explicit user direction; standard native controls and existing labels remain. No VoiceOver support verdict is claimed. |

Fresh polish captures: [compact dark Settings](screenshots/polish-settings-compact-dark.png),
[compact light Settings](screenshots/polish-settings-compact-light.png),
[large Settings](screenshots/polish-settings-large-dark.png),
[compact Karst, 10 pt](screenshots/polish-karst-compact-10.png),
[compact Anoto, 32 pt](screenshots/polish-anoto-compact-32.png),
[Increase Contrast](screenshots/polish-anoto-increase-contrast.png),
[large Karst, 16 pt](screenshots/polish-karst-large-16.png),
[Things](screenshots/polish-things-16.png),
[Todoist](screenshots/polish-todoist-16.png),
[TickTick](screenshots/polish-ticktick-16.png).

Measured resting/editing pairs: Karst/System16
([rest](screenshots/typing-karst16-rest.png), [edit](screenshots/typing-karst16-edit.png)),
Karst/Maple10 ([rest](screenshots/typing-karst10-rest.png), [edit](screenshots/typing-karst10-edit.png)),
Anoto/Maple32 ([rest](screenshots/typing-anoto32-rest.png), [edit](screenshots/typing-anoto32-edit.png)).

## Native interaction and effort checks

The disposable controls preview verified persisted double-click modes, Cancel,
Space-only forward selection, Left retention, rapid typing routing, actual
flat right-click/Right menus, effort assignment and native Undo, all four scale
previews and retained XXXL after disabling extension. Compact 640×480-content
Settings in both light and dark scrolls to the new controls while Save/Cancel
stay pinned. Light appearance was forced only in the disposable preview bundle;
no system appearance was changed. Large
Settings remains independently resizable. Maximum combined schedule/priority-9/
effort badges stay legible in Karst and Anoto at 32 points; Maple Mono NF at
10 points retains the clear Anoto gutter. These native gesture observations
are manual checks, not synthetic model-only gesture proof.

New captures: [Karst 32](screenshots/controls-karst-32.png),
[Anoto 32](screenshots/controls-anoto-32.png),
[Anoto/Maple 10](screenshots/controls-anoto-10.png),
[compact General](screenshots/controls-settings-general-compact.png),
[compact Appearance](screenshots/controls-settings-appearance-compact.png),
[light General](screenshots/controls-settings-general-light.png),
[light Appearance](screenshots/controls-settings-appearance-light.png),
[Things](screenshots/controls-things-16.png),
[Todoist](screenshots/controls-todoist-16.png),
[TickTick](screenshots/controls-ticktick-16.png).

## Screenshots

- Settings: [dark](screenshots/settings-dark.jpg),
  [light](screenshots/settings-light.jpg).
- Paper: [Karst](screenshots/karst.jpg), [Anoto](screenshots/anoto.jpg),
  [Things](screenshots/things.jpg), [Todoist](screenshots/todoist.jpg),
  [TickTick](screenshots/ticktick.jpg), [list only](screenshots/list-only.jpg).
