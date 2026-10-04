import SwiftUI

enum OnboardingStep: String, CaseIterable {
  case welcome, frequency, duration, reps, sets, exercises, scrolling, minutes, breaks
  case restHabits, loggingHabits, setTiming, reveal, restStory, progressStory, subscription, ready
  case routine // Decode-only grouped question.
  static func restored(_ profile: Profile) -> Self {
    if let id = profile.onboardingStepID, let step = Self(rawValue: id) {
      if step == .routine { return .reps }
      if step == .ready { return .progressStory }
      return step
    }
    let old: [Self] = [.welcome, .frequency, .duration, .reps, .scrolling, .reveal, .progressStory]
    return old[min(max(profile.onboardingStep, 0), old.count - 1)]
  }
}

enum OnboardingRoute {
  static func steps(_ baseline: RoutineBaseline) -> [OnboardingStep] {
    var steps: [OnboardingStep] = [.frequency, .duration, .reps, .sets, .exercises, .scrolling]
    let scrolls = baseline.scrollFrequency.map { $0 != .no } ?? (baseline.scrollsBetweenSets == true)
    if scrolls {
      steps.append(.minutes)
      if baseline.scrollFrequency == .sometimes { steps.append(.breaks) }
    }
    steps += [.restHabits, .loggingHabits, .setTiming]
    return steps + [.reveal, .restStory, .progressStory, .subscription]
  }
}

