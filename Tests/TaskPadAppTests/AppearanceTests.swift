import XCTest
import AppKit
import SwiftUI
import TaskPadCore
@testable import TaskPad

final class AppearanceTests: XCTestCase {
    @MainActor func testSystemUpdatesAnAlreadyHostedPadWithoutChangingSavedTheme() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-live-appearance-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
        let before = model.state
        let system = HostScheme()
        let host = NSHostingView(rootView: SystemPad(model: model, system: system))
        host.frame = NSRect(x: 0, y: 0, width: 420, height: 500)
        func brightness() throws -> CGFloat {
            host.layoutSubtreeIfNeeded()
            let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: bitmap)
            let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
            let color = try XCTUnwrap(bitmap.colorAt(x: Int(400 * scale), y: Int(450 * scale))?.usingColorSpace(.deviceRGB))
            return (color.redComponent + color.greenComponent + color.blueComponent) / 3
        }
        XCTAssertGreaterThan(try brightness(), 0.9)
        system.scheme = .dark
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertLessThan(try brightness(), 0.25)
        system.scheme = .light
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertGreaterThan(try brightness(), 0.9)
        XCTAssertEqual(model.state, before)
        XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, before)
    }

    func testPaletteTextAndBadgesStayReadableOnSelectedScheduledRows() {
        func components(_ color: NSColor) -> [CGFloat] {
            let rgb = color.usingColorSpace(.sRGB)!
            return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
        }
        func luminance(_ rgb: [CGFloat]) -> CGFloat {
            let linear = rgb.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        for theme in PadTheme.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let palette = theme.palette(for: scheme)
                let accent = components(palette.nativeAccent)
                for selection in [CGFloat(0), 0.08, 0.14] {
                    let opacity = 1 - (1 - selection) * (1 - 0.045)
                    let paper = zip(components(palette.nativePaper), accent).map { $0 * (1 - opacity) + $1 * opacity }
                    for color in [palette.nativeInk, palette.nativeAccent] + TaskColor.allCases.map({ palette.nativeTaskInk($0) }) {
                        let a = luminance(components(color)), b = luminance(paper)
                        XCTAssertGreaterThanOrEqual((max(a, b) + 0.05) / (min(a, b) + 0.05), 4.5, "\(theme) \(scheme) selection \(selection)")
                    }
                }
            }
        }
    }
    @MainActor func testIndependentEnablementRestoresStoredMetadataAndActions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-visibility-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-12")
        var settings = store.state.settings
        var rule = RepeatTask(text: "Scheduled"); rule.priority = .high; rule.effort = 7
        settings.schedules = [rule]; try store.applySettings(settings)
        try store.editSheet { $0.tasks[0].text = "Edited scheduled occurrence" }
        let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
        let original = model.state!.sheet
        for priority in [false, true] {
            for effort in [false, true] {
                var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(model.settings)) as! [String: Any]
                object["priorityEnabled"] = priority; object["effortEnabled"] = effort
                let choice = try JSONDecoder().decode(PadSettings.self, from: JSONSerialization.data(withJSONObject: object))
                XCTAssertTrue(model.applySettings(choice))
                let task = model.state!.sheet.tasks[0]
                let actions = slotActions(task, model: model)
                XCTAssertEqual(actions.contains { $0.id == "p9" && $0.selected }, priority)
                XCTAssertEqual(actions.contains { $0.id == "effort-7" && $0.selected }, effort)
                let width = 420 - 68 - 24 - choice.scheduledBadgeWidth
                    - (priority ? choice.priorityBadgeWidth(task.priority) : 0)
                    - (effort ? choice.effortBadgeWidth(7) : 0)
                XCTAssertEqual(choice.taskTextWidth(task, sheetWidth: 420, theme: .karst), width)
                XCTAssertEqual(model.state!.sheet, original)
                XCTAssertEqual(model.settings.schedules, [rule])
                XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, model.state)
            }
        }
    }
    @MainActor func testDisabledMetadataHasNoActionsOrWidthAndCannotBeChanged() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-appearance-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try PadStore(directory: root, today: "2026-10-12")
        try store.editSheet { $0.tasks[0].text = "Keep me"; $0.tasks[0].priority = .high; $0.tasks[0].effort = 7 }
        let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
        let task = model.state!.sheet.tasks[0]
        let actions = slotActions(task, model: model)
        XCTAssertFalse(actions.contains { $0.id.count == 2 && $0.id.first == "p" || $0.id.hasPrefix("effort") })
        XCTAssertTrue(actions.contains { $0.id == "blue" })
        XCTAssertEqual(model.settings.taskTextWidth(task, sheetWidth: 420, theme: .karst), 328)
        model.setPriority(task.id, .none); model.setEffort(task.id, nil)
        XCTAssertEqual(model.state!.sheet.tasks[0], task)
        XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, model.state)
    }

    @MainActor func testEveryThemeRendersBothAppearancesAndSystemTracksEnvironment() throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-palette-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
        for name in ["karst", "anoto", "things", "todoist", "ticktick", "linear", "raycast"] {
            let theme = try JSONDecoder().decode(PadTheme.self, from: Data("\"\(name)\"".utf8))
            for mode in ["light", "dark", "system"] {
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(model.settings)) as? [String: Any])
                object["appearance"] = mode
                let settings = try JSONDecoder().decode(PadSettings.self, from: JSONSerialization.data(withJSONObject: object))
                XCTAssertTrue(model.applySettings(settings, theme: theme))
                XCTAssertEqual(try PadStore(directory: root, today: "2026-10-12").state, model.state)
                for system in [ColorScheme.light, .dark] {
                    let host = NSHostingView(rootView: PadView(model: model).environment(\.colorScheme, system))
                    host.frame = NSRect(x: 0, y: 0, width: 420, height: 500)
                    host.layoutSubtreeIfNeeded()
                    let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
                    let paper = try XCTUnwrap(bitmap.colorAt(x: Int(400 * scale), y: Int(450 * scale))?.usingColorSpace(.deviceRGB))
                    let dark = mode == "dark" || (mode == "system" && system == .dark)
                    let brightness = (paper.redComponent + paper.greenComponent + paper.blueComponent) / 3
                    if dark { XCTAssertLessThan(brightness, 0.25, "\(name) \(mode) \(system)") }
                    else { XCTAssertGreaterThan(brightness, 0.9, "\(name) \(mode) \(system)") }
                }
            }
        }
    }
}

@MainActor private final class HostScheme: ObservableObject {
    @Published var scheme: ColorScheme = .light
}

private struct SystemPad: View {
    let model: AppModel
    @ObservedObject var system: HostScheme
    var body: some View { PadView(model: model).environment(\.colorScheme, system.scheme) }
}
