import SwiftUI

/// Settings: kicker-titled glass groups of rows that name things, never
/// explain them. Order reads who you are → how you train → what locks →
/// what you're on → account exits.
struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(ScreenTimeController.self) private var screenTime
    @Environment(\.dismiss) private var dismiss
    @State private var renaming = false
    @State private var nameDraft = ""
    @State private var picking = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var deleteText = ""
    @State private var deleteError: String?
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GBSpace.xl) {
                    profileGroup
                    trainingGroup
                    blockingGroup
                    subscriptionGroup
                    accountGroup
                    Text("GymBlock \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(GBFont.body(12))
                        .foregroundStyle(GBColor.fog)
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.vertical, GBSpace.md)
            }
            .paperBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
            .sheet(isPresented: $picking) { BlockedAppsPicker() }
            .alert("Your name", isPresented: $renaming) {
                TextField("Name", text: $nameDraft)
                Button("Save") {
                    store.profile.name = nameDraft.trimmingCharacters(in: .whitespaces)
                    let target = store.profile.weeklyTarget
                    Task { await store.friendsService.updateProfile(displayName: store.profile.name, weeklyTarget: target) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Sign out?", isPresented: $confirmSignOut) {
                Button("Sign out", role: .destructive) {
                    dismiss()
                    Task { await store.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your workouts stay on this phone.")
            }
            .alert("Delete your account?", isPresented: $confirmDelete) {
                TextField("Type delete", text: $deleteText)
                Button("Delete forever", role: .destructive) {
                    Task {
                        do {
                            try await store.deleteAccount()
                            dismiss()
                        } catch {
                            deleteError = (error as? AuthError)?.message ?? error.localizedDescription
                        }
                    }
                }
                .disabled(deleteText.lowercased() != "delete")
                Button("Cancel", role: .cancel) { deleteText = "" }
            } message: {
                Text("This removes your account, workouts, friends and records. It can't be undone. Type “delete” to confirm.")
            }
            .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    // MARK: Groups

    private var profileGroup: some View {
        GlassGroup(title: "Profile") {
            GlassRow(icon: "person.fill", title: "Name", action: {
                nameDraft = store.profile.name
                renaming = true
            }) {
                Text(store.profile.name.isEmpty ? "Add" : store.profile.name)
            }
            if let username = store.myPublicProfile?.username {
                GlassRow(icon: "at", title: "Username") { Text(username) }
            }
        }
    }

    private var weeklyTargetBinding: Binding<Int> {
        Binding(
            get: { store.profile.weeklyTarget },
            set: { value in
                store.profile.weeklyTarget = value
                let name = store.profile.name
                Task { await store.friendsService.updateProfile(displayName: name, weeklyTarget: value) }
            }
        )
    }

    private var trainingGroup: some View {
        @Bindable var store = store
        return GlassGroup(title: "Training") {
            GlassRow(icon: "calendar", iconTint: GBColor.orange, title: "Weekly target") {
                MiniStepper(label: "", value: weeklyTargetBinding, range: 1...7)
            }
            GlassRow(icon: "scalemass", title: "Units") {
                Picker("Units", selection: $store.profile.unit) {
                    ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            GlassRow(icon: "timer", title: "Default rest") {
                Menu(Format.rest(store.profile.defaultRestSeconds)) {
                    ForEach([0, 60, 90, 120, 150, 180, 240], id: \.self) { s in
                        Button(Format.rest(s)) { store.profile.defaultRestSeconds = s }
                    }
                }
                .foregroundStyle(GBColor.ink)
            }
            GlassRow(icon: "circle.lefthalf.filled", title: "Appearance") {
                Menu(appearance.title) {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                }
                .foregroundStyle(GBColor.ink)
            }
            GlassRow(icon: "person.2", title: "Share workouts") {
                Toggle("", isOn: $store.profile.shareWorkoutsByDefault).labelsHidden().tint(GBColor.orange)
            }
        }
    }

    @ViewBuilder
    private var blockingGroup: some View {
        @Bindable var store = store
        GlassGroup(title: "Blocking") {
            GlassRow(icon: "lock.fill", iconTint: GBColor.orange, title: "Lock apps in workouts") {
                Toggle("", isOn: $store.profile.blockingEnabled).labelsHidden().tint(GBColor.orange)
            }
            GlassRow(icon: "square.grid.2x2", title: "Apps", action: openPicker) {
                Text(blockedValue)
            }
        }
        .disabled(store.activeWorkout != nil)
        if store.activeWorkout != nil {
            Text("Blocking settings unlock when your workout ends.")
                .font(GBFont.body(13))
                .foregroundStyle(GBColor.steel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, -GBSpace.md)
                .padding(.horizontal, GBSpace.xs)
        }
    }

    @ViewBuilder
    private var subscriptionGroup: some View {
        if let status = store.subscriptionStatus {
            GlassGroup(title: "Subscription") {
                GlassRow(icon: "star.fill", iconTint: GBColor.orange, title: tierTitle(status)) {
                    Text(renewalText(status))
                        .foregroundStyle(status.willRenew ? GBColor.steel : GBColor.orange)
                }
                GlassRow(icon: "creditcard", title: "Manage subscription", action: {
                    Task { await store.subscriptions.manageSubscriptions() }
                })
            }
        }
    }

    @ViewBuilder
    private var accountGroup: some View {
        if store.account != nil {
            GlassGroup(title: "Account") {
                if let email = store.account?.email {
                    GlassRow(icon: "envelope", title: "Email") {
                        Text(email).lineLimit(1).truncationMode(.middle)
                    }
                }
                GlassRow(icon: "rectangle.portrait.and.arrow.right", iconTint: GBColor.steel, title: "Sign out", action: {
                    confirmSignOut = true
                })
            }
            Button("Delete account") { confirmDelete = true }
                .buttonStyle(QuietButtonStyle(color: GBColor.fog))
                .font(GBFont.body(14))
        }
    }

    private var blockedValue: String {
        if !screenTime.isSupported { return "Needs iPhone" }
        if screenTime.state != .approved { return "Allow" }
        return screenTime.selectionSummary
    }

    private func openPicker() {
        Task {
            if screenTime.state != .approved { await screenTime.requestAuthorization() }
            if screenTime.state == .approved { picking = true }
        }
    }

    private func tierTitle(_ s: SubscriptionStatus) -> String {
        switch s.tier {
        case .trial: "Free trial"
        case .pro: "GymBlock Pro"
        case .expired: "Not subscribed"
        }
    }

    private func renewalText(_ s: SubscriptionStatus) -> String {
        guard let date = s.expiration else { return "" }
        let d = date.formatted(.dateTime.month(.abbreviated).day())
        return s.willRenew ? "Renews \(d)" : "Ends \(d)"
    }
}
