import SwiftUI

struct SessionView: View {
  @EnvironmentObject private var store: GymStore
  @State private var exercisePicker = false
  @State private var weightEditor = false
  @State private var switching = false
  @State private var pendingExercise: Exercise?
  @State private var records = false
  @State private var ending = false
  @State private var endingIdle = false
  @State private var zeroReps = false
  @State private var editing: LoggedSet?
  @State private var reps = ""
  @State private var minutes = ""
  private var session: Session { store.session ?? Session() }
  private var exercise: Exercise? { session.selected }
  private var active: Bool { session.stage == .active || session.stage == .log }
  private var selecting: Bool { session.stage == .exercise || session.stage == .workout }
  private var actualMinutes: Double {
    if let entered = parseNumber(minutes) { return entered }
    return max(0, Date().timeIntervalSince(session.setStarted ?? Date()) / 60)
  }
  private var valid: Bool {
    exercise?.timed == true ? actualMinutes.isFinite && actualMinutes > 0
      : Int(reps).map { (1...999).contains($0) } ?? false
  }
  private var weightLabel: String {
    let perDumbbell = exercise?.name.localizedCaseInsensitiveContains("dumbbell") == true || exercise?.id == "curl"
    return store.profile.unit + (perDumbbell ? " / " + store.t("dumbbell") : "")
  }
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        if selecting {
          ExercisePickerContent { store.chooseExercise($0) }
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 32) {
              Button { dismissKeyboard(); exercisePicker = true } label: {
                HStack(spacing: 16) {
                  Text(store.t(exercise?.name ?? "Exercise")).font(GymType.title(28))
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier("set.exercise")
                  Spacer(minLength: 8)
                  Image(systemName: "chevron.down").font(.system(size: 16, weight: .medium))
                    .foregroundStyle(GymColor.dim).accessibilityHidden(true)
                }.foregroundStyle(GymColor.ink).frame(minHeight: 56).contentShape(Rectangle())
              }.buttonStyle(.plain).accessibilityIdentifier("set.change")
                .accessibilityLabel(store.t("Change exercise") + ", " + store.t(exercise?.name ?? "Exercise"))
              if active { activeContent } else { readyContent }
              if store.profile.focusEnabled == true {
                Text(store.t("Focus demo")).font(GymType.body(13)).foregroundStyle(GymColor.dim)
                  .accessibilityIdentifier("session.blocking")
              }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
          }.scrollDismissesKeyboard(.interactively)
          VStack(spacing: 8) {
            if active {
              GymButton(title: store.t("Finish set"), enabled: valid || reps == "0", id: "set.stop") {
                if exercise?.timed != true && Int(reps) == 0 { dismissKeyboard(); zeroReps = true } else { finishSet() }
              }
            } else {
              GymButton(title: store.t("Start set"), enabled: exercise?.timed == true ||
                (session.weightIsSet != false && GymStore.displayedWeight(session.weightKG, unit: store.profile.unit) <= 500), id: "set.start") {
                dismissKeyboard(); minutes = ""; store.updateDraft(minutes: 0)
                store.startSet(weight: GymStore.displayedWeight(session.weightKG, unit: store.profile.unit), unit: store.profile.unit)
              }
            }
          }.padding(.horizontal, 24).padding(.top, 8)
        }
        Button {
          dismissKeyboard()
          // Never end a workout with saved sets on a single, possibly accidental, tap.
          if active { ending = true } else if !session.sets.isEmpty { endingIdle = true } else { store.finish() }
        } label: {
          Text(store.t("End workout")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
            .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
        }.buttonStyle(.plain)
          .accessibilityIdentifier("session.finish").padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 8)
      }.gymPage().navigationTitle(store.t(selecting ? "Choose exercise" : session.name)).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(store.t("Done")) { dismissKeyboard() }.accessibilityIdentifier("set.keyboard.done")
          }
          if active || !session.sets.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
              Button(store.t("Sets")) { dismissKeyboard(); records = true }
                .font(GymType.label(14)).accessibilityIdentifier("session.sets")
            }
          }
        }
        .confirmationDialog(store.t("Finish this set?"), isPresented: $ending, titleVisibility: .visible) {
          Button(store.t("Finish and end")) { finishSet(); store.finish() }.disabled(!valid).accessibilityIdentifier("session.saveEnd")
          Button(store.t("Discard set and end"), role: .destructive) { store.cancelSet(); store.finish() }.accessibilityIdentifier("session.discardEnd")
          Button(store.t("Keep going")) {}
        } message: { Text(store.t("Saved sets stay.")) }
        .confirmationDialog(store.t("End workout?"), isPresented: $endingIdle, titleVisibility: .visible) {
          Button(store.t("End workout")) { store.finish() }.accessibilityIdentifier("session.endConfirm")
          Button(store.t("Keep going"), role: .cancel) {}
        } message: { Text(setCount(session.completedSets.count, store: store) + " " + store.t("will be saved.")) }
        .alert(store.t("No reps recorded"), isPresented: $zeroReps) {
          Button(store.t("Edit reps"), role: .cancel) {}.accessibilityIdentifier("attempt.edit")
          Button(store.t("Record attempt")) { store.recordAttempt() }.accessibilityIdentifier("attempt.save")
          Button(store.t("Discard set"), role: .destructive) { store.cancelSet() }.accessibilityIdentifier("attempt.discard")
        }
        .sheet(isPresented: $exercisePicker, onDismiss: { if pendingExercise != nil { switching = true } }) {
          NavigationStack {
            ExercisePickerContent {
              if $0.id != exercise?.id {
                if active { pendingExercise = $0 } else { store.chooseExercise($0) }
              }
              exercisePicker = false
            }.gymPage().navigationTitle(store.t("Choose exercise")).navigationBarTitleDisplayMode(.inline)
              .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismissKeyboard(); exercisePicker = false }.accessibilityIdentifier("exercise.cancel") } }
          }
        }
        .sheet(isPresented: $weightEditor) {
          WeightEditor(weightKG: session.weightKG) { value, unit in store.updateWeight(value, unit: unit) }
        }
        .confirmationDialog(store.t("Finish this set?"), isPresented: $switching, titleVisibility: .visible) {
          Button(store.t("Finish and change")) { resolveSwitch(saving: true) }.disabled(!valid).accessibilityIdentifier("switch.save")
          Button(store.t("Discard set and change"), role: .destructive) { resolveSwitch(saving: false) }.accessibilityIdentifier("switch.discard")
          Button(store.t("Keep going")) { pendingExercise = nil }.accessibilityIdentifier("switch.cancel")
        } message: { Text(store.t("Saved sets stay.")) }
        .onChange(of: switching) { _, presented in if !presented { pendingExercise = nil } }
        .sheet(isPresented: $records) { SessionRecordsView() }
        .sheet(item: $editing) { SetEditor(set: $0, sessionID: session.id) }
        .onAppear { loadReps() }
        .onChange(of: session.selected?.id) { _, _ in loadReps(); minutes = "" }
        .onChange(of: reps) { _, value in store.updateRepText(value) }
    }
  }
  @ViewBuilder private var activeContent: some View {
    if exercise?.timed != true {
      Text(weightText).font(GymType.body(17)).foregroundStyle(GymColor.dim)
      VStack(spacing: 16) {
        Text(store.t("Reps")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
        HStack(spacing: 16) {
          Button { reps = String(max(0, (Int(reps) ?? 1) - 1)) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }
            .buttonStyle(.bordered).buttonBorderShape(.circle).accessibilityLabel(store.t("Decrease reps")).accessibilityIdentifier("set.reps.minus")
          TextField("—", text: $reps).font(GymType.hero(64)).monospacedDigit().keyboardType(.numberPad)
            .multilineTextAlignment(.center).accessibilityLabel(store.t("Reps")).accessibilityIdentifier("set.reps")
            .modifier(SelectNumberOnFocus())
          Button { reps = String(min(999, (Int(reps) ?? 0) + 1)) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
            .buttonStyle(.bordered).buttonBorderShape(.circle).accessibilityLabel(store.t("Increase reps")).accessibilityIdentifier("set.reps.plus")
        }
      }.padding(.vertical, 20)
    }
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 8) {
        Text(store.t("Set time")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
        Text(clockString(max(0, Int(context.date.timeIntervalSince(session.setStarted ?? context.date)))))
          .font(exercise?.timed == true ? GymType.hero(64) : GymType.body(20)).monospacedDigit()
          .accessibilityIdentifier("set.elapsed")
      }.frame(maxWidth: .infinity)
    }
  }
  @ViewBuilder private var readyContent: some View {
    if session.stage == .rest {
      if let last = session.sets.last {
        Button { editing = last } label: {
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(store.t("Last set")).foregroundStyle(GymColor.dim)
              Spacer()
              Text(setValue(last, store: store)).foregroundStyle(GymColor.ink)
            }
            if last.exercise.id != exercise?.id { Text(store.t(last.exercise.name)).font(GymType.body(13)).foregroundStyle(GymColor.dim) }
          }.font(GymType.body(17)).frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("set.saved")
      }
      if let start = session.restStarted { RestCounter(started: start).padding(.vertical, 12) }
      if exercise?.timed != true {
        HStack {
          Text(store.t("Next weight")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
          Spacer()
          weightButton(compact: true)
        }
      }
    } else {
      Text(store.t("Set") + " \(session.sets.filter { $0.exercise.id == exercise?.id && $0.completed }.count + 1)")
        .font(GymType.body(15)).foregroundStyle(GymColor.dim)
      if exercise?.timed != true { weightButton(compact: false).padding(.vertical, 20) }
      if let exercise, let previous = store.lastSet(for: exercise) {
        HStack {
          Text(store.t("Last time")).foregroundStyle(GymColor.dim)
          Spacer()
          Text(setValue(previous, store: store))
        }.font(GymType.body(17)).frame(minHeight: 44)
      }
    }
    if store.deletedSet != nil {
      Button(store.t("Undo")) { store.undoDelete() }.frame(minHeight: 44).accessibilityIdentifier("set.undo")
    }
  }
  private var weightText: String {
    session.weightKG == 0 ? store.t("Bodyweight") : formatNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit)) + " " + weightLabel
  }
  private func weightButton(compact: Bool) -> some View {
    Button { weightEditor = true } label: {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        if session.weightIsSet == false {
          Text(store.t("Choose weight")).font(GymType.title(compact ? 20 : 30))
        } else if session.weightKG == 0 {
          Text(store.t("Bodyweight")).font(GymType.title(compact ? 20 : 30))
        } else {
          Text(formatNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit)))
            .font(GymType.title(compact ? 24 : 56)).monospacedDigit()
          Text(weightLabel).font(GymType.body(compact ? 15 : 17)).foregroundStyle(GymColor.dim)
        }
      }.padding(.horizontal, compact ? 12 : 22).padding(.vertical, 10)
        .frame(maxWidth: compact ? nil : .infinity, minHeight: 52)
    }.buttonStyle(.bordered).buttonBorderShape(.capsule).tint(GymColor.ink)
      .accessibilityLabel(session.weightIsSet == false ? store.t("Choose weight") : store.t("Edit weight") + ", " + weightText)
      .accessibilityIdentifier("set.weight")
  }
  private func resolveSwitch(saving: Bool) {
    guard let next = pendingExercise else { return }
    dismissKeyboard()
    store.switchExercise(to: next, savingCurrent: saving, reps: Int(reps) ?? 0, minutes: actualMinutes)
    pendingExercise = nil; minutes = ""
  }
  private func loadReps() { reps = session.draftRepsText ?? String(session.draftReps ?? 10) }
  private func finishSet() {
    dismissKeyboard()
    if session.stage == .log { store.logSet(reps: Int(reps) ?? 0, minutes: actualMinutes) }
    else { store.finishSet(reps: Int(reps) ?? 0, minutes: actualMinutes) }
    OnboardingFeedback.shared.play(profile: store.profile, completion: true)
  }
}
struct ExercisePickerContent: View {
  @EnvironmentObject private var store: GymStore
  @State private var search = ""
  @State private var custom = false
  let onChoose: (Exercise) -> Void
  private var recent: [Exercise] {
    var seen = Set<String>()
    let current = Set((store.session?.exercises ?? []).map(\.id))
    return Array(store.data.history.sorted { $0.started > $1.started }.flatMap(\.sets).map(\.exercise)
      .filter { !current.contains($0.id) && seen.insert($0.id).inserted }.prefix(5))
  }
  private var catalog: [Exercise] {
    let grouped = Set(recent.map(\.id) + (store.session?.exercises ?? []).map(\.id))
    return store.allExercises.filter {
      search.isEmpty ? !grouped.contains($0.id) : store.t($0.name).localizedCaseInsensitiveContains(search)
    }
  }
  var body: some View {
    List {
      if search.isEmpty {
        if let current = store.session?.exercises, !current.isEmpty {
          Section(store.t("This workout")) { ForEach(current) { exerciseRow($0) } }
        }
        if !recent.isEmpty { Section(store.t("Recent")) { ForEach(recent) { exerciseRow($0) } } }
      }
      Section(search.isEmpty ? store.t("Exercises") : "") { ForEach(catalog) { exerciseRow($0) } }
      if !search.isEmpty && catalog.isEmpty { Text(store.t("No matches")).foregroundStyle(GymColor.dim) }
      Button(search.isEmpty ? store.t("New exercise") : store.t("Create") + " ‘" + search + "’") { custom = true }
        .accessibilityIdentifier("exercise.custom")
    }.gymPage().searchable(text: $search, prompt: store.t("Search exercises")).gymSearchNavigation()
      .navigationDestination(isPresented: $custom) {
        CustomExerciseView(embedded: true, initialName: search) { onChoose($0) }
      }
  }
  private func exerciseRow(_ exercise: Exercise) -> some View {
    Button { dismissKeyboard(); onChoose(exercise) } label: {
      HStack {
        Text(store.t(exercise.name)).foregroundStyle(GymColor.ink); Spacer()
        if store.session?.selected?.id == exercise.id {
          Image(systemName: "checkmark").foregroundStyle(GymColor.red).accessibilityHidden(true)
        }
      }.frame(minHeight: 44)
    }.accessibilityIdentifier("exercise." + exercise.id)
  }
}
struct WeightEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let weightKG: Double
  let onSave: (Double, String) -> Void
  @State private var text = ""
  @State private var typing = false
  @FocusState private var focused: Bool
  private var value: Double? { parseNumber(text) }
  private var valid: Bool { value.map { $0.isFinite && (0...500).contains($0) } ?? false }
  private var values: [Double] {
    Array(Set((0...1000).map { Double($0) / 2 } + (valid ? [value!] : []))).sorted()
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          if typing {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              TextField("0", text: $text).font(GymType.title(48)).monospacedDigit()
                .keyboardType(.decimalPad).multilineTextAlignment(.center).focused($focused)
                .modifier(SelectNumberOnFocus()).accessibilityLabel(store.t("Weight"))
                .accessibilityIdentifier("set.weight.manual")
              Text(store.profile.unit).font(GymType.body(17)).foregroundStyle(GymColor.dim)
            }.padding(.vertical, 24)
          } else {
            Picker(store.t("Weight"), selection: Binding(get: { value ?? 0 }, set: { text = inputNumber($0) })) {
              ForEach(values, id: \.self) { v in
                Text(v == 0 ? store.t("Bodyweight") : formatNumber(v) + " " + store.profile.unit).tag(v)
              }
            }.pickerStyle(.wheel).frame(height: 216).accessibilityIdentifier("set.weight.wheel")
          }
          Button(store.t(typing ? "Use picker" : "Type weight")) {
            if typing && !valid { text = "0" }
            typing.toggle(); focused = typing
          }.font(GymType.body(15)).frame(minHeight: 44).accessibilityIdentifier("weight.mode")
          if !valid { Text(store.t("Use a weight from 0 to 500.")).font(GymType.body(15)).foregroundStyle(GymColor.red) }
        }.padding(24)
      }.gymPage().navigationTitle(store.t("Weight")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) {
              guard let value, valid else { return }
              // Preserve the original stored load if no actual edit took place.
              let original = inputNumber(GymStore.displayedWeight(weightKG, unit: store.profile.unit))
              let saved = text == original ? GymStore.displayedWeight(weightKG, unit: store.profile.unit) : value
              onSave(saved, store.profile.unit); dismiss()
            }.disabled(!valid).accessibilityIdentifier("set.weight.picker.done")
          }
        }.onAppear { text = inputNumber(GymStore.displayedWeight(weightKG, unit: store.profile.unit)) }
    }.presentationDetents([.medium, .large])
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
      VStack {
        if store.session?.stage == .active || store.session?.stage == .log {
          Button(store.t("Cancel set")) { store.cancelSet(); dismiss() }
            .frame(minHeight: 44).accessibilityIdentifier("set.cancel")
          if store.session?.selected?.timed != true {
            Button(store.t("Record attempt")) { store.recordAttempt(); dismiss() }
              .frame(minHeight: 44).accessibilityIdentifier("set.attempt")
          }
        }
        if let session = store.session { WorkoutDetailView(sessionID: session.id, embedded: true) }
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
struct SummaryView: View {
  @EnvironmentObject private var store: GymStore
  var session: Session
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text(store.t("Workout saved")).font(GymType.title(32)).accessibilityIdentifier("summary.title")
          Text("\(max(1, Int(session.duration / 60))) " + store.t("min")).font(GymType.title(28)).monospacedDigit()
          Text(setCount(session.completedSets.count, store: store) + " · \(session.totalReps) " + store.t("reps"))
            .font(GymType.body(17)).foregroundStyle(GymColor.dim)
          if !session.repSets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text(store.t("Weight moved")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
              Text(formatNumber(GymStore.displayedWeight(session.volumeKG, unit: store.profile.unit)) + " " + store.profile.unit)
                .font(GymType.title(24)).accessibilityIdentifier("summary.volume")
            }
          }
          NavigationLink(store.t("View workout")) { WorkoutDetailView(sessionID: session.id) }.frame(minHeight: 44)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).padding(.top, 32)
      }.gymPage().navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
          GymButton(title: store.t("Done"), id: "summary.done") { store.summary = nil }
            .padding(.horizontal, 24).padding(.vertical, 16)
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
