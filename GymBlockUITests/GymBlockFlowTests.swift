import XCTest

final class GymBlockFlowTests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(); app.launchArguments = ["--ui-reset", "--demo"]; app.launch()
    }
    private func tap(_ id: String) {
        let element = app.buttons[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 6), id)
        for _ in 0..<6 { if element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.isHittable, id); XCTAssertTrue(element.isEnabled, id); element.tap()
    }
    private func fill(_ id: String, _ text: String) {
        let field = app.textFields[id]
        XCTAssertTrue(field.waitForExistence(timeout: 5), id)
        for _ in 0..<5 { if field.isHittable { break }; app.swipeUp() }
        field.tap()
        if let existing = field.value as? String, !existing.isEmpty, existing != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(text)
        if app.buttons["keyboard.done"].exists { app.buttons["keyboard.done"].firstMatch.tap() }
    }
    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 0.7)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
    func testFreestyleSearchEditablePickerSetRestRepeatAndRelaunch() {
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6 active weeks in a row"].exists)
        snap("01-home-red-blue")
        tap("home.start")
        XCTAssertTrue(app.staticTexts["session.blocking"].exists)
        XCTAssertTrue(app.textFields["exercise.search"].exists)
        fill("exercise.search", "dum")
        XCTAssertTrue(app.buttons["exercise.hammer"].exists)
        snap("02-search-dumbbell")
        tap("exercise.curl")
        tap("set.weight.picker")
        XCTAssertTrue(app.pickerWheels.firstMatch.waitForExistence(timeout: 5))
        app.pickerWheels.firstMatch.adjust(toPickerWheelValue: "22.5")
        XCTAssertEqual(app.textFields["set.weight.manual"].value as? String, "22.5")
        snap("03-editable-weight-picker")
        tap("set.weight.picker.done")
        fill("set.weight", "25")
        tap("set.start")
        XCTAssertTrue(app.textFields["set.reps"].exists)
        fill("set.reps", "12")
        snap("04-active-set-reps")
        tap("set.stop")
        XCTAssertTrue(app.staticTexts["rest.countdown"].exists)
        XCTAssertEqual(app.textFields["set.weight"].value as? String, "25")
        snap("05-automatic-rest")
        tap("set.start"); fill("set.reps", "8"); tap("set.stop")
        tap("set.change"); fill("exercise.search", "hammer"); tap("exercise.hammer")
        fill("set.weight", "15"); tap("set.start"); fill("set.reps", "10")
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.buttons["set.stop"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["set.reps"].value as? String, "10")
        tap("set.stop"); tap("session.finish")
        XCTAssertTrue(app.staticTexts["summary.unblocked"].exists)
        XCTAssertTrue(app.staticTexts["3 sets · 30 reps · 1 min"].exists || app.staticTexts["Workout complete"].exists)
        snap("06-workout-summary"); tap("summary.done")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        tap("home.history"); XCTAssertTrue(app.staticTexts["25 kg × 12"].waitForExistence(timeout: 5)); tap("history.done")
    }
    func testSplitCreationSelectionAndProgressAnimation() {
        tap("home.preferences"); tap("settings.splits"); tap("split.add")
        fill("split.name", "Monday")
        tap("split.exercises"); tap("split.exercise.curl"); tap("split.exercise.hammer"); tap("split.exercises.done")
        tap("split.save")
        XCTAssertTrue(app.buttons["split.edit.Monday"].waitForExistence(timeout: 5))
        snap("07-splits-settings")
        tap("preferences.done")
        tap("home.workout"); app.buttons["Monday"].tap()
        tap("home.start")
        XCTAssertTrue(app.buttons["exercise.curl"].exists)
        XCTAssertTrue(app.buttons["exercise.hammer"].exists)
        XCTAssertFalse(app.buttons["exercise.bench"].exists)
        snap("08-split-ready")
        tap("exercise.curl"); tap("set.start"); tap("set.stop"); tap("session.finish"); tap("summary.done")
        tap("home.progress")
        tap("progress.exercise.curl")
        XCTAssertTrue(app.staticTexts["progress.change"].waitForExistence(timeout: 5))
        tap("progress.replay"); snap("09-split-before-after-progress")
        app.navigationBars.buttons.firstMatch.tap()
        tap("progress.done")
    }
    func testPoundsConversionDurationAndEmptyWorkout() {
        tap("home.start"); fill("exercise.search", "curl"); tap("exercise.curl")
        fill("set.weight", "10"); app.segmentedControls.buttons["lb"].tap()
        XCTAssertEqual(app.textFields["set.weight"].value as? String, "22.05")
        fill("set.weight", "20"); tap("set.start"); tap("set.stop")
        tap("set.change"); fill("exercise.search", "Running"); tap("exercise.run")
        tap("set.start"); fill("set.minutes", "5"); tap("set.stop")
        XCTAssertTrue(app.staticTexts["5 min"].exists)
        tap("session.finish"); tap("summary.done")
        tap("home.start"); tap("session.finish"); tap("session.finish.confirm")
        XCTAssertTrue(app.staticTexts["No sets logged this time."].waitForExistence(timeout: 5)); tap("summary.done")
    }
    func testCleanOnboardingRemainsAvailableWithoutDemo() {
        app.terminate(); app.launchArguments = ["--ui-reset"]; app.launch()
        tap("language.en"); tap("onboarding.continue"); fill("name.field", "Sirish"); tap("onboarding.continue")
        tap("training.Weightlifting"); tap("onboarding.continue"); tap("favorite.curl"); tap("onboarding.continue")
        tap("onboarding.continue"); tap("onboarding.continue")
        XCTAssertTrue(app.buttons["home.start"].waitForExistence(timeout: 5))
        tap("home.start")
        XCTAssertTrue(app.textFields["exercise.search"].exists)
        XCTAssertFalse(app.staticTexts["Choose your workout."].exists)
    }
}
