import SwiftUI
import AppKit
import TaskPadCore

struct PadView: View {
    @ObservedObject var model: AppModel
    @State private var dragging: UUID?
    @State private var dropTarget: UUID?
    @State private var slotFrames: [UUID: CGRect] = [:]
    var body: some View {
        VStack(spacing: 0) {
            if let state = model.state {
                if state.settings.header.visible { chrome(state.settings.header, state: state, header: true) }
                if let message = model.message {
                    HStack(alignment: .top, spacing: 12) {
                        Text(message).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if model.unsaved { Button("Retry") { model.retrySave() } }
                        else { Button("Dismiss") { model.message = nil } }
                    }.padding(12).background(Color(red: 0.99, green: 0.93, blue: 0.82))
                }
                if state.draft != nil && !model.showRollover {
                    HStack {
                        Text("Your new-day decision is waiting.").font(.system(size: 12))
                        Spacer(); Button("Continue") { model.showRollover = true }
                    }.padding(12).background(model.theme.rule)
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(state.sheet.tasks.enumerated()), id: \.element.id) { index, task in
                                TaskRow(task: task, number: index + 1, model: model)
                                    .id(task.id)
                                    .background {
                                        GeometryReader { geometry in
                                            Color.clear.preference(key: SlotFrames.self, value: [task.id: geometry.frame(in: .named("sheet"))])
                                        }
                                    }
                                    .overlay { if dropTarget == task.id && dragging != task.id { Rectangle().stroke(model.theme.accent.opacity(0.65), lineWidth: 2).allowsHitTesting(false) } }
                                    .simultaneousGesture(DragGesture(minimumDistance: 8, coordinateSpace: .named("sheet"))
                                        .onChanged { value in
                                            guard model.canEdit, model.editingTask == nil else { return }
                                            dragging = task.id; dropTarget = target(at: value.location)
                                        }
                                        .onEnded { value in
                                            defer { dragging = nil; dropTarget = nil }
                                            guard model.canEdit, let source = dragging, let destination = target(at: value.location) else { return }
                                            model.move(source, to: destination)
                                        })
                            }
                            if state.settings.notesEnabled { notes(state.sheet.notes) }
                        }
                        .coordinateSpace(name: "sheet")
                        .onPreferenceChange(SlotFrames.self) { slotFrames = $0 }
                        .background(alignment: .leading) {
                            if model.theme == .anoto {
                                Rectangle().fill(Color(red: 0.73, green: 0.32, blue: 0.30).opacity(0.48))
                                    .frame(width: 1).padding(.leading, model.theme.margin)
                            }
                        }
                    }
                    .onChange(of: model.selectedTask) { _, id in if let id { proxy.scrollTo(id, anchor: .center) } }
                }
                if state.settings.footer.visible { chrome(state.settings.footer, state: state, header: false) }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Couldn’t open your task pad").font(.title2)
                    Text(model.loadError ?? "Your existing data has not been changed.")
                    Button("Try again") { model.reload() }
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(model.theme.ink).background(model.theme.paper).preferredColorScheme(.light)
        .background {
            GeometryReader { geometry in
                Color.clear.onAppear { model.sheetWidth = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, value in model.sheetWidth = value }
            }
        }
        .frame(minWidth: 360, minHeight: 400)
        .sheet(isPresented: $model.showRollover) { RolloverView(model: model) }
        .sheet(isPresented: $model.showSettings) { PadSettingsView(model: model) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.checkDay() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in model.checkDay() }
    }
    private func target(at point: CGPoint) -> UUID? {
        slotFrames.first { $0.value.contains(point) }?.key
    }
    private func chrome(_ options: ChromeSettings, state: PadState, header: Bool) -> some View {
        let dark = header && model.theme == .karst
        return VStack(alignment: .leading, spacing: header ? 8 : 4) {
            if options.showBrand && !options.brand.isEmpty {
                Text(PadText.format(options.brand, state: state)).font(.system(size: 11, weight: .medium)).tracking(1)
            }
            if options.showTitle && !options.title.isEmpty {
                Text(PadText.format(options.title, state: state)).font(.system(size: header ? 21 : 11, weight: header ? .medium : .regular))
            }
            HStack(spacing: 12) {
                if options.showDate { Text(PadDay.display(state.sheet.day, format: state.settings.dateFormat)) }
                Spacer(minLength: 0)
                if options.showCount { Text(PadText.format(options.countFormat, state: state)).monospacedDigit() }
            }.font(.system(size: header ? 11 : 10)).opacity(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24).padding(.vertical, header ? 20 : 10)
        .foregroundStyle(dark ? Color.white : model.theme.ink)
        .background(dark ? Color(red: 0.09, green: 0.10, blue: 0.11) : model.theme.paper)
        .overlay(alignment: header ? .bottom : .top) { Rectangle().fill(model.theme.rule).frame(height: 1) }
    }
    private func notes(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes").font(.system(size: 12, weight: .medium))
                Spacer(); Button(model.editingNotes ? "Done" : "Edit") { if model.editingNotes { model.finishEditing() } else { model.startNotes() } }.font(.system(size: 11))
            }
            if model.editingNotes {
                NativeEditor(text: text, label: "Daily notes", font: model.settings.nativeFont, ink: model.theme.nativeInk,
                             rowHeight: model.settings.rowHeight, bounded: false, change: { model.changeNotes($0) }, finish: { model.finishEditing() })
                    .frame(minHeight: model.settings.rowHeight * 2)
            } else {
                Text(inlineMarkdown(text.isEmpty ? "" : text)).font(model.settings.font)
                    .frame(maxWidth: .infinity, minHeight: model.settings.rowHeight, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    .onTapGesture(count: 2) { model.startNotes() }
            }
        }.padding(.leading, model.theme.textInset).padding(.trailing, 24).padding(.vertical, 20)
    }
}

