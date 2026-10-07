import XCTest
@testable import GymBlock

@MainActor final class BenefitSceneTests: XCTestCase {
  func testEveryRouteShowsPairedStoryPagesThenBlockingThenOffer() {
    for answer in HabitAnswer.allCases {
      var b = RoutineBaseline(); b.scrollFrequency = answer; b.scrollsBetweenSets = answer != .no
      let route = OnboardingRoute.steps(b)
      XCTAssertEqual(Array(route.suffix(10)), [.mindA, .mindB, .restA, .restB, .logA, .logB, .blocking, .alerts, .commit, .subscription])
      XCTAssertEqual(route.contains(.phoneMinutes), answer != .no)
      XCTAssertEqual(route.contains(.days), answer != .no)  // No phone time, nothing to add up.
      XCTAssertEqual(Array(route.prefix(3)), [.name, .body, .scrolling])  // Profile first, then habits.
    }
    XCTAssertEqual(OnboardingRoute.steps(RoutineBaseline()).last, .subscription)
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
  func testLegacyGenderPageResumesOnTheMergedPage() {
    var p = Profile(); p.onboardingStepID = "gender"
    XCTAssertEqual(OnboardingStep.restored(p), .body)
  }
  func testContinueWaitsOnlyOnAnimatedPages() {
    XCTAssertTrue(OnboardingStep.restA.animated); XCTAssertTrue(OnboardingStep.days.animated)
    XCTAssertFalse(OnboardingStep.scrolling.animated); XCTAssertFalse(OnboardingStep.commit.animated)
    XCTAssertTrue(OnboardingStep.alerts.animated)
    XCTAssertEqual(PumpPlot.scrolling.map(\.y).max()!, 0.34, accuracy: 0.001)  // Scrolling never reaches the pump line.
    XCTAssertEqual(PumpPlot.timed.map(\.y).max(), 1)
    XCTAssertEqual(PumpPlot.restEnds(PumpPlot.scrolling).count, 3)
  }
  func testPairedPagesShareOneStage() {
    XCTAssertEqual(OnboardingStep.mindA.stage, OnboardingStep.mindB.stage)
    XCTAssertEqual(OnboardingStep.restA.stage, OnboardingStep.restB.stage)
    XCTAssertEqual(OnboardingStep.logA.stage, OnboardingStep.logB.stage)
    XCTAssertEqual(OnboardingStep.welcome.stage, OnboardingStep.scrolling.stage)
    XCTAssertNotEqual(OnboardingStep.reveal.stage, OnboardingStep.mindA.stage)
  }
  func testGymTimeEstimateUsesTheirMinutesAndAdjustableDefaults() {
    var b = RoutineBaseline(); b.scrollFrequency = .yes; b.scrollingMinutes = 2
    var e = GymTimeEstimate(b)
    XCTAssertEqual(e.rests, 17)
    XCTAssertEqual(e.phoneMinutes, 34)
    XCTAssertEqual(e.days, 5)
    XCTAssertEqual(e.yearlyPhoneHours, 34 * 5 * 52 / 60, accuracy: 0.001)
    XCTAssertEqual(e.yearlyWorkouts, 196)  // 147.3 h as 45-minute workouts.
    e.sets = 4
    XCTAssertEqual(e.phoneMinutes, 46)
    e.write(into: &b)
    XCTAssertEqual(GymTimeEstimate(b), e)  // Adjustments persist and restore exactly.
    var none = RoutineBaseline(); none.scrollFrequency = .no
    XCTAssertEqual(GymTimeEstimate(none).phoneMinutes, 0)
    var sometimes = RoutineBaseline(); sometimes.scrollFrequency = .sometimes
    XCTAssertEqual(GymTimeEstimate(sometimes).minutesPerRest, 1)
    XCTAssertEqual(GymTimeEstimate(RoutineBaseline(exercises: 1, sets: 1)).rests, 0)
  }
  func testBodyAnswersDecodeOptionallyForExistingProfiles() throws {
    var p = Profile(); p.gender = "female"; p.heightCM = 165; p.bodyWeightKG = 61.5
    let decoded = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(p))
    XCTAssertEqual(decoded.gender, "female"); XCTAssertEqual(decoded.heightCM, 165); XCTAssertEqual(decoded.bodyWeightKG, 61.5)
    let legacy = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(Profile()))
    XCTAssertNil(legacy.gender); XCTAssertNil(legacy.heightCM)
    XCTAssertEqual(BodyUnits.feet(70), "5′ 10″")
  }
  func testUnconfiguredPurchaseCannotInventEntitlement() async {
    let purchase = GymSubscription()
    XCTAssertFalse(purchase.configured)
    await purchase.load(); XCTAssertNil(purchase.product); XCTAssertFalse(purchase.hasAccess)
    await purchase.buy(); XCTAssertFalse(purchase.hasAccess)
    await purchase.restore(); XCTAssertFalse(purchase.hasAccess)
    XCTAssertNotNil(purchase.message)
  }
}
