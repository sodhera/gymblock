import Foundation
import Supabase
import SwiftUI
import UIKit
import UserNotifications

/// GymBond (8 Nov 2026, docs/GYMBOND-PLAN.md): train with a friend. Every account has one invite
/// code; a friend who joins with it makes a bond, and both get two weeks of GymBlock Pro (the server
/// grants them through RevenueCat: `supabase/migrations/20261108000100_gymbond.sql`). Friends see
/// each other's first name, this week's days and finished workouts, and hear when the other finishes
/// a workout, is about to lose a streak, or nudges them. Everything goes through the server's
/// functions; the iPhone keeps a copy so Profile and Home draw it offline. Development runs have no
/// account and show nothing, unless `-bondPreview friends` seeds sample friends for screenshots.
@MainActor final class GymBond: ObservableObject {
  static let shared = GymBond()

  struct Friend: Identifiable, Codable, Equatable {
    var bondID: UUID
    var userID: UUID
    var name: String
    /// They invited you: you joined with their code.
    var invitedMe: Bool
    var since: Date
    /// When their finished workouts ended, over the last ten weeks.
    var workouts: [Date]
    var lastWorkoutName: String?
    var lastWorkoutAt: Date?
    /// When you last nudged them; one a day.
    var nudgedAt: Date?
    var giftDueAt: Date?
    var giftGrantedAt: Date?
    var id: UUID { bondID }
    var days: Set<Int> { Set(workouts.map { TrainingDays.key($0) }) }
    /// Their week, Monday first, with the app's own calendar.
    func week(at now: Date = Date()) -> [Bool] { TrainingDays.week(at: now, days: days).map { $0 == .trained } }
    func thisWeek(at now: Date = Date()) -> Int { TrainingDays.thisWeek(at: now, days: days) }
    func streak(at now: Date = Date()) -> Int {
      TrainingDays.streak(at: now, weeks: Set(workouts.map { TrainingDays.key(TrainingDays.monday(of: $0)) }))
    }
    func canNudge(at now: Date = Date()) -> Bool { nudgedAt.map { now.timeIntervalSince($0) >= 24 * 3600 } ?? true }
  }

  @Published private(set) var code: String?
  @Published private(set) var friends: [Friend] = []
  /// The server (or the cache) has answered for this account, so an empty list is real.
  @Published private(set) var loaded = false
  @Published private(set) var busy = false
  private var userID: UUID?
  private var refreshTask: Task<Void, Never>?
  /// Development only: sample friends on a phone with no account (`-bondPreview friends`).
  private(set) var preview = false
  private var client: SupabaseClient { Backend.supabase }
  private var cacheKey: String { "gymblock.bond.v1." + (userID?.uuidString.lowercased() ?? "") }
  private static let tokenKey = "gymblock.bond.apnsToken"
  private static let codec: (JSONEncoder, JSONDecoder) = {
    let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    return (e, d)
  }()
  /// Signed in and online: the only time anything here talks to the server.
  var live: Bool { userID != nil && !AppConfig.offline }

  // MARK: Rows

  private struct FriendRow: Decodable {
    var bond_id: UUID
    var friend_id: UUID
    var friend_name: String
    var invited_me: Bool
    var since: Date
    var workouts: [Date]
    var last_workout_name: String?
    var last_workout_at: Date?
    var nudged_at: Date?
    var gift_due_at: Date?
    var gift_granted_at: Date?
    var friend: Friend {
      Friend(bondID: bond_id, userID: friend_id, name: friend_name, invitedMe: invited_me, since: since, workouts: workouts,
             lastWorkoutName: last_workout_name, lastWorkoutAt: last_workout_at, nudgedAt: nudged_at,
             giftDueAt: gift_due_at, giftGrantedAt: gift_granted_at)
    }
  }
  private struct Redeemed: Decodable { var status: String; var name: String?; var bond_id: UUID?; var pro_now: Bool? }
  private struct Nudged: Decodable { var status: String }
  private struct Cache: Codable { var code: String?; var friends: [Friend] }

  // MARK: Account

  /// The signed-in user changed: show their cached bonds at once, then ask the server.
  func setUser(_ id: UUID?) {
    refreshTask?.cancel(); refreshTask = nil
    guard !preview else { return }
    userID = id
    loaded = false
    if id != nil, let data = UserDefaults.standard.data(forKey: cacheKey), let cache = try? Self.codec.1.decode(Cache.self, from: data) {
      code = cache.code; friends = cache.friends; loaded = true
    } else {
      code = nil; friends = []
    }
    guard live else { return }
    refreshTask = Task { [weak self] in await self?.refresh() }
  }
  private func writeCache() {
    guard userID != nil, !preview, let data = try? Self.codec.0.encode(Cache(code: code, friends: friends)) else { return }
    UserDefaults.standard.set(data, forKey: cacheKey)
  }

