import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @State private var settings = false
  @State private var choice = false
  var onSplits: () -> Void = {}
  private var split: Workout? { store.data.workouts.first { $0.id == store.profile.preferredSplitID } }
  private var weeklyWorkouts: Int {
    let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())!.start
    return store.data.history.filter { ($0.ended ?? $0.started) >= start && !$0.completedSets.isEmpty }.count
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 40) {
          HStack(spacing: 12) {
            Text(store.profile.language == "es"
                 ? "\(weeklyWorkouts) entrenamientos esta semana"
                 : "\(weeklyWorkouts) \(weeklyWorkouts == 1 ? "workout" : "workouts") this week")
              .font(GymType.body(15)).foregroundStyle(GymColor.dim).accessibilityIdentifier("home.activity")
            if store.data.demoLoaded == true {
              Text(store.t("Demo")).font(GymType.body(13)).foregroundStyle(GymColor.dim)
            }
          }
          Button { choice = true } label: {
            HStack {
              Text(split?.name ?? store.t("Free workout")).font(GymType.title(28))
              Spacer()
              Image(systemName: "chevron.down").font(.system(size: 14, weight: .medium)).accessibilityHidden(true)
            }.foregroundStyle(GymColor.ink).frame(minHeight: 56).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityIdentifier("home.workout")
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
      }.gymPage().navigationTitle(store.t("Workout"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button { settings = true } label: { Image(systemName: "gearshape") }
              .accessibilityLabel(store.t("Settings")).accessibilityIdentifier("home.preferences")
          }
        }
        .safeAreaInset(edge: .bottom) {
          GymButton(title: store.t("Start workout"), id: "home.start") { store.startSession(workout: split) }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
        }
        .sheet(isPresented: $settings) { PreferencesView() }
        .sheet(isPresented: $choice) { WorkoutChoiceView() }
    }
  }
}

struct WorkoutChoiceView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        choice(store.t("Free workout"), id: nil)
        ForEach(store.data.workouts) { choice($0.name, id: $0.id) }
        NavigationLink(store.t("Create split")) {
          SplitEditorContent(workout: Workout(name: "", exercises: [])) { split in
            store.updateProfile { $0.preferredSplitID = split.id }; dismiss()
          }
        }
      }.gymPage().navigationTitle(store.t("Choose workout")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } } }
    }.presentationDetents([.medium, .large])
  }
  private func choice(_ name: String, id: UUID?) -> some View {
    Button {
      store.updateProfile { $0.preferredSplitID = id }; dismiss()
    } label: {
      HStack {
        Text(name).foregroundStyle(GymColor.ink); Spacer()
        if store.profile.preferredSplitID == id {
          Image(systemName: "checkmark").foregroundStyle(GymColor.red).accessibilityHidden(true)
        }
      }.frame(minHeight: 44)
    }.accessibilityAddTraits(store.profile.preferredSplitID == id ? .isSelected : [])
  }
}

struct PreferencesView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker(store.t("Units"), selection: Binding(get: { store.profile.unit }, set: { v in store.updateProfile { $0.unit = v } })) {
            Text("kg").tag("kg"); Text("lb").tag("lb")
          }
          HStack {
            Text(store.t("Name"))
            TextField(store.t("Optional"), text: Binding(get: { store.profile.name }, set: { v in store.updateProfile { $0.name = String(v.prefix(40)) } }))
              .multilineTextAlignment(.trailing)
          }
          Picker(store.t("Language"), selection: Binding(get: { store.profile.language }, set: { v in store.updateProfile { $0.language = v } })) {
            Text("English").tag("en"); Text("Español").tag("es")
          }
          Toggle(store.t("Haptics"), isOn: Binding(get: { store.profile.hapticsEnabled ?? true }, set: { v in store.updateProfile { $0.hapticsEnabled = v } }))
          Toggle(store.t("Sound"), isOn: Binding(get: { store.profile.soundEnabled ?? false }, set: { v in store.updateProfile { $0.soundEnabled = v } }))
        }
        Section {
          NavigationLink(store.t("Training answers")) { TrainingAnswersForm() }.accessibilityIdentifier("settings.baseline")
          NavigationLink(store.t("Focus demo")) { FocusSettingsForm() }
          NavigationLink(store.t("Data")) { DataSettingsView() }
        }
      }.gymPage().navigationTitle(store.t("Settings")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("preferences.done") } }
    }
  }
}

