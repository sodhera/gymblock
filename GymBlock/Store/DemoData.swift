#if DEBUG
import Foundation

/// Plausible training history for Simulator screenshots and design review.
/// Only reachable through the `-demo-history` launch argument in Debug builds;
/// the shipping app never shows data the user didn't log.
enum DemoData {
    static func history(templates: [WorkoutTemplate], weeks: Int = 10, now: Date = .now) -> [Workout] {
        let cal = TrainingCalendar.calendar
        let plan = templates.isEmpty ? StarterTemplates.templates(forDaysPerWeek: 5) : templates
        var workouts: [Workout] = []
        var rng = SeededGenerator(seed: 38)
        let thisWeek = TrainingCalendar.startOfWeek(for: now)
        var planIndex = 0

        for weekOffset in stride(from: weeks, through: 0, by: -1) {
            guard let weekStart = cal.date(byAdding: .weekOfYear, value: -weekOffset, to: thisWeek) else { continue }
            let dayOffsets: [Int] = weekOffset == 0 ? [0, 2, 3] : [0, 1, 3, 4, 5].filter { _ in Int.random(in: 0..<10, using: &rng) < 9 }
            for day in dayOffsets {
                guard let date = cal.date(byAdding: .day, value: day, to: weekStart),
                      let start = cal.date(bySettingHour: 7 + Int.random(in: 0...11, using: &rng), minute: 10, second: 0, of: date),
                      start < now
                else { continue }
                let template = plan[planIndex % plan.count]
                planIndex += 1
                let progress = Double(weeks - weekOffset) / Double(max(weeks, 1))
                var workout = Workout(title: template.name, templateID: template.id, start: start, isShared: true)
                workout.exercises = template.exercises.map { item in
                    let base = baseWeight(item.exerciseID)
                    let sets = (0..<item.sets).map { _ in
                        SetEntry(
                            weight: base.map { ($0 * (0.9 + 0.15 * progress) / 2.5).rounded() * 2.5 },
                            reps: item.reps ?? 10,
                            seconds: item.reps == 0 ? 60 : nil,
                            isDone: true
                        )
                    }
                    return ExerciseLog(exerciseID: item.exerciseID, sets: sets, restSeconds: item.restSeconds)
                }
                workout.end = start.addingTimeInterval(TimeInterval(55 * 60 + Int.random(in: 0...1500, using: &rng)))
                workouts.append(workout)
            }
        }
        return workouts
    }

    private static func baseWeight(_ id: String) -> Double? {
        switch id {
        case "bench-press-bb": 80
        case "squat-bb": 110
        case "deadlift-bb": 140
        case "ohp-bb": 50
        case "bent-over-row-bb": 70
        case "rdl-bb": 100
        case "incline-bench-db": 30
        case "shoulder-press-db": 26
        case "lateral-raise-db": 10
        case "curl-db": 14
        case "leg-press": 180
        case "lat-pulldown-cable", "seated-row-cable": 65
        case "triceps-rope-pushdown", "triceps-pushdown": 30
        case "face-pull": 25
        case "lying-leg-curl": 45
        case "standing-calf-raise": 80
        case "bulgarian-split-squat", "lunge-db": 22
        case "pull-up", "hanging-leg-raise", "plank": nil
        default: 40
        }
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
#endif
