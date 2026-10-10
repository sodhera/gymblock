import Charts
import SwiftUI

/// The streak with its flame, then this week's days. Opens History.
struct StreakCard: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let stats: HomeStats
  let action: () -> Void
  @State private var drawn = false
  var body: some View {
    Button(action: action) {
      VStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Image(systemName: "flame.fill").font(.system(.title2, weight: .bold))
          .foregroundStyle(stats.streakWeeks > 0 ? JourneyColor.signal : JourneyColor.tertiary)
          .symbolEffect(.bounce, value: drawn)
        Text("\(stats.streakWeeks)").font(.system(size: 44, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        Text(store.t("week streak")).font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
          .padding(.leading, 2)
        Spacer(minLength: 0)
      }.padding(.bottom, 14)
      HStack(spacing: 0) {
        ForEach(0..<7, id: \.self) { d in
          let on = stats.grid.last?[d] ?? false
          let today = d == stats.todayIndex
          VStack(spacing: 6) {
            Circle().fill(on ? JourneyColor.signal : JourneyColor.ink(0.08))
              .overlay(Circle().strokeBorder(JourneyColor.signal, lineWidth: today && !on ? 1.5 : 0))
              .overlay { if on { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(JourneyColor.onAccent) } }
              .frame(width: 22, height: 22).scaleEffect(drawn ? 1 : 0.5)
              .animation(.spring(duration: 0.45, bounce: 0.3).delay(Double(d) * 0.04), value: drawn)
            Text(["M", "T", "W", "T", "F", "S", "S"][d]).font(.caption2.weight(today ? .bold : .regular))
              .foregroundStyle(today ? JourneyColor.text : JourneyColor.tertiary)
          }.frame(maxWidth: .infinity)
        }
      }
      }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .journeyGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("home.week")
      .accessibilityLabel("\(stats.streakWeeks) " + store.t("week streak") + ", \(stats.thisWeek) " + store.t("of") + " \(stats.goal) " + store.t("this week") + ". " + store.t("Opens History"))
      .onAppear { withAnimation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.1).delay(0.1)) { drawn = true } }
  }
}

/// A small tappable card: a symbol, a value, and what it is. Opens its detail.
struct InfoCard: View {
  let symbol: String
  let value: String
  let label: String
  var detail: String = ""
  var id = ""
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Image(systemName: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(JourneyColor.signal)
          Spacer()
          Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(JourneyColor.tertiary)
        }
        Text(value).font(.system(.title3, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text).lineLimit(1).minimumScaleFactor(0.7)
          .padding(.top, 4)
        Text(label).font(.caption).foregroundStyle(JourneyColor.secondary).lineLimit(1).minimumScaleFactor(0.8)
        if !detail.isEmpty { Text(detail).font(.caption2).foregroundStyle(JourneyColor.tertiary).lineLimit(1) }
      }.padding(16).frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .journeyGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)
    }.buttonStyle(JourneyPressStyle())
      .accessibilityLabel(label + ", " + value + (detail.isEmpty ? "" : ", " + detail)).accessibilityIdentifier(id)
  }
}

/// One exercise per page, its best comparable set per workout as a line. Pages advance on their
/// own every few seconds with a slide; a swipe takes over and pauses the clock for a while.
struct ExerciseCarousel: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let trends: [ExerciseTrend]
  var example = false
  let open: (ExerciseTrend) -> Void
  @State private var page = 0
  @State private var pausedUntil = Date.distantPast
  @State private var drawn = false
  var body: some View {
    VStack(spacing: 10) {
      TabView(selection: $page) {
        ForEach(Array(trends.enumerated()), id: \.element.id) { i, trend in
          Button { open(trend) } label: { TrendPage(trend: trend, drawn: drawn, example: example) }
            .buttonStyle(JourneyPressStyle()).tag(i).accessibilityIdentifier("home.trend.\(trend.exercise.id)")
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .frame(height: 196)
      .animation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.08), value: page)
      .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { _ in pausedUntil = Date().addingTimeInterval(12) })
      .journeySurface(cornerRadius: 22)
      HStack(spacing: 6) {
        ForEach(trends.indices, id: \.self) { i in
          Capsule().fill(i == page ? JourneyColor.signal : JourneyColor.ink(0.14))
            .frame(width: i == page ? 18 : 6, height: 6)
            .animation(.spring(duration: 0.4, bounce: 0.1), value: page)
        }
      }.accessibilityHidden(true)
    }
    .accessibilityIdentifier("home.trends")
    .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.9).delay(0.3)) { drawn = true } }
    .task {
      guard trends.count > 1, !reduceMotion else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled, Date() >= pausedUntil else { continue }
        withAnimation(.spring(duration: 0.7, bounce: 0.08)) { page = (page + 1) % trends.count }
      }
    }
  }
}

