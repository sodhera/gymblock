import XCTest

final class BenefitLayoutUITests: XCTestCase {
  func testCompactBenefits() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--ui-reset", "--ui-reduced-motion"]
    app.launch()
    func tap(_ id: String) {
      let b = app.buttons[id].firstMatch
      XCTAssertTrue(b.waitForExistence(timeout: 6)); b.tap()
    }
    func snap(_ name: String) {
      let screenshot = app.screenshot()
      try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name + ".png"))
      let a = XCTAttachment(screenshot: screenshot); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    tap("onboarding.secondary"); snap("v4-final-brains")
    tap("onboarding.continue"); snap("v4-final-arms")
    tap("journey.replay"); tap("onboarding.continue")
    XCTAssertTrue(app.staticTexts["This looks motivating."].waitForExistence(timeout: 6))
    XCTAssertTrue(app.staticTexts["This looks motivating."].isHittable)
    XCTAssertTrue(app.staticTexts["You can't tell if you're doing well or not."].isHittable)
    XCTAssertTrue(app.staticTexts["Percentages compare weight × reps with the previous record."].isHittable)
    snap("v4-final-records"); tap("onboarding.continue"); snap("v4-final-offer")
  }
}
