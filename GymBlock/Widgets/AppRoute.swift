import Foundation

/// Where a widget, the control or a link opens the app: gymblock://<route>?from=<source>. The host is
/// the route, so the sign-in callback (gymblock://auth/callback) is never mistaken for one. `from` is a
/// fixed word naming the surface (small, medium, rect, inline, circular, month, control), for
/// analytics only: never a name or any of the user's text.
enum AppRoute: String {
  case home, start, workout, profile

  init?(url: URL) {
    guard url.scheme?.lowercased() == "gymblock", let h = url.host?.lowercased(), let r = AppRoute(rawValue: h) else { return nil }
    self = r
  }

  static func url(_ r: AppRoute, from: String) -> URL {
    URL(string: "gymblock://\(r.rawValue)?from=\(clean(from) ?? "link")")!
  }

  /// The link's `from`, if it's a short lowercase word; otherwise "link".
  static func source(_ url: URL) -> String {
    let from = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "from" }?.value
    return from.flatMap(clean) ?? "link"
  }

  private static func clean(_ s: String) -> String? {
    s.range(of: "^[a-z]{1,12}$", options: .regularExpression) != nil ? s : nil
  }
}
