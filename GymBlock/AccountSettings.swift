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
    Section {
      if cloud {
        HStack {
          Text(store.t("Signed in"))
          Spacer()
          Text(account.email ?? account.displayName ?? "—").foregroundStyle(JourneyColor.secondary).lineLimit(1).truncationMode(.middle)
        }.accessibilityIdentifier("settings.account")
        if subscription.hasAccess {
          HStack {
            Text("GymBlock Pro")
            Spacer()
            if let date = subscription.expiration {
              Text(store.t(subscription.willRenew ? "Renews" : "Expires") + " " + date.formatted(date: .abbreviated, time: .omitted))
                .foregroundStyle(JourneyColor.secondary)
            }
          }
        }
      } else if !AppConfig.offline {
        Button(store.t("Sign in")) { signingIn = true }.foregroundStyle(GymColor.ink).accessibilityIdentifier("settings.signin")
      }
      Button(store.t(cloud || AppConfig.offline ? "Log out" : "Clear this iPhone")) { confirmLogOut = true }
        .foregroundStyle(GymColor.ink).accessibilityIdentifier("settings.logout")
      if cloud || AppConfig.offline {
        Button(store.t("Delete account"), role: .destructive) { confirmDelete = true }
          .foregroundStyle(Color(uiColor: .systemRed)).accessibilityIdentifier("settings.delete")
      }
    } header: { Text(store.t("Account")) } footer: {
      Text(store.t(cloud ? "Log out keeps your account. Delete removes it and everything synced to it."
                   : AppConfig.offline ? "Development run: both act on this iPhone only."
                   : "Sign in to back up your workouts and keep them on any iPhone.")).font(.footnote)
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

/// The documents and where to get help.
struct LegalSection: View {
  @EnvironmentObject private var store: GymStore
  var body: some View {
    Section {
      Link(store.t("Privacy Policy"), destination: AppConfig.privacyURL).foregroundStyle(GymColor.ink)
      Link(store.t("Terms of Service"), destination: AppConfig.termsURL).foregroundStyle(GymColor.ink)
      Link(store.t("Support"), destination: AppConfig.supportURL).foregroundStyle(GymColor.ink)
    } header: { Text(store.t("Legal")) } footer: {
      Text("GymBlock " + Analytics.appVersion + " (" + Analytics.build + ")").font(.footnote)
    }
  }
}
