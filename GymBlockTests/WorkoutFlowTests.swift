import XCTest

@testable import GymBlock

/// The workout screen's rules: stepping, targets, what comes next, one-tap logging,
/// interruptions and like-for-like progress.
@MainActor final class WorkoutFlowTests: XCTestCase {
  private var defaults: UserDefaults!
  private var domain: String!
  override func setUp() {
    domain = "WorkoutFlow.\(UUID())"
    defaults = UserDefaults(suiteName: domain)!
  }
  override func tearDown() { defaults.removePersistentDomain(forName: domain) }
  private func exercise(_ id: String) -> Exercise { Exercise.catalog.first { $0.id == id }! }
  private func logSet(_ s: GymStore, reps: Int, kg: Double? = nil) {
    s.startSet(weight: kg ?? s.session!.weightKG, unit: "kg")
    s.data.session?.setStarted = Date().addingTimeInterval(-40)
    s.finishSet(reps: reps, minutes: 0)
  }

  func testWeightStepsSnapToThePlateGridAndStartFromAnEmptyBarOrLightDumbbell() {
    let s = GymStore(defaults: defaults)
    s.startSession()
    s.chooseExercise(exercise("curl"))
    XCTAssertEqual(s.session?.weightIsSet, false)
    s.stepWeight(1)
    XCTAssertEqual(s.session?.weightKG, 10)  // A light dumbbell.
    s.stepWeight(1)
    XCTAssertEqual(s.session?.weightKG, 12.5)
    s.updateWeight(61, unit: "kg")
    s.stepWeight(1)
    XCTAssertEqual(s.session?.weightKG, 62.5)
    s.stepWeight(-1); s.stepWeight(-1)
    XCTAssertEqual(s.session?.weightKG, 57.5)
    s.chooseExercise(exercise("bench"))
    s.stepWeight(1)
    XCTAssertEqual(s.session?.weightKG, 20)  // An empty bar.
    s.chooseExercise(exercise("squat"))
    s.stepWeight(-1)
    XCTAssertEqual(s.session?.weightKG, 0)  // Bodyweight, chosen explicitly.
    XCTAssertEqual(s.session?.weightIsSet, true)
    s.stepWeight(-1)
    XCTAssertEqual(s.session?.weightKG, 0)
  }

  func testPoundStepsAndBodyweightExercisesNeedNoWeight() {
    let s = GymStore(defaults: defaults)
    s.updateProfile { $0.unit = "lb" }
    s.startSession()
    s.chooseExercise(exercise("bench"))
    s.stepWeight(1)
    XCTAssertEqual(GymStore.displayedWeight(s.session!.weightKG, unit: "lb"), 45, accuracy: 0.001)
    s.stepWeight(1)
    XCTAssertEqual(GymStore.displayedWeight(s.session!.weightKG, unit: "lb"), 50, accuracy: 0.001)
    s.chooseExercise(exercise("pull-up"))
    XCTAssertEqual(s.session?.weightIsSet, true)
    XCTAssertEqual(s.session?.weightKG, 0)
  }

  func testRepsStepToZeroAndZeroBecomesAMissedAttempt() {
    let s = GymStore(defaults: defaults)
    s.startSession()
    s.chooseExercise(exercise("curl"))
    s.updateWeight(15, unit: "kg")
    s.updateDraft(reps: 2)
    s.startSet(weight: 15, unit: "kg")
    s.stepReps(-1); s.stepReps(-1); s.stepReps(-1)
    XCTAssertEqual(s.draftRepCount, 0)
    s.recordAttempt()
    XCTAssertEqual(s.session?.sets.first?.unsuccessful, true)
    XCTAssertEqual(s.doneSets(exercise("curl")), 0)  // A miss isn't a done set.
    XCTAssertEqual(s.session?.stage, .rest)
  }

  func testTargetComesFromLastTimeAndNextExerciseWrapsUntilTheSplitIsDone() {
    let s = GymStore(defaults: defaults)
    let split = Workout(name: "Arms", exercises: [exercise("curl"), exercise("hammer"), exercise("triceps")])
    s.data.workouts = [split]
    XCTAssertEqual(s.targetSets(exercise("curl")), 3)  // No history: three.
    s.startSession(workout: split)
    s.updateWeight(15, unit: "kg")
    for _ in 0..<4 { logSet(s, reps: 10) }
    s.finish(); s.summary = nil
    XCTAssertEqual(s.targetSets(exercise("curl")), 4)  // Last time: four.

    s.startSession(workout: split)
    XCTAssertEqual(s.session?.selected?.id, "curl")
    for _ in 0..<3 { logSet(s, reps: 10) }
    XCTAssertEqual(s.nextExercise?.id, "hammer")  // Already suggested before the fourth.
    logSet(s, reps: 10)
    s.chooseExercise(exercise("triceps"))
    XCTAssertEqual(s.session?.stage, .rest)  // Switching keeps the rest running.
    s.updateWeight(20, unit: "kg")
    for _ in 0..<3 { logSet(s, reps: 10) }
    XCTAssertEqual(s.nextExercise?.id, "hammer")  // Wraps back to the skipped one.
    XCTAssertFalse(s.splitComplete)
    s.chooseExercise(exercise("hammer"))
    s.updateWeight(12.5, unit: "kg")
    for _ in 0..<3 { logSet(s, reps: 10) }
    XCTAssertNil(s.nextExercise)
    XCTAssertTrue(s.splitComplete)
  }