struct FocusSettingsForm: View {
  @EnvironmentObject private var store: GymStore
  var body: some View {
    Form {
      Toggle(store.t("Focus demo"), isOn: Binding(get: { store.profile.focusEnabled ?? false }, set: { v in store.updateProfile { $0.focusEnabled = v } }))
        .accessibilityIdentifier("focus.enabled")
      Text(store.t("This demo doesn’t block other apps.")).foregroundStyle(GymColor.dim)
    }.gymPage().navigationTitle(store.t("Focus demo")).navigationBarTitleDisplayMode(.inline)
  }
}
struct DataSettingsView: View {
  @EnvironmentObject private var store: GymStore
  @State private var deleting = false
  var body: some View {
    Form {
      if store.data.history.isEmpty && store.data.workouts.isEmpty {
        Button(store.t("Load sample workouts")) { store.loadDemoIfEmpty() }.accessibilityIdentifier("settings.demo")
      }
      Button(store.t("Delete training answers"), role: .destructive) { deleting = true }
    }.gymPage().navigationTitle(store.t("Data")).navigationBarTitleDisplayMode(.inline)
      .confirmationDialog(store.t("Delete training answers?"), isPresented: $deleting, titleVisibility: .visible) {
        Button(store.t("Delete answers"), role: .destructive) { store.deleteRoutineAnswers() }
        Button(store.t("Cancel"), role: .cancel) {}
      } message: { Text(store.t("Workouts and splits stay saved.")) }
  }
}

struct TrainingAnswersForm: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var draft = RoutineBaseline()
  @State private var error = false
  @State private var raw: [String: String] = [:]
  @State private var invalid = Set<String>()
  var body: some View {
    Form {
      Section {
        habit("Phone between sets", value: $draft.scrollFrequency)
        number("Minutes / rest", value: Binding(get: { draft.scrollingMinutes.map(inputNumber) ?? "" }, set: { draft.scrollingMinutes = parseNumber($0); draft.minutesPerBreak = nil }), unit: "min")
      }
      Section {
        number("Exercises / workout", value: survey(.exercises))
        number("Sets / exercise", value: survey(.sets))
        number("Reps / set", value: survey(.reps))
        number("Days / week", value: Binding(get: { draft.trainingDays.map(String.init) ?? "" }, set: { draft.trainingDays = Int($0) }))
      }
      if error { Text(store.t("Check the entered values.")).foregroundStyle(GymColor.red) }
    }.gymPage().navigationTitle(store.t("Training answers")).navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(store.t("Save")) {
            guard invalid.isEmpty, draft.trainingDays == nil || (1...7).contains(draft.trainingDays!),
              draft.duration == nil || (1...600).contains(draft.duration!),
              draft.exercises == nil || (1...50).contains(draft.exercises!),
              draft.sets == nil || (1...50).contains(draft.sets!),
              draft.reps.isEmpty || RoutineBaseline.repRange(draft.reps) != nil,
              draft.scrollingMinutes == nil || (draft.scrollingMinutes!.isFinite && (0...600).contains(draft.scrollingMinutes!))
            else { error = true; return }
            draft.scrollsBetweenSets = draft.scrollFrequency.map { $0 != .no }
            store.updateProfile { $0.baseline = draft }; dismiss()
          }
        }
      }.onAppear { draft = store.profile.baseline ?? RoutineBaseline() }
  }
  private func survey(_ field: SurveyField) -> Binding<String> {
    Binding(get: { field.read(draft) }, set: {
      field.write($0, into: &draft)
      if field == .reps && !$0.isEmpty { draft.timed = false }
    })
  }
  private func number(_ label: String, value: Binding<String>, unit: String = "") -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(store.t(label)); Spacer()
        TextField("—", text: Binding(get: { raw[label] ?? value.wrappedValue }, set: { text in
          raw[label] = text
          let valid: Bool
          if text.isEmpty { valid = true }
          else if label == "Reps / set" { valid = RoutineBaseline.repRange(text) != nil }
          else if label == "Minutes / rest" { valid = parseNumber(text).map { $0.isFinite && (0...600).contains($0) } ?? false }
          else {
            let range: ClosedRange<Int> = label == "Days / week" ? 1...7 : label == "Workout length" ? 1...600 : label == "Scrolling breaks" ? 0...2500 : 1...50
            valid = Int(text).map { range.contains($0) } ?? false
          }
          if valid { invalid.remove(label); value.wrappedValue = text } else { invalid.insert(label) }
        })).keyboardType(label == "Reps / set" ? .numbersAndPunctuation : .decimalPad)
          .multilineTextAlignment(.trailing).frame(minWidth: 60, maxWidth: 100)
          .accessibilityLabel(store.t(label)).modifier(SelectNumberOnFocus())
        if !unit.isEmpty { Text(unit).foregroundStyle(GymColor.dim) }
      }
      if invalid.contains(label) { Text(store.t("Check this value.")).font(GymType.body(13)).foregroundStyle(GymColor.red) }
    }
  }
  private func habit(_ label: String, value: Binding<HabitAnswer?>) -> some View {
    Picker(store.t(label), selection: value) {
      Text(store.t("Not sure")).tag(Optional<HabitAnswer>.none)
      ForEach(HabitAnswer.allCases, id: \.self) { item in
        Text(store.t(item == .yes ? "Yes" : item == .sometimes ? "Sometimes" : "No")).tag(Optional(item))
      }
    }
  }
}

