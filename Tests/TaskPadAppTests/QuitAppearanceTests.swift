import XCTest
import AppKit
import TaskPadCore
@testable import TaskPad

final class QuitAppearanceTests: XCTestCase {
    @MainActor func testUnsavedQuitUsesSavedAppearanceAndKeepsChanges() throws {
        let app = NSApplication.shared
        let originalAppearance = app.appearance
        defer { app.appearance = originalAppearance }
        for host in [NSAppearance.Name.aqua, .darkAqua] {
            app.appearance = NSAppearance(named: host)
            for mode in PadAppearance.allCases {
                let root = FileManager.default.temporaryDirectory.appendingPathComponent("TaskPad-quit-\(UUID())")
                defer { try? FileManager.default.removeItem(at: root) }
                let model = AppModel(directory: root, dateProvider: { "2026-10-12" })
                var settings = model.settings; settings.appearance = mode
                XCTAssertTrue(model.applySettings(settings))
                let active = root.appendingPathComponent("active.json")
                let backup = root.appendingPathComponent("last-good.json")
                let durable = try Data(contentsOf: active)
                try FileManager.default.moveItem(at: active, to: backup)
                try FileManager.default.createDirectory(at: active, withIntermediateDirectories: false)
                model.toggle(model.selectedTask!)
                XCTAssertTrue(model.unsaved)
                let candidate = model.state
                let delegate = AppDelegate(); delegate.model = model
                var observed: NSAppearance.Name?
                let timer = Timer(timeInterval: 0.02, repeats: false) { _ in
                    MainActor.assumeIsolated {
                        observed = app.modalWindow?.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
                        app.stopModal(withCode: .alertFirstButtonReturn)
                    }
                }
                RunLoop.main.add(timer, forMode: .modalPanel)
                defer { timer.invalidate() }
                XCTAssertEqual(delegate.applicationShouldTerminate(app), .terminateCancel)
                let expected: NSAppearance.Name = mode == .system ? host : (mode == .light ? .aqua : .darkAqua)
                XCTAssertEqual(observed, expected, "\(mode) under \(host)")
                XCTAssertTrue(model.unsaved)
                XCTAssertEqual(model.state, candidate)
                XCTAssertEqual(try Data(contentsOf: backup), durable)
                XCTAssertNil(app.modalWindow)
            }
        }
    }
}