  func testOneTapLoggingStartsTheRestAndNeverInventsTiming() {
    let s = GymStore(defaults: defaults)
    s.updateProfile { $0.timeSets = false }
    XCTAssertFalse(s.timesSets)
    s.startSession()
    s.chooseExercise(exercise("bench"))
    XCTAssertFalse(s.logQuickSet())  // No weight chosen yet.
    s.updateWeight(60, unit: "kg")
    s.updateDraft(reps: 8)
    XCTAssertTrue(s.logQuickSet())
    XCTAssertEqual(s.session?.stage, .rest)
    XCTAssertNotNil(s.session?.restStarted)
    XCTAssertEqual(s.session?.sets.first?.timingUnknown, true)
    XCTAssertNil(s.session?.sets.first?.gapBeforeSeconds)
    XCTAssertTrue(s.logQuickSet())
    XCTAssertEqual(s.session?.sets.last?.gapUnknown, true)
    XCTAssertEqual(s.session?.sets.last?.weightKG, 60)
    XCTAssertEqual(s.session?.sets.last?.reps, 8)
    s.chooseExercise(exercise("run"))
    XCTAssertFalse(s.logQuickSet())  // Timed exercises always use the clock.
  }

  func testImplausibleSetClocksAreNotTreatedAsMeasured() {
    let s = GymStore(defaults: defaults)
    s.startSession()
    s.chooseExercise(exercise("bench"))
    s.updateWeight(60, unit: "kg")
    s.startSet(weight: 60, unit: "kg")
    s.finishSet(reps: 5, minutes: 0)  // Start and Finish back to back.
    XCTAssertEqual(s.session?.sets.last?.timingUnknown, true)
    XCTAssertNil(s.session?.sets.last?.displayedSetSeconds)
    logSet(s, reps: 5)
    XCTAssertNil(s.session?.sets.last?.timingUnknown)
    s.startSet(weight: 60, unit: "kg")
    s.data.session?.setStarted = Date().addingTimeInterval(-20 * 60)  // Finish forgotten.
    s.finishSet(reps: 5, minutes: 0)
    XCTAssertEqual(s.session?.sets.last?.timingUnknown, true)
    XCTAssertFalse(GymStore.implausible(25 * 60, timed: true))  // A long run is real.
  }

  func testAWorkoutLeftRunningEndsAtItsLastSetAndDropsTheOpenSet() {
    let s = GymStore(defaults: defaults)
    s.startSession()
    s.chooseExercise(exercise("bench"))
    s.updateWeight(60, unit: "kg")
    logSet(s, reps: 5)
    XCTAssertFalse(s.isStale())
    let lastSet = Date().addingTimeInterval(-2 * 3600)
    s.data.session?.started = lastSet.addingTimeInterval(-30 * 60)
    s.data.session?.sets[0].date = lastSet
    s.data.session?.restStarted = lastSet
    XCTAssertTrue(s.isStale())
    s.startSet(weight: 60, unit: "kg")
    XCTAssertFalse(s.isStale())  // Starting a set is activity.
    s.data.session?.setStarted = Date().addingTimeInterval(-90 * 60)
    XCTAssertTrue(s.isStale())
    s.finishStale()
    XCTAssertNil(s.session)
    XCTAssertEqual(s.data.history.first?.sets.count, 1)
    XCTAssertEqual(s.data.history.first?.ended, lastSet)
    XCTAssertEqual(s.data.history.first!.duration, 30 * 60, accuracy: 1)
  }

  func testSplitsRotateOnlyAfterAWorkoutWithSets() {
    let s = GymStore(defaults: defaults)
    let a = Workout(name: "A", exercises: [exercise("curl")])
    let b = Workout(name: "B", exercises: [exercise("bench")])
    s.data.workouts = [a, b]
    s.startSession(workout: a)
    s.finish()
    XCTAssertNil(s.profile.preferredSplitID)  // Nothing logged: no rotation.
    s.startSession(workout: a)
    s.updateWeight(10, unit: "kg")
    logSet(s, reps: 10)
    s.finish(); s.summary = nil
    XCTAssertEqual(s.profile.preferredSplitID, b.id)
    s.startSession(workout: b)
    s.updateWeight(60, unit: "kg")
    logSet(s, reps: 5)
    s.finish()
    XCTAssertEqual(s.profile.preferredSplitID, a.id)  // Wraps around.
  }

