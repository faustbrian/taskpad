import SwiftUI
import AppKit

@main
struct TaskpadApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Window("Taskpad", id: "taskpad") {
            PadView(model: model).background(WindowSetup()).onAppear { delegate.model = model }
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
            CommandGroup(replacing: .newItem) {
                Button("New Task") { model.addTask() }.keyboardShortcut("n").disabled(!model.canEdit)
            }
            CommandMenu("Sheet") {
                Button("Edit Selected Task") { if let id = model.selectedTask { model.startEditing(id) } }
                    .keyboardShortcut("e").disabled(!model.canEdit || model.selectedTask == nil)
                Button("Complete / Uncomplete") { if let id = model.selectedTask { model.toggle(id) } }
                    .keyboardShortcut(.return).disabled(!model.canEdit || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Button("Delete Selected Task") { if let id = model.selectedTask { model.delete(id) } }
                    .keyboardShortcut(.delete).disabled(!model.canEdit || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Button("Move Task Up") { if let id = model.selectedTask { model.move(id, offset: -1) } }
                    .keyboardShortcut(.upArrow, modifiers: [.option, .command]).disabled(!model.canEdit || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Button("Move Task Down") { if let id = model.selectedTask { model.move(id, offset: 1) } }
                    .keyboardShortcut(.downArrow, modifiers: [.option, .command]).disabled(!model.canEdit || model.selectedTask == nil || model.editingTask != nil || model.editingNotes)
                Divider()
                Button("Edit Notes") { model.startNotes() }.keyboardShortcut("n", modifiers: [.command, .shift]).disabled(!model.canEdit)
            }
        }
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
        if !flag { sender.windows.first(where: { $0.identifier?.rawValue == "taskpad" || $0.title == "Taskpad" })?.makeKeyAndOrderFront(nil) }
        return true
    }
}

struct WindowSetup: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window, window.frameAutosaveName.isEmpty else { return }
            window.setFrameAutosaveName("TaskpadWindow")
            window.setFrameUsingName("TaskpadWindow")
        }
    }
}
