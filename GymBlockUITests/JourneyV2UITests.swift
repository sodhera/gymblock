import XCTest

final class JourneyV2UITests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--ui-reset"]
    app.launch()
  }
  private func tap(_ id: String) {
    let button = app.buttons[id].firstMatch
    if !button.exists { XCTAssertTrue(button.waitForExistence(timeout: 6), id) }
    for _ in 0..<5 {
      if button.isHittable { break }
      app.scrollViews.firstMatch.swipeUp()
    }
    if !button.isEnabled || !button.isHittable {
      let ready = expectation(
        for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: button)
      wait(for: [ready], timeout: 6)
    }
    button.tap()
  }
  private func next() { tap("onboarding.continue") }
  private func snap(_ name: String) {
    Thread.sleep(
      forTimeInterval: name.contains("attention-after") || name.contains("rest-story")
        || name.contains("rep-comparison") ? 2 : name.contains("four-week") ? 1.4 : 0.5
    )
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  private func question(_ text: String) {
    if app.staticTexts["onboarding.question"].label != text {
      let ready = expectation(
        for: NSPredicate(format: "label == %@", text),
        evaluatedWith: app.staticTexts["onboarding.question"])
      wait(for: [ready], timeout: 6)
    }
  }
  private func wheel(_ value: String) {
    if !app.pickerWheels.firstMatch.exists {
      XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 6))
    }
    for _ in 0..<5 {
      if app.pickerWheels.firstMatch.isHittable { break }
      app.scrollViews.firstMatch.swipeUp()
    }
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: value)
  }
  private func training() {
    next()
    question("How many days a week do you work out?")
    if app.buttons["baseline.days.3"].exists {
      tap("baseline.days.3")
    } else {
      wheel("3 days / week")
    }
    snap("journey-02-days")
    next()
    question("How long is a usual visit?")
    wheel("60 min")
    snap("journey-03-visit-picker")
    next()
    question("On average, how many reps per set?")
    wheel("10 reps")
    snap("journey-04-reps")
    next()
    question("How many sets per exercise?")
    wheel("3 sets")
    snap("journey-05-sets")
    next()
    question("How many exercises on a usual training day?")
    wheel("6 exercises")
    snap("journey-06-exercises")
    next()
    question("Do you scroll between sets?")
  }
  private func habits() {
    question("Do you time your rests between sets?")
    tap("habit.restHabits.no")
    snap("journey-09-rest-habit")
    next()
    question("Do you log your workouts and look back at them?")
    tap("habit.loggingHabits.neither")
    snap("journey-10-log-habit")
    next()
    question("Do you record how long each set takes?")
    tap("habit.setTiming.no")
    snap("journey-11-set-time-habit")
    next()
  }
  private func storiesAndReady() {
    next()
    question("Give your next set a fair chance.")
    snap("journey-15-rest-story")
    tap("journey.rest.research")
    XCTAssertTrue(app.staticTexts["Rest supports your next set."].waitForExistence(timeout: 5))
    snap("journey-16-rest-research")
    app.buttons["Done"].tap()
    next()
    question("Make the next workout less of a guess.")
    XCTAssertTrue(app.descendants(matching: .any)["journey.comparison"].exists)
    snap("journey-17-rep-comparison")
    next()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "216")
    snap("journey-18-four-week-record")
    tap("journey.record.detail")
    XCTAssertTrue(
      app.staticTexts.matching(
        NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "2160", "2160")
      ).firstMatch.waitForExistence(timeout: 5))
    snap("journey-four-week-detail")
    tap("journey.record.done")
    next()
    question("Your next set starts here.")
    snap("journey-19-ready")
    tap("onboarding.secondary")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
    app.tabBars.buttons["History"].tap()
    XCTAssertTrue(app.staticTexts["No workouts yet."].waitForExistence(timeout: 5))
  }
  func testPersonalJourneyPickersCalculationsResumeAndNoFakeHistory() {
    snap("journey-01-welcome")
    training()
    tap("habit.scrolling.yes")
    snap("journey-07-scroll-question")
    next()
    question("How many minutes do you scroll between sets?")
    wheel("2 min")
    snap("journey-08-scroll-minutes")
    next()
    habits()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "34 min")
    snap("journey-12-attention-before")
    app.terminate()
    app.launchArguments = []
    app.launch()
    XCTAssertTrue(app.staticTexts["baseline.result"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "34 min")
    next()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "34 min")
    snap("journey-13-attention-after")
    app.terminate()
    app.launchArguments = []
    app.launch()
    XCTAssertTrue(app.staticTexts["baseline.result"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "34 min")
    XCTAssertEqual(app.buttons["onboarding.continue"].label, "Over four weeks")
    next()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "6 h 48 min")
    snap("journey-14-four-week-attention")
    storiesAndReady()
  }
  func testSometimesFractionalMinutesWithActualBreaks() {
    training()
    tap("habit.scrolling.sometimes")
    next()
    wheel("0.5 min")
    next()
    habits()
    XCTAssertTrue(app.staticTexts["How many breaks do you scroll in?"].waitForExistence(timeout: 5))
    wheel("5 scrolling breaks")
    snap("journey-sometimes-breaks")
    next()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "2.5 min")
    snap("journey-sometimes-attention-before")
    next()
    snap("journey-sometimes-attention-after")
    next()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "30 min")
    storiesAndReady()
  }
  func testNoScrollingAndJustTrainStayHonest() {
    training()
    tap("habit.scrolling.no")
    next()
    habits()
    XCTAssertFalse(app.staticTexts["baseline.result"].exists)
    XCTAssertTrue(app.staticTexts["You’re already keeping the space between sets."].exists)
    storiesAndReady()
    app.terminate()
    app.launchArguments = ["--ui-reset"]
    app.launch()
    tap("onboarding.secondary")
    XCTAssertTrue(app.buttons["exercise.curl"].waitForExistence(timeout: 6))
    XCTAssertFalse(app.staticTexts["Focus demo"].exists)
  }
  func testInvalidEstimateCanBeAdjustedWithoutBlockingJourney() {
    training()
    tap("habit.scrolling.yes")
    next()
    wheel("6 min")
    next()
    habits()
    XCTAssertTrue(app.staticTexts["Let’s check that estimate."].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["baseline.result"].exists)
    snap("journey-invalid-estimate")
    tap("baseline.explanation")
    wheel("5 breaks")
    tap("estimate.done")
    XCTAssertTrue(app.staticTexts["baseline.result"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "30 min")
    snap("journey-corrected-estimate")
    next()
    next()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "6 h")
    storiesAndReady()
  }
  func testUnknownTimedRoutineStillReachesTrainingWithoutInventedTotals() {
    next()
    tap("onboarding.options")
    tap("onboarding.skip")
    question("How long is a usual visit?")
    tap("onboarding.options")
    tap("onboarding.skip")
    question("On average, how many reps per set?")
    tap("onboarding.options")
    tap("baseline.timed")
    question("Do you scroll between sets?")
    tap("onboarding.options")
    tap("onboarding.skip")
    habits()
    XCTAssertFalse(app.staticTexts["baseline.result"].exists)
    next()
    next()
    next()
    XCTAssertEqual(app.staticTexts["baseline.result"].label, "4")
    next()
    tap("onboarding.continue")
    XCTAssertTrue(app.buttons["exercise.curl"].waitForExistence(timeout: 5))
  }
  func testSevenDaysAndBackKeepWheelAnswer() {
    next()
    if app.buttons["baseline.days.7"].exists {
      tap("baseline.days.7")
    } else {
      wheel("7 days / week")
    }
    next()
    wheel("75 min")
    next()
    tap("onboarding.back")
    question("How long is a usual visit?")
    XCTAssertTrue((app.pickerWheels.firstMatch.value as? String ?? "").contains("75 min"))
    tap("onboarding.back")
    question("How many days a week do you work out?")
    if app.buttons["baseline.days.7"].exists {
      XCTAssertTrue(app.buttons["baseline.days.7"].isSelected)
    } else {
      XCTAssertTrue((app.pickerWheels.firstMatch.value as? String ?? "").contains("7 days"))
    }
  }
  func testSpanishQuestionsAndBackPreserveDuration() {
    tap("onboarding.options")
    app.buttons["Español"].tap()
    next()
    question("¿Cuántos días a la semana entrenas?")
    tap("baseline.days.7")
    next()
    question("¿Cuánto dura una visita habitual?")
    wheel("75 min")
    snap("journey-spanish-duration")
    next()
    question("De media, ¿cuántas repeticiones por serie?")
    tap("onboarding.back")
    question("¿Cuánto dura una visita habitual?")
    XCTAssertTrue((app.pickerWheels.firstMatch.value as? String ?? "").contains("75 min"))
  }

}
