import SwiftUI

/// This week as one quiet line: seven small dots (emerald for a day trained, an ink ring on today)
/// and the streak beside them.
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
      Text(label).font(.system(.subheadline, weight: .medium)).monospacedDigit()
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
