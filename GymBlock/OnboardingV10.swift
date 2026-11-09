import SwiftUI

// Onboarding V10 (docs/ONBOARDING-V10-PLAN.md, 1 Nov 2026): the clean flow's own pieces. Rows with
// an icon (days, source), the big-number results, the life dots (Brainrot's beat in GymBlock's
// numbers), the word loop, the notification prompt as the picture, the commit mark, the two trial
// pages and the why page as two cards. Paper, ink, emerald, red only for time on the phone.

// MARK: - Answers with an icon

/// Days a week as a range, as Cal AI asks it (1 Nov 2026, at the user's request); the weekly goal
/// and the year take the higher value in the range.
enum DaysRange: CaseIterable {
  case few, some, most
  var days: Int { switch self { case .few: return 2; case .some: return 5; case .most: return 6 } }
  var title: String { switch self { case .few: return "0–2"; case .some: return "3–5"; case .most: return "6+" } }
  var detail: String { switch self { case .few: return "Now and then"; case .some: return "A few a week"; case .most: return "Dedicated athlete" } }
  var dots: Int { switch self { case .few: return 1; case .some: return 3; case .most: return 6 } }
}

extension AgeAnswer {
  var title: String {
    switch self {
    case .under18: return "Under 18"
    case .from18: return "18–24"
    case .from25: return "25–34"
    case .from35: return "35–44"
    case .from45: return "45–54"
    case .from55: return "55 or over"
    }
  }
}

extension SourceAnswer {
  var title: String {
    switch self {
    case .tiktok: return "TikTok"
    case .instagram: return "Instagram"
    case .youtube: return "YouTube"
    case .appStore: return "App Store"
    case .google: return "Google"
    case .friend: return "A friend"
    case .other: return "Somewhere else"
    }
  }
}

/// One, three or six dots: the days rows' icons.
struct DotsIcon: View {
  let count: Int
  var body: some View {
    Canvas { c, size in
      let d: CGFloat = count == 1 ? 9 : 6
      let points: [CGPoint]
      switch count {
      case 1: points = [CGPoint(x: 0.5, y: 0.5)]
      case 3: points = [CGPoint(x: 0.5, y: 0.22), CGPoint(x: 0.25, y: 0.72), CGPoint(x: 0.75, y: 0.72)]
      default: points = [0.2, 0.5, 0.8].flatMap { x in [0.3, 0.7].map { y in CGPoint(x: x, y: y) } }
      }
      for p in points {
        c.fill(Path(ellipseIn: CGRect(x: p.x * size.width - d / 2, y: p.y * size.height - d / 2, width: d, height: d)), with: .color(JourneyColor.text))
      }
    }
    .frame(width: 26, height: 26)
    .accessibilityHidden(true)
  }
}

/// The source rows' marks: the real icons (1 Nov 2026, at the user's request, as Cal AI shows them;
/// `app.*` in Assets), the App Store's glyph on its blue, Google's G.
struct SourceIcon: View {
  let source: SourceAnswer
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
    ZStack {
      switch source {
      case .tiktok: Image("app.tiktok").resizable().scaledToFill().clipShape(shape)
      case .instagram: Image("app.instagram").resizable().scaledToFill().clipShape(shape)
      case .youtube: Image("app.youtube").resizable().scaledToFill().clipShape(shape)
      case .appStore:
        shape.fill(Color(red: 0.11, green: 0.51, blue: 0.98))
        Image("brand.appstore").renderingMode(.template).resizable().scaledToFit().frame(width: 18, height: 18).foregroundStyle(.white)
      case .google:
        shape.fill(.white)
        shape.strokeBorder(JourneyColor.ink(0.12), lineWidth: 1)
        Image("GoogleG").resizable().frame(width: 15, height: 15)
      case .friend:
        shape.fill(JourneyColor.ink(0.08))
        Image(systemName: "person.2.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(JourneyColor.text)
      case .other:
        shape.fill(JourneyColor.ink(0.08))
        Image(systemName: "ellipsis").font(.system(size: 13, weight: .bold)).foregroundStyle(JourneyColor.text)
      }
    }
    .frame(width: 26, height: 26)
    .accessibilityHidden(true)
  }
}

