import SwiftUI
import TaskpadCore

struct PadView: View {
    @ObservedObject var model: AppModel
    @FocusState private var focusedTask: UUID?

    var body: some View {
        VStack(spacing: 0) {
            if let state = model.state {
                header(state)
                if let message = model.message {
                    HStack(alignment: .top) {
                        Text(message).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        if model.unsaved { Button("Retry") { model.retrySave() } }
                        else { Button("Dismiss") { model.message = nil } }
                    }
                    .padding(12).background(Color(red: 0.99, green: 0.91, blue: 0.78))
                }
                if state.draft != nil && !model.showRollover {
                    HStack {
                        Text("Your new-day decision is waiting.").font(.system(size: 12))
                        Spacer()
                        Button("Continue") { model.showRollover = true }
                    }.padding(12).background(model.theme.rule)
                }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(state.sheet.tasks) { task in taskRow(task) }
                        if model.canEdit {
                            Button { model.addTask() } label: {
                                HStack {
                                    Image(systemName: "plus").frame(width: 20)
                                    Text(state.sheet.tasks.count == 30 ? "Sheet full — 30 tasks" : "Add a task…")
                                        .font(model.theme.font)
                                    Spacer()
                                }.foregroundStyle(model.theme.ink.opacity(0.68)).padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            .keyboardShortcut(model.editingTask == nil && !model.editingNotes && model.selectedTask == nil
                                              ? KeyboardShortcut(.return, modifiers: []) : nil)
                            .help("Add task (Return when no task is selected, or ⌘N)")
                            .accessibilityLabel("Add task")
                            .padding(.horizontal, 20)
                        }
                        Canvas { context, size in
                            for y in stride(from: CGFloat(44), through: size.height, by: 44) {
                                var path = Path()
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                                context.stroke(path, with: .color(model.theme.rule), lineWidth: 1)
                            }
                        }
                        .frame(height: CGFloat(max(0, 8 - state.sheet.tasks.count)) * 44)
                        .accessibilityHidden(true)
                        notes(state.sheet.notes)
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, minHeight: 550, alignment: .top)
                    .background {
                        if model.theme == .notepad {
                            Rectangle().fill(Color(red: 0.72, green: 0.30, blue: 0.28).opacity(0.50))
                                .frame(width: 1).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 50)
                        }
                    }
                }
                .disabled(!model.canEdit)
                HStack {
                    Text("\(state.sheet.tasks.count) / 30").monospacedDigit()
                    Spacer()
                    if model.editingTask != nil || model.editingNotes {
                        Text("Return to finish · ⇧Return for a new line")
                    } else { Text("One sheet. Just today.") }
                }
                .font(.system(size: 10)).foregroundStyle(model.theme.ink.opacity(0.65))
                .padding(.horizontal, 20).padding(.vertical, 10)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Couldn’t open your task pad").font(.title2)
                    Text(model.loadError ?? "Your existing data has not been changed.")
                    Button("Try again") { model.reload() }
                }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(model.theme.ink)
        .background(model.theme.paper)
        .preferredColorScheme(.light)
        .frame(minWidth: 360, minHeight: 480)
        .sheet(isPresented: $model.showRollover) { RolloverView(model: model) }
        .onChange(of: focusedTask) { _, id in model.selectedTask = id }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.checkDay() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in model.checkDay() }
    }

    private func header(_ state: PadState) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                if state.theme == .karst {
                    Text("TASKPAD").font(.system(size: 11, weight: .medium, design: .monospaced)).tracking(3)
                    Text("What matters today?").font(.system(size: 22, weight: .medium))
                } else {
                    Text("Today’s sheet").font(.system(size: 24, weight: .medium, design: .serif))
                }
                Text(displayDay(state.sheet.day)).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(1)
                    .opacity(0.75)
            }
            Spacer()
            Menu {
                ForEach(PadTheme.allCases, id: \.self) { theme in
                    Button {
                        model.setTheme(theme)
                    } label: { Text((state.theme == theme ? "✓ " : "") + theme.rawValue.capitalized) }
                }
            } label: {
                Image(systemName: "slider.horizontal.3").font(.system(size: 15))
                    .foregroundStyle(state.theme == .karst ? Color.white : model.theme.ink)
            }
            .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Choose theme")
            .environment(\.colorScheme, state.theme == .karst ? .dark : .light)
            .help("Choose Karst or Notepad")
        }
        .padding(24)
        .foregroundStyle(state.theme == .karst ? Color.white : model.theme.ink)
        .background(state.theme == .karst ? Color(red: 0.10, green: 0.11, blue: 0.11) : model.theme.paper)
        .overlay(alignment: .bottom) { Rectangle().fill(model.theme.rule).frame(height: 1) }
    }

    private func taskRow(_ task: PadTask) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Button { model.toggle(task.id) } label: {
                ZStack {
                    if model.theme == .karst { Circle().strokeBorder(model.theme.ink.opacity(0.6), lineWidth: 1) }
                    else { RoundedRectangle(cornerRadius: 3).strokeBorder(model.theme.ink.opacity(0.5), lineWidth: 1) }
                    if task.isComplete { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)) }
                }.frame(width: 18, height: 18)
            }
            .buttonStyle(.plain).padding(.top, 13)
            .accessibilityLabel(task.isComplete ? "Mark incomplete: \(task.text)" : "Complete: \(task.text)")
            .accessibilityValue(task.isComplete ? "Completed" : "Incomplete")

            VStack(alignment: .leading, spacing: 0) {
                if model.editingTask == task.id {
                    NativeEditor(text: task.text, label: "Edit task", font: model.theme.nativeFont, ink: model.theme.nativeInk,
                                 change: { model.changeText(task.id, text: $0) }, finish: { model.finishEditing(); focusedTask = task.id })
                        .padding(.vertical, 4)
                } else {
                    Text(inlineMarkdown(task.text.isEmpty ? "Write a task…" : task.text))
                        .font(model.theme.font)
                        .foregroundStyle(task.color?.ink ?? model.theme.ink)
                        .strikethrough(task.isComplete)
                        .opacity(task.isComplete ? 0.58 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 11)
                        .textSelection(.enabled)
                        .simultaneousGesture(TapGesture(count: 2).onEnded { model.startEditing(task.id) })
                        .accessibilityAction(named: "Edit task") { model.startEditing(task.id) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if task.priority != .none {
                Text(task.priority == .high ? "!!!" : task.priority == .medium ? "!!" : "!")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(model.theme.ink.opacity(0.6)).padding(.top, 16)
                    .accessibilityLabel("\(task.priority.rawValue.capitalized) priority")
            }
            Menu { taskActions(task) } label: { Image(systemName: "ellipsis").font(.system(size: 12)) }
                .menuStyle(.borderlessButton).fixedSize().padding(.top, 13)
                .accessibilityLabel("Actions for \(task.text)")
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 44, alignment: .top)
        .background(focusedTask == task.id ? model.theme.ink.opacity(0.045) : Color.clear)
        .overlay(alignment: .bottom) { Rectangle().fill(model.theme.rule).frame(height: 1) }
        .contentShape(Rectangle())
        .focusable(model.editingTask != task.id)
        .focused($focusedTask, equals: task.id)
        .simultaneousGesture(TapGesture().onEnded { focusedTask = task.id })
        .onKeyPress(.return) {
            guard model.editingTask == nil && !model.editingNotes && model.canEdit else { return .ignored }
            model.startEditing(task.id); return .handled
        }
        .onKeyPress(.space) {
            guard model.editingTask == nil && !model.editingNotes && model.canEdit else { return .ignored }
            model.toggle(task.id); return .handled
        }
        .onKeyPress(.delete) {
            guard model.editingTask == nil && !model.editingNotes && model.canEdit else { return .ignored }
            model.delete(task.id); return .handled
        }
        .onMoveCommand { direction in
            guard model.editingTask == nil && !model.editingNotes else { return }
            guard let tasks = model.state?.sheet.tasks, let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
            let next = direction == .up ? index - 1 : direction == .down ? index + 1 : index
            if tasks.indices.contains(next) { focusedTask = tasks[next].id }
        }
        .contextMenu { taskActions(task) }
    }

    @ViewBuilder private func taskActions(_ task: PadTask) -> some View {
        Button("Edit") { model.startEditing(task.id) }
        Button(task.isComplete ? "Mark incomplete" : "Complete") { model.toggle(task.id) }
        Menu("Priority") {
            ForEach(TaskPriority.allCases, id: \.self) { priority in
                Button((task.priority == priority ? "✓ " : "") + priority.rawValue.capitalized) { model.setPriority(task.id, priority) }
            }
        }
        Menu("Ink color") {
            Button((task.color == nil ? "✓ " : "") + "Default") { model.setColor(task.id, nil) }
            ForEach(TaskColor.allCases, id: \.self) { color in
                Button((task.color == color ? "✓ " : "") + color.rawValue.capitalized) { model.setColor(task.id, color) }
            }
        }
        Divider()
        Button("Move up") { model.move(task.id, offset: -1) }
        Button("Move down") { model.move(task.id, offset: 1) }
        Divider()
        Button("Delete", role: .destructive) { model.delete(task.id) }
    }

    private func notes(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NOTES").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2)
                Spacer()
                if model.editingNotes { Button("Done") { model.finishEditing() }.font(.system(size: 12)) }
                else { Button("Edit") { model.startNotes() }.font(.system(size: 12)) }
            }
            if model.editingNotes {
                NativeEditor(text: text, label: "Daily notes", font: model.theme.nativeFont, ink: model.theme.nativeInk,
                             change: { model.changeNotes($0) }, finish: { model.finishEditing() })
                    .frame(minHeight: 80)
            } else {
                Text(inlineMarkdown(text.isEmpty ? "A little space to think…" : text))
                    .font(model.theme.font).opacity(text.isEmpty ? 0.55 : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 65, alignment: .topLeading)
                    .textSelection(.enabled)
                    .simultaneousGesture(TapGesture(count: 2).onEnded { model.startNotes() })
            }
        }
        .padding(.leading, 56).padding(.trailing, 20).padding(.vertical, 20)
        .overlay(alignment: .top) { Rectangle().fill(model.theme.rule).frame(height: 1) }
    }
}

