import SwiftUI

// Onboarding V7 scenes (docs/ONBOARDING-V7-PLAN.md): the welcome, the days
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
/// starting on the same frame. Each frame is drawn `JourneyScores.displayLead` ahead, the time the
/// screen takes to show it. Reduce Motion shows the last frame and skips the score.
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
      content(finished ? duration : start.map { max(0, min(duration, context.date.timeIntervalSince($0) + JourneyScores.displayLead)) } ?? 0)
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
  var maxScale: CGFloat = 1.15
  @ViewBuilder let content: () -> Content
  var body: some View {
    GeometryReader { g in
      let s = min(maxScale, min(g.size.width / size.width, g.size.height / size.height))
      content().frame(width: size.width, height: size.height).scaleEffect(s)
        .frame(width: g.size.width, height: g.size.height)
    }
  }
}

// MARK: - Welcome

/// One message under the old story (20 Oct 2026, at the user's request): notifications pile onto a lock
/// screen, the kettlebell falls and locks it, the arm flexes and turns green, then "Focused workouts."
/// The words that used to frame it ("Stop scrolling → Stay focused", "Record everything → Get
/// jacked") are gone. Everything moves from one clock (JourneyScores.welcome).
struct WelcomeScene: View {
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  /// One thing moves at a time: the phone fills and locks, the arm flexes (its spring peaks 0.315 s
  /// after it starts), then the words.
  static let flex = LockPhone.land + 0.42, peak = flex + 0.315
  static let words = peak + 0.1
  static let duration = words + 0.6
  var body: some View {
    SceneClock(duration: Self.duration, score: JourneyScores.welcome, done: done) { t in
      let words = Ease.out(Ease.seg(t, Self.words, Self.words + 0.45))
      VStack(spacing: JourneyLayout.compact ? 18 : 28) {
        Spacer(minLength: 0)
        // Small screens keep air around it rather than filling edge to edge.
        DesignFit(size: CGSize(width: 388, height: 360), maxScale: JourneyLayout.compact ? 0.74 : 1.1) {
          HStack(spacing: 0) {
            LockPhone(t: t)
            Spacer(minLength: 0)
            arm(t)
          }
        }.frame(maxHeight: 400)
        Text(store.t("Focused workouts.")).font(.app(size: JourneyLayout.compact ? 34 : 40, weight: .bold)).tracking(-1)
          .foregroundStyle(JourneyColor.text).multilineTextAlignment(.center).lineLimit(1).minimumScaleFactor(0.7)
          .opacity(words).offset(y: (1 - words) * 10)
        Spacer(minLength: 0)
      }.frame(maxWidth: .infinity)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.phone")
    .accessibilityLabel(store.t("Focused workouts. Your apps lock while you train."))
  }
  private func arm(_ t: Double) -> some View {
    let flex = t < Self.flex ? 0 : Ease.spring(t - Self.flex, 11, 0.42)
    // Settles exactly on the last pose, so the resting arm is one clean frame, not two blended.
    let curl = min(1, 0.12 + 0.88 * flex)
    let glow = t < Self.flex + 0.15 ? 0 : Ease.spring(t - Self.flex - 0.15, 8, 0.5)
    return ZStack {
      Circle().fill(RadialGradient(colors: [JourneyColor.accent.opacity(0.24), .clear], center: .center, startRadius: 0, endRadius: 125))
        .frame(width: 250, height: 250).scaleEffect(0.75 + 0.25 * glow).opacity(Ease.out(Ease.seg(t, Self.flex + 0.15, Self.flex + 0.65)))
      ArmView(curl: curl, warmth: Ease.inOut(Ease.seg(t, Self.flex, Self.flex + 0.6))).frame(width: 206, height: 206)
    }.frame(width: 206)
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
      letter(.app(.title3), spacing: 16)
      // Between title 3 and body: on the largest phones the body size left an empty band under the note.
      letter(.app(size: 18.5, relativeTo: .body), spacing: 14)
      letter(.app(.body), spacing: 12)
      letter(.app(.callout), spacing: 9, signature: 26)
      // Small screens: the callout setting, scaled down just enough to fit. Accessibility sizes scroll
      // instead, so their text stays large.
      if typeSize.isAccessibilitySize {
        ScrollView { letter(.app(.body), spacing: 12) }.scrollIndicators(.hidden)
      } else {
        ScaleToFit { letter(.app(.callout), spacing: 9, signature: 26) }
      }
    }
    .accessibilityElement(children: .combine).accessibilityIdentifier("founder.note")
  }
  private func letter(_ font: Font, spacing: CGFloat, signature: CGFloat = 32) -> some View {
    VStack(alignment: .leading, spacing: spacing) {
      Text(store.t("Hey friend,"))
      Text(store.t("In the gym, we grow by being honest and consistent. That goes for the sets, and for the minutes between them."))
      Text(store.t("Mine kept slipping into my phone. One quick scroll became ten, and by the time I picked the weight back up, my focus and my pump were gone."))
      Text(store.t("GymBlock is how I took those minutes back. It locks the apps that pull you away while you train, and keeps an honest record of every set, so you always know what you did last time and what to beat today."))
      Text(store.t("Little things, done right, every session."))
      VStack(alignment: .leading, spacing: 2) {
        Rectangle().fill(JourneyColor.hairline).frame(width: 48, height: 1).padding(.bottom, 8)
        // Sulav's own signature (18 Oct 2026, from Preview), drawn in the text colour so it reads in
        // light and dark; about as tall as the typed name it replaced was large.
        Image("FounderSignature").renderingMode(.template).resizable().scaledToFit()
          .frame(height: signature * 1.5).foregroundStyle(JourneyColor.text)
          .accessibilityLabel("Sulav")
        Text(store.t("Founder, GymBlock")).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
      }.padding(.top, 2)
    }
    .font(font).foregroundStyle(JourneyColor.text.opacity(0.86)).lineSpacing(3)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.horizontal, 6)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

// MARK: - Days a week

/// How many days a week they lift, on a slider from once a week to every day (18 Oct 2026, at the
/// user's request, replacing five tap rows): the number large, what it means under it, the slider, and
/// its two ends named. It sets Home's weekly goal and the yearly estimate.
struct TrainingDaysStage: View {
  @Binding var days: Int?
  let choose: (Int) -> Void
  @EnvironmentObject private var store: GymStore
  /// Where the slider starts before it's touched: the middle of the week.
  static let start = 4
  var body: some View {
    let n = days ?? Self.start
    let value = Binding<Double>(get: { Double(days ?? Self.start) }, set: { new in
      let step = Int(new.rounded())
      if step != days { choose(step) }
    })
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(spacing: 4) {
        Text("\(n)").font(.app(size: JourneyLayout.compact ? 72 : 88, weight: .semibold)).monospacedDigit().tracking(-2)
          .foregroundStyle(JourneyColor.text).contentTransition(.numericText(value: Double(n)))
        Text(store.t(n == 7 ? "Every day" : n == 1 ? "day a week" : "days a week"))
          .font(.app(.title3, weight: .medium)).foregroundStyle(JourneyColor.secondary)
      }
      .animation(JourneyMotion.gentle, value: n)
      .accessibilityHidden(true)
      Spacer(minLength: 0).frame(maxHeight: 56)
      VStack(spacing: 10) {
        Slider(value: value, in: 1...7, step: 1)
          .tint(JourneyColor.signal)
          .accessibilityLabel(store.t("Days a week"))
          .accessibilityValue(String(format: store.t("%@ days a week"), "\(n)"))
          .accessibilityIdentifier("days.slider")
        HStack {
          Text(store.t("Once a week"))
          Spacer()
          Text(store.t("Every day"))
        }.font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).accessibilityHidden(true)
      }
      .padding(.horizontal, 4)
      Spacer(minLength: 0)
    }
    // The page opens on a value, so Continue works without touching the slider.
    .onAppear { if days == nil { days = Self.start } }
  }
}

