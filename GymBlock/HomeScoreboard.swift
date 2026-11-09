import Charts
import SwiftUI

/// Home's head, after Cal AI's (9 Nov 2026, at the user's request): the mark and the name on the
/// left, the week streak in a glass pill on the right, and under them this week as seven dated
/// circles, Monday first. A trained day is filled in its split's colour, today sits lifted on a
/// white glass card with an ink ring, a past day missed is a dashed ring, and a day still to come
/// is faint. It replaces the quiet dots line at the top of Home.
struct HomeHeader: View {
  @EnvironmentObject private var store: GymStore
  let stats: HomeStats
  var body: some View {
    // Compact (9 Nov 2026, "it feels a bit large"): a 22-pt name, a 36-pt pill, 32-pt day rings.
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        BrandMark(size: 24)
        Text("GymBlock").font(.app(size: 22, weight: .bold)).tracking(-0.5).foregroundStyle(JourneyColor.text)
        Spacer(minLength: 12)
        streakPill
      }
      weekStrip
    }
  }

  /// The streak: a flame and the days in the run (since 9 Nov 2026, days as Cal AI counts them; two
  /// missed days in a row end it), 0 until there is one. It opens the streak page (`StreakPage`).
  private var streakPill: some View {
    NavigationLink { StreakPage() } label: { streakLabel }
      .buttonStyle(JourneyPressStyle())
      .accessibilityIdentifier("home.streak")
      .accessibilityLabel("\(stats.streakDays) " + store.t("day streak"))
  }
  private var streakLabel: some View {
    HStack(spacing: 6) {
      StreakFlame(size: 18)
      Text("\(stats.streakDays)").font(.app(.subheadline, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text)
    }
    .padding(.horizontal, 12).frame(height: 36)
    .journeyGlass(Capsule())
    .accessibilityElement(children: .ignore)
  }

  private var weekStrip: some View {
    let calendar = TrainingDays.calendar
    let monday = TrainingDays.monday(of: Date())
    let keys = TrainingDays.weekKeys(at: Date())
    let colors = store.dayColors
    let names = DateFormatter()
    names.locale = Locale(identifier: store.profile.language == "es" ? "es" : "en_US")
    names.setLocalizedDateFormatFromTemplate("EEE")
    return HStack(spacing: 0) {
      ForEach(0..<7, id: \.self) { d in
        let date = calendar.date(byAdding: .day, value: d, to: monday) ?? monday
        let on = stats.grid.last?[d] ?? false
        let today = d == stats.todayIndex
        let future = d > stats.todayIndex
        DayCell(name: names.string(from: date), number: calendar.component(.day, from: date),
                color: on ? Color.paper((colors[keys[d]] ?? .emerald).paper) : nil, today: today, future: future)
          .frame(maxWidth: .infinity)
      }
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("home.week")
    .accessibilityLabel("\(stats.thisWeek) \(store.t("of")) \(stats.goal) \(store.t("this week"))")
  }

  /// One day: its name over its number in a ring; today on its own white card.
  private struct DayCell: View {
    let name: String
    let number: Int
    let color: Color?
    let today: Bool
    let future: Bool
    var body: some View {
      VStack(spacing: 7) {
        Text(name).font(.app(.footnote, weight: today ? .semibold : .medium))
          .foregroundStyle(today ? JourneyColor.text : future ? JourneyColor.ink(0.3) : JourneyColor.secondary)
          .lineLimit(1).minimumScaleFactor(0.8)
        ZStack {
          if let color {
            Circle().fill(color)
          } else if today {
            Circle().strokeBorder(JourneyColor.ink(0.22), lineWidth: 2)
          } else if future {
            Circle().strokeBorder(JourneyColor.ink(0.1), lineWidth: 1.5)
          } else {
            Circle().strokeBorder(JourneyColor.ink(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
          }
          Text("\(number)").font(.app(.subheadline, weight: color != nil ? .semibold : .regular)).monospacedDigit()
            .foregroundStyle(color != nil ? Color.white : future ? JourneyColor.ink(0.3) : JourneyColor.text)
        }
        .frame(width: 32, height: 32)
      }
      .padding(.vertical, 8).padding(.horizontal, 4)
      .background {
        if today { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(JourneyColor.raised)
            .shadow(color: JourneyColor.ink(0.08), radius: 10, y: 4) }
      }
    }
  }
}


/// This week as one quiet line: seven small dots (emerald for a day trained, an ink ring on today)
/// and the streak beside them. Back at the top of Home on 12 Oct 2026, above the progress card.
struct WeekLine: View {
  @EnvironmentObject private var store: GymStore
  let stats: HomeStats
  var body: some View {
    let keys = TrainingDays.weekKeys(at: Date())
    let colors = store.dayColors
    return HStack(spacing: 14) {
      HStack(spacing: 7) {
        ForEach(0..<7, id: \.self) { d in
          let on = stats.grid.last?[d] ?? false
          let today = d == stats.todayIndex
          Circle().fill(on ? Color.paper((colors[keys[d]] ?? .emerald).paper) : today ? Color.clear : JourneyColor.ink(0.12))
            .overlay(Circle().strokeBorder(JourneyColor.text, lineWidth: today && !on ? 1.25 : 0))
            .frame(width: 9, height: 9)
        }
      }
      Text(label).font(.app(.subheadline, weight: .medium)).monospacedDigit()
        .foregroundStyle(JourneyColor.secondary)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("home.week")
    .accessibilityLabel(label + ", \(stats.thisWeek) \(store.t("of")) \(stats.goal) \(store.t("this week"))")
  }
  /// The truth, never an example: "Week 1" before the first workout, the streak once there is one,
  /// otherwise this week against the goal.
  private var label: String {
    // Singular on its own key: Spanish read "1 semanas de racha".
    if stats.streakWeeks == 1 { return store.t("1 week streak") }
    if stats.streakWeeks > 1 { return "\(stats.streakWeeks) " + store.t("week streak") }
    if stats.totalWorkouts == 0 { return store.t("Week 1") }
    return "\(stats.thisWeek) " + store.t("of") + " \(stats.goal) " + store.t("this week")
  }
}

/// One exercise's progress, almost cardless, straight on the paper (12 Oct 2026, the carousel page's
/// chart with the quiet line's restraint; no gridlines, scale or dates: the page's dots darken behind
/// the plot, and only the latest workout is a point, labelled with its value): the exercise and what's held constant, the gain in emerald, an emerald line over
/// a soft fill with each workout a point and the latest filled, a three-value scale, then where it
/// started and where it is now. The last eight comparable workouts only: same split, reps or load
/// held constant (`exerciseTrends`). With no line yet the same card holds an empty, labelled chart,
/// never sample numbers, so Home is never blank.
struct ProgressCard: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// Nil: nothing comparable yet.
  let trend: ExerciseTrend?
  /// Any finished workout yet; picks the empty card's line.
  let hasHistory: Bool
  @State private var drawn = false
  var body: some View {
    Group {
      if let trend { filled(trend) } else { empty }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(0.25)) { drawn = true } }
  }

  private func shown(_ trend: ExerciseTrend) -> [(date: Date, value: Double)] { Array(trend.points.suffix(8)) }

  private func filled(_ trend: ExerciseTrend) -> some View {
    let points = shown(trend)
    let values = points.map(\.value)
    let low = values.min() ?? 0, high = values.max() ?? 1
    let pad = max(1, (high - low) * 0.35)
    let domain = (low - pad)...(high + pad)
    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(store.t(trend.exercise.name)).font(.app(.headline, weight: .semibold)).foregroundStyle(JourneyColor.text).lineLimit(1)
          Text(trend.constant)
            .font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).lineLimit(1)
        }
        Spacer(minLength: 8)
        Text(gainText(points, trend)).font(.app(.headline, weight: .bold)).monospacedDigit()
          .foregroundStyle(gain(points) > 0 ? JourneyColor.signal : JourneyColor.secondary).fixedSize()
      }
      Chart {
        ForEach(Array(points.enumerated()), id: \.offset) { i, p in
          let y = drawn ? p.value : (values.first ?? 0)
          AreaMark(x: .value("Workout", i), yStart: .value("Floor", domain.lowerBound), yEnd: .value("Best", y))
            .foregroundStyle(LinearGradient(colors: [JourneyColor.signal.opacity(0.1), JourneyColor.signal.opacity(0)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
          LineMark(x: .value("Workout", i), y: .value("Best", y))
            .foregroundStyle(JourneyColor.signal).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        // Only the latest workout is a point, labelled with where it is now.
        PointMark(x: .value("Workout", points.count - 1), y: .value("Best", drawn ? (values.last ?? 0) : (values.first ?? 0)))
          .symbol { Circle().fill(JourneyColor.signal).frame(width: 10, height: 10) }
      }
      .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
      .chartXScale(domain: -0.12...Double(max(1, points.count - 1)) + 0.12)
      .chartYScale(domain: domain)
      .chartOverlay { proxy in
        // The latest value just above its point, its right edge on the point's.
        GeometryReader { geometry in
          if let plot = proxy.plotFrame, let at = proxy.position(for: (x: points.count - 1, y: values.last ?? 0)) {
            let origin = geometry[plot].origin
            Text(value(values.last ?? 0, trend)).font(.app(.footnote, weight: .semibold)).monospacedDigit()
              .foregroundStyle(JourneyColor.secondary).fixedSize()
              .frame(width: 140, alignment: .trailing)
              .position(x: origin.x + at.x - 70 + 5, y: origin.y + at.y - 20)
              .opacity(drawn ? 1 : 0).animation(.easeOut(duration: 0.3).delay(0.9), value: drawn)
          }
        }.allowsHitTesting(false)
      }
      .frame(height: 150)
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("home.progress")
    .accessibilityLabel(store.t(trend.exercise.name) + " " + trend.constant + ", " + gainText(points, trend) + ", " + value(values.last ?? 0, trend))
  }

  /// The same card with nothing invented: a faint dashed baseline and what will fill it.
  private var empty: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(spacing: 6) {
        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.signal)
        Text(store.t(hasHistory ? "Repeat a workout to see your progress" : "Start a workout to see your progress"))
          .font(.app(.subheadline, weight: .medium)).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
      }.frame(maxWidth: .infinity).frame(height: 132)
    }
    .accessibilityElement(children: .combine).accessibilityIdentifier("home.progress.empty")
  }

  /// The change over the shown workouts, zero when it's smaller than a plate: that is kg/lb rounding
  /// (24 lb is 10.89 kg), not progress.
  private func gain(_ points: [(date: Date, value: Double)]) -> Double {
    let change = (points.last?.value ?? 0) - (points.first?.value ?? 0)
    return abs(change) < (store.profile.unit == "lb" ? 0.45 : 0.2) ? 0 : change
  }
  /// "+2.5 kg", "+2 reps"; "Holding" when level; a drop says so in grey, never in red.
  private func gainText(_ points: [(date: Date, value: Double)], _ trend: ExerciseTrend) -> String {
    let change = gain(points)
    guard abs(change) > 0.001 else { return store.t("Holding") }
    let amount = trend.repMode ? "\(Int(abs(change).rounded())) " + store.t("reps") : formatNumber(abs(change)) + " " + store.profile.unit
    return (change > 0 ? "+" : "−") + amount
  }
  private func value(_ v: Double, _ trend: ExerciseTrend) -> String {
    trend.repMode ? "\(Int(v.rounded())) " + store.t("reps") : formatNumber(v) + " " + store.profile.unit
  }
}

