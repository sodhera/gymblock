import SwiftUI

/// The moment after Finish: the lock springs open, today's circle fills in,
/// and the numbers land. Restrained on purpose — one orange fill, one haptic,
/// no confetti. PRs get their own line because they earned it.
struct WorkoutSummaryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var workout: Workout
    var records: [PersonalRecord]
    @State private var revealed = false
    @State private var savedTemplate = false

    private var todayIndex: Int? {
        store.week.days.firstIndex { Calendar.current.isDate($0, inSameDayAs: workout.start) }
    }

    private var displayWeek: WeekProgress {
        var week = store.week
        if !revealed, let i = todayIndex, workout.counts {
            // Was today already trained before this workout? Then there's
            // nothing to animate in.
            let others = store.workouts.filter { $0.id != workout.id && $0.counts && Calendar.current.isDate($0.start, inSameDayAs: workout.start) }
            if others.isEmpty { week.trained.remove(i) }
        }
        return week
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.xxl) {
                    header
                    VStack(alignment: .leading, spacing: GBSpace.lg) {
                        WeekStrip(week: displayWeek)
                    }
                    .padding(GBSpace.lg)
                    .solidCard()

                    stats
                    if !records.isEmpty { recordsSection }
                    exercisesSection
                    shareToggle
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.top, GBSpace.lg)
                .padding(.bottom, 120)
            }
            .paperBackground()
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: GBSpace.sm) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.primary)
                    if workout.templateID == nil && !savedTemplate {
                        Button("Save as template") {
                            store.saveTemplate(store.templateFrom(workout))
                            Haptics.success()
                            withAnimation { savedTemplate = true }
                        }
                        .buttonStyle(.quiet)
                    }
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.bottom, GBSpace.xs)
            }
            .task {
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { revealed = true }
                if workout.counts { Haptics.lock() }
                if !records.isEmpty {
                    try? await Task.sleep(for: .seconds(0.5))
                    Haptics.pr()
                }
            }
        }
        .interactiveDismissDisabled(false)
    }

    private var header: some View {
        let week = store.week
        return VStack(alignment: .leading, spacing: GBSpace.xs) {
            HStack(spacing: 6) {
                Image(systemName: "lock.open.fill")
                Text("Apps unlocked")
            }
            .kicker(GBColor.orange)

            Group {
                if !workout.counts {
                    Text("Logged.\n") + Text("Didn't count this time.").foregroundStyle(GBColor.fog)
                } else if week.isComplete && revealed {
                    Text("\(week.count) of \(week.target).\n") + Text("Week's done.").foregroundStyle(GBColor.orange)
                } else {
                    Text("\(revealed ? week.count : max(0, week.count - 1)) of \(week.target)\n")
                        + Text("this week.").foregroundStyle(GBColor.fog)
                }
            }
            .font(GBFont.hero(38))
            .foregroundStyle(GBColor.ink)
            .contentTransition(.numericText())
        }
    }

    private var stats: some View {
        HStack(spacing: 0) {
            stat("Time", Format.duration(workout.duration))
            stat("Volume", Format.volume(workout.volume, unit: store.profile.unit))
            stat("Sets", "\(workout.completedSetCount)")
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).kicker()
            Text(value).font(GBFont.number(20, weight: .bold)).foregroundStyle(GBColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recordsSection: some View {
        VStack(alignment: .leading, spacing: GBSpace.sm) {
            Text(records.count == 1 ? "New record" : "\(records.count) new records").kicker(GBColor.orange)
            VStack(spacing: 0) {
                ForEach(records) { record in
                    HStack {
                        Text(store.exercise(record.exerciseID)?.displayName ?? "")
                            .font(GBFont.headline(16))
                            .foregroundStyle(GBColor.ink)
                        Spacer()
                        Text("\(Format.weight(record.weight, unit: store.profile.unit)) \(store.profile.unit.rawValue) × \(record.reps)")
                            .font(GBFont.number(15, weight: .semibold))
                            .foregroundStyle(GBColor.orange)
                    }
                    .padding(GBSpace.md)
                }
            }
            .background(GBColor.orangeWash, in: RoundedRectangle(cornerRadius: GBRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: GBRadius.md, style: .continuous).strokeBorder(GBColor.orange.opacity(0.25)))
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: GBSpace.sm) {
            Text("Exercises").kicker()
            VStack(spacing: 0) {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, log in
                    let exercise = store.exercise(log.exerciseID)
                    let best = log.sets.max { ($0.estimatedOneRepMax ?? 0) < ($1.estimatedOneRepMax ?? 0) }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise?.displayName ?? "").font(GBFont.headline(16)).foregroundStyle(GBColor.ink)
                            Text("\(log.sets.count) sets").font(GBFont.body(13)).foregroundStyle(GBColor.steel)
                        }
                        Spacer()
                        if let best {
                            Text(Format.set(best, unit: store.profile.unit, metric: exercise?.metric ?? .weightReps))
                                .font(GBFont.number(15, weight: .medium))
                                .foregroundStyle(GBColor.ink2)
                        }
                    }
                    .padding(GBSpace.md)
                    if index < workout.exercises.count - 1 {
                        Rectangle().fill(GBColor.hairline).frame(height: 1).padding(.leading, GBSpace.md)
                    }
                }
            }
            .solidCard(cornerRadius: GBRadius.md)
        }
    }

    private var shareToggle: some View {
        Toggle(isOn: Binding(
            get: { workout.isShared },
            set: {
                workout.isShared = $0
                store.updateWorkout(workout)
                Haptics.tap()
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Share this workout").font(GBFont.headline(16)).foregroundStyle(GBColor.ink)
                Text("Friends see your exercises and sets.").font(GBFont.body(13)).foregroundStyle(GBColor.steel)
            }
        }
        .tint(GBColor.orange)
        .padding(GBSpace.md)
        .solidCard(cornerRadius: GBRadius.md)
    }
}
