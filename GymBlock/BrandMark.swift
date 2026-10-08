import SwiftUI

/// The brand mark: a padlock whose shackle is a barbell. A rounded-square body; above it a bar with
/// a rounded plate at each end, and a short post under each plate dropping into the body as the
/// shackle legs; the emerald signal dot is the keyhole. The same geometry, in the same unit square,
/// as the app icon (`scripts/generate-app-icon.swift`); keep the two tables identical.
struct BrandMark: View {
  var size: CGFloat = 28

  /// Ink shapes in a unit square, y down: (x, y, width, height, corner radius).
  static let ink: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, radius: CGFloat)] = [
    (0.08, 0.50, 0.84, 0.50, 0.17),   // lock body
    (0.00, 0.14, 1.00, 0.10, 0.05),   // bar
    (0.16, 0.00, 0.22, 0.38, 0.08),   // left plate
    (0.62, 0.00, 0.22, 0.38, 0.08),   // right plate
    (0.20, 0.36, 0.14, 0.22, 0.00),   // left shackle post
    (0.66, 0.36, 0.14, 0.22, 0.00),   // right shackle post
  ]
  /// The keyhole: centre and diameter in the unit square.
  static let keyhole = (cx: CGFloat(0.5), cy: CGFloat(0.75), d: CGFloat(0.17))

  var body: some View {
    ZStack {
      BrandMarkInk().fill(JourneyColor.text)
      Circle().fill(JourneyColor.signal)
        .frame(width: size * Self.keyhole.d, height: size * Self.keyhole.d)
        .offset(x: size * (Self.keyhole.cx - 0.5), y: size * (Self.keyhole.cy - 0.5))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

/// The ink of the mark as one shape, scaled to its rect.
private struct BrandMarkInk: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let s = min(rect.width, rect.height)
    let origin = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
    for shape in BrandMark.ink {
      let r = CGRect(x: origin.x + shape.x * s, y: origin.y + shape.y * s, width: shape.w * s, height: shape.h * s)
      path.addRoundedRect(in: r, cornerSize: CGSize(width: shape.radius * s, height: shape.radius * s), style: .continuous)
    }
    return path
  }
}
