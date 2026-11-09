import FamilyControls
import SwiftUI

/// Onboarding V10 (docs/ONBOARDING-V10-PLAN.md, 1 Nov 2026): one frame on every page — a round
/// glass Back and a thin progress line, the question left-aligned, one grey line under it, the
/// content in the middle, the one ink Continue at the bottom. Nothing animates while they answer;
/// the pictures live on the interstitials. The numbers and the words are theirs (`TimeBack`).
enum OnboardingStep: String, CaseIterable {
  case welcome, name, trainingDays, source, scrolling, cost, restNeed, scrollMinutes, perRest
  case exerciseCount, setCount, workoutTime, age, yearDots, yearPhone, life, tried, whyFails, shield, promise, words
  // The GymBond code page (8 Nov 2026) sits after the account, before the wall.
  // The GymBuddy invite page (9 Nov 2026) is the setup page after Save your progress.
  case alerts, commit, account, bondCode, bondInvite, trial1, trial2, subscription, youreIn, notifications, screenTime, chooseApps, splits, firstWorkout
  // V8/V9 pages (20 Oct–1 Nov 2026) replaced by V10; saved progress on them resumes at the nearest page.
  case yearTime, blocking, ahead, gymTime
  // Sulav's note, removed on 5 Nov 2026 at the user's request; saved progress on it resumes at the rest alerts.
  case founder
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
    case .gymTime: return .workoutTime  // No longer asked (28 Oct 2026).
    case .yearTime: return .age         // The year became the life number (V10).
    case .blocking: return .alerts      // The apps picker moved to Home (V10), then after the price.
    case .founder: return .alerts       // Sulav's note, removed (5 Nov 2026).
    case .ahead: return .perRest
    case .minutes, .breaks, .frequency, .restHabits, .loggingHabits, .setTiming, .mindMuscle, .restStory, .progressStory, .ready,
         .phoneMinutes, .reveal, .days, .mindA, .mindB, .restA, .restB, .logA, .logB:
      return .restNeed
    default: return self
    }
  }
  /// The account step or later: the answers are worth keeping in the account from here on.
  var reachedAccount: Bool { [.bondCode, .trial1, .trial2, .subscription, .youreIn, .account, .notifications, .screenTime, .chooseApps, .splits, .bondInvite, .firstWorkout].contains(current) }
  /// Pages whose animation must finish before Continue appears.
  var animated: Bool { [.welcome, .yearDots, .yearPhone, .whyFails, .shield, .promise, .words, .youreIn].contains(self) }
  /// Pages that answer on rows in the middle of the screen.
  var question: Bool { [.trainingDays, .source, .scrolling, .cost, .restNeed, .scrollMinutes, .exerciseCount, .setCount, .age, .tried].contains(self) }
  /// Pages whose headline and content are centred (the interstitials), as Cal AI's are.
  var centred: Bool { [.yearDots, .yearPhone, .life, .words, .commit, .trial1, .trial2, .youreIn].contains(self) }
  /// Pages sharing a stage keep their visual in place; only the words change.
  var stage: String {
    switch self {
    case .yearDots, .yearPhone: return "year"
    default: return rawValue
    }
  }
}