// MARK: - The shield, in action

/// What a locked app does mid-workout, played on a phone as in SleepBlock (20 Oct 2026, at the user's
/// request, replacing the shield card on its own): the home screen, a tap on TikTok, the app opening,
/// then GymBlock's shield over it with the real shield's words (GymBlockShield). It loops; the lock
/// click and Continue come once, on the first landing. An illustration, drawn rather than recorded:
/// blocking only runs on a real iPhone.
struct ShieldStage: View {
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var start: Date?
  @State private var still = false
  /// The tap, the app open and the shield landing; the loop's length.
  static let press = 1.0, open = 1.2, lands = 2.25, period = 6.4
  static let screen = CGSize(width: 300, height: 650)
  /// TikTok's icon on the home screen (third row, second column).
  static let icon = CGPoint(x: 114, y: 292)
  var body: some View {
    DesignFit(size: CGSize(width: Self.screen.width + 16, height: Self.screen.height + 16), maxScale: 1) {
      TimelineView(.animation(paused: start == nil || still)) { context in
        let t = still ? Self.lands + 1 : start.map { max(0, context.date.timeIntervalSince($0) + JourneyScores.displayLead).truncatingRemainder(dividingBy: Self.period) } ?? 0
        phone(t)
      }
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("blocking.shieldPreview")
    .accessibilityLabel(store.t("Illustration: TikTok is tapped mid-workout and GymBlock’s lock screen covers it."))
    .task { await run() }
  }
  private func run() async {
    if JourneyMotion.reduced(systemReduceMotion) { still = true; done(); return }
    try? await Task.sleep(for: .seconds(JourneyMotion.settle))
    guard !Task.isCancelled else { return }
    let begin = JourneyScorePlayer.shared.play(JourneyScores.shield, profile: store.profile)
    start = begin
    // A beat to read the shield before Continue.
    try? await Task.sleep(for: .seconds(max(0, begin.timeIntervalSinceNow) + Self.lands + 1))
    guard !Task.isCancelled else { return }
    done()
  }

  private func phone(_ t: Double) -> some View {
    let open = Ease.out(Ease.seg(t, Self.open, Self.open + 0.35))
    let shield = Ease.out(Ease.seg(t, Self.lands - 0.22, Self.lands))
    let away = Ease.inOut(Ease.seg(t, Self.period - 0.7, Self.period - 0.15))
    let anchor = UnitPoint(x: Self.icon.x / Self.screen.width, y: Self.icon.y / Self.screen.height)
    return ZStack {
      home(t)
      app.clipShape(RoundedRectangle(cornerRadius: 72 - 28 * open, style: .continuous))
        .scaleEffect(0.17 + 0.83 * open, anchor: anchor).opacity(t < Self.open ? 0 : min(1, open * 3) * (1 - away))
      shieldScreen(t).scaleEffect(1.03 - 0.03 * shield).opacity(shield * (1 - away))
      statusBar(ink: shield > 0.5 && away < 0.5)
      Capsule().fill(.black).frame(width: 86, height: 25).frame(maxHeight: .infinity, alignment: .top).padding(.top, 9)
    }
    .frame(width: Self.screen.width, height: Self.screen.height)
    .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
    .padding(8)
    .background(RoundedRectangle(cornerRadius: 52, style: .continuous).fill(Color(red: 0.09, green: 0.09, blue: 0.1)))
    .shadow(color: .black.opacity(0.18), radius: 18, y: 12)
  }

  private static let apps: [(name: String, symbol: String, color: Color)] = [
    ("Messages", "message.fill", Color(red: 0.2, green: 0.78, blue: 0.35)), ("Photos", "camera.macro", Color(red: 0.9, green: 0.42, blue: 0.54)),
    ("Camera", "camera.fill", Color(white: 0.45)), ("Mail", "envelope.fill", Color(red: 0.2, green: 0.5, blue: 0.95)),
    ("Clock", "clock.fill", Color(white: 0.12)), ("Maps", "map.fill", Color(red: 0.3, green: 0.7, blue: 0.45)),
    ("Notes", "note.text", Color(red: 0.95, green: 0.75, blue: 0.2)), ("Settings", "gear", Color(white: 0.55)),
    ("Instagram", "camera", Color(red: 0.84, green: 0.36, blue: 0.55)), ("TikTok", "", .black),
    ("YouTube", "play.fill", Color(red: 0.9, green: 0.28, blue: 0.23)), ("GymBlock", "", Color(red: 0.961, green: 0.953, blue: 0.937)),
  ]
  private func home(_ t: Double) -> some View {
    let press = Ease.bump(t, Self.press - 0.12, 0.3)
    let finger = Ease.seg(t, Self.press - 0.45, Self.press - 0.2) * (1 - Ease.seg(t, Self.press + 0.15, Self.press + 0.35))
    return ZStack(alignment: .topLeading) {
      LinearGradient(colors: [Color(red: 0.85, green: 0.81, blue: 0.77), Color(red: 0.73, green: 0.69, blue: 0.65), Color(red: 0.56, green: 0.55, blue: 0.56)],
                     startPoint: .topLeading, endPoint: .bottom)
      ForEach(Array(Self.apps.enumerated()), id: \.offset) { i, app in
        VStack(spacing: 5) {
          tile(app).scaleEffect(app.name == "TikTok" ? 1 - 0.12 * press : 1)
          Text(app.name).font(.system(size: 9.5, weight: .medium)).foregroundStyle(.white).lineLimit(1).fixedSize()
        }
        .position(x: 42 + Double(i % 4) * 72, y: 108 + Double(i / 4) * 96)
      }
      HStack(spacing: 22) {
        ForEach([("phone.fill", Color(red: 0.2, green: 0.78, blue: 0.35)), ("safari", Color(red: 0.2, green: 0.5, blue: 0.95)),
                 ("message.fill", Color(red: 0.2, green: 0.78, blue: 0.35)), ("music.note", Color(red: 0.95, green: 0.3, blue: 0.4))], id: \.0) { symbol, color in
          tile((name: "", symbol: symbol, color: color))
        }
      }
      .padding(12).background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(.white.opacity(0.28)))
      .position(x: Self.screen.width / 2, y: Self.screen.height - 62)
      Circle().fill(.white.opacity(0.35)).overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
        .frame(width: 36, height: 36).scaleEffect(1 - 0.15 * press).opacity(finger)
        .position(x: Self.icon.x + 8, y: Self.icon.y + 10)
    }
    .frame(width: Self.screen.width, height: Self.screen.height)
  }
  private func tile(_ app: (name: String, symbol: String, color: Color)) -> some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(app.color).frame(width: 52, height: 52)
      .overlay {
        switch app.name {
        case "TikTok": note(size: 26)
        case "GymBlock": BrandMark(size: 34)
        default: Image(systemName: app.symbol).font(.system(size: 23, weight: .medium)).foregroundStyle(.white)
        }
      }
  }
  /// A stand-in for TikTok's note, as in SleepBlock: a white note with its cyan and pink edges.
  private func note(size: CGFloat) -> some View {
    Text("♪").font(.system(size: size, weight: .bold)).foregroundStyle(.white)
      .shadow(color: .cyan, radius: 0, x: -size / 14, y: -size / 28)
      .shadow(color: .pink, radius: 0, x: size / 14, y: size / 18)
  }
  private var app: some View {
    ZStack {
      Color.black
      VStack(spacing: 14) {
        note(size: 64)
        Text("TikTok").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
      }
    }.frame(width: Self.screen.width, height: Self.screen.height)
  }
  /// The real shield's layout: the mark and words above the middle, the ink button near the bottom.
  private func shieldScreen(_ t: Double) -> some View {
    let click = t < Self.lands ? 1 : 1 - 0.14 * Ease.bump(t, Self.lands, 0.18) + 0.08 * Ease.bump(t, Self.lands + 0.14, 0.2)
    return ZStack {
      Color(red: 0.961, green: 0.953, blue: 0.937)
      VStack(spacing: 10) {
        Spacer().frame(height: 170)
        BrandMark(size: 62).scaleEffect(click)
        Text(store.t("You’re mid-workout.")).font(.system(size: 22, weight: .bold)).foregroundStyle(JourneyColor.text).padding(.top, 8)
        Text(String(format: store.t("%@ opens when you finish your workout in GymBlock."), "TikTok"))
          .font(.system(size: 14)).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 30)
        Spacer()
        Text(store.t("Back to training")).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
          .frame(maxWidth: .infinity, minHeight: 46).background(Capsule().fill(JourneyColor.button)).padding(.horizontal, 22)
        Spacer().frame(height: 52)
      }
    }.frame(width: Self.screen.width, height: Self.screen.height)
  }
  private func statusBar(ink: Bool) -> some View {
    VStack {
      HStack {
        Text("9:41").font(.system(size: 13, weight: .semibold))
        Spacer()
        HStack(spacing: 4) { Image(systemName: "cellularbars"); Image(systemName: "wifi"); Image(systemName: "battery.100percent") }
          .font(.system(size: 11))
      }.padding(.horizontal, 26).padding(.top, 15)
      Spacer()
      Capsule().frame(width: 104, height: 4).padding(.bottom, 7)
    }.foregroundStyle(ink ? JourneyColor.text : .white)
  }
}