  /// The bonds as the server has them. Quiet when it can't be reached: the cache stands.
  func refresh() async {
    guard live, let uid = userID else { return }
    do {
      let rows: [FriendRow] = try await client.rpc("gb_bond_friends").execute().value
      guard uid == userID else { return }
      friends = rows.map(\.friend)
      loaded = true
      writeCache()
      await registerForPush()
    } catch {
      AppLog.error("GymBond refresh failed: \(error.localizedDescription)")
      Analytics.error("bond_refresh", error)
    }
  }

  /// The account's invite code, made the first time it's asked for.
  @discardableResult func fetchCode() async -> String? {
    if let code { return code }
    guard live else { return nil }
    do {
      let value: String = try await client.rpc("gb_bond_code").execute().value
      code = value
      writeCache()
      return value
    } catch {
      AppLog.error("GymBond code failed: \(error.localizedDescription)")
      Analytics.error("bond_code", error)
      return nil
    }
  }

  // MARK: Joining

  enum RedeemResult: Equatable {
    case bonded(name: String, proNow: Bool)
    case failed(String)
  }
  /// Joins with a friend's code. `t` translates the message that comes back.
  func redeem(_ raw: String, from source: String, t: (String) -> String) async -> RedeemResult {
    let clean = Self.normalize(raw)
    guard clean.count == 6 else { return .failed(t("Codes are six characters.")) }
    // No account yet: offline development runs can't have one; online, the silent account wasn't made
    // (the caller tries again first), so it reads as a connection problem, which it usually is.
    guard live else { return .failed(t(AppConfig.offline ? "Sign in to use a code." : "Couldn’t reach your account. Check your connection and try again.")) }
    guard !busy else { return .failed(t("One moment…")) }
    busy = true; defer { busy = false }
    do {
      let r: Redeemed = try await client.rpc("gb_bond_redeem", params: ["p_code": clean]).execute().value
      Analytics.track("bond_redeem", ["status": r.status, "where": source, "pro_now": r.pro_now])
      switch r.status {
      case "bonded":
        await refresh()
        return .bonded(name: r.name ?? t("your friend"), proNow: r.pro_now ?? false)
      case "own_code": return .failed(t("That’s your own code."))
      case "already_bonded": return .failed(String(format: t("You’re already bonded with %@."), r.name ?? t("them")))
      case "limit": return .failed(t("Five friends is the most for now."))
      default: return .failed(t("That code wasn’t found."))
      }
    } catch {
      AppLog.error("GymBond redeem failed: \(error.localizedDescription)")
      Analytics.error("bond_redeem", error)
      return .failed(t("Couldn’t check the code. Check your connection and try again."))
    }
  }
  /// Upper case, letters and digits only, read as spoken (a 0 is an O, a 1 an I), six at most.
  nonisolated static func normalize(_ raw: String) -> String {
    String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.map { $0 == "0" ? "O" : $0 == "1" ? "I" : $0 }.prefix(6))
  }

  /// A nudge: a push to them, one a day. False when it couldn't be sent (or it's too soon).
  func nudge(_ friend: Friend) async -> Bool {
    guard live else { return false }
    do {
      let r: Nudged = try await client.rpc("gb_bond_nudge", params: ["p_bond": friend.bondID]).execute().value
      Analytics.track("bond_nudge", ["status": r.status])
      guard r.status == "sent" else { return false }
      if let i = friends.firstIndex(where: { $0.id == friend.id }) { friends[i].nudgedAt = Date(); writeCache() }
      return true
    } catch {
      AppLog.error("GymBond nudge failed: \(error.localizedDescription)")
      Analytics.error("bond_nudge", error)
      return false
    }
  }

  /// Ends the bond for both sides; the two weeks of Pro stay.
  func end(_ friend: Friend) async {
    guard live else { return }
    do {
      try await client.rpc("gb_bond_end", params: ["p_bond": friend.bondID]).execute()
      friends.removeAll { $0.id == friend.id }
      writeCache()
      Analytics.track("bond_ended")
    } catch {
      AppLog.error("GymBond end failed: \(error.localizedDescription)")
      Analytics.error("bond_end", error)
    }
  }

  /// What the share sheet sends: the gift, the code, the App Store.
  func shareText(spanish: Bool) -> String? {
    guard let code else { return nil }
    return spanish
      ? "Te regalo dos semanas de GymBlock Pro. Usa mi código \(code) al registrarte. \(AppConfig.appStoreURL.absoluteString)"
      : "I’m gifting you two weeks of GymBlock Pro. Use my code \(code) when you sign up. \(AppConfig.appStoreURL.absoluteString)"
  }

  // MARK: Push

  /// Asks iOS for a push token whenever the account is signed in and notifications are allowed
  /// (since 8 Nov 2026, at the user's request: not only with a bond, so a message can reach one
  /// account from the server, `gb_notify`). The token comes back through `PushDelegate` and is kept
  /// on this install's device row.
  func registerForPush() async {
    guard live, RestAlert.granted(await RestAlert.status()) else { return }
    UIApplication.shared.registerForRemoteNotifications()
  }
  /// A Debug build registers with APNs' sandbox; the server picks the host from this.
  static var environment: String {
    #if DEBUG
      return "development"
    #else
      return "production"
    #endif
  }
  func saveToken(_ token: String) {
    guard live, let uid = userID else { return }
    guard UserDefaults.standard.string(forKey: Self.tokenKey) != token + "|" + uid.uuidString else { return }
    Task {
      do {
        let params: [String: AnyJSON] = ["p_install": .string(Analytics.installID.uuidString.lowercased()), "p_token": .string(token), "p_environment": .string(Self.environment)]
        try await client.rpc("gb_set_push_token", params: params).execute()
        UserDefaults.standard.set(token + "|" + uid.uuidString, forKey: Self.tokenKey)
        Analytics.track("bond_push_token", ["saved": true])
      } catch {
        AppLog.error("GymBond token save failed: \(error.localizedDescription)")
        Analytics.error("bond_push_token", error)
      }
    }
  }
  /// Before Log out, while still signed in: this iPhone stops receiving the bonds' pushes.
  func forgetToken() async {
    guard live, userID != nil, UserDefaults.standard.string(forKey: Self.tokenKey) != nil else { return }
    let params: [String: AnyJSON] = ["p_install": .string(Analytics.installID.uuidString.lowercased()), "p_token": .null, "p_environment": .null]
    do { try await client.rpc("gb_set_push_token", params: params).execute() }
    catch { AppLog.error("GymBond token clear failed: \(error.localizedDescription)") }
    UserDefaults.standard.removeObject(forKey: Self.tokenKey)
  }

  // MARK: Development

  #if DEBUG
    /// `-bondPreview friends` (or `empty`): sample bonds on a phone with no account, for screenshots.
    /// Never on a device with an account, never saved.
    func loadPreview(_ kind: String) {
      preview = true
      loaded = true
      code = "7KD4QX"
      guard kind == "friends" else { friends = []; return }
      let c = TrainingDays.calendar
      let monday = TrainingDays.monday(of: Date())
      func at(_ weeksBack: Int, _ weekday: Int, hour: Int = 18) -> Date {
        c.date(byAdding: .hour, value: hour, to: c.date(byAdding: .day, value: weekday - 7 * weeksBack, to: monday) ?? monday) ?? monday
      }
      // Sirish: Monday and Wednesday this week, three days a week for five weeks (a 6-week streak).
      let sirish = (0..<6).flatMap { w in w == 0 ? [at(0, 0), at(0, 2)] : [at(w, 0), at(w, 2), at(w, 4)] }.filter { $0 <= Date() }
      // Manjil: nothing yet this week, four days last week and the week before.
      let manjil = (1..<3).flatMap { w in [at(w, 0), at(w, 1), at(w, 3), at(w, 5)] }
      friends = [
        Friend(bondID: UUID(), userID: UUID(), name: "Sirish", invitedMe: false, since: at(5, 0), workouts: sirish,
               lastWorkoutName: "Push", lastWorkoutAt: sirish.last, nudgedAt: nil, giftDueAt: at(5, 0), giftGrantedAt: at(5, 0)),
        Friend(bondID: UUID(), userID: UUID(), name: "Manjil", invitedMe: true, since: at(2, 0), workouts: manjil,
               lastWorkoutName: "Legs", lastWorkoutAt: manjil.last, nudgedAt: Date().addingTimeInterval(-3600), giftDueAt: at(2, 0), giftGrantedAt: nil),
      ]
    }
  #endif
}

/// Receives the push token iOS issues after `registerForRemoteNotifications` (GymBond asks for it
/// only while there's a bond). Nothing else lands here: rest alerts stay local notifications.
final class PushDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    Task { @MainActor in GymBond.shared.saveToken(token) }
  }
  func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    AppLog.error("Push registration failed: \(error.localizedDescription)")
  }
}
