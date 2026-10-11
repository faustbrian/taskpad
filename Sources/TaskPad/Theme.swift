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
            + (!priorityEnabled || task.priority.rawValue == 0 ? 0 : priorityBadgeWidth(task.priority))
            + (effortEnabled ? (task.effort.map(effortBadgeWidth) ?? 0) : 0)
        return max(40, sheetWidth - theme.textInset - 24 - metadata)
    }
}

extension PadTheme {
    var title: String {
        switch self { case .karst: return "Karst"; case .anoto: return "Anoto"; case .things: return "Things"; case .todoist: return "Todoist"; case .ticktick: return "TickTick"; case .linear: return "Linear"; case .raycast: return "Raycast" }
    }
    var margin: CGFloat { 52 }
    var textInset: CGFloat { 68 }
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
                   SlotAction(id: "toggle", title: task.isComplete ? "Mark pending" : "Mark done", perform: { model.toggle(task.id) })]
    if model.settings.priorityEnabled {
        actions.append(SlotAction(id: "s1", separator: true))
        actions += TaskPriority.allCases.map { priority in
            SlotAction(id: "p\(priority.rawValue)", title: priority.rawValue == 0 ? "Priority 0 · None" : "Priority \(model.settings.priorityDisplay.label(priority))", selected: task.priority == priority, perform: { model.setPriority(task.id, priority) })
        }
    }
    actions += [SlotAction(id: "s2", separator: true), SlotAction(id: "ink", title: "Default ink", selected: task.color == nil, perform: { model.setColor(task.id, nil) })]
    actions += TaskColor.allCases.map { color in
        SlotAction(id: color.rawValue, title: color.rawValue.capitalized + " ink", selected: task.color == color, perform: { model.setColor(task.id, color) })
    }
    if model.settings.effortEnabled {
        actions += [SlotAction(id: "effort-separator", separator: true),
                    SlotAction(id: "effort-none", title: "No effort estimate", selected: task.effort == nil, perform: { model.setEffort(task.id, nil) })]
        actions += model.settings.effortChoices(retaining: task.effort).map { size in
            SlotAction(id: "effort-\(size)", title: "Effort \(model.settings.effortScale.label(size) ?? "")", selected: task.effort == size,
                       perform: { model.setEffort(task.id, size) })
        }
    }
    actions += [SlotAction(id: "s3", separator: true),
                SlotAction(id: "up", title: "Move up", perform: { model.move(task.id, offset: -1) }),
                SlotAction(id: "down", title: "Move down", perform: { model.move(task.id, offset: 1) }),
                SlotAction(id: "clear", title: task.scheduleID == nil ? "Clear slot" : "Clear today's occurrence", perform: { model.delete(task.id) })]
    return actions
}
