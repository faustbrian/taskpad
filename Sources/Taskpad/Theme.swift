import AppKit
import SwiftUI
import TaskpadCore

extension PadTheme {
    var paper: Color { self == .karst ? Color(red: 0.985, green: 0.984, blue: 0.975) : Color(red: 0.985, green: 0.970, blue: 0.918) }
    var ink: Color { Color(nsColor: nativeInk) }
    var nativeInk: NSColor { NSColor(srgbRed: 0.22, green: 0.23, blue: 0.23, alpha: 1) }
    var rule: Color { self == .karst ? Color.black.opacity(0.16) : Color(red: 0.65, green: 0.72, blue: 0.65).opacity(0.30) }
    var nativeFont: NSFont {
        self == .notepad ? (NSFont(name: "Noteworthy-Light", size: 17) ?? NSFont.systemFont(ofSize: 16)) : NSFont.systemFont(ofSize: 16)
    }
    var font: Font { Font(nativeFont) }
}

extension TaskColor {
    var ink: Color {
        switch self {
        case .red: return Color(red: 0.62, green: 0.19, blue: 0.18)
        case .orange: return Color(red: 0.57, green: 0.32, blue: 0.08)
        case .green: return Color(red: 0.18, green: 0.40, blue: 0.25)
        case .blue: return Color(red: 0.17, green: 0.36, blue: 0.60)
        case .purple: return Color(red: 0.44, green: 0.25, blue: 0.56)
        }
    }
}

func inlineMarkdown(_ source: String) -> AttributedString {
    (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(source)
}
