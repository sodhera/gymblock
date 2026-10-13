import SwiftUI
import UIKit

/// The app's typeface in one place (12 Oct 2026): DM Sans, SleepBlock's face, on trial. Set `dmSans`
/// to false to go back to Apple's SF Pro everywhere. Text styles keep Dynamic Type (sizes scale from
/// iOS's defaults with the reader's setting). DM Sans ships as its variable font (optical size 9–40,
/// weight 100–1000) under the SIL Open Font License, Fonts/OFL.txt. Symbols keep the system font.
enum AppFont {
  static let dmSans = true

  /// iOS's default (Large) size and weight for each text style.
  static func base(_ style: Font.TextStyle) -> (size: CGFloat, weight: Font.Weight, ui: UIFont.TextStyle) {
    switch style {
    case .largeTitle: return (34, .regular, .largeTitle)
    case .title: return (28, .regular, .title1)
    case .title2: return (22, .regular, .title2)
    case .title3: return (20, .regular, .title3)
    case .headline: return (17, .semibold, .headline)
    case .subheadline: return (15, .regular, .subheadline)
    case .callout: return (16, .regular, .callout)
    case .footnote: return (13, .regular, .footnote)
    case .caption: return (12, .regular, .caption1)
    case .caption2: return (11, .regular, .caption2)
    default: return (17, .regular, .body)
    }
  }

  private static func axis(_ weight: Font.Weight) -> CGFloat {
    switch weight {
    case .ultraLight: 100
    case .thin: 200
    case .light: 300
    case .medium: 500
    case .semibold: 600
    case .bold: 700
    case .heavy: 800
    case .black: 900
    default: 400
    }
  }

  private static let opsz: UInt32 = 0x6F70_737A  // 'opsz'
  private static let wght: UInt32 = 0x7767_6874  // 'wght'

  /// DM Sans at this size and weight, its optical size matched to the size; nil if the font didn't
  /// register, so callers fall back to SF Pro rather than to nothing. The PostScript name carries the
  /// default optical size ("DMSans-9ptRegular"), not "DM Sans".
  static func uiFont(size: CGFloat, weight: Font.Weight) -> UIFont? {
    let descriptor = UIFontDescriptor(fontAttributes: [
      .name: "DMSans-9ptRegular",
      UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [opsz: min(max(size, 9), 40), wght: axis(weight)],
    ])
    let font = UIFont(descriptor: descriptor, size: size)
    return font.familyName.contains("DM Sans") ? font : nil
  }

  #if !LIVE_EXTENSION
  /// Navigation bar titles in the same face (UIKit draws those). The app only: widgets have no bars.
  static func styleBars() {
    guard dmSans else { return }
    let bar = UINavigationBar.appearance()
    if let large = uiFont(size: 34, weight: .bold) { bar.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)] }
    if let inline = uiFont(size: 17, weight: .semibold) { bar.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline)] }
  }
  #endif
}

extension Font {
  /// A text style in the app's typeface, scaled for Dynamic Type. Same arguments as `Font.system`.
  static func app(_ style: Font.TextStyle, design: Font.Design? = nil, weight: Font.Weight? = nil) -> Font {
    let base = AppFont.base(style)
    guard AppFont.dmSans, design == nil || design == .default,
          let font = AppFont.uiFont(size: UIFontMetrics(forTextStyle: base.ui).scaledValue(for: base.size), weight: weight ?? base.weight)
    else { return .system(style, design: design, weight: weight) }
    return Font(font)
  }

  /// A fixed size in the app's typeface. Same arguments as `Font.system(size:)`.
  static func app(size: CGFloat, weight: Font.Weight? = nil, design: Font.Design? = nil) -> Font {
    guard AppFont.dmSans, design == nil || design == .default, let font = AppFont.uiFont(size: size, weight: weight ?? .regular)
    else { return .system(size: size, weight: weight, design: design) }
    return Font(font)
  }
}
