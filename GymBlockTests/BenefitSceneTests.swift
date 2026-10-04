import XCTest
@testable import GymBlock

@MainActor final class BenefitSceneTests: XCTestCase {
  func testTimedRestReachesPumpOnFifthContractionWhileLongRestResets() {
    XCTAssertEqual(RestIllustration.pose(time: 0, timed: true).warmth, 0)
    XCTAssertEqual(RestIllustration.pose(time: 0, timed: false).curl, 0)
    for (cycle, peak) in [0.25, 0.45, 0.65, 0.85, 1.0].enumerated() {
      let t = 0.6 + Double(cycle) * 1.7 + 0.65
      XCTAssertEqual(RestIllustration.pose(time: t, timed: true).warmth, peak, accuracy: 0.0001)
    }
    XCTAssertLessThan(RestIllustration.pose(time: RestIllustration.pumpTime - 0.01, timed: true).warmth, 1)
    XCTAssertEqual(RestIllustration.pose(time: 10.6, timed: true).warmth, 1)
    for cycle in 0..<3 {
      let t = 0.6 + Double(cycle) * 2.4
      XCTAssertEqual(RestIllustration.pose(time: t + 0.65, timed: false).warmth, 0.25, accuracy: 0.0001)
      XCTAssertEqual(RestIllustration.pose(time: t + 2.399, timed: false).warmth, 0, accuracy: 0.001)
    }
  }
  func testEveryRouteShowsThreeBenefitsBeforeSubscription() {
    for answer in HabitAnswer.allCases {
      var b = RoutineBaseline(); b.scrollFrequency = answer; b.scrollsBetweenSets = answer != .no
      let route = OnboardingRoute.steps(b)
      XCTAssertEqual(Array(route.suffix(4)), [.reveal, .restStory, .progressStory, .subscription])
      XCTAssertEqual(route.contains(.minutes), answer != .no)
      XCTAssertEqual(route.contains(.breaks), answer == .sometimes)
    }
    XCTAssertEqual(OnboardingRoute.steps(RoutineBaseline()).last, .subscription)
  }
  func testUnconfiguredPurchaseCannotInventEntitlement() async {
    let purchase = GymSubscription()
    XCTAssertFalse(purchase.configured)
    await purchase.load(); XCTAssertNil(purchase.product); XCTAssertFalse(purchase.hasAccess)
    await purchase.buy(); XCTAssertFalse(purchase.hasAccess)
    await purchase.restore(); XCTAssertFalse(purchase.hasAccess)
    XCTAssertNotNil(purchase.message)
  }
}
