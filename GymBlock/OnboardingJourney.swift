import SwiftUI

/// Raw identifiers survive question reordering. Legacy drafts keep their answers and logs.
enum OnboardingStep: String, CaseIterable {
  case welcome, frequency, duration, routine, scrolling, minutes, reveal, ready
  static func restored(_ profile: Profile) -> Self {
    if let id = profile.onboardingStepID, let step = Self(rawValue: id) {
      return step == .reveal && profile.baseline?.canReveal != true ? .ready : step
    }
    let old: [Self] = [.welcome, .frequency, .duration, .routine, .scrolling, .reveal, .ready]
    let step = old[min(max(profile.onboardingStep, 0), old.count - 1)]
    return step == .reveal && profile.baseline?.canReveal != true ? .ready : step
  }
  var progress: Double { Double(Self.allCases.firstIndex(of: self) ?? 0) / 7 }
}

struct OnboardingView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var visible = true
  @State private var transitioning = false
  @State private var transitionTask: Task<Void, Never>?
  @State private var editor: SurveyField?
  @State private var explanation = false
  @State private var focus = false
  @State private var example = false
  @State private var after = false
  @State private var half = false
  @State private var markReady = false
  @State private var previewTransitioning = false
  @State private var animateReveal = false
  @State private var scrollAnswerChosen = false
  private var step: OnboardingStep { OnboardingStep.restored(store.profile) }
  private var baseline: RoutineBaseline { store.profile.baseline ?? RoutineBaseline() }
  private var gain: Double { Double(baseline.feedMinutes ?? 0) * (half ? 0.5 : 1) }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        VStack(spacing: 0) {
          chrome.padding(.horizontal, 24).padding(.top, 8)
          ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
              Spacer(
                minLength: step == .reveal
                  ? (geometry.size.height < 700 ? 0 : 16) : (geometry.size.height < 700 ? 16 : 32))
              if step != .welcome && step != .reveal {
                Text(store.t(question)).font(GymType.title(28)).multilineTextAlignment(.center)
                  .accessibilityAddTraits(.isHeader).padding(
                    .bottom, geometry.size.height < 700 ? 24 : 40
                  )
                  .accessibilityIdentifier("onboarding.question")
              }
              scene(compact: geometry.size.height < 700)
              if let error {
                Text(store.t(error)).font(GymType.body(14)).foregroundStyle(GymColor.red)
                  .multilineTextAlignment(.center).padding(.top, 20)
                  .accessibilityIdentifier("onboarding.error")
                if step == .minutes && !baseline.scrollingValid {
                  HStack {
                    Button(store.t("Edit time")) { move(.duration) }
                    Button(store.t("Edit routine")) { move(.routine) }
                  }.font(GymType.label(14)).padding(.top, 8)
                }
              }
              Spacer(
                minLength: step == .reveal
                  ? (geometry.size.height < 700 ? 0 : 16) : (geometry.size.height < 700 ? 16 : 32))
            }.frame(maxWidth: .infinity)
              .frame(minHeight: max(0, geometry.size.height - 192))
              .padding(.horizontal, 24).opacity(visible ? 1 : 0)
          }.scrollDismissesKeyboard(.interactively)
          actions.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
        }
      }
      .background(OnboardingStage(depth: step.progress))
      .toolbar(.hidden, for: .navigationBar)
      .sheet(item: $editor) { field in
        SurveyEditor(field: field, baseline: baseline) { value in
          update { field.write(value, into: &$0) }
        }
      }
      .sheet(isPresented: $explanation) { assumptions }
      .sheet(isPresented: $focus) { FocusPreview() }
      .sheet(isPresented: $example) { OneSetPreview() }
      .onAppear {
        let restored = step
        scrollAnswerChosen =
          store.profile.onboardingScrollAnswered == true || baseline.scrollsBetweenSets != nil
        restorePreview()
        if step == .reveal { store.updateProfile { $0.onboardingRevealSeen = true } }
        store.updateProfile {
          $0.onboardingVersion = 3
          if $0.focusEnabled == nil { $0.focusEnabled = false }
          $0.onboardingStepID = restored.rawValue
          if $0.language.isEmpty {
            $0.language = Locale.current.language.languageCode?.identifier == "es" ? "es" : "en"
          }
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { markReady = true }
      }
      .onDisappear {
        transitionTask?.cancel()
        OnboardingFeedback.shared.cancel()
      }
    }
  }

  private var chrome: some View {
    HStack(spacing: 20) {
      Button {
        back()
      } label: {
        Image(systemName: "chevron.left").frame(width: 44, height: 44)
      }.buttonStyle(OnboardingGlassStyle()).opacity(step == .welcome ? 0 : 1)
        .disabled(step == .welcome || transitioning)
        .accessibilityLabel(store.t("Back")).accessibilityIdentifier("onboarding.back")
      if step == .welcome {
        Spacer()
      } else {
        GeometryReader { g in
          ZStack(alignment: .leading) {
            Capsule().fill(GymColor.ink.opacity(0.08))
            Capsule().fill(GymColor.red).frame(width: max(3, g.size.width * step.progress))
          }
        }.frame(height: 3).accessibilityLabel(store.t("Setup progress"))
          .accessibilityValue("\(Int(step.progress * 100))%")
      }
      Menu {
        Picker(
          store.t("Language"),
          selection: Binding(
            get: { store.profile.language },
            set: { language in
              store.updateProfile { $0.language = language }
            })
        ) {
          Text("English").tag("en")
          Text("Español").tag("es")
        }.accessibilityIdentifier("onboarding.language")
        Button(store.t(store.profile.soundEnabled == false ? "Enable sounds" : "Mute sounds")) {
          store.updateProfile { $0.soundEnabled = !($0.soundEnabled ?? true) }
          OnboardingFeedback.shared.cancel()
        }.accessibilityIdentifier("onboarding.sound")
        Button(store.t(store.profile.hapticsEnabled == false ? "Enable haptics" : "Mute haptics")) {
          store.updateProfile { $0.hapticsEnabled = !($0.hapticsEnabled ?? true) }
        }.accessibilityIdentifier("onboarding.haptics")
        Button(store.t("Just train")) { finish(start: true, skip: true) }
      } label: {
        Image(systemName: "ellipsis").frame(width: 44, height: 44)
      }
      .buttonStyle(OnboardingGlassStyle()).accessibilityLabel(store.t("Options"))
      .accessibilityIdentifier("onboarding.options")
    }.foregroundStyle(GymColor.ink).frame(height: 44)
  }

  private var question: String {
    switch step {
    case .welcome: return ""
    case .frequency: return "How often do you work out?"
    case .duration: return "How long is a usual visit?"
    case .routine: return "What’s a usual workout?"
    case .scrolling: return "Do you scroll between sets?"
    case .minutes: return "How much of each break is scrolling?"
    case .reveal: return "Your time at the gym."
    case .ready: return "Ready for your next set."
    }
  }

  @ViewBuilder private func scene(compact: Bool) -> some View {
    switch step {
    case .welcome:
      VStack(spacing: 26) {
        WorkoutMark(assembled: markReady).frame(width: 116, height: 116)
        VStack(spacing: 12) {
          Text("GymBlock").font(GymType.hero(38))
          Text(store.t("Stay with your workout.")).font(GymType.body(17)).foregroundStyle(
            GymColor.dim)
        }
      }.padding(.bottom, 36)
    case .frequency:
      SurveyNumber(value: baseline.visits, unit: store.t("workouts / week"), id: "baseline.visits")
      { editor = .visits }
      WorkoutRhythm(count: baseline.visits ?? 0).padding(.top, 32)
      choices([2, 3, 4, 5], field: .visits).padding(.top, 32)
    case .duration:
      SurveyNumber(value: baseline.duration, unit: store.t("minutes"), id: "baseline.duration") {
        editor = .duration
      }
      VisitRuler(value: baseline.duration).padding(.top, 32)
      choices([30, 45, 60, 90], field: .duration).padding(.top, 24)
    case .routine:
      RoutineSketch(baseline: baseline).padding(.bottom, 32)
      if typeSize.isAccessibilitySize {
        VStack(spacing: 16) { routineValues }
      } else {
        HStack(alignment: .top, spacing: 8) { routineValues }
      }
      if let total = baseline.totalSets {
        Text(routineReadout(total)).font(GymType.body(14)).foregroundStyle(GymColor.dim)
          .padding(.top, 24).accessibilityIdentifier("baseline.routine.total")
      }
      HStack(spacing: 24) {
        Button(store.t("Varies")) {
          update {
            $0.exercises = nil
            $0.sets = nil
            $0.reps = ""
            $0.details = []
          }
        }
        .accessibilityIdentifier("baseline.varies")
        Button(store.t(baseline.timed ? "Use reps" : "Mostly timed")) {
          update { $0.timed.toggle() }
        }
        .accessibilityIdentifier("baseline.timed")
      }.font(GymType.body(14)).frame(minHeight: 44).padding(.top, 12)
    case .scrolling:
      VStack(spacing: 14) {
        answer("Yes", value: true, id: "yes")
        answer("No", value: false, id: "no")
        answer("Not sure", value: nil, id: "unknown")
      }
    case .minutes:
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
        ForEach(1...5, id: \.self) { number in
          choice(
            "\(number) " + store.t("min"), selected: baseline.minutesPerBreak == number,
            id: "baseline.break.\(number)"
          ) { update { $0.minutesPerBreak = number } }
        }
        choice(
          (baseline.minutesPerBreak ?? 0) > 5
            ? "\(baseline.minutesPerBreak!) " + store.t("min") : store.t("More"),
          selected: (baseline.minutesPerBreak ?? 0) > 5, id: "baseline.break.more"
        ) { editor = .minutes }
      }
      Button {
        editor = .breaks
      } label: {
        Text(
          baseline.scrollingBreaks.map { "\($0) " + store.t("scrolling breaks") }
            ?? store.t("Assuming every break"))
        Text("· " + store.t("Edit"))
      }.font(GymType.body(14)).foregroundStyle(GymColor.dim).frame(minHeight: 44).padding(.top, 20)
        .accessibilityIdentifier("baseline.break.assumption")
    case .reveal:
      VStack(spacing: compact ? 12 : 20) {
        VStack(spacing: compact ? 4 : 8) {
          Text(Self.minutes(after ? gain : Double(baseline.feedMinutes ?? 0)))
            .font(GymType.hero(typeSize.isAccessibilitySize ? 52 : (compact ? 64 : 76)))
            .monospacedDigit()
            .foregroundStyle(after ? GymColor.red : GymColor.ink)
            .contentTransition(.numericText()).accessibilityIdentifier("baseline.result")
          Text(store.t(after ? "more phone-free minutes" : "scrolling minutes per workout"))
            .font(GymType.label(16)).multilineTextAlignment(.center)
          Text(
            store.t(
              after
                ? (half
                  ? "If you halve scrolling between sets." : "If you skip scrolling between sets.")
                : "Based on your answers")
          )
          .font(GymType.body(14)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
        }
        WorkoutTimeline(
          duration: baseline.duration ?? 1, scrolling: Double(baseline.feedMinutes ?? 0),
          gain: after ? gain : 0, animateEntrance: animateReveal, compact: compact)
        if after {
          HStack(spacing: 12) {
            choice(
              store.t("Half as much"), selected: half, id: "baseline.scenario.half",
              height: compact ? 44 : 52
            ) {
              half = true
              savePreview()
            }
            choice(
              store.t("No scrolling"), selected: !half, id: "baseline.scenario.none",
              height: compact ? 44 : 52
            ) {
              half = false
              savePreview()
            }
          }
          if let visits = baseline.visits, (1...21).contains(visits) {
            Text(
              Self.minutes(gain * Double(visits)) + " " + store.t("min across") + " \(visits) "
                + store.t("weekly workouts")
            )
            .font(GymType.body(14)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
            .accessibilityIdentifier("baseline.weekly")
          }
        }
        HStack(spacing: 24) {
          if after {
            Button(store.t("Replay")) {
              withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) { after = false }
              store.updateProfile { $0.onboardingPreviewTarget = nil }
            }.accessibilityIdentifier("baseline.replay")
          }
          Button(store.t("How this is estimated")) { explanation = true }
            .accessibilityIdentifier("baseline.explanation")
        }.font(GymType.body(14)).frame(minHeight: 44)

      }.animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: after)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: half)
    case .ready:
      VStack(spacing: 28) {
        WorkoutMark(assembled: true).frame(width: 88, height: 88)
        Button(store.t("See one set")) { example = true }
          .font(GymType.label(16)).frame(minHeight: 44).accessibilityIdentifier(
            "onboarding.example")
        Button {
          focus = true
        } label: {
          Label(store.t("Focus demo"), systemImage: "moon")
        }.font(GymType.body(14)).frame(minHeight: 44).accessibilityIdentifier("onboarding.focus")
      }
    }
  }

  @ViewBuilder private var routineValues: some View {
    routineValue("Exercises", value: valueFor(.exercises), field: .exercises)
    routineValue("Sets each", value: valueFor(.sets), field: .sets)
    if !baseline.timed { routineValue("Reps", value: valueFor(.reps), field: .reps) }
  }
  private func valueFor(_ field: SurveyField) -> String? {
    let value = field.read(baseline)
    if value.isEmpty && !baseline.details.isEmpty && field != .exercises {
      return store.t("Varies")
    }
    return value.isEmpty ? nil : value
  }
  private func routineValue(_ title: String, value: String?, field: SurveyField) -> some View {
    Button {
      editor = field
    } label: {
      VStack(spacing: 6) {
        HStack(spacing: 4) {
          Text(value ?? "—").font(GymType.title(30)).foregroundStyle(GymColor.ink)
          Image(systemName: "pencil").font(.system(size: 10)).foregroundStyle(GymColor.dim)
        }
        Text(store.t(title)).font(GymType.body(14)).foregroundStyle(GymColor.dim)
      }.frame(maxWidth: .infinity, minHeight: 72)
    }.buttonStyle(.plain).accessibilityLabel(
      store.t(title) + ", " + (value ?? store.t("Not supplied"))
    )
    .accessibilityHint(store.t("Tap to edit"))
    .accessibilityIdentifier(field.controlID)
  }
  private func routineReadout(_ sets: Int) -> String {
    var text = "\(sets) " + store.t("sets")
    if let reps = baseline.totalReps {
      let count =
        reps.lowerBound == reps.upperBound
        ? "\(reps.lowerBound)" : "\(reps.lowerBound)–\(reps.upperBound)"
      text += " · " + count + " " + store.t("reps")
    }
    return text
  }
  private func answer(_ title: String, value: Bool?, id: String) -> some View {
    let selected = scrollAnswerChosen && baseline.scrollsBetweenSets == value
    return Button {
      scrollAnswerChosen = true
      store.updateProfile { $0.onboardingScrollAnswered = true }
      update {
        $0.scrollsBetweenSets = value
        $0.scrolling = value == false ? 0 : nil
      }
      feedback(selection: true)
    } label: {
      HStack {
        Text(store.t(title)).font(GymType.label(17))
        Spacer()
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(selected ? GymColor.red : GymColor.dim.opacity(0.5))
      }.padding(.horizontal, 22).frame(minHeight: 58)
    }.buttonStyle(OnboardingGlassStyle(selected: selected))
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("baseline.between." + id)
  }
  private func choices(_ numbers: [Int], field: SurveyField) -> some View {
    HStack(spacing: 12) {
      ForEach(numbers, id: \.self) { n in
        choice("\(n)", selected: field.read(baseline) == String(n), id: field.controlID + ".\(n)") {
          update { field.write(String(n), into: &$0) }
        }
      }
    }
  }
  private func choice(
    _ title: String, selected: Bool, id: String, height: CGFloat = 52, action: @escaping () -> Void
  )
    -> some View
  {
    Button {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { action() }
      feedback(selection: true)
    } label: {
      Text(title).font(GymType.label(16)).multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: height).padding(.horizontal, 4)
    }.buttonStyle(OnboardingGlassStyle(selected: selected))
      .accessibilityAddTraits(selected ? .isSelected : []).accessibilityIdentifier(id)
  }

  private var actions: some View {
    VStack(spacing: 6) {
      Button {
        advance()
      } label: {
        Text(store.t(primaryTitle)).font(GymType.label(17)).frame(
          maxWidth: .infinity, minHeight: 58)
      }.buttonStyle(OnboardingGlassStyle(primary: true))
        .disabled(transitioning || error != nil).accessibilityIdentifier("onboarding.continue")
      Button(store.t(secondaryTitle)) { secondary() }
        .font(GymType.body(15)).foregroundStyle(GymColor.dim).frame(minHeight: 44)
        .disabled(transitioning).accessibilityIdentifier("onboarding.skip")
    }
  }
  private var primaryTitle: String {
    switch step {
    case .welcome: return "Get started"
    case .minutes: return "Show me"
    case .reveal: return after ? "Use this goal" : "See the difference"
    case .ready: return "Start workout"
    default: return "Continue"
    }
  }
  private var secondaryTitle: String {
    switch step {
    case .welcome: return "Just train"
    case .reveal: return "Continue without a goal"
    case .ready: return "Go to Home"
    default: return "Not sure"
    }
  }
  private var error: String? {
    switch step {
    case .minutes:
      if !baseline.breakAssumptionValid { return "Check the number of scrolling breaks." }
      if !baseline.scrollingValid { return "That exceeds your visit. Check your answers." }
    case .routine:
      if let n = baseline.exercises, !(1...50).contains(n) {
        return "Enter 1–50 exercises, or leave it blank."
      }
      if let n = baseline.sets, !(1...50).contains(n) {
        return "Enter 1–50 sets, or leave it blank."
      }
      if !baseline.timed && !baseline.reps.isEmpty && RoutineBaseline.repRange(baseline.reps) == nil
      {
        return "Use a rep count or range, such as 8–12."
      }
    case .frequency:
      if let n = baseline.visits, !(0...21).contains(n) {
        return "Enter 0–21 visits, or leave it blank."
      }
    case .duration:
      if let n = baseline.duration, !(1...600).contains(n) {
        return "Enter 1–600 minutes, or leave it blank."
      }
    default: break
    }
    return nil
  }
  private func advance() {
    guard !transitioning, !previewTransitioning, error == nil else { return }
    switch step {
    case .welcome: move(.frequency)
    case .frequency: move(.duration)
    case .duration: move(.routine)
    case .routine: move(.scrolling)
    case .scrolling: move(baseline.scrollsBetweenSets == true ? .minutes : .ready)
    case .minutes: move(baseline.canReveal ? .reveal : .ready)
    case .reveal:
      if !after {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) { after = true }
        savePreview()
        previewTransitioning = true
        transitionTask = Task { @MainActor in
          try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 350))
          guard !Task.isCancelled else { return }
          previewTransitioning = false
        }
        feedback(completion: true)
      } else {
        let target = half ? Double(baseline.minutesPerBreak ?? 0) / 2 : 0
        let confirmedGain: Int? = gain.rounded() == gain ? Int(gain) : nil
        store.updateProfile {
          $0.baseline?.goalMinutesPerBreak = target
          $0.baseline?.reductionGoal = confirmedGain
        }
        move(.ready)
      }
    case .ready: finish(start: true)
    }
  }
  private func secondary() {
    switch step {
    case .welcome: finish(start: true, skip: true)
    case .frequency:
      update { $0.visits = nil }
      move(.duration)
    case .duration:
      update { $0.duration = nil }
      move(.routine)
    case .routine:
      update {
        $0.exercises = nil
        $0.sets = nil
        $0.reps = ""
        $0.details = []
      }
      move(.scrolling)
    case .scrolling:
      store.updateProfile { $0.onboardingScrollAnswered = true }
      update {
        $0.scrollsBetweenSets = nil
        $0.scrolling = nil
      }
      scrollAnswerChosen = true
      move(.ready)
    case .minutes:
      update { $0.minutesPerBreak = nil }
      move(.ready)
    case .reveal:
      store.updateProfile {
        $0.baseline?.reductionGoal = nil
        $0.baseline?.goalMinutesPerBreak = nil
      }
      move(.ready)
    case .ready: finish(start: false)
    }
  }
  private func back() {
    switch step {
    case .welcome: break
    case .frequency: move(.welcome)
    case .duration: move(.frequency)
    case .routine: move(.duration)
    case .scrolling: move(.routine)
    case .minutes: move(.scrolling)
    case .reveal: move(.minutes)
    case .ready:
      move(
        baseline.canReveal ? .reveal : baseline.scrollsBetweenSets == true ? .minutes : .scrolling)
    }
  }
  private func move(_ next: OnboardingStep) {
    guard !transitioning else { return }
    transitioning = true
    previewTransitioning = false
    dismissKeyboard()
    feedback()
    transitionTask?.cancel()
    transitionTask = Task { @MainActor in
      withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.15)) { visible = false }
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 150))
      guard !Task.isCancelled else { return }
      after = false
      half = false
      store.updateProfile {
        $0.onboardingStepID = next.rawValue
        $0.onboardingStep = OnboardingStep.allCases.firstIndex(of: next) ?? 0
      }
      if next == .reveal {
        animateReveal = store.profile.onboardingRevealSeen != true
        restorePreview()
        store.updateProfile { $0.onboardingRevealSeen = true }
      }
      withAnimation(.easeIn(duration: reduceMotion ? 0.1 : 0.28)) { visible = true }
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 280))
      guard !Task.isCancelled else { return }
      transitioning = false
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
  private func restorePreview() {
    after = store.profile.onboardingPreviewTarget != nil
    half = store.profile.onboardingPreviewTarget.map { $0 > 0 } ?? false
  }
  private func savePreview() {
    let target = half ? Double(baseline.minutesPerBreak ?? 0) / 2 : 0
    store.updateProfile {
      $0.onboardingPreviewTarget = target
      $0.onboardingRevealSeen = true
    }
  }
  private func finish(start: Bool, skip: Bool = false) {
    guard !transitioning else { return }
    dismissKeyboard()
    feedback(completion: true)
    if start { store.startSession() }
    store.updateProfile {
      $0.onboarded = true
      $0.onboardingStepID = OnboardingStep.ready.rawValue
      if skip { $0.focusEnabled = false }
    }
  }
  private func feedback(completion: Bool = false, selection: Bool = false) {
    OnboardingFeedback.shared.play(
      profile: store.profile, completion: completion, selection: selection)
  }
  static func minutes(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }

  private var assumptions: some View {
    NavigationStack {
      Form {
        Section(store.t("Based on your answers")) {
          Text(
            "\(baseline.effectiveScrollingBreaks ?? 0) " + store.t("scrolling breaks")
              + " × \(baseline.minutesPerBreak ?? 0) " + store.t("min")
              + " = \(baseline.feedMinutes ?? 0) " + store.t("min"))
          Text(
            store.t("Phone-free time includes rest. This is an estimate, not measured phone use."))
          if after {
            Text(store.t("Possible change") + ": " + Self.minutes(gain) + " " + store.t("min"))
          }
        }
        Section {
          Button(store.t("Edit scrolling breaks")) {
            explanation = false
            move(.minutes)
          }
          Button(store.t("Edit time")) {
            explanation = false
            move(.duration)
          }
          Button(store.t("Edit routine")) {
            explanation = false
            move(.routine)
          }
        }
      }.navigationTitle(store.t("How this is estimated")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { explanation = false }
          }
        }
    }.presentationDetents([.medium, .large])
  }
}
