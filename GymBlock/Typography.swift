import SwiftUI
import UIKit

/// Speaking Coach's bundled DM Sans, including its weight and optical-size axes.
/// Text follows the user's preferred size; already-scaled workout numbers do not scale twice.
enum GymType {
  static func uiFont(_ size: CGFloat, weight: CGFloat = 400) -> UIFont {
    let descriptor = UIFontDescriptor(fontAttributes: [
      .name: "DMSans-9ptRegular",
      UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
        0x6F70_737A: min(max(size, 9), 40), 0x7767_6874: weight,
      ],
    ])
    return UIFont(descriptor: descriptor, size: size)
  }
  private static func scaled(_ size: CGFloat, weight: CGFloat, style: UIFont.TextStyle) -> Font {
    Font(UIFontMetrics(forTextStyle: style).scaledFont(for: uiFont(size, weight: weight)))
  }
  static func hero(_ size: CGFloat) -> Font { scaled(size, weight: 600, style: .largeTitle) }
  static func title(_ size: CGFloat) -> Font { scaled(size, weight: 500, style: .title2) }
  static func body(_ size: CGFloat) -> Font { scaled(size, weight: 400, style: .body) }
  static func label(_ size: CGFloat) -> Font { scaled(size, weight: 500, style: .headline) }
  static func number(_ size: CGFloat) -> Font { Font(uiFont(size, weight: 500)) }
}

/// The same restrained paper and dot-grid vocabulary as Speaking Coach.
/// Workout controls sit on solid surfaces so the texture never competes with numbers.
struct GymBackdrop: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  var body: some View {
    ZStack {
      GymColor.ground
      if !reduceTransparency && contrast != .increased {
        Canvas { context, size in
          for x in stride(from: 11.0, to: size.width, by: 22) {
            for y in stride(from: 11.0, to: size.height, by: 22) {
              context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                with: .color(GymColor.ink.opacity(0.11)))
            }
          }
        }
      }
    }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
  }
}
struct GymCard: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast
  func body(content: Content) -> some View {
    content
      .background(GymColor.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
      .overlay {
        if contrast == .increased {
          RoundedRectangle(cornerRadius: 26).strokeBorder(GymColor.dim, lineWidth: 1)
        }
      }
      .shadow(color: GymColor.ink.opacity(reduceTransparency ? 0 : 0.06), radius: 20, y: 10)
  }
}
extension View {
  func gymCard() -> some View { modifier(GymCard()) }
  func gymPage() -> some View { scrollContentBackground(.hidden).background(GymBackdrop()) }
}
