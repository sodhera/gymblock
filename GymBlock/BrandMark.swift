import SwiftUI

/// The brand mark: a dumbbell with a small padlock on the middle of its bar. Two thick plates, a heavy
/// bar, the lock straddling the bar with its shackle above; the keyhole is the only colour. Chosen by
/// the user on 9 Oct 2026 from rendered glass options. The same unit-square geometry (y down) as the
/// Liquid Glass app icon in `GymBlock/AppIcon.icon` and the fallback PNG in
/// `scripts/generate-app-icon.swift`; keep them in step.
struct BrandMark: View {
  var size: CGFloat = 28
  var body: some View {
    ZStack {
      iron
      BrandMarkShape(part: .keyhole).fill(JourneyColor.signal)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
  /// Liquid Glass on iOS 26, like the app icon; flat ink before that.
  @ViewBuilder private var iron: some View {
    if #available(iOS 26.0, *) {
      Color.clear.glassEffect(Glass.regular.tint(JourneyColor.text.opacity(0.92)), in: BrandMarkShape(part: .iron))
    } else {
      BrandMarkShape(part: .iron).fill(JourneyColor.text, style: FillStyle(eoFill: true))
    }
  }
  enum Geometry {
    static let plateW = 0.26, plateH = 0.56
    static let barY = 0.50, barH = 0.10
    static let lockW = 0.24
    static var lockH: Double { lockW * 0.92 }
    static var lockTop: Double { barY - lockH * 0.45 }
    static var shackleR: Double { lockW * 0.33 }
    static var shackleW: Double { lockW * 0.22 }
    static var keyR: Double { lockW * 0.09 }
    static var keyCY: Double { lockTop + lockH * 0.42 }
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
    var keyhole = Path()
    keyhole.addEllipse(in: r(0.5 - G.keyR, G.keyCY - G.keyR, 2 * G.keyR, 2 * G.keyR))
    keyhole.addLines([CGPoint(x: o.x + (0.5 - G.keyR * 0.4) * s, y: o.y + (G.keyCY + G.keyR * 0.4) * s),
                      CGPoint(x: o.x + (0.5 + G.keyR * 0.4) * s, y: o.y + (G.keyCY + G.keyR * 0.4) * s),
                      CGPoint(x: o.x + (0.5 + G.keyR * 0.85) * s, y: o.y + (G.keyCY + G.keyR * 3.0) * s),
                      CGPoint(x: o.x + (0.5 - G.keyR * 0.85) * s, y: o.y + (G.keyCY + G.keyR * 3.0) * s)])
    keyhole.closeSubpath()
    if part == .keyhole { return keyhole }
    var path = Path()
    let pr = G.plateW * 0.42 * s
    path.addRoundedRect(in: r(0, 0.5 - G.plateH / 2, G.plateW, G.plateH), cornerSize: CGSize(width: pr, height: pr), style: .continuous)
    path.addRoundedRect(in: r(1 - G.plateW, 0.5 - G.plateH / 2, G.plateW, G.plateH), cornerSize: CGSize(width: pr, height: pr), style: .continuous)
    path.addRoundedRect(in: r(0.04, G.barY - G.barH / 2, 0.92, G.barH), cornerSize: CGSize(width: G.barH / 2 * s, height: G.barH / 2 * s))
    let centre = CGPoint(x: o.x + 0.5 * s, y: o.y + G.lockTop * s)
    var ring = Path()
    ring.addEllipse(in: CGRect(x: centre.x - (G.shackleR + G.shackleW / 2) * s, y: centre.y - (G.shackleR + G.shackleW / 2) * s, width: 2 * (G.shackleR + G.shackleW / 2) * s, height: 2 * (G.shackleR + G.shackleW / 2) * s))
    ring.addEllipse(in: CGRect(x: centre.x - (G.shackleR - G.shackleW / 2) * s, y: centre.y - (G.shackleR - G.shackleW / 2) * s, width: 2 * (G.shackleR - G.shackleW / 2) * s, height: 2 * (G.shackleR - G.shackleW / 2) * s))
    let lr = G.lockW * 0.3 * s
    var body = Path(roundedRect: r(0.5 - G.lockW / 2, G.lockTop, G.lockW, G.lockH), cornerSize: CGSize(width: lr, height: lr), style: .continuous)
    body = body.subtracting(keyhole)
    return path.union(ring.normalized(eoFill: true)).union(body)
  }
}
