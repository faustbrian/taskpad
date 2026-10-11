import SwiftUI

struct SettingsMenuButton: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            model.finishEditing()
            openSettings()
        }
        .keyboardShortcut(",")
        .disabled(!model.canEdit)
    }
}
