import StoreKit
import SwiftUI

/// Gender, height and weight from onboarding, editable at any time: three choices as ruled rows.
struct BodySettingsView: View {
  @EnvironmentObject private var store: GymStore
  private var metric: Bool { store.profile.unit == "kg" }
  private var height: Int { Int(((store.profile.heightCM ?? 170) / (metric ? 1 : 2.54)).rounded()) }
  private var weight: Int { Int((GymStore.displayedWeight(store.profile.bodyWeightKG ?? 72, unit: store.profile.unit)).rounded()) }
  var body: some View {
    SettingsSubpage(title: store.t("Body")) {
      SettingMenu(title: store.t("Gender"), value: genderTitle, id: "settings.gender") {
        Picker(store.t("Gender"), selection: Binding(get: { store.profile.gender ?? "" }, set: { v in store.updateProfile { $0.gender = v.isEmpty ? nil : v } })) {
          Text(store.t("Not set")).tag("")
          Text(store.t("Male")).tag("male"); Text(store.t("Female")).tag("female"); Text(store.t("Other")).tag("other")
        }
      }
      SettingMenu(title: store.t("Height"), value: metric ? "\(height) cm" : BodyUnits.feet(Double(height)), id: "settings.height") {
        Picker(store.t("Height"), selection: Binding(
          get: { height },
          set: { v in store.updateProfile { $0.heightCM = metric ? Double(v) : (Double(v) * 2.54).rounded() } })) {
          ForEach(metric ? Array(120...220) : Array(48...90), id: \.self) { v in
            Text(metric ? "\(v) cm" : BodyUnits.feet(Double(v))).tag(v)
          }
        }
      }
      SettingMenu(title: store.t("Weight"), value: "\(weight) \(store.profile.unit)", id: "settings.weight") {
        Picker(store.t("Weight"), selection: Binding(
          get: { weight },
          set: { v in store.updateProfile { $0.bodyWeightKG = (GymStore.kilograms(Double(v), unit: $0.unit) * 10).rounded() / 10 } })) {
          ForEach(metric ? Array(30...200) : Array(66...440), id: \.self) { v in Text("\(v) \(store.profile.unit)").tag(v) }
        }
      }
      SettingsNote(store.t("Synced to your account."))
    }.track(screen: "settings.body")
  }
  private var genderTitle: String {
    switch store.profile.gender {
    case "male": return store.t("Male")
    case "female": return store.t("Female")
    case "other": return store.t("Other")
    default: return store.t("Not set")
    }
  }
}

