import SwiftUI

/// Gender, height and weight from onboarding, editable at any time. Stays on this iPhone.
struct BodySettingsView: View {
  @EnvironmentObject private var store: GymStore
  private var metric: Bool { store.profile.unit == "kg" }
  var body: some View {
    Form {
      Picker(store.t("Gender"), selection: Binding(get: { store.profile.gender ?? "" }, set: { v in store.updateProfile { $0.gender = v.isEmpty ? nil : v } })) {
        Text(store.t("Not set")).tag("")
        Text(store.t("Male")).tag("male"); Text(store.t("Female")).tag("female"); Text(store.t("Other")).tag("other")
      }.accessibilityIdentifier("settings.gender")
      Picker(store.t("Height"), selection: Binding(
        get: { Int(((store.profile.heightCM ?? 170) / (metric ? 1 : 2.54)).rounded()) },
        set: { v in store.updateProfile { $0.heightCM = metric ? Double(v) : (Double(v) * 2.54).rounded() } })) {
        ForEach(metric ? Array(120...220) : Array(48...90), id: \.self) { v in
          Text(metric ? "\(v) cm" : BodyUnits.feet(Double(v))).tag(v)
        }
      }.accessibilityIdentifier("settings.height")
      Picker(store.t("Weight"), selection: Binding(
        get: { Int((GymStore.displayedWeight(store.profile.bodyWeightKG ?? 72, unit: store.profile.unit)).rounded()) },
        set: { v in store.updateProfile { $0.bodyWeightKG = (GymStore.kilograms(Double(v), unit: $0.unit) * 10).rounded() / 10 } })) {
        ForEach(metric ? Array(30...200) : Array(66...440), id: \.self) { v in Text("\(v) \(store.profile.unit)").tag(v) }
      }.accessibilityIdentifier("settings.weight")
      Text(store.t("Stays on this phone.")).font(.footnote).foregroundStyle(GymColor.dim)
    }.gymPage().navigationTitle(store.t("Body")).navigationBarTitleDisplayMode(.inline)
  }
}

/// A local notification when a rest reaches the chosen length.
struct RestAlertSettingsView: View {
  @EnvironmentObject private var store: GymStore
  @State private var denied = false
  var body: some View {
    Form {
      Toggle(store.t("Rest alert"), isOn: Binding(get: { store.profile.restAlerts == true }, set: { on in
        guard on else { store.updateProfile { $0.restAlerts = false }; return }
        Task { @MainActor in
          let granted = await RestAlert.requestPermission()
          denied = !granted
          store.updateProfile { $0.restAlerts = granted }
        }
      })).accessibilityIdentifier("settings.restAlert")
      Picker(store.t("Alert after"), selection: Binding(get: { store.profile.restSeconds ?? 90 }, set: { v in store.updateProfile { $0.restSeconds = v } })) {
        ForEach([60, 90, 120, 180, 240], id: \.self) { Text(clockString($0)).tag($0) }
      }.disabled(store.profile.restAlerts != true)
      if denied {
        Text(store.t("Notifications are off for GymBlock. Turn them on in iOS Settings.")).font(.footnote).foregroundStyle(GymColor.dim)
      }
    }.gymPage().navigationTitle(store.t("Rest alert")).navigationBarTitleDisplayMode(.inline)
  }
}

/// Account actions. GymBlock has no server account: both act on this iPhone only.
struct AccountSection: View {
  @EnvironmentObject private var store: GymStore
  let close: () -> Void
  @State private var confirmLogOut = false
  @State private var confirmDelete = false
  var body: some View {
    Section {
      Button(store.t("Log out")) { confirmLogOut = true }
        .foregroundStyle(GymColor.ink).accessibilityIdentifier("settings.logout")
      Button(store.t("Delete account"), role: .destructive) { confirmDelete = true }
        .foregroundStyle(Color(uiColor: .systemRed)).accessibilityIdentifier("settings.delete")
    } footer: {
      Text(store.t("Your account lives only on this iPhone.")).font(.footnote)
    }
    .confirmationDialog(store.t("Log out of GymBlock?"), isPresented: $confirmLogOut, titleVisibility: .visible) {
      Button(store.t("Log out")) { run(store.logOut) }.accessibilityIdentifier("settings.logout.confirm")
      Button(store.t("Cancel"), role: .cancel) {}
    } message: { Text(store.t("Your workouts and splits stay on this iPhone.")) }
    .alert(store.t("Delete your account?"), isPresented: $confirmDelete) {
      Button(store.t("Delete account"), role: .destructive) { run(store.deleteAccount) }
        .accessibilityIdentifier("settings.delete.confirm")
      Button(store.t("Cancel"), role: .cancel) {}
    } message: {
      Text(store.t("This permanently deletes your workouts, splits, answers and settings. It can’t be undone."))
    }
    // Outermost, so the dialogs inherit it: only the destructive choice reads red.
    .tint(GymColor.ink)
  }
  /// Close Settings first so the sheet isn't torn down mid-presentation.
  private func run(_ action: @escaping () -> Void) {
    close()
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(350))
      action()
    }
  }
}
