import XCTest
import AppKit
import TaskPadCore
@testable import TaskPad

final class UndoTests: XCTestCase {
    func testEditingAndAnotherTaskActionUndoIndependently() async throws {
        try await MainActor.run {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-undo-\(UUID())")
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try PadStore(directory: directory, today: "2026-10-10")
            try store.editSheet { $0.tasks[0].text = "A"; $0.tasks[1].text = "B" }
            let model = AppModel(directory: directory, dateProvider: { "2026-10-10" })
            let a = model.state!.sheet.tasks[0].id
            let b = model.state!.sheet.tasks[1].id
            model.startEditing(a)
            model.changeText(a, text: "Edited A")
            model.toggle(b)
            model.finishEditing()
            model.undo()
            XCTAssertEqual(model.state!.sheet.tasks[0].text, "Edited A")
            XCTAssertFalse(model.state!.sheet.tasks[1].isComplete)
            model.undo()
            XCTAssertEqual(model.state!.sheet.tasks[0].text, "A")
            model.redo()
            model.redo()
            XCTAssertEqual(model.state!.sheet.tasks[0].text, "Edited A")
            XCTAssertTrue(model.state!.sheet.tasks[1].isComplete)
            XCTAssertEqual(try PadStore(directory: directory, today: "2026-10-10").state, model.state)
        }
    }

    func testRolloverDoesNotLeaveUndoThatCanRestoreYesterdaysSheet() async throws {
        try await MainActor.run {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-undo-\(UUID())")
            defer { try? FileManager.default.removeItem(at: directory) }
            var day = "2026-10-10"
            let model = AppModel(directory: directory, dateProvider: { day })
            let id = model.state!.sheet.tasks[0].id
            model.startEditing(id)
            model.changeText(id, text: "Yesterday")
            model.finishEditing()
            XCTAssertEqual(model.state!.sheet.used, 1)
            model.undo()
            XCTAssertEqual(model.state!.sheet.used, 0)
            model.redo()
            XCTAssertEqual(model.state!.sheet.tasks[0].text, "Yesterday")
            day = "2026-10-11"
            model.checkDay()
            model.confirmRollover()
            model.undo()
            XCTAssertEqual(model.state!.sheet.day, day)
            XCTAssertEqual(model.state!.sheet.used, 0)
            XCTAssertFalse(model.unsaved)
            XCTAssertEqual(try PadStore(directory: directory, today: day).state, model.state)
        }
    }

    func testNotesAndStyleOrReorderActionsUndoIndependently() async throws {
        try await MainActor.run {
            let actions: [(AppModel, UUID) -> Void] = [
                { $0.setPriority($1, .high) },
                { $0.setColor($1, .blue) },
                { $0.move($1, offset: -1) }
            ]
            for action in actions {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-undo-\(UUID())")
                defer { try? FileManager.default.removeItem(at: directory) }
                let store = try PadStore(directory: directory, today: "2026-10-10")
                try store.editSheet { $0.tasks[0].text = "A"; $0.tasks[1].text = "B"; $0.notes = "Original notes" }
                var settings = store.state.settings; settings.notesEnabled = true; try store.applySettings(settings)
                let original = store.state.sheet
                let model = AppModel(directory: directory, dateProvider: { "2026-10-10" })
                model.startNotes()
                model.changeNotes("Edited notes")
                action(model, original.tasks[1].id)
                model.finishEditing()
                model.undo()
                XCTAssertEqual(model.state!.sheet.notes, "Edited notes")
                XCTAssertEqual(model.state!.sheet.tasks, original.tasks)
                model.undo()
                XCTAssertEqual(model.state!.sheet, original)
                model.redo()
                model.redo()
                XCTAssertEqual(model.state!.sheet.notes, "Edited notes")
                XCTAssertEqual(try PadStore(directory: directory, today: "2026-10-10").state, model.state)
            }
        }
    }
}
