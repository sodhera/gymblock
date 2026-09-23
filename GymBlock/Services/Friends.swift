import Foundation
import Supabase

// Friends and cloud sync over Supabase PostgREST. Schema and privacy rules
// live in supabase/migrations/001_init.sql; RLS enforces them server-side, so
// this client never has to be trusted to hide anything.
//
// What friends see: your week (days trained), streak, consistency and PRs
// always; the contents of a workout (exercises, sets, notes) only when you
// marked that workout shared.

struct PublicProfile: Codable, Identifiable, Hashable {
    var id: UUID
    var username: String
    var displayName: String
    var weeklyTarget: Int

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case weeklyTarget = "weekly_target"
    }

    var name: String { displayName.isEmpty ? "@\(username)" : displayName }
    var initials: String {
        let parts = name.replacingOccurrences(of: "@", with: "").split(separator: " ")
        return parts.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

struct Friendship: Codable, Hashable {
    var requester: UUID
    var addressee: UUID
    var status: String
}

struct WorkoutSummaryRow: Codable, Identifiable, Hashable {
    var id: UUID
    var userID: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date
    var setCount: Int
    var volumeKg: Double
    var counts: Bool
    var isShared: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, counts
        case userID = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case setCount = "set_count"
        case volumeKg = "volume_kg"
        case isShared = "is_shared"
    }

    /// Lets friends' rows flow through the same `Streak` math as your own.
    var asWorkout: Workout {
        var w = Workout(title: title, start: startedAt)
        w.id = id
        w.end = endedAt
        // `counts` is decided by the owner's client; mirror it with a synthetic
        // set list of the right size so `Workout.counts` agrees.
        let sets = counts ? max(setCount, Workout.minimumSetsToCount) : 0
        w.exercises = [ExerciseLog(exerciseID: "summary", sets: Array(repeating: SetEntry(isDone: true), count: sets))]
        return w
    }
}

struct RecordRow: Codable, Hashable {
    var userID: UUID
    var exerciseID: String
    var exerciseName: String
    var weightKg: Double
    var reps: Int
    var e1rmKg: Double
    var achievedAt: Date

    enum CodingKeys: String, CodingKey {
        case reps
        case userID = "user_id"
        case exerciseID = "exercise_id"
        case exerciseName = "exercise_name"
        case weightKg = "weight_kg"
        case e1rmKg = "e1rm_kg"
        case achievedAt = "achieved_at"
    }
}

struct WorkoutDetailRow: Codable {
    var workoutID: UUID
    var userID: UUID
    var exercises: [ExerciseLog]
    var note: String

    enum CodingKeys: String, CodingKey {
        case exercises, note
        case workoutID = "workout_id"
        case userID = "user_id"
    }
}

/// A friend with everything the Friends tab draws.
struct FriendCard: Identifiable, Hashable {
    var profile: PublicProfile
    var workouts: [WorkoutSummaryRow]
    var records: [RecordRow]
    var id: UUID { profile.id }

    var week: WeekProgress {
        Streak.week(containing: .now, workouts: workouts.map(\.asWorkout), target: profile.weeklyTarget)
    }
    var streak: Int { Streak.weeks(workouts: workouts.map(\.asWorkout), target: profile.weeklyTarget) }
    var consistency: Double? { Streak.consistency(workouts: workouts.map(\.asWorkout), target: profile.weeklyTarget) }
    var lastWorkout: WorkoutSummaryRow? { workouts.max { $0.startedAt < $1.startedAt } }
}

struct FriendsSnapshot: Equatable {
    var friends: [FriendCard] = []
    var incoming: [PublicProfile] = []
    var outgoing: [PublicProfile] = []
}

enum FriendsError: LocalizedError {
    case notConfigured, notSignedIn, userNotFound, alreadyFriends, isYou, usernameTaken, invalidUsername, network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Friends need an account. Not set up in this build."
        case .notSignedIn: "Sign in to add friends."
        case .userNotFound: "No one with that username."
        case .alreadyFriends: "You're already connected."
        case .isYou: "That's you."
        case .usernameTaken: "That username's taken."
        case .invalidUsername: "3–20 letters, numbers or underscores."
        case .network(let m): m
        }
    }
}

