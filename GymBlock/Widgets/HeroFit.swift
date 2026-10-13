import CoreText
import SwiftUI
import UIKit

/// Type in widgets. Home Screen words are DM Sans at fixed sizes (a widget doesn't take the app's
/// Dynamic Type scaling); every ticking clock is SF Pro with monospaced digits, because DM Sans has no
/// tabular figures and its digits would jitter; accessory families and the Live Activity are SF Pro only.
enum WidgetType {
  /// The one switch. Set it to false if WidgetKit's archive loses DM Sans's variation axes (bold
  /// rendering as regular): the widgets then measure and draw in SF Pro.
  static let useDMSans = AppFont.dmSans

  /// Words at a fixed size: DM Sans, or SF Pro when it's off or didn't register.
  static func words(_ size: CGFloat, _ weight: Font.Weight) -> Font {
    guard useDMSans, let font = AppFont.uiFont(size: size, weight: weight) else { return .system(size: size, weight: weight) }
    return Font(font)
  }

  /// The same face as `words`, for measuring.
  static func uiFont(_ size: CGFloat, _ weight: Font.Weight) -> UIFont {
    (useDMSans ? AppFont.uiFont(size: size, weight: weight) : nil) ?? .systemFont(ofSize: size, weight: uiWeight(weight))
  }

  private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
    switch weight {
    case .ultraLight: .ultraLight
    case .thin: .thin
    case .light: .light
    case .medium: .medium
    case .semibold: .semibold
    case .bold: .bold
    case .heavy: .heavy
    case .black: .black
    default: .regular
    }
  }
}

/// The largest hero that really fits its box, by measuring the text, never by a `minimumScaleFactor`
/// floor. Words are never broken; a short form (Spanish "Entreno libre") is used only where the full
/// form can't fit at a size worth reading.
struct HeroFit: Equatable {
  let text: String
  let size: CGFloat
  let tracking: CGFloat
  /// The lines it takes: the line limit to draw it with.
  let lines: Int
  let showsCaption: Bool
  /// Moves the hero left so its first stem lines up with the status line's, −4…0.
  let nudge: CGFloat
  /// Nothing fit (an unbreakable word in the user's own split name): drawn at the ladder's last size,
  /// allowed down to 0.8 and truncated at the tail.
  let scaled: Bool

  /// The caption's line under a one-line hero: DM Sans 13 (16.9) and its 2-pt gap.
  static let captionSlot: CGFloat = 18.9

  /// Tighter as it grows: −1 from 30 pt, −0.6 at 26–28, −0.4 below.
  static func tracking(_ size: CGFloat) -> CGFloat { size >= 30 ? -1 : size >= 26 ? -0.6 : -0.4 }

  /// Tries `hero`, then `short`, down the ladder (largest first), wrapping greedily at `W − 1`. A size
  /// fits when its lines are within `maxLines` (one when `captionRequired`, which reserves the caption
  /// for the sample marker) and their height, plus the caption under a single line, is within `H`.
  /// `hero` isn't tried below `floor` when a short form exists. `status` is the line above the hero;
  /// only its first glyph matters (a plain stem by default).
  static func pick(hero: String, short: String?, width W: CGFloat, budget H: CGFloat,
                   ladder: [CGFloat], maxLines: Int, preferFullDownTo floor: CGFloat,
                   caption: Bool, captionRequired: Bool, status: String = "H") -> HeroFit {
    var candidates = [hero]
    if let short, !short.isEmpty, short != hero { candidates.append(short) }
    let cap = captionRequired ? 1 : max(1, maxLines)
    let captioned = caption || captionRequired
    for (index, text) in candidates.enumerated() {
      let preferShort = index == 0 && candidates.count > 1
      for size in ladder {
        if preferShort && size < floor { break }
        let font = WidgetType.uiFont(size, .bold), kern = Self.tracking(size)
        guard let lines = lineCount(text, font: font, tracking: kern, width: W - 1), lines <= cap else { continue }
        guard CGFloat(lines) * font.lineHeight + (lines == 1 && captioned ? captionSlot : 0) <= H else { continue }
        return HeroFit(text: text, size: size, tracking: kern, lines: lines, showsCaption: captioned && lines == 1,
                       nudge: nudge(text, font: font, status: status), scaled: false)
      }
    }
    let text = candidates[candidates.count - 1], size = ladder.last ?? 22
    return HeroFit(text: text, size: size, tracking: Self.tracking(size), lines: cap, showsCaption: captioned && cap == 1,
                   nudge: nudge(text, font: WidgetType.uiFont(size, .bold), status: status), scaled: true)
  }

  /// Greedy word wrap: the number of lines, or nil if a single word is wider than the line.
  private static func lineCount(_ text: String, font: UIFont, tracking: CGFloat, width: CGFloat) -> Int? {
    let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
    var lines = 1, line = ""
    for word in words {
      if measure(word, font, tracking) > width { return nil }
      let joined = line.isEmpty ? word : line + " " + word
      if line.isEmpty || measure(joined, font, tracking) <= width { line = joined } else { lines += 1; line = word }
    }
    return lines
  }

  private static func measure(_ s: String, _ font: UIFont, _ tracking: CGFloat) -> CGFloat {
    (s as NSString).size(withAttributes: [.font: font, .kern: tracking]).width
  }

  /// Big type's side bearing grows with its size, so a 40-pt "P" starts visibly right of a 15-pt
  /// eyebrow. The difference between the two first glyphs' left bearings pulls it back into line.
  private static func nudge(_ hero: String, font: UIFont, status: String) -> CGFloat {
    let lead = leftBearing(hero, font) - leftBearing(status, WidgetType.uiFont(15, .medium))
    return min(0, max(-4, -lead))
  }

  private static func leftBearing(_ text: String, _ font: UIFont) -> CGFloat {
    guard let first = text.first else { return 0 }
    let units = Array(String(first).utf16), ct = font as CTFont
    var glyphs = [CGGlyph](repeating: 0, count: units.count)
    guard CTFontGetGlyphsForCharacters(ct, units, &glyphs, units.count) else { return 0 }
    return CTFontGetBoundingRectsForGlyphs(ct, .horizontal, glyphs, nil, 1).minX
  }
}

/// A fitted hero, drawn as measured: bold in the widget face, tracked, never tightened, nudged into
/// line with the status above it. In ink; the caller lays it out inside the measured box.
struct HeroText: View {
  let fit: HeroFit
  @Environment(\.widgetTone) private var tone
  var body: some View {
    Text(fit.text)
      .font(WidgetType.words(fit.size, .bold))
      .tracking(fit.tracking)
      .lineLimit(fit.lines)
      .allowsTightening(false)
      .minimumScaleFactor(fit.scaled ? 0.8 : 1)
      .truncationMode(.tail)
      .foregroundStyle(tone.ink)
      .offset(x: fit.nudge)
  }
}
