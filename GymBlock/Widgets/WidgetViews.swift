import SwiftUI
import WidgetKit

/// One widget moment: the snapshot read at an entry's date. Every view works out its phase, dots,
/// streak and lines from this, so each timeline entry draws its own today ring, Monday reset, month
/// and stale state without the app.
struct WidgetGlance {
  enum Phase: Equatable { case setup, idle, running, paused, stale }
  let snapshot: WidgetSnapshot?
  let date: Date
  let phase: Phase

  init(_ snapshot: WidgetSnapshot?, at date: Date) {
    self.snapshot = snapshot
    self.date = date
    guard let s = snapshot, s.state != .setup else { phase = .setup; return }
    if s.state == .running, let r = s.running {
      // Stale first: a workout paused and then forgotten is still forgotten.
      phase = date >= r.activeUntil ? .stale : r.pausedAt != nil ? .paused : .running
    } else {
      phase = .idle
    }
  }

  /// The extension's own strings (the reader's system language), for when there's no snapshot to
  /// carry the app's: setup before the first write, the gallery and the placeholder.
  static func local(_ key: String) -> String { Bundle.main.localizedString(forKey: key, value: nil, table: nil) }

  var labels: WidgetSnapshot.Labels { snapshot?.labels ?? .init(t: Self.local) }
  var hero: String { snapshot?.hero ?? "" }
  var heroShort: String? { snapshot?.heroShort }
  /// Sample history is on show: marked wherever it shows, never passed off as the reader's.
  var sample: Bool { phase != .setup && snapshot?.sample == true }
  var days: Set<Int> { Set(snapshot?.days ?? []) }
  var week: [DayMark] { TrainingDays.week(at: date, days: days) }
  /// The split colour of a trained day; nil is emerald.
  func color(_ day: Int) -> SplitColor? { snapshot?.colors?[day].map { SplitColor(name: $0) } }
  var weekColors: [SplitColor?] { TrainingDays.weekKeys(at: date).map(color) }
  var thisWeek: Int { TrainingDays.thisWeek(at: date, days: days) }
  var streak: Int {
    guard let s = snapshot else { return 0 }
    return TrainingDays.streak(at: date, baseWeek: s.baseWeek, priorRun: s.priorRun, days: days)
  }
  /// A running workout opens the workout, even once it has gone stale (the app asks there).
  var route: AppRoute { phase == .running || phase == .paused || phase == .stale ? .workout : .home }
  /// The workout clock, ending where the stale entry takes over, so a forgotten workout never reads 14:32:10.
  var clock: ClosedRange<Date> {
    guard let r = snapshot?.running else { return date...date }
    return r.clockStart...max(r.clockStart, r.activeUntil)
  }
  var exercise: String { snapshot?.running?.exercise ?? labels.chooseExercise }

  /// The status line in words: what VoiceOver reads, and the clock's stand-in on the Always-On display.
  var statusWord: String {
    switch phase {
    case .setup: labels.openGymBlock
    case .idle: labels.upNext
    case .running: labels.training
    case .paused: labels.paused
    case .stale: labels.stillWorkingOut
    }
  }

  /// The grey line under the small and Lock Screen hero: the sample marker, "48 min last time" or
  /// "First time" when idle; the exercise while it runs. Sample history is marked only where it shows:
  /// a workout in progress is the reader's own, so it keeps its exercise.
  var caption: String? {
    switch phase {
    case .idle: sample ? labels.sampleData : snapshot?.caption
    case .running, .paused: exercise
    case .setup, .stale: nil
    }
  }

  /// The medium's last line. Its week row always shows, so with sample history it always says so.
  var detail: String {
    if sample { return labels.sampleData }
    switch phase {
    case .idle: return snapshot?.detail ?? ""
    case .running, .paused: return exercise
    case .setup, .stale: return ""
    }
  }

  /// Home's rule for the week line: the streak once there is one, "Week 1" before the first workout,
  /// otherwise this week against the goal.
  var weekLabel: String {
    let n = streak
    if n > 1 { return "\(n) " + labels.weekStreak }
    if n == 1 { return labels.weekStreakOne }
    guard let s = snapshot, s.hasHistory else { return labels.week1 }
    return "\(thisWeek) \(labels.of) \(s.goal) \(labels.thisWeek)"
  }

