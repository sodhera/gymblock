import Charts
import SwiftUI

struct TrainingPoint: Identifiable {
  let id: UUID
  let date: Date
  let name: String
  let reps: Int
  let volumeKG: Double
  let sets: Int
}
extension GymStore {
  func trainingPoints(splitID: UUID? = nil, since: Date? = nil) -> [TrainingPoint] {
    data.history.filter {
      (splitID == nil || $0.splitID == splitID) && (since == nil || $0.started >= since!)
    }
    .filter { !$0.repSets.isEmpty }.sorted { $0.started < $1.started }.map {
      TrainingPoint(
        id: $0.id, date: $0.started, name: $0.name,
        reps: $0.totalReps, volumeKG: $0.volumeKG, sets: $0.repSets.count)
    }
  }
}

/// One calendar week's total. `current` marks the week that contains today.
struct WeekTotal: Identifiable {
  var id: Date { start }
  let start: Date
  let value: Double
  let current: Bool
}
/// One bucket per calendar week from `since` (or the first workout) up to this week, empty weeks
/// included, so the bars always show the whole period and not just the weeks with training.
func weekTotals(_ points: [TrainingPoint], since: Date?, value: (TrainingPoint) -> Double) -> [WeekTotal] {
  let calendar = Calendar.current
  guard let currentStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return [] }
  let firstDate = since ?? points.first?.date ?? Date()
  guard var cursor = calendar.dateInterval(of: .weekOfYear, for: firstDate)?.start else { return [] }
  var totals: [Date: Double] = [:]
  for point in points {
    let week = calendar.dateInterval(of: .weekOfYear, for: point.date)?.start ?? currentStart
    totals[week, default: 0] += value(point)
  }
  var weeks: [WeekTotal] = []
  while cursor <= currentStart && weeks.count < 260 {
    weeks.append(WeekTotal(start: cursor, value: totals[cursor] ?? 0, current: cursor == currentStart))
    guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) else { break }
    cursor = next
  }
  return weeks
}

/// Weekly bars on glass: white bars, this week in red, a quiet trailing axis and no clutter.
struct WeeklyBars: View {
  let weeks: [WeekTotal]
  var height: CGFloat = 150
  var body: some View {
    let xValues: AxisMarkValues = weeks.count <= 6 ? .stride(by: .weekOfYear) : .automatic(desiredCount: 4)
    Chart(weeks) { week in
      BarMark(x: .value("Week", week.start, unit: .weekOfYear), y: .value("Total", week.value))
        .foregroundStyle(week.current ? JourneyColor.signal : JourneyColor.text)
        .cornerRadius(4)
    }
    .chartYScale(domain: .automatic(includesZero: true))
    .chartXAxis {
      AxisMarks(values: xValues) { _ in
        AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: true)
          .font(.caption2).foregroundStyle(JourneyColor.tertiary)
      }
    }
    .chartYAxis {
      AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
        AxisGridLine().foregroundStyle(JourneyColor.hairline)
        AxisValueLabel().font(.caption2).foregroundStyle(JourneyColor.tertiary)
      }
    }
    .frame(height: height)
  }
}

/// One metric over time: the period total, its weekly bars and every workout's value.
struct TrainingStatsView: View {
  @EnvironmentObject private var store: GymStore
  @State private var splitID: UUID?
  @State private var fourWeeks: Bool
  let initialMetric: Int
  init(initialMetric: Int = 0, initialFourWeeks: Bool = true) {
    self.initialMetric = initialMetric; _fourWeeks = State(initialValue: initialFourWeeks)
  }
  private var since: Date? { fourWeeks ? Calendar.current.date(byAdding: .day, value: -28, to: Date()) : nil }
  private var points: [TrainingPoint] { store.trainingPoints(splitID: splitID, since: since) }
  private var weeks: [WeekTotal] { weekTotals(points, since: since, value: value) }
  private var title: String { initialMetric == 0 ? "Reps" : initialMetric == 1 ? "Weight moved" : "Sets" }
  private var unit: String { initialMetric == 0 ? store.t("reps") : initialMetric == 1 ? store.profile.unit : store.t("sets") }
  private var scopeName: String {
    store.t(splitID == nil ? "All workouts" : store.data.workouts.first { $0.id == splitID }?.name ?? "Split")
  }
  private func value(_ p: TrainingPoint) -> Double {
    initialMetric == 0 ? Double(p.reps) : initialMetric == 1 ? GymStore.displayedWeight(p.volumeKG, unit: store.profile.unit) : Double(p.sets)
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if points.isEmpty {
          Eyebrow(text: scopeName)
          Text(store.t("No workouts in this period")).font(JourneyType.option).foregroundStyle(JourneyColor.secondary)
        } else {
          VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
              Eyebrow(text: scopeName + " · " + store.t(fourWeeks ? "Last 4 weeks" : "All time"))
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatNumber(points.reduce(0) { $0 + value($1) }.rounded()))
                  .font(.system(.largeTitle, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
                  .lineLimit(1).minimumScaleFactor(0.5)
                  .accessibilityIdentifier("totals.amount")
                Text(unit).font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
              }
            }
            WeeklyBars(weeks: weeks, height: 170).accessibilityIdentifier("totals.chart")
          }.padding(20).frame(maxWidth: .infinity, alignment: .leading).journeySurface()
          VStack(alignment: .leading, spacing: 0) {
            Eyebrow(text: store.t("Workouts")).padding(.top, 16).padding(.bottom, 4)
            ForEach(Array(points.reversed().enumerated()), id: \.element.id) { index, point in
              if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
              HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(point.date, format: .dateTime.day().month(.abbreviated)).font(.subheadline).monospacedDigit()
                  .foregroundStyle(JourneyColor.secondary).frame(width: 64, alignment: .leading)
                Text(store.t(point.name)).font(.body).foregroundStyle(JourneyColor.text).lineLimit(1)
                Spacer(minLength: 8)
                Text(formatNumber(value(point)) + " " + unit).font(.system(.subheadline, weight: .medium)).monospacedDigit()
                  .foregroundStyle(JourneyColor.text).lineLimit(1)
              }.padding(.vertical, 12).accessibilityElement(children: .combine)
            }
          }.padding(.horizontal, 20).padding(.bottom, 6).frame(maxWidth: .infinity, alignment: .leading).journeySurface()
          if initialMetric == 1 {
            Text(store.t("Logged weight × completed reps. Bodyweight adds no estimated load; dumbbell weight uses your per-dumbbell entry."))
              .font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 4)
          }
        }
      }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }.gymPage().navigationTitle(store.t(title)).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Picker(store.t("Period"), selection: $fourWeeks) {
              Text(store.t("Last 4 weeks")).tag(true); Text(store.t("All time")).tag(false)
            }
            Picker(store.t("Scope"), selection: $splitID) {
              Text(store.t("All workouts")).tag(Optional<UUID>.none)
              ForEach(store.data.workouts) { Text($0.name).tag(Optional($0.id)) }
            }
          } label: { Text(store.t(fourWeeks ? "Last 4 weeks" : "All time")) }
            .accessibilityLabel(store.t("Filter")).accessibilityIdentifier("totals.filter")
        }
      }
  }
}
