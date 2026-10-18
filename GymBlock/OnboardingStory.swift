import SwiftUI

// Onboarding V7 scenes (docs/ONBOARDING-V7-PLAN.md): the welcome, Sulav's note, the days
// question, the time-driven mind-muscle stage, the shield and Lock Screen previews, the plan,
// and the two pages after the offer (split templates, first workout).

// MARK: - Clock

/// Easing for scenes drawn from a clock.
enum Ease {
  static func clamp(_ x: Double, _ a: Double = 0, _ b: Double = 1) -> Double { min(b, max(a, x)) }
  static func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp((t - a) / (b - a)) }
  static func out(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
  static func inOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
  static func lerp(_ a: Double, _ b: Double, _ k: Double) -> Double { a + (b - a) * k }
  static func bump(_ t: Double, _ c: Double, _ w: Double) -> Double { t < c || t > c + w ? 0 : sin(.pi * (t - c) / w) }
  /// A damped spring from 0 to 1 (overshoots when `z` < 1).
  static func spring(_ t: Double, _ w: Double = 12, _ z: Double = 0.5) -> Double {
    guard t > 0 else { return 0 }
    let wd = w * sqrt(1 - z * z)
    return 1 - exp(-z * w * t) * (cos(wd * t) + z * w / wd * sin(wd * t))
  }
}

/// Runs a scene from its own clock at the display's refresh rate, with its haptic and sound score
/// starting on the same frame. Reduce Motion shows the last frame and skips the score.
struct SceneClock<Content: View>: View {
  let duration: Double
  var score: JourneyScore? = nil
  var done: () -> Void = {}
  @ViewBuilder let content: (Double) -> Content
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var start: Date?
  @State private var finished = false
  var body: some View {
    TimelineView(.animation(paused: start == nil || finished)) { context in
      content(finished ? duration : start.map { max(0, min(duration, context.date.timeIntervalSince($0))) } ?? 0)
    }
    .task { await run() }
  }
  private func run() async {
    if JourneyMotion.reduced(systemReduceMotion) { finished = true; done(); return }
    try? await Task.sleep(for: .seconds(JourneyMotion.settle))
    guard !Task.isCancelled else { return }
    // The picture starts on the moment the score lands (sound latency included), not before it.
    let begin = score.map { JourneyScorePlayer.shared.play($0, profile: store.profile) } ?? Date()
    start = begin
    try? await Task.sleep(for: .seconds(max(0, begin.timeIntervalSinceNow) + duration))
    guard !Task.isCancelled else { return }
    finished = true
    done()
  }
}

/// Lays a scene out at a fixed design size and scales it to the space it gets.
struct DesignFit<Content: View>: View {
  let size: CGSize
  @ViewBuilder let content: () -> Content
  var body: some View {
    GeometryReader { g in
      let s = min(1.15, min(g.size.width / size.width, g.size.height / size.height))
      content().frame(width: size.width, height: size.height).scaleEffect(s)
        .frame(width: g.size.width, height: g.size.height)
    }
  }
}

// MARK: - Welcome