  /// No split and no workout yet: "Your first workout" stands alone on the inline line.
  var firstWorkout: Bool { phase == .idle && snapshot?.hasHistory == false && snapshot?.caption == nil }

  /// "October", in the device's language with its first letter raised, as on Profile.
  var monthName: String {
    let name = date.formatted(.dateTime.month(.wide))
    return name.prefix(1).uppercased(with: .current) + name.dropFirst()
  }
}

/// The small and medium status line (DM Sans 15 medium, one 19.5-pt line): "Up next" in emerald, the
/// workout clock in SF Pro (DM Sans digits would jitter), "Paused" or "Still working out?" in grey.
/// The clock gives way to "Training" on the Always-On display.
private struct GlanceStatus: View {
  let glance: WidgetGlance
  @Environment(\.widgetTone) private var tone
  @Environment(\.isLuminanceReduced) private var dimmed
  var body: some View {
    Group {
      if glance.phase == .running && !dimmed {
        Text(timerInterval: glance.clock, countsDown: false, showsHours: true)
          .font(.system(size: 15, weight: .semibold).monospacedDigit())
          .foregroundStyle(tone.ink)
          .multilineTextAlignment(.leading)
      } else if glance.phase == .running {
        words(glance.labels.training).foregroundStyle(tone.ink)
      } else if glance.phase == .paused {
        words(glance.labels.paused).foregroundStyle(tone.secondary)
      } else if glance.phase == .stale {
        words(glance.labels.stillWorkingOut).foregroundStyle(tone.secondary).minimumScaleFactor(0.75)
      } else {
        words(glance.labels.upNext).foregroundStyle(tone.signal).widgetAccentable()
      }
    }
    .lineLimit(1)
    .frame(maxWidth: .infinity, minHeight: 19.5, maxHeight: 19.5, alignment: .leading)
  }
  private func words(_ s: String) -> Text { Text(s).font(WidgetType.words(15, .medium)) }
}

/// What HeroFit lines the hero's first stem up with: the status line's first glyph.
private func statusGlyph(_ glance: WidgetGlance, dimmed: Bool) -> String {
  glance.phase == .running && !dimmed ? "0" : glance.statusWord
}

/// Before the app has written anything, or after log out or delete: the mark and one line, no names.
private struct GlanceSetup: View {
  let glance: WidgetGlance
  @Environment(\.widgetTone) private var tone
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      WidgetMark(32)
      Spacer(minLength: 8)
      Text(glance.labels.openGymBlock).font(WidgetType.words(15, .medium)).foregroundStyle(tone.secondary).lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(glance.labels.openGymBlock)
  }
}

/// This week as seven dots, Monday first: Home's week line, with the days to come faded.
struct WeekDots: View {
  let marks: [DayMark]
  var colors: [SplitColor?] = []
  var size: CGFloat = 9
  var gap: CGFloat = 7
  var body: some View {
    HStack(spacing: gap) {
      ForEach(Array(marks.enumerated()), id: \.offset) { i, mark in
        DayDot(mark: mark, size: size, color: i < colors.count ? colors[i] : nil)
      }
    }
  }
}

/// Up next, systemSmall: the status on top, the hero at the bottom, at most one grey line under it.
/// Only the status changes with the state; a rest looks like running (rests are the Live Activity's).
/// No week dots: they would repeat This month beside it.
struct UpNextSmallView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  @Environment(\.isLuminanceReduced) private var dimmed
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    if g.phase == .setup {
      GlanceSetup(glance: g)
    } else {
      GeometryReader { box in
        let caption = g.caption
        let fit = HeroFit.pick(hero: g.hero, short: g.heroShort, width: box.size.width, budget: box.size.height - 19.5 - 8,
                               ladder: [40, 36, 34, 30, 26, 22], maxLines: 2, preferFullDownTo: 30,
                               caption: caption != nil, captionRequired: g.phase == .idle && g.sample,
                               status: statusGlyph(g, dimmed: dimmed))
        VStack(alignment: .leading, spacing: 0) {
          GlanceStatus(glance: g)
          Spacer(minLength: 8)
          HeroText(fit: fit)
          if fit.showsCaption, let caption {
            Text(caption).font(WidgetType.words(13, .regular)).foregroundStyle(tone.secondary)
              .lineLimit(1).minimumScaleFactor(0.9).padding(.top, 2)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(([g.statusWord, g.hero] + (fit.showsCaption ? [caption ?? ""] : [])).filter { !$0.isEmpty }.joined(separator: ", "))
      }
    }
  }
}

