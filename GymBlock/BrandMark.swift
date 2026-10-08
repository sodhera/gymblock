import SwiftUI

/// The brand mark: a kettlebell that is a padlock. The handle is the shackle, the bell is the body,
/// and the keyhole is cut in the emerald signal, the only colour. Chosen on 8 Oct 2026 from rendered
/// options (plate dial, stacked plates). The same geometry as the app icon in
/// `scripts/generate-app-icon.swift`: unit square, y down, angles in degrees counter-clockwise with
/// 90 pointing up. Keep the two in step.
struct BrandMark: View {
  var size: CGFloat = 28
  var body: some View {
    ZStack {
      BrandMarkShape(part: .body).fill(JourneyColor.text)
      BrandMarkShape(part: .keyhole).fill(JourneyColor.signal)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  enum Geometry {
    /// The bell: a circle with a flattened base.
    static let bell = (cx: 0.5, cy: 0.665, r: 0.285, from: 236.0, to: -56.0)
    /// The handle: a thick loop over the top whose horns land on the bell's shoulders.
    static let handle = (cx: 0.5, cy: 0.39, outer: 0.235, inner: 0.125, hornY: 0.53, innerY: 0.47)
    /// The keyhole: a round head and a tapered slot.
    static let head = (cx: 0.5, cy: 0.635, r: 0.06)
    static let slot = (top: 0.655, bottom: 0.80, topHalf: 0.023, bottomHalf: 0.042)
  }
}

private struct BrandMarkShape: Shape {
  enum Part { case body, keyhole }
  let part: Part
  func path(in rect: CGRect) -> Path {
    let s = min(rect.width, rect.height)
    let o = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
    func arc(_ cx: Double, _ cy: Double, _ r: Double, _ a0: Double, _ a1: Double) -> [CGPoint] {
      (0...96).map { i in
        let a = (a0 + (a1 - a0) * Double(i) / 96) * .pi / 180
        return p(cx + r * cos(a), cy - r * sin(a))
      }
    }
    var path = Path()
    typealias G = BrandMark.Geometry
    switch part {
    case .body:
      path.addLines(arc(G.bell.cx, G.bell.cy, G.bell.r, G.bell.from, G.bell.to)); path.closeSubpath()
      let h = G.handle
      path.addLines(arc(h.cx, h.cy, h.outer, 180, 0)
        + [p(h.cx + h.outer, h.hornY), p(h.cx + h.inner, h.innerY)]
        + arc(h.cx, h.cy, h.inner, 0, 180)
        + [p(h.cx - h.inner, h.innerY), p(h.cx - h.outer, h.hornY)])
      path.closeSubpath()
    case .keyhole:
      let r = G.head.r
      path.addEllipse(in: CGRect(origin: p(G.head.cx - r, G.head.cy - r), size: CGSize(width: 2 * r * s, height: 2 * r * s)))
      let t = G.slot
      path.addLines([p(0.5 - t.topHalf, t.top), p(0.5 + t.topHalf, t.top), p(0.5 + t.bottomHalf, t.bottom), p(0.5 - t.bottomHalf, t.bottom)])
      path.closeSubpath()
    }
    return path
  }
}
