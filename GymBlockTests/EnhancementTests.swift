import AVFoundation
import XCTest
@testable import GymBlock

@MainActor final class EnhancementTests: XCTestCase {
  func testScrollingUsesGapsNotSetCountAndPreservesUnknowns() {
    var b = RoutineBaseline(duration: 60, visits: 3, exercises: 6, sets: 3,
      scrollsBetweenSets: true, minutesPerBreak: 2)
    XCTAssertEqual(b.breakCount, 17)
    XCTAssertEqual(b.feedMinutes, 34)
    XCTAssertEqual(b.weeklyFeedMinutes, 102)
    b.exercises = 1; b.sets = 1
    XCTAssertEqual(b.feedMinutes, 0)
    b.minutesPerBreak = nil
    XCTAssertNil(b.feedMinutes)
    b.scrollsBetweenSets = false
    XCTAssertEqual(b.feedMinutes, 0)
    b.scrollsBetweenSets = nil; b.scrolling = 10
    XCTAssertEqual(b.weeklyFeedMinutes, 30) // Previously saved survey answer remains attributed.
    b.scrollsBetweenSets = true; b.minutesPerBreak = 5; b.exercises = 6; b.sets = 3
    XCTAssertEqual(b.feedMinutes, 85)
    XCTAssertFalse(b.scrollingValid)
    XCTAssertNil(b.weeklyFeedMinutes)
  }
  func testScrollingUsesIndividualSetsAndUnknownVisitCount() {
    var b = RoutineBaseline(visits: 3, details: [BaselineExercise(sets: 3), BaselineExercise(sets: 2)],
      scrollsBetweenSets: true, minutesPerBreak: 6)
    XCTAssertEqual(b.breakCount, 4)
    XCTAssertEqual(b.feedMinutes, 24)
    XCTAssertEqual(b.weeklyFeedMinutes, 72)
    b.visits = nil
    XCTAssertNil(b.weeklyFeedMinutes)
    b.details[0].sets = nil
    XCTAssertNil(b.feedMinutes)
  }
  func testTrainingVolumeCountsActualRepSetsWithoutInventingBodyweight() {
    var s = Session()
    s.sets = [
      LoggedSet(exercise: Exercise.catalog[0], weightKG: 10, reps: 10, minutes: 0),
      LoggedSet(exercise: Exercise.catalog[0], weightKG: 5, reps: 8, minutes: 0, warmup: true),
      LoggedSet(exercise: Exercise.catalog.first { $0.id == "crunch" }!, weightKG: 0, reps: 12, minutes: 0),
      LoggedSet(exercise: Exercise.catalog[0], weightKG: 500, reps: 0, minutes: 0, unsuccessful: true),
      LoggedSet(exercise: Exercise.catalog.first { $0.timed }!, weightKG: 100, reps: 100, minutes: 2)
    ]
    XCTAssertEqual(s.totalReps, 30)
    XCTAssertEqual(s.volumeKG, 140)
    XCTAssertEqual(s.repSets.count, 3)
    XCTAssertEqual(GymStore.displayedWeight(s.volumeKG, unit: "lb"), 140 * 2.2046226218, accuracy: 0.00001)
  }
  func testTrainingPointsFollowCorrectionsDeletionAndSplitScope() {
    let domain = "Enhancements.\(UUID())"
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = GymStore(defaults: defaults)
    let split = Workout(name: "Arms", exercises: [Exercise.catalog[0]])
    store.startSession(workout: split)
    store.startSet(weight: 20, unit: "kg")
    store.finishSet(reps: 8, minutes: 0)
    store.finish()
    let session = store.data.history[0]
    XCTAssertEqual(store.trainingPoints(splitID: split.id)[0].volumeKG, 160)
    XCTAssertTrue(store.trainingPoints(splitID: UUID()).isEmpty)
    var correction = session.sets[0]; correction.reps = 7
    XCTAssertTrue(store.editSet(correction, sessionID: session.id))
    XCTAssertEqual(store.trainingPoints()[0].reps, 7)
    XCTAssertEqual(store.trainingPoints()[0].volumeKG, 140)
    store.deleteSet(correction, sessionID: session.id)
    XCTAssertTrue(store.trainingPoints().isEmpty)
    store.undoDelete()
    XCTAssertEqual(store.trainingPoints()[0].volumeKG, 140)
  }
  func testBundledCuesDecodeAsShortAudioAndLegacyAnswersDecode() async throws {
    for name in ["advance", "complete"] {
      let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "wav"))
      let player = try AVAudioPlayer(contentsOf: url)
      XCTAssertGreaterThan(player.duration, 0.05)
      XCTAssertLessThan(player.duration, 0.5)
    }
    var profile = Profile()
    profile.hapticsEnabled = false
    profile.soundEnabled = true
    let played = await OnboardingFeedback.shared.playSound(profile: profile)
    XCTAssertTrue(played)
    profile.soundEnabled = false
    let muted = await OnboardingFeedback.shared.playSound(profile: profile)
    XCTAssertFalse(muted)
    let b = try JSONDecoder().decode(RoutineBaseline.self, from:
      Data("{\"distractions\":[],\"reps\":\"\",\"timed\":false,\"details\":[],\"scrolling\":10}".utf8))
    XCTAssertEqual(b.feedMinutes, 10)
    XCTAssertNil(b.scrollsBetweenSets)
  }
}
