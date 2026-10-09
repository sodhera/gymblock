import SwiftUI

@main struct GymBlockApp: App {
  @StateObject private var store: GymStore
  @StateObject private var account = Account()
  @StateObject private var subscription = GymSubscription()
  @Environment(\.scenePhase) private var scenePhase
  init() {
    // No navigation bar appearance override: iOS 26 draws its own Liquid Glass bar and toolbar items.
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--ui-reset") {
        UserDefaults.standard.removeObject(forKey: GymStore.storageKey)
      }
    #endif
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--ui-report-accessibility") {
        NSLog(
          "GymBlock accessibility: motion=\(UIAccessibility.isReduceMotionEnabled), transparency=\(UIAccessibility.isReduceTransparencyEnabled)"
        )
      }
    #endif
    let store = GymStore()
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--demo") { store.loadDemoIfEmpty() }
      // Development only: re-enter the app without the paywall (absent from Release builds).
      if ProcessInfo.processInfo.arguments.contains("--skip-onboarding") { store.updateProfile { $0.onboarded = true } }
      // Development only: open onboarding on one page with sample answers (`-journeyStep reveal`).
      if let step = UserDefaults.standard.string(forKey: "journeyStep") {
        store.updateProfile {
          $0.onboarded = false; $0.onboardingStepID = step; $0.name = "Sirish"; $0.focusEnabled = true
          var b = $0.baseline ?? RoutineBaseline()
          b.scrollFrequency = .yes; b.scrollsBetweenSets = true; b.scrollingMinutes = 2
          $0.baseline = b
        }
      }
      // Development only: open a sample Push workout in one state (`-workoutStage rest`).
      if let stage = UserDefaults.standard.string(forKey: "workoutStage") { store.debugWorkout(stage) }
    #endif
    GymStore.live = store
    // Lifts a shield the last run left up if no workout is running any more.
    AppBlocking.shared.sync(store)
    _store = StateObject(wrappedValue: store)
    CloudSync.shared.attach(store)
    Analytics.launched()
    // Onboarding's arm illustration is pre-rendered in the background from launch.
    if !store.profile.onboarded { ArmFrames.shared.prepare() }
  }
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(store).environmentObject(account).environmentObject(subscription)
        .tint(GymColor.ink).foregroundStyle(GymColor.ink)
        .preferredColorScheme(JourneyColor.theme.scheme)
        .onOpenURL { account.handle($0) }
        .task { wire() }
    }
    .onChange(of: scenePhase) { _, phase in
      Analytics.scene(phase)
      if phase == .active {
        AppBlocking.shared.refresh()
        Task { await CloudSync.shared.push() }
      }
    }
  }
  /// The account drives everything that is per user: sync, purchases and analytics identity.
  private func wire() {
    account.onUserChange = { user in
      Analytics.identify(user?.id)
      CloudSync.shared.setUser(user?.id)
      Task { await subscription.identify(user?.id) }
    }
    subscription.onEntitlement = { CloudSync.shared.snapshot($0) }
    subscription.configure()
    account.start()
  }
}
struct RootView: View {
  @EnvironmentObject private var store: GymStore
  var body: some View {
    ZStack {
      GymColor.ground.ignoresSafeArea()
      if !store.profile.onboarded {
        OnboardingView()
      } else {
        GymNavigationView()
      }
    }
    .alert("Could not save on this device", isPresented: $store.storageError) {
      Button("Try again") { store.persist() }
    }
  }
}
