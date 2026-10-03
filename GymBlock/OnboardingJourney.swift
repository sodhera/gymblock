import SwiftUI

enum OnboardingStep: String, CaseIterable {
  case welcome, frequency, duration, reps, sets, exercises, scrolling, minutes
  case restHabits, loggingHabits, setTiming, reveal, restStory, progressStory, ready
  case routine  // Decode-only route from the previous grouped question.
  static func restored(_ profile: Profile) -> Self {
    if let id = profile.onboardingStepID, let step = Self(rawValue: id) {
      return step == .routine ? .reps : step
    }
    let old: [Self] = [.welcome, .frequency, .duration, .reps, .scrolling, .reveal, .ready]
    let result = old[min(max(profile.onboardingStep, 0), old.count - 1)]
    return result == .reveal && profile.baseline?.canReveal != true ? .ready : result
  }
}

struct OnboardingView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var draft = 3.0
  @State private var didEdit = false
  @State private var visible = true
  @State private var transitioning = false
  @State private var transitionTask: Task<Void, Never>?
  @State private var artTask: Task<Void, Never>?
  @State private var artProgress = 0.0
  @State private var detail: JourneyDetail?
  @State private var markReady = false
  @State private var bridge = 0.0
  @State private var bridgeValue = ""
  @State private var showBridge = false
  private var step: OnboardingStep { OnboardingStep.restored(store.profile) }
  private var baseline: RoutineBaseline { store.profile.baseline ?? RoutineBaseline() }
  private var storyStage: Int { store.profile.onboardingStoryStage ?? 0 }
  private var needsBreaks: Bool {
    step == .reveal && baseline.scrollFrequency == .sometimes && baseline.scrollingBreaks == nil
  }
  private var route: [OnboardingStep] {
    var result: [OnboardingStep] = [.frequency, .duration]
    if !baseline.timed { result += [.reps, .sets, .exercises] }
    result += [.scrolling]
    if baseline.scrollFrequency == .yes || baseline.scrollFrequency == .sometimes
      || baseline.scrollsBetweenSets == true
    {
      result += [.minutes]
    }
    return result + [
      .restHabits, .loggingHabits, .setTiming, .reveal, .restStory, .progressStory, .ready,
    ]
  }
  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        VStack(spacing: 0) {
          chrome.padding(.horizontal, 24).padding(.top, 8)
          ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
              if step != .welcome && step != .reveal {
                Text(store.t(question)).font(GymType.title(28)).multilineTextAlignment(.center)
                  .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
              }
              scene(compact: geometry.size.height < 700)
            }.padding(.horizontal, 24).padding(.vertical, 24)
              .frame(maxWidth: .infinity).frame(minHeight: max(0, geometry.size.height - 152))
              .opacity(visible ? 1 : 0)
          }
          actions.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
        }
      }.overlay {
        if showBridge {
          JourneyTrace(value: bridgeValue, progress: bridge).allowsHitTesting(false)
            .accessibilityHidden(true)
        }
      }.background(
        OnboardingStage(depth: Double(route.firstIndex(of: step) ?? 0) / Double(route.count))
      )
      .toolbar(.hidden, for: .navigationBar)
      .sheet(item: $detail) { item in
        switch item {
        case .estimate: JourneyEstimateEditor()
        case .rest: JourneyResearchSheet()
        case .focus: FocusPreview()
        case .record: JourneyRecordSheet()
        }
      }
      .onAppear {
        prepare()
        let restored = step
        store.updateProfile {
          $0.onboardingStepID = restored.rawValue
          $0.onboardingVersion = 4
          if $0.focusEnabled == nil { $0.focusEnabled = false }
          if $0.language.isEmpty {
            $0.language = Locale.current.language.languageCode?.identifier == "es" ? "es" : "en"
          }
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.65)) { markReady = true }
        animateArt()
      }
      .onChange(of: scenePhase) { _, phase in
        if phase != .active {
          transitionTask?.cancel()
          artTask?.cancel()
          OnboardingFeedback.shared.cancel()
          showBridge = false
          visible = true
          transitioning = false
          artProgress = 1
        }
      }
      .onDisappear {
        transitionTask?.cancel()
        artTask?.cancel()
        OnboardingFeedback.shared.cancel()
      }
    }
  }
  private var chrome: some View {
    HStack(spacing: 18) {
      Button {
        back()
      } label: {
        Image(systemName: "chevron.left").frame(width: 44, height: 44)
      }
      .buttonStyle(OnboardingGlassStyle()).disabled(step == .welcome || transitioning)
      .opacity(step == .welcome ? 0 : 1).accessibilityLabel(store.t("Back"))
      .accessibilityIdentifier("onboarding.back")
      if step == .welcome {
        Spacer()
      } else {
        HStack(spacing: 5) {
          ForEach(0..<3) { chapter in
            GeometryReader { g in
              Capsule().fill(GymColor.ink.opacity(0.08))
              Capsule().fill(GymColor.red).frame(width: g.size.width * chapterProgress(chapter))
            }.frame(height: 3)
          }
        }.accessibilityLabel(store.t("Setup progress"))
          .accessibilityValue(
            store.t(
              step == .reveal || step == .restStory || step == .progressStory || step == .ready
                ? "Your next month"
                : [.restHabits, .loggingHabits, .setTiming, .scrolling, .minutes].contains(step)
                  ? "Your habits" : "Your training"))
      }
      Menu {
        if step != .welcome && step != .ready {
          Button(store.t("Skip this question")) { skip() }.accessibilityIdentifier(
            "onboarding.skip")
        }
        if [.reps, .sets, .exercises].contains(step) {
          Button(store.t("Varies")) { skip() }.accessibilityIdentifier("baseline.varies")
        }
        if step == .reps {
          Button(store.t("Mostly timed")) {
            update { $0.timed = true }
            move(.scrolling)
          }.accessibilityIdentifier("baseline.timed")
        }
        if [.reveal, .restStory, .progressStory].contains(step) {
          Button(store.t("Replay")) {
            setStoryStage(0)
            animateArt()
          }
        }
        Button(store.t("Just train")) { finish(start: true, skip: true) }
        if step == .ready { Button(store.t("Focus demo")) { detail = .focus } }
        Picker(
          store.t("Language"),
          selection: Binding(
            get: { store.profile.language },
            set: { language in store.updateProfile { $0.language = language } })
        ) {
          Text("English").tag("en")
          Text("Español").tag("es")
        }
        Button(store.t(store.profile.soundEnabled == false ? "Enable sounds" : "Mute sounds")) {
          store.updateProfile { $0.soundEnabled = !($0.soundEnabled ?? true) }
          OnboardingFeedback.shared.cancel()
        }.accessibilityIdentifier("onboarding.sound")
        Button(store.t(store.profile.hapticsEnabled == false ? "Enable haptics" : "Mute haptics")) {
          store.updateProfile { $0.hapticsEnabled = !($0.hapticsEnabled ?? true) }
        }
      } label: {
        Image(systemName: "ellipsis").frame(width: 44, height: 44)
      }
      .buttonStyle(OnboardingGlassStyle()).accessibilityLabel(store.t("Options"))
      .accessibilityIdentifier("onboarding.options")
    }.foregroundStyle(GymColor.ink).frame(height: 44)
  }
  private func chapterProgress(_ chapter: Int) -> Double {
    let training = route.filter { [.frequency, .duration, .reps, .sets, .exercises].contains($0) }
    let habits = route.filter {
      [.scrolling, .minutes, .restHabits, .loggingHabits, .setTiming].contains($0)
    }
    if training.contains(step) {
      return chapter == 0
        ? Double((training.firstIndex(of: step) ?? 0) + 1) / Double(training.count) : 0
    }
    if habits.contains(step) {
      return chapter == 0
        ? 1
        : chapter == 1 ? Double((habits.firstIndex(of: step) ?? 0) + 1) / Double(habits.count) : 0
    }
    return chapter < 2
      ? 1 : step == .ready ? 1 : step == .progressStory ? 0.75 : step == .restStory ? 0.5 : 0.25
  }
  private var question: String {
    switch step {
    case .welcome: return "GymBlock"
    case .frequency: return "How many days a week do you work out?"
    case .duration: return "How long is a usual visit?"
    case .reps, .routine: return "On average, how many reps per set?"
    case .sets: return "How many sets per exercise?"
    case .exercises: return "How many exercises on a usual training day?"
    case .scrolling: return "Do you scroll between sets?"
    case .minutes: return "How many minutes do you scroll between sets?"
    case .restHabits: return "Do you time your rests between sets?"
    case .loggingHabits: return "Do you log your workouts and look back at them?"
    case .setTiming: return "Do you record how long each set takes?"
    case .reveal: return "Keep this time for yourself."
    case .restStory: return "Give your next set a fair chance."
    case .progressStory: return "Make the next workout less of a guess."
    case .ready: return "Your next set starts here."
    }
  }
  @ViewBuilder private func scene(compact: Bool) -> some View {
    switch step {
    case .welcome:
      VStack(spacing: 26) {
        WorkoutMark(assembled: markReady).frame(width: 116, height: 116)
        Text("GymBlock").font(GymType.hero(38))
        Text(store.t("Make your next set count.")).font(GymType.body(17)).foregroundStyle(
          GymColor.dim)
      }
    case .frequency:
      if typeSize.isAccessibilitySize {
        wheel(values: (1...7).map(Double.init), unit: "days / week", id: "baseline.days")
      } else {
        HStack(spacing: 0) {
          ForEach(1...7, id: \.self) { day in
            Button {
              draft = Double(day)
              didEdit = true
              OnboardingFeedback.shared.play(profile: store.profile, selection: true)
            } label: {
              Text("\(day)").font(GymType.label(22)).frame(maxWidth: .infinity, minHeight: 58)
                .background {
                  if draft == Double(day) { Capsule().fill(GymColor.red.opacity(0.12)).padding(4) }
                }
                .foregroundStyle(draft == Double(day) ? GymColor.red : GymColor.ink)
            }.buttonStyle(.plain).accessibilityAddTraits(draft == Double(day) ? .isSelected : [])
              .accessibilityLabel("\(day) " + store.t("days / week")).accessibilityIdentifier(
                "baseline.days.\(day)")
          }
        }.buttonStyle(OnboardingGlassStyle()).modifier(OnboardingGlass(tint: nil))
      }
    case .duration:
      wheel(
        values: stride(from: 5.0, through: 240.0, by: 5).map { $0 }, unit: "min",
        id: "baseline.duration")
    case .reps, .routine:
      wheel(values: (1...50).map(Double.init), unit: "reps", id: "baseline.reps")
    case .sets: wheel(values: (1...20).map(Double.init), unit: "sets", id: "baseline.sets")
    case .exercises:
      wheel(values: (1...30).map(Double.init), unit: "exercises", id: "baseline.exercises")
    case .minutes:
      wheel(
        values: stride(from: 0.5, through: 15.0, by: 0.5).map { $0 }, unit: "min",
        id: "baseline.scrollMinutes")
    case .scrolling, .restHabits, .setTiming:
      VStack(spacing: 12) {
        ForEach([HabitAnswer.yes, .sometimes, .no], id: \.self) { answer in
          answerRow(
            answer == .yes ? "Yes" : answer == .no ? "No" : "Sometimes", selected: habit == answer,
            id: "habit.\(step.rawValue).\(answer.rawValue)"
          ) {
            update {
              if step == .scrolling {
                $0.scrollFrequency = answer
                $0.scrollsBetweenSets = answer != .no
                $0.scrollingBreaks = nil
              } else if step == .restHabits {
                $0.restTiming = answer
              } else {
                $0.setTiming = answer
              }
            }
          }
        }
      }
    case .loggingHabits:
      VStack(spacing: 12) {
        ForEach(LoggingHabit.allCases, id: \.self) { answer in
          answerRow(
            answer == .review ? "Log and review" : answer == .logOnly ? "Log only" : "Neither",
            selected: baseline.loggingHabit == answer, id: "habit.loggingHabits.\(answer.rawValue)"
          ) { update { $0.loggingHabit = answer } }
        }
      }
    case .reveal:
      if needsBreaks {
        Text(store.t("How many breaks do you scroll in?")).font(GymType.title(28))
          .multilineTextAlignment(.center)
        wheel(
          values: (0...(baseline.breakCount ?? 50)).map(Double.init), unit: "scrolling breaks",
          id: "baseline.actualBreaks")
      } else {
        focusScene(compact: compact)
      }
    case .restStory:
      JourneyRest(progress: artProgress).padding(.vertical, 12)
      Text(
        store.t(
          baseline.restTiming == .yes
            ? "Keep your rest visible with your sets."
            : "Let the rest counter start when you finish a set.")
      )
      .font(GymType.body(17)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
      Text(store.t("See the gap. Start when you’re ready.")).font(GymType.body(14)).foregroundStyle(
        GymColor.dim
      )
      .multilineTextAlignment(.center)
      Button(store.t("Why rest matters")) { detail = .rest }.font(GymType.body(14)).frame(
        minHeight: 44
      )
      .accessibilityIdentifier("journey.rest.research")
    case .progressStory:
      if storyStage == 0 {
        JourneyComparison(showChange: artProgress >= 1)
        Text(
          store.t(
            baseline.loggingHabit == .neither
              ? "Remember what you did."
              : baseline.loggingHabit == .logOnly
                ? "See what changed." : "Keep the comparison close to your next set.")
        )
        .font(GymType.body(17)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
        Text(
          store.t(
            baseline.setTiming == .yes
              ? "Set time stays with reps and weight." : "Start and finish. Set time is recorded.")
        )
        .font(GymType.body(14)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
      } else {
        hero(
          baseline.fourWeekSets.map(String.init) ?? "4",
          label: baseline.fourWeekSets == nil ? "weeks to build a record" : "sets you could track",
          qualifier: baseline.fourWeekSets == nil
            ? "Example: four weeks" : "Over 4 weeks at your current routine")
        JourneyMonth(days: baseline.trainingDays)
        Text(store.t("You could have a record of every one.")).font(GymType.body(17))
          .foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
        if baseline.fourWeekSets != nil {
          Button(store.t("Your routine in numbers")) { detail = .record }
            .font(GymType.body(14)).frame(minHeight: 44).accessibilityIdentifier(
              "journey.record.detail")
        }
      }
    case .ready:
      JourneyMarks(count: 1, outlined: true).padding(.vertical, 24)
      Text(store.t("A clear workout. A record to build on.")).font(GymType.body(17))
        .foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
    }
  }
  private func wheel(values: [Double], unit: String, id: String) -> some View {
    var preserved = values
    if !preserved.contains(draft) {
      preserved.append(draft)
      preserved.sort()
    }
    return JourneyWheel(
      values: preserved, unit: store.t(unit), id: id,
      value: Binding(
        get: { draft },
        set: {
          draft = $0
          didEdit = true
        })
    )
    .frame(height: typeSize.isAccessibilitySize ? 260 : 220).frame(maxWidth: .infinity)
  }
  private func hero(_ value: String, label: String, qualifier: String) -> some View {
    VStack(spacing: 12) {
      Text(value).font(GymType.hero(typeSize.isAccessibilitySize ? 48 : 60)).monospacedDigit()
        .foregroundStyle(GymColor.red).multilineTextAlignment(.center).accessibilityIdentifier(
          "baseline.result")
      Text(store.t(label)).font(GymType.label(17)).multilineTextAlignment(.center)
      Text(store.t(qualifier)).font(GymType.body(13)).foregroundStyle(GymColor.dim)
        .multilineTextAlignment(.center)
    }
  }
  @ViewBuilder private func focusScene(compact: Bool) -> some View {
    if baseline.canShowAttention, let minutes = baseline.attentionMinutes {
      hero(
        storyStage == 2
          ? JourneyFormat.minutes(baseline.fourWeekAttention ?? minutes)
          : JourneyFormat.number(minutes) + " min",
        label: storyStage == 0
          ? "Estimated scrolling per visit"
          : storyStage == 1
            ? "potential phone-free time" : "Potential phone-free time over 4 weeks",
        qualifier: storyStage == 0 ? "Based on your answers" : "Rest stays. Scrolling goes.")
      if storyStage == 2 {
        JourneyMonth(days: baseline.trainingDays)
      } else {
        JourneyVisit(
          duration: baseline.duration ?? 60, scrolling: minutes, phoneFree: storyStage > 0)
      }
    } else {
      Text(
        store.t(
          !baseline.attentionValid
            ? "Let’s check that estimate."
            : baseline.scrollFrequency == .no || baseline.scrollsBetweenSets == false
              ? "You’re already keeping the space between sets."
              : "Start by noticing your next break.")
      )
      .font(GymType.title(28)).multilineTextAlignment(.center)
      JourneyMarks(count: 3, outlined: true).padding(.vertical, 24)
      if !baseline.attentionValid {
        Text(store.t("The scrolling estimate leaves no time for your workout.")).font(
          GymType.body(15)
        ).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
      }
    }
    if baseline.scrollFrequency == .yes || baseline.scrollFrequency == .sometimes
      || baseline.scrollsBetweenSets == true
    {
      Button {
        detail = .estimate
      } label: {
        Text(
          store.t(
            baseline.scrollingBreaks == nil
              ? "One visit a day · every break · Adjust" : "Your break estimate · Adjust")
        )
        .font(GymType.body(13)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
      }.frame(minHeight: 44).accessibilityIdentifier("baseline.explanation")
    }
  }
  private var habit: HabitAnswer? {
    if step == .scrolling {
      return baseline.scrollFrequency ?? baseline.scrollsBetweenSets.map { $0 ? .yes : .no }
    }
    return step == .restHabits ? baseline.restTiming : baseline.setTiming
  }
  private func answerRow(_ title: String, selected: Bool, id: String, action: @escaping () -> Void)
    -> some View
  {
    Button {
      action()
      OnboardingFeedback.shared.play(profile: store.profile, selection: true)
    } label: {
      HStack {
        Text(store.t(title))
        Spacer()
        Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(
          selected ? GymColor.red : GymColor.dim.opacity(0.4))
      }
      .font(GymType.label(17)).padding(.horizontal, 22).frame(minHeight: 58)
    }.buttonStyle(OnboardingGlassStyle(selected: selected)).accessibilityIdentifier(id)
      .accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var actions: some View {
    VStack(spacing: 4) {
      Button {
        advance()
      } label: {
        Text(store.t(primaryTitle)).font(GymType.label(17)).frame(
          maxWidth: .infinity, minHeight: 58)
      }
      .buttonStyle(OnboardingGlassStyle(primary: true)).disabled(transitioning || requiresAnswer)
      .accessibilityIdentifier("onboarding.continue")
      if step == .welcome || step == .ready {
        Button(store.t(step == .welcome ? "Just train" : "Go to Home")) {
          finish(start: step == .welcome, skip: step == .welcome)
        }
        .font(GymType.body(15)).foregroundStyle(GymColor.dim).frame(minHeight: 44)
        .accessibilityIdentifier("onboarding.secondary")
      }
    }
  }
  private var primaryTitle: String {
    if step == .welcome { return "Get started" }
    if step == .ready { return "Start workout" }
    if needsBreaks { return "Show me" }
    if step == .reveal && baseline.canShowAttention {
      if storyStage == 0 { return "See the difference" }
      if storyStage == 1 && baseline.fourWeekTrainingDays != nil
        && baseline.visitsPerTrainingDay != 2
      {
        return "Over four weeks"
      }
    }
    if step == .progressStory && storyStage == 0 { return "Your four weeks" }
    return "Continue"
  }
  private var requiresAnswer: Bool {
    [.scrolling, .restHabits, .setTiming].contains(step)
      ? habit == nil : step == .loggingHabits && baseline.loggingHabit == nil
  }
  private func prepare() {
    switch step {
    case .frequency: draft = Double(baseline.trainingDays ?? 3)
    case .duration: draft = Double(baseline.duration ?? 60)
    case .reps, .routine: draft = Double(baseline.defaultReps ?? 10)
    case .sets: draft = Double(Int(SurveyField.sets.read(baseline)) ?? 3)
    case .exercises: draft = Double(Int(SurveyField.exercises.read(baseline)) ?? 6)
    case .minutes:
      draft = baseline.scrollingMinutes ?? baseline.minutesPerBreak.map(Double.init) ?? 2
    case .reveal: draft = Double(min(5, baseline.breakCount ?? 5))
    default: break
    }
    didEdit = false
  }
  private func commitPicker() {
    switch step {
    case .frequency: update { $0.trainingDays = Int(draft) }
    case .duration: update { $0.duration = Int(draft) }
    case .reps, .routine:
      if didEdit || baseline.reps.isEmpty && baseline.details.isEmpty {
        update {
          SurveyField.reps.write(String(Int(draft)), into: &$0)
          $0.timed = false
        }
      }
    case .sets:
      if didEdit || baseline.sets == nil && baseline.details.isEmpty {
        update { SurveyField.sets.write(String(Int(draft)), into: &$0) }
      }
    case .exercises:
      if didEdit || baseline.exercises == nil && baseline.details.isEmpty {
        update { SurveyField.exercises.write(String(Int(draft)), into: &$0) }
      }
    case .minutes:
      update {
        $0.scrollingMinutes = draft
        $0.minutesPerBreak = draft.rounded() == draft ? Int(draft) : nil
      }
    default: break
    }
  }
  private func advance() {
    guard !transitioning, !requiresAnswer else { return }
    commitPicker()
    if step == .welcome {
      move(.frequency)
      return
    }
    if step == .ready {
      finish(start: true)
      return
    }
    if needsBreaks {
      update { $0.scrollingBreaks = Int(draft) }
      return
    }
    if step == .reveal && baseline.canShowAttention {
      if storyStage == 0 {
        update { if $0.visitsPerTrainingDay == nil { $0.visitsPerTrainingDay = 1 } }
        setStoryStage(1)
        return
      }
      if storyStage == 1 && baseline.fourWeekAttention != nil {
        setStoryStage(2)
        return
      }
    }
    if step == .progressStory && storyStage == 0 {
      setStoryStage(1)
      return
    }
    if let index = route.firstIndex(of: step), index + 1 < route.count { move(route[index + 1]) }
  }
  private func skip() {
    switch step {
    case .frequency: update { $0.trainingDays = nil }
    case .duration: update { $0.duration = nil }
    case .reps, .routine: update { SurveyField.reps.write("", into: &$0) }
    case .sets: update { SurveyField.sets.write("", into: &$0) }
    case .exercises: update { SurveyField.exercises.write("", into: &$0) }
    case .scrolling:
      update {
        $0.scrollFrequency = nil
        $0.scrollsBetweenSets = nil
      }
    case .minutes:
      update {
        $0.scrollingMinutes = nil
        $0.minutesPerBreak = nil
      }
    case .restHabits: update { $0.restTiming = nil }
    case .loggingHabits: update { $0.loggingHabit = nil }
    case .setTiming: update { $0.setTiming = nil }
    default: break
    }
    if let index = route.firstIndex(of: step), index + 1 < route.count { move(route[index + 1]) }
  }
  private func back() {
    if step == .frequency {
      move(.welcome)
      return
    }
    if let index = route.firstIndex(of: step), index > 0 { move(route[index - 1]) }
  }
  private func move(_ next: OnboardingStep) {
    guard !transitioning else { return }
    OnboardingFeedback.shared.play(profile: store.profile)
    transitionTask?.cancel()
    artTask?.cancel()
    transitioning = true
    showBridge = !reduceMotion && [.reps, .sets, .exercises, .setTiming].contains(step)
    bridgeValue = step == .setTiming ? "" : String(Int(draft))
    bridge = 0
    withAnimation(.easeInOut(duration: 0.4)) { bridge = 1 }
    transitionTask = Task { @MainActor in
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { visible = false }
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 120))
      guard !Task.isCancelled else { return }
      store.updateProfile {
        $0.onboardingStepID = next.rawValue
        $0.onboardingStoryStage = 0
      }
      prepare()
      withAnimation(reduceMotion ? nil : .easeIn(duration: 0.18)) { visible = true }
      animateArt()
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 40 : 180))
      guard !Task.isCancelled else { return }
      showBridge = false
      transitioning = false
    }
  }
  private func setStoryStage(_ value: Int) {
    store.updateProfile { $0.onboardingStoryStage = value }
    OnboardingFeedback.shared.play(profile: store.profile, completion: true)
    // Protect the changed action label from a duplicate tap, not the whole animation.
    transitioning = true
    transitionTask?.cancel()
    transitionTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      transitioning = false
    }
  }
  private func animateArt() {
    artTask?.cancel()
    artProgress = reduceMotion ? 1 : 0
    guard !reduceMotion else { return }
    if step == .restStory {
      withAnimation(.easeOut(duration: 1.6)) { artProgress = 1 }
    } else if step == .progressStory {
      artTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(650))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.5)) { artProgress = 1 }
      }
    }
  }
  private func update(_ body: (inout RoutineBaseline) -> Void) {
    store.updateProfile {
      var b = $0.baseline ?? RoutineBaseline()
      body(&b)
      b.goalMinutesPerBreak = nil
      b.reductionGoal = nil
      $0.baseline = b
      $0.onboardingPreviewTarget = nil
    }
  }
  private func finish(start: Bool, skip: Bool = false) {
    guard !transitioning else { return }
    store.updateProfile {
      $0.onboarded = true
      $0.onboardingStepID = OnboardingStep.ready.rawValue
      if skip { $0.focusEnabled = false }
    }
    if start { store.startSession() }
  }
  static func minutes(_ value: Double) -> String { JourneyFormat.number(value) }
}

