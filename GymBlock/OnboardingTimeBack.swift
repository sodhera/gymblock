import SwiftUI

// Onboarding V8 (docs/ONBOARDING-V8-PLAN.md, 20 Oct 2026): time back, not the pump. While they
// answer, each question page shows a thing they know that answers back (a stopwatch, a feed, the
// rack, today's log, the gym clock). The first graph comes once they've answered: the minutes
// scrolling runs past the rest they need. The workout page draws the same two bars at workout size
// and the promise takes the red away. Every number comes from `TimeBack`.

// MARK: - Words

extension GymStore {
  /// "1 minute", "half a minute", "2½ minutes".
  func minutesWords(_ m: Double) -> String {
    if m == 1 { return t("1 minute") }
    if m == 0.5 { return t("half a minute") }
    return String(format: t("%@ minutes"), TimeWords.half(m))
  }
  /// What a workout loses, as said: "35 minutes", or "about an hour" from 55 to 65.
  func lostWords(_ time: TimeBack) -> String {
    time.lostIsAnHour ? t("about an hour") : String(format: t("%@ minutes"), "\(time.shownLost)")
  }
  /// "1½ hours", "45 minutes".
  func gymWords(_ minutes: Double) -> String { t(TimeWords.gymLong(minutes)) }
  /// "about 55 min", "about 1 h 5 min".
  func aboutWords(_ minutes: Int) -> String { String(format: t("about %@"), TimeWords.duration(minutes)) }
}

// MARK: - Page 6: the rest they need

/// A stopwatch on a five-minute dial, its hand and green wedge at `minutes`.
struct StopwatchFace: View, Animatable {
  var minutes: Double
  var animatableData: Double { get { minutes } set { minutes = newValue } }
  static let size = CGSize(width: 240, height: 262)
  var body: some View {
    Canvas { c, size in
      let s = size.width / Self.size.width
      let center = CGPoint(x: 120 * s, y: 150 * s)
      func polar(_ r: Double, _ degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: center.x + r * s * sin(a), y: center.y - r * s * cos(a))
      }
      func disc(_ r: Double) -> Path { Path(ellipseIn: CGRect(x: center.x - r * s, y: center.y - r * s, width: 2 * r * s, height: 2 * r * s)) }
      let ink = GraphicsContext.Shading.color(JourneyColor.text)
      // The crown on its stem, and the side button.
      c.fill(Path(roundedRect: CGRect(x: 102 * s, y: 4 * s, width: 36 * s, height: 15 * s), cornerRadius: 5 * s), with: ink)
      c.fill(Path(CGRect(x: 113 * s, y: 17 * s, width: 14 * s, height: 18 * s)), with: ink)
      var side = c
      side.translateBy(x: center.x, y: center.y); side.rotate(by: .degrees(40)); side.translateBy(x: -center.x, y: -center.y)
      side.fill(Path(roundedRect: CGRect(x: 111 * s, y: 28 * s, width: 18 * s, height: 18 * s), cornerRadius: 4 * s), with: ink)
      c.fill(disc(106), with: ink)
      c.fill(disc(93), with: .color(JourneyColor.raised))
      let a = min(359.9, max(0, minutes / 5 * 360))
      if a > 0.1 {
        var wedge = Path()
        wedge.move(to: center)
        wedge.addArc(center: center, radius: 93 * s, startAngle: .degrees(-90), endAngle: .degrees(-90 + a), clockwise: false)
        wedge.closeSubpath()
        c.fill(wedge, with: .color(JourneyColor.accent.opacity(0.18)))
      }
      for i in 0..<60 {
        let minute = i % 12 == 0
        var tick = Path()
        tick.move(to: polar(86, Double(i) * 6)); tick.addLine(to: polar(minute ? 72 : 80, Double(i) * 6))
        c.stroke(tick, with: .color(JourneyColor.ink(minute ? 0.8 : 0.22)), style: StrokeStyle(lineWidth: (minute ? 3 : 1.5) * s, lineCap: .round))
      }
      for m in 0..<5 {
        c.draw(Text("\(m)").font(.system(size: 17 * s, weight: .semibold)).foregroundStyle(JourneyColor.ink(0.5)), at: polar(57, Double(m) * 72))
      }
      var hand = Path()
      hand.move(to: polar(-14, a)); hand.addLine(to: polar(80, a))
      c.stroke(hand, with: .color(JourneyColor.accent), style: StrokeStyle(lineWidth: 4 * s, lineCap: .round))
      c.fill(disc(8), with: ink)
      c.fill(disc(3), with: .color(JourneyColor.accent))
    }
    .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
  }
}