/// An answer row with a mark on the left and, optionally, a second line (the days and source rows).
/// Otherwise `JourneyOption`: selecting only selects, the chosen row rises, the check is the signal.
struct JourneyIconOption<Icon: View>: View {
  let title: String
  var detail: String? = nil
  let selected: Bool
  let id: String
  let icon: Icon
  let action: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
    Button(action: { Analytics.tap(id); action() }) {
      HStack(spacing: 14) {
        icon
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(JourneyType.option).foregroundStyle(JourneyColor.text).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
          if let detail { Text(detail).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).lineLimit(typeSize.isAccessibilitySize ? 3 : 1) }
        }
        Spacer(minLength: 8)
        Image(systemName: "checkmark.circle.fill").font(.system(.body, weight: .semibold))
          .symbolRenderingMode(.palette).foregroundStyle(JourneyColor.onAccent, JourneyColor.accent)
          .opacity(selected ? 1 : 0).scaleEffect(selected ? 1 : 0.6).accessibilityHidden(true)
      }.padding(.horizontal, 16).padding(.vertical, detail == nil ? 0 : 8)
        .frame(maxWidth: .infinity, minHeight: JourneyLayout.compact ? 44 : 52)
        .contentShape(shape)
        .journeyGlass(shape, tint: selected ? JourneyColor.ink(0.12) : nil, interactive: true)
        .overlay(shape.strokeBorder(JourneyColor.ink(selected ? 0.5 : 0), lineWidth: 1.5))
    }.buttonStyle(JourneyPressStyle())
      .animation(reduceMotion ? nil : JourneyMotion.gentle, value: selected)
      .accessibilityIdentifier(id).accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityLabel(detail.map { title + ", " + $0 } ?? title)
  }
}

// MARK: - The results as big numbers

/// A result page: the number large in the red of time on the phone, its unit beside it, and one
/// strip under it (the grey the rest they need, the red the minutes past it) with its two labels.
/// Static: nothing to wait for, as Cal AI's results are.
struct BigNumberStage: View {
  enum Kind { case perRest(TimeBack), workout(TimeBack) }
  let kind: Kind
  init(_ kind: Kind) { self.kind = kind }
  @EnvironmentObject private var store: GymStore
  var body: some View {
    let (number, unit, grey, red, left, right) = parts
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: 0)
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(number).font(.app(size: 72, weight: .bold)).tracking(-2).monospacedDigit().foregroundStyle(JourneyColor.danger)
        Text(unit).font(.app(.title2, weight: .semibold)).foregroundStyle(JourneyColor.danger)
      }.lineLimit(1).minimumScaleFactor(0.6)
      GeometryReader { g in
        let w = g.size.width, part = grey / max(0.01, grey + red)
        ZStack(alignment: .leading) {
          Rectangle().fill(JourneyColor.ink(0.5)).frame(width: w * part)
          Rectangle().fill(JourneyColor.danger).frame(width: w * (1 - part)).offset(x: w * part)
        }
      }
      .frame(height: 22).clipShape(Capsule()).padding(.top, 26)
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 1) {
          Text(left.0).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
          Text(left.1).font(.app(.title3, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 1) {
          Text(right.0).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
          Text(right.1).font(.app(.title3, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.dangerText)
        }
      }.padding(.top, 10)
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.bigNumber")
    .accessibilityLabel(number + " " + unit + ". " + left.0 + " " + left.1 + ". " + right.0 + " " + right.1)
  }
  private var parts: (String, String, Double, Double, (String, String), (String, String)) {
    switch kind {
    case .perRest(let time):
      let need = time.restNeed, lost = time.lostPerRest ?? 0
      return (TimeWords.half(lost), store.t("min"), need, lost,
              (store.t("Rest you need"), TimeWords.clock(need)), (store.t("Past it"), TimeWords.clock(lost)))
    case .workout(let time):
      let rests = time.neededRest ?? 0, lost = Double(time.shownLost)
      return ("\(time.shownLost)", store.t("min"), rests, lost,
              (store.t("Rests you need"), TimeWords.duration(Int(rests))), (store.t("On your phone"), TimeWords.duration(time.shownLost)))
    }
  }
}

// MARK: - The life dots

