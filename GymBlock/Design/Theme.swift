import SwiftUI

// GymBlock's design tokens. See DESIGN.md → "Palette" and "Typography".
//
// The brand is light-first: warm bone paper, near-black ink, and one accent —
// safety orange — reserved for "locked in" moments (starting a workout, days
// trained, finished sets, PRs). Everything else is ink and greys. If you are
// reaching for orange to decorate something, don't: color is earned.

enum GBColor {
    // Grounds
    static let paper = Color(hex: 0xF4F2ED)        // app background (warm bone)
    static let paperDeep = Color(hex: 0xEAE7E0)    // pressed / sunken wells
    static let surface = Color.white               // glass tint base, sheets
    static let shieldWhite = Color(hex: 0xFFFFFF)

    // Ink
    static let ink = Color(hex: 0x111214)          // primary text, primary dark buttons
    static let ink2 = Color(hex: 0x3A3C40)         // strong secondary
    static let steel = Color(hex: 0x6E7178)        // secondary text
    static let fog = Color(hex: 0xA3A5AA)          // tertiary text, placeholders
    static let mist = Color(hex: 0xD9D6CF)         // empty states, untrained days
    static let hairline = Color.black.opacity(0.07)

    // Accent
    static let orange = Color(hex: 0xFF5B1A)       // safety orange — the only accent
    static let orangeDeep = Color(hex: 0xE24A0E)   // pressed accent
    static let orangeSoft = Color(hex: 0xFF5B1A, opacity: 0.12) // finished-set row tint
    static let orangeWash = Color(hex: 0xFF5B1A, opacity: 0.06)

    // Semantic
    static let danger = Color(hex: 0xC8372D)
    static let warmup = Color(hex: 0xD89A00)       // "W" set marker (a label, not an accent)

    // Muscle map
    static let bodyBase = Color(hex: 0x111214, opacity: 0.10)
    static let muscleSecondary = Color(hex: 0xFF5B1A, opacity: 0.38)
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
