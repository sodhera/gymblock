import XCTest

@testable import GymBlock

@MainActor final class JourneyV2Tests: XCTestCase {
  private func baseline() -> RoutineBaseline {
    RoutineBaseline(
      duration: 60, exercises: 6, sets: 3, reps: "10",
      trainingDays: 3, scrollingMinutes: 2, scrollFrequency: .yes, visitsPerTrainingDay: 1)
  }
  func testFourWeekNumbersKeepDaysDistinctFromLegacyVisits() {
    var b = baseline()
    b.visits = 10
    XCTAssertEqual(b.breakCount, 17)
    XCTAssertEqual(b.attentionMinutes, 34)
    XCTAssertEqual(b.fourWeekAttention, 408)
    XCTAssertEqual(JourneyFormat.minutes(b.fourWeekAttention!), "6 h 48 min")
    XCTAssertEqual(b.fourWeekSets, 216)
    XCTAssertEqual(b.fourWeekReps, 2160...2160)
    XCTAssertEqual(b.visits, 10)
    b.visitsPerTrainingDay = 2
    XCTAssertNil(b.attentionMinutes)
    XCTAssertNil(b.fourWeekAttention)
    XCTAssertEqual(b.fourWeekSets, 216)
  }
  func testSometimesFractionsAndMissingAnswersNeverBecomeInventedSavings() {
    var b = baseline()
    b.scrollFrequency = .sometimes
    XCTAssertNil(b.attentionMinutes)
    b.scrollingBreaks = 5
    b.scrollingMinutes = 0.5
    XCTAssertEqual(b.attentionMinutes, 2.5)
    XCTAssertEqual(b.fourWeekAttention, 30)
    b.scrollFrequency = .no
    XCTAssertEqual(b.attentionMinutes, 0)
    XCTAssertFalse(b.canShowAttention)
    b.scrollFrequency = nil
    XCTAssertNil(b.attentionMinutes)
    b.scrollFrequency = .yes
    b.scrollingBreaks = 18
    XCTAssertNil(b.attentionMinutes)
    b.scrollingBreaks = 5
    b.scrollingMinutes = 12
    XCTAssertFalse(b.canShowAttention)  // 60 scrolling minutes leaves no workout time.
    b.duration = nil
    XCTAssertFalse(b.canShowAttention)
    b.trainingDays = nil
    XCTAssertNil(b.fourWeekSets)
    b.timed = true
    XCTAssertNil(b.fourWeekReps)
  }
  func testLegacyGroupedPageMigratesAndNewFieldsDecodeOptionally() throws {
    var profile = Profile()
    profile.onboardingStepID = "routine"
    XCTAssertEqual(OnboardingStep.restored(profile), .reps)
    profile.onboardingStepID = "loggingHabits"
    XCTAssertEqual(OnboardingStep.restored(profile), .loggingHabits)
    let encoded = try JSONEncoder().encode(baseline())
    var object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    for key in ["trainingDays", "scrollingMinutes", "scrollFrequency", "visitsPerTrainingDay"] {
      object.removeValue(forKey: key)
    }
    let old = try JSONDecoder().decode(
      RoutineBaseline.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(old.trainingDays)
    XCTAssertNil(old.scrollingMinutes)
    XCTAssertEqual(old.reps, "10")
  }
  func testTimingPersistsAndExcludesRepEditingDelayWithGapAcrossExercises() {
    let domain = "JourneyTiming.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    store.startSession()
    store.chooseExercise(Exercise.catalog[0])
    store.startSet(weight: 20, unit: "kg")
    let start = Date().addingTimeInterval(-50)
    store.data.session?.setStarted = start
    store.showLog()
    let stop = store.session!.setStopped!
    store.data.session?.setStopped = stop.addingTimeInterval(-10)
    store.logSet(reps: 10, minutes: 0)
    let first = store.session!.sets[0]
    XCTAssertEqual(
      first.elapsedSetSeconds!, stop.addingTimeInterval(-10).timeIntervalSince(start),
      accuracy: 0.01)
    XCTAssertEqual(first.minutes, 0)
    XCTAssertNil(first.gapBeforeSeconds)
    store.data.session?.restStarted = Date().addingTimeInterval(-80)
    store.chooseExercise(Exercise.catalog[1])
    store.startSet(weight: 15, unit: "kg")
    store.data.session?.setStarted = Date().addingTimeInterval(-35)
    store.finishSet(reps: 8, minutes: 0)
    let second = store.session!.sets[1]
    XCTAssertEqual(second.elapsedSetSeconds!, 35, accuracy: 0.1)
    XCTAssertEqual(store.session!.gapSeconds(before: second)!, 80, accuracy: 0.1)
    XCTAssertTrue(store.session!.gapCrossesExercises(before: second))
    store.finish()
    let restored = GymStore(defaults: defaults)
    XCTAssertEqual(restored.data.history[0].sets[1].gapSourceID, first.id)
    XCTAssertEqual(restored.data.history[0].sets[1].elapsedSetSeconds!, 35, accuracy: 0.1)
  }
  func testTimingCorrectionsDeletionAndCancelKeepTheirMeaning() {
    let domain = "JourneyCorrection.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    store.startSession()
    store.chooseExercise(Exercise.catalog[0])
    store.startSet(weight: 20, unit: "kg")
    store.finishSet(reps: 10, minutes: 0)
    let origin = store.session!.restStarted!
    store.startSet(weight: 20, unit: "kg")
    store.cancelSet()
    XCTAssertEqual(store.session?.restStarted, origin)
    store.startSet(weight: 20, unit: "kg")
    store.finishSet(reps: 9, minutes: 0)
    let id = store.session!.id
    var first = store.session!.sets[0]
    let second = store.session!.sets[1]
    store.deleteSet(first, sessionID: id)
    XCTAssertNil(store.session!.gapSeconds(before: second))
    store.undoDelete()
    XCTAssertNotNil(store.session!.gapSeconds(before: second))
    first.elapsedSetSeconds = .nan
    XCTAssertFalse(store.editSet(first, sessionID: id))
    first.elapsedSetSeconds = 35
    first.date = first.date.addingTimeInterval(-20)
    XCTAssertTrue(store.editSet(first, sessionID: id))
    XCTAssertNil(
      store.session!.gapSeconds(before: store.session!.sets.first { $0.id == second.id }!))
    XCTAssertEqual(store.session!.sets.first { $0.id == first.id }!.elapsedSetSeconds, 35)
    XCTAssertEqual(store.session?.totalReps, 19)
    XCTAssertEqual(store.session?.volumeKG, 380)
  }
  func testFourWeekReportFiltersActualWorkRatherThanOnboardingProjections() {
    let domain = "JourneyReport.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    let now = Date()
    let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: now)!
    var old = Session(started: cutoff.addingTimeInterval(-1))
    old.sets = [LoggedSet(exercise: Exercise.catalog[0], weightKG: 20, reps: 10, minutes: 0)]
    var boundary = Session(started: cutoff)
    boundary.sets = [LoggedSet(exercise: Exercise.catalog[0], weightKG: 20, reps: 8, minutes: 0)]
    store.data.history = [old, boundary]
    store.data.profile.baseline = baseline()
    XCTAssertEqual(store.trainingPoints().reduce(0) { $0 + $1.reps }, 18)
    XCTAssertEqual(store.trainingPoints(since: cutoff).reduce(0) { $0 + $1.reps }, 8)
    XCTAssertEqual(store.trainingPoints(since: cutoff).count, 1)
  }
  func testExplicitDemoHasCoherentSampleTimingWithoutChangingExistingWork() {
    let domain = "JourneyDemo.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    XCTAssertTrue(store.loadDemoIfEmpty())
    let sample = store.data.history[0]
    XCTAssertNil(sample.sets[0].gapBeforeSeconds)
    for index in 1..<sample.sets.count {
      let set = sample.sets[index]
      XCTAssertEqual(set.gapSourceID, sample.sets[index - 1].id)
      XCTAssertEqual(
        set.date.timeIntervalSince(sample.sets[index - 1].date),
        set.elapsedSetSeconds! + sample.gapSeconds(before: set)!, accuracy: 0.01)
    }
    let ids = store.data.history.map(\.id)
    XCTAssertFalse(store.loadDemoIfEmpty())
    XCTAssertEqual(store.data.history.map(\.id), ids)
  }

  func testV3RouteCollectsSometimesBreaksBeforeTeachingAndSkipsNoScrollReveal() {
    var b = baseline()
    b.scrollFrequency = .sometimes
    let route = OnboardingRoute.steps(b)
    XCTAssertLessThan(route.firstIndex(of: .breaks)!, route.firstIndex(of: .restHabits)!)
    XCTAssertEqual(route.last, .subscription)
    XCTAssertFalse(route.contains(.ready))
    b.scrollFrequency = .no
    b.scrollsBetweenSets = false
    let noScroll = OnboardingRoute.steps(b)
    XCTAssertFalse(noScroll.contains(.minutes))
    XCTAssertFalse(noScroll.contains(.breaks))
    XCTAssertTrue(noScroll.contains(.reveal))
  }
  func testEndingEmptySessionCreatesNeitherHistoryNorSummary() {
    let domain = "EmptyV3.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    store.startSession()
    store.finish()
    XCTAssertNil(store.session)
    XCTAssertNil(store.summary)
    XCTAssertTrue(store.data.history.isEmpty)
  }

}
