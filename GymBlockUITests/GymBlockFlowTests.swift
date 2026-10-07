import XCTest

/// Whole workouts, as a gym-goer does them: Home → workout → summary → History.
final class GymBlockFlowTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication(); app.launchArguments = ["--ui-reset", "--demo"]; app.launch()
  }
  private func tap(_ id: String) {
    let button = app.buttons[id].firstMatch
    // Form rows below the fold aren't created until scrolled to.
    for _ in 0..<5 where !button.waitForExistence(timeout: 2) { app.swipeUp() }
    XCTAssertTrue(button.waitForExistence(timeout: 6), id)
    for _ in 0..<4 { if button.isHittable { break }; app.swipeUp() }
    let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: button)
    wait(for: [ready], timeout: 6); button.tap()
  }
  /// The primary action, after the brief guard that stops double taps.
  private func primary(_ label: String? = nil) {
    let button = app.buttons["workout.primary"]
    XCTAssertTrue(button.waitForExistence(timeout: 6))
    if let label {
      let match = expectation(for: NSPredicate(format: "label BEGINSWITH %@", label), evaluatedWith: button)
      wait(for: [match], timeout: 6)
    }
    Thread.sleep(forTimeInterval: 0.7)
    button.tap()
  }
  private func fill(_ id: String, _ value: String) {
    let field = app.textFields[id]; XCTAssertTrue(field.waitForExistence(timeout: 6), id)
    field.tap()
    // Number fields select their entire content on focus.
    field.typeText(value)
  }
  private func search(_ text: String) {
    let field = app.searchFields.firstMatch; XCTAssertTrue(field.waitForExistence(timeout: 6)); field.tap(); field.typeText(text)
  }
  private func snap(_ name: String) {
    let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
  }
  private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
  private func elapsed() -> Int {
    let pieces = app.staticTexts["rest.elapsed"].label.split(separator: ":").compactMap { Int($0) }
    return pieces.count == 2 ? pieces[0] * 60 + pieces[1] : -1
  }
  private func freeWorkout() {
    tap("home.workout"); tap("choice.free")
    XCTAssertTrue(app.buttons["home.workout"].label.contains("Free workout"))
  }
  private func endWorkout() {
    tap("session.finish"); tap("session.endConfirm")
    XCTAssertTrue(app.buttons["summary.done"].waitForExistence(timeout: 6))
  }

  func testFreeWorkoutTypingCorrectionSwitchAndRelaunch() {
    snap("v6-01-home"); freeWorkout(); tap("home.start")
    search("dum"); snap("v6-02-picker"); tap("exercise.curl")
    XCTAssertEqual(app.staticTexts["set.exercise"].label, "Dumbbell curl")
    snap("v6-03-ready")
    fill("set.weight", "25"); snap("v6-04-typing")
    primary("Start set")  // Above the keyboard: typing and starting is one motion.
    fill("set.reps", "12"); snap("v6-05-active"); primary("Finish set")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 5)); snap("v6-06-rest")
    tap("set.saved"); fill("edit.reps", "7"); snap("v6-07-edit-set"); tap("edit.save")
    XCTAssertTrue(app.buttons["set.saved"].label.hasSuffix("× 7"), app.buttons["set.saved"].label)
    let before = elapsed()
    tap("set.change"); search("hammer"); tap("exercise.hammer")
    XCTAssertGreaterThanOrEqual(elapsed(), before)  // Changing exercise never resets the rest.
    snap("v6-08-switch-rest")
    fill("set.weight", "15"); primary("Start set"); fill("set.reps", "8")
    app.terminate(); app.launchArguments = []; app.launch()  // Interrupted mid-set: nothing is lost.
    XCTAssertTrue(app.buttons["workout.primary"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.buttons["workout.primary"].label, "Finish set")
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("set.change"); search("curl"); tap("exercise.curl")
    tap("switch.cancel")
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("set.change"); search("curl"); tap("exercise.curl"); tap("switch.save")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 5))
    tap("session.sets"); snap("v6-09-sets"); tap("records.done")
    endWorkout()
    XCTAssertEqual(element("summary.sets").label, "Sets, 2")
    XCTAssertEqual(element("summary.volume").label, "Weight moved, 295 kg")
    snap("v6-10-summary"); tap("summary.done")
    tap("home.history"); snap("v6-11-history"); tap("history.reps")
    XCTAssertTrue(app.staticTexts["totals.amount"].waitForExistence(timeout: 5)); snap("v6-12-reps-chart")
  }

  func testLogOutKeepsWorkoutsAndDeleteAccountErasesEverything() {
    tap("home.preferences"); tap("settings.logout"); tap("settings.logout.confirm")
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8))  // Back to onboarding.
    app.terminate(); app.launchArguments = ["--skip-onboarding"]; app.launch()  // Workouts survived the log-out.
    tap("home.history"); XCTAssertTrue(app.buttons["history.reps"].waitForExistence(timeout: 6))
    XCTAssertFalse(app.staticTexts["No workouts yet"].exists)
    app.navigationBars.buttons.firstMatch.tap()
    tap("home.preferences"); tap("settings.delete"); tap("settings.delete.confirm")
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8))
    app.terminate(); app.launchArguments = []; app.launch()
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8))  // Nothing left to resume.
  }

  func testSplitCreateRotateAndProgress() {
    XCTAssertTrue(app.buttons["home.workout"].label.contains("Push"))  // Arms was last: Push is up next.
    tap("home.workout"); snap("v6-13-choose-workout"); tap("split.add"); fill("split.name", "Monday")
    tap("split.exercises"); tap("split.exercise.curl"); tap("split.exercise.hammer"); tap("split.exercises.done"); tap("split.save")
    XCTAssertTrue(app.buttons["home.workout"].waitForExistence(timeout: 6))
    XCTAssertTrue(app.buttons["home.workout"].label.contains("Monday"))
    tap("home.start")
    XCTAssertEqual(app.staticTexts["set.exercise"].label, "Dumbbell curl")  // The split's first exercise, ready.
    primary("Start set"); fill("set.reps", "11"); primary("Finish set")
    endWorkout(); tap("summary.done")
    XCTAssertTrue(app.buttons["home.workout"].label.contains("Arms"))  // Rotated past the last split.
    tap("home.history"); tap("history.progress")
    tap("progress.scope"); app.buttons["Arms"].tap(); tap("progress.exercise.curl")
    XCTAssertTrue(app.staticTexts["progress.change"].waitForExistence(timeout: 6)); snap("v6-14-before-after")
  }

  func testMissedAttemptOneTapLoggingAndAnEmptyWorkout() {
    freeWorkout(); tap("home.start"); tap("exercise.curl")
    primary("Start set")
    for _ in 0..<12 { app.buttons["set.reps.minus"].tap() }
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "0")
    primary("Finish set")  // Zero reps is a missed attempt.
    XCTAssertTrue(app.buttons["set.saved"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["set.saved"].label.contains("Attempt"), app.buttons["set.saved"].label)
    endWorkout(); tap("summary.done")
    tap("home.preferences"); snap("v6-15-settings"); tap("settings.baseline"); snap("v6-16-training-answers")
    app.navigationBars.buttons["Cancel"].tap()
    app.switches["settings.timeSets"].switches.firstMatch.tap(); tap("preferences.done")
    tap("home.start"); tap("exercise.curl")
    primary("Log set")  // One tap per set.
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 5))
    endWorkout(); tap("summary.done")
    tap("home.start"); tap("exercise.cancel")
    XCTAssertEqual(app.buttons["workout.primary"].label, "Choose exercise")
    tap("session.finish")  // Nothing logged: ends at once, with no summary.
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6)); XCTAssertFalse(app.buttons["summary.done"].exists)
  }

  func testHistoryAndSettingsRemainReadableAtLargerText() {
    app.terminate()
    app.launchArguments = ["--ui-reset", "--demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
    app.launch()
    snap("v6-accessible-home")
    tap("home.history")
    XCTAssertTrue(app.buttons["history.reps"].waitForExistence(timeout: 6))
    snap("v6-accessible-history")
    tap("history.reps")
    XCTAssertTrue(app.staticTexts["totals.amount"].waitForExistence(timeout: 6))
    app.navigationBars.buttons.firstMatch.tap(); app.navigationBars.buttons.firstMatch.tap()
    tap("home.preferences"); tap("settings.baseline")
    XCTAssertTrue(app.navigationBars.buttons["Cancel"].waitForExistence(timeout: 6))
    snap("v6-accessible-training-answers")
    app.navigationBars.buttons["Cancel"].tap(); tap("preferences.done")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
  }

  func testCustomExerciseAndTypedDigitsAreNeverDropped() {
    freeWorkout(); tap("home.start"); search("Cable curl"); tap("exercise.custom")
    XCTAssertEqual(app.textFields["custom.name"].value as? String, "Cable curl")
    tap("custom.add")
    XCTAssertTrue(app.staticTexts["set.exercise"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.staticTexts["set.exercise"].label, "Cable curl")
    XCTAssertTrue(app.staticTexts["Add the weight for this set."].exists)  // A first-time load is never invented.
    primary("Start set")  // …so Start opens the weight instead of starting.
    app.textFields["set.weight"].typeText("60")
    XCTAssertEqual(app.textFields["set.weight"].value as? String, "60 kg")
    primary("Start set"); fill("set.reps", "9"); primary("Finish set")
    XCTAssertTrue(app.buttons["set.saved"].label.contains("60 kg × 9"), app.buttons["set.saved"].label)
    tap("set.change"); search("Cable curl")
    XCTAssertTrue(app.buttons["exercise." + "Cable curl"].exists || app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cable curl")).firstMatch.waitForExistence(timeout: 6))
    tap("exercise.cancel")
    endWorkout(); tap("summary.done")
  }
}