/// Up next, systemMedium: Home in miniature with no button. The week row stays in every state (today
/// stays ringed until Finish), then the status, a one-line hero and the detail.
struct UpNextMediumView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  @Environment(\.isLuminanceReduced) private var dimmed
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    if g.phase == .setup {
      GlanceSetup(glance: g)
    } else {
      GeometryReader { box in
        let fit = HeroFit.pick(hero: g.hero, short: g.heroShort, width: box.size.width,
                               budget: box.size.height - 19.5 - 8 - 19.5 - 19.5,
                               ladder: [44, 40, 36, 34, 30, 26], maxLines: 1, preferFullDownTo: 34,
                               caption: false, captionRequired: false, status: statusGlyph(g, dimmed: dimmed))
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 14) {
            WeekDots(marks: g.week, colors: g.weekColors, size: 9, gap: 7)
            Text(g.weekLabel).font(WidgetType.words(15, .medium)).foregroundStyle(tone.secondary)
              .lineLimit(1).minimumScaleFactor(0.85)
          }
          .frame(height: 19.5)
          Spacer(minLength: 8)
          GlanceStatus(glance: g)
          HeroText(fit: fit)
          Text(g.detail).font(WidgetType.words(15, .regular)).foregroundStyle(tone.secondary)
            .lineLimit(1).minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, minHeight: 19.5, maxHeight: 19.5, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([g.weekLabel, g.statusWord, g.hero, g.detail].filter { !$0.isEmpty }.joined(separator: ", "))
      }
    }
  }
}

/// Up next, accessoryRectangular: SF Pro only, like the Lock Screen clock, and no background. The
/// hero gives way to its short form, then shrinks, rather than wrapping.
struct UpNextRectView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  @Environment(\.isLuminanceReduced) private var dimmed
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    if g.phase == .setup {
      HStack(spacing: 6) {
        WidgetMark(22)
        Text(g.labels.openGymBlock).font(.system(size: 15, weight: .semibold)).foregroundStyle(tone.ink).lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(g.labels.openGymBlock)
    } else {
      VStack(alignment: .leading, spacing: 1) {
        status(g)
        ViewThatFits(in: .horizontal) {
          Text(g.hero).lineLimit(1)
          Text(g.heroShort ?? g.hero).lineLimit(1)
          Text(g.heroShort ?? g.hero).lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.system(size: 22, weight: .bold)).foregroundStyle(tone.ink)
        // No "48 min last time" here (9 Nov 2026, the user: redundant on the Lock Screen).
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel([g.statusWord, g.hero].filter { !$0.isEmpty }.joined(separator: ", "))
    }
  }

  @ViewBuilder private func status(_ g: WidgetGlance) -> some View {
    let font = Font.system(size: 13, weight: .semibold)
    if g.phase == .running && !dimmed {
      Text(timerInterval: g.clock, countsDown: false, showsHours: true)
        .font(font.monospacedDigit()).foregroundStyle(tone.ink).multilineTextAlignment(.leading).lineLimit(1)
    } else if g.phase == .running {
      Text(g.labels.training).font(font).foregroundStyle(tone.ink).lineLimit(1)
    } else if g.phase == .idle {
      Text(g.labels.upNext).font(font).foregroundStyle(tone.signal).widgetAccentable().lineLimit(1)
    } else {
      Text(g.statusWord).font(font).foregroundStyle(tone.secondary).lineLimit(1)
    }
  }
}

