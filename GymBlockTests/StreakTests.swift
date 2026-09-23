import XCTest
@testable import GymBlock

/// The weekly streak is the product's core promise; these pin its rules.
final class StreakTests: XCTestCase {
    private let cal = TrainingCalendar.calendar

    /// A Wednesday, so "this week" has days on both sides.
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 12))! }

    private func workout(daysAgo: Int, sets: Int = 5) -> Workout {
        let start = cal.date(byAdding: .day, value: -daysAgo, to: now)!
        var w = Workout(title: "Test", start: start)
        w.end = start.addingTimeInterval(3600)
        w.exercises = [ExerciseLog(exerciseID: "bench-press-bb", sets: (0..<sets).map { _ in SetEntry(weight: 60, reps: 8, isDone: true) })]
        return w
    }

    /// Workouts on specific weekdays (0 = Monday) `weeksAgo` weeks back.
    private func week(_ weeksAgo: Int, days: [Int]) -> [Workout] {
        let monday = TrainingCalendar.startOfWeek(for: now)
        return days.map { day in
            let date = cal.date(byAdding: .day, value: day - 7 * weeksAgo, to: monday)!
            let offset = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day!
            return workout(daysAgo: offset)
        }
    }

    func testEmptyHistoryHasNoStreak() {
        XCTAssertEqual(Streak.weeks(workouts: [], target: 3, now: now), 0)
    }

    func testCompletedWeeksCount() {
        let history = week(1, days: [0, 2, 4]) + week(2, days: [0, 1, 2]) + week(3, days: [1, 3, 5])
        XCTAssertEqual(Streak.weeks(workouts: history, target: 3, now: now), 3)
    }

    func testUnfinishedCurrentWeekDoesNotBreakStreak() {
        let history = week(0, days: [0]) + week(1, days: [0, 2, 4]) + week(2, days: [0, 2, 4])
        XCTAssertEqual(Streak.weeks(workouts: history, target: 3, now: now), 2)
    }

    func testCompletedCurrentWeekAddsToStreak() {
        let history = week(0, days: [0, 1, 2]) + week(1, days: [0, 2, 4])
        XCTAssertEqual(Streak.weeks(workouts: history, target: 3, now: now), 2)
    }

    func testMissedWeekBreaksStreak() {
        let history = week(1, days: [0, 2, 4]) + week(2, days: [0]) + week(3, days: [0, 2, 4])
        XCTAssertEqual(Streak.weeks(workouts: history, target: 3, now: now), 1)
    }

    func testTwoWorkoutsSameDayCountOnce() {
        let monday = week(1, days: [0, 0, 0])
        XCTAssertEqual(Streak.weeks(workouts: monday, target: 2, now: now), 0)
    }

    func testAbandonedWorkoutDoesNotCount() {
        let thin = [workout(daysAgo: 0, sets: 1)]
        XCTAssertEqual(Streak.week(containing: now, workouts: thin, target: 1).count, 0)
    }

    func testWeekStripMarksTrainedDays() {
        let progress = Streak.week(containing: now, workouts: week(0, days: [0, 2]), target: 4)
        XCTAssertEqual(progress.trained, [0, 2])
        XCTAssertEqual(progress.remaining, 2)
    }

    func testEpleyPrefersMoreRepsAtSimilarWeight() {
        let a = SetEntry(weight: 100, reps: 5, isDone: true)
        let b = SetEntry(weight: 105, reps: 1, isDone: true)
        XCTAssertGreaterThan(a.estimatedOneRepMax!, b.estimatedOneRepMax!)
    }

    func testWarmupsDoNotCountTowardVolumeOrRecords() {
        let warm = SetEntry(kind: .warmup, weight: 200, reps: 5, isDone: true)
        XCTAssertEqual(warm.volume, 0)
        XCTAssertNil(warm.estimatedOneRepMax)
    }

    func testFirstEverSetIsNotAPR() {
        let set = SetEntry(weight: 100, reps: 5, isDone: true)
        XCTAssertFalse(Records.isRecord(set, exerciseID: "bench-press-bb", previous: [:]))
    }

    func testPhoneMath() {
        var d = OnboardingDraft()
        d.daysPerWeek = 4
        d.sessionMinutes = 60
        d.phoneMinutes = 15
        XCTAssertEqual(PhoneMath.yearlyHours(d), 52)
        XCTAssertEqual(PhoneMath.sessionsLost(d), 52)
    }

    func testCatalogIDsAreUnique() {
        XCTAssertEqual(Set(ExerciseCatalog.all.map(\.id)).count, ExerciseCatalog.all.count)
    }

    func testStarterTemplatesOnlyReferenceRealExercises() {
        for days in 2...6 {
            for t in StarterTemplates.templates(forDaysPerWeek: days) {
                for item in t.exercises {
                    XCTAssertNotNil(ExerciseCatalog.byID[item.exerciseID], "\(item.exerciseID) missing")
                }
            }
        }
    }
}
