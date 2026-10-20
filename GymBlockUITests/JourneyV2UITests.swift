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

  /// Name → days a week (lands on the phone question). Choosing never advances on its own.
  private func profile(_ name: String = "Sam", days: Int = 4) {
    page("First, what should we call you?")
    let field = app.textFields["profile.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)  // A name is required.
    field.typeText(name + "\n")
    page("Hi \(name). How many days a week do you work out?")
    // The slider opens on 4, so Continue works untouched (18 Oct 2026).
    let slider = app.sliders["days.slider"]
    XCTAssertTrue(slider.waitForExistence(timeout: 6))
    if days != 4 { slider.adjust(toNormalizedSliderPosition: CGFloat(days - 1) / 6) }
    page("Hi \(name). How many days a week do you work out?")  // Still here: choosing only chooses.
    next(); page("Be honest. Do you check your phone between sets?")
  }
  /// The body questions left onboarding on 17 Oct 2026; kept so the journeys read the same.
  private func body() {}
  private func answer(_ id: String) {
    tap(id); XCTAssertTrue(app.buttons[id].isSelected)
    page("Be honest. Do you check your phone between sets?"); next()
  }
  /// Rest alerts: the system prompt appears once per simulator; allow it if it does.
  private func allowAlerts(rest: String = "1:30") {
    page("We’ll buzz you\nwhen your \(rest) is up."); tap("alerts.on")
    let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["Allow"]
    if allow.waitForExistence(timeout: 4) { allow.tap() }
  }
  /// A row on a time-back question, then Continue (selecting only selects).
  private func choose(_ id: String, on headline: String) {
    page(headline)
    XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)  // Nothing is chosen for them.
    tap(id); XCTAssertTrue(app.buttons[id].isSelected)
    page(headline); next()
  }
  /// Time back (docs/ONBOARDING-V8-PLAN.md): the rest they need, how long they scroll, exercises,
  /// sets and time at the gym.
  private func timeBack(rest: String = "rest.1.5", scroll: String = "4 min", exercises: Int = 5, sets: Int = 3, gym: Int = 90, perRest: String) {
    choose(rest, on: "How long do you need to rest between sets?")
    page("How long are you on your phone each time?")
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 6))
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: scroll); snap("07-scroll"); next()
    page(perRest)
    next()
    choose("exercises.\(exercises)", on: "How many exercises per workout?")
    choose("sets.\(sets)", on: "And how many sets of each?")
    choose("gym.\(gym)", on: "How long are you at the gym?")
  }

  func testFullJourneyShowsTimeBackSetsUpBlockingAndEndsOnOffer() {
    XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 8)); snap("01-welcome"); next()
    profile("Sirish")
    snap("05-scrolling"); answer("habit.scrolling.yes")
    timeBack(perRest: "That’s 2.5 minutes lost. Every rest.")
    // 14 rests × (4 − 1.5 min): only the scrolling past the rest they need.
    page("35 minutes go to your phone, every workout."); snap("12-workout")
    next(); page("That’s about 120\u{00A0}hours a year.")  // 35 min × 4 × 52, down to 10.
    XCTAssertTrue(app.staticTexts["year.workouts"].waitForExistence(timeout: 4))
    XCTAssertEqual(app.staticTexts["year.workouts"].label, "= 80 extra workouts"); snap("13-year")  // Of their 1.5 hours.
    next(); page("We’ll give you those 35 minutes back."); snap("14-promise")
    next(); page("Why I built GymBlock."); snap("14b-founder")
    next(); page("Open a locked app mid-workout and you’ll see this."); settle(2); snap("15-shield")
    next(); page("Which apps should we lock?")
    // Apps come from Screen Time's own picker, which needs the iPhone passcode: not reachable from a UI test.
    XCTAssertEqual(app.staticTexts["blocking.summary"].label, "Choose the apps that pull you in.")
    XCTAssertTrue(app.buttons["blocking.choose"].exists); XCTAssertTrue(app.buttons["block.add"].exists); snap("16-blocking")
    tap("blocking.later"); allowAlerts(); snap("17-alerts")
    page("Sirish, here’s your plan."); snap("18-commit")
    app.buttons["commit.hold"].press(forDuration: 0.4)  // Releasing early does not commit.
    XCTAssertTrue(app.buttons["commit.hold"].exists); page("Sirish, here’s your plan.")
    app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Let’s save your plan."); snap("19-account")
    XCTAssertEqual(app.buttons["account.apple"].label, "Sign up with Apple")  // Sign-up's own words.
    tap("account.debugSkip")
    page("Sirish, get your time back.")
    XCTAssertTrue(any("paywall.twoWays").waitForExistence(timeout: 6))
    XCTAssertTrue(any("journey.recap").exists)
    XCTAssertTrue(app.staticTexts["subscription.message"].exists)  // Says why there are no plans.
    XCTAssertFalse(app.buttons["subscription.buy"].isEnabled)  // No product configured; nothing fake.
    snap("20-offer")
  }

  func testRarelyIsAlreadyAheadAndBackFollowsRoute() {
    next(); profile(); body(); answer("habit.scrolling.no")
    choose("rest.0.0", on: "How long do you need to rest between sets?")  // Not sure: 2 minutes.
    page("Then you’re already ahead.")
    XCTAssertFalse(app.pickerWheels.firstMatch.exists)  // Rarely: no scrolling minutes, nothing to add up.
    next(); page("Why I built GymBlock.")
    next(); page("Open a locked app mid-workout and you’ll see this.")
    tap("onboarding.back"); page("Why I built GymBlock.")
    tap("onboarding.back"); page("Then you’re already ahead.")
    tap("onboarding.back"); page("How long do you need to rest between sets?")
    XCTAssertTrue(app.buttons["rest.0.0"].isSelected)
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
    tap("onboarding.continue"); page("First, what should we call you?")
  }

  func testRelaunchResumesWithoutBypassingOffer() {
    next(); profile("Ana"); body(); answer("habit.scrolling.sometimes")
    timeBack(perRest: "That’s 2.5 minutes lost each time you pick it up.")
    page("15 minutes go to your phone, every workout.")  // Half of 14 rests × 2.5, down to 5.
    next(); next(); page("We’ll give you those 15 minutes back.")
    next(); next(); next(); page("Which apps should we lock?"); tap("blocking.later")
    allowAlerts()
    page("Ana, here’s your plan."); app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Let’s save your plan."); tap("account.debugSkip")
    page("Ana, get your time back.")
    XCTAssertTrue(any("journey.recap").waitForExistence(timeout: 5))
    app.terminate(); app.launchArguments = ["--offline"]; app.launch()  // No reset, no skip: the offer is where it resumes.
    page("Ana, get your time back.")
    // The offer is a wall, as in SleepBlock: no way back into the questions, none into the app.
    XCTAssertFalse(app.buttons["onboarding.back"].exists)
    XCTAssertFalse(app.buttons["home.start"].exists)
    tap("subscription.debugSkip"); page("You’re in. How do you split your training?")
    XCTAssertFalse(app.buttons["onboarding.back"].isHittable)  // Past the offer there is no going back to it.
  }

  func testLargeTextReducedMotionKeepsEveryPageReachable() {
    app.terminate()
    app.launchArguments = ["--ui-reset", "--ui-reduced-motion", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
    app.launch()
    next(); profile(); body(); answer("habit.scrolling.yes")
    timeBack(perRest: "That’s 2.5 minutes lost. Every rest.")
    page("35 minutes go to your phone, every workout."); snap("large-workout")
    for name in ["year", "promise", "founder", "shield"] { next(); snap("large-" + name) }
    next(); page("Which apps should we lock?"); snap("large-blocking")
    tap("blocking.later"); allowAlerts(); snap("large-alerts")
    page("Sam, here’s your plan."); snap("large-commit")
    app.buttons["commit.hold"].press(forDuration: 2.2)
    page("Let’s save your plan."); tap("account.debugSkip")
    page("Sam, get your time back."); snap("large-offer")
  }
}
