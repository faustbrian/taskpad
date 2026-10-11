import AppKit
import SwiftUI

/// Observe the native scene without replacing SwiftUI's window delegate.
struct SettingsWindowSetup: NSViewRepresentable {
    let opened: () -> Void
    let resigned: () -> Void
    let closed: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            coordinator.observe(window, opened: opened, resigned: resigned, closed: closed)
        }
    }

    final class Coordinator {
        private weak var window: NSWindow?
        private var observations: [NSObjectProtocol] = []
        func observe(_ window: NSWindow, opened: @escaping () -> Void, resigned: @escaping () -> Void, closed: @escaping () -> Void) {
            guard self.window !== window else { return }
            observations.forEach(NotificationCenter.default.removeObserver)
            self.window = window
            window.styleMask.insert(.resizable)
            window.setFrameAutosaveName("TaskPadSettingsWindow")
            window.setFrameUsingName("TaskPadSettingsWindow")
            let center = NotificationCenter.default
            observations = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { _ in opened() },
                center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { _ in resigned() },
                center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in closed() }
            ]
            if window.isKeyWindow { opened() }
        }
        deinit { observations.forEach(NotificationCenter.default.removeObserver) }
    }
}
