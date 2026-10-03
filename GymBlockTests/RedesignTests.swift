import XCTest

@testable import GymBlock

@MainActor final class RedesignTests: XCTestCase {
  var defaults: UserDefaults!
  var domain: String!
  override func setUp() {
    domain = "Redesign.\(UUID())"
    defaults = UserDefaults(suiteName: domain)!
  }
  override func tearDown() { defaults.removePersistentDomain(forName: domain) }
  func ready(_ store: GymStore) {
    store.startSession()
    store.chooseExercise(Exercise.catalog[0])
    store.startSet(weight: 20, unit: "kg")
  }
  func testOnboardingTotalsPreserveRangesAndUnknowns() {
    var b = RoutineBaseline(
      duration: 60, visits: 3, exercises: 6, sets: 3, reps: "10", scrolling: 10)
    XCTAssertEqual(b.weeklyGymMinutes, 180)
    XCTAssertEqual(b.totalSets, 18)
    XCTAssertEqual(b.totalReps, 180...180)
    XCTAssertEqual(b.weeklyFeedMinutes, 30)
    b.reps = "8–12"
    XCTAssertEqual(b.totalReps, 144...216)
    b.visits = nil
    XCTAssertNil(b.weeklyFeedMinutes)
    b.details = [BaselineExercise(sets: 3, reps: "12,10,8"), BaselineExercise(sets: 2, reps: "5")]
    XCTAssertEqual(b.totalSets, 5)
    XCTAssertEqual(b.totalReps, 40...40)
    b.details[0].reps = "12,10"
    XCTAssertNil(b.totalReps)
    b.details[0].sets = nil
    XCTAssertNil(b.totalSets)
    b.scrolling = 61
    XCTAssertFalse(b.scrollingValid)
    b.scrolling = 0
    b.visits = 3
    XCTAssertEqual(b.weeklyFeedMinutes, 0)
    b.timed = true
    XCTAssertNil(b.totalReps)
    XCTAssertNil(RoutineBaseline.repRange("12–8"))
    XCTAssertNil(RoutineBaseline.repRange("0"))
    XCTAssertNil(RoutineBaseline.repRange("-10"))
    XCTAssertNil(RoutineBaseline.repRange("10-"))
    XCTAssertTrue(BaselineExercise(reps: "12,10,8").valid)
    XCTAssertFalse(BaselineExercise(sets: 2, reps: "12,10,8").valid)
    b.duration = 0
    XCTAssertNil(b.weeklyGymMinutes)
  }
  func testExtraAndFewerRepsAndAttemptNeverInflateRecords() {
    let s = GymStore(defaults: defaults)
    ready(s)
    s.finishSet(reps: 12, minutes: 0)
    s.startSet(weight: 20, unit: "kg")
    s.finishSet(reps: 7, minutes: 0)
    s.startSet(weight: 500, unit: "kg")
    s.recordAttempt()
    s.recordAttempt()
    XCTAssertEqual(s.session?.sets.count, 3)
    XCTAssertEqual(s.session?.completedSets.count, 2)
    XCTAssertEqual(s.session?.totalReps, 19)
    s.finish()
    XCTAssertEqual(s.biggestLifts.first?.set.weightKG, 20)
    XCTAssertEqual(s.biggestLifts.first?.set.reps, 12)
    XCTAssertEqual(s.summary?.completedSets.count, 2)
  }
  func testAttemptOnlyIsHistoryButDoesNotCountAsTraining() {
    let s = GymStore(defaults: defaults)
    ready(s)
    s.recordAttempt()
    s.finish()
    XCTAssertEqual(s.data.history.count, 1)
    XCTAssertEqual(s.weekCount, 0)
    XCTAssertEqual(s.activeWeekStreak, 0)
    XCTAssertTrue(s.biggestLifts.isEmpty)
  }
  func testCancelAndRelaunchNeverFabricateWork() {
    let s = GymStore(defaults: defaults)
    ready(s)
    s.updateDraft(reps: 7)
    s.cancelSet()
    XCTAssertEqual(s.session?.stage, .setup)
    XCTAssertTrue(s.session!.sets.isEmpty)
    let reloaded = GymStore(defaults: defaults)
    XCTAssertEqual(reloaded.session?.draftReps, 7)
    reloaded.startSet(weight: 20, unit: "kg")
    reloaded.startSession()
    XCTAssertTrue(reloaded.session!.sets.isEmpty)
  }
  func testChangeExercisePreservesCounterAndIndependentValues() {
    let s = GymStore(defaults: defaults)
    ready(s)
    s.finishSet(reps: 7, minutes: 0)
    let restStart = s.session?.restStarted
    s.chooseExercise(Exercise.catalog[1])
    s.updateWeight(12.5, unit: "kg")
    s.updateDraft(reps: 11)
    XCTAssertEqual(s.session?.restStarted, restStart)
    XCTAssertEqual(s.session?.stage, .rest)
    s.chooseExercise(Exercise.catalog[0])
    XCTAssertEqual(s.session?.weightKG, 20)
    XCTAssertEqual(s.session?.draftReps, 7)
    s.chooseExercise(Exercise.catalog[1])
    XCTAssertEqual(s.session?.weightKG, 12.5)
    XCTAssertEqual(s.session?.draftReps, 11)
    XCTAssertEqual(GymStore(defaults: defaults).session?.restStarted, restStart)
  }
  func testEditDeleteAndUndoUpdateOnlyCorrectRest() {
    let s = GymStore(defaults: defaults)
    ready(s)
    s.finishSet(reps: 10, minutes: 0)
    let id = s.session!.id
    let restStart = s.session!.restStarted
    var set = s.session!.sets[0]
    set.reps = 8
    XCTAssertTrue(s.editSet(set, sessionID: id))
    XCTAssertEqual(s.session?.restStarted, restStart)
    s.deleteSet(set, sessionID: id)
    XCTAssertEqual(s.session?.stage, .setup)
    XCTAssertNil(s.session?.restStarted)
    s.undoDelete()
    XCTAssertEqual(s.session?.restStarted, restStart)
    XCTAssertEqual(s.session?.sets.first?.reps, 8)
    s.startSet(weight: 20, unit: "kg")
    s.finishSet(reps: 7, minutes: 0)
    let newCounter = s.session?.restStarted
    s.deleteSet(set, sessionID: id)
    XCTAssertEqual(s.session?.restStarted, newCounter)
    s.undoDelete()
    XCTAssertEqual(s.session?.sets.count, 2)
  }
  func testAddingCompletedSetDoesNotModifyActiveStateOrTiming() {
    let s = GymStore(defaults: defaults)
    ready(s)
    let started = s.session?.setStarted
    XCTAssertTrue(
      s.addCompletedSet(
        exercise: Exercise.catalog[1], weight: 10, reps: 8, minutes: 0, warmup: true))
    XCTAssertEqual(s.session?.stage, .active)
    XCTAssertEqual(s.session?.setStarted, started)
    XCTAssertEqual(s.session?.sets.first?.timingUnknown, true)
    XCTAssertEqual(s.session?.sets.first?.warmup, true)
    XCTAssertEqual(s.session?.sets.first?.comparable, false)
    XCTAssertFalse(
      s.addCompletedSet(exercise: Exercise.catalog[0], weight: 10, reps: 0, minutes: 0))
  }
  func testRepProgressAndWarmupExclusion() {
    let s = GymStore(defaults: defaults)
    let split = Workout(name: "Arms", exercises: [Exercise.catalog[0]])
    for reps in [10, 12] {
      s.startSession(workout: split)
      s.startSet(weight: 20, unit: "kg")
      s.finishSet(reps: reps, minutes: 0)
      s.finish()
      s.summary = nil
    }
    XCTAssertEqual(
      s.repProgress(for: Exercise.catalog[0], split: split, weightKG: 20).map(\.reps), [10, 12])
    var set = s.data.history[0].sets[0]
    set.warmup = true
    XCTAssertTrue(s.editSet(set, sessionID: s.data.history[0].id))
    XCTAssertEqual(s.repProgress(for: Exercise.catalog[0], split: split, weightKG: 20).count, 1)
    XCTAssertEqual(s.biggestLifts.first?.set.reps, 10)
  }
  func testTimedSetResetAndBaselinePersistenceDoNotOverwriteHistory() {
    let s = GymStore(defaults: defaults)
    s.updateProfile { $0.baseline = RoutineBaseline(duration: 60, visits: 3, scrolling: 10) }
    ready(s)
    s.finishSet(reps: 10, minutes: 0)
    s.chooseExercise(Exercise.catalog.first { $0.timed }!)
    s.startSet(weight: 0, unit: "kg")
    XCTAssertEqual(s.session?.draftMinutes, 0)
    let loaded = GymStore(defaults: defaults)
    XCTAssertEqual(loaded.session?.sets.count, 1)
    XCTAssertEqual(loaded.profile.baseline?.weeklyFeedMinutes, 30)
  }
  func testFirstExerciseHasNoInventedWeightAndInvalidDraftSurvives() {
    let s = GymStore(defaults: defaults)
    s.startSession()
    s.chooseExercise(Exercise.catalog[0])
    XCTAssertEqual(s.session?.weightIsSet, false)
    XCTAssertEqual(s.session?.draftRepsText, "")
    s.updateWeight(22.5, unit: "kg")
    s.updateRepText("0")
    s.chooseExercise(Exercise.catalog[1])
    s.chooseExercise(Exercise.catalog[0])
    XCTAssertEqual(s.session?.weightKG, 22.5)
    XCTAssertEqual(s.session?.weightIsSet, true)
    XCTAssertEqual(s.session?.draftRepsText, "0")
    XCTAssertEqual(GymStore(defaults: defaults).session?.draftRepsText, "0")
    s.startSet(weight: 22.5, unit: "kg")
    s.finishSet(reps: 0, minutes: 0)
    XCTAssertTrue(s.session!.sets.isEmpty)
  }

}
