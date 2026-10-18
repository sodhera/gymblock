import FamilyControls
import ManagedSettings
import SwiftUI

/// Lays a fixed reference composition into whatever space the stage zone offers.
struct StageBox {
  let size: CGSize
  let ref: CGSize
  var s: CGFloat { min(size.width / ref.width, size.height / ref.height) }
  var ox: CGFloat { (size.width - ref.width * s) / 2 }
  var oy: CGFloat { (size.height - ref.height * s) / 2 }
  func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
  func len(_ v: CGFloat) -> CGFloat { v * s }
}

private func pause(_ seconds: Double) async -> Bool {
  try? await Task.sleep(for: .seconds(seconds))
  return !Task.isCancelled
}
/// Waits until `t` seconds after `start`, so a sequence of steps keeps time with its score
/// (scheduled up front) instead of drifting by each sleep's overshoot. It returns the display's
/// lead early, so the frame a step changes is on screen on its beat.
private func pause(until t: Double, from start: Date) async -> Bool {
  let wait = t - JourneyScores.displayLead - Date().timeIntervalSince(start)
  if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
  return !Task.isCancelled
}

// MARK: - Notifications (welcome, first question)

struct Ping: Identifiable {
  let id: Int
  let app: String
  let symbol: String
  let text: String
  static let all: [Ping] = [
    // The last one in ends on top of the locked stack, so it's a feed, not a friend's message.
    Ping(id: 0, app: "Messages", symbol: "message.fill", text: "You coming to the gym?"),
    Ping(id: 1, app: "TikTok", symbol: "music.note", text: "Videos you might like"),
    Ping(id: 2, app: "YouTube", symbol: "play.rectangle.fill", text: "New: 10 min ab burner"),
    Ping(id: 3, app: "Instagram", symbol: "camera", text: "maya.lifts liked your photo"),
  ]
}

struct PingCard: View {
  let ping: Ping
  var compact = false
  @EnvironmentObject private var store: GymStore
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: ping.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(JourneyColor.text)
        .frame(width: 38, height: 38)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(JourneyColor.ink(0.14)))
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(ping.app).font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.text)
          Spacer(minLength: 4)
          Text(store.t("now")).font(.app(.caption)).foregroundStyle(JourneyColor.secondary)
        }
        Text(store.t(ping.text)).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary).lineLimit(1)
      }
    }.padding(.horizontal, 14).padding(.vertical, 12)
      .journeyGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

/// The phone question's notifications: three cards land one after another, newest on top, each
/// on its own light tap. The stack keeps its full size from the start (no jump as cards arrive) and
/// scales down to fit the space the page leaves it, so small screens and large text never overlap
/// the headline or the answers.
struct NotificationStage: View {
  let awake: Bool
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var shown = 0
  /// Top to bottom: the newest (YouTube) sits on top, the first to arrive (Messages) at the bottom.
  private var slots: [Ping] { Array(Ping.all.prefix(3).reversed()) }
  var body: some View {
    ScaleToFit {
      VStack(spacing: 10) {
        ForEach(Array(slots.enumerated()), id: \.element.id) { k, ping in
          // Slot k is the (3 - k)th to arrive.
          let on = shown >= 3 - k
          PingCard(ping: ping)
            .opacity(on ? 1 : 0).offset(y: on ? 0 : -14).scaleEffect(on ? 1 : 0.96)
            .animation(.spring(duration: 0.38, bounce: 0.2), value: on)
        }
      }.frame(maxWidth: 360)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.phone")
    .accessibilityLabel(store.t("Notifications arriving."))
    .task { await play() }
  }
  private func play() async {
    if JourneyMotion.reduced(systemReduceMotion) { shown = 3; done(); return }
    shown = 0
    for i in 0..<3 {
      guard await pause(i == 0 ? JourneyMotion.settle : 0.45) else { return }
      // One light tap per card, a little stronger each time, like they're creeping closer; no
      // sound. The card arrives on the tap's moment.
      let begin = JourneyScorePlayer.shared.play(JourneyScores.notification(strength: 0.3 + 0.08 * Double(i)), profile: store.profile)
      guard await pause(until: 0, from: begin) else { return }
      shown = i + 1
    }
    // The last card's spring settles, then Continue.
    guard await pause(0.45) else { return }
    done()
  }
}

/// Shows content at its natural height, scaled down (never up) to fit the space it's given, so a
/// small screen or large text shrinks the scene instead of pushing it into the headline or buttons.
struct ScaleToFit<Content: View>: View {
  @ViewBuilder let content: () -> Content
  @State private var natural: CGFloat = 0
  var body: some View {
    GeometryReader { g in
      let s = natural > 0 ? min(1, g.size.height / natural) : 1
      content()
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: g.size.width)
        .background(GeometryReader { c in
          Color.clear
            .onAppear { natural = c.size.height }
            .onChange(of: c.size.height) { _, h in natural = h }
        })
        .scaleEffect(s)
        .frame(width: g.size.width, height: g.size.height)
    }
  }
}

// MARK: - Your phone time

