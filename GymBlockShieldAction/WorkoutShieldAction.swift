import ManagedSettings

/// The shield's one button closes the blocked app. Unblocking only happens in GymBlock (pause or finish).
final class WorkoutShieldAction: ShieldActionDelegate {
  override func handle(action: ManagedSettings.ShieldAction, for application: ApplicationToken,
                       completionHandler: @escaping (ShieldActionResponse) -> Void) {
    completionHandler(.close)
  }
  override func handle(action: ManagedSettings.ShieldAction, for webDomain: WebDomainToken,
                       completionHandler: @escaping (ShieldActionResponse) -> Void) {
    completionHandler(.close)
  }
  override func handle(action: ManagedSettings.ShieldAction, for category: ActivityCategoryToken,
                       completionHandler: @escaping (ShieldActionResponse) -> Void) {
    completionHandler(.close)
  }
}
