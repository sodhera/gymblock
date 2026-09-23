import Foundation
import ManagedSettings

// State shared between the app and its Screen Time extensions through the app
// group. The extensions run in their own sandboxed processes and cannot see
// the app's store, so the app mirrors the few facts the shield needs here
// every time the workout changes. Compiled into all four targets.

nonisolated enum SharedWorkoutState {
    static let appGroup = "group.com.sulav.gymblock"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    private enum Key {
        static let isActive = "workout.isActive"
        static let title = "workout.title"
        static let start = "workout.start"
        static let remainingSets = "workout.remainingSets"
        static let currentExercise = "workout.currentExercise"
        static let currentExerciseSetsLeft = "workout.currentExerciseSetsLeft"
        static let reachCount = "workout.reachCount"
        static let lastReach = "workout.lastReach"
    }

    struct Snapshot {
        var title: String
        var start: Date
        var remainingSets: Int
        var currentExercise: String?
        var currentExerciseSetsLeft: Int
        var reachCount: Int
    }

    static func publish(
        title: String, start: Date, remainingSets: Int, currentExercise: String?, currentExerciseSetsLeft: Int
    ) {
        let d = defaults
        if !d.bool(forKey: Key.isActive) {
            d.set(0, forKey: Key.reachCount)
        }
        d.set(true, forKey: Key.isActive)
        d.set(title, forKey: Key.title)
        d.set(start.timeIntervalSince1970, forKey: Key.start)
        d.set(remainingSets, forKey: Key.remainingSets)
        d.set(currentExercise, forKey: Key.currentExercise)
        d.set(currentExerciseSetsLeft, forKey: Key.currentExerciseSetsLeft)
    }

    static func clear() {
        let d = defaults
        d.set(false, forKey: Key.isActive)
        for key in [Key.title, Key.start, Key.remainingSets, Key.currentExercise, Key.currentExerciseSetsLeft] {
            d.removeObject(forKey: key)
        }
    }

    static func current() -> Snapshot? {
        let d = defaults
        guard d.bool(forKey: Key.isActive) else { return nil }
        return Snapshot(
            title: d.string(forKey: Key.title) ?? "Workout",
            start: Date(timeIntervalSince1970: d.double(forKey: Key.start)),
            remainingSets: d.integer(forKey: Key.remainingSets),
            currentExercise: d.string(forKey: Key.currentExercise),
            currentExerciseSetsLeft: d.integer(forKey: Key.currentExerciseSetsLeft),
            reachCount: d.integer(forKey: Key.reachCount)
        )
    }

    /// Counts reaches for a blocked app during this workout. Debounced: the
    /// system may ask the shield for its configuration more than once per open.
    @discardableResult
    static func recordReach(now: Date = .now) -> Int {
        let d = defaults
        let last = d.double(forKey: Key.lastReach)
        var count = d.integer(forKey: Key.reachCount)
        if now.timeIntervalSince1970 - last > 3 {
            count += 1
            d.set(count, forKey: Key.reachCount)
            d.set(now.timeIntervalSince1970, forKey: Key.lastReach)
        }
        return count
    }

    static var reachCount: Int { defaults.integer(forKey: Key.reachCount) }
}

nonisolated extension ManagedSettingsStore.Name {
    /// The one named store GymBlock writes shields into. Clearing it lifts
    /// everything GymBlock applied without touching other apps' restrictions.
    static let gymblock = Self("com.sulav.gymblock.workout")
}

nonisolated enum SharedSchedule {
    /// DeviceActivity name for the safety cap: if a workout is somehow never
    /// finished (crash, dead phone, forgotten), the monitor extension lifts the
    /// block when this interval ends so nobody's phone stays locked overnight.
    static let safetyActivity = "com.sulav.gymblock.safety"
    static let safetyCapHours = 4
}
