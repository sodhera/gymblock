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

// MARK: - Notifications (welcome, first question)

struct Ping: Identifiable {
  let id: Int
  let app: String
  let symbol: String
  let text: String
  static let all: [Ping] = [
    Ping(id: 0, app: "Instagram", symbol: "camera", text: "maya.lifts liked your photo"),
    Ping(id: 1, app: "TikTok", symbol: "music.note", text: "Videos you might like"),
    Ping(id: 2, app: "YouTube", symbol: "play.rectangle.fill", text: "New: 10 min ab burner"),
    Ping(id: 3, app: "Messages", symbol: "message.fill", text: "You coming to the gym?"),
  ]
}

struct PingCard: View {
  let ping: Ping
  var compact = false
  @EnvironmentObject private var store: GymStore
  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: ping.symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
        .frame(width: 38, height: 38)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.14)))
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Text(ping.app).font(.subheadline.weight(.semibold)).foregroundStyle(JourneyColor.text)
          Spacer(minLength: 4)
          Text(store.t("now")).font(.caption).foregroundStyle(JourneyColor.secondary)
        }
        Text(store.t(ping.text)).font(.subheadline).foregroundStyle(JourneyColor.secondary).lineLimit(1)
      }
    }.padding(.horizontal, 14).padding(.vertical, 12)
      .journeyGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }
}