func displayDay(_ day: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: day) else { return day }
    formatter.locale = .current
    formatter.dateFormat = "EEEE, d MMMM yyyy"
    return formatter.string(from: date).uppercased()
}

struct RolloverView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("A fresh sheet").font(.system(size: 25, weight: .medium, design: .serif))
            Text("Anything to note before leaving \(model.state?.sheet.day ?? "the previous day") behind?")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            TextField("Closing notes (optional)", text: Binding(get: { model.state?.draft?.closingNotes ?? "" }, set: { value in model.editDraft { $0.closingNotes = value } }), axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.roundedBorder).accessibilityLabel("Closing notes")
            HStack {
                Text("Carry forward").font(.headline)
                Spacer()
                Button("Select all") { model.editDraft { $0.selectedTaskIDs = Set(model.state?.sheet.tasks.filter { !$0.isComplete }.map(\.id) ?? []) } }
                Button("Select none") { model.editDraft { $0.selectedTaskIDs = [] } }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.state?.sheet.tasks.filter { !$0.isComplete } ?? []) { task in
                        Toggle(isOn: Binding(get: { model.state?.draft?.selectedTaskIDs.contains(task.id) == true }, set: { selected in
                            model.editDraft { draft in
                                if selected { draft.selectedTaskIDs.insert(task.id) } else { draft.selectedTaskIDs.remove(task.id) }
                            }
                        })) { Text(inlineMarkdown(task.text)).fixedSize(horizontal: false, vertical: true) }
                    }
                    if model.state?.sheet.tasks.filter({ !$0.isComplete }).isEmpty == true {
                        Text("No unfinished tasks. Start with a clean sheet.").foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }.frame(minHeight: 70, maxHeight: 220)
            Toggle("Carry daily notes", isOn: Binding(get: { model.state?.draft?.carryNotes ?? false }, set: { value in model.editDraft { $0.carryNotes = value } }))
            Text("Closing notes stay with the archived sheet. Nothing carries unless you choose it.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let message = model.message { Text(message).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                if model.unsaved { Button("Retry save") { model.retrySave() } }
                Spacer()
                Button("Not yet") { model.showRollover = false }.keyboardShortcut(.cancelAction)
                Button("Start today") { model.confirmRollover() }.keyboardShortcut(.defaultAction).disabled(model.unsaved)
            }
        }
        .padding(28).frame(width: 440)
        .preferredColorScheme(.light)
    }
}
