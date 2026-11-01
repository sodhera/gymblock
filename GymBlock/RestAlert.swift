import Foundation
import UserNotifications

/// Local "rest's up" notification. Nothing leaves the device.
enum RestAlert {
  static let id = "gymblock.rest"
  static func requestPermission() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
  }
  /// What iOS has recorded: the prompt shows only while this is `.notDetermined`.
  static func status() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }
  static func granted(_ s: UNAuthorizationStatus) -> Bool { [.authorized, .provisional, .ephemeral].contains(s) }
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
  static func scheduleIdle(at date: Date, paused: Bool, spanish: Bool) {
    let wait = date.timeIntervalSinceNow
    guard wait > 1 else { return }
    let content = UNMutableNotificationContent()
    content.title = spanish ? "¿Sigues entrenando?" : "Still training?"
    content.body = paused
      ? (spanish ? "Tu entrenamiento sigue en pausa. Ábrelo para reanudarlo o terminarlo." : "Your workout is still paused. Open GymBlock to resume or finish it.")
      : (spanish ? "Tu entrenamiento sigue abierto. Ábrelo para terminarlo." : "Your workout is still running. Open GymBlock to finish it.")
    let request = UNNotificationRequest(identifier: idleID, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false))
    UNUserNotificationCenter.current().add(request)
  }
  static func cancelIdle() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [idleID])
  }
  static let trialID = "gymblock.trial"
  static let trialKey = "gymblock.trial.reminder"
  /// The paywall's promise: two days before a free trial turns into a paid plan, a reminder. Only
  /// delivered if notifications were allowed; never asks for permission by itself. Kept, so it can
  /// be added again once they allow notifications on the page after the price (1 Nov 2026).
  static func scheduleTrialReminder(trialDays: Int, price: String, spanish: Bool) {
    guard trialDays > 2 else { return }
    let title = spanish ? "Tu prueba gratis termina en 2 días" : "Your free trial ends in 2 days"
    let body = (spanish ? "Después, %@. Puedes cancelar en Ajustes antes de esa fecha." : "Then it’s %@. You can cancel in Settings before then.")
      .replacingOccurrences(of: "%@", with: price)
    let fire = Date().addingTimeInterval(Double(trialDays - 2) * 86_400)
    UserDefaults.standard.set(["title": title, "body": body, "fire": fire.timeIntervalSince1970], forKey: trialKey)
    addTrialReminder()
  }
  /// Adds the kept reminder (the same identifier replaces it), while its day is still ahead.
  static func addTrialReminder() {
    guard let saved = UserDefaults.standard.dictionary(forKey: trialKey), let title = saved["title"] as? String,
          let body = saved["body"] as? String, let fire = saved["fire"] as? Double else { return }
    let wait = Date(timeIntervalSince1970: fire).timeIntervalSinceNow
    guard wait > 60 else { return }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    let request = UNNotificationRequest(identifier: trialID, content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: wait, repeats: false))
    UNUserNotificationCenter.current().add(request)
  }
}