/// Up to three exercises' progress in turn (12 Oct 2026): a page every 4 s with a slide, a swipe takes
/// over and holds the clock for 12 s, small dots beneath (the shown one a short emerald capsule). Reduce
/// Motion keeps it still; one exercise shows alone with no dots. Each page opens that exercise's progress.
struct ProgressCarousel: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let trends: [ExerciseTrend]
  @State private var page = 0
  @State private var heldUntil = Date.distantPast
  var body: some View {
    VStack(spacing: 12) {
      TabView(selection: $page) {
        ForEach(Array(trends.enumerated()), id: \.element.id) { i, trend in
          NavigationLink {
            ExerciseProgressView(exercise: trend.exercise, split: store.data.workouts.first { $0.id == trend.splitID })
          } label: { ProgressCard(trend: trend, hasHistory: true).padding(.horizontal, 24) }
            .buttonStyle(JourneyPressStyle()).tag(i).accessibilityIdentifier("home.trend.\(trend.exercise.id)")
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: 212)
      // Full width, so a page slides off the screen's edge rather than vanishing at the margin.
      .padding(.horizontal, -24)
      .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in heldUntil = Date().addingTimeInterval(12) })
      if trends.count > 1 {
        HStack(spacing: 6) {
          ForEach(trends.indices, id: \.self) { i in
            Capsule().fill(i == page ? JourneyColor.signal : JourneyColor.ink(0.14))
              .frame(width: i == page ? 18 : 6, height: 6)
          }
        }.animation(.spring(duration: 0.4, bounce: 0.1), value: page).accessibilityHidden(true)
      }
    }
    .accessibilityIdentifier("home.trends")
    .task(id: trends.map(\.id)) {
      if page >= trends.count { page = 0 }
      guard trends.count > 1, !reduceMotion else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled, Date() >= heldUntil else { continue }
        withAnimation(.spring(duration: 0.7, bounce: 0.08)) { page = (page + 1) % trends.count }
      }
    }
  }
}

