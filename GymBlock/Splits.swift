import SwiftUI

struct SplitsView: View {
  var onDone: (() -> Void)?
  @EnvironmentObject private var store: GymStore
  @State private var adding = false
  var body: some View {
    List {
      if store.data.workouts.isEmpty {
        Text(store.t("Save a group of exercises.")).foregroundStyle(GymColor.dim).listRowBackground(Color.clear)
        Button(store.t("Create split")) { adding = true }.accessibilityIdentifier("split.add")
        Button(store.t("Free workout")) { store.startSession() }
      } else {
        ForEach(store.data.workouts) { split in
          NavigationLink { SplitDetailView(splitID: split.id) } label: {
            VStack(alignment: .leading, spacing: 4) {
              Text(split.name)
              Text("\(split.exercises.count) " + store.t("exercises")).font(GymType.body(13)).foregroundStyle(GymColor.dim)
            }.padding(.vertical, 6)
          }.accessibilityIdentifier("split.edit.\(split.name)")
        }.onDelete { indices in indices.map { store.data.workouts[$0].id }.forEach { store.deleteSplit($0) } }
      }
    }.gymPage().navigationTitle(store.t("Splits")).navigationBarTitleDisplayMode(.large)
      .toolbar {
        if !store.data.workouts.isEmpty {
          ToolbarItem(placement: .topBarTrailing) {
            Button(store.t("Add split")) { adding = true }.accessibilityIdentifier("split.add")
          }
        }
        if let onDone {
          ToolbarItem(placement: .confirmationAction) { Button(store.t("Done"), action: onDone) }
        }
      }.sheet(isPresented: $adding) { SplitEditor(workout: Workout(name: "", exercises: [])) }
  }
}

struct SplitDetailView: View {
  @EnvironmentObject private var store: GymStore
  let splitID: UUID
  @State private var editing = false
  private var split: Workout? { store.data.workouts.first { $0.id == splitID } }
  var body: some View {
    Group {
      if let split {
        List {
          ForEach(split.exercises) { Text(store.t($0.name)).padding(.vertical, 8) }
          NavigationLink(store.t("Progress")) { ExerciseProgressList(scopeID: split.id, title: split.name) }
        }.safeAreaInset(edge: .bottom) {
          GymButton(title: store.t(store.session == nil ? "Start workout" : "Return to workout"), id: "split.start") {
            if store.session == nil { store.startSession(workout: split) }
            else { NotificationCenter.default.post(name: .returnToWorkout, object: nil) }
          }.padding(.horizontal, 24).padding(.vertical, 16)
        }.navigationTitle(split.name)
          .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(store.t("Edit")) { editing = true } } }
          .sheet(isPresented: $editing) { SplitEditor(workout: split) }
      }
    }.gymPage().navigationBarTitleDisplayMode(.inline)
  }
}

struct SplitEditor: View {
  let workout: Workout
  var body: some View { NavigationStack { SplitEditorContent(workout: workout) } }
}
struct SplitEditorContent: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let workout: Workout
  var onSaved: ((Workout) -> Void)?
  @State private var name: String
  @State private var exercises: [Exercise]
  @State private var error = false
  @State private var adding = false
  init(workout: Workout, onSaved: ((Workout) -> Void)? = nil) {
    self.workout = workout; self.onSaved = onSaved
    _name = State(initialValue: workout.name); _exercises = State(initialValue: workout.exercises)
  }
  private var duplicate: Bool {
    store.data.workouts.contains { $0.id != workout.id && $0.name.localizedCaseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
  }
  var body: some View {
    List {
      Section(store.t("Name")) {
        TextField(store.t("Name"), text: $name).accessibilityIdentifier("split.name")
        if error && duplicate { Text(store.t("This name is already used.")).foregroundStyle(GymColor.red) }
      }
      Section {
        ForEach(exercises) { Text(store.t($0.name)) }
          .onDelete { exercises.remove(atOffsets: $0) }.onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
        Button(store.t("Add exercises")) { adding = true }
          .accessibilityIdentifier("split.exercises").deleteDisabled(true).moveDisabled(true)
        if error && exercises.isEmpty { Text(store.t("Add an exercise to save.")).foregroundStyle(GymColor.red) }
      }
    }.environment(\.editMode, .constant(.active)).gymPage()
      .navigationDestination(isPresented: $adding) {
        SplitExercisePicker(exercises: $exercises).environment(\.editMode, .constant(.inactive))
      }
      .navigationTitle(store.t(workout.name.isEmpty ? "New split" : "Edit split"))
      .navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(store.t("Save")) {
            if store.saveSplit(id: workout.id, name: name, exercises: exercises) {
              if let saved = store.data.workouts.first(where: { $0.id == workout.id }), let onSaved { onSaved(saved) }
              else { dismiss() }
            } else { error = true }
          }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("split.save")
        }
      }
  }
}
struct SplitExercisePicker: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @Binding var exercises: [Exercise]
  @State private var search = ""
  var body: some View {
    List {
      ForEach(store.allExercises.filter { search.isEmpty || store.t($0.name).localizedCaseInsensitiveContains(search) }) { exercise in
        let selected = exercises.contains { $0.id == exercise.id }
        Button {
          if selected { exercises.removeAll { $0.id == exercise.id } } else { exercises.append(exercise) }
        } label: {
          HStack {
            Text(store.t(exercise.name)).foregroundStyle(GymColor.ink); Spacer()
            if selected { Image(systemName: "checkmark").foregroundStyle(GymColor.red).accessibilityHidden(true) }
          }.frame(minHeight: 44)
        }.accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("split.exercise.\(exercise.id)")
      }
      NavigationLink(store.t("New exercise")) { CustomExerciseView(embedded: true, initialName: search) { exercises.append($0) } }
    }.searchable(text: $search, prompt: store.t("Search exercises")).gymSearchNavigation().gymPage()
      .navigationTitle(store.t("Add exercises")).navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("split.exercises.done") } }
  }
}
