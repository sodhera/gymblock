import FamilyControls
import SwiftUI

/// Settings, laid out like SleepBlock's: a large title with a round close button, small uppercase
/// section labels, and grouped glass cards of one-line rows (a tinted icon chip, a title, a quiet
/// value, a chevron). Ordered by how often they matter: you, the plan, the workout, blocking, the
/// app, your answers, help, then the account exits (Delete account as faint text below them).
/// Sub-pages are still native Forms under the Liquid Glass navigation bar.
struct PreferencesView: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  @Environment(\.dismiss) private var dismiss
  @State private var denied = false
  @ObservedObject private var blocking = AppBlocking.shared
  @State private var picking = false
  @State private var pickDraft = FamilyActivitySelection()
  @State private var blockDenied = false
  @State private var renaming = false
  @State private var draftName = ""
  var body: some View {
    NavigationStack {
      SettingsPage(close: { dismiss() }) {
        header
        SettingsSection(store.t("Profile")) {
          SettingsGroup {
            Button { draftName = store.profile.name; renaming = true } label: {
              SettingsRow(icon: "person.fill", title: store.t("Name"),
                          value: store.profile.name.isEmpty ? store.t("Optional") : store.profile.name, chevron: true)
            }.buttonStyle(.plain).accessibilityIdentifier("settings.name")
            if let email = account.email {
              SettingsDivider()
              SettingsRow(icon: "envelope.fill", tint: JourneyColor.secondary, title: store.t("Email"), value: email)
            }
            SettingsDivider()
            NavigationLink { BodySettingsView() } label: {
              SettingsRow(icon: "figure.arms.open", title: store.t("Body"), chevron: true)
            }.buttonStyle(.plain).accessibilityIdentifier("settings.body")
          }
        }
        SubscriptionSettingsSection()
        SettingsSection(store.t("Workout"), note: store.t(denied ? "Notifications are off for GymBlock. Turn them on in iOS Settings."
                                                         : store.timesSets ? "Start and Finish each set to time it." : "One tap logs a set. Rest still counts.")) {
          SettingsGroup {
            SettingsMenu(icon: "timer", title: store.t("Rest length"), value: clockString(store.restTarget), id: "settings.rest") {
              Picker(store.t("Rest length"), selection: Binding(get: { store.restTarget }, set: { store.setRestTarget($0) })) {
                ForEach(GymStore.restChoices, id: \.self) { Text(clockString($0)).tag($0) }
              }
            }
            SettingsDivider()
            SettingsToggle(icon: "bell.fill", title: store.t("Rest alert"), id: "settings.restAlert",
                           isOn: Binding(get: { store.profile.restAlerts == true }, set: setAlerts))
            SettingsDivider()
            SettingsToggle(icon: "stopwatch.fill", title: store.t("Time each set"), id: "settings.timeSets",
                           isOn: Binding(get: { store.timesSets }, set: { v in store.updateProfile { $0.timeSets = v } }))
          }
        }
        SettingsSection(store.t("Blocking"), note: store.t(blockDenied && !blocking.authorized ? "Screen Time access is off for GymBlock. Allow it in iOS Settings."
                                                         : "Uses Apple’s Screen Time from Start workout to Finish. Pausing lifts it.")) {
          SettingsGroup {
            SettingsToggle(icon: "lock.fill", title: store.t("Block apps during workouts"), id: "focus.enabled",
                           isOn: Binding(get: { store.profile.focusEnabled == true }, set: setBlocking))
            SettingsDivider()
            Button(action: chooseApps) {
              HStack(spacing: 12) {
                SettingsIcon(symbol: "square.grid.2x2.fill")
                Text(store.t("Apps to block")).font(.body).foregroundStyle(JourneyColor.text)
                Spacer(minLength: 12)
                BlockedIcons(size: 18, limit: 3).foregroundStyle(JourneyColor.secondary)
                if blocking.isEmpty { Text(store.t("None")).font(.subheadline).foregroundStyle(JourneyColor.secondary) }
                SettingsChevron()
              }.settingsRowFrame()
            }.buttonStyle(.plain).accessibilityIdentifier("settings.blockedApps")
          }
        }
        SettingsSection(store.t("App")) {
          SettingsGroup {
            SettingsMenu(icon: "scalemass.fill", title: store.t("Units"), value: store.profile.unit, id: "settings.units") {
              Picker(store.t("Units"), selection: Binding(get: { store.profile.unit }, set: { v in store.updateProfile { $0.unit = v } })) {
                Text("kg").tag("kg"); Text("lb").tag("lb")
              }
            }
            SettingsDivider()
            SettingsMenu(icon: "globe", title: store.t("Language"), value: store.profile.language == "es" ? "Español" : "English", id: "settings.language") {
              Picker(store.t("Language"), selection: Binding(get: { store.profile.language }, set: { v in store.updateProfile { $0.language = v } })) {
                Text("English").tag("en"); Text("Español").tag("es")
              }
            }
            SettingsDivider()
            SettingsToggle(icon: "iphone.radiowaves.left.and.right", title: store.t("Haptics"), id: "settings.haptics",
                           isOn: Binding(get: { store.profile.hapticsEnabled ?? true }, set: { v in store.updateProfile { $0.hapticsEnabled = v } }))
            SettingsDivider()
            SettingsToggle(icon: "speaker.wave.2.fill", title: store.t("Sound"), id: "settings.sound",
                           isOn: Binding(get: { store.profile.soundEnabled ?? false }, set: { v in store.updateProfile { $0.soundEnabled = v } }))
          }
        }
        SettingsSection(store.t("Your data")) {
          SettingsGroup {
            NavigationLink { TrainingAnswersForm() } label: {
              SettingsRow(icon: "list.bullet.clipboard.fill", title: store.t("Training answers"), chevron: true)
            }.buttonStyle(.plain).accessibilityIdentifier("settings.baseline")
            SettingsDivider()
            NavigationLink { DataSettingsView() } label: {
              SettingsRow(icon: "tray.full.fill", title: store.t("Data"), chevron: true)
            }.buttonStyle(.plain).accessibilityIdentifier("settings.data")
          }
        }
        LegalSection()
        AccountSection { dismiss() }
        Text("GymBlock " + Analytics.appVersion + " (" + Analytics.build + ")").font(JourneyType.caption)
          .foregroundStyle(JourneyColor.tertiary).frame(maxWidth: .infinity).padding(.top, 24)
      }
      .familyActivityPicker(headerText: store.t("Choose what to block from Start workout to Finish."), isPresented: $picking, selection: $pickDraft)
      .onChange(of: pickDraft) { _, chosen in blocking.choose(chosen) }
      .alert(store.t("Your name"), isPresented: $renaming) {
        TextField(store.t("Your name"), text: $draftName).textInputAutocapitalization(.words)
        Button(store.t("Cancel"), role: .cancel) {}
        Button(store.t("Save")) {
          store.updateProfile { $0.name = String(draftName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)) }
        }
      } message: { Text(store.t("This is how GymBlock greets you.")) }
      .track(screen: "settings")
    }
  }
  private var header: some View {
    HStack {
      Text(store.t("Settings")).font(JourneyType.headline).tracking(-0.3).foregroundStyle(JourneyColor.text)
        .accessibilityAddTraits(.isHeader)
      Spacer()
      // The close button is pinned by `SettingsPage`; this holds its place beside the title.
      Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
    }.padding(.top, 8)
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

// MARK: - Settings parts (after SleepBlock's GlassGroup / GlassRow)

/// The page: the paper stage, a transparent scroll, no navigation bar on the root, and the round close
/// button pinned top right so it stays in reach however far the page has scrolled.
struct SettingsPage<Content: View>: View {
  let close: () -> Void
  @ViewBuilder var content: Content
  var body: some View {
    ZStack {
      GymBackdrop()
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) { content }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 20).padding(.bottom, 48)
      }
    }
    .overlay(alignment: .topTrailing) {
      SettingsCloseButton(action: close).accessibilityIdentifier("preferences.done").padding(.trailing, 20).padding(.top, 8)
    }
    .foregroundStyle(JourneyColor.text)
    .toolbar(.hidden, for: .navigationBar)
  }
}