/// The stopwatch winds to the rest they choose, a tick for every 15 seconds it passes. Rarely's
/// page ("Then you're already ahead.") shows the same watch with "Rests on time".
struct RestWatchStage: View {
  let minutes: Double?
  var ahead = false
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var shown = 0.0
  @State private var first = true
  static let wind = 0.75
  var body: some View {
    VStack(spacing: JourneyLayout.compact ? 6 : 10) {
      Spacer(minLength: 0)
      StopwatchFace(minutes: shown).frame(maxWidth: JourneyLayout.compact ? 170 : 210, maxHeight: JourneyLayout.compact ? 186 : 229)
      CountingText(value: shown) { TimeWords.clock($0) }
        .font(.app(JourneyLayout.compact ? .title2 : .title, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        .opacity(minutes == nil ? 0 : 1)
      if ahead {
        Label(store.t("Rests on time"), systemImage: "checkmark.circle.fill")
          .font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.accent)
      }
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("rest.watch")
    .accessibilityLabel(minutes.map { TimeWords.clock($0) } ?? "")
    .task(id: minutes) { await wind() }
  }
  private func wind() async {
    guard let minutes else { done(); return }
    if JourneyMotion.reduced(systemReduceMotion) { shown = minutes; done(); return }
    if first { first = false; try? await Task.sleep(for: .seconds(JourneyMotion.settle)); guard !Task.isCancelled else { return } }
    let begin = JourneyScorePlayer.shared.play(JourneyScores.windUp(from: shown, to: minutes, duration: Self.wind), profile: store.profile)
    try? await Task.sleep(for: .seconds(max(0, begin.timeIntervalSinceNow)))
    withAnimation(.easeOut(duration: Self.wind)) { shown = minutes }
    try? await Task.sleep(for: .seconds(Self.wind))
    guard !Task.isCancelled else { return }
    done()
  }
}

// MARK: - Page 7: how long they scroll

/// A phone that keeps scrolling a feed, one video every 1.25 s, as feeds do.
struct FeedPhone: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var start = Date()
  static let size = CGSize(width: 146, height: 262)
  static let reels: [(caption: String, top: Color, bottom: Color)] = [
    ("POV: just one more video", Color(red: 0.79, green: 0.72, blue: 0.65), Color(red: 0.55, green: 0.48, blue: 0.42)),
    ("Rate this pump 1–10", Color(red: 0.66, green: 0.71, blue: 0.61), Color(red: 0.39, green: 0.46, blue: 0.37)),
    ("3 mistakes on bench", Color(red: 0.82, green: 0.65, blue: 0.6), Color(red: 0.59, green: 0.42, blue: 0.38)),
    ("Wait for the end…", Color(red: 0.72, green: 0.7, blue: 0.8), Color(red: 0.47, green: 0.45, blue: 0.6)),
    ("Gym fails, part 47", Color(red: 0.78, green: 0.76, blue: 0.71), Color(red: 0.52, green: 0.49, blue: 0.44)),
    ("This fixed my squat", Color(red: 0.62, green: 0.7, blue: 0.72), Color(red: 0.36, green: 0.45, blue: 0.47)),
  ]
  var body: some View {
    TimelineView(.animation(paused: JourneyMotion.reduced(systemReduceMotion))) { context in
      let period = 1.25, n = Self.reels.count
      let t = max(0, context.date.timeIntervalSince(start))
      let step = Int(t / period)
      // Each video holds, then the next swipes up.
      let position = Double(step % n) + Ease.inOut(Ease.seg(t - Double(step) * period, period - 0.5, period))
      GeometryReader { g in
        VStack(spacing: 0) {
          ForEach(0...n, id: \.self) { i in reel(Self.reels[i % n]).frame(height: g.size.height) }
        }.offset(y: -position * g.size.height)
      }
      .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
    .padding(6)
    .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color(red: 0.09, green: 0.09, blue: 0.1)))
    .overlay(alignment: .top) { Capsule().fill(Color(red: 0.04, green: 0.04, blue: 0.05)).frame(width: 40, height: 12).padding(.top, 13) }
    .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
    .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
    .accessibilityHidden(true)
  }
  private func reel(_ r: (caption: String, top: Color, bottom: Color)) -> some View {
    ZStack(alignment: .bottomLeading) {
      LinearGradient(colors: [r.top, r.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
      VStack(alignment: .leading, spacing: 2) {
        Text(store.t(r.caption)).font(.system(size: 12.5, weight: .bold)).lineLimit(2)
        Text("@gym.daily").font(.system(size: 10)).opacity(0.8)
      }.foregroundStyle(.white).padding(.leading, 11).padding(.trailing, 38).padding(.bottom, 15)
      VStack(spacing: 11) {
        ForEach(["heart.fill", "bubble.right.fill", "paperplane.fill"], id: \.self) { Image(systemName: $0) }
      }.font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 10).padding(.bottom, 15)
    }
  }
}

/// The feed keeps going above the wheel; the pill says how long they say they stay on it.
struct ScrollMinutesStage: View {
  @Binding var minutes: Double
  @EnvironmentObject private var store: GymStore
  var body: some View {
    VStack(spacing: JourneyLayout.compact ? 6 : 10) {
      HStack(spacing: 6) {
        Image(systemName: "timer")
        Text(minutes >= 15 ? "15+ " + store.t("min") : "\(Int(minutes)) " + store.t("min")).monospacedDigit()
          .contentTransition(.numericText(value: minutes))
      }
      .font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.onButton)
      .padding(.horizontal, 12).padding(.vertical, 6).background(Capsule().fill(JourneyColor.button))
      .animation(.snappy, value: minutes)
      FeedPhone().frame(maxHeight: FeedPhone.size.height).frame(maxHeight: .infinity)
      JourneyWheel(values: (1...15).map(Double.init), unit: store.t("min"), id: "baseline.scrollMinutes", value: $minutes,
                   format: { $0 >= 15 ? "15+ " + store.t("min") : "\(Int($0)) " + store.t("min") })
        .frame(height: JourneyLayout.compact ? 130 : 170)
    }
  }
}

