import AppKit
import SwiftUI
import TaskPadCore

/// Shared native measurement keeps editor expansion on the pad's ruled grid.
enum TaskLayout {
    static func lines(_ text: String, width: CGFloat, font: NSFont) -> Int {
        let storage = NSTextStorage(string: text.isEmpty ? " " : text, attributes: [.font: font])
        let manager = NSLayoutManager(); let container = NSTextContainer(size: NSSize(width: max(40, width), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0; manager.addTextContainer(container); storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        var count = 0
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, _, _ in count += 1 }
        if text.hasSuffix("\n") { count += 1 }
        return max(1, count)
    }
}

struct NativeEditor: NSViewRepresentable {
    var text: String
    var label: String
    var font: NSFont
    var ink: NSColor
    var rowHeight: CGFloat = 40
    var bounded = true
    var availableWidth: CGFloat = 300
    var change: (String) -> Void
    var finish: () -> Void
    var navigate: ((Int) -> Void)? = nil
    var rejected: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView(); scroll.drawsBackground = false; scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true; scroll.borderType = .noBorder
        let editor = TaskTextView(); editor.isRichText = false; editor.allowsUndo = true; editor.drawsBackground = false
        editor.isVerticallyResizable = true; editor.isHorizontallyResizable = false; editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true; editor.textContainer?.lineFragmentPadding = 0
        editor.textContainerInset = NSSize(width: 0, height: 0); editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.string = text; editor.setAccessibilityLabel(label); editor.delegate = context.coordinator
        configure(editor); scroll.documentView = editor
        DispatchQueue.main.async { editor.window?.makeFirstResponder(editor); editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0)) }
        return scroll
    }
    private func configure(_ editor: NSTextView) {
        editor.font = font; editor.textColor = ink; editor.insertionPointColor = ink
        let paragraph = NSMutableParagraphStyle(); paragraph.minimumLineHeight = rowHeight; paragraph.maximumLineHeight = rowHeight
        editor.defaultParagraphStyle = paragraph
        let baseline = (rowHeight - (font.ascender - font.descender + font.leading)) / 2
        editor.typingAttributes = [.font: font, .foregroundColor: ink, .paragraphStyle: paragraph, .baselineOffset: baseline]
        if editor.textStorage?.length ?? 0 > 0 { editor.textStorage?.addAttributes([.paragraphStyle: paragraph, .baselineOffset: baseline], range: NSRange(location: 0, length: editor.string.utf16.count)) }
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        if editor.string != text {
            let range = editor.selectedRange(); editor.string = text
            editor.setSelectedRange(NSRange(location: min(range.location, text.utf16.count), length: 0))
        }
        configure(editor)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        let width = max(40, proposal.width ?? 300)
        let lines = TaskLayout.lines(text, width: width, font: font)
        return CGSize(width: width, height: CGFloat(min(bounded ? 5 : 10, lines)) * rowHeight)
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeEditor
        init(_ parent: NativeEditor) { self.parent = parent }
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard parent.bounded, let replacementString else { return true }
            let candidate = (textView.string as NSString).replacingCharacters(in: affectedCharRange, with: replacementString)
            let measured = textView.textContainer?.containerSize.width ?? 0
            let width = measured > 40 ? measured : parent.availableWidth
            let originalLines = TaskLayout.lines(textView.string, width: width, font: parent.font)
            let candidateLines = TaskLayout.lines(candidate, width: width, font: parent.font)
            let allowed = TaskInput.allowsChange(from: textView.string, to: candidate)
            if allowed && candidateLines <= TaskInput.maxLines { return true }
            // Narrower windows or changed fonts may make saved text wrap past five lines.
            // Deletion can repair that text but cannot increase its existing line excess.
            if allowed && originalLines > TaskInput.maxLines && candidate.count < textView.string.count && candidateLines <= originalLines { return true }
            parent.rejected(); NSSound.beep(); return false
        }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }; parent.change(editor.string)
        }
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { return false }; parent.finish(); return true
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) { parent.finish(); return true }
            if selector == #selector(NSResponder.insertTab(_:)) || selector == #selector(NSResponder.insertBacktab(_:)) {
                let offset = selector == #selector(NSResponder.insertBacktab(_:)) ? -1 : 1
                if let navigate = parent.navigate { navigate(offset) }
                else { parent.finish() }
                return true
            }
            return false
        }
    }
}

private final class TaskTextView: NSTextView {
    private let textUndo = UndoManager()
    override var undoManager: UndoManager? { textUndo }
}

/// A native row responder avoids intercepting Space/digits/arrows inside text editors.
struct RowKeyboard: NSViewRepresentable {
    var active: Bool
    var actions: [SlotAction]
    var key: (UInt16, String, Bool) -> Bool
    func makeNSView(context: Context) -> RowKeyView { let view = RowKeyView(); view.setAccessibilityElement(false); return view }
    func updateNSView(_ view: RowKeyView, context: Context) {
        view.key = key; view.actions = actions; view.isActive = active
        if active {
            DispatchQueue.main.async { [weak view] in
                guard let view, view.isActive, let window = view.window else { return }
                if window.firstResponder !== view { window.makeFirstResponder(view) }
            }
        }
    }
}
final class RowKeyView: NSView {
    var isActive = false
    var key: ((UInt16, String, Bool) -> Bool)?
    var actions: [SlotAction] = []
    private var targets: [MenuTarget] = []
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func keyDown(with event: NSEvent) {
        guard isActive else { super.keyDown(with: event); return }
        if !event.modifierFlags.intersection([.command, .option, .control]).isEmpty { super.keyDown(with: event); return }
        if event.keyCode == 124 { openMenu(); return }
        if key?(event.keyCode, event.charactersIgnoringModifiers ?? "", event.modifierFlags.contains(.shift)) == true { return }
        super.keyDown(with: event)
    }
    private func openMenu() {
        let menu = NSMenu(); targets = []
        for action in actions {
            if action.separator { menu.addItem(.separator()); continue }
            let target = MenuTarget(action.perform); targets.append(target)
            let item = NSMenuItem(title: action.title, action: #selector(MenuTarget.run), keyEquivalent: "")
            item.target = target; item.state = action.selected ? .on : .off; menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 68, y: bounds.height), in: self)
    }
}
private final class MenuTarget: NSObject {
    let perform: () -> Void
    init(_ perform: @escaping () -> Void) { self.perform = perform }
    @objc func run() { perform() }
}
