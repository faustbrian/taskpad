import XCTest
import TaskPadCore

final class AppearancePersistenceTests: XCTestCase {
    func testAppearanceAndIndependentMetadataVisibilitySurviveReopeningWithoutChangingTasks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-appearance-core-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-12")
        try store.editSheet { $0.tasks[0].text = "Keep metadata"; $0.tasks[0].priority = .high; $0.tasks[0].effort = 6 }
        let sheet = store.state.sheet
        for mode in ["system", "light", "dark"] {
            for priority in [false, true] {
                for effort in [false, true] {
                    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(store.state.settings)) as! [String: Any]
                    object["appearance"] = mode; object["priorityEnabled"] = priority; object["effortEnabled"] = effort
                    let settings = try JSONDecoder().decode(PadSettings.self, from: JSONSerialization.data(withJSONObject: object))
                    try store.applySettings(settings)
                    let reopened = try PadStore(directory: root, today: "2026-10-12")
                    let saved = try JSONSerialization.jsonObject(with: JSONEncoder().encode(reopened.state.settings)) as! [String: Any]
                    XCTAssertEqual(saved["appearance"] as? String, mode)
                    XCTAssertEqual(saved["priorityEnabled"] as? Bool, priority)
                    XCTAssertEqual(saved["effortEnabled"] as? Bool, effort)
                    XCTAssertEqual(reopened.state.sheet, sheet)
                }
            }
        }
    }
}