/// Brainrot's beat in a lifter's unit: one dot for every workout in their next year, lighting up
/// one by one with a tick; on the next page the share the phone takes turns red from the end and
/// lands on a thud. The two pages share the grid.
struct LifeDotsStage: View {
  let time: TimeBack
  let phase: Phase
  let done: () -> Void
  enum Phase { case gym, phone }
  @EnvironmentObject private var store: GymStore
  static let fill = 1.8, red = 1.4
  var body: some View {
    let count = time.yearWorkouts, reds = time.yearPhoneWorkouts
    let over = phase == .gym ? Self.fill : Self.red
    SceneClock(duration: over + 0.4, score: JourneyScores.dots(count: phase == .gym ? count : reds, over: over, heavy: phase == .phone), done: done) { t in
      grid(t, over: over, count: count, reds: reds)
    }
    // The second page restarts the clock on the same grid.
    .id(phase)
    .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.year")
    .accessibilityLabel(phase == .gym ? String(format: store.t("%@ dots: your next year of workouts, one each."), "\(count)")
                        : String(format: store.t("%@ of the %@ dots red: the workouts your phone takes."), "\(reds)", "\(count)"))
  }
  /// Columns for the count, so the dots stay big enough to count: 8 up to 80, 13 up to 200, then 16.
  static func columns(_ count: Int) -> Int { count <= 80 ? 8 : count <= 200 ? 13 : 16 }
  private func grid(_ t: Double, over: Double, count: Int, reds: Int) -> some View {
    let k = JourneyScores.easeInOut(min(1, t / over))
    let lit = phase == .gym ? Int(Double(count) * k + 0.5) : count
    let red = phase == .phone ? Int(Double(reds) * k + 0.5) : 0
    let cols = Self.columns(count), rows = max(1, (count + cols - 1) / cols)
    let gapShare = 0.4
    let aspect = (Double(cols) + gapShare * Double(cols - 1)) / (Double(rows) + gapShare * Double(rows - 1))
    return VStack(spacing: 0) {
      Spacer(minLength: 0)
      Canvas { c, size in
        let d = size.width / (CGFloat(cols) + CGFloat(gapShare) * CGFloat(cols - 1)), gap = d * CGFloat(gapShare)
        for i in 0..<count {
          let rect = CGRect(x: CGFloat(i % cols) * (d + gap), y: CGFloat(i / cols) * (d + gap), width: d, height: d)
          let color = i >= count - red ? JourneyColor.danger : JourneyColor.ink(0.5)
          c.fill(Path(ellipseIn: rect), with: .color(color.opacity(i < lit ? 1 : 0.08)))
        }
      }
      .aspectRatio(aspect, contentMode: .fit).frame(maxWidth: JourneyLayout.compact ? 260 : 320, maxHeight: JourneyLayout.compact ? 300 : 420)
      Spacer(minLength: 0)
    }
  }
}

/// The number in life, as Brainrot's "22 years": the hours (or years) large in the red of time on
/// the phone, centred, nothing else.
struct LifeNumberStage: View {
  let hours: Double
  @EnvironmentObject private var store: GymStore
  var body: some View {
    let span = LifeWords.span(hours: hours)
    VStack(spacing: 4) {
      Spacer(minLength: 0)
      Text(span.text).font(.app(size: JourneyLayout.compact ? 72 : 88, weight: .bold)).tracking(-3).monospacedDigit()
        .foregroundStyle(JourneyColor.danger).lineLimit(1).minimumScaleFactor(0.5)
      Text(store.t(span.unit)).font(.app(.title2, weight: .semibold)).foregroundStyle(JourneyColor.danger)
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
  }
}

/// "5 more months of" Living, Reading, Sleeping, Cooking, Lifting: one word at a time on a loop,
/// the rest in grey under it. Let's do this waits for the third word (9 Nov 2026, at the user's
/// request), so the loop is seen before they move on; at once under Reduce Motion.
struct WordsStage: View {
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var index = 0
  /// Each experience with a picture of someone living it, as Brainrot pairs each word with a scene of
  /// the brain. Apple's emoji (1 Nov 2026, at the user's request: the ink figures were lifeless): full
  /// colour, drawn, and read in a glance, with no art to commission.
  /// The old word fades out before the new one fades in, so two words never overlap mid-swap.
  static let swap: AnyTransition = .asymmetric(insertion: .opacity.animation(.easeOut(duration: 0.3).delay(0.22)),
                                               removal: .opacity.animation(.easeIn(duration: 0.18)))
  /// Family emoji joined with ZWJ draw as grey silhouettes since iOS 17.4, so the family and the kids
  /// are separate faces side by side.
  static let words: [(word: String, symbol: String)] = [
    ("Family time", "👨👩👧"), ("Learning guitar", "🎸"), ("Hiking", "🥾"), ("Your kids", "👧👦"),
    ("Dancing", "💃"), ("Sports", "⚽️"), ("Friends", "🧑‍🤝‍🧑"),
  ]
  var body: some View {
    let w = Self.words[index]
    let size: CGFloat = JourneyLayout.compact ? 72 : 96
    VStack(spacing: 22) {
      Spacer(minLength: 0)
      // Several faces in a row sit a little smaller so they fit the width.
      Text(w.symbol).font(.system(size: size * (w.symbol.count > 1 ? 0.74 : 1.1)))
        .frame(height: JourneyLayout.compact ? 100 : 130).id("icon\(index)").transition(Self.swap)
        .accessibilityHidden(true)
      // One line always: a long one ("Learning guitar") scales down rather than pushing the figure up.
      Text(store.t(w.word)).font(.app(size: JourneyLayout.compact ? 52 : 64, weight: .bold)).tracking(-2)
        .lineLimit(1).minimumScaleFactor(0.55).padding(.horizontal, 8)
        .foregroundStyle(JourneyColor.text).id(index).transition(Self.swap)
      Spacer(minLength: 0)
    }
    .animation(.smooth(duration: 0.45), value: index)
    .accessibilityElement(children: .ignore).accessibilityLabel(Self.words.map { store.t($0.word) }.joined(separator: ", "))
    .task {
      guard !JourneyMotion.reduced(systemReduceMotion) else { done(); return }
      var flips = 0
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1.4))
        guard !Task.isCancelled else { return }
        index = (index + 1) % Self.words.count
        flips += 1
        if flips == 2 { done() }
      }
    }
  }
}

