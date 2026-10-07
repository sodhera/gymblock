import SwiftUI

/// Onboarding: one question or one idea per page, on a fixed grid —
/// progress line, headline box, stage, caption, actions. See docs/ONBOARDING-V5-PLAN.md.
enum OnboardingStep: String, CaseIterable {
  case welcome, name, body, scrolling, phoneMinutes, reveal, days, mindA, mindB, restA, restB, logA, logB, blocking, alerts, commit, subscription
  // Decode-only steps saved by earlier journeys.
  case gender, frequency, restHabits, loggingHabits, mindMuscle, restStory, progressStory
  case duration, reps, sets, exercises, minutes, breaks, setTiming, routine, ready
  static func restored(_ profile: Profile) -> Self {
    if let id = profile.onboardingStepID, let step = Self(rawValue: id) { return step.current }
    let old: [Self] = [.welcome, .reveal, .scrolling, .scrolling, .scrolling, .reveal, .logA]
    return old[min(max(profile.onboardingStep, 0), old.count - 1)]
  }
  /// Maps removed pages onto the nearest current page; stored answers are never discarded.
  var current: Self {
    switch self {
    case .gender: return .body
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
    var steps: [OnboardingStep] = [.name, .body, .scrolling]
    let scrolls = baseline.scrollFrequency != .no
    if scrolls { steps.append(.phoneMinutes) }
    steps.append(.reveal)
    if scrolls { steps.append(.days) }
    return steps + [.mindA, .mindB, .restA, .restB, .logA, .logB, .blocking, .alerts, .commit, .subscription]
  }
}

struct OnboardingView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  @StateObject private var subscription = GymSubscription()
  @State private var draft = 2.0
  @State private var estimate = GymTimeEstimate()
  @State private var apps: Set<String> = []
  @State private var locking = false
  @State private var answering = false
  @State private var nameDraft = ""
  @State private var metric = BodyUnits.defaultMetric
  @State private var heightCM = 175.0
  @State private var gender: String?
  @State private var bodyTouched = false
  @State private var weightKG = 75.0
  @State private var covered = true
  @State private var ready = true
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
        headline.padding(.horizontal, 28).padding(.top, 18)
        ZStack {
          stage.id(step.stage).transition(.opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.97)))
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.horizontal, 24).padding(.vertical, 16)
        Text(caption.map(store.t) ?? " ").font(.caption2).foregroundStyle(JourneyColor.tertiary)
          .multilineTextAlignment(.center).lineLimit(2).frame(minHeight: 16).padding(.horizontal, 32)
          .id("caption." + step.stage).transition(.opacity)
        actions.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 6)
      }
    }
    .foregroundStyle(JourneyColor.text)
    // The launch screen is white: fade from it once, then the cover leaves the hierarchy entirely.
    .overlay { if covered { Color.white.ignoresSafeArea().allowsHitTesting(false).transition(.opacity) } }
    .preferredColorScheme(.dark)
    // Safety net: Continue always appears, even if a sequence is interrupted.
    .task(id: step) { if !ready { try? await Task.sleep(for: .seconds(6)); markReady() } }
    .task(id: step == .subscription) { if step == .subscription { await subscription.load() } }
    .onChange(of: subscription.hasAccess) { _, access in if access { finish() } }
    .onChange(of: estimate) { _, value in update { value.write(into: &$0) } }
    .onAppear {
      if reduceMotion || Self.coverShown { covered = false } else {
        Self.coverShown = true
        withAnimation(.easeOut(duration: 0.35)) { covered = false }
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
    HStack(spacing: 8) {
      Button(action: back) {
        Image(systemName: "chevron.left").font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
          .frame(width: 44, height: 44).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel(store.t("Back")).accessibilityIdentifier("onboarding.back")
        .disabled(locking)
      JourneyProgress(value: progress).padding(.horizontal, 6)
      Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
    }.opacity(step == .welcome ? 0 : 1).allowsHitTesting(step != .welcome)
  }
  private var progress: Double {
    let all = [OnboardingStep.welcome] + route
    return Double(all.firstIndex(of: step) ?? 0) / Double(max(1, all.count - 1))
  }

  /// A box that always reserves two lines, so every page's content starts at the same height.
  private var headline: some View {
    ZStack(alignment: .top) {
      Text("A\nB").font(JourneyType.headline).hidden().accessibilityHidden(true)
      headlineText.id(step)
        // The old line leaves quickly; the new one arrives just after, so the two never overlap.
        .transition(.asymmetric(
          insertion: AnyTransition.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)).animation(.smooth(duration: 0.28).delay(0.1)),
          removal: AnyTransition.opacity.animation(.easeOut(duration: 0.1))))
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
    }.font(JourneyType.headline).multilineTextAlignment(.center)
      .lineLimit(3).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
  }
  private var headlineCopy: String {
    switch step {
    case .name: return "What should we call you?"
    case .body: return "Tell us about you."
    case .alerts: return "Get a buzz when rest is up."
    case .scrolling: return "Do you use your phone between sets?"
    case .phoneMinutes: return "Between sets, how long are you on your phone?"
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
    case .body: return "Stays on this phone."
    case .alerts: return "Change it anytime in Settings."
    case .reveal, .days: return "Based on your answers."
    case .commit: return "Press and hold."
    case .mindA, .mindB, .restA, .restB: return "Illustration"
    case .logA, .logB: return "Example"
    case .blocking: return "Blocking is simulated in this build."
    case .subscription: return subscription.message
    default: return nil
    }
  }

  @ViewBuilder private var stage: some View {
    switch step {
    case .welcome, .scrolling: NotificationStage(awake: step == .scrolling, done: markReady)
    case .name: NameStage(name: $nameDraft) { if canSaveName { advance() } }
    case .body: BodyStage(gender: Binding(get: { gender }, set: { setGender($0) }), metric: $metric,
                          heightCM: $heightCM, weightKG: $weightKG) { bodyTouched = true }
    case .alerts: AlertStage(done: markReady)
    case .phoneMinutes:
      JourneyWheel(values: stride(from: 0.5, through: 10, by: 0.5).map { $0 }, unit: store.t("min"), id: "baseline.scrollMinutes",
                   value: $draft).frame(height: 216).frame(maxHeight: .infinity)
    case .reveal: RevealStage(estimate: $estimate, done: markReady)
    case .days: DaysStage(estimate: estimate, done: markReady)
    case .mindA, .mindB: MindStage(focused: step == .mindB, done: markReady)
    case .restA, .restB: RestStage(timed: step == .restB, done: markReady)
    case .logA, .logB: LogStage(remembered: step == .logB, done: markReady)
    case .commit: CommitStage(lit: pledged)
    case .blocking: BlockStage(selected: Binding(get: { apps }, set: { apps = $0; saveApps() }), locking: locking)
    case .subscription: OfferStage(subscription: subscription)
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
        VStack(spacing: 10) {
          option("Every rest", .yes); option("Sometimes", .sometimes); option("Rarely", .no)
        }
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
        gated(JourneyButton(title: store.t("Get started"), id: "onboarding.continue", enabled: ready) { move(.name) })
        Color.clear.frame(height: 44)
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
        JourneyButton(title: subscription.product.map { store.t("Subscribe") + " · " + $0.displayPrice } ?? store.t("Subscribe"),
                      id: "subscription.buy", enabled: subscription.product != nil && !subscription.busy) {
          Task { await subscription.buy() }
        }
        JourneyTextButton(title: store.t("Restore purchases"), id: "subscription.restore") { Task { await subscription.restore() } }
      default:
        gated(JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: ready, action: advance))
        Color.clear.frame(height: 44)
      }
    }
  }
  /// Continue holds its place but stays hidden until the page's animation has played.
  private func gated(_ button: JourneyButton) -> some View {
    button.opacity(ready ? 1 : 0).offset(y: ready ? 0 : 6).allowsHitTesting(ready)
      .animation(.smooth(duration: 0.3), value: ready)
  }
  private func markReady() {
    guard !ready else { return }
    withAnimation(.smooth(duration: 0.3)) { ready = true }
  }
  private func commit() {
    guard !committed else { return }
    withAnimation(.spring(duration: 0.35)) { committed = true; pledged = 3 }
    store.updateProfile { $0.onboardingStoryStage = 1 }
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 650))
      if step == .commit { move(.subscription) }
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
  /// Saves, shows the check for a beat, then advances.
  private func choice(_ title: String, id: String, selected: Bool, apply: @escaping () -> Void) -> some View {
    JourneyOption(title: store.t(title), selected: selected, id: id) {
      guard !answering else { return }
      answering = true
      apply()
      JourneyHaptic.play(.selection, store.profile)
      let from = step
      Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 180))
        answering = false
        if step == from { next() }
      }
    }
  }
  /// Typical starting values, only until the person turns a wheel.
  private func bodyDefaults(_ gender: String?) -> (height: Double, weight: Double) {
    gender == "male" ? (178, 80) : gender == "female" ? (165, 65) : (170, 72)
  }
  private func setGender(_ value: String?) {
    gender = value
    guard !bodyTouched else { return }
    withAnimation(.snappy(duration: 0.3)) {
      heightCM = bodyDefaults(value).height; weightKG = bodyDefaults(value).weight
    }
  }
  private var canSaveName: Bool { !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  private func prepare() {
    switch step {
    case .name: nameDraft = store.profile.name
    case .body:
      let p = store.profile
      metric = p.bodyWeightKG != nil ? p.unit == "kg" : BodyUnits.defaultMetric
      gender = p.gender
      bodyTouched = p.heightCM != nil
      heightCM = p.heightCM ?? bodyDefaults(p.gender).height
      weightKG = p.bodyWeightKG ?? bodyDefaults(p.gender).weight
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
    if step == .body {
      store.updateProfile {
        $0.gender = gender
        $0.heightCM = heightCM.rounded(); $0.bodyWeightKG = (weightKG * 10).rounded() / 10; $0.unit = metric ? "kg" : "lb"
      }
    }
    if step == .phoneMinutes { update { $0.scrollingMinutes = draft; $0.minutesPerBreak = nil } }
    if step == .reveal { update { estimate.write(into: &$0) } }
    next()
  }
  private func next() {
    if let index = route.firstIndex(of: step), index + 1 < route.count { move(route[index + 1]) }
  }
  private func back() {
    guard !locking else { return }
    if step == .name { dismissKeyboard(); move(.welcome); return }
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
    let wait = reduceMotion ? 0.25 : 0.08 * Double(apps.count) + 0.45
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(wait))
      JourneyHaptic.play(.success, store.profile)
      if step == .blocking { next() }
      locking = false
    }
  }
  private func move(_ next: OnboardingStep) {
    ready = reduceMotion || !next.animated
    JourneyHaptic.play(.light, store.profile)
    withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.32)) {
      store.updateProfile { $0.onboardingStepID = next.rawValue; $0.onboardingStoryStage = 0 }
      prepare()
    }
  }
  private func update(_ body: (inout RoutineBaseline) -> Void) {
    store.updateProfile {
      var baseline = $0.baseline ?? RoutineBaseline()
      body(&baseline); baseline.goalMinutesPerBreak = nil; baseline.reductionGoal = nil
      $0.baseline = baseline; $0.onboardingPreviewTarget = nil
    }
  }
  private func finish() {
    store.updateProfile { $0.onboarded = true; $0.onboardingStepID = OnboardingStep.subscription.rawValue }
  }
}