struct TaskRow: View {
    let task: PadTask
    let number: Int
    @ObservedObject var model: AppModel
    @State private var width: CGFloat = 280
    private var selected: Bool { model.selectedTask == task.id }
    private var editing: Bool { model.editingTask == task.id }
    private var lineCount: Int {
        selected ? min(5, TaskLayout.lines(task.text, width: textWidth, font: model.settings.nativeFont)) : 1
    }
    private var textWidth: CGFloat { max(40, width - model.theme.textInset - 24 - trailingWidth) }
    private var trailingWidth: CGFloat { (task.scheduledTime == nil ? 0 : 48) + (task.priority.rawValue == 0 ? 0 : 24) }
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button { model.toggle(task.id) } label: { check }
                .buttonStyle(.plain).frame(width: 52, height: model.settings.rowHeight)
                .focusable(false)
                .accessibilityLabel("Slot \(number), \(task.isComplete ? "mark pending" : "mark done")")
                .accessibilityValue(task.isComplete ? "Done" : "Pending")
            Spacer().frame(width: 16)
            Group {
                if editing {
                    NativeEditor(text: task.text, label: "Edit slot \(number)", font: model.settings.nativeFont,
                                 ink: model.theme.nativeInk, rowHeight: model.settings.rowHeight, availableWidth: textWidth,
                                 change: { model.changeText(task.id, text: $0) }, finish: { model.finishEditing() },
                                 navigate: { model.navigate($0, editing: true) }, rejected: { model.message = PadError.taskTooLong.localizedDescription })
                } else {
                    Text(inlineMarkdown(task.text.isEmpty ? " " : task.text))
                        .font(model.settings.font).foregroundStyle(task.color?.ink ?? model.theme.ink)
                        .strikethrough(task.isComplete).opacity(task.isComplete ? 0.48 : 1)
                        .lineLimit(lineCount).truncationMode(.tail)
                        .lineSpacing(max(0, model.settings.rowHeight - (model.settings.nativeFont.ascender - model.settings.nativeFont.descender + model.settings.nativeFont.leading)))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, model.settings.textTopInset)
                        .frame(maxWidth: .infinity, minHeight: model.settings.rowHeight * CGFloat(lineCount), alignment: .topLeading)
                        .onTapGesture(count: 2) { model.startEditing(task.id) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let time = task.scheduledTime {
                VStack(spacing: 2) {
                    Image(systemName: "pin.fill").font(.system(size: 9))
                    Text(time).font(.system(size: 10)).monospacedDigit()
                }.foregroundStyle(model.theme.accent).frame(width: 48, height: model.settings.rowHeight)
                    .accessibilityLabel("Repeating task scheduled at \(time)")
            }
            if task.priority.rawValue > 0 {
                Text(String(task.priority.rawValue)).font(.system(size: 10, weight: .semibold)).foregroundStyle(model.theme.accent)
                    .frame(width: 24, height: model.settings.rowHeight).accessibilityLabel("Priority \(task.priority.rawValue)")
            }
        }
        .padding(.trailing, 24)
        .frame(height: model.settings.rowHeight * CGFloat(lineCount), alignment: .top)
        .background(task.scheduleID != nil ? model.theme.accent.opacity(0.045) : Color.clear)
        .background(selected ? model.theme.accent.opacity(0.055) : Color.clear)
        .background {
            RowKeyboard(active: selected && !editing && !model.editingNotes && model.canEdit && !model.showSettings,
                        actions: slotActions(task, model: model), key: handleKey)
        }
        .background {
            GeometryReader { geometry in Color.clear.onAppear { width = geometry.size.width }.onChange(of: geometry.size.width) { _, value in width = value } }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(model.theme.rule).frame(height: 1) }
        .overlay(alignment: .leading) { if selected { Rectangle().fill(model.theme.accent.opacity(0.55)).frame(width: 2) } }
        .contentShape(Rectangle()).simultaneousGesture(TapGesture().onEnded { model.select(task.id) })
        .contextMenu {
            ForEach(slotActions(task, model: model)) { action in
                if action.separator { Divider() }
                else { Button((action.selected ? "✓ " : "") + action.title, action: action.perform) }
            }
        }
        .disabled(!model.canEdit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Slot \(number): \(task.isBlank ? "empty" : task.text)")
        .accessibilityAction(named: "Edit") { model.startEditing(task.id) }
    }
    private var check: some View {
        ZStack {
            if model.theme == .karst {
                Circle().fill(task.isComplete ? Color.black : Color.clear)
                Circle().strokeBorder(model.theme.ink.opacity(task.isComplete ? 1 : 0.4), lineWidth: 1)
            } else {
                RoundedRectangle(cornerRadius: model.theme == .anoto ? 1 : 4).strokeBorder(task.isComplete ? model.theme.accent : model.theme.ink.opacity(0.35), lineWidth: 1)
                if task.isComplete { Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(model.theme.accent) }
            }
        }.frame(width: 17, height: 17)
    }
    private func handleKey(_ code: UInt16, _ text: String, _ shift: Bool) -> Bool {
        guard model.canEdit, model.editingTask == nil, !model.editingNotes else { return false }
        switch code {
        case 48: model.navigate(shift ? -1 : 1)
        case 125: model.navigate(1)
        case 126: model.navigate(-1)
        case 49, 123: model.toggle(task.id)
        case 36, 76: model.startEditing(task.id)
        case 51, 117: model.delete(task.id)
        default:
            guard text.count == 1, let value = Int(text), (0...9).contains(value) else { return false }
            model.setPriority(task.id, TaskPriority(rawValue: value))
        }
        return true
    }
}

private struct SlotFrames: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, latest in latest }) }
}