/// A whole workout as one ring: the red arc is time on the phone, the green arc is training.
struct SplitRing: View, Animatable {
  var phone: Double
  var training: Double
  var animatableData: AnimatablePair<Double, Double> {
    get { AnimatablePair(phone, training) }
    set { phone = newValue.first; training = newValue.second }
  }
  var body: some View {
    ZStack {
      Circle().stroke(JourneyColor.ink(0.08), lineWidth: 14)
      Circle().trim(from: 0, to: max(0, phone))
        .stroke(JourneyColor.danger, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
        .rotationEffect(.degrees(-90))
      Circle().trim(from: min(1, phone), to: min(1, phone + training))
        .stroke(JourneyColor.signal, style: StrokeStyle(lineWidth: 14, lineCap: .butt))
        .rotationEffect(.degrees(-90))
    }
  }
}

/// Phone time against training time, for an assumed typical workout.
struct RevealStage: View {
  let estimate: GymTimeEstimate
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var phone = 0.0
  @State private var training = 0.0
  @State private var counted = 0.0
  @State private var legend = false
  var body: some View {
    VStack(spacing: 24) {
      Spacer(minLength: 0)
      ZStack {
        SplitRing(phone: phone, training: training)
        VStack(spacing: 2) {
          CountingText(value: counted) { "\(Int($0.rounded()))" }
            .font(.app(size: JourneyLayout.compact ? 44 : 52, weight: .bold, design: .default)).monospacedDigit()
            .foregroundStyle(JourneyColor.text).frame(minWidth: 120)
          Text(store.t("min on your phone")).font(.app(JourneyLayout.compact ? .caption : .subheadline)).foregroundStyle(JourneyColor.secondary)
        }
      }.frame(width: JourneyLayout.compact ? 176 : 200, height: JourneyLayout.compact ? 176 : 200)
        .accessibilityElement(children: .ignore).accessibilityIdentifier("reveal.phone")
        .accessibilityLabel("\(Int(estimate.phoneMinutes.rounded())) " + store.t("min on your phone") + ", "
          + "\(Int(estimate.trainingMinutes.rounded())) " + store.t("min lifting"))
      // The sums behind both numbers, so "12 min" for 18 sets reads as lifting time, not a mistake.
      HStack(spacing: 0) {
        legendItem(JourneyColor.danger, store.t("On your phone"), estimate.phoneMinutes,
                   String(format: store.t("%@ rests × %@ min"), "\(estimate.rests)", Self.minutes(estimate.minutesPerRest)), id: "reveal.legend.phone")
        Rectangle().fill(JourneyColor.hairline).frame(width: 1, height: 52)
        legendItem(JourneyColor.signal, store.t("Lifting"), estimate.trainingMinutes,
                   String(format: store.t("%@ sets × %@ s"), "\(GymTimeEstimate.exercises * GymTimeEstimate.sets)", "\(Int(GymTimeEstimate.setSeconds))"),
                   id: "reveal.legend.training")
      }.padding(.vertical, 14).frame(maxWidth: 340)
        .journeyGlass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(legend ? 1 : 0).offset(y: legend ? 0 : 10)
      Spacer(minLength: 0)
    }
    .task { await play() }
  }
  private func legendItem(_ color: Color, _ label: String, _ minutes: Double, _ sum: String, id: String) -> some View {
    VStack(spacing: 4) {
      HStack(spacing: 6) {
        Circle().fill(color).frame(width: 8, height: 8)
        Text(label).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
      }
      Text("\(Int(minutes.rounded())) " + store.t("min")).font(.app(.title3, weight: .semibold)).monospacedDigit()
        .foregroundStyle(JourneyColor.text)
      Text(sum).font(.app(.caption)).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(1).minimumScaleFactor(0.8)
    }.frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier(id)
  }
  /// 3 → "3", 1.5 → "1.5".
  static func minutes(_ m: Double) -> String { m == m.rounded() ? "\(Int(m))" : String(format: "%.1f", m) }
  private func play() async {
    let p = estimate.phoneShare, t = 1 - estimate.phoneShare
    if JourneyMotion.reduced(systemReduceMotion) {
      phone = p; training = t; counted = estimate.phoneMinutes; legend = true; done(); return
    }
    guard await pause(JourneyMotion.settle + 0.1) else { return }
    let fill = 1.6 * max(0.3, p)
    // Ticks climb with the red count; the green lands with a light shimmer, no bass (JourneyScores.reveal).
    let begin = JourneyScorePlayer.shared.play(JourneyScores.reveal(fill: fill), profile: store.profile)
    guard await pause(until: 0, from: begin) else { return }
    withAnimation(.easeInOut(duration: fill)) { phone = p; counted = estimate.phoneMinutes }
    guard await pause(fill + 0.25) else { return }
    withAnimation(.easeOut(duration: 0.7)) { training = t }
    guard await pause(0.5) else { return }
    withAnimation(JourneyMotion.gentle) { legend = true }
    guard await pause(0.6) else { return }
    done()
  }
}

// MARK: - What it adds up to

/// One dot per 45-minute workout the yearly phone time could have been.
struct WorkoutDots: View, Animatable {
  var dots: Int
  var lit: Double
  var animatableData: Double { get { lit } set { lit = newValue } }
  static let columns = 14
  var body: some View {
    Canvas { c, size in
      let rows = max(1, Int(ceil(Double(dots) / Double(Self.columns))))
      let pitch = min(size.width / CGFloat(Self.columns), size.height / CGFloat(rows))
      let d = pitch * 0.48
      let x0 = (size.width - pitch * CGFloat(Self.columns)) / 2
      let y0 = (size.height - pitch * CGFloat(rows)) / 2
      let on = Int(lit.rounded(.down))
      for i in 0..<dots {
        let r = i / Self.columns, col = i % Self.columns
        let rect = CGRect(x: x0 + CGFloat(col) * pitch + (pitch - d) / 2, y: y0 + CGFloat(r) * pitch + (pitch - d) / 2, width: d, height: d)
        c.fill(Path(ellipseIn: rect), with: .color(i < on ? JourneyColor.danger : JourneyColor.ink(0.08)))
      }
    }
  }
}

struct DaysStage: View {
  let estimate: GymTimeEstimate
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  /// How long the dots take to light, eased like the ticks that follow them (JourneyScores.year).
  static let fill = 1.8
  /// Keeps the grid readable: one dot per workout up to 280, otherwise each dot stands for several.
  private var perDot: Int { max(1, Int(ceil(Double(estimate.yearlyWorkouts) / 280))) }
  private var dots: Int { max(1, Int(ceil(Double(estimate.yearlyWorkouts) / Double(perDot)))) }
  var body: some View {
    // Drawn from the score's clock, so the last dot lights on the plate drop, not after it.
    SceneClock(duration: Self.fill + 0.45, score: JourneyScores.year(fill: Self.fill), done: done) { t in
      let meaning = Ease.out(Ease.seg(t, Self.fill, Self.fill + 0.4))
      VStack(spacing: 18) {
        WorkoutDots(dots: dots, lit: Double(dots) * JourneyScores.easeInOut(t / Self.fill))
          .frame(maxWidth: JourneyLayout.compact ? 240 : 320).frame(maxHeight: .infinity)
          .accessibilityHidden(true)
        VStack(spacing: 4) {
          Text("= \(estimate.yearlyWorkouts) " + store.t("workouts"))
            .font(.app(JourneyLayout.compact ? .title2 : .title, weight: .bold)).foregroundStyle(JourneyColor.text).monospacedDigit()
            .accessibilityIdentifier("days.workouts")
          Text(perDot == 1 ? store.t("Each dot is one 45-min workout.")
               : String(format: store.t("Each dot is %@ workouts of 45 min."), "\(perDot)"))
            .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
        }.opacity(meaning).offset(y: 8 * (1 - meaning))
      }
    }
  }
}

// MARK: - Mind-muscle connection (two pages)

private let mindRef = CGSize(width: 300, height: 360)

struct NervePath: Shape {
  func path(in rect: CGRect) -> Path {
    let b = StageBox(size: rect.size, ref: mindRef)
    var p = Path()
    p.move(to: b.p(150, 136))
    p.addCurve(to: b.p(182, 280), control1: b.p(144, 190), control2: b.p(200, 220))
    return p
  }
}
/// A comet of light along the nerve; `head` animates, the tail follows exactly.
struct NervePulse: Shape {
  var head: Double
  var length = 0.22
  var animatableData: Double { get { head } set { head = newValue } }
  func path(in rect: CGRect) -> Path {
    let from = max(0, min(1, head - length)), to = max(0, min(1, head))
    guard to > from else { return Path() }
    return NervePath().path(in: rect).trimmedPath(from: from, to: to)
  }
}
struct AttentionPath: Shape {
  func path(in rect: CGRect) -> Path {
    let b = StageBox(size: rect.size, ref: mindRef)
    var p = Path()
    p.move(to: b.p(90, 100))
    p.addQuadCurve(to: b.p(70, 128), control: b.p(70, 102))
    return p
  }
}

/// Both mind-muscle pages, drawn from one clock (`MindState`, `MindFrame`) with their scores: the
/// fading page's signals weaken one after another, the steady page's land the same every time.
struct MindStage: View {
  let focused: Bool
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  var body: some View {
    SceneClock(duration: focused ? 3.55 : 3.6, score: focused ? JourneyScores.mindSteady : JourneyScores.mindFading, done: done) { t in
      MindFrame(state: focused ? .steady(t) : .fading(t))
    }
    // A new clock for the second page; it starts exactly where the first one ended.
    .id(focused)
    .accessibilityElement().accessibilityIdentifier("journey.mindMuscle")
    .accessibilityLabel(store.t(focused
      ? "With the phone away, each signal reaches the arm and it flexes."
      : "While scrolling, attention drifts to the phone and signals fade before reaching the arm."))
  }
}

// MARK: - Rest and the pump (two pages)

/// Stylized pump over time. Sets push it up; rests let it fall. Long phone rests drain it to zero.
enum PumpPlot {
  static let scrolling: [CGPoint] = [
    CGPoint(x: 0, y: 0), CGPoint(x: 0.06, y: 0.32), CGPoint(x: 0.31, y: 0.02), CGPoint(x: 0.37, y: 0.34),
    CGPoint(x: 0.63, y: 0.03), CGPoint(x: 0.69, y: 0.33), CGPoint(x: 0.96, y: 0.02),
  ]
  static let timed: [CGPoint] = [
    CGPoint(x: 0, y: 0), CGPoint(x: 0.06, y: 0.3), CGPoint(x: 0.21, y: 0.24), CGPoint(x: 0.27, y: 0.54),
    CGPoint(x: 0.42, y: 0.48), CGPoint(x: 0.48, y: 0.78), CGPoint(x: 0.63, y: 0.72), CGPoint(x: 0.69, y: 1.0),
    CGPoint(x: 0.96, y: 1.0),
  ]
  /// Indices where a rest segment ends (it starts one before).
  static func restEnds(_ points: [CGPoint]) -> [Int] {
    (1..<points.count).filter { points[$0].y < points[$0 - 1].y - 0.001 }
  }
}

struct PumpChart: View, Animatable {
  var points: [CGPoint]
  var progress: Double
  var timed: Bool
  var reached: Bool
  var finished: Bool
  var restLabel: String
  var axisY: String
  var axisX: String
  var pumpLabel: String
  var verdict: String
  var animatableData: Double { get { progress } set { progress = newValue } }
  var body: some View {
    GeometryReader { g in
      let plot = CGRect(x: 26, y: 22, width: g.size.width - 30, height: g.size.height - 62)
      let pt = { (p: CGPoint) in CGPoint(x: plot.minX + p.x * plot.width, y: plot.maxY - p.y * plot.height) }
      let head = point(at: progress)
      ZStack(alignment: .topLeading) {
        // Axes
        Path { p in
          p.move(to: CGPoint(x: plot.minX, y: plot.minY - 8)); p.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
          p.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        }.stroke(JourneyColor.ink(0.22), lineWidth: 1)
        Text(axisY).font(.app(.caption2, weight: .medium)).foregroundStyle(JourneyColor.secondary).fixedSize()
          .rotationEffect(.degrees(-90)).position(x: 9, y: plot.midY)
        Text(axisX + " →").font(.app(.caption2, weight: .medium)).foregroundStyle(JourneyColor.secondary)
          .frame(width: plot.width, alignment: .trailing).position(x: plot.midX, y: plot.maxY + 36)
        // Target
        Path { $0.move(to: pt(CGPoint(x: 0, y: 1))); $0.addLine(to: pt(CGPoint(x: 1, y: 1))) }
          .stroke(reached ? JourneyColor.accent : JourneyColor.ink(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
        HStack(spacing: 6) {
          Text(pumpLabel).font(.app(.caption, weight: .bold)).tracking(0.6)
            .foregroundStyle(reached ? JourneyColor.accent : JourneyColor.secondary)
          if finished { Text(verdict).font(.app(.caption)).foregroundStyle(reached ? JourneyColor.accent : JourneyColor.secondary) }
        }.frame(width: plot.width, alignment: .trailing).position(x: plot.midX, y: plot.minY - 12)
        // Data
        line(pt).stroke(timed ? JourneyColor.ink(0.9) : JourneyColor.ink(0.45),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        Circle().fill(reached ? JourneyColor.accent : timed ? JourneyColor.text : JourneyColor.ink(0.6))
          .frame(width: reached ? 12 : 8, height: reached ? 12 : 8).position(pt(head))
        ForEach(PumpPlot.restEnds(points), id: \.self) { end in
          let mid = (points[end - 1].x + points[end].x) / 2
          HStack(spacing: 3) {
            if !timed { Image(systemName: "iphone").font(.system(size: 9, weight: .semibold)) }
            Text(restLabel).font(.app(.caption, weight: .medium)).monospacedDigit()
          }.foregroundStyle(timed ? JourneyColor.text : JourneyColor.secondary).fixedSize()
            .position(x: plot.minX + mid * plot.width, y: plot.maxY + 14)
            .opacity(progress >= Double(end) - 0.05 ? 1 : 0)
        }
      }
    }
  }
  private func point(at value: Double) -> CGPoint {
    let i = min(points.count - 1, max(0, Int(value.rounded(.down))))
    let f = value - Double(i)
    guard i + 1 < points.count, f > 0 else { return points[i] }
    let a = points[i], b = points[i + 1]
    return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
  }
  private func line(_ pt: (CGPoint) -> CGPoint) -> Path {
    var p = Path(); p.move(to: pt(points[0]))
    let whole = Int(progress.rounded(.down))
    if whole >= 1 { for i in 1...min(whole, points.count - 1) { p.addLine(to: pt(points[i])) } }
    if progress > Double(whole) { p.addLine(to: pt(point(at: progress))) }
    return p
  }
}

struct RestStage: View {
  let timed: Bool
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var progress = 0.0
  @State private var curl = 0.2
  @State private var warmth = 0.05
  @State private var reached = false
  @State private var finished = false
  private var points: [CGPoint] { timed ? PumpPlot.timed : PumpPlot.scrolling }
  var body: some View {
    // The chart carries the message, so it sits first in the reading path; the arm is the result cue.
    VStack(spacing: 10) {
      PumpChart(points: points, progress: progress, timed: timed, reached: reached, finished: finished,
                restLabel: store.t("Rest") + " " + (timed ? "1:30" : "3:40"),
                axisY: store.t("Pump"), axisX: store.t("Time"), pumpLabel: store.t("FULL PUMP"),
                verdict: store.t(reached ? "Reached" : "Never reached"))
        .frame(height: JourneyLayout.compact ? 190 : 250)
      ArmView(curl: curl, warmth: warmth)
        .frame(maxWidth: JourneyLayout.compact ? 80 : 110, maxHeight: JourneyLayout.compact ? 80 : 110)
        .background(Circle().fill(RadialGradient(colors: [JourneyColor.accent.opacity(0.26), .clear], center: .center, startRadius: 0, endRadius: 80))
          .frame(width: 170, height: 170).opacity(reached ? 1 : 0))
    }.frame(maxHeight: .infinity)
      .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.rest")
      .accessibilityLabel(store.t(timed
        ? "With 1:30 rests the pump builds every set until it reaches the line."
        : "With long phone rests the pump drains to zero after every set and never reaches the line."))
      .task(id: timed) { await play() }
  }
  private func play() async {
    var t = Transaction(); t.disablesAnimations = true
    withTransaction(t) { progress = 0; reached = false; finished = false }
    withAnimation(.smooth(duration: 0.3)) { curl = 0.2; warmth = 0.05 }
    let pts = points
    if JourneyMotion.reduced(systemReduceMotion) {
      progress = Double(pts.count - 1); reached = timed; finished = true
      curl = timed ? 1 : 0.2; warmth = timed ? 1 : 0.02; done(); return
    }
    guard await pause(JourneyMotion.settle + 0.15) else { return }
    let durations = (1..<pts.count).map { i -> Double in
      let rising = pts[i].y > pts[i - 1].y + 0.001
      let holding = pts[i].y >= 0.999 && pts[i - 1].y >= 0.999
      return rising ? 0.34 : holding ? 0.5 : (timed ? 0.45 : 0.85)
    }
    // Scrolling: every set swells to the same middle strength, the rests get nothing. Timed: each
    // set lands stronger (JourneyScores.pump).
    let start = JourneyScorePlayer.shared.play(JourneyScores.pump(pts, timed: timed, durations: durations), profile: store.profile)
    guard await pause(until: 0, from: start) else { return }
    var at = 0.0
    for i in 1..<pts.count {
      let rising = pts[i].y > pts[i - 1].y + 0.001
      let holding = pts[i].y >= 0.999 && pts[i - 1].y >= 0.999
      let duration = durations[i - 1]
      withAnimation(.easeInOut(duration: duration)) { progress = Double(i) }
      if rising {
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) { curl = 1; warmth = pts[i].y }
      } else if !holding {
        withAnimation(.easeInOut(duration: duration)) { curl = 0.3; warmth = pts[i].y }
      }
      at += duration
      guard await pause(until: at, from: start) else { return }
      if pts[i].y >= 0.999 && !reached {
        withAnimation(.spring(duration: 0.6, bounce: 0.15)) { reached = true }
      }
    }
    withAnimation(.smooth(duration: 0.5)) { finished = true }
    guard await pause(0.55) else { return }
    done()
  }
}

// MARK: - Progress (two pages)

private let logRef = CGSize(width: 320, height: 280)
private let logVolume: [Double] = [160, 200, 180, 225, 250]
private let logValues = ["20×8", "20×10", "20×9", "22.5×10", "25×10"]

private func logPoint(_ i: Int, _ b: StageBox) -> CGPoint {
  b.p(34 + CGFloat(i) * 63, 196 - CGFloat((logVolume[i] - 150) / 110) * 150)
}
struct LogLine: Shape {
  /// How far along the drawn line each week's point sits (0–1), by length, so a line drawn at a
  /// constant speed reaches each one at its own time.
  static let hits: [Double] = {
    let b = StageBox(size: logRef, ref: logRef)
    let pts = (0..<5).map { logPoint($0, b) }
    var lengths = [0.0]
    for i in 1..<pts.count { lengths.append(lengths[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
    return lengths.map { $0 / (lengths.last ?? 1) }
  }()
  func path(in rect: CGRect) -> Path {
    let b = StageBox(size: rect.size, ref: logRef)
    var p = Path(); p.move(to: logPoint(0, b))
    for i in 1..<5 { p.addLine(to: logPoint(i, b)) }
    return p
  }
}

/// The log page's moment `t` on its score's clock (JourneyScores.remembering). The line draws at a
/// constant speed; each week's dot pops to its fullest the instant the line reaches it, on its key
/// click and tap; today's dot is the gain, and turns green as +5 kg lands, on that same beat.
struct LogFrame {
  /// When the line starts (the first dot grows just before it), how long it draws, and how long a
  /// dot takes to grow to its peak.
  static let start = 0.1, draw = 1.2, pop = 0.08
  static let hits = LogLine.hits.map { start + $0 * draw }
  static var today: Double { hits[hits.count - 1] }
  static var end: Double { today + 0.45 }
  let t: Double
  var line: Double { Ease.seg(t, Self.start, Self.start + Self.draw) }
  func dot(_ i: Int) -> Double { Self.pop(t - Self.hits[i]) }
  var gain: Double { Ease.out(Ease.seg(t, Self.today - Self.pop, Self.today)) }
  var green: Bool { t >= Self.today }
  /// A pop that peaks on its beat (`u` = 0): it grows over the `pop` before, overshoots, settles.
  static func pop(_ u: Double) -> Double {
    if u < -pop { return 0 }
    if u < 0 { return 1.2 * Ease.out((u + pop) / pop) }
    return 1 + 0.2 * (1 - Ease.out(min(1, u / 0.3)))
  }
}

struct LogStage: View {
  let remembered: Bool
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var revealed = 0
  @State private var forgotten = 0
  var body: some View {
    GeometryReader { g in
      let b = StageBox(size: g.size, ref: logRef)
      ZStack {
        Group {
          ForEach(0..<3, id: \.self) { k in
            Path { p in p.move(to: b.p(18, 46 + CGFloat(k) * 75)); p.addLine(to: b.p(302, 46 + CGFloat(k) * 75)) }
              .stroke(JourneyColor.ink(0.05), lineWidth: 1)
          }
          Path { p in p.move(to: b.p(18, 30)); p.addLine(to: b.p(18, 222)); p.addLine(to: b.p(306, 222)) }
            .stroke(JourneyColor.ink(0.22), lineWidth: 1)
          Text(store.t("Weight × reps")).font(.app(.caption2, weight: .medium)).foregroundStyle(JourneyColor.secondary).fixedSize()
            .rotationEffect(.degrees(-90)).position(b.p(6, 126))
          Text(store.t("Week") + " →").font(.app(.caption2, weight: .medium)).foregroundStyle(JourneyColor.secondary)
            .position(b.p(282, 266))
        }.opacity(remembered ? 1 : 0)
        if remembered {
          // The line, the dots and the gain are drawn from the score's clock, so each pop is seen on
          // the click that's heard.
          SceneClock(duration: LogFrame.end, score: JourneyScores.remembering(hits: LogFrame.hits), done: done) { t in
            logged(LogFrame(t: t), b)
          }
        }
        ForEach(0..<5, id: \.self) { i in
          value(i, b)
          Text(store.t(["W1", "W2", "W3", "W4", "Today"][i])).font(.app(.caption2)).foregroundStyle(JourneyColor.secondary)
            .position(b.p(34 + CGFloat(i) * 63, 240))
        }
      }
    }
    .accessibilityElement().accessibilityIdentifier("journey.logging")
    .accessibilityLabel(store.t(remembered
      ? "Logged weeks form a rising line; today is 5 kilograms heavier than week 1."
      : "Remembered weights fade into question marks, week after week."))
    .task(id: remembered) { if !remembered { await forget() } }
  }
  private func logged(_ f: LogFrame, _ b: StageBox) -> some View {
    ZStack {
      LogLine().trim(from: 0, to: f.line).stroke(JourneyColor.ink(0.8), style: StrokeStyle(lineWidth: b.len(2.2), lineCap: .round, lineJoin: .round))
      ForEach(0..<5, id: \.self) { i in
        let today = i == 4 && f.green
        Circle().fill(today ? JourneyColor.accent : JourneyColor.stage)
          .overlay(Circle().strokeBorder(today ? JourneyColor.accent : JourneyColor.ink(0.85), lineWidth: b.len(2)))
          .frame(width: b.len(i == 4 ? 12 : 9), height: b.len(i == 4 ? 12 : 9))
          .scaleEffect(max(0.01, f.dot(i)))
          .position(logPoint(i, b))
      }
      Text("+5 kg").font(.app(.headline, weight: .semibold)).foregroundStyle(JourneyColor.accent)
        .position(b.p(286, 16)).opacity(f.gain).offset(y: 6 * (1 - f.gain))
        .accessibilityIdentifier("journey.newBest")
    }
  }
  private func value(_ i: Int, _ b: StageBox) -> some View {
    let lost = !remembered && i < forgotten
    let y: CGFloat = remembered ? logPoint(i, b).y - b.len(20) : b.p(0, 120).y
    return ZStack {
      Text(logValues[i]).foregroundStyle(JourneyColor.text).opacity(lost ? 0 : 1).blur(radius: lost ? 4 : 0)
      Text("?").foregroundStyle(JourneyColor.text.opacity(0.75)).opacity(lost ? 1 : 0).scaleEffect(lost ? 1 : 0.6)
    }.font(.app(remembered ? .subheadline : .title, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
      .opacity(remembered || i < revealed ? 1 : 0)
      .position(x: logPoint(i, b).x, y: y)
      .animation(.spring(duration: 0.6, bounce: 0.1).delay(remembered ? Double(i) * 0.06 : 0), value: remembered)
  }
  /// One week at a time: it appears in full, holds, fades to "?" in full, and only then does the
  /// next appear. Today's stays.
  private func forget() async {
    if JourneyMotion.reduced(systemReduceMotion) { revealed = 5; forgotten = 4; done(); return }
    revealed = 0; forgotten = 0
    guard await pause(JourneyMotion.settle + 0.1) else { return }
    // Each number fades with a fainter tap (JourneyScores.forgetting), on the same clock as the fades.
    let start = JourneyScorePlayer.shared.play(JourneyScores.forgetting(period: 0.69, fade: 0.45), profile: store.profile)
    for i in 0..<5 {
      guard await pause(until: Double(i) * 0.69, from: start) else { return }
      withAnimation(.smooth(duration: 0.25)) { revealed = i + 1 }
      guard i < 4 else { break }
      guard await pause(until: Double(i) * 0.69 + 0.45, from: start) else { return }
      withAnimation(.easeOut(duration: 0.14)) { forgotten = i + 1 }
    }
    guard await pause(until: 4 * 0.69 + 0.35, from: start) else { return }
    done()
  }
}

// MARK: - Choose apps to block

/// The chosen apps, categories and sites on glass, drawn by iOS from Screen Time's opaque tokens
/// (GymBlock never learns which they are). Empty slots before anything is chosen; any tile opens
/// the system picker. Turn on blocking stamps a lock on each.
struct BlockStage: View {
  let locking: Bool
  let choose: () -> Void
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  @State private var stamped = 0
  enum Item: Hashable { case app(ApplicationToken), category(ActivityCategoryToken), site(WebDomainToken) }
  private var items: [Item] {
    let s = blocking.selection
    return s.applicationTokens.map(Item.app) + s.categoryTokens.map(Item.category) + s.webDomainTokens.map(Item.site)
  }
  /// Development only (`-storeShots YES`): six sample apps, locked, for App Store screenshots.
  private let samples = StoreShots.apps
  var body: some View {
    let all = items
    let shown = Array(all.prefix(all.count > 4 ? 3 : 4))
    // The shield has its own page before this one (OnboardingStep.shield); here, only the apps.
    ScaleToFit { VStack(spacing: 18) {
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
        if !samples.isEmpty {
          ForEach(samples.prefix(3), id: \.self) { sample($0) }
          if samples.count > 3 { more(samples.count - 3) }
        } else {
          ForEach(Array(shown.enumerated()), id: \.element) { i, item in tile(item, locked: i < stamped) }
          if all.count > 4 { more(all.count - 3) }
          // Nothing chosen yet: two rows of slots, so the page reads as a place to fill, not an empty one.
          ForEach(0..<max(0, (all.isEmpty ? 8 : 4) - all.count), id: \.self) { i in empty(first: all.isEmpty && i == 0) }
        }
      }.frame(maxWidth: 320)
      Text(!samples.isEmpty ? String(format: store.t("%@ blocked from Start to Finish."), "\(samples.count) " + store.t("apps"))
           : all.isEmpty ? store.t("Choose the apps that pull you in.")
           : String(format: store.t("%@ blocked from Start to Finish."), blocking.summary(store.t)))
        .font(JourneyType.label).foregroundStyle(JourneyColor.secondary).monospacedDigit().multilineTextAlignment(.center)
        .contentTransition(.numericText()).animation(.smooth(duration: 0.3), value: all.count)
        .accessibilityIdentifier("blocking.summary")
    }.frame(maxHeight: .infinity) }
    .task(id: locking) {
      guard locking else { stamped = 0; return }
      for i in 0..<min(4, all.count) {
        guard await pause(i == 0 ? 0.05 : 0.14) else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) { stamped = i + 1 }
        JourneyHaptic.play(.rigid, store.profile)
      }
    }
  }
  private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
  private func slot<Icon: View, Name: View>(locked: Bool = false, id: String, @ViewBuilder icon: () -> Icon, @ViewBuilder name: () -> Name) -> some View {
    Button { guard !locking else { return }; JourneyHaptic.play(.selection, store.profile); choose() } label: {
      VStack(spacing: 10) {
        icon().frame(width: 60, height: 60)
          .journeyGlass(shape, interactive: true)
          .opacity(locked ? 0.55 : 1)
          .overlay(alignment: .topTrailing) {
            Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(JourneyColor.onAccent)
              .frame(width: 26, height: 26).background(Circle().fill(JourneyColor.accent))
              .overlay(Circle().strokeBorder(JourneyColor.stage, lineWidth: 2))
              .offset(x: 9, y: -9).scaleEffect(locked ? 1 : 0.3).opacity(locked ? 1 : 0)
          }
        name().font(JourneyType.caption).lineLimit(1).frame(height: 16)
      }.frame(maxWidth: .infinity).contentShape(Rectangle())
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier(id)
  }
  @ViewBuilder private func tile(_ item: Item, locked: Bool) -> some View {
    switch item {
    case .app(let token):
      slot(locked: locked, id: "block.item") { Label(token).labelStyle(.iconOnly).scaleEffect(1.6) } name: { Label(token).labelStyle(.titleOnly).foregroundStyle(JourneyColor.text) }
    case .category(let token):
      slot(locked: locked, id: "block.item") { Label(token).labelStyle(.iconOnly).scaleEffect(1.6) } name: { Label(token).labelStyle(.titleOnly).foregroundStyle(JourneyColor.text) }
    case .site(let token):
      slot(locked: locked, id: "block.item") { Image(systemName: "globe").font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text) }
        name: { Label(token).labelStyle(.titleOnly).foregroundStyle(JourneyColor.text) }
    }
  }
  private func sample(_ app: StoreShots.App) -> some View {
    slot(locked: true, id: "block.item") {
      Image(app.asset).resizable().scaledToFill().frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 10.5, style: .continuous))
    } name: { Text(app.name).foregroundStyle(JourneyColor.text) }
  }
  private func more(_ n: Int) -> some View {
    slot(id: "block.more") { Text("+\(n)").font(.app(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text).monospacedDigit() }
      name: { Text(store.t("more")).foregroundStyle(JourneyColor.secondary) }
  }
  private func empty(first: Bool) -> some View {
    slot(id: first ? "block.add" : "block.empty") {
      Image(systemName: "plus").font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.secondary).opacity(first ? 1 : 0)
    } name: { Text(first ? store.t("Choose") : " ").foregroundStyle(JourneyColor.tertiary) }
      .accessibilityLabel(store.t("Choose apps")).accessibilityHidden(!first)
  }
}

// MARK: - Commitment

struct CommitStage: View {
  let lit: Int
  @EnvironmentObject private var store: GymStore
  static let pledges = ["My phone stays away between sets.", "I time every rest.", "I log every set."]
  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(Self.pledges.enumerated()), id: \.offset) { i, pledge in
          let on = i < lit
          if i > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1).padding(.leading, 60) }
          HStack(spacing: 18) {
            ZStack {
              Circle().strokeBorder(JourneyColor.ink(on ? 0 : 0.28), lineWidth: 1.5)
              Circle().fill(JourneyColor.button).scaleEffect(on ? 1 : 0.3).opacity(on ? 1 : 0)
              Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(JourneyColor.onButton).opacity(on ? 1 : 0)
            }.frame(width: 26, height: 26)
            Text(store.t(pledge)).font(.app(.body, weight: .medium)).foregroundStyle(on ? JourneyColor.text : JourneyColor.secondary)
              .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
          }.padding(.vertical, 14).padding(.horizontal, 18)
            .animation(.spring(duration: 0.3, bounce: 0.35), value: on)
            .accessibilityElement(children: .combine).accessibilityAddTraits(on ? .isSelected : [])
        }
      }.frame(maxWidth: 340).journeySurface()
      Spacer(minLength: 0)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Press and hold: the capsule fills, haptics ramp, and the commitment completes at 1.6 s.
struct HoldButton: View {
  let title: String
  let doneTitle: String
  let committed: Bool
  let onProgress: (Double) -> Void
  let onComplete: () -> Void
  @EnvironmentObject private var store: GymStore
  @State private var fill = 0.0
  @State private var holding = false
  @State private var ticker: Task<Void, Never>?
  static let duration = 1.6
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        Capsule().fill(JourneyColor.button)
        label(JourneyColor.onButton)
        Capsule().fill(JourneyColor.commitFill).frame(width: g.size.width * (committed ? 1 : fill))
        label(JourneyColor.onAccent).mask(alignment: .leading) { Rectangle().frame(width: g.size.width * (committed ? 1 : fill)) }
      }
    }.frame(height: 50).clipShape(Capsule())
      .scaleEffect(holding ? 0.97 : 1).animation(.smooth(duration: 0.2), value: holding)
      .contentShape(Capsule())
      .gesture(DragGesture(minimumDistance: 0)
        .onChanged { _ in if !holding && !committed { start() } }
        .onEnded { _ in release() })
      .accessibilityElement().accessibilityLabel(title).accessibilityAddTraits(.isButton)
      .accessibilityIdentifier("commit.hold")
      .accessibilityAction { finish() }
  }
  private func label(_ color: Color) -> some View {
    Text(committed ? doneTitle : title).font(JourneyType.button).foregroundStyle(color).frame(maxWidth: .infinity)
  }
  private func start() {
    holding = true
    let begin = Date()
    withAnimation(.linear(duration: Self.duration)) { fill = 1 }
    // One continuous buzz that climbs from barely there to full while the finger stays down.
    JourneyScorePlayer.shared.swell(Self.duration, from: 0.05, to: 0.7, sharpness: 0.4)
    ticker = Task { @MainActor in
      while !Task.isCancelled {
        let p = min(1, Date().timeIntervalSince(begin) / Self.duration)
        onProgress(p)
        if p >= 1 { finish(); return }
        try? await Task.sleep(for: .milliseconds(90))
      }
    }
  }
  private func release() {
    holding = false
    guard !committed else { return }
    ticker?.cancel()
    JourneyScorePlayer.shared.stop()
    onProgress(0)
    withAnimation(.easeOut(duration: 0.3)) { fill = 0 }
  }
  private func finish() {
    ticker?.cancel()
    holding = false
    onProgress(1)
    onComplete()
  }
}