/// What you do, what you get: apps pile onto a lock screen, the kettlebell falls and locks it, the
/// arm flexes and turns green. Everything moves from one clock (JourneyScores.welcome).
struct WelcomeScene: View {
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  static let duration = 3.85
  var body: some View {
    SceneClock(duration: Self.duration, score: JourneyScores.welcome, done: done) { t in
      DesignFit(size: CGSize(width: 388, height: 560)) { frame(t) }
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.phone")
    .accessibilityLabel(store.t("Stop scrolling, stay focused. Record everything, get jacked. Your apps lock while you train."))
  }
  private func frame(_ t: Double) -> some View {
    VStack(spacing: 0) {
      row(store.t("Stop\nscrolling"), store.t("Stay\nfocused"), t: t, left: 0.1, arrow: 2.35, right: 2.5, pop: false)
      Spacer(minLength: 0)
      HStack(spacing: 0) {
        LockPhone(t: t)
        Spacer(minLength: 0)
        arm(t)
      }.frame(height: 360)
      Spacer(minLength: 0)
      row(store.t("Record\neverything"), store.t("Get\njacked"), t: t, left: 0.3, arrow: 3.0, right: 3.2, pop: true)
    }
  }
  private func row(_ a: String, _ b: String, t: Double, left: Double, arrow: Double, right: Double, pop: Bool) -> some View {
    let l = Ease.out(Ease.seg(t, left, left + 0.4))
    let r = pop ? Ease.seg(t, right, right + 0.16) : Ease.out(Ease.seg(t, right, right + 0.4))
    let scale = pop ? (t < right ? 0.85 : 0.85 + 0.15 * Ease.spring(t - right, 14, 0.45)) : 1
    return HStack(spacing: 0) {
      Text(a).font(.app(size: 31, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
        .multilineTextAlignment(.leading).lineSpacing(-4).fixedSize()
        .opacity(l).offset(y: (1 - l) * 12)
      Spacer(minLength: 6)
      WelcomeArrow(line: Ease.out(Ease.seg(t, arrow, arrow + 0.28)), head: Ease.out(Ease.seg(t, arrow + 0.2, arrow + 0.38)))
        .frame(width: 58, height: 22)
      Spacer(minLength: 6)
      Text(b).font(.app(size: 31, weight: .bold)).foregroundStyle(JourneyColor.text)
        .multilineTextAlignment(.trailing).lineSpacing(-4).fixedSize()
        .opacity(r).offset(x: pop ? 0 : (1 - r) * -16).scaleEffect(scale, anchor: .trailing)
    }.tracking(-0.8)
  }
  private func arm(_ t: Double) -> some View {
    let flex = t < 2.55 ? 0 : Ease.spring(t - 2.55, 11, 0.42)
    // Settles exactly on the last pose, so the resting arm is one clean frame, not two blended.
    let curl = min(1, 0.12 + 0.88 * flex)
    let glow = t < 2.7 ? 0 : Ease.spring(t - 2.7, 8, 0.5)
    return ZStack {
      Circle().fill(RadialGradient(colors: [JourneyColor.accent.opacity(0.24), .clear], center: .center, startRadius: 0, endRadius: 125))
        .frame(width: 250, height: 250).scaleEffect(0.75 + 0.25 * glow).opacity(Ease.out(Ease.seg(t, 2.7, 3.2)))
      ArmView(curl: curl, warmth: Ease.inOut(Ease.seg(t, 2.55, 3.15))).frame(width: 206, height: 206)
    }.frame(width: 206)
  }
}

/// An ink arrow that draws itself: the shaft, then the head.
struct WelcomeArrow: View {
  let line: Double
  let head: Double
  var body: some View {
    ZStack {
      Path { p in p.move(to: CGPoint(x: 8, y: 11)); p.addLine(to: CGPoint(x: 50, y: 11)) }
        .trim(from: 0, to: line).stroke(JourneyColor.text, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
      Path { p in p.move(to: CGPoint(x: 42, y: 3.5)); p.addLine(to: CGPoint(x: 50.5, y: 11)); p.addLine(to: CGPoint(x: 42, y: 18.5)) }
        .trim(from: 0, to: head).stroke(JourneyColor.text, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
    }.frame(width: 58, height: 22)
  }
}

/// A lock screen that fills with notifications until the kettlebell lands on it.
struct LockPhone: View {
  let t: Double
  @EnvironmentObject private var store: GymStore
  static let arrivals = [0.35, 0.75, 1.1, 1.4]
  static let fall = 1.75, land = 2.13
  static let pings: [(app: String, symbol: String, text: String, color: Color)] = [
    ("Instagram", "camera", "maya.lifts liked your photo", Color(red: 0.9, green: 0.42, blue: 0.54)),
    ("TikTok", "music.note", "Videos you might like", Color(red: 0.11, green: 0.11, blue: 0.12)),
    ("YouTube", "play.fill", "New: 10 min ab burner", Color(red: 0.9, green: 0.28, blue: 0.23)),
    ("Messages", "message.fill", "You coming to the gym?", Color(red: 0.2, green: 0.78, blue: 0.35)),
  ]
  var body: some View {
    let land = Self.land
    var rot = 0.0, dy = 0.0
    for a in Self.arrivals where t > a { rot += 1.4 * exp(-(t - a) * 13) * sin((t - a) * 62) }
    if t > land { let q = t - land; dy = 5 * exp(-q * 9) * cos(q * 30); rot += 0.8 * exp(-q * 9) * sin(q * 34) }
    return ZStack(alignment: .top) {
      RoundedRectangle(cornerRadius: 34, style: .continuous).fill(Color(red: 0.09, green: 0.09, blue: 0.1))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 14)
      ZStack(alignment: .top) {
        LinearGradient(colors: [Color(red: 0.85, green: 0.81, blue: 0.77), Color(red: 0.73, green: 0.69, blue: 0.65), Color(red: 0.56, green: 0.55, blue: 0.56)],
                       startPoint: .topLeading, endPoint: .bottom)
        VStack(spacing: 0) {
          Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.85)).padding(.top, 26)
          Text("9:41").font(.system(size: 46, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.95))
        }
        ForEach(0..<4, id: \.self) { i in card(i) }
        Rectangle().fill(Color(red: 0.953, green: 0.94, blue: 0.92)).opacity(0.93 * Ease.out(Ease.seg(t, land, land + 0.4)))
        Text(store.t("Locked until you finish")).font(.system(size: 9.5, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
          .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 18)
          .opacity(Ease.out(Ease.seg(t, land + 0.35, land + 0.7)))
      }.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous)).padding(6)
      Capsule().fill(Color(red: 0.04, green: 0.04, blue: 0.05)).frame(width: 46, height: 13).padding(.top, 13)
      kettlebell
    }
    .frame(width: 168, height: 344)
    .rotationEffect(.degrees(rot), anchor: UnitPoint(x: 0.5, y: 0.9)).offset(y: dy)
  }
  private func card(_ i: Int) -> some View {
    let a = Self.arrivals[i], land = Self.land
    let k = t < a ? 0 : Ease.spring(t - a, 15, 0.62)
    var y = (1 - k) * -22
    for (j, b) in Self.arrivals.enumerated() where j > i && t > b { y += 48 * Ease.spring(t - b, 15, 0.72) }
    let gone = Ease.inOut(Ease.seg(t, land + 0.03 * Double(3 - i), land + 0.4 + 0.03 * Double(3 - i)))
    y += gone * 70
    let ping = Self.pings[i]
    return HStack(spacing: 6) {
      Image(systemName: ping.symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
        .frame(width: 22, height: 22).background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(ping.color))
      VStack(alignment: .leading, spacing: 1) {
        HStack {
          Text(ping.app).font(.system(size: 8.6, weight: .semibold))
          Spacer(minLength: 2)
          Text(store.t("now")).font(.system(size: 8)).foregroundStyle(Color(white: 0.45))
        }
        Text(store.t(ping.text)).font(.system(size: 8.4)).foregroundStyle(Color(white: 0.25)).lineLimit(1)
      }
    }
    .foregroundStyle(Color(white: 0.1))
    .padding(.horizontal, 7).frame(height: 42)
    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.86)))
    .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
    .padding(.horizontal, 13)
    .scaleEffect(0.9 + 0.1 * min(1, k))
    .offset(y: 102 + y)
    .opacity(t < a ? 0 : Ease.clamp(k * 1.6) * (1 - gone))
  }
  private var kettlebell: some View {
    let fall = Self.fall, land = Self.land
    var y = -320.0, sx = 1.0, sy = 1.0
    if t >= fall && t < land { let x = Ease.seg(t, fall, land); y = -320 * (1 - x * x); sx = 0.96; sy = 1.05 }
    if t >= land { let q = t - land, sq = exp(-q * 10) * cos(q * 26); y = 0; sx = 1 + 0.12 * sq; sy = 1 - 0.16 * sq }
    return BrandMark(size: 84)
      .shadow(color: .black.opacity(0.3), radius: 6, y: 5)
      .shadow(color: JourneyColor.accent.opacity(t > land + 0.15 ? 0.5 : 0), radius: 10)
      .scaleEffect(x: sx, y: sy, anchor: .bottom)
      .offset(y: 120 + y).opacity(t < fall ? 0 : 1)
  }
}