/// The account as ruled rows: sign in (when there's no account), log out, a plain-words line, then
/// Delete account as faint text below, rare and permanent so it never competes. Development runs
/// without an account keep the device-only actions so the same rows always exist.
struct AccountSection: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  @EnvironmentObject private var subscription: GymSubscription
  let close: () -> Void
  @State private var confirmLogOut = false
  @State private var confirmDelete = false
  @State private var signingIn = false
  @State private var failed = false
  private var cloud: Bool { account.user != nil }
  var body: some View {
    SettingsLabel(store.t("Account"))
    if !cloud && !AppConfig.offline {
      Button { signingIn = true } label: { SettingRow(title: store.t("Sign in"), chevron: true) }
        .buttonStyle(.plain).pageRow().accessibilityIdentifier("settings.signin")
        .sheet(isPresented: $signingIn) { SignInSheet() }
    }
    Button { confirmLogOut = true } label: {
      SettingRow(title: store.t(cloud || AppConfig.offline ? "Log out" : "Clear this iPhone"))
    }.buttonStyle(.plain).pageRow().accessibilityIdentifier("settings.logout")
      .confirmationDialog(store.t(cloud ? "Log out of GymBlock?" : "Clear this iPhone?"), isPresented: $confirmLogOut, titleVisibility: .visible) {
        Button(store.t(cloud || AppConfig.offline ? "Log out" : "Clear")) { logOut() }.accessibilityIdentifier("settings.logout.confirm")
        Button(store.t("Cancel"), role: .cancel) {}
      } message: {
        Text(store.t(cloud ? "Your workouts stay in your account. This iPhone is cleared." : "Your workouts and splits stay on this iPhone."))
      }
      .tint(GymColor.ink)
    if cloud || AppConfig.offline {
      Button(role: .destructive) { confirmDelete = true } label: {
        Text(store.t("Delete account")).font(.app(.subheadline)).foregroundStyle(JourneyColor.tertiary)
          .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
      }.buttonStyle(.plain).padding(.top, 8).pageRow().listRowSeparator(.hidden).accessibilityIdentifier("settings.delete")
        .alert(store.t("Delete your account?"), isPresented: $confirmDelete) {
          Button(store.t("Delete account"), role: .destructive) { deleteAccount() }
            .accessibilityIdentifier("settings.delete.confirm")
          Button(store.t("Cancel"), role: .cancel) {}
        } message: {
          Text(store.t(cloud ? "This permanently deletes your account, workouts, splits, answers and settings everywhere. It can’t be undone."
                       : "This permanently deletes your workouts, splits, answers and settings. It can’t be undone."))
        }
        .alert(store.t("Could not delete the account"), isPresented: $failed) {
          Button("OK") {}
        } message: { Text(store.t("Check your connection and try again.")) }
    }
  }
  /// With an account the device copy is cleared (it comes back at the next sign-in); without one,
  /// workouts stay here and only onboarding starts again.
  private func logOut() {
    let hadCloud = cloud
    run {
      Task { @MainActor in
        await account.signOut()
        await subscription.identify(nil)
        if hadCloud { store.deleteAccount() } else { store.logOut() }
      }
    }
  }
  private func deleteAccount() {
    Task { @MainActor in
      guard await account.deleteAccount() else { failed = true; return }
      await subscription.identify(nil)
      run { store.deleteAccount() }
    }
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

/// Signing in from Settings, for a phone that was cleared or never signed in.
struct SignInSheet: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid()
        VStack(spacing: 16) {
          AccountStage()
          if let message = account.message {
            Text(message).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
          }
          AccountButtons().padding(.bottom, 8)
        }.padding(24)
      }
      .navigationTitle(store.t("Sign in")).navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } } }
      .onChange(of: account.userID) { _, id in if id != nil { dismiss() } }
    }.track(screen: "settings.signin")
  }
}

/// Where to get help and the documents, each opening its web page.
struct LegalSection: View {
  @EnvironmentObject private var store: GymStore
  var body: some View {
    SettingsLabel(store.t("Help"))
    Link(destination: AppConfig.supportURL) { SettingRow(title: store.t("Support"), external: true) }.pageRow()
    Link(destination: AppConfig.privacyURL) { SettingRow(title: store.t("Privacy Policy"), external: true) }.pageRow()
    Link(destination: AppConfig.termsURL) { SettingRow(title: store.t("Terms of Service"), external: true) }.pageRow()
  }
}

/// GymBlock Pro: what the account is on and a way to manage it in the App Store. Hidden when there
/// is nothing true to show (no subscription, or a development run), never a pretend plan.
struct SubscriptionSettingsSection: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var subscription: GymSubscription
  @State private var managing = false
  var body: some View {
    if subscription.hasAccess {
      SettingsLabel(store.t("Subscription"))
      SettingRow(title: "Gym Block Pro", value: renewal).pageRow()
      Button { managing = true } label: { SettingRow(title: store.t("Manage subscription"), chevron: true) }
        .buttonStyle(.plain).pageRow().accessibilityIdentifier("settings.manageSubscription")
        .manageSubscriptionsSheet(isPresented: $managing)
    }
  }
  private var renewal: String? {
    guard let date = subscription.expiration else { return nil }
    return store.t(subscription.willRenew ? "Renews" : "Ends") + " " + date.formatted(date: .abbreviated, time: .omitted)
  }
}
