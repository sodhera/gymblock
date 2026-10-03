import Charts
import SwiftUI

struct ProgressView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var splitID: UUID?
  @State private var history = false
  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 24) {
          Text(store.t("Progress")).font(GymType.hero(32)).accessibilityAddTraits(.isHeader)
          if !store.data.workouts.isEmpty {
            Picker(store.t("Split"), selection: $splitID) {
              ForEach(store.data.workouts) { Text($0.name).tag(Optional($0.id)) }
            }.pickerStyle(.menu).font(GymType.title(22)).accessibilityIdentifier("progress.split")
            if let split = store.data.workouts.first(where: { $0.id == splitID }) {
              VStack(spacing: 0) {
                ForEach(split.exercises) { exercise in
                  NavigationLink {
                    ExerciseProgressView(exercise: exercise, split: split)
                  } label: {
                    HStack(spacing: 16) {
                      VStack(alignment: .leading, spacing: 6) {
                        Text(store.t(exercise.name)).font(GymType.title(19)).foregroundStyle(
                          GymColor.ink)
                        if let set = store.latestSet(for: exercise, split: split) {
                          Text(setValue(set, store: store)).font(GymType.body(14)).foregroundStyle(
                            GymColor.dim)
                        }
                      }
                      Spacer(minLength: 0)
                      Image(systemName: "arrow.up.right").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(GymColor.red)
                    }.frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                  }.accessibilityIdentifier("progress.exercise." + exercise.id)
                  if exercise.id != split.exercises.last?.id { Divider().opacity(0.45) }
                }
              }.padding(.horizontal, 20).gymCard()
            }
          } else {
            Text(store.t("Add a split to compare its exercises.")).foregroundStyle(GymColor.dim)
          }
          NavigationLink {
            HistoryView()
          } label: {
            Label(store.t("History"), systemImage: "clock.arrow.circlepath").font(GymType.label(16))
              .frame(minHeight: 44)
          }.accessibilityIdentifier("progress.history")
        }.padding(24)
      }.gymPage().navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("progress.done")
          }
        }
        .onAppear {
          if splitID == nil {
            splitID = store.profile.preferredSplitID ?? store.data.workouts.first?.id
          }
        }
    }
  }
}
struct ExerciseProgressView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let exercise: Exercise
  let split: Workout
  @State private var repMode = false
  @State private var shown = 0.0
  private var latest: LoggedSet? { store.latestSet(for: exercise, split: split) }
  private var previousSet: LoggedSet? {
    guard let latest else { return nil }
    let previousSession = store.splitSessions(split).filter {
      !$0.sets.contains { $0.id == latest.id }
        && $0.sets.contains { $0.exercise.id == exercise.id && $0.comparable }
    }.max { $0.started < $1.started }
    return previousSession?.sets.last { $0.exercise.id == exercise.id && $0.comparable }
  }
  private var weights: [ProgressPoint] {
    store.progress(for: exercise, split: split, reps: latest?.reps ?? 0)
  }
  private var repetitions: [ProgressPoint] {
    store.repProgress(for: exercise, split: split, weightKG: latest?.weightKG ?? 0)
  }
  private var points: [ProgressPoint] { repMode ? repetitions : weights }
  private func value(_ point: ProgressPoint) -> Double {
    repMode
      ? Double(point.reps) : GymStore.displayedWeight(point.weightKG, unit: store.profile.unit)
  }
  private var first: Double { points.first.map(value) ?? 0 }
  private var last: Double { points.last.map(value) ?? 0 }
  private var ceiling: Double { max(1, points.map(value).max() ?? 1) * 1.15 }
  private var unit: String { repMode ? store.t("reps") : store.profile.unit }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        Text(store.t(exercise.name)).font(GymType.hero(32)).accessibilityAddTraits(.isHeader)
        if let latest, exercise.timed {
          Text(formatNumber(latest.minutes) + " " + store.t("min")).font(
            GymType.hero(34).monospacedDigit())
          Text(store.t("Latest activity duration")).foregroundStyle(GymColor.dim)
        } else if let latest, let previous = previousSet, weights.count < 2 && repetitions.count < 2
        {
          VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Previous workout")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
            Text(setValue(previous, store: store)).font(GymType.hero(24))
            Text(previous.date, format: .dateTime.month(.abbreviated).day()).font(GymType.body(12))
              .foregroundStyle(GymColor.dim)
          }
          VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Latest workout")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
            Text(setValue(latest, store: store)).font(GymType.hero(24))
            Text(latest.date, format: .dateTime.month(.abbreviated).day()).font(GymType.body(12))
              .foregroundStyle(GymColor.dim)
          }
          Text(store.t("Different weight or reps")).font(GymType.body(15)).foregroundStyle(
            GymColor.dim)
          NavigationLink(store.t("History")) { ExerciseRecords(exercise: exercise, split: split) }
        } else if let latest, !points.isEmpty {
          Text(
            repMode
              ? store.t("Same weight:") + " "
                + formatNumber(GymStore.displayedWeight(latest.weightKG, unit: store.profile.unit))
                + " " + store.profile.unit : store.t("Same reps:") + " \(latest.reps)"
          ).font(GymType.body(15)).foregroundStyle(GymColor.dim)
          if weights.count > 1 && repetitions.count > 1 {
            Picker(store.t("Compare"), selection: $repMode) {
              Text(store.t("Weight")).tag(false)
              Text(store.t("Reps")).tag(true)
            }.pickerStyle(.segmented)
          }
          comparison(
            title: "First", amount: first, date: points.first?.date,
            tint: GymColor.dim.opacity(0.5))
          comparison(title: "Latest", amount: shown, date: points.last?.date, tint: GymColor.red)
          if points.count > 1 {
            Text((last > first ? "+" : "") + formatNumber(last - first) + " " + unit).font(
              GymType.hero(24)
            ).monospacedDigit().accessibilityIdentifier("progress.change")
          } else {
            Text(store.t("First recorded set")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
          }
          NavigationLink(store.t("History")) {
            ComparisonHistory(points: points, repMode: repMode, unit: unit)
          }.frame(minHeight: 44).accessibilityIdentifier("progress.chart")
        } else {
          Text(store.t("No comparable sets yet.")).foregroundStyle(GymColor.dim)
        }
      }.padding(24)
    }.gymPage().navigationTitle(split.name).navigationBarTitleDisplayMode(.inline)
      .task {
        repMode = weights.count < 2 && repetitions.count > 1
        animate()
      }
      .onChange(of: repMode) { _, _ in animate() }
  }
  private func comparison(title: String, amount: Double, date: Date?, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(store.t(title)).font(GymType.body(15)).foregroundStyle(GymColor.dim)
          if let date {
            Text(date, format: .dateTime.month(.abbreviated).day()).font(GymType.body(12))
              .foregroundStyle(
                GymColor.dim)
          }
        }
        Spacer()
        Text(formatNumber(amount) + " " + unit).font(GymType.hero(24)).monospacedDigit()
          .contentTransition(.numericText())
      }
      GeometryReader { proxy in
        Rectangle().fill(tint).frame(width: max(0, proxy.size.width * min(1, amount / ceiling)))
          .clipShape(Capsule())
      }.frame(height: 10)
    }.padding(20).gymCard()
  }
  private func animate() {
    shown = first
    if reduceMotion {
      shown = last
    } else {
      withAnimation(.easeOut(duration: 0.5).delay(0.1)) { shown = last }
    }
  }
}
struct ComparisonHistory: View {
  @EnvironmentObject private var store: GymStore
  let points: [ProgressPoint]
  let repMode: Bool
  let unit: String
  private func value(_ p: ProgressPoint) -> Double {
    repMode ? Double(p.reps) : GymStore.displayedWeight(p.weightKG, unit: store.profile.unit)
  }
  var body: some View {
    List {
      if points.count > 1 {
        Chart(points) { p in
          LineMark(x: .value("Date", p.date), y: .value(unit, value(p))).foregroundStyle(
            GymColor.red)
          PointMark(x: .value("Date", p.date), y: .value(unit, value(p))).foregroundStyle(
            GymColor.red)
        }.chartYAxisLabel(unit).frame(height: 190).padding(.vertical, 12).accessibilityLabel(
          store.t("Comparable workout history"))
      }
      ForEach(points.reversed()) { p in
        HStack {
          Text(p.date, format: .dateTime.month(.abbreviated).day())
          Spacer()
          Text(formatNumber(value(p)) + " " + unit).monospacedDigit()
        }
      }
    }.gymPage().navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.inline)
  }
}

struct ExerciseRecords: View {
  @EnvironmentObject private var store: GymStore
  let exercise: Exercise
  let split: Workout
  var body: some View {
    List {
      ForEach(store.splitSessions(split)) { session in
        Section(session.started.formatted(date: .abbreviated, time: .omitted)) {
          ForEach(session.sets.filter { $0.exercise.id == exercise.id && $0.comparable }) { set in
            Text(setValue(set, store: store))
          }
        }
      }
    }.gymPage().navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.inline)
  }
}
