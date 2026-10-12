import Charts
import SwiftUI

/// This week as one quiet line: seven small dots (emerald for a day trained, an ink ring on today)
/// and the streak beside them. Back at the top of Home on 12 Oct 2026, above the progress card.
struct WeekLine: View {
  @EnvironmentObject private var store: GymStore
  let stats: HomeStats
  var body: some View {
    HStack(spacing: 14) {
      HStack(spacing: 7) {
        ForEach(0..<7, id: \.self) { d in
          let on = stats.grid.last?[d] ?? false
          let today = d == stats.todayIndex
          Circle().fill(on ? JourneyColor.signal : today ? Color.clear : JourneyColor.ink(0.12))
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
    if stats.streakWeeks > 0 { return "\(stats.streakWeeks) " + store.t("week streak") }
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
      .background(DotField())
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
      }.frame(maxWidth: .infinity).frame(height: 132).background(DotField(hole: CGSize(width: 330, height: 96)))
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

/// The page's own dot grid, a little darker, inside these bounds: the chart's scale without drawing lines. The
/// dots sit exactly on `DotGrid`'s 22-pt lattice (screen-anchored, columns centred) and ease in over
/// three dots from the edges, so the page's dots darken into the field with no border. Assumes the view is centred horizontally, as Home is.
struct DotField: View {
  /// A soft oval gap in the middle, so a line of text over the field stays clean.
  var hole: CGSize? = nil
  var body: some View {
    GeometryReader { g in
      let frame = g.frame(in: .global)
      Canvas { context, size in
        let step: CGFloat = 22, radius: CGFloat = 1.2, feather: CGFloat = 66
        let screenWidth = frame.maxX + frame.minX
        let originX = screenWidth.truncatingRemainder(dividingBy: step) / 2
        var y = (((frame.minY - step / 2) / step).rounded(.up)) * step + step / 2
        while y <= frame.maxY {
          var x = (((frame.minX - originX) / step).rounded(.up)) * step + originX
          while x <= frame.maxX {
            let edge = min(x - frame.minX, frame.maxX - x, y - frame.minY, frame.maxY - y)
            // Smoothstep from the page's own dots at the edge to the field's full tone inside.
            let ramp = min(1, max(0, edge / feather))
            var fade = ramp * ramp * (3 - 2 * ramp)
            let local = CGPoint(x: x - frame.minX, y: y - frame.minY)
            if let hole {
              let dx = (local.x - size.width / 2) / (hole.width / 2), dy = (local.y - size.height / 2) / (hole.height / 2)
              fade *= min(1, max(0, (hypot(dx, dy) - 1) / 0.35))
            }
            context.fill(Path(ellipseIn: CGRect(x: local.x - radius, y: local.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(JourneyColor.ink(0.17 * fade)))
            x += step
          }
          y += step
        }
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}

/// The queued workout as the page's headline: a small "Up next" with a chevron (tap to change),
/// the split's name large, and one quiet line of what's ahead.
struct UpNext: View {
  @EnvironmentObject private var store: GymStore
  @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 56
  let split: Workout?
  let detail: String
  /// A first-run title in place of the split's name ("Your first workout").
  var title: String? = nil
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
        }.buttonStyle(.plain).accessibilityIdentifier("home.setUpSplit")
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
        Text(title ?? split.map { store.t($0.name) } ?? store.t("Free workout")).font(.app(size: heroSize, weight: .bold)).tracking(-1.2)
          .foregroundStyle(JourneyColor.text).lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.leading)
        Text(detail).font(.app(.body)).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(2)
      }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("home.next")
      .accessibilityHint(store.t("Choose another workout"))
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
