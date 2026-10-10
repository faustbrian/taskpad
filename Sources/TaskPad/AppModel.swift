import AppKit
import SwiftUI
import TaskPadCore

@MainActor
final class AppModel: ObservableObject {
    @Published var state: PadState?
    @Published var loadError: String?
    @Published var message: String?
    @Published var unsaved = false
    @Published var showRollover = false
    @Published var showSettings = false
    @Published var editingTask: UUID?
    @Published var editingNotes = false
    @Published var selectedTask: UUID?
    private var store: PadStore?
    private var editingBefore: PadSheet?
    private let undoManager = UndoManager()
    private let dateProvider: () -> String
    let directory: URL
    var sheetWidth: CGFloat = 420
    var settings: PadSettings { state?.settings ?? PadSettings() }
    var today: String { dateProvider() }
    var theme: PadTheme { state?.theme ?? .karst }
    var canEdit: Bool { state != nil && state?.draft == nil && !showRollover }
    var activeUndoManager: UndoManager? {
        if let editor = NSApp?.keyWindow?.firstResponder as? NSTextView, editor.isEditable { return editor.undoManager }
        return canEdit ? undoManager : nil
    }
    func undo() { activeUndoManager?.undo(); objectWillChange.send() }
    func redo() { activeUndoManager?.redo(); objectWillChange.send() }

