import SwiftUI
import AppKit
import TaskPadCore

struct PadSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var draft: PadSettings
    @State private var theme: PadTheme
    init(model: AppModel) { self.model = model; _draft = State(initialValue: model.settings); _theme = State(initialValue: model.theme) }
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                Form {
                    Section("One fixed sheet") {
                        Stepper("Slots: \(draft.slotLimit)", value: $draft.slotLimit, in: 1...100)
                        Text("Filled and empty slots share the same fixed sheet. Lowering the limit never discards filled items.").font(.caption).foregroundStyle(.secondary)
                        Picker("Carry-over", selection: $draft.carryMode) {
                            Text("Auto").tag(CarryMode.automatic); Text("Ask").tag(CarryMode.ask); Text("Never").tag(CarryMode.never)
                        }
                        Text("Auto: carry unfinished manual tasks and enabled notes. Never: start fresh with no previous tasks or notes. Repeating tasks still appear on their scheduled days. If Auto would overflow, you choose what fits.").font(.caption).foregroundStyle(.secondary)
                        Toggle("Show daily notes", isOn: $draft.notesEnabled)
                        Text("Hiding notes preserves their text.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Window") { TextField("Window title", text: $draft.windowTitle) }
                    Section("Focused tasks") {
                        Text("A resting row is one line. Focus expands it to up to five ruled lines. New task text is limited to five visual lines and 500 characters; notes are separate.").font(.caption).foregroundStyle(.secondary)
                    }
                }.formStyle(.grouped).tabItem { Text("Pad") }
                Form {
                    Section("Paper") {
                        Picker("Theme", selection: $theme) { ForEach(PadTheme.allCases, id: \.self) { Text($0.title).tag($0) } }
                    }
                    Section("Typography") {
                        Picker("Font", selection: $draft.fontName) {
                            Text("System · San Francisco").tag("System")
                            ForEach(NSFontManager.shared.availableFontFamilies.sorted(), id: \.self) { Text($0).tag($0) }
                        }
                        Stepper("Font size: \(Int(draft.fontSize)) pt", value: $draft.fontSize, in: 10...32, step: 1)
                        Text("Unavailable fonts fall back to the system font. Fonts installed on this Mac, including Maple Mono NF, appear in the list.").font(.caption).foregroundStyle(.secondary)
                        Text("The quick brown fox · 07:30").font(draft.font).padding(.vertical, 8)
                    }
                }.formStyle(.grouped).tabItem { Text("Appearance") }
                Form {
                    ChromeForm(title: "Header", options: $draft.header)
                    ChromeForm(title: "Footer", options: $draft.footer)
                    Section("Date and text formats") {
                        TextField("Date format (empty = system locale)", text: $draft.dateFormat)
                        Text(PadDay.display(model.state?.sheet.day ?? model.today, format: draft.dateFormat)).font(.caption).foregroundStyle(.secondary)
                        Text("Custom date formats use Foundation patterns, for example EEE, d MMM. Text fields support {date}, {used}, {limit}, {completed} and {remaining}. Unknown tokens stay literal.").font(.caption).foregroundStyle(.secondary)
                    }
                }.formStyle(.grouped).tabItem { Text("Header & Footer") }
                Form {
                    Section {
                        Text("Visible all day on selected weekdays. The time is a reminder on the row, not a notification. Each occurrence takes one slot and starts pending on its next scheduled day.").font(.caption).foregroundStyle(.secondary)
                        ForEach($draft.schedules) { $rule in
                            RepeatRuleEditor(rule: $rule, remove: { draft.schedules.removeAll { $0.id == rule.id } })
                        }
                        Button("Create repeating task") { draft.schedules.append(RepeatTask(text: "")) }
                    }
                }.formStyle(.grouped).tabItem { Text("Repeating Tasks") }
            }
            Divider()
            if let message = model.message { Text(message).font(.caption).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.top, 8) }
            HStack {
                Text("Settings are always available with ⌘,").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { model.showSettings = false }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if model.applySettings(draft) { model.setTheme(theme); if !model.unsaved { model.showSettings = false } }
                }.keyboardShortcut(.defaultAction).disabled(!model.canEdit || model.unsaved)
            }.padding(16)
        }.frame(width: 570, height: 630).preferredColorScheme(.light)
    }
}

private struct ChromeForm: View {
    let title: String
    @Binding var options: ChromeSettings
    var body: some View {
        Section(title) {
            Toggle("Show \(title.lowercased()) section", isOn: $options.visible)
            Toggle("Show brand text", isOn: $options.showBrand)
            TextField("Brand text", text: $options.brand)
            Toggle("Show heading / motto", isOn: $options.showTitle)
            TextField("Heading / motto", text: $options.title)
            Toggle("Show date", isOn: $options.showDate)
            Toggle("Show slot count", isOn: $options.showCount)
            TextField("Count format", text: $options.countFormat)
        }
    }
}

private struct RepeatRuleEditor: View {
    @Binding var rule: RepeatTask
    var remove: () -> Void
    private let days = [(2,"M"),(3,"T"),(4,"W"),(5,"T"),(6,"F"),(7,"S"),(1,"S")]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { TextField("Focused task", text: $rule.text); Button("Remove", action: remove) }
            HStack(spacing: 8) {
                ForEach(days, id: \.0) { day, label in
                    Toggle(label, isOn: Binding(get: { rule.weekdays.contains(day) }, set: { if $0 { rule.weekdays.insert(day) } else { rule.weekdays.remove(day) } }))
                        .toggleStyle(.button).accessibilityLabel(["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"][day-1])
                }
            }
            HStack {
                Picker("Hour", selection: $rule.hour) { ForEach(0..<24) { Text(String(format: "%02d", $0)).tag($0) } }
                Picker("Minute", selection: $rule.minute) { ForEach(0..<60) { Text(String(format: "%02d", $0)).tag($0) } }
                Picker("Priority", selection: $rule.priority) { ForEach(TaskPriority.allCases, id: \.self) { Text(String($0.rawValue)).tag($0) } }
            }
            Divider()
        }.padding(.vertical, 6)
    }
}
