import Foundation
import ManagedSettings
import UserNotifications

/// The shield's buttons. "Back to training": a shield action can't open its app (it may only return
/// `.none`, `.close` or `.defer`; reaching `UIApplication` would be private API), so, as JournalBlock does,
/// it posts an immediate notification from GymBlock and closes the blocked app: the banner is waiting on
/// the Home Screen and one tap opens GymBlock on the workout. Without notification permission the button
/// just closes the blocked app. "Give me 1 minute" (Strict mode off, once per exercise) is the only way
/// past the block before the workout ends; see `BlockingPass`.
final class WorkoutShieldAction: ShieldActionDelegate {
  override func handle(action: ManagedSettings.ShieldAction, for application: ApplicationToken,
                       completionHandler: @escaping (ShieldActionResponse) -> Void) {
    respond(to: action, completionHandler)
  }
  override func handle(action: ManagedSettings.ShieldAction, for webDomain: WebDomainToken,
                       completionHandler: @escaping (ShieldActionResponse) -> Void) {
    respond(to: action, completionHandler)
  }
  override func handle(action: ManagedSettings.ShieldAction, for category: ActivityCategoryToken,
                       completionHandler: @escaping (ShieldActionResponse) -> Void) {
    respond(to: action, completionHandler)
  }

  private func respond(to action: ManagedSettings.ShieldAction, _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
    // "Give me 1 minute" (the second button): the block lifts and the app opens; the monitor puts it
    // back (BlockingPass).
    if action == .secondaryButtonPressed {
      completionHandler(BlockingPass.spend() ? .defer : .close)
      return
    }
    guard action == .primaryButtonPressed else { completionHandler(.close); return }
    let es = Locale.preferredLanguages.first?.hasPrefix("es") == true
    let content = UNMutableNotificationContent()
    content.title = es ? "Vuelve a tu entrenamiento" : "Back to your workout"
    content.body = es ? "Toca para abrir Gym Block." : "Tap to open Gym Block."
    content.sound = .default
    content.interruptionLevel = .timeSensitive
    // Delivered now (nil trigger); one identifier so repeated taps replace the banner rather than stack.
    let request = UNNotificationRequest(identifier: "gymblock.shield.back", content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { _ in completionHandler(.close) }
  }
}
