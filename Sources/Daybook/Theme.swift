import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Workday Light tokens from the Claude Design mock.
enum Theme {
    static let bg = Color(hex: 0xF4F7FD)
    static let surface = Color.white
    static let text = Color(hex: 0x1D1D1F)

    static let accent = Color(hex: 0x3767B0)
    static let accent100 = Color(hex: 0xECF2FC)
    static let accent200 = Color(hex: 0xD7E4F8)
    static let accent600 = Color(hex: 0x2D569A)
    static let accent700 = Color(hex: 0x24437C)

    static let orange400 = Color(hex: 0xF5B03F)
    static let orange500 = Color(hex: 0xF2970F)
    static let orange600 = Color(hex: 0xCF7D05)
    static let orange700 = Color(hex: 0xA56203)

    static let neutral100 = Color(hex: 0xF8FAFD)
    static let neutral200 = Color(hex: 0xEEF2F8)
    static let neutral300 = Color(hex: 0xDDE3EC)
    static let neutral500 = Color(hex: 0x9CA6B5)
    static let neutral600 = Color(hex: 0x7D8798)
    static let neutral700 = Color(hex: 0x5F6878)

    /// Save-confirmation green. Not in the design tokens — desaturated and pulled
    /// toward teal so it reads as part of the cool blue palette, not a stock green.
    static let success = Color(hex: 0x4F9E84)

    static let divider = Color(hex: 0x1D1D1F).opacity(0.1)

    static let radiusSm: CGFloat = 6
    static let radiusMd: CGFloat = 10
    static let radiusLg: CGFloat = 16

    // MARK: - Text size

    /// Multiplier applied to every font in the app. Held statically rather than in
    /// the environment because the sizes are literals at ~65 call sites; `Store`
    /// updates this before publishing, so the next render picks it up.
    static var textScale: CGFloat = 1

    static let minTextScale: CGFloat = 0.85
    static let maxTextScale: CGFloat = 1.30
    static let textScaleStep: CGFloat = 0.05

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight)
    }

    /// For AppKit views and any hardcoded height that has to track the text.
    static func scaled(_ size: CGFloat) -> CGFloat {
        (size * textScale).rounded(.toNearestOrEven)
    }

    static let popoverWidth: CGFloat = 404

    /// Fixed height of the tab content area. Every tab scrolls inside it, so the
    /// popover is the same size on every tab and long pages can never overflow.
    /// Comfortably fits the open date picker (~297).
    static let contentHeight: CGFloat = 360
}
