import SwiftUI

/// The brand mark: a dumbbell with a small padlock on the middle of its bar. One pill plate each
/// side, a heavy bar, the lock straddling the bar with its shackle above; mirror-symmetric. In the app it is ink on paper with the keyhole in the signal
/// colour; the app icon is the same geometry in emerald on black (`scripts/generate-app-icon.swift`).
/// Chosen by the user on 9 Oct 2026 from rendered options. Keep `Geometry` and the script in step.
struct BrandMark: View {
  var size: CGFloat = 28
  var body: some View {
    ZStack {
      BrandMarkShape(part: .iron).fill(JourneyColor.text, style: FillStyle(eoFill: true))
      BrandMarkShape(part: .keyhole).fill(JourneyColor.signal)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
  enum Geometry {
    static let barY = 0.50, barH = 0.10, barX = 0.05, barW = 0.90
    static let plate = (x: 0.0, y: 0.22, w: 0.24, h: 0.56, r: 0.10)
    static let lockW = 0.22, lockH = 0.20, lockR = 0.065
    static var lockTop: Double { barY - lockH * 0.5 }
    static var shackleR: Double { lockW * 0.30 }
    static var shackleW: Double { lockW * 0.20 }
    static let keyR = 0.021
    static var keyCY: Double { lockTop + lockH * 0.40 }
  }
}

private struct BrandMarkShape: Shape {
  enum Part { case iron, keyhole }
  let part: Part
  func path(in rect: CGRect) -> Path {
    typealias G = BrandMark.Geometry
    let s = min(rect.width, rect.height)
    let o = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
    func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect { CGRect(x: o.x + x * s, y: o.y + y * s, width: w * s, height: h * s) }
    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
    var keyhole = Path()
    keyhole.addEllipse(in: r(0.5 - G.keyR, G.keyCY - G.keyR, 2 * G.keyR, 2 * G.keyR))
    keyhole.addLines([p(0.5 - G.keyR * 0.42, G.keyCY + G.keyR * 0.35), p(0.5 + G.keyR * 0.42, G.keyCY + G.keyR * 0.35),
                      p(0.5 + G.keyR * 0.78, G.keyCY + G.keyR * 2.7), p(0.5 - G.keyR * 0.78, G.keyCY + G.keyR * 2.7)])
    keyhole.closeSubpath()
    if part == .keyhole { return keyhole }
    var path = Path()
    let plate = G.plate, cs = CGSize(width: plate.r * s, height: plate.r * s)
    path.addRoundedRect(in: r(plate.x, plate.y, plate.w, plate.h), cornerSize: cs, style: .continuous)
    path.addRoundedRect(in: r(1 - plate.x - plate.w, plate.y, plate.w, plate.h), cornerSize: cs, style: .continuous)
    path.addRoundedRect(in: r(G.barX, G.barY - G.barH / 2, G.barW, G.barH), cornerSize: CGSize(width: G.barH / 2 * s, height: G.barH / 2 * s))
    let centre = p(0.5, G.lockTop)
    let ro = (G.shackleR + G.shackleW / 2) * s, ri = (G.shackleR - G.shackleW / 2) * s
    var ring = Path()
    ring.addEllipse(in: CGRect(x: centre.x - ro, y: centre.y - ro, width: 2 * ro, height: 2 * ro))
    ring.addEllipse(in: CGRect(x: centre.x - ri, y: centre.y - ri, width: 2 * ri, height: 2 * ri))
    let body = Path(roundedRect: r(0.5 - G.lockW / 2, G.lockTop, G.lockW, G.lockH), cornerSize: CGSize(width: G.lockR * s, height: G.lockR * s), style: .continuous)
    return path.union(ring.normalized(eoFill: true)).union(body.subtracting(keyhole))
  }
}