// MARK: - Account and offer

/// One promise: a symbol in a quiet circle, a line, a detail.
struct FeatureRow: View {
  let symbol: String
  let text: String
  let detail: String
  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: symbol).font(.system(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.text)
        .frame(width: 34, height: 34).background(Circle().fill(JourneyColor.ink(0.09)))
        .overlay(Circle().strokeBorder(JourneyRim.gradient, lineWidth: 0.8)).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(text).font(.app(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
        Text(detail).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
      }.fixedSize(horizontal: false, vertical: true)
    }.padding(.vertical, 8)
  }
}

/// Why an account: the three things it does, on one glass card.
struct AccountStage: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 10) {
          BrandMark(size: 22)
          Text(store.t("Your account")).font(.app(.headline, weight: .semibold)).foregroundStyle(JourneyColor.text)
          Spacer()
        }.padding(.bottom, 18)
        FeatureRow(symbol: "icloud.fill", text: store.t("Backed up as you train"), detail: store.t("Every set is saved to your account."))
        FeatureRow(symbol: "iphone.gen3", text: store.t("Same log on any iPhone"), detail: store.t("Sign in and it’s all there."))
        FeatureRow(symbol: "lock.fill", text: store.t("Private"), detail: store.t("Only you can read your data."))
      }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        .padding(18).journeySurface()
        .accessibilityIdentifier("journey.account")
      Spacer(minLength: 0)
    }
  }
}