enum OnboardingRoute {
  /// The pages their answers lead to (docs/ONBOARDING-V10-PLAN.md). A phone that fits inside the
  /// rest skips the workout, the age and the life pages; answers that don't fit an earlier gym time
  /// get the per-rest promise only. The second trial page needs notifications on.
  static func steps(_ baseline: RoutineBaseline, restAlerts: Bool = false, screenTime: Bool = false, appsChosen: Bool = false) -> [OnboardingStep] {
    var steps: [OnboardingStep] = [.name, .trainingDays, .source, .scrolling, .cost, .restNeed, .scrollMinutes, .perRest]
    let time = TimeBack(baseline)
    let why: [OnboardingStep] = baseline.triedThatFailed.isEmpty ? [] : [.whyFails]
    if time.lostPerRest != 0 {
      steps += [.exerciseCount, .setCount]
      if !time.perRestOnly { steps += [.workoutTime, .age, .yearDots, .yearPhone, .life] }
      // The good news right after the bad (Brainrot's order): the promise, what the time is for, then
      // what they've tried, why it didn't hold, and the shield as the proof.
      steps += [.promise] + (time.perRestOnly ? [] : [.words]) + [.tried] + why + [.shield]
    } else {
      steps += [.promise, .tried] + why + [.shield]
    }
    // The wall: the trial page, the reminder page, the price (Brainrot's three; 1 Nov 2026).
    // Notifications are asked before the commit; allowed there (or already, on a reinstall), they
    // aren't asked again after the price. As SleepBlock's primers (1 Nov 2026), after the price:
    // notifications if still off, then Screen Time and the apps, each left out once iOS has the answer.
    let alerts: [OnboardingStep] = restAlerts ? [] : [.alerts]
    let permissions: [OnboardingStep] = (restAlerts ? [] : [.notifications]) + (screenTime ? [] : [.screenTime]) + (appsChosen ? [] : [.chooseApps])
    // The GymBond code page (8 Nov 2026) right after the account: a friend's code is joined with the
    // account that now exists, and Pro from it skips the wall.
    // No account page before the wall (8 Nov 2026, at the user's request, as Cal AI's flow): a silent
    // account is made at the commit, and "Save your progress" (Apple or Google, or Not now) is the
    // first setup page after the price.
    // The GymBuddy invite (9 Nov 2026, at the user's request) comes after the split is chosen: their code as a gift of two weeks of Pro, or Skip.
    return steps + alerts + [.commit, .bondCode, .trial1, .trial2, .subscription, .youreIn, .account] + permissions + [.splits, .bondInvite, .firstWorkout]
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
  /// The rows' choices before Continue saves them. A rest of 0 is "Not sure".
  @State private var restChoice: Double?
  @State private var scrollChoice: Double?
  @State private var exerciseChoice: Int?
  @State private var setChoice: Int?
  @State private var ageChoice: AgeAnswer?
  @State private var sourceChoice: SourceAnswer?
  @State private var costChoice: Set<CostAnswer> = []
  @State private var triedChoice: Set<TriedAnswer> = []
  @State private var nameDraft = ""
  @State private var trainingDays: Int?
  /// The GymBond code page: the code as typed, and what the server said about it.
  @State private var bondDraft = ""
  @State private var bondStatus: String?
  @State private var bondGood = false
  @State private var bondBusy = false
  @State private var template: SplitTemplate?
  @ObservedObject private var blocking = AppBlocking.shared
  @State private var requestingScreenTime = false
  @State private var picking = false
  @State private var pickDraft = FamilyActivitySelection()
  @State private var setupSteps: [OnboardingStep] = []
  /// iOS's own answer, read on appear and on every return: the saved setting can be stale (synced
  /// from another iPhone, or kept after a reinstall reset the permission), so it never hides the ask.
  @State private var notificationsAllowed: Bool?
  @State private var covered = true
  @State private var ready = true
  /// When the current page appeared, for the minimum time before Continue.
  @State private var pageShownAt = Date()
  /// Page changes run on one clock: everything changing fades out, the page swaps unseen, everything fades in.
  @State private var shown = true
  @State private var stageLeaving = false
  @State private var moving = false
  @State private var finished = false
  @Environment(\.dynamicTypeSize) private var typeSize
  /// Back from Settings on the alerts page: if notifications were turned on there, move on.
  @Environment(\.scenePhase) private var scenePhase
  /// VoiceOver lands on the new question after each page change.
  @AccessibilityFocusState private var questionFocused: Bool
  /// Pages slide a little in the direction of travel as they fade, so Back feels like going back.
  @State private var slide: CGFloat = 0
  @State private var pledged = 0
  @State private var committed = false
  /// The commit page's hold, 0 to 1, and where the fingerprint sits: an emerald circle grows from it
  /// with the hold and floods the page (Brainrot's commit, 1 Nov 2026, at the user's request).
  /// Driven as one animation (0 → 1 over the hold's length, back on release), so the render server
  /// draws every frame: fed from the hold's 40 ms ticks it drew in steps (1 Nov 2026, the user).
  @State private var holdProgress = 0.0
  @State private var holdCenter: CGPoint?
  @State private var flooding = false
  /// The flood is under way: the print draws white, since the flood grows from it.
  private var printFlooded: Bool { step == .commit && (committed || flooding) }
  @MainActor private static var coverShown = false
  private var baseline: RoutineBaseline { store.profile.baseline ?? RoutineBaseline() }
  private var time: TimeBack { TimeBack(baseline, restSeconds: store.profile.restSeconds) }
  private var step: OnboardingStep { OnboardingStep.restored(store.profile) }
  @State private var wallForward = true
  private var route: [OnboardingStep] {
    OnboardingRoute.steps(baseline, restAlerts: notificationsAllowed ?? (store.profile.restAlerts == true), screenTime: blocking.authorized, appsChosen: !blocking.isEmpty)
  }

  var body: some View {
    ZStack {
      DotGrid()
      if step == .commit, let holdCenter {
        CommitFlood(progress: committed ? 1 : holdProgress, center: holdCenter)
      }
      // The price page, warmed up off screen from the wall's first page: RevenueCat's view loads its
      // paywall and images when it's made, and made at the moment of the slide it stalled it (1 Nov 2026).
      if onWall && step != .subscription {
        PaywallView(subscription: subscription, skip: {}, inOnboarding: true, tracked: false)
          .opacity(0).allowsHitTesting(false).accessibilityHidden(true)
      }
      VStack(spacing: 0) {
        // Above the page, so the paywall can run up under it with no band of its own.
        topBar.frame(height: 44).padding(.horizontal, 12).zIndex(1)
        // On the wall the pages slide sideways as a pager (1 Nov 2026, at the user's request); the
        // dots above stay put. Elsewhere a page fades and nudges, as before.
        ZStack {
          Group {
            if step == .subscription {
              // The price: RevenueCat's page (or the app's own), the wall's last page, under the dots.
              PaywallView(subscription: subscription, skip: { move(.youreIn) }, inOnboarding: true)
                .padding(.top, -44)  // Up under the Back button: no bar on the price (1 Nov 2026).
            } else if scrolls {
              // Accessibility text sizes: the page scrolls and its content keeps a usable height.
              ScrollView { VStack(spacing: 0) { page(fixed: false) } }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
            } else {
              VStack(spacing: 0) { page(fixed: true) }
            }
          }
          .id(onWall ? "wall." + step.rawValue : "page")
          .transition(.asymmetric(insertion: .move(edge: wallForward ? .trailing : .leading), removal: .move(edge: wallForward ? .leading : .trailing)))
        }
      }
      // Nothing on a page that's leaving can be tapped (a second tap used to change a saved answer).
      .allowsHitTesting(!moving)
      // The launch screen is the same stage: the first page simply rises into it.
      .opacity(covered ? 0 : 1).offset(y: covered && !reduceMotion ? 10 : 0)
    }
    .coordinateSpace(name: "onboarding")
    .onPreferenceChange(HoldCenterKey.self) { holdCenter = $0 }
    .foregroundStyle(JourneyColor.text)
    .preferredColorScheme(JourneyColor.theme.scheme)
    // Continue waits for the page's animation to finish. Safety net, well past the longest
    // sequence: it still appears if one is interrupted. Leaving the page cancels this task; the
    // sleep's cancellation is swallowed by `try?`, so it must be checked.
    .task(id: step) {
      let page = step
      guard !ready else { return }
      try? await Task.sleep(for: .seconds(20))
      guard !Task.isCancelled else { return }
      markReady(page)
    }
    .environment(\.journeyPress, true)
    // The apps picker as a half sheet, so setup stays in view behind it (as SleepBlock's).
    .sheet(isPresented: $picking, onDismiss: appsPicked) {
      NavigationStack {
        FamilyActivityPicker(headerText: store.t("Most people lock Instagram, TikTok and YouTube."), selection: $pickDraft)
          .navigationTitle(store.t("Choose apps")).navigationBarTitleDisplayMode(.inline)
          .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { picking = false } } }
      }
      .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }
    .onChange(of: step) { old, _ in if old == .youreIn { setupSteps = Array(route.drop { $0 != .youreIn }.dropFirst()) } }
    .onChange(of: step) { old, new in Analytics.leave("onboarding." + old.rawValue); Analytics.enter("onboarding." + new.rawValue, ["step": stepIndex(new)]) }
    .onAppear { Analytics.enter("onboarding." + step.rawValue, ["step": stepIndex(step)]) }
    .onDisappear { Analytics.leave("onboarding." + step.rawValue) }
    // Back from iOS Settings: its answer may have changed either way.
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active, step != .alerts && step != .notifications else { return }
      Task { @MainActor in notificationsAllowed = RestAlert.granted(await RestAlert.status()) }
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active, step == .alerts || step == .notifications else { return }
      Task { @MainActor in
        if RestAlert.granted(await RestAlert.status()) {
          Analytics.track("onboarding_alerts", ["choice": "settings", "granted": true])
          store.updateProfile { $0.restAlerts = true }
          notificationsAllowed = true
          RestAlert.addTrialReminder()
          leaveNotifications()
        }
      }
    }
    .onAppear {
      // What iOS already knows: allowed on a reinstall means the alerts page has nothing to ask.
      Task { @MainActor in
        let allowed = RestAlert.granted(await RestAlert.status())
        notificationsAllowed = allowed
        if allowed, store.profile.restAlerts != true { store.updateProfile { $0.restAlerts = true } }
      }
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
        $0.onboardingVersion = 12
        if $0.focusEnabled == nil { $0.focusEnabled = false }
        if $0.language.isEmpty {
          // The phone's preferred language: Locale.current says English here, because the app doesn't
          // declare a Spanish localization.
          $0.language = Locale.preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
        }
      }
    }
  }

  // MARK: Grid

  /// Pages that scroll: at accessibility text sizes, and on a small phone from the second-largest
  /// standard size up (the welcome and the splits page fit or scroll on their own).
  private var scrolls: Bool {
    (typeSize.isAccessibilitySize || (JourneyLayout.compact && typeSize >= .xxLarge)) && ![.welcome, .youreIn, .notifications, .screenTime, .chooseApps, .splits].contains(step)
  }
  @ViewBuilder private func page(fixed: Bool) -> some View {
    // The welcome scene and You're in carry their own words; every other page has the headline and its line.
    if step != .welcome && step != .youreIn {
      headline.padding(.horizontal, 24).padding(.top, JourneyLayout.compact ? 6 : 12)
        .opacity(shown ? 1 : 0).offset(x: slide)
    }
    ZStack {
      stage.id(step.stage).transition(.identity)
    }.frame(maxWidth: .infinity, minHeight: fixed ? nil : 300, maxHeight: fixed ? .infinity : nil)
      .padding(.horizontal, 24)
      .padding(.vertical, 12)
      // A stage shared by two pages stays put; only a new stage fades and slides.
      .opacity(shown || !stageLeaving ? 1 : 0).offset(x: stageLeaving ? slide : 0)
    Text(caption.map(store.t) ?? " ").font(JourneyType.caption).foregroundStyle(captionColor)
      .multilineTextAlignment(.center).lineLimit(typeSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
      .frame(minHeight: 20).padding(.horizontal, 32)
      // The caption arrives with the page's button, never floating alone over the empty space.
      .opacity(shown && actionsShown ? 1 : 0).offset(x: slide)
      .animation(.smooth(duration: 0.3), value: actionsShown)
      .accessibilityHidden(caption == nil)
    // The hold is taller than Continue; on a phone with no home indicator it keeps the same air below.
    actions.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 6)
      .opacity(shown ? 1 : 0).offset(x: slide * 0.5)
  }
  /// "No payment due now" under the trial pages is the signal; every other caption is grey.
  private var captionColor: Color { [.trial1, .trial2].contains(step) ? JourneyColor.signalText : JourneyColor.secondary }

  /// The pages after the account that lead to the price: one wall, as Brainrot's (1 Nov 2026, at
  /// the user's request). No Back from the first of them, and page dots in place of the line.
  private var wall: [OnboardingStep] { route.filter { [.trial1, .trial2, .subscription].contains($0) } }
  /// Three dots on the wall: the trial page, the price… and a third the price's own page counts as
  /// (Brainrot's three; the reminder page is out, so the paywall takes dots two and three).
  private var onWall: Bool { wall.contains(step) }
  private var topBar: some View {
    ZStack {
      // After the price the line starts again, for the setup alone (1 Nov 2026, at the user's
      // request): none on You're in, then one step per page to the first workout. There's no Back
      // there, so it runs the page's full width, edge to edge with the content.
      if let setupProgress {
        JourneyProgress(value: setupProgress, label: store.t("Progress")).padding(.horizontal, 12)
      } else {
        HStack(spacing: 8) {
          // The wall's first page has no way back to the account; inside the wall, Back steps to its
          // first page (as Brainrot's does, 1 Nov 2026).
          let noBack = step == wall.first || paid
          JourneyBackButton(label: store.t("Go back"), action: back).disabled(account.busy)
            .opacity(noBack ? 0 : 1).allowsHitTesting(!noBack)
          if !onWall && !paid { JourneyProgress(value: progress, label: store.t("Progress")).padding(.horizontal, 8) } else { Spacer() }
          Color.clear.frame(width: 36, height: 36).accessibilityHidden(true)
        }.opacity(step == .welcome ? 0 : 1).allowsHitTesting(step != .welcome)
      }
      // The dots on the bar's own centre (between the Back slot and the spacer they sat a few points
      // off), and up near the top, as Brainrot's.
      // Not on the price itself (1 Nov 2026, at the user's request): only the trial pages show them.
      if onWall && step != .subscription {
        WallDots(count: 3, index: wall.firstIndex(of: step) ?? 0).offset(y: -10)
          .accessibilityLabel(String(format: store.t("Page %@ of %@"), "\((wall.firstIndex(of: step) ?? 0) + 1)", "3"))
      }
      Wordmark().opacity(step == .welcome ? 1 : 0)
    }
  }
  /// The pages after the price: no way back to it, and the setup's own progress line.
  private var paid: Bool { [.youreIn, .account, .notifications, .screenTime, .chooseApps, .splits, .bondInvite, .firstWorkout].contains(step) }
  /// The setup pages after You're in, as the route stood when they left it (a page iOS answers
  /// drops out of the route, which would make the line jump back).
  /// The page on screen always keeps its place, even when iOS has already answered it.
  private var setup: [OnboardingStep] {
    let base = setupSteps.isEmpty ? Array(route.drop { $0 != .youreIn }.dropFirst()) : setupSteps
    return [OnboardingStep.account, .notifications, .screenTime, .chooseApps, .splits, .bondInvite, .firstWorkout].filter { base.contains($0) || $0 == step }
  }
  private var setupProgress: Double? {
    guard paid, let i = setup.firstIndex(of: step) else { return nil }
    return Double(i + 1) / Double(setup.count)
  }
  private var progress: Double {
    let all = [OnboardingStep.welcome] + route
    return Double(all.firstIndex(of: step) ?? 0) / Double(max(1, all.count - 1))
  }
  private func stepIndex(_ step: OnboardingStep) -> Int { ([OnboardingStep.welcome] + route).firstIndex(of: step) ?? 0 }

  /// The question and its line. The box always reserves two headline lines and one line under them,
  /// so every page's content starts at the same height; the words sit at the top of it, the line
  /// right under the question (a one-line question used to float in the middle, half a line off its
  /// subtitle). Left-aligned, centred on the interstitials.
  private var headline: some View {
    headlineBlock(white: false)
      // The commit page: the same words in white, seen only where the flood is, so they turn white
      // exactly as its edge passes them.
      .overlay {
        if step == .commit, let holdCenter {
          GeometryReader { g in
            let f = g.frame(in: .named("onboarding"))
            headlineBlock(white: true).frame(width: g.size.width, height: g.size.height)
              .mask { CommitFloodCircle(progress: committed ? 1 : holdProgress, pageCenter: holdCenter, center: CGPoint(x: holdCenter.x - f.minX, y: holdCenter.y - f.minY)) }
          }.accessibilityHidden(true)
        }
      }
  }
  private func headlineBlock(white: Bool) -> some View {
    let centred = step.centred
    let subtitleFont = Font.app(.subheadline)
    return ZStack(alignment: centred ? .top : .topLeading) {
      // The box reserves two lines and a subtitle, except on the first trial page: one line and no
      // subtitle, so the phone under it gets the same air above as below (1 Nov 2026).
      VStack(alignment: .leading, spacing: 6) {
        Text(step == .trial1 ? "A" : "A\nB").font(headlineFont)
        if step != .trial1 && step != .trial2 { Text("A").font(subtitleFont) }
      }.hidden().accessibilityHidden(true)
      VStack(alignment: centred ? .center : .leading, spacing: 6) {
        headlineText.id(step).transition(.identity).foregroundStyle(white ? Color.white : JourneyColor.text)
        if let subtitle {
          Text(store.t(subtitle)).font(subtitleFont).foregroundStyle(white ? Color.white.opacity(0.85) : JourneyColor.secondary)
            .multilineTextAlignment(centred ? .center : .leading).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }.frame(maxWidth: .infinity, alignment: centred ? .center : .leading)
    }.frame(maxWidth: .infinity)
  }
  private var headlineText: some View {
    Group {
      if step == .trial1 {
        // Brainrot's title, with the free part in the signal colour (1 Nov 2026, at the user's request).
        Text(store.t("Try GymBlock ")) + Text(store.t("for free")).foregroundColor(JourneyColor.signalText)
      } else if let personal {
        Text(personal)
      } else {
        Text(store.t(headlineCopy))
      }
    }.font(headlineFont).tracking(-0.3).multilineTextAlignment(step.centred ? .center : .leading)
      .lineLimit(typeSize.isAccessibilitySize ? nil : [.workoutTime, .promise, .yearDots, .yearPhone, .life].contains(step) ? 3 : 2)
      .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.7).fixedSize(horizontal: false, vertical: true)
      .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
      .accessibilityFocused($questionFocused)
  }
  /// The large title, one step smaller on small screens.
  private var headlineFont: Font { JourneyLayout.compact ? Font.app(.title2, design: .default, weight: .bold) : JourneyType.headline }
  private var headlineCopy: String {
    switch step {
    case .name: return "What should we call you?"
    case .trainingDays: return "How many days a week do you train?"
    case .source: return "Where did you hear about us?"
    case .scrolling: return "Do you check your phone between sets?"
    case .cost: return "And what does that cost you?"
    case .restNeed: return "How long do you rest between sets?"
    case .scrollMinutes: return "How long are you on your phone each time?"
    case .exerciseCount: return "How many exercises do you do per workout?"
    case .setCount: return "And how many sets of each exercise?"
    case .age: return "How old are you?"
    case .yearDots: return "This is your next year at the gym."
    case .tried: return "What have you tried?"
    case .shield: return "This is what you’ll see with GymBlock."
    case .alerts, .notifications: return "We’ll buzz you when your rest is up."
    case .screenTime: return "Lock your apps while you train."
    case .chooseApps: return "Now choose what to lock."
    case .commit: return "Ready to get your time back?"
    case .account: return "Save your progress."
    case .bondInvite: return "Invite a friend to be your GymBuddy."
    case .bondCode: return "Enter referral code (optional)"
    case .trial1: return "Try GymBlock free for 7 days."
    case .trial2: return "We’ll remind you before your trial ends."
    case .splits: return "Let’s set up your training."
    case .firstWorkout: return firstWorkoutHeadline
    default: return "Stay focused with GymBlock."
    }
  }
  /// Headlines built from their name and their own numbers (already translated).
  private var personal: String? {
    let time = self.time
    switch step {
    case .perRest:
      guard let lost = time.lostPerRest else { return nil }
      // The number is the page's big number, so the headline leads into it (one 28, not four).
      return store.t(lost == 0 ? "Then your phone time fits inside your rest." : "Every rest, you lose this much.")
    case .workoutTime:
      return store.t("Every workout, your phone takes this much.")
    case .yearPhone:
      return String(format: store.t("%@ of them go to your phone."), "\(time.yearPhoneWorkouts)")
    case .life:
      return String(format: store.t("That’s %@ of your life."), store.lifeWords(time.lifeLostHours(baseline.age)))
    case .whyFails:
      return store.t(baseline.triedThatFailed.count == 1 ? "Here’s why that didn’t hold." : "Here’s why those didn’t hold.")
    case .promise:
      if (time.lostPerRest ?? 0) == 0 { return store.t("Keep every rest on time.") }
      if time.perRestOnly {
        let lost = time.lostPerRest ?? 0
        return lost == 1 ? store.t("We’ll give you that minute back. Every rest.")
          : String(format: store.t("We’ll give you those %@ back. Every rest."), store.minutesWords(lost))
      }
      // Right after "That's 5 months of your life.": the same months, given back.
      let span = LifeWords.span(hours: time.lifeLostHours(baseline.age))
      return String(format: store.t(span.one ? "We’ll give you that %@ back." : "We’ll give you those %@ back."), store.lifeWords(time.lifeLostHours(baseline.age)))
    case .words:
      let span = LifeWords.span(hours: time.lifeLostHours(baseline.age))
      return String(format: store.t("%@ more %@ of"), span.text, store.t(span.unit))
    default: return nil
    }
  }
  private var firstWorkoutHeadline: String {
    let split = store.data.workouts.first { $0.id == store.profile.preferredSplitID } ?? store.data.workouts.first
    return split.map { String(format: store.t("Ready? Your first workout is %@."), $0.name) } ?? "Ready? Start your first workout."
  }
  /// The grey line under the question.
  private var subtitle: String? {
    let time = self.time
    switch step {
    case .name: return "It’s how we’ll greet you in the app."
    case .trainingDays: return "We’ll set your weekly goal from this."
    case .cost, .tried: return "Pick all that apply."
    case .scrollMinutes: return "Your best guess is fine."
    case .age: return "For one more number."
    case .yearDots:
      return String(format: store.t("Each dot is one workout: %@."), "\(time.yearWorkouts)")
    case .yearPhone:
      guard let session = time.sessionMinutes else { return nil }
      return String(format: store.t("%@ of every %@ minutes, between sets."), "\(time.shownLost)", "\(Int(session))")
    case .life:
      return String(format: store.t("At %@ workouts a week until you’re 65."), "\(time.days)")
    case .promise:
      if (time.lostPerRest ?? 0) == 0 { return "Your phone fits inside your rest. We’ll help you keep it that way." }
      if time.perRestOnly { return store.promiseLine(time, baseline: baseline) ?? "Every rest." }
      return time.lostIsAnHour ? "About an hour back, every workout." : String(format: store.t("%@ minutes back, every workout."), "\(time.shownLost)")
    case .alerts, .notifications: return "One buzz, right when it’s time. Change it anytime."
    case .screenTime: return "GymBlock needs Screen Time to lock them. Calls always work."
    case .chooseApps: return "Pick the apps that pull you in. They stay locked from your first set to your last."
    case .commit: return "Here’s what you’re signing."
    case .account: return account.message ?? "Every workout syncs to your account and comes back on any iPhone."
    case .bondCode: return "You can skip this step."
    case .bondInvite: return "Gift them two weeks of GymBlock Pro. When they join with your code, you get two weeks too."
    case .splits: return "Pick one. Change it anytime."
    default: return nil
    }
  }
  /// The small line above the button, where a page has one.
  private var caption: String? {
    let time = self.time
    switch step {
    case .perRest:
      if time.lostPerRest == 0 { return "We’ll help you keep it that way." }
      return time.restNeed == 1 ? store.t("The first minute was rest you’d take anyway.")
        : String(format: store.t("The first %@ were rest you’d take anyway."), store.minutesWords(time.restNeed))
    case .workoutTime:
      return String(format: store.t("From your answers: %@ rests × %@."), "\(time.rests ?? 0)", store.minutesWords(time.lostPerRest ?? 0))
    case .yearPhone: return "Your numbers, multiplied out."
    case .life: return "Your numbers, multiplied out."
    case .promise: return time.perRestOnly ? nil : store.promiseLine(time, baseline: baseline)
    case .trial1, .trial2: return "✓ No payment due now"
    case .firstWorkout: return store.profile.focusEnabled == true && AppBlocking.shared.ready ? "Starting it locks your apps until you finish." : "Every set is saved as you go."
    case .splits: return JourneyLayout.compact ? SplitTemplateStage.summary(template, store: store) : nil
    default: return nil
    }
  }

  @ViewBuilder private var stage: some View {
    switch step {
    case .welcome: WelcomeScene(done: sceneDone)
    case .name: NameStage(name: $nameDraft) { if canSaveName { advance() } }
    case .trainingDays, .source, .scrolling, .cost, .restNeed, .scrollMinutes, .exerciseCount, .setCount, .age, .tried: questionStage
    case .perRest:
      if (time.lostPerRest ?? 0) > 0 { BigNumberStage(.perRest(time)) } else { RestFitsStage(time: time, done: {}) }
    case .workoutTime: BigNumberStage(.workout(time))
    case .yearDots, .yearPhone: LifeDotsStage(time: time, phase: step == .yearPhone ? .phone : .gym, done: sceneDone)
    case .life: LifeNumberStage(hours: time.lifeLostHours(baseline.age))
    case .whyFails: WhyStage(tried: baseline.triedThatFailed, done: sceneDone)
    // The same film as the first trial page: a set logged, then the lock (1 Nov 2026, at the user's request).
    case .shield: ShieldStage(done: sceneDone, logFirst: true)
    case .promise:
      if (time.lostPerRest ?? 0) == 0 { RestFitsStage(time: time, done: sceneDone) }
      else if time.perRestOnly { PerRestStage(time: time, giveBack: true, done: sceneDone) }
      else { WorkStripStage(time: time, giveBack: true, done: sceneDone) }
    case .words: WordsStage(done: sceneDone)
    // The same page in the sign-up and, if they didn't allow it there, again after the price.
    case .alerts, .notifications:
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        MockPermissionDialog(glyph: "bell.badge", title: store.t("“GymBlock” Would Like to Send You Notifications"),
                             confirm: store.t("Allow"), deny: store.t("Don’t Allow"), denyColor: JourneyColor.tertiary, confirmLeading: false,
                             confirmID: "alerts.on", denyID: "alerts.notNow", onConfirm: allowNotifications, onDeny: {
          Analytics.track("onboarding_alerts", ["choice": "notNow", "granted": false])
          store.updateProfile { $0.restAlerts = false }
          step == .alerts ? next() : moveOn(from: .notifications)
        })
        Spacer(minLength: 0)
      }
    case .screenTime:
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        MockPermissionDialog(glyph: "hourglass", title: store.t("“GymBlock” Would Like to Access Screen Time"),
                             confirm: store.t("Continue"), deny: store.t("Don’t Allow"), busy: requestingScreenTime,
                             confirmID: "screenTime.continue", denyID: "screenTime.notNow", onConfirm: allowScreenTime, onDeny: {
          Analytics.track("onboarding_screen_time", ["choice": "notNow", "granted": false])
          move(.splits)
        })
        Spacer(minLength: 0)
      }
    case .chooseApps: PickerPreview()
    case .commit: CommitPledgeStage(time: time, baseline: baseline, name: store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines), committed: committed)
    case .account:
      // "Save your progress", after the price (8 Nov 2026): Apple or Google link onto the silent
      // account; the buttons in the middle of the page, Not now below.
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        AccountButtons(intent: .link, skip: { moveOn(from: .account) }) { _ in moveOn(from: .account) }
        Spacer(minLength: 0)
      }
    // The first trial page shows the thing itself: the blocking, played on the phone as on the shield page (1 Nov 2026, at the user's request).
    case .bondCode: BondCodeStage(code: $bondDraft, status: bondStatus, good: bondGood, busy: bondBusy, submit: redeemBond)
    case .bondInvite: BondInviteStage()
    case .trial1: ShieldStage(done: {}, logFirst: true, small: true)
    case .trial2: TrialBellStage()
    case .youreIn: YoureInStage(name: store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines), done: sceneDone)
    case .splits: SplitTemplateStage(choice: $template)
    case .firstWorkout: FirstWorkoutStage()
    default: Color.clear
    }
  }
  /// The question pages' answers: glass rows in the middle of the screen, as Cal AI lays them out.
  private var questionStage: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      JourneyGlassGroup(spacing: JourneyLayout.compact ? 8 : 10) {
        VStack(spacing: JourneyLayout.compact ? 8 : 10) { questionRows }
      }
      Spacer(minLength: 0)
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
      case .welcome:
        gated(JourneyButton(title: store.t("Get started"), id: "onboarding.continue", enabled: ready) { move(.name) })
        JourneyTextButton(title: store.t("I already have an account"), id: "welcome.signIn", action: onSignIn)
          .opacity(ready ? 1 : 0).allowsHitTesting(ready).accessibilityHidden(!ready)
      case .name:
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: canSaveName, action: advance)
        Color.clear.frame(height: 44)
      case .trainingDays, .source, .scrolling, .cost, .restNeed, .scrollMinutes, .exerciseCount, .setCount, .age, .tried:
        JourneyButton(title: store.t("Continue"), id: "onboarding.continue", enabled: questionAnswered, action: advance)
        Color.clear.frame(height: 44)
      case .alerts, .notifications, .screenTime:
        // The drawn prompt's own buttons carry the page (1 Nov 2026, at the user's request); the
        // footprint stays so the page's bottom matches the others. (App Review 5.1.1(iv), 17 Oct 2026,
        // wanted the system request to be the only way on; Not now skips it.)
        Color.clear.frame(height: 50)
        Color.clear.frame(height: 44)
      case .account:
        // The buttons are on the stage; Not now keeps the silent account (Settings offers the link again).
        Color.clear.frame(height: 50)
        JourneyTextButton(title: store.t("Not now"), id: "account.notNow") {
          Analytics.track("onboarding_account", ["choice": "notNow"])
          moveOn(from: .account)
        }
      case .bondInvite:
        // The share sheet is the page's button; Skip keeps the code for Profile's GymBond page.
        BondShareButton(title: store.t("Invite a friend"), id: "bond.invite.share")
        JourneyTextButton(title: store.t("Skip"), id: "bond.invite.skip") {
          Analytics.track("bond_invite_skipped")
          move(.firstWorkout)
        }
      case .bondCode:
        // Submit sits in the field's row; Skip is the page's button, as Cal AI's (8 Nov 2026).
        JourneyButton(title: store.t("Skip"), id: "bond.skip", enabled: !bondBusy) {
          Analytics.track("bond_skipped")
          dismissKeyboard()
          move(.trial1)
        }
        Color.clear.frame(height: 44)
      case .commit:
        FingerprintHold(title: store.t("Hold to sign"), holdingTitle: store.t("Keep holding…"), doneTitle: store.t("Signed"), committed: committed,
                        onProgress: { p in
                          let next = min(3, Int(p * 3 + 0.001))
                          if next != pledged { withAnimation(.spring(duration: 0.3)) { pledged = next } }
                          // One animation per hold, the print's own length; let go and it rewinds with the print.
                          if p == 0 {
                            flooding = false
                            withAnimation(.easeOut(duration: 0.4)) { holdProgress = 0 }
                          } else if !flooding {
                            flooding = true
                            withAnimation(.linear(duration: FingerprintHold.duration)) { holdProgress = 1 }
                          }
                        },
                        onComplete: commit, hint: store.t("Double-tap to sign."), light: printFlooded)
          .background(GeometryReader { g in
            Color.clear.preference(key: HoldCenterKey.self, value: CGPoint(x: g.frame(in: .named("onboarding")).midX, y: g.frame(in: .named("onboarding")).minY + (JourneyLayout.compact ? 52 : 58)))
          })
      case .words:
        // Grey until the third word has shown (9 Nov 2026, at the user's request), not hidden.
        JourneyButton(title: store.t("Let’s do this"), id: "onboarding.continue", enabled: ready, action: advance)
        Color.clear.frame(height: 44)
      // The wall's pages have no secondary, so the button sits lower, in its slot (1 Nov 2026, at the user's request).
      case .trial1:
        // "Try for $0.00", as Brainrot's, always (1 Nov 2026, the user's call: not the store's currency, not a fallback).
        JourneyButton(title: store.t("Try for $0.00"), id: "trial.try", action: advance).padding(.bottom, 8)
      case .trial2:
        JourneyButton(title: store.t("Continue for free"), id: "trial.continue", action: advance).padding(.bottom, 8)
      case .subscription:
        // RootView shows the offer in place of this page.
        EmptyView()
      case .youreIn:
        gated(JourneyButton(title: store.t("Set up my account"), trailingSymbol: "arrow.right", id: "onboarding.continue", enabled: ready, action: advance))
        Color.clear.frame(height: 44)
      case .chooseApps:
        JourneyButton(title: store.t("Choose apps"), id: "apps.choose") {
          Analytics.track("onboarding_apps", ["choice": "open"])
          pickDraft = blocking.selection
          picking = true
        }
        JourneyTextButton(title: store.t("Not now"), id: "apps.notNow") {
          Analytics.track("onboarding_apps", ["choice": "notNow"])
          move(.splits)
        }
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
  /// Whether the page's button is showing: on a question once they've answered, elsewhere once the
  /// scene has finished (always, for VoiceOver). The caption follows it.
  private var actionsShown: Bool {
    if UIAccessibility.isVoiceOverRunning { return true }
    return step.question ? questionAnswered : ready
  }
  /// Shows a page's button once `shown` (the scene has finished, unless the page says otherwise).
  private func gated<Button: View>(_ button: Button, when shown: Bool? = nil) -> some View {
    // VoiceOver users get it straight away: the scene is described, and a button that appears
    // silently after it was never found.
    let on = (shown ?? ready) || UIAccessibility.isVoiceOverRunning
    return button.opacity(on ? 1 : 0).offset(y: on ? 0 : 8).allowsHitTesting(on).accessibilityHidden(!on)
      .animation(.smooth(duration: 0.3), value: on)
  }
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

  /// A friend's code: joined, their two weeks of Pro are asked for again from RevenueCat, and the
  /// wall is skipped once Pro has landed; otherwise on to the trial pages (the gift lands with the
  /// hourly run and the price page steps aside by itself).
  private func redeemBond() {
    guard !bondBusy, !moving, GymBond.normalize(bondDraft).count == 6 else { return }
    bondBusy = true
    dismissKeyboard()
    Task { @MainActor in
      // The silent account from the commit page may have failed (offline then); one more try now.
      if account.state != .signedIn { await account.signInAnonymously() }
      switch await GymBond.shared.redeem(bondDraft, from: "onboarding", t: store.t) {
      case .bonded(let name, _):
        bondGood = true
        bondStatus = String(format: store.t("You’re bonded with %@."), name)
        JourneyHaptic.play(.success, store.profile)
        await subscription.refresh()
        bondBusy = false
        try? await Task.sleep(for: .seconds(1.4))
        guard step == .bondCode else { return }
        move(subscription.hasAccess ? .youreIn : .trial1)
      case .failed(let message):
        bondGood = false
        bondStatus = message
        bondBusy = false
      }
    }
  }

  private func commit() {
    guard !committed else { return }
    withAnimation(JourneyMotion.gentle) { committed = true; pledged = 3; holdProgress = 1 }
    Analytics.track("onboarding_committed", ["hold_ms": Int(Date().timeIntervalSince(pageShownAt) * 1000)])
    store.updateProfile { $0.onboardingStoryStage = 1 }
    JourneyScorePlayer.shared.play(JourneyScores.committed, profile: store.profile)
    Task { @MainActor in
      // The silent account is made while the signature is written (8 Nov 2026); offline, the phone
      // carries on and RootView tries again at the next launch.
      async let made = account.signInAnonymously()
      // Long enough to see the signature written and read it (1 Nov 2026).
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 200 : 1900))
      _ = await made
      if step == .commit { move(.bondCode) }
    }
  }

  /// The rows, one question at a time. Selecting only selects; Continue moves on.
  @ViewBuilder private var questionRows: some View {
    switch step {
    case .trainingDays:
      ForEach(DaysRange.allCases, id: \.self) { r in
        iconChoice(r.title, detail: r.detail, id: "days.\(r.days)", selected: trainingDays == r.days, icon: DotsIcon(count: r.dots)) { trainingDays = r.days }
      }
    case .source:
      ForEach(SourceAnswer.allCases, id: \.self) { s in
        iconChoice(s.title, detail: nil, id: "source.\(s.rawValue)", selected: sourceChoice == s, icon: SourceIcon(source: s)) { sourceChoice = s }
      }
    case .scrolling:
      ForEach(HabitAnswer.allCases, id: \.self) { a in
        choice(a == .yes ? "Every rest" : a == .sometimes ? "Sometimes" : "Rarely", id: "habit.scrolling.\(a.rawValue)", selected: baseline.scrollFrequency == a) {
          update { $0.scrollFrequency = a; $0.scrollsBetweenSets = a != .no }
        }
      }
    case .cost:
      ForEach(CostAnswer.offered, id: \.self) { a in
        choice(a.title, id: "cost.\(a.rawValue)", selected: costChoice.contains(a)) { costChoice = Self.toggled(costChoice, a, none: .notMuch) }
      }
    case .restNeed:
      ForEach([(1.0, "1 minute"), (1.5, "1.5 minutes"), (2.0, "2 minutes"), (3.0, "3 minutes"), (0.0, "Not sure")], id: \.0) { value, title in
        choice(title, id: "rest.\(value)", selected: restChoice == value) { restChoice = value }
      }
    case .scrollMinutes:
      ForEach(scrollRows, id: \.0) { value, title in
        choice(title, id: "scroll.\(Int(value))", selected: scrollChoice == value) { scrollChoice = value }
      }
    case .exerciseCount:
      ForEach([(3, "3 or fewer"), (4, "4"), (5, "5"), (6, "6"), (7, "7 or more")], id: \.0) { value, title in
        choice(title, id: "exercises.\(value)", selected: exerciseChoice == value) { exerciseChoice = value }
      }
    case .setCount:
      ForEach([(2, "2"), (3, "3"), (4, "4"), (5, "5 or more")], id: \.0) { value, title in
        choice(title, id: "sets.\(value)", selected: setChoice == value) { setChoice = value }
      }
    case .age:
      ForEach(AgeAnswer.allCases, id: \.self) { a in
        choice(a.title, id: "age.\(a.rawValue)", selected: ageChoice == a) { ageChoice = a }
      }
    case .tried:
      ForEach(TriedAnswer.allCases, id: \.self) { a in
        choice(a.title, id: "tried.\(a.rawValue)", selected: triedChoice.contains(a)) { triedChoice = Self.toggled(triedChoice, a, none: .nothing) }
      }
    default: EmptyView()
    }
  }
  /// The phone-minute rows start a whole minute above the rest they picked (28 Oct 2026, the user's
  /// rule for the wheel; 1.5 minutes of rest starts them at 3), so no row can fit inside the rest.
  private var scrollRows: [(Double, String)] {
    let all: [(Double, String)] = [(2, "About 2 minutes"), (3, "About 3 minutes"), (4, "About 4 minutes"), (6, "About 6 minutes"), (8, "About 8 minutes"), (10, "10 minutes or more")]
    let floor = min(10, (time.restNeed + 1).rounded(.up))
    return all.filter { $0.0 >= floor }
  }
  private var questionAnswered: Bool {
    switch step {
    case .trainingDays: return trainingDays != nil
    case .source: return sourceChoice != nil
    case .scrolling: return baseline.scrollFrequency != nil
    case .cost: return !costChoice.isEmpty
    case .restNeed: return restChoice != nil
    case .scrollMinutes: return scrollChoice != nil
    case .exerciseCount: return exerciseChoice != nil
    case .setCount: return setChoice != nil
    case .age: return ageChoice != nil
    case .tried: return !triedChoice.isEmpty
    default: return true
    }
  }
  /// A multi-select tap: the pick toggles; the "none" answer clears the rest and is cleared by them.
  private static func toggled<A: Hashable>(_ set: Set<A>, _ a: A, none: A) -> Set<A> {
    var picks = set
    if picks.contains(a) { picks.remove(a); return picks }
    if a == none { return [a] }
    picks.remove(none); picks.insert(a)
    return picks
  }
  /// Selecting only selects. Continue moves on — nothing jumps away mid-thought.
  private func choice(_ title: String, id: String, selected: Bool, apply: @escaping () -> Void) -> some View {
    JourneyOption(title: store.t(title), selected: selected, id: id) {
      withAnimation(JourneyMotion.gentle) { apply() }
      JourneyHaptic.play(.selection, store.profile)
    }
  }
  private func iconChoice<Icon: View>(_ title: String, detail: String?, id: String, selected: Bool, icon: Icon, apply: @escaping () -> Void) -> some View {
    JourneyIconOption(title: store.t(title), detail: detail.map(store.t), selected: selected, id: id, icon: icon) {
      withAnimation(JourneyMotion.gentle) { apply() }
      JourneyHaptic.play(.selection, store.profile)
    }
  }
  private var canSaveName: Bool { !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

  private func prepare() {
    switch step {
    case .name: nameDraft = store.profile.name
    case .trainingDays: trainingDays = baseline.trainingDays.flatMap { d in DaysRange.allCases.first { $0.days == d }?.days }
    case .source: sourceChoice = baseline.source
    case .splits: template = store.data.workouts.isEmpty ? nil : .keep
    case .restNeed: restChoice = baseline.restNeedUnsure == true ? 0 : baseline.restNeedSeconds.map { Double($0) / 60 }
    case .scrollMinutes: scrollChoice = baseline.scrollingMinutes.flatMap { m in scrollRows.contains { $0.0 == m } ? m : nil }
    case .exerciseCount: exerciseChoice = baseline.exercises.map { min(7, max(3, $0)) }
    case .setCount: setChoice = baseline.sets.map { min(5, max(2, $0)) }
    case .age: ageChoice = baseline.age
    case .cost: costChoice = Set(baseline.costs ?? [])
    case .tried: triedChoice = Set(baseline.tried ?? [])
    case .commit: pledged = 0; committed = false; holdProgress = 0; flooding = false
    case .bondCode: bondDraft = ""; bondStatus = nil; bondGood = false; bondBusy = false
    default: break
    }
  }
  private func advance() {
    // A second tap while the page is leaving would save and log the answer twice.
    guard !moving else { return }
    if step == .name {
      guard canSaveName else { return }
      let name = String(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
      store.updateProfile { $0.name = name }
      dismissKeyboard()
    }
    if step == .trainingDays { guard let trainingDays else { return }; update { $0.trainingDays = trainingDays } }
    if step == .source { guard let sourceChoice else { return }; update { $0.source = sourceChoice } }
    if step == .cost { guard !costChoice.isEmpty else { return }; update { $0.costs = CostAnswer.allCases.filter(costChoice.contains) } }
    if step == .restNeed {
      guard let restChoice else { return }
      let unsure = restChoice == 0
      let seconds = Int(((unsure ? TimeBack.unsureRest : restChoice) * 60).rounded())
      // The rest they need is also their rest timer.
      update { $0.restNeedSeconds = seconds; $0.restNeedUnsure = unsure }
      store.updateProfile { $0.restSeconds = seconds }
    }
    if step == .scrollMinutes { guard let scrollChoice else { return }; update { $0.scrollingMinutes = scrollChoice; $0.minutesPerBreak = nil } }
    if step == .exerciseCount { guard let exerciseChoice else { return }; update { $0.exercises = exerciseChoice } }
    if step == .setCount { guard let setChoice else { return }; update { $0.sets = setChoice } }
    if step == .age { guard let ageChoice else { return }; update { $0.age = ageChoice } }
    if step == .tried { guard !triedChoice.isEmpty else { return }; update { $0.tried = TriedAnswer.allCases.filter(triedChoice.contains) } }
    trackAnswer()
    next()
  }
  /// What each question page was answered with. Never the name itself.
  private func trackAnswer() {
    var props: [String: Any?] = ["question": step.rawValue]
    switch step {
    case .name: props["answered"] = true
    case .trainingDays: props["value"] = trainingDays
    case .source: props["value"] = sourceChoice?.rawValue
    case .scrolling: props["value"] = baseline.scrollFrequency?.rawValue
    case .cost: props["value"] = CostAnswer.allCases.filter(costChoice.contains).map(\.rawValue).joined(separator: ",")
    case .restNeed: props["rest_seconds"] = restChoice.map { Int((($0 == 0 ? TimeBack.unsureRest : $0) * 60).rounded()) }; props["unsure"] = restChoice == 0
    case .scrollMinutes: props["minutes_per_scroll"] = scrollChoice
    case .exerciseCount: props["value"] = exerciseChoice
    case .setCount: props["value"] = setChoice
    case .age: props["value"] = ageChoice?.rawValue
    case .tried: props["value"] = TriedAnswer.allCases.filter(triedChoice.contains).map(\.rawValue).joined(separator: ",")
    case .perRest, .workoutTime, .life, .promise:
      let time = self.time
      props["lost_per_rest"] = time.lostPerRest; props["lost_per_workout"] = time.shownLost; props["outcome"] = "\(time.outcome)"
      props["life_hours"] = Int(time.lifeLostHours(baseline.age)); props["life_years"] = time.lifeYears(baseline.age)
    default: return
    }
    Analytics.track("onboarding_answer", props)
  }
  private func next() {
    if let index = route.firstIndex(of: step), index + 1 < route.count { move(route[index + 1]) }
  }
  private func back() {
    // The wall's first page has no way back (its button is hidden; this covers a swipe).
    guard step != wall.first, !paid else { return }
    if step == .name { dismissKeyboard(); move(.welcome); return }
    if let index = route.firstIndex(of: step), index > 0 { move(route[index - 1]) }
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
    // Within the wall: one sideways slide, the old page leaving as the new one arrives.
    if wall.contains(step) && wall.contains(next) && !reduceMotion {
      wallForward = forward
      withAnimation(.spring(duration: 0.35, bounce: 0)) {
        ready = !next.animated
        pageShownAt = Date()
        store.updateProfile { $0.onboardingStepID = next.rawValue; $0.onboardingStoryStage = 0 }
        prepare()
      }
      Task { @MainActor in
        try? await Task.sleep(for: .seconds(0.35))
        moving = false
        if UIAccessibility.isVoiceOverRunning { questionFocused = true }
      }
      return
    }
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
      // VoiceOver reads the new question, rather than staying on a button that's gone.
      if UIAccessibility.isVoiceOverRunning { questionFocused = true }
    }
  }
  private func update(_ body: (inout RoutineBaseline) -> Void) {
    store.updateProfile {
      var baseline = $0.baseline ?? RoutineBaseline()
      body(&baseline); baseline.goalMinutesPerBreak = nil; baseline.reductionGoal = nil
      $0.baseline = baseline; $0.onboardingPreviewTarget = nil
    }
  }
  /// The permission pages in order; from one, the next still in the route (one iOS has already
  /// answered drops out of it), else the splits.
  private func moveOn(from page: OnboardingStep) {
    let order: [OnboardingStep] = [.account, .notifications, .screenTime, .chooseApps, .splits]
    let later = order.drop { $0 != page }.dropFirst()
    move(later.first { route.contains($0) } ?? .splits)
  }
  private func allowNotifications() {
    Task { @MainActor in
      let status = await RestAlert.status()
      switch status {
      case .notDetermined:
        let granted = await RestAlert.requestPermission()
        Analytics.track("onboarding_alerts", ["choice": "asked", "granted": granted])
        store.updateProfile { $0.restAlerts = granted }
        notificationsAllowed = granted
        // The trial reminder was set at the purchase, before notifications were allowed.
        if granted { RestAlert.addTrialReminder() }
        granted ? leaveNotifications() : (step == .alerts ? next() : moveOn(from: .notifications))
      case .denied:
        // iOS won't ask again: Settings is the only place to turn it on. The page waits for them.
        Analytics.track("onboarding_alerts", ["choice": "settings", "granted": false])
        if let url = URL(string: UIApplication.openSettingsURLString) { _ = await UIApplication.shared.open(url) }
      default:
        store.updateProfile { $0.restAlerts = true }
        notificationsAllowed = true
        RestAlert.addTrialReminder()
        leaveNotifications()
      }
    }
  }
  /// Allowed: the page leaves the route, so the next page is named rather than looked up.
  private func leaveNotifications() {
    if step == .alerts { move(.commit) } else if step == .notifications { moveOn(from: .notifications) }
  }
  /// Screen Time first, then the apps, as two asks (SleepBlock's lesson: the picker appearing the
  /// moment access landed never said what it was for). Declined, the splits; Home keeps the card.
  private func allowScreenTime() {
    guard !requestingScreenTime else { return }
    requestingScreenTime = true
    Task { @MainActor in
      let granted = await blocking.requestAccess()
      requestingScreenTime = false
      Analytics.track("onboarding_screen_time", ["choice": "asked", "granted": granted])
      if step == .screenTime { move(granted ? .chooseApps : .splits) }
    }
  }
  /// The picker closed: whatever they ticked is kept and turns blocking on, then the splits.
  private func appsPicked() {
    let first = blocking.isEmpty
    blocking.choose(pickDraft)
    if first, !blocking.isEmpty { store.updateProfile { $0.focusEnabled = true } }
    Analytics.track("onboarding_apps", ["choice": "closed", "apps": blocking.apps, "categories": blocking.categories])
    if step == .chooseApps { move(.splits) }
  }

  /// After the offer: the chosen template becomes splits (existing ones are kept), then the first workout.
  private func applyTemplate() {
    guard !moving else { return }
    guard let template else { return }
    if template != .keep {
      for (i, (name, ids)) in template.splits.enumerated() {
        let exercises = SplitTemplate.exercises(ids)
        let localized = store.t(name)
        guard !store.data.workouts.contains(where: { $0.name.localizedCaseInsensitiveCompare(localized) == .orderedSame }) else { continue }
        _ = store.saveSplit(id: UUID(), name: localized, exercises: exercises, color: SplitTemplate.colors[i % SplitTemplate.colors.count])
      }
    }
    if let first = store.data.workouts.first, template != SplitTemplate.none { store.updateProfile { $0.preferredSplitID = first.id } }
    Analytics.track("onboarding_answer", ["question": "splits", "value": template.rawValue, "splits": store.data.workouts.count])
    move(.bondInvite)
  }
  /// The end of onboarding: into the app, with the first split (if any) lined up on Home, or
  /// straight into it.
  private func finish(skipped: Bool, start: Bool = false) {
    guard !moving, !finished else { return }
    finished = true
    // Starting the workout has its own beat (the lock); otherwise a success tap.
    if !start { JourneyHaptic.play(.success, store.profile) }
    let p = store.profile
    OnboardingAnalytics.completed([
      "splits": store.data.workouts.count, "splits_skipped": skipped, "blocking": p.focusEnabled, "rest_alerts": p.restAlerts,
      "subscribed": subscription.hasAccess, "signed_in": account.state == .signedIn && !account.isAnonymous, "anonymous": account.isAnonymous, "pages": route.count + 1,
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

/// Where the commit page's fingerprint is, in the page's coordinate space.
struct HoldCenterKey: PreferenceKey {
  static var defaultValue: CGPoint? = nil
  static func reduce(value: inout CGPoint?, nextValue: () -> CGPoint?) { value = nextValue() ?? value }
}

/// The emerald that floods the commit page as they hold: a circle growing from the fingerprint,
/// wide enough at 1 to cover the far corners. Behind the words and the card; the words turn white
/// once it reaches them.
struct CommitFlood: View {
  let progress: Double
  let center: CGPoint
  var body: some View {
    CommitFloodCircle(progress: progress, pageCenter: center, center: center).foregroundStyle(JourneyColor.signal)
      .ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
  }
}

/// The flood's circle: `pageCenter` sizes it (the far corners of the screen from the fingerprint),
/// `center` places it in whatever view draws it. Its frame animates, so a hold is one smooth sweep.
struct CommitFloodCircle: View {
  let progress: Double
  let pageCenter: CGPoint
  let center: CGPoint
  var body: some View {
    let s = UIScreen.main.bounds.size
    let reach = 2 * hypot(max(pageCenter.x, s.width - pageCenter.x), max(pageCenter.y, s.height - pageCenter.y)) + 40
    let d = reach * min(1, max(0, progress))
    Circle().frame(width: d, height: d).position(center)
  }
}

/// The wall's page dots: the current page a short ink bar, the others small grey dots.
struct WallDots: View {
  let count: Int
  let index: Int
  var body: some View {
    HStack(spacing: 7) {
      ForEach(0..<max(1, count), id: \.self) { i in
        Capsule().fill(i == index ? JourneyColor.text : JourneyColor.ink(0.2))
          .frame(width: i == index ? 22 : 7, height: 7)
      }
    }
    .animation(.smooth(duration: 0.3), value: index)
    .accessibilityElement()
  }
}
