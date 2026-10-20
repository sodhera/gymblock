import XCTest
@testable import GymBlock

@MainActor final class BenefitSceneTests: XCTestCase {
  /// The review's example: needs 1½ min, scrolls 4, 5 exercises × 3 sets, 1½ hours, 4 days.
  private func example() -> RoutineBaseline {
    var b = RoutineBaseline(); b.scrollFrequency = .yes; b.scrollsBetweenSets = true
    b.restNeedSeconds = 90; b.scrollingMinutes = 4; b.exercises = 5; b.sets = 3; b.duration = 90; b.trainingDays = 4
    return b
  }
  func testEveryRouteTellsItsOwnStoryThenBlockingThenOffer() {
    let tail: [OnboardingStep] = [.shield, .blocking, .alerts, .commit, .account, .subscription, .splits, .firstWorkout]
    for answer in HabitAnswer.allCases {
      var b = example(); b.scrollFrequency = answer; b.scrollsBetweenSets = answer != .no
      let route = OnboardingRoute.steps(b)
      XCTAssertEqual(Array(route.suffix(8)), tail)
      XCTAssertEqual(Array(route.prefix(5)), [.founder, .name, .trainingDays, .scrolling, .restNeed])  // Sulav's note, then one question a page.
      XCTAssertEqual(route.contains(.scrollMinutes), answer != .no)
      XCTAssertEqual(route.contains(.ahead), answer == .no)
      XCTAssertEqual(route.count, answer == .no ? 14 : 21)  // 22 and 15 pages with the welcome.
    }
    // Scrolling that fits inside the rest: the per-rest page says so, then how GymBlock works.
    var fits = example(); fits.scrollingMinutes = 1
    XCTAssertEqual(Array(OnboardingRoute.steps(fits).prefix(8)), [.founder, .name, .trainingDays, .scrolling, .restNeed, .scrollMinutes, .perRest, .shield])
    // Sets and the rest they need alone don't fit the gym time: only the per-rest promise.
    var unfit = example(); unfit.exercises = 7; unfit.sets = 5; unfit.restNeedSeconds = 120; unfit.scrollingMinutes = 6; unfit.duration = 60
    XCTAssertEqual(Array(OnboardingRoute.steps(unfit).dropFirst(10).prefix(2)), [.promise, .shield])
    // Under five minutes a workout: the number, then on.
    var small = example(); small.scrollingMinutes = 2; small.exercises = 3; small.sets = 2; small.duration = 45
    XCTAssertEqual(Array(OnboardingRoute.steps(small).dropFirst(10).prefix(2)), [.workoutTime, .shield])
    XCTAssertEqual(OnboardingRoute.steps(RoutineBaseline()).last, .firstWorkout)
  }
  func testLogOutKeepsWorkoutsAndDeleteAccountErasesEverything() {
    let domain = "Account.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    store.loadDemoIfEmpty()
    store.updateProfile { $0.name = "Sam"; $0.onboarded = true; $0.heightCM = 180 }
    let history = store.data.history.map(\.id)
    store.logOut()
    var restored = GymStore(defaults: defaults)
    XCTAssertFalse(restored.profile.onboarded)
    XCTAssertEqual(restored.data.history.map(\.id), history)  // Log out keeps local work.
    XCTAssertEqual(restored.profile.name, "Sam")
    restored.deleteAccount()
    restored = GymStore(defaults: defaults)
    XCTAssertTrue(restored.data.history.isEmpty); XCTAssertTrue(restored.data.workouts.isEmpty)
    XCTAssertFalse(restored.profile.onboarded); XCTAssertEqual(restored.profile.name, ""); XCTAssertNil(restored.profile.heightCM)
  }
  func testSetCountIsSingularForOne() {
    let store = GymStore(defaults: UserDefaults(suiteName: "Plural.\(UUID())")!)
    XCTAssertEqual(setCount(1, store: store), "1 set"); XCTAssertEqual(setCount(2, store: store), "2 sets")
  }
  func testRemovedBodyPagesResumeOnTheDaysQuestion() {
    for id in ["body", "gender", "height", "weight"] {
      var p = Profile(); p.onboardingStepID = id
      XCTAssertEqual(OnboardingStep.restored(p), .trainingDays)
    }
  }
  func testTheYearUsesTheirDaysAndCountsWorkoutsOfTheirLength() {
    let t = TimeBack(example())
    XCTAssertEqual(t.days, 4)
    XCTAssertEqual(t.yearHours, 35.0 * 4 * 52 / 60, accuracy: 0.001)  // 121.3 h
    XCTAssertEqual(t.shownYear, 120)  // Down to the nearest 10.
    XCTAssertEqual(t.extraWorkouts, 80)  // 121.3 h ÷ 1½ h = 80.9, down to the nearest 5.
    XCTAssertEqual(t.monthHours, 10)
  }
  func testSplitTemplatesUseOnlyCatalogueExercises() {
    for template in SplitTemplate.allCases {
      for (_, ids) in template.splits { XCTAssertEqual(SplitTemplate.exercises(ids).count, ids.count, "\(template)") }
    }
  }
  func testContinueWaitsOnlyOnAnimatedPages() {
    for step: OnboardingStep in [.perRest, .workoutTime, .yearTime, .promise, .ahead, .scrolling, .commit, .alerts] { XCTAssertTrue(step.animated, "\(step)") }
    // Questions: Continue is there as soon as there's an answer.
    for step: OnboardingStep in [.name, .trainingDays, .restNeed, .scrollMinutes, .exerciseCount, .setCount, .gymTime] { XCTAssertFalse(step.animated, "\(step)") }
  }
  func testSoundsAndTapsLandOnTheSameBeat() {
    func taps(_ score: JourneyScore) -> [Double] { score.haptics.compactMap { if case let .tap(t, _, _) = $0 { t } else { nil } } }
    func has(_ score: JourneyScore, tapAt t: Double) -> Bool { taps(score).contains { abs($0 - t) < 0.0001 } }
    // The stopwatch: a tick and a quiet tick sound for every 15 seconds it winds.
    let wind = JourneyScores.windUp(from: 0, to: 1.5, duration: 0.75)
    XCTAssertEqual(wind.sounds.count, 6); XCTAssertEqual(taps(wind).count, 6)
    for cue in wind.sounds { XCTAssertTrue(has(wind, tapAt: cue.at)) }
    XCTAssertEqual(wind.sounds.last!.at, 0.75, accuracy: 0.0001)
    XCTAssertTrue(JourneyScores.windUp(from: 1.5, to: 1.5, duration: 0.75).sounds.isEmpty)
    // The lost minutes: tocks follow the eased count from where it starts, and it lands on the last.
    let lost = JourneyScores.lostCount(at: PerRestStage.grow, fill: PerRestStage.fill, heavy: false)
    XCTAssertEqual(lost.sounds.map(\.at).max()!, PerRestStage.grow + PerRestStage.fill, accuracy: 0.0001)
    XCTAssertTrue(has(lost, tapAt: PerRestStage.grow + PerRestStage.fill))
    let workout = JourneyScores.lostCount(at: WorkTimeStage.grow, fill: WorkTimeStage.fill, heavy: true)
    XCTAssertTrue(workout.sounds.contains { $0.sound == .plateDrop && abs($0.at - (WorkTimeStage.grow + WorkTimeStage.fill)) < 0.0001 })
    // Given back: the latch and the clink when the red has gone.
    let back = JourneyScores.giveBack(at: WorkTimeStage.wait, slide: WorkTimeStage.slide)
    XCTAssertTrue(has(back, tapAt: WorkTimeStage.wait + WorkTimeStage.slide))
    XCTAssertEqual(back.sounds.first!.at, WorkTimeStage.wait + WorkTimeStage.slide, accuracy: 0.0001)
    // The rack: a thud and a clank for each piece, a gap apart.
    let rack = JourneyScores.rack(pieces: 3, at: 0.3, gap: RackStage.gap)
    for (k, cue) in rack.sounds.enumerated() {
      XCTAssertEqual(cue.at, 0.3 + Double(k) * RackStage.gap, accuracy: 0.0001)
      XCTAssertTrue(has(rack, tapAt: cue.at))
    }
    // The log: a tick per mark, and a tick sound at the end of each row.
    let tally = JourneyScores.tally(marks: [[0.1, 0.2], [0.4, 0.5]])
    XCTAssertEqual(taps(tally), [0.1, 0.2, 0.4, 0.5]); XCTAssertEqual(tally.sounds.map(\.at), [0.2, 0.5])
    // The year: the dots follow the ticks' curve, and the last one lights on the plate drop.
    let year = JourneyScores.year(fill: ExtraWorkoutsStage.fill)
    XCTAssertEqual(try! XCTUnwrap(year.sounds.first { $0.sound == .plateDrop }).at, ExtraWorkoutsStage.fill, accuracy: 0.0001)
    XCTAssertLessThan(JourneyScores.easeInOut((ExtraWorkoutsStage.fill - 0.001) / ExtraWorkoutsStage.fill), 1)
    XCTAssertEqual(JourneyScores.easeInOut(1), 1)
    for p in stride(from: 0.05, through: 0.95, by: 0.15) { XCTAssertEqual(JourneyScores.easeInOut(JourneyScores.easeInOutTime(p)), p, accuracy: 0.001) }
    // Rest alerts: a tick on each second of the countdown, then the double buzz on 0:00.
    for (k, t) in taps(JourneyScores.restUp).prefix(5).enumerated() { XCTAssertEqual(t, Double(k + 1) * JourneyScores.countdownStep, accuracy: 0.0001) }
  }
  func testTheStopwatchStaysForRarelysAheadPage() {
    XCTAssertEqual(OnboardingStep.restNeed.stage, OnboardingStep.ahead.stage)
    XCTAssertNotEqual(OnboardingStep.welcome.stage, OnboardingStep.scrolling.stage)  // V7: the welcome is its own scene.
    XCTAssertNotEqual(OnboardingStep.workoutTime.stage, OnboardingStep.perRest.stage)
  }
  func testOnlyTheScrollingPastTheRestTheyNeedIsLost() {
    let t = TimeBack(example())
    XCTAssertEqual(t.lostPerRest, 2.5)  // 4 − 1½: the rest they need is never lost.
    XCTAssertEqual(t.sets, 15); XCTAssertEqual(t.rests, 14)
    XCTAssertEqual(t.lost!, 35, accuracy: 0.0001)  // 14 × 2½
    XCTAssertEqual(t.shownLost, 35); XCTAssertEqual(t.workout, 55); XCTAssertFalse(t.lostIsAnHour)
    XCTAssertEqual(t.outcome, .full); XCTAssertFalse(t.fitted)
    // Sulav's case: 6 × 4 in 2 hours is "about an hour", back in about 1 h 5 min.
    var sulav = example(); sulav.exercises = 6; sulav.sets = 4; sulav.duration = 120
    let s = TimeBack(sulav)
    XCTAssertEqual(s.lost!, 57.5, accuracy: 0.0001); XCTAssertEqual(s.shownLost, 55); XCTAssertTrue(s.lostIsAnHour); XCTAssertEqual(s.workout, 65)
    // Sometimes: half the rests.
    var some = example(); some.scrollFrequency = .sometimes
    XCTAssertEqual(TimeBack(some).lost!, 17.5, accuracy: 0.0001); XCTAssertEqual(TimeBack(some).shownLost, 15)
    // "Not sure" counts as 2 minutes; without an answer, their rest timer.
    var unsure = example(); unsure.restNeedUnsure = true
    XCTAssertEqual(TimeBack(unsure).restNeed, 2); XCTAssertEqual(TimeBack(unsure).lostPerRest, 2)
    var noAnswer = example(); noAnswer.restNeedSeconds = nil
    XCTAssertEqual(TimeBack(noAnswer, restSeconds: 60).restNeed, 1)
    // Rarely, or scrolling inside the rest: ahead.
    var rarely = example(); rarely.scrollFrequency = .no
    XCTAssertEqual(TimeBack(rarely).outcome, .ahead)
    var inside = example(); inside.scrollingMinutes = 1
    XCTAssertEqual(TimeBack(inside).lostPerRest, 0); XCTAssertEqual(TimeBack(inside).outcome, .ahead)
    // Scrolling past the gym time is cut to fit, never more.
    var over = example(); over.scrollingMinutes = 8; over.duration = 60
    let o = TimeBack(over)
    XCTAssertTrue(o.fitted); XCTAssertEqual(o.lost!, 60 - 10 - 21, accuracy: 0.0001)  // 60 − sets − the rest they need
    // Sets and needed rest alone past the gym time: no total, never a guess.
    var unfit = example(); unfit.exercises = 7; unfit.sets = 5; unfit.restNeedSeconds = 120; unfit.scrollingMinutes = 6; unfit.duration = 60
    XCTAssertNil(TimeBack(unfit).lost); XCTAssertEqual(TimeBack(unfit).outcome, .unfit)
    // Under five minutes: small (5 rests × ½ min = 2.5, shown as 3).
    var small = example(); small.scrollingMinutes = 2; small.exercises = 3; small.sets = 2; small.duration = 45
    XCTAssertEqual(TimeBack(small).outcome, .small); XCTAssertEqual(TimeBack(small).shownLost, 3)
    // Unanswered: open.
    XCTAssertEqual(TimeBack(RoutineBaseline()).outcome, .open)
  }
  func testTimeReadsAsPeopleSayIt() {
    XCTAssertEqual(TimeWords.half(1.5), "1½"); XCTAssertEqual(TimeWords.half(2), "2"); XCTAssertEqual(TimeWords.half(0.5), "½")
    XCTAssertEqual(TimeWords.clock(2.5), "2:30"); XCTAssertEqual(TimeWords.clock(1.5), "1:30")
    XCTAssertEqual(TimeWords.duration(55), "55 min"); XCTAssertEqual(TimeWords.duration(65), "1 h 5 min"); XCTAssertEqual(TimeWords.duration(60), "1 h")
    XCTAssertEqual(TimeWords.gymLong(90), "1½ hours"); XCTAssertEqual(TimeWords.gymShort(90), "1½ h"); XCTAssertEqual(TimeWords.gymLong(45), "45 minutes")
  }
  func testBodyAnswersDecodeOptionallyForExistingProfiles() throws {
    var p = Profile(); p.gender = "female"; p.heightCM = 165; p.bodyWeightKG = 61.5
    let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(p))
    XCTAssertEqual(decoded.gender, "female"); XCTAssertEqual(decoded.heightCM, 165); XCTAssertEqual(decoded.bodyWeightKG, 61.5)
    let legacy = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(Profile()))
    XCTAssertNil(legacy.gender); XCTAssertNil(legacy.heightCM)
    XCTAssertEqual(BodyUnits.feet(70), "5′ 10″")
  }
  func testUnconfiguredPurchaseCannotInventEntitlement() async throws {
    let purchase = GymSubscription()
    // With REVENUECAT_API_KEY set, buy() opens a real App Store sheet and the run waits on it forever.
    try XCTSkipIf(purchase.configured, "RevenueCat is configured in this build; this checks the unconfigured path only.")
    await purchase.load(); XCTAssertNil(purchase.plan); XCTAssertTrue(purchase.plans.isEmpty); XCTAssertFalse(purchase.hasAccess)
    await purchase.buy(); XCTAssertFalse(purchase.hasAccess)
    await purchase.restore(); XCTAssertFalse(purchase.hasAccess)
    XCTAssertNotNil(purchase.message)
  }
}
