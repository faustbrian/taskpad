import XCTest
import AppKit
import SwiftUI
import TaskPadCore
@testable import TaskPad

final class RowTypingTests: XCTestCase {
    @MainActor func testRapidSpaceThenTypingTargetsNewlySelectedSlot() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let row = try await fixture.focusedRow()
        let ids = fixture.model.state!.sheet.tasks.map(\.id)
        row.keyDown(with: fixture.event(" ", code: 49))
        row.keyDown(with: fixture.event("a", code: 0))
        row.keyDown(with: fixture.event("b", code: 11))
        try await fixture.wait { fixture.model.state!.sheet.tasks[1].text == "ab" }
        XCTAssertEqual(fixture.model.editingTask, ids[1])
        XCTAssertTrue(fixture.model.state!.sheet.tasks[0].isComplete)
        XCTAssertTrue(fixture.model.state!.sheet.tasks[0].isBlank)
    }
    @MainActor func testSpaceAdvancesOnlyWhenCompletingAndNeverWraps() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let ids = fixture.model.state!.sheet.tasks.map(\.id)
        var row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event(" ", code: 49))
        XCTAssertTrue(fixture.model.state!.sheet.tasks[0].isComplete)
        XCTAssertEqual(fixture.model.selectedTask, ids[1])
        row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event("\u{f702}", code: 123))
        XCTAssertTrue(fixture.model.state!.sheet.tasks[1].isComplete)
        XCTAssertEqual(fixture.model.selectedTask, ids[1])
        row.keyDown(with: fixture.event(" ", code: 49))
        XCTAssertFalse(fixture.model.state!.sheet.tasks[1].isComplete)
        XCTAssertEqual(fixture.model.selectedTask, ids[1])
        fixture.model.select(ids[2])
        row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event(" ", code: 49))
        XCTAssertTrue(fixture.model.state!.sheet.tasks[2].isComplete)
        XCTAssertEqual(fixture.model.selectedTask, ids[2])
        XCTAssertEqual(try PadStore(directory: fixture.root, today: "2026-10-12").state, fixture.model.state)
    }
    // TYPE-01/02: exercise the actual selected-row responder and native editor.
    @MainActor func testTypingStartsEditingAndRetainsBurstIncludingSpacesAndDigits() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let row = try await fixture.focusedRow()
        let ids = fixture.model.state!.sheet.tasks.map(\.id)
        row.keyDown(with: fixture.event("H", code: 4, flags: .shift))
        // These arrive before SwiftUI installs the editor, not after a render delay.
        row.keyDown(with: fixture.event("i", code: 34))
        row.keyDown(with: fixture.event(" ", code: 49))
        row.keyDown(with: fixture.event("7", code: 26))
        XCTAssertEqual(fixture.model.editingTask, ids[0])
        try await fixture.wait { fixture.model.state!.sheet.tasks[0].text == "Hi 7" }
        XCTAssertTrue(fixture.window.firstResponder is NSTextView)
        XCTAssertEqual(fixture.model.state!.sheet.tasks[0].priority.rawValue, 0)
        XCTAssertFalse(fixture.model.state!.sheet.tasks[0].isComplete)
        XCTAssertEqual(fixture.model.state!.sheet.tasks.map(\.id), ids)
        fixture.model.finishEditing()
        fixture.model.undo()
        XCTAssertTrue(fixture.model.state!.sheet.tasks[0].isBlank)
        fixture.model.redo()
        XCTAssertEqual(fixture.model.state!.sheet.tasks[0].text, "Hi 7")
        XCTAssertEqual(try PadStore(directory: fixture.root, today: "2026-10-12").state, fixture.model.state)
    }

    @MainActor func testTypingAppendsWithoutReplacingExistingTask() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let id = fixture.model.selectedTask!
        fixture.model.startEditing(id); fixture.model.changeText(id, text: "Merge"); fixture.model.finishEditing()
        let row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event("!", code: 18, flags: .shift))
        try await fixture.wait { fixture.model.state!.sheet.tasks[0].text == "Merge!" }
        fixture.model.finishEditing(); fixture.model.undo()
        XCTAssertEqual(fixture.model.state!.sheet.tasks[0].text, "Merge")
    }

    @MainActor func testBufferedTabSendsFollowingTextToNextSlot() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let row = try await fixture.focusedRow()
        let ids = fixture.model.state!.sheet.tasks.map(\.id)
        row.keyDown(with: fixture.event("a", code: 0))
        row.keyDown(with: fixture.event("\t", code: 48))
        row.keyDown(with: fixture.event("b", code: 11))
        try await fixture.wait { fixture.model.editingTask == ids[1] && fixture.model.state!.sheet.tasks[1].text == "b" }
        XCTAssertEqual(fixture.model.state!.sheet.tasks[0].text, "a")
        XCTAssertEqual(fixture.model.state!.sheet.tasks[1].text, "b")
    }

    @MainActor func testBufferedTabWithOneSlotKeepsFollowingTextInThatSlot() async throws {
        let fixture = try Fixture(slots: 1)
        defer { fixture.close() }
        let row = try await fixture.focusedRow()
        let id = fixture.model.selectedTask!
        row.keyDown(with: fixture.event("a", code: 0))
        row.keyDown(with: fixture.event("\t", code: 48))
        row.keyDown(with: fixture.event("b", code: 11))
        try await fixture.wait { fixture.model.state!.sheet.tasks[0].text == "ab" }
        XCTAssertEqual(fixture.model.editingTask, id)
        XCTAssertTrue(fixture.window.firstResponder is NSTextView)
        XCTAssertEqual(fixture.model.state!.sheet.tasks.map(\.id), [id])
        fixture.model.finishEditing()
        _ = try await fixture.focusedRow()
        XCTAssertEqual(fixture.model.state!.sheet.tasks[0].text, "ab")
        XCTAssertEqual(try PadStore(directory: fixture.root, today: "2026-10-12").state, fixture.model.state)
    }

    @MainActor func testBufferedFinishReturnsFollowingInputToRowShortcuts() async throws {
        for (text, code) in [("\r", UInt16(36)), ("\u{1b}", UInt16(53))] {
            let fixture = try Fixture()
            defer { fixture.close() }
            let row = try await fixture.focusedRow()
            row.keyDown(with: fixture.event("a", code: 0))
            row.keyDown(with: fixture.event(text, code: code))
            row.keyDown(with: fixture.event("9", code: 25))
            try await fixture.wait { fixture.model.state!.sheet.tasks[0].priority.rawValue == 9 }
            XCTAssertNil(fixture.model.editingTask)
            XCTAssertEqual(fixture.model.state!.sheet.tasks[0].text, "a")
        }
    }

    @MainActor func testBufferedShiftReturnStillInsertsNewline() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event("a", code: 0))
        row.keyDown(with: fixture.event("\r", code: 36, flags: .shift))
        row.keyDown(with: fixture.event("b", code: 11))
        try await fixture.wait { fixture.model.state!.sheet.tasks[0].text == "a\nb" }
        XCTAssertNotNil(fixture.model.editingTask)
    }

    // TYPE-03/04: first input uses native validation and native Undo, not a preload.
    @MainActor func testActivationCharacterParticipatesInNativeUndo() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event("a", code: 0))
        try await fixture.wait { fixture.model.state!.sheet.tasks[0].text == "a" }
        let editor = try XCTUnwrap(fixture.window.firstResponder as? NSTextView)
        XCTAssertTrue(editor.undoManager!.canUndo)
        editor.undoManager!.undo()
        XCTAssertEqual(editor.string, "")
        editor.undoManager!.redo()
        XCTAssertEqual(editor.string, "a")
    }

    @MainActor func testFirstTypedInputCannotBypassCharacterOrVisualLineLimits() async throws {
        for (original, insertion, expected, width) in [
            (String(repeating: "a", count: 499), "z", String(repeating: "a", count: 499) + "z", 1400.0),
            (String(repeating: "a", count: 500), "z", String(repeating: "a", count: 500), 1400.0),
            ("a\nb\nc\nd\ne", String(repeating: "word ", count: 35), "a\nb\nc\nd\ne", 420.0)
        ] {
            let fixture = try Fixture(width: width)
            defer { fixture.close() }
            let id = fixture.model.selectedTask!
            fixture.model.startEditing(id); fixture.model.changeText(id, text: original); fixture.model.finishEditing()
            let row = try await fixture.focusedRow()
            row.keyDown(with: fixture.event(insertion, code: 6))
            try await fixture.wait { original == expected ? fixture.model.message != nil : fixture.model.state!.sheet.tasks[0].text == expected }
            XCTAssertEqual(fixture.model.editingTask, id)
            XCTAssertEqual(fixture.model.state!.sheet.tasks[0].text, expected)
            XCTAssertEqual(try PadStore(directory: fixture.root, today: "2026-10-12").state, fixture.model.state)
        }
    }

    // TYPE-05: existing row shortcuts still win before text editing begins.
    @MainActor func testRowShortcutsDoNotStartTextEditing() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        var row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event("9", code: 25))
        XCTAssertEqual(fixture.model.state!.sheet.tasks[0].priority.rawValue, 9)
        row.keyDown(with: fixture.event(" ", code: 49))
        XCTAssertTrue(fixture.model.state!.sheet.tasks[0].isComplete)
        let first = fixture.model.state!.sheet.tasks[0].id
        fixture.model.select(first)
        row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event("\u{f702}", code: 123))
        XCTAssertFalse(fixture.model.state!.sheet.tasks[0].isComplete)
        let ids = fixture.model.state!.sheet.tasks.map(\.id)
        row.keyDown(with: fixture.event("\u{f700}", code: 126))
        XCTAssertEqual(fixture.model.selectedTask, ids[2])
        row = try await fixture.focusedRow()
        row.keyDown(with: fixture.event("\t", code: 48))
        XCTAssertEqual(fixture.model.selectedTask, ids[0])
        XCTAssertNil(fixture.model.editingTask)
    }

    @MainActor func testUnicodeInputWithoutPhysicalKeyCharactersStartsEditing() async throws {
        let fixture = try Fixture()
        defer { fixture.close() }
        let row = try await fixture.focusedRow()
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                    windowNumber: fixture.window.windowNumber, context: nil,
                                    characters: "é", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 0)!
        row.keyDown(with: event)
        try await fixture.wait { fixture.model.state!.sheet.tasks[0].text == "é" }
    }

    // GRID-01: compare actual rendered glyph pixels, not two matching formulas.
    @MainActor func testFirstLineDoesNotMoveWhenNativeEditorOpens() async throws {
        var fonts = ["System"]
        if NSFont(name: "MapleMono-NF-Regular", size: 16) != nil { fonts.append("MapleMono-NF-Regular") }
        for font in fonts {
            for size in [10.0, 16, 32] {
                let fixture = try Fixture(fontName: font, fontSize: size)
                defer { fixture.close() }
                let id = fixture.model.selectedTask!
                fixture.model.startEditing(id); fixture.model.changeText(id, text: "Agile"); fixture.model.finishEditing()
                _ = try await fixture.focusedRow()
                let before = try fixture.glyphRows()
                fixture.model.startEditing(id)
                try await fixture.wait { fixture.window.firstResponder is NSTextView }
                let after = try fixture.glyphRows()
                XCTAssertEqual(after, before, "Opening the editor must not move \(font) \(size) text vertically")
                let editor = try XCTUnwrap(fixture.window.firstResponder as? NSTextView)
                editor.keyDown(with: fixture.event("!", code: 18, flags: .shift))
                try await fixture.wait { fixture.model.state!.sheet.tasks[0].text == "Agile!" }
                XCTAssertEqual(try fixture.glyphRows(), before)
                fixture.model.finishEditing()
                _ = try await fixture.focusedRow()
                XCTAssertEqual(try fixture.glyphRows(), before)
            }
        }
    }

    @MainActor func testMultilineEditorKeepsFirstLineAndRuledLinePitch() async throws {
        for (font, size) in ["System", "MapleMono-NF-Regular"].flatMap({ font in [10.0, 16, 32].map { (font, $0) } }) {
            if font != "System" && NSFont(name: font, size: size) == nil { continue }
            let fixture = try Fixture(fontName: font, fontSize: size)
            defer { fixture.close() }
            let id = fixture.model.selectedTask!
            fixture.model.startEditing(id); fixture.model.changeText(id, text: "Agile\nAgile"); fixture.model.finishEditing()
            _ = try await fixture.focusedRow()
            let first = try fixture.glyphRows()
            let second = try fixture.glyphRows(line: 1)
            fixture.model.startEditing(id)
            try await fixture.wait { fixture.window.firstResponder is NSTextView }
            XCTAssertEqual(try fixture.glyphRows(), first)
            XCTAssertEqual(try fixture.glyphRows(line: 1), second)
            let scale = CGFloat(fixture.window.contentView!.bitmapImageRepForCachingDisplay(in: fixture.window.contentView!.bounds)!.pixelsWide) / fixture.window.contentView!.bounds.width
            XCTAssertEqual(second.first! - first.first!, Int(fixture.model.settings.rowHeight * scale))
        }
    }

    @MainActor private final class Fixture {
        let root: URL
        let model: AppModel
        let window: NSWindow
        init(fontName: String = "System", fontSize: Double = 16, width: Double = 420, slots: Int = 3) throws {
            _ = NSApplication.shared
            root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-row-typing-\(UUID())")
            model = AppModel(directory: root, dateProvider: { "2026-10-12" })
            var settings = model.settings; settings.slotLimit = slots; settings.header.visible = false
            settings.fontName = fontName; settings.fontSize = fontSize
            guard model.applySettings(settings) else { throw PadError.invalidData }
            window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 500), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PadView(model: model))
            window.contentView?.layoutSubtreeIfNeeded()
        }
        func close() { window.close(); try? FileManager.default.removeItem(at: root) }
        func glyphRows(line: Int = 0) throws -> [Int] {
            let view = try XCTUnwrap(window.contentView)
            view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
            let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let scale = CGFloat(bitmap.pixelsWide) / view.bounds.width
            var rows: [Int] = []
            for y in Int(CGFloat(line) * model.settings.rowHeight * scale)..<Int(CGFloat(line + 1) * model.settings.rowHeight * scale) {
                for x in Int(68 * scale)..<Int(110 * scale) {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                    if color.alphaComponent > 0.5 && max(color.redComponent, color.greenComponent, color.blueComponent) < 0.5 {
                        rows.append(y); break
                    }
                }
            }
            XCTAssertFalse(rows.isEmpty, "The native capture must include the task glyphs")
            return rows
        }
        func event(_ text: String, code: UInt16, flags: NSEvent.ModifierFlags = []) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                            windowNumber: window.windowNumber, context: nil, characters: text,
                            charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
        }
        func focusedRow() async throws -> RowKeyView {
            try await Task.sleep(nanoseconds: 10_000_000)
            try await wait { self.window.firstResponder is RowKeyView }
            return try XCTUnwrap(window.firstResponder as? RowKeyView)
        }
        func wait(_ condition: () -> Bool) async throws {
            for _ in 0..<100 {
                window.contentView?.layoutSubtreeIfNeeded()
                if condition() { return }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            XCTFail("Native responder transition did not reach the expected state")
            throw PadError.invalidData
        }
    }
}
