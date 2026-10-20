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

// MARK: - Sucked in (the first question)

/// Your workout pulled into your phone (20 Oct 2026, at the user's request, replacing three
/// notifications: checking the phone is fine; getting sucked into it is the problem). A phone
/// scrolls its feed while the kit around it (dumbbell, kettlebell, plate, barbell) is pulled in one
/// piece at a time, spiralling, shrinking and vanishing into the screen, each on a soft tap; a faint
/// red, the colour of time on the phone, grows behind it. Then the kit is back and it goes again.
/// No words: the page has enough.
struct SuckedInStage: View {
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var start: Date?
  @State private var still = false
  /// Kit (KitPiece kinds) and where each starts around the phone, in degrees (0 = right, y down).
  static let pieces: [(kind: Int, angle: Double)] = [(0, -150), (1, -30), (4, 150), (2, 30)]
  static let first = 0.45, gap = 0.6, pull = 1.4
  /// When piece `i` disappears into the screen.
  static func swallowed(_ i: Int) -> Double { first + gap * Double(i) + pull }
  static let respawn = 0.6
  static let period = swallowed(pieces.count - 1) + 1.5 + respawn
  static let size = CGSize(width: 360, height: 330)
  var body: some View {
    DesignFit(size: Self.size, maxScale: JourneyLayout.compact ? 0.9 : 1.1) {
      TimelineView(.animation(paused: start == nil || still)) { context in
        let elapsed = start.map { max(0, context.date.timeIntervalSince($0) + JourneyScores.displayLead) } ?? 0
        scene(still ? Self.swallowed(Self.pieces.count - 1) + 0.6 : elapsed.truncatingRemainder(dividingBy: Self.period), feed: elapsed)
      }
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.phone")
    .accessibilityLabel(store.t("Illustration: a phone pulling your workout into it."))
    .task { await run() }
  }
  private func run() async {
    if JourneyMotion.reduced(systemReduceMotion) { still = true; done(); return }
    try? await Task.sleep(for: .seconds(JourneyMotion.settle))
    guard !Task.isCancelled else { return }
    // The taps play on the first pass only; the loop is silent.
    let begin = JourneyScorePlayer.shared.play(JourneyScores.suckedIn, profile: store.profile)
    start = begin
    try? await Task.sleep(for: .seconds(max(0, begin.timeIntervalSinceNow) + Self.swallowed(Self.pieces.count - 1) + 0.4))
    guard !Task.isCancelled else { return }
    done()
  }

  private func scene(_ t: Double, feed: Double) -> some View {
    let back = Ease.out(Ease.seg(t, Self.period - Self.respawn, Self.period))
    let eaten = Self.pieces.indices.reduce(0.0) { $0 + Ease.out(Ease.seg(t, Self.swallowed($1) - 0.15, Self.swallowed($1) + 0.4)) } / Double(Self.pieces.count) * (1 - back)
    let gulp = Self.pieces.indices.reduce(0.0) { $0 + Ease.bump(t, Self.swallowed($1), 0.22) }
    return ZStack {
      Circle().fill(RadialGradient(colors: [JourneyColor.danger.opacity(0.26), .clear], center: .center, startRadius: 0, endRadius: 160))
        .frame(width: 320, height: 320).scaleEffect(0.7 + 0.3 * eaten).opacity(eaten)
      phone(feed: feed).scaleEffect(1 + 0.035 * gulp)
      ForEach(Array(Self.pieces.enumerated()), id: \.offset) { i, piece in
        kit(i, piece, t: t, back: back)
      }
    }.frame(width: Self.size.width, height: Self.size.height)
  }
  private func kit(_ i: Int, _ piece: (kind: Int, angle: Double), t: Double, back: Double) -> some View {
    let begin = Self.first + Self.gap * Double(i)
    let p = Ease.seg(t, begin, begin + Self.pull)
    // Slow at first, then faster and faster: a pull, not a slide.
    let k = t >= Self.period - Self.respawn ? 0 : p * p
    let theta = (piece.angle + 210 * k) * .pi / 180
    let reach = 1 - k
    let bob = sin(t * 2.2 + Double(i) * 1.7) * 3 * reach
    let x = cos(theta) * 132 * reach, y = sin(theta) * 108 * reach + bob
    let visible = t >= Self.period - Self.respawn ? back : 1 - Ease.seg(k, 0.82, 1)
    return KitPiece(kind: piece.kind).frame(width: 80, height: 72)
      .scaleEffect(0.92 * (1 - 0.85 * k) * (t >= Self.period - Self.respawn ? 0.85 + 0.15 * back : 1))
      .rotationEffect(.degrees(240 * k))
      .opacity(visible)
      .offset(x: x, y: y)
  }
  /// A phone scrolling an endless feed: cards in the reels' muted colours sliding up.
  private func phone(feed: Double) -> some View {
    let card = 62.0, spacing = 6.0, colors = FeedPhone.reels.map(\.bottom)
    let cycle = (card + spacing) * Double(colors.count)
    let y = -(feed * 34).truncatingRemainder(dividingBy: cycle)
    return VStack(spacing: spacing) {
      ForEach(0..<(colors.count * 2), id: \.self) { i in
        RoundedRectangle(cornerRadius: 9, style: .continuous).fill(colors[i % colors.count]).frame(height: card)
      }
    }
    .padding(.horizontal, 7)
    .offset(y: y)
    .frame(width: 108, height: 226, alignment: .top)
    .background(Color(red: 0.13, green: 0.13, blue: 0.14))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .padding(5)
    .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(red: 0.09, green: 0.09, blue: 0.1)))
    .overlay(alignment: .top) { Capsule().fill(Color(red: 0.04, green: 0.04, blue: 0.05)).frame(width: 34, height: 10).padding(.top, 11) }
    .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
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

// MARK: - What it adds up to

/// One dot per workout the year's lost minutes add up to.
struct WorkoutDots: View, Animatable {
  var dots: Int
  var lit: Double
  var columns = 14
  var animatableData: Double { get { lit } set { lit = newValue } }
  var body: some View {
    Canvas { c, size in
      let columns = self.columns
      let rows = max(1, Int(ceil(Double(dots) / Double(columns))))
      let pitch = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
      let d = pitch * 0.48
      let x0 = (size.width - pitch * CGFloat(columns)) / 2
      let y0 = (size.height - pitch * CGFloat(rows)) / 2
      let on = Int(lit.rounded(.down))
      for i in 0..<dots {
        let r = i / columns, col = i % columns
        let rect = CGRect(x: x0 + CGFloat(col) * pitch + (pitch - d) / 2, y: y0 + CGFloat(r) * pitch + (pitch - d) / 2, width: d, height: d)
        c.fill(Path(ellipseIn: rect), with: .color(i < on ? JourneyColor.danger : JourneyColor.ink(0.08)))
      }
    }
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

/// A fingerprint you hold, after SleepBlock's (18 Oct 2026, at the user's request, replacing the hold
/// capsule): holding it reads as authorising the plan, not clicking past it. The print fills emerald
/// from the bottom with a scan line on the fill's edge, a ring closes round it, and the commitment
/// completes at 1.6 s; letting go early rewinds. The mark is Material Symbols `fingerprint`, weight 100
/// (CREDITS.md), never SF Symbols' `touchid`, which Apple licenses only for Touch ID itself.
struct FingerprintHold: View {
  let title: String
  let holdingTitle: String
  let doneTitle: String
  let committed: Bool
  let onProgress: (Double) -> Void
  let onComplete: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.scenePhase) private var scenePhase
  @State private var fill = 0.0
  @State private var holding = false
  @State private var pulse = false
  @State private var ticker: Task<Void, Never>?
  static let duration = 1.6
  private let print: CGFloat = JourneyLayout.compact ? 64 : 76
  private var ring: CGFloat { print + 40 }
  private var progress: Double { committed ? 1 : fill }
  var body: some View {
    VStack(spacing: 10) {
      ZStack {
        Circle().fill(JourneyColor.ink(holding ? 0.09 : 0.05)).frame(width: print + 22, height: print + 22)
          .overlay(Circle().strokeBorder(JourneyColor.hairline, lineWidth: 1))
        Circle().trim(from: 0, to: progress)
          .stroke(JourneyColor.signal, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .frame(width: ring - 6, height: ring - 6).rotationEffect(.degrees(-90))
        if committed {
          Image(systemName: "checkmark").font(.system(size: print * 0.42, weight: .light)).foregroundStyle(JourneyColor.signal)
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else {
          mark(JourneyColor.ink(0.28))
          mark(JourneyColor.signal).mask(alignment: .bottom) { Rectangle().frame(height: print * progress) }
          // The scan line rides the top of the fill.
          if progress > 0.02 && progress < 0.99 {
            Capsule().fill(JourneyColor.signal).frame(width: print * 0.9, height: 1.5)
              .shadow(color: JourneyColor.signal.opacity(0.7), radius: 4)
              .offset(y: print / 2 - print * progress)
          }
        }
      }
      .frame(width: ring, height: ring)
      .scaleEffect(committed ? 1.03 : holding ? 0.96 : 1)
      .animation(.spring(response: 0.34, dampingFraction: 0.7), value: committed)
      .animation(.easeOut(duration: 0.18), value: holding)
      .overlay {
        // One outward pulse, on success only.
        if committed && !reduceMotion {
          Circle().stroke(JourneyColor.signal.opacity(pulse ? 0 : 0.45), lineWidth: 2)
            .scaleEffect(pulse ? 1.45 : 1).frame(width: ring, height: ring).allowsHitTesting(false)
        }
      }
      .contentShape(Circle())
      .gesture(DragGesture(minimumDistance: 0)
        .onChanged { v in
          // Sliding off the print is letting go.
          if abs(v.translation.width) > 60 || abs(v.translation.height) > 60 { release(); return }
          if !holding && !committed { start() }
        }
        .onEnded { _ in release() })
      Text(committed ? doneTitle : holding ? holdingTitle : title)
        .font(JourneyType.label).foregroundStyle(committed ? JourneyColor.signal : JourneyColor.secondary)
        .contentTransition(.opacity).animation(.easeInOut(duration: 0.2), value: committed)
    }
    .frame(maxWidth: .infinity)
    .accessibilityElement().accessibilityLabel(title).accessibilityAddTraits(.isButton)
    .accessibilityIdentifier("commit.hold")
    // VoiceOver can't express a press and hold, so it gets a plain action.
    .accessibilityAction { finish() }
    .onChange(of: scenePhase) { _, phase in if phase != .active { release() } }
    .onChange(of: committed) { _, done in
      guard done else { return }
      DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.7)) { pulse = true } }
    }
  }
  private func mark(_ color: Color) -> some View {
    Image("FingerprintMark").renderingMode(.template).resizable().scaledToFit()
      .frame(width: print, height: print).foregroundStyle(color)
  }
  private func start() {
    holding = true
    let begin = Date()
    withAnimation(.linear(duration: Self.duration)) { fill = 1 }
    // One continuous buzz that climbs while the finger stays down, and a tick every fifth, like a
    // scanner reading ridges.
    JourneyScorePlayer.shared.swell(Self.duration, from: 0.05, to: 0.7, sharpness: 0.4)
    ticker = Task { @MainActor in
      var tick = 0
      while !Task.isCancelled {
        let p = min(1, Date().timeIntervalSince(begin) / Self.duration)
        onProgress(p)
        if Int(p * 5) > tick { tick = Int(p * 5); if p < 1 { JourneyHaptic.pressLight() } }
        if p >= 1 { finish(); return }
        try? await Task.sleep(for: .milliseconds(40))
      }
    }
  }
  private func release() {
    guard holding, !committed else { holding = false; return }
    holding = false
    ticker?.cancel()
    JourneyScorePlayer.shared.stop()
    onProgress(0)
    // Rewinds rather than snapping to zero: a slip isn't punished.
    withAnimation(.easeOut(duration: 0.4)) { fill = 0 }
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
      JourneyHaptic.press()
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
