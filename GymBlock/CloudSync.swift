import CryptoKit
import Foundation
import RevenueCat
import Supabase

/// Keeps the account's data in Supabase: profile, splits, every workout and set, and the
/// subscription snapshot. The iPhone copy stays the working copy; every save schedules a push of
/// whatever changed (fingerprints per row, so unchanged rows never travel), and signing in pulls
/// the account's data and merges it by id before the first push.
@MainActor final class CloudSync {
  static let shared = CloudSync()
  private weak var store: GymStore?
  private(set) var userID: UUID?
  private var pushTask: Task<Void, Never>?
  private var pullTask: Task<Void, Never>?
  private var pushing = false
  private var dirty = false
  /// Fingerprints of the rows the server has, per entity key, kept per account.
  private var known: [String: String] = [:]
  private var knownKey: String { "gymblock.sync.v1." + (userID?.uuidString ?? "") }
  private var client: SupabaseClient { Backend.supabase }
  private static let fingerprinter: JSONEncoder = {
    let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; e.dateEncodingStrategy = .iso8601; return e
  }()

  func attach(_ store: GymStore) {
    self.store = store
    store.onPersist = { [weak self] in self?.schedulePush() }
  }

  /// The signed-in user changed: forget the old fingerprints, pull the new account, then push.
  func setUser(_ id: UUID?) {
    pushTask?.cancel(); pushTask = nil
    pullTask?.cancel()
    userID = id
    known = id == nil ? [:] : (UserDefaults.standard.dictionary(forKey: knownKey) as? [String: String] ?? [:])
    guard id != nil, !AppConfig.offline else { return }
    pullTask = Task { [weak self] in
      await self?.pull()
      await self?.push()
    }
  }
  /// Waits for the sign-in pull, so callers can see whether the account was already onboarded.
  func awaitPull() async { await pullTask?.value }

  // MARK: Rows

  struct ProfileRow: Codable {
    var id: UUID
    var name: String
    var language: String
    var gender: String?
    var height_cm: Double?
    var body_weight_kg: Double?
    var unit: String
    var rest_seconds: Int?
    var rest_alerts: Bool?
    var time_sets: Bool?
    var haptics_enabled: Bool?
    var sound_enabled: Bool?
    var focus_enabled: Bool?
    var block_whole_phone: Bool
    var blocked_apps: [String]
    var preferred_split_id: UUID?
    var onboarded: Bool
    var onboarding_step: String?
    var onboarding_version: Int?
    var pledged: Bool
    var baseline: RoutineBaseline?

    init(_ p: Profile, id: UUID) {
      self.id = id; name = p.name; language = p.language.isEmpty ? "en" : p.language; gender = p.gender
      height_cm = p.heightCM; body_weight_kg = p.bodyWeightKG; unit = p.unit; rest_seconds = p.restSeconds
      rest_alerts = p.restAlerts; time_sets = p.timeSets; haptics_enabled = p.hapticsEnabled; sound_enabled = p.soundEnabled
      focus_enabled = p.focusEnabled; block_whole_phone = p.blockWholePhone; blocked_apps = p.blockedApps
      preferred_split_id = p.preferredSplitID; onboarded = p.onboarded; onboarding_step = p.onboardingStepID
      onboarding_version = p.onboardingVersion; pledged = (p.onboardingStoryStage ?? 0) > 0 || p.onboarded; baseline = p.baseline
    }
    func applied(to local: Profile) -> Profile {
      var p = local
      p.name = name; p.language = language; p.gender = gender; p.heightCM = height_cm; p.bodyWeightKG = body_weight_kg
      p.unit = unit; p.restSeconds = rest_seconds; p.restAlerts = rest_alerts; p.timeSets = time_sets
      p.hapticsEnabled = haptics_enabled; p.soundEnabled = sound_enabled; p.focusEnabled = focus_enabled
      p.blockWholePhone = block_whole_phone; p.blockedApps = blocked_apps; p.preferredSplitID = preferred_split_id
      p.onboarded = onboarded; p.onboardingVersion = onboarding_version; p.baseline = baseline
      if onboarded { p.onboardingStepID = OnboardingStep.splits.rawValue }
      return p
    }
  }
  struct SplitRow: Codable {
    var id: UUID
    var user_id: UUID
    var name: String
    var exercises: [Exercise]
    var position: Int
  }
  struct WorkoutRow: Codable {
    var id: UUID
    var user_id: UUID
    var split_id: UUID?
    var name: String
    var started_at: Date
    var ended_at: Date?
    var paused_seconds: Double
    var duration_seconds: Double?
    var exercises: [Exercise]
    var set_count: Int
    var total_reps: Int
    var volume_kg: Double
    var state: Session?
    var deleted_at: Date?

