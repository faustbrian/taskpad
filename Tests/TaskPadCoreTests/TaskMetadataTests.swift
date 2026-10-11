import XCTest
import TaskPadCore

final class TaskMetadataTests: XCTestCase {
    func testEveryEffortScaleAndPriorityPresentationUsesTheLiteralValues() throws {
        let labels: [(EffortScale, [String], [Int])] = [
            (.exponential, ["1", "2", "4", "8", "16", "32", "64"], [1, 2, 4, 8, 16, 32, 64]),
            (.fibonacci, ["1", "2", "3", "5", "8", "13", "21"], [1, 2, 3, 5, 8, 13, 21]),
            (.linear, ["1", "2", "3", "4", "5", "6", "7"], [1, 2, 3, 4, 5, 6, 7]),
            (.tshirt, ["XS", "S", "M", "L", "XL", "XXL", "XXXL"], [1, 2, 3, 5, 8, 13, 21])
        ]
        for (scale, expected, numeric) in labels {
            XCTAssertEqual((1...7).compactMap { scale.label($0) }, expected)
            XCTAssertEqual((1...7).compactMap { scale.numericValue($0) }, numeric)
            var settings = PadSettings(); settings.effortScale = scale
            XCTAssertEqual(settings.effortChoices(), [1, 2, 3, 4, 5])
            XCTAssertEqual(settings.effortChoices(retaining: 7), [1, 2, 3, 4, 5, 7])
            settings.extendedEffort = true
            XCTAssertEqual(settings.effortChoices(), [1, 2, 3, 4, 5, 6, 7])
            XCTAssertNil(scale.label(0)); XCTAssertNil(scale.numericValue(8))
        }
        for value in 0...9 {
            let priority = TaskPriority(rawValue: value)
            XCTAssertEqual(PriorityDisplay.numbers.label(priority), value == 0 ? "" : String(value))
            XCTAssertEqual(PriorityDisplay.marks.label(priority), ["", "!", "!!", "!!!", "!!!!", "!!!!!", "!!!!!!", "!!!!!!!", "!!!!!!!!", "!!!!!!!!!"][value])
        }
    }