/// Notifications pile up, then sweep away, leaving one lock. On the first question they creep back.
struct NotificationStage: View {
  let awake: Bool
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var shown = 0
  @State private var cleared = false
  @State private var locked = false
  var body: some View {
    ZStack {
      VStack(spacing: 10) {
        ForEach(Array(Ping.all.prefix(shown).reversed())) { ping in
          PingCard(ping: ping)
            .offset(x: cleared ? 420 : 0).opacity(cleared ? 0 : 1)
            .animation(.smooth(duration: 0.6).delay(cleared ? Double(ping.id) * 0.08 : 0), value: cleared)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
        }
      }.frame(maxWidth: 360).frame(maxHeight: .infinity)
      VStack(spacing: 14) {
        Image(systemName: "lock.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(JourneyColor.onAccent)
          .frame(width: 72, height: 72).background(Circle().fill(JourneyColor.accent))
          .background(Circle().fill(RadialGradient(colors: [JourneyColor.accent.opacity(0.28), .clear], center: .center, startRadius: 0, endRadius: 110)).frame(width: 220, height: 220))
        Text(store.t("Apps locked while you train")).font(.subheadline).foregroundStyle(JourneyColor.secondary)
      }.scaleEffect(locked ? 1 : 0.7).opacity(locked ? 1 : 0)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.phone")
      .accessibilityLabel(store.t(awake ? "Notifications arriving." : "Notifications are cleared and apps are locked while you train."))
      .task(id: awake) { await play() }
  }
  private func play() async {
    let reduced = JourneyMotion.reduced(systemReduceMotion)
    if awake {
      withAnimation(.smooth(duration: 0.4)) { locked = false; cleared = false; shown = 0 }
      if reduced { shown = 3; return }
      for i in 0..<3 {
        guard await pause(i == 0 ? JourneyMotion.settle : 1.1) else { return }
        withAnimation(JourneyMotion.gentle) { shown = i + 1 }
        JourneyHaptic.notification(store.profile)
      }
      return
    }
    var t = Transaction(); t.disablesAnimations = true
    withTransaction(t) { shown = 0; cleared = false; locked = false }
    if reduced { locked = true; done(); return }
    for i in 0..<Ping.all.count {
      guard await pause(i == 0 ? JourneyMotion.settle + 0.15 : 0.5) else { return }
      withAnimation(JourneyMotion.gentle) { shown = i + 1 }
      JourneyHaptic.notification(store.profile)
    }
    guard await pause(0.9) else { return }
    cleared = true
    JourneyHaptic.play(.soft, store.profile, intensity: 0.7)
    guard await pause(0.6) else { return }
    withAnimation(.spring(duration: 0.7, bounce: 0.18)) { locked = true }
    JourneyHaptic.play(.rigid, store.profile)
    guard await pause(0.12) else { return }
    JourneyHaptic.play(.success, store.profile)
    guard await pause(0.35) else { return }
    done()
  }
}

// MARK: - Your phone time

/// A whole workout as one ring: the red arc is time on the phone, the white arc is training.
struct SplitRing: View, Animatable {
  var phone: Double
  var training: Double
  var animatableData: AnimatablePair<Double, Double> {
    get { AnimatablePair(phone, training) }
    set { phone = newValue.first; training = newValue.second }
  }
  var body: some View {
    ZStack {
      Circle().stroke(Color.white.opacity(0.08), lineWidth: 16)
      Circle().trim(from: 0, to: max(0, phone - 0.004))
        .stroke(JourneyColor.signalRed, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
        .rotationEffect(.degrees(-90))
      Circle().trim(from: min(1, phone + 0.004), to: min(1, phone + training))
        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 16, lineCap: .butt))
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
            .font(.system(size: 64, weight: .bold, design: .default)).monospacedDigit()
            .foregroundStyle(JourneyColor.text).frame(minWidth: 120)
          Text(store.t("min on your phone")).font(.subheadline).foregroundStyle(JourneyColor.secondary)
        }
      }.frame(width: 236, height: 236)
        .accessibilityElement(children: .ignore).accessibilityIdentifier("reveal.phone")
        .accessibilityLabel("\(Int(estimate.phoneMinutes.rounded())) " + store.t("min on your phone") + ", "
          + "\(Int(estimate.trainingMinutes.rounded())) " + store.t("min training"))
      HStack(spacing: 0) {
        legendItem(JourneyColor.signalRed, store.t("On your phone"), estimate.phoneMinutes, id: "reveal.legend.phone")
        Rectangle().fill(JourneyColor.hairline).frame(width: 1, height: 40)
        legendItem(.white, store.t("Training"), estimate.trainingMinutes, id: "reveal.legend.training")
      }.padding(.vertical, 14).frame(maxWidth: 340)
        .journeyGlass(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(legend ? 1 : 0).offset(y: legend ? 0 : 10)
      Spacer(minLength: 0)
    }
    .task { await play() }
  }
  private func legendItem(_ color: Color, _ label: String, _ minutes: Double, id: String) -> some View {
    VStack(spacing: 4) {
      HStack(spacing: 6) {
        Circle().fill(color).frame(width: 8, height: 8)
        Text(label).font(.footnote).foregroundStyle(JourneyColor.secondary)
      }
      Text("\(Int(minutes.rounded())) " + store.t("min")).font(.system(.title3, weight: .semibold)).monospacedDigit()
        .foregroundStyle(JourneyColor.text)
    }.frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier(id)
  }
  private func play() async {
    let p = estimate.phoneShare, t = 1 - estimate.phoneShare
    if JourneyMotion.reduced(systemReduceMotion) {
      phone = p; training = t; counted = estimate.phoneMinutes; legend = true; done(); return
    }
    guard await pause(JourneyMotion.settle + 0.1) else { return }
    let fill = 1.6 * max(0.3, p)
    withAnimation(.easeInOut(duration: fill)) { phone = p; counted = estimate.phoneMinutes }
    await JourneyHaptic.crescendo(store.profile, count: 14, duration: fill)
    JourneyHaptic.land(store.profile)
    guard await pause(0.25) else { return }
    withAnimation(.easeOut(duration: 0.7)) { training = t }
    JourneyHaptic.play(.soft, store.profile, intensity: 0.6)
    guard await pause(0.5) else { return }
    withAnimation(JourneyMotion.gentle) { legend = true }
    guard await pause(0.4) else { return }
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
        c.fill(Path(ellipseIn: rect), with: .color(i < on ? JourneyColor.accent : Color.white.opacity(0.08)))
      }
    }
  }
}

