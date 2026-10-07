import SwiftUI
import UIKit

/// Onboarding palette. Roughly 90% stage, 8% neutrals, ≤2% accent:
/// red marks the one thing to look at on a screen, never decoration.
enum JourneyColor {
  static let stage = Color(red: 0.035, green: 0.035, blue: 0.04)
  static let text = Color(white: 0.96)
  static let secondary = Color(white: 0.56)
  static let tertiary = Color(white: 0.34)
  static let fill = Color.white.opacity(0.06)
  static let hairline = Color.white.opacity(0.1)
  static let accent = Color(red: 1.0, green: 0.27, blue: 0.23)
  /// Muscle tint: cool grey → warm neutral → accent.
  static func heat(_ value: Double) -> Color {
    let v = min(1, max(0, value))
    let stops: [(Double, (Double, Double, Double))] = [(0, (0.5, 0.5, 0.52)), (0.5, (0.93, 0.87, 0.85)), (1, (1.0, 0.27, 0.23))]
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

enum JourneyHaptic {
  case selection, light, soft, rigid, success
  @MainActor static func play(_ kind: Self, _ profile: Profile) {
    guard profile.hapticsEnabled ?? true else { return }
    switch kind {
    case .selection: UISelectionFeedbackGenerator().selectionChanged()
    case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
    case .soft: UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
    case .rigid: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
    case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
  }
}

// MARK: - Stage

/// A quiet dotted field, brightest at the centre. Rendered once into a bitmap and reused,
/// so it costs nothing while anything above it animates.
struct DotGrid: View {
  @MainActor private static var cache: [String: UIImage] = [:]
  var body: some View {
    GeometryReader { g in
      Image(uiImage: Self.image(g.size)).resizable().ignoresSafeArea()
    }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
  }
  @MainActor static func image(_ size: CGSize) -> UIImage {
    let size = CGSize(width: max(1, size.width.rounded()), height: max(1, size.height.rounded()))
    let key = "\(size.width)x\(size.height)"
    if let cached = cache[key] { return cached }
    let image = UIGraphicsImageRenderer(size: size).image { r in
      let c = r.cgContext
      c.setFillColor(UIColor(JourneyColor.stage).cgColor); c.fill(CGRect(origin: .zero, size: size))
      let step: CGFloat = 22, radius: CGFloat = 0.9
      let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
      let reach = hypot(size.width, size.height) * 0.58
      var y = step / 2
      while y < size.height {
        var x = size.width.truncatingRemainder(dividingBy: step) / 2
        while x < size.width {
          let d = min(1, hypot(x - center.x, y - center.y) / reach)
          c.setFillColor(UIColor(white: 1, alpha: 0.03 + 0.09 * pow(1 - d, 1.4)).cgColor)
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

// MARK: - Controls

struct JourneyPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.85 : 1)
      .animation(.smooth(duration: 0.2), value: configuration.isPressed)
  }
}

/// White capsule, black label: the brightest object on every screen.
struct JourneyButton: View {
  let title: String
  var id = ""
  var enabled = true
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title).font(JourneyType.button).foregroundStyle(.black)
        .lineLimit(1).minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Capsule().fill(Color.white))
        .contentShape(Capsule())
    }.buttonStyle(JourneyPressStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.3)
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
        Image(systemName: "checkmark").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
          .opacity(selected ? 1 : 0).scaleEffect(selected ? 1 : 0.5).accessibilityHidden(true)
      }.padding(.horizontal, 22).frame(maxWidth: .infinity, minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(selected ? Color.white.opacity(0.14) : JourneyColor.fill))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? Color.white.opacity(0.7) : JourneyColor.hairline, lineWidth: selected ? 1.5 : 1))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(JourneyPressStyle())
      .animation(.smooth(duration: 0.25), value: selected)
      .accessibilityIdentifier(id).accessibilityAddTraits(selected ? .isSelected : [])
  }
}

struct JourneyProgress: View {
  let value: Double
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.1))
        Capsule().fill(Color.white.opacity(0.85)).frame(width: max(3, g.size.width * value))
      }
    }.frame(height: 3).animation(.smooth(duration: 0.5), value: value)
      .accessibilityElement().accessibilityValue(Text("\(Int(value * 100))%"))
  }
}

/// A labelled value with − and + buttons: immediately understandable, one tap per change.
struct JourneyStepper: View {
  let label: String
  let value: String
  let id: String
  let canDecrease: Bool
  let canIncrease: Bool
  let change: (Int) -> Void
  var body: some View {
    HStack(spacing: 12) {
      Text(label).font(.body).foregroundStyle(JourneyColor.secondary).lineLimit(1).minimumScaleFactor(0.8)
      Spacer(minLength: 8)
      button("minus", -1, enabled: canDecrease)
      Text(value).font(.system(.headline, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        .contentTransition(.numericText()).frame(minWidth: 58)
        .accessibilityIdentifier(id + ".value")
      button("plus", 1, enabled: canIncrease)
    }.frame(minHeight: 48)
      .accessibilityElement(children: .contain).accessibilityIdentifier(id)
  }
  private func button(_ symbol: String, _ delta: Int, enabled: Bool) -> some View {
    Button { change(delta) } label: {
      Image(systemName: symbol).font(.system(.subheadline, weight: .bold)).foregroundStyle(JourneyColor.text)
        .frame(width: 36, height: 36).background(Circle().fill(JourneyColor.fill))
        .frame(width: 44, height: 44).contentShape(Rectangle())
    }.buttonStyle(JourneyPressStyle()).disabled(!enabled).opacity(enabled ? 1 : 0.3)
      .accessibilityLabel(label + (delta < 0 ? " −" : " +")).accessibilityIdentifier(id + (delta < 0 ? ".minus" : ".plus"))
  }
}

/// Animates a number by re-rendering only this text.
struct CountingText: View, Animatable {
  var value: Double
  var format: (Double) -> String
  var animatableData: Double { get { value } set { value = newValue } }
  var body: some View { Text(format(value)) }
}
