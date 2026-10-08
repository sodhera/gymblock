import SwiftUI

/// Onboarding: one question or one idea per page, on a fixed grid —
/// progress line, headline box, stage, caption, actions. See docs/ONBOARDING-V5-PLAN.md.
enum OnboardingStep: String, CaseIterable {
  case welcome, name, gender, height, weight, scrolling, phoneMinutes, reveal, days, mindA, mindB, restA, restB, logA, logB, blocking, alerts, commit, account, subscription, splits
  // Decode-only steps saved by earlier journeys.
  case body, frequency, restHabits, loggingHabits, mindMuscle, restStory, progressStory
  case duration, reps, sets, exercises, minutes, breaks, setTiming, routine, ready
  static func restored(_ profile: Profile) -> Self {
    if let id = profile.onboardingStepID, let step = Self(rawValue: id) { return step.current }
    let old: [Self] = [.welcome, .reveal, .scrolling, .scrolling, .scrolling, .reveal, .logA]
    return old[min(max(profile.onboardingStep, 0), old.count - 1)]
  }
  /// Maps removed pages onto the nearest current page; stored answers are never discarded.
  var current: Self {
    switch self {
    case .body: return .gender
    case .duration, .reps, .sets, .exercises, .routine: return .scrolling
    case .minutes, .breaks: return .phoneMinutes
    case .frequency, .restHabits, .loggingHabits, .setTiming: return .reveal
    case .mindMuscle: return .mindA
    case .restStory: return .restA
    case .progressStory, .ready: return .logA
    default: return self
    }
  }
  /// Pages whose animation must finish before Continue appears.
  var animated: Bool { [.welcome, .reveal, .days, .mindA, .mindB, .restA, .restB, .logA, .logB, .alerts].contains(self) }
  /// Pages sharing a stage keep their visual in place; only the words change.
  var stage: String {
    switch self {
    case .welcome, .scrolling: return "notify"
    case .mindA, .mindB: return "mind"
    case .restA, .restB: return "rest"
    case .logA, .logB: return "log"
    default: return rawValue
    }
  }
}

enum OnboardingRoute {
  static func steps(_ baseline: RoutineBaseline) -> [OnboardingStep] {
    var steps: [OnboardingStep] = [.name, .gender, .height, .weight, .scrolling]
    let scrolls = baseline.scrollFrequency != .no
    if scrolls { steps.append(.phoneMinutes) }
    steps.append(.reveal)
    if scrolls { steps.append(.days) }
    return steps + [.mindA, .mindB, .restA, .restB, .logA, .logB, .blocking, .alerts, .commit, .account, .subscription, .splits]
  }
}

