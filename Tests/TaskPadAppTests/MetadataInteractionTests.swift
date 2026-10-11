import XCTest
import TaskPadCore
@testable import TaskPad

final class MetadataInteractionTests: XCTestCase {
    @MainActor func testDoubleClickModesAndEffortUndoDoNotAdvanceFocus() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-metadata-ui-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
        let id = model.selectedTask!
        var settings = model.settings; settings.doubleClickAction = .toggle; settings.extendedEffort = true
        XCTAssertTrue(model.applySettings(settings))
        model.setEffort(id, 7)
        model.doubleClick(id)
        XCTAssertTrue(model.state!.sheet.tasks[0].isComplete)
        XCTAssertNil(model.editingTask); XCTAssertEqual(model.selectedTask, id)
        model.undo()
        XCTAssertFalse(model.state!.sheet.tasks[0].isComplete); XCTAssertEqual(model.state!.sheet.tasks[0].effort, 7)
        model.redo()
        XCTAssertTrue(model.state!.sheet.tasks[0].isComplete)
        model.setEffort(id, nil); model.undo()
        XCTAssertEqual(model.state!.sheet.tasks[0].effort, 7)
        model.redo(); XCTAssertNil(model.state!.sheet.tasks[0].effort)
        XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, model.state)
        settings.doubleClickAction = .edit; XCTAssertTrue(model.applySettings(settings))
        model.doubleClick(id)
        XCTAssertEqual(model.editingTask, id); XCTAssertTrue(model.state!.sheet.tasks[0].isComplete)
    }

    @MainActor func testDisabledExtendedEffortRetainsExistingValueButRejectsNewAssignments() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-metadata-ui-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
        let ids = model.state!.sheet.tasks.map(\.id)
        var settings = model.settings; settings.extendedEffort = true
        XCTAssertTrue(model.applySettings(settings)); model.setEffort(ids[0], 6)
        settings.extendedEffort = false; settings.effortScale = .exponential; settings.priorityDisplay = .marks
        XCTAssertTrue(model.applySettings(settings))
        XCTAssertEqual(model.state!.sheet.tasks[0].effort, 6)
        var actions = slotActions(model.state!.sheet.tasks[0], model: model)
        XCTAssertTrue(actions.contains { $0.id == "effort-6" && $0.title == "Effort 32" && $0.selected })
        XCTAssertFalse(actions.contains { $0.id == "effort-7" })
        model.setEffort(ids[1], 6); XCTAssertNil(model.state!.sheet.tasks[1].effort)
        model.setPriority(ids[0], .high)
        actions = slotActions(model.state!.sheet.tasks[0], model: model)
        XCTAssertTrue(actions.contains { $0.id == "p9" && $0.title == "Priority !!!!!!!!!" && $0.selected })
        XCTAssertEqual(model.state!.sheet.tasks[0].effort, 6)
        try XCTUnwrap(actions.first { $0.id == "effort-none" }).perform()
        XCTAssertNil(model.state!.sheet.tasks[0].effort)
        model.setEffort(ids[0], 6); XCTAssertNil(model.state!.sheet.tasks[0].effort)
        XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, model.state)
    }
}
