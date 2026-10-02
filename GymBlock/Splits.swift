import SwiftUI

struct SplitsView: View {
    var onDone: (() -> Void)?
    @EnvironmentObject private var store: GymStore
    @State private var editing: Workout?
    var body: some View {
        List {
            Section {
                ForEach(store.data.workouts) { split in
                    Button { editing = split } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) { Text(split.name).foregroundStyle(GymColor.ink); Text("\(split.exercises.count) " + store.t("exercises")).font(.caption).foregroundStyle(GymColor.dim) }
                            Spacer(); Image(systemName: "chevron.right").foregroundStyle(GymColor.dim).font(.caption)
                        }.padding(.vertical, 5)
                    }.accessibilityIdentifier("split.edit.\(split.name)")
                }.onDelete { indices in let ids = indices.map { store.data.workouts[$0].id }; ids.forEach { store.deleteSplit($0) } }
                Button { editing = Workout(name: "", exercises: []) } label: { Label(store.t("Add split"), systemImage: "plus") }.accessibilityIdentifier("split.add")
            } footer: { Text(store.t("Splits are optional. You can always start a free workout.")) }
        }.scrollContentBackground(.hidden).background(GymColor.ground).navigationTitle(store.t("Splits"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { onDone?() }.accessibilityIdentifier("preferences.done") } }
            .sheet(item: $editing) { SplitEditor(workout: $0) }
    }
}
struct SplitEditor: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @State private var name: String
    @State private var exercises: [Exercise]
    @State private var add = false
    @State private var error = false
    init(workout: Workout) { self.workout = workout; _name = State(initialValue: workout.name); _exercises = State(initialValue: workout.exercises) }
    var body: some View {
        NavigationStack {
            List {
                Section(store.t("Split name")) { TextField("Monday or Arms", text: $name).accessibilityIdentifier("split.name") }
                Section(store.t("Exercises")) {
                    ForEach(exercises) { exercise in Text(store.t(exercise.name)) }
                        .onDelete { exercises.remove(atOffsets: $0) }
                        .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
                    Button { add = true } label: { Label(store.t("Add exercises"), systemImage: "plus") }.accessibilityIdentifier("split.exercises")
                }
                if error { Section { Text(store.t("Use a unique name and add at least one exercise.")).foregroundStyle(GymColor.red) } }
            }.environment(\.editMode, .constant(.active))
                .scrollContentBackground(.hidden).background(GymColor.ground).navigationTitle(store.t(workout.name.isEmpty ? "Add split" : "Edit split"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button(store.t("Save")) {
                        if store.saveSplit(id: workout.id, name: name, exercises: exercises) { dismiss() } else { error = true }
                    }.accessibilityIdentifier("split.save") }
                }
                .sheet(isPresented: $add) { SplitExercisePicker(exercises: $exercises) }
        }
    }
}
struct SplitExercisePicker: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @Binding var exercises: [Exercise]
    @State private var search = ""
    @State private var custom = false
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.allExercises.filter { search.isEmpty || store.t($0.name).localizedCaseInsensitiveContains(search) }) { exercise in
                    Button {
                        if exercises.contains(where: { $0.id == exercise.id }) { exercises.removeAll { $0.id == exercise.id } }
                        else { exercises.append(exercise) }
                    } label: {
                        HStack { Text(store.t(exercise.name)).foregroundStyle(GymColor.ink); Spacer(); Image(systemName: exercises.contains(where: { $0.id == exercise.id }) ? "checkmark.circle.fill" : "circle").foregroundStyle(GymColor.blue) }
                    }.accessibilityIdentifier("split.exercise.\(exercise.id)")
                }
                Button(store.t("Add custom exercise")) { custom = true }
            }.searchable(text: $search, prompt: store.t("Search exercises"))
                .navigationTitle(store.t("Add exercises")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("split.exercises.done") } }
                .sheet(isPresented: $custom) { CustomExerciseView { exercises.append($0) } }
        }
    }
}
