import FamilyControls
import SwiftUI

/// Onboarding: one question or one idea per page, on a fixed grid —
/// progress line, headline box, stage, caption, actions. See docs/ONBOARDING-V5-PLAN.md.
enum OnboardingStep: String, CaseIterable {
  case welcome, founder, name, trainingDays, scrolling, phoneMinutes, reveal, days, mindA, mindB, restA, restB, logA, logB, blocking, alerts, commit, account, subscription, splits, firstWorkout
  // Asked before 17 Oct 2026 (V5); saved progress on them resumes at the days question.
  case gender, height, weight
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
    case .body, .gender, .height, .weight: return .trainingDays
    case .duration, .reps, .sets, .exercises, .routine: return .scrolling
    case .minutes, .breaks: return .phoneMinutes
    case .frequency, .restHabits, .loggingHabits, .setTiming: return .reveal
    case .mindMuscle: return .mindA
    case .restStory: return .restA
    case .progressStory, .ready: return .logA
    default: return self
    }
  }
  /// The account step or later: the answers are worth keeping in the account from here on.
  var reachedAccount: Bool { [.account, .subscription, .splits, .firstWorkout].contains(current) }
  /// Pages whose animation must finish before Continue appears.
  var animated: Bool { [.welcome, .scrolling, .reveal, .days, .mindA, .mindB, .restA, .restB, .logA, .logB, .blocking, .alerts, .commit].contains(self) }
  /// Pages sharing a stage keep their visual in place; only the words change.
  var stage: String {
    switch self {
    case .scrolling: return "notify"
    case .mindA, .mindB: return "mind"
    case .restA, .restB: return "rest"
    case .logA, .logB: return "log"
    default: return rawValue
    }
  }
}

enum OnboardingRoute {
  static func steps(_ baseline: RoutineBaseline) -> [OnboardingStep] {
    var steps: [OnboardingStep] = [.founder, .name, .trainingDays, .scrolling]
    let scrolls = baseline.scrollFrequency != .no
    if scrolls { steps.append(.phoneMinutes) }
    steps.append(.reveal)
    if scrolls { steps.append(.days) }
    return steps + [.mindA, .mindB, .restA, .restB, .logA, .logB, .blocking, .alerts, .commit, .account, .subscription, .splits, .firstWorkout]
  }
}

