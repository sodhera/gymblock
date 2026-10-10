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
/// One switch decides the screen, from state alone: the launch hold, onboarding (welcome and the
/// questions, ending in sign-up), the standalone sign-in, an account notice, the offer, the app.
/// Screens fade out, swap unseen, and fade in, so two are never on screen at once.
struct RootView: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  @EnvironmentObject private var subscription: GymSubscription
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  /// "I already have an account" was tapped on the welcome page.
  @State private var signingIn = false
  /// The Debug-only skip on an offer with no product configured, for this run.
  @State private var skippedOffer = false
  /// The launch hold is capped, so no network can't keep anyone on it.
  @State private var waitExpired = false
  @State private var launched = false
  @State private var shown: Screen = .launch
  @State private var visible = true

  enum Screen: Equatable { case launch, onboarding, signIn, notice(Account.Notice), paywall, app }

  private var screen: Screen {
    if !launched && !waitExpired && !AppConfig.offline {
      if account.state == .loading { return .launch }
      // A subscriber's entitlement is cached, so this is normally instant; it keeps the offer from flashing.
      if store.profile.onboarded && account.state == .signedIn && subscription.configured && !subscription.resolved { return .launch }
    }
    // A sign-in that went somewhere unexpected is said before anything else moves on.
    if let notice = account.notice { return .notice(notice) }
    if store.profile.onboarded { return needsOffer ? .paywall : .app }
    if atOffer { return passedOffer ? .onboarding : .paywall }
    if signingIn { return .signIn }
    return .onboarding
  }
  /// Onboarding has reached the offer (after the account step, before splits).
  private var atOffer: Bool { !store.profile.onboarded && OnboardingStep.restored(store.profile) == .subscription }
  private var passedOffer: Bool { subscription.hasAccess || skippedOffer }
  /// An onboarded account whose entitlement has resolved without Pro. Signed-out and offline
  /// phones never see it: the iPhone copy keeps working without the network.
  private var needsOffer: Bool {
    account.state == .signedIn && subscription.configured && subscription.resolved && !passedOffer
  }

  var body: some View {
    ZStack {
      GymColor.ground.ignoresSafeArea()
      Group {
        switch shown {
        case .launch: LaunchView()
        case .onboarding: OnboardingView(onSignIn: openSignIn)
        case .signIn: SignInView(back: { signingIn = false; account.message = nil }, signedIn: signedIn)
        case .notice(let notice): AccountNoticeView(notice: notice, primary: { noticePrimary(notice) },
                                                    secondary: notice == .notFound ? retrySignIn : nil)
        case .paywall: PaywallView(subscription: subscription) { skippedOffer = true }
        case .app: GymNavigationView()
        }
      }
      .transition(.identity)
      .opacity(visible ? 1 : 0)
    }
    .task(id: screen) {
      if screen != .launch { launched = true }
      guard screen != shown else { return }
      guard !reduceMotion, shown != .launch || screen != .onboarding else { shown = screen; return }
      withAnimation(.easeIn(duration: 0.15)) { visible = false }
      try? await Task.sleep(for: .seconds(0.15))
      shown = screen
      withAnimation(.easeOut(duration: 0.3)) { visible = true }
    }
    .task {
      try? await Task.sleep(for: .seconds(4))
      waitExpired = true
    }
    // Past the offer: onboarding carries on with splits.
    .onChange(of: passedOffer) { _, _ in advancePastOffer() }
    .onChange(of: atOffer) { _, _ in advancePastOffer() }
    .onAppear {
      advancePastOffer()
      #if DEBUG
        // Development only: open an account notice, which otherwise needs a real second account (`-accountNotice notFound`).
        switch UserDefaults.standard.string(forKey: "accountNotice") {
        case "existing": account.notice = .existingAccount
        case "notFound": account.notice = .notFound
        default: break
        }
      #endif
    }
    .alert("Could not save on this device", isPresented: $store.storageError) {
      Button("Try again") { store.persist() }
    }
  }

  private func advancePastOffer() {
    guard atOffer, passedOffer else { return }
    store.updateProfile { $0.onboardingStepID = OnboardingStep.splits.rawValue }
  }
  private func openSignIn() {
    account.message = nil
    signingIn = true
  }
  /// After the standalone sign-in: an account that finished onboarding opens (its profile has
  /// arrived); one that stopped before paying resumes at the offer; none at all is a notice.
  private func signedIn(_ found: CloudSync.Found) {
    switch found {
    case .profile(onboarded: true): signingIn = false
    case .profile(onboarded: false):
      store.updateProfile { $0.onboardingStepID = OnboardingStep.subscription.rawValue }
      signingIn = false
    case .none, .failed: break
    }
  }
  private func noticePrimary(_ notice: Account.Notice) {
    switch notice {
    case .existingAccount: account.notice = nil
    case .notFound:
      // Sign up instead: out of the empty account, straight into the questions.
      Task { @MainActor in
        await account.signOut()
        signingIn = false
        store.updateProfile { $0.onboardingStepID = OnboardingStep.name.rawValue }
      }
    }
  }
  private func retrySignIn() {
    Task { @MainActor in
      await account.signOut()
      signingIn = true
    }
  }
}
