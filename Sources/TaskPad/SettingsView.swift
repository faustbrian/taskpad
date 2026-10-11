import SwiftUI
import AppKit
import TaskPadCore

private enum SettingsPage: String, CaseIterable, Identifiable {
    case general, appearance, header, footer, repeating
    var id: Self { self }
    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .header: return "Header"
        case .footer: return "Footer"
        case .repeating: return "Repeating Tasks"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintpalette.fill"
        case .header: return "rectangle.topthird.inset.filled"
        case .footer: return "rectangle.bottomthird.inset.filled"
        case .repeating: return "repeat"
        }
    }
    var tint: Color {
        switch self {
        case .general: return .gray
        case .appearance: return .purple
        case .header, .footer: return .blue
        case .repeating: return .orange
        }
    }
    var summary: String {
        switch self {
        case .general: return "A fixed daily sheet, with only the space you choose."
        case .appearance: return "Choose your paper and the type that feels right."
        case .header: return "Show a heading, just the date, or no header at all."
        case .footer: return "An optional finishing line beneath your list."
        case .repeating: return "Make room for the routines that belong on your day."
        }
    }
}

// Native Settings follows the saved app mode; System stays live with macOS.
private final class SettingsAppearance: ObservableObject {
    @Published var colorScheme: ColorScheme
    private var observation: NSKeyValueObservation?
    init() {
        colorScheme = Self.scheme(NSApp.effectiveAppearance)
        observation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] app, _ in
            let scheme = Self.scheme(app.effectiveAppearance)
            DispatchQueue.main.async { self?.colorScheme = scheme }
        }
    }
    private static func scheme(_ appearance: NSAppearance) -> ColorScheme {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
}

