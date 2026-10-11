import XCTest
import AppKit
import TaskPadCore
@testable import TaskPad

final class InteractionTests: XCTestCase {
    // TPR01/02/07: navigation and clear/edit operations act on fixed slots.
    func testRoundRobinClearAndBlankEditingPreserveExactlyThreeSlots() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-interaction-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            var settings = model.settings; settings.slotLimit = 3; settings.priorityEnabled = true; XCTAssertTrue(model.applySettings(settings))
            let ids = model.state!.sheet.tasks.map(\.id)
            model.select(ids[0]); model.navigate(-1); XCTAssertEqual(model.selectedTask, ids[2])
            model.navigate(1, editing: true); XCTAssertEqual(model.editingTask, ids[0])
            model.changeText(ids[0], text: "A"); model.navigate(-1, editing: true)
            XCTAssertEqual(model.editingTask, ids[2]); model.finishEditing()
            XCTAssertEqual(model.state!.sheet.tasks.map(\.id), ids)
            model.select(ids[0]); model.delete(ids[0]); XCTAssertEqual(model.state!.sheet.tasks.map(\.id), ids)
            XCTAssertTrue(model.state!.sheet.tasks[0].isBlank)
            model.undo(); XCTAssertEqual(model.state!.sheet.tasks[0].text, "A")
            for value in 0...9 { model.setPriority(ids[0], TaskPriority(rawValue: value)); XCTAssertEqual(model.state!.sheet.tasks[0].priority.rawValue, value) }
            model.setPriority(ids[0], TaskPriority(rawValue: 10)); XCTAssertEqual(model.state!.sheet.tasks[0].priority.rawValue, 9)
            XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, model.state)
        }
    }
    // TPR03/05: Auto overflow exposes the safe persisted draft to the UI consumer.
    func testAutoOverflowOpensDecisionAndPreservesOldSheet() async {
        await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-interaction-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            var day = "2026-10-12"
            let model = AppModel(directory: root, dateProvider: { day })
            var settings = model.settings; settings.slotLimit = 1; settings.carryMode = .automatic
            var rule = RepeatTask(text: "Tuesday routine"); rule.weekdays = [3]; settings.schedules = [rule]
            XCTAssertTrue(model.applySettings(settings))
            let id = model.state!.sheet.tasks[0].id
            model.startEditing(id); model.changeText(id, text: "Manual"); model.finishEditing()
            day = "2026-10-13"; model.checkDay()
            XCTAssertTrue(model.showRollover); XCTAssertFalse(model.canEdit); XCTAssertNotNil(model.message)
            XCTAssertEqual(model.state!.sheet.tasks[0].text, "Manual"); XCTAssertEqual(model.state!.sheet.day, "2026-10-12")
            model.showRollover = false
            let reopened = AppModel(directory: root, dateProvider: { day })
            XCTAssertTrue(reopened.showRollover); XCTAssertEqual(reopened.state, model.state)
            reopened.editDraft { $0.selectedTaskIDs = [] }; reopened.confirmRollover()
            XCTAssertEqual(reopened.state!.sheet.tasks.map(\.text), ["Tuesday routine"])
            XCTAssertTrue(reopened.canEdit); XCTAssertNil(reopened.message)
        }
    }
    // TPR07/09: one-to-five lines are measured, not guessed from source newlines.
    func testNativeTextMeasurementAndFontFallback() {
        let font = NSFont.systemFont(ofSize: 16)
        XCTAssertEqual(TaskLayout.lines("one\ntwo\nthree\nfour\nfive", width: 240, font: font), 5)
        XCTAssertEqual(TaskLayout.lines("one\ntwo\nthree\nfour\nfive\nsix", width: 240, font: font), 6)
        XCTAssertGreaterThan(TaskLayout.lines(String(repeating: "word ", count: 30), width: 100, font: font), 5)
        var settings = PadSettings(); settings.fontName = "NotARealInstalledFont-TaskPad"
        XCTAssertEqual(settings.nativeFont, NSFont.systemFont(ofSize: 16))
        for size in [10.0, 16, 32] { settings.fontSize = size; XCTAssertGreaterThanOrEqual(settings.rowHeight, size * 2) }
    }
    func testNewRepeatingTextCannotBypassFiveVisualLines() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-interaction-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            let before = model.state
            var settings = model.settings
            settings.schedules = [RepeatTask(text: String(repeating: "focused work ", count: 30))]
            XCTAssertFalse(model.applySettings(settings))
            XCTAssertEqual(model.state, before)
            XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, before)
        }
    }
    func testFreshNativeEditorAcceptsFiveLinesButRejectsSixAndLongWrappingPaste() async {
        await MainActor.run {
            var rejections = 0
            let parent = NativeEditor(text: "", label: "Test", font: .systemFont(ofSize: 16), ink: .black,
                                      availableWidth: 240, change: { _ in }, finish: {}, rejected: { rejections += 1 })
            let delegate = parent.makeCoordinator()
            let editor = NSTextView(frame: .zero)
            editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            XCTAssertTrue(delegate.textView(editor, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "one\ntwo\nthree\nfour\nfive"))
            XCTAssertFalse(delegate.textView(editor, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "one\ntwo\nthree\nfour\nfive\nsix"))
            XCTAssertFalse(delegate.textView(editor, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: String(repeating: "word ", count: 80)))
            XCTAssertEqual(rejections, 2)
            editor.string = String(repeating: "word ", count: 80)
            XCTAssertTrue(delegate.textView(editor, shouldChangeTextIn: NSRange(location: 0, length: 5), replacementString: ""))
        }
    }

    func testShorterReplacementCannotIntroduceSixLinesIntoValidText() async throws {
        try await MainActor.run {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-interaction-\(UUID())")
            defer { try? FileManager.default.removeItem(at: root) }
            let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            let id = model.state!.sheet.tasks[0].id
            let original = "Keep one focused task on this sheet"
            let invalid = "a\nb\nc\nd\ne\nf"
            model.startEditing(id); model.changeText(id, text: original)
            var rejected = false
            let parent = NativeEditor(text: original, label: "Test", font: .systemFont(ofSize: 16), ink: .black,
                                      availableWidth: 240, change: { _ in }, finish: {}, rejected: { rejected = true })
            let editor = NSTextView(frame: .zero); editor.string = original
            editor.textContainer?.containerSize = NSSize(width: 240, height: CGFloat.greatestFiniteMagnitude)
            XCTAssertFalse(parent.makeCoordinator().textView(editor, shouldChangeTextIn: NSRange(location: 0, length: original.utf16.count), replacementString: invalid))
            XCTAssertTrue(rejected)
            model.changeText(id, text: invalid)
            XCTAssertEqual(model.state!.sheet.tasks[0].text, original)
            XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state.sheet.tasks[0].text, original)
        }
    }

}
