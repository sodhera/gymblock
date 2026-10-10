import SwiftUI
import UIKit

/// One look everywhere: *paper*. A warm off-white stage with a faint peach light in the middle and
/// quiet ink dots, white Liquid Glass, ink type, an ink primary action, and one emerald signal that is
/// ≤2% of a screen and always the one thing to look at. Never a coloured background.
struct JourneyTheme {
  enum Backdrop { case solid, gradient(top: Color, bottom: Color) }
  let name: String
  let scheme: ColorScheme
  let stage: Color
  let backdrop: Backdrop
  let text: Color
  let secondary: Color
  let tertiary: Color
  /// The colour "ink" is drawn in: text on dark themes, near-black on light ones. Tracks, hairlines
  /// and quiet fills are this at low opacity, so they read on any stage.
  let ink: Color
  let raised: Color
  let glow: Color
  let glowAlpha: CGFloat
  let dot: Color
  let dotAlpha: CGFloat
  let vignette: CGFloat
  let signal: Color
  /// The one warm colour, for what costs you: time on the phone.
  let danger: Color
  let onAccent: Color
  /// The primary action's glass tint and the label on it.
  let button: Color
  let onButton: Color

  /// Warm off-white paper, ink type, emerald signal. Light appearance.
  static let paper = JourneyTheme(
    name: "paper", scheme: .light,
    stage: Color(red: 0.961, green: 0.953, blue: 0.937), backdrop: .solid,
    text: Color(red: 0.08, green: 0.08, blue: 0.09), secondary: Color(red: 0.40, green: 0.40, blue: 0.42),
    tertiary: Color(red: 0.58, green: 0.58, blue: 0.60), ink: Color(red: 0.08, green: 0.08, blue: 0.09),
    raised: Color.white, glow: Color(red: 1, green: 0.93, blue: 0.80), glowAlpha: 0.9,
    dot: Color(red: 0.08, green: 0.08, blue: 0.09), dotAlpha: 0.10, vignette: 0,
    signal: Color(red: 0.06, green: 0.60, blue: 0.42), danger: Color(red: 0.86, green: 0.25, blue: 0.21), onAccent: .white,
    button: Color(red: 0.08, green: 0.08, blue: 0.09), onButton: .white)
  /// The app's theme. Chosen on 8 Oct 2026 from three rendered directions (paper, an indigo dusk, a slate).
  static let current: JourneyTheme = .paper
}

enum JourneyColor {
  static var theme: JourneyTheme { JourneyTheme.current }
  static var stage: Color { theme.stage }
  static var signal: Color { theme.signal }
  /// Time lost to the phone: the only warm colour in the app.
  static var danger: Color { theme.danger }
  static var text: Color { theme.text }
  static var secondary: Color { theme.secondary }
  static var tertiary: Color { theme.tertiary }
  /// Ink at an opacity: tracks, hairlines, quiet fills, the dots on a chart.
  static func ink(_ opacity: Double) -> Color { theme.ink.opacity(opacity) }
  /// The raised surface before iOS 26 (and the glass tint on it).
  static var fill: Color { theme.ink.opacity(0.08) }
  static var raised: Color { theme.raised }
  static var hairline: Color { theme.ink.opacity(0.12) }
  /// The light the stage gives off; glass refracts it.
  static var glow: Color { theme.glow }
  /// The focal colour.
  static var accent: Color { theme.signal }
  /// Icons and labels drawn on top of `accent`.
  static var onAccent: Color { theme.onAccent }
  /// The primary action's colour and the label on it.
  static var button: Color { theme.button }
  static var onButton: Color { theme.onButton }
  /// The colour that fills the hold-to-commit button.
  static var commitFill: Color { theme.signal }
  /// Muscle tint: cool grey → light → signal.
  static func heat(_ value: Double) -> Color {
    let v = min(1, max(0, value))
    let s = UIColor(theme.signal); var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    s.getRed(&r, green: &g, blue: &b, alpha: &a)
    let mid: (Double, Double, Double) = theme.scheme == .dark ? (0.9, 0.92, 0.95) : (0.55, 0.58, 0.6)
    let stops: [(Double, (Double, Double, Double))] = [(0, (0.5, 0.52, 0.56)), (0.5, mid), (1, (Double(r), Double(g), Double(b)))]
    let i = v < 0.5 ? 0 : 1
    let (x, ca) = stops[i], (y, cb) = stops[i + 1]
    let p = (v - x) / (y - x)
    return Color(red: ca.0 + (cb.0 - ca.0) * p, green: ca.1 + (cb.1 - ca.1) * p, blue: ca.2 + (cb.2 - ca.2) * p)
  }
}

