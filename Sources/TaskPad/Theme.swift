import AppKit
import SwiftUI
import TaskPadCore

extension PadSettings {
    var nativeFont: NSFont {
        if fontName == "System" { return NSFont.systemFont(ofSize: fontSize) }
        return NSFont(name: fontName, size: fontSize)
            ?? NSFontManager.shared.font(withFamily: fontName, traits: [], weight: 5, size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize)
    }
    var font: Font { Font(nativeFont) }
    var textTopInset: CGFloat { TaskLayout.topInset(font: nativeFont, rowHeight: rowHeight) }
    var rowHeight: CGFloat { ceil(max(40, fontSize * 2.25)) }
    var metadataFontSize: CGFloat { max(12, min(18, fontSize * 0.75)) }
    var scheduledBadgeWidth: CGFloat { ceil(metadataFontSize * 3.5 + 12) }
    func priorityBadgeWidth(_ priority: TaskPriority) -> CGFloat {
        let label = priorityDisplay.label(priority) as NSString
        let width = label.size(withAttributes: [.font: NSFont.systemFont(ofSize: metadataFontSize, weight: .semibold)]).width
        return ceil(max(metadataFontSize * 1.6 + 8, width + 16))
    }
    func effortBadgeWidth(_ effort: Int) -> CGFloat {
        let label = (effortScale.label(effort) ?? "") as NSString
        return ceil(max(28, label.size(withAttributes: [.font: NSFont.systemFont(ofSize: metadataFontSize - 1, weight: .medium)]).width + 14))
    }
    func taskTextWidth(_ task: PadTask, sheetWidth: CGFloat, theme: PadTheme) -> CGFloat {
        let metadata = (task.scheduledTime == nil ? 0 : scheduledBadgeWidth)
            + (task.priority.rawValue == 0 ? 0 : priorityBadgeWidth(task.priority))
            + (task.effort.map(effortBadgeWidth) ?? 0)
        return max(40, sheetWidth - theme.textInset - 24 - metadata)
    }
}

extension PadTheme {
    var title: String {
        switch self { case .karst: return "Karst"; case .anoto: return "Anoto"; case .things: return "Things"; case .todoist: return "Todoist"; case .ticktick: return "TickTick" }
    }
    var paper: Color {
        switch self {
        case .karst: return Color(red: 0.985, green: 0.984, blue: 0.975)
        case .anoto: return Color(red: 0.99, green: 0.978, blue: 0.925)
        case .things: return Color(red: 0.975, green: 0.979, blue: 0.99)
        case .todoist: return Color(red: 0.998, green: 0.987, blue: 0.98)
        case .ticktick: return Color(red: 0.971, green: 0.982, blue: 0.995)
        }
    }
    var nativeInk: NSColor { NSColor(srgbRed: 0.17, green: 0.19, blue: 0.21, alpha: 1) }
    var ink: Color { Color(nsColor: nativeInk) }
    var accent: Color {
        switch self {
        case .karst: return .black
        case .anoto: return Color(red: 0.19, green: 0.40, blue: 0.70)
        case .things: return Color(red: 0.18, green: 0.48, blue: 0.82)
        case .todoist: return Color(red: 0.78, green: 0.23, blue: 0.18)
        case .ticktick: return Color(red: 0.22, green: 0.43, blue: 0.88)
        }
    }
    var rule: Color { ink.opacity(self == .anoto ? 0.12 : 0.10) }
    var margin: CGFloat { 52 }
    var textInset: CGFloat { 68 }
}

extension TaskColor {
    var ink: Color {
        switch self {
        case .red: return Color(red: 0.65, green: 0.19, blue: 0.18)
        case .orange: return Color(red: 0.60, green: 0.33, blue: 0.08)
        case .green: return Color(red: 0.17, green: 0.42, blue: 0.25)
        case .blue: return Color(red: 0.17, green: 0.36, blue: 0.64)
        case .purple: return Color(red: 0.44, green: 0.25, blue: 0.57)
        }
    }
}

func inlineMarkdown(_ source: String) -> AttributedString {
    (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(source)
}

struct SlotAction: Identifiable {
    var id: String
    var title: String = ""
    var selected = false
    var separator = false
    var perform: () -> Void = {}
}

@MainActor
func slotActions(_ task: PadTask, model: AppModel) -> [SlotAction] {
    var actions = [SlotAction(id: "edit", title: "Edit task", perform: { model.startEditing(task.id) }),
                   SlotAction(id: "toggle", title: task.isComplete ? "Mark pending" : "Mark done", perform: { model.toggle(task.id) }),
                   SlotAction(id: "s1", separator: true)]
    actions += TaskPriority.allCases.map { priority in
        SlotAction(id: "p\(priority.rawValue)", title: priority.rawValue == 0 ? "Priority 0 · None" : "Priority \(model.settings.priorityDisplay.label(priority))", selected: task.priority == priority, perform: { model.setPriority(task.id, priority) })
    }
    actions += [SlotAction(id: "s2", separator: true), SlotAction(id: "ink", title: "Default ink", selected: task.color == nil, perform: { model.setColor(task.id, nil) })]
    actions += TaskColor.allCases.map { color in
        SlotAction(id: color.rawValue, title: color.rawValue.capitalized + " ink", selected: task.color == color, perform: { model.setColor(task.id, color) })
    }
    actions += [SlotAction(id: "effort-separator", separator: true),
                SlotAction(id: "effort-none", title: "No effort estimate", selected: task.effort == nil, perform: { model.setEffort(task.id, nil) })]
    actions += model.settings.effortChoices(retaining: task.effort).map { size in
        SlotAction(id: "effort-\(size)", title: "Effort \(model.settings.effortScale.label(size) ?? "")", selected: task.effort == size,
                   perform: { model.setEffort(task.id, size) })
    }
    actions += [SlotAction(id: "s3", separator: true),
                SlotAction(id: "up", title: "Move up", perform: { model.move(task.id, offset: -1) }),
                SlotAction(id: "down", title: "Move down", perform: { model.move(task.id, offset: 1) }),
                SlotAction(id: "clear", title: task.scheduleID == nil ? "Clear slot" : "Clear today's occurrence", perform: { model.delete(task.id) })]
    return actions
}
