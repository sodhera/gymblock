import SwiftUI

@main struct GymBlockApp: App {
  @StateObject private var store: GymStore
  @StateObject private var account = Account()
  @StateObject private var subscription = GymSubscription()
  @Environment(\.scenePhase) private var scenePhase
  init() {
    // No navigation bar appearance override beyond the typeface: iOS 26 draws its own Liquid Glass bar.
    AppFont.styleBars()
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
          if b.trainingDays == nil { b.trainingDays = 4 }
          $0.baseline = b
        }
      }
      // Development only: open a sample Push workout in one state (`-workoutStage rest`).
      if let stage = UserDefaults.standard.string(forKey: "workoutStage") { store.debugWorkout(stage) }
    #endif
    GymStore.live = store
    // The widgets, now: the development launches above saved before `live` was set.
    WidgetSync.sync(store)
    WidgetSync.flush()
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
      #if DEBUG
        // Development only: every widget state at its true size instead of the app (`-widgetPreview lock`).
        if WidgetPreviewScreen.requested { WidgetPreviewScreen() } else { root }
      #else
        root
      #endif
    }
    .onChange(of: scenePhase) { _, phase in
      Analytics.scene(phase)
      if phase == .active {
        AppBlocking.shared.refresh()
        Task { await CloudSync.shared.push() }
        // The snapshot's week and six weeks of days move with the date, with nothing saved.
        WidgetSync.sync(store)
      }
      // Suspended next: a write still waiting out its second would never land.
      if phase == .background { WidgetSync.flush() }
    }
  }
  private var root: some View {
    RootView().environmentObject(store).environmentObject(account).environmentObject(subscription)
      .tint(GymColor.ink).foregroundStyle(GymColor.ink)
      // Widget and control routes by host; the sign-in callback (gymblock://auth/callback) isn't one.
      .onOpenURL { url in
        if AppRoute(url: url) != nil { AppRouter.shared.openURL(url) } else { account.handle(url) }
      }
      .task { wire() }
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
  /// The lock animation plays once per launch before anything else appears.
  @State private var splashDone = false
  /// System, Light or Dark (Settings → Appearance), kept on this iPhone.
  @AppStorage(Appearance.key) private var appearance = Appearance.system.rawValue
  /// The app follows the appearance; onboarding, sign-in and the offer stay on paper, as drawn.
  private var colorScheme: ColorScheme? {
    switch shown {
    case .app, .launch: return Appearance(rawValue: appearance)?.colorScheme ?? nil
    default: return .light
    }
  }

  enum Screen: Equatable { case launch, onboarding, signIn, notice(Account.Notice), paywall, app }

  /// What's built under the splash: Home, when that's where this launch is going, so the splash lifts
  /// off a page that's already drawn instead of stalling while it builds. Past the splash, the screen.
  private var base: Screen {
    guard shown == .launch else { return shown }
    return store.profile.onboarded && account.notice == nil && !needsOffer ? .app : .launch
  }

  private var screen: Screen {
    if !splashDone { return .launch }
    if !launched && !waitExpired && unanswered { return .launch }
    // A sign-in that went somewhere unexpected is said before anything else moves on.
    if let notice = account.notice { return .notice(notice) }
    if store.profile.onboarded { return needsOffer ? .paywall : .app }
    if atOffer { return passedOffer ? .onboarding : .paywall }
    if signingIn { return .signIn }
    return .onboarding
  }
  /// What the launch hold waits on: the account, then a signed-in account's entitlement.
  private var unanswered: Bool {
    if AppConfig.offline { return false }
    if account.state == .loading { return true }
    // A subscriber's entitlement is cached, so this is normally instant; it keeps the offer from flashing.
    return store.profile.onboarded && account.state == .signedIn && subscription.configured && !subscription.resolved
  }
  /// The app, with nothing left that could put the offer wall over it (AppRouter.settled). The hold
  /// gives up after 4 seconds, so the app can show while this is still false.
  private var settled: Bool { screen == .app && !unanswered }
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
        switch base {
        case .launch: Color.clear
        case .onboarding: OnboardingView(onSignIn: openSignIn).transition(.opacity)
        case .signIn: SignInView(back: { signingIn = false; account.message = nil }, signedIn: signedIn).transition(.opacity)
        case .notice(let notice): AccountNoticeView(notice: notice, primary: { noticePrimary(notice) },
                                                    secondary: notice == .notFound ? retrySignIn : nil).transition(.opacity)
        case .paywall: PaywallView(subscription: subscription) { skippedOffer = true }.transition(.opacity)
        case .app: GymNavigationView().transition(.opacity)
        }
      }
      .opacity(visible ? 1 : 0)
      // The splash lies over the page it leads to; the lock tucks away, then the paper lifts off.
      if shown == .launch {
        LaunchView { splashDone = true }.transition(.opacity).zIndex(1)
      }
    }
    .preferredColorScheme(colorScheme)
    .overlay {
      #if DEBUG
        if let app = StoreShots.shieldApp { ShieldPreview(app: app) }
      #endif
    }
    .task(id: screen) {
      if screen != .launch { launched = true }
      guard screen != shown else { return }
      // Out of the splash: Home is already built under it (`base`), so the paper just lifts off; any
      // other page fades in as it does. No dip to an empty screen, no stall.
      if shown == .launch, !reduceMotion {
        withAnimation(.easeOut(duration: 0.3)) { shown = screen }
        return
      }
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
    // Widget and control routes act only on the app, once the splash has lifted; onboarding, sign-in,
    // notices and the offer wall drop them.
    .onChange(of: shown, initial: true) { _, s in AppRouter.shared.screen = routerScreen(s) }
    // The control's start also waits until the offer wall can't follow.
    .onChange(of: settled, initial: true) { _, s in AppRouter.shared.settled = s }
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

  /// `shown` is `.app` once the splash has lifted.
  private func routerScreen(_ s: Screen) -> AppRouter.Screen {
    switch s {
    case .launch: return .launch
    case .app: return .app
    default: return .other
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

/// The app's appearance (11 Oct 2026): follow the system, or always light or dark.
enum Appearance: String, CaseIterable {
  case system, light, dark
  static let key = "gymblock.appearance"
  var colorScheme: ColorScheme? { self == .light ? .light : self == .dark ? .dark : nil }
  var title: String { self == .system ? "System" : self == .light ? "Light" : "Dark" }
}
