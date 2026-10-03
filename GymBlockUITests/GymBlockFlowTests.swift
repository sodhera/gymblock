import XCTest

final class GymBlockFlowTests: XCTestCase {
  var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--ui-reset", "--demo"]
    app.launch()
  }
  private func tap(_ id: String) {
    let element = app.buttons[id].firstMatch
    if !element.exists { _ = element.waitForExistence(timeout: 2) }
    for _ in 0..<6 {
      if element.exists && element.isHittable { break }
      if app.scrollViews.firstMatch.exists {
        app.scrollViews.firstMatch.swipeUp()
      } else {
        app.swipeUp()
      }
    }
    XCTAssertTrue(element.exists, id)
    XCTAssertTrue(element.isHittable, id)
    if !element.isEnabled || !element.isHittable {
      let ready = expectation(
        for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: element)
      wait(for: [ready], timeout: 5)
    }
    element.tap()
  }
  private func fill(_ id: String, _ value: String) {
    let field = app.textFields[id]
    for _ in 0..<5 {
      if field.exists { break }
      scrollForm()
    }
    XCTAssertTrue(field.waitForExistence(timeout: 6), id)
    for _ in 0..<5 {
      if field.isHittable { break }
      scrollForm()
    }
    field.tap()
    if let old = field.value as? String, old != field.placeholderValue {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
    }
    field.typeText(value)

  }
  private func scrollForm() {
    let scroll = app.scrollViews.firstMatch
    let collection = app.collectionViews.firstMatch
    if scroll.exists && scroll.isHittable {
      scroll.swipeUp()
    } else if collection.exists && collection.isHittable {
      collection.swipeUp()
    } else {
      app.swipeUp()
    }
  }
  private func search(_ text: String) {
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 6))
    field.tap()
    field.typeText(text)
  }
  private func snap(_ name: String) {
    // Native transitions can finish after XCTest reports the app idle.
    Thread.sleep(forTimeInterval: 0.5)
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = name
    shot.lifetime = .keepAlways
    add(shot)
  }
  private func end() {
    tap("session.finish")
  }
  private func editWeight(_ value: String) {
    tap("set.weight")
    fill("set.weight.manual", value)
    tap("set.weight.picker.done")
  }
  func testFreestyleSetCorrectionSwitchAndRelaunch() {
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
    snap("redesign-01-home")
    tap("home.start")
    search("dum")
    snap("redesign-02-search")
    tap("exercise.curl")
    snap("redesign-03-ready")
    tap("set.weight")
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "22.5")
    XCTAssertEqual(app.textFields["set.weight.manual"].value as? String, "22.5")
    snap("redesign-04-picker")
    fill("set.weight.manual", "25")
    XCTAssertEqual(app.textFields["set.weight.manual"].value as? String, "25")
    tap("set.weight.picker.done")
    tap("set.start")
    tap("set.reps.plus")
    tap("set.reps.plus")
    snap("redesign-05-active")
    fill("set.reps", "12")
    tap("set.stop")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].exists)
    snap("redesign-06-rest")
    tap("set.saved")
    fill("edit.reps", "7")
    tap("edit.save")
    XCTAssertTrue(app.buttons["set.saved"].label.contains("7"))
    tap("set.start")
    fill("set.reps", "8")
    app.terminate()
    app.launchArguments = []
    app.launch()
    XCTAssertTrue(app.buttons["set.stop"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("session.options")
    tap("session.sets")
    tap("records.add")
    fill("edit.reps", "6")
    app.switches["Warm-up"].tap()
    snap("redesign-23-set-correction")
    tap("edit.save")
    tap("records.done")
    XCTAssertTrue(app.buttons["set.stop"].exists)
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("set.stop")
    tap("set.change")
    search("hammer")
    tap("exercise.hammer")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].exists)
    editWeight("15")
    tap("set.start")
    tap("session.options")
    tap("set.attempt")
    XCTAssertTrue(app.buttons["set.saved"].label.contains("Attempt"))
    end()
    snap("redesign-07-summary")
    tap("summary.done")
    XCTAssertTrue(app.buttons["home.start"].exists)
  }
  func testSplitStartsDirectlyAndProgressShowsBeforeAfter() {
    tap("home.workout")
    app.buttons["Arms"].tap()
    tap("home.start")
    XCTAssertTrue(app.buttons["set.start"].exists)
    XCTAssertFalse(app.searchFields.firstMatch.exists)
    tap("set.start")
    fill("set.reps", "10")
    tap("set.stop")
    tap("set.change")
    tap("exercise.hammer")
    expectExercise("hammer")
    end()
    tap("summary.done")
    app.tabBars.buttons["History"].tap()
    app.segmentedControls["history.mode"].buttons["Progress"].tap()
    tap("progress.exercise.curl")
    XCTAssertTrue(app.staticTexts["progress.change"].waitForExistence(timeout: 5))
    snap("redesign-08-progress")
    tap("progress.chart")
    XCTAssertTrue(app.staticTexts["History"].exists)
  }

  func testNativeSplitEditorAndPoundsConversion() {
    tap("home.preferences")
    tap("settings.splits")
    tap("split.add")
    fill("split.name", "Monday")
    tap("split.exercises")
    tap("split.exercise.curl")
    tap("split.exercise.hammer")
    tap("split.exercises.done")
    tap("split.save")
    XCTAssertTrue(app.buttons["split.edit.Monday"].exists)
    snap("redesign-15-splits")
    tap("preferences.done")
    tap("home.workout")
    app.buttons["Monday"].tap()
    tap("home.start")
    tap("set.weight")
    fill("set.weight.manual", "10")
    XCTAssertEqual(app.textFields["set.weight.manual"].value as? String, "10")
    tap("set.weight.picker.done")
    tap("set.weight")
    app.segmentedControls.buttons["lb"].tap()
    XCTAssertEqual(app.textFields["set.weight.manual"].value as? String, "22.05")
    tap("set.weight.picker.done")
    tap("set.start")
    XCTAssertTrue(app.staticTexts["22.05 lb"].exists)
    tap("set.stop")
    tap("set.saved")
    tap("edit.delete")
    XCTAssertTrue(app.buttons["set.undo"].exists)
    tap("set.undo")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].exists)
  }

  func testLargeTextWorkoutControlsStayReachable() {
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
    snap("redesign-17-accessible-home")
    XCTAssertTrue(app.tabBars.buttons["History"].isHittable)
    tab("History")
    snap("gym-flow-12-accessible-history")
    tab("Home")
    tap("home.workout")
    app.buttons["Arms"].tap()
    tap("home.start")
    XCTAssertTrue(app.buttons["set.start"].isHittable)
    snap("redesign-18-accessible-ready")
    tap("set.weight")
    fill("set.weight.manual", "25")
    snap("redesign-25-accessible-weight-entry")
    tap("set.weight.picker.done")
    tap("set.start")
    XCTAssertTrue(app.buttons["set.stop"].isHittable)
    XCTAssertTrue(app.buttons["set.change"].isHittable)
    snap("redesign-19-accessible-active")
    tap("set.stop")
    XCTAssertTrue(app.buttons["set.start"].isHittable)
    XCTAssertTrue(app.buttons["set.change"].isHittable)
    snap("redesign-20-accessible-rest")

  }

  private func tab(_ name: String) {
    let button = app.tabBars.buttons[name]
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    button.tap()
  }
  private func expectExercise(_ name: String) {
    let changed = expectation(
      for: NSPredicate(format: "label CONTAINS %@", name),
      evaluatedWith: app.buttons["set.exercise"])
    wait(for: [changed], timeout: 5)
  }
  private func elapsed() -> Int {
    let label = app.staticTexts["rest.elapsed"].label
    let parts = label.split(separator: ":").compactMap { Int($0) }
    return parts.count == 2 ? parts[0] * 60 + parts[1] : -1
  }
  func testGymNavigationAndChangingMindDuringSet() {
    XCTAssertFalse(app.staticTexts["Best lifts"].exists)
    XCTAssertTrue(app.tabBars.buttons["Home"].exists)
    snap("gym-flow-01-home")
    tab("History")
    snap("gym-flow-02-history")
    app.segmentedControls["history.mode"].buttons["Progress"].tap()
    XCTAssertTrue(app.staticTexts["Best lifts"].exists)
    snap("gym-flow-03-progress")
    tab("Splits")
    XCTAssertTrue(app.buttons["split.add"].exists)
    snap("gym-flow-04-splits")
    tab("Home")
    tap("home.start")
    tap("exercise.curl")
    tap("set.start")
    fill("set.reps", "8")
    tab("History")
    snap("gym-flow-05-browse-while-active")
    tap("history.resume")
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("set.change")
    search("hammer")
    tap("exercise.hammer")
    XCTAssertTrue(app.buttons["switch.cancel"].waitForExistence(timeout: 5))
    snap("gym-flow-06-unfinished-set-choice")
    tap("switch.cancel")
    expectExercise("Dumbbell curl")
    XCTAssertEqual(app.textFields["set.reps"].value as? String, "8")
    tap("set.change")
    search("hammer")
    tap("exercise.hammer")
    tap("switch.save")
    expectExercise("hammer")
    XCTAssertTrue(app.buttons["set.saved"].label.contains("8"))
    XCTAssertTrue(app.staticTexts["rest.elapsed"].exists)
    let initial = elapsed()
    tab("History")
    tap("history.resume")
    XCTAssertGreaterThan(elapsed(), initial)
    let beforeReload = elapsed()
    app.terminate()
    app.launchArguments = []
    app.launch()
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(elapsed(), beforeReload)
    XCTAssertTrue(app.buttons["set.change"].isHittable)
    snap("gym-flow-07-switched-with-rest-counter")
    tap("set.start")
    fill("set.reps", "7")
    tap("set.exercise")
    tap("exercise.curl")
    tap("switch.discard")
    XCTAssertTrue(app.buttons["set.start"].exists)
    XCTAssertTrue(app.staticTexts["rest.elapsed"].exists)
    expectExercise("Dumbbell curl")
    tap("session.options")
    tap("session.sets")
    XCTAssertEqual(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved.")).count, 1)
    snap("gym-flow-08-preserved-set")
    tap("records.done")
    end()
    tap("summary.done")
    tab("History")
    app.segmentedControls["history.mode"].buttons["Workouts"].tap()
    snap("gym-flow-09-finished-history")
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.")).firstMatch
      .tap()
    snap("gym-flow-10-workout-detail")
  }
  func testEmptyHistoryAndSplitsNavigationAfterSkippingSetup() {
    app.terminate()
    app.launchArguments = ["--ui-reset"]
    app.launch()
    tap("onboarding.secondary")
    XCTAssertTrue(app.buttons["exercise.curl"].waitForExistence(timeout: 5))
    end()
    tap("summary.done")
    tab("History")
    XCTAssertTrue(app.staticTexts["No workouts yet."].exists)
    snap("gym-flow-11-empty-history")
    app.segmentedControls["history.mode"].buttons["Progress"].tap()
    XCTAssertTrue(app.staticTexts["Add a split to compare its exercises."].exists)
    tab("Splits")
    tap("split.add")
    fill("split.name", "Monday")
    tap("split.exercises")
    tap("split.exercise.curl")
    tap("split.exercise.hammer")
    tap("split.exercises.done")
    tap("split.save")
    tab("Home")
    tap("home.workout")
    app.buttons["Monday"].tap()
    tap("home.start")
    tab("Splits")
    XCTAssertTrue(app.buttons["splits.resume"].exists)
    tap("splits.resume")
    XCTAssertTrue(app.buttons["set.start"].exists)
    XCTAssertFalse(app.buttons["set.start"].isEnabled)
  }

  func testVisibleEndAndTrainingVisualizations() {
    tap("home.start")
    XCTAssertTrue(app.buttons["session.finish"].isHittable)
    snap("enhanced-01-visible-end-choice")
    tap("exercise.curl")
    tap("set.start")
    fill("set.reps", "8")
    tap("session.finish")
    XCTAssertTrue(app.buttons["session.saveEnd"].waitForExistence(timeout: 5))
    snap("enhanced-02-end-active")
    tap("session.saveEnd")
    XCTAssertTrue(app.staticTexts["summary.volume"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["summary.volume"].label.contains("160"))
    snap("enhanced-03-workout-totals")
    tap("summary.done")
    tab("History")
    app.segmentedControls["history.mode"].buttons["Progress"].tap()
    tap("progress.totals")
    XCTAssertTrue(app.otherElements["totals.chart"].waitForExistence(timeout: 5))
    snap("enhanced-04-reps-trend")
    app.segmentedControls["totals.metric"].buttons["Weight moved"].tap()
    tap("totals.style")
    app.buttons["Bars"].tap()
    snap("enhanced-05-volume-bars")
    tap("totals.scope")
    app.buttons["Arms"].tap()
    app.segmentedControls["totals.metric"].buttons["Sets"].tap()
    snap("enhanced-06-split-sets")
  }

  func testSavedTimingAndFourWeekReport() {
    tap("home.workout")
    app.buttons["Arms"].tap()
    tap("home.start")
    tap("set.start")
    fill("set.reps", "10")
    tap("set.stop")
    tap("set.saved")
    tap("Recorded timing")
    fill("edit.elapsed", "35")
    tap("edit.save")
    tap("set.start")
    fill("set.reps", "11")
    tap("set.stop")
    tap("set.saved")
    tap("Recorded timing")
    fill("edit.elapsed", "40")
    fill("edit.gap", "90")
    snap("journey-workout-timing-editor")
    tap("edit.save")
    end()
    tap("summary.done")
    tab("History")
    app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history.")).firstMatch
      .tap()
    XCTAssertTrue(app.staticTexts["Set time 0:40"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Gap before 1:30"].exists)
    snap("journey-workout-saved-timing")
    app.navigationBars.buttons.firstMatch.tap()
    app.segmentedControls["history.mode"].buttons["Progress"].tap()
    tap("progress.totals")
    let all = app.staticTexts["totals.amount"].label
    tap("totals.period")
    app.buttons["Last four weeks"].tap()
    XCTAssertNotEqual(app.staticTexts["totals.amount"].label, all)
    snap("journey-workout-four-week-reps")
  }

}