struct DaysStage: View {
  let estimate: GymTimeEstimate
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var lit = 0.0
  @State private var meaning = false
  /// Keeps the grid readable: one dot per workout up to 280, otherwise each dot stands for several.
  private var perDot: Int { max(1, Int(ceil(Double(estimate.yearlyWorkouts) / 280))) }
  private var dots: Int { max(1, Int(ceil(Double(estimate.yearlyWorkouts) / Double(perDot)))) }
  var body: some View {
    VStack(spacing: 18) {
      WorkoutDots(dots: dots, lit: lit).frame(maxWidth: 320).frame(maxHeight: .infinity)
        .accessibilityHidden(true)
      VStack(spacing: 4) {
        Text("= \(estimate.yearlyWorkouts) " + store.t("workouts"))
          .font(.system(.title, weight: .bold)).foregroundStyle(JourneyColor.text).monospacedDigit()
          .accessibilityIdentifier("days.workouts")
        Text(perDot == 1 ? store.t("Each dot is one 45-min workout.")
             : String(format: store.t("Each dot is %@ workouts of 45 min."), "\(perDot)"))
          .font(.footnote).foregroundStyle(JourneyColor.secondary)
      }.opacity(meaning ? 1 : 0).offset(y: meaning ? 0 : 8)
    }
    .task { await play() }
  }
  private func play() async {
    if JourneyMotion.reduced(systemReduceMotion) { lit = Double(dots); meaning = true; done(); return }
    guard await pause(JourneyMotion.settle + 0.1) else { return }
    let duration = 1.8
    withAnimation(.easeInOut(duration: duration)) { lit = Double(dots) }
    await JourneyHaptic.crescendo(store.profile, count: 16, duration: duration)
    if Task.isCancelled { return }
    JourneyHaptic.land(store.profile)
    withAnimation(JourneyMotion.gentle) { meaning = true }
    guard await pause(0.5) else { return }
    done()
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

struct MindStage: View {
  let focused: Bool
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var pulse = 0.0
  @State private var pulseAlpha = 0.0
  @State private var lit = false
  @State private var curl = 0.15
  @State private var warmth = 0.0
  @State private var flow: CGFloat = 0
  var body: some View {
    GeometryReader { g in
      let b = StageBox(size: g.size, ref: mindRef)
      ZStack {
        Circle().fill(RadialGradient(colors: [JourneyColor.accent.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: b.len(120)))
          .frame(width: b.len(240), height: b.len(240)).position(b.p(150, 80)).opacity(focused ? 1 : 0)
        NervePath().stroke(lit ? JourneyColor.accent.opacity(0.75) : Color.white.opacity(focused ? 0.16 : 0.1),
                           style: StrokeStyle(lineWidth: b.len(2), lineCap: .round))
        NervePulse(head: pulse).stroke(focused ? JourneyColor.accent.opacity(0.3) : Color.white.opacity(0.1), style: StrokeStyle(lineWidth: b.len(9), lineCap: .round))
          .opacity(pulseAlpha)
        NervePulse(head: pulse).stroke(focused ? JourneyColor.accent : Color.white.opacity(0.5), style: StrokeStyle(lineWidth: b.len(3), lineCap: .round))
          .opacity(pulseAlpha)
        AttentionPath().stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: b.len(1.6), lineCap: .round, dash: [2, 7], dashPhase: flow))
          .opacity(focused ? 0 : 1)
        pings(b).opacity(focused ? 0 : 1).offset(x: focused ? -b.len(30) : 0)
        brain(b)
        ArmView(curl: curl, warmth: warmth).frame(width: b.len(168), height: b.len(168)).position(b.p(150, 276))
      }
    }
    .animation(.smooth(duration: 0.8), value: focused)
    .accessibilityElement().accessibilityIdentifier("journey.mindMuscle")
    .accessibilityLabel(store.t(focused
      ? "With the phone away, each signal reaches the arm and it flexes."
      : "While scrolling, attention drifts to the phone and signals fade before reaching the arm."))
    .task(id: focused) { await play() }
  }
  private func brain(_ b: StageBox) -> some View {
    let tone = focused ? JourneyColor.text : JourneyColor.secondary
    return ZStack {
      BrainOutline().fill(JourneyColor.stage)
      BrainFolds().stroke(tone.opacity(0.45), style: StrokeStyle(lineWidth: b.len(1.4), lineCap: .round))
      BrainOutline().stroke(tone, style: StrokeStyle(lineWidth: b.len(1.8), lineCap: .round))
      BrainEyes(mood: focused ? 1 : -0.8).fill(tone)
      BrainMouth(mood: focused ? 1 : -0.8).stroke(tone, style: StrokeStyle(lineWidth: b.len(2.6), lineCap: .round))
    }.frame(width: b.len(132), height: b.len(121)).position(b.p(150, 78))
  }
  /// Two miniature notifications pulling attention away.
  private func pings(_ b: StageBox) -> some View {
    VStack(alignment: .leading, spacing: b.len(6)) {
      ForEach(0..<2, id: \.self) { i in
        HStack(spacing: b.len(5)) {
          Image(systemName: Ping.all[i].symbol).font(.system(size: b.len(11), weight: .bold)).foregroundStyle(.white)
            .frame(width: b.len(22), height: b.len(22))
            .background(RoundedRectangle(cornerRadius: b.len(6), style: .continuous).fill(Color.white.opacity(0.22)))
          VStack(alignment: .leading, spacing: b.len(4)) {
            Capsule().fill(Color.white.opacity(0.75)).frame(width: b.len(30), height: b.len(4))
            Capsule().fill(Color.white.opacity(0.4)).frame(width: b.len(44), height: b.len(4))
          }
        }.padding(b.len(7))
          .background(RoundedRectangle(cornerRadius: b.len(10), style: .continuous).fill(Color.white.opacity(0.14)))
          .overlay(RoundedRectangle(cornerRadius: b.len(10), style: .continuous).strokeBorder(Color.white.opacity(0.18)))
          .offset(x: b.len(CGFloat(i) * 8))
      }
    }.position(b.p(50, 150))
  }
  private func play() async {
    let reduced = JourneyMotion.reduced(systemReduceMotion)
    if !focused {
      lit = false
      withAnimation(.smooth(duration: 0.35)) { curl = 0.15; warmth = 0 }
      flow = 0
      if reduced { done(); return }
      withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { flow = -9 }
      for k in 0..<2 {
        guard await pause(k == 0 ? JourneyMotion.settle + 0.2 : 0.8) else { return }
        pulse = 0; pulseAlpha = 1
        withAnimation(.easeOut(duration: 0.8)) { pulse = 0.42 }
        withAnimation(.easeIn(duration: 0.35).delay(0.5)) { pulseAlpha = 0 }
        guard await pause(0.75) else { return }
        JourneyHaptic.play(.soft, store.profile, intensity: 0.35)
        withAnimation(.easeInOut(duration: 0.3)) { curl = 0.26 }
        withAnimation(.easeInOut(duration: 0.45).delay(0.3)) { curl = 0.15 }
      }
      guard await pause(0.5) else { return }
      done()
    } else {
      var t = Transaction(); t.disablesAnimations = true
      withTransaction(t) { flow = 0 }
      if reduced { curl = 1; warmth = 1; lit = true; done(); return }
      lit = false
      for k in 0..<3 {
        guard await pause(k == 0 ? JourneyMotion.settle + 0.25 : 0.45) else { return }
        withTransaction(t) { pulse = 0 }
        pulseAlpha = 1
        withAnimation(.easeIn(duration: 0.5)) { pulse = 1.22 }
        guard await pause(0.42) else { return }
        JourneyHaptic.play(.medium, store.profile, intensity: 0.5 + 0.2 * CGFloat(k))
        withAnimation(.spring(duration: 0.45, bounce: 0.1)) { curl = 1; warmth = min(1, 0.4 + 0.3 * Double(k)) }
        if k < 2 { withAnimation(.easeInOut(duration: 0.45).delay(0.3)) { curl = 0.35 } }
      }
      guard await pause(0.3) else { return }
      withAnimation(.smooth(duration: 0.9)) { lit = true; warmth = 1 }
      JourneyHaptic.play(.success, store.profile)
      guard await pause(0.5) else { return }
      done()
    }
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
        }.stroke(Color.white.opacity(0.22), lineWidth: 1)
        Text(axisY).font(.caption2.weight(.medium)).foregroundStyle(JourneyColor.secondary).fixedSize()
          .rotationEffect(.degrees(-90)).position(x: 9, y: plot.midY)
        Text(axisX + " →").font(.caption2.weight(.medium)).foregroundStyle(JourneyColor.secondary)
          .frame(width: plot.width, alignment: .trailing).position(x: plot.midX, y: plot.maxY + 36)
        // Target
        Path { $0.move(to: pt(CGPoint(x: 0, y: 1))); $0.addLine(to: pt(CGPoint(x: 1, y: 1))) }
          .stroke(reached ? JourneyColor.accent : Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
        HStack(spacing: 6) {
          Text(pumpLabel).font(.caption2.weight(.bold)).tracking(0.6)
            .foregroundStyle(reached ? JourneyColor.accent : JourneyColor.secondary)
          if finished { Text(verdict).font(.caption2).foregroundStyle(reached ? JourneyColor.accent : JourneyColor.secondary) }
        }.frame(width: plot.width, alignment: .trailing).position(x: plot.midX, y: plot.minY - 12)
        // Data
        line(pt).stroke(timed ? Color.white.opacity(0.9) : Color.white.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        Circle().fill(reached ? JourneyColor.accent : timed ? Color.white : Color.white.opacity(0.6))
          .frame(width: reached ? 12 : 8, height: reached ? 12 : 8).position(pt(head))
        ForEach(PumpPlot.restEnds(points), id: \.self) { end in
          let mid = (points[end - 1].x + points[end].x) / 2
          HStack(spacing: 3) {
            if !timed { Image(systemName: "iphone").font(.system(size: 9, weight: .semibold)) }
            Text(restLabel).font(.caption2.weight(.medium)).monospacedDigit()
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
        .frame(height: 250)
      ArmView(curl: curl, warmth: warmth)
        .frame(maxWidth: 110, maxHeight: 110)
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
    for i in 1..<pts.count {
      let rising = pts[i].y > pts[i - 1].y + 0.001
      let holding = pts[i].y >= 0.999 && pts[i - 1].y >= 0.999
      let duration = rising ? 0.34 : holding ? 0.5 : (timed ? 0.45 : 0.85)
      withAnimation(.easeInOut(duration: duration)) { progress = Double(i) }
      if rising {
        withAnimation(.spring(duration: 0.4, bounce: 0.1)) { curl = 1; warmth = pts[i].y }
        JourneyHaptic.play(.medium, store.profile, intensity: 0.35 + 0.6 * pts[i].y)
      } else if !holding {
        withAnimation(.easeInOut(duration: duration)) { curl = 0.3; warmth = pts[i].y }
      }
      guard await pause(duration) else { return }
      if pts[i].y >= 0.999 && !reached {
        withAnimation(.spring(duration: 0.6, bounce: 0.15)) { reached = true }
        JourneyHaptic.land(store.profile)
      }
    }
    withAnimation(.smooth(duration: 0.5)) { finished = true }
    JourneyHaptic.play(timed ? .success : .soft, store.profile, intensity: 0.5)
    guard await pause(0.4) else { return }
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
  func path(in rect: CGRect) -> Path {
    let b = StageBox(size: rect.size, ref: logRef)
    var p = Path(); p.move(to: logPoint(0, b))
    for i in 1..<5 { p.addLine(to: logPoint(i, b)) }
    return p
  }
}

struct LogStage: View {
  let remembered: Bool
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var revealed = 0
  @State private var forgotten = 0
  @State private var line = 0.0
  @State private var best = false
  var body: some View {
    GeometryReader { g in
      let b = StageBox(size: g.size, ref: logRef)
      ZStack {
        Group {
          ForEach(0..<3, id: \.self) { k in
            Path { p in p.move(to: b.p(18, 46 + CGFloat(k) * 75)); p.addLine(to: b.p(302, 46 + CGFloat(k) * 75)) }
              .stroke(Color.white.opacity(0.05), lineWidth: 1)
          }
          Path { p in p.move(to: b.p(18, 30)); p.addLine(to: b.p(18, 222)); p.addLine(to: b.p(306, 222)) }
            .stroke(Color.white.opacity(0.22), lineWidth: 1)
          Text(store.t("Weight × reps")).font(.caption2.weight(.medium)).foregroundStyle(JourneyColor.secondary).fixedSize()
            .rotationEffect(.degrees(-90)).position(b.p(6, 126))
          Text(store.t("Week") + " →").font(.caption2.weight(.medium)).foregroundStyle(JourneyColor.secondary)
            .position(b.p(282, 266))
        }.opacity(remembered ? 1 : 0)
        LogLine().trim(from: 0, to: line).stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: b.len(2.2), lineCap: .round, lineJoin: .round))
        ForEach(0..<5, id: \.self) { i in
          let p = logPoint(i, b)
          let last = i == 4
          Circle().fill(last && best ? JourneyColor.accent : JourneyColor.stage)
            .overlay(Circle().strokeBorder(last && best ? JourneyColor.accent : Color.white.opacity(0.85), lineWidth: b.len(2)))
            .frame(width: b.len(last ? 12 : 9), height: b.len(last ? 12 : 9))
            .scaleEffect(remembered && line >= Double(i) / 4 - 0.01 ? 1 : 0.01)
            .position(p)
            .animation(.spring(duration: 0.45, bounce: 0.15), value: line)
          value(i, b)
          Text(store.t(["W1", "W2", "W3", "W4", "Today"][i])).font(.caption2).foregroundStyle(JourneyColor.secondary)
            .position(b.p(34 + CGFloat(i) * 63, 240))
        }
        Text("+5 kg").font(.system(.headline, weight: .semibold)).foregroundStyle(JourneyColor.accent)
          .position(b.p(286, 16)).opacity(best ? 1 : 0).offset(y: best ? 0 : 6)
          .accessibilityIdentifier("journey.newBest")
      }
    }
    .accessibilityElement().accessibilityIdentifier("journey.logging")
    .accessibilityLabel(store.t(remembered
      ? "Logged weeks form a rising line; today is 5 kilograms heavier than week 1."
      : "Remembered weights fade into question marks, week after week."))
    .task(id: remembered) { await play() }
  }
  private func value(_ i: Int, _ b: StageBox) -> some View {
    let lost = !remembered && i < forgotten
    let y: CGFloat = remembered ? logPoint(i, b).y - b.len(20) : b.p(0, 120).y
    return ZStack {
      Text(logValues[i]).foregroundStyle(JourneyColor.text).opacity(lost ? 0 : 1).blur(radius: lost ? 4 : 0)
      Text("?").foregroundStyle(JourneyColor.text.opacity(0.75)).opacity(lost ? 1 : 0).scaleEffect(lost ? 1 : 0.6)
    }.font(.system(remembered ? .subheadline : .title, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
      .opacity(remembered || i < revealed ? 1 : 0)
      .position(x: logPoint(i, b).x, y: y)
      .animation(.spring(duration: 0.6, bounce: 0.1).delay(remembered ? Double(i) * 0.06 : 0), value: remembered)
  }
  private func play() async {
    let reduced = JourneyMotion.reduced(systemReduceMotion)
    if !remembered {
      withAnimation(.smooth(duration: 0.3)) { line = 0; best = false }
      if reduced { revealed = 5; forgotten = 4; done(); return }
      revealed = 0; forgotten = 0
      for i in 0..<5 {
        guard await pause(i == 0 ? JourneyMotion.settle + 0.1 : 0.55) else { return }
        withAnimation(.smooth(duration: 0.45)) { revealed = i + 1 }
        JourneyHaptic.play(.light, store.profile, intensity: 0.5)
        if i > 0 {
          guard await pause(0.25) else { return }
          withAnimation(.smooth(duration: 0.6)) { forgotten = i }
          JourneyHaptic.play(.soft, store.profile, intensity: 0.25)
        }
      }
      guard await pause(0.5) else { return }
      done()
    } else {
      if reduced { line = 1; best = true; done(); return }
      guard await pause(JourneyMotion.settle + 0.15) else { return }
      withAnimation(.easeInOut(duration: 1.2)) { line = 1 }
      for k in 0..<4 {
        guard await pause(0.3) else { return }
        JourneyHaptic.play(.light, store.profile, intensity: 0.4 + 0.15 * CGFloat(k))
      }
      guard await pause(0.05) else { return }
      withAnimation(.spring(duration: 0.6, bounce: 0.15)) { best = true }
      JourneyHaptic.land(store.profile)
      guard await pause(0.45) else { return }
      done()
    }
  }
}

// MARK: - Choose apps to block

struct BlockedApp: Identifiable {
  let name: String
  let symbol: String
  var id: String { name }
  static let all: [BlockedApp] = [
    BlockedApp(name: "Instagram", symbol: "camera"), BlockedApp(name: "TikTok", symbol: "music.note"),
    BlockedApp(name: "YouTube", symbol: "play.rectangle"), BlockedApp(name: "X", symbol: "xmark"),
    BlockedApp(name: "Snapchat", symbol: "bubble.left"), BlockedApp(name: "Reddit", symbol: "bubble.left.and.bubble.right"),
  ]
}

struct BlockStage: View {
  @Binding var selected: Set<String>
  let locking: Bool
  @EnvironmentObject private var store: GymStore
  @State private var stamped = 0
  private var order: [String] { BlockedApp.all.map(\.name).filter(selected.contains) }
  var body: some View {
    VStack {
      Spacer(minLength: 0)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 26) {
        ForEach(BlockedApp.all) { app in tile(app) }
      }
      Spacer(minLength: 0)
    }
    .task(id: locking) {
      guard locking else { stamped = 0; return }
      for i in 0..<order.count {
        guard await pause(i == 0 ? 0.05 : 0.14) else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.25)) { stamped = i + 1 }
        JourneyHaptic.play(.rigid, store.profile)
      }
    }
  }
  private func tile(_ app: BlockedApp) -> some View {
    let on = selected.contains(app.name)
    let locked = (order.firstIndex(of: app.name).map { $0 < stamped }) ?? false
    return Button {
      guard !locking else { return }
      withAnimation(JourneyMotion.gentle) { if on { selected.remove(app.name) } else { selected.insert(app.name) } }
      JourneyHaptic.play(.selection, store.profile)
    } label: {
      VStack(spacing: 10) {
        Image(systemName: app.symbol).font(.system(.title2, weight: .medium))
          .foregroundStyle(on ? JourneyColor.text : JourneyColor.tertiary)
          .frame(width: 68, height: 68)
          .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), tint: on ? Color.white.opacity(0.16) : nil, interactive: true)
          .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.white.opacity(on ? 0.55 : 0), lineWidth: 1.5))
          .overlay(alignment: .topTrailing) {
            Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(JourneyColor.onAccent)
              .frame(width: 24, height: 24).background(Circle().fill(JourneyColor.accent))
              .offset(x: 8, y: -8).scaleEffect(locked ? 1 : 0.3).opacity(locked ? 1 : 0)
          }
        Text(app.name).font(.caption).foregroundStyle(on ? JourneyColor.text : JourneyColor.secondary)
      }.frame(maxWidth: .infinity).contentShape(Rectangle())
    }.buttonStyle(JourneyPressStyle())
      .accessibilityLabel(app.name).accessibilityAddTraits(on ? .isSelected : [])
      .accessibilityIdentifier("block." + app.name)
  }
}

