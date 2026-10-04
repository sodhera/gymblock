import XCTest

@testable import GymBlock

@MainActor final class OnboardingJourneyTests: XCTestCase {
  func testSupersetBreakOverrideAndFractionalGoal() {
    var b = RoutineBaseline(
      duration: 60, visits: 3, exercises: 6, sets: 3,
      scrollsBetweenSets: true, minutesPerBreak: 2, scrollingBreaks: 5)
    XCTAssertEqual(b.breakCount, 17)
    XCTAssertEqual(b.feedMinutes, 10)
    XCTAssertEqual(b.weeklyFeedMinutes, 30)
    b.goalMinutesPerBreak = 1
    XCTAssertEqual(b.phoneFreeGain, 5)
    b.minutesPerBreak = 1
    b.goalMinutesPerBreak = 0.5
    XCTAssertEqual(b.phoneFreeGain, 2.5)
    b.scrollingBreaks = 18
    XCTAssertFalse(b.scrollingValid)
    XCTAssertNil(b.feedMinutes)
    XCTAssertNil(b.phoneFreeGain)
    b.scrollingBreaks = -1
    XCTAssertFalse(b.breakAssumptionValid)
  }
  func testTimedWorkoutNeedsActualBreakCountRatherThanRepGuess() {
    var b = RoutineBaseline(duration: 30, timed: true, scrollsBetweenSets: true, minutesPerBreak: 3)
    XCTAssertNil(b.feedMinutes)
    XCTAssertFalse(b.canReveal)
    b.scrollingBreaks = 4
    XCTAssertEqual(b.feedMinutes, 12)
    XCTAssertTrue(b.canReveal)
    XCTAssertNil(b.totalReps)
    XCTAssertNil(b.weeklyFeedMinutes)
    b.duration = nil
    XCTAssertFalse(b.canReveal)
  }
  func testZeroAndInconsistentEstimatesNeverProduceReveal() {
    var b = RoutineBaseline(
      duration: 60, exercises: 1, sets: 1,
      scrollsBetweenSets: true, minutesPerBreak: 2)
    XCTAssertEqual(b.feedMinutes, 0)
    XCTAssertFalse(b.canReveal)
    b.exercises = 6
    b.sets = 3
    b.minutesPerBreak = 6
    XCTAssertEqual(b.feedMinutes, 102)  // No silent cap at 60.
    XCTAssertFalse(b.canReveal)
    b.minutesPerBreak = 2
    XCTAssertTrue(b.canReveal)
    b.scrollsBetweenSets = false
    XCTAssertFalse(b.canReveal)
    b.scrollsBetweenSets = nil
    b.scrolling = 34
    XCTAssertFalse(b.canReveal)  // Legacy aggregate isn't evidence of every-break scrolling.
  }
  func testStableStepAndLegacyMigrationDoNotChangeAnswersOrHistory() throws {
    var p = Profile()
    p.baseline = RoutineBaseline(
      duration: 60, exercises: 6, sets: 3,
      scrollsBetweenSets: true, minutesPerBreak: 2)
    p.onboardingStep = 5
    XCTAssertEqual(OnboardingStep.restored(p), .reveal)
    p.onboardingStepID = "duration"
    XCTAssertEqual(OnboardingStep.restored(p), .duration)
    p.onboardingStepID = nil
    p.baseline?.minutesPerBreak = nil
    XCTAssertEqual(OnboardingStep.restored(p), .reveal)  // Unknown estimates use the qualitative focus scene.
    p.onboardingStep = -10
    XCTAssertEqual(OnboardingStep.restored(p), .welcome)
    var data = LocalData()
    data.profile = p
    data.history = [Session(name: "Saved workout")]
    let decoded = try JSONDecoder().decode(LocalData.self, from: JSONEncoder().encode(data))
    XCTAssertEqual(decoded.history[0].id, data.history[0].id)
    XCTAssertEqual(decoded.profile.baseline?.duration, 60)
    XCTAssertNil(decoded.profile.baseline?.scrollingBreaks)
    XCTAssertNil(decoded.profile.onboardingPreviewTarget)
  }
  func testExistingVariableRoutineRemainsAccurateBeforeTypicalValuesAreEdited() {
    var b = RoutineBaseline(
      exercises: 6, sets: 3, reps: "10",
      details: [BaselineExercise(sets: 3, reps: "8–12"), BaselineExercise(sets: 2, reps: "10")])
    XCTAssertEqual(SurveyField.exercises.read(b), "2")
    XCTAssertEqual(SurveyField.sets.read(b), "")
    XCTAssertEqual(SurveyField.reps.read(b), "")
    XCTAssertEqual(b.totalSets, 5)
    SurveyField.sets.write("4", into: &b)
    XCTAssertTrue(b.details.isEmpty)
    XCTAssertEqual(b.sets, 4)
    XCTAssertEqual(b.totalSets, 8)
    XCTAssertNil(b.totalReps)
  }
  func testDeletingSurveyAlsoDeletesPreviewWithoutDeletingTraining() {
    let domain = "OnboardingDelete.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    store.data.workouts = [Workout(name: "Arms", exercises: [Exercise.catalog[0]])]
    store.startSession(workout: store.data.workouts[0])
    store.startSet(weight: 20, unit: "kg")
    store.finishSet(reps: 8, minutes: 0)
    store.finish()
    let historyID = store.data.history[0].id
    let splitID = store.data.workouts[0].id
    store.startSession()
    let activeID = store.session?.id
    store.updateProfile {
      $0.baseline = RoutineBaseline(duration: 60, exercises: 6, sets: 3)
      $0.onboardingPreviewTarget = 1
      $0.onboardingScrollAnswered = true
      $0.onboardingRevealSeen = true
    }
    store.deleteRoutineAnswers()
    let restored = GymStore(defaults: defaults)
    XCTAssertNil(restored.profile.baseline)
    XCTAssertNil(restored.profile.onboardingPreviewTarget)
    XCTAssertNil(restored.profile.onboardingScrollAnswered)
    XCTAssertEqual(restored.data.history[0].id, historyID)
    XCTAssertEqual(restored.data.workouts[0].id, splitID)
    XCTAssertEqual(restored.session?.id, activeID)
  }
  func testPreviewPersistsSeparatelyFromGoalAndWorkoutAchievements() throws {
    let domain = "OnboardingJourney.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    store.updateProfile {
      $0.baseline = RoutineBaseline(
        duration: 60, visits: 3, exercises: 6, sets: 3,
        scrollsBetweenSets: true, minutesPerBreak: 2)
      $0.onboardingStepID = "reveal"
      $0.onboardingPreviewTarget = 1
    }
    let restored = GymStore(defaults: defaults)
    XCTAssertEqual(restored.profile.onboardingPreviewTarget, 1)
    XCTAssertNil(restored.profile.baseline?.reductionGoal)
    XCTAssertNil(restored.profile.baseline?.phoneFreeGain)
    XCTAssertTrue(restored.data.history.isEmpty)
    XCTAssertTrue(restored.biggestLifts.isEmpty)
    XCTAssertNil(restored.session)
  }
}
