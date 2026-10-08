import SwiftUI

/// The brand mark: a padlock whose keyhole is a barbell. The barbell is the key. Solid ink body
/// and shackle; the barbell cut in the emerald signal is the only colour. The same geometry, in the
/// same unit square (y down), as the app icon in `scripts/generate-app-icon.swift`; keep the two
/// tables identical.
struct BrandMark: View {
  var size: CGFloat = 28

  enum Piece {
    /// A stroked arc over the top of (cx, cy): the shackle's bend.
    case arc(cx: CGFloat, cy: CGFloat, r: CGFloat, w: CGFloat)
    case rect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat)
  }
  /// Ink, in drawing order.
  static let ink: [Piece] = [
    .arc(cx: 0.5, cy: 0.43, r: 0.21, w: 0.11),
    .rect(x: 0.235, y: 0.43, w: 0.11, h: 0.08, r: 0),
    .rect(x: 0.655, y: 0.43, w: 0.11, h: 0.08, r: 0),
    .rect(x: 0.12, y: 0.45, w: 0.76, h: 0.52, r: 0.185),
  ]
  /// The keyhole, in the signal colour.
  static let keyhole: [Piece] = [
    .rect(x: 0.26, y: 0.675, w: 0.48, h: 0.07, r: 0.035),
    .rect(x: 0.28, y: 0.585, w: 0.085, h: 0.25, r: 0.034),
    .rect(x: 0.635, y: 0.585, w: 0.085, h: 0.25, r: 0.034),
  ]

  var body: some View {
    ZStack {
      BrandMarkShape(pieces: Self.ink).fill(JourneyColor.text)
      BrandMarkShape(pieces: Self.keyhole).fill(JourneyColor.signal)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

/// A list of pieces as one shape, scaled to the square inside its rect.
private struct BrandMarkShape: Shape {
  let pieces: [BrandMark.Piece]
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let s = min(rect.width, rect.height)
    let o = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
    for piece in pieces {
      switch piece {
      case .rect(let x, let y, let w, let h, let r):
        path.addRoundedRect(in: CGRect(x: o.x + x * s, y: o.y + y * s, width: w * s, height: h * s),
                            cornerSize: CGSize(width: r * s, height: r * s), style: .continuous)
      case .arc(let cx, let cy, let r, let w):
        // The bend as a filled half-annulus, so it joins the legs with no seam.
        let c = CGPoint(x: o.x + cx * s, y: o.y + cy * s)
        var bend = Path()
        bend.addArc(center: c, radius: (r + w / 2) * s, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        bend.addArc(center: c, radius: (r - w / 2) * s, startAngle: .degrees(360), endAngle: .degrees(180), clockwise: true)
        bend.closeSubpath()
        path.addPath(bend)
      }
    }
    return path
  }
}
