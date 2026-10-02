import SwiftUI

struct SessionView: View {
    @EnvironmentObject private var store: GymStore
    @State private var weight = "10"
    @State private var reps = "10"
    @State private var minutes = "5"
    @State private var search = ""
    @State private var showCustom = false
    @State private var confirmFinish = false
    @FocusState private var searchFocused: Bool
    private var session: Session { store.session ?? Session() }
    private var exercise: Exercise? { session.selected }
    private var timed: Bool { exercise?.timed == true }
    private var weightValue: Double? { Double(weight.replacingOccurrences(of: ",", with: ".")) }
    private var minuteValue: Double? { Double(minutes.replacingOccurrences(of: ",", with: ".")) }
    private var validWeight: Bool { weightValue.map { $0.isFinite && (0...500).contains($0) } ?? false }
    private var validLog: Bool { timed ? (minuteValue.map { $0.isFinite && $0 > 0 } ?? false) : (Int(reps).map { (1...100).contains($0) } ?? false) }
    private var selecting: Bool { session.stage == .exercise || session.stage == .workout }
    private var active: Bool { session.stage == .active || session.stage == .log }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if selecting { exerciseSelection }
                        else { setContent }
                    }.padding(24)
                }.scrollDismissesKeyboard(.interactively)
                if !selecting { footer.padding(.horizontal, 24).padding(.vertical, 12) }
            }.background(GymColor.ground).toolbar(.hidden, for: .navigationBar)
                .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(store.t("Done")) { dismissKeyboard() }.accessibilityIdentifier("keyboard.done") } }
        }
        .onAppear { loadValues(); if selecting && session.exercises.isEmpty { searchFocused = true } }
        .onChange(of: session.selected?.id) { _, _ in loadValues(); dismissKeyboard() }
        .onChange(of: session.stage) { _, stage in if stage == .exercise { search = ""; searchFocused = session.exercises.isEmpty }; if stage == .setup { loadValues() } }
        .onChange(of: reps) { _, value in if let value = Int(value) { store.updateDraft(reps: value) } }
        .onChange(of: minutes) { _, value in if let value = Double(value.replacingOccurrences(of: ",", with: ".")) { store.updateDraft(minutes: value) } }
        .confirmationDialog(store.t("Finish this session?"), isPresented: $confirmFinish, titleVisibility: .visible) {
            Button(store.t("Finish")) { dismissKeyboard(); store.finish() }.accessibilityIdentifier("session.finish.confirm")
            Button(store.t("Keep training"), role: .cancel) {}
        } message: { Text(store.t("Only logged sets will be saved. The focus preview will end.")) }
        .sheet(isPresented: $showCustom) { CustomExerciseView { store.chooseExercise($0) } }
    }
    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Label(store.t("Focus preview on"), systemImage: "lock.fill").font(.caption.weight(.semibold)).foregroundStyle(GymColor.blue).accessibilityIdentifier("session.blocking")
                Text(session.name).font(.caption).foregroundStyle(GymColor.dim)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in Text(elapsed(session.started, context.date)).font(.caption.monospacedDigit()).foregroundStyle(GymColor.dim) }
            Button(store.t("Finish")) { if active || session.sets.isEmpty { confirmFinish = true } else { store.finish() } }
                .font(.subheadline.weight(.semibold)).frame(minWidth: 50, minHeight: 44).accessibilityIdentifier("session.finish")
        }.padding(.horizontal, 24).padding(.vertical, 8).background(GymColor.surface)
    }
    private var matches: [Exercise] {
        if !search.isEmpty { return store.allExercises.filter { store.t($0.name).localizedCaseInsensitiveContains(search) } }
        if !session.exercises.isEmpty { return session.exercises }
        let recent = store.data.history.flatMap(\.sets).map(\.exercise)
        let favorites = store.allExercises.filter { store.profile.favorites.contains($0.id) }
        var seen = Set<String>()
        return Array((recent + favorites + store.allExercises).filter { seen.insert($0.id).inserted }.prefix(6))
    }
    private var exerciseSelection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(store.t("Choose an exercise")).font(.largeTitle.weight(.bold))
            TextField(store.t("Search exercises"), text: $search).focused($searchFocused)
                .submitLabel(.search).padding(16).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("exercise.search")
            if search.isEmpty { Text(store.t(session.exercises.isEmpty ? "Recent & favorites" : "This split")).font(.subheadline).foregroundStyle(GymColor.dim) }
            ForEach(matches) { exercise in
                Button { dismissKeyboard(); store.chooseExercise(exercise) } label: {
                    HStack { Text(store.t(exercise.name)).font(.body.weight(.medium)); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(GymColor.blue) }
                        .padding(18).frame(minHeight: 56).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain).accessibilityIdentifier("exercise.\(exercise.id)")
            }
            if matches.isEmpty { Text(store.t("No matches. Add your own exercise below.")).foregroundStyle(GymColor.dim) }
            Button { dismissKeyboard(); showCustom = true } label: { Label(store.t("Add custom exercise"), systemImage: "plus") }
                .frame(minHeight: 44).accessibilityIdentifier("exercise.custom")
            if !session.exercises.isEmpty && search.isEmpty { Text(store.t("Search to add an exercise outside this split.")).font(.caption).foregroundStyle(GymColor.dim) }
        }
    }
    private var setContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(store.t(exercise?.name ?? "")).font(.largeTitle.weight(.bold))
            if active {
                HStack {
                    Text(store.t(timed ? "Activity in progress" : "Set in progress")).font(.subheadline).foregroundStyle(GymColor.red)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in Text(elapsed(session.setStarted ?? .now, context.date)).font(.subheadline.monospacedDigit()).foregroundStyle(GymColor.dim) }
                }
                if !timed { Text("\(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit).formatted(.number.precision(.fractionLength(0...2)))) \(store.profile.unit)").font(.title2.weight(.semibold)).foregroundStyle(GymColor.blue) }
                NumericEntry(label: store.t(timed ? "Minutes completed" : "Reps"), text: timed ? $minutes : $reps, id: timed ? "set.minutes" : "set.reps", maxValue: timed ? 500 : 100, step: timed ? 0.5 : 1, minimum: 1)
                if !validLog { Text(store.t("Enter a positive number to continue.")).font(.caption).foregroundStyle(GymColor.red) }
            } else {
                if session.stage == .rest {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(ceil((session.restEnds ?? context.date).timeIntervalSince(context.date))))
                        HStack {
                            Text(store.t(remaining > 0 ? "Rest" : "Rest complete")).font(.headline)
                            Spacer()
                            Text(String(format: "%d:%02d", remaining / 60, remaining % 60)).font(.title.monospacedDigit().weight(.bold)).foregroundStyle(GymColor.red).accessibilityIdentifier("rest.countdown")
                        }
                    }
                    HStack {
                        ForEach([30, 60, 90], id: \.self) { seconds in Button("\(seconds)s") { store.setRest(seconds: seconds) }.frame(maxWidth: .infinity, minHeight: 44).background(GymColor.surface, in: Capsule()).accessibilityIdentifier("rest.\(seconds)") }
                    }
                }
                if !timed {
                    HStack {
                        Text(store.t("Weight")).font(.headline)
                        Spacer()
                        Picker(store.t("Weight unit"), selection: Binding(get: { store.profile.unit }, set: { unit in
                            if let value = weightValue, validWeight { weight = inputString(GymStore.displayedWeight(GymStore.kilograms(value, unit: store.profile.unit), unit: unit)) }
                            store.updateProfile { $0.unit = unit }
                        })) { Text("kg").tag("kg"); Text("lb").tag("lb") }.pickerStyle(.segmented).frame(width: 130).accessibilityIdentifier("weight.unit")
                    }
                    NumericEntry(label: store.profile.unit, text: $weight, id: "set.weight", maxValue: 500, step: 0.5, minimum: 0)
                    Text(store.t("Tap the number to type. Use the picker or + / − to adjust.")).font(.caption).foregroundStyle(GymColor.dim)
                    Text(store.t("Use 0 for bodyweight or no added weight.")).font(.caption).foregroundStyle(GymColor.dim)
                    if !validWeight { Text(store.t("Enter a weight from 0 to 500.")).font(.caption).foregroundStyle(GymColor.red) }
                }
                if let previous = store.lastSet(for: exercise ?? Exercise.catalog[0]) {
                    Text(store.t("Last set") + ": " + (timed ? "\(previous.minutes.formatted()) min" : "\(GymStore.displayedWeight(previous.weightKG, unit: store.profile.unit).formatted(.number.precision(.fractionLength(0...1)))) \(store.profile.unit) × \(previous.reps)"))
                        .font(.subheadline).foregroundStyle(GymColor.dim)
                }
            }
            if !session.sets.isEmpty { VStack(alignment: .leading, spacing: 14) { Text(store.t("Logged sets")).font(.headline); SetList(sets: session.sets) }.padding(.top, 8) }
        }
    }
    private var footer: some View {
        VStack(spacing: 4) {
            if active {
                GymButton(title: store.t(timed ? "Finish activity" : "Finish set"), icon: "stop.fill", enabled: validLog, id: "set.stop", finishSet: true) {
                    dismissKeyboard()
                    if session.stage == .log { store.logSet(reps: Int(reps) ?? 0, minutes: minuteValue ?? 0) }
                    else { store.finishSet(reps: Int(reps) ?? 0, minutes: minuteValue ?? 0) }
                }
            } else {
                GymButton(title: store.t(timed ? "Start activity" : session.stage == .rest ? "Start next set" : "Start set"), icon: "play.fill", enabled: timed || validWeight, id: "set.start") {
                    dismissKeyboard(); store.startSet(weight: timed ? 0 : weightValue ?? 0, unit: store.profile.unit)
                }
                Button(store.t("Change exercise")) { dismissKeyboard(); store.changeExercise() }.frame(minHeight: 44).font(.subheadline.weight(.medium)).accessibilityIdentifier("set.change")
            }
        }
    }
    private func loadValues() {
        weight = inputString(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit))
        reps = String(session.draftReps ?? store.lastSet(for: exercise ?? Exercise.catalog[0])?.reps ?? 10)
        minutes = inputString(session.draftMinutes.flatMap { $0 > 0 ? $0 : nil } ?? 5)
    }
    private func dismissKeyboard() { searchFocused = false; UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
    private func inputString(_ value: Double) -> String { value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2)).grouping(.never)) }
    private func elapsed(_ from: Date, _ to: Date) -> String { let seconds = max(0, Int(to.timeIntervalSince(from))); return String(format: "%d:%02d", seconds / 60, seconds % 60) }
}
struct NumericEntry: View {
    let label: String
    @Binding var text: String
    let id: String
    let maxValue: Double
    let step: Double
    let minimum: Double
    @State private var picker = false
    private var value: Double { Double(text.replacingOccurrences(of: ",", with: ".")) ?? minimum }
    private func format(_ value: Double) -> String { value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).precision(.fractionLength(0...2)).grouping(.never)) }
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button { text = format(max(minimum, value - step)) } label: { Image(systemName: "minus").frame(width: 44, height: 44) }.accessibilityLabel("Decrease " + label).accessibilityIdentifier(id + ".minus")
                TextField(label, text: $text).font(.system(size: 38, weight: .semibold)).monospacedDigit().multilineTextAlignment(.center)
                    .keyboardType(step < 1 ? .decimalPad : .numberPad).accessibilityLabel(label).accessibilityIdentifier(id)
                    .modifier(SelectNumberOnFocus())
                Button { text = format(min(maxValue, value + step)) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.accessibilityLabel("Increase " + label).accessibilityIdentifier(id + ".plus")
            }
            Button { picker = true } label: { HStack(spacing: 6) { Text(label); Image(systemName: "chevron.up.chevron.down") }.font(.subheadline.weight(.medium)).frame(minHeight: 44) }.accessibilityIdentifier(id + ".picker")
        }.padding(16).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 18))
            .sheet(isPresented: $picker) {
                NavigationStack {
                    VStack(spacing: 12) {
                        TextField(label, text: $text).font(.largeTitle.monospacedDigit()).multilineTextAlignment(.center).keyboardType(step < 1 ? .decimalPad : .numberPad).padding(12).accessibilityIdentifier(id + ".manual").modifier(SelectNumberOnFocus())
                        Picker(label, selection: Binding(get: { min(maxValue, max(minimum, (value / step).rounded() * step)) }, set: { text = format($0) })) {
                            ForEach(0...Int((maxValue - minimum) / step), id: \.self) { index in let number = minimum + Double(index) * step; Text(format(number)).tag(number) }
                        }.pickerStyle(.wheel).labelsHidden().accessibilityIdentifier(id + ".wheel")
                    }.padding(.horizontal, 24).navigationTitle(label).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { picker = false }.accessibilityIdentifier(id + ".picker.done") } }
                }.presentationDetents([.height(360)])
            }
    }
}
struct SelectNumberOnFocus: ViewModifier {
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
            guard let field = notification.object as? UITextField, field.isFirstResponder else { return }
            DispatchQueue.main.async { field.selectAll(nil) }
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
                Button(store.t("Add exercise")) {
                    onAdd(Exercise(id: UUID().uuidString, name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)), area: timed ? "Cardio" : "Your training", timed: timed)); dismiss()
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("custom.add")
            }.navigationTitle(store.t("Add custom exercise")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } } }
        }
    }
}
struct SummaryView: View {
    @EnvironmentObject private var store: GymStore
    var session: Session
    @State private var save = false
    @State private var name = ""
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Label(store.t("Focus preview ended"), systemImage: "lock.open.fill").font(.caption.weight(.semibold)).foregroundStyle(GymColor.blue).accessibilityIdentifier("summary.unblocked")
                    GymMark(size: 100, celebrate: true).frame(maxWidth: .infinity).padding(.vertical, 12)
                    Text(store.t(session.sets.isEmpty ? "Session ended." : "Workout complete")).font(.largeTitle.weight(.bold))
                    if session.sets.isEmpty { Text(store.t("No sets logged this time.")).foregroundStyle(GymColor.dim) }
                    else {
                        Card { WorkoutRecap(session: session) }
                        Card { SetList(sets: session.sets) }
                        if session.splitID == nil {
                            Toggle(store.t("Save these exercises as a split"), isOn: $save).accessibilityIdentifier("summary.save")
                            if save { TextField(store.t("Split name"), text: $name).padding(18).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("summary.name") }
                        }
                    }
                }.padding(24)
            }
            GymButton(title: store.t("Done"), id: "summary.done") { if save { store.saveWorkout(from: session, name: name) }; store.summary = nil }.padding(24)
        }.onAppear { name = session.name == "Free workout" ? "" : session.name }
    }
}
