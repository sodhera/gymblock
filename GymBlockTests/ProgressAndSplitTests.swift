import XCTest

@testable import GymBlock

@MainActor final class ProgressAndSplitTests: XCTestCase {
  private var defaults: UserDefaults!
  private var domain: String!
  override func setUp() {
    super.setUp()
    domain = "GymBlockProgress.\(UUID())"
    defaults = UserDefaults(suiteName: domain)!
  }
  override func tearDown() {
    defaults.removePersistentDomain(forName: domain)
    super.tearDown()
  }
  private func logged(_ store: GymStore, split: Workout?, weight: Double, reps: Int) {
    store.startSession(workout: split)
    store.chooseExercise(Exercise.catalog[0])
    store.startSet(weight: weight, unit: "kg")
    store.finishSet(reps: reps, minutes: 0)
    store.finish()
    store.summary = nil
  }
  func testSplitStartsFocusedImmediatelyAndPersistsStableIdentityAfterRename() {
    let store = GymStore(defaults: defaults)
    let id = UUID()
    XCTAssertTrue(
      store.saveSplit(id: id, name: "Arms", exercises: [Exercise.catalog[0], Exercise.catalog[1]]))
    let split = store.data.workouts[0]
    store.startSession(workout: split)
    XCTAssertTrue(store.session!.isBlockingSimulated)
    XCTAssertEqual(store.session?.stage, .setup)
    XCTAssertEqual(store.session?.exercises.count, 2)
    XCTAssertEqual(store.session?.splitID, id)
    store.chooseExercise(Exercise.catalog[0])
    store.startSet(weight: 20, unit: "kg")
    store.finishSet(reps: 10, minutes: 0)
    store.finish()
    XCTAssertTrue(store.saveSplit(id: id, name: "Monday", exercises: split.exercises.reversed()))
    XCTAssertEqual(GymStore(defaults: defaults).splitSessions(store.data.workouts[0]).count, 1)
    XCTAssertEqual(store.data.workouts[0].exercises.first?.id, split.exercises.last?.id)
  }
  func testSplitRejectsEmptyDuplicateNamesAndDeduplicatesExercises() {
    let store = GymStore(defaults: defaults)
    XCTAssertFalse(store.saveSplit(id: UUID(), name: " ", exercises: [Exercise.catalog[0]]))
    XCTAssertFalse(store.saveSplit(id: UUID(), name: "Arms", exercises: []))
    XCTAssertTrue(
      store.saveSplit(
        id: UUID(), name: "Arms", exercises: [Exercise.catalog[0], Exercise.catalog[0]]))
    XCTAssertFalse(store.saveSplit(id: UUID(), name: "arms", exercises: [Exercise.catalog[1]]))
    XCTAssertEqual(store.data.workouts[0].exercises.count, 1)
    store.deleteSplit(store.data.workouts[0].id)
    XCTAssertTrue(GymStore(defaults: defaults).data.workouts.isEmpty)
  }
  func testDirectFinishStartsRestAndRejectsDuplicateOrInvalidSets() {
    let store = GymStore(defaults: defaults)
    store.startSession()
    store.chooseExercise(Exercise.catalog[0])
    store.startSet(weight: 501, unit: "kg")
    XCTAssertEqual(store.session?.stage, .setup)
    store.startSet(weight: 22.5, unit: "kg")
    store.finishSet(reps: 0, minutes: 0)
    XCTAssertTrue(store.session!.sets.isEmpty)
    store.finishSet(reps: 1000, minutes: 0)
    XCTAssertTrue(store.session!.sets.isEmpty)
    store.finishSet(reps: 12, minutes: 0)
    store.finishSet(reps: 12, minutes: 0)
    XCTAssertEqual(store.session?.sets.count, 1)
    XCTAssertEqual(store.session?.stage, .rest)
    XCTAssertNotNil(store.session?.restStarted)
    store.startSet(weight: 22.5, unit: "kg")
    XCTAssertEqual(store.session?.stage, .active)
    XCTAssertNil(store.session?.restStarted)
    store.updateDraft(reps: 8)
    XCTAssertEqual(GymStore(defaults: defaults).session?.draftReps, 8)
  }
  func testProgressUsesOnlyMatchingSplitExerciseAndRepCount() {
    let store = GymStore(defaults: defaults)
    let split = Workout(name: "Arms", exercises: [Exercise.catalog[0]])
    logged(store, split: split, weight: 10, reps: 10)
    logged(store, split: split, weight: 12, reps: 10)
    logged(store, split: split, weight: 15, reps: 3)
    logged(store, split: nil, weight: 20, reps: 10)
    let points = store.progress(for: Exercise.catalog[0], split: split, reps: 10)
    XCTAssertEqual(points.map(\.weightKG), [10, 12])
    XCTAssertEqual(store.biggestLifts.first?.set.weightKG, 20)
    XCTAssertEqual(store.latestSet(for: Exercise.catalog[0], split: split)?.reps, 3)
  }
  func testDemoLoadsOnceWithoutOverwritingRealWorkAndHasNoFutureSessions() {
    let store = GymStore(defaults: defaults)
    store.updateProfile {
      $0.name = "Sam"
      $0.language = "es"
    }
    XCTAssertTrue(store.loadDemoIfEmpty())
    XCTAssertEqual(store.profile.name, "Sam")
    XCTAssertEqual(store.profile.language, "es")
    XCTAssertEqual(store.data.workouts.count, 3)
    XCTAssertGreaterThan(store.data.history.count, 10)
    XCTAssertTrue((5...6).contains(store.activeWeekStreak))
    XCTAssertFalse(
      store.data.history.contains {
        $0.started > Date() || ($0.ended ?? Date()) > Date()
          || $0.sets.contains { $0.date > Date() }
      })
    let count = store.data.history.count
    XCTAssertFalse(store.loadDemoIfEmpty())
    let split = store.data.workouts[0]
    logged(store, split: split, weight: 25, reps: 10)
    XCTAssertFalse(store.loadDemoIfEmpty())
    let loaded = GymStore(defaults: defaults)
    XCTAssertEqual(loaded.data.history.count, count + 1)
    XCTAssertEqual(loaded.data.demoLoaded, true)
  }
  func testLegacyLocalDataStillDecodesWithoutNewOptionalFields() throws {
    let store = GymStore(defaults: defaults)
    logged(store, split: nil, weight: 10, reps: 10)
    var object =
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(store.data)) as! [String: Any]
    object.removeValue(forKey: "demoLoaded")
    var history = object["history"] as! [[String: Any]]
    for i in history.indices {
      history[i].removeValue(forKey: "splitID")
      history[i].removeValue(forKey: "draftReps")
      history[i].removeValue(forKey: "draftMinutes")
    }
    object["history"] = history
    defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: GymStore.storageKey)
    XCTAssertEqual(GymStore(defaults: defaults).data.history.first?.sets.count, 1)
  }
}
