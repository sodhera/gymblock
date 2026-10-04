import Charts
import SwiftUI

struct ExerciseProgressList: View {
  @EnvironmentObject private var store: GymStore
  @State private var scopeID: UUID?
  var title = "Exercise progress"
  init(scopeID: UUID? = nil, title: String = "Exercise progress") {
    _scopeID = State(initialValue: scopeID); self.title = title
  }
  private var scopes: [Workout] {
    var seen = Set<UUID>()
    return (store.data.workouts + store.data.history.compactMap { s in
      s.splitID.map { Workout(id: $0, name: s.name, exercises: s.exercises) }
    }).filter { seen.insert($0.id).inserted }
  }
  private var exercises: [Exercise] {
    var seen = Set<String>()
    return store.data.history.filter { $0.splitID == scopeID }.flatMap(\.sets).filter(\.completed)
      .map(\.exercise).filter { seen.insert($0.id).inserted }
  }
  var body: some View {
    List {
      if exercises.isEmpty { Text(store.t("No records in this scope")).foregroundStyle(GymColor.dim) }
      ForEach(exercises) { exercise in
        NavigationLink(store.t(exercise.name)) {
          ExerciseProgressView(exercise: exercise, split: scopes.first { $0.id == scopeID })
        }.accessibilityIdentifier("progress.exercise." + exercise.id)
      }
    }.gymPage().navigationTitle(store.t(title)).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Picker(store.t("Scope"), selection: $scopeID) {
            Text(store.t("Free workouts")).tag(Optional<UUID>.none)
            ForEach(scopes) { Text($0.name).tag(Optional($0.id)) }
          }.pickerStyle(.menu).accessibilityIdentifier("progress.scope")
        }
      }
  }
}

struct ExerciseProgressView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let exercise: Exercise
  var split: Workout? = nil
  @State private var repMode = true
  private var sessions: [Session] {
    store.data.history.filter { $0.splitID == split?.id }.sorted { $0.started < $1.started }
  }
  private var latest: LoggedSet? {
    sessions.reversed().first { $0.sets.contains { $0.exercise.id == exercise.id && $0.comparable } }?
      .sets.last { $0.exercise.id == exercise.id && $0.comparable }
  }
  private func comparable(repMode: Bool) -> [ProgressPoint] {
    guard let latest, !exercise.timed else { return [] }
    return sessions.compactMap { session in
      let sets = session.sets.filter {
        $0.exercise.id == exercise.id && $0.comparable &&
          (repMode ? abs($0.weightKG - latest.weightKG) < 0.001 : $0.reps == latest.reps)
      }
      let best = sets.max { repMode ? $0.reps < $1.reps : $0.weightKG < $1.weightKG }
      return best.map { ProgressPoint(sessionID: session.id, date: session.ended ?? session.started, weightKG: $0.weightKG, reps: $0.reps) }
    }
  }
  private var points: [ProgressPoint] { comparable(repMode: repMode) }
  private var records: [LoggedSet] { sessions.flatMap(\.sets).filter { $0.exercise.id == exercise.id && $0.completed } }
  private var unit: String { repMode ? store.t("reps") : store.profile.unit }
  private func amount(_ p: ProgressPoint) -> Double { repMode ? Double(p.reps) : GymStore.displayedWeight(p.weightKG, unit: store.profile.unit) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        Text(split?.name ?? store.t("Free workouts")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
        if comparable(repMode: true).count > 1 && comparable(repMode: false).count > 1 {
          Picker(store.t("Compare"), selection: $repMode) {
            Text(store.t("Reps")).tag(true); Text(store.t("Weight")).tag(false)
          }.pickerStyle(.segmented)
        }
        if let first = points.first, let last = points.last, points.count > 1 {
          comparison("Before", point: first, red: false)
          Divider()
          comparison("After", point: last, red: true)
          let difference = amount(last) - amount(first)
          Text((difference > 0 ? "+" : "") + formatNumber(difference) + " " + unit)
            .font(GymType.title(28)).foregroundStyle(GymColor.red).accessibilityIdentifier("progress.change")
          if let latest {
            Text(repMode ? store.t("Same weight") + " · " + formatNumber(GymStore.displayedWeight(latest.weightKG, unit: store.profile.unit)) + " " + store.profile.unit
                 : store.t("Same reps") + " · \(latest.reps)")
              .font(GymType.body(15)).foregroundStyle(GymColor.dim)
          }
          NavigationLink(store.t("All records")) { ComparisonHistory(points: points, repMode: repMode, unit: unit) }
            .frame(minHeight: 44).accessibilityIdentifier("progress.chart")
        } else {
          if !exercise.timed { Text(store.t("No matching comparison yet")).font(GymType.body(17)).foregroundStyle(GymColor.dim) }
          ForEach(records.reversed()) { set in
            HStack {
              Text(set.date, format: .dateTime.month(.abbreviated).day()).foregroundStyle(GymColor.dim)
              Spacer()
              Text(setValue(set, store: store)).monospacedDigit()
            }.padding(.vertical, 8)
          }
        }
      }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }.gymPage().navigationTitle(store.t(exercise.name)).navigationBarTitleDisplayMode(.inline)
      .onAppear { repMode = comparable(repMode: true).count > 1 || comparable(repMode: false).count < 2 }
  }
  private func comparison(_ label: String, point: ProgressPoint, red: Bool) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(store.t(label)).font(GymType.body(17)).foregroundStyle(GymColor.dim)
        Spacer()
        Text(point.date, format: .dateTime.month(.abbreviated).day()).font(GymType.body(13)).foregroundStyle(GymColor.dim)
      }
      Text(formatNumber(GymStore.displayedWeight(point.weightKG, unit: store.profile.unit)) + " " + store.profile.unit + " × \(point.reps)")
        .font(GymType.title(32)).foregroundStyle(red ? GymColor.red : GymColor.ink).monospacedDigit()
    }
  }
}

struct ComparisonHistory: View {
  @EnvironmentObject private var store: GymStore
  let points: [ProgressPoint]
  let repMode: Bool
  let unit: String
  private func value(_ point: ProgressPoint) -> Double { repMode ? Double(point.reps) : GymStore.displayedWeight(point.weightKG, unit: store.profile.unit) }
  var body: some View {
    List {
      if points.count > 1 {
        Chart(points) { point in
          LineMark(x: .value("Date", point.date), y: .value(unit, value(point))).foregroundStyle(GymColor.red)
          PointMark(x: .value("Date", point.date), y: .value(unit, value(point))).foregroundStyle(GymColor.red)
        }.chartYAxisLabel(unit).frame(height: 200).padding(.vertical, 12)
      }
      ForEach(points.reversed()) { point in
        HStack {
          Text(point.date, format: .dateTime.month(.abbreviated).day()); Spacer()
          Text(formatNumber(value(point)) + " " + unit).monospacedDigit()
        }
      }
    }.gymPage().navigationTitle(store.t("All records")).navigationBarTitleDisplayMode(.inline)
  }
}