    init(directory suppliedDirectory: URL? = nil, dateProvider: @escaping () -> String = { PadDay.local() }) {
        self.dateProvider = dateProvider; undoManager.groupsByEvent = false
        if let suppliedDirectory { directory = suppliedDirectory }
        else if let path = ProcessInfo.processInfo.environment["TASKPAD_DATA_DIR"] ?? Bundle.main.object(forInfoDictionaryKey: "TaskPadSmokeDataDirectory") as? String {
            directory = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TaskPad", isDirectory: true)
        }
        reload()
    }
    func reload() {
        do {
            let opened = try PadStore(directory: directory, today: today)
            store = opened; state = opened.state; loadError = nil
            selectedTask = opened.state.sheet.tasks.first?.id
            showRollover = opened.state.draft != nil
            checkDay()
        } catch { loadError = error.localizedDescription }
    }
    private func save(_ candidate: PadState) {
        do {
            guard let store else { throw PadError.invalidData }
            try candidate.validate(); try store.save(candidate)
            state = candidate; unsaved = false; message = nil
        } catch { state = candidate; unsaved = true; message = "Not saved. \(error.localizedDescription)" }
    }
    func retrySave() { guard let state else { return }; save(state); if !unsaved { checkDay() } }
    func editSheet(_ name: String, undo: Bool = true, _ edit: (inout PadSheet) throws -> Void) {
        guard canEdit, var next = state else { return }; let before = next.sheet
        do {
            try edit(&next.sheet); try next.validate(); save(next)
            if undo, before != next.sheet { registerUndo(before, name: name) }
        } catch { message = error.localizedDescription }
    }
    private func registerUndo(_ sheet: PadSheet, name: String) {
        let ordinary = !undoManager.isUndoing && !undoManager.isRedoing
        if ordinary { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { model in
            guard model.state?.sheet.id == sheet.id, model.state?.sheet.day == sheet.day,
                  sheet.tasks.count == model.settings.slotLimit else { return }
            model.editSheet(name) { $0 = sheet }
        }
        undoManager.setActionName(name); if ordinary { undoManager.endUndoGrouping() }
    }
    func select(_ id: UUID) {
        guard canEdit, state?.sheet.tasks.contains(where: { $0.id == id }) == true else { return }
        if editingTask != id { finishEditing() }; selectedTask = id
    }
    func navigate(_ offset: Int, editing: Bool = false) {
        guard canEdit, let tasks = state?.sheet.tasks, !tasks.isEmpty else { return }
        let current = selectedTask.flatMap { id in tasks.firstIndex(where: { $0.id == id }) } ?? 0
        let next = tasks[(current + offset + tasks.count) % tasks.count].id
        finishEditing(); selectedTask = next
        if editing { startEditing(next) }
    }
    func startEditing(_ id: UUID) {
        guard canEdit, state?.sheet.tasks.contains(where: { $0.id == id }) == true else { return }
        if editingTask == id { return }; finishEditing()
        editingBefore = state?.sheet; editingTask = id; selectedTask = id
    }
    func startNotes() {
        guard canEdit, settings.notesEnabled else { return }; finishEditing(); editingBefore = state?.sheet; editingNotes = true
    }
    func changeText(_ id: UUID, text: String) {
        let original = state?.sheet.tasks.first(where: { $0.id == id })?.text ?? ""
        guard TaskInput.allowsChange(from: original, to: text) else { message = PadError.taskTooLong.localizedDescription; return }
        editSheet("Edit Task", undo: false) { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }; sheet.tasks[index].text = text
        }
    }
    func changeNotes(_ text: String) { editSheet("Edit Notes", undo: false) { $0.notes = text } }
    func finishEditing() {
        let before = editingBefore; editingBefore = nil; editingTask = nil; editingNotes = false
        if let before, before != state?.sheet { registerUndo(before, name: "Edit Text") }
    }
    func toggle(_ id: UUID) {
        finishEditing(); selectedTask = id
        editSheet("Toggle Task") { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }; sheet.tasks[index].isComplete.toggle()
        }
    }
    func delete(_ id: UUID) {
        finishEditing(); selectedTask = id
        editSheet("Clear Slot") { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }
            let scheduleID = sheet.tasks[index].scheduleID, time = sheet.tasks[index].scheduledTime
            sheet.tasks[index].clear(); sheet.tasks[index].scheduleID = scheduleID; sheet.tasks[index].scheduledTime = time
        }
    }
    func move(_ id: UUID, offset: Int) { finishEditing(); editSheet("Move Task") { try $0.move(id, offset: offset) }; selectedTask = id }
    func move(_ id: UUID, to destination: UUID) { finishEditing(); editSheet("Move Task") { try $0.move(id, to: destination) }; selectedTask = id }
    func setPriority(_ id: UUID, _ value: TaskPriority) {
        guard (0...9).contains(value.rawValue) else { return }; finishEditing()
        editSheet("Change Priority") { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }; sheet.tasks[index].priority = value
        }
    }
    func setColor(_ id: UUID, _ value: TaskColor?) {
        finishEditing(); editSheet("Change Ink") { sheet in
            guard let index = sheet.tasks.firstIndex(where: { $0.id == id }) else { return }; sheet.tasks[index].color = value
        }
    }
    func setTheme(_ value: PadTheme) { guard var next = state else { return }; finishEditing(); next = state!; next.theme = value; save(next) }
    @discardableResult func applySettings(_ value: PadSettings, theme selectedTheme: PadTheme? = nil) -> Bool {
        guard let store, !unsaved else { message = "Save pending edits before changing settings."; return false }
        finishEditing()
        guard !unsaved else { return false }
        do {
            // A rule is another task entry surface, not an escape from the row bound.
            let existing = Dictionary(uniqueKeysWithValues: settings.schedules.map { ($0.id, $0.text) })
            for rule in value.schedules where existing[rule.id] != rule.text {
                let width = max(40, sheetWidth - (selectedTheme ?? theme).textInset - 24 - 48 - (rule.priority.rawValue == 0 ? 0 : 24))
                guard TaskLayout.lines(rule.text, width: width, font: value.nativeFont) <= TaskInput.maxLines else { throw PadError.taskTooLong }
            }
            var candidate = try store.settingsCandidate(value)
            if let selectedTheme { candidate.theme = selectedTheme }
            save(candidate)
            undoManager.removeAllActions()
            if candidate.sheet.tasks.contains(where: { $0.id == selectedTask }) == false { selectedTask = candidate.sheet.tasks.first?.id }
            return !unsaved
        } catch { message = error.localizedDescription; return false }
    }
    func checkDay() {
        guard !unsaved, let store, let state, today > state.sheet.day else { return }
        finishEditing(); guard !unsaved else { return }
        do { try store.beginRollover(to: today); syncTransition(from: state.sheet.id) }
        catch { self.state = store.state; showRollover = store.state.draft != nil; message = error.localizedDescription }
    }
    private func syncTransition(from id: UUID) {
        guard let store else { return }; state = store.state; showRollover = store.state.draft != nil
        if store.state.sheet.id != id { editingTask = nil; selectedTask = store.state.sheet.tasks.first?.id; undoManager.removeAllActions() }
    }
    func editDraft(_ edit: (inout RolloverDraft) -> Void) {
        guard var next = state, var draft = next.draft else { return }; edit(&draft); next.draft = draft; save(next)
    }
    func confirmRollover() {
        guard !unsaved, let store, let id = state?.sheet.id else { return }
        do { try store.confirmRollover(to: today); syncTransition(from: id); message = nil }
        catch { message = "The previous sheet is still safe. \(error.localizedDescription)" }
    }
}
