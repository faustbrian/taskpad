import XCTest
@testable import TaskpadCore

final class TaskpadTests: XCTestCase {
    private func withStore(_ body: (PadStore, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("taskpad-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-10")
        try body(store, root)
    }

    func testThirtyTotalTasksIsAHardLimitEvenWhenCompleted() throws {
        var sheet = PadSheet(day: "2026-10-10")
        for index in 0..<30 {
            try sheet.add("Task \(index)")
        }
        XCTAssertEqual(sheet.tasks.count, 30)
        sheet.tasks[0].isComplete = true
        XCTAssertThrowsError(try sheet.add("Overflow"))
        XCTAssertEqual(sheet.tasks.count, 30)
        sheet.tasks.removeFirst()
        try sheet.add("Replacement")
        XCTAssertEqual(sheet.tasks.last?.text, "Replacement")
    }

    func testTaskOperationsAndThemePersistWithoutAutomaticSorting() throws {
        try withStore { store, root in
            try store.editSheet { sheet in
                try sheet.add("**First**\nsecond line")
                try sheet.add("Other")
                sheet.tasks[0].priority = .high
                sheet.tasks[0].color = .blue
                sheet.tasks[0].isComplete = true
                sheet.notes = "Notes with `code`"
            }
            let original = store.state.sheet
            try store.setTheme(.notepad)
            let reopened = try PadStore(directory: root, today: "2026-10-11")
            XCTAssertEqual(reopened.state.sheet, original)
            XCTAssertEqual(reopened.state.theme, .notepad)
            guard reopened.state.sheet.tasks.count == 2 else { return }
            try reopened.editSheet { sheet in
                try sheet.move(sheet.tasks[1].id, offset: -1)
            }
            XCTAssertEqual(reopened.state.sheet.tasks.map(\.text), ["Other", "**First**\nsecond line"])
        }
    }

    func testRolloverDefaultsToEmptyAndArchivesCompleteFidelity() throws {
        try withStore { store, root in
            try store.editSheet { sheet in
                try sheet.add("Keep yesterday only")
                sheet.tasks[0].priority = .medium
                sheet.tasks[0].color = .orange
                sheet.notes = "Working notes"
            }
            let previous = store.state.sheet
            try store.beginRollover(to: "2026-10-13")
            XCTAssertEqual(store.state.draft?.selectedTaskIDs, [])
            XCTAssertEqual(store.state.draft?.carryNotes, false)
            try store.editDraft { $0.closingNotes = "Closing reflection" }
            try store.confirmRollover(to: "2026-10-13")
            XCTAssertEqual(store.state.sheet.day, "2026-10-13")
            XCTAssertTrue(store.state.sheet.tasks.isEmpty)
            XCTAssertTrue(store.state.sheet.notes.isEmpty)
            XCTAssertNil(store.state.draft)
            let files = try FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Archives"), includingPropertiesForKeys: nil)
            XCTAssertEqual(files.count, 1)
            let text = try String(contentsOf: files[0], encoding: .utf8)
            XCTAssertTrue(text.contains("Closing reflection"))
            XCTAssertTrue(text.contains("Working notes"))
            XCTAssertTrue(text.contains(previous.tasks[0].id.uuidString))
            let json = try XCTUnwrap(text.components(separatedBy: "```json\n").last?.components(separatedBy: "\n```").first)
            var expectedArchive = previous
            expectedArchive.closingNotes = "Closing reflection"
            XCTAssertEqual(try JSONDecoder().decode(PadSheet.self, from: Data(json.utf8)), expectedArchive)
            try store.beginRollover(to: "2026-10-13")
            XCTAssertNil(store.state.draft)
            XCTAssertThrowsError(try store.confirmRollover(to: "2026-10-13"))
        }
    }

    func testSelectiveCarryKeepsOrderAndStylesButNeverCompletedTasks() throws {
        try withStore { store, _ in
            try store.editSheet { sheet in
                try sheet.add("One")
                try sheet.add("Done")
                try sheet.add("Three")
                sheet.tasks[1].isComplete = true
                sheet.tasks[2].priority = .high
                sheet.tasks[2].color = .green
                sheet.notes = "**Working**"
            }
            let old = store.state.sheet
            try store.beginRollover(to: "2026-10-11")
            try store.editDraft {
                $0.selectedTaskIDs = [old.tasks[2].id, old.tasks[0].id]
                $0.carryNotes = true
                $0.closingNotes = "Not copied"
            }
            try store.confirmRollover(to: "2026-10-11")
            XCTAssertEqual(store.state.sheet.tasks, [old.tasks[0], old.tasks[2]])
            XCTAssertEqual(store.state.sheet.notes, old.notes)
            XCTAssertEqual(store.state.sheet.closingNotes, "")
        }
    }

    func testCancelledDraftSurvivesRelaunchAndBackwardClockDoesNotReplaceSheet() throws {
        try withStore { store, root in
            let sheet = store.state.sheet
            try store.beginRollover(to: "2026-10-11")
            try store.editDraft { $0.closingNotes = "Unfinished reflection" }
            let reopened = try PadStore(directory: root, today: "2026-10-09")
            XCTAssertEqual(reopened.state.sheet, sheet)
            XCTAssertEqual(reopened.state.draft?.closingNotes, "Unfinished reflection")
            try reopened.beginRollover(to: "2026-10-09")
            XCTAssertThrowsError(try reopened.confirmRollover(to: "2026-10-09"))
            XCTAssertEqual(reopened.state.sheet, sheet)
        }
    }

    func testUnreadableStateIsNotReplacedWithEmptyData() throws {
        try withStore { _, root in
            let file = root.appendingPathComponent("active.json")
            try Data("broken".utf8).write(to: file)
            XCTAssertThrowsError(try PadStore(directory: root, today: "2026-10-11"))
            XCTAssertEqual(try String(contentsOf: file), "broken")
        }
    }
}