// MARK: - Permissions, the commit, the trial

/// The permission pages after the price (1 Nov 2026, at the user's request, as SleepBlock's
/// primers): iOS's own dialog, drawn so the real one is known on sight, with working buttons. The
/// button that brings the real request is labelled and placed as in the dialog that follows it
/// (Screen Time: Continue on the left; notifications: Allow on the right), and an arrow bobs under
/// it with "Tap …". The other button moves on without asking. iOS chrome, so no Liquid Glass.
struct MockPermissionDialog: View {
  let glyph: String
  let title: String
  let confirm: String
  let deny: String
  /// Screen Time keeps iOS's blue link for its other button; notifications' is faint, so Allow is
  /// the only one that looks alive.
  var denyColor: Color = Color(red: 0, green: 0.48, blue: 1)
  var confirmLeading = true
  var busy = false
  var confirmID = ""
  var denyID = ""
  let onConfirm: () -> Void
  let onDeny: () -> Void
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  var body: some View {
    VStack(spacing: 18) {
      VStack(spacing: 0) {
        VStack(spacing: 12) {
          Image(systemName: glyph).font(.system(size: 26, weight: .medium)).foregroundStyle(Color(white: 0.45)).accessibilityHidden(true)
          Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.black).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
          // Greeked lines: the dialog's small print, gestured at rather than quoted.
          VStack(spacing: 5) {
            Capsule().fill(Color.black.opacity(0.08)).frame(width: 170, height: 6)
            Capsule().fill(Color.black.opacity(0.08)).frame(width: 128, height: 6)
          }.padding(.top, 2).accessibilityHidden(true)
        }.padding(.horizontal, 20).padding(.vertical, 22)
        Rectangle().fill(Color.black.opacity(0.12)).frame(height: 0.5)
        HStack(spacing: 0) {
          if confirmLeading { confirmButton; divider; denyButton } else { denyButton; divider; confirmButton }
        }
      }
      .frame(maxWidth: 300)
      .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
      .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
      // The arrow under whichever half brings the real request.
      HStack(spacing: 0) {
        if !confirmLeading { Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
        // The arrow and its words bob together, up and down only, drawn on a clock: an animation
        // started on appear also caught the page sliding in, and the words swayed sideways.
        TimelineView(.animation(paused: JourneyMotion.reduced(systemReduceMotion))) { context in
          let t = context.date.timeIntervalSinceReferenceDate
          VStack(spacing: 12) {
            Image(systemName: "arrow.up").font(.system(size: 22, weight: .bold))
            Text(String(format: store.t("Tap %@"), confirm)).font(.app(.footnote, weight: .semibold))
          }
          .offset(y: JourneyMotion.reduced(systemReduceMotion) ? 0 : 3 * sin(t * .pi / 1.1))
        }
        .foregroundStyle(JourneyColor.signalText).frame(maxWidth: .infinity)
        if confirmLeading { Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
      }
      .frame(maxWidth: 300).accessibilityHidden(true)
    }
  }
  private var divider: some View { Rectangle().fill(Color.black.opacity(0.12)).frame(width: 0.5, height: 48) }
  private var confirmButton: some View {
    Button { JourneyHaptic.press(); Analytics.tap(confirmID); onConfirm() } label: {
      ZStack {
        Text(confirm).opacity(busy ? 0 : 1)
        if busy { ProgressView().tint(.black) }
      }
      .font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
      .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
    }.buttonStyle(.plain).disabled(busy).accessibilityIdentifier(confirmID)
  }
  private var denyButton: some View {
    Button { JourneyHaptic.pressLight(); Analytics.tap(denyID); onDeny() } label: {
      Text(deny).font(.system(size: 17)).foregroundStyle(denyColor)
        .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
    }.buttonStyle(.plain).disabled(busy).accessibilityIdentifier(denyID)
  }
}

/// The page that asks for the apps: iOS's app picker, drawn in its light look with the apps' real
/// icons, three of them ticked. Illustrative, not their own list (Screen Time never tells an app
/// what's installed).
struct PickerPreview: View {
  @EnvironmentObject private var store: GymStore
  static let rows: [(name: String, icon: String, on: Bool)] = [
    ("Instagram", "app.instagram", true), ("Messages", "app.messages", false), ("TikTok", "app.tiktok", true),
    ("Safari", "app.safari", false), ("YouTube", "app.youtube", true),
  ]
  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(spacing: 0) {
        ForEach(Array(Self.rows.enumerated()), id: \.offset) { i, row in
          HStack(spacing: 14) {
            ZStack {
              if row.on {
                Circle().fill(Color(red: 0, green: 0.48, blue: 1))
                Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
              } else {
                Circle().strokeBorder(Color.black.opacity(0.22), lineWidth: 1.5)
              }
            }.frame(width: 24, height: 24)
            Image(row.icon).resizable().scaledToFill().frame(width: 34, height: 34)
              .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(row.name).font(.system(size: 17)).foregroundStyle(.black)
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 16).frame(height: 54)
          .overlay(alignment: .bottom) {
            if i < Self.rows.count - 1 { Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5).padding(.leading, 104) }
          }
        }
      }
      .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
      .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(store.t("A preview of the app list, with Instagram, TikTok and YouTube ticked."))
  }
}

