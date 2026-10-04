import XCTest

final class WorkoutActionsUITests: XCTestCase {
  private func tap(_ app: XCUIApplication, _ id: String) {
    let button = app.buttons[id].firstMatch
    XCTAssertTrue(button.waitForExistence(timeout: 6), id)
    XCTAssertTrue(button.isHittable, id)
    button.tap()
  }
  private func snap(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  func testBottomEndPreservesAnActiveSetUntilConfirmed() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--ui-reset", "--demo"]; app.launch()
    tap(app, "home.start"); snap(app, "actions-choose-exercise")
    tap(app, "exercise.curl"); snap(app, "actions-ready")
    XCTAssertTrue(app.buttons["set.change"].label.contains("Change exercise"))
    XCTAssertGreaterThan(app.buttons["session.finish"].frame.minY, app.buttons["set.start"].frame.maxY)
    tap(app, "set.start")
    let reps = app.textFields["set.reps"]
    XCTAssertTrue(reps.waitForExistence(timeout: 6)); reps.tap(); reps.typeText("12")
    tap(app, "session.finish")
    XCTAssertTrue(app.buttons["session.saveEnd"].waitForExistence(timeout: 6))
    snap(app, "actions-end-confirmation")
    app.buttons["Keep going"].tap()
    XCTAssertEqual(reps.value as? String, "12")
    snap(app, "actions-active")
    tap(app, "set.stop")
    XCTAssertTrue(app.staticTexts["rest.elapsed"].waitForExistence(timeout: 6))
    snap(app, "actions-rest")
    tap(app, "session.finish")
    XCTAssertTrue(app.staticTexts["1 sets · 12 reps"].waitForExistence(timeout: 6))
    tap(app, "summary.done")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
  }
  func testActionsRemainReachableAtLargerText() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["--ui-reset", "--demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
    app.launch()
    tap(app, "home.start"); tap(app, "exercise.curl")
    XCTAssertTrue(app.buttons["set.change"].isHittable)
    XCTAssertTrue(app.buttons["set.start"].isHittable)
    snap(app, "actions-large-ready")
    tap(app, "set.start")
    XCTAssertTrue(app.buttons["set.stop"].waitForExistence(timeout: 6))
    snap(app, "actions-large-active")
    tap(app, "session.finish"); tap(app, "session.discardEnd")
    XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 6))
    XCTAssertFalse(app.buttons["summary.done"].exists)
  }
}
