import SwiftUI

/// The brand mark: a cast-iron kettlebell with a keyhole. A thick handle, wider than the bell, whose
/// legs lean in and curve into the bell's shoulders; a round bell with a flat base; and the keyhole
/// in the emerald signal, the only colour and the only lock cue. The handle was traced from a photo
/// of a real kettlebell the user picked on 12 Oct 2026 (it replaced the trapezoid handle of 9 Oct).
/// The outline is `KettlebellOutline` below, shared word for word with `scripts/generate-app-icon.swift`.
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
}

/// The mark as a padlock, for the launch screen (11 Oct 2026): the kettlebell's handle is the shackle.
/// It appears unlocked (handle raised and swivelled open on one leg, the keyhole an empty cut-out),
/// the handle swings shut and drops into the bell, it clicks (a crisp haptic, the bell gives a
/// little), and the keyhole lights emerald: locked. Then `done`.
struct KettlebellLock: View {
  var size: CGFloat = 96
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false
  @State private var swung = false
  @State private var dropped = false
  @State private var locked = false
  /// Shrunk away into its bell: the exit, in solid ink rather than a fade (12 Oct 2026).
  @State private var gone = false
  var body: some View {
    ZStack {
      // Raised only a little: the legs lean in, so a long lift would show them meeting inside the bell.
      BrandMarkShape(part: .handle).fill(JourneyColor.text, style: FillStyle(eoFill: true))
        .rotationEffect(.degrees(swung ? 0 : -16), anchor: UnitPoint(x: 0.60, y: 0.70))
        .offset(y: dropped ? 0 : -size * 0.15)
      ZStack {
        BrandMarkShape(part: .bell).fill(JourneyColor.text)
        // The curves where the legs meet the bell, once they have.
        BrandMarkShape(part: .joins).fill(JourneyColor.text).opacity(locked ? 1 : 0)
      }
      .scaleEffect(x: 1, y: locked ? 1 : 0.985, anchor: .bottom)
      BrandMarkShape(part: .keyhole).fill(locked ? JourneyColor.signal : JourneyColor.stage)
        .scaleEffect(locked ? 1 : 0.82, anchor: UnitPoint(x: 0.5, y: 0.71))
    }
    .frame(width: size, height: size)
    // One piece: faded part by part, the handle and bell overlap into darker seams.
    .compositingGroup()
    .scaleEffect(gone ? 0.001 : 1, anchor: UnitPoint(x: KettlebellOutline.bell.x, y: KettlebellOutline.bell.y))
    .padding(.top, size * 0.3)  // Room for the raised handle.
    .opacity(shown ? 1 : 0)
    .accessibilityHidden(true)
    .task {
      if reduceMotion {
        swung = true; dropped = true; locked = true; shown = true
        try? await Task.sleep(for: .milliseconds(350))
        done(); return
      }
      // About 2 s in all (12 Oct 2026: the user found 1.45 s too fast); time to see it open, and locked.
      JourneyHaptic.prepare(.rigid)  // So the click lands with the handle, not after it.
      withAnimation(.easeOut(duration: 0.3)) { shown = true }
      try? await Task.sleep(for: .milliseconds(450))
      withAnimation(.easeInOut(duration: 0.34)) { swung = true }
      try? await Task.sleep(for: .milliseconds(380))
      withAnimation(.spring(duration: 0.36, bounce: 0.26)) { dropped = true }
      try? await Task.sleep(for: .milliseconds(220))  // It lands: the spring first reaches the bell.
      JourneyHaptic.play(.rigid, store.profile, intensity: 1)
      withAnimation(.spring(duration: 0.36, bounce: 0.4)) { locked = true }
      try? await Task.sleep(for: .milliseconds(650))
      // Out, solid all the way: it tucks into its bell, then the page arrives over the same paper.
      withAnimation(.easeIn(duration: 0.32)) { gone = true }
      try? await Task.sleep(for: .milliseconds(320))
      done()
    }
  }
}

private struct BrandMarkShape: Shape {
  enum Part { case iron, keyhole, handle, bell, joins }
  let part: Part
  func path(in rect: CGRect) -> Path {
    let s = min(rect.width, rect.height), paths = KettlebellOutline.paths()
    let unit: CGPath
    switch part {
    case .iron: unit = paths.iron
    case .keyhole: unit = paths.keyhole
    case .handle: unit = paths.handle
    case .bell: unit = paths.bell
    case .joins: unit = paths.joins
    }
    return Path(unit).applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: rect.midX - s / 2, ty: rect.midY - s / 2))
  }
}