struct OnboardingView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  @EnvironmentObject private var subscription: GymSubscription
  @EnvironmentObject private var account: Account
  /// "I already have an account": the standalone sign-in, which RootView shows.
  var onSignIn: () -> Void = {}
  @State private var draft = 2.0
  @State private var estimate = GymTimeEstimate()
  @ObservedObject private var blocking = AppBlocking.shared
  /// The system app picker, its working copy, and a note when Screen Time access is refused.
  @State private var picking = false
  /// iOS has been asked for Screen Time access on this page (App Review 5.1.1(iv), 17 Oct 2026: the
  /// page may only be left once the system request has shown).
  @State private var askedScreenTime = false
  @State private var pickDraft = FamilyActivitySelection()
  @State private var blockMessage: String?
  @State private var locking = false
  @State private var nameDraft = ""
  @State private var trainingDays: Int?
  @State private var template: SplitTemplate?
  @State private var gender: String?
  @State private var heightUnit = BodyUnits.defaultMetric ? 0 : 1
  @State private var weightUnit = BodyUnits.defaultMetric ? 0 : 1
  @State private var heightCM = 175.0
  @State private var weightKG = 75.0
  @State private var covered = true
  @State private var ready = true
  /// When the current page appeared, for the minimum time before Continue.
  @State private var pageShownAt = Date()
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
        // The welcome scene carries its own words; every other page has the headline box.
        if step != .welcome {
          headline.padding(.horizontal, 28).padding(.top, 14)
            .opacity(shown ? 1 : 0).offset(x: slide)
        }
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
    // Continue waits for the page's animation to finish. Safety net, well past the longest
    // sequence: it still appears if one is interrupted.
    // Leaving the page cancels this task. The sleep's cancellation is swallowed by `try?`, so it must
    // be checked, or the next page would get its Continue the moment it opened.
    .task(id: step) {
      let page = step
      guard !ready else { return }
      try? await Task.sleep(for: .seconds(20))
      guard !Task.isCancelled else { return }
      markReady(page)
    }
    .onChange(of: step) { old, new in Analytics.leave("onboarding." + old.rawValue); Analytics.enter("onboarding." + new.rawValue, ["step": stepIndex(new)]) }
    .onAppear { Analytics.enter("onboarding." + step.rawValue, ["step": stepIndex(step)]) }
    .onDisappear { Analytics.leave("onboarding." + step.rawValue) }
    .familyActivityPicker(headerText: store.t("Choose what to block from Start workout to Finish."), isPresented: $picking, selection: $pickDraft)
    .onChange(of: pickDraft) { _, chosen in blocking.choose(chosen) }
    .onAppear {
      if reduceMotion || Self.coverShown { covered = false } else {
        Self.coverShown = true
        withAnimation(.easeOut(duration: 0.6)) { covered = false }
      }
      ArmFrames.shared.prepare()
      JourneyScorePlayer.shared.prepare()
      ready = reduceMotion || !step.animated
      pageShownAt = Date()
      prepare()
      store.updateProfile {
        $0.onboardingStepID = step.rawValue
        // V7 no longer asks body weight, so kg or lb comes from the phone's region the first time.
        if ($0.onboardingVersion ?? 0) < 10 && $0.onboardingStepID == nil { $0.unit = BodyUnits.defaultMetric ? "kg" : "lb" }
        $0.onboardingVersion = 10
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
        // Past the offer there is no going back to it.
        JourneyBackButton(label: store.t("Back"), action: back).disabled(locking)
          .opacity(step == .splits || step == .firstWorkout ? 0 : 1).allowsHitTesting(step != .splits && step != .firstWorkout)
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
      if step == .founder {
        Text(store.t("“Perfection is lots of little things done right.”")).italic()
      } else if let personal {
        Text(personal)
      } else {
        Text(store.t(headlineCopy))
      }
    }.font(JourneyType.headline).tracking(-0.3).multilineTextAlignment(.center)
      .lineLimit(step == .reveal ? 3 : 2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
  }
  private var headlineCopy: String {
    switch step {
    case .name: return "First, what should we call you?"
    case .gender: return "What’s your gender?"
    case .height: return "How tall are you?"
    case .weight: return "How much do you weigh?"
    case .alerts: return "We’ll buzz you when rest is up."
    case .scrolling: return "Be honest. Do you check your phone between sets?"
    case .phoneMinutes: return "Roughly how long, each rest?"
    case .reveal: return "Here’s where your workout time goes."
    case .days: return daysHeadline
    case .commit: return "Here’s your plan."
    case .mindA: return "Scrolling weakens your mind-muscle connection."
    case .mindB: return "Put it away. Feel every rep."
    case .restA: return "Long scrolls between sets?\nThe pump never builds."
    case .restB: return "Rest on time,\nand it keeps building."
    case .logA: return "Quick: what did you bench last week?"
    case .logB: return "Your log remembers. Every set."
    case .blocking: return "Which apps should we lock while you train?"
    case .account: return "Let’s save your plan to your account."
    case .splits: return "You’re in. How do you usually split your training?"
    case .trainingDays: return "How many days a week do you work out?"
    case .firstWorkout: return firstWorkoutHeadline
    default: return "Stay focused with GymBlock."
    }
  }
  /// Uses their name where it reads naturally.
  private var personal: String? {
    let name = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else { return nil }
    switch step {
    case .reveal: return name + ", " + store.t("here’s where your workout time goes.")
    case .trainingDays: return String(format: store.t("Nice to meet you, %@. How many days a week do you work out?"), name)
    case .commit: return name + ", " + store.t("here’s your plan.")
    default: return nil
    }
  }
  private var daysHeadline: String {
    String(format: store.t("At your %@ workouts a week, that’s %@ hours a year."), "\(estimate.days)", "\(Int(estimate.yearlyPhoneHours.rounded()))")
  }
  private var firstWorkoutHeadline: String {
    let split = store.data.workouts.first { $0.id == store.profile.preferredSplitID } ?? store.data.workouts.first
    return split.map { String(format: store.t("Ready? Your first workout is %@."), $0.name) } ?? "Ready? Start your first workout."
  }
  private var caption: String? {
    switch step {
    case .name: return "It’s how we’ll greet you in the app."
    case .trainingDays: return "We’ll set your weekly goal from this."
    case .scrolling: return "No judgement. Mine was every rest."
    case .phoneMinutes: return "Your best guess is fine."
    case .alerts: return "One buzz, right when it’s time. Change it anytime."
    case .reveal: return "A typical workout: 6 exercises × 3 sets, with your rests."
    case .days: return "Your own numbers, multiplied out."
    case .commit: return "Hold the button until it fills."
    case .firstWorkout: return store.profile.focusEnabled == true && AppBlocking.shared.ready ? "Starting it locks your apps until you finish." : "Every set is saved as you go."
    case .mindA, .mindB, .restA, .restB: return "Illustrative, not a measurement."
    case .logA, .logB: return "An example log, not your data."
    case .blocking: return blockMessage ?? "Uses Apple’s Screen Time. Ending your workout lifts it."
    case .account: return account.message ?? "Your workouts sync to your account and come back on any iPhone."
    case .splits: return "Change them anytime."
    default: return nil
    }
  }

  @ViewBuilder private var stage: some View {
    switch step {
    case .welcome: WelcomeScene(done: sceneDone)
    case .founder: FounderStage()
    case .trainingDays: TrainingDaysStage(days: $trainingDays) { n in
      withAnimation(JourneyMotion.gentle) { trainingDays = n }
      JourneyHaptic.play(.selection, store.profile)
    }
    case .scrolling: NotificationStage(awake: true, done: sceneDone)
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
    case .alerts: LockScreenRest(done: sceneDone)
    case .phoneMinutes:
      JourneyWheel(values: stride(from: 0.5, through: 10, by: 0.5).map { $0 }, unit: store.t("min"), id: "baseline.scrollMinutes",
                   value: $draft).frame(height: 216).frame(maxHeight: .infinity)
    case .reveal: RevealStage(estimate: estimate, done: sceneDone)
    case .days: DaysStage(estimate: estimate, done: sceneDone)
    case .mindA, .mindB: MindStage(focused: step == .mindB, done: sceneDone)
    case .restA, .restB: RestStage(timed: step == .restB, done: sceneDone)
    case .logA, .logB: LogStage(remembered: step == .logB, done: sceneDone)
    case .commit: PlanStage(done: sceneDone)
    case .blocking: BlockStage(locking: locking, choose: chooseApps, done: sceneDone)
    case .account: AccountStage()
    case .splits: SplitTemplateStage(choice: $template)
    case .firstWorkout: FirstWorkoutStage()
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
        gated(JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: baseline.scrollFrequency != nil, action: advance))
        Color.clear.frame(height: 44)
      case .trainingDays:
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: trainingDays != nil, action: advance)
        Color.clear.frame(height: 44)
      case .alerts:
        // App Review 5.1.1(iv) (17 Oct 2026): a page that explains a permission always goes on to the
        // system request, so Continue is the only way on and iOS's own prompt is where to say no.
        gated(JourneyButton(title: store.t("Continue"), id: "alerts.on", enabled: ready) {
          Task { @MainActor in
            let granted = await RestAlert.requestPermission()
            Analytics.track("onboarding_alerts", ["choice": "asked", "granted": granted])
            store.updateProfile { $0.restAlerts = granted }
            if step == .alerts { next() }
          }
        })
        Color.clear.frame(height: 44)
      case .name:
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: canSaveName, action: advance)
        Color.clear.frame(height: 44)
      case .welcome:
        gated(JourneyButton(title: store.t("Get started"), id: "onboarding.continue", enabled: ready) { move(.founder) })
        JourneyTextButton(title: store.t("I already have an account"), id: "welcome.signIn", action: onSignIn)
          .opacity(ready ? 1 : 0).allowsHitTesting(ready).accessibilityHidden(!ready)
      case .account:
        // The last step of sign-up. An account that turns out to exist already is RootView's
        // notice to give; anything else carries on to the offer, which RootView shows.
        AccountButtons(intent: .signUp, skip: { move(.subscription) }) { found in
          if found != .profile(onboarded: true) { move(.subscription) }
        }
      case .commit:
        gated(HoldButton(title: store.t("Hold to commit"), doneTitle: store.t("Committed"), committed: committed,
                   onProgress: { p in
                     let next = min(3, Int(p * 3 + 0.001))
                     if next != pledged { withAnimation(.spring(duration: 0.3)) { pledged = next } }
                   },
                   onComplete: commit))
        Color.clear.frame(height: 44)
      case .blocking:
        // App Review 5.1.1(iv) (17 Oct 2026): until iOS has asked for Screen Time access, Choose apps
        // (which asks first) is the only way on. Once it has asked, choosing apps can wait; a refusal
        // carries on, with iOS Settings one tap away.
        let asked = askedScreenTime || blocking.status != .notDetermined || StoreShots.on
        let refused = asked && !blocking.authorized && !StoreShots.on
        if blocking.ready || StoreShots.on {
          gated(JourneyButton(title: store.t("Turn on blocking"), id: "blocking.on", enabled: !locking, action: turnOnBlocking))
        } else if refused {
          gated(JourneyButton(title: store.t("Continue"), id: "blocking.continue") { skipBlocking() })
        } else {
          gated(JourneyButton(title: store.t("Choose apps"), id: "blocking.choose", action: chooseApps))
        }
        if refused {
          JourneyTextButton(title: store.t("Open Settings"), id: "blocking.settings") {
            Analytics.track("blocking_settings_opened")
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
          }
        } else if asked {
          JourneyTextButton(title: store.t("Not now"), id: "blocking.later") { skipBlocking() }
        } else {
          Color.clear.frame(height: 44)
        }
      case .subscription:
        // RootView shows the offer in place of this page.
        EmptyView()
      case .splits:
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: template != nil) { applyTemplate() }
        Color.clear.frame(height: 44)
      case .firstWorkout:
        JourneyButton(title: store.t("Start workout"), symbol: "play.fill", id: "first.start") { finish(skipped: false, start: true) }
        JourneyTextButton(title: store.t("I’m not at the gym yet"), id: "first.later") { finish(skipped: false) }
      default:
        gated(JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: ready, action: advance))
        Color.clear.frame(height: 44)
      }
    }
  }
  /// Continue holds its place and fades in once the page's scene has played.
  private func gated<Button: View>(_ button: Button) -> some View {
    // Hidden means hidden for VoiceOver too, so nothing can be activated before the scene ends.
    button.opacity(ready ? 1 : 0).offset(y: ready ? 0 : 8).allowsHitTesting(ready).accessibilityHidden(!ready)
      .animation(.smooth(duration: 0.3), value: ready)
  }
  /// A scene has finished. Continue still waits a beat after it, and until the page has been up a
  /// minimum time, so nobody taps through before the point lands.
  /// A page's scene has ended: its Continue fades in. Only that page's own signal counts; a late one
  /// from a page already left never reveals the next page's button.
  private func markReady(_ page: OnboardingStep) {
    guard !ready, step == page else { return }
    withAnimation(.smooth(duration: 0.3)) { ready = true }
  }
  /// The signal a scene on this page calls when it ends, bound to this page.
  private var sceneDone: () -> Void {
    let page = step
    return { markReady(page) }
  }

  private func commit() {
    guard !committed else { return }
    withAnimation(JourneyMotion.gentle) { committed = true; pledged = 3 }
    Analytics.track("onboarding_committed", ["hold_ms": Int(Date().timeIntervalSince(pageShownAt) * 1000)])
    store.updateProfile { $0.onboardingStoryStage = 1 }
    JourneyScorePlayer.shared.play(JourneyScores.committed, profile: store.profile)
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
    case .trainingDays: trainingDays = baseline.trainingDays.map { min(6, max(2, $0)) }
    case .splits: template = store.data.workouts.isEmpty ? nil : .keep
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
    case .blocking: blockMessage = nil
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
    if step == .trainingDays { guard let trainingDays else { return }; update { $0.trainingDays = trainingDays } }
    if step == .gender { guard gender != nil else { return }; store.updateProfile { $0.gender = gender } }
    if step == .height { store.updateProfile { $0.heightCM = heightCM.rounded() } }
    if step == .weight {
      store.updateProfile { $0.bodyWeightKG = (weightKG * 10).rounded() / 10; $0.unit = weightUnit == 0 ? "kg" : "lb" }
    }
    if step == .phoneMinutes { update { $0.scrollingMinutes = draft; $0.minutesPerBreak = nil } }
    trackAnswer()
    next()
  }
  /// What each question page was answered with. Never the name itself; body measures in 5-unit bands.
  private func trackAnswer() {
    var props: [String: Any?] = ["question": step.rawValue]
    switch step {
    case .name: props["answered"] = true
    case .trainingDays: props["value"] = trainingDays
    case .gender: props["value"] = gender
    case .height: props["cm_band"] = Int((heightCM / 5).rounded()) * 5; props["unit"] = heightUnit == 0 ? "cm" : "ft_in"
    case .weight: props["kg_band"] = Int((weightKG / 5).rounded()) * 5; props["unit"] = weightUnit == 0 ? "kg" : "lb"
    case .scrolling: props["value"] = baseline.scrollFrequency?.rawValue
    case .phoneMinutes: props["minutes_per_rest"] = draft
    case .reveal, .days:
      props["phone_minutes"] = Int(estimate.phoneMinutes.rounded()); props["training_minutes"] = Int(estimate.trainingMinutes.rounded())
      props["yearly_phone_hours"] = Int(estimate.yearlyPhoneHours.rounded())
    default: return
    }
    Analytics.track("onboarding_answer", props)
  }
  private func next() {
    if let index = route.firstIndex(of: step), index + 1 < route.count { move(route[index + 1]) }
  }
  private func back() {
    guard !locking else { return }
    if step == .founder { move(.welcome); return }
    if step == .name { dismissKeyboard() }
    if let index = route.firstIndex(of: step), index > 0 { move(route[index - 1]) }
  }
  /// Apple's picker only returns a choice once Screen Time access is granted, so tapping Choose apps
  /// asks for it first (iOS asks once). Choosing never advances the page.
  private func chooseApps() {
    guard !locking, !picking else { return }
    Task { @MainActor in
      let granted = await blocking.requestAccess()
      askedScreenTime = true
      guard granted else {
        blockMessage = "Screen Time access is off. You can allow it in Settings anytime."
        return
      }
      blockMessage = nil
      pickDraft = blocking.selection
      picking = true
    }
  }
  /// On without blocking: after iOS has asked, whatever the answer.
  private func skipBlocking() {
    guard !locking else { return }
    Analytics.track("onboarding_blocking", ["choice": "later", "chosen": blocking.ready, "authorized": blocking.authorized])
    store.updateProfile { $0.focusEnabled = false }
    next()
  }
  private func turnOnBlocking() {
    guard !locking, blocking.ready else { return }
    Analytics.track("onboarding_blocking", ["choice": "on", "apps": blocking.apps, "categories": blocking.categories, "sites": blocking.sites])
    store.updateProfile { $0.focusEnabled = true }
    locking = true
    let wait = reduceMotion ? 0.25 : 0.14 * Double(min(6, blocking.apps + blocking.categories)) + 0.7
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
    JourneyScorePlayer.shared.stop()
    JourneyHaptic.play(.soft, store.profile, intensity: 0.55)
    let out = reduceMotion ? 0.1 : 0.18
    stageLeaving = next.stage != step.stage
    let all = [OnboardingStep.welcome] + route
    let forward = (all.firstIndex(of: next) ?? 0) >= (all.firstIndex(of: step) ?? 0)
    Analytics.track("onboarding_step", ["from": step.rawValue, "to": next.rawValue, "direction": forward ? "forward" : "back",
                                        "index": stepIndex(next), "total": all.count,
                                        "dwell_ms": Int(Date().timeIntervalSince(pageShownAt) * 1000)])
    if step == .welcome && forward { OnboardingAnalytics.started() }
    let travel: CGFloat = reduceMotion ? 0 : 18
    withAnimation(.easeIn(duration: out)) { shown = false; slide = forward ? -travel : travel }
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(out))
      // Swap while nothing changing is visible. Views keep their own `.animation(value:)` morphs.
      withTransaction(Transaction(animation: nil)) {
        ready = reduceMotion || !next.animated
        pageShownAt = Date()
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
  /// After the offer: the chosen template becomes splits (existing ones are kept), then the first workout.
  private func applyTemplate() {
    guard let template else { return }
    if template != .keep {
      for (name, ids) in template.splits {
        let exercises = SplitTemplate.exercises(ids)
        let localized = store.t(name)
        guard !store.data.workouts.contains(where: { $0.name.localizedCaseInsensitiveCompare(localized) == .orderedSame }) else { continue }
        _ = store.saveSplit(id: UUID(), name: localized, exercises: exercises)
      }
    }
    if let first = store.data.workouts.first, template != SplitTemplate.none { store.updateProfile { $0.preferredSplitID = first.id } }
    Analytics.track("onboarding_answer", ["question": "splits", "value": template.rawValue, "splits": store.data.workouts.count])
    move(.firstWorkout)
  }
  /// The end of onboarding: into the app, with the first split (if any) lined up on Home, or
  /// straight into it.
  private func finish(skipped: Bool, start: Bool = false) {
    JourneyHaptic.play(.success, store.profile)
    JourneyScorePlayer.shared.shutDown()
    let p = store.profile
    OnboardingAnalytics.completed([
      "splits": store.data.workouts.count, "splits_skipped": skipped, "blocking": p.focusEnabled, "rest_alerts": p.restAlerts,
      "subscribed": subscription.hasAccess, "signed_in": account.state == .signedIn, "pages": route.count + 1,
    ])
    store.updateProfile {
      if $0.preferredSplitID == nil { $0.preferredSplitID = store.data.workouts.first?.id }
      $0.onboarded = true; $0.onboardingStepID = OnboardingStep.firstWorkout.rawValue
    }
    if start {
      let split = store.data.workouts.first { $0.id == store.profile.preferredSplitID }
      store.startSession(workout: split)
    }
  }
}
