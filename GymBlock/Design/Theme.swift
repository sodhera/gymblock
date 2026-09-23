import SwiftUI

// GymBlock's design tokens. See DESIGN.md → "Palette" and "Typography".
//
// The brand is light-first (with a matching dark mode): warm bone paper, near-black ink, and one accent —
// safety orange — reserved for "locked in" moments (starting a workout, days
// trained, finished sets, PRs). Everything else is ink and greys. If you are
// reaching for orange to decorate something, don't: color is earned.

enum GBColor {
    // Light values are the brand; dark values keep the same roles on a warm
    // near-black ("paper at night") so the app reads as one system in both.

    // Grounds
    static let paper = dynamic(0xF4F2ED, 0x0E0E0F)        // app background
    static let paperDeep = dynamic(0xEAE7E0, 0x1E1E20)    // pressed rows, input wells
    static let card = dynamic(0xFFFFFF, 0x1A1A1C)         // cards, tiles, chips
    /// Tint for Liquid Glass surfaces: frosted white by day, smoke by night.
    static let glassTint = dynamic(0xFFFFFF, 0x2A2A2D, lightAlpha: 0.55, darkAlpha: 0.45)

    // Ink
    static let ink = dynamic(0x111214, 0xF2F1EC)          // primary text, ink buttons
    static let ink2 = dynamic(0x3A3C40, 0xCDCCC7)         // strong secondary
    static let steel = dynamic(0x6E7178, 0x9A9DA3)        // secondary text, kickers
    static let fog = dynamic(0xA3A5AA, 0x66696F)          // tertiary, placeholders
    static let mist = dynamic(0xD9D6CF, 0x2F2F32)         // untrained days, empty bars
    static let hairline = dynamic(0x000000, 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.09)
    /// Text on an ink-filled surface (flips with ink).
    static let onInk = dynamic(0xF4F2ED, 0x111214)
    static let shadow = dynamic(0x000000, 0x000000, lightAlpha: 0.05, darkAlpha: 0.0)

    // Accent — identical in both modes; it's the brand.
    static let orange = Color(hex: 0xFF5B1A)
    static let orangeDeep = Color(hex: 0xE24A0E)
    static let orangeSoft = dynamic(0xFF5B1A, 0xFF5B1A, lightAlpha: 0.12, darkAlpha: 0.20) // finished-set row
    static let orangeWash = dynamic(0xFF5B1A, 0xFF5B1A, lightAlpha: 0.06, darkAlpha: 0.12)

    // Semantic
    static let danger = dynamic(0xC8372D, 0xFF6B5E)
    static let warmup = dynamic(0xD89A00, 0xF2B634)       // "W" set marker (a label, not an accent)

    private static func dynamic(_ light: UInt32, _ dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum GBSpace {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 40
    /// Screen side margin.
    static let margin: CGFloat = 20
}

enum GBRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 18
    static let lg: CGFloat = 24
    static let xl: CGFloat = 30
}

// MARK: - Typography
//
// SF Pro only — no font files. Heroes and kickers use the *expanded* width,
// which reads like the lettering stamped on plates and equipment; body copy is
// regular width; every number that sits in a column (weights, reps, timers) is
// monospaced-digit so logs line up like a logbook.

enum GBFont {
    /// Big editorial headlines ("3 of 4 this week.").
    static func hero(_ size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold).width(.expanded)
    }
    /// Screen titles and card titles.
    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold).width(.expanded)
    }
    static func headline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular)
    }
    static func label(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .medium)
    }
    /// Small-caps style section label: "WEEK 38", "PUSH · 32:14".
    static func kicker(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold).width(.expanded)
    }
    /// Tabular numerals for logs and timers.
    static func number(_ size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    /// The giant stat numeral (streak, timer).
    static func stat(_ size: CGFloat = 44) -> Font {
        .system(size: size, weight: .bold).width(.expanded).monospacedDigit()
    }
}

extension View {
    /// Uppercase, tracked, steel — the one section-label grammar in the app.
    func kicker(_ color: Color = GBColor.steel) -> some View {
        self
            .font(GBFont.kicker())
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// Paper background that fills behind safe areas.
    func paperBackground() -> some View {
        background(GBColor.paper.ignoresSafeArea())
    }
}