// MARK: - Founder's note

/// Sulav's note: the voice for everything after it. Set on the paper like a letter, no card, no
/// animation, no sound. Short enough to read in ten seconds.
struct FounderStage: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    // The larger setting where it fits, the body size on small screens, scrolling only as a last
    // resort (the largest accessibility sizes).
    ViewThatFits(in: .vertical) {
      letter(.title3, spacing: 16)
      letter(.body, spacing: 12)
      letter(.callout, spacing: 9, signature: 26)
      // Small screens: the callout setting, scaled down just enough to fit. Accessibility sizes scroll
      // instead, so their text stays large.
      if typeSize.isAccessibilitySize {
        ScrollView { letter(.body, spacing: 12) }.scrollIndicators(.hidden)
      } else {
        ScaleToFit { letter(.callout, spacing: 9, signature: 26) }
      }
    }
    .accessibilityElement(children: .combine).accessibilityIdentifier("founder.note")
  }
  private func letter(_ style: Font.TextStyle, spacing: CGFloat, signature: CGFloat = 32) -> some View {
    VStack(alignment: .leading, spacing: spacing) {
      Text(store.t("Hey friend,"))
      Text(store.t("In the gym, we grow by being honest and consistent. That goes for the sets, and for the minutes between them."))
      Text(store.t("Mine kept slipping into my phone. One quick scroll became ten, and by the time I picked the weight back up, my focus and my pump were gone."))
      Text(store.t("GymBlock is how I took those minutes back. It locks the apps that pull you away while you train, and keeps an honest record of every set, so you always know what you did last time and what to beat today."))
      Text(store.t("Little things, done right, every session."))
      VStack(alignment: .leading, spacing: 2) {
        Rectangle().fill(JourneyColor.hairline).frame(width: 48, height: 1).padding(.bottom, 8)
        Text("Sulav").font(.custom("SnellRoundhand-Bold", size: signature, relativeTo: .title)).foregroundStyle(JourneyColor.text)
        Text(store.t("Founder, GymBlock")).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
      }.padding(.top, 2)
    }
    .font(.app(style)).foregroundStyle(JourneyColor.text.opacity(0.86)).lineSpacing(3)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

// MARK: - Days a week

/// One tap: how many days a week they lift. It sets Home's weekly goal and the yearly estimate.
struct TrainingDaysStage: View {
  @Binding var days: Int?
  let choose: (Int) -> Void
  @EnvironmentObject private var store: GymStore
  var body: some View {
    VStack(spacing: 26) {
      Spacer(minLength: 0)
      HStack(spacing: 10) {
        ForEach([2, 3, 4, 5, 6], id: \.self) { n in
          let on = days == n
          Button { choose(n) } label: {
            Text(n == 6 ? "6+" : "\(n)").font(.app(.title2, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
              .frame(width: 60, height: 60)
              .background(Circle().fill(on ? Color.white : .clear))
              .journeyGlass(Circle(), interactive: true)
              .overlay(Circle().strokeBorder(JourneyColor.text, lineWidth: on ? 1.6 : 0))
              .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).symbolRenderingMode(.palette)
                  .foregroundStyle(JourneyColor.onAccent, JourneyColor.signal).background(Circle().fill(JourneyColor.stage).padding(2))
                  .offset(x: 3, y: -3).scaleEffect(on ? 1 : 0.4).opacity(on ? 1 : 0)
              }
          }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("days.\(n)").accessibilityAddTraits(on ? .isSelected : [])
            .accessibilityLabel(String(format: store.t("%@ days a week"), n == 6 ? "6+" : "\(n)"))
        }
      }
      Spacer(minLength: 0)
    }
  }
}

// MARK: - Mind-muscle connection, from a clock

private let mindStageRef = CGSize(width: 300, height: 360)

/// Where everything is at one moment of the mind-muscle scene.
struct MindState {
  var focus = 1.0, mood = 1.0, warmth = 1.0, curl = 1.0, lit = 0.0, glow = 0.0, attention = 0.0, flow = 0.0
  var pulses: [(head: Double, alpha: Double)] = []
  var pings: [(x: Double, alpha: Double, scale: Double)] = []

  /// Scrolling weakens it: four signals, each shorter and duller; the brain's face drops, the arm drains to grey.
  static func fading(_ t: Double) -> MindState {
    let focus = 1 - Ease.inOut(Ease.seg(t, 0.3, 3.0))
    let starts = [0.25, 1.05, 1.85, 2.65], reach = [1, 0.72, 0.48, 0.28], alpha = [1, 0.8, 0.6, 0.42]
    var s = MindState()
    s.focus = focus; s.mood = Ease.lerp(-0.8, 0.6, focus); s.warmth = 0.55 * focus
    s.curl = 0.15 + 0.45 * Ease.bump(t, starts[0] + 0.62, 0.5) + 0.16 * Ease.bump(t, starts[1] + 0.66, 0.45) + 0.05 * Ease.bump(t, starts[2] + 0.7, 0.4)
    s.glow = 0.5 * focus * (1 - Ease.seg(t, 0, 1.2))
    s.pulses = starts.indices.map { i in (reach[i] * Ease.out(Ease.seg(t, starts[i], starts[i] + 0.8)), alpha[i] * (1 - Ease.seg(t, starts[i] + 0.62, starts[i] + 0.95))) }
    s.attention = Ease.seg(t, 0.5, 0.9); s.flow = -t * 11
    s.pings = [0.4, 1.2].map { p in (Ease.lerp(-70, 0, Ease.spring(t - p, 14, 0.6)), Ease.seg(t, p, p + 0.18), t < p ? 0.8 : 0.8 + 0.2 * Ease.spring(t - p, 16, 0.5)) }
    return s
  }
  /// Put it away: three identical signals; the arm flexes on each and warms to green.
  static func steady(_ t: Double) -> MindState {
    let starts = [0.35, 1.2, 2.05], arrive = starts.map { $0 + 0.63 }
    var s = MindState()
    var curl = 0.15
    for (k, a) in arrive.enumerated() {
      if t >= a { curl = Ease.lerp(curl, 1, Ease.spring(t - a, 16, 0.55)) }
      if k < 2 && t >= a + 0.3 { curl = Ease.lerp(curl, 0.35, Ease.inOut(Ease.seg(t, a + 0.3, a + 0.75))) }
    }
    s.curl = curl
    s.warmth = zip([0.4, 0.3, 0.3], arrive).reduce(0) { $0 + $1.0 * Ease.out(Ease.seg(t, $1.1, $1.1 + 0.35)) }
    s.lit = Ease.inOut(Ease.seg(t, 2.8, 3.5)); s.glow = s.lit
    s.focus = 1; s.mood = Ease.lerp(-0.8, 1, Ease.inOut(Ease.seg(t, 0.3, 1.5)))
    s.pulses = starts.map { (1.22 * pow(Ease.seg(t, $0, $0 + 0.7), 2), 1 - Ease.seg(t, $0 + 0.65, $0 + 0.8)) }
    s.attention = 1 - Ease.seg(t, 0, 0.3); s.flow = -t * 11
    s.pings = [0, 1].map { i in (Ease.lerp(0, -80, Ease.inOut(Ease.seg(t, 0.02 * Double(i), 0.5 + 0.02 * Double(i)))), 1 - Ease.seg(t, 0.05, 0.45), 1) }
    return s
  }
}

/// The approved brain, nerve and arm, drawn from a `MindState`.
struct MindFrame: View {
  let state: MindState
  var body: some View {
    GeometryReader { g in
      let b = StageBox(size: g.size, ref: mindStageRef)
      let s = state
      ZStack {
        Circle().fill(RadialGradient(colors: [JourneyColor.accent.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: b.len(120)))
          .frame(width: b.len(240), height: b.len(240)).position(b.p(150, 80)).opacity(s.glow)
        NervePath().stroke(JourneyColor.ink(0.12), style: StrokeStyle(lineWidth: b.len(2), lineCap: .round))
        NervePath().stroke(JourneyColor.accent.opacity(0.75), style: StrokeStyle(lineWidth: b.len(2), lineCap: .round)).opacity(s.lit)
        ForEach(s.pulses.indices, id: \.self) { i in
          let p = s.pulses[i]
          ZStack {
            NervePulse(head: p.head).stroke(JourneyColor.accent.opacity(0.3 * s.focus), style: StrokeStyle(lineWidth: b.len(9), lineCap: .round))
            NervePulse(head: p.head).stroke(JourneyColor.ink(0.1 * (1 - s.focus)), style: StrokeStyle(lineWidth: b.len(9), lineCap: .round))
            NervePulse(head: p.head).stroke(JourneyColor.ink(0.45), style: StrokeStyle(lineWidth: b.len(3), lineCap: .round))
            NervePulse(head: p.head).stroke(JourneyColor.accent, style: StrokeStyle(lineWidth: b.len(3), lineCap: .round)).opacity(s.focus)
          }.opacity(p.alpha)
        }
        AttentionPath().stroke(JourneyColor.ink(0.35), style: StrokeStyle(lineWidth: b.len(1.6), lineCap: .round, dash: [2, 7], dashPhase: s.flow))
          .opacity(s.attention)
        ForEach(s.pings.indices, id: \.self) { i in ping(i, b).opacity(s.pings[i].alpha) }
        brain(b)
        ArmView(curl: s.curl, warmth: s.warmth).frame(width: b.len(168), height: b.len(168)).position(b.p(150, 276))
      }
    }
  }
  private func brain(_ b: StageBox) -> some View {
    let k = Ease.clamp((state.mood + 0.8) / 1.8)
    let tone = JourneyColor.text.opacity(0.55 + 0.45 * k)
    return ZStack {
      BrainOutline().fill(JourneyColor.stage)
      BrainFolds().stroke(tone.opacity(0.45), style: StrokeStyle(lineWidth: b.len(1.4), lineCap: .round))
      BrainOutline().stroke(tone, style: StrokeStyle(lineWidth: b.len(1.8), lineCap: .round))
      BrainEyes(mood: state.mood).fill(tone)
      BrainMouth(mood: state.mood).stroke(tone, style: StrokeStyle(lineWidth: b.len(2.6), lineCap: .round))
    }.frame(width: b.len(132), height: b.len(121)).position(b.p(150, 78))
  }
  private func ping(_ i: Int, _ b: StageBox) -> some View {
    let p = state.pings[i]
    return HStack(spacing: b.len(5)) {
      Image(systemName: ["camera", "music.note"][i]).font(.system(size: b.len(11), weight: .bold)).foregroundStyle(JourneyColor.text)
        .frame(width: b.len(22), height: b.len(22))
        .background(RoundedRectangle(cornerRadius: b.len(6), style: .continuous).fill(JourneyColor.ink(0.22)))
      VStack(alignment: .leading, spacing: b.len(4)) {
        Capsule().fill(JourneyColor.ink(0.75)).frame(width: b.len(30), height: b.len(4))
        Capsule().fill(JourneyColor.ink(0.4)).frame(width: b.len(44), height: b.len(4))
      }
    }.padding(b.len(7))
      .background(RoundedRectangle(cornerRadius: b.len(10), style: .continuous).fill(JourneyColor.ink(0.14)))
      .overlay(RoundedRectangle(cornerRadius: b.len(10), style: .continuous).strokeBorder(JourneyColor.ink(0.18)))
      .scaleEffect(p.scale)
      .position(b.p(50 + CGFloat(i) * 8 + CGFloat(p.x), 129 + CGFloat(i) * 42))
  }
}

// MARK: - The shield, as people will meet it

/// The real lock screen's words (GymBlockShield), for an example app; it slides up and locks.
struct OnboardingShield: View {
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  var body: some View {
    // Its clock runs to the kettlebell's rebound (1.42 s), then the page's button appears.
    SceneClock(duration: 1.45, score: JourneyScores.shield, done: done) { t in
      let rise = Ease.out(Ease.seg(t, 0.3, 0.9))
      let click = t < 0.98 ? 1 : 1 - 0.14 * Ease.bump(t, 0.98, 0.18) + 0.08 * Ease.bump(t, 1.12, 0.2)
      VStack(spacing: 10) {
        BrandMark(size: 46).scaleEffect(click)
        Text(store.t("You’re mid-workout.")).font(.app(.title3, weight: .bold)).foregroundStyle(JourneyColor.text).padding(.top, 4)
        Text(String(format: store.t("%@ opens when you finish your workout in GymBlock."), "Instagram"))
          .font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
        Text(store.t("Back to training")).font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.onButton)
          .frame(maxWidth: .infinity, minHeight: 40).background(Capsule().fill(JourneyColor.button)).padding(.top, 6)
      }
      .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 16)
      .frame(maxWidth: 300)
      .journeySurface()
      .opacity(rise).offset(y: (1 - rise) * 60)
    }
    .accessibilityElement(children: .combine).accessibilityIdentifier("blocking.shieldPreview")
  }
}

