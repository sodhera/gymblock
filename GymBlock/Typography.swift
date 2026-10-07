import SwiftUI
import UIKit

/// SF Pro, scaled with Dynamic Type, matching the onboarding.
/// Already-scaled workout numbers do not scale twice.
enum GymType {
  static func uiFont(_ size: CGFloat, weight: CGFloat = 400) -> UIFont {
    let w: UIFont.Weight = weight >= 650 ? .bold : weight >= 550 ? .semibold : weight >= 450 ? .medium : .regular
    return UIFont.systemFont(ofSize: size, weight: w)
  }
  private static func scaled(_ size: CGFloat, weight: CGFloat, style: UIFont.TextStyle) -> Font {
    Font(UIFontMetrics(forTextStyle: style).scaledFont(for: uiFont(size, weight: weight)))
  }
  static func hero(_ size: CGFloat) -> Font { scaled(size, weight: 600, style: .largeTitle) }
  static func title(_ size: CGFloat) -> Font { scaled(size, weight: 700, style: .title2) }
  static func body(_ size: CGFloat) -> Font { scaled(size, weight: 400, style: .body) }
  static func label(_ size: CGFloat) -> Font { scaled(size, weight: 500, style: .headline) }
  static func number(_ size: CGFloat) -> Font { Font(uiFont(size, weight: 500)) }
}

/// The ember stage behind every page, as in onboarding.
struct GymBackdrop: View {
  var body: some View { DotGrid() }
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
  @ViewBuilder func gymSearchNavigation() -> some View {
    if #available(iOS 17.1, *) { searchPresentationToolbarBehavior(.avoidHidingContent) }
    else { self }
  }
}
