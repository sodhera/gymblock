import Foundation

/// Public client configuration. Everything here ships inside the binary (publishable keys and
/// public ids); secrets stay on the server.
enum AppConfig {
  /// The Supabase project shared with other Sodhera apps; GymBlock's tables are prefixed `gb_`.
  static let supabaseURL = URL(string: "https://tlcmpgxuyngsbjuhring.supabase.co")!
  static let supabaseKey = "sb_publishable_nIHOrgL5YE6qXiKCjQ7-Yg_Sj4w5z9e"
  /// Where the Google sign-in sheet returns to (registered in Supabase → Authentication → URL configuration).
  static let authCallback = URL(string: "gymblock://auth/callback")!
  /// RevenueCat's public SDK key, injected from Secrets.xcconfig; empty until the app is created there.
  static let revenueCatKey = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? "")
    .trimmingCharacters(in: .whitespacesAndNewlines)
  static let entitlement = "pro"
  static let monthlyProductID = "com.sodhera.gymblock.pro.monthly"
  static let yearlyProductID = "com.sodhera.gymblock.pro.yearly"

  static let privacyURL = URL(string: "https://www.orecci.com/gymblock/privacy-policy.html")!
  static let termsURL = URL(string: "https://www.orecci.com/gymblock/terms-of-service.html")!
  static let supportURL = URL(string: "https://www.orecci.com/gymblock/support.html")!
  static let deletionURL = URL(string: "https://www.orecci.com/gymblock/user-data-deletion.html")!
  static let supportEmail = "admin@sodhera.com"

  /// Development runs (UI tests, `--demo`, page jumps) stay offline: no account, no analytics.
  static var offline: Bool {
    #if DEBUG
      let args = ProcessInfo.processInfo.arguments
      // `--online` keeps the account, purchases and analytics live even on a page jump, for checking them by hand.
      if args.contains("--online") { return false }
      return args.contains { ["--ui-reset", "--demo", "--skip-onboarding", "--offline"].contains($0) || $0.hasPrefix("-journeyStep") || $0.hasPrefix("-workoutStage") }
    #else
      return false
    #endif
  }
}
