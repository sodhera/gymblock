import XCTest

final class BenefitLayoutUITests: XCTestCase {
  /// The primary action sits at the same height on every page, so the thumb never hunts.
  func testPrimaryActionNeverMoves() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--ui-reset", "--ui-reduced-motion"]
    app.launch()
    func tap(_ id: String) {
      let b = app.buttons[id].firstMatch
      XCTAssertTrue(b.waitForExistence(timeout: 6), id)
      let ready = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: b)
      wait(for: [ready], timeout: 6); b.tap()
    }
    let first = app.buttons["onboarding.continue"]
    XCTAssertTrue(first.waitForExistence(timeout: 6))
    let anchor = first.frame.midY
    tap("onboarding.continue")
    tap("onboarding.continue")  // Sulav's note.
    let field = app.textFields["profile.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 6)); field.typeText("Sam\n")  // Keyboard page: the button rides the keyboard.
    // Days a week, phone question: Continue never moves.
    XCTAssertTrue(app.sliders["days.slider"].waitForExistence(timeout: 6))  // Opens on 4.
    for _ in 0..<1 {
      let button = app.buttons["onboarding.continue"]
      XCTAssertTrue(button.waitForExistence(timeout: 6))
      XCTAssertEqual(button.frame.midY, anchor, accuracy: 3)
      tap("onboarding.continue")
    }
    tap("habit.scrolling.yes")
    XCTAssertEqual(app.buttons["onboarding.continue"].frame.midY, anchor, accuracy: 3)
    tap("onboarding.continue")
    // Time back (V8): every question's rows sit above the same Continue.
    func choose(_ id: String) {
      tap(id)
      XCTAssertEqual(app.buttons["onboarding.continue"].frame.midY, anchor, accuracy: 3)
      tap("onboarding.continue")
    }
    choose("rest.1.5")
    XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 6))
    app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "4 min")
    XCTAssertEqual(app.buttons["onboarding.continue"].frame.midY, anchor, accuracy: 3)
    tap("onboarding.continue")
    tap("onboarding.continue")  // Lost per rest.
    choose("exercises.5"); choose("sets.3"); choose("gym.90")
    for _ in 0..<4 {  // The workout, the year, the promise and the shield, up to the apps page.
      let button = app.buttons["onboarding.continue"]
      XCTAssertTrue(button.waitForExistence(timeout: 6))
      XCTAssertEqual(button.frame.midY, anchor, accuracy: 3)
      tap("onboarding.continue")
    }
    XCTAssertEqual(app.buttons["blocking.choose"].frame.midY, anchor, accuracy: 3)
    tap("blocking.later")
    XCTAssertTrue(app.buttons["alerts.later"].waitForExistence(timeout: 6))
    let alertsOn = app.buttons["alerts.on"]
    wait(for: [expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: alertsOn)], timeout: 6)
    XCTAssertEqual(alertsOn.frame.midY, anchor, accuracy: 3)
    tap("alerts.later")
    XCTAssertTrue(app.buttons["commit.hold"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.buttons["commit.hold"].frame.midY, anchor, accuracy: 3)
    app.buttons["commit.hold"].press(forDuration: 2.2)
    XCTAssertTrue(app.buttons["account.apple"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.buttons["account.apple"].frame.midY, anchor, accuracy: 3)
    tap("account.debugSkip")
    XCTAssertTrue(app.buttons["subscription.buy"].waitForExistence(timeout: 6))
    XCTAssertEqual(app.buttons["subscription.buy"].frame.midY, anchor, accuracy: 3)
  }
}
