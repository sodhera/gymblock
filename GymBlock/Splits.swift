import SwiftUI

struct SplitEditor: View {
  let workout: Workout
  var body: some View { NavigationStack { SplitEditorContent(workout: workout) } }
}

/// A split: its name and the exercises in order. Native editing (drag to reorder, swipe to delete)
/// on the paper stage, with the name as the page's own headline.
/// A split, designed from a clean slate on 11 Oct 2026: the name is the page's title (typed in place),
/// one grey line under it, then the exercises as numbered ruled rows (hold and drag to reorder, swipe
/// to remove) and a quiet "Add exercises" row. Cancel and Save sit in the bar.
struct SplitEditorContent: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let workout: Workout
  var onSaved: ((Workout) -> Void)?
  @State private var name: String
  @State private var exercises: [Exercise]
  @State private var color: SplitColor
  @State private var adding = false
  @FocusState private var naming: Bool
  init(workout: Workout, onSaved: ((Workout) -> Void)? = nil) {
    self.workout = workout; self.onSaved = onSaved
    _name = State(initialValue: workout.name); _exercises = State(initialValue: workout.exercises)
    _color = State(initialValue: workout.splitColor)
  }
  private var duplicate: Bool {
    store.data.workouts.contains { $0.id != workout.id && $0.name.localizedCaseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
  }
  private var canSave: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty && !duplicate }
  private var line: String {
    if duplicate { return store.t("This name is already used.") }
    if exercises.isEmpty { return store.t("Add an exercise to save.") }
    return exercises.count == 1 ? store.t("1 exercise") : "\(exercises.count) " + store.t("exercises")
  }
  var body: some View {
    List {
      VStack(alignment: .leading, spacing: 6) {
        TextField(store.t("Push, Pull, Legs…"), text: $name)
          .font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
          .textInputAutocapitalization(.words).submitLabel(.done).focused($naming).tint(JourneyColor.signal)
          .onChange(of: name) { _, value in if value.count > 50 { name = String(value.prefix(50)) } }
          .accessibilityIdentifier("split.name")
        Text(line).font(.app(.subheadline)).foregroundStyle(duplicate ? JourneyColor.signal : JourneyColor.tertiary)
          .accessibilityIdentifier("split.line")
      }.padding(.top, 4).padding(.bottom, 22).pageRow().listRowSeparator(.hidden)
      PageLabel(text: store.t("Colour")).pageRow().listRowSeparator(.hidden)
      swatches.padding(.top, 2).padding(.bottom, 26).pageRow().listRowSeparator(.hidden)
      PageLabel(text: store.t("Exercises")).pageRow().listRowSeparator(.hidden, edges: .top)
      ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
        HStack(alignment: .firstTextBaseline, spacing: 14) {
          Text("\(index + 1)").font(.app(.subheadline, weight: .medium)).monospacedDigit()
            .foregroundStyle(JourneyColor.tertiary).frame(width: 20, alignment: .leading)
          Text(store.t(exercise.name)).font(.app(.title3)).foregroundStyle(JourneyColor.text).lineLimit(1)
          Spacer(minLength: 0)
        }.frame(minHeight: 52).pageRow()
          .accessibilityIdentifier("split.row.\(exercise.id)")
      }
      .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
      .onDelete { exercises.remove(atOffsets: $0) }
      Button { naming = false; adding = true } label: {
        HStack(spacing: 10) {
          Image(systemName: "plus").font(.system(.body, weight: .semibold))
          Text(store.t(exercises.isEmpty ? "Add exercises" : "Add more")).font(.app(.body))
        }.foregroundStyle(JourneyColor.signal).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.hapticPlain).pageRow().listRowSeparator(.hidden, edges: .bottom)
        .accessibilityIdentifier("split.exercises")
      if exercises.count > 1 {
        Text(store.t("Hold and drag to reorder. Swipe to remove.")).font(.app(.footnote)).foregroundStyle(JourneyColor.tertiary)
          .padding(.top, 6).pageRow().listRowSeparator(.hidden)
      }
    }
    .listStyle(.plain).scrollContentBackground(.hidden).background(DotGrid())
    .navigationDestination(isPresented: $adding) { SplitExercisePicker(exercises: $exercises) }
    .navigationTitle(store.t(workout.name.isEmpty ? "New split" : "Edit split")).navigationBarTitleDisplayMode(.inline)
    // Cancel and Save are the way out, pushed or presented; a back arrow beside Cancel would be a second one.
    .navigationBarBackButtonHidden()
    .track(screen: "split.edit", ["new": workout.name.isEmpty])
    // Ready to type the name, once the sheet or push has settled (focus asked for mid-presentation is dropped).
    .task {
      guard workout.name.isEmpty && name.isEmpty else { return }
      try? await Task.sleep(for: .milliseconds(450))
      naming = true
    }
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { JourneyHaptic.pressLight(); dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button(store.t("Save")) { JourneyHaptic.pressLight()
          if store.saveSplit(id: workout.id, name: name, exercises: exercises, color: color) {
            JourneyHaptic.play(.success, store.profile)
            if let saved = store.data.workouts.first(where: { $0.id == workout.id }), let onSaved { onSaved(saved) }
            else { dismiss() }
          }
        }.fontWeight(.semibold).disabled(!canSave).accessibilityIdentifier("split.save")
      }
    }
  }

  /// The split's colour, as its days will look on Home, Profile and the widgets: ten dots in one row,
  /// a ring round the chosen one.
  private var swatches: some View {
    HStack(spacing: 0) {
      ForEach(SplitColor.allCases) { option in
        Button {
          guard option != color else { return }
          color = option
          JourneyHaptic.play(.selection, store.profile)
        } label: {
          Circle().fill(Color.paper(option.paper)).frame(width: 24, height: 24)
            .padding(4)
            .overlay(Circle().strokeBorder(JourneyColor.text, lineWidth: option == color ? 2 : 0))
            .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(store.t(option.label)).accessibilityAddTraits(option == color ? .isSelected : [])
        .accessibilityIdentifier("split.color." + option.rawValue)
      }
    }
    .animation(JourneyMotion.gentle, value: color)
  }
}