/// Up next, accessoryInline: one line in the system font, each state with a shorter form to fall back to.
struct UpNextInlineView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.isLuminanceReduced) private var dimmed
  var body: some View {
    let g = WidgetGlance(snapshot, at: date), l = g.labels
    switch g.phase {
    case .setup:
      Text(l.openGymBlock)
    case .idle where g.sample:
      ViewThatFits { Text(l.sampleData + " · " + g.hero); Text(l.sampleData) }
    case .idle where g.firstWorkout:
      ViewThatFits { Text(g.hero); Text(g.heroShort ?? g.hero) }
    case .idle:
      ViewThatFits { Text(l.upNext + " · " + g.hero); Text(g.hero); Text(g.heroShort ?? g.hero) }
    case .running where dimmed:
      ViewThatFits { Text(g.hero + " · " + l.training) }
    case .running:
      // Text interpolation, not `+` (deprecated in iOS 26). Verify on the Lock Screen that the joined
      // clock ticks; the timer label is the fallback either way.
      ViewThatFits {
        Text("\(g.hero) · \(Text(timerInterval: g.clock, countsDown: false))")
        Label { Text(timerInterval: g.clock, countsDown: false) } icon: { Image(systemName: "timer") }
      }
    case .paused:
      ViewThatFits { Text(g.hero + " · " + l.paused) }
    case .stale:
      ViewThatFits { Text(l.stillWorkingOut) }
    }
  }
}

/// This month, systemSmall: every day as a dot under one line. The grid's geometry is the same for
/// every month length, first and last columns flush with the text; no weekday letters, no tally on
/// the face (VoiceOver gets it). A day counts once it has a completed set, as on Home.
struct MonthSmallView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    if g.phase == .setup {
      GlanceSetup(glance: g)
    } else {
      GeometryReader { box in
        let month = TrainingDays.month(at: date, days: g.days)
        let w = box.size.width
        let pitch = max(1, floor((box.size.height - 19.5 - 8) / 6))
        let dot = (min(w / 7, pitch) * 0.62).rounded()
        let rows = (month.lead + month.length + 6) / 7
        let trained = month.marks.filter { $0 == .trained }.count
        let line = g.sample ? g.labels.sampleData : g.monthName
        VStack(alignment: .leading, spacing: 0) {
          ZStack(alignment: .topLeading) {
            ForEach(0..<month.length, id: \.self) { i in
              let cell = month.lead + i
              DayDot(mark: month.marks[i], size: dot, color: g.color(TrainingDays.monthKey(i + 1, at: date)))
                .position(x: dot / 2 + CGFloat(cell % 7) * (w - dot) / 6, y: dot / 2 + CGFloat(cell / 7) * pitch)
            }
          }
          .frame(width: w, height: CGFloat(rows - 1) * pitch + dot, alignment: .topLeading)
          Spacer(minLength: 8)
          Text(line).font(WidgetType.words(15, .medium)).foregroundStyle(tone.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((g.sample ? g.labels.sampleData + ", " : "") + g.monthName + ", \(trained) "
          + (trained == 1 ? g.labels.workout : g.labels.workouts))
      }
    }
  }
}

/// This week, accessoryCircular: seven dots round the kettlebell, Monday at twelve o'clock, clockwise.
/// The mark's keyhole is always cut out here (the Lock Screen is one colour); never a number in the
/// middle. Sample history hides the ring, since a dot can't carry a label.
struct WeekCircularView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    GeometryReader { box in
      let side = min(box.size.width, box.size.height)
      let d = (side * 0.097).rounded()
      let r = side / 2 - d / 2 - side * 0.07
      let c = CGPoint(x: box.size.width / 2, y: box.size.height / 2)
      let mark = side * (g.phase == .setup ? 0.47 : 0.40)
      ZStack {
        if g.phase != .setup && !g.sample {
          let marks = g.week, colors = g.weekColors
          ForEach(0..<7, id: \.self) { i in
            let a = -Double.pi / 2 + Double(i) * 2 * .pi / 7
            DayDot(mark: marks[i], size: d, color: colors[i]).position(x: c.x + r * CGFloat(cos(a)), y: c.y + r * CGFloat(sin(a)))
          }
        }
        KettlebellShape(part: .ironCut).fill(tone.ink, style: FillStyle(eoFill: true))
          .frame(width: mark, height: mark).unredacted().accessibilityHidden(true)
          .position(c)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label(g))
  }

  /// "2 of 5 this week, 3 week streak".
  private func label(_ g: WidgetGlance) -> String {
    let l = g.labels
    if g.phase == .setup { return l.openGymBlock }
    if g.sample { return l.sampleData }
    guard let s = g.snapshot, s.hasHistory else { return l.week1 }
    let week = "\(g.thisWeek) \(l.of) \(s.goal) \(l.thisWeek)", n = g.streak
    return n > 1 ? week + ", \(n) " + l.weekStreak : n == 1 ? week + ", " + l.weekStreakOne : week
  }
}

