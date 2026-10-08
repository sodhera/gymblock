import XCTest

/// The moments that go wrong in a gym: sweaty double taps, ending mid-set, a forgotten workout,
/// moving on after the last set, and large text.
final class WorkoutActionsUITests: XCTestCase {
  private func tap(_ app: XCUIApplication, _ id: String) {
    let button = app.buttons[id].firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 6), id)
    let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: button)
    wait(for: [ready], timeout: 6)
    button.tap()
  }
  private func primary(_ app: XCUIApplication, _ label: String) -> XCUIElement {
    let button = app.buttons["workout.primary"]
    XCTAssertTrue(button.waitForExistence(timeout: 6))
    let match = expectation(for: NSPredicate(format: "label BEGINSWITH %@", label), evaluatedWith: button)
    wait(for: [match], timeout: 6)
    return button
  }
  private func snap(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  private func launch(_ arguments: [String] = []) -> XCUIApplication {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--ui-reset", "--demo"] + arguments; app.launch()
    return app
  }

  func testTheButtonNeverMovesAndEndingMidSetAsksFirst() {
    let app = launch()
    snap(app, "actions-home")
    let home = app.buttons["home.start"]; XCTAssertTrue(home.waitForExistence(timeout: 6))
    let homeFrame = home.frame
    home.tap()
    let ready = primary(app, "Start set"); snap(app, "actions-ready")
    XCTAssertEqual(ready.frame, homeFrame)  // Home's Start and the workout's button share one place.
    Thread.sleep(forTimeInterval: 0.7); ready.tap()
    let active = primary(app, "Finish set")
    XCTAssertEqual(active.frame, homeFrame)
    let reps = app.textFields["set.reps"]; reps.tap(); reps.typeText("12")
    tap(app, "session.finish")
    XCTAssertTrue(app.buttons["session.saveEnd"].waitForExistence(timeout: 6))
    snap(app, "actions-end-confirmation")
    tap(app, "session.keepGoing")
    XCTAssertEqual(reps.value as? String, "12")
    Thread.sleep(forTimeInterval: 0.7); active.tap()
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 6))
    XCTAssertEqual(primary(app, "Start set").frame, homeFrame)
    snap(app, "actions-rest")
    tap(app, "session.finish")  // A saved set means ending needs a deliberate second tap.
    tap(app, "session.endConfirm")
    XCTAssertEqual(app.descendants(matching: .any)["summary.sets"].firstMatch.label, "Sets, 1")
    XCTAssertEqual(app.buttons["summary.done"].frame, homeFrame)
    tap(app, "summary.done")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
  }

  func testADoubleTapNeverStartsAndFinishesASetAtOnce() {
    let app = launch()
    tap(app, "home.start")
    primary(app, "Start set").doubleTap()
    XCTAssertEqual(primary(app, "Finish set").label, "Finish set")  // Started once, not finished.
    Thread.sleep(forTimeInterval: 0.7)
    primary(app, "Finish set").doubleTap()
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.buttons["workout.primary"].label, "Start set")  // Finished once, not restarted.
    tap(app, "session.sets")
    XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved.")).count, 1)
    tap(app, "records.done")
  }

  func testAfterTheLastSetTheNextExerciseIsOneTapAndTheRestKeepsCounting() {
    let app = launch()
    tap(app, "home.workout"); tap(app, "choice.Push")
    tap(app, "home.start")
    XCTAssertEqual(app.staticTexts["set.exercise"].label, "Bench press")
    for _ in 0..<3 {
      Thread.sleep(forTimeInterval: 0.7); primary(app, "Start set").tap()
      Thread.sleep(forTimeInterval: 0.7); primary(app, "Finish set").tap()
    }
    let next = primary(app, "Next: Dumbbell shoulder press")
    XCTAssertTrue(app.buttons["workout.another"].exists)
    snap(app, "actions-next-exercise")
    Thread.sleep(forTimeInterval: 0.7); next.tap()
    XCTAssertEqual(app.staticTexts["set.exercise"].label, "Dumbbell shoulder press")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].exists)
    XCTAssertEqual(primary(app, "Start set").label, "Start set")
  }

  func testPauseStopsTheClocksAndResumeCarriesOn() {
    let app = launch(["-workoutStage", "rest"])
    tap(app, "workout.pause")
    XCTAssertTrue(app.staticTexts["workout.paused"].waitForExistence(timeout: 6))
    let resume = primary(app, "Resume")
    let frozen = app.staticTexts["rest.elapsed"].label
    let clock = app.staticTexts["workout.clock"].label
    Thread.sleep(forTimeInterval: 2.5)
    XCTAssertEqual(app.staticTexts["rest.elapsed"].label, frozen)  // Nothing counts while paused.
    XCTAssertEqual(app.staticTexts["workout.clock"].label, clock)
    snap(app, "actions-paused")
    Thread.sleep(forTimeInterval: 0.7); resume.tap()
    XCTAssertEqual(primary(app, "Start set").label, "Start set")
    XCTAssertFalse(app.staticTexts["workout.paused"].exists)
    let seconds = { (text: String) -> Int in
      let p = text.split(separator: ":").compactMap { Int($0) }; return p.count == 2 ? p[0] * 60 + p[1] : -1
    }
    XCTAssertLessThanOrEqual(seconds(app.staticTexts["rest.elapsed"].label) - seconds(frozen), 3)  // Carries on from the pause.
  }

  func testAWorkoutLeftRunningOffersToFinishAtItsLastSet() {
    let app = launch(["-workoutStage", "stale"])
    let finish = app.alerts.buttons["Finish workout"]
    XCTAssertTrue(finish.waitForExistence(timeout: 8))
    XCTAssertTrue(app.alerts.staticTexts["Still working out?"].exists)
    snap(app, "actions-stale")
    finish.tap()
    XCTAssertTrue(app.buttons["summary.done"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.descendants(matching: .any)["summary.time"].firstMatch.label, "Time, 30 min")
  }

  func testActionsRemainReachableAtLargerText() {
    let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"])
    snap(app, "actions-large-home")
    tap(app, "home.start")
    XCTAssertTrue(app.buttons["set.change"].isHittable)
    XCTAssertTrue(primary(app, "Start set").isHittable)
    snap(app, "actions-large-ready")
    Thread.sleep(forTimeInterval: 0.7); primary(app, "Start set").tap()
    XCTAssertTrue(primary(app, "Finish set").isHittable)
    snap(app, "actions-large-active")
    tap(app, "session.finish"); tap(app, "session.discardEnd")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["summary.done"].exists)
  }
}