/// Apple text styles, so every string follows Dynamic Type. Headlines are the large title.
enum JourneyType {
  static let headline = Font.system(.title, design: .default, weight: .bold)
  static let display = Font.system(size: 52, weight: .bold, design: .default)
  static let option = Font.system(.body, design: .default, weight: .medium)
  static let button = Font.system(.headline, design: .default, weight: .semibold)
  static let label = Font.system(.subheadline, design: .default, weight: .medium)
  static let caption = Font.system(.footnote, design: .default, weight: .regular)
  static let eyebrow = Font.system(.subheadline, design: .default, weight: .medium)
}

/// Motion: calm, slightly slow, never bouncy. One curve family everywhere.
enum JourneyMotion {
  static func reduced(_ system: Bool) -> Bool {
    #if DEBUG
    return system || ProcessInfo.processInfo.arguments.contains("--ui-reduced-motion")
    #else
    return system
    #endif
  }
  static let page = Animation.smooth(duration: 0.6)
  static let settle = 0.4  // Scenes start once the page has faded in (0.35 s).
  static let gentle = Animation.spring(duration: 0.55, bounce: 0.12)
}

// MARK: - Haptics

/// Designed haptics: prepared generators (no latency) and a few patterns with meaning.
@MainActor enum JourneyHaptic {
  case selection, light, soft, medium, rigid, heavy, success
  private static let selector = UISelectionFeedbackGenerator()
  private static let notifier = UINotificationFeedbackGenerator()
  private static var impacts: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
  private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
    if let g = impacts[style] { return g }
    let g = UIImpactFeedbackGenerator(style: style); g.prepare(); impacts[style] = g; return g
  }
  static func play(_ kind: Self, _ profile: Profile, intensity: CGFloat = 1) {
    guard profile.hapticsEnabled ?? true else { return }
    switch kind {
    case .selection: selector.selectionChanged(); selector.prepare()
    case .light: impact(.light).impactOccurred(intensity: intensity)
    case .soft: impact(.soft).impactOccurred(intensity: intensity)
    case .medium: impact(.medium).impactOccurred(intensity: intensity)
    case .rigid: impact(.rigid).impactOccurred(intensity: intensity)
    case .heavy: impact(.heavy).impactOccurred(intensity: intensity)
    case .success: notifier.notificationOccurred(.success); notifier.prepare()
    }
  }
  /// The iOS notification feel: two quick taps.
  static func notification(_ profile: Profile) {
    play(.light, profile, intensity: 0.8)
    Task { @MainActor in try? await Task.sleep(for: .milliseconds(90)); play(.light, profile, intensity: 0.55) }
  }
  /// A thud: something landed.
  static func land(_ profile: Profile) {
    play(.heavy, profile, intensity: 0.85)
    Task { @MainActor in try? await Task.sleep(for: .milliseconds(70)); play(.soft, profile, intensity: 0.5) }
  }
  /// Ticks that grow stronger, spread over `duration`.
  static func crescendo(_ profile: Profile, count: Int, duration: Double) async {
    for i in 0..<count {
      play(.light, profile, intensity: 0.25 + 0.75 * CGFloat(i) / CGFloat(max(1, count - 1)))
      try? await Task.sleep(for: .seconds(duration / Double(max(1, count))))
      if Task.isCancelled { return }
    }
  }
}

// MARK: - Stage

