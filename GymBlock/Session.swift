import SwiftUI

/// One tap chooses. This workout's exercises come first (with sets done), then recent ones,
/// then everything by body area.
struct ExercisePickerContent: View {
  @EnvironmentObject private var store: GymStore
  @State private var search = ""
  @State private var custom = false
  let onChoose: (Exercise) -> Void
  private var current: [Exercise] { store.session?.exercises ?? [] }
  private var recent: [Exercise] {
    var seen = Set(current.map(\.id))
    return Array(store.data.history.sorted { $0.started > $1.started }.flatMap(\.sets).map(\.exercise)
      .filter { seen.insert($0.id).inserted }.prefix(5))
  }
  private var areas: [(String, [Exercise])] {
    let shown = Set((current + recent).map(\.id))
    let all = store.allExercises.filter { !shown.contains($0.id) }
    let known = Exercise.areas.compactMap { area in
      let items = all.filter { $0.area == area }
      return items.isEmpty ? nil : (area, items)
    }
    let other = all.filter { !Exercise.areas.contains($0.area) }
    return known + (other.isEmpty ? [] : [("Your exercises", other)])
  }
  private var matches: [Exercise] {
    store.allExercises.filter { store.t($0.name).localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search) }
  }
  var body: some View {
    List {
      if search.isEmpty {
        if !current.isEmpty { Section(store.t("This workout")) { ForEach(current) { exerciseRow($0) } } }
        if !recent.isEmpty { Section(store.t("Recent")) { ForEach(recent) { exerciseRow($0) } } }
        ForEach(areas, id: \.0) { area, items in
          Section(store.t(area)) { ForEach(items) { exerciseRow($0) } }
        }
      } else {
        Section { ForEach(matches) { exerciseRow($0) } }
        if matches.isEmpty { Text(store.t("No matches")).foregroundStyle(GymColor.dim) }
      }
      Button {
        custom = true
      } label: {
        Label(search.isEmpty ? store.t("New exercise") : store.t("Create") + " ‘" + search + "’", systemImage: "plus")
          .foregroundStyle(GymColor.ink)
      }.accessibilityIdentifier("exercise.custom")
    }.gymPage().searchable(text: $search, prompt: store.t("Search exercises")).gymSearchNavigation()
      .navigationDestination(isPresented: $custom) {
        CustomExerciseView(embedded: true, initialName: search) { onChoose($0) }
      }
  }
  private func exerciseRow(_ exercise: Exercise) -> some View {
    let done = store.doneSets(exercise)
    return Button { dismissKeyboard(); onChoose(exercise) } label: {
      HStack {
        Text(store.t(exercise.name)).foregroundStyle(GymColor.ink)
        Spacer()
        if store.session?.selected?.id == exercise.id {
          Image(systemName: "checkmark").foregroundStyle(GymColor.red).accessibilityHidden(true)
        } else if done > 0 {
          Text(setCount(done, store: store)).font(.subheadline).foregroundStyle(GymColor.dim).monospacedDigit()
        }
      }.frame(minHeight: 44)
    }.accessibilityIdentifier("exercise." + exercise.id)
  }
}
struct SelectNumberOnFocus: ViewModifier {
  func body(content: Content) -> some View {
    content.onReceive(
      NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
    ) { notification in
      guard let field = notification.object as? UITextField, field.isFirstResponder else { return }
      // Select the old value so typing replaces it — but never after typing has started,
      // or the next keystroke would overwrite what was just typed.
      let original = field.text
      DispatchQueue.main.async { if field.isFirstResponder && field.text == original { field.selectAll(nil) } }
    }
  }
}
struct SessionRecordsView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var adding = false
  var body: some View {
    NavigationStack {
      Group {
        if let session = store.session {
          WorkoutDetailView(sessionID: session.id, embedded: true,
                            cancelSet: session.stage == .active || session.stage == .log ? { store.cancelSet(); dismiss() } : nil)
        }
      }
        .gymPage().navigationTitle(store.t("Sets")).navigationBarTitleDisplayMode(.inline).toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("records.done")
          }
          ToolbarItem(placement: .topBarLeading) {
            Button(store.t("Add set")) { adding = true }.accessibilityLabel(store.t("Add completed set")).accessibilityIdentifier(
              "records.add")
          }
        }.navigationDestination(isPresented: $adding) {
          SetEditor(set: nil, sessionID: store.session?.id ?? UUID(), embedded: true)
        }
    }
  }
}
struct SetEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  let set: LoggedSet?
  let sessionID: UUID
  var embedded = false
  @State private var weight = ""
  @State private var reps = ""
  @State private var minutes = ""
  @State private var warmup = false
  @State private var date = Date()
  @State private var error = false
  @State private var elapsedSeconds = ""
  @State private var gapSeconds = ""
  @State private var timingExpanded = false
  @State private var detent = PresentationDetent.medium
  private var exercise: Exercise? { self.set?.exercise ?? store.session?.selected }
  var body: some View {
    Group {
      if embedded { editor } else { NavigationStack { editor } }
    }.presentationDetents([.medium, .large], selection: $detent)
      .onChange(of: timingExpanded) { _, expanded in
        if expanded { detent = .large }
      }
  }
  private var editor: some View {
      Form {
        if let exercise {
          if !exercise.timed {
            labeledInput("Weight", text: $weight, unit: store.profile.unit, id: "edit.weight", decimal: true)
          }
          if set?.unsuccessful == true {
            Text(store.t("Unsuccessful attempt · 0 completed reps")).foregroundStyle(
              GymColor.dim)
          } else if exercise.timed {
            labeledInput("Time", text: $minutes, unit: store.t("min"), id: "edit.minutes", decimal: true)
          } else {
            labeledInput("Reps", text: $reps, unit: "", id: "edit.reps", decimal: false)
          }

        }
        if set == nil && exercise?.timed != true {
          DisclosureGroup(store.t("Details")) { Toggle(store.t("Warm-up"), isOn: $warmup) }
        }
        if let set {
          DisclosureGroup(store.t("Details"), isExpanded: $timingExpanded) {
            if exercise?.timed != true { Toggle(store.t("Warm-up"), isOn: $warmup) }
            DatePicker(store.t("Completed at"), selection: $date, in: ...Date())
            timingInput("Set time (seconds)", text: $elapsedSeconds, id: "edit.elapsed")
            if set.gapSourceID != nil {
              timingInput("Gap before (seconds)", text: $gapSeconds, id: "edit.gap")
            }
            Text(
              store.t(
                "Elapsed Start-to-Finish time. Gaps include exercise changes and interruptions.")
            )
            .font(GymType.body(13)).foregroundStyle(GymColor.dim)
          }
        }
        if error { Text(store.t("Check the entered values.")).foregroundStyle(GymColor.red) }
        if let set {
          Button(store.t("Delete set"), role: .destructive) {
            store.deleteSet(set, sessionID: sessionID)
            dismiss()
          }.accessibilityIdentifier("edit.delete")
        }
      }.gymPage().navigationTitle(store.t(set == nil ? "Add completed set" : "Edit set"))
        .navigationBarTitleDisplayMode(.inline).navigationBarBackButtonHidden()
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Save")) { save() }.accessibilityIdentifier("edit.save")
          }

        }
        .onAppear {
          weight = inputNumber(
            GymStore.displayedWeight(
              set?.weightKG ?? store.session?.weightKG ?? 0, unit: store.profile.unit))
          reps = String(set?.reps ?? store.session?.draftReps ?? 10)
          minutes = inputNumber(set?.minutes ?? 5)
          warmup = set?.warmup ?? false
          date = set?.date ?? Date()
          elapsedSeconds = set?.displayedSetSeconds.map(inputNumber) ?? ""
          gapSeconds = set?.gapUnknown == true ? "" : set?.gapBeforeSeconds.map(inputNumber) ?? ""
        }
  }
  private func labeledInput(_ title: String, text: Binding<String>, unit: String, id: String, decimal: Bool) -> some View {
    HStack {
      Text(store.t(title)); Spacer()
      TextField("—", text: text).keyboardType(decimal ? .decimalPad : .numberPad)
        .multilineTextAlignment(.trailing).frame(minWidth: 60, maxWidth: 100)
        .accessibilityLabel(store.t(title)).accessibilityIdentifier(id).modifier(SelectNumberOnFocus())
      if !unit.isEmpty { Text(unit).foregroundStyle(GymColor.dim) }
    }
  }
  @ViewBuilder private func timingInput(_ title: String, text: Binding<String>, id: String)
    -> some View
  {
    let label = Text(store.t(title)).accessibilityHidden(true)
    let field = TextField(store.t("Not recorded"), text: text)
      .keyboardType(.decimalPad).accessibilityLabel(store.t(title))
      .accessibilityIdentifier(id).frame(minHeight: 44)
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 8) {
        label.font(GymType.body(14)).foregroundStyle(GymColor.dim)
        field
      }.accessibilityElement(children: .contain)
    } else {
      HStack {
        label
        Spacer()
        field.multilineTextAlignment(.trailing).frame(width: 100)
      }.accessibilityElement(children: .contain)
    }
  }
  private func save() {
    guard let exercise, let value = parseNumber(weight), value.isFinite, (0...500).contains(value)
    else {
      error = true
      return
    }
    if var set {
      set.weightKG = exercise.timed ? 0 : GymStore.kilograms(value, unit: store.profile.unit)
      set.reps = exercise.timed || set.unsuccessful == true ? 0 : Int(reps) ?? 0
      set.minutes = exercise.timed ? parseNumber(minutes) ?? 0 : 0
      set.warmup = warmup
      let elapsed = elapsedSeconds.isEmpty ? nil : parseNumber(elapsedSeconds)
      let gap = gapSeconds.isEmpty ? nil : parseNumber(gapSeconds)
      guard elapsedSeconds.isEmpty || elapsed != nil, gapSeconds.isEmpty || gap != nil,
        [elapsed, gap].allSatisfy({ $0 == nil || ($0!.isFinite && $0! >= 0 && $0! <= 604800) })
      else {
        error = true
        return
      }
      set.elapsedSetSeconds = elapsed
      set.timingUnknown = elapsed == nil
      set.gapBeforeSeconds = gap
      set.gapUnknown = gap == nil || date != set.date
      set.date = date
      if store.editSet(set, sessionID: sessionID) { dismiss() } else { error = true }
    } else if store.addCompletedSet(
      exercise: exercise, weight: value, reps: Int(reps) ?? 0, minutes: parseNumber(minutes) ?? 0,
      warmup: warmup)
    {
      dismiss()
    } else {
      error = true
    }
  }
}
struct CustomExerciseView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var embedded = false
  var initialName = ""
  @State private var name = ""
  @State private var timed = false
  let onAdd: (Exercise) -> Void
  var body: some View {
    Group { if embedded { form } else { NavigationStack { form } } }
      .onAppear { name = initialName }
  }
  private var form: some View {
    Form {
      LabeledContent(store.t("Name")) {
        TextField(store.t("Name"), text: $name).multilineTextAlignment(.trailing).accessibilityIdentifier("custom.name")
      }
      Picker(store.t("Measure"), selection: $timed) {
        Text(store.t("Reps")).tag(false); Text(store.t("Time")).tag(true)
      }
    }.gymPage().navigationTitle(store.t("New exercise")).navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden().toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(store.t("Save")) {
            onAdd(Exercise(id: UUID().uuidString, name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)), area: "Your training", timed: timed))
            dismiss()
          }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("custom.add")
        }
      }
  }
}
func parseNumber(_ text: String) -> Double? {
  let separator = Locale.current.decimalSeparator ?? "."
  return Double(
    text.replacingOccurrences(of: separator, with: ".").replacingOccurrences(of: ",", with: "."))
}
func inputNumber(_ value: Double) -> String {
  value.formatted(
    .number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2)).grouping(
      .never))
}
func clockString(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

/// "1 set", "2 sets".
@MainActor func setCount(_ n: Int, store: GymStore) -> String {
  "\(n) " + store.t(n == 1 ? "set" : "sets")
}