/// A small uppercase label over one glass group, with an optional plain-words note under it.
struct SettingsSection<Content: View>: View {
  let label: String
  var note: String? = nil
  @ViewBuilder var content: Content
  init(_ label: String, note: String? = nil, @ViewBuilder content: () -> Content) {
    self.label = label; self.note = note; self.content = content()
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(label).font(.system(.caption, weight: .semibold)).tracking(1.4).textCase(.uppercase)
        .foregroundStyle(JourneyColor.secondary).padding(.leading, 4)
        .accessibilityAddTraits(.isHeader)
      content
      if let note {
        Text(note).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
          .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
      }
    }.padding(.top, 28)
  }
}

/// One glass card holding a cluster of rows, separated by `SettingsDivider`.
struct SettingsGroup<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    VStack(alignment: .leading, spacing: 0) { content }
      .padding(.horizontal, 16)
      .journeySurface(cornerRadius: 20)
  }
}

struct SettingsDivider: View {
  var body: some View { Rectangle().fill(JourneyColor.ink(0.08)).frame(height: 1) }
}

/// The leading icon chip: the symbol in a soft rounded square tinted from its own colour.
struct SettingsIcon: View {
  let symbol: String
  var tint: Color = JourneyColor.signal
  var body: some View {
    Image(systemName: symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(tint)
      .frame(width: 30, height: 30)
      .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.12)))
      .accessibilityHidden(true)
  }
}