/// The commit page: what the hold signs (1 Nov 2026, at the user's request; the mark alone was
/// decoration). A pledge in their own numbers, "I" lines on a glass card, the hours in the signal
/// colour, and a signature line under it that takes their name when they've held. The checks go
/// emerald as it's signed.
struct CommitPledgeStage: View {
  let time: TimeBack
  let baseline: RoutineBaseline
  let name: String
  let committed: Bool
  @EnvironmentObject private var store: GymStore
  var body: some View {
    let lines = pledge
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(alignment: .leading, spacing: 14) {
        Text(store.t("My commitment")).font(.app(.footnote, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
        ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark").font(.system(.subheadline, weight: .bold))
              .foregroundStyle(committed ? JourneyColor.signalText : JourneyColor.ink(0.3)).frame(width: 18)
            Text(l.text).font(.app(l.big ? .title3 : .body, weight: l.big ? .semibold : .regular))
              .foregroundStyle(l.big ? JourneyColor.signalText : JourneyColor.text).fixedSize(horizontal: false, vertical: true)
          }
        }
        // The signature line: empty until they've held, then their name written onto it in a
        // signature hand (1 Nov 2026, at the user's request), left to right as a pen would.
        VStack(alignment: .leading, spacing: 2) {
          Text(name.isEmpty ? " " : name).font(.custom("SnellRoundhand-Bold", size: 38)).foregroundStyle(JourneyColor.text)
            .lineLimit(1).minimumScaleFactor(0.5).padding(.leading, 6).padding(.top, 6)
            .mask(alignment: .leading) {
              GeometryReader { g in Rectangle().frame(width: committed ? g.size.width : 0) }
            }
            .animation(committed ? .easeInOut(duration: 0.8) : nil, value: committed)
          Rectangle().fill(JourneyColor.hairline).frame(height: 1)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading).padding(18).journeySurface()
      Spacer(minLength: 0)
    }
    .animation(JourneyMotion.gentle, value: committed)
    .accessibilityElement(children: .combine)
  }
  /// The lines, from their answers: the rest, the lock, the minutes, and the hours of their life.
  private var pledge: [(text: String, big: Bool)] {
    var lines: [(String, Bool)] = [
      (String(format: store.t("I rest %@, then lift."), TimeWords.clock(time.restNeed)), false),
      (store.t("My apps stay locked, first set to last."), false),
    ]
    if (time.lostPerRest ?? 0) == 0 {
      lines.append((store.t("Every rest on time."), true))
    } else if time.perRestOnly {
      lines.append((String(format: store.t("I get %@ back, every rest."), store.minutesWords(time.lostPerRest ?? 0)), true))
    } else {
      lines.append((time.lostIsAnHour ? store.t("I get about an hour back, every workout.")
                    : String(format: store.t("I get %@ minutes back, every workout."), "\(time.shownLost)"), false))
      lines.append((String(format: store.t("%@ of my life, back."), store.lifeWords(time.lifeLostHours(baseline.age))), true))
    }
    return lines
  }
}

