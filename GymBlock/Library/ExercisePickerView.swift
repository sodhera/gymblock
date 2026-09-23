import SwiftUI

/// Search + muscle filter + multi-select over the exercise library. Used to
/// add exercises to a workout or template, or (single-select) to replace one.
/// Exercises are text only — name, then "Chest · Triceps" — no figures.
struct ExercisePickerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var title: String
    var allowsMultiple = true
    var onPick: ([String]) -> Void

    @State private var query = ""
    @State private var muscle: Muscle?
    @State private var selection: [String] = []
    @State private var creating = false

    private var recentIDs: [String] {
        var seen = Set<String>()
        var ids: [String] = []
        for workout in store.sortedWorkouts {
            for log in workout.exercises where !seen.contains(log.exerciseID) {
                seen.insert(log.exerciseID)
                ids.append(log.exerciseID)
            }
            if ids.count >= 8 { break }
        }
        return ids
    }

    private var results: [Exercise] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return ExerciseLibrary.shared.all
            .filter { muscle == nil || $0.primary.contains(muscle!) || $0.secondary.contains(muscle!) }
            .filter {
                q.isEmpty
                    || $0.displayName.lowercased().contains(q)
                    || $0.primary.contains { $0.name.lowercased().hasPrefix(q) }
            }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty, muscle == nil, !recentIDs.isEmpty {
                    Section {
                        ForEach(recentIDs.compactMap { store.exercise($0) }) { row($0) }
                    } header: {
                        Text("Recent").kicker()
                    }
                }
                Section {
                    ForEach(results) { row($0) }
                    if results.isEmpty {
                        VStack(spacing: GBSpace.sm) {
                            Text("No match for “\(query)”")
                                .font(GBFont.body(15))
                                .foregroundStyle(GBColor.steel)
                            Button("Create “\(query)”") { creating = true }
                                .font(GBFont.label(15))
                                .foregroundStyle(GBColor.orange)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, GBSpace.xl)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(muscle?.name ?? "All exercises").kicker()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .paperBackground()
            .safeAreaInset(edge: .top, spacing: 0) { filterBar }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Create", systemImage: "plus") { creating = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if allowsMultiple && !selection.isEmpty {
                    Button(selection.count == 1 ? "Add 1 exercise" : "Add \(selection.count) exercises") {
                        onPick(selection)
                        dismiss()
                    }
                    .buttonStyle(.primary)
                    .padding(.horizontal, GBSpace.margin)
                    .padding(.bottom, GBSpace.xs)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection.isEmpty)
            .sheet(isPresented: $creating) {
                CustomExerciseView(initialName: query) { exercise in
                    if allowsMultiple {
                        selection.append(exercise.id)
                    } else {
                        onPick([exercise.id])
                        dismiss()
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: GBSpace.xs) {
                chip("All", selected: muscle == nil) { muscle = nil }
                ForEach(Muscle.filterOrder) { m in
                    chip(m.name, selected: muscle == m) { muscle = muscle == m ? nil : m }
                }
            }
            .padding(.horizontal, GBSpace.margin)
            .padding(.vertical, GBSpace.xs)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            Text(title)
                .font(GBFont.label(14))
                .foregroundStyle(selected ? .white : GBColor.ink)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(selected ? GBColor.ink : Color.white))
        }
        .buttonStyle(ScaleOnPress())
    }

    private func row(_ exercise: Exercise) -> some View {
        let isSelected = selection.contains(exercise.id)
        return Button {
            if allowsMultiple {
                Haptics.tap()
                if let i = selection.firstIndex(of: exercise.id) { selection.remove(at: i) } else { selection.append(exercise.id) }
            } else {
                Haptics.tap()
                onPick([exercise.id])
                dismiss()
            }
        } label: {
            HStack(spacing: GBSpace.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.displayName)
                        .font(GBFont.headline(16))
                        .foregroundStyle(GBColor.ink)
                    Text(Format.muscles(exercise) + (exercise.isCustom ? " · Custom" : ""))
                        .font(GBFont.body(13))
                        .foregroundStyle(GBColor.steel)
                }
                Spacer()
                if allowsMultiple {
                    ZStack {
                        Circle().strokeBorder(isSelected ? GBColor.orange : GBColor.mist, lineWidth: 2)
                        if isSelected {
                            if let n = selection.firstIndex(of: exercise.id) {
                                Circle().fill(GBColor.orange)
                                Text("\(n + 1)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                            }
                        }
                    }
                    .frame(width: 24, height: 24)
                    .animation(.snappy(duration: 0.2), value: isSelected)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom exercise

struct CustomExerciseView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var initialName: String = ""
    var onCreate: (Exercise) -> Void

    @State private var name = ""
    @State private var equipment: Equipment = .barbell
    @State private var muscle: Muscle = .chest
    @State private var metric: MetricKind = .weightReps

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .font(GBFont.headline(17))
                }
                Section {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Main muscle", selection: $muscle) {
                        ForEach(Muscle.filterOrder) { Text($0.name).tag($0) }
                    }
                    Picker("Logged as", selection: $metric) {
                        Text("Weight × reps").tag(MetricKind.weightReps)
                        Text("Reps only").tag(MetricKind.reps)
                        Text("Time").tag(MetricKind.time)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let exercise = store.createCustomExercise(
                            name: name.trimmingCharacters(in: .whitespaces), equipment: equipment, primary: muscle, metric: metric
                        )
                        Haptics.success()
                        onCreate(exercise)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { name = initialName }
        .presentationDetents([.medium])
    }
}
