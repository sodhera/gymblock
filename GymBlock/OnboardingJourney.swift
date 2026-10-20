import FamilyControls
import SwiftUI

/// Onboarding: one question or one idea per page, on a fixed grid —
/// progress line, headline box, stage, caption, actions. See docs/ONBOARDING-V8-PLAN.md.
enum OnboardingStep: String, CaseIterable {
  case welcome, founder, name, trainingDays, scrolling, restNeed, scrollMinutes, perRest, ahead, exerciseCount, setCount, gymTime
  case workoutTime, yearTime, promise, shield, blocking, alerts, commit, account, subscription, splits, firstWorkout
  // V7's pages (17 Oct 2026), replaced on 20 Oct 2026 by time back; saved progress on them resumes
  // at the rest question.
  case phoneMinutes, reveal, days, mindA, mindB, restA, restB, logA, logB
  // Asked before 17 Oct 2026 (V5); saved progress on them resumes at the days question.
  case gender, height, weight
  // Decode-only steps saved by earlier journeys.
  case body, frequency, restHabits, loggingHabits, mindMuscle, restStory, progressStory
  case duration, reps, sets, exercises, minutes, breaks, setTiming, routine, ready
  static func restored(_ profile: Profile) -> Self {
    if let id = profile.onboardingStepID, let step = Self(rawValue: id) { return step.current }
    let old: [Self] = [.welcome, .restNeed, .scrolling, .scrolling, .scrolling, .restNeed, .restNeed]
    return old[min(max(profile.onboardingStep, 0), old.count - 1)]
  }
  /// Maps removed pages onto the nearest current page; stored answers are never discarded.
  var current: Self {
    switch self {
    case .body, .gender, .height, .weight: return .trainingDays
    case .duration, .reps, .sets, .exercises, .routine: return .scrolling
    case .minutes, .breaks, .frequency, .restHabits, .loggingHabits, .setTiming, .mindMuscle, .restStory, .progressStory, .ready,
         .phoneMinutes, .reveal, .days, .mindA, .mindB, .restA, .restB, .logA, .logB:
      return .restNeed
    default: return self
    }
  }
  /// The account step or later: the answers are worth keeping in the account from here on.
  var reachedAccount: Bool { [.account, .subscription, .splits, .firstWorkout].contains(current) }
  /// Pages whose animation must finish before Continue appears.
  var animated: Bool { [.welcome, .scrolling, .perRest, .ahead, .workoutTime, .yearTime, .promise, .shield, .alerts, .commit].contains(self) }
  /// Pages sharing a stage keep their visual in place; only the words change.
  var stage: String {
    switch self {
    case .scrolling: return "notify"
    // Rarely's "already ahead" keeps the stopwatch from the rest question in place.
    case .restNeed, .ahead: return "watch"
    default: return rawValue
    }
  }
}

