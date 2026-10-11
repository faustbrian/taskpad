import AppKit
import SwiftUI
import TaskPadCore

extension PadAppearance {
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
    func resolved(in system: ColorScheme) -> ColorScheme { colorScheme ?? system }
}

/// Concrete colors shared by SwiftUI paper and AppKit glyphs/caret.
struct ThemePalette {
    let nativePaper: NSColor
    let nativeInk: NSColor
    let nativeAccent: NSColor
    let isDark: Bool
    let anoto: Bool
    var paper: Color { Color(nsColor: nativePaper) }
    var ink: Color { Color(nsColor: nativeInk) }
    var accent: Color { Color(nsColor: nativeAccent) }
    var rule: Color { ink.opacity(isDark ? 0.16 : (anoto ? 0.12 : 0.10)) }
    var margin: Color { Color(nsColor: Self.color(isDark ? 0xDB8582 : 0xBA514D)).opacity(0.48) }
    var warning: Color { Color(nsColor: Self.color(isDark ? 0x453821 : 0xFCEED1)) }
    var headerPaper: Color { Color(nsColor: Self.color(isDark ? 0x111211 : 0x17191C)) }
    var headerInk: Color { Color(nsColor: Self.color(0xF4F4EE)) }

    func nativeTaskInk(_ color: TaskColor?) -> NSColor {
        guard let color else { return nativeInk }
        let value: UInt32
        switch (color, isDark) {
        case (.red, false): value = 0x8C2827
        case (.orange, false): value = 0x79400B
        case (.green, false): value = 0x205331
        case (.blue, false): value = 0x234A87
        case (.purple, false): value = 0x5F357D
        case (.red, true): value = 0xFF9D99
        case (.orange, true): value = 0xF4BE80
        case (.green, true): value = 0x9BD6AD
        case (.blue, true): value = 0xA0C4FF
        case (.purple, true): value = 0xCEAFF3
        }
        return Self.color(value)
    }
    static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
}

extension PadTheme {
    func palette(for scheme: ColorScheme) -> ThemePalette {
        let dark = scheme == .dark
        let paper: UInt32
        let accent: UInt32
        switch (self, dark) {
        case (.karst, false): paper = 0xFBFBF9; accent = 0x000000
        case (.karst, true): paper = 0x1C1D1C; accent = 0xE4E3DF
        case (.anoto, false): paper = 0xFCF9EC; accent = 0x285DA7
        case (.anoto, true): paper = 0x25231E; accent = 0x93BDFF
        case (.things, false): paper = 0xF9FAFC; accent = 0x235CAA
        case (.things, true): paper = 0x1D232D; accent = 0x8EBDFA
        case (.todoist, false): paper = 0xFEFCFA; accent = 0xAF3227
        case (.todoist, true): paper = 0x26211F; accent = 0xF6A298
        case (.ticktick, false): paper = 0xF8FAFE; accent = 0x2F59B5
        case (.ticktick, true): paper = 0x1D2430; accent = 0x9FBFFF
        case (.linear, false): paper = 0xFAFAFC; accent = 0x604BB5
        case (.linear, true): paper = 0x17181C; accent = 0xABA5FF
        case (.raycast, false): paper = 0xFAF9F9; accent = 0xAB2E3B
        case (.raycast, true): paper = 0x202022; accent = 0xFF999F
        }
        return ThemePalette(nativePaper: ThemePalette.color(paper),
                            nativeInk: ThemePalette.color(dark ? 0xECEDE7 : 0x2B3036),
                            nativeAccent: ThemePalette.color(accent), isDark: dark, anoto: self == .anoto)
    }
}