// MARK: - Commitment

struct CommitStage: View {
  let lit: Int
  @EnvironmentObject private var store: GymStore
  static let pledges = ["My phone stays away between sets.", "I time every rest.", "I log every set."]
  var body: some View {
    VStack(alignment: .leading, spacing: 26) {
      ForEach(Array(Self.pledges.enumerated()), id: \.offset) { i, pledge in
        let on = i < lit
        HStack(spacing: 16) {
          ZStack {
            Circle().strokeBorder(Color.white.opacity(on ? 0 : 0.25), lineWidth: 1.5)
            Circle().fill(Color.white).scaleEffect(on ? 1 : 0.3).opacity(on ? 1 : 0)
            Image(systemName: "checkmark").font(.system(size: 12, weight: .heavy)).foregroundStyle(.black).opacity(on ? 1 : 0)
          }.frame(width: 28, height: 28)
          Text(store.t(pledge)).font(.title3.weight(.medium)).foregroundStyle(on ? JourneyColor.text : JourneyColor.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }.animation(.spring(duration: 0.3, bounce: 0.35), value: on)
          .accessibilityElement(children: .combine).accessibilityAddTraits(on ? .isSelected : [])
      }
    }.frame(maxWidth: 320, alignment: .leading).frame(maxWidth: .infinity, maxHeight: .infinity)
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
        Capsule().fill(Color.white)
        label(JourneyColor.onButton)
        Capsule().fill(JourneyColor.commitFill).frame(width: g.size.width * (committed ? 1 : fill))
        label(.white).mask(alignment: .leading) { Rectangle().frame(width: g.size.width * (committed ? 1 : fill)) }
      }
    }.frame(height: 56).clipShape(Capsule())
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
    ticker = Task { @MainActor in
      while !Task.isCancelled {
        let p = min(1, Date().timeIntervalSince(begin) / Self.duration)
        onProgress(p)
        if store.profile.hapticsEnabled ?? true {
          UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.25 + 0.75 * p)
        }
        if p >= 1 { finish(); return }
        try? await Task.sleep(for: .milliseconds(90))
      }
    }
  }
  private func release() {
    holding = false
    guard !committed else { return }
    ticker?.cancel()
    onProgress(0)
    withAnimation(.easeOut(duration: 0.3)) { fill = 0 }
  }
  private func finish() {
    ticker?.cancel()
    holding = false
    onProgress(1)
    JourneyHaptic.play(.success, store.profile)
    onComplete()
  }
}