/// Apple as the primary, Google beneath it, in the same footprint as every other page's actions.
/// The intent names the action ("Sign up with…" at the end of sign-up, "Sign in with…" on the
/// returning path) and is what the account uses to tell a surprise from the expected. Each button
/// keeps its own spinner until the account's data has arrived. Development runs replace Google with
/// a labelled skip, so tests never touch a real sheet.
struct AccountButtons: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  var intent: Account.Intent = .link
  var skip: (() -> Void)? = nil
  /// What the account held, after a sign-in that went through.
  var signedIn: (CloudSync.Found) -> Void = { _ in }
  private var verb: String { intent == .signUp ? "Sign up with" : intent == .signIn ? "Sign in with" : "Continue with" }
  var body: some View {
    VStack(spacing: 4) {
      JourneyButton(title: store.t(verb + " Apple"), symbol: "apple.logo", id: "account.apple",
                    enabled: !account.busy || account.loading == .apple, loading: account.loading == .apple) {
        run(.apple)
      }
      #if DEBUG
        if AppConfig.offline, let skip {
          JourneyTextButton(title: "Continue without an account · Debug", id: "account.debugSkip", action: skip)
        } else { google }
      #else
        google
      #endif
    }
  }
  private func run(_ provider: Account.Provider) {
    guard !account.busy else { return }
    JourneyHaptic.play(.medium, store.profile)
    Task { @MainActor in
      if let found = await account.signIn(provider, intent: intent) { signedIn(found) }
    }
  }
  /// The same shape and size as the Apple button, in white with Google's own G.
  private var google: some View {
    let loading = account.loading == .google
    let label = ZStack {
      HStack(spacing: 8) {
        Image("GoogleG").resizable().frame(width: 18, height: 18).accessibilityHidden(true)
        Text(store.t(verb + " Google")).font(JourneyType.button).lineLimit(1).minimumScaleFactor(0.8)
      }.opacity(loading ? 0 : 1)
      if loading { ProgressView().tint(JourneyColor.text) }
    }.foregroundStyle(JourneyColor.text).frame(maxWidth: .infinity, minHeight: 22)
    let tapped = {
      Analytics.tap("account.google")
      run(.google)
    }
    let dimmed = account.busy && !loading
    return Group {
      if #available(iOS 26.0, *) {
        Button(action: tapped) { label }.buttonStyle(.glassProminent).tint(.white)
          .overlay(Capsule().strokeBorder(JourneyColor.ink(0.12), lineWidth: 1).allowsHitTesting(false))
      } else {
        Button(action: tapped) {
          label.frame(minHeight: 50).background(Capsule().fill(.white)).overlay(Capsule().strokeBorder(JourneyColor.ink(0.12), lineWidth: 1))
        }.buttonStyle(JourneyPressStyle())
      }
    }.controlSize(.large).buttonBorderShape(.capsule)
      .disabled(dimmed).opacity(dimmed ? 0.38 : 1)
      .accessibilityIdentifier("account.google").padding(.top, 6)
  }
}


