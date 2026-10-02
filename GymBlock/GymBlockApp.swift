import SwiftUI

@main struct GymBlockApp: App {
    @StateObject private var store: GymStore
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-reset") {
            UserDefaults.standard.removeObject(forKey: GymStore.storageKey)
        }
        #endif
        let store = GymStore()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") { store.loadDemoIfEmpty() }
        #endif
        _store = StateObject(wrappedValue: store)
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(GymColor.blue)
        }
    }
}
struct RootView: View {
    @EnvironmentObject private var store: GymStore
    var body: some View {
        ZStack {
            GymColor.ground.ignoresSafeArea()
            if !store.profile.onboarded { OnboardingView() }
            else if let summary = store.summary { SummaryView(session: summary) }
            else if store.session != nil { SessionView() }
            else { HomeView() }
        }
        .foregroundStyle(GymColor.ink)
        .alert("Could not save on this device", isPresented: $store.storageError) {
            Button("Try again") { store.persist() }
        }
    }
}
