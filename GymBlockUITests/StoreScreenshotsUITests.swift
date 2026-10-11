import XCTest

/// Walks every screen reachable by tapping and saves a full-screen PNG of each, for App Store
/// screenshot selection. Run with `TEST_RUNNER_SHOTS=<folder>`; without it every test is skipped.
final class StoreScreenshotsUITests: XCTestCase {
  private var app: XCUIApplication!
  private var folder: String!

  override func setUpWithError() throws {
    guard let path = ProcessInfo.processInfo.environment["SHOTS"] else { throw XCTSkip("SHOTS not set") }
    folder = path
    continueAfterFailure = true
  }
  private func launch(_ args: [String]) {
    app = XCUIApplication(); app.launchArguments = args; app.launch()
  }
  private func snap(_ name: String, settle: TimeInterval = 1.2) {
    Thread.sleep(forTimeInterval: settle)
    let png = XCUIScreen.main.screenshot().pngRepresentation
    try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"))
  }
  @discardableResult private func tap(_ id: String, scroll: Bool = true) -> Bool {
    let button = app.buttons[id].firstMatch
    if scroll { for _ in 0..<5 where !button.waitForExistence(timeout: 2) { app.swipeUp() } }
    guard button.waitForExistence(timeout: 6) else { return false }
    for _ in 0..<4 { if button.isHittable { break }; app.swipeUp() }
    Thread.sleep(forTimeInterval: 0.4); button.tap(); return true
  }
  private func back() { app.navigationBars.buttons.firstMatch.tap() }

  func testHomeHistoryAndProgress() {
    launch(["--ui-reset", "--demo"])
    _ = app.buttons["home.start"].waitForExistence(timeout: 10)
    if tap("home.pr", scroll: false) { snap("50-home-pr-detail"); back() }
    if tap("home.time", scroll: false) { snap("51-home-time-training"); back() }
    let trend = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'home.trend.'")).firstMatch
    if trend.waitForExistence(timeout: 4) { trend.tap(); snap("52-home-exercise-progress"); back() }
    tap("home.history", scroll: false); snap("53-history")
    if tap("history.reps", scroll: false) { snap("54-history-reps-chart"); back() }
    if tap("history.progress") {
      snap("55-progress")
      let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'progress.exercise.'")).firstMatch
      if first.waitForExistence(timeout: 4) { first.tap(); snap("56-progress-before-after"); back() }
      back()
    }
    let workout = app.buttons.matching(NSPredicate(format: "identifier MATCHES 'history\\\\.[0-9A-F-]{36}'")).firstMatch
    for _ in 0..<4 where !workout.isHittable { app.swipeUp() }
    if workout.exists { workout.tap(); snap("57-workout-detail") }
  }

  func testStartChooserSplitsAndPicker() {
    launch(["--ui-reset", "--demo"])
    tap("home.start", scroll: false); snap("60-start-chooser")
    tap("split.add"); snap("61-split-editor-new")
    let name = app.textFields["split.name"]
    if name.waitForExistence(timeout: 4) { name.tap(); name.typeText("Upper") }
    tap("split.exercises"); snap("62-split-exercise-picker")
    tap("split.exercise.bench"); tap("split.exercise.row"); tap("split.exercise.press")
    snap("63-split-exercise-picker-chosen")
    tap("split.exercises.done"); snap("64-split-editor-filled")
  }

  func testFreeWorkoutScreens() {
    launch(["--ui-reset", "--demo"])
    tap("home.start", scroll: false); tap("choice.free"); snap("65-exercise-picker")
    let search = app.searchFields.firstMatch
    if search.waitForExistence(timeout: 4) { search.tap(); search.typeText("curl"); snap("66-exercise-search") }
    tap("exercise.curl")
    let weight = app.textFields["set.weight"]
    if weight.waitForExistence(timeout: 4) { weight.tap(); weight.typeText("22.5"); snap("67-workout-typing-weight") }
    tap("workout.primary"); tap("set.keyboard.done")
    Thread.sleep(forTimeInterval: 4); tap("workout.primary")
    if tap("set.saved", scroll: false) { snap("68-edit-set"); tap("edit.save") }
    if tap("session.sets", scroll: false) { snap("69-workout-sets-sheet"); tap("records.done") }
    if tap("set.change", scroll: false) { snap("70-change-exercise"); app.buttons["exercise.cancel"].firstMatch.tap() }
    tap("session.finish", scroll: false); snap("71-end-workout-alert")
    tap("session.endConfirm", scroll: false)
    if app.buttons["summary.done"].waitForExistence(timeout: 6) {
      snap("72-summary-free")
      if tap("summary.saveSplit") { snap("73-summary-save-split") }
    }
  }

  func testSettingsPages() {
    launch(["--ui-reset", "--demo"])
    tap("home.preferences", scroll: false)
    if ProcessInfo.processInfo.environment["SETTINGS_SCROLL"] != nil {
      snap("80-settings-top"); app.swipeUp(); snap("81-settings-middle")
      app.swipeUp(); app.swipeUp(); snap("82-settings-bottom")
      app.swipeDown(); app.swipeDown(); app.swipeDown(); app.swipeDown()
    }
    let pages = [("settings.baseline", "84-settings-training-answers"),
                 ("settings.blockedApps", "85-settings-blocked-apps"), ("settings.data", "86-settings-your-data")]
    for (id, name) in pages {
      guard tap(id) else { continue }
      snap(name)
      let cancel = app.navigationBars.buttons["Cancel"]
      if cancel.exists { cancel.tap() } else { back() }
      Thread.sleep(forTimeInterval: 0.6)
      for _ in 0..<4 { app.swipeDown() }
    }
  }

  func testSignIn() {
    launch(["--ui-reset", "--online"])
    _ = app.buttons["welcome.signIn"].waitForExistence(timeout: 20)
    if tap("welcome.signIn", scroll: false) { snap("24-sign-in", settle: 2) }
  }
}