// MARK: - Rest alerts on the Lock Screen

/// The Live Activity counts the last seconds of a rest, then the buzz and the notification land.
struct LockScreenRest: View {
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  var body: some View {
    SceneClock(duration: 2.75, score: JourneyScores.restUp, done: done) { t in
      // One digit every 0.4 s from 0:05; 0:00 is the buzz (JourneyScores.restUp ticks on each change).
      let remaining = max(0, 5 - Int((t / JourneyScores.countdownStep).rounded(.down)))
      let over = remaining == 0
      VStack(spacing: 16) {
        Spacer(minLength: 0)
        Text(store.t("On your Lock Screen")).font(JourneyType.eyebrow).foregroundStyle(JourneyColor.secondary)
        VStack(spacing: 12) {
          HStack(alignment: .firstTextBaseline) {
            Text(store.t(over ? "Rest’s up · Push" : "Rest · Push")).font(.app(.subheadline)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text("0:0\(remaining)").font(.system(size: 30, weight: .medium, design: .monospaced)).foregroundStyle(.white)
          }
          GeometryReader { g in
            Capsule().fill(.white.opacity(0.14))
            Capsule().fill(Color(red: 0.18, green: 0.75, blue: 0.52)).frame(width: g.size.width * (0.62 + 0.38 * Ease.seg(t, 0, JourneyScores.countdownStep * 5)))
          }.frame(height: 6)
          HStack {
            Text(store.t("Next: Bench press · set 3 of 3")).font(.app(.subheadline)).foregroundStyle(.white).lineLimit(1)
            Spacer(minLength: 6)
            Text(store.t("Start set")).font(.app(.footnote, weight: .semibold)).foregroundStyle(.white)
              .padding(.horizontal, 12).padding(.vertical, 5).background(Capsule().fill(.white.opacity(0.14)))
          }
        }
        .padding(.horizontal, 18).padding(.vertical, 16).frame(maxWidth: 360)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(red: 0.106, green: 0.11, blue: 0.12)))
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
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
          .offset(y: t < 2.05 ? -24 : -24 + 24 * Ease.spring(t - 2.05, 14, 0.7))
          .opacity(Ease.seg(t, 2.05, 2.25))
        Spacer(minLength: 0)
      }
    }
    .accessibilityElement(children: .combine).accessibilityIdentifier("alerts.preview")
  }
}