enum OnboardingRoute {
  /// The pages their answers lead to (docs/ONBOARDING-V8-PLAN.md): Rarely, or scrolling that fits
  /// inside the rest, goes straight to how GymBlock works; answers that don't fit their gym time get
  /// the per-rest promise only; under five minutes a workout gets the number and nothing more.
  static func steps(_ baseline: RoutineBaseline) -> [OnboardingStep] {
    var steps: [OnboardingStep] = [.founder, .name, .trainingDays, .scrolling, .restNeed]
    let time = TimeBack(baseline)
    if baseline.scrollFrequency == .no {
      steps.append(.ahead)
    } else {
      steps += [.scrollMinutes, .perRest]
      if time.lostPerRest != 0 {
        steps += [.exerciseCount, .setCount, .gymTime]
        switch time.outcome {
        case .unfit: steps.append(.promise)
        case .small: steps.append(.workoutTime)
        default: steps += [.workoutTime, .yearTime, .promise]
        }
      }
    }
    return steps + [.shield, .blocking, .alerts, .commit, .account, .subscription, .splits, .firstWorkout]
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
  /// Minutes a scroll lasts, on the wheel.
  @State private var draft = 1.0
  /// The rows' choices before Continue saves them. A rest of 0 is "Not sure".
  @State private var restChoice: Double?
  @State private var exerciseChoice: Int?
  @State private var setChoice: Int?
  @State private var gymChoice: Int?
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
  private var time: TimeBack { TimeBack(baseline, restSeconds: store.profile.restSeconds) }
  private var step: OnboardingStep { OnboardingStep.restored(store.profile) }
  private var route: [OnboardingStep] { OnboardingRoute.steps(baseline) }

  var body: some View {
    ZStack {
      DotGrid()
      VStack(spacing: 0) {
        topBar.frame(height: 44).padding(.horizontal, 12)
        // The welcome scene carries its own words; every other page has the headline box.
        if step != .welcome {
          headline.padding(.horizontal, JourneyLayout.compact ? 24 : 28).padding(.top, JourneyLayout.compact ? 6 : 14)
            .opacity(shown ? 1 : 0).offset(x: slide)
        }
        ZStack {
          stage.id(step.stage).transition(.identity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
          // Small screens keep a margin around every scene instead of filling the screen edge to edge.
          // (Sulav's note is text, so it keeps the usual margin.)
          .padding(.horizontal, JourneyLayout.compact && step != .founder ? 32 : (JourneyLayout.compact ? 18 : 24))
          .padding(.vertical, JourneyLayout.compact ? 14 : 12)
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
    .environment(\.journeyPress, true)
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
        $0.onboardingVersion = 11
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
      Text("A\nB").font(headlineFont).hidden().accessibilityHidden(true)
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
    }.font(headlineFont).tracking(-0.3).multilineTextAlignment(.center)
      .lineLimit([.scrollMinutes, .workoutTime, .promise].contains(step) ? 3 : 2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
  }
  /// The large title, one step smaller on small screens.
  private var headlineFont: Font { JourneyLayout.compact ? Font.app(.title2, design: .default, weight: .bold) : JourneyType.headline }
  private var headlineCopy: String {
    switch step {
    case .name: return "First, what should we call you?"
    case .gender: return "What’s your gender?"
    case .height: return "How tall are you?"
    case .weight: return "How much do you weigh?"
    case .alerts: return "We’ll buzz you\nwhen rest is up."
    case .scrolling: return "Be honest. Do you check your phone between sets?"
    case .restNeed: return "How long do you need to rest between sets?"
    case .scrollMinutes: return "When you start scrolling between sets, how many minutes do you scroll?"
    case .ahead: return "Then you’re already ahead."
    case .exerciseCount: return "How many exercises do you usually do every workout?"
    case .setCount: return "And how many sets of each exercise?"
    case .gymTime: return "How long are you usually at the gym?"
    case .commit: return "Here’s your plan."
    case .shield: return "Open a locked app while you train, and you’ll see this."
    case .blocking: return "Which apps should we lock while you train?"
    case .account: return "Let’s save your plan to your account."
    case .splits: return "You’re in. How do you usually split your training?"
    case .trainingDays: return "How many days a week do you work out?"
    case .firstWorkout: return firstWorkoutHeadline
    default: return "Stay focused with GymBlock."
    }
  }
  /// Headlines built from their name and their own numbers (already translated).
  private var personal: String? {
    let name = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let time = self.time
    switch step {
    case .trainingDays where !name.isEmpty: return String(format: store.t("Hi %@. How many days a week do you work out?"), name)
    case .commit where !name.isEmpty: return name + ", " + store.t("here’s your plan.")
    case .perRest:
      guard let lost = time.lostPerRest else { return nil }
      if lost == 0 { return store.t("Then your scrolling fits inside your rest.") }
      return String(format: store.t(time.share < 1 ? "That’s %@ lost each time you scroll." : "That’s %@ lost. Every rest."), store.minutesWords(lost))
    case .workoutTime:
      if time.outcome == .small {
        let words = store.minutesWords(Double(max(1, time.shownLost)))
        return name.isEmpty ? String(format: store.t("Scrolling takes about %@ of your workout."), words)
          : String(format: store.t("%@, scrolling takes about %@ of your workout."), name, words)
      }
      let gym = store.gymWords(time.gym ?? 60)
      if name.isEmpty {
        let lost = store.lostWords(time)
        return String(format: store.t("%@ of your %@ goes to scrolling."), lost.prefix(1).uppercased() + lost.dropFirst(), gym)
      }
      return String(format: store.t("%@, %@ of your %@ goes to scrolling."), name, store.lostWords(time), gym)
    case .yearTime:
      // The number keeps its unit on the same line ("120 hours", never "120 / hours").
      let hours = "\(time.shownYear)"
      return String(format: store.t("At %@ workouts a week, that’s about %@ hours a year."), "\(time.days)", hours)
        .replacingOccurrences(of: hours + " ", with: hours + "\u{00A0}")
    case .promise:
      if time.outcome == .unfit {
        let lost = time.lostPerRest ?? 0
        return lost == 1 ? store.t("We’ll give you that minute back. Every rest.")
          : String(format: store.t("We’ll give you those %@ back. Every rest."), store.minutesWords(lost))
      }
      return time.lostIsAnHour ? store.t("We’ll give you that hour back.\nAnd a better workout.")
        : String(format: store.t("We’ll give you those %@ back.\nAnd a better workout."), String(format: store.t("%@ minutes"), "\(time.shownLost)"))
    case .alerts:
      return String(format: store.t("We’ll buzz you\nwhen your %@ is up."), clockString(store.profile.restSeconds ?? 90))
    default: return nil
    }
  }
  private var firstWorkoutHeadline: String {
    let split = store.data.workouts.first { $0.id == store.profile.preferredSplitID } ?? store.data.workouts.first
    return split.map { String(format: store.t("Ready? Your first workout is %@."), $0.name) } ?? "Ready? Start your first workout."
  }
  private var caption: String? {
    switch step {
    case .name: return "It’s how we’ll greet you in the app."
    case .trainingDays: return "We’ll set your weekly goal from this."
    case .scrolling: return "No judgement. We did too."
    case .restNeed: return restChoice == 0 ? "We’ll start you at 2 minutes." : "We’ll time your rests to this."
    case .scrollMinutes: return "Your best guess is fine."
    case .perRest:
      let need = time.restNeed
      if time.lostPerRest == 0 { return "We’ll help you keep it that way." }
      return need == 1 ? store.t("The first minute was rest you’d take anyway.")
        : String(format: store.t("The first %@ were rest you’d take anyway."), store.minutesWords(need))
    case .ahead: return "We’ll help you keep it that way."
    case .setCount:
      guard let setChoice else { return nil }
      let sets = (baseline.exercises ?? 5) * setChoice
      return String(format: store.t("%@ sets, so %@ rests."), "\(sets)", "\(max(0, sets - 1))")
    case .gymTime: return "From walking in to walking out."
    case .workoutTime:
      let time = self.time
      if time.outcome == .small { return "We’ll help you keep it that way." }
      if time.fitted { return String(format: store.t("From your answers, fitted into your %@."), store.gymWords(time.gym ?? 60)) }
      let per = store.minutesWords(time.lostPerRest ?? 0)
      return String(format: store.t(time.share < 1 ? "From your answers: about half of %@ rests × %@." : "From your answers: %@ rests × %@."), "\(time.rests ?? 0)", per)
    case .yearTime: return "Your numbers, multiplied out."
    case .promise: return "Every rest on time. Every set saved."
    case .alerts: return "One buzz, right when it’s time. Change it anytime."
    case .firstWorkout: return store.profile.focusEnabled == true && AppBlocking.shared.ready ? "Starting it locks your apps until you finish." : "Every set is saved as you go."
    case .shield: return "It lifts the moment you finish."
    case .blocking: return blockMessage ?? "Uses Apple’s Screen Time. Ending your workout lifts it."
    case .account: return account.message ?? "Your workouts sync to your account and come back on any iPhone."
    case .splits: return (JourneyLayout.compact ? SplitTemplateStage.summary(template, store: store) : nil) ?? "Change them anytime."
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
    // One stopwatch for the rest question and Rarely's "already ahead", so it stays in place.
    case .restNeed, .ahead:
      RestWatchStage(minutes: step == .ahead ? time.restNeed : restChoice.map { $0 == 0 ? TimeBack.unsureRest : $0 },
                     ahead: step == .ahead, done: step == .ahead ? sceneDone : {})
    case .scrollMinutes: ScrollMinutesStage(minutes: $draft)
    case .perRest: PerRestStage(time: time, done: sceneDone)
    case .exerciseCount: RackStage(count: exerciseChoice)
    case .setCount: LogTallyStage(exercises: baseline.exercises ?? 5, sets: setChoice)
    case .gymTime: GymClockStage(minutes: gymChoice)
    case .workoutTime: WorkTimeStage(time: time, done: sceneDone)
    case .yearTime: ExtraWorkoutsStage(time: time, done: sceneDone)
    case .promise:
      if time.outcome == .unfit { PerRestStage(time: time, giveBack: true, done: sceneDone) }
      else { WorkTimeStage(time: time, giveBack: true, done: sceneDone) }
    case .commit: PlanStage(done: sceneDone)
    case .shield: ShieldStage(done: sceneDone)
    case .blocking: BlockStage(locking: locking, choose: chooseApps)
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
      case .restNeed, .exerciseCount, .setCount, .gymTime:
        JourneyGlassGroup(spacing: JourneyLayout.compact ? 8 : 10) {
          VStack(spacing: JourneyLayout.compact ? 8 : 10) { questionRows }
        }.padding(.bottom, 14)
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: questionAnswered, action: advance)
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
        gated(FingerprintHold(title: store.t("Hold to commit"), holdingTitle: store.t("Keep holding…"), doneTitle: store.t("Committed"), committed: committed,
                   onProgress: { p in
                     let next = min(3, Int(p * 3 + 0.001))
                     if next != pledged { withAnimation(.spring(duration: 0.3)) { pledged = next } }
                   },
                   onComplete: commit))
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
  /// The time-back questions' rows (docs/ONBOARDING-V8-PLAN.md). Selecting only selects.
  @ViewBuilder private var questionRows: some View {
    switch step {
    case .restNeed:
      ForEach([(1.0, "1 min"), (1.5, "1½ min"), (2.0, "2 min"), (3.0, "3 min"), (0.0, "Not sure")], id: \.0) { value, title in
        choice(title, id: "rest.\(value)", selected: restChoice == value) { restChoice = value }
      }
    case .exerciseCount:
      ForEach([(3, "3 or fewer"), (4, "4"), (5, "5"), (6, "6"), (7, "7 or more")], id: \.0) { value, title in
        choice(title, id: "exercises.\(value)", selected: exerciseChoice == value) { exerciseChoice = value }
      }
    case .setCount:
      ForEach([(2, "2"), (3, "3"), (4, "4"), (5, "5 or more")], id: \.0) { value, title in
        choice(title, id: "sets.\(value)", selected: setChoice == value) { setChoice = value }
      }
    case .gymTime:
      ForEach([(45, "45 min"), (60, "1 hour"), (90, "1½ hours"), (120, "2 hours"), (150, "2½ hours or more")], id: \.0) { value, title in
        choice(title, id: "gym.\(value)", selected: gymChoice == value) { gymChoice = value }
      }
    default: EmptyView()
    }
  }
  private var questionAnswered: Bool {
    switch step {
    case .restNeed: return restChoice != nil
    case .exerciseCount: return exerciseChoice != nil
    case .setCount: return setChoice != nil
    case .gymTime: return gymChoice != nil
    default: return true
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
    case .trainingDays: trainingDays = baseline.trainingDays.map { min(7, max(1, $0)) }
    case .splits: template = store.data.workouts.isEmpty ? nil : .keep
    case .gender: gender = store.profile.gender
    case .height: heightCM = store.profile.heightCM ?? bodyDefaults(store.profile.gender).height
    case .weight:
      let p = store.profile
      weightKG = p.bodyWeightKG ?? bodyDefaults(p.gender).weight
      weightUnit = p.bodyWeightKG != nil ? (p.unit == "kg" ? 0 : 1) : heightUnit
    case .restNeed: restChoice = baseline.restNeedUnsure == true ? 0 : baseline.restNeedSeconds.map { Double($0) / 60 }
    // The wheel starts at their own answer, or at one minute: no suggested number.
    case .scrollMinutes: draft = min(15, max(1, (baseline.scrollingMinutes ?? 1).rounded()))
    case .exerciseCount: exerciseChoice = baseline.exercises.map { min(7, max(3, $0)) }
    case .setCount: setChoice = baseline.sets.map { min(5, max(2, $0)) }
    case .gymTime: gymChoice = baseline.duration.map { d in [45, 60, 90, 120, 150].min { abs($0 - d) < abs($1 - d) } ?? 60 }
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
    if step == .restNeed {
      guard let restChoice else { return }
      let unsure = restChoice == 0
      let seconds = Int(((unsure ? TimeBack.unsureRest : restChoice) * 60).rounded())
      // The rest they need is also their rest timer.
      update { $0.restNeedSeconds = seconds; $0.restNeedUnsure = unsure }
      store.updateProfile { $0.restSeconds = seconds }
    }
    if step == .scrollMinutes { update { $0.scrollingMinutes = draft; $0.minutesPerBreak = nil } }
    if step == .exerciseCount { guard let exerciseChoice else { return }; update { $0.exercises = exerciseChoice } }
    if step == .setCount { guard let setChoice else { return }; update { $0.sets = setChoice } }
    if step == .gymTime { guard let gymChoice else { return }; update { $0.duration = gymChoice } }
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
    case .restNeed: props["rest_seconds"] = restChoice.map { Int((($0 == 0 ? TimeBack.unsureRest : $0) * 60).rounded()) }; props["unsure"] = restChoice == 0
    case .scrollMinutes: props["minutes_per_scroll"] = draft
    case .exerciseCount: props["value"] = exerciseChoice
    case .setCount: props["value"] = setChoice
    case .gymTime: props["minutes"] = gymChoice
    case .perRest, .workoutTime, .yearTime, .promise:
      let time = self.time
      props["lost_per_rest"] = time.lostPerRest; props["lost_per_workout"] = time.shownLost; props["outcome"] = "\(time.outcome)"
      props["year_hours"] = time.shownYear; props["extra_workouts"] = time.extraWorkouts
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
    // No tap on every page change: haptics are kept for beats that mean something.
    JourneyScorePlayer.shared.stop()
    // Quick: out in 0.12 s, in with a 0.3 s spring (they read as slow at 0.18 + 0.5 s).
    let out = reduceMotion ? 0.08 : 0.12
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
      withAnimation(.spring(duration: reduceMotion ? 0.12 : 0.3, bounce: 0.08)) { shown = true; slide = 0 }
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
    // Starting the workout has its own beat (the lock); otherwise a success tap.
    if !start { JourneyHaptic.play(.success, store.profile) }
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
      JourneyScorePlayer.shared.play(JourneyScores.startWorkout, profile: store.profile)
      let split = store.data.workouts.first { $0.id == store.profile.preferredSplitID }
      store.startSession(workout: split)
    }
    // Let the last sound finish, then the engines sleep.
    Task { @MainActor in try? await Task.sleep(for: .seconds(1.5)); JourneyScorePlayer.shared.shutDown() }
  }
}
