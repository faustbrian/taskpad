import XCTest
@testable import TaskPadCore

final class TaskPadTests: XCTestCase {
    private func isolated(_ body: (PadStore, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-core-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try body(PadStore(directory: root, today: "2026-10-12"), root)
    }
    // TPR01/08: limits constrain a persistent number of slots, not an add operation.
    func testResizePreservesFilledSlotsAndRejectsDestructiveShrink() throws {
        try isolated { store, root in
            var settings = store.state.settings; settings.slotLimit = 3; try store.applySettings(settings)
            let ids = store.state.sheet.tasks.map(\.id)
            try store.editSheet { $0.tasks[0].text = "A"; $0.tasks[2].text = "C"; $0.tasks[2].isComplete = true }
            settings.slotLimit = 2; try store.applySettings(settings)
            XCTAssertEqual(store.state.sheet.tasks.map(\.id), [ids[0], ids[2]])
            XCTAssertEqual(store.state.sheet.used, 2)
            let before = store.state; settings.slotLimit = 1
            XCTAssertThrowsError(try store.applySettings(settings)); XCTAssertEqual(store.state, before)
            XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, before)
            settings.slotLimit = 5; try store.applySettings(settings)
            XCTAssertEqual(store.state.sheet.tasks.count, 5)
            XCTAssertEqual(Array(store.state.sheet.tasks.prefix(2)), before.sheet.tasks)
            XCTAssertTrue(store.state.sheet.tasks.suffix(3).allSatisfy(\.isBlank))
            for invalid in [0, 101] { settings.slotLimit = invalid; XCTAssertThrowsError(try store.applySettings(settings)) }
        }
    }
    // TPR02: a move carries the complete identity, including scheduled data.
    func testReorderAndClearKeepCountIdentityAndMetadata() throws {
        var sheet = PadSheet(day: "2026-10-12", limit: 5)
        let ids = sheet.tasks.map(\.id)
        sheet.tasks[0].text = "**A**"; sheet.tasks[0].priority = .high; sheet.tasks[0].color = .purple
        sheet.tasks[0].isComplete = true; sheet.tasks[0].scheduleID = UUID(); sheet.tasks[0].scheduledTime = "07:30"
        let original = sheet.tasks
        try sheet.move(ids[0], to: ids[4])
        XCTAssertEqual(sheet.tasks, [original[1], original[2], original[3], original[4], original[0]])
        try sheet.move(ids[0], to: ids[0]); XCTAssertEqual(sheet.tasks.count, 5)
        sheet.tasks[2].clear(); XCTAssertEqual(sheet.tasks[2].id, ids[3]); XCTAssertTrue(sheet.tasks[2].isBlank)
        XCTAssertEqual(sheet.tasks.last, original[0])
    }
    // TPR03: Ask default none, selective order and independent notes/closing reflection.
    func testAskSelectiveCarryAndArchiveFullFidelity() throws {
        try isolated { store, root in
            var settings = store.state.settings; settings.slotLimit = 5; settings.notesEnabled = true; try store.applySettings(settings)
            try store.editSheet {
                $0.tasks[0].text = "A"; $0.tasks[1].text = "Done"; $0.tasks[1].isComplete = true
                $0.tasks[3].text = "**C**\nsecond"; $0.tasks[3].priority = .high; $0.tasks[3].color = .green; $0.notes = "WORK"
            }
            let old = store.state.sheet
            try store.beginRollover(to: "2026-10-15")
            XCTAssertEqual(store.state.draft?.selectedTaskIDs, []); XCTAssertFalse(store.state.draft!.carryNotes)
            XCTAssertThrowsError(try store.editDraft { $0.selectedTaskIDs = [old.tasks[1].id] })
            XCTAssertThrowsError(try store.editDraft { $0.selectedTaskIDs = [old.tasks[2].id] })
            try store.editDraft { $0.selectedTaskIDs = [old.tasks[3].id, old.tasks[0].id]; $0.carryNotes = true; $0.closingNotes = "CLOSE" }
            let reopened = try PadStore(directory: root, today: "2026-10-15")
            XCTAssertEqual(reopened.state.draft, store.state.draft); XCTAssertEqual(reopened.state.sheet, old)
            try reopened.confirmRollover(to: "2026-10-15")
            XCTAssertEqual(Array(reopened.state.sheet.tasks.prefix(2)), [old.tasks[0], old.tasks[3]])
            XCTAssertEqual(reopened.state.sheet.tasks.count, 5); XCTAssertEqual(reopened.state.sheet.used, 2)
            XCTAssertEqual(reopened.state.sheet.notes, "WORK"); XCTAssertEqual(reopened.state.sheet.closingNotes, "")
            var expected = old; expected.closingNotes = "CLOSE"
            XCTAssertEqual(try archived(root), expected)
            try reopened.beginRollover(to: "2026-10-15"); XCTAssertNil(reopened.state.draft)
        }
    }
    func testAutoNeverAndDefaultCleanSlate() throws {
        for mode in CarryMode.allCases {
            try isolated { store, root in
                var settings = store.state.settings; settings.slotLimit = 3; settings.carryMode = mode; settings.notesEnabled = true
                try store.applySettings(settings)
                try store.editSheet { $0.tasks[0].text = "A"; $0.tasks[1].text = "Done"; $0.tasks[1].isComplete = true; $0.notes = "WORK" }
                try store.beginRollover(to: "2026-10-13")
                if mode == .ask { XCTAssertNotNil(store.state.draft); try store.confirmRollover(to: "2026-10-13") }
                XCTAssertEqual(store.state.sheet.tasks.count, 3)
                XCTAssertEqual(store.state.sheet.used, mode == .automatic ? 1 : 0)
                XCTAssertEqual(store.state.sheet.notes, mode == .automatic ? "WORK" : "")
                XCTAssertNil(store.state.draft); XCTAssertEqual(try archived(root).used, 2)
                try store.beginRollover(to: "2026-10-09"); XCTAssertEqual(store.state.sheet.day, "2026-10-13")
            }
        }
    }
    // TPR04/05: schedules exist all day and reset only on eligible civil dates.
    func testWeekdayScheduleOccurrencesDeduplicateAndResetNextDay() throws {
        try isolated { store, root in
            var rule = RepeatTask(text: "Merge develop into main"); rule.priority = .high
            var duplicateText = rule; duplicateText.id = UUID(); duplicateText.minute = 45
            var settings = store.state.settings; settings.slotLimit = 3; settings.schedules = [rule, duplicateText]; settings.carryMode = .never
            try store.applySettings(settings)
            XCTAssertEqual(store.state.sheet.tasks.compactMap(\.scheduledTime), ["07:30", "07:45"])
            let monday = store.state.sheet.tasks[0]
            try store.editSheet { $0.tasks[0].isComplete = true }
            try store.applySettings(settings)
            XCTAssertTrue(store.state.sheet.tasks[0].isComplete)
            XCTAssertEqual(store.state.sheet.tasks.filter { $0.scheduleID == rule.id }.count, 1)
            let reopened = try PadStore(directory: root, today: "2026-10-12")
            XCTAssertTrue(reopened.state.sheet.tasks[0].isComplete)
            try reopened.beginRollover(to: "2026-10-13")
            XCTAssertEqual(reopened.state.sheet.tasks.filter { $0.scheduleID == rule.id }.count, 1)
            XCTAssertFalse(reopened.state.sheet.tasks[0].isComplete); XCTAssertNotEqual(reopened.state.sheet.tasks[0].id, monday.id)
            try reopened.beginRollover(to: "2026-10-12"); XCTAssertEqual(reopened.state.sheet.day, "2026-10-13")
            try reopened.beginRollover(to: "2026-10-17"); XCTAssertEqual(reopened.state.sheet.used, 0)
            XCTAssertTrue(rule.isDue(on: "2026-10-12")); XCTAssertFalse(rule.isDue(on: "2026-10-17"))
        }
    }
    func testAutoCapacityConflictPreservesManualWorkAndAsksWhatFits() throws {
        try isolated { store, root in
            var settings = store.state.settings; settings.slotLimit = 2; settings.carryMode = .automatic
            var rule = RepeatTask(text: "Tuesday routine"); rule.weekdays = [3]; settings.schedules = [rule]
            try store.applySettings(settings)
            try store.editSheet { $0.tasks[0].text = "A"; $0.tasks[1].text = "B" }
            let old = store.state.sheet
            XCTAssertThrowsError(try store.beginRollover(to: "2026-10-13"))
            XCTAssertEqual(store.state.sheet, old); XCTAssertEqual(store.state.draft?.selectedTaskIDs, Set(old.tasks.map(\.id)))
            let reopened = try PadStore(directory: root, today: "2026-10-13")
            XCTAssertEqual(reopened.state, store.state)
            try reopened.editDraft { $0.selectedTaskIDs = [old.tasks[1].id] }; try reopened.confirmRollover(to: "2026-10-13")
            XCTAssertEqual(reopened.state.sheet.tasks.map(\.text), ["Tuesday routine", "B"])
            XCTAssertEqual(try archived(root), old)
        }
    }
    func testDueScheduleCannotEvictFullSheetAndUnrelatedSettingsPreserveOccurrenceEdits() throws {
        try isolated { store, _ in
            var settings = store.state.settings; settings.slotLimit = 1; try store.applySettings(settings)
            try store.editSheet { $0.tasks[0].text = "Manual" }
            settings.schedules = [RepeatTask(text: "Routine")]
            let before = store.state
            XCTAssertThrowsError(try store.applySettings(settings)); XCTAssertEqual(store.state, before)
            try store.editSheet { $0.tasks[0].clear() }; try store.applySettings(settings)
            try store.editSheet { $0.tasks[0].text = "Today's change"; $0.tasks[0].isComplete = true }
            let edited = store.state.sheet
            settings.fontSize = 20; try store.applySettings(settings)
            XCTAssertEqual(store.state.sheet, edited)
            settings.schedules = []; try store.applySettings(settings)
            XCTAssertEqual(store.state.sheet.tasks[0].text, "Today's change"); XCTAssertNil(store.state.sheet.tasks[0].scheduleID)
            XCTAssertTrue(store.state.sheet.tasks[0].isComplete)
        }
    }
    // TPR07/08: input/grapheme, counts, localized date and persisted presentation.
    func testTextBoundsFormattingDefaultsAndSettingsPersist() throws {
        XCTAssertTrue(TaskInput.accepts(String(repeating: "👩🏽‍💻", count: 500)))
        XCTAssertFalse(TaskInput.accepts(String(repeating: "a", count: 501)))
        XCTAssertTrue(TaskInput.accepts("a\nb\nc\nd\ne")); XCTAssertFalse(TaskInput.accepts("a\nb\nc\nd\ne\nf"))
        try isolated { store, root in
            XCTAssertEqual(store.state.theme, .karst); XCTAssertEqual(store.state.settings.fontName, "System")
            XCTAssertFalse(store.state.settings.notesEnabled); XCTAssertFalse(store.state.settings.footer.visible)
            XCTAssertFalse(store.state.settings.header.showBrand); XCTAssertEqual(store.state.settings.carryMode, .ask)
            var settings = store.state.settings; settings.slotLimit = 3; settings.header.visible = false; settings.footer.visible = false
            settings.header.countFormat = "{used} out of {limit} slots taken"; settings.fontName = "Maple Mono NF"; settings.fontSize = 20
            settings.notesEnabled = false; settings.windowTitle = "My pad"; settings.dateFormat = "yyyy/MM/dd"
            try store.applySettings(settings)
            try store.editSheet { $0.tasks[0].text = "A"; $0.tasks[0].isComplete = true; $0.tasks[1].text = "  "; $0.notes = "Hidden, not erased" }
            XCTAssertEqual(PadText.format(settings.header.countFormat, state: store.state), "1 out of 3 slots taken")
            XCTAssertEqual(PadDay.display("2026-10-12", format: settings.dateFormat), "2026/10/12")
            let date = try XCTUnwrap(PadDay.date("2026-10-12")), formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fi_FI"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateStyle = .full
            XCTAssertEqual(PadDay.display("2026-10-12", locale: formatter.locale), formatter.string(from: date))
            XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, store.state)
        }
    }
    private func archived(_ root: URL) throws -> PadSheet {
        let files = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Archives"), includingPropertiesForKeys: nil)
        let text = try String(contentsOf: XCTUnwrap(files.first))
        let json = try XCTUnwrap(text.components(separatedBy: "```json\n").last?.components(separatedBy: "\n```").first)
        return try JSONDecoder().decode(PadSheet.self, from: Data(json.utf8))
    }
}