/// The graphite stage, drawn once into a cached bitmap so it costs nothing while anything above it animates.
/// A wide cool wash, a tighter core behind the stage area, dots that brighten towards the glow, and a soft
/// vignette at the edges: enough light for glass to refract, never a coloured background.
struct DotGrid: View {
  var body: some View {
    GeometryReader { g in Image(uiImage: Self.image(g.size)).resizable() }
      .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
  }
  @MainActor private static var cache: [String: UIImage] = [:]
  @MainActor static func image(_ size: CGSize) -> UIImage {
    let size = CGSize(width: max(1, size.width.rounded()), height: max(1, size.height.rounded()))
    let key = JourneyTheme.current.name + "-\(size.width)x\(size.height)"
    if let cached = cache[key] { return cached }
    let image = UIGraphicsImageRenderer(size: size).image { r in
      let c = r.cgContext
      Self.draw(in: c, size: size)
    }
    cache[key] = image
    return image
  }
  /// Shared with the app icon so every surface is the same stage.
  static func draw(in c: CGContext, size: CGSize, glowScale: CGFloat = 1) {
    let t = JourneyTheme.current
    let space = CGColorSpaceCreateDeviceRGB()
    c.setFillColor(UIColor(t.stage).cgColor); c.fill(CGRect(origin: .zero, size: size))
    if case .gradient(let top, let bottom) = t.backdrop,
       let g = CGGradient(colorsSpace: space, colors: [UIColor(top).cgColor, UIColor(bottom).cgColor] as CFArray, locations: [0, 1]) {
      c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }
    let center = CGPoint(x: size.width / 2, y: size.height * 0.40)
    func radial(_ alpha: CGFloat, _ radius: CGFloat, at point: CGPoint) {
      let glow = UIColor(t.glow).withAlphaComponent(alpha * t.glowAlpha)
      let colors = [glow.cgColor, glow.withAlphaComponent(alpha * t.glowAlpha * 0.35).cgColor, glow.withAlphaComponent(0).cgColor] as CFArray
      if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1]) {
        c.drawRadialGradient(gradient, startCenter: point, startRadius: 0, endCenter: point, endRadius: radius, options: [])
      }
    }
    // A wide wash, then a tighter core, so the middle of the page carries the light.
    radial(t.scheme == .dark ? 0.07 : 0.55, size.width * 1.05 * glowScale, at: center)
    radial(t.scheme == .dark ? 0.09 : 0.45, size.width * 0.50 * glowScale, at: center)
    // Dots, brightening towards the core.
    let step: CGFloat = 22, radius: CGFloat = 1.0
    let reach = hypot(size.width, size.height) * 0.56
    var y = step / 2
    while y < size.height {
      var x = size.width.truncatingRemainder(dividingBy: step) / 2
      while x < size.width {
        let d = min(1, hypot(x - center.x, y - center.y) / reach)
        c.setFillColor(UIColor(t.dot).withAlphaComponent(t.dotAlpha * (0.25 + 0.75 * pow(1 - d, 1.6))).cgColor)
        c.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius))
        x += step
      }
      y += step
    }
    // A soft vignette keeps the edges quiet and the content in the middle (dark themes only).
    if t.vignette > 0 {
      let edge = UIColor.black
      let vignette = [edge.withAlphaComponent(0).cgColor, edge.withAlphaComponent(t.vignette).cgColor] as CFArray
      if let gradient = CGGradient(colorsSpace: space, colors: vignette, locations: [0.55, 1]) {
        let corner = CGPoint(x: size.width / 2, y: size.height / 2)
        c.drawRadialGradient(gradient, startCenter: corner, startRadius: 0, endCenter: corner, endRadius: hypot(size.width, size.height) * 0.62, options: [])
      }
    }
  }
}

// MARK: - Liquid Glass

extension View {
  /// Liquid Glass on iOS 26 with a faint top light so every raised surface reads as raised;
  /// a quiet translucent fill before that.
  @ViewBuilder func journeyGlass<S: InsettableShape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        .overlay(shape.strokeBorder(JourneyRim.gradient, lineWidth: 0.8).allowsHitTesting(false))
    } else {
      self.background(shape.fill(tint?.opacity(0.35) ?? JourneyColor.raised.opacity(0.9)))
        .overlay(shape.strokeBorder(JourneyRim.gradient, lineWidth: 1).allowsHitTesting(false))
    }
  }
  /// A raised glass surface that is only decoration: content goes in front of it.
  func journeySurface(cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
    journeyGlass(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint)
  }
}

/// The top-lit edge every glass surface shares.
enum JourneyRim {
  static var gradient: LinearGradient {
    let light = JourneyTheme.current.scheme == .dark
    return LinearGradient(
      colors: light ? [Color.white.opacity(0.22), Color.white.opacity(0.06), Color.white.opacity(0.02)]
                    : [Color.white.opacity(0.9), Color.white.opacity(0.5), Color.black.opacity(0.04)],
      startPoint: .top, endPoint: .bottom)
  }
}

/// Groups glass shapes so they blend and morph together.
struct JourneyGlassGroup<Content: View>: View {
  var spacing: CGFloat = 10
  @ViewBuilder var content: Content
  var body: some View {
    if #available(iOS 26.0, *) { GlassEffectContainer(spacing: spacing) { content } } else { content }
  }
}

struct JourneyPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .animation(.smooth(duration: 0.25), value: configuration.isPressed)
  }
}