// MARK: - Two bars on one time axis (pages 8, 12, 14)

/// What's needed on top; below, how it goes: the same, then the red that runs past it. The dashed
/// line is where the top bar ends. Lengths are in minutes on an axis `axis` minutes wide; the caller
/// animates them.
struct TimeLanes: View {
  let axis: Double
  let top: (label: String, value: String, length: Double)
  let bottom: (label: String, value: String, shared: Double, over: Double)
  /// The bottom bar's part under the top bar: scrolling inside the rest is a light red; at workout
  /// size it's the same workout, neutral.
  var sharedTint: Color = JourneyColor.ink(0.24)
  let mark: Double
  var marked = 1.0
  /// The dashed "35 min back" box where the red was, and how far it's faded in.
  var back: (text: String, length: Double, opacity: Double)? = nil
  var overLabel: (text: String, opacity: Double)? = nil
  let ticks: [(Double, String)]
  private let bar: CGFloat = JourneyLayout.compact ? 20 : 24
  var body: some View {
    GeometryReader { g in
      let w = g.size.width
      let x = { (m: Double) -> CGFloat in CGFloat(max(0, m) / max(0.01, axis)) * w }
      VStack(alignment: .leading, spacing: 0) {
        label(top.label, top.value)
        ZStack(alignment: .leading) {
          Capsule().fill(JourneyColor.ink(0.06))
          Capsule().fill(JourneyColor.ink(0.24)).frame(width: max(top.length > 0 ? bar : 0, x(top.length)))
        }.frame(height: bar)
        label(bottom.label, bottom.value).padding(.top, 16)
        ZStack(alignment: .leading) {
          Capsule().fill(JourneyColor.ink(0.06))
          HStack(spacing: 0) {
            UnevenRoundedRectangle(topLeadingRadius: bar / 2, bottomLeadingRadius: bar / 2,
                                   bottomTrailingRadius: bottom.over > 0.01 ? 0 : bar / 2, topTrailingRadius: bottom.over > 0.01 ? 0 : bar / 2)
              .fill(sharedTint).frame(width: x(bottom.shared))
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: bar / 2, topTrailingRadius: bar / 2)
              .fill(JourneyColor.danger).frame(width: x(bottom.over))
          }
          if let back {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
              .strokeBorder(JourneyColor.accent, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
              .overlay(Text(back.text).font(.app(.footnote, weight: .bold)).foregroundStyle(JourneyColor.accent).lineLimit(1).minimumScaleFactor(0.7))
              .frame(width: x(back.length), height: bar + 8).offset(x: x(mark)).opacity(back.opacity)
          }
        }.frame(height: bar)
        ZStack(alignment: .topLeading) {
          if let overLabel {
            Text(overLabel.text).font(.app(.subheadline, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.danger)
              .fixedSize().frame(width: 120).position(x: x(mark + bottom.over / 2), y: 12).opacity(overLabel.opacity)
          }
        }.frame(height: overLabel == nil ? 8 : 26)
        ZStack(alignment: .topLeading) {
          ForEach(Array(ticks.enumerated()), id: \.offset) { i, tick in
            Text(tick.1).font(.app(.caption2)).monospacedDigit().foregroundStyle(JourneyColor.secondary).fixedSize()
              .alignmentGuide(.leading) { d in
                i == 0 ? -x(tick.0) : i == ticks.count - 1 ? -x(tick.0) + d.width : -x(tick.0) + d.width / 2
              }
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
      }
      .overlay(alignment: .topLeading) {
        // Where the top bar ends, through both bars.
        Path { p in p.move(to: CGPoint(x: x(mark), y: 20)); p.addLine(to: CGPoint(x: x(mark), y: 20 + bar + 16 + 20 + bar + 6)) }
          .stroke(JourneyColor.ink(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])).opacity(marked)
      }
    }.frame(height: 20 + bar + 16 + 20 + bar + (overLabel == nil ? 8 : 26) + 22)
  }
  private func label(_ text: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(text).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).lineLimit(1)
      Spacer(minLength: 8)
      Text(value).font(.app(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text).lineLimit(1)
    }.frame(height: 20, alignment: .top)
  }
}

extension TimeLanes {
  /// Minute ticks for the rest axis: every minute up to 6, then every 2.
  static func restTicks(_ axis: Double, store: GymStore) -> [(Double, String)] {
    let step = axis <= 6 ? 1.0 : 2.0
    return stride(from: 0.0, through: axis + 0.001, by: step).map { ($0, $0 == 0 ? "0" : "\(Int($0)) " + store.t("min")) }
  }
  /// Workout ticks: every 15 minutes up to an hour, then every 30.
  static func gymTicks(_ axis: Double, store: GymStore) -> [(Double, String)] {
    let step = axis <= 60 ? 15.0 : 30.0
    return stride(from: 0.0, through: axis + 0.001, by: step).map { m in (m, m == 0 ? "0" : m < 60 ? "\(Int(m)) " + store.t("min") : TimeWords.gymShort(m)) }
  }
}

// MARK: - Page 8: lost per rest (the first graph)

/// The rest they need against how long they scroll, on one axis. Both bars grow, then the part of
/// the scroll past the rest turns red and counts up. When the scroll fits inside the rest, no red.
struct PerRestStage: View {
  let time: TimeBack
  /// The promise when the answers don't fit their gym time: the same bars, the red sliding away.
  var giveBack = false
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  static let grow = 0.5, fill = 1.3, wait = 0.6, slide = 1.1
  var body: some View {
    let need = time.restNeed, scroll = time.scrolling ?? need, lost = time.lostPerRest ?? 0
    let axis = max(4, max(need, scroll).rounded(.up) + 1)
    let duration = giveBack ? Self.wait + Self.slide + 0.4 : Self.grow + (lost > 0 ? Self.fill : 0) + 0.3
    let score = giveBack ? JourneyScores.giveBack(at: Self.wait, slide: Self.slide)
      : lost > 0 ? JourneyScores.lostCount(at: Self.grow, fill: Self.fill, heavy: false) : nil
    SceneClock(duration: duration, score: score, done: done) { t in
      let g = giveBack ? 1 : Ease.out(Ease.seg(t, 0, Self.grow))
      let r = giveBack ? 1 - Ease.inOut(Ease.seg(t, Self.wait, Self.wait + Self.slide)) : JourneyScores.easeInOut(Ease.seg(t, Self.grow, Self.grow + Self.fill))
      VStack(spacing: JourneyLayout.compact ? 10 : 18) {
        Spacer(minLength: 0)
        if lost > 0 && !giveBack {
          VStack(spacing: 2) {
            Text("+" + TimeWords.clock(lost * r)).font(.app(size: JourneyLayout.compact ? 38 : 46, weight: .bold)).monospacedDigit()
              .foregroundStyle(JourneyColor.danger).accessibilityIdentifier("perRest.lost")
            Text(store.t(time.share < 1 ? "each time you scroll" : "every rest")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary)
          }
        }
        TimeLanes(axis: axis,
                  top: (store.t("Rest you need"), TimeWords.clock(need), need * g),
                  bottom: (store.t("Scrolling"), TimeWords.clock(giveBack && r < 0.5 ? need : scroll), min(need, scroll) * g, lost * r),
                  sharedTint: JourneyColor.danger.opacity(0.24), mark: need, marked: g,
                  ticks: TimeLanes.restTicks(axis, store: store))
        Spacer(minLength: 0)
      }
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("perRest.lanes")
    .accessibilityLabel(store.t("Rest you need") + " " + TimeWords.clock(need) + ", " + store.t("Scrolling") + " " + TimeWords.clock(scroll))
  }
}

// MARK: - Page 9: exercises, as kit on the rack

/// One piece of kit, drawn in ink, standing on its baseline (the bottom of a 80 × 72 cell).
struct KitPiece: View {
  let kind: Int
  var body: some View {
    Canvas { c, size in
      let s = size.width / 80
      let ink = GraphicsContext.Shading.color(JourneyColor.text)
      let paper = GraphicsContext.Shading.color(JourneyColor.stage)
      func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ rad: Double) -> Path {
        Path(roundedRect: CGRect(x: (40 + x) * s, y: (72 + y) * s, width: w * s, height: h * s), cornerRadius: rad * s)
      }
      func circle(_ x: Double, _ y: Double, _ rad: Double) -> Path {
        Path(ellipseIn: CGRect(x: (40 + x - rad) * s, y: (72 + y - rad) * s, width: 2 * rad * s, height: 2 * rad * s))
      }
      switch kind {
      case 0:  // Dumbbell.
        c.fill(r(-30, -36, 15, 36, 4), with: ink); c.fill(r(15, -36, 15, 36, 4), with: ink); c.fill(r(-16, -22, 32, 8, 3), with: ink)
      case 1: break  // The kettlebell, drawn over the canvas below.
      case 2:  // A plate on its edge.
        c.fill(circle(0, -31, 31), with: ink)
        c.stroke(circle(0, -31, 22), with: .color(JourneyColor.stage.opacity(0.28)), lineWidth: 2 * s)
        c.fill(circle(0, -31, 6), with: paper)
        c.draw(Text("20").font(.system(size: 9 * s, weight: .bold)).foregroundStyle(JourneyColor.stage.opacity(0.8)), at: CGPoint(x: 40 * s, y: (72 - 46) * s))
      case 3:  // Medicine ball.
        c.fill(circle(0, -26, 26), with: ink)
        var seams = Path()
        seams.move(to: CGPoint(x: 14 * s, y: 46 * s)); seams.addQuadCurve(to: CGPoint(x: 66 * s, y: 46 * s), control: CGPoint(x: 40 * s, y: 60 * s))
        seams.move(to: CGPoint(x: 40 * s, y: 20 * s)); seams.addQuadCurve(to: CGPoint(x: 40 * s, y: 72 * s), control: CGPoint(x: 29 * s, y: 46 * s))
        c.stroke(seams, with: .color(JourneyColor.stage.opacity(0.35)), lineWidth: 2.5 * s)
      case 4:  // A short barbell.
        c.fill(r(-40, -18, 80, 5, 2.5), with: ink)
        c.fill(r(-33, -34, 9, 34, 3), with: ink); c.fill(r(24, -34, 9, 34, 3), with: ink)
        c.fill(r(-23, -28, 6, 22, 2), with: ink); c.fill(r(17, -28, 6, 22, 2), with: ink)
      case 5:  // Cable handle.
        var loop = Path()
        loop.move(to: CGPoint(x: 21 * s, y: 61 * s)); loop.addLine(to: CGPoint(x: 40 * s, y: 24 * s)); loop.addLine(to: CGPoint(x: 59 * s, y: 61 * s))
        c.stroke(loop, with: ink, style: StrokeStyle(lineWidth: 7 * s, lineCap: .round, lineJoin: .round))
        c.fill(r(-24, -14, 48, 12, 6), with: ink)
        c.stroke(circle(0, -53, 5), with: ink, lineWidth: 3 * s)
      default:  // A lighter dumbbell.
        c.fill(r(-24, -28, 11, 28, 3), with: ink); c.fill(r(13, -28, 11, 28, 3), with: ink); c.fill(r(-14, -18, 28, 7, 3), with: ink)
      }
    }
    .overlay(alignment: .bottom) {
      // The mark's kettlebell without its keyhole: plain kit, not the logo (20 Oct 2026, at the user's request).
      if kind == 1 { KettlebellShape(part: .iron).fill(JourneyColor.text, style: FillStyle(eoFill: true)).frame(width: 66, height: 66).accessibilityHidden(true) }
    }
  }
}

/// A rack built to fit their workout: one piece of kit per exercise, each dropping onto its shelf
/// with a plate's clank. The rack is only as wide as the kit on it (half below, the rest above), so it
/// is full whatever the answer; "3 or fewer" never looks like an empty rack (20 Oct 2026, at the
/// user's request, replacing seven fixed slots).
struct RackStage: View {
  let count: Int?
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var shown = 0
  static let size = CGSize(width: 360, height: 240)
  static let cell = 80.0, shelves = (top: 100.0, bottom: 214.0), floor = 236.0
  static let gap = 0.11
  var body: some View {
    // Before an answer the rack is the smallest one: two below, one above.
    let n = max(3, shown)
    let width = Double((n + 1) / 2) * Self.cell + 16
    let x = Self.size.width / 2 - width / 2
    DesignFit(size: Self.size, maxScale: 1) {
      ZStack(alignment: .topLeading) {
        Group {
          ForEach([x, x + width - 7], id: \.self) { postX in
            RoundedRectangle(cornerRadius: 3.5).fill(JourneyColor.text).frame(width: 7, height: Self.floor - Self.shelves.top).offset(x: postX, y: Self.shelves.top)
          }
          ForEach([Self.shelves.top, Self.shelves.bottom], id: \.self) { y in
            RoundedRectangle(cornerRadius: 3.5).fill(JourneyColor.text).frame(width: width, height: 7).offset(x: x, y: y)
          }
        }.animation(.spring(response: 0.42, dampingFraction: 0.8), value: n)
        ForEach(0..<shown, id: \.self) { i in
          KitPiece(kind: i).frame(width: 80, height: 72)
            .offset(x: Self.slot(i, n: n).x - 40, y: Self.slot(i, n: n).y - 72)
            .transition(.asymmetric(insertion: .offset(y: -120).combined(with: .opacity), removal: .opacity))
        }
      }.frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("rack")
    .accessibilityLabel("\(count ?? 0)")
    .task(id: count) { await fill() }
  }
  /// Kit alternates shelves (bottom, top, bottom…), so a piece keeps its shelf as the rack grows;
  /// each shelf's pieces sit centred, so an odd count leaves the top row one short, in the middle.
  static func slot(_ i: Int, n: Int) -> CGPoint {
    let onShelf = i % 2 == 0 ? (n + 1) / 2 : n / 2
    let x = size.width / 2 + (Double(i / 2) - Double(onShelf - 1) / 2) * cell
    return CGPoint(x: x, y: i % 2 == 0 ? shelves.bottom : shelves.top)
  }
  private func fill() async {
    let target = min(7, max(0, count ?? 0))
    if JourneyMotion.reduced(systemReduceMotion) || target <= shown { withAnimation(.easeOut(duration: 0.2)) { shown = target }; return }
    if shown == 0 { try? await Task.sleep(for: .seconds(JourneyMotion.settle)) }
    let added = target - shown
    // Each piece lands about 0.3 s after it starts to fall.
    JourneyScorePlayer.shared.play(JourneyScores.rack(pieces: added, at: 0.3, gap: Self.gap), profile: store.profile)
    for _ in 0..<added {
      guard !Task.isCancelled else { return }
      withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) { shown += 1 }
      try? await Task.sleep(for: .seconds(Self.gap))
    }
  }
}

// MARK: - Page 10: sets, as today's log

/// Tally marks drawn as if by pen: four strokes, the fifth across them.
struct TallyMarks: Shape {
  var count: Int
  /// How many marks are drawn, continuously (2.5 = two drawn, the third half way).
  var drawn: Double
  var animatableData: Double { get { drawn } set { drawn = newValue } }
  func path(in rect: CGRect) -> Path {
    var p = Path()
    let sx = rect.width / 56, sy = rect.height / 26
    for k in 0..<count {
      let part = min(1, max(0, drawn - Double(k)))
      guard part > 0 else { continue }
      var stroke = Path()
      if k < 4 {
        let x = 9 + Double(k) * 12
        stroke.move(to: CGPoint(x: x * sx, y: 4 * sy)); stroke.addLine(to: CGPoint(x: (x + 1.6) * sx, y: 23 * sy))
      } else {
        stroke.move(to: CGPoint(x: 2 * sx, y: 19 * sy)); stroke.addQuadCurve(to: CGPoint(x: 50 * sx, y: 5 * sy), control: CGPoint(x: 26 * sx, y: 14 * sy))
      }
      p.addPath(stroke.trimmedPath(from: 0, to: part))
    }
    return p
  }
}

/// Today's log: one line per exercise, a tally mark for every set, drawn row by row.
struct LogTallyStage: View {
  let exercises: Int
  let sets: Int?
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var drawn = 0.0
  static let names = ["Bench press", "Squat", "Lat pulldown", "Shoulder press", "Deadlift", "Barbell curl", "Cable triceps pushdown"]
  static let mark = 0.07
  var body: some View {
    let rows = min(7, max(1, exercises)), each = min(5, max(0, sets ?? 0))
    DesignFit(size: CGSize(width: 330, height: CGFloat(48 + rows * 33)), maxScale: 1) {
      VStack(spacing: 0) {
        HStack {
          Text(store.t("Today’s log"))
          Spacer()
          if each > 0 { Text(String(format: store.t("%@ sets"), "\(rows * each)")).monospacedDigit() }
        }.font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).padding(.bottom, 7)
        ForEach(0..<rows, id: \.self) { i in
          HStack {
            Text(store.t(Self.names[i])).font(.app(.callout)).foregroundStyle(JourneyColor.text).lineLimit(1)
            Spacer(minLength: 8)
            TallyMarks(count: each, drawn: max(0, drawn - Double(i * each)))
              .stroke(JourneyColor.text, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
              .frame(width: 56, height: 26)
          }.frame(height: 33)
            .overlay(alignment: .top) { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
        }
      }
      .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 4)
      .journeySurface(cornerRadius: 20)
      .frame(width: 316)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("log.tally")
    .accessibilityLabel(String(format: store.t("%@ sets"), "\(rows * each)"))
    .task(id: "\(rows)x\(each)") { await draw(rows: rows, each: each) }
  }
  private func draw(rows: Int, each: Int) async {
    drawn = 0
    guard each > 0 else { return }
    let total = Double(rows * each)
    if JourneyMotion.reduced(systemReduceMotion) { drawn = total; return }
    try? await Task.sleep(for: .seconds(0.15))
    guard !Task.isCancelled else { return }
    // Row by row: each mark `mark` apart, a short pause between rows; a tick as each one finishes.
    let row = Double(each) * Self.mark + 0.1
    let marks = (0..<rows).map { r in (0..<each).map { k in Double(r) * row + Double(k + 1) * Self.mark } }
    JourneyScorePlayer.shared.play(JourneyScores.tally(marks: marks), profile: store.profile)
    for r in 0..<rows {
      withAnimation(.linear(duration: Double(each) * Self.mark)) { drawn = Double((r + 1) * each) }
      try? await Task.sleep(for: .seconds(row))
      guard !Task.isCancelled else { return }
    }
  }
}

// MARK: - Page 11: time at the gym, on the gym clock

/// A wall clock whose hands have run `elapsed` minutes from six o'clock; the wedge the hour hand
/// swept is the time spent.
struct GymClockFace: View, Animatable {
  var elapsed: Double
  var animatableData: Double { get { elapsed } set { elapsed = newValue } }
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  var body: some View {
    TimelineView(.animation(paused: JourneyMotion.reduced(systemReduceMotion))) { context in
      Canvas { c, size in
        let s = size.width / 220, center = CGPoint(x: 110 * s, y: 110 * s)
        func polar(_ r: Double, _ degrees: Double) -> CGPoint {
          let a = degrees * .pi / 180
          return CGPoint(x: center.x + r * s * sin(a), y: center.y - r * s * cos(a))
        }
        func disc(_ r: Double) -> Path { Path(ellipseIn: CGRect(x: center.x - r * s, y: center.y - r * s, width: 2 * r * s, height: 2 * r * s)) }
        c.fill(disc(104), with: .color(JourneyColor.text))
        c.fill(disc(95), with: .color(JourneyColor.raised))
        let hour = 180 + elapsed / 2
        if elapsed > 0.5 {
          var wedge = Path()
          wedge.move(to: center)
          wedge.addArc(center: center, radius: 95 * s, startAngle: .degrees(90), endAngle: .degrees(hour - 90), clockwise: false)
          wedge.closeSubpath()
          c.fill(wedge, with: .color(JourneyColor.accent.opacity(0.14)))
        }
        for i in 0..<60 {
          let five = i % 5 == 0, quarter = i % 15 == 0
          var tick = Path()
          tick.move(to: polar(88, Double(i) * 6)); tick.addLine(to: polar(quarter ? 73 : five ? 78 : 84, Double(i) * 6))
          c.stroke(tick, with: .color(JourneyColor.ink(five ? 0.85 : 0.22)), style: StrokeStyle(lineWidth: (quarter ? 4 : five ? 2.5 : 1.2) * s, lineCap: .round))
        }
        func hand(_ degrees: Double, _ length: Double, _ tail: Double, _ width: Double, _ color: Color) {
          var p = Path(); p.move(to: polar(-tail, degrees)); p.addLine(to: polar(length, degrees))
          c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width * s, lineCap: .round))
        }
        hand(hour, 48, 10, 7, JourneyColor.text)
        hand(elapsed * 6, 78, 14, 4.5, JourneyColor.text)
        // The second hand keeps going, as a gym's clock does.
        let seconds = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6) / 6 * 360
        hand(seconds, 82, 20, 1.8, JourneyColor.accent)
        c.fill(disc(6), with: .color(JourneyColor.text))
        c.fill(disc(2.4), with: .color(JourneyColor.accent))
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

/// The hands run from six o'clock for as long as they say they're at the gym.
struct GymClockStage: View {
  let minutes: Int?
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var elapsed = 0.0
  @State private var first = true
  static let run = 1.6
  var body: some View {
    VStack(spacing: JourneyLayout.compact ? 6 : 10) {
      Spacer(minLength: 0)
      GymClockFace(elapsed: elapsed).frame(maxWidth: JourneyLayout.compact ? 160 : 196, maxHeight: JourneyLayout.compact ? 160 : 196)
      Text(minutes.map { store.gymWords(Double($0)) } ?? " ").font(.app(JourneyLayout.compact ? .title2 : .title, weight: .bold))
        .foregroundStyle(JourneyColor.text).contentTransition(.opacity)
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("gym.clock")
    .accessibilityLabel(minutes.map { store.gymWords(Double($0)) } ?? "")
    .task(id: minutes) { await runHands() }
  }
  private func runHands() async {
    guard let minutes else { return }
    if JourneyMotion.reduced(systemReduceMotion) { elapsed = Double(minutes); return }
    if first { first = false; try? await Task.sleep(for: .seconds(JourneyMotion.settle)); guard !Task.isCancelled else { return } }
    elapsed = 0
    let begin = JourneyScorePlayer.shared.play(JourneyScores.clockRun(duration: Self.run), profile: store.profile)
    try? await Task.sleep(for: .seconds(max(0, begin.timeIntervalSinceNow)))
    withAnimation(.easeInOut(duration: Self.run)) { elapsed = Double(minutes) }
  }
}

// MARK: - Pages 12 and 14: the workout, two bars

/// Page 8's two bars at workout size: their workout with rests on time, against their time at the
/// gym; the red is the minutes scrolling runs past the rest. On the promise page it starts on that
/// last frame and the red slides away: the gym bar closes onto the workout and "35 min back" shows.
struct WorkTimeStage: View {
  let time: TimeBack
  var giveBack = false
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  static let grow = 0.5, fill = 1.3, wait = 0.6, slide = 1.1
  var body: some View {
    let gym = time.gym ?? 60, lost = time.lost ?? 0, workout = gym - lost
    let duration = giveBack ? Self.wait + Self.slide + 0.5 : Self.grow + Self.fill + 0.4
    let score = giveBack ? JourneyScores.giveBack(at: Self.wait, slide: Self.slide) : JourneyScores.lostCount(at: Self.grow, fill: Self.fill, heavy: true)
    SceneClock(duration: duration, score: score, done: done) { t in
      // Page 12: bars grow, then the red runs out past the workout and counts up.
      // Page 14: everything starts full; the red slides away.
      let g = giveBack ? 1 : Ease.out(Ease.seg(t, 0, Self.grow))
      let r = giveBack ? 1 - Ease.inOut(Ease.seg(t, Self.wait, Self.wait + Self.slide)) : JourneyScores.easeInOut(Ease.seg(t, Self.grow, Self.grow + Self.fill))
      let after = giveBack ? Ease.out(Ease.seg(t, Self.wait + Self.slide - 0.2, Self.wait + Self.slide + 0.3)) : 0
      let shownWorkout = store.aboutWords(time.workout)
      VStack(spacing: JourneyLayout.compact ? 10 : 18) {
        Spacer(minLength: 0)
        VStack(spacing: 2) {
          if giveBack {
            ZStack {
              Text(TimeWords.gymShort(gym)).opacity(1 - after)
              Text(shownWorkout).opacity(after)
            }.font(.app(size: JourneyLayout.compact ? 36 : 44, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
            ZStack {
              Text(store.t("at the gym today")).foregroundStyle(JourneyColor.secondary).opacity(1 - after)
              Text(store.t("with GymBlock")).foregroundStyle(JourneyColor.accent).opacity(after)
            }.font(.app(.subheadline))
          } else {
            Text("+\(Int((Double(time.shownLost) * r).rounded())) " + store.t("min")).font(.app(size: JourneyLayout.compact ? 38 : 46, weight: .bold))
              .monospacedDigit().foregroundStyle(JourneyColor.danger).accessibilityIdentifier("workout.lost")
            Text(store.t("scrolling, every workout")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary)
          }
        }
        TimeLanes(axis: gym,
                  top: (store.t("Your workout, rests on time"), shownWorkout, workout * g),
                  bottom: (store.t("Your time at the gym"), after > 0.5 ? shownWorkout : TimeWords.gymShort(gym), workout * g, lost * r),
                  mark: workout, marked: g,
                  back: giveBack ? (String(format: store.t("%@ min back"), "\(time.shownLost)"), lost, after) : nil,
                  overLabel: giveBack ? nil : ("+\(time.shownLost) " + store.t("min"), Ease.seg(t, Self.grow + Self.fill, Self.grow + Self.fill + 0.3)),
                  ticks: TimeLanes.gymTicks(gym, store: store))
        Spacer(minLength: 0)
      }
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier(giveBack ? "promise.lanes" : "workout.lanes")
    .accessibilityLabel(store.t("Your workout, rests on time") + " " + store.aboutWords(time.workout) + ", "
      + store.t("Your time at the gym") + " " + store.gymWords(gym))
  }
}

// MARK: - Page 13: the year, as extra workouts

/// The year's lost hours as workouts of their own length, one dot each, lighting on the score's
/// ticks and landing on the plate drop.
struct ExtraWorkoutsStage: View {
  let time: TimeBack
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  static let fill = 1.8
  var body: some View {
    let workouts = max(1, time.extraWorkouts)
    // Up to 120 workouts a dot each; past that each dot stands for several.
    let perDot = max(1, Int((Double(workouts) / 120).rounded(.up))), dots = max(1, Int((Double(workouts) / Double(perDot)).rounded(.up)))
    SceneClock(duration: Self.fill + 0.45, score: JourneyScores.year(fill: Self.fill), done: done) { t in
      let meaning = Ease.out(Ease.seg(t, Self.fill, Self.fill + 0.4))
      VStack(spacing: 18) {
        WorkoutDots(dots: dots, lit: Double(dots) * JourneyScores.easeInOut(t / Self.fill), columns: dots > 60 ? 12 : 10)
          .frame(maxWidth: JourneyLayout.compact ? 220 : 280).frame(maxHeight: .infinity)
          .accessibilityHidden(true)
        VStack(spacing: 4) {
          Text(String(format: store.t("= %@ extra workouts"), "\(time.extraWorkouts)"))
            .font(.app(JourneyLayout.compact ? .title2 : .title, weight: .bold)).foregroundStyle(JourneyColor.text).monospacedDigit()
            .accessibilityIdentifier("year.workouts")
          Text(perDot == 1 ? String(format: store.t("Each dot is one workout of %@."), store.gymWords(time.gym ?? 60))
               : String(format: store.t("Each dot is %@ workouts of %@."), "\(perDot)", store.gymWords(time.gym ?? 60)))
            .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
        }.opacity(meaning).offset(y: 8 * (1 - meaning))
      }
    }
  }
}
