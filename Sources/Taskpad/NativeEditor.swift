import AppKit
import SwiftUI

/// A small native bridge for multiline editing, Return semantics and Cocoa undo.
struct NativeEditor: NSViewRepresentable {
    var text: String
    var label: String
    var font: NSFont
    var ink: NSColor
    var change: (String) -> Void
    var finish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        let editor = TaskTextView()
        editor.isRichText = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.lineFragmentPadding = 0
        editor.textContainerInset = NSSize(width: 1, height: 5)
        editor.minSize = NSSize(width: 0, height: 36)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.font = font
        editor.textColor = ink
        editor.insertionPointColor = ink
        editor.string = text
        editor.setAccessibilityLabel(label)
        editor.delegate = context.coordinator
        scroll.documentView = editor
        DispatchQueue.main.async {
            editor.window?.makeFirstResponder(editor)
            editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        }
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? NSTextView else { return }
        if editor.string != text {
            let range = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(range.location, text.utf16.count), length: 0))
        }
        editor.font = font
        editor.textColor = ink
        editor.insertionPointColor = ink
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        let width = max(60, proposal.width ?? 300)
        let bounds = (text + "\n ").boundingRect(with: NSSize(width: width - 8, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font])
        return CGSize(width: width, height: min(240, max(42, ceil(bounds.height) + 12)))
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeEditor
        init(_ parent: NativeEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.change(editor.string)
        }
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { return false }
                parent.finish()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.finish()
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) || commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                let window = textView.window
                let backward = commandSelector == #selector(NSResponder.insertBacktab(_:))
                parent.finish()
                DispatchQueue.main.async {
                    if backward { window?.selectPreviousKeyView(nil) }
                    else { window?.selectNextKeyView(nil) }
                }
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