/// The second trial page's picture: the symbol bell (the one the user liked), ringing like a real
/// one (1 Nov 2026): the body swings from its crown and dies away; the symbol's own clapper is
/// masked off and a matching one, drawn in its place, swings from inside the rim on its own, a beat
/// behind and wider; then a rest, on a loop. The badge pops onto the shoulder and rides the body.
/// Drawn on a clock, so every frame moves; nothing clips, the swing has room.
struct TrialBellStage: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var start = Date()
  /// The ring dies away over `ring` seconds; the bell rests until `period`.
  static let ring = 1.6, period = 3.4, badgeAt = 0.45
  /// The symbol's geometry, as fractions of its frame (measured from a render of `bell.fill`):
  /// the glyph's top, the rim's bottom, the clapper's top and bottom, the clapper's width.
  static let glyphTop = 0.073, rimBottom = 0.765, clapperTop = 0.819, clapperBottom = 0.927, clapperWidth = 0.265
  var body: some View {
    let reduced = JourneyMotion.reduced(systemReduceMotion)
    let size: CGFloat = JourneyLayout.compact ? 110 : 140
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      TimelineView(.animation(paused: reduced)) { context in
        let elapsed = reduced ? Self.period : context.date.timeIntervalSince(start)
        let t = elapsed.truncatingRemainder(dividingBy: Self.period)
        bell(size, body: reduced ? 0 : Self.bodyAngle(t), clapper: reduced ? 0 : Self.clapperAngle(t), badge: reduced ? 1 : Self.badgePop(elapsed))
      }
      .padding(40)  // Room for the swing and the badge.
      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(store.t("Illustration: a bell with one notification."))
  }
  /// The body: a swing that dies away, about 2½ swings a second.
  static func bodyAngle(_ t: Double) -> Double { t < ring ? 11 * exp(-2.1 * t) * sin(2 * .pi * 2.4 * t) : 0 }
  /// The clapper: the same rhythm, a beat behind and wider, hitting the sides.
  static func clapperAngle(_ t: Double) -> Double { t < ring + 0.3 ? 26 * exp(-1.7 * t) * sin(2 * .pi * 2.4 * t - 1.2) : 0 }
  /// The badge's pop: from nothing, over, then settled.
  static func badgePop(_ elapsed: Double) -> Double {
    let u = elapsed - badgeAt
    return u < 0 ? 0 : max(0, 1 + 0.22 * exp(-6 * u) * sin(11 * u) - exp(-16 * u))
  }
  private func bell(_ size: CGFloat, body: Double, clapper: Double, badge: Double) -> some View {
    let grey = JourneyColor.ink(0.14)
    return Image(systemName: "bell.fill").font(.system(size: size, weight: .regular)).foregroundStyle(grey)
      // The symbol without its clapper.
      .mask(alignment: .top) { GeometryReader { g in Rectangle().frame(height: g.size.height * (Self.rimBottom + 0.02)) } }
      // The clapper, drawn where the symbol's was, hanging from inside the rim on its own swing;
      // clipped under the rim's gap so it keeps the symbol's shape.
      .overlay {
        GeometryReader { g in
          let w = g.size.width, h = g.size.height
          // The symbol's clapper is the lower half of an ellipse, its flat top at the gap.
          let cw = w * Self.clapperWidth, ch = 2 * h * (Self.clapperBottom - Self.clapperTop)
          Ellipse().fill(grey).frame(width: cw, height: ch)
            .position(x: w / 2, y: h * Self.clapperTop)
            .rotationEffect(.degrees(clapper), anchor: UnitPoint(x: 0.5, y: 0.5))
            .mask(alignment: .bottom) { Rectangle().frame(height: h * (1 - Self.clapperTop)) }
        }
      }
      // The badge on the right shoulder, popping in (placed from the centre: the symbol's frame is
      // wider than the drawn bell).
      .overlay {
        Text("1").font(.app(.headline, weight: .bold)).foregroundStyle(.white)
          .frame(width: 42, height: 42).background(Circle().fill(JourneyColor.danger))
          .scaleEffect(max(0.001, badge))
          .offset(x: size * 0.34, y: -size * 0.3)
      }
      .rotationEffect(.degrees(body), anchor: UnitPoint(x: 0.5, y: Self.glyphTop))
  }
}

// MARK: - Here's why that didn't hold.