  func testImprovementsHoldRepsOrLoadConstantWithinTheSameSplit() {
    let s = GymStore(defaults: defaults)
    let arms = Workout(name: "Arms", exercises: [exercise("curl")])
    s.data.workouts = [arms]
    func workout(_ kg: Double, _ reps: Int) -> Session {
      s.startSession(workout: arms)
      s.updateWeight(kg, unit: "kg")
      logSet(s, reps: reps)
      s.finish()
      defer { s.summary = nil }
      return s.summary!
    }
    _ = workout(20, 10)
    let heavier = s.improvements(in: workout(22.5, 10))
    XCTAssertEqual(heavier.first?.weightGainKG ?? 0, 2.5, accuracy: 0.001)
    XCTAssertEqual(heavier.first?.reps, 10)
    let moreReps = s.improvements(in: workout(22.5, 12))
    XCTAssertEqual(moreReps.first?.repGain, 2)
    XCTAssertNil(moreReps.first?.weightGainKG)
    XCTAssertTrue(s.improvements(in: workout(25, 6)).isEmpty)  // Heavier but fewer reps: not like for like.
    // A free workout doesn't compare against the split.
    s.startSession()
    s.chooseExercise(exercise("curl"))
    s.updateWeight(40, unit: "kg")
    logSet(s, reps: 10)
    s.finish()
    XCTAssertTrue(s.improvements(in: s.summary!).isEmpty)
  }

  func testRestLengthIsBoundedAndPreviousBestIgnoresTheCurrentWorkout() {
    let s = GymStore(defaults: defaults)
    XCTAssertEqual(s.restTarget, 90)
    s.setRestTarget(5)
    XCTAssertEqual(s.restTarget, 90)
    s.setRestTarget(120)
    XCTAssertEqual(s.restTarget, 120)
    s.startSession()
    s.chooseExercise(exercise("bench"))
    s.updateWeight(60, unit: "kg")
    logSet(s, reps: 5)
    XCTAssertNil(s.previousBest(exercise("bench")))  // Only earlier workouts count as "Last time".
    s.finish(); s.summary = nil
    s.startSession()
    s.chooseExercise(exercise("bench"))
    XCTAssertEqual(s.previousBest(exercise("bench"))?.set.weightKG, 60)
    XCTAssertEqual(s.session?.weightKG, 60)  // Prefilled from last time.
  }

  func testLockScreenButtonStartsAndFinishesSetsAndIgnoresStaleTaps() {
    let s = GymStore(defaults: defaults)
    s.startSession()
    s.chooseExercise(exercise("bench"))
    let id = s.session!.id.uuidString
    XCTAssertFalse(s.stepFromLockScreen(id, expecting: "start"))  // No weight yet: the app needs you.
    s.updateWeight(60, unit: "kg")
    s.updateDraft(reps: 5)
    XCTAssertFalse(s.stepFromLockScreen(UUID().uuidString, expecting: "start"))  // Another workout's button.
    XCTAssertTrue(s.stepFromLockScreen(id, expecting: "start"))
    XCTAssertEqual(s.session?.stage, .active)
    XCTAssertFalse(s.stepFromLockScreen(id, expecting: "start"))  // A second, stale Start does nothing.
    s.data.session?.setStarted = Date().addingTimeInterval(-30)
    XCTAssertTrue(s.stepFromLockScreen(id, expecting: "finish"))
    XCTAssertEqual(s.session?.sets.count, 1)
    XCTAssertEqual(s.session?.sets.first?.reps, 5)
    XCTAssertEqual(s.session?.stage, .rest)
    XCTAssertFalse(s.stepFromLockScreen(id, expecting: "finish"))  // Never logs the same set twice.
    XCTAssertEqual(s.session?.sets.count, 1)
    s.updateProfile { $0.timeSets = false }
    XCTAssertTrue(s.stepFromLockScreen(id, expecting: "start"))  // One-tap logging logs straight away.
    XCTAssertEqual(s.session?.sets.count, 2)
  }

  func testAverageRestUsesOnlyKnownGapsAndDeletingAWorkoutKeepsTheRest() {
    let s = GymStore(defaults: defaults)
    s.startSession()
    s.chooseExercise(exercise("bench"))
    s.updateWeight(60, unit: "kg")
    logSet(s, reps: 5)
    s.data.session?.restStarted = Date().addingTimeInterval(-100)
    logSet(s, reps: 5)
    s.data.session?.restStarted = Date().addingTimeInterval(-80)
    logSet(s, reps: 5)
    s.data.session?.sets[2].gapUnknown = true
    XCTAssertEqual(s.session!.averageRest!, 100, accuracy: 1)
    s.finish(); s.summary = nil
    s.startSession()
    s.chooseExercise(exercise("curl"))
    s.updateWeight(10, unit: "kg")
    logSet(s, reps: 10)
    s.finish(); s.summary = nil
    let first = s.data.history.last!.id
    s.deleteWorkout(first)
    XCTAssertEqual(s.data.history.count, 1)
    XCTAssertEqual(GymStore(defaults: defaults).data.history.first?.sets.first?.exercise.id, "curl")
  }
}