// MARK: - The plan

/// Their answers as a plan: three lines on the paper, kg or lb beneath, and the hold to commit.
struct PlanStage: View {
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  var body: some View {
    // The last line finishes settling at 1.05 s; the hold appears after it.
    SceneClock(duration: 1.1, done: done) { t in
      VStack(spacing: 18) {
        Spacer(minLength: 0)
        VStack(spacing: 0) {
          ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
            let k = Ease.out(Ease.seg(t, 0.15 + Double(i) * 0.2, 0.65 + Double(i) * 0.2))
            VStack(alignment: .leading, spacing: 3) {
              Text(row.0).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
              Text(row.1).font(.app(.title2, weight: .semibold)).foregroundStyle(JourneyColor.text).tracking(-0.3)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 15)
              .overlay(alignment: .top) { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
              .opacity(k).offset(y: (1 - k) * 12)
          }
          Rectangle().fill(JourneyColor.hairline).frame(height: 1)
        }
        Spacer(minLength: 0)
      }
    }.accessibilityIdentifier("journey.plan")
  }
  private var rows: [(String, String)] {
    let days = store.profile.baseline?.trainingDays ?? 4
    let rest = clockString(store.profile.restSeconds ?? 90)
    let locked = blocking.ready && store.profile.focusEnabled == true
    return [
      (store.t("Training"), String(format: store.t("%@ days a week"), "\(days)")),
      (store.t("While you train"), locked ? String(format: store.t("%@ locked"), blocking.summary(store.t)) : store.t("Rest timer and log")),
      (store.t("Between sets"), String(format: store.t(store.profile.restAlerts == true ? "%@ rests, then a buzz" : "%@ rests"), rest)),
    ]
  }
}

