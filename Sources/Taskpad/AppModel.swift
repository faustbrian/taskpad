import AppKit
import SwiftUI
import TaskpadCore

@MainActor
final class AppModel: ObservableObject {
    @Published var state: PadState?
    @Published var loadError: String?
    @Published var message: String?
    @Published var unsaved = false
    @Published var showRollover = false
    @Published var editingTask: UUID?
    @Published var editingNotes = false
    @Published var selectedTask: UUID?
    private var store: PadStore?
    private var editingBefore: PadSheet?
    private let undoManager = UndoManager()
    private let dateProvider: () -> String
    var activeUndoManager: UndoManager? {
        if let editor = NSApp?.keyWindow?.firstResponder as? NSTextView, editor.isEditable { return editor.undoManager }
        return canEdit ? undoManager : nil
    }
    func undo() { activeUndoManager?.undo(); objectWillChange.send() }
    func redo() { activeUndoManager?.redo(); objectWillChange.send() }
    let directory: URL

    init(directory suppliedDirectory: URL? = nil, dateProvider: @escaping () -> String = { PadDay.local() }) {
        self.dateProvider = dateProvider
        undoManager.groupsByEvent = false
        // Explicitly scoped smoke-test storage; ordinary launches never use it.
        if let suppliedDirectory {
            directory = suppliedDirectory
        } else if let path = ProcessInfo.processInfo.environment["TASKPAD_DATA_DIR"] ?? Bundle.main.object(forInfoDictionaryKey: "TaskpadSmokeDataDirectory") as? String {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Taskpad", isDirectory: true)
        }
        reload()
    }
    var today: String { dateProvider() }
    var theme: PadTheme { state?.theme ?? .karst }
    var canEdit: Bool { state != nil && state?.draft == nil && !showRollover }

    func reload() {
        do {
            let opened = try PadStore(directory: directory, today: today)
            store = opened
            state = opened.state
            loadError = nil
            checkDay()
        } catch { loadError = error.localizedDescription }
    }

    private func save(_ candidate: PadState) {
        do {
            try candidate.validate()
            try store?.save(candidate)
            state = candidate
            unsaved = false
            message = nil
        } catch {
            // Keep the visible candidate recoverable; never claim it was saved.
            state = candidate
            unsaved = true
            message = "Not saved. \(error.localizedDescription)"
        }
    }
    func retrySave() {
        guard let state else { return }
        save(state)
        if !unsaved { checkDay() }
    }

    func editSheet(_ name: String, undo: Bool = true, _ edit: (inout PadSheet) throws -> Void) {
        guard canEdit, var next = state else { return }
        let before = next.sheet
        do {
            try edit(&next.sheet)
            try next.validate()
            save(next)
            if undo, before != next.sheet { registerUndo(before, name: name) }
        } catch { message = error.localizedDescription }
    }

    private func registerUndo(_ sheet: PadSheet, name: String) {
        let isOrdinaryAction = !undoManager.isUndoing && !undoManager.isRedoing
        if isOrdinaryAction { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { model in
            guard model.state?.sheet.id == sheet.id, model.state?.sheet.day == sheet.day else { return }
            model.editSheet(name) { $0 = sheet }
        }
        undoManager.setActionName(name)
        if isOrdinaryAction { undoManager.endUndoGrouping() }
    }

    func addTask() {
        guard canEdit, let state else { return }
        guard state.sheet.tasks.count < 30 else { message = PadError.capacity.localizedDescription; return }
        finishEditing()
        let task = PadTask(text: "")
        editSheet("Add Task") { $0.tasks.append(task) }
        startEditing(task.id)
    }
    func startEditing(_ id: UUID) {
        guard canEdit else { return }
        finishEditing()
        editingBefore = state?.sheet
        editingTask = id
        selectedTask = id
    }
    func startNotes() {
        guard canEdit else { return }
        finishEditing()
        editingBefore = state?.sheet
        editingNotes = true
    }
    func changeText(_ id: UUID, text: String) {
        editSheet("Edit Task", undo: false) { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }
            sheet.tasks[index].text = text
        }
    }
    func changeNotes(_ text: String) { editSheet("Edit Notes", undo: false) { $0.notes = text } }
    func finishEditing() {
        let before = editingBefore
        editingBefore = nil
        let id = editingTask
        editingTask = nil
        editingNotes = false
        if let id, state?.sheet.tasks.first(where: { $0.id == id })?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            editSheet("Remove Empty Task", undo: false) { $0.tasks.removeAll { $0.id == id } }
        }
        if let before, before != state?.sheet { registerUndo(before, name: "Edit Text") }
    }
    func toggle(_ id: UUID) {
        finishEditing()
        editSheet("Complete Task") { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }
            sheet.tasks[index].isComplete.toggle()
        }
    }
    func delete(_ id: UUID) {
        finishEditing()
        editSheet("Delete Task") { $0.tasks.removeAll { $0.id == id } }
        selectedTask = state?.sheet.tasks.first?.id
    }
    func move(_ id: UUID, offset: Int) {
        finishEditing()
        editSheet("Move Task") { try $0.move(id, offset: offset) }
    }
    func setPriority(_ id: UUID, _ value: TaskPriority) {
        finishEditing()
        editSheet("Change Priority") { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }
            sheet.tasks[index].priority = value
        }
    }
    func setColor(_ id: UUID, _ value: TaskColor?) {
        finishEditing()
        editSheet("Change Color") { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }
            sheet.tasks[index].color = value
        }
    }
    func setTheme(_ value: PadTheme) {
        guard var next = state else { return }
        next.theme = value
        save(next)
    }
    func checkDay() {
        guard !unsaved, let store, let state else { return }
        guard today > state.sheet.day else { return }
        finishEditing()
        guard !unsaved else { return }
        do {
            try store.beginRollover(to: today)
            self.state = store.state
            showRollover = store.state.draft != nil
        } catch { message = error.localizedDescription }
    }
    func editDraft(_ edit: (inout RolloverDraft) -> Void) {
        guard var next = state, var draft = next.draft else { return }
        edit(&draft)
        next.draft = draft
        save(next)
    }
    func confirmRollover() {
        guard !unsaved, let store else { return }
        do {
            try store.confirmRollover(to: today)
            state = store.state
            editingTask = nil
            selectedTask = nil
            undoManager.removeAllActions()
            showRollover = false
            message = nil
        } catch { message = "The previous sheet is still safe. \(error.localizedDescription)" }
    }
}
