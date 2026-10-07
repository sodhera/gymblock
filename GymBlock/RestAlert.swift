import Foundation
import UserNotifications

/// Local "rest's up" notification. Nothing leaves the device.
enum RestAlert {
  static let id = "gymblock.rest"
  static func requestPermission() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
  }
  static func schedule(at date: Date, seconds: Int, spanish: Bool) {
    let wait = date.timeIntervalSinceNow
    guard wait > 1 else { return }
    let content = UNMutableNotificationContent()
    content.title = spanish ? "Descanso terminado" : "Rest’s up"
    content.body = (spanish ? "%@ listo. Siguiente serie." : "%@ done. Time for your next set.")
      .replacingOccurrences(of: "%@", with: clockString(seconds))
    content.sound = .default
    content.interruptionLevel = .timeSensitive
    let request = UNNotificationRequest(identifier: id, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false))
    UNUserNotificationCenter.current().add(request)
  }
  static func cancel() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
  }
}
