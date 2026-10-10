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

  /// Name → gender → (lands on) height. Choosing never advances on its own.
  private func profile(_ name: String = "Sam", gender: String = "male") {
    page("What should we call you?")
    let field = app.textFields["profile.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)  // A name is required.
    field.typeText(name + "\n")
    page("What’s your gender?")
    XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)
    tap("profile.gender." + gender)
    XCTAssertTrue(app.buttons["profile.gender." + gender].isSelected)
    page("What’s your gender?")  // Still here: selecting only selects.
    next(); page("How tall are you?")
  }
  /// Height → weight → the phone question, accepting the defaults.
  private func body() { next(); page("How much do you weigh?"); next(); page("Do you use your phone between sets?") }
  private func answer(_ id: String) {
    tap(id); XCTAssertTrue(app.buttons[id].isSelected)
    page("Do you use your phone between sets?"); next()
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
    if app.pickerWheels["178 cm"].waitForExistence(timeout: 4) {  // Male default.
      app.segmentedControls.buttons["ft · in"].tap()
    }
    XCTAssertTrue(app.pickerWheels["5′ 10″"].waitForExistence(timeout: 4)); snap("04-height"); next()
    page("How much do you weigh?")
    XCTAssertTrue(app.pickerWheels["80 kg"].exists || app.pickerWheels["176 lb"].exists); snap("05-weight"); next()
    page("Do you use your phone between sets?"); snap("06-scrolling"); answer("habit.scrolling.yes")
    page("How long on your phone, each rest?")
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 6))
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "2 min"); snap("03-minutes"); next()
    page("Sirish, here’s how much time you spend on your phone during your workout session.")
    // 17 rests × 2 min on the phone, against 18 sets × 40 s of training.
    XCTAssertTrue(any("reveal.phone").label.contains("34 min on your phone"), any("reveal.phone").label)
    XCTAssertTrue(any("reveal.phone").label.contains("12 min training"))
    XCTAssertFalse(app.buttons["reveal.sets.plus"].exists)  // No adjusters: one plain fact.
    snap("07-reveal")
    next(); page("That’s 147 hours a year.")  // 34 min × 5 a week × 52.
    XCTAssertTrue(app.staticTexts["days.workouts"].waitForExistence(timeout: 4))
    XCTAssertEqual(app.staticTexts["days.workouts"].label, "= 196 workouts"); snap("08-hours")  // 45 min each.
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
    // Apps come from Screen Time's own picker, which needs the iPhone passcode: not reachable from a UI test.
    XCTAssertEqual(app.staticTexts["blocking.summary"].label, "Choose the apps that pull you in.")
    XCTAssertTrue(app.buttons["blocking.choose"].exists); XCTAssertTrue(app.buttons["block.add"].exists); snap("11-blocking")
    tap("blocking.later"); allowAlerts(); snap("13-alerts")
    page("Sirish, commit to focus."); snap("14-commit")
    app.buttons["commit.hold"].press(forDuration: 0.4)  // Releasing early does not commit.
    XCTAssertTrue(app.buttons["commit.hold"].exists); page("Sirish, commit to focus.")
    app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Keep your progress safe."); snap("14b-account")
    XCTAssertEqual(app.buttons["account.apple"].label, "Sign up with Apple")  // Sign-up's own words.
    tap("account.debugSkip")
    page("Your workouts, back under your control.")
    XCTAssertTrue(any("journey.recap").waitForExistence(timeout: 6))
    XCTAssertTrue(app.staticTexts["subscription.message"].exists)  // Says why there are no plans.
    XCTAssertFalse(app.buttons["subscription.buy"].isEnabled)  // No product configured; nothing fake.
    XCTAssertFalse(app.buttons["subscription.preview"].exists)
    snap("12-offer")
  }

  func testRarelySkipsMinutesShowsNoPhoneTimeAndBackFollowsRoute() {
    next(); profile(); body(); answer("habit.scrolling.no")
    page("Sam, here’s how much time you spend on your phone during your workout session.")
    XCTAssertTrue(any("reveal.phone").label.hasPrefix("0 min"))  // Rarely: no phone time assumed.
    XCTAssertFalse(app.staticTexts["days.workouts"].exists)  // Nothing to add up, so no days page.
    tap("onboarding.back"); page("Do you use your phone between sets?")
    XCTAssertTrue(app.buttons["habit.scrolling.no"].isSelected)
  }

  /// Sign-in is its own screen, not sign-up's account step: its own words, "Sign in with…", no progress line.
  func testSignInIsItsOwnScreenApartFromSignUp() {
    // The welcome scene plays before its actions appear.
    settle(8); snap("20-welcome")
    tap("welcome.signIn"); page("Welcome back")
    XCTAssertEqual(app.buttons["account.apple"].label, "Sign in with Apple")
    XCTAssertTrue(app.buttons["account.google"].exists)
    XCTAssertFalse(app.buttons["account.debugSkip"].exists)  // Signing in has nothing to skip to.
    snap("21-sign-in")
    tap("onboarding.back")
    wait(for: [expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: app.buttons["onboarding.continue"])], timeout: 20)
    tap("onboarding.continue"); page("What should we call you?")
  }

  func testRelaunchResumesWithoutBypassingOffer() {
    next(); profile("Ana", gender: "female")
    XCTAssertTrue(app.pickerWheels["165 cm"].waitForExistence(timeout: 4) || app.pickerWheels["5′ 5″"].exists)
    body(); answer("habit.scrolling.sometimes")
    page("How long on your phone, each rest?"); next()
    page("Ana, here’s how much time you spend on your phone during your workout session.")
    XCTAssertTrue(any("reveal.phone").label.contains("17 min on your phone"))  // Sometimes defaults to 1 min per rest.
    for _ in 0..<8 { next() }
    page("Block what distracts you."); tap("blocking.later")
    page("Get a buzz when rest is up."); tap("alerts.later")
    page("Ana, commit to focus."); app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Keep your progress safe."); tap("account.debugSkip")
    page("Your workouts, back under your control.")
    XCTAssertTrue(any("journey.recap").waitForExistence(timeout: 5))
    app.terminate(); app.launchArguments = ["--offline"]; app.launch()  // No reset, no skip: the offer is where it resumes.
    page("Your workouts, back under your control.")
    // The offer is a wall, as in SleepBlock: no way back into the questions, none into the app.
    XCTAssertFalse(app.buttons["onboarding.back"].exists)
    XCTAssertFalse(app.buttons["home.start"].exists)
    tap("subscription.debugSkip"); page("Set up your splits.")
    XCTAssertFalse(app.buttons["onboarding.back"].isHittable)  // Past the offer there is no going back to it.
  }

  func testLargeTextReducedMotionKeepsEveryPageReachable() {
    app.terminate()
    app.launchArguments = ["--ui-reset", "--ui-reduced-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
    app.launch()
    next(); profile(); snap("large-height"); body(); answer("habit.scrolling.yes"); next()
    page("Sam, here’s how much time you spend on your phone during your workout session."); snap("large-reveal")
    for name in ["days", "mind-a", "mind-b", "rest-a", "rest-b", "log-a", "log-b"] { next(); snap("large-" + name) }
    next(); page("Block what distracts you."); snap("large-blocking")
    tap("blocking.later"); page("Get a buzz when rest is up."); snap("large-alerts"); tap("alerts.later")
    page("Sam, commit to focus."); snap("large-commit")
    app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Keep your progress safe."); tap("account.debugSkip")
    page("Your workouts, back under your control."); snap("large-offer")
  }
}