enum JourneyDetail: String, Identifiable {
  case estimate, rest, focus, record
  var id: String { rawValue }
}

struct JourneyEstimateEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var breaks = 5.0
  @State private var visits = 1
  @State private var duration = 60.0
  @State private var scrollMinutes = 2.0
  private var baseline: RoutineBaseline { store.profile.baseline ?? RoutineBaseline() }
  var body: some View {
    NavigationStack {
      Form {
        Section(store.t("Based on your answers")) {
          if let count = baseline.effectiveScrollingBreaks,
            let minutes = baseline.scrollingMinutes ?? baseline.minutesPerBreak.map(Double.init)
          {
            Text(
              "\(count) × \(JourneyFormat.number(minutes)) min = \(JourneyFormat.number(Double(count) * minutes)) min"
            )
          }
          Text(
            store.t("Phone-free time includes rest. This is an estimate, not measured phone use."))
          Text(store.t("Gaps include exercise changes. Supersets may need fewer."))
        }
        Section(store.t("Scrolling breaks")) {
          JourneyWheel(
            values: Array(Set((0...(baseline.breakCount ?? 50)).map(Double.init) + [breaks]))
              .sorted(), unit: store.t("breaks"),
            id: "estimate.breaks", value: $breaks
          ).frame(height: 150)
        }
        Section(store.t("Visit minutes")) {
          JourneyWheel(
            values: Array(Set(stride(from: 5.0, through: 240.0, by: 5).map { $0 } + [duration]))
              .sorted(), unit: store.t("min"), id: "estimate.duration", value: $duration
          ).frame(height: 150)
        }
        Section(store.t("Minutes scrolling per break")) {
          JourneyWheel(
            values: Array(
              Set(stride(from: 0.5, through: 15.0, by: 0.5).map { $0 } + [scrollMinutes])
            ).sorted(), unit: store.t("min"), id: "estimate.minutes", value: $scrollMinutes
          ).frame(height: 150)
        }
        Section {
          Picker(store.t("Visits on a training day"), selection: $visits) {
            Text("1").tag(1)
            Text(store.t("More than one")).tag(2)
          }
          Text(
            store.t(
              "Multiple visits need a separate time estimate. Your daily sets can still be projected."
            ))
        }
      }.navigationTitle(store.t("Your estimate")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) {
              store.updateProfile {
                $0.baseline?.scrollingBreaks = Int(breaks)
                $0.baseline?.duration = Int(duration)
                $0.baseline?.scrollingMinutes = scrollMinutes
                $0.baseline?.visitsPerTrainingDay = visits
                $0.onboardingStoryStage = 0
              }
              dismiss()
            }.accessibilityIdentifier("estimate.done")
          }
        }.onAppear {
          breaks = Double(baseline.effectiveScrollingBreaks ?? 5)
          duration = Double(baseline.duration ?? 60)
          scrollMinutes =
            baseline.scrollingMinutes ?? baseline.minutesPerBreak.map(Double.init) ?? 2
          visits = baseline.visitsPerTrainingDay ?? 1
        }
    }
  }
}

