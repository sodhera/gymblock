import SwiftUI
import UIKit
import WidgetKit

/// One paper colour, both appearances spelled out. The app reads these through `JourneyTheme.paper`
/// (dynamic colours); widgets pick a side themselves from the colour scheme, so the two can't drift.
struct PaperColor: Equatable {
  struct RGB: Equatable {
    let r, g, b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
    var ui: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
  }
  let light: RGB
  let dark: RGB
  func color(dark isDark: Bool) -> Color { (isDark ? dark : light).color }
}

/// The paper stage's four widget tokens (the values in code; the docs round emerald to #0F9A6B).
/// Tertiary and danger stay in `JourneyTheme`: widgets never use them.
enum Paper {
  /// #F5F3EF, at night #151412.
  static let stage = PaperColor(light: .init(r: 0.961, g: 0.953, b: 0.937), dark: .init(r: 0.082, g: 0.078, b: 0.071))
  /// #141417, at night #F3F0EA.
  static let ink = PaperColor(light: .init(r: 0.08, g: 0.08, b: 0.09), dark: .init(r: 0.953, g: 0.941, b: 0.918))
  /// #66666B (5.15:1 on paper), at night #B0ADA8.
  static let secondary = PaperColor(light: .init(r: 0.40, g: 0.40, b: 0.42), dark: .init(r: 0.69, g: 0.68, b: 0.66))
  /// Emerald #0F996B, at night #33C28A: the only signal.
  static let signal = PaperColor(light: .init(r: 0.06, g: 0.60, b: 0.42), dark: .init(r: 0.20, g: 0.76, b: 0.54))
}

/// A split's colour (15 Oct 2026, at the user's request): its trained days on Home, Profile's calendar
/// and the widgets take it, so a month reads as push, pull and legs at a glance. Emerald, the signal,
/// is the default, so nothing changes until a colour is picked. Stored by name, so a name this build
/// doesn't know falls back to emerald instead of failing to decode.
enum SplitColor: String, CaseIterable, Identifiable {
  case emerald, teal, blue, indigo, purple, pink, red, orange, amber, graphite
  var id: String { rawValue }
  init(name: String?) { self = name.flatMap(SplitColor.init(rawValue:)) ?? .emerald }
  var paper: PaperColor {
    switch self {
    case .emerald: Paper.signal
    case .teal: .init(light: .init(r: 0.05, g: 0.55, b: 0.66), dark: .init(r: 0.24, g: 0.72, b: 0.82))
    case .blue: .init(light: .init(r: 0.17, g: 0.42, b: 0.90), dark: .init(r: 0.38, g: 0.60, b: 0.97))
    case .indigo: .init(light: .init(r: 0.36, g: 0.34, b: 0.82), dark: .init(r: 0.52, g: 0.50, b: 0.98))
    case .purple: .init(light: .init(r: 0.58, g: 0.30, b: 0.84), dark: .init(r: 0.72, g: 0.50, b: 0.94))
    case .pink: .init(light: .init(r: 0.86, g: 0.25, b: 0.50), dark: .init(r: 0.94, g: 0.45, b: 0.63))
    case .red: .init(light: .init(r: 0.86, g: 0.22, b: 0.24), dark: .init(r: 0.95, g: 0.42, b: 0.42))
    case .orange: .init(light: .init(r: 0.93, g: 0.45, b: 0.09), dark: .init(r: 0.97, g: 0.60, b: 0.30))
    case .amber: .init(light: .init(r: 0.82, g: 0.60, b: 0.02), dark: .init(r: 0.94, g: 0.75, b: 0.24))
    case .graphite: .init(light: .init(r: 0.36, g: 0.36, b: 0.39), dark: .init(r: 0.66, g: 0.65, b: 0.63))
    }
  }
  /// Its name in the colour picker, for VoiceOver.
  var label: String { rawValue.capitalized }
}

/// How a widget is being drawn, and the colours that follow. Resolved once per entry view from the
/// rendering mode, whether the background shows, and the scheme; the preview injects it instead.
struct WidgetTone: Equatable {
  enum Mode: Equatable {
    /// Full colour on the paper background.
    case paper
    /// Full colour with the background taken away (StandBy, CarPlay): dark tokens, never ink on black.
    case removed
    /// A tinted or clear Home Screen: everything one colour, the accent group another.
    case accented
    /// The Lock Screen, and StandBy at night: monochrome.
    case vibrant
  }
  let mode: Mode
  let dark: Bool
  /// DEBUG preview only: stands in for the accent group, so `.primary` becomes white and accentable
  /// marks take this colour. Nil in a real widget, where the system does it.
  var tint: Color? = nil

  static func resolve(_ r: WidgetRenderingMode, background: Bool, scheme: ColorScheme) -> WidgetTone {
    if r == .accented { return .init(mode: .accented, dark: true) }
    if r == .vibrant { return .init(mode: .vibrant, dark: true) }
    return background ? .init(mode: .paper, dark: scheme == .dark) : .init(mode: .removed, dark: true)
  }

  /// Full colour: the mark keeps its emerald keyhole. Otherwise the keyhole is cut out of the iron.
  var fullColor: Bool { mode == .paper || mode == .removed }
  /// The container background; the system replaces it everywhere but `.paper`.
  var stage: Color { Paper.stage.color(dark: dark) }
  var ink: Color {
    if fullColor { return Paper.ink.color(dark: dark) }
    return tint == nil ? .primary : .white
  }
  var secondary: Color {
    if fullColor { return Paper.secondary.color(dark: dark) }
    return tint == nil ? .secondary : .white.opacity(0.6)
  }
  /// Trained days and the "Up next" eyebrow; pair it with `.widgetAccentable()`.
  var signal: Color {
    if fullColor { return Paper.signal.color(dark: dark) }
    return tint ?? .primary
  }
  /// Ink opacity for a past day with no workout, and for a day still to come (fainter, so the rest of
  /// the week never reads as missed).
  var past: Double { dots.past }
  var future: Double { dots.future }
  private var dots: (past: Double, future: Double) {
    switch mode {
    case .paper: (0.12, 0.05)
    case .removed: (0.18, 0.08)
    case .accented: (0.22, 0.10)
    case .vibrant: (0.30, 0.12)
    }
  }
}

private struct WidgetToneKey: EnvironmentKey {
  static let defaultValue = WidgetTone(mode: .paper, dark: false)
}

extension EnvironmentValues {
  var widgetTone: WidgetTone {
    get { self[WidgetToneKey.self] }
    set { self[WidgetToneKey.self] = newValue }
  }
}

/// One day as a dot, the same on every surface: filled when trained, a ring on today, faint before,
/// fainter after. Fill, ring and opacity carry the meaning, so colour is never the only signal.
struct DayDot: View {
  let mark: DayMark
  let size: CGFloat
  /// The split trained that day; nil is the signal emerald.
  var color: SplitColor? = nil
  @Environment(\.widgetTone) private var tone
  var body: some View {
    Group {
      switch mark {
      case .trained:
        Circle().fill(tone.fullColor ? (color ?? .emerald).paper.color(dark: tone.dark) : tone.signal).widgetAccentable()
      case .today: Circle().strokeBorder(tone.ink, lineWidth: size >= 11 ? 1.5 : 1.25)
      case .past: Circle().fill(tone.ink.opacity(tone.past))
      case .future: Circle().fill(tone.ink.opacity(tone.future))
      }
    }
    .frame(width: size, height: size)
  }
}