struct PadSettingsView: View {
    @ObservedObject var model: AppModel
    @State private var draft: PadSettings
    @State private var theme: PadTheme
    @State private var page: SettingsPage = .general
    @StateObject private var appearance = SettingsAppearance()
    @Environment(\.dismiss) private var dismiss
    init(model: AppModel) { self.model = model; _draft = State(initialValue: model.settings); _theme = State(initialValue: model.theme) }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    settingsIcon(page, size: 40)
                    Text(page.title).font(.system(size: 21, weight: .semibold)).accessibilityAddTraits(.isHeader)
                    Text(page.summary).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 12)
                content
                actions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 640, minHeight: 480)
        .font(.system(size: 13)).foregroundStyle(.primary)
        .preferredColorScheme(model.settings.appearance.colorScheme ?? appearance.colorScheme)
        .background(SettingsWindowSetup(
            opened: { model.settingsIsKey = true; model.beginSettings() },
            resigned: { model.settingsIsKey = false },
            closed: { model.settingsIsKey = false; model.showSettings = false }
        ))
        .onChange(of: model.settingsSessionID) { _, _ in
            draft = model.settings
            theme = model.theme
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings").font(.system(size: 18, weight: .semibold)).padding(.horizontal, 12).padding(.top, 28).padding(.bottom, 16)
            ForEach(SettingsPage.allCases) { item in
                Button { page = item } label: {
                    HStack(spacing: 10) {
                        settingsIcon(item, size: 24)
                        Text(item.title).font(.system(size: 13, weight: page == item ? .medium : .regular))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .foregroundStyle(page == item ? Color.white : Color.primary)
                    .background(page == item ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain).accessibilityLabel(item.title)
                .accessibilityValue(page == item ? "Selected" : "")
            }
            Spacer()
            Text("⌘, opens settings").font(.system(size: 11)).foregroundStyle(.secondary).padding(12)
        }
        .padding(.horizontal, 10).frame(width: 190)
        .frame(maxHeight: .infinity).background(.regularMaterial)
    }
    private func settingsIcon(_ item: SettingsPage, size: CGFloat) -> some View {
        Image(systemName: item.symbol).font(.system(size: size * 0.56, weight: .medium))
            .frame(width: size, height: size).foregroundStyle(.white)
            .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.23))
            .accessibilityHidden(true)
    }
    @ViewBuilder private var content: some View {
        switch page {
        case .general:
                Form {
                    Section("One fixed sheet") {
                        Stepper("Slots: \(draft.slotLimit)", value: $draft.slotLimit, in: 1...100)
                        Text("Every slot is reserved. Filled slots are never removed.").font(.caption).foregroundStyle(.secondary)
                        Picker("Carry-over", selection: $draft.carryMode) {
                            Text("Auto").tag(CarryMode.automatic); Text("Ask").tag(CarryMode.ask); Text("Never").tag(CarryMode.never)
                        }
                        Text(carryHelp).font(.caption).foregroundStyle(.secondary)
                        Toggle("Show daily notes", isOn: $draft.notesEnabled)
                        Text("Hiding notes preserves their text.").font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Window") { TextField("Window title", text: $draft.windowTitle) }
                    Section("Interactions") {
                        Picker("Double-click a task", selection: $draft.doubleClickAction) {
                            ForEach(DoubleClickAction.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        Text("Space marks done and moves to the next slot. Left Arrow toggles without moving.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.formStyle(.grouped)
        case .appearance:
                Form {
                    Section("Paper") {
                        Picker("Appearance", selection: $draft.appearance) {
                            ForEach(PadAppearance.allCases, id: \.self) { Text($0.title).tag($0) }
                        }.pickerStyle(.segmented)
                        Picker("Theme", selection: $theme) { ForEach(PadTheme.allCases, id: \.self) { Text($0.title).tag($0) } }
                    }
                    Section("Typography") {
                        Picker("Font", selection: $draft.fontName) {
                            Text("System · San Francisco").tag("System")
                            ForEach(NSFontManager.shared.availableFontFamilies.sorted(), id: \.self) { Text($0).tag($0) }
                        }
                        Stepper("Font size: \(Int(draft.fontSize)) pt", value: $draft.fontSize, in: 10...32, step: 1)
                        Text("Choose an installed font. Missing fonts use the system font.").font(.caption).foregroundStyle(.secondary)
                        Text("The quick brown fox · 07:30").font(draft.font).padding(.vertical, 8)
                    }
                    Section("Task badges") {
                        Toggle("Enable priority", isOn: $draft.priorityEnabled)
                        if draft.priorityEnabled {
                            Picker("Priority display", selection: $draft.priorityDisplay) {
                                ForEach(PriorityDisplay.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                        }
                        Toggle("Enable effort", isOn: $draft.effortEnabled)
                        if draft.effortEnabled {
                            Picker("Effort scale", selection: $draft.effortScale) {
                                ForEach(EffortScale.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            Toggle("Extended effort scale", isOn: $draft.extendedEffort)
                            Text(draft.effortChoices().compactMap { draft.effortScale.label($0) }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Scale changes keep relative size; hiding extended values keeps existing estimates.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Turning a feature off hides its badges and controls, without erasing saved values.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.formStyle(.grouped)
        case .header: chrome("Header", options: $draft.header)
        case .footer: chrome("Footer", options: $draft.footer)
        case .repeating:
            Form {
                Section {
                    Text("Visible all day, with a scheduled time. Each task reserves a slot; no notifications.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach($draft.schedules) { $rule in
                    Section { RepeatRuleEditor(rule: $rule, settings: draft, remove: { draft.schedules.removeAll { $0.id == rule.id } }) }
                }
                Section { Button("Create repeating task") { draft.schedules.append(RepeatTask(text: "")) } }
            }.formStyle(.grouped)
        }
    }
    private func chrome(_ title: String, options: Binding<ChromeSettings>) -> some View {
        Form {
            ChromeForm(title: title, options: options)
            Section("Date and text formats") {
                TextField("Date format", text: $draft.dateFormat, prompt: Text("System locale"))
                Text(PadDay.display(model.state?.sheet.day ?? model.today, format: draft.dateFormat)).font(.caption).foregroundStyle(.secondary)
                Text("Blank uses your system locale. Examples: EEE, d MMM or yyyy/MM/dd.").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("Text format help") {
                    Text("Use {date}, {used}, {limit}, {completed} or {remaining}. For example: {used} out of {limit} slots taken. Unknown tokens stay literal.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.formStyle(.grouped)
    }
    private var actions: some View {
        VStack(spacing: 0) {
            Divider()
            if let message = model.message {
                Text(message).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 12)
            }
            if !model.canEdit {
                Text("Finish your new-day decision in the pad before saving Settings.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.top, 12)
            }
            HStack {
                if model.unsaved {
                    Button("Retry Save") { model.retrySave() }
                }
                Spacer()
                Button(model.unsaved ? "Close" : "Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if model.applySettings(draft, theme: theme) { dismiss() }
                }.keyboardShortcut(.defaultAction).disabled(!model.canEdit || model.unsaved)
            }.padding(16)
        }
    }
    private var carryHelp: String {
        switch draft.carryMode {
        case .automatic: return "Carry unfinished tasks and enabled notes. If they won’t fit, choose what carries."
        case .ask: return "Choose what to carry when a new day begins."
        case .never: return "Start fresh each day. Repeating tasks still appear when scheduled."
        }
    }
}

private struct ChromeForm: View {
    let title: String
    @Binding var options: ChromeSettings
    var body: some View {
        Section(title) {
            Toggle("Show \(title.lowercased()) section", isOn: $options.visible)
            Group {
                Toggle("Show brand text", isOn: $options.showBrand)
                TextField("Brand text", text: $options.brand).disabled(!options.showBrand)
                Toggle("Show \(title == "Header" ? "heading" : "motto")", isOn: $options.showTitle)
                TextField(title == "Header" ? "Heading" : "Motto", text: $options.title).disabled(!options.showTitle)
                Toggle("Show date", isOn: $options.showDate)
                Toggle("Show slot count", isOn: $options.showCount)
                TextField("Count format", text: $options.countFormat).disabled(!options.showCount)
            }.disabled(!options.visible)
        }
    }
}

private struct RepeatRuleEditor: View {
    @Binding var rule: RepeatTask
    let settings: PadSettings
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
            }
            HStack {
                if settings.priorityEnabled {
                    Picker("Priority", selection: $rule.priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { Text($0.rawValue == 0 ? "None" : settings.priorityDisplay.label($0)).tag($0) }
                    }
                }
                if settings.effortEnabled {
                    Picker("Effort", selection: $rule.effort) {
                        Text("None").tag(nil as Int?)
                        ForEach(settings.effortChoices(retaining: rule.effort), id: \.self) {
                            Text(settings.effortScale.label($0) ?? "").tag(Optional($0))
                        }
                    }
                }
            }
            Divider()
        }.padding(.vertical, 6)
    }
}