struct OnboardingView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  @Environment(\.dynamicTypeSize) private var typeSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var draft = 3.0
  @State private var didEdit = false
  @State private var visible = true
  @State private var transitioning = false
  @State private var transitionTask: Task<Void, Never>?
  @State private var detail: JourneyDetail?
  private var baseline: RoutineBaseline { store.profile.baseline ?? RoutineBaseline() }
  private var step: OnboardingStep { OnboardingStep.restored(store.profile) }
  private var route: [OnboardingStep] { OnboardingRoute.steps(baseline) }
  private var questionStep: Bool { ![.welcome, .reveal, .restStory, .progressStory, .subscription, .ready].contains(step) }

  var body: some View {
    NavigationStack {
      GeometryReader { geometry in
        VStack(spacing: 0) {
          chrome.padding(.horizontal, 24).padding(.top, 8)
          ScrollView(showsIndicators: false) {
            VStack(spacing: step == .welcome ? 24 : step == .progressStory ? 20 : 28) {
              if step == .welcome {
                Text(store.t("Stay focused.\nStay intentional.")).font(GymType.title(32))
                  .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
              } else {
                Text(store.t(question)).font(GymType.title(28)).multilineTextAlignment(.center)
                  .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
              }
              scene
            }.padding(.horizontal, 24).padding(.top, geometry.size.height < 650 || !questionStep && step != .welcome ? 20 : 44)
              .padding(.bottom, 24).frame(maxWidth: .infinity)
              .opacity(visible ? 1 : 0).id(step)
          }
          Spacer(minLength: 0)
          actions.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 12)
        }
      }.gymPage().toolbar(.hidden, for: .navigationBar)
        .sheet(item: $detail) { item in
          switch item {
          case .estimate: JourneyEstimateEditor()
          case .rest: JourneyResearchSheet()
          case .focus: FocusPreview()
          }
        }
        .onAppear {
          prepare()
          store.updateProfile {
            $0.onboardingStepID = step.rawValue
            $0.onboardingVersion = 6
            if $0.focusEnabled == nil { $0.focusEnabled = false }
            if $0.language.isEmpty {
              $0.language = Locale.current.language.languageCode?.identifier == "es" ? "es" : "en"
            }
          }
        }
        .onChange(of: scenePhase) { _, phase in
          if phase != .active { transitionTask?.cancel(); visible = true; transitioning = false }
        }
        .onDisappear { transitionTask?.cancel(); OnboardingFeedback.shared.cancel() }
    }
  }
  private var chrome: some View {
    HStack(spacing: 16) {
      if step == .welcome {
        Text("GymBlock").font(GymType.label(17))
        Spacer()
        Menu {
          Button("English") { store.updateProfile { $0.language = "en" } }
          Button("Español") { store.updateProfile { $0.language = "es" } }
        } label: {
          Text(store.profile.language == "es" ? "Español" : "English").font(GymType.body(15))
            .frame(minHeight: 44)
        }.accessibilityLabel(store.t("Language"))
      } else {
        Button(action: back) {
          Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium))
            .frame(width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel(store.t("Back"))
          .accessibilityIdentifier("onboarding.back").disabled(transitioning)
        if questionStep {
          ProgressView(value: progress).tint(GymColor.red).accessibilityLabel(store.t(stepSection))
          Button(store.t("Skip questions"), action: skipQuestions)
            .font(GymType.body(13)).frame(minHeight: 44).accessibilityIdentifier("onboarding.skipSetup")
        } else if step == .subscription {
          Spacer()
          Text("GymBlock").font(GymType.label(15))
          Spacer()
          Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        } else {
          Spacer()
          HStack(spacing: 8) {
            ForEach(0..<3) { index in
              Capsule().fill(index == storyIndex ? GymColor.red : GymColor.dim.opacity(0.2))
                .frame(width: index == storyIndex ? 22 : 6, height: 4)
            }
          }.accessibilityElement().accessibilityLabel(store.t("How GymBlock helps"))
          Spacer()
          Menu {
            Toggle(store.t("Sound"), isOn: Binding(get: { store.profile.soundEnabled ?? false },
              set: { value in store.updateProfile { $0.soundEnabled = value } }))
          } label: {
            Image(systemName: store.profile.soundEnabled == true ? "speaker.wave.2" : "speaker.slash")
              .frame(width: 44, height: 44)
          }.accessibilityLabel(store.t("Sound"))
        }
      }
    }.foregroundStyle(GymColor.ink).frame(minHeight: 44)
  }
  private var storyIndex: Int { step == .reveal ? 0 : step == .restStory ? 1 : 2 }
  private var stepSection: String {
    [.frequency, .duration, .reps, .sets, .exercises].contains(step) ? "Your workouts" : "Your habits"
  }
  private var progress: Double {
    // Conditional questions can be skipped without moving the journey backward.
    let milestones: [OnboardingStep] = [.frequency, .duration, .reps, .sets, .exercises,
      .scrolling, .minutes, .breaks, .restHabits, .loggingHabits, .setTiming,
      .reveal, .restStory, .progressStory]
    return Double((milestones.firstIndex(of: step) ?? milestones.count - 1) + 1) / Double(milestones.count)
  }
  private var question: String {
    switch step {
    case .welcome: return "Stay focused. Stay intentional."
    case .frequency: return "How many days a week do you workout?"
    case .duration: return "How long is a usual gym visit?"
    case .reps, .routine: return "How many reps do you do per set, on average?"
    case .sets: return "How many sets do you do per exercise, on average?"
    case .exercises: return "How many exercises in a day?"
    case .scrolling: return "Do you scroll through your phone in between sets?"
    case .minutes: return "How many minutes do you scroll between sets?"
    case .breaks: return "How many breaks include scrolling?"
    case .restHabits: return "Do you measure how long you rest between sets?"
    case .loggingHabits: return "Do you record your workouts and look at those records later?"
    case .setTiming: return "Do you measure how long each set takes?"
    case .reveal: return "Let your mind rest between sets."
    case .restStory: return "Time your rests."
    case .progressStory, .ready: return "See what your work adds up to."
    case .subscription: return "Stay focused with GymBlock."
    }
  }
  @ViewBuilder private var scene: some View {
    switch step {
    case .welcome:
      Text(store.t("Less scrolling. More attention on your workout."))
        .font(GymType.body(17)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
      JourneyPhone().padding(.top, 12)
      Text(store.t("Workout")).font(GymType.label(17))
    case .frequency:
      VStack(spacing: 28) {
        Text("\(Int(draft)) " + store.t(Int(draft) == 1 ? "day a week" : "days a week")).font(GymType.title(38)).monospacedDigit()
          .contentTransition(.numericText()).accessibilityHidden(true)
        VStack(spacing: 8) {
          TrainingDaysSlider(value: $draft, haptics: store.profile.hapticsEnabled ?? true,
                             label: store.t("days a week")).frame(height: 44)
          HStack { Text("1"); Spacer(); Text("7") }
            .font(GymType.body(13)).foregroundStyle(GymColor.dim).accessibilityHidden(true)
        }
      }.padding(.top, 36)
    case .duration: wheel(stride(from: 5.0, through: 240, by: 5).map { $0 }, unit: "min", id: "baseline.duration")
    case .reps, .routine: wheel((1...50).map(Double.init), unit: "reps", id: "baseline.reps")
    case .sets: wheel((1...20).map(Double.init), unit: "sets", id: "baseline.sets")
    case .exercises: wheel((1...30).map(Double.init), unit: "exercises", id: "baseline.exercises")
    case .minutes:
      VStack(spacing: 8) {
        wheel(stride(from: 0.5, through: 15, by: 0.5).map { $0 }, unit: "min", id: "baseline.scrollMinutes")
        Text(store.t("Count scrolling time only.")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
      }
    case .breaks:
      VStack(spacing: 8) {
        wheel((0...(baseline.breakCount ?? 50)).map(Double.init), unit: "breaks", id: "baseline.actualBreaks")
        if let count = baseline.breakCount {
          Text(store.t("Out of") + " \(count) " + store.t("possible breaks"))
            .font(GymType.body(14)).foregroundStyle(GymColor.dim)
        }
      }
    case .scrolling, .restHabits, .setTiming:
      VStack(spacing: 0) {
        ForEach(HabitAnswer.allCases, id: \.self) { answer in
          answerRow(answer == .yes ? (step == .scrolling ? "Yes, every break" : "Yes") : answer == .sometimes ? "Sometimes" : "No",
                    selected: habit == answer, id: "habit.\(step.rawValue).\(answer.rawValue)") {
            update {
              if step == .scrolling {
                $0.scrollFrequency = answer; $0.scrollsBetweenSets = answer != .no
                $0.scrollingBreaks = nil
                if answer == .no { $0.scrollingMinutes = nil; $0.minutesPerBreak = nil }
              } else if step == .restHabits { $0.restTiming = answer }
              else { $0.setTiming = answer }
            }
          }
        }
      }
    case .loggingHabits:
      VStack(spacing: 0) {
        ForEach(LoggingHabit.allCases, id: \.self) { answer in
          answerRow(answer == .review ? "I record and review them" : answer == .logOnly ? "I record them only" : "I do not record them",
                    selected: baseline.loggingHabit == answer, id: "habit.loggingHabits.\(answer.rawValue)") {
            update { $0.loggingHabit = answer }
          }
        }
      }
    case .reveal:
      FocusBenefitScene()
      if baseline.canShowAttention, let minutes = baseline.attentionMinutes {
        Button { detail = .estimate } label: {
          Text(JourneyFormat.number(minutes) + " " + store.t("min of estimated scrolling per visit"))
            .font(GymType.body(14)).foregroundStyle(GymColor.dim)
        }.frame(minHeight: 44).accessibilityIdentifier("baseline.explanation")
      } else if !baseline.attentionValid {
        Button(store.t("Check your time estimate")) { detail = .estimate }
          .font(GymType.body(14)).frame(minHeight: 44)
      }
    case .restStory: RestBenefitScene()
    case .progressStory, .ready: RecordBenefitScene()
    case .subscription:
      SubscriptionOffer { finish(start: false) }

    }
  }
  private func wheel(_ values: [Double], unit: String, id: String) -> some View {
    JourneyWheel(values: Array(Set(values + [draft])).sorted(), unit: store.t(unit), id: id,
      value: Binding(get: { draft }, set: { draft = $0; didEdit = true }))
      .frame(height: typeSize.isAccessibilitySize ? 260 : 216)
  }
  private func answerRow(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
    Button {
      guard !transitioning else { return }
      action(); next()
    } label: {
      HStack {
        Text(store.t(title)).font(GymType.body(20))
        Spacer()
        if selected { Image(systemName: "checkmark").foregroundStyle(GymColor.red).accessibilityHidden(true) }
      }.foregroundStyle(GymColor.ink).padding(.horizontal, 8).frame(minHeight: 68)
        .contentShape(Rectangle()).overlay(alignment: .bottom) { Rectangle().fill(GymColor.ink.opacity(0.12)).frame(height: 1) }
    }.buttonStyle(.plain).accessibilityIdentifier(id).accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var actions: some View {
    VStack(spacing: 4) {
      if step != .subscription && ![.scrolling, .restHabits, .loggingHabits, .setTiming].contains(step) {
      GymButton(title: store.t(primaryTitle), enabled: !transitioning && !requiresAnswer,
                id: "onboarding.continue", action: advance)
      }
      if step == .welcome {
        Button(store.t("Skip questions"), action: skipQuestions).font(GymType.body(15)).foregroundStyle(GymColor.dim).frame(minHeight: 44)
          .accessibilityIdentifier("onboarding.secondary")
      } else if questionStep {
        if step == .reps {
          Menu {
            Button(store.t("I’m not sure"), action: skip)
            Button(store.t("I use timed sets")) {
              update { $0.timed = true; SurveyField.reps.write("", into: &$0) }
              move(.sets)
            }.accessibilityIdentifier("baseline.timed")
          } label: { Text(store.t("Not sure")).font(GymType.body(15)).frame(minHeight: 44) }
            .foregroundStyle(GymColor.dim).accessibilityIdentifier("onboarding.skip")
        } else {
          Button(store.t("Not sure"), action: skip).font(GymType.body(15))
            .foregroundStyle(GymColor.dim).frame(minHeight: 44).accessibilityIdentifier("onboarding.skip")
        }
      }
    }
  }
  private var primaryTitle: String {
    step == .welcome ? "Get started" : step == .progressStory || step == .ready ? "View subscription" : "Continue"
  }
  private var habit: HabitAnswer? {
    if step == .scrolling { return baseline.scrollFrequency ?? baseline.scrollsBetweenSets.map { $0 ? .yes : .no } }
    return step == .restHabits ? baseline.restTiming : baseline.setTiming
  }
  private var requiresAnswer: Bool {
    [.scrolling, .restHabits, .setTiming].contains(step) ? habit == nil
      : step == .loggingHabits && baseline.loggingHabit == nil
  }
  private func prepare() {
    switch step {
    case .frequency: draft = Double(baseline.trainingDays ?? 3)
    case .duration: draft = Double(baseline.duration ?? 60)
    case .reps, .routine: draft = Double(baseline.defaultReps ?? 10)
    case .sets: draft = Double(Int(SurveyField.sets.read(baseline)) ?? 3)
    case .exercises: draft = Double(Int(SurveyField.exercises.read(baseline)) ?? 6)
    case .minutes: draft = baseline.scrollingMinutes ?? baseline.minutesPerBreak.map(Double.init) ?? 2
    case .breaks: draft = Double(baseline.scrollingBreaks ?? min(5, baseline.breakCount ?? 5))
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
        update { SurveyField.reps.write(String(Int(draft)), into: &$0); $0.timed = false }
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
      update { $0.scrollingMinutes = draft; $0.minutesPerBreak = draft.rounded() == draft ? Int(draft) : nil }
    case .breaks: update { $0.scrollingBreaks = Int(draft) }
    default: break
    }
  }
  private func advance() {
    guard !transitioning && !requiresAnswer else { return }
    commitPicker()
    if step == .welcome { store.updateProfile { $0.onboardingSkippedQuestions = false }; move(.frequency); return }
    if step == .progressStory || step == .ready { move(.subscription); return }
    next()
  }
  private func next() {
    if let index = route.firstIndex(of: step), index + 1 < route.count { move(route[index + 1]) }
  }
  private func skip() {
    switch step {
    case .frequency: update { $0.trainingDays = nil }
    case .duration: update { $0.duration = nil }
    case .reps, .routine: update { SurveyField.reps.write("", into: &$0) }
    case .sets: update { SurveyField.sets.write("", into: &$0) }
    case .exercises: update { SurveyField.exercises.write("", into: &$0) }
    case .scrolling: update { $0.scrollFrequency = nil; $0.scrollsBetweenSets = nil }
    case .minutes: update { $0.scrollingMinutes = nil; $0.minutesPerBreak = nil }
    case .breaks: update { $0.scrollingBreaks = nil }
    case .restHabits: update { $0.restTiming = nil }
    case .loggingHabits: update { $0.loggingHabit = nil }
    case .setTiming: update { $0.setTiming = nil }
    default: break
    }
    next()
  }
  private func skipQuestions() {
    store.updateProfile { $0.onboardingSkippedQuestions = true }
    move(.reveal)
  }
  private func back() {
    if step == .frequency || step == .reveal && store.profile.onboardingSkippedQuestions == true { move(.welcome); return }
    if let index = route.firstIndex(of: step), index > 0 { move(route[index - 1]) }
  }
  private func move(_ next: OnboardingStep) {
    guard !transitioning else { return }
    transitionTask?.cancel()
    transitioning = true
    OnboardingFeedback.shared.play(profile: store.profile, selection: true)
    transitionTask = Task { @MainActor in
      withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.1)) { visible = false }
      try? await Task.sleep(for: .milliseconds(100))
      guard !Task.isCancelled else { return }
      store.updateProfile { $0.onboardingStepID = next.rawValue; $0.onboardingStoryStage = 0 }
      prepare()
      withAnimation(.easeIn(duration: reduceMotion ? 0.08 : 0.12)) { visible = true }
      transitioning = false
    }
  }
  private func update(_ body: (inout RoutineBaseline) -> Void) {
    store.updateProfile {
      var baseline = $0.baseline ?? RoutineBaseline()
      body(&baseline); baseline.goalMinutesPerBreak = nil; baseline.reductionGoal = nil
      $0.baseline = baseline; $0.onboardingPreviewTarget = nil
    }
  }
  private func finish(start: Bool, skip: Bool = false) {
    guard !transitioning else { return }
    store.updateProfile {
      $0.onboarded = true; $0.onboardingStepID = OnboardingStep.ready.rawValue
      if skip { $0.focusEnabled = false }
    }
    if start { store.startSession() }
  }
  static func minutes(_ value: Double) -> String { JourneyFormat.number(value) }
}