// MARK: - Rest alerts on the Lock Screen

/// The Live Activity counts the last seconds of a rest, then the buzz and the notification land.
struct LockScreenRest: View {
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  var body: some View {
    SceneClock(duration: 2.75, score: JourneyScores.restUp, done: done) { t in
      // One digit every 0.4 s from 0:05, each with a tick; 0:00 is the buzz (JourneyScores.restUp).
      let remaining = max(0, 5 - Int((t / JourneyScores.countdownStep).rounded(.down)))
      let over = remaining == 0
      VStack(spacing: JourneyLayout.compact ? 12 : 16) {
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
            Text(store.t("Next: Bench press · set 3 of 3")).font(.app(JourneyLayout.compact ? .footnote : .subheadline)).foregroundStyle(.white).lineLimit(1)
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
    // A picture of the Lock Screen: one still sentence, not a live countdown and a "Start set" that isn't a button.
    .accessibilityElement(children: .ignore).accessibilityIdentifier("alerts.preview")
    .accessibilityLabel(store.t("On your Lock Screen") + ": " + store.t("Rest’s up. Time for your next set."))
  }
}

// MARK: - The plan

/// Their answers as a plan: three lines on the paper (four when their workout with rests on time is
/// known), and the hold to commit.
struct PlanStage: View {
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  var body: some View {
    // The last line finishes settling at 1.05 s (1.25 s with four); the hold appears after it.
    SceneClock(duration: rows.count > 3 ? 1.3 : 1.1, done: done) { t in
      VStack(spacing: 18) {
        Spacer(minLength: 0)
        VStack(spacing: 0) {
          ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
            let k = Ease.out(Ease.seg(t, 0.15 + Double(i) * 0.2, 0.65 + Double(i) * 0.2))
            VStack(alignment: .leading, spacing: 3) {
              Text(row.0).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
              // Their workout with rests on time is the one thing in the plan that's new: the signal.
              Text(row.1).font(.app(JourneyLayout.compact ? .title3 : .title2, weight: .semibold))
                .foregroundStyle(i == 3 ? JourneyColor.signalText : JourneyColor.text).tracking(-0.3)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, JourneyLayout.compact ? 10 : 15)
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
    let baseline = store.profile.baseline ?? RoutineBaseline()
    let days = baseline.trainingDays ?? 4
    let rest = clockString(store.profile.restSeconds ?? 90)
    let locked = blocking.ready && store.profile.focusEnabled == true
    let time = TimeBack(baseline, restSeconds: store.profile.restSeconds)
    return [
      (store.t("Training"), String(format: store.t("%@ days a week"), "\(days)")),
      (store.t("While you train"), locked ? String(format: store.t("%@ locked"), blocking.summary(store.t)) : store.t("Rest timer and log")),
      (store.t("Between sets"), String(format: store.t(store.profile.restAlerts == true ? "%@ rests, then a buzz" : "%@ rests"), rest)),
    ] + (time.outcome == .full ? [(store.t("Each workout"), store.aboutLine(time.workout))] : [])
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

/// One tap on the split most people run, or build your own in the split editor (name, exercises,
/// order). Splits you build are kept and selected; build as many as you like. On small screens the
/// preview card doesn't fit beside the options, so the line above Continue says what we'll set up
/// (`summary`); if the page still runs over (large text, longer Spanish), it scrolls.
struct SplitTemplateStage: View {
  @Binding var choice: SplitTemplate?
  @EnvironmentObject private var store: GymStore
  @State private var building = false
  private var compact: Bool { JourneyLayout.compact }
  private var options: [SplitTemplate] {
    (store.data.workouts.isEmpty ? [] : [.keep]) + [.pushPullLegs, .upperLower, .fullBody, .bodyPart, .none]
  }
  var body: some View {
    ViewThatFits(in: .vertical) {
      list
      ScrollView { list.padding(.vertical, 2) }.scrollIndicators(.hidden)
    }
    .sheet(isPresented: $building) {
      NavigationStack {
        SplitEditorContent(workout: Workout(name: "", exercises: [])) { split in
          store.updateProfile { if $0.preferredSplitID == nil { $0.preferredSplitID = split.id } }
          withAnimation(JourneyMotion.gentle) { choice = .keep }
          JourneyHaptic.play(.success, store.profile)
          building = false
        }
      }.presentationDetents([.large]).tint(JourneyColor.text)
    }
  }
  private var list: some View {
    VStack(spacing: compact ? 10 : 14) {
      Spacer(minLength: 0)
      if !compact { preview.animation(JourneyMotion.gentle, value: choice) }
      JourneyGlassGroup(spacing: compact ? 8 : 10) {
        VStack(spacing: compact ? 8 : 10) {
          ForEach(options) { option in
            JourneyOption(title: option == .keep ? keepTitle : store.t(option.title),
                          selected: choice == option, id: "splits.template." + option.rawValue) {
              withAnimation(JourneyMotion.gentle) { choice = option }
              JourneyHaptic.play(.selection, store.profile)
            }
          }
        }
      }
      Button { building = true } label: {
        Label(store.t(store.data.workouts.isEmpty ? "Build my own split" : "Build another split"), systemImage: "plus")
          .font(JourneyType.option).foregroundStyle(JourneyColor.text)
          .frame(maxWidth: .infinity, minHeight: compact ? 44 : 52)
          .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(JourneyColor.ink(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])))
      }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("splits.build")
    }
  }
  /// What we'll set up, in one or two lines: the compact page's caption in place of the card.
  static func summary(_ choice: SplitTemplate?, store: GymStore) -> String? {
    func list(_ names: [String]) -> String {
      guard let last = names.last, names.count > 1 else { return names.first ?? "" }
      return names.dropLast().joined(separator: ", ") + " " + store.t("and") + " " + last
    }
    switch choice {
    case nil: return nil
    case .keep?:
      let names = store.data.workouts.map(\.name)
      return String(format: store.t(names.count == 1 ? "Your split: %@." : "Your splits: %@."), list(names))
    case .some(.none): return store.t("Every workout starts free: pick exercises as you go.")
    case let template?:
      let names = list(template.splits.map { store.t($0.0) }), counts = Set(template.splits.map(\.1.count))
      guard counts.count == 1, let n = counts.first else { return String(format: store.t("We’ll set up %@."), names) }
      return String(format: store.t(template.splits.count == 1 ? "We’ll set up %@: %@ exercises." : "We’ll set up %@: %@ exercises each."), names, "\(n)")
    }
  }
  private var keepTitle: String {
    let n = store.data.workouts.count
    return n == 1 ? store.t("Keep my split") : String(format: store.t("Keep my %@ splits"), "\(n)")
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
            Text("\(row.2)").font(.app(.footnote)).monospacedDigit().foregroundStyle(JourneyColor.secondary)
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
            Button { editing = split } label: {
              // A full 44-pt target (the word alone was about 20 pt tall).
              Text(store.t("Edit")).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.text)
              .accessibilityIdentifier("first.edit")
          }.padding(.horizontal, 16).padding(.vertical, 12)
          ForEach(split.exercises.prefix(JourneyLayout.compact ? 5 : 7)) { e in
            HStack {
              Text(store.t(e.name)).font(.app(.body)).foregroundStyle(JourneyColor.text).lineLimit(1)
              Spacer()
              Text(e.timed ? store.t("Timed") : String(format: store.t("%@ sets"), "3")).font(.app(.footnote)).monospacedDigit().foregroundStyle(JourneyColor.secondary)
            }.padding(.horizontal, 16).padding(.vertical, JourneyLayout.compact ? 8 : 11)
              .overlay(alignment: .top) { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
          }
          let shown = JourneyLayout.compact ? 5 : 7
          if split.exercises.count > shown {
            Text(String(format: store.t("+ %@ more"), "\(split.exercises.count - shown)")).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
              .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 8)
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