// BEGIN KETTLEBELL OUTLINE
/// The kettlebell's outlines in the unit square, y down. Traced from a photo of a cast-iron
/// kettlebell the user chose on 12 Oct 2026. The numbers are in bell radii from the bell's centre.
/// Keep this block identical in GymBlock/BrandMark.swift and scripts/generate-app-icon.swift.
enum KettlebellOutline {
  /// Where the bell sits in the unit square, and its radius.
  static let bell = (x: 0.5, y: 0.685, r: 0.292)
  /// The flat base, below the bell's centre.
  static let base = 0.907
  /// The handle's two top corners: centres (±x, y), and the outer and inner radii (the bar is the difference).
  static let corner = (x: 0.50, y: -1.50, outer: 0.674, inner: 0.259)
  /// The legs lean in towards the bell, in degrees from vertical; the inner edge leans more, so they thicken.
  static let lean = (outer: 21.8, inner: 25.2)
  /// The curves where the legs run into the bell: outside (the waist) and inside the window.
  static let fillets = (waist: 0.10, window: 0.08)
  /// The keyhole: the head's centre (above the bell's centre), its radius, and the slot's length.
  static let key = (y: -0.08, r: 0.185, length: 0.50)
  /// For the launch animation: how far the handle's legs run on inside the bell, and where its window closes.
  static let legEnd = (outer: 0.05, window: -0.05)

