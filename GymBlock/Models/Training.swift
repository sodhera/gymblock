import Foundation

// Derived numbers: the week strip, the streak, PRs, "last time". Pure
// functions over `[Workout]` so they are trivially testable and never drift
// between surfaces (Today, Profile, friends, the shield all read these).

// MARK: - Calendar

enum TrainingCalendar {
    /// Weeks run Monday → Sunday everywhere in the app, regardless of locale:
    /// "training week" is a gym convention, and friends in different locales
    /// must agree on what "this week" means.
    static var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    static func startOfWeek(for date: Date, calendar: Calendar = calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func weekDays(containing date: Date, calendar: Calendar = calendar) -> [Date] {
        let start = startOfWeek(for: date, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func weekNumber(_ date: Date, calendar: Calendar = calendar) -> Int {
        calendar.component(.weekOfYear, from: date)
    }
}

// MARK: - Week & streak

struct WeekProgress: Equatable {
    /// Monday…Sunday of this week.
    var days: [Date]
    /// Which of `days` have a counting workout.
    var trained: Set<Int>
    var target: Int

    var count: Int { trained.count }
    var isComplete: Bool { count >= target }
    var remaining: Int { max(0, target - count) }
}

enum Streak {
    /// Unique training days (start-of-day) from counting workouts.
    static func trainingDays(_ workouts: [Workout], calendar: Calendar = TrainingCalendar.calendar) -> Set<Date> {
        Set(workouts.filter(\.counts).map { calendar.startOfDay(for: $0.start) })
    }

    static func week(
        containing date: Date, workouts: [Workout], target: Int,
        calendar: Calendar = TrainingCalendar.calendar
    ) -> WeekProgress {
        let days = TrainingCalendar.weekDays(containing: date, calendar: calendar)
        let trainedDays = trainingDays(workouts, calendar: calendar)
        let trained = Set(days.indices.filter { trainedDays.contains(calendar.startOfDay(for: days[$0])) })
        return WeekProgress(days: days, trained: trained, target: target)
    }

    /// Consecutive weeks that hit the target. The current week adds to the
    /// streak once it's complete, but an unfinished current week never breaks
    /// it — you still have days left. Rest days can't break a weekly streak;
    /// that's the whole point of counting weeks.
    ///
    /// `target` is applied to every week (a target change re-scores history,
    /// deliberately: the streak answers "am I doing what I said I'd do").
    static func weeks(
        workouts: [Workout], target: Int, now: Date = .now,
        calendar: Calendar = TrainingCalendar.calendar
    ) -> Int {
        let target = max(1, target)
        let days = trainingDays(workouts, calendar: calendar)
        guard !days.isEmpty else { return 0 }

        var countsByWeek: [Date: Int] = [:]
        for day in days {
            countsByWeek[TrainingCalendar.startOfWeek(for: day, calendar: calendar), default: 0] += 1
        }

        let thisWeek = TrainingCalendar.startOfWeek(for: now, calendar: calendar)
        var streak = (countsByWeek[thisWeek] ?? 0) >= target ? 1 : 0
        var cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek)!
        while (countsByWeek[cursor] ?? 0) >= target {
            streak += 1
            cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)!
        }
        return streak
    }

    /// Share of the last `weeks` completed weeks (excluding this one) that hit
    /// the target — the "consistency" number friends see. Nil with no history.
    static func consistency(
        workouts: [Workout], target: Int, weeks: Int = 12, now: Date = .now,
        calendar: Calendar = TrainingCalendar.calendar
    ) -> Double? {
        let days = trainingDays(workouts, calendar: calendar)
        guard let first = days.min() else { return nil }
        let thisWeek = TrainingCalendar.startOfWeek(for: now, calendar: calendar)
        let firstWeek = TrainingCalendar.startOfWeek(for: first, calendar: calendar)
        var hit = 0
        var total = 0
        for offset in 1...weeks {
            guard let week = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  week >= firstWeek else { break }
            total += 1
            let count = days.filter { TrainingCalendar.startOfWeek(for: $0, calendar: calendar) == week }.count
            if count >= target { hit += 1 }
        }
        guard total > 0 else { return nil }
        return Double(hit) / Double(total)
    }
}

// MARK: - Records

struct PersonalRecord: Identifiable, Hashable, Codable {
    var exerciseID: String
    var weight: Double
    var reps: Int
    var estimatedOneRepMax: Double
    var date: Date
    var id: String { exerciseID }
}

enum Records {
    /// Best set (by estimated 1RM) per exercise across all finished workouts.
    static func best(_ workouts: [Workout]) -> [String: PersonalRecord] {
        var best: [String: PersonalRecord] = [:]
        for workout in workouts where workout.end != nil {
            for log in workout.exercises {
                for set in log.sets where set.isDone {
                    guard let e1rm = set.estimatedOneRepMax, let weight = set.weight, let reps = set.reps else { continue }
                    if e1rm > (best[log.exerciseID]?.estimatedOneRepMax ?? 0) {
                        best[log.exerciseID] = PersonalRecord(
                            exerciseID: log.exerciseID, weight: weight, reps: reps,
                            estimatedOneRepMax: e1rm, date: workout.start
                        )
                    }
                }
            }
        }
        return best
    }