// MARK: - Offer

struct OfferStage: View {
  @ObservedObject var subscription: GymSubscription
  @EnvironmentObject private var store: GymStore
  var body: some View {
    let apps = store.profile.blockedApps
    let blocking = store.profile.focusEnabled == true && !apps.isEmpty
    let list = apps.prefix(2).joined(separator: ", ") + (apps.count > 2 ? " +\(apps.count - 2)" : "")
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: 24) {
        row("lock", blocking ? store.t("Blocks") + " " + list : store.t("Blocks the apps you choose"))
        row("timer", store.t("Times every rest"))
        row("chart.line.uptrend.xyaxis", store.t("Shows your progress"))
      }.fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        .padding(22).journeyGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityIdentifier("journey.recap")
      if let product = subscription.product {
        VStack(spacing: 4) {
          Text(product.displayPrice + " " + store.t("per month")).font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text)
          Text(store.t("Renews monthly until cancelled.")).font(.caption).foregroundStyle(JourneyColor.secondary)
        }.padding(.top, 36)
      }
      Spacer(minLength: 0)
      HStack {
        legal("Terms of Use", key: "GymBlockTermsURL")
        Spacer()
        legal("Privacy Policy", key: "GymBlockPrivacyURL")
      }.font(.caption).foregroundStyle(JourneyColor.secondary)
    }
  }
  private func row(_ symbol: String, _ text: String) -> some View {
    HStack(spacing: 16) {
      Image(systemName: symbol).font(.system(.title3, weight: .regular)).foregroundStyle(JourneyColor.text)
        .frame(width: 30).accessibilityHidden(true)
      Text(text).font(.body).foregroundStyle(JourneyColor.text).fixedSize(horizontal: false, vertical: true)
    }
  }
  @ViewBuilder private func legal(_ title: String, key: String) -> some View {
    if let text = Bundle.main.object(forInfoDictionaryKey: key) as? String,
      let url = URL(string: text), url.scheme == "https" { Link(store.t(title), destination: url) }
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
        .font(.system(.largeTitle, weight: .semibold)).multilineTextAlignment(.center).foregroundStyle(JourneyColor.text)
        .textContentType(.givenName).textInputAutocapitalization(.words).autocorrectionDisabled()
        .submitLabel(.continue).focused($focused).onSubmit(submit).tint(JourneyColor.accent)
        .padding(.vertical, 18).padding(.horizontal, 20)
        .journeyGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .frame(height: 230).clipped()
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
        Circle().stroke(Color.white.opacity(0.08), lineWidth: 8)
        Circle().trim(from: 0, to: ring).stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: 2) {
          Text(store.t("Rest")).font(.footnote).foregroundStyle(JourneyColor.secondary)
          CountingText(value: seconds) { clockString(Int($0)) }
            .font(.system(.largeTitle, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        }
      }.frame(width: 170, height: 170)
      HStack(spacing: 12) {
        Image(systemName: "bell.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(JourneyColor.onAccent)
          .frame(width: 38, height: 38).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(JourneyColor.accent))
        VStack(alignment: .leading, spacing: 2) {
          HStack {
            Text("GymBlock").font(.subheadline.weight(.semibold)).foregroundStyle(JourneyColor.text)
            Spacer(minLength: 4)
            Text(store.t("now")).font(.caption).foregroundStyle(JourneyColor.secondary)
          }
          Text(store.t("Rest’s up. Time for your next set.")).font(.subheadline).foregroundStyle(JourneyColor.secondary).lineLimit(1)
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