// MARK: - After the offer: splits in one tap

/// The splits most people already run, each with six common exercises (editable afterwards).
enum SplitTemplate: String, CaseIterable, Identifiable {
  case keep, pushPullLegs, upperLower, fullBody, bodyPart, none
  var id: String { rawValue }
  var title: String {
    switch self {
    case .keep: return "Keep my splits"
    case .pushPullLegs: return "Push · Pull · Legs"
    case .upperLower: return "Upper · Lower"
    case .fullBody: return "Full body"
    case .bodyPart: return "One muscle a day"
    case .none: return "No fixed plan"
    }
  }
  var splits: [(String, [String])] {
    switch self {
    case .keep, .none: return []
    case .pushPullLegs: return [("Push", ["bench", "incline-bench", "dumbbell-press", "lateral", "pushdown", "dip"]),
                                ("Pull", ["pull-up", "barbell-row", "pulldown", "cable-row", "curl", "hammer"]),
                                ("Legs", ["squat", "rdl", "leg-press", "leg-curl", "leg-extension", "calf-raise"])]
    case .upperLower: return [("Upper", ["bench", "barbell-row", "press", "pulldown", "curl", "pushdown"]),
                              ("Lower", ["squat", "rdl", "leg-press", "leg-curl", "calf-raise", "leg-raise"])]
    case .fullBody: return [("Full body", ["squat", "bench", "barbell-row", "press", "rdl", "plank"])]
    case .bodyPart: return [("Chest", ["bench", "incline-bench", "dumbbell-bench", "fly", "dip"]),
                            ("Back", ["pull-up", "barbell-row", "pulldown", "cable-row", "row"]),
                            ("Legs", ["squat", "leg-press", "rdl", "leg-curl", "leg-extension", "calf-raise"]),
                            ("Shoulders", ["press", "dumbbell-press", "lateral"]),
                            ("Arms", ["barbell-curl", "curl", "hammer", "triceps", "pushdown"])]
    }
  }
  static func exercises(_ ids: [String]) -> [Exercise] { ids.compactMap { id in Exercise.catalog.first { $0.id == id } } }
}

