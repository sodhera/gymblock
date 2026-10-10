import StoreKit
import SwiftUI

/// Gender, height and weight from onboarding, editable at any time.
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
      Text(store.t("Synced to your account.")).font(.footnote).foregroundStyle(GymColor.dim)
    }.gymPage().navigationTitle(store.t("Body")).navigationBarTitleDisplayMode(.inline)
  }
}

/// The account: who is signed in, the subscription, log out and delete. Development runs without an
/// account keep the device-only actions so the same rows always exist.
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
    SettingsSection(store.t("Account")) {
      SettingsGroup {
        if !cloud && !AppConfig.offline {
          Button { signingIn = true } label: {
            SettingsRow(icon: "person.crop.circle.badge.plus", title: store.t("Sign in"), chevron: true)
          }.buttonStyle(.plain).accessibilityIdentifier("settings.signin")
          SettingsDivider()
        }
        Button { confirmLogOut = true } label: {
          SettingsRow(icon: "rectangle.portrait.and.arrow.right", tint: JourneyColor.secondary,
                      title: store.t(cloud || AppConfig.offline ? "Log out" : "Clear this iPhone"), titleColor: JourneyColor.secondary)
        }.buttonStyle(.plain).accessibilityIdentifier("settings.logout")
      }
      Text(store.t(cloud ? "Log out keeps your account. Delete removes it and everything synced to it."
                   : AppConfig.offline ? "Development run: both act on this iPhone only."
                   : "Sign in to back up your workouts and keep them on any iPhone."))
        .font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
        .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
      // Rare and permanent, so it sits outside the card as faint text that never competes.
      if cloud || AppConfig.offline {
        Button(role: .destructive) { confirmDelete = true } label: {
          Text(store.t("Delete account")).font(.subheadline).foregroundStyle(JourneyColor.tertiary)
            .frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.plain).accessibilityIdentifier("settings.delete").padding(.top, 4)
      }
    }
    .confirmationDialog(store.t(cloud ? "Log out of GymBlock?" : "Clear this iPhone?"), isPresented: $confirmLogOut, titleVisibility: .visible) {
      Button(store.t(cloud || AppConfig.offline ? "Log out" : "Clear")) { logOut() }.accessibilityIdentifier("settings.logout.confirm")
      Button(store.t("Cancel"), role: .cancel) {}
    } message: {
      Text(store.t(cloud ? "Your workouts stay in your account. This iPhone is cleared." : "Your workouts and splits stay on this iPhone."))
    }
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
    .sheet(isPresented: $signingIn) { SignInSheet() }
    // Outermost, so the dialogs inherit it: only the destructive choice reads red.
    .tint(GymColor.ink)
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

/// The documents and where to get help, then the version.
struct LegalSection: View {
  @EnvironmentObject private var store: GymStore
  var body: some View {
    SettingsSection(store.t("Help")) {
      SettingsGroup {
        Link(destination: AppConfig.supportURL) { SettingsRow(icon: "questionmark.circle.fill", title: store.t("Support"), chevron: true) }
        SettingsDivider()
        Link(destination: AppConfig.privacyURL) { SettingsRow(icon: "hand.raised.fill", title: store.t("Privacy Policy"), chevron: true) }
        SettingsDivider()
        Link(destination: AppConfig.termsURL) { SettingsRow(icon: "doc.text.fill", title: store.t("Terms of Service"), chevron: true) }
      }
    }
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
      SettingsSection(store.t("Subscription")) {
        SettingsGroup {
          SettingsRow(icon: "crown.fill", title: "Gym Block Pro", value: renewal)
          SettingsDivider()
          Button { managing = true } label: {
            SettingsRow(icon: "creditcard.fill", tint: JourneyColor.secondary, title: store.t("Manage subscription"), chevron: true)
          }.buttonStyle(.plain).accessibilityIdentifier("settings.manageSubscription")
        }
      }
      .manageSubscriptionsSheet(isPresented: $managing)
    }
  }
  private var renewal: String? {
    guard let date = subscription.expiration else { return nil }
    return store.t(subscription.willRenew ? "Renews" : "Ends") + " " + date.formatted(date: .abbreviated, time: .omitted)
  }
}