    init(_ s: Session, user: UUID) {
      id = s.id; user_id = user; split_id = s.splitID; name = String(s.name.prefix(60)); started_at = s.started; ended_at = s.ended
      paused_seconds = s.pausedSeconds ?? 0; duration_seconds = s.ended.map { s.duration(at: $0) }; exercises = s.exercises
      set_count = s.completedSets.count; total_reps = s.totalReps; volume_kg = s.volumeKG
      state = s.ended == nil ? s : nil; deleted_at = nil
    }
    var session: Session? {
      if ended_at == nil { return state }
      var s = Session()
      s.id = id; s.started = started_at; s.ended = ended_at; s.name = name; s.exercises = exercises; s.splitID = split_id
      s.stage = .rest; s.pausedSeconds = paused_seconds > 0 ? paused_seconds : nil
      return s
    }
  }
  struct SetRow: Codable {
    var id: UUID
    var user_id: UUID
    var workout_id: UUID
    var position: Int
    var exercise_id: String
    var exercise_name: String
    var exercise_area: String
    var timed: Bool
    var weight_kg: Double
    var reps: Int
    var minutes: Double
    var logged_at: Date
    var warmup: Bool
    var unsuccessful: Bool
    var timing_unknown: Bool
    var set_seconds: Double?
    var gap_before_seconds: Double?
    var gap_source_id: UUID?
    var gap_unknown: Bool

    init(_ set: LoggedSet, workout: UUID, user: UUID, position: Int) {
      id = set.id; user_id = user; workout_id = workout; self.position = position
      exercise_id = String(set.exercise.id.prefix(64)); exercise_name = String(set.exercise.name.prefix(80))
      exercise_area = String(set.exercise.area.prefix(40)); timed = set.exercise.timed
      weight_kg = set.weightKG; reps = min(999, max(0, set.reps)); minutes = set.minutes; logged_at = set.date
      warmup = set.warmup == true; unsuccessful = set.unsuccessful == true; timing_unknown = set.timingUnknown == true
      set_seconds = set.elapsedSetSeconds; gap_before_seconds = set.gapBeforeSeconds; gap_source_id = set.gapSourceID
      gap_unknown = set.gapUnknown == true
    }
    var loggedSet: LoggedSet {
      LoggedSet(id: id, exercise: Exercise(id: exercise_id, name: exercise_name, area: exercise_area, timed: timed),
                weightKG: weight_kg, reps: reps, minutes: minutes, date: logged_at,
                unsuccessful: unsuccessful ? true : nil, warmup: warmup ? true : nil, timingUnknown: timing_unknown ? true : nil,
                elapsedSetSeconds: set_seconds, gapBeforeSeconds: gap_before_seconds, gapSourceID: gap_source_id,
                gapUnknown: gap_unknown ? true : nil)
    }
  }
  struct SubscriptionRow: Encodable {
    var user_id: UUID
    var entitled: Bool
    var product_id: String?
    var will_renew: Bool?
    var expires_at: Date?
    var original_purchase_at: Date?
    var store: String?
  }

  // MARK: Pull

  private struct Tombstone: Encodable { var deleted_at: Date }

  func pull() async {
    guard let store, let uid = userID else { return }
    do {
      let profiles: [ProfileRow] = try await client.from("gb_profiles").select().eq("id", value: uid).execute().value
      let splits: [SplitRow] = try await client.from("gb_splits").select("id, user_id, name, exercises, position")
        .eq("user_id", value: uid).filter("deleted_at", operator: "is", value: "null").order("position").execute().value
      let workouts: [WorkoutRow] = try await client.from("gb_workouts").select()
        .eq("user_id", value: uid).filter("deleted_at", operator: "is", value: "null").order("started_at", ascending: false).execute().value
      let sets: [SetRow] = try await client.from("gb_sets").select().eq("user_id", value: uid).order("position").execute().value
      merge(profile: profiles.first, splits: splits, workouts: workouts, sets: sets, into: store)
      Analytics.track("sync_pulled", ["splits": splits.count, "workouts": workouts.count, "sets": sets.count])
    } catch {
      AppLog.error("Sync pull failed: \(error.localizedDescription)")
      Analytics.error("sync_pull", error)
    }
  }

  private func merge(profile: ProfileRow?, splits: [SplitRow], workouts: [WorkoutRow], sets: [SetRow], into store: GymStore) {
    var data = store.data
    let fresh = data.history.isEmpty && data.workouts.isEmpty && data.session == nil && !data.profile.onboarded
    var next = known
    // Splits: the account's splits join the local ones; a fresh install takes the account's order.
    let localSplits = Set(data.workouts.map(\.id))
    for row in splits where !localSplits.contains(row.id) {
      data.workouts.append(Workout(id: row.id, name: row.name, exercises: row.exercises))
      next["split:" + row.id.uuidString] = fingerprint(row)
    }
    if fresh { data.workouts = splits.map { Workout(id: $0.id, name: $0.name, exercises: $0.exercises) } }
    // Workouts and their sets.
    let bySession = Dictionary(grouping: sets, by: \.workout_id)
    var localWorkouts = Set(data.history.map(\.id))
    if let id = data.session?.id { localWorkouts.insert(id) }
    for row in workouts where !localWorkouts.contains(row.id) {
      guard var session = row.session else { continue }
      if row.ended_at == nil {
        // A workout still running on another iPhone comes back here if nothing is running locally.
        guard data.session == nil else { continue }
        data.session = session
      } else {
        session.sets = (bySession[row.id] ?? []).sorted { $0.position < $1.position }.map(\.loggedSet)
        data.history.append(session)
      }
      next["workout:" + row.id.uuidString] = fingerprint(row, sets: bySession[row.id] ?? [])
    }
    data.history.sort { $0.started > $1.started }
    // Profile: the account's answers win on a fresh install, or when the account finished onboarding and this phone hasn't.
    if let profile, fresh || (profile.onboarded && !data.profile.onboarded) {
      data.profile = profile.applied(to: data.profile)
      next["profile"] = fingerprint(profile)
    }
    known = next
    store.data = data
    store.persist()
  }