protocol FriendsProviding {
    var isConfigured: Bool { get }
    func myProfile() async -> PublicProfile?
    func claimUsername(_ username: String, displayName: String, weeklyTarget: Int) async throws -> PublicProfile
    func updateProfile(displayName: String, weeklyTarget: Int) async
    func isUsernameAvailable(_ username: String) async -> Bool
    func snapshot() async throws -> FriendsSnapshot
    func sendRequest(toUsername username: String) async throws -> PublicProfile
    func accept(_ requester: UUID) async throws
    func remove(_ other: UUID) async throws
    func nudge(_ friend: UUID) async throws
    func sharedDetail(for workoutID: UUID) async -> WorkoutDetailRow?
    func upload(_ workout: Workout, records: [PersonalRecord]) async
    func deleteWorkout(_ id: UUID) async
}

enum Usernames {
    static func isValid(_ s: String) -> Bool {
        s.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    static func sanitize(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }.prefix(20))
            .applyingTransform(.stripDiacritics, reverse: false) ?? ""
    }
}

enum FriendsService {
    static func makeDefault() -> FriendsProviding {
        guard let client = SupabaseConfig.client else { return DisabledFriends() }
        return SupabaseFriends(client: client)
    }
}

struct DisabledFriends: FriendsProviding {
    var isConfigured: Bool { false }
    func myProfile() async -> PublicProfile? { nil }
    func claimUsername(_ username: String, displayName: String, weeklyTarget: Int) async throws -> PublicProfile { throw FriendsError.notConfigured }
    func updateProfile(displayName: String, weeklyTarget: Int) async {}
    func isUsernameAvailable(_ username: String) async -> Bool { true }
    func snapshot() async throws -> FriendsSnapshot { throw FriendsError.notConfigured }
    func sendRequest(toUsername username: String) async throws -> PublicProfile { throw FriendsError.notConfigured }
    func accept(_ requester: UUID) async throws { throw FriendsError.notConfigured }
    func remove(_ other: UUID) async throws { throw FriendsError.notConfigured }
    func nudge(_ friend: UUID) async throws { throw FriendsError.notConfigured }
    func sharedDetail(for workoutID: UUID) async -> WorkoutDetailRow? { nil }
    func upload(_ workout: Workout, records: [PersonalRecord]) async {}
    func deleteWorkout(_ id: UUID) async {}
}

final class SupabaseFriends: FriendsProviding {
    private let client: SupabaseClient

    init(client: SupabaseClient) { self.client = client }

    var isConfigured: Bool { true }

    private var me: UUID? { client.auth.currentSession?.user.id }

    func myProfile() async -> PublicProfile? {
        guard let me else { return nil }
        return try? await client.from("profiles").select().eq("id", value: me).single().execute().value
    }

    func isUsernameAvailable(_ username: String) async -> Bool {
        let rows: [PublicProfile] = (try? await client.from("profiles").select().eq("username", value: username).execute().value) ?? []
        return rows.isEmpty || rows.first?.id == me
    }

    func claimUsername(_ username: String, displayName: String, weeklyTarget: Int) async throws -> PublicProfile {
        guard let me else { throw FriendsError.notSignedIn }
        guard Usernames.isValid(username) else { throw FriendsError.invalidUsername }
        guard await isUsernameAvailable(username) else { throw FriendsError.usernameTaken }
        let row = PublicProfile(id: me, username: username, displayName: displayName, weeklyTarget: weeklyTarget)
        do {
            return try await client.from("profiles").upsert(row).select().single().execute().value
        } catch {
            throw FriendsError.network(error.localizedDescription)
        }
    }

    func updateProfile(displayName: String, weeklyTarget: Int) async {
        guard let me else { return }
        struct Patch: Encodable { var display_name: String; var weekly_target: Int }
        _ = try? await client.from("profiles")
            .update(Patch(display_name: displayName, weekly_target: weeklyTarget))
            .eq("id", value: me).execute()
    }

