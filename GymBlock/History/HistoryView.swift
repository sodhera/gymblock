import SwiftUI

/// Every finished workout, grouped by training week, plus a Records view of
/// the best set per exercise. Rows name things; numbers carry the detail.
struct HistoryView: View {
    @Environment(AppStore.self) private var store
    @State private var mode: Mode = .workouts

    enum Mode: String, CaseIterable { case workouts = "Workouts", records = "Records" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.xl) {
                    Picker("View", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in Haptics.tap() }

                    switch mode {
                    case .workouts: workoutsList
                    case .records: recordsList
                    }
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.bottom, 120)
            }
            .paperBackground()
            .navigationTitle("History")
            .navigationDestination(for: UUID.self) { id in
                WorkoutDetailView(workoutID: id)
            }
        }
    }

    // MARK: Workouts

    private var groupedWeeks: [(start: Date, workouts: [Workout])] {
        let groups = Dictionary(grouping: store.sortedWorkouts) { TrainingCalendar.startOfWeek(for: $0.start) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.start > $1.start }) }
    }

    @ViewBuilder
    private var workoutsList: some View {
        if store.workouts.isEmpty {
            EmptyState(icon: "list.bullet.rectangle", title: "No workouts yet", message: "Your first one lands here.")
        } else {
            ForEach(groupedWeeks, id: \.start) { group in
                VStack(alignment: .leading, spacing: GBSpace.sm) {
                    HStack {
                        Text(weekLabel(group.start)).kicker()
                        Spacer()
                        let count = Set(group.workouts.filter(\.counts).map { Calendar.current.startOfDay(for: $0.start) }).count
                        Text("\(count) of \(store.profile.weeklyTarget)")
                            .font(GBFont.label(13))
                            .foregroundStyle(count >= store.profile.weeklyTarget ? GBColor.orange : GBColor.steel)
                    }
                    .padding(.horizontal, GBSpace.xxs)
                    VStack(spacing: GBSpace.xs) {
                        ForEach(group.workouts) { workout in
                            NavigationLink(value: workout.id) {
                                WorkoutRow(workout: workout)
                            }
                            .buttonStyle(ScaleOnPress(scale: 0.98))
                        }
                    }
                }
            }
        }
    }

    private func weekLabel(_ start: Date) -> String {
        let thisWeek = TrainingCalendar.startOfWeek(for: .now)
        if start == thisWeek { return "This week" }
        if let last = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: thisWeek), start == last { return "Last week" }
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.day()))"
    }

    // MARK: Records

    @ViewBuilder
    private var recordsList: some View {
        let records = store.records.values.sorted {
            (store.exercise($0.exerciseID)?.displayName ?? "") < (store.exercise($1.exerciseID)?.displayName ?? "")
        }
        if records.isEmpty {
            EmptyState(icon: "trophy", title: "No records yet", message: "Your best set for every lift shows up here.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.exercise(record.exerciseID)?.displayName ?? record.exerciseID)
                                .font(GBFont.headline(16))
                                .foregroundStyle(GBColor.ink)
                            Text(Format.day(record.date))
                                .font(GBFont.body(13))
                                .foregroundStyle(GBColor.steel)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Format.weight(record.weight, unit: store.profile.unit)) \(store.profile.unit.rawValue) × \(record.reps)")
                                .font(GBFont.number(16, weight: .bold))
                                .foregroundStyle(GBColor.ink)
                            Text("e1RM \(Format.weight(record.estimatedOneRepMax, unit: store.profile.unit))")
                                .font(GBFont.number(12, weight: .medium))
                                .foregroundStyle(GBColor.fog)
                        }
                    }
                    .padding(GBSpace.md)
                    if index < records.count - 1 {
                        Rectangle().fill(GBColor.hairline).frame(height: 1).padding(.leading, GBSpace.md)
                    }
                }
            }
            .solidCard(cornerRadius: GBRadius.md)
        }
    }
}

struct WorkoutRow: View {
    @Environment(AppStore.self) private var store
    var workout: Workout

