import XCTest
import AppKit
import SwiftUI
import TaskPadCore
@testable import TaskPad

final class SettingsTests: XCTestCase {
    // POL-07: the actual SwiftUI content must fit a compact Settings window.
    func testSettingsContentFitsCompactWindow() async {
        await MainActor.run {
            _ = NSApplication.shared
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-settings-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            let host = NSHostingController(rootView: PadSettingsView(model: model))
            let fitted = host.sizeThatFits(in: CGSize(width: 640, height: 480))
            XCTAssertLessThanOrEqual(fitted.width, 640)
            XCTAssertLessThanOrEqual(fitted.height, 480)
        }
    }
    // POL-01: background pad edits survive draft Save; Settings cannot undo the pad.
    func testIndependentSettingsPreservesPadEditsAndOwnsUndoFocus() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-settings-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            var enabled = model.settings; enabled.effortEnabled = true
            XCTAssertTrue(model.applySettings(enabled))
            let id = model.state!.sheet.tasks[0].id
            model.beginSettings()
            var draft = model.settings
            draft.windowTitle = "My pad"
            draft.doubleClickAction = .toggle; draft.priorityDisplay = .marks
            draft.effortScale = .tshirt; draft.extendedEffort = true
            model.startEditing(id); model.changeText(id, text: "Written while Settings is open"); model.finishEditing()
            model.setEffort(id, 5)
            let sheet = model.state!.sheet
            model.settingsIsKey = true
            model.undo()
            XCTAssertEqual(model.state!.sheet, sheet)
            XCTAssertFalse(model.canUseSheetCommands)
            model.settingsIsKey = false
            model.undo()
            XCTAssertNil(model.state!.sheet.tasks[0].effort)
            model.undo()
            XCTAssertTrue(model.state!.sheet.tasks[0].isBlank)
            model.redo()
            model.redo()
            XCTAssertEqual(model.state!.sheet, sheet)
            XCTAssertTrue(model.applySettings(draft, theme: .anoto))
            XCTAssertEqual(model.state!.sheet, sheet)
            XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, model.state)
        }
    }
    // P3: Save and Retry must retain the entire requested configuration, including theme.
    func testSettingsAndThemeStayTogetherThroughValidationAndSaveFailure() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-settings-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            var enabled = model.settings; enabled.effortEnabled = true
            XCTAssertTrue(model.applySettings(enabled))
            model.setEffort(model.selectedTask!, 5)
            let before = model.state!
            let active = root.appendingPathComponent("active.json")
            let durable = try Data(contentsOf: active)
            var invalid = model.settings; invalid.slotLimit = 0
            XCTAssertFalse(model.applySettings(invalid, theme: .anoto))
            XCTAssertEqual(model.state, before)
            XCTAssertEqual(try Data(contentsOf: active), durable)

            var selected = model.settings
            selected.windowTitle = "My fixed sheet"; selected.slotLimit = 20; selected.fontSize = 18
            selected.doubleClickAction = .toggle; selected.priorityDisplay = .marks
            selected.effortScale = .tshirt; selected.extendedEffort = true
            selected.priorityEnabled = true; selected.effortEnabled = false; selected.appearance = .dark
            let backup = root.appendingPathComponent("before-failure.json")
            try FileManager.default.moveItem(at: active, to: backup)
            try FileManager.default.createDirectory(at: active, withIntermediateDirectories: false)
            try Data("Owned save-failure fixture".utf8).write(to: active.appendingPathComponent("blocker"))
            XCTAssertFalse(model.applySettings(selected, theme: .anoto))
            XCTAssertTrue(model.unsaved)
            XCTAssertEqual(model.state?.settings, selected)
            XCTAssertEqual(model.theme, .anoto)
            XCTAssertEqual(try Data(contentsOf: backup), durable)

            try FileManager.default.removeItem(at: active)
            try FileManager.default.moveItem(at: backup, to: active)
            model.retrySave()
            XCTAssertFalse(model.unsaved)
            XCTAssertEqual(model.theme, .anoto)
            let reopened = try PadStore(directory: root, today: "2026-10-12").state
            XCTAssertEqual(reopened, model.state)
            XCTAssertEqual(reopened.theme, .anoto)
            XCTAssertEqual(reopened.settings, selected)
            XCTAssertEqual(reopened.sheet.tasks.map(\.id), Array(before.sheet.tasks.prefix(20)).map(\.id))
        }
    }
}
