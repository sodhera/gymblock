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
struct TrainingStatsView: View {
  @EnvironmentObject private var store: GymStore
  @State private var splitID: UUID?
  @State private var fourWeeks: Bool
  let initialMetric: Int
  init(initialMetric: Int = 0, initialFourWeeks: Bool = true) {
    self.initialMetric = initialMetric; _fourWeeks = State(initialValue: initialFourWeeks)
  }
  private var points: [TrainingPoint] {
    store.trainingPoints(splitID: splitID, since: fourWeeks ? Calendar.current.date(byAdding: .day, value: -28, to: Date()) : nil)
  }
  private var weeks: [TrainingPoint] {
    let groups = Dictionary(grouping: points) { Calendar.current.dateInterval(of: .weekOfYear, for: $0.date)!.start }
    return groups.map { date, values in
      TrainingPoint(id: values[0].id, date: date, name: "", reps: values.reduce(0) { $0 + $1.reps },
                    volumeKG: values.reduce(0) { $0 + $1.volumeKG }, sets: values.reduce(0) { $0 + $1.sets })
    }.sorted { $0.date < $1.date }
  }
  private var title: String { initialMetric == 0 ? "Reps" : initialMetric == 1 ? "Weight moved" : "Sets" }
  private var unit: String { initialMetric == 0 ? store.t("reps") : initialMetric == 1 ? store.profile.unit : store.t("sets") }
  private func value(_ p: TrainingPoint) -> Double {
    initialMetric == 0 ? Double(p.reps) : initialMetric == 1 ? GymStore.displayedWeight(p.volumeKG, unit: store.profile.unit) : Double(p.sets)
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        Text(store.t(splitID == nil ? "All workouts" : store.data.workouts.first { $0.id == splitID }?.name ?? "Split"))
          .font(GymType.body(15)).foregroundStyle(GymColor.dim)
        if points.isEmpty { Text(store.t("No workouts in this period")).foregroundStyle(GymColor.dim) }
        else {
          Text(formatNumber(points.reduce(0) { $0 + value($1) }) + " " + unit).font(GymType.title(36)).monospacedDigit()
            .accessibilityIdentifier("totals.amount")
          Chart(weeks) { point in
            BarMark(x: .value("Week", point.date, unit: .weekOfYear), y: .value(unit, value(point))).foregroundStyle(GymColor.red).cornerRadius(3)
          }.chartYScale(domain: .automatic(includesZero: true)).chartYAxisLabel(unit).frame(height: 220)
            .accessibilityIdentifier("totals.chart")
          DisclosureGroup(store.t("Workout values")) {
            ForEach(points.reversed()) { point in
              HStack {
                Text(point.date, format: .dateTime.month(.abbreviated).day()); Spacer()
                Text(formatNumber(value(point)) + " " + unit).monospacedDigit()
              }.padding(.vertical, 8)
            }
          }
          if initialMetric == 1 {
            DisclosureGroup(store.t("How it’s counted")) {
              Text(store.t("Logged weight × completed reps. Bodyweight adds no estimated load; dumbbell weight uses your per-dumbbell entry."))
                .font(GymType.body(15)).foregroundStyle(GymColor.dim)
            }
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
