import Foundation

/// Where a widget, the control or a link asks the app to go (docs/WIDGETS-PLAN.md §7). A request waits
/// for the app screen: it's held through the splash and dropped by onboarding, sign-in, a notice or
/// the offer wall, so nothing from outside gets past them. GymNavigationView, MainTabs and HomeView act
/// on `ready` and consume it; a start must also be `settled` and fresh, so a press never starts a
/// workout behind the wall or later.
@MainActor final class AppRouter: ObservableObject {
  static let shared = AppRouter()
  struct Request: Equatable {
    let route: AppRoute
    let at: Date
    var fresh: Bool { Date().timeIntervalSince(at) <= 10 }
  }
  /// What RootView shows: the splash, the app, or anything else (onboarding, sign-in, a notice, the offer).
  enum Screen { case launch, app, other }
  /// The pending request, but only while the app screen is up.
  @Published private(set) var ready: Request?
  private var pending: Request? { didSet { update() } }
  var screen: Screen = .launch {
    didSet {
      if screen == .other { pending = nil }
      update()
    }
  }
  /// The launch hold's questions (the account, a signed-in account's entitlement) are answered and
  /// lead to the app. The hold's 4-second cap can show the app first and the offer wall still follow:
  /// a start acted on then would run, apps shielded, behind a wall with no way to Finish. So a start
  /// waits for this, and the ten-second rule drops it if the answers take longer. Other routes only
  /// move between pages and go through as soon as the app is up.
  var settled = false { didSet { update() } }
  /// Whether a link may start a workout: Debug only, for `simctl openurl` checks. In Release only the
  /// control and the app's own button start one. A property so tests can check the Release rule.
  var linksStart: Bool = {
    #if DEBUG
      return true
    #else
      return false
    #endif
  }()

  private func update() {
    var next = screen == .app ? pending : nil
    if next?.route == .start && !settled { next = nil }
    if next != ready { ready = next }
  }

  /// Widgets and links.
  func openURL(_ url: URL) {
    guard let r = AppRoute(url: url) else { return }
    if r == .start && !linksStart { return }
    open(r, source: AppRoute.source(url))
  }

  /// Also the control's intent. Logs the route and a fixed surface word, nothing else.
  func open(_ r: AppRoute, source: String) {
    Analytics.track("widget_opened", ["route": r.rawValue, "from": source])
    guard screen != .other else { return }
    pending = Request(route: r, at: Date())
  }

  func consume(_ r: Request) { if pending == r { pending = nil } }
}