  // MARK: Push

  func schedulePush() {
    guard userID != nil, !AppConfig.offline else { return }
    dirty = true
    guard pushTask == nil else { return }
    pushTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(1500))
      self?.pushTask = nil
      await self?.push()
    }
  }

  func push() async {
    guard let store, let uid = userID, !AppConfig.offline else { return }
    guard !pushing else { dirty = true; return }
    pushing = true; dirty = false
    defer { pushing = false; if dirty { schedulePush() } }
    let data = store.data
    var next = known
    var sent = 0
    do {
      let profile = ProfileRow(data.profile, id: uid)
      if try await upsert("gb_profiles", profile, key: "profile", known: &next) { sent += 1 }

      let splitIDs = Set(data.workouts.map(\.id))
      for (index, workout) in data.workouts.enumerated() {
        let row = SplitRow(id: workout.id, user_id: uid, name: workout.name, exercises: workout.exercises, position: index)
        if try await upsert("gb_splits", row, key: "split:" + workout.id.uuidString, known: &next) { sent += 1 }
      }
      for key in next.keys where key.hasPrefix("split:") {
        guard let id = UUID(uuidString: String(key.dropFirst(6))), !splitIDs.contains(id) else { continue }
        try await client.from("gb_splits").update(Tombstone(deleted_at: Date())).eq("id", value: id).execute()
        next.removeValue(forKey: key); sent += 1
      }

      let sessions = data.history + [data.session].compactMap { $0 }
      let workoutIDs = Set(sessions.map(\.id))
      for session in sessions {
        let row = WorkoutRow(session, user: uid)
        let setRows = session.sets.enumerated().map { SetRow($0.element, workout: session.id, user: uid, position: $0.offset) }
        let key = "workout:" + session.id.uuidString
        let print = fingerprint(row, sets: setRows)
        guard next[key] != print else { continue }
        try await client.from("gb_workouts").upsert(row).execute()
        if !setRows.isEmpty { try await client.from("gb_sets").upsert(setRows).execute() }
        let keep = setRows.map { $0.id.uuidString.lowercased() }
        var remove = client.from("gb_sets").delete().eq("workout_id", value: session.id)
        if !keep.isEmpty { remove = remove.not("id", operator: .in, value: "(" + keep.joined(separator: ",") + ")") }
        try await remove.execute()
        next[key] = print; sent += 1
      }
      for key in next.keys where key.hasPrefix("workout:") {
        guard let id = UUID(uuidString: String(key.dropFirst(8))), !workoutIDs.contains(id) else { continue }
        try await client.from("gb_workouts").update(Tombstone(deleted_at: Date())).eq("id", value: id).execute()
        next.removeValue(forKey: key); sent += 1
      }
      known = next
      UserDefaults.standard.set(known, forKey: knownKey)
      if sent > 0 { Analytics.track("sync_pushed", ["rows": sent]) }
    } catch {
      known = next
      UserDefaults.standard.set(known, forKey: knownKey)
      dirty = true
      AppLog.error("Sync push failed: \(error.localizedDescription)")
      Analytics.error("sync_push", error)
    }
  }

  /// The entitlement as RevenueCat reports it, so the account carries its own subscription history.
  func snapshot(_ info: CustomerInfo) {
    guard let uid = userID, !AppConfig.offline else { return }
    let entitlement = info.entitlements[AppConfig.entitlement]
    let row = SubscriptionRow(user_id: uid, entitled: entitlement?.isActive == true, product_id: entitlement?.productIdentifier,
                              will_renew: entitlement?.willRenew, expires_at: entitlement?.expirationDate,
                              original_purchase_at: entitlement?.originalPurchaseDate, store: entitlement.map { "\($0.store)" })
    Task {
      do { try await client.from("gb_subscriptions").upsert(row).execute() }
      catch { AppLog.error("Subscription snapshot failed: \(error.localizedDescription)") }
    }
  }

  // MARK: Helpers

  private func upsert<Row: Encodable>(_ table: String, _ row: Row, key: String, known: inout [String: String]) async throws -> Bool {
    let print = fingerprint(row)
    guard known[key] != print else { return false }
    try await client.from(table).upsert(row).execute()
    known[key] = print
    return true
  }
  private func fingerprint<Row: Encodable>(_ row: Row, sets: [SetRow] = []) -> String {
    var data = (try? Self.fingerprinter.encode(row)) ?? Data()
    if !sets.isEmpty { data.append((try? Self.fingerprinter.encode(sets)) ?? Data()) }
    return SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
  }
}
