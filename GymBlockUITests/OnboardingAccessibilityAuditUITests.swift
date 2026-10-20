import XCTest

/// Apple's accessibility audit (contrast, hit regions, element descriptions, Dynamic Type, clipped
/// text, traits) on every onboarding page, opened with `-journeyStep` (inspection, 20 Oct 2026).
/// Issues are logged as "AUDIT <page> | <type> | …", not failed, so one run lists them all.
final class OnboardingAccessibilityAuditUITests: XCTestCase {
  private func name(_ type: XCUIAccessibilityAuditType) -> String {
    switch type {
    case .contrast: return "contrast"
    case .elementDetection: return "elementDetection"
    case .hitRegion: return "hitRegion"
    case .sufficientElementDescription: return "description"
    case .dynamicType: return "dynamicType"
    case .textClipped: return "textClipped"
    case .trait: return "trait"
    default: return "other(\(type.rawValue))"
    }
  }

  func testAuditEveryOnboardingPage() throws {
    let pages = ["welcome", "founder", "name", "trainingDays", "scrolling", "restNeed", "scrollMinutes", "perRest",
                 "exerciseCount", "setCount", "gymTime", "workoutTime", "yearTime", "promise", "shield", "blocking",
                 "alerts", "commit", "account", "subscription", "splits", "firstWorkout", "ahead"]
    for page in pages {
      let app = XCUIApplication()
      app.launchArguments = ["--ui-reset", "-journeyStep", page] + (page == "ahead" ? ["-journeyFrequency", "no"] : [])
      app.launch()
      // Let the scene finish so Continue and the last frame are on screen.
      _ = app.staticTexts["onboarding.question"].waitForExistence(timeout: 15)
      sleep(8)
      var issues: [String] = []
      try app.performAccessibilityAudit { issue in
        let element = issue.element.map { "type=\($0.elementType.rawValue) label='\($0.label)' id='\($0.identifier)' frame=\($0.frame)" } ?? "no element"
        issues.append("\(self.name(issue.auditType)) | \(issue.compactDescription) | \(element)")
        return true
      }
      print(issues.isEmpty ? "AUDIT \(page) | clean" : issues.map { "AUDIT \(page) | \($0)" }.joined(separator: "\n"))
      app.terminate()
    }
  }
}
