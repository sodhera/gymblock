import XCTest

@testable import GymBlock

@MainActor final class GymNavigationTests: XCTestCase {
  private var defaults: UserDefaults!
  private var domain: String!
  override func setUp() {
    domain = "Navigation.\(UUID())"
    defaults = UserDefaults(suiteName: domain)!
  }
  override func tearDown() { defaults.removePersistentDomain(forName: domain) }
  private func active() -> GymStore {
    let store = GymStore(defaults: defaults)
    store.startSession()
    store.chooseExercise(Exercise.catalog[0])
    store.startSet(weight: 20, unit: "kg")
    return store
  }
  func testCounterCountsUpSurvivesReloadAndExerciseChanges() {
    let store = active()
    store.finishSet(reps: 8, minutes: 0)
    let origin = store.session!.restStarted!
    XCTAssertEqual(store.restElapsed(at: origin), 0)
    XCTAssertEqual(store.restElapsed(at: origin.addingTimeInterval(95)), 95)
    store.chooseExercise(Exercise.catalog[1])
    XCTAssertEqual(store.session?.restStarted, origin)
    let reloaded = GymStore(defaults: defaults)
    XCTAssertEqual(reloaded.restElapsed(at: origin.addingTimeInterval(130)), 130)
    reloaded.startSet(weight: 10, unit: "kg")
    XCTAssertNil(reloaded.session?.restStarted)
  }
  func testSavingBeforeSwitchKeepsOldSetAndSplitUnchanged() {
    let store = GymStore(defaults: defaults)
    let split = Workout(name: "Arms", exercises: [Exercise.catalog[0]])
    store.data.workouts = [split]
    store.startSession(workout: split)
    store.startSet(weight: 20, unit: "kg")
    XCTAssertTrue(store.switchExercise(to: Exercise.catalog[1], savingCurrent: true, reps: 7))
    XCTAssertEqual(store.session?.selected?.id, "hammer")
    XCTAssertEqual(store.session?.sets.first?.exercise.id, "curl")
    XCTAssertEqual(store.session?.sets.first?.reps, 7)
    XCTAssertEqual(store.session?.sets.first?.weightKG, 20)
    XCTAssertEqual(store.session?.stage, .rest)
    XCTAssertNotNil(store.session?.restStarted)
    XCTAssertEqual(store.data.workouts.first?.exercises.map(\.id), ["curl"])
  }
  func testInvalidSaveDoesNotSwitchOrDiscardAndDiscardPreservesEarlierSets() {
    let store = active()
    store.finishSet(reps: 8, minutes: 0)
    store.startSet(weight: 20, unit: "kg")
    store.updateRepText("0")
    XCTAssertFalse(store.switchExercise(to: Exercise.catalog[1], savingCurrent: true, reps: 0))
    XCTAssertEqual(store.session?.stage, .active)
    XCTAssertEqual(store.session?.selected?.id, "curl")
    XCTAssertTrue(store.switchExercise(to: Exercise.catalog[1], savingCurrent: false))
    XCTAssertEqual(store.session?.sets.count, 1)
    XCTAssertEqual(store.session?.sets.first?.reps, 8)
    XCTAssertEqual(store.session?.stage, .rest)
    XCTAssertNil(store.session?.setStarted)
    XCTAssertNotNil(store.session?.restStarted)
  }
  func testLegacyRestDeadlineMigratesFromLoggedSetDate() throws {
    var data = LocalData()
    var session = Session()
    let set = LoggedSet(exercise: Exercise.catalog[0], weightKG: 20, reps: 10, minutes: 0)
    session.sets = [set]
    session.selected = set.exercise
    session.stage = .rest
    session.restSourceID = set.id
    session.restEnds = set.date.addingTimeInterval(60)
    data.session = session
    defaults.set(try JSONEncoder().encode(data), forKey: GymStore.storageKey)
    let migrated = GymStore(defaults: defaults)
    XCTAssertEqual(migrated.session?.restStarted, set.date)
    XCTAssertNil(migrated.session?.restEnds)
    XCTAssertEqual(migrated.restElapsed(at: set.date.addingTimeInterval(90)), 90)
    XCTAssertEqual(GymStore(defaults: defaults).session?.restStarted, set.date)
  }
  func testTimedActiveSwitchLogsDurationOnlyOnOriginalExercise() {
    let store = GymStore(defaults: defaults)
    store.startSession()
    store.chooseExercise(Exercise.catalog.first { $0.id == "run" }!)
    store.startSet(weight: 0, unit: "kg")
    XCTAssertTrue(store.switchExercise(to: Exercise.catalog[0], savingCurrent: true, minutes: 3.5))
    XCTAssertEqual(store.session?.sets.first?.exercise.id, "run")
    XCTAssertEqual(store.session?.sets.first?.minutes, 3.5)
    XCTAssertEqual(store.session?.sets.first?.reps, 0)
  }
}
