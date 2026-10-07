import SwiftUI

@main struct GymBlockApp: App {
  @StateObject private var store: GymStore
  init() {
    let navigation = UINavigationBarAppearance()
    navigation.configureWithTransparentBackground()
    navigation.titleTextAttributes = [
      .font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: UIColor(GymColor.ink),
    ]
    navigation.largeTitleTextAttributes = [
      .font: UIFont.systemFont(ofSize: 34, weight: .bold), .foregroundColor: UIColor(GymColor.ink),
    ]
    UINavigationBar.appearance().standardAppearance = navigation
    UINavigationBar.appearance().scrollEdgeAppearance = navigation

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
    _store = StateObject(wrappedValue: store)
    // Onboarding's arm illustration is pre-rendered in the background from launch.
    if !store.profile.onboarded { ArmFrames.shared.prepare() }
  }
  var body: some Scene {
    WindowGroup {
      // One dark ember look everywhere, as in onboarding.
      RootView().environmentObject(store).tint(GymColor.ink).foregroundStyle(GymColor.ink)
        .preferredColorScheme(.dark)
    }
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
