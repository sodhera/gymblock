import XCTest
@testable import GymBlock

@MainActor final class GymStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var domain: String!
    override func setUp() {
        super.setUp()
        domain = "GymBlockTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: domain)!
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: domain)
        super.tearDown()
    }
    func testBlockStartsBeforeWorkoutChoiceAndEndsBeforeSummary() {
        let store = GymStore(defaults: defaults)
        store.startSession()
        XCTAssertTrue(store.session!.isBlockingSimulated)
        XCTAssertEqual(store.session?.stage, .exercise)
        store.chooseWorkout(nil)
        store.chooseExercise(Exercise.catalog[0])
        store.startSet(weight: 10, unit: "kg")
        store.showLog()
        store.logSet(reps: 12, minutes: 0)
        store.finish()
        XCTAssertNil(store.session)
        XCTAssertFalse(store.summary!.isBlockingSimulated)
        XCTAssertEqual(store.data.history.count, 1)
        XCTAssertEqual(store.summary?.totalReps, 12)
        XCTAssertEqual(store.summary?.volumeKG, 120)
    }
    func testPoundsConversionRoundTripAndPersistence() {
        let store = GymStore(defaults: defaults)
        store.updateProfile { $0.name = "Sirish"; $0.language = "en"; $0.onboarded = true; $0.unit = "lb" }
        store.startSession(); store.chooseWorkout(nil); store.chooseExercise(Exercise.catalog[0])
        store.startSet(weight: 20, unit: "lb"); store.showLog(); store.logSet(reps: 8, minutes: 0)
        let loaded = GymStore(defaults: defaults)
        XCTAssertEqual(loaded.profile.name, "Sirish")
        XCTAssertEqual(loaded.session?.stage, .rest)
        XCTAssertEqual(loaded.session!.sets[0].weightKG, 9.0718474, accuracy: 0.000001)
        XCTAssertEqual(GymStore.displayedWeight(loaded.session!.sets[0].weightKG, unit: "lb"), 20, accuracy: 0.000001)
        loaded.finish()
        XCTAssertEqual(GymStore(defaults: defaults).data.history.count, 1)
    }
    func testInvalidAndDuplicateLoggingCannotCreateSets() {
        let store = GymStore(defaults: defaults)
        store.startSession(); store.chooseWorkout(nil); store.chooseExercise(Exercise.catalog[0])
        store.startSet(weight: -2, unit: "kg")
        XCTAssertEqual(store.session?.stage, .setup)
        store.startSet(weight: .infinity, unit: "kg")
        XCTAssertEqual(store.session?.stage, .setup)
        store.startSet(weight: 0, unit: "kg"); store.showLog()
        store.logSet(reps: 0, minutes: 0)
        XCTAssertTrue(store.session!.sets.isEmpty)
        store.logSet(reps: 10, minutes: 0); store.logSet(reps: 10, minutes: 0)
        XCTAssertEqual(store.session?.sets.count, 1)
    }
    func testDurationLoggingAndSavedWorkoutDeduplication() {
        let store = GymStore(defaults: defaults)
        let run = Exercise.catalog.first { $0.id == "run" }!
        store.startSession(); store.chooseWorkout(nil); store.chooseExercise(run)
        store.startSet(weight: 0, unit: "kg"); store.showLog()
        store.logSet(reps: 99, minutes: -1)
        XCTAssertTrue(store.session!.sets.isEmpty)
        store.logSet(reps: 99, minutes: 5)
        store.anotherSet(); store.startSet(weight: 0, unit: "kg"); store.showLog(); store.logSet(reps: 0, minutes: 3)
        store.finish()
        XCTAssertEqual(store.summary?.totalReps, 0)
        XCTAssertEqual(store.summary!.sets.reduce(0) { $0 + $1.minutes }, 8)
        store.saveWorkout(from: store.summary!, name: "Morning")
        let savedID = store.data.workouts[0].id
        store.saveWorkout(from: store.summary!, name: "Morning")
        XCTAssertEqual(store.data.workouts.count, 1)
        XCTAssertEqual(store.data.workouts[0].id, savedID)
        XCTAssertEqual(store.data.workouts[0].exercises.count, 1)
    }
    func testEmptySessionDoesNotCountAndMultipleSameDayWorkoutsCountOneDay() {
        let store = GymStore(defaults: defaults)
        store.startSession(); store.finish()
        XCTAssertTrue(store.data.history.isEmpty)
        XCTAssertEqual(store.weekCount, 0)
        for _ in 0..<2 {
            store.startSession(); store.chooseWorkout(nil); store.chooseExercise(Exercise.catalog[0]); store.startSet(weight: 5, unit: "kg"); store.showLog(); store.logSet(reps: 5, minutes: 0); store.finish()
        }
        XCTAssertEqual(store.data.history.count, 2)
        XCTAssertEqual(store.weekCount, 1)
    }
    func testRestDeadlineAndLocalPreferencesSurviveRelaunch() {
        let store = GymStore(defaults: defaults)
        store.updateProfile { $0.blockWholePhone = false; $0.blockedApps = ["YouTube"]; $0.favorites = ["curl", "run"]; $0.training = ["Cardio", "Weightlifting"] }
        XCTAssertEqual(store.favoriteWorkout?.exercises.count, 2)
        store.startSession(); store.chooseWorkout(store.favoriteWorkout); store.chooseExercise(Exercise.catalog[0]); store.startSet(weight: 10, unit: "kg"); store.showLog(); store.logSet(reps: 8, minutes: 0); store.setRest(seconds: 60)
        let loaded = GymStore(defaults: defaults)
        XCTAssertEqual(loaded.profile.blockedApps, ["YouTube"])
        XCTAssertEqual(loaded.session?.stage, .rest)
        XCTAssertNotNil(loaded.session?.restEnds)
        loaded.anotherSet()
        XCTAssertNil(loaded.session?.restEnds)
    }
}
