import SwiftUI
import AppKit

@main
struct TaskPadApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Window("TaskPad", id: "TaskPad") {
            PadView(model: model).background(WindowSetup(title: model.settings.windowTitle)).onAppear { delegate.model = model }
        }
        .defaultSize(width: 420, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.undo() }.keyboardShortcut("z")
                    .disabled(model.activeUndoManager?.canUndo != true)
                Button("Redo") { model.redo() }.keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(model.activeUndoManager?.canRedo != true)
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appSettings) {
                SettingsMenuButton(model: model)
            }
            CommandMenu("Sheet") {
                Button("Edit Selected Task") { if let id = model.selectedTask { model.startEditing(id) } }
                    .keyboardShortcut("e").disabled(!model.canUseSheetCommands || model.selectedTask == nil)
                Button("Complete / Uncomplete") { if let id = model.selectedTask { model.toggle(id) } }
                    .keyboardShortcut(.return).disabled(!model.canUseSheetCommands || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Button("Clear Selected Slot") { if let id = model.selectedTask { model.delete(id) } }
                    .keyboardShortcut(.delete).disabled(!model.canUseSheetCommands || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Button("Move Task Up") { if let id = model.selectedTask { model.move(id, offset: -1) } }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command]).disabled(!model.canUseSheetCommands || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Button("Move Task Down") { if let id = model.selectedTask { model.move(id, offset: 1) } }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command]).disabled(!model.canUseSheetCommands || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Divider()
                Button("Edit Notes") { model.startNotes() }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(!model.canUseSheetCommands || !model.settings.notesEnabled)
            }
        }
        Settings {
            PadSettingsView(model: model)
        }
        .defaultSize(width: 780, height: 680)
        .windowResizability(.contentMinSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model, model.unsaved else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Your latest changes haven’t been saved"
        alert.informativeText = "Keep the pad open to retry saving, or explicitly quit without these changes. The last saved sheet is still on disk."
        alert.addButton(withTitle: "Keep Open")
        alert.addButton(withTitle: "Retry Save")
        alert.addButton(withTitle: "Quit Without Saving")
        let result = alert.runModal()
        if result == .alertSecondButtonReturn {
            model.retrySave()
            return model.unsaved ? .terminateCancel : .terminateNow
        }
        return result == .alertThirdButtonReturn ? .terminateNow : .terminateCancel
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first(where: { $0.identifier?.rawValue == "TaskPad" || $0.title == "TaskPad" })?.makeKeyAndOrderFront(nil) }
        return true
    }
}

struct WindowSetup: NSViewRepresentable {
    var title: String
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.title = title
            guard window.frameAutosaveName.isEmpty else { return }
            window.setFrameAutosaveName("TaskPadWindow")
            window.setFrameUsingName("TaskPadWindow")
        }
    }
}