struct SplitTemplateStage: View {
  @Binding var choice: SplitTemplate?
  @EnvironmentObject private var store: GymStore
  private var options: [SplitTemplate] {
    (store.data.workouts.isEmpty ? [] : [.keep]) + [.pushPullLegs, .upperLower, .fullBody, .bodyPart, .none]
  }
  var body: some View {
    VStack(spacing: 14) {
      Spacer(minLength: 0)
      preview.animation(JourneyMotion.gentle, value: choice)
      JourneyGlassGroup(spacing: 10) {
        VStack(spacing: 10) {
          ForEach(options) { option in
            JourneyOption(title: option == .keep ? String(format: store.t("Keep my %@ splits"), "\(store.data.workouts.count)") : store.t(option.title),
                          selected: choice == option, id: "splits.template." + option.rawValue) {
              withAnimation(JourneyMotion.gentle) { choice = option }
              JourneyHaptic.play(.selection, store.profile)
            }
          }
        }
      }
    }
  }
  @ViewBuilder private var preview: some View {
    let rows: [(String, String, Int)] = {
      switch choice {
      case .keep?: return store.data.workouts.prefix(3).map { ($0.name, $0.exercises.map { store.t($0.name) }.joined(separator: ", "), $0.exercises.count) }
      case let template?: return template.splits.prefix(3).map { (store.t($0.0), SplitTemplate.exercises($0.1).map { store.t($0.name) }.joined(separator: ", "), $0.1.count) }
      default: return []
      }
    }()
    if !rows.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        Text(store.t(choice == .keep ? "Your splits" : "We’ll set up")).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).padding(.bottom, 6)
        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
          HStack(spacing: 10) {
            Text(row.0).font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.text).frame(width: 74, alignment: .leading).lineLimit(1)
            Text(row.1).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).lineLimit(1)
            Spacer(minLength: 4)
            Text("\(row.2)").font(.app(.footnote)).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
          }.padding(.vertical, 6)
        }
      }.padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
        .journeySurface().transition(.opacity)
    } else if choice == SplitTemplate.none {
      Text(store.t("Every workout starts free: pick exercises as you go. You can save one as a split later."))
        .font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
        .padding(.horizontal, 12).transition(.opacity)
    }
  }
}