/// Pick exercises for a split: grouped by area, a check that fills in the signal colour, a running
/// count, and search that offers to create what it can't find.
/// Add exercises to a split: the catalogue by area as ruled rows, an emerald check on each one
/// chosen, search in the bar, and "New exercise" (or "Add “…”" for a search with no match) last.
/// The title counts what's chosen.
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
        PageLabel(text: store.t(group.area)).padding(.top, 18).pageRow().listRowSeparator(.hidden, edges: .top)
        ForEach(group.exercises) { exercise in row(exercise) }
      }
      Button { creating = true } label: {
        HStack(spacing: 10) {
          Image(systemName: "plus").font(.system(.body, weight: .semibold))
          Text(!query.isEmpty && !exact ? String(format: store.t("Add “%@”"), query) : store.t("New exercise")).font(.app(.body)).lineLimit(1)
        }.foregroundStyle(JourneyColor.signal).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.hapticPlain).padding(.top, 8).pageRow().listRowSeparator(.hidden)
        .accessibilityIdentifier("split.exercise.new")
    }
    .listStyle(.plain).scrollContentBackground(.hidden).background(DotGrid())
    .searchable(text: $search, prompt: store.t("Search exercises")).gymSearchNavigation()
    .animation(.smooth(duration: 0.3), value: matches.map(\.id))
    .navigationDestination(isPresented: $creating) {
      CustomExerciseView(embedded: true, initialName: query) { exercises.append($0) }
    }
    .navigationTitle(exercises.isEmpty ? store.t("Add exercises") : "\(exercises.count) " + store.t("selected"))
    .navigationBarTitleDisplayMode(.inline).track(screen: "split.exercises")
    // Done is the way back; a back arrow beside it would be a second one.
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(store.t("Done")) { JourneyHaptic.pressLight(); dismiss() }.fontWeight(.semibold)
          .accessibilityLabel(store.t("Done") + (exercises.isEmpty ? "" : ", \(exercises.count) " + store.t("selected")))
          .accessibilityIdentifier("split.exercises.done")
      }
    }
  }
  private func row(_ exercise: Exercise) -> some View {
    let selected = exercises.contains { $0.id == exercise.id }
    return Button {
      withAnimation(.smooth(duration: 0.2)) {
        if selected { exercises.removeAll { $0.id == exercise.id } } else { exercises.append(exercise) }
      }
      JourneyHaptic.play(.selection, store.profile)
    } label: {
      HStack(spacing: 12) {
        Text(store.t(exercise.name)).font(.app(.body)).foregroundStyle(JourneyColor.text).lineLimit(1)
        Spacer(minLength: 8)
        if selected {
          Image(systemName: "checkmark").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.signal)
            .transition(.scale.combined(with: .opacity)).accessibilityHidden(true)
        }
      }.frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).contentShape(Rectangle())
    }.buttonStyle(.hapticPlain).pageRow()
      .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier("split.exercise.\(exercise.id)")
  }
}

/// A small uppercase label over a run of rows, as on the workout page, the entry page and the summary.
struct PageLabel: View {
  let text: String
  var body: some View {
    Text(text).font(.app(.caption, weight: .semibold)).tracking(1.4).textCase(.uppercase)
      .foregroundStyle(JourneyColor.secondary).frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
      .accessibilityAddTraits(.isHeader)
  }
}

extension View {
  /// A row of a plain List laid on the paper page: no background, hairline rules, 24-pt gutters.
  func pageRow() -> some View {
    listRowBackground(Color.clear).listRowSeparatorTint(JourneyColor.ink(0.08))
      .listRowInsets(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
  }
}
