import Charts
import SwiftUI

/// One exercise's progress as a quiet line, in place of the week dots (11 Oct 2026): the exercise
/// and what's held constant, the gain in emerald, the line itself (no axes; the latest workout a dot),
/// then where it started and where it is now. Only comparable sets, from the same split with the
/// reps or the load held constant (`exerciseTrends`). Home shows it only once there is a line to
/// draw: a new account sees no empty chart, and the first real gain is what brings it in.
struct ProgressLine: View {
  @EnvironmentObject private var store: GymStore
  let trend: ExerciseTrend
  var body: some View {
    chart(trend).accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityIdentifier("home.progress")
  }

  /// The last eight comparable workouts.
  private func shown(_ trend: ExerciseTrend) -> [(date: Date, value: Double)] { Array(trend.points.suffix(8)) }

  private func chart(_ trend: ExerciseTrend) -> some View {
    let points = shown(trend)
    let values = points.map(\.value)
    let low = values.min() ?? 0, high = values.max() ?? 0
    let pad = max((high - low) * 0.25, trend.repMode ? 1 : 1.25)
    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(store.t(trend.exercise.name)).font(.system(.subheadline, weight: .medium)).foregroundStyle(JourneyColor.secondary)
          .lineLimit(1)
        Text(trend.constant).font(.subheadline).foregroundStyle(JourneyColor.tertiary).lineLimit(1)
        Spacer(minLength: 8)
        Text(gainText(points, trend)).font(.system(.subheadline, weight: .semibold)).monospacedDigit()
          .foregroundStyle(gain(points) > 0 ? JourneyColor.signal : JourneyColor.secondary).fixedSize()
      }
      Chart {
        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
          LineMark(x: .value("Workout", index), y: .value("Best", point.value))
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .foregroundStyle(JourneyColor.ink(0.5))
        }
        PointMark(x: .value("Workout", points.count - 1), y: .value("Best", values.last ?? 0))
          .symbolSize(70).foregroundStyle(JourneyColor.signal)
      }
      .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
      .chartXScale(domain: 0...max(1, points.count - 1), range: .plotDimension(padding: 5))
      .chartYScale(domain: (low - pad)...(high + pad))
      .frame(height: 52)
      HStack {
        Text(points.first?.date.formatted(.dateTime.month(.abbreviated).day()) ?? "")
        Spacer()
        Text(value(values.last ?? 0, trend))
      }.font(.footnote).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
    }
  }

  private func gain(_ points: [(date: Date, value: Double)]) -> Double { (points.last?.value ?? 0) - (points.first?.value ?? 0) }
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
  private var label: String {
    let points = shown(trend)
    return store.t(trend.exercise.name) + " " + trend.constant + ", " + gainText(points, trend) + ", " + value(points.last?.value ?? 0, trend)
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
            Text(link.label).font(.system(.body, weight: .medium))
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
        }.font(.system(.subheadline, weight: .medium)).foregroundStyle(JourneyColor.signal)
        Text(title ?? split.map { store.t($0.name) } ?? store.t("Free workout")).font(.system(size: heroSize, weight: .bold)).tracking(-1.2)
          .foregroundStyle(JourneyColor.text).lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.leading)
        Text(detail).font(.body).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(2)
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