struct RolloverView: View {
    @ObservedObject var model: AppModel
    private var eligible: [PadTask] { model.state?.sheet.tasks.filter(\.canCarry) ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A fresh sheet").font(.system(size: 24, weight: .medium))
            if model.settings.notesEnabled {
                Text("Anything to note before leaving \(model.state?.sheet.day ?? "the previous day") behind?").font(.system(size: 13)).foregroundStyle(.secondary)
                TextField("Closing notes (optional)", text: Binding(get: { model.state?.draft?.closingNotes ?? "" }, set: { value in model.editDraft { $0.closingNotes = value } }), axis: .vertical)
                    .lineLimit(3...5).textFieldStyle(.roundedBorder).accessibilityLabel("Closing notes")
            }
            HStack {
                Text("Carry forward").font(.headline); Spacer()
                Button("Select all") { model.editDraft { $0.selectedTaskIDs = Set(eligible.map(\.id)) } }
                Button("Select none") { model.editDraft { $0.selectedTaskIDs = [] } }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(eligible) { task in
                        Toggle(isOn: Binding(get: { model.state?.draft?.selectedTaskIDs.contains(task.id) == true }, set: { selected in
                            model.editDraft { if selected { $0.selectedTaskIDs.insert(task.id) } else { $0.selectedTaskIDs.remove(task.id) } }
                        })) { Text(inlineMarkdown(task.text)).lineLimit(3) }
                    }
                    if eligible.isEmpty { Text("No unfinished manual tasks.").foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
            }.frame(minHeight: 60, maxHeight: 210)
            if model.settings.notesEnabled {
                Toggle("Carry daily notes", isOn: Binding(get: { model.state?.draft?.carryNotes ?? false }, set: { value in model.editDraft { $0.carryNotes = value } }))
            }
            let due = model.settings.due(on: model.today).count
            if due > 0 { Text("\(due) repeating \(due == 1 ? "task is" : "tasks are") reserved for today.").font(.system(size: 11)).foregroundStyle(.secondary) }
            if model.settings.notesEnabled {
                Text("Closing notes stay with the archive. Only selected tasks carry.").font(.system(size: 11)).foregroundStyle(.secondary)
            } else {
                Text("Only selected tasks carry.").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let message = model.message { Text(message).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                if model.unsaved { Button("Retry save") { model.retrySave() } }; Spacer()
                Button("Not yet") { model.showRollover = false }.keyboardShortcut(.cancelAction)
                Button("Start today") { model.confirmRollover() }.keyboardShortcut(.defaultAction).disabled(model.unsaved)
            }
        }.padding(28).frame(width: 440).preferredColorScheme(.light)
    }
}