    var body: some View {
        HStack(alignment: .top, spacing: GBSpace.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.title)
                        .font(GBFont.headline(17))
                        .foregroundStyle(GBColor.ink)
                    if workout.isShared {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(GBColor.fog)
                    }
                }
                Text("\(Format.day(workout.start)) · \(Format.duration(workout.duration)) · \(workout.completedSetCount) sets")
                    .font(GBFont.body(14))
                    .foregroundStyle(GBColor.steel)
                Text(workout.exercises.compactMap { store.exercise($0.exerciseID)?.name }.joined(separator: ", "))
                    .font(GBFont.body(13))
                    .foregroundStyle(GBColor.fog)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GBColor.fog)
                .padding(.top, 4)
        }
        .padding(GBSpace.md)
        .solidCard(cornerRadius: GBRadius.md)
        .contentShape(Rectangle())
    }
}

struct EmptyState: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: GBSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(GBColor.steel)
                .frame(width: 52, height: 52)
                .background(GBColor.card, in: Circle())
            Text(title).font(GBFont.headline(17)).foregroundStyle(GBColor.ink)
            Text(message).font(GBFont.body(15)).foregroundStyle(GBColor.steel).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GBSpace.huge)
    }
}

// MARK: - Detail

struct WorkoutDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var workoutID: UUID
    @State private var confirmDelete = false
    @State private var savedTemplate = false

    private var workout: Workout? { store.workouts.first { $0.id == workoutID } }

    var body: some View {
        if let workout {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.xl) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.start.formatted(.dateTime.weekday(.wide).month().day().hour().minute()))
                            .kicker()
                        HStack(spacing: GBSpace.lg) {
                            detail("Time", Format.duration(workout.duration))
                            detail("Volume", Format.volume(workout.volume, unit: store.profile.unit))
                            detail("Sets", "\(workout.completedSetCount)")
                        }
                        .padding(.top, GBSpace.xs)
                    }

                    ForEach(workout.exercises) { log in
                        let exercise = store.exercise(log.exerciseID)
                        VStack(alignment: .leading, spacing: GBSpace.xs) {
                            Text(exercise?.displayName ?? "").font(GBFont.headline(17)).foregroundStyle(GBColor.ink)
                            if !log.note.isEmpty {
                                Text(log.note).font(GBFont.body(14)).foregroundStyle(GBColor.steel)
                            }
                            ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, set in
                                HStack {
                                    Text(set.kind.marker ?? "\(log.sets.prefix(index + 1).filter { $0.kind != .warmup }.count)")
                                        .font(GBFont.number(14, weight: .bold))
                                        .foregroundStyle(set.kind == .warmup ? GBColor.warmup : GBColor.steel)
                                        .frame(width: 24, alignment: .leading)
                                    Text(Format.set(set, unit: store.profile.unit, metric: exercise?.metric ?? .weightReps))
                                        .font(GBFont.number(15, weight: .medium))
                                        .foregroundStyle(GBColor.ink)
                                    Spacer()
                                }
                            }
                        }
                        .padding(GBSpace.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .solidCard(cornerRadius: GBRadius.md)
                    }

                    Toggle(isOn: Binding(
                        get: { workout.isShared },
                        set: { var w = workout; w.isShared = $0; store.updateWorkout(w); Haptics.tap() }
                    )) {
                        Text("Shared with friends").font(GBFont.headline(16))
                    }
                    .tint(GBColor.orange)
                    .padding(GBSpace.md)
                    .solidCard(cornerRadius: GBRadius.md)

                    VStack(spacing: GBSpace.md) {
                        Button(savedTemplate ? "Saved as template" : "Save as template") {
                            store.saveTemplate(store.templateFrom(workout))
                            Haptics.success()
                            savedTemplate = true
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(savedTemplate)

                        Button("Delete workout") { confirmDelete = true }
                            .buttonStyle(QuietButtonStyle(color: GBColor.danger))
                    }
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.bottom, 120)
            }
            .paperBackground()
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete workout", role: .destructive) {
                    store.deleteWorkout(workout.id)
                    dismiss()
                }
            } message: {
                Text("It comes off your week and your streak.")
            }
        } else {
            EmptyState(icon: "questionmark", title: "Workout not found", message: "It may have been deleted.")
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).kicker()
            Text(value).font(GBFont.number(18, weight: .bold)).foregroundStyle(GBColor.ink)
        }
    }
}