    /// True when `set` beats every previous finished workout's best for this
    /// exercise. Requires some history — a first-ever set isn't a "PR", it's
    /// a baseline, and celebrating every lift on day one cheapens the moment.
    static func isRecord(_ set: SetEntry, exerciseID: String, previous: [String: PersonalRecord]) -> Bool {
        guard set.isDone, let e1rm = set.estimatedOneRepMax, let prior = previous[exerciseID] else { return false }
        return e1rm > prior.estimatedOneRepMax + 0.01
    }

    /// The sets logged for this exercise in the most recent finished workout
    /// that included it — the "Previous" column.
    static func previousSets(for exerciseID: String, in workouts: [Workout], excluding id: UUID? = nil) -> [SetEntry] {
        let finished = workouts
            .filter { $0.end != nil && $0.id != id }
            .sorted { $0.start > $1.start }
        for workout in finished {
            if let log = workout.exercises.first(where: { $0.exerciseID == exerciseID }), !log.completedSets.isEmpty {
                return log.completedSets
            }
        }
        return []
    }
}

// MARK: - Starter templates

enum StarterTemplates {
    /// A sensible split for the chosen days per week, created during
    /// onboarding so Today has something to start on day one. Users edit or
    /// delete them like any template.
    static func templates(forDaysPerWeek days: Int) -> [WorkoutTemplate] {
        switch days {
        case ...3: return [fullBodyA, fullBodyB]
        case 4: return [upper, lower]
        default: return [push, pull, legs]
        }
    }

    static func splitName(forDaysPerWeek days: Int) -> String {
        switch days {
        case ...3: "Full body"
        case 4: "Upper / Lower"
        default: "Push / Pull / Legs"
        }
    }

    private static func t(_ name: String, _ items: [(String, Int, Int)]) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            exercises: items.map { TemplateExercise(exerciseID: $0.0, sets: $0.1, reps: $0.2, restSeconds: $0.1 >= 4 ? 150 : 90) }
        )
    }

    static let push = t("Push", [
        ("bench-press-bb", 4, 6), ("incline-bench-db", 3, 10), ("shoulder-press-db", 3, 10),
        ("lateral-raise-db", 3, 15), ("triceps-rope-pushdown", 3, 12),
    ])
    static let pull = t("Pull", [
        ("deadlift-bb", 3, 5), ("pull-up", 3, 8), ("seated-row-cable", 3, 10),
        ("face-pull", 3, 15), ("curl-db", 3, 12),
    ])
    static let legs = t("Legs", [
        ("squat-bb", 4, 6), ("rdl-bb", 3, 8), ("leg-press", 3, 12),
        ("lying-leg-curl", 3, 12), ("standing-calf-raise", 3, 15),
    ])
    static let upper = t("Upper", [
        ("bench-press-bb", 4, 6), ("bent-over-row-bb", 4, 8), ("shoulder-press-db", 3, 10),
        ("lat-pulldown-cable", 3, 10), ("curl-db", 2, 12), ("triceps-pushdown", 2, 12),
    ])
    static let lower = t("Lower", [
        ("squat-bb", 4, 6), ("rdl-bb", 3, 8), ("bulgarian-split-squat", 3, 10),
        ("lying-leg-curl", 3, 12), ("standing-calf-raise", 3, 15), ("hanging-leg-raise", 3, 12),
    ])
    static let fullBodyA = t("Full Body A", [
        ("squat-bb", 3, 6), ("bench-press-bb", 3, 6), ("bent-over-row-bb", 3, 8),
        ("lateral-raise-db", 2, 15), ("plank", 2, 0),
    ])
    static let fullBodyB = t("Full Body B", [
        ("deadlift-bb", 3, 5), ("ohp-bb", 3, 8), ("lat-pulldown-cable", 3, 10),
        ("lunge-db", 2, 10), ("curl-db", 2, 12),
    ])
}