    func snapshot() async throws -> FriendsSnapshot {
        guard let me else { throw FriendsError.notSignedIn }
        do {
            let links: [Friendship] = try await client.from("friendships").select().execute().value
            let otherIDs = links.map { $0.requester == me ? $0.addressee : $0.requester }
            guard !otherIDs.isEmpty else { return FriendsSnapshot() }

            let profiles: [PublicProfile] = try await client.from("profiles").select()
                .in("id", values: otherIDs.map(\.uuidString)).execute().value
            let byID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            let accepted = links.filter { $0.status == "accepted" }.map { $0.requester == me ? $0.addressee : $0.requester }
            let incoming = links.filter { $0.status == "pending" && $0.addressee == me }.compactMap { byID[$0.requester] }
            let outgoing = links.filter { $0.status == "pending" && $0.requester == me }.compactMap { byID[$0.addressee] }

            var cards: [FriendCard] = []
            if !accepted.isEmpty {
                // Enough history for a 12-week consistency figure plus a streak.
                let since = Calendar.current.date(byAdding: .day, value: -26 * 7, to: .now)!
                let ids = accepted.map(\.uuidString)
                let workouts: [WorkoutSummaryRow] = try await client.from("workouts").select()
                    .in("user_id", values: ids)
                    .gte("started_at", value: since.ISO8601Format())
                    .order("started_at", ascending: false)
                    .execute().value
                let records: [RecordRow] = try await client.from("personal_records").select()
                    .in("user_id", values: ids)
                    .order("achieved_at", ascending: false)
                    .execute().value
                cards = accepted.compactMap { id in
                    guard let profile = byID[id] else { return nil }
                    return FriendCard(
                        profile: profile,
                        workouts: workouts.filter { $0.userID == id },
                        records: records.filter { $0.userID == id }
                    )
                }
            }
            return FriendsSnapshot(
                friends: cards.sorted { $0.week.count > $1.week.count || ($0.week.count == $1.week.count && $0.profile.name < $1.profile.name) },
                incoming: incoming,
                outgoing: outgoing
            )
        } catch let error as FriendsError {
            throw error
        } catch {
            throw FriendsError.network("Couldn't load friends. Pull to try again.")
        }
    }

    func sendRequest(toUsername username: String) async throws -> PublicProfile {
        guard let me else { throw FriendsError.notSignedIn }
        let clean = Usernames.sanitize(username)
        let rows: [PublicProfile] = (try? await client.from("profiles").select().eq("username", value: clean).execute().value) ?? []
        guard let other = rows.first else { throw FriendsError.userNotFound }
        guard other.id != me else { throw FriendsError.isYou }
        struct Insert: Encodable { var requester: UUID; var addressee: UUID; var status = "pending" }
        do {
            try await client.from("friendships").insert(Insert(requester: me, addressee: other.id)).execute()
        } catch {
            // The pair index rejects duplicates in either direction.
            throw FriendsError.alreadyFriends
        }
        return other
    }

    func accept(_ requester: UUID) async throws {
        guard let me else { throw FriendsError.notSignedIn }
        struct Patch: Encodable { var status = "accepted" }
        try await client.from("friendships").update(Patch())
            .eq("requester", value: requester).eq("addressee", value: me).execute()
    }

    func remove(_ other: UUID) async throws {
        guard let me else { throw FriendsError.notSignedIn }
        try await client.from("friendships").delete()
            .or("and(requester.eq.\(me),addressee.eq.\(other)),and(requester.eq.\(other),addressee.eq.\(me))")
            .execute()
    }

    func nudge(_ friend: UUID) async throws {
        guard let me else { throw FriendsError.notSignedIn }
        struct Insert: Encodable { var sender: UUID; var recipient: UUID }
        try await client.from("nudges").insert(Insert(sender: me, recipient: friend)).execute()
    }

    func sharedDetail(for workoutID: UUID) async -> WorkoutDetailRow? {
        try? await client.from("workout_details").select().eq("workout_id", value: workoutID).single().execute().value
    }

    func upload(_ workout: Workout, records: [PersonalRecord]) async {
        guard let me, let end = workout.end else { return }
        let summary = WorkoutSummaryRow(
            id: workout.id, userID: me, title: String(workout.title.prefix(60)), startedAt: workout.start, endedAt: end,
            setCount: workout.completedSetCount, volumeKg: workout.volume, counts: workout.counts, isShared: workout.isShared
        )
        do {
            try await client.from("workouts").upsert(summary).execute()
            let detail = WorkoutDetailRow(workoutID: workout.id, userID: me, exercises: workout.exercises, note: workout.note)
            try await client.from("workout_details").upsert(detail).execute()
            if !records.isEmpty {
                let rows = records.map {
                    RecordRow(
                        userID: me, exerciseID: $0.exerciseID,
                        exerciseName: ExerciseLibrary.shared.exercise($0.exerciseID)?.displayName ?? $0.exerciseID,
                        weightKg: $0.weight, reps: $0.reps, e1rmKg: $0.estimatedOneRepMax, achievedAt: $0.date
                    )
                }
                try await client.from("personal_records").upsert(rows).execute()
            }
        } catch {
            AppLog.cloud.error("Workout upload failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func deleteWorkout(_ id: UUID) async {
        _ = try? await client.from("workouts").delete().eq("id", value: id).execute()
    }
}
