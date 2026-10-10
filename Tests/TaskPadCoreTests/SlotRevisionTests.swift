import XCTest
@testable import TaskPadCore

final class SlotRevisionTests: XCTestCase {
    // R01: the active sheet is a fixed pad, not an initially empty task list.
    func testFreshSheetPrefillsThirtyDistinctBlankSlots() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-slots-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-10")
        XCTAssertEqual(store.state.sheet.tasks.count, 30)
        XCTAssertEqual(Set(store.state.sheet.tasks.map(\.id)).count, 30)
        XCTAssertTrue(store.state.sheet.tasks.allSatisfy { $0.text.isEmpty && !$0.isComplete })
        XCTAssertEqual(try PadStore(directory: root, today: "2026-10-10").state, store.state)
    }
    // R02/R04: on-disk preferences are an observable persistence boundary.
    private func fixture(_ settings: [String: Any], theme: String = "karst", _ body: (PadStore) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-revision-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let sheet = PadSheet(day: "2026-10-10", limit: settings["slotLimit"] as? Int ?? 30)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(PadState(sheet: sheet))) as? [String: Any])
        json["version"] = 2
        json["settings"] = settings
        json["theme"] = theme
        try JSONSerialization.data(withJSONObject: json).write(to: root.appendingPathComponent("active.json"))
        try body(PadStore(directory: root, today: "2026-10-10"))
    }

    func testConfiguredTwentySlotFixtureDecodesExactlyTwentySlots() throws {
        try fixture(["slotLimit": 20]) { store in
            XCTAssertEqual(store.state.sheet.tasks.count, 20)
        }
    }

    func testNeverCarryReplacesSheetWithoutPrompt() throws {
        try fixture(["carryMode": "never"]) { store in
            try store.beginRollover(to: "2026-10-11")
            XCTAssertEqual(store.state.sheet.day, "2026-10-11")
            XCTAssertNil(store.state.draft)
        }
    }

    func testRequestedThemeCanBeLoaded() throws {
        for theme in ["things", "todoist", "ticktick"] {
            try fixture([:], theme: theme) { store in
                XCTAssertEqual(store.state.theme.rawValue, theme)
            }
        }
    }
}
