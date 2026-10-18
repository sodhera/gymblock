import XCTest
@testable import GymBlock

@MainActor final class BenefitSceneTests: XCTestCase {
  func testEveryRouteShowsPairedStoryPagesThenBlockingThenOffer() {
    for answer in HabitAnswer.allCases {
      var b = RoutineBaseline(); b.scrollFrequency = answer; b.scrollsBetweenSets = answer != .no
      let route = OnboardingRoute.steps(b)
      XCTAssertEqual(Array(route.suffix(13)), [.mindA, .mindB, .restA, .restB, .logA, .logB, .blocking, .alerts, .commit, .account, .subscription, .splits, .firstWorkout])
      XCTAssertEqual(route.contains(.phoneMinutes), answer != .no)
      XCTAssertEqual(route.contains(.days), answer != .no)  // No phone time, nothing to add up.
      XCTAssertEqual(Array(route.prefix(4)), [.founder, .name, .trainingDays, .scrolling])  // Sulav's note, then one question a page.
    }
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
  func testYearlyEstimateUsesTheirTrainingDays() {
    var b = RoutineBaseline(); b.scrollFrequency = .yes; b.scrollingMinutes = 2; b.trainingDays = 4
    let e = GymTimeEstimate(b)
    XCTAssertEqual(e.days, 4)
    XCTAssertEqual(Int(e.yearlyPhoneHours.rounded()), 118)  // 34 min × 4 × 52 ÷ 60
    XCTAssertEqual(e.yearlyWorkouts, 157)
  }
  func testSplitTemplatesUseOnlyCatalogueExercises() {
    for template in SplitTemplate.allCases {
      for (_, ids) in template.splits { XCTAssertEqual(SplitTemplate.exercises(ids).count, ids.count, "\(template)") }
    }
  }
  func testContinueWaitsOnlyOnAnimatedPages() {
    XCTAssertTrue(OnboardingStep.restA.animated); XCTAssertTrue(OnboardingStep.days.animated)
    XCTAssertTrue(OnboardingStep.scrolling.animated); XCTAssertTrue(OnboardingStep.commit.animated)  // V7: they animate too.
    XCTAssertFalse(OnboardingStep.name.animated); XCTAssertFalse(OnboardingStep.trainingDays.animated)
    XCTAssertTrue(OnboardingStep.alerts.animated)
    XCTAssertEqual(PumpPlot.scrolling.map(\.y).max()!, 0.34, accuracy: 0.001)  // Scrolling never reaches the pump line.
    XCTAssertEqual(PumpPlot.timed.map(\.y).max(), 1)
    XCTAssertEqual(PumpPlot.restEnds(PumpPlot.scrolling).count, 3)
  }
  func testSoundsAndTapsLandOnTheSameBeat() {
    func taps(_ score: JourneyScore) -> [Double] { score.haptics.compactMap { if case let .tap(t, _, _) = $0 { t } else { nil } } }
    // Mind A: each trombone note is heard on its twitch, with that twitch's tap.
    let mind = JourneyScores.mindFading
    XCTAssertEqual(mind.sounds.map(\.sound), [.womp1, .womp2, .womp3])
    for (cue, tap) in zip(mind.sounds, taps(mind)) { XCTAssertEqual(cue.at + JourneyScore.wompAttack, tap, accuracy: 0.0001) }
    // Pump B: when it's full, the clink, that set's plate and the tap are one moment.
    let pts = PumpPlot.timed
    let durations = (1..<pts.count).map { i in pts[i].y > pts[i - 1].y + 0.001 ? 0.34 : pts[i].y >= 0.999 && pts[i - 1].y >= 0.999 ? 0.5 : 0.45 }
    let pump = JourneyScores.pump(pts, timed: true, durations: durations)
    let clink = try! XCTUnwrap(pump.sounds.first { $0.sound == .clink2 })
    XCTAssertTrue(pump.sounds.contains { [.plateLight, .plateMedium, .plateHeavy].contains($0.sound) && abs($0.at - clink.at) < 0.0001 })
    XCTAssertEqual(taps(pump).filter { abs($0 - clink.at) < 0.0001 }.count, 1)
    XCTAssertEqual(taps(pump).max()!, clink.at, accuracy: 0.0001)  // Nothing after it.
    // Pump A: nothing after the last clank.
    let scroll = JourneyScores.pump(PumpPlot.scrolling, timed: false, durations: Array(repeating: 0.34, count: PumpPlot.scrolling.count - 1))
    XCTAssertEqual(taps(scroll).max()!, scroll.sounds.map(\.at).max()!, accuracy: 0.0001)
    // Rest alerts: a tick on each second of the countdown, then the double buzz on 0:00.
    for (k, t) in taps(JourneyScores.restUp).prefix(5).enumerated() { XCTAssertEqual(t, Double(k + 1) * JourneyScores.countdownStep, accuracy: 0.0001) }
  }
  func testPairedPagesShareOneStage() {
    XCTAssertEqual(OnboardingStep.mindA.stage, OnboardingStep.mindB.stage)
    XCTAssertEqual(OnboardingStep.restA.stage, OnboardingStep.restB.stage)
    XCTAssertEqual(OnboardingStep.logA.stage, OnboardingStep.logB.stage)
    XCTAssertNotEqual(OnboardingStep.welcome.stage, OnboardingStep.scrolling.stage)  // V7: the welcome is its own scene.
    XCTAssertNotEqual(OnboardingStep.reveal.stage, OnboardingStep.mindA.stage)
  }
  func testPhoneTimeIsMeasuredAgainstAnAssumedTypicalWorkout() {
    var b = RoutineBaseline(); b.scrollFrequency = .yes; b.scrollingMinutes = 2
    let e = GymTimeEstimate(b)
    XCTAssertEqual(e.rests, 17)
    XCTAssertEqual(e.phoneMinutes, 34)
    XCTAssertEqual(e.liftingMinutes, 12)  // 18 sets × 40 s.
    XCTAssertEqual(e.workoutMinutes, 46)
    XCTAssertEqual(e.trainingMinutes, 12)
    XCTAssertEqual(e.phoneShare, 34.0 / 46, accuracy: 0.0001)
    XCTAssertEqual(e.yearlyPhoneHours, 34 * 5 * 52 / 60, accuracy: 0.001)
    XCTAssertEqual(e.yearlyWorkouts, 196)
    // Longer phone breaks stretch the rest; shorter ones leave rest time that counts as training.
    XCTAssertEqual(GymTimeEstimate(minutesPerRest: 3).workoutMinutes, 12 + 51)
    XCTAssertEqual(GymTimeEstimate(minutesPerRest: 1).trainingMinutes, 46 - 17)
    var none = RoutineBaseline(); none.scrollFrequency = .no
    XCTAssertEqual(GymTimeEstimate(none).phoneMinutes, 0); XCTAssertEqual(GymTimeEstimate(none).phoneShare, 0)
    var sometimes = RoutineBaseline(); sometimes.scrollFrequency = .sometimes
    XCTAssertEqual(GymTimeEstimate(sometimes).minutesPerRest, 1)
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