    func testEffortSurvivesReorderScaleChangeArchiveCarryAndRepeatingRegeneration() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-metadata-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-12")
        var settings = store.state.settings; settings.slotLimit = 3; settings.extendedEffort = true
        var rule = RepeatTask(text: "Morning routine"); rule.effort = 2
        settings.schedules = [rule]; try store.applySettings(settings)
        let ids = store.state.sheet.tasks.map(\.id)
        try store.editSheet {
            $0.tasks[0].effort = 5
            $0.tasks[1].text = "Carry me"; $0.tasks[1].effort = 7
            $0.tasks[2].text = "Already done"; $0.tasks[2].effort = 3; $0.tasks[2].isComplete = true
            try $0.move(ids[1], to: ids[0])
        }
        let expected = store.state.sheet
        settings.effortScale = .tshirt; settings.extendedEffort = false
        try store.applySettings(settings)
        XCTAssertEqual(store.state.sheet, expected)
        XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state.sheet, expected)
        try store.beginRollover(to: "2026-10-13")
        try store.editDraft { $0.selectedTaskIDs = [ids[1]] }
        try store.confirmRollover(to: "2026-10-13")
        XCTAssertEqual(store.state.sheet.tasks.count, 3)
        let scheduled = store.state.sheet.tasks[0]
        XCTAssertEqual(scheduled.scheduleID, rule.id); XCTAssertNotEqual(scheduled.id, ids[0])
        XCTAssertEqual(scheduled.effort, 2); XCTAssertFalse(scheduled.isComplete)
        XCTAssertEqual(store.state.sheet.tasks[1], expected.tasks[0])
        XCTAssertFalse(store.state.sheet.tasks.contains { $0.id == ids[2] })
        let archive = root.appendingPathComponent("Archives/\(expected.day)-\(expected.id.uuidString).md")
        let content = try String(contentsOf: archive, encoding: .utf8)
        let metadata = try XCTUnwrap(content.components(separatedBy: "```json\n").last?.components(separatedBy: "\n```").first)
        XCTAssertEqual(try JSONDecoder().decode(PadSheet.self, from: Data(metadata.utf8)), expected)
        try store.editSheet { $0.tasks[1].clear() }
        XCTAssertEqual(store.state.sheet.tasks[1].id, ids[1]); XCTAssertNil(store.state.sheet.tasks[1].effort)
    }

    func testInvalidEffortCannotReplaceLastGoodData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-metadata-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-12")
        let file = root.appendingPathComponent("active.json"), before = try Data(contentsOf: root.appendingPathComponent("active.json"))
        for invalid in [0, -1, 8] {
            var next = store.state; next.sheet.tasks[0].effort = invalid
            XCTAssertThrowsError(try store.save(next))
            XCTAssertEqual(try Data(contentsOf: file), before)
            var rule = RepeatTask(text: "Routine"); rule.effort = invalid
            XCTAssertThrowsError(try rule.validate())
        }
    }

    func testBehaviorSettingsAndEffortSurviveStoreRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-metadata-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-12")
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(store.state)) as? [String: Any])
        var settings = document["settings"] as! [String: Any]
        for key in ["doubleClickAction", "priorityDisplay", "effortScale", "extendedEffort", "appearance", "priorityEnabled", "effortEnabled"] { settings.removeValue(forKey: key) }
        document["settings"] = settings
        try JSONSerialization.data(withJSONObject: document).write(to: root.appendingPathComponent("active.json"))
        let defaults = try PadStore(directory: root, today: "2026-10-12").state
        XCTAssertEqual(defaults.settings.doubleClickAction, .edit)
        XCTAssertEqual(defaults.settings.priorityDisplay, .numbers)
        XCTAssertEqual(defaults.settings.effortScale, .fibonacci)
        XCTAssertFalse(defaults.settings.extendedEffort)
        XCTAssertFalse(defaults.settings.priorityEnabled)
        XCTAssertFalse(defaults.settings.effortEnabled)
        XCTAssertEqual(defaults.settings.appearance, .system)
        XCTAssertNil(defaults.sheet.tasks[0].effort)
        XCTAssertEqual(defaults.sheet, store.state.sheet)
        settings["doubleClickAction"] = "toggle"
        settings["priorityDisplay"] = "marks"
        settings["effortScale"] = "tshirt"
        settings["extendedEffort"] = true
        document["settings"] = settings
        var sheet = document["sheet"] as! [String: Any]
        var tasks = sheet["tasks"] as! [[String: Any]]
        tasks[0]["text"] = "Focused task"
        tasks[0]["effort"] = 7
        sheet["tasks"] = tasks; document["sheet"] = sheet
        try JSONSerialization.data(withJSONObject: document).write(to: root.appendingPathComponent("active.json"))
        let reopened = try PadStore(directory: root, today: "2026-10-12")
        try reopened.save(reopened.state)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("active.json"))) as? [String: Any])
        let savedSettings = saved["settings"] as! [String: Any]
        XCTAssertEqual(savedSettings["doubleClickAction"] as? String, "toggle")
        XCTAssertEqual(savedSettings["priorityDisplay"] as? String, "marks")
        XCTAssertEqual(savedSettings["effortScale"] as? String, "tshirt")
        XCTAssertEqual(savedSettings["extendedEffort"] as? Bool, true)
        let savedTasks = (saved["sheet"] as! [String: Any])["tasks"] as! [[String: Any]]
        XCTAssertEqual(savedTasks[0]["effort"] as? Int, 7)
        XCTAssertEqual(savedTasks[0]["id"] as? String, tasks[0]["id"] as? String)
    }
}