/// What they tried, each with why it didn't hold, on one card; GymBlock's one answer on another.
/// The lines land one after another on a falter; GymBlock's on the lock.
struct WhyStage: View {
  let tried: [TriedAnswer]
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  static let first = 0.4, gap = 0.7, lockGap = 0.9
  static func lands(_ i: Int) -> Double { first + gap * Double(i) }
  var body: some View {
    // Never empty here (the route skips this page for "Nothing yet"); a dev run can still land on it.
    let rows = tried.isEmpty ? [TriedAnswer.willpower] : tried
    let lock = Self.lands(rows.count - 1) + Self.lockGap
    let answer = store.t("Locked from your first set to your last. No Ignore button.")
    SceneClock(duration: lock + 0.5, score: JourneyScores.whyFails(rows: rows.indices.map(Self.lands), lock: lock), done: done) { t in
      ScaleToFit {
        VStack(spacing: 14) {
          card(store.t("What you tried")) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, a in
              line("xmark", JourneyColor.dangerText, lead: store.t(a.title), store.t(a.reason), rise: rise(t, Self.lands(i)))
            }
          }
          card(store.t("With GymBlock")) {
            line("checkmark", JourneyColor.signalText, lead: nil, answer, rise: rise(t, lock))
          }
        }
      }
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("journey.whyFails")
    .accessibilityLabel(rows.map { store.t($0.title) + ": " + store.t($0.reason) }.joined(separator: ". ") + ". GymBlock: " + answer)
  }
  private func rise(_ t: Double, _ at: Double) -> Double { Ease.out(Ease.seg(t, at - 0.05, at + 0.35)) }
  private func card<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.app(.footnote, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16).journeySurface()
  }
  /// The thing in semibold, why it didn't hold in regular weight after it (1 Nov 2026, at the user's
  /// request: in one weight the two ran together).
  private func line(_ symbol: String, _ color: Color, lead: String?, _ text: String, rise: Double) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: symbol).font(.system(.subheadline, weight: .bold)).foregroundStyle(color).frame(width: 18)
      // GymBlock's line has no lead: its card is already titled "With GymBlock".
      ((lead.map { Text($0).fontWeight(.semibold) + Text(": ") } ?? Text("")) + Text(text))
        .font(.app(.body)).foregroundStyle(JourneyColor.text).fixedSize(horizontal: false, vertical: true)
    }
    .opacity(rise).offset(y: (1 - rise) * 8)
  }
}

// MARK: - You're in

