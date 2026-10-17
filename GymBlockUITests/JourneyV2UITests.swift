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

  /// Sulav's note → name → days a week (lands on the phone question). Choosing never advances on its own.
  private func profile(_ name: String = "Sam", days: Int = 4) {
    page("“Perfection is lots of little things done right.”"); next()
    page("First, what should we call you?")
    let field = app.textFields["profile.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)  // A name is required.
    field.typeText(name + "\n")
    page("Nice to meet you, \(name). How many days a week do you lift?")
    XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)
    tap("days.\(days)")
    XCTAssertTrue(app.buttons["days.\(days)"].isSelected)
    page("Nice to meet you, \(name). How many days a week do you lift?")  // Still here: selecting only selects.
    next(); page("Be honest. Do you check your phone between sets?")
  }
  /// The body questions left onboarding on 17 Oct 2026; kept so the journeys read the same.
  private func body() {}
  private func answer(_ id: String) {
    tap(id); XCTAssertTrue(app.buttons[id].isSelected)
    page("Be honest. Do you check your phone between sets?"); next()
  }
  /// Rest alerts: the system prompt appears once per simulator; allow it if it does.
  private func allowAlerts() {
    page("We’ll buzz you when rest is up."); tap("alerts.on")
    let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
    if allow.waitForExistence(timeout: 4) { allow.tap() }
  }

  func testFullJourneyEstimatesFromMinutesSetsUpBlockingAndEndsOnOffer() {
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8)); snap("01-welcome"); next()
    profile("Sirish")
    snap("06-scrolling"); answer("habit.scrolling.yes")
    page("Roughly how long, each rest?")
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 6))
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "2 min"); snap("03-minutes"); next()
    page("Sirish, here’s where your workout time goes.")
    // 17 rests × 2 min on the phone, against 18 sets × 40 s of training.
    XCTAssertTrue(any("reveal.phone").label.contains("34 min on your phone"), any("reveal.phone").label)
    XCTAssertTrue(any("reveal.phone").label.contains("12 min training"))
    XCTAssertFalse(app.buttons["reveal.sets.plus"].exists)  // No adjusters: one plain fact.
    snap("07-reveal")
    next(); page("At your 4 workouts a week, that’s 118 hours a year.")  // 34 min × 4 a week × 52.
    XCTAssertTrue(app.staticTexts["days.workouts"].waitForExistence(timeout: 4))
    XCTAssertEqual(app.staticTexts["days.workouts"].label, "= 196 workouts"); snap("08-hours")  // 45 min each.
    next(); page("Scrolling weakens your mind-muscle connection."); snap("07-mind-a")
    next(); page("Put it away. Feel every rep."); snap("08-mind-b")
    next(); page("Long scrolls between sets?\nThe pump never builds.")
    // Continue appears once the scene ends (XCUITest waits for animations, so only the end state is observable).
    let shown = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["onboarding.continue"])
    wait(for: [shown], timeout: 7); snap("09-rest-a")
    next(); page("Rest on time,\nand it keeps building."); snap("10-rest-b")
    next(); page("Quick: what did you bench last week?"); settle(4); snap("09-log-a")
    next(); page("Your log remembers. Every set."); settle(3); snap("10-log-b")
    next(); page("Which apps should we lock while you train?")
    // Apps come from Screen Time's own picker, which needs the iPhone passcode: not reachable from a UI test.
    XCTAssertEqual(app.staticTexts["blocking.summary"].label, "Choose the apps that pull you in.")
    XCTAssertTrue(app.buttons["blocking.choose"].exists); XCTAssertTrue(app.buttons["block.add"].exists); snap("11-blocking")
    tap("blocking.later"); allowAlerts(); snap("13-alerts")
    page("Sirish, here’s your plan."); snap("14-commit")
    app.buttons["commit.hold"].press(forDuration: 0.4)  // Releasing early does not commit.
    XCTAssertTrue(app.buttons["commit.hold"].exists); page("Sirish, here’s your plan.")
    app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Let’s save your plan to your account."); snap("14b-account")
    XCTAssertEqual(app.buttons["account.apple"].label, "Sign up with Apple")  // Sign-up's own words.
    tap("account.debugSkip")
    page("Sirish, your best sessions start today.")
    XCTAssertTrue(any("journey.recap").waitForExistence(timeout: 6))
    XCTAssertTrue(app.staticTexts["subscription.message"].exists)  // Says why there are no plans.
    XCTAssertFalse(app.buttons["subscription.buy"].isEnabled)  // No product configured; nothing fake.
    XCTAssertFalse(app.buttons["subscription.preview"].exists)
    snap("12-offer")
  }

  func testRarelySkipsMinutesShowsNoPhoneTimeAndBackFollowsRoute() {
    next(); profile(); body(); answer("habit.scrolling.no")
    page("Sam, here’s where your workout time goes.")
    XCTAssertTrue(any("reveal.phone").label.hasPrefix("0 min"))  // Rarely: no phone time assumed.
    XCTAssertFalse(app.staticTexts["days.workouts"].exists)  // Nothing to add up, so no days page.
    tap("onboarding.back"); page("Be honest. Do you check your phone between sets?")
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
    tap("onboarding.continue"); page("“Perfection is lots of little things done right.”")
  }

  func testRelaunchResumesWithoutBypassingOffer() {
    next(); profile("Ana")
    XCTAssertTrue(app.pickerWheels["165 cm"].waitForExistence(timeout: 4) || app.pickerWheels["5′ 5″"].exists)
    body(); answer("habit.scrolling.sometimes")
    page("Roughly how long, each rest?"); next()
    page("Ana, here’s where your workout time goes.")
    XCTAssertTrue(any("reveal.phone").label.contains("17 min on your phone"))  // Sometimes defaults to 1 min per rest.
    for _ in 0..<8 { next() }
    page("Which apps should we lock while you train?"); tap("blocking.later")
    page("We’ll buzz you when rest is up."); tap("alerts.later")
    page("Ana, here’s your plan."); app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Let’s save your plan to your account."); tap("account.debugSkip")
    page("Ana, your best sessions start today.")
    XCTAssertTrue(any("journey.recap").waitForExistence(timeout: 5))
    app.terminate(); app.launchArguments = ["--offline"]; app.launch()  // No reset, no skip: the offer is where it resumes.
    page("Ana, your best sessions start today.")
    // The offer is a wall, as in SleepBlock: no way back into the questions, none into the app.
    XCTAssertFalse(app.buttons["onboarding.back"].exists)
    XCTAssertFalse(app.buttons["home.start"].exists)
    tap("subscription.debugSkip"); page("You’re in. How do you usually split your training?")
    XCTAssertFalse(app.buttons["onboarding.back"].isHittable)  // Past the offer there is no going back to it.
  }

  func testLargeTextReducedMotionKeepsEveryPageReachable() {
    app.terminate()
    app.launchArguments = ["--ui-reset", "--ui-reduced-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
    app.launch()
    next(); profile(); snap("large-height"); body(); answer("habit.scrolling.yes"); next()
    page("Sam, here’s where your workout time goes."); snap("large-reveal")
    for name in ["days", "mind-a", "mind-b", "rest-a", "rest-b", "log-a", "log-b"] { next(); snap("large-" + name) }
    next(); page("Which apps should we lock while you train?"); snap("large-blocking")
    tap("blocking.later"); page("We’ll buzz you when rest is up."); snap("large-alerts"); tap("alerts.later")
    page("Sam, here’s your plan."); snap("large-commit")
    app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Let’s save your plan to your account."); tap("account.debugSkip")
    page("Sam, your best sessions start today."); snap("large-offer")
  }
}
