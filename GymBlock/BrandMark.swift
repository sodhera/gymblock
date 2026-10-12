import SwiftUI

/// The brand mark: a cast-iron kettlebell with a keyhole. A wide trapezoid handle whose horns flare
/// past the bell and curve into its shoulders, a round bell with a flat base, and the keyhole in the
/// emerald signal, the only colour and the only lock cue. Chosen by the user on 9 Oct 2026 from
/// rendered options. The same geometry as `scripts/generate-app-icon.swift`: unit square, y down.
/// Keep the two in step.
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
    /// Handle outline and its window: (x, y, corner radius). First and last points sit inside the bell.
    static let handle: [(Double, Double, Double)] = [
      (0.30, 0.66, 0), (0.19, 0.49, 0.05), (0.265, 0.07, 0.11), (0.735, 0.07, 0.11), (0.81, 0.49, 0.05), (0.70, 0.66, 0)]
    static let window: [(Double, Double, Double)] = [
      (0.30, 0.52, 0), (0.275, 0.49, 0.02), (0.325, 0.15, 0.055), (0.675, 0.15, 0.055), (0.725, 0.49, 0.02), (0.70, 0.52, 0)]
    /// The bell: a circle cut flat at `base`.
    static let bell = (cx: 0.5, cy: 0.67, r: 0.32, base: 0.965)
    /// The keyhole: a round head and a tapered slot.
    static let key = (cy: 0.645, r: 0.055, length: 0.15)
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
      BrandMarkShape(part: .handle).fill(JourneyColor.text, style: FillStyle(eoFill: true))
        .rotationEffect(.degrees(swung ? 0 : -16), anchor: UnitPoint(x: 0.70, y: 0.66))
        .offset(y: dropped ? 0 : -size * 0.24)
      BrandMarkShape(part: .bell).fill(JourneyColor.text)
        .scaleEffect(x: locked ? 1 : 1.0, y: locked ? 1 : 0.985, anchor: .bottom)
      BrandMarkShape(part: .keyhole).fill(locked ? JourneyColor.signal : JourneyColor.stage)
        .scaleEffect(locked ? 1 : 0.82, anchor: UnitPoint(x: 0.5, y: 0.68))
    }
    .frame(width: size, height: size)
    // One piece: faded part by part, the handle and bell overlap into darker seams.
    .compositingGroup()
    .scaleEffect(gone ? 0.001 : 1, anchor: UnitPoint(x: 0.5, y: 0.68))
    .padding(.top, size * 0.3)  // Room for the raised handle.
    .opacity(shown ? 1 : 0)
    .accessibilityHidden(true)
    .task {
      if reduceMotion {
        swung = true; dropped = true; locked = true; shown = true
        try? await Task.sleep(for: .milliseconds(350))
        done(); return
      }
      withAnimation(.easeOut(duration: 0.25)) { shown = true }
      try? await Task.sleep(for: .milliseconds(300))
      withAnimation(.easeInOut(duration: 0.22)) { swung = true }
      try? await Task.sleep(for: .milliseconds(240))
      withAnimation(.spring(duration: 0.26, bounce: 0.28)) { dropped = true }
      try? await Task.sleep(for: .milliseconds(170))
      JourneyHaptic.play(.rigid, store.profile, intensity: 1)
      withAnimation(.spring(duration: 0.3, bounce: 0.45)) { locked = true }
      try? await Task.sleep(for: .milliseconds(480))
      // Out, solid all the way: it tucks into its bell, then the page arrives over the same paper.
      withAnimation(.easeIn(duration: 0.26)) { gone = true }
      try? await Task.sleep(for: .milliseconds(260))
      done()
    }
  }
}

private struct BrandMarkShape: Shape {
  enum Part { case iron, keyhole, handle, bell }
  let part: Part
  func path(in rect: CGRect) -> Path {
    typealias G = BrandMark.Geometry
    let s = min(rect.width, rect.height)
    let o = CGPoint(x: rect.midX - s / 2, y: rect.midY - s / 2)
    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: o.x + x * s, y: o.y + y * s) }
    func outline(_ path: inout Path, _ pts: [(Double, Double, Double)]) {
      path.move(to: p(pts[0].0, pts[0].1))
      for i in 1..<(pts.count - 1) {
        let corner = p(pts[i].0, pts[i].1), next = p(pts[i + 1].0, pts[i + 1].1)
        if pts[i].2 > 0 { path.addArc(tangent1End: corner, tangent2End: next, radius: pts[i].2 * s) } else { path.addLine(to: corner) }
      }
      path.addLine(to: p(pts[pts.count - 1].0, pts[pts.count - 1].1))
      path.closeSubpath()
    }
    var path = Path()
    switch part {
    case .iron:
      // Handle minus window (even-odd), then the bell as its own subpath over the window's foot.
      outline(&path, G.handle)
      outline(&path, G.window)
      var bell = Path()
      let b = G.bell, half = asin((b.base - b.cy) / b.r) * 180 / .pi   // angle of the flat base below centre
      bell.addLines(stride(from: 180 + half, through: -half, by: -2).map { a in
        let r = a * .pi / 180
        return p(b.cx + b.r * cos(r), b.cy - b.r * sin(r))
      })
      bell.closeSubpath()
      // The bell must not punch a hole where it overlaps the handle: fill it separately with no even-odd.
      return path.normalized(eoFill: true).union(bell)
    case .handle:
      // The handle alone, its window cut out (even-odd), and open at the bottom: a U-shaped shackle
      // with two legs. The cut is the bar between the feet, which sits inside the bell once locked,
      // so the locked mark is unchanged.
      outline(&path, G.handle)
      outline(&path, G.window)
      let foot = CGRect(x: o.x + 0.30 * s, y: o.y + 0.50 * s, width: 0.40 * s, height: 0.20 * s)
      return path.normalized(eoFill: true).subtracting(Path(foot))
    case .bell:
      let b = G.bell, half = asin((b.base - b.cy) / b.r) * 180 / .pi
      path.addLines(stride(from: 180 + half, through: -half, by: -2).map { a in
        let r = a * .pi / 180
        return p(b.cx + b.r * cos(r), b.cy - b.r * sin(r))
      })
      path.closeSubpath()
    case .keyhole:
      let k = G.key
      path.addEllipse(in: CGRect(origin: p(0.5 - k.r, k.cy - k.r), size: CGSize(width: 2 * k.r * s, height: 2 * k.r * s)))
      path.addLines([p(0.5 - k.r * 0.4, k.cy + 0.02), p(0.5 + k.r * 0.4, k.cy + 0.02),
                     p(0.5 + k.r * 0.72, k.cy + k.length), p(0.5 - k.r * 0.72, k.cy + k.length)])
      path.closeSubpath()
    }
    return path
  }
}
