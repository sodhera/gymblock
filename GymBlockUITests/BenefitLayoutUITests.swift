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
    let field = app.textFields["profile.name"]
    XCTAssertTrue(field.waitForExistence(timeout: 6)); field.typeText("Sam\n")  // Keyboard page: the button rides the keyboard.
    // Gender, height, weight, phone question: Continue never moves.
    XCTAssertTrue(app.buttons["profile.gender.other"].waitForExistence(timeout: 6))
    tap("profile.gender.other")
    for _ in 0..<3 {
      let button = app.buttons["onboarding.continue"]
      XCTAssertTrue(button.waitForExistence(timeout: 6))
      XCTAssertEqual(button.frame.midY, anchor, accuracy: 3)
      tap("onboarding.continue")
    }
    tap("habit.scrolling.yes")
    XCTAssertEqual(app.buttons["onboarding.continue"].frame.midY, anchor, accuracy: 3)
    tap("onboarding.continue")
    for _ in 0..<9 {
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