// MARK: - Name, height and weight

struct NameStage: View {
  @Binding var name: String
  let submit: () -> Void
  @EnvironmentObject private var store: GymStore
  @FocusState private var focused: Bool
  var body: some View {
    VStack(spacing: 10) {
      Spacer(minLength: 0)
      TextField("", text: $name, prompt: Text(store.t("Your name")).foregroundColor(JourneyColor.tertiary))
        .font(.app(.title, weight: .semibold)).multilineTextAlignment(.center).foregroundStyle(JourneyColor.text)
        .textContentType(.givenName).textInputAutocapitalization(.words).autocorrectionDisabled()
        .submitLabel(.continue).focused($focused).onSubmit(submit).tint(JourneyColor.accent)
        .padding(.vertical, 14).padding(.horizontal, 18)
        .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("profile.name")
      Spacer(minLength: 0)
    }
    .task { try? await Task.sleep(for: .seconds(JourneyMotion.settle)); focused = true }
  }
}

/// Gender: the options are the content, so they sit in the middle of the page.
struct GenderStage: View {
  let gender: String?
  let choose: (String) -> Void
  @EnvironmentObject private var store: GymStore
  var body: some View {
    JourneyGlassGroup(spacing: 12) {
      VStack(spacing: 12) {
        ForEach([("Male", "male"), ("Female", "female"), ("Other", "other")], id: \.1) { title, value in
          JourneyOption(title: store.t(title), selected: gender == value, id: "profile.gender." + value) { choose(value) }
        }
      }
    }.frame(maxHeight: .infinity)
  }
}

