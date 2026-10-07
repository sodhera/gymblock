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
  static let idleID = "gymblock.idle"
  /// "Still training?" when a workout has had no activity for a while. Only delivered if
  /// notifications were allowed; never asks for permission by itself.
  static func scheduleIdle(at date: Date, spanish: Bool) {
    let wait = date.timeIntervalSinceNow
    guard wait > 1 else { return }
    let content = UNMutableNotificationContent()
    content.title = spanish ? "¿Sigues entrenando?" : "Still training?"
    content.body = spanish ? "Tu entrenamiento sigue abierto. Ábrelo para terminarlo." : "Your workout is still running. Open GymBlock to finish it."
    let request = UNNotificationRequest(identifier: idleID, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false))
    UNUserNotificationCenter.current().add(request)
  }
  static func cancelIdle() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [idleID])
  }
}
