import SwiftUI
import Charts

struct ProgressView: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State private var splitID: UUID?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if store.data.workouts.isEmpty { Text(store.t("Add a split in Settings to track its progress.")).foregroundStyle(GymColor.dim) }
                    else {
                        HStack {
                            Text(store.t("Split")).foregroundStyle(GymColor.dim)
                            Spacer()
                            Picker(store.t("Split"), selection: $splitID) { ForEach(store.data.workouts) { Text($0.name).tag(Optional($0.id)) } }
                                .pickerStyle(.menu).accessibilityIdentifier("progress.split")
                        }
                        if let split = store.data.workouts.first(where: { $0.id == splitID }) {
                            Text(split.name).font(.largeTitle.weight(.bold))
                            Text(store.profile.language == "es" ? "\(store.splitSessions(split).count) entrenamientos" : "\(store.splitSessions(split).count) workouts logged").font(.subheadline).foregroundStyle(GymColor.dim)
                            ForEach(split.exercises) { exercise in
                                NavigationLink { ExerciseProgressView(exercise: exercise, split: split) } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(store.t(exercise.name)).font(.headline).foregroundStyle(GymColor.ink)
                                            if let set = store.latestSet(for: exercise, split: split) {
                                                Text(set.exercise.timed ? "\(set.minutes.formatted()) min" : "\(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit).formatted(.number.precision(.fractionLength(0...1)))) \(store.profile.unit) × \(set.reps)").font(.subheadline).foregroundStyle(GymColor.dim)
                                            } else { Text(store.t("No sets logged yet.")).font(.subheadline).foregroundStyle(GymColor.dim) }
                                        }
                                        Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(GymColor.blue)
                                    }.padding(18).frame(maxWidth: .infinity).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 16))
                                }.accessibilityIdentifier("progress.exercise.\(exercise.id)")
                            }
                            Text(store.t("Only workouts started from this split are shown.")).font(.caption).foregroundStyle(GymColor.dim)
                        }
                    }
                }.padding(24)
            }.background(GymColor.ground).navigationTitle(store.t("Progress")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("progress.done") } }
                .onAppear { if splitID == nil { splitID = store.data.workouts.first?.id } }
        }
    }
}
struct ExerciseProgressView: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    let exercise: Exercise
    let split: Workout
    @State private var shownWeight = 0.0
    private var latest: LoggedSet? { store.latestSet(for: exercise, split: split) }
    private var points: [ProgressPoint] { store.progress(for: exercise, split: split, reps: latest?.reps ?? 0) }
    private var first: Double { points.first?.weightKG ?? 0 }
    private var last: Double { points.last?.weightKG ?? 0 }
    private var ceiling: Double { max(1, (points.map(\.weightKG).max() ?? 1) * 1.15) }
    private func formatted(_ kg: Double) -> String { GymStore.displayedWeight(kg, unit: store.profile.unit).formatted(.number.precision(.fractionLength(0...1))) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(store.t(exercise.name)).font(.largeTitle.weight(.bold))
                if let latest, !exercise.timed, !points.isEmpty {
                    Text(store.t("Best weight at") + " \(latest.reps) " + store.t("reps")).font(.subheadline).foregroundStyle(GymColor.dim)
                    Card {
                        VStack(alignment: .leading, spacing: 18) {
                            comparisonRow(title: store.t("First session"), weight: first, ratio: first / ceiling, color: GymColor.blue.opacity(0.45))
                            comparisonRow(title: store.t("Latest session"), weight: shownWeight, ratio: shownWeight / ceiling, color: GymColor.red)
                            if points.count > 1 {
                                Text((last - first >= 0 ? "+" : "−") + formatted(abs(last - first)) + " \(store.profile.unit) · " + store.t("same reps"))
                                    .font(.headline).foregroundStyle(GymColor.red).accessibilityIdentifier("progress.change")
                            } else { Text(store.t("Your baseline. Log another session to compare.")).font(.subheadline).foregroundStyle(GymColor.dim) }
                        }
                    }
                    Button { Task { await animate() } } label: { Label(store.t("Replay progress"), systemImage: "arrow.counterclockwise") }.frame(minHeight: 44).accessibilityIdentifier("progress.replay")
                    if points.count > 1 {
                        Chart(points) { point in
                            LineMark(x: .value("Date", point.date), y: .value(store.profile.unit, GymStore.displayedWeight(point.weightKG, unit: store.profile.unit))).foregroundStyle(GymColor.blue)
                            PointMark(x: .value("Date", point.date), y: .value(store.profile.unit, GymStore.displayedWeight(point.weightKG, unit: store.profile.unit))).foregroundStyle(GymColor.red)
                        }.chartYAxisLabel(store.profile.unit).chartXAxisLabel(store.t("Session date"))
                            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisGridLine(); AxisTick(); AxisValueLabel(format: .dateTime.month(.abbreviated).day()) } }
                            .frame(height: 190).accessibilityLabel(store.t("Weight history at the same rep count"))
                    }
                    Text(store.t("Same exercise and reps, across sessions in this split.")).font(.footnote).foregroundStyle(GymColor.dim)
                } else if let latest, exercise.timed {
                    Text("\(latest.minutes.formatted()) " + store.t("min")).font(.largeTitle.monospacedDigit())
                    Text(store.t("Latest activity duration")).foregroundStyle(GymColor.dim)
                } else { Text(store.t("No sets logged yet.")).foregroundStyle(GymColor.dim) }
            }.padding(24)
        }.background(GymColor.ground).navigationTitle(split.name).navigationBarTitleDisplayMode(.inline)
            .task { await animate() }
    }
    private func comparisonRow(title: String, weight: Double, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Text(title).font(.subheadline).foregroundStyle(GymColor.dim); Spacer(); Text("\(formatted(weight)) \(store.profile.unit)").font(.headline.monospacedDigit()).contentTransition(.numericText()) }
            GeometryReader { proxy in
                ZStack(alignment: .leading) { Capsule().fill(GymColor.wash); Capsule().fill(color).frame(width: max(0, proxy.size.width * min(1, ratio))) }
            }.frame(height: 12)
        }
    }
    @MainActor private func animate() async {
        shownWeight = first
        if reducedMotion { shownWeight = last }
        else {
            do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
            withAnimation(.easeOut(duration: 0.55)) { shownWeight = last }
        }
    }
}
