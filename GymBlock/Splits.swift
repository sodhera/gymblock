import SwiftUI

struct SplitEditor: View {
  let workout: Workout
  var body: some View { NavigationStack { SplitEditorContent(workout: workout) } }
}

/// A split: its name and the exercises in order. Native editing (drag to reorder, swipe to delete)
/// on the paper stage, with the name as the page's own headline.
struct SplitEditorContent: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let workout: Workout
  var onSaved: ((Workout) -> Void)?
  @State private var name: String
  @State private var exercises: [Exercise]
  @State private var error = false
  @State private var adding = false
  @FocusState private var naming: Bool
  init(workout: Workout, onSaved: ((Workout) -> Void)? = nil) {
    self.workout = workout; self.onSaved = onSaved
    _name = State(initialValue: workout.name); _exercises = State(initialValue: workout.exercises)
  }
  private var duplicate: Bool {
    store.data.workouts.contains { $0.id != workout.id && $0.name.localizedCaseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
  }
  private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty && !duplicate }
  var body: some View {
    List {
      Section {
        TextField(store.t("Push, Pull, Legs…"), text: $name)
          .font(.system(.title2, weight: .bold)).focused($naming)
          .textInputAutocapitalization(.words).submitLabel(.done)
          .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
          .accessibilityIdentifier("split.name")
        if duplicate {
          Text(store.t("This name is already used.")).font(JourneyType.caption).foregroundStyle(JourneyColor.signal)
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
        }
      } header: { Eyebrow(text: store.t("Name")).textCase(nil) }
      Section {
        ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
          HStack(spacing: 12) {
            Text("\(index + 1)").font(JourneyType.caption).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
              .frame(width: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              Text(store.t(exercise.name)).font(.body).foregroundStyle(JourneyColor.text)
              Text(store.t(exercise.area)).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
            }
          }.padding(.vertical, 2)
        }
        .onDelete { exercises.remove(atOffsets: $0) }
        .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
        Button { naming = false; adding = true } label: {
          Label(store.t(exercises.isEmpty ? "Add exercises" : "Add more"), systemImage: "plus")
            .font(.body.weight(.medium)).foregroundStyle(JourneyColor.text)
        }.accessibilityIdentifier("split.exercises").deleteDisabled(true).moveDisabled(true)
      } header: {
        HStack {
          Eyebrow(text: store.t("Exercises")).textCase(nil)
          Spacer()
          if !exercises.isEmpty {
            Text(exercises.count == 1 ? store.t("1 exercise") : "\(exercises.count) " + store.t("exercises"))
              .font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).textCase(nil)
          }
        }
      } footer: {
        if exercises.isEmpty {
          Text(store.t("Add the exercises in the order you do them. You can drag them later.")).font(JourneyType.caption)
        } else {
          Text(store.t("Drag to reorder. Swipe left to remove.")).font(JourneyType.caption)
        }
      }
      if error && exercises.isEmpty {
        Text(store.t("Add an exercise to save.")).foregroundStyle(JourneyColor.signal).listRowBackground(Color.clear)
      }
    }
    .environment(\.editMode, .constant(.active)).gymPage()
    .animation(.spring(duration: 0.45, bounce: 0.1), value: exercises.map(\.id))
    .navigationDestination(isPresented: $adding) {
      SplitExercisePicker(exercises: $exercises).environment(\.editMode, .constant(.inactive))
    }
    .navigationTitle(store.t(workout.name.isEmpty ? "New split" : "Edit split")).track(screen: "split.edit", ["new": workout.name.isEmpty])
    .navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button(store.t("Save")) {
          if store.saveSplit(id: workout.id, name: name, exercises: exercises) {
            JourneyHaptic.play(.success, store.profile)
            if let saved = store.data.workouts.first(where: { $0.id == workout.id }), let onSaved { onSaved(saved) }
            else { dismiss() }
          } else { error = true }
        }.fontWeight(.semibold).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityIdentifier("split.save")
      }
    }
    .onAppear { if workout.name.isEmpty { naming = true } }
  }
}