/// Streak, systemSmall and systemMedium (9 Nov 2026, at the user's request, after Cal AI's streak
/// widget; the emerald card of 8 Nov is gone): the orange flame with the days in a row inside it,
/// on paper, the mark small and grey at the bottom left. The medium one says the words beside it.
/// The day streak counts the snapshot's days (the last 42), so it tops out at 42 here.
struct StreakView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  let medium: Bool
  @Environment(\.widgetTone) private var tone
  /// No card: the flame sits on the paper plate.
  static func card(_ tone: WidgetTone) -> Color? { nil }
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    if g.phase == .setup {
      GlanceSetup(glance: g)
    } else {
      let n = TrainingDays.dayStreak(at: date, days: Set(snapshot?.days ?? []))
      let words = g.sample ? g.labels.sampleData : (g.labels.dayStreak ?? "day streak")
      ZStack(alignment: .bottomLeading) {
        if medium {
          HStack(spacing: 16) {
            StreakFlame(count: n, size: 84)
            VStack(alignment: .leading, spacing: 2) {
              Text(verbatim: "\(n)").font(WidgetType.words(44, .bold)).tracking(-1).foregroundStyle(tone.ink).lineLimit(1)
              Text(words).font(WidgetType.words(15, .medium)).foregroundStyle(tone.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          StreakFlame(count: n, size: 74).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        WidgetMark(18).opacity(0.45)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(g.sample ? g.labels.sampleData : "\(n) " + words)
    }
  }
}


/// Home's head as a widget, systemMedium (9 Nov 2026, at the user's request): the mark and the name
/// on the left, the flame with the day streak on the right, and this week as seven dated circles
/// under them, Monday first: a trained day filled in its split's colour, today ringed, a missed day
/// a dashed ring, a day to come faint. The day names follow the phone's language.
struct WeekStripView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    if g.phase == .setup {
      GlanceSetup(glance: g)
    } else {
      let streak = TrainingDays.dayStreak(at: date, days: g.days)
      let calendar = TrainingDays.calendar
      let monday = TrainingDays.monday(of: date)
      let marks = g.week, colors = g.weekColors
      let names = Self.dayNames
      // Sized to fill the medium plate (the user, 9 Nov: space at the top and bottom).
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 7) {
          WidgetMark(24)
          Text(verbatim: "GymBlock").font(WidgetType.words(21, .bold)).tracking(-0.4).foregroundStyle(tone.ink)
          Spacer(minLength: 0)
          HStack(spacing: 5) {
            StreakFlame(size: 19)
            Text(verbatim: "\(streak)").font(WidgetType.words(17, .semibold)).foregroundStyle(tone.ink)
          }
        }
        Spacer(minLength: 10)
        HStack(spacing: 0) {
          ForEach(0..<7, id: \.self) { d in
            let day = calendar.date(byAdding: .day, value: d, to: monday) ?? monday
            WeekStripDay(name: names.string(from: day), number: calendar.component(.day, from: day), mark: marks[d], color: colors[d])
              .frame(maxWidth: .infinity)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(spoken(g, streak: streak))
    }
  }
  private static let dayNames: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("EEE")
    return f
  }()
  private func spoken(_ g: WidgetGlance, streak: Int) -> String {
    var out = g.sample ? g.labels.sampleData + ", " : ""
    out += "\(streak) " + (g.labels.dayStreak ?? "day streak")
    out += ", \(g.thisWeek) " + g.labels.of + " \(snapshot?.goal ?? 0) " + g.labels.thisWeek
    return out
  }
}

/// One day of the strip: its name over its number in a ring.
private struct WeekStripDay: View {
  let name: String
  let number: Int
  let mark: DayMark
  let color: SplitColor?
  @Environment(\.widgetTone) private var tone
  var body: some View {
    let today = mark == .today
    let faint = mark == .future
    VStack(spacing: 7) {
      Text(name).font(WidgetType.words(12, today ? .semibold : .medium))
        .foregroundStyle(nameColor(today: today, faint: faint))
        .lineLimit(1).minimumScaleFactor(0.7)
      ZStack {
        ring
        Text(verbatim: "\(number)").font(WidgetType.words(15, mark == .trained ? .semibold : .regular))
          .foregroundStyle(numberColor(faint: faint))
      }
      .frame(width: 36, height: 36)
    }
  }
  private func nameColor(today: Bool, faint: Bool) -> Color {
    if today { return tone.ink }
    return faint ? tone.ink.opacity(0.3) : tone.secondary
  }
  private func numberColor(faint: Bool) -> Color {
    if mark == .trained { return .white }
    return faint ? tone.ink.opacity(0.3) : tone.ink
  }
  @ViewBuilder private var ring: some View {
    switch mark {
    case .trained:
      let fill: Color = tone.fullColor ? (color ?? .emerald).paper.color(dark: tone.dark) : tone.signal
      Circle().fill(fill).widgetAccentable()
    case .today: Circle().strokeBorder(tone.ink.opacity(0.25), lineWidth: 2)
    case .future: Circle().strokeBorder(tone.ink.opacity(0.1), lineWidth: 1.5)
    case .past: Circle().strokeBorder(tone.ink.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
    }
  }
}


/// Streak on the Lock Screen, accessoryCircular (9 Nov 2026, at the user's request, in place of the
/// week's seven dots, which read as nothing): the flame over the days in a row, one colour as the
/// Lock Screen draws everything.
struct StreakCircularView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    GeometryReader { box in
      let side = min(box.size.width, box.size.height)
      VStack(spacing: -side * 0.02) {
        Image(systemName: "flame.fill").font(.system(size: side * 0.34, weight: .semibold)).foregroundStyle(tone.ink)
        Text(verbatim: g.phase == .setup ? "–" : "\(TrainingDays.dayStreak(at: date, days: g.days))")
          .font(WidgetType.words(side * 0.36, .bold)).foregroundStyle(tone.ink).lineLimit(1).minimumScaleFactor(0.6)
      }
      .frame(width: box.size.width, height: box.size.height)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label(g))
  }
  private func label(_ g: WidgetGlance) -> String {
    if g.phase == .setup { return g.labels.openGymBlock }
    if g.sample { return g.labels.sampleData }
    return "\(TrainingDays.dayStreak(at: date, days: g.days)) " + (g.labels.dayStreak ?? "day streak")
  }
}

/// Streak on the Lock Screen, accessoryRectangular: the flame, the number large, "day streak" under it.
struct StreakRectView: View {
  let snapshot: WidgetSnapshot?
  let date: Date
  @Environment(\.widgetTone) private var tone
  var body: some View {
    let g = WidgetGlance(snapshot, at: date)
    let n = TrainingDays.dayStreak(at: date, days: g.days)
    HStack(spacing: 10) {
      Image(systemName: "flame.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(tone.ink)
      VStack(alignment: .leading, spacing: 0) {
        Text(verbatim: g.phase == .setup ? "–" : "\(n)").font(WidgetType.words(26, .bold)).foregroundStyle(tone.ink).lineLimit(1)
        Text(g.phase == .setup ? g.labels.openGymBlock : g.sample ? g.labels.sampleData : (g.labels.dayStreak ?? "day streak"))
          .font(WidgetType.words(13, .medium)).foregroundStyle(tone.secondary).lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(g.phase == .setup ? g.labels.openGymBlock : "\(n) " + (g.labels.dayStreak ?? "day streak"))
  }
}
