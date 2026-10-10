# TaskPad requirements audit

Reviewed 10 October 2026. All requested features below are implemented. This
is a requirement-level audit, not a claim of exhaustive testing on every Mac.
The original “Notepad” theme is now **Anoto**; no legacy migration is included.

## Fixed pad and interactions

| Requirement | Result and evidence |
| --- | --- |
| Consistent TaskPad naming | Package, executable, app entry point, source/test directories, bundle display name and default text use TaskPad. No Taskpad or Notepad source references remain. The existing lowercase repository directory and bundle identifier are technical identifiers. |
| Configurable item limit; exactly that many prefilled slots; no Add task | 1–100, default 30. Native settings saved 20 and rendered all 20 slots. SlotRevisionTests covers fresh 30 and configured 20; TaskPadTests covers growth and rejection of destructive shrink. Completed tasks still occupy slots. |
| Tab and arrows wrap | Native Up from slot 1 reached 20; Down/Tab returned to 1; Shift-Tab reached 20. InteractionTests also checks round-robin selection and blank editing. |
| Space/Left toggle; Right opens context menu; 0–9 priority | Native Space and Left changed pending/done; 0 and 9 changed priority; Right opened the flat menu. Intermediate priorities use the same range-checked path. Editors deliberately retain ordinary text-entry keys. |
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

- `./scripts/test.sh`: 28 tests passed (18 core, 10 app).
- `./scripts/build.sh`: release bundle built and ad-hoc signed for this Mac.
- Native checks used isolated disposable storage, not the user's task data.
- Settings remains a modal draft editor with Save/Cancel; the requested Apple
  styling does not introduce navigation history or extra product workflows.
- Settings/editing is temporarily disabled while a new-day decision is waiting;
  Continue resolves that decision. Hidden chrome does not block Settings.
- Native checks ran on the current Apple Silicon Mac. macOS 14 hardware,
  Intel builds, full VoiceOver coverage, notarization, hosted CI and actual
  power-loss testing were not performed.

## Screenshots

- Settings: [dark](screenshots/settings-dark.jpg),
  [light](screenshots/settings-light.jpg).
- Paper: [Karst](screenshots/karst.jpg), [Anoto](screenshots/anoto.jpg),
  [Things](screenshots/things.jpg), [Todoist](screenshots/todoist.jpg),
  [TickTick](screenshots/ticktick.jpg), [list only](screenshots/list-only.jpg).