/// The primary action: bright, prominent Liquid Glass. Disabled, it stays in place at low opacity
/// so the page never looks like it is missing its button.
struct JourneyButton: View {
  let title: String
  var symbol: String? = nil
  var id = ""
  var enabled = true
  /// A spinner in place of the label, at the same size, while the tap is being answered.
  var loading = false
  let action: () -> Void
  var body: some View {
    let label = ZStack {
      HStack(spacing: 8) {
        if let symbol { Image(systemName: symbol).font(.system(.headline, weight: .semibold)).accessibilityHidden(true) }
        Text(title).font(JourneyType.button).lineLimit(1).minimumScaleFactor(0.8)
      }.opacity(loading ? 0 : 1)
      if loading { ProgressView().tint(JourneyColor.onButton) }
    }.foregroundStyle(JourneyColor.onButton).frame(maxWidth: .infinity, minHeight: 22)
    let tapped = { Analytics.tap(id); action() }
    Group {
      if #available(iOS 26.0, *) {
        Button(action: tapped) { label }.buttonStyle(.glassProminent).tint(JourneyColor.button)
      } else {
        Button(action: tapped) { label.frame(minHeight: 50).background(Capsule().fill(JourneyColor.button)) }.buttonStyle(JourneyPressStyle())
      }
    }.controlSize(.large).buttonBorderShape(.capsule)
      .disabled(!enabled).opacity(enabled ? 1 : 0.38)
      .animation(.smooth(duration: 0.45), value: enabled)
      .accessibilityIdentifier(id)
  }
}

struct JourneyTextButton: View {
  let title: String
  var id = ""
  let action: () -> Void
  var body: some View {
    Button(action: { Analytics.tap(id); action() }) {
      Text(title).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityIdentifier(id)
  }
}

/// An answer. Selecting only selects; Continue moves on. A chosen answer rises (brighter glass,
/// a white edge) and the red check is the only red on the page.
struct JourneyOption: View {
  let title: String
  let selected: Bool
  let id: String
  var detail: String? = nil
  let action: () -> Void
  var body: some View {
    Button(action: { Analytics.tap(id); action() }) {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(JourneyType.option).foregroundStyle(JourneyColor.text).lineLimit(1)
          if let detail { Text(detail).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).lineLimit(1) }
        }
        Spacer(minLength: 8)
        Image(systemName: "checkmark.circle.fill").font(.system(.body, weight: .semibold))
          .symbolRenderingMode(.palette).foregroundStyle(JourneyColor.onAccent, JourneyColor.accent)
          .opacity(selected ? 1 : 0).scaleEffect(selected ? 1 : 0.6).accessibilityHidden(true)
      }.padding(.horizontal, 18).frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .journeyGlass(RoundedRectangle(cornerRadius: 18, style: .continuous),
                      tint: selected ? JourneyColor.ink(0.12) : nil, interactive: true)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(JourneyColor.ink(selected ? 0.5 : 0), lineWidth: 1.5))
    }.buttonStyle(JourneyPressStyle())
      .animation(JourneyMotion.gentle, value: selected)
      .accessibilityIdentifier(id).accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// A back button in a glass circle.
struct JourneyBackButton: View {
  let label: String
  let action: () -> Void
  var body: some View {
    let icon = Image(systemName: "chevron.left").font(.system(.footnote, weight: .bold)).foregroundStyle(JourneyColor.text)
      .frame(width: 36, height: 36)
    Group {
      if #available(iOS 26.0, *) {
        Button(action: action) { icon }.buttonStyle(.glass).buttonBorderShape(.circle)
      } else {
        Button(action: action) { icon.background(Circle().fill(JourneyColor.fill)) }.buttonStyle(JourneyPressStyle())
      }
    }.accessibilityLabel(label).accessibilityIdentifier("onboarding.back")
  }
}

struct JourneyProgress: View {
  let value: Double
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(JourneyColor.ink(0.12))
        Capsule().fill(JourneyColor.ink(0.9)).frame(width: max(3, g.size.width * value))
      }
    }.frame(height: 3).animation(.smooth(duration: 0.7), value: value)
      .accessibilityElement().accessibilityValue(Text("\(Int(value * 100))%"))
  }
}

/// The wordmark: the mark beside the name.
struct Wordmark: View {
  var body: some View {
    HStack(spacing: 8) {
      BrandMark(size: 18)
      Text("GymBlock").font(.system(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
    }.accessibilityElement(children: .ignore).accessibilityLabel("GymBlock")
  }
}

/// A small label above a block of content: sentence case, the subheadline style, secondary colour.
struct Eyebrow: View {
  let text: String
  var body: some View {
    Text(text).font(JourneyType.eyebrow).foregroundStyle(JourneyColor.secondary)
  }
}

/// Animates a number by re-rendering only this text.
struct CountingText: View, Animatable {
  var value: Double
  var format: (Double) -> String
  var animatableData: Double { get { value } set { value = newValue } }
  var body: some View { Text(format(value)) }
}
