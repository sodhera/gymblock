import Foundation
import Supabase
import SwiftUI
import UIKit
import UserNotifications

/// First-party product analytics into Supabase (`gb_events`): every screen and how long it was
/// open, every tap and choice, every workout step with its timing, purchases, sign-ins and errors.
/// Properties are fixed keys with bounded values: ids, enum raw values, numbers and flags. Never a
/// name, a free-text answer or an email. Development runs stay out of the real data.
@MainActor enum Analytics {
  // MARK: Identity and context

  static let installID: UUID = {
    let key = "gymblock.installID"
    if let raw = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: raw) { return id }
    let id = UUID()
    UserDefaults.standard.set(id.uuidString, forKey: key)
    return id
  }()
  private(set) static var sessionID = UUID()
  private static var sessionStarted = Date()
  private static var backgroundedAt: Date?
  static var userID: UUID?
  static var enabled: Bool { !AppConfig.offline }

  static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  static let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
  static let osVersion = UIDevice.current.systemVersion
  static let deviceModel: String = {
    var system = utsname(); uname(&system)
    let mirror = Mirror(reflecting: system.machine)
    let id = mirror.children.reduce(into: "") { s, c in if let v = c.value as? Int8, v != 0 { s.append(Character(UnicodeScalar(UInt8(v)))) } }
    return id.isEmpty ? UIDevice.current.model : id
  }()
  static let locale = Locale.current.identifier
  static let timeZone = TimeZone.current.identifier

  // MARK: Queue

  private struct Row: Encodable {
    let id: UUID
    let install_id: UUID
    let session_id: UUID
    let user_id: UUID?
    let name: String
    let screen: String?
    let properties: [String: AnyJSON]
    let duration_ms: Int?
    let app_version: String
    let build: String
    let os_version: String
    let device_model: String
    let locale: String
    let occurred_at: Date
  }
  private static var pending: [Row] = []
  private static var flushTask: Task<Void, Never>?
  private static var screens: [(id: String, since: Date)] = []
  private static let limit = 500

  /// The screen the user is looking at (the last one entered and not yet left).
  static var currentScreen: String? { screens.last?.id }

  // MARK: Recording

  /// A product event. Values: String, Int, Double, Bool, or nil (dropped).
  static func track(_ name: String, _ properties: [String: Any?] = [:], screen: String? = nil, duration: Int? = nil) {
    guard enabled else { return }
    let row = Row(
      id: UUID(), install_id: installID, session_id: sessionID, user_id: userID,
      name: clean(name), screen: (screen ?? currentScreen).map(clean), properties: json(properties),
      duration_ms: duration.map { min(max($0, 0), 86_400_000) },
      app_version: appVersion, build: build, os_version: osVersion, device_model: deviceModel, locale: locale,
      occurred_at: Date())
    pending.append(row)
    if pending.count > limit { pending.removeFirst(pending.count - limit) }
    scheduleFlush(soon: pending.count >= 20)
  }

  /// A tap on a control, by its accessibility id.
  static func tap(_ id: String, _ properties: [String: Any?] = [:]) {
    guard !id.isEmpty else { return }
    var props = properties; props["id"] = id
    track("tap", props)
  }

  /// Entering a screen; `leave` closes it with how long it was open.
  static func enter(_ screen: String, _ properties: [String: Any?] = [:]) {
    guard enabled else { return }
    if screens.contains(where: { $0.id == screen }) { return }
    screens.append((screen, Date()))
    var props = properties; props["screen"] = screen
    track("screen", props, screen: screen)
  }
  static func leave(_ screen: String) {
    guard enabled, let index = screens.lastIndex(where: { $0.id == screen }) else { return }
    let since = screens[index].since
    screens.remove(at: index)
    track("screen_left", ["screen": screen], screen: screen, duration: Int(Date().timeIntervalSince(since) * 1000))
  }

  /// A failure worth knowing about. The message is the error's text, never the user's.
  static func error(_ domain: String, _ error: Error) {
    track("error", ["domain": domain, "message": String(error.localizedDescription.prefix(160))])
  }

  // MARK: Lifecycle

  static func launched() {
    guard enabled else { return }
    track("app_launched", ["reduce_motion": UIAccessibility.isReduceMotionEnabled])
    Task { await registerDevice() }
  }
  static func scene(_ phase: ScenePhase) {
    guard enabled else { return }
    switch phase {
    case .background:
      backgroundedAt = Date()
      track("app_backgrounded", duration: Int(Date().timeIntervalSince(sessionStarted) * 1000))
      Task { await flushNow() }
    case .active:
      if let away = backgroundedAt, Date().timeIntervalSince(away) > 30 * 60 {
        sessionID = UUID(); sessionStarted = Date()
        track("app_opened", ["after_minutes": Int(Date().timeIntervalSince(away) / 60)])
      } else if backgroundedAt != nil {
        track("app_foregrounded")
      }
      backgroundedAt = nil
    default: break
    }
  }

  /// Ties events to the account; nil on sign-out.
  static func identify(_ id: UUID?) {
    userID = id
    guard enabled else { return }
    Task { await registerDevice() }
  }

  private struct DeviceRow: Encodable {
    let install_id: UUID
    let user_id: UUID?
    let model: String
    let os_version: String
    let app_version: String
    let build: String
    let locale: String
    let time_zone: String
    let notifications: String?
    let reduce_motion: Bool
    let last_seen_at: Date
  }
  private static func registerDevice() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    let status: String? = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional ? "authorized"
      : settings.authorizationStatus == .denied ? "denied" : "not_determined"
    let row = DeviceRow(install_id: installID, user_id: userID, model: deviceModel, os_version: osVersion, app_version: appVersion,
                        build: build, locale: locale, time_zone: timeZone, notifications: status,
                        reduce_motion: UIAccessibility.isReduceMotionEnabled, last_seen_at: Date())
    do { try await Backend.supabase.from("gb_devices").upsert(row, onConflict: "install_id").execute() }
    catch { AppLog.error("Device register failed: \(error.localizedDescription)") }
  }

  // MARK: Flushing

  private static func scheduleFlush(soon: Bool) {
    if soon { flushTask?.cancel(); flushTask = nil; Task { await flushNow() }; return }
    guard flushTask == nil else { return }
    flushTask = Task {
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      flushTask = nil
      await flushNow()
    }
  }
  /// Sends what's queued. Failures keep the rows for the next flush (bounded).
  static func flushNow() async {
    guard enabled, !pending.isEmpty else { return }
    let batch = pending
    pending.removeAll()
    do {
      try await Backend.supabase.from("gb_events").insert(batch).execute()
    } catch {
      AppLog.error("Analytics flush failed: \(error.localizedDescription)")
      pending = Array((batch + pending).suffix(limit))
    }
  }

  // MARK: Helpers

  private static func clean(_ raw: String) -> String {
    let lowered = raw.lowercased().map { c -> Character in
      c.isLetter || c.isNumber || c == "_" || c == "." ? c : "_"
    }
    return String(String(lowered).prefix(64))
  }
  private static func json(_ properties: [String: Any?]) -> [String: AnyJSON] {
    var out: [String: AnyJSON] = [:]
    for (key, raw) in properties {
      guard let value = raw else { continue }
      let k = String(key.prefix(40))
      switch value {
      case let s as String: out[k] = .string(String(s.prefix(120)))
      case let b as Bool: out[k] = .bool(b)
      case let i as Int: out[k] = .integer(i)
      case let d as Double: out[k] = d.isFinite ? .double((d * 100).rounded() / 100) : .null
      case let u as UUID: out[k] = .string(u.uuidString.lowercased())
      case let date as Date: out[k] = .string(ISO8601DateFormatter().string(from: date))
      default: out[k] = .string(String(String(describing: value).prefix(120)))
      }
    }
    return out
  }
}

extension View {
  /// Records when this screen appears and how long it stayed open.
  func track(screen id: String, _ properties: [String: Any?] = [:]) -> some View {
    onAppear { Analytics.enter(id, properties) }.onDisappear { Analytics.leave(id) }
  }
}
