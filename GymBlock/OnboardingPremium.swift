import SwiftUI
import UIKit

/// Onboarding colour: one dark *ember* stage — near-black with warm red-tinted dots and a low glow.
/// Red (#FF626B, the app's dark-mode red) is the signal: ≤2% of a screen, always the one thing to look at.
enum JourneyColor {
  static let stage = Color(red: 0.035, green: 0.031, blue: 0.035)
  static let signalRed = Color(red: 1, green: 0x62 / 255, blue: 0x6B / 255)
  static let text = Color(white: 0.96)
  static let secondary = Color(white: 0.64)
  static let tertiary = Color(white: 0.5)
  static let fill = Color.white.opacity(0.07)
  static let hairline = Color.white.opacity(0.11)
  /// The focal colour.
  static let accent = signalRed
  /// Icons and labels drawn on top of `accent`.
  static let onAccent = Color.white
  /// Primary button label (the button itself is white glass).
  static let onButton = Color.black
  /// The colour that fills the hold-to-commit button.
  static let commitFill = signalRed
  /// Muscle tint: cool grey → warm → signal red.
  static func heat(_ value: Double) -> Color {
    let v = min(1, max(0, value))
    let stops: [(Double, (Double, Double, Double))] = [(0, (0.5, 0.5, 0.52)), (0.5, (0.93, 0.86, 0.85)), (1, (1.0, 0.384, 0.42))]
    let i = v < 0.5 ? 0 : 1
    let (a, ca) = stops[i], (b, cb) = stops[i + 1]
    let p = (v - a) / (b - a)
    return Color(red: ca.0 + (cb.0 - ca.0) * p, green: ca.1 + (cb.1 - ca.1) * p, blue: ca.2 + (cb.2 - ca.2) * p)
  }
}

/// Apple text styles, so every string follows Dynamic Type.
enum JourneyType {
  static let headline = Font.system(.title, design: .default, weight: .bold)
  static let option = Font.system(.title3, design: .default, weight: .medium)
  static let button = Font.system(.headline, design: .default, weight: .semibold)
  static let label = Font.system(.subheadline, design: .default, weight: .medium)
  static let caption = Font.system(.footnote, design: .default, weight: .regular)
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

/// The ember stage, drawn once into a cached bitmap so it costs nothing while anything above it animates.
struct DotGrid: View {
  var body: some View {
    GeometryReader { g in Image(uiImage: Self.image(g.size)).resizable() }
      .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
  }
  @MainActor private static var cache: [String: UIImage] = [:]
  @MainActor static func image(_ size: CGSize) -> UIImage {
    let size = CGSize(width: max(1, size.width.rounded()), height: max(1, size.height.rounded()))
    let key = "\(size.width)x\(size.height)"
    if let cached = cache[key] { return cached }
    let image = UIGraphicsImageRenderer(size: size).image { r in
      let c = r.cgContext
      c.setFillColor(UIColor(JourneyColor.stage).cgColor); c.fill(CGRect(origin: .zero, size: size))
      // A low, warm glow gives glass something to refract.
      let glow = UIColor(red: 1, green: 0.38, blue: 0.42, alpha: 0.09)
      let colors = [glow.cgColor, glow.withAlphaComponent(0).cgColor] as CFArray
      if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.42)
        c.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width * 0.95, options: [])
      }
      let step: CGFloat = 22, radius: CGFloat = 0.95
      let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
      let reach = hypot(size.width, size.height) * 0.58
      var y = step / 2
      while y < size.height {
        var x = size.width.truncatingRemainder(dividingBy: step) / 2
        while x < size.width {
          let d = min(1, hypot(x - center.x, y - center.y) / reach)
          c.setFillColor(UIColor(red: 1, green: 0.42, blue: 0.4, alpha: 0.05 + 0.16 * pow(1 - d, 1.4)).cgColor)
          c.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius))
          x += step
        }
        y += step
      }
    }
    cache[key] = image
    return image
  }
}

// MARK: - Liquid Glass

extension View {
  /// Liquid Glass on iOS 26; a quiet translucent fill before that.
  @ViewBuilder func journeyGlass<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      self.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
    } else {
      self.background(shape.fill(tint?.opacity(0.35) ?? JourneyColor.fill))
        .overlay(shape.stroke(JourneyColor.hairline, lineWidth: 1))
    }
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

/// The primary action: bright, prominent Liquid Glass.
struct JourneyButton: View {
  let title: String
  var id = ""
  var enabled = true
  let action: () -> Void
  var body: some View {
    let label = Text(title).font(JourneyType.button).foregroundStyle(JourneyColor.onButton)
      .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, minHeight: 26)
    Group {
      if #available(iOS 26.0, *) {
        Button(action: action) { label }.buttonStyle(.glassProminent).tint(.white)
      } else {
        Button(action: action) { label.frame(minHeight: 56).background(Capsule().fill(Color.white)) }.buttonStyle(JourneyPressStyle())
      }
    }.controlSize(.large).buttonBorderShape(.capsule)
      .disabled(!enabled).opacity(enabled ? 1 : 0.35)
      .accessibilityIdentifier(id)
  }
}

struct JourneyTextButton: View {
  let title: String
  var id = ""
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityIdentifier(id)
  }
}

/// An answer. Selecting only selects; Continue moves on.
struct JourneyOption: View {
  let title: String
  let selected: Bool
  let id: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack {
        Text(title).font(JourneyType.option).foregroundStyle(JourneyColor.text)
        Spacer(minLength: 8)
        Image(systemName: "checkmark.circle.fill").font(.system(.title3, weight: .semibold))
          .symbolRenderingMode(.palette).foregroundStyle(JourneyColor.onAccent, JourneyColor.accent)
          .opacity(selected ? 1 : 0).scaleEffect(selected ? 1 : 0.6).accessibilityHidden(true)
      }.padding(.horizontal, 22).frame(maxWidth: .infinity, minHeight: 60)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous),
                      tint: selected ? JourneyColor.accent.opacity(0.28) : nil, interactive: true)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(JourneyColor.accent.opacity(selected ? 0.8 : 0), lineWidth: 1.5))
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
    let icon = Image(systemName: "chevron.left").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
      .frame(width: 44, height: 44)
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
        Capsule().fill(Color.white.opacity(0.14))
        Capsule().fill(Color.white.opacity(0.9)).frame(width: max(3, g.size.width * value))
      }
    }.frame(height: 3).animation(.smooth(duration: 0.7), value: value)
      .accessibilityElement().accessibilityValue(Text("\(Int(value * 100))%"))
  }
}

/// Animates a number by re-rendering only this text.
struct CountingText: View, Animatable {
  var value: Double
  var format: (Double) -> String
  var animatableData: Double { get { value } set { value = newValue } }
  var body: some View { Text(format(value)) }
}
