import SwiftUI
import UserNotifications

/// Settings, designed from a clean slate on 11 Oct 2026 in the app's own language: a large title with
/// a round glass close button, small uppercase section labels and plain ruled rows on the paper page
/// (no cards, no icon chips; toggles turn emerald when on). Ordered by how often they matter: you,
/// the plan, the workout, blocking, notifications, the app, your data, help, then the account exits. Haptics are
/// always on, so there is no switch for them. Sub-pages (Body, Training answers, Data) share the page.
struct PreferencesView: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  @Environment(\.dismiss) private var dismiss
  @Environment(\.scenePhase) private var scenePhase
  /// iOS's notification permission, read on open and on every return to the app; nil until read.
  @State private var notifications: UNAuthorizationStatus?
  @ObservedObject private var blocking = AppBlocking.shared
  @State private var renaming = false
  @State private var draftName = ""
  @AppStorage(Appearance.key) private var appearance = Appearance.system.rawValue
  /// Strict mode lives with the blocked apps on this iPhone (the App Group), where the shield reads it.
  @AppStorage(BlockingPass.strictKey, store: BlockingPass.defaults) private var strict = true
  var body: some View {
    NavigationStack {
      List {
        HStack(alignment: .center) {
          Text(store.t("Settings")).font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
            .accessibilityAddTraits(.isHeader)
          Spacer()
          RoundGlassButton(symbol: "xmark", label: store.t("Close")) { dismiss() }.accessibilityIdentifier("preferences.done")
        }.padding(.top, 22).padding(.bottom, 4).pageRow().listRowSeparator(.hidden)

        SettingsLabel(store.t("You"))
        Button { draftName = store.profile.name; renaming = true } label: {
          SettingRow(title: store.t("Name"), value: store.profile.name.isEmpty ? store.t("Optional") : store.profile.name, chevron: true)
        }.buttonStyle(.plain).pageRow().accessibilityIdentifier("settings.name")
        if let email = account.email {
          SettingRow(title: store.t("Email"), value: email).pageRow()
        }
        NavigationLink { BodySettingsView() } label: { SettingRow(title: store.t("Body")) }
          .pageRow().accessibilityIdentifier("settings.body")

        SubscriptionSettingsSection()

        SettingsLabel(store.t("Workout"))
        SettingMenu(title: store.t("Rest length"), value: clockString(store.restTarget), id: "settings.rest") {
          Picker(store.t("Rest length"), selection: Binding(get: { store.restTarget }, set: { store.setRestTarget($0) })) {
            ForEach(GymStore.restChoices, id: \.self) { Text(clockString($0)).tag($0) }
          }
        }
        SettingToggle(title: store.t("Time each set"), id: "settings.timeSets",
                      isOn: Binding(get: { store.timesSets }, set: { v in store.updateProfile { $0.timeSets = v } }))
        SettingsNote(store.t(store.timesSets ? "Start and Finish each set to time it." : "One tap logs a set. Rest still counts."))

        SettingsLabel(store.t("Blocking"))
        NavigationLink { BlockedAppsView() } label: { SettingRow(title: store.t("Blocked apps"), value: blockingValue) }
          .pageRow().accessibilityIdentifier("settings.blockedApps")
        SettingToggle(title: store.t("Strict mode"), id: "settings.strict",
                      isOn: Binding(get: { strict }, set: { on in strict = on; Analytics.tap("settings.strict", ["on": on]) }))
        SettingsNote(store.t(strict ? "No way past the block until you finish." : "The block screen offers 1 minute, once per exercise."))

        SettingsLabel(store.t("Notifications"))
        notificationsRow
        SettingToggle(title: store.t("Rest alert"), id: "settings.restAlert",
                      isOn: Binding(get: { store.profile.restAlerts == true }, set: setAlerts))
        if store.profile.restAlerts == true && notifications.map(allowed) == false {
          SettingsNote(store.t("Notifications are off, so rest alerts can’t reach you."))
        }

        SettingsLabel(store.t("App"))
        SettingMenu(title: store.t("Appearance"), value: store.t(Appearance(rawValue: appearance)?.title ?? "System"), id: "settings.appearance") {
          Picker(store.t("Appearance"), selection: $appearance) {
            ForEach(Appearance.allCases, id: \.self) { Text(store.t($0.title)).tag($0.rawValue) }
          }
        }
        SettingMenu(title: store.t("Units"), value: store.profile.unit, id: "settings.units") {
          Picker(store.t("Units"), selection: Binding(get: { store.profile.unit }, set: { v in store.updateProfile { $0.unit = v } })) {
            Text("kg").tag("kg"); Text("lb").tag("lb")
          }
        }
        SettingMenu(title: store.t("Language"), value: store.profile.language == "es" ? "Español" : "English", id: "settings.language") {
          Picker(store.t("Language"), selection: Binding(get: { store.profile.language }, set: { v in store.updateProfile { $0.language = v } })) {
            Text("English").tag("en"); Text("Español").tag("es")
          }
        }
        SettingToggle(title: store.t("Sound"), id: "settings.sound",
                      isOn: Binding(get: { store.profile.soundEnabled ?? false }, set: { v in store.updateProfile { $0.soundEnabled = v } }))

        SettingsLabel(store.t("Your data"))
        NavigationLink { TrainingAnswersForm() } label: { SettingRow(title: store.t("Training answers")) }
          .pageRow().accessibilityIdentifier("settings.baseline")
        NavigationLink { DataSettingsView() } label: { SettingRow(title: store.t("Data")) }
          .pageRow().accessibilityIdentifier("settings.data")

        LegalSection()
        AccountSection { dismiss() }
      }
      .listStyle(.plain).scrollContentBackground(.hidden).background(DotGrid())
      .contentMargins(.bottom, 32, for: .scrollContent)
      .toolbar(.hidden, for: .navigationBar)
      .alert(store.t("Your name"), isPresented: $renaming) {
        TextField(store.t("Your name"), text: $draftName).textInputAutocapitalization(.words)
        Button(store.t("Cancel"), role: .cancel) {}
        Button(store.t("Save")) {
          store.updateProfile { $0.name = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)) }
        }
      } message: { Text(store.t("This is how GymBlock greets you.")) }
      .track(screen: "settings")
      .task { await readNotifications() }
      .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await readNotifications() } } }
    }
  }
  /// iOS's notification permission. GymBlock can ask for it but never take it back, so there's no
  /// switch: a button while it isn't given (it asks; once refused, iOS won't ask again, so it opens
  /// GymBlock's notification settings in iOS), then just "On".
  @ViewBuilder private var notificationsRow: some View {
    if let notifications, !allowed(notifications) {
      Button(action: allowNotifications) {
        HStack(spacing: 10) {
          Text(store.t("Notifications")).font(.app(.body)).foregroundStyle(JourneyColor.text).lineLimit(1)
          Spacer(minLength: 12)
          Text(store.t("Turn on")).font(.app(.body, weight: .semibold)).foregroundStyle(JourneyColor.signal).lineLimit(1)
        }.frame(minHeight: 50).contentShape(Rectangle())
      }.buttonStyle(.plain).pageRow().accessibilityIdentifier("settings.notifications")
    } else {
      SettingRow(title: store.t("Notifications"), value: notifications == nil ? nil : store.t("On")).pageRow()
        .accessibilityIdentifier("settings.notifications")
    }
  }
  private func allowed(_ status: UNAuthorizationStatus) -> Bool {
    status == .authorized || status == .provisional || status == .ephemeral
  }
  private func readNotifications() async {
    notifications = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }
  private func allowNotifications() {
    Analytics.tap("settings.notifications")
    Task { @MainActor in
      if notifications == .notDetermined {
        let granted = await RestAlert.requestPermission()
        Analytics.track("notifications_access", ["granted": granted, "where": "settings"])
      } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        await UIApplication.shared.open(url)
      }
      await readNotifications()
    }
  }
  /// "Off", "No access" (Screen Time), "None" or what's blocked ("3 apps").
  private var blockingValue: String {
    switch blocking.state(store.profile) {
    case .off: store.t("Off")
    case .noAccess: store.t("No access")
    case .noApps: store.t("None")
    case .on: blocking.summary(store.t)
    }
  }
  /// Turning the alert on asks iOS once; if notifications are off, it stays off and the row above
  /// has the way to turn them on.
  private func setAlerts(_ on: Bool) {
    guard on else { store.updateProfile { $0.restAlerts = false }; return }
    Task { @MainActor in
      let granted = await RestAlert.requestPermission()
      store.updateProfile { $0.restAlerts = granted }
      await readNotifications()
    }
  }
}

