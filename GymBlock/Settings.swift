import FamilyControls
import SwiftUI

/// Settings, ordered by how often they matter during a workout.
struct PreferencesView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var denied = false
  @ObservedObject private var blocking = AppBlocking.shared
  @State private var picking = false
  @State private var pickDraft = FamilyActivitySelection()
  @State private var blockDenied = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker(store.t("Rest length"), selection: Binding(get: { store.restTarget }, set: { store.setRestTarget($0) })) {
            ForEach(GymStore.restChoices, id: \.self) { Text(clockString($0)).tag($0) }
          }.accessibilityIdentifier("settings.rest")
          Toggle(store.t("Rest alert"), isOn: Binding(get: { store.profile.restAlerts == true }, set: setAlerts)).tint(JourneyColor.signal)
            .accessibilityIdentifier("settings.restAlert")
          Toggle(store.t("Time each set"), isOn: Binding(get: { store.timesSets }, set: { v in store.updateProfile { $0.timeSets = v } })).tint(JourneyColor.signal)
            .accessibilityIdentifier("settings.timeSets")
        } header: { Text(store.t("Workout")) } footer: {
          Text(store.t(denied ? "Notifications are off for GymBlock. Turn them on in iOS Settings."
                       : store.timesSets ? "Start and Finish each set to time it." : "One tap logs a set. Rest still counts."))
        }
        Section {
          Toggle(store.t("Block apps during workouts"), isOn: Binding(get: { store.profile.focusEnabled == true }, set: setBlocking)).tint(JourneyColor.signal)
            .accessibilityIdentifier("focus.enabled")
          Button(action: chooseApps) {
            HStack(spacing: 8) {
              Text(store.t("Apps to block")).foregroundStyle(JourneyColor.text)
              Spacer()
              BlockedIcons(size: 18, limit: 3).foregroundStyle(JourneyColor.secondary)
              if blocking.isEmpty { Text(store.t("None")).foregroundStyle(JourneyColor.secondary) }
              Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(JourneyColor.tertiary)
            }
          }.accessibilityIdentifier("settings.blockedApps")
        } header: { Text(store.t("Blocking")) } footer: {
          Text(store.t(blockDenied && !blocking.authorized ? "Screen Time access is off for GymBlock. Allow it in iOS Settings."
                       : "Uses Apple’s Screen Time from Start workout to Finish. Pausing lifts it."))
        }
        Section {
          HStack {
            Text(store.t("Name"))
            TextField(store.t("Optional"), text: Binding(get: { store.profile.name }, set: { v in store.updateProfile { $0.name = String(v.prefix(40)) } }))
              .multilineTextAlignment(.trailing)
          }
          NavigationLink(store.t("Body")) { BodySettingsView() }.accessibilityIdentifier("settings.body")
          Picker(store.t("Units"), selection: Binding(get: { store.profile.unit }, set: { v in store.updateProfile { $0.unit = v } })) {
            Text("kg").tag("kg"); Text("lb").tag("lb")
          }
          Picker(store.t("Language"), selection: Binding(get: { store.profile.language }, set: { v in store.updateProfile { $0.language = v } })) {
            Text("English").tag("en"); Text("Español").tag("es")
          }
          Toggle(store.t("Haptics"), isOn: Binding(get: { store.profile.hapticsEnabled ?? true }, set: { v in store.updateProfile { $0.hapticsEnabled = v } })).tint(JourneyColor.signal)
          Toggle(store.t("Sound"), isOn: Binding(get: { store.profile.soundEnabled ?? false }, set: { v in store.updateProfile { $0.soundEnabled = v } })).tint(JourneyColor.signal)
        } header: { Text(store.t("You")) }
        Section {
          NavigationLink(store.t("Training answers")) { TrainingAnswersForm() }.accessibilityIdentifier("settings.baseline")
          NavigationLink(store.t("Data")) { DataSettingsView() }.accessibilityIdentifier("settings.data")
        }
        AccountSection { dismiss() }
        LegalSection()
      }.gymPage().tint(JourneyColor.secondary).track(screen: "settings")
        .familyActivityPicker(headerText: store.t("Choose what to block from Start workout to Finish."), isPresented: $picking, selection: $pickDraft)
        .onChange(of: pickDraft) { _, chosen in blocking.choose(chosen) }
        .navigationTitle(store.t("Settings")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() }.tint(JourneyColor.text).accessibilityIdentifier("preferences.done") } }
    }
  }
  /// Turning blocking on asks for Screen Time access, then for the apps if none are chosen yet.
  private func setBlocking(_ on: Bool) {
    guard on else { store.updateProfile { $0.focusEnabled = false }; return }
    Task { @MainActor in
      let granted = await blocking.requestAccess()
      blockDenied = !granted
      store.updateProfile { $0.focusEnabled = granted }
      if granted && blocking.isEmpty { pickDraft = blocking.selection; picking = true }
    }
  }
  private func chooseApps() {
    Task { @MainActor in
      guard await blocking.requestAccess() else { blockDenied = true; return }
      blockDenied = false
      pickDraft = blocking.selection
      picking = true
    }
  }
  /// Turning the alert on asks iOS once; if notifications are off, say where to fix it.
  private func setAlerts(_ on: Bool) {
    guard on else { store.updateProfile { $0.restAlerts = false }; denied = false; return }
    Task { @MainActor in
      let granted = await RestAlert.requestPermission()
      denied = !granted
      store.updateProfile { $0.restAlerts = granted }
    }
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
    }.gymPage().navigationTitle(store.t("Data")).navigationBarTitleDisplayMode(.inline).track(screen: "settings.data")
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
    }.gymPage().navigationTitle(store.t("Training answers")).navigationBarTitleDisplayMode(.inline).track(screen: "settings.answers")
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