  /// The mark (fill even-odd) and its keyhole; and for the launch animation the handle (fill even-odd),
  /// the bell, and the curves where they join (shown once they have).
  static func paths() -> (iron: CGPath, keyhole: CGPath, handle: CGPath, bell: CGPath, joins: CGPath) {
    typealias Pt = (x: Double, y: Double)
    typealias Leg = (at: Pt, down: Pt, out: Pt)
    func p(_ q: Pt) -> CGPoint { CGPoint(x: bell.x + bell.r * q.x, y: bell.y + bell.r * q.y) }
    func angle(_ c: Pt, _ q: Pt) -> Double { atan2(q.y - c.y, q.x - c.x) }
    /// An arc about `c` from angle `a` to `b`, sweeping clockwise on screen (+1) or anticlockwise (−1).
    func arc(_ path: CGMutablePath, _ c: Pt, _ r: Double, _ a: Double, _ b: Double, _ sweep: Double) {
      var b = b
      while sweep > 0 && b < a { b += 2 * .pi }
      while sweep < 0 && b > a { b -= 2 * .pi }
      path.addArc(center: p(c), radius: bell.r * r, startAngle: a, endAngle: b, clockwise: sweep < 0)
    }
    /// A leg's edge: where it leaves its corner circle, its direction down, and its outward normal.
    func leg(_ r: Double, _ degrees: Double, _ side: Double) -> Leg {
      let t = degrees * .pi / 180, out = (x: side * cos(t), y: sin(t))
      return ((side * corner.x + r * out.x, corner.y + r * out.y), (-side * sin(t), cos(t)), out)
    }
    /// Where a line first meets a circle about the bell's centre on its way down.
    func meet(_ from: Pt, _ down: Pt, _ r: Double) -> Pt {
      let b = from.x * down.x + from.y * down.y, c = from.x * from.x + from.y * from.y - r * r
      let t = -b - (b * b - c).squareRoot()
      return (from.x + t * down.x, from.y + t * down.y)
    }
    /// The fillet of radius `f` between a leg's edge and the bell, on the `side` of the edge.
    func fillet(_ l: Leg, _ f: Double, _ side: Pt) -> (c: Pt, leg: Pt, bell: Pt) {
      let c = meet((l.at.x + f * side.x, l.at.y + f * side.y), l.down, 1 + f)
      return (c, (c.x - f * side.x, c.y - f * side.y), (c.x / (1 + f), c.y / (1 + f)))
    }
    let o = (l: leg(corner.outer, lean.outer, -1), r: leg(corner.outer, lean.outer, 1))
    let i = (l: leg(corner.inner, lean.inner, -1), r: leg(corner.inner, lean.inner, 1))
    let waist = (l: fillet(o.l, fillets.waist, o.l.out), r: fillet(o.r, fillets.waist, o.r.out))
    let foot = (l: fillet(i.l, fillets.window, (-i.l.out.x, -i.l.out.y)), r: fillet(i.r, fillets.window, (-i.r.out.x, -i.r.out.y)))
    let centre: Pt = (0, 0), cl: Pt = (-corner.x, corner.y), cr: Pt = (corner.x, corner.y)
    let top = -Double.pi / 2, b0 = asin(base)

    // The silhouette: along the base, up the bell's right side, the waist, the leg, over the top, and back down.
    let outline = CGMutablePath()
    outline.move(to: p((-cos(b0), base)))
    outline.addLine(to: p((cos(b0), base)))
    arc(outline, centre, 1, b0, angle(centre, waist.r.bell), -1)
    arc(outline, waist.r.c, fillets.waist, angle(waist.r.c, waist.r.bell), angle(waist.r.c, waist.r.leg), 1)
    outline.addLine(to: p(o.r.at))
    arc(outline, cr, corner.outer, angle(cr, o.r.at), top, -1)
    outline.addLine(to: p((-corner.x, corner.y - corner.outer)))
    arc(outline, cl, corner.outer, top, angle(cl, o.l.at), -1)
    outline.addLine(to: p(waist.l.leg))
    arc(outline, waist.l.c, fillets.waist, angle(waist.l.c, waist.l.leg), angle(waist.l.c, waist.l.bell), 1)
    arc(outline, centre, 1, angle(centre, waist.l.bell), .pi - b0, -1)
    outline.closeSubpath()

    // The window: over the top of the bell, up the right leg's inner edge, across, and down the left.
    let window = CGMutablePath()
    window.move(to: p(foot.l.bell))
    arc(window, centre, 1, angle(centre, foot.l.bell), angle(centre, foot.r.bell), 1)
    arc(window, foot.r.c, fillets.window, angle(foot.r.c, foot.r.bell), angle(foot.r.c, foot.r.leg), -1)
    window.addLine(to: p(i.r.at))
    arc(window, cr, corner.inner, angle(cr, i.r.at), top, -1)
    window.addLine(to: p((-corner.x, corner.y - corner.inner)))
    arc(window, cl, corner.inner, top, angle(cl, i.l.at), -1)
    window.addLine(to: p(foot.l.leg))
    arc(window, foot.l.c, fillets.window, angle(foot.l.c, foot.l.leg), angle(foot.l.c, foot.l.bell), -1)
    window.closeSubpath()

    let iron = CGMutablePath()
    iron.addPath(outline); iron.addPath(window)

    let keyhole = CGMutablePath()
    let head = p((0, key.y)), hr = bell.r * key.r
    keyhole.addEllipse(in: CGRect(x: head.x - hr, y: head.y - hr, width: 2 * hr, height: 2 * hr))
    keyhole.addLines(between: [p((-0.4 * key.r, key.y + 0.06)), p((0.4 * key.r, key.y + 0.06)),
                               p((0.72 * key.r, key.y + key.length)), p((-0.72 * key.r, key.y + key.length))])
    keyhole.closeSubpath()

    // The handle alone: the bar, its legs running on into the bell and closed across down there.
    func along(_ l: Leg, toY y: Double) -> Pt { let t = (y - l.at.y) / l.down.y; return (l.at.x + t * l.down.x, y) }
    let handle = CGMutablePath()
    for (l, r, radius, end) in [(o.l, o.r, corner.outer, legEnd.outer), (i.l, i.r, corner.inner, legEnd.window)] {
      handle.move(to: p(along(l, toY: end)))
      handle.addLine(to: p(l.at))
      arc(handle, cl, radius, angle(cl, l.at), top, 1)
      arc(handle, cr, radius, top, angle(cr, r.at), 1)
      handle.addLine(to: p(along(r, toY: end)))
      handle.closeSubpath()
    }

    // The bell alone, and the four curves where the legs run into it, each reaching a little into the
    // leg and the bell so no seam shows.
    let body = CGMutablePath()
    body.move(to: p((-cos(b0), base)))
    body.addLine(to: p((cos(b0), base)))
    arc(body, centre, 1, b0, .pi - b0, -1)
    body.closeSubpath()
    let joins = CGMutablePath()
    for (edge, f, r, into, sweep) in [(o.l, waist.l, fillets.waist, -1.0, -1.0), (o.r, waist.r, fillets.waist, -1.0, 1.0),
                                      (i.l, foot.l, fillets.window, 1.0, 1.0), (i.r, foot.r, fillets.window, 1.0, -1.0)] {
      let x = meet(f.leg, edge.down, 1), e = 0.03 * into
      joins.move(to: p((f.leg.x + e * edge.out.x, f.leg.y + e * edge.out.y)))
      joins.addLine(to: p((x.x + 0.06 * edge.down.x + e * edge.out.x, x.y + 0.06 * edge.down.y + e * edge.out.y)))
      joins.addLine(to: p((f.bell.x * 0.94, f.bell.y * 0.94)))
      joins.addLine(to: p(f.bell))
      arc(joins, f.c, r, angle(f.c, f.bell), angle(f.c, f.leg), sweep)
      joins.closeSubpath()
    }
    return (iron, keyhole, handle, body, joins)
  }
}
// END KETTLEBELL OUTLINE