/// The first page after they pay (1 Nov 2026, at the user's request: the splits question was no
/// welcome for someone who'd just paid). Its own layout, as the welcome's: the mark drops onto the
/// paper with the plate's thud and its keyhole lights emerald with the lock's click; confetti fires
/// from both bottom corners on the Activity ring's chime; their name rises in large under the mark,
/// then what they now have ticks in, line by line. Continue comes once the lines are in.
struct YoureInStage: View {
  let name: String
  let done: () -> Void
  @EnvironmentObject private var store: GymStore
  static let land = 0.34, lock = 0.44, burst = 0.5, words = 0.6, length = 3.8
  /// How far the confetti's canvas runs below the page's content: past the button and the screen's
  /// bottom edge, so pieces fall out of sight rather than vanishing above the button.
  static let below: CGFloat = 420
  static func row(_ i: Int) -> Double { 1.15 + 0.28 * Double(i) }
  /// Continue appears once the last line is in, while the confetti is still coming down.
  static let ready = row(2) + 0.45
  static let rows = ["Apps locked while you train", "Every rest timed", "Every set saved to your account"]
  struct Piece {
    let left: Bool
    let angle, speed, fall, spin, size, wobble: Double
    let round: Bool
    let color: Color
  }
  /// The same volley every time: a fixed spread of angles, speeds and colours from each corner,
  /// up and in across the page.
  static let pieces: [Piece] = {
    var seed: UInt64 = 0x9E3779B97F4A7C15
    func random() -> Double {
      seed = seed &* 6364136223846793005 &+ 1442695040888963407
      return Double(seed >> 11) / Double(1 << 53)
    }
    let colors = SplitColor.allCases.filter { $0 != .graphite }.map { $0.paper.light.color } + [JourneyColor.signal, JourneyColor.signal]
    return (0..<180).map { i in
      let left = i % 2 == 0
      let tilt = 0.06 + random() * 0.46  // From straight up, towards the middle.
      return Piece(left: left, angle: -.pi / 2 + (left ? tilt : -tilt), speed: 1900 + random() * 1700, fall: 90 + random() * 120,
                   spin: (random() - 0.5) * 16, size: 7 + random() * 6, wobble: random() * .pi * 2, round: i % 5 == 0,
                   color: colors[(i / 2) % colors.count])
    }
  }()
  var body: some View {
    let mark: CGFloat = JourneyLayout.compact ? 112 : 150
    SceneClock(duration: Self.length, score: JourneyScores.youreIn, done: done) { t in
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        markView(t, size: mark)
        let rise = Ease.out(Ease.seg(t, Self.words, Self.words + 0.45)), line = Ease.out(Ease.seg(t, Self.words + 0.15, Self.words + 0.6))
        Text(name.isEmpty ? store.t("You’re in.") : String(format: store.t("You’re in, %@."), name))
          .font(.app(size: JourneyLayout.compact ? 34 : 40, weight: .bold)).tracking(-1).multilineTextAlignment(.center)
          .lineLimit(2).minimumScaleFactor(0.6).foregroundStyle(JourneyColor.text)
          .padding(.top, JourneyLayout.compact ? 24 : 34).opacity(rise).offset(y: (1 - rise) * 14)
        Text(store.t("Welcome to GymBlock Pro.")).font(.app(.body)).foregroundStyle(JourneyColor.secondary)
          .padding(.top, 6).opacity(line).offset(y: (1 - line) * 10)
        VStack(alignment: .leading, spacing: 14) {
          ForEach(Array(Self.rows.enumerated()), id: \.offset) { i, text in row(t, i, text) }
        }.fixedSize().padding(.top, JourneyLayout.compact ? 26 : 38)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity)
      // The confetti reaches the screen's edges and runs on down behind the button and off the
      // bottom of the screen (1 Nov 2026, at the user's request); it fires from the bottom corners.
      .background {
        Canvas { c, s in confetti(c, s, t) }.padding(.horizontal, -24).padding(.top, -120).padding(.bottom, -Self.below)
          .allowsHitTesting(false)
      }
    }
    .task {
      try? await Task.sleep(for: .seconds(JourneyMotion.settle + Self.ready))
      guard !Task.isCancelled else { return }
      done()
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel((name.isEmpty ? store.t("You’re in.") : String(format: store.t("You’re in, %@."), name)) + " "
                        + store.t("Welcome to GymBlock Pro.") + " " + Self.rows.map { store.t($0) }.joined(separator: ". "))
  }
  /// The mark: it drops, squashes as it lands, its keyhole lights emerald, a soft glow swells behind it
  /// and an emerald ring goes out from it.
  private func markView(_ t: Double, size: CGFloat) -> some View {
    let lit = Ease.seg(t, Self.lock, Self.lock + 0.18), ring = Ease.seg(t, Self.lock, Self.lock + 0.8)
    let u = t - Self.land
    let squash = u < 0 ? 0 : 0.12 * exp(-7 * u) * cos(22 * u)
    return ZStack {
      Circle().fill(RadialGradient(colors: [JourneyColor.signal.opacity(0.22), JourneyColor.signal.opacity(0)], center: .center, startRadius: 0, endRadius: size))
        .frame(width: size * 2, height: size * 2).scaleEffect(0.7 + 0.3 * Ease.out(lit) + 0.08 * Ease.bump(t, Self.lock, 0.5)).opacity(lit)
      Circle().stroke(JourneyColor.signal, lineWidth: 3).frame(width: size * 1.2, height: size * 1.2)
        .scaleEffect(0.85 + 1.2 * Ease.out(ring)).opacity(ring > 0 ? (1 - ring) * 0.7 : 0)
      ZStack {
        KettlebellShape(part: .iron).fill(JourneyColor.text, style: FillStyle(eoFill: true))
        KettlebellShape(part: .keyhole).fill(JourneyColor.signal).opacity(lit)
      }
      .frame(width: size, height: size)
      .scaleEffect(x: 1 + squash, y: 1 - squash, anchor: .bottom)
      .offset(y: -120 * (1 - pow(Ease.seg(t, 0, Self.land), 2)))
      .opacity(Ease.seg(t, 0, 0.12))
    }
    .frame(width: size, height: size)
  }
  private func row(_ t: Double, _ i: Int, _ text: String) -> some View {
    let k = Ease.out(Ease.seg(t, Self.row(i), Self.row(i) + 0.35)), pop = Ease.spring(t - Self.row(i), 16, 0.45)
    return HStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill").font(.system(size: 22, weight: .semibold))
        .symbolRenderingMode(.palette).foregroundStyle(JourneyColor.onAccent, JourneyColor.accent)
        .scaleEffect(max(0.001, pop))
      Text(store.t(text)).font(.app(.body, weight: .medium)).foregroundStyle(JourneyColor.text)
    }
    .opacity(k).offset(x: (1 - k) * -10)
  }
  private func confetti(_ c: GraphicsContext, _ s: CGSize, _ t: Double) {
    let u = t - Self.burst
    guard u > 0 else { return }
    let fade = 1 - Ease.seg(t, Self.length - 0.7, Self.length)
    // The volley slows in the air, then each piece flutters down at its own pace.
    let drag = (1 - exp(-3.2 * u)) / 3.2
    for p in Self.pieces {
      let x = (p.left ? 0 : s.width) + cos(p.angle) * p.speed * drag + 16 * sin(5 * u + p.wobble)
      // Fired from about the screen's bottom edge, well above the canvas's own.
      let y = s.height - Self.below + 200 + sin(p.angle) * p.speed * drag + p.fall * u + 0.5 * 140 * u * u
      var g = c
      g.opacity = fade
      g.translateBy(x: x, y: y)
      g.rotate(by: .radians(p.spin * u + p.wobble))
      // Paper turning in the air: its width breathes.
      let w = p.size * (p.round ? 1 : abs(cos(4 * u + p.wobble)) * 0.6 + 0.4), h = p.round ? p.size : p.size * 0.55
      let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
      g.fill(p.round ? Path(ellipseIn: rect) : Path(rect), with: .color(p.color))
    }
  }
}