/// The queued workout as the page's headline: a small "Up next" with a chevron (tap to change) and
/// the split's name large. What's ahead is on the plan Start workout slides up to (13 Oct 2026).
struct UpNext: View {
  @EnvironmentObject private var store: GymStore
  let split: Workout?
  /// A first-run title in place of the split's name ("Your first workout").
  var title: String? = nil
  /// Where the name sits: Home draws it once, floating, so this copy only holds the place.
  var heroSlot: String? = nil
  /// One quiet emerald link under the hero ("+ Set up a split").
  var link: (label: String, action: () -> Void)? = nil
  let change: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      hero
      if let link {
        Button(action: link.action) {
          HStack(spacing: 8) {
            Image(systemName: "plus").font(.system(.subheadline, weight: .semibold))
            Text(link.label).font(.app(.body, weight: .medium))
          }.foregroundStyle(JourneyColor.signal).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.hapticPlain).accessibilityIdentifier("home.setUpSplit")
      }
    }
  }
  private var hero: some View {
    Button(action: change) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 5) {
          Text(store.t("Up next"))
          Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
        }.font(.app(.subheadline, weight: .medium)).foregroundStyle(JourneyColor.signal)
        HeroTitle(text: name).heroSlot(heroSlot)
      }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("home.next")
      .accessibilityLabel(store.t("Up next") + ", " + name)
      .accessibilityHint(store.t("Choose another workout"))
  }
  private var name: String { title ?? split.map { store.t($0.name) } ?? store.t("Free workout") }
}

