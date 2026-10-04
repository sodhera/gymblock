import XCTest

final class JourneyV4UITests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication(); app.launchArguments = ["--ui-reset"]; app.launch()
  }
  private func tap(_ id: String) {
    let button = app.buttons[id].firstMatch
    for _ in 0..<6 {
      if button.waitForExistence(timeout: 1) && button.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(button.waitForExistence(timeout: 6), id)
    let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: button)
    wait(for: [ready], timeout: 6); button.tap()
  }
  private func next() { tap("onboarding.continue") }
  private func question(_ text: String) {
    let element = app.staticTexts["onboarding.question"]
    let ready = expectation(for: NSPredicate(format: "label == %@", text), evaluatedWith: element)
    wait(for: [ready], timeout: 6)
  }
  private func snap(_ name: String) {
    let screenshot = app.screenshot()
    try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name + ".png"))
    let attachment = XCTAttachment(screenshot: screenshot); attachment.name = name
    attachment.lifetime = .keepAlways; add(attachment)
  }
  private func wheel(_ text: String) {
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 6))
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: text)
  }
  private func training() {
    snap("v4-01-welcome"); next(); question("How many days a week do you workout?")
    let slider = app.sliders["baseline.days"]
    XCTAssertTrue(slider.waitForExistence(timeout: 5)); slider.adjust(toNormalizedSliderPosition: 0)
    XCTAssertEqual(slider.value as? String, "1")
    slider.adjust(toNormalizedSliderPosition: 1); XCTAssertEqual(slider.value as? String, "7")
    slider.adjust(toNormalizedSliderPosition: 1.0 / 3.0); snap("v4-02-glass-slider")
    next(); question("How long is a usual gym visit?"); wheel("60 min"); snap("v4-03-minutes")
    next(); question("How many reps do you do per set, on average?"); wheel("10 reps"); snap("v4-04-reps")
    next(); question("How many sets do you do per exercise, on average?"); wheel("3 sets"); snap("v4-05-sets")
    next(); question("How many exercises in a day?"); wheel("6 exercises"); snap("v4-06-exercises")
    next(); question("Do you scroll through your phone in between sets?"); snap("v4-07-scroll-question")
  }
  private func habits() {
    question("Do you measure how long you rest between sets?"); snap("v4-09-rest-question"); tap("habit.restHabits.no")
    question("Do you record your workouts and look at those records later?"); snap("v4-10-record-question"); tap("habit.loggingHabits.neither")
    question("Do you measure how long each set takes?"); snap("v4-11-time-question"); tap("habit.setTiming.no")
  }
  private func benefits() {
    question("Let your mind rest between sets."); snap("v4-12-brains-start")
    XCTAssertTrue(app.staticTexts["Your proposed copy · Unverified health claim"].waitForExistence(timeout: 12))
    snap("v4-13-brains-end"); next(); question("Time your rests."); snap("v4-14-arms-rest")
    // Observe the entire finite arm sequence, then capture the fifth-rep celebration.
    let settled = expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.buttons["journey.replay"])
    wait(for: [settled], timeout: 5)
    let delay = expectation(description: "finite arm sequence")
    DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) { delay.fulfill() }
    wait(for: [delay], timeout: 10); snap("v4-15-perfect-pump")
    next(); question("See what your work adds up to.")
    XCTAssertTrue(app.staticTexts["↑ 33.3%"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["↓ 10%"].exists); snap("v4-16-records")
    next(); question("Stay focused with GymBlock.")
    XCTAssertTrue(app.staticTexts["subscription.status"].waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["subscription.buy"].exists); snap("v4-17-subscription")
  }
  func testFullJourneyShowsBenefitsAndOfferWithoutInventingHistory() {
    training(); tap("habit.scrolling.yes")
    question("How many minutes do you scroll between sets?"); wheel("2 min"); snap("v4-08-scroll-minutes"); next()
    habits(); benefits()
    tap("subscription.preview"); XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["exercise.curl"].exists)
    app.tabBars.buttons["History"].tap()
    XCTAssertTrue(app.staticTexts["No workouts yet"].waitForExistence(timeout: 5)); snap("v4-18-empty-history")
  }
  func testSkipQuestionsBackAndRelaunchDoNotBypassOffer() {
    tap("onboarding.secondary"); question("Let your mind rest between sets.")
    tap("onboarding.back"); XCTAssertTrue(app.buttons["onboarding.secondary"].waitForExistence(timeout: 5))
    tap("onboarding.secondary"); next(); next(); question("See what your work adds up to."); next()
    question("Stay focused with GymBlock.")
    app.terminate(); app.launchArguments = []; app.launch()
    question("Stay focused with GymBlock.")
    tap("onboarding.back"); question("See what your work adds up to.")
    XCTAssertFalse(app.buttons["home.start"].exists)
  }
  func testSometimesThenNoClearsConditionalRoute() {
    training(); tap("habit.scrolling.sometimes"); question("How many minutes do you scroll between sets?"); wheel("2 min"); next()
    question("How many breaks include scrolling?"); wheel("5 breaks"); next()
    question("Do you measure how long you rest between sets?")
    tap("onboarding.back"); question("How many breaks include scrolling?")
    tap("onboarding.back"); question("How many minutes do you scroll between sets?")
    tap("onboarding.back"); question("Do you scroll through your phone in between sets?")
    tap("habit.scrolling.no"); habits(); question("Let your mind rest between sets.")
    XCTAssertFalse(app.buttons["baseline.explanation"].exists)
  }
  func testLargeTextReducedMotionKeepsNavigationAndRecordMeaning() {
    app.terminate()
    app.launchArguments = ["--ui-reset", "--ui-reduced-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
    app.launch()
    tap("onboarding.secondary"); question("Let your mind rest between sets.")
    app.swipeUp(); snap("v4-large-brains")
    next(); question("Time your rests."); app.swipeUp(); snap("v4-large-arms")
    next(); question("See what your work adds up to.")
    for _ in 0..<4 { if app.staticTexts["↑ 33.3%"].exists { break }; app.swipeUp() }
    XCTAssertTrue(app.staticTexts["↑ 33.3%"].exists); snap("v4-large-records")
    next(); question("Stay focused with GymBlock.")
    tap("subscription.preview"); XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
  }

}