/// Pick exercises for a split: grouped by area, a check that fills in the signal colour, a running
/// count, and search that offers to create what it can't find.
struct SplitExercisePicker: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @Binding var exercises: [Exercise]
  @State private var search = ""
  @State private var creating = false
  private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var matches: [Exercise] {
    store.allExercises.filter { query.isEmpty || store.t($0.name).localizedCaseInsensitiveContains(query) }
  }
  /// Areas in catalogue order, then anything custom.
  private var groups: [(area: String, exercises: [Exercise])] {
    var order: [String] = []
    var byArea: [String: [Exercise]] = [:]
    for exercise in matches {
      if byArea[exercise.area] == nil { order.append(exercise.area) }
      byArea[exercise.area, default: []].append(exercise)
    }
    return order.map { ($0, byArea[$0] ?? []) }
  }
  private var exact: Bool { matches.contains { store.t($0.name).localizedCaseInsensitiveCompare(query) == .orderedSame } }
  var body: some View {
    List {
      ForEach(groups, id: \.area) { group in
        Section {
          ForEach(group.exercises) { exercise in row(exercise) }
        } header: { Eyebrow(text: store.t(group.area)).textCase(nil) }
      }
      if !query.isEmpty && !exact {
        Section {
          Button { creating = true } label: {
            Label(String(format: store.t("Add “%@”"), query), systemImage: "plus")
              .font(.body.weight(.medium)).foregroundStyle(JourneyColor.text)
          }.accessibilityIdentifier("split.exercise.new")
        }
      } else if query.isEmpty {
        Section {
          Button { creating = true } label: {
            Label(store.t("New exercise"), systemImage: "plus").font(.body.weight(.medium)).foregroundStyle(JourneyColor.text)
          }.accessibilityIdentifier("split.exercise.new")
        }
      }
    }
    .searchable(text: $search, prompt: store.t("Search exercises")).gymSearchNavigation().gymPage()
    .animation(.spring(duration: 0.4, bounce: 0.1), value: matches.map(\.id))
    .navigationDestination(isPresented: $creating) {
      CustomExerciseView(embedded: true, initialName: query) { exercises.append($0) }
    }
    .navigationTitle(store.t("Add exercises")).navigationBarTitleDisplayMode(.inline).track(screen: "split.exercises")
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button { dismiss() } label: {
          HStack(spacing: 6) {
            if !exercises.isEmpty {
              Text("\(exercises.count)").font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(JourneyColor.onAccent)
                .padding(.horizontal, 7).frame(minWidth: 22, minHeight: 22).background(Capsule().fill(JourneyColor.signal))
                .contentTransition(.numericText()).animation(.spring(duration: 0.35, bounce: 0.3), value: exercises.count)
            }
            Text(store.t("Done")).fontWeight(.semibold)
          }
        }.accessibilityLabel(store.t("Done") + (exercises.isEmpty ? "" : ", \(exercises.count) " + store.t("selected")))
          .accessibilityIdentifier("split.exercises.done")
      }
    }
  }
  private func row(_ exercise: Exercise) -> some View {
    let selected = exercises.contains { $0.id == exercise.id }
    return Button {
      withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
        if selected { exercises.removeAll { $0.id == exercise.id } } else { exercises.append(exercise) }
      }
      JourneyHaptic.play(.selection, store.profile)
    } label: {
      HStack(spacing: 12) {
        Text(store.t(exercise.name)).foregroundStyle(JourneyColor.text)
        Spacer()
        ZStack {
          Circle().strokeBorder(JourneyColor.ink(selected ? 0 : 0.25), lineWidth: 1.5)
          Circle().fill(JourneyColor.signal).scaleEffect(selected ? 1 : 0.3).opacity(selected ? 1 : 0)
          Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(JourneyColor.onAccent)
            .scaleEffect(selected ? 1 : 0.5).opacity(selected ? 1 : 0)
        }.frame(width: 24, height: 24).accessibilityHidden(true)
      }.frame(minHeight: 40).contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("split.exercise.\(exercise.id)")
  }
}
