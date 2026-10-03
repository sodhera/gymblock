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
  func trainingPoints(splitID: UUID? = nil) -> [TrainingPoint] {
    data.history.filter { splitID == nil || $0.splitID == splitID }
      .filter { !$0.repSets.isEmpty }.sorted { $0.started < $1.started }.map {
        TrainingPoint(id: $0.id, date: $0.started, name: $0.name,
          reps: $0.totalReps, volumeKG: $0.volumeKG, sets: $0.repSets.count)
      }
  }
}
struct TrainingStatsView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var metric = 0
  @State private var bars = false
  @State private var splitID: UUID?
  private var points: [TrainingPoint] { store.trainingPoints(splitID: splitID) }
  private var unit: String { metric == 0 ? store.t("reps") : metric == 1 ? store.profile.unit : store.t("sets") }
  private func value(_ p: TrainingPoint) -> Double {
    metric == 0 ? Double(p.reps) : metric == 1
      ? GymStore.displayedWeight(p.volumeKG, unit: store.profile.unit) : Double(p.sets)
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(store.t("Training totals")).font(GymType.hero(32))
        if typeSize.isAccessibilitySize {
          VStack(alignment: .leading, spacing: 12) { scopePicker; stylePicker }
        } else {
          HStack { scopePicker; Spacer(); stylePicker }
        }
        Picker(store.t("Metric"), selection: $metric) {
          Text(store.t("Reps")).tag(0)
          Text(store.t("Weight moved")).tag(1)
          Text(store.t("Sets")).tag(2)
        }.pickerStyle(.segmented).accessibilityIdentifier("totals.metric")
        if points.isEmpty {
          Text(store.t("No rep-based workouts yet.")).foregroundStyle(GymColor.dim)
        } else {
          VStack(alignment: .leading, spacing: 8) {
            Text(formatNumber(points.reduce(0) { $0 + value($1) }) + " " + unit)
              .font(GymType.hero(36)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
              .contentTransition(.numericText())
              .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: metric)
              .accessibilityIdentifier("totals.amount")
            Text(store.t("Across") + " \(points.count) " + store.t("workouts"))
              .font(GymType.body(14)).foregroundStyle(GymColor.dim)
          }
          Chart(points) { p in
            if bars {
              BarMark(x: .value("Date", p.date), y: .value(unit, value(p)))
                .foregroundStyle(GymColor.red).cornerRadius(4)
            } else {
              LineMark(x: .value("Date", p.date), y: .value(unit, value(p)))
                .foregroundStyle(GymColor.red)
              PointMark(x: .value("Date", p.date), y: .value(unit, value(p)))
                .foregroundStyle(GymColor.red)
            }
          }.chartYScale(domain: .automatic(includesZero: true)).chartYAxisLabel(unit)
            .chartXAxis {
              AxisMarks(values: .automatic(desiredCount: typeSize.isAccessibilitySize ? 2 : 5)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
              }
            }
            .frame(height: 220).accessibilityIdentifier("totals.chart")
            // Changing units rebuilds the plot without interpolating incompatible axis scales.
            .transaction { $0.animation = nil }
          Text(store.t("Work performed, not a strength score. Completed sets include warm-ups; timed activities are separate."))
            .font(GymType.body(13)).foregroundStyle(GymColor.dim)
          if metric == 1 {
            Text(store.t("Sum of logged load × completed reps. Bodyweight adds no guessed load. Dumbbell load uses your per-dumbbell entry."))
              .font(GymType.body(13)).foregroundStyle(GymColor.dim)
          }
          DisclosureGroup(store.t("Workout values")) {
            ForEach(points.reversed()) { p in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(store.t(p.name))
                  Text(p.date, format: .dateTime.month(.abbreviated).day())
                    .font(GymType.body(12)).foregroundStyle(GymColor.dim)
                }
                Spacer()
                Text(formatNumber(value(p)) + " " + unit).monospacedDigit()
              }.padding(.vertical, 10)
            }
          }
        }
      }.padding(24)
    }.gymPage().navigationBarTitleDisplayMode(.inline)
  }
  private var scopePicker: some View {
    Picker(store.t("Workouts"), selection: $splitID) {
      Text(store.t("All workouts")).tag(Optional<UUID>.none)
      ForEach(store.data.workouts) { Text($0.name).tag(Optional($0.id)) }
    }.pickerStyle(.menu).font(GymType.body(16)).accessibilityIdentifier("totals.scope")
  }
  private var stylePicker: some View {
    Picker(store.t("View"), selection: $bars) {
      Text(store.t("Trend")).tag(false)
      Text(store.t("Bars")).tag(true)
    }.pickerStyle(.menu).font(GymType.body(16)).accessibilityIdentifier("totals.style")
  }
}