// MARK: - Settings parts

/// A small uppercase section label, with room above it.
struct SettingsLabel: View {
  let text: String
  init(_ text: String) { self.text = text }
  var body: some View {
    PageLabel(text: text).padding(.top, 22).pageRow().listRowSeparator(.hidden, edges: .top)
  }
}

/// One quiet grey line under a section, in plain words.
struct SettingsNote: View {
  let text: String
  init(_ text: String) { self.text = text }
  var body: some View {
    Text(text).font(.app(.footnote)).foregroundStyle(JourneyColor.tertiary).fixedSize(horizontal: false, vertical: true)
      .padding(.top, 8).padding(.bottom, 2).pageRow().listRowSeparator(.hidden)
  }
}

/// A ruled row: what it is on the left; its value in grey and a chevron (or an outward arrow for a
/// web page) on the right.
struct SettingRow: View {
  let title: String
  var value: String? = nil
  var chevron = false
  var external = false
  var titleColor: Color = JourneyColor.text
  var body: some View {
    HStack(spacing: 10) {
      Text(title).font(.app(.body)).foregroundStyle(titleColor).lineLimit(1)
      Spacer(minLength: 12)
      if let value { Text(value).font(.app(.body)).foregroundStyle(JourneyColor.secondary).lineLimit(1) }
      if chevron { Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(JourneyColor.tertiary) }
      if external { Image(systemName: "arrow.up.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(JourneyColor.tertiary) }
    }.frame(minHeight: 50).contentShape(Rectangle())
  }
}

/// A switch as a ruled row, emerald when on.
struct SettingToggle: View {
  let title: String
  let id: String
  @Binding var isOn: Bool
  var body: some View {
    Toggle(isOn: $isOn) { Text(title).font(.app(.body)).foregroundStyle(JourneyColor.text) }
      .tint(JourneyColor.signal).frame(minHeight: 50).pageRow().accessibilityIdentifier(id)
  }
}

/// A choice as a ruled row: the current value in grey; tapping opens the system menu.
struct SettingMenu<Choices: View>: View {
  let title: String
  let value: String
  let id: String
  @ViewBuilder var choices: Choices
  var body: some View {
    Menu { choices } label: {
      HStack(spacing: 6) {
        Text(title).font(.app(.body)).foregroundStyle(JourneyColor.text).lineLimit(1)
        Spacer(minLength: 12)
        Text(value).font(.app(.body)).foregroundStyle(JourneyColor.secondary).lineLimit(1)
        Image(systemName: "chevron.up.chevron.down").font(.system(.caption, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
      }.frame(minHeight: 50).contentShape(Rectangle())
    }.buttonStyle(.plain).pageRow().accessibilityLabel(title + ", " + value).accessibilityIdentifier(id)
  }
}

/// A settings sub-page: the same paper page, its name as the large title, ruled rows below.
struct SettingsSubpage<Content: View>: View {
  let title: String
  @ViewBuilder var content: Content
  var body: some View {
    List {
      Text(title).font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
        .accessibilityAddTraits(.isHeader).padding(.bottom, 4).pageRow().listRowSeparator(.hidden)
      content
    }
    .listStyle(.plain).scrollContentBackground(.hidden).background(DotGrid())
    .navigationBarTitleDisplayMode(.inline)
  }
}

struct SettingsDivider: View {
  var body: some View { Rectangle().fill(JourneyColor.ink(0.08)).frame(height: 1) }
}

// MARK: - Sub-pages

/// Sample workouts for an empty log, and clearing the training answers.
struct DataSettingsView: View {
  @EnvironmentObject private var store: GymStore
  @State private var deleting = false
  var body: some View {
    SettingsSubpage(title: store.t("Data")) {
      if store.data.history.isEmpty && store.data.workouts.isEmpty {
        Button { store.loadDemoIfEmpty() } label: { SettingRow(title: store.t("Load sample workouts")) }
          .buttonStyle(.plain).pageRow().accessibilityIdentifier("settings.demo")
      }
      Button { deleting = true } label: { SettingRow(title: store.t("Delete training answers"), titleColor: JourneyColor.secondary) }
        .buttonStyle(.plain).pageRow().accessibilityIdentifier("settings.deleteAnswers")
        .confirmationDialog(store.t("Delete training answers?"), isPresented: $deleting, titleVisibility: .visible) {
          Button(store.t("Delete answers"), role: .destructive) { store.deleteRoutineAnswers() }
          Button(store.t("Cancel"), role: .cancel) {}
        } message: { Text(store.t("Workouts and splits stay saved.")) }
      SettingsNote(store.t("Workouts and splits stay saved."))
    }.track(screen: "settings.data")
  }
}

/// The answers from onboarding, editable: phone between sets and minutes per rest, then how you
/// train. Each number is checked as it's typed; Save keeps them, Cancel leaves them.
struct TrainingAnswersForm: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var draft = RoutineBaseline()
  @State private var error = false
  @State private var raw: [String: String] = [:]
  @State private var invalid = Set<String>()
  var body: some View {
    SettingsSubpage(title: store.t("Training answers")) {
      SettingsLabel(store.t("Your phone"))
      SettingMenu(title: store.t("Phone between sets"), value: habitTitle(draft.scrollFrequency), id: "answers.habit") {
        Picker(store.t("Phone between sets"), selection: $draft.scrollFrequency) {
          Text(store.t("Not sure")).tag(Optional<HabitAnswer>.none)
          ForEach(HabitAnswer.allCases, id: \.self) { item in Text(habitTitle(item)).tag(Optional(item)) }
        }
      }
      number("Minutes / rest", value: Binding(get: { draft.scrollingMinutes.map(inputNumber) ?? "" }, set: { draft.scrollingMinutes = parseNumber($0); draft.minutesPerBreak = nil }), unit: "min")
      SettingsLabel(store.t("Your training"))
      number("Exercises / workout", value: survey(.exercises))
      number("Sets / exercise", value: survey(.sets))
      number("Reps / set", value: survey(.reps))
      number("Days / week", value: Binding(get: { draft.trainingDays.map(String.init) ?? "" }, set: { draft.trainingDays = Int($0) }))
      if error { SettingsNote(store.t("Check the entered values.")) }
    }
    .track(screen: "settings.answers")
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
        }.fontWeight(.semibold).accessibilityIdentifier("answers.save")
      }
    }
    .onAppear { draft = store.profile.baseline ?? RoutineBaseline() }
  }
  private func habitTitle(_ item: HabitAnswer?) -> String {
    guard let item else { return store.t("Not sure") }
    return store.t(item == .yes ? "Yes" : item == .sometimes ? "Sometimes" : "No")
  }
  private func survey(_ field: SurveyField) -> Binding<String> {
    Binding(get: { field.read(draft) }, set: {
      field.write($0, into: &draft)
      if field == .reps && !$0.isEmpty { draft.timed = false }
    })
  }
  /// A number as a ruled row: the question on the left, the answer typed on the right.
  @ViewBuilder private func number(_ label: String, value: Binding<String>, unit: String = "") -> some View {
    HStack(spacing: 8) {
      Text(store.t(label)).font(.app(.body)).foregroundStyle(invalid.contains(label) ? JourneyColor.signal : JourneyColor.text).lineLimit(1)
      Spacer(minLength: 12)
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
        .font(.app(.body)).monospacedDigit().foregroundStyle(JourneyColor.text).tint(JourneyColor.signal)
        .multilineTextAlignment(.trailing).frame(minWidth: 60, maxWidth: 100)
        .accessibilityLabel(store.t(label)).modifier(SelectNumberOnFocus())
      if !unit.isEmpty { Text(unit).font(.app(.body)).foregroundStyle(JourneyColor.secondary) }
    }.frame(minHeight: 50).pageRow()
    if invalid.contains(label) { SettingsNote(store.t("Check this value.")) }
  }
}