/// The last page: one tap from the first locked set.
struct FirstWorkoutStage: View {
  @EnvironmentObject private var store: GymStore
  @State private var editing: Workout?
  private var split: Workout? { store.data.workouts.first { $0.id == store.profile.preferredSplitID } ?? store.data.workouts.first }
  var body: some View {
    VStack(spacing: 12) {
      Spacer(minLength: 0)
      if let split {
        VStack(spacing: 0) {
          HStack {
            Text(split.name + " · " + String(format: store.t("%@ exercises"), "\(split.exercises.count)"))
              .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
            Spacer()
            Button(store.t("Edit")) { editing = split }.font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.text)
              .accessibilityIdentifier("first.edit")
          }.padding(.horizontal, 16).padding(.vertical, 12)
          ForEach(split.exercises.prefix(7)) { e in
            HStack {
              Text(store.t(e.name)).font(.app(.body)).foregroundStyle(JourneyColor.text).lineLimit(1)
              Spacer()
              Text(e.timed ? store.t("Timed") : String(format: store.t("%@ sets"), "3")).font(.app(.footnote)).monospacedDigit().foregroundStyle(JourneyColor.secondary)
            }.padding(.horizontal, 16).padding(.vertical, 11)
              .overlay(alignment: .top) { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
          }
        }.journeySurface().accessibilityIdentifier("first.split")
        if store.data.workouts.count > 1 {
          Text(String(format: store.t("Then %@. Home always shows what’s next."), store.data.workouts.dropFirst().prefix(2).map(\.name).joined(separator: ", ")))
            .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
        }
      } else {
        VStack(spacing: 10) {
          Image(systemName: "figure.strengthtraining.traditional").font(.largeTitle).foregroundStyle(JourneyColor.secondary).accessibilityHidden(true)
          Text(store.t("Pick each exercise as you go. Every set is saved.")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary)
            .multilineTextAlignment(.center)
        }.padding(24).frame(maxWidth: .infinity).journeySurface()
      }
      Spacer(minLength: 0)
    }
    .sheet(item: $editing) { split in
      NavigationStack { SplitEditorContent(workout: split) { _ in editing = nil } }.presentationDetents([.large]).tint(JourneyColor.text)
    }
  }
}