struct WorkoutRecap: View {
  @EnvironmentObject private var store: GymStore
  let session: Session
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(store.t(session.name)).font(GymType.label(17))
        Spacer()
        Text(session.ended ?? session.started, format: .dateTime.month(.abbreviated).day()).font(
          GymType.body(12)
        ).foregroundStyle(GymColor.dim)
      }
      Text(
        "\(session.completedSets.count) " + store.t("sets")
          + " · \(max(1, Int(session.duration / 60))) " + store.t("min")
      ).font(GymType.body(15)).foregroundStyle(GymColor.dim)
    }
  }
}
struct WorkoutDetailView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  let sessionID: UUID
  var embedded = false
  @State private var editing: LoggedSet?
  private var session: Session? {
    store.data.history.first { $0.id == sessionID } ?? store.session.flatMap { $0.id == sessionID ? $0 : nil }
  }
  private var exercises: [Exercise] {
    var seen = Set<String>()
    return (session?.sets ?? []).map(\.exercise).filter { seen.insert($0.id).inserted }
  }
  var body: some View {
    List {
      if let session {
        if !embedded {
          Section {
            Text(session.ended ?? session.started, format: .dateTime.month(.wide).day().year())
              .foregroundStyle(GymColor.dim)
            Text("\(max(1, Int(session.duration / 60))) " + store.t("min") + " · \(session.totalReps) " + store.t("reps"))
          }.listRowBackground(Color.clear)
        }
        ForEach(exercises) { exercise in
          Section {
            let sets = session.sets.filter { $0.exercise.id == exercise.id }
            HStack {
              Text(store.t("Set")).frame(width: 40, alignment: .leading)
              if !exercise.timed { Spacer(); Text(store.t("Weight") + " (" + store.profile.unit + ")") }
              Spacer()
              Text(store.t(exercise.timed ? "Time" : "Reps")).frame(width: 60, alignment: .trailing)
            }.font(GymType.body(13)).foregroundStyle(GymColor.dim).accessibilityHidden(true)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
              Button { editing = set } label: {
                if typeSize.isAccessibilitySize {
                  VStack(alignment: .leading, spacing: 6) {
                    Text(store.t("Set") + " \(index + 1)")
                    Text(setValue(set, store: store))
                  }.foregroundStyle(GymColor.ink)
                } else {
                  HStack {
                    Text("\(index + 1)").frame(width: 40, alignment: .leading)
                    if !exercise.timed {
                      Spacer()
                      Text(set.weightKG == 0 ? store.t("Bodyweight") : formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)))
                    }
                    Spacer()
                    Text(set.unsuccessful == true ? store.t("Attempt") : exercise.timed ? formatNumber(set.minutes) + " " + store.t("min") : String(set.reps))
                      .frame(minWidth: 60, alignment: .trailing)
                  }.monospacedDigit().foregroundStyle(GymColor.ink).frame(minHeight: 44)
                }
              }.accessibilityLabel(store.t("Set") + " \(index + 1), " + setValue(set, store: store))
                .accessibilityIdentifier("saved." + set.id.uuidString)
            }
          } header: { Text(store.t(exercise.name)).font(GymType.label(17)).textCase(nil) }
        }
        if session.sets.isEmpty { Text(store.t("No sets yet")).foregroundStyle(GymColor.dim) }
      }
      if store.deletedSet != nil { Button(store.t("Undo")) { store.undoDelete() } }
    }.gymPage().navigationTitle(embedded ? store.t("Sets") : store.t(session?.name ?? "Workout"))
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
        if let editing { SetEditor(set: editing, sessionID: sessionID, embedded: true) }
      }
  }
}
struct SetList: View {
  @EnvironmentObject private var store: GymStore
  var sets: [LoggedSet]
  var body: some View {
    ForEach(sets) { set in
      HStack {
        Text(store.t(set.exercise.name))
        Spacer()
        Text(setValue(set, store: store)).foregroundStyle(GymColor.dim)
      }.font(GymType.body(15))
    }
  }
}
@MainActor func setValue(_ set: LoggedSet, store: GymStore) -> String {
  if set.unsuccessful == true {
    return store.t("Attempt") + " · "
      + formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)) + " "
      + store.profile.unit
  }
  if set.exercise.timed { return formatNumber(set.minutes) + " " + store.t("min") }
  let weight =
    set.weightKG == 0
    ? store.t("Bodyweight")
    : formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)) + " "
      + store.profile.unit
  return weight + " × \(set.reps)" + (set.warmup == true ? " · " + store.t("Warm-up") : "")
}
func formatNumber(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...2)))
}