struct OnboardingView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  @EnvironmentObject private var subscription: GymSubscription
  @EnvironmentObject private var account: Account
  /// Signing in from the welcome page: a returning account goes straight in, a new one starts the questions.
  @State private var returning = false
  @State private var draft = 2.0
  @State private var estimate = GymTimeEstimate()
  @State private var apps: Set<String> = []
  @State private var locking = false
  @State private var nameDraft = ""
  @State private var gender: String?
  @State private var heightUnit = BodyUnits.defaultMetric ? 0 : 1
  @State private var weightUnit = BodyUnits.defaultMetric ? 0 : 1
  @State private var heightCM = 175.0
  @State private var weightKG = 75.0
  @State private var covered = true
  @State private var ready = true
  /// Page changes run on one clock: everything changing fades out, the page swaps unseen, everything fades in.
  @State private var shown = true
  @State private var stageLeaving = false
  @State private var moving = false
  /// Pages slide a little in the direction of travel as they fade, so Back feels like going back.
  @State private var slide: CGFloat = 0
  @State private var pledged = 0
  @State private var committed = false
  @MainActor private static var coverShown = false
  private var baseline: RoutineBaseline { store.profile.baseline ?? RoutineBaseline() }
  private var step: OnboardingStep { OnboardingStep.restored(store.profile) }
  private var route: [OnboardingStep] { OnboardingRoute.steps(baseline) }

  var body: some View {
    ZStack {
      DotGrid()
      VStack(spacing: 0) {
        topBar.frame(height: 44).padding(.horizontal, 12)
        headline.padding(.horizontal, 28).padding(.top, 14)
          .opacity(shown ? 1 : 0).offset(x: slide)
        ZStack {
          stage.id(step.stage).transition(.identity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 24).padding(.vertical, 12)
          // A stage shared by two pages stays put; only a new stage fades and slides.
          .opacity(shown || !stageLeaving ? 1 : 0).offset(x: stageLeaving ? slide : 0)
        Text(caption.map(store.t) ?? " ").font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
          .multilineTextAlignment(.center).lineLimit(2).frame(minHeight: 20).padding(.horizontal, 32)
          .opacity(shown ? 1 : 0).offset(x: slide)
        actions.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 6)
          .opacity(shown ? 1 : 0).offset(x: slide * 0.5)
      }
      // The launch screen is the same dark stage: the first page simply rises into it.
      .opacity(covered ? 0 : 1).offset(y: covered && !reduceMotion ? 10 : 0)
    }
    .foregroundStyle(JourneyColor.text)
    .preferredColorScheme(JourneyColor.theme.scheme)
    // Safety net: Continue always appears, even if a sequence is interrupted.
    .task(id: step) { if !ready { try? await Task.sleep(for: .seconds(6)); markReady() } }
    .task(id: step == .subscription) { if step == .subscription { await subscription.load() } }
    .onChange(of: subscription.hasAccess) { _, access in if access, step == .subscription { move(.splits) } }
    .onChange(of: account.userID) { _, id in if id != nil, step == .account { signedIn() } }
    .onChange(of: step) { old, new in Analytics.leave("onboarding." + old.rawValue); Analytics.enter("onboarding." + new.rawValue, ["step": stepIndex(new)]) }
    .onAppear { Analytics.enter("onboarding." + step.rawValue, ["step": stepIndex(step)]) }
    .onDisappear { Analytics.leave("onboarding." + step.rawValue) }
    .onAppear {
      if reduceMotion || Self.coverShown { covered = false } else {
        Self.coverShown = true
        withAnimation(.easeOut(duration: 0.6)) { covered = false }
      }
      ArmFrames.shared.prepare()
      ready = reduceMotion || !step.animated
      prepare()
      store.updateProfile {
        $0.onboardingStepID = step.rawValue
        $0.onboardingVersion = 9
        if $0.focusEnabled == nil { $0.focusEnabled = false }
        if $0.language.isEmpty {
          $0.language = Locale.current.language.languageCode?.identifier == "es" ? "es" : "en"
        }
      }
    }
  }

  // MARK: Grid

  private var topBar: some View {
    ZStack {
      HStack(spacing: 8) {
        JourneyBackButton(label: store.t("Back"), action: back).disabled(locking)
        JourneyProgress(value: progress).padding(.horizontal, 8)
        Color.clear.frame(width: 36, height: 36).accessibilityHidden(true)
      }.opacity(step == .welcome ? 0 : 1).allowsHitTesting(step != .welcome)
      Wordmark().opacity(step == .welcome ? 1 : 0)
    }
  }
  private var progress: Double {
    let all = [OnboardingStep.welcome] + route
    return Double(all.firstIndex(of: step) ?? 0) / Double(max(1, all.count - 1))
  }
  private func stepIndex(_ step: OnboardingStep) -> Int { ([OnboardingStep.welcome] + route).firstIndex(of: step) ?? 0 }

  /// A box that always reserves two lines, so every page's content starts at the same height;
  /// a one-line headline sits in the middle of it rather than above a hole.
  private var headline: some View {
    ZStack(alignment: .center) {
      Text("A\nB").font(JourneyType.headline).hidden().accessibilityHidden(true)
      headlineText.id(step).transition(.identity)
    }.frame(maxWidth: .infinity)
  }
  private var headlineText: some View {
    Group {
      if step == .welcome {
        Text(store.t("Stay focused.")) + Text("\n" + store.t("Stay intentional.")).foregroundColor(JourneyColor.secondary)
      } else if let personal {
        Text(personal)
      } else {
        Text(store.t(headlineCopy))
      }
    }.font(JourneyType.headline).tracking(-0.3).multilineTextAlignment(.center)
      .lineLimit(2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
  }
  private var headlineCopy: String {
    switch step {
    case .name: return "What should we call you?"
    case .gender: return "What’s your gender?"
    case .height: return "How tall are you?"
    case .weight: return "How much do you weigh?"
    case .alerts: return "Get a buzz when rest is up."
    case .scrolling: return "Do you use your phone between sets?"
    case .phoneMinutes: return "How long on your phone, each rest?"
    case .reveal: return "Here’s your phone time."
    case .days: return daysHeadline
    case .commit: return "Commit to focus."
    case .mindA: return "Scrolling weakens your mind-muscle connection."
    case .mindB: return "Put it away. Feel every rep."
    case .restA: return "Scroll between sets.\nNever hit the pump."
    case .restB: return "Time your rests.\nHit the pump."
    case .logA: return "Memory forgets your progress."
    case .logB: return "Your log doesn’t."
    case .blocking: return "Block what distracts you."
    case .account: return "Keep your progress safe."
    case .splits: return "Set up your splits."
    default: return "Stay focused with GymBlock."
    }
  }
  /// Uses their name where it reads naturally.
  private var personal: String? {
    let name = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }
    switch step {
    case .reveal: return name + ", " + store.t("here’s your phone time.")
    case .subscription: return store.t("Stay focused,") + " " + name + "."
    case .commit: return name + ", " + store.t("commit to focus.")
    default: return nil
    }
  }
  private var daysHeadline: String {
    String(format: store.t("That’s %@ hours a year."), "\(Int(estimate.yearlyPhoneHours.rounded()))")
  }
  private var caption: String? {
    switch step {
    case .gender, .height, .weight: return "Stays on this iPhone. Never shared."
    case .alerts: return "One buzz when your rest is up. Change it anytime."
    case .reveal: return "A typical workout: 6 exercises × 3 sets, 2-minute rests."
    case .days: return "At 5 workouts a week. Your own numbers, multiplied out."
    case .commit: return "Hold the button until it fills."
    case .mindA, .mindB, .restA, .restB: return "Illustrative, not a measurement."
    case .logA, .logB: return "An example log, not your data."
    case .blocking: return "Blocking is a preview in this build: nothing is enforced yet."
    case .account: return account.message ?? "Your workouts sync to your account and come back on any iPhone."
    case .subscription: return subscription.message ?? (subscription.plans.isEmpty ? nil : "Auto-renews. Cancel anytime in iOS Settings.")
    case .splits: return store.data.workouts.isEmpty ? "Optional. You can always train freely and add splits later." : "Home lines up the next split and its last weights."
    default: return nil
    }
  }

  @ViewBuilder private var stage: some View {
    switch step {
    case .welcome, .scrolling: NotificationStage(awake: step == .scrolling, done: markReady)
    case .name: NameStage(name: $nameDraft) { if canSaveName { advance() } }
    case .gender: GenderStage(gender: gender) { value in
      withAnimation(JourneyMotion.gentle) { gender = value }
      JourneyHaptic.play(.selection, store.profile)
    }
    case .height:
      MeasureStage(values: heightUnit == 0 ? (120...220).map(Double.init) : (48...90).map(Double.init),
                   unit: heightUnit == 0 ? "cm" : "", id: "profile.height",
                   value: Binding(get: { heightUnit == 0 ? heightCM.rounded() : min(90, max(48, (heightCM / 2.54).rounded())) },
                                  set: { heightCM = heightUnit == 0 ? $0 : $0 * 2.54 }),
                   format: heightUnit == 0 ? nil : BodyUnits.feet, units: ["cm", "ft · in"], unitIndex: $heightUnit)
    case .weight:
      MeasureStage(values: weightUnit == 0 ? (30...200).map(Double.init) : (66...440).map(Double.init),
                   unit: weightUnit == 0 ? "kg" : "lb", id: "profile.weight",
                   value: Binding(get: { weightUnit == 0 ? weightKG.rounded() : min(440, max(66, (weightKG * 2.20462).rounded())) },
                                  set: { weightKG = weightUnit == 0 ? $0 : $0 / 2.20462 }),
                   units: ["kg", "lb"], unitIndex: $weightUnit)
    case .alerts: AlertStage(done: markReady)
    case .phoneMinutes:
      JourneyWheel(values: stride(from: 0.5, through: 10, by: 0.5).map { $0 }, unit: store.t("min"), id: "baseline.scrollMinutes",
                   value: $draft).frame(height: 216).frame(maxHeight: .infinity)
    case .reveal: RevealStage(estimate: estimate, done: markReady)
    case .days: DaysStage(estimate: estimate, done: markReady)
    case .mindA, .mindB: MindStage(focused: step == .mindB, done: markReady)
    case .restA, .restB: RestStage(timed: step == .restB, done: markReady)
    case .logA, .logB: LogStage(remembered: step == .logB, done: markReady)
    case .commit: CommitStage(lit: pledged)
    case .blocking: BlockStage(selected: Binding(get: { apps }, set: { apps = $0; saveApps() }), locking: locking)
    case .account: AccountStage()
    case .subscription: OfferStage(subscription: subscription)
    case .splits: SplitsStage()
    default: Color.clear
    }
  }

  // MARK: Actions — always in the thumb zone; the primary sits at the same height on every page.

  private var actions: some View {
    // Swap per page instantly so a fast tap never lands on the outgoing page's control.
    actionContent.id(step).transition(.identity)
  }
  @ViewBuilder private var actionContent: some View {
    VStack(spacing: 4) {
      switch step {
      case .scrolling:
        JourneyGlassGroup(spacing: 10) {
          VStack(spacing: 10) {
            option("Every rest", .yes); option("Sometimes", .sometimes); option("Rarely", .no)
          }
        }.padding(.bottom, 14)
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: baseline.scrollFrequency != nil, action: advance)
        Color.clear.frame(height: 44)
      case .gender:
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: gender != nil, action: advance)
        Color.clear.frame(height: 44)
      case .alerts:
        gated(JourneyButton(title: store.t("Turn on rest alerts"), id: "alerts.on", enabled: ready) {
          Task { @MainActor in
            let granted = await RestAlert.requestPermission()
            store.updateProfile { $0.restAlerts = granted }
            if step == .alerts { next() }
          }
        })
        JourneyTextButton(title: store.t("Not now"), id: "alerts.later") {
          store.updateProfile { $0.restAlerts = false }
          next()
        }
      case .name:
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: canSaveName, action: advance)
        Color.clear.frame(height: 44)
      case .welcome:
        gated(JourneyButton(title: store.t("Get started"), id: "onboarding.continue", enabled: ready) { returning = false; move(.name) })
        JourneyTextButton(title: store.t("I already have an account"), id: "welcome.signIn") { returning = true; move(.account) }
          .opacity(ready ? 1 : 0).allowsHitTesting(ready).accessibilityHidden(!ready)
      case .account:
        AccountButtons { move(.subscription) }
      case .commit:
        HoldButton(title: store.t("Hold to commit"), doneTitle: store.t("Committed"), committed: committed,
                   onProgress: { p in
                     let next = min(3, Int(p * 3 + 0.001))
                     if next != pledged { withAnimation(.spring(duration: 0.3)) { pledged = next } }
                   },
                   onComplete: commit)
        Color.clear.frame(height: 44)
      case .blocking:
        JourneyButton(title: store.t("Turn on blocking"), id: "blocking.on", enabled: !apps.isEmpty && !locking, action: turnOnBlocking)
        JourneyTextButton(title: store.t("Not now"), id: "blocking.later") {
          guard !locking else { return }
          store.updateProfile { $0.focusEnabled = false }
          next()
        }
      case .subscription:
        JourneyButton(title: subscribeTitle, id: "subscription.buy", enabled: subscription.plan != nil && !subscription.busy) {
          Task { await subscription.buy() }
        }
        #if DEBUG
          // Simulator use only: with no product configured, step into the app. Never in Release.
          if subscription.plan == nil {
            JourneyTextButton(title: "Continue without subscribing · Debug", id: "subscription.debugSkip") { move(.splits) }
          } else {
            JourneyTextButton(title: store.t("Restore purchases"), id: "subscription.restore") { Task { await subscription.restore() } }
          }
        #else
          JourneyTextButton(title: store.t("Restore purchases"), id: "subscription.restore") { Task { await subscription.restore() } }
        #endif
      case .splits:
        JourneyButton(title: store.t(store.data.workouts.isEmpty ? "Continue" : "Start training"), id: "onboarding.continue", action: finish)
        JourneyTextButton(title: store.t("Skip for now"), id: "splits.skip") { finish() }
          .opacity(store.data.workouts.isEmpty ? 1 : 0).allowsHitTesting(store.data.workouts.isEmpty)
      default:
        gated(JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: ready, action: advance))
        Color.clear.frame(height: 44)
      }
    }
  }
  private var subscribeTitle: String {
    guard let plan = subscription.plan else { return store.t("Subscribe") }
    if plan.trialDays > 0 { return String(format: store.t("Start %@-day free trial"), "\(plan.trialDays)") }
    return store.t("Subscribe") + " · " + plan.price + " / " + store.t(plan.yearly ? "year" : "month")
  }
  /// After sign-in: a returning account is already onboarded (RootView opens the app once its
  /// profile arrives); a new account carries on to the offer, or to the questions if it came from welcome.
  private func signedIn() {
    Task { @MainActor in
      await CloudSync.shared.awaitPull()
      guard step == .account, !store.profile.onboarded else { return }
      move(returning ? .name : .subscription)
    }
  }
  /// Continue holds its place and fades in once the page's scene has played.
  private func gated(_ button: JourneyButton) -> some View {
    // Hidden means hidden for VoiceOver too, so nothing can be activated before the scene ends.
    button.opacity(ready ? 1 : 0).offset(y: ready ? 0 : 8).allowsHitTesting(ready).accessibilityHidden(!ready)
      .animation(.smooth(duration: 0.5), value: ready)
  }
  private func markReady() {
    guard !ready else { return }
    withAnimation(.smooth(duration: 0.5)) { ready = true }
  }

  private func commit() {
    guard !committed else { return }
    withAnimation(JourneyMotion.gentle) { committed = true; pledged = 3 }
    store.updateProfile { $0.onboardingStoryStage = 1 }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 900))
      if step == .commit { move(.account) }
    }
  }
  private func option(_ title: String, _ answer: HabitAnswer) -> some View {
    choice(title, id: "habit.scrolling.\(answer.rawValue)", selected: baseline.scrollFrequency == answer) {
      update {
        $0.scrollFrequency = answer; $0.scrollsBetweenSets = answer != .no
        if answer == .no { $0.scrollingMinutes = 0; $0.minutesPerBreak = nil }
        else if ($0.scrollingMinutes ?? 0) <= 0 { $0.scrollingMinutes = nil }
      }
    }
  }
  /// Selecting only selects. Continue moves on — nothing jumps away mid-thought.
  private func choice(_ title: String, id: String, selected: Bool, apply: @escaping () -> Void) -> some View {
    JourneyOption(title: store.t(title), selected: selected, id: id) {
      withAnimation(JourneyMotion.gentle) { apply() }
      JourneyHaptic.play(.selection, store.profile)
    }
  }
  /// Typical starting values for the wheels.
  private func bodyDefaults(_ gender: String?) -> (height: Double, weight: Double) {
    gender == "male" ? (178, 80) : gender == "female" ? (165, 65) : (170, 72)
  }
  private var canSaveName: Bool { !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  private func prepare() {
    switch step {
    case .name: nameDraft = store.profile.name
    case .gender: gender = store.profile.gender
    case .height: heightCM = store.profile.heightCM ?? bodyDefaults(store.profile.gender).height
    case .weight:
      let p = store.profile
      weightKG = p.bodyWeightKG ?? bodyDefaults(p.gender).weight
      weightUnit = p.bodyWeightKG != nil ? (p.unit == "kg" ? 0 : 1) : heightUnit
    case .phoneMinutes:
      let saved = baseline.scrollingMinutes ?? 0
      draft = saved > 0 ? min(10, (saved * 2).rounded() / 2) : (baseline.scrollFrequency == .sometimes ? 1 : 2)
    case .reveal, .days: estimate = GymTimeEstimate(baseline)
    case .commit: pledged = 0; committed = false
    case .blocking:
      var chosen = Set(store.profile.blockedApps)
      if chosen == ["Instagram", "TikTok"] && baseline.scrollFrequency != .no { chosen.insert("YouTube") }
      apps = chosen
    default: break
    }
  }
  private func advance() {
    if step == .name {
      guard canSaveName else { return }
      let name = String(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
      store.updateProfile { $0.name = name }
      dismissKeyboard()
    }
    if step == .gender { guard gender != nil else { return }; store.updateProfile { $0.gender = gender } }
    if step == .height { store.updateProfile { $0.heightCM = heightCM.rounded() } }
    if step == .weight {
      store.updateProfile { $0.bodyWeightKG = (weightKG * 10).rounded() / 10; $0.unit = weightUnit == 0 ? "kg" : "lb" }
    }
    if step == .phoneMinutes { update { $0.scrollingMinutes = draft; $0.minutesPerBreak = nil } }
    next()
  }
  private func next() {
    if let index = route.firstIndex(of: step), index + 1 < route.count { move(route[index + 1]) }
  }
  private func back() {
    guard !locking else { return }
    if step == .name { dismissKeyboard(); move(.welcome); return }
    if step == .account && returning { move(.welcome); return }
    if let index = route.firstIndex(of: step), index > 0 { move(route[index - 1]) }
  }
  private func saveApps() {
    let ordered = BlockedApp.all.map(\.name).filter(apps.contains)
    store.updateProfile { $0.blockedApps = ordered }
  }
  private func turnOnBlocking() {
    guard !locking, !apps.isEmpty else { return }
    saveApps()
    store.updateProfile { $0.focusEnabled = true }
    locking = true
    let wait = reduceMotion ? 0.25 : 0.14 * Double(apps.count) + 0.7
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(wait))
      JourneyHaptic.play(.success, store.profile)
      if step == .blocking { next() }
      locking = false
    }
  }
  private func move(_ next: OnboardingStep) {
    guard !moving else { return }
    moving = true
    JourneyHaptic.play(.soft, store.profile, intensity: 0.55)
    let out = reduceMotion ? 0.1 : 0.18
    stageLeaving = next.stage != step.stage
    let all = [OnboardingStep.welcome] + route
    let forward = (all.firstIndex(of: next) ?? 0) >= (all.firstIndex(of: step) ?? 0)
    let travel: CGFloat = reduceMotion ? 0 : 18
    withAnimation(.easeIn(duration: out)) { shown = false; slide = forward ? -travel : travel }
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(out))
      // Swap while nothing changing is visible. Views keep their own `.animation(value:)` morphs.
      withTransaction(Transaction(animation: nil)) {
        ready = reduceMotion || !next.animated
        store.updateProfile { $0.onboardingStepID = next.rawValue; $0.onboardingStoryStage = 0 }
        prepare()
        slide = forward ? travel : -travel
      }
      withAnimation(.spring(duration: reduceMotion ? 0.15 : 0.5, bounce: 0.1)) { shown = true; slide = 0 }
      moving = false
    }
  }
  private func update(_ body: (inout RoutineBaseline) -> Void) {
    store.updateProfile {
      var baseline = $0.baseline ?? RoutineBaseline()
      body(&baseline); baseline.goalMinutesPerBreak = nil; baseline.reductionGoal = nil
      $0.baseline = baseline; $0.onboardingPreviewTarget = nil
    }
  }
  /// The end of onboarding: into the app, with the first split (if any) lined up on Home.
  private func finish() {
    JourneyHaptic.play(.success, store.profile)
    store.updateProfile {
      if $0.preferredSplitID == nil { $0.preferredSplitID = store.data.workouts.first?.id }
      $0.onboarded = true; $0.onboardingStepID = OnboardingStep.splits.rawValue
    }
  }
}
