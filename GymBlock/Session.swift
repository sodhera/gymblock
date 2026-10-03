import SwiftUI

struct SessionView: View {
  @EnvironmentObject private var store: GymStore
  @State private var exercisePicker = false
  @State private var weightEditor = false
  @State private var switching = false
  @State private var pendingExercise: Exercise?
  @State private var records = false
  @State private var ending = false
  @State private var editing: LoggedSet?
  @State private var reps = "10"
  @State private var minutes = ""
  @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 72
  private var session: Session { store.session ?? Session() }
  private var exercise: Exercise? { session.selected }
  private var active: Bool { session.stage == .active || session.stage == .log }
  private var selecting: Bool { session.stage == .exercise || session.stage == .workout }
  private var actualMinutes: Double {
    if let entered = parseNumber(minutes) { return entered }
    return max(0, Date().timeIntervalSince(session.setStarted ?? Date()) / 60)
  }
  private var valid: Bool {
    exercise?.timed == true
      ? actualMinutes.isFinite && actualMinutes > 0
      : Int(reps).map { (1...999).contains($0) } ?? false
  }
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        HStack {
          Text(store.t((store.profile.focusEnabled ?? true) ? "Focus demo" : "Focus off")).font(
            GymType.body(12)
          ).foregroundStyle(GymColor.dim).accessibilityIdentifier("session.blocking")
          Spacer()
        }.padding(.horizontal, 24).padding(.top, 8)
        if selecting {
          ExercisePickerContent { store.chooseExercise($0) }
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              Button {
                exercisePicker = true
              } label: {
                HStack(alignment: .firstTextBaseline) {
                  Text(store.t(exercise?.name ?? "Exercise")).font(GymType.hero(32))
                    .multilineTextAlignment(.leading)
                  Image(systemName: "chevron.down").font(GymType.body(12))
                }.foregroundStyle(GymColor.ink).frame(
                  maxWidth: .infinity, minHeight: 44, alignment: .leading)
              }.accessibilityIdentifier("set.exercise")
              VStack(alignment: .leading, spacing: 24) {
                if active { activeContent } else { readyContent }
              }.frame(maxWidth: .infinity, alignment: .leading).padding(24).gymCard()
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(
              .top, 28
            ).padding(.bottom, 24)
          }.scrollDismissesKeyboard(.interactively)
          VStack(spacing: 8) {
            if active {
              GymButton(
                title: store.t(exercise?.timed == true ? "Finish activity" : "Finish set"),
                enabled: valid, id: "set.stop"
              ) { finishSet() }
            } else {
              GymButton(
                title: store.t(
                  session.stage == .rest
                    ? "Start next set" : exercise?.timed == true ? "Start activity" : "Start set"),
                enabled: exercise?.timed == true
                  || (session.weightIsSet != false
                    && GymStore.displayedWeight(session.weightKG, unit: store.profile.unit) <= 500),
                id: "set.start"
              ) {
                minutes = ""
                store.updateDraft(minutes: 0)
                store.startSet(
                  weight: GymStore.displayedWeight(session.weightKG, unit: store.profile.unit),
                  unit: store.profile.unit)
              }
            }
            Button(store.t("Change exercise")) { exercisePicker = true }
              .font(GymType.label(16)).frame(minHeight: 44).accessibilityIdentifier("set.change")
          }
          .padding(.horizontal, 24).padding(.bottom, 12)
        }
      }
      .gymPage().navigationTitle(store.t(session.name)).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            if active {
              Button(store.t("Cancel set")) { store.cancelSet() }.accessibilityIdentifier(
                "set.cancel")
              if exercise?.timed != true {
                Button(store.t("Record unsuccessful attempt")) { store.recordAttempt() }
                  .accessibilityIdentifier("set.attempt")
              }
            }
            Button(store.t("Sets")) { records = true }.accessibilityIdentifier("session.sets")
            Button(store.t("End workout")) { if active { ending = true } else { store.finish() } }
              .accessibilityIdentifier("session.finish")
          } label: {
            Image(systemName: "ellipsis")
          }.accessibilityLabel(store.t("Workout options")).accessibilityIdentifier(
            "session.options")
        }
      }
      .confirmationDialog(store.t("End workout?"), isPresented: $ending, titleVisibility: .visible)
      {
        Button(store.t("Save set and end")) {
          if valid {
            finishSet()
            store.finish()
          }
        }.disabled(!valid).accessibilityIdentifier("session.saveEnd")
        Button(store.t("Discard current set and end"), role: .destructive) {
          store.cancelSet()
          store.finish()
        }.accessibilityIdentifier("session.discardEnd")
        Button(store.t("Keep training")) {}
      }
      .sheet(
        isPresented: $exercisePicker,
        onDismiss: {
          if pendingExercise != nil { switching = true }
        }
      ) {
        NavigationStack {
          ExercisePickerContent {
            if $0.id != exercise?.id {
              if active { pendingExercise = $0 } else { store.chooseExercise($0) }
            }
            exercisePicker = false
          }.gymPage().navigationTitle(store.t("Exercises")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button(store.t("Done")) { exercisePicker = false }
              }
            }
        }
      }
      .sheet(isPresented: $weightEditor) {
        WeightEditor(weightKG: session.weightKG) { value, unit in
          store.updateProfile { $0.unit = unit }
          store.updateWeight(value, unit: unit)
        }
      }
      .confirmationDialog(
        store.t("Switch exercise?"), isPresented: $switching, titleVisibility: .visible
      ) {
        Button(store.t("Save set and switch")) { resolveSwitch(saving: true) }
          .disabled(!valid).accessibilityIdentifier("switch.save")
        Button(store.t("Discard current set and switch"), role: .destructive) {
          resolveSwitch(saving: false)
        }
        .accessibilityIdentifier("switch.discard")
        Button(store.t("Keep training")) { pendingExercise = nil }
          .accessibilityIdentifier("switch.cancel")
      } message: {
        Text(store.t("Completed sets stay saved. Choose what to do with this unfinished set."))
      }
      .onChange(of: switching) { _, presented in if !presented { pendingExercise = nil } }
      .sheet(isPresented: $records) { SessionRecordsView() }
      .sheet(item: $editing) { SetEditor(set: $0, sessionID: session.id) }
      .onAppear { loadReps() }
      .onChange(of: session.selected?.id) { _, _ in
        loadReps()
        minutes = ""
      }
      .onChange(of: reps) { _, value in store.updateRepText(value)
      }
      .onChange(of: minutes) { _, value in
        if let value = parseNumber(value) { store.updateDraft(minutes: value) }
      }
    }
  }
  @ViewBuilder private var activeContent: some View {
    if exercise?.timed != true {
      Text(
        session.weightKG == 0
          ? store.t("Bodyweight")
          : formatNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit)) + " "
            + store.profile.unit
      ).font(GymType.body(17)).foregroundStyle(GymColor.dim)
    }
    if exercise?.timed == true {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        Text(
          clockString(
            max(0, Int(context.date.timeIntervalSince(session.setStarted ?? context.date))))
        ).font(GymType.number(numberSize)).monospacedDigit().lineLimit(1)
          .minimumScaleFactor(0.5).frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier("set.elapsed")
      }
      TextField(store.t("Minutes completed (optional correction)"), text: $minutes).keyboardType(
        .decimalPad
      ).textFieldStyle(.roundedBorder).accessibilityIdentifier("set.minutes").modifier(
        SelectNumberOnFocus())
    } else {
      VStack(alignment: .leading, spacing: 12) {
        Text(store.t("Reps completed")).font(GymType.label(15)).foregroundStyle(GymColor.dim)
        HStack {
          Button {
            reps = String(max(1, (Int(reps) ?? 1) - 1))
          } label: {
            Image(systemName: "minus").frame(width: 44, height: 44).background(
              GymColor.red.opacity(0.08), in: Circle())
          }.accessibilityLabel(store.t("Decrease reps")).accessibilityIdentifier("set.reps.minus")
          TextField("—", text: $reps).font(GymType.number(numberSize))
            .monospacedDigit().keyboardType(.numberPad).multilineTextAlignment(.center)
            .accessibilityLabel(store.t("Reps completed")).accessibilityIdentifier("set.reps")
            .modifier(SelectNumberOnFocus())
          Button {
            reps = String(min(999, (Int(reps) ?? 0) + 1))
          } label: {
            Image(systemName: "plus").frame(width: 44, height: 44).background(
              GymColor.red.opacity(0.08), in: Circle())
          }.accessibilityLabel(store.t("Increase reps")).accessibilityIdentifier("set.reps.plus")
        }
      }
    }
    if !valid {
      Text(
        store.t(
          exercise?.timed == true
            ? "Enter completed minutes above zero."
            : "Enter completed reps, or record an attempt from Workout options.")
      ).font(GymType.body(13)).foregroundStyle(GymColor.red)
    }
  }
  @ViewBuilder private var readyContent: some View {
    if session.stage == .rest {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        VStack(alignment: .leading, spacing: 8) {
          Text(store.t("Rest elapsed")).font(GymType.label(15)).foregroundStyle(GymColor.dim)
          Text(clockString(store.restElapsed(at: context.date))).font(GymType.number(numberSize))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(GymColor.ink)
            .accessibilityIdentifier("rest.elapsed")
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      if let last = session.sets.last {
        Button {
          editing = last
        } label: {
          HStack {
            Text(
              (last.exercise.id == exercise?.id
                ? store.t("Saved:") : store.t(last.exercise.name) + " ·")
                + " " + setValue(last, store: store)
            ).foregroundStyle(
              GymColor.dim
            )
            .font(GymType.body(15))
            Image(systemName: "pencil").font(GymType.body(12))
          }.frame(minHeight: 44)
        }.accessibilityIdentifier("set.saved")
      }
    } else {
      Text(
        store.t("Set")
          + " \(session.sets.filter { $0.exercise.id == exercise?.id && $0.completed }.count + 1)"
      ).font(GymType.body(15)).foregroundStyle(GymColor.dim)
    }
    if exercise?.timed != true {
      VStack(alignment: .leading, spacing: 8) {
        if session.stage == .rest {
          Text(store.t("Next set")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
        }
        Button {
          weightEditor = true
        } label: {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            if session.weightIsSet == false || session.weightKG == 0 {
              Text(store.t(session.weightIsSet == false ? "Choose weight" : "Bodyweight"))
                .font(GymType.title(28)).foregroundStyle(GymColor.ink)
            } else {
              Text(
                formatNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit))
              )
              .font(GymType.number(session.stage == .rest ? 32 : numberSize)).monospacedDigit()
              .foregroundStyle(GymColor.ink)
              Text(store.profile.unit).font(GymType.title(22)).foregroundStyle(GymColor.dim)
            }
            Spacer(minLength: 0)
            Image(systemName: "pencil").font(.system(size: 15)).foregroundStyle(GymColor.red)
          }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        }.accessibilityLabel(store.t("Edit weight")).accessibilityIdentifier("set.weight")
        if GymStore.displayedWeight(session.weightKG, unit: store.profile.unit) > 500 {
          Text(store.t("Enter a weight from 0 to 500.")).font(GymType.body(13)).foregroundStyle(
            GymColor.red)
        }
        if exercise?.name.localizedCaseInsensitiveContains("dumbbell") == true
          || exercise?.id == "curl"
        {
          Text(store.t("Per dumbbell · reps per side")).font(GymType.body(13)).foregroundStyle(
            GymColor.dim)
        }
      }
    }
    if session.stage != .rest, let exercise, let previous = store.lastSet(for: exercise) {
      Text(store.t("Last time:") + " " + setValue(previous, store: store)).font(GymType.body(15))
        .foregroundStyle(GymColor.dim)
    }
    if store.deletedSet != nil {
      Button(store.t("Undo delete")) { store.undoDelete() }.frame(minHeight: 44)
        .accessibilityIdentifier("set.undo")
    }
  }
  private func resolveSwitch(saving: Bool) {
    guard let next = pendingExercise else { return }
    dismissKeyboard()
    store.switchExercise(
      to: next, savingCurrent: saving, reps: Int(reps) ?? 0, minutes: actualMinutes)
    pendingExercise = nil
    minutes = ""
  }
  private func loadReps() {
    reps = session.draftRepsText ?? String(session.draftReps ?? 10)
    if active && exercise?.timed == true, let value = session.draftMinutes, value > 0 {
      minutes = inputNumber(value)
    }
  }
  private func finishSet() {
    dismissKeyboard()
    if session.stage == .log {
      store.logSet(reps: Int(reps) ?? 0, minutes: actualMinutes)
    } else {
      store.finishSet(reps: Int(reps) ?? 0, minutes: actualMinutes)
    }
  }
}
struct ExercisePickerContent: View {
  @EnvironmentObject private var store: GymStore
  @State private var search = ""
  @State private var custom = false
  let onChoose: (Exercise) -> Void
  private var matches: [Exercise] {
    if !search.isEmpty {
      return store.allExercises.filter { store.t($0.name).localizedCaseInsensitiveContains(search) }
    }
    let recent = store.data.history.flatMap(\.sets).map(\.exercise)
    var seen = Set<String>()
    let inWorkout = Set((store.session?.exercises ?? []).map(\.id))
    return Array(
      (recent + store.allExercises).filter {
        !inWorkout.contains($0.id) && seen.insert($0.id).inserted
      }.prefix(8))
  }
  var body: some View {
    List {
      if search.isEmpty, let exercises = store.session?.exercises, !exercises.isEmpty {
        Section(store.t("This workout")) {
          ForEach(exercises) { exercise in exerciseRow(exercise) }
        }
      }
      Section(store.t(search.isEmpty ? "Recent exercises" : "Results")) {
        ForEach(matches) { exercise in exerciseRow(exercise) }
      }
      if matches.isEmpty || !search.isEmpty {
        Button(store.t("Add custom exercise")) { custom = true }.accessibilityIdentifier(
          "exercise.custom")
      }
    }.searchable(text: $search, prompt: store.t("Search exercises"))
      .sheet(isPresented: $custom) { CustomExerciseView { onChoose($0) } }
  }
  private func exerciseRow(_ exercise: Exercise) -> some View {
    Button {
      dismissKeyboard()
      onChoose(exercise)
    } label: {
      HStack {
        Text(store.t(exercise.name)).foregroundStyle(GymColor.ink)
        Spacer()
        let count =
          store.session?.sets.filter { $0.exercise.id == exercise.id && $0.completed }.count ?? 0
        if count > 0 { Text("\(count)").font(GymType.body(12)).foregroundStyle(GymColor.dim) }
        Image(
          systemName: store.session?.selected?.id == exercise.id
            ? "checkmark.circle.fill" : "chevron.right"
        )
        .font(.system(size: 13)).foregroundStyle(
          store.session?.selected?.id == exercise.id ? GymColor.red : GymColor.dim)
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
  @State private var unit = ""
  @State private var converted: (text: String, kilograms: Double)?
  private var value: Double? { parseNumber(text) }
  private var preservedKG: Double? {
    guard let converted, converted.text == text else { return nil }
    return converted.kilograms
  }
  private var valid: Bool { value.map { $0.isFinite && (0...500).contains($0) } ?? false }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          HStack {
            Button {
              text = inputNumber(max(0, (value ?? 0) - 0.5))
            } label: {
              Image(systemName: "minus").frame(width: 44, height: 44)
            }.accessibilityLabel(store.t("Decrease weight"))
            TextField("0", text: $text).font(GymType.hero(48).monospacedDigit())
              .multilineTextAlignment(
                .center
              ).keyboardType(.decimalPad).accessibilityLabel(store.t("Weight"))
              .accessibilityIdentifier(
                "set.weight.manual"
              ).modifier(SelectNumberOnFocus())
            Button {
              text = inputNumber(min(500, (value ?? 0) + 0.5))
            } label: {
              Image(systemName: "plus").frame(width: 44, height: 44)
            }.accessibilityLabel(store.t("Increase weight"))
          }
          Picker(store.t("Weight unit"), selection: $unit) {
            Text("kg").tag("kg")
            Text("lb").tag("lb")
          }.pickerStyle(.segmented).frame(maxWidth: 160).accessibilityIdentifier("weight.unit")
            .onChange(of: unit) { old, new in
              if !old.isEmpty, let value {
                let kilograms = preservedKG ?? GymStore.kilograms(value, unit: old)
                let displayed = inputNumber(GymStore.displayedWeight(kilograms, unit: new))
                converted = (displayed, kilograms)
                text = displayed
              }
            }
          Picker(
            store.t("Weight"),
            selection: Binding(
              get: { min(500, max(0, ((value ?? 0) * 2).rounded() / 2)) },
              set: { text = inputNumber($0) })
          ) {
            ForEach(0...1000, id: \.self) { i in
              Text(i == 0 ? store.t("Bodyweight") : formatNumber(Double(i) / 2)).tag(Double(i) / 2)
            }
          }.pickerStyle(.wheel).accessibilityIdentifier("set.weight.wheel")
          if !valid {
            Text(store.t("Enter a weight from 0 to 500.")).font(GymType.body(13)).foregroundStyle(
              GymColor.red)
          }
        }
      }.scrollDismissesKeyboard(.interactively).padding(.horizontal, 24).gymPage().navigationTitle(
        store.t("Weight")
      ).navigationBarTitleDisplayMode(
        .inline
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(store.t("Done")) {
            if let value, valid {
              let exact = preservedKG.map { GymStore.displayedWeight($0, unit: unit) }
              let saved = exact.flatMap { (0...500).contains($0) ? $0 : nil } ?? value
              onSave(saved, unit)
              dismiss()
            }
          }.disabled(!valid).accessibilityIdentifier("set.weight.picker.done")
        }
      }
      .onAppear {
        unit = store.profile.unit
        text = inputNumber(GymStore.displayedWeight(weightKG, unit: unit))
        converted = (text, weightKG)
      }
    }.presentationDetents([.medium, .large])
  }
}
struct SelectNumberOnFocus: ViewModifier {
  func body(content: Content) -> some View {
    content.onReceive(
      NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)
    ) { notification in
      guard let field = notification.object as? UITextField, field.isFirstResponder else { return }
      DispatchQueue.main.async { field.selectAll(nil) }
    }
  }
}
struct SessionRecordsView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var adding = false
  var body: some View {
    NavigationStack {
      VStack { if let session = store.session { WorkoutDetailView(sessionID: session.id) } }
        .gymPage().navigationTitle(store.t("Sets")).navigationBarTitleDisplayMode(.inline).toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("records.done")
          }
          ToolbarItem(placement: .topBarLeading) {
            Button {
              adding = true
            } label: {
              Image(systemName: "plus")
            }.accessibilityLabel(store.t("Add completed set")).accessibilityIdentifier(
              "records.add")
          }
        }.sheet(isPresented: $adding) {
          SetEditor(set: nil, sessionID: store.session?.id ?? UUID())
        }
    }
  }
}
struct SetEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let set: LoggedSet?
  let sessionID: UUID
  @State private var weight = ""
  @State private var reps = ""
  @State private var minutes = ""
  @State private var warmup = false
  @State private var date = Date()
  @State private var error = false
  private var exercise: Exercise? { self.set?.exercise ?? store.session?.selected }
  var body: some View {
    NavigationStack {
      Form {
        if let exercise {
          Text(store.t(exercise.name))
          if !exercise.timed {
            TextField(store.profile.unit, text: $weight).keyboardType(.decimalPad)
              .accessibilityIdentifier("edit.weight").modifier(SelectNumberOnFocus())
          }
          if set?.unsuccessful == true {
            Text(store.t("Unsuccessful attempt · 0 completed reps")).foregroundStyle(
              GymColor.dim)
          } else if exercise.timed {
            TextField(store.t("Minutes completed"), text: $minutes).keyboardType(.decimalPad)
              .accessibilityIdentifier("edit.minutes").modifier(SelectNumberOnFocus())
          } else {
            TextField(store.t("Reps completed"), text: $reps).keyboardType(.numberPad)
              .accessibilityIdentifier("edit.reps").modifier(SelectNumberOnFocus())
            Toggle(store.t("Warm-up"), isOn: $warmup)
          }
          if set != nil { DatePicker(store.t("Completed at"), selection: $date, in: ...Date()) }
        }
        if error { Text(store.t("Check the entered values.")).foregroundStyle(GymColor.red) }
        if let set {
          Button(store.t("Delete set"), role: .destructive) {
            store.deleteSet(set, sessionID: sessionID)
            dismiss()
          }.accessibilityIdentifier("edit.delete")
        }
      }.gymPage().navigationTitle(store.t(set == nil ? "Add completed set" : "Edit set"))
        .navigationBarTitleDisplayMode(.inline)
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
        }
    }.presentationDetents([.medium, .large])
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
  @State private var name = ""
  @State private var timed = false
  let onAdd: (Exercise) -> Void
  var body: some View {
    NavigationStack {
      Form {
        TextField(store.t("Exercise name"), text: $name).accessibilityIdentifier("custom.name")
        Toggle(store.t("Duration-based"), isOn: $timed)
      }.gymPage().navigationTitle(store.t("Add custom exercise")).navigationBarTitleDisplayMode(
        .inline
      )
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(store.t("Add exercise")) {
            onAdd(
              Exercise(
                id: UUID().uuidString,
                name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)),
                area: "Your training", timed: timed))
            dismiss()
          }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("custom.add")
        }
      }
    }
  }
}
struct SummaryView: View {
  @EnvironmentObject private var store: GymStore
  var session: Session
  @State private var saving = false
  @State private var name = ""
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Spacer()
        Image(systemName: session.completedSets.isEmpty ? "checkmark" : "checkmark.seal.fill")
          .font(.system(size: 48, weight: .light)).foregroundStyle(GymColor.red)
          .padding(.bottom, 12).accessibilityHidden(true)
        Text(
          store.t(
            session.sets.isEmpty
              ? "Session ended."
              : session.completedSets.isEmpty ? "Attempt recorded" : "Workout saved")
        ).font(GymType.hero(32)).accessibilityIdentifier("summary.title")
        Text(
          "\(session.completedSets.count) " + store.t("sets")
            + " · \(max(1, Int(session.duration / 60))) " + store.t("min")
        ).foregroundStyle(GymColor.dim)
        Text(store.t("Focus demo ended")).font(GymType.body(13)).foregroundStyle(GymColor.dim)
          .accessibilityIdentifier("summary.unblocked")
        Spacer()
        GymButton(title: store.t("Done"), id: "summary.done") { store.summary = nil }
      }.padding(24).gymPage().navigationBarTitleDisplayMode(.inline)
        .toolbar {
          if !session.sets.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
              Menu {
                if session.splitID == nil { Button(store.t("Save as split")) { saving = true } }
                NavigationLink(store.t("View workout")) { WorkoutDetailView(sessionID: session.id) }
              } label: {
                Image(systemName: "ellipsis")
              }.accessibilityLabel(store.t("Workout options"))
            }
          }
        }
        .alert(store.t("Save as split"), isPresented: $saving) {
          TextField(store.t("Split name"), text: $name)
          Button(store.t("Save")) { store.saveWorkout(from: session, name: name) }
          Button(store.t("Cancel"), role: .cancel) {}
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
