import Foundation
import PostHog
import Supabase

/// PostHog gets the same events as `gb_events`, already cleaned by `Analytics` (fixed keys,
/// bounded values: never a name, a free-text answer or an email). Nothing is captured on its own:
/// no autocapture, no screen swizzling, no lifecycle events, no session replay, no surveys, no
/// push hooks and no location from the IP address. The account is the Supabase user id, with no
/// person properties beyond the SDK's device defaults. A silent no-op with no key and in
/// development runs (`AppConfig.offline`).
@MainActor enum GymPostHog {
  private static let ready: Bool = {
    let key = AppConfig.postHogKey
    guard !key.isEmpty, !AppConfig.offline else { return false }
    let config = PostHogConfig(projectToken: key, host: AppConfig.postHogHost)
    config.captureApplicationLifecycleEvents = false
    config.captureScreenViews = false
    config.captureElementInteractions = false
    config.sessionReplay = false
    config.surveys = false
    config.capturePushNotificationSubscriptions = false
    config.capturePushNotificationOpened = false
    config.preloadFeatureFlags = false
    config.disableGeoIp = true
    PostHogSDK.shared.setup(config)
    registerInstall()
    return true
  }()

  /// One of `Analytics`' rows. Screens go in as PostHog screen views, everything else by name.
  static func capture(_ name: String, screen: String?, properties: [String: AnyJSON], duration: Int?) {
    guard ready else { return }
    var props: [String: Any] = [:]
    for (key, value) in properties {
      if case .null = value { continue }
      props[key] = value.value
    }
    if let screen { props["screen"] = screen }
    if let duration { props["duration_ms"] = duration }
    props["gb_session_id"] = Analytics.sessionID.uuidString.lowercased()
    if name == "screen", let screen {
      PostHogSDK.shared.screen(screen, properties: props)
    } else {
      PostHogSDK.shared.capture(name, properties: props)
    }
  }

  /// The signed-in account, or nil after Log out / Delete account: a fresh anonymous id, so the
  /// next person on this phone isn't joined to the last one.
  static func identify(_ id: UUID?) {
    guard ready else { return }
    if let id {
      PostHogSDK.shared.identify(id.uuidString.lowercased())
    } else {
      PostHogSDK.shared.flush()
      PostHogSDK.shared.reset()
      registerInstall()
    }
  }

  /// The same install id as `gb_events`, so the two can be joined (reset clears it).
  private static func registerInstall() {
    PostHogSDK.shared.register(["install_id": Analytics.installID.uuidString.lowercased()])
  }
}