struct SettingsChevron: View {
  var body: some View {
    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
      .accessibilityHidden(true)
  }
}

extension View {
  /// Every row's height and hit area.
  func settingsRowFrame() -> some View {
    padding(.vertical, 11).frame(minHeight: 52).contentShape(Rectangle())
  }
}

/// A one-line row: icon, title, an optional quiet value, an optional chevron. Rows name things;
/// the notes under a group explain them.
struct SettingsRow: View {
  let icon: String
  var tint: Color = JourneyColor.signal
  let title: String
  var titleColor: Color = JourneyColor.text
  var value: String? = nil
  var chevron = false
  var body: some View {
    HStack(spacing: 12) {
      SettingsIcon(symbol: icon, tint: tint)
      Text(title).font(.body).foregroundStyle(titleColor)
      Spacer(minLength: 12)
      if let value {
        Text(value).font(.subheadline).foregroundStyle(JourneyColor.secondary).lineLimit(1).truncationMode(.middle)
      }
      if chevron { SettingsChevron() }
    }.settingsRowFrame()
  }
}

/// A row with a switch in the signal colour.
struct SettingsToggle: View {
  let icon: String
  let title: String
  var id = ""
  @Binding var isOn: Bool
  var body: some View {
    HStack(spacing: 12) {
      SettingsIcon(symbol: icon)
      Toggle(isOn: $isOn) { Text(title).font(.body).foregroundStyle(JourneyColor.text) }
        .tint(JourneyColor.signal).accessibilityIdentifier(id)
    }.settingsRowFrame()
  }
}

/// A row that opens a menu of choices, showing the current one as its value.
struct SettingsMenu<Choices: View>: View {
  let icon: String
  let title: String
  let value: String
  var id = ""
  @ViewBuilder var choices: Choices
  var body: some View {
    Menu { choices } label: {
      HStack(spacing: 12) {
        SettingsIcon(symbol: icon)
        Text(title).font(.body).foregroundStyle(JourneyColor.text)
        Spacer(minLength: 12)
        Text(value).font(.subheadline).foregroundStyle(JourneyColor.secondary).monospacedDigit()
        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
      }.settingsRowFrame()
    }.buttonStyle(.plain).accessibilityIdentifier(id)
  }
}

/// The round glass close button at the top right of the page.
struct SettingsCloseButton: View {
  let action: () -> Void
  var body: some View {
    let icon = Image(systemName: "xmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(JourneyColor.text)
      .frame(width: 44, height: 44)
    Group {
      if #available(iOS 26.0, *) {
        Button(action: action) { icon }.buttonStyle(.glass).buttonBorderShape(.circle)
      } else {
        Button(action: action) { icon.background(Circle().fill(JourneyColor.fill)) }.buttonStyle(JourneyPressStyle())
      }
    }.accessibilityLabel("Close")
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