struct JourneyResearchSheet: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        Text(store.t("Rest supports your next set.")).font(GymType.title(24))
        Text(
          store.t(
            "Too little recovery can make the next set harder to perform. There isn’t one ideal rest time for everyone."
          ))
        Text(
          store.t(
            "Timing makes the gap visible. It doesn’t measure recovery or predict muscle gain."))
        Link(
          store.t("Rest interval research · 2024"),
          destination: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11349676/")!)
        Link(
          store.t("ACSM evidence review · 2026"),
          destination: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/")!)
      }.navigationTitle(store.t("Why rest matters")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() } }
        }
    }.presentationDetents([.medium, .large])
  }
}

struct JourneyRecordSheet: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        Section(store.t("Over 4 weeks at your current routine")) {
          if let days = store.profile.baseline?.fourWeekTrainingDays {
            LabeledContent(store.t("Training days"), value: String(days))
          }
          if let sets = store.profile.baseline?.fourWeekSets {
            LabeledContent(store.t("Sets"), value: String(sets))
          }
          if let reps = store.profile.baseline?.fourWeekReps {
            LabeledContent(
              store.t("Approximate reps"),
              value: reps.lowerBound == reps.upperBound
                ? String(reps.lowerBound) : "\(reps.lowerBound)–\(reps.upperBound)")
          }
          Text(store.t("A projection of your routine, not completed workouts or predicted gains."))
            .font(GymType.body(14)).foregroundStyle(GymColor.dim)
        }
      }.navigationTitle(store.t("Your routine in numbers")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("journey.record.done")
          }
        }
    }.presentationDetents([.medium, .large])
  }
}
