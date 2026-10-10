import XCTest
import TaskPadCore
@testable import TaskPad

final class SettingsTests: XCTestCase {
    // P3: Save and Retry must retain the entire requested configuration, including theme.
    func testSettingsAndThemeStayTogetherThroughValidationAndSaveFailure() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-settings-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            let before = model.state!
            let active = root.appendingPathComponent("active.json")
            let durable = try Data(contentsOf: active)
            var invalid = model.settings; invalid.slotLimit = 0
            XCTAssertFalse(model.applySettings(invalid, theme: .anoto))
            XCTAssertEqual(model.state, before)
            XCTAssertEqual(try Data(contentsOf: active), durable)

            var selected = model.settings
            selected.windowTitle = "My fixed sheet"; selected.slotLimit = 20; selected.fontSize = 18
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
