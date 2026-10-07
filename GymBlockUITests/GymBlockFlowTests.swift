import XCTest

final class GymBlockFlowTests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication(); app.launchArguments = ["--ui-reset", "--demo"]; app.launch()
  }
  private func tap(_ id: String) {
    let button = app.buttons[id].firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 6), id)
    for _ in 0..<4 { if button.isHittable { break }; app.swipeUp() }
    let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: button)
    wait(for: [ready], timeout: 6); button.tap()
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
  private func tab(_ name: String) {
    // The native tab bar is covered by the number keyboard while editing reps.
    if app.keyboards.firstMatch.exists {
      let done = app.buttons["set.keyboard.done"]
      if done.exists { done.tap() } else { app.scrollViews.firstMatch.swipeDown() }
    }
    let button = app.tabBars.buttons[name]
    XCTAssertTrue(button.waitForExistence(timeout: 6)); button.tap()
    let selected = expectation(for: NSPredicate(format: "selected == true"), evaluatedWith: button)
    wait(for: [selected], timeout: 6)
  }
  private func weight(_ text: String) {
    tap("set.weight"); tap("weight.mode"); fill("set.weight.manual", text); tap("set.weight.picker.done")
  }
  private func elapsed() -> Int {
    let pieces = app.staticTexts["rest.elapsed"].label.split(separator: ":").compactMap { Int($0) }
    return pieces.count == 2 ? pieces[0] * 60 + pieces[1] : -1
  }
  func testFreeWorkoutCorrectionSwitchRestAndRelaunch() {
    snap("v3-app-01-home"); tap("home.start"); search("dum"); snap("v3-app-02-search"); tap("exercise.curl")
    snap("v3-app-03-ready"); tap("set.weight")
    XCTAssertFalse(app.textFields["set.weight.manual"].exists)
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "22.5 kg"); snap("v3-app-04-weight-picker")
    tap("weight.mode"); fill("set.weight.manual", "25"); snap("v3-app-05-weight-manual"); tap("set.weight.picker.done")
    tap("set.start"); fill("set.reps", "12"); snap("v3-app-06-active"); tap("set.stop")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 5)); snap("v3-app-07-rest")
    tap("set.saved"); fill("edit.reps", "7"); snap("v3-app-08-edit-set"); tap("edit.save")
    XCTAssertTrue(app.buttons["set.saved"].label.hasSuffix("× 7")); let before = elapsed()
    tap("set.change"); search("hammer"); tap("exercise.hammer")
    XCTAssertGreaterThanOrEqual(elapsed(), before); snap("v3-app-09-switch-rest")
    weight("15"); tap("set.start"); fill("set.reps", "8")
    tab("History"); snap("v3-app-10-history"); tab("Workout")
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    app.terminate(); app.launchArguments = []; app.launch()
    XCTAssertTrue(app.buttons["set.stop"].waitForExistence(timeout: 6)); XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("set.change"); search("curl"); tap("exercise.curl")
    XCTAssertTrue(app.buttons["switch.cancel"].waitForExistence(timeout: 5)); tap("switch.cancel")
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("set.change"); search("curl"); tap("exercise.curl"); tap("switch.save")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].exists)
    tap("session.sets"); snap("v3-app-11-grouped-sets"); tap("records.done")
    tap("session.finish"); tap("session.endConfirm"); XCTAssertTrue(app.staticTexts["2 sets · 15 reps"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["summary.volume"].label, "295 kg")
    snap("v3-app-12-summary"); tap("summary.done")
    tab("History"); tap("history.reps"); XCTAssertTrue(app.staticTexts["totals.amount"].waitForExistence(timeout: 5)); snap("v3-app-13-reps-chart")
  }
  func testLogOutKeepsWorkoutsAndDeleteAccountErasesEverything() {
    tap("home.preferences"); tap("settings.logout"); tap("settings.logout.confirm")
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8))  // Back to onboarding.
    app.terminate(); app.launchArguments = ["--skip-onboarding"]; app.launch()  // Workouts survived the log-out.
    tab("History"); XCTAssertFalse(app.staticTexts["No workouts yet"].exists)
    tab("Workout"); tap("home.preferences"); tap("settings.delete"); tap("settings.delete.confirm")
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8))
    app.terminate(); app.launchArguments = []; app.launch()
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8))  // Nothing left to resume.
  }
  func testSplitNavigationEditorAndProgress() {
    tab("Splits"); snap("v3-app-14-splits"); tap("split.add"); fill("split.name", "Monday")
    tap("split.exercises"); tap("split.exercise.curl"); tap("split.exercise.hammer"); tap("split.exercises.done"); tap("split.save")
    tap("split.edit.Monday"); snap("v3-app-15-split-detail"); tap("split.start")
    XCTAssertTrue(app.buttons["set.start"].waitForExistence(timeout: 6)); tap("set.start"); fill("set.reps", "11"); tap("set.stop")
    tap("session.finish"); tap("session.endConfirm"); tap("summary.done"); tab("History"); tap("history.progress")
    tap("progress.scope"); app.buttons["Arms"].tap(); tap("progress.exercise.curl")
    XCTAssertTrue(app.staticTexts["progress.change"].waitForExistence(timeout: 6)); snap("v3-app-16-before-after")
  }
  func testSettingsAndActiveSetDiscardPreserveHistory() {
    tap("home.preferences"); snap("v3-app-17-settings"); tap("settings.baseline"); snap("v3-app-18-training-answers")
    app.navigationBars.buttons["Cancel"].tap(); tap("preferences.done")
    tap("home.start"); tap("exercise.curl"); tap("set.start")
    tap("set.reps.minus"); tap("set.reps.minus"); tap("set.stop")
    tap("set.start")
    for _ in 0..<8 { tap("set.reps.minus") }
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "0")
    tap("set.stop"); snap("v3-zero-rep-choice")
    tap("attempt.save")
    tap("set.start"); XCTAssertTrue(app.buttons["set.stop"].waitForExistence(timeout: 5))
    snap("v3-attempt-next-set"); tap("set.change"); tap("exercise.hammer"); snap("v3-attempt-change")
    tap("switch.discard")
    tap("session.sets"); XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved.")).count, 2)
    tap("records.done"); tap("session.finish"); tap("session.endConfirm"); tap("summary.done")
    tap("home.start"); tap("session.finish")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6)); XCTAssertFalse(app.buttons["summary.done"].exists)
  }
  func testHistoryAndSettingsRemainReadableAtLargerText() {
    tab("History")
    XCTAssertTrue(app.buttons["history.reps"].waitForExistence(timeout: 6))
    snap("v3-accessible-history")
    tap("history.reps")
    XCTAssertTrue(app.staticTexts["totals.amount"].waitForExistence(timeout: 6))
    snap("v3-accessible-reps-chart")
    app.navigationBars.buttons.firstMatch.tap()
    tab("Workout"); tap("home.preferences"); tap("settings.baseline")
    XCTAssertTrue(app.navigationBars.buttons["Cancel"].waitForExistence(timeout: 6))
    snap("v3-accessible-training-answers")
    app.navigationBars.buttons["Cancel"].tap(); tap("preferences.done")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
  }
  func testCustomExerciseSearchAndEmptySession() {
    tap("home.start"); search("Cable curl"); tap("exercise.custom")
    XCTAssertEqual(app.textFields["custom.name"].value as? String, "Cable curl")
    tap("custom.add")
    XCTAssertTrue(app.staticTexts["set.exercise"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.staticTexts["set.exercise"].label, "Cable curl")
    weight("60")  // Typed digits are never dropped.
    XCTAssertTrue(app.buttons["set.weight"].label.contains("60 kg"), app.buttons["set.weight"].label)
    tap("set.start"); fill("set.reps", "9"); tap("set.stop")
    tap("set.change"); search("Cable curl")
    XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Cable curl")).firstMatch.waitForExistence(timeout: 6))
    tap("exercise.cancel")
    tap("session.finish"); tap("session.endConfirm"); tap("summary.done")
  }

}
