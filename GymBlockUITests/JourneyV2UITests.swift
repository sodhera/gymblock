import XCTest

final class JourneyV5UITests: XCTestCase {
  private var app: XCUIApplication!
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication(); app.launchArguments = ["--ui-reset"]; app.launch()
  }
  private func any(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }
  private func tap(_ id: String) {
    let button = app.buttons[id].firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 8), id)
    let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: button)
    wait(for: [ready], timeout: 6); button.tap()
  }
  private func next() { tap("onboarding.continue") }
  private func page(_ text: String) {
    let element = app.staticTexts["onboarding.question"].firstMatch
    let ready = expectation(for: NSPredicate(format: "label == %@", text), evaluatedWith: element)
    wait(for: [ready], timeout: 8)
  }
  private func snap(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
    attachment.lifetime = .keepAlways; add(attachment)
  }
  private func settle(_ seconds: TimeInterval) {
    let delay = expectation(description: "animation")
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { delay.fulfill() }
    wait(for: [delay], timeout: seconds + 2)
  }

  /// Name → gender, height and weight on one page.
  private func profile(_ name: String = "Sam", gender: String = "male") {
    page("What should we call you?")
    let field = app.textFields["profile.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)  // A name is required.
    field.typeText(name + "\n")
    page("Tell us about you."); tap("profile.gender." + gender)
    XCTAssertTrue(app.buttons["profile.gender." + gender].isSelected)
  }
  /// Rest alerts: the system prompt appears once per simulator; allow it if it does.
  private func allowAlerts() {
    page("Get a buzz when rest is up."); tap("alerts.on")
    let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
    if allow.waitForExistence(timeout: 4) { allow.tap() }
  }

  func testFullJourneyEstimatesFromMinutesSetsUpBlockingAndEndsOnOffer() {
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8)); snap("01-welcome"); next()
    profile("Sirish")
    XCTAssertTrue(app.pickerWheels["178 cm"].waitForExistence(timeout: 4))  // Male default.
    app.segmentedControls.buttons["ft · lb"].tap()
    XCTAssertTrue(app.pickerWheels["5′ 10″"].waitForExistence(timeout: 4)); snap("04-body"); next()
    page("Do you use your phone between sets?"); snap("02-scrolling"); tap("habit.scrolling.yes")
    page("Between sets, how long are you on your phone?")
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 6))
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "2 min"); snap("03-minutes"); next()
    page("Sirish, here’s your phone time.")
    XCTAssertTrue(any("reveal.phone").label.contains("34"))
    // A plus tap updates the estimate in place.
    tap("reveal.sets.plus")
    let updated = expectation(for: NSPredicate(format: "label CONTAINS %@", "46"), evaluatedWith: any("reveal.phone"))
    wait(for: [updated], timeout: 5); snap("05-reveal")
    next(); page("That’s 199 hours a year.")  // 46 min × 5 a week × 52.
    XCTAssertTrue(app.staticTexts["days.workouts"].waitForExistence(timeout: 4))
    XCTAssertEqual(app.staticTexts["days.workouts"].label, "= 266 workouts"); snap("06-hours")  // 45 min each.
    next(); page("Scrolling weakens your mind-muscle connection."); snap("07-mind-a")
    next(); page("Put it away. Feel every rep."); snap("08-mind-b")
    next(); page("Scroll between sets.\nNever hit the pump.")
    // Continue appears once the scene ends (XCUITest waits for animations, so only the end state is observable).
    let shown = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["onboarding.continue"])
    wait(for: [shown], timeout: 7); snap("09-rest-a")
    next(); page("Time your rests.\nHit the pump."); snap("10-rest-b")
    next(); page("Memory forgets your progress."); settle(4); snap("09-log-a")
    next(); page("Your log doesn’t."); settle(3); snap("10-log-b")
    next(); page("Block what distracts you.")
    XCTAssertTrue(app.buttons["block.Instagram"].isSelected); XCTAssertFalse(app.buttons["block.X"].isSelected)
    tap("block.X"); XCTAssertTrue(app.buttons["block.X"].isSelected); snap("11-blocking")
    tap("blocking.on"); allowAlerts(); snap("13-alerts")
    page("Sirish, commit to focus."); snap("14-commit")
    app.buttons["commit.hold"].press(forDuration: 0.4)  // Releasing early does not commit.
    XCTAssertTrue(app.buttons["commit.hold"].exists); page("Sirish, commit to focus.")
    app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Stay focused, Sirish.")
    XCTAssertTrue(app.staticTexts["Blocks Instagram, TikTok +2"].waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["subscription.buy"].isEnabled)  // No product configured; nothing fake.
    XCTAssertFalse(app.buttons["subscription.preview"].exists)
    snap("12-offer")
  }

  func testRarelySkipsMinutesShowsNoPhoneTimeAndBackFollowsRoute() {
    next(); profile(); next(); tap("habit.scrolling.no")
    page("Sam, here’s your phone time.")
    XCTAssertTrue(any("reveal.phone").label.hasPrefix("0 min"))  // Rarely: no phone time assumed.
    XCTAssertFalse(app.staticTexts["days.workouts"].exists)  // Nothing to add up, so no days page.
    tap("onboarding.back"); page("Do you use your phone between sets?")
    XCTAssertTrue(app.buttons["habit.scrolling.no"].isSelected)
  }

  func testRelaunchResumesWithoutBypassingOffer() {
    next(); profile("Ana", gender: "female")
    XCTAssertTrue(app.pickerWheels["165 cm"].waitForExistence(timeout: 4) || app.pickerWheels["5′ 5″"].exists)
    next(); tap("habit.scrolling.sometimes")
    page("Between sets, how long are you on your phone?"); next()
    page("Ana, here’s your phone time.")
    XCTAssertTrue(any("reveal.phone").label.contains("17"))  // Sometimes defaults to 1 min per rest.
    for _ in 0..<8 { next() }
    page("Block what distracts you."); tap("blocking.later")
    page("Get a buzz when rest is up."); tap("alerts.later")
    page("Ana, commit to focus."); app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Stay focused, Ana.")
    XCTAssertTrue(app.staticTexts["Blocks the apps you choose"].waitForExistence(timeout: 5))
    app.terminate(); app.launchArguments = []; app.launch()
    page("Stay focused, Ana.")
    tap("onboarding.back"); page("Ana, commit to focus.")
    tap("onboarding.back"); page("Get a buzz when rest is up.")
    tap("onboarding.back"); page("Block what distracts you.")
    XCTAssertFalse(app.buttons["home.start"].exists)
  }

  func testLargeTextReducedMotionKeepsEveryPageReachable() {
    app.terminate()
    app.launchArguments = ["--ui-reset", "--ui-reduced-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
    app.launch()
    next(); profile(); snap("large-body"); next(); tap("habit.scrolling.yes"); next()
    page("Sam, here’s your phone time."); snap("large-reveal")
    for name in ["days", "mind-a", "mind-b", "rest-a", "rest-b", "log-a", "log-b"] { next(); snap("large-" + name) }
    next(); page("Block what distracts you."); snap("large-blocking")
    tap("blocking.on"); page("Get a buzz when rest is up."); snap("large-alerts"); tap("alerts.later")
    page("Sam, commit to focus."); snap("large-commit")
    app.buttons["commit.hold"].press(forDuration: 2.2); page("Stay focused, Sam."); snap("large-offer")
  }
}