/// The workout's name as Home's headline and the plan's. Home draws one copy that glides between the
/// two places (13 Oct 2026: the name showed twice as the page slid up); each place keeps an
/// invisible copy that holds its room.
struct HeroTitle: View {
  @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56
  let text: String
  var body: some View {
    Text(text).font(.app(size: size, weight: .bold)).tracking(-1.2).foregroundStyle(JourneyColor.text)
      .lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.leading)
  }
}

extension View {
  /// A place the floating name can sit: invisible, reporting where it is in the pages (`HeroSlots`).
  @ViewBuilder func heroSlot(_ id: String?) -> some View {
    if let id {
      opacity(0).accessibilityHidden(true).background {
        GeometryReader { g in Color.clear.preference(key: HeroSlots.self, value: [id: g.frame(in: .named("pageContent"))]) }
      }
    } else {
      self
    }
  }
}

/// Time training, week by week. Opened from Home's time card.
struct TimeTrainingView: View {
  @EnvironmentObject private var store: GymStore
  private var points: [TrainingPoint] { store.trainingPoints() }
  private var weeks: [WeekTotal] {
    let since = Calendar.current.date(byAdding: .weekOfYear, value: -7, to: Date())
    let sessions = Dictionary(uniqueKeysWithValues: store.data.history.map { ($0.id, $0) })
    return weekTotals(points.filter { $0.date >= (since ?? .distantPast) }, since: since) { (sessions[$0.id]?.duration ?? 0) / 60 }
  }
  private var total: Int { Int(store.data.history.filter { !$0.completedSets.isEmpty }.reduce(0.0) { $0 + $1.duration } / 60) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
          Eyebrow(text: store.t("All time"))
          Text(JourneyFormat.minutes(Double(total))).font(.app(.largeTitle, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
          Text("\(store.data.history.filter { !$0.completedSets.isEmpty }.count) " + store.t("workouts")).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).journeySurface(cornerRadius: 22)
        VStack(alignment: .leading, spacing: 12) {
          Eyebrow(text: store.t("Minutes per week"))
          WeeklyBars(weeks: weeks, height: 160)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).journeySurface(cornerRadius: 22)
      }.padding(24)
    }.gymPage().navigationTitle(store.t("Time training")).navigationBarTitleDisplayMode(.inline).track(screen: "home.time")
  }
}