private struct TrendPage: View {
  @EnvironmentObject private var store: GymStore
  let trend: ExerciseTrend
  let drawn: Bool
  let example: Bool
  private var unit: String { trend.repMode ? store.t("reps") : store.profile.unit }
  /// A tight scale, so a 60 → 70 climb looks like one.
  private var domain: ClosedRange<Double> {
    let values = trend.points.map(\.value)
    let low = values.min() ?? 0, high = values.max() ?? 1
    let pad = max(1, (high - low) * 0.35)
    return (low - pad)...(high + pad * 0.6)
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 1) {
          Text(store.t(trend.exercise.name)).font(.system(.headline, weight: .semibold)).foregroundStyle(JourneyColor.text).lineLimit(1)
          Text((example ? store.t("Example") + " · " : "") + trend.constant + (trend.splitName.map { " · " + store.t($0) } ?? ""))
            .font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).lineLimit(1)
        }
        Spacer()
        Text((trend.gain >= 0 ? "+" : "") + formatNumber(trend.gain) + " " + unit)
          .font(.system(.headline, weight: .bold)).monospacedDigit()
          .foregroundStyle(trend.gain > 0 ? JourneyColor.signal : JourneyColor.secondary)
      }
      Chart {
        ForEach(Array(trend.points.enumerated()), id: \.offset) { i, p in
          let x = Double(i), y = drawn ? p.value : (trend.points.first?.value ?? 0)
          AreaMark(x: .value("Workout", x), yStart: .value("Floor", domain.lowerBound), yEnd: .value("Value", y))
            .foregroundStyle(LinearGradient(colors: [JourneyColor.signal.opacity(0.22), JourneyColor.signal.opacity(0)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
          LineMark(x: .value("Workout", x), y: .value("Value", y))
            .foregroundStyle(JourneyColor.signal).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round)).interpolationMethod(.monotone)
          PointMark(x: .value("Workout", x), y: .value("Value", y))
            .symbol {
              if i == trend.points.count - 1 { Circle().fill(JourneyColor.signal).frame(width: 10, height: 10) }
              else { Circle().fill(JourneyColor.raised).overlay(Circle().strokeBorder(JourneyColor.signal, lineWidth: 2)).frame(width: 8, height: 8) }
            }
        }
      }
      .chartXAxis(.hidden)
      .chartYAxis { AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in AxisValueLabel().font(.system(size: 9)).foregroundStyle(JourneyColor.tertiary) } }
      .chartXScale(domain: -0.3...Double(max(1, trend.points.count - 1)) + 0.3)
      .chartYScale(domain: domain)
      .frame(height: 110)
      HStack {
        Text(trend.points.first.map { $0.date.formatted(.dateTime.day().month(.abbreviated)) } ?? "").font(.system(size: 9)).foregroundStyle(JourneyColor.tertiary)
        Spacer()
        Text(store.t("today")).font(.system(size: 9)).foregroundStyle(JourneyColor.tertiary)
      }
    }.padding(16).contentShape(Rectangle())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(store.t(trend.exercise.name) + ", " + trend.constant + ", " + formatNumber(trend.gain) + " " + unit)
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
          Text(JourneyFormat.minutes(Double(total))).font(.system(.largeTitle, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
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
