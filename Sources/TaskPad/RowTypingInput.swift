import AppKit

/// Keep native events until SwiftUI has installed the row's text editor.
/// Replaying through AppKit preserves text input, validation and native Undo.
@MainActor
final class RowTypingInput {
    private var events: [NSEvent] = []
    private var awaitingResponder = false
    private(set) var isDelivering = false
    private(set) var currentEvent: NSEvent?
    var isPending: Bool { !events.isEmpty }

    func append(_ event: NSEvent) { events.append(event) }
    func pauseForResponderChange() { awaitingResponder = true }

    func deliver(to responder: NSResponder) {
        guard !isDelivering else { return }
        isDelivering = true
        defer { isDelivering = false; currentEvent = nil }
        awaitingResponder = false
        while !events.isEmpty {
            let event = events.removeFirst()
            currentEvent = event
            if let editor = responder as? NSTextView {
                editor.interpretKeyEvents([event])
            } else {
                // Let the row apply its shortcuts or install the next editor.
                responder.keyDown(with: event)
            }
            if awaitingResponder { return }
        }
    }
}
