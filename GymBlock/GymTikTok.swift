import Foundation
import TikTokBusinessSDK

/// Ad attribution for TikTok App Promotion campaigns, after SleepBlock's. The SDK reports installs,
/// launches and retention by itself; this adds the three funnel events worth optimizing toward: an
/// account created, a trial started, a subscription paid for.
///
/// No App Tracking Transparency prompt, deliberately: the IDFA is never available and nothing here
/// links a person across apps or websites. Attribution runs on SKAdNetwork (TikTok's id is in
/// Info.plist), which needs no consent. `TikTokBusiness.identify` is never called, so no hashed
/// email or phone leaves the phone. The SDK's own purchase observer is off (purchases are reported
/// from RevenueCat's answer, once) and so are its "enhanced data postback" page and click events,
/// which read on-screen text.
///
/// A silent no-op without all three keys (Secrets.xcconfig → Info.plist) and in development runs
/// (`AppConfig.offline`). Debug builds report to Events Manager's test feed, never production.
@MainActor enum GymTikTok {
  private struct Credentials {
    let appID: String
    let tiktokAppID: String
    let accessToken: String
  }

  private static var credentials: Credentials? {
    func value(_ key: String) -> String? {
      let raw = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      return raw?.isEmpty == false ? raw : nil
    }
    guard let appID = value("AppleAppID"), let tiktokAppID = value("TikTokAppID"),
          let accessToken = value("TikTokAccessToken") else { return nil }
    return Credentials(appID: appID, tiktokAppID: tiktokAppID, accessToken: accessToken)
  }

  private static var started = false

  /// As early in launch as possible: the SDK times the install and launch events off it.
  static func start() {
    guard !started, !AppConfig.offline, let credentials else { return }
    guard let config = TikTokConfig(accessToken: credentials.accessToken, appId: credentials.appID,
                                    tiktokAppId: credentials.tiktokAppID) else {
      AppLog.error("TikTok config rejected its credentials")
      return
    }
    config.skAdNetworkSupportEnabled = true
    config.disablePaymentTracking()
    config.disableAutoEnhancedDataPostbackEvent()
    #if DEBUG
      config.debugModeEnabled = true
    #endif
    started = true
    TikTokBusiness.initializeSdk(config) { success, error in
      if !success { AppLog.error("TikTok init failed: \(error?.localizedDescription ?? "unknown")") }
    }
  }

  /// A new GymBlock account (sign-up, or Settings attaching one), never a returning sign-in.
  static func reportRegistration() {
    report(.registration)
  }

  /// RevenueCat's answer for the purchase: a free trial is StartTrial; only a paid subscription
  /// is Subscribe, with its price (TikTok needs both value and currency, or neither).
  static func reportPurchase(price: Decimal, currency: String?, trial: Bool) {
    if trial {
      report(.startTrial)
    } else {
      report(.subscribe, currency.map { ["value": NSDecimalNumber(decimal: price).doubleValue, "currency": $0] })
    }
  }

  private static func report(_ event: TTEventName, _ properties: [String: Any]? = nil) {
    guard started else { return }
    let payload = TikTokBaseEvent(eventName: event.rawValue)
    properties?.forEach { payload.addProperty(withKey: $0.key, value: $0.value) }
    TikTokBusiness.trackTTEvent(payload)
  }
}