enum JourneyDetail: String, Identifiable {
  case estimate, rest, focus
  var id: String { rawValue }
}

struct JourneyEstimateEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        if let b = store.profile.baseline, let count = b.effectiveScrollingBreaks,
           let minutes = b.scrollingMinutes ?? b.minutesPerBreak.map(Double.init) {
          Text("\(count) × \(JourneyFormat.number(minutes)) min = \(JourneyFormat.number(Double(count) * minutes)) min")
            .font(GymType.title(24))
          Text(store.t("Your estimate, not measured phone use.")).foregroundStyle(GymColor.dim)
          if let month = b.fourWeekAttention {
            LabeledContent(store.t("Over 4 weeks"), value: JourneyFormat.minutes(month))
          }
        }
        NavigationLink(store.t("Edit answers")) { TrainingAnswersForm() }
      }.gymPage().navigationTitle(store.t("Estimate details")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() } } }
    }.presentationDetents([.medium, .large])
  }
}

struct JourneyResearchSheet: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        Text(store.t("Rest supports your next set.")).font(GymType.title(24))
        Text(store.t("There isn’t one ideal rest time for everyone. Timing helps you notice your own intervals."))
          .foregroundStyle(GymColor.dim)
        Link(store.t("Rest interval research · 2024"), destination: URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11349676/")!)
      }.gymPage().navigationTitle(store.t("About rest")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() } } }
    }.presentationDetents([.medium, .large])
  }
}