/// One big wheel and a unit switch.
struct MeasureStage: View {
  let values: [Double]
  let unit: String
  let id: String
  @Binding var value: Double
  var format: ((Double) -> String)? = nil
  let units: [String]
  @Binding var unitIndex: Int
  @EnvironmentObject private var store: GymStore
  var body: some View {
    VStack(spacing: 26) {
      Spacer(minLength: 0)
      JourneyWheel(values: values, unit: unit, id: id, value: $value, format: format)
        .frame(height: 200).clipped()
      Picker(store.t("Units"), selection: $unitIndex) {
        ForEach(units.indices, id: \.self) { Text(units[$0]).tag($0) }
      }.pickerStyle(.segmented).frame(maxWidth: 220).accessibilityIdentifier(id + ".units")
      Spacer(minLength: 0)
    }
  }
}

// MARK: - Rest alerts

/// A rest ring runs to 1:30 and a lock-screen notification lands.
struct AlertStage: View {
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var ring = 0.0
  @State private var seconds = 0.0
  @State private var arrived = false
  var body: some View {
    VStack(spacing: 28) {
      Spacer(minLength: 0)
      ZStack {
        Circle().stroke(JourneyColor.ink(0.08), lineWidth: 8)
        Circle().trim(from: 0, to: ring).stroke(JourneyColor.ink(0.9), style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: 2) {
          Text(store.t("Rest")).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
          CountingText(value: seconds) { clockString(Int($0)) }
            .font(.app(.largeTitle, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        }
      }.frame(width: 150, height: 150)
      HStack(spacing: 12) {
        Image(systemName: "bell.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(JourneyColor.onAccent)
          .frame(width: 38, height: 38).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(JourneyColor.accent))
        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text("GymBlock").font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.text)
            Spacer(minLength: 4)
            Text(store.t("now")).font(.app(.caption)).foregroundStyle(JourneyColor.secondary)
          }
          Text(store.t("Rest’s up. Time for your next set.")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary).lineLimit(1)
        }
      }.padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: 360)
        .journeyGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .offset(y: arrived ? 0 : -24).opacity(arrived ? 1 : 0)
        .accessibilityElement(children: .combine).accessibilityIdentifier("alerts.preview")
      Spacer(minLength: 0)
    }
    .task { await play() }
  }
  private func play() async {
    if JourneyMotion.reduced(systemReduceMotion) { ring = 1; seconds = 90; arrived = true; done(); return }
    try? await Task.sleep(for: .seconds(JourneyMotion.settle + 0.1))
    guard !Task.isCancelled else { return }
    withAnimation(.easeInOut(duration: 1.7)) { ring = 1; seconds = 90 }
    await JourneyHaptic.crescendo(store.profile, count: 8, duration: 1.7)
    guard !Task.isCancelled else { return }
    withAnimation(JourneyMotion.gentle) { arrived = true }
    JourneyHaptic.notification(store.profile)
    try? await Task.sleep(for: .seconds(0.5))
    guard !Task.isCancelled else { return }
    done()
  }
}
