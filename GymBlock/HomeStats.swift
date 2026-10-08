import Foundation

/// The numbers Home keeps score with. Each one is a measurement of logged workouts, tied to one
/// of the three promises: show up (consistency), rest on time, and get stronger like for like.
struct HomeStats {
  /// Days trained, newest week last: `grid[week][weekday]`, Monday first.
  let grid: [[Bool]]
  let weekStarts: [Date]
  let streakWeeks: Int
  let thisWeek: Int
  let goal: Int
  /// Share of measured rests that ended within the rest length (plus a 30-second grace), over 28 days.
  let restsOnTime: Double?
  let averageRest: Double?
  let restCount: Int
  /// Exercises beaten like for like (same split, reps or load held constant) in the last 28 days.
  let liftsUp: Int
  let workoutsInWindow: Int
  let totalWorkouts: Int
  let totalVolumeKG: Double
  /// Monday = 0.
  let todayIndex: Int
  /// Minutes of finished workouts, all time.
  let totalMinutes: Int
  /// The most recent like-for-like gain, if any.
  let lastPR: (date: Date, exercise: Exercise, splitID: UUID?, text: String)?
}

extension GymStore {
  func homeStats(weeks: Int = 12, now: Date = Date()) -> HomeStats {
    let calendar = Calendar.current
    let goal = min(7, max(1, profile.baseline?.trainingDays ?? 5))
    let finished = data.history.filter { !$0.completedSets.isEmpty }
    let trainedDays = Set(finished.map { calendar.startOfDay(for: $0.started) })

    // Consistency grid, Monday-first weeks ending with this week.
    var monday = calendar
    monday.firstWeekday = 2
    let thisWeekStart = monday.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    var weekStarts: [Date] = []
    var grid: [[Bool]] = []
    for offset in stride(from: weeks - 1, through: 0, by: -1) {
      guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) else { continue }
      weekStarts.append(start)
      grid.append((0..<7).map { day in
        guard let date = calendar.date(byAdding: .day, value: day, to: start) else { return false }
        return trainedDays.contains(calendar.startOfDay(for: date))
      })
    }
    let thisWeek = grid.last?.filter { $0 }.count ?? 0

    // Streak: consecutive weeks with at least one workout, counting back; this week joins once it has one.
    var streak = 0
    for (index, week) in grid.enumerated().reversed() {
      let days = week.filter { $0 }.count
      let isCurrent = index == grid.count - 1
      if days >= 1 { streak += 1 } else if isCurrent { continue } else { break }
    }

    // Rests on time, last 28 days.
    let since = calendar.date(byAdding: .day, value: -28, to: now) ?? now
    let recent = finished.filter { $0.started >= since }
    var gaps: [Double] = []
    for session in recent {
      for set in session.sets where set.completed {
        if let gap = session.gapSeconds(before: set), !session.gapCrossesExercises(before: set) { gaps.append(gap) }
      }
    }
    let grace = 30.0
    let onTime = gaps.isEmpty ? nil : Double(gaps.filter { $0 <= Double(restTarget) + grace }.count) / Double(gaps.count)
    let average = gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count)

    // Lifts beaten like for like in the window.
    let lifts = recent.reduce(0) { $0 + improvements(in: $1).count }

    let todayIndex = (calendar.component(.weekday, from: now) + 5) % 7
    let totalMinutes = Int(finished.reduce(0.0) { $0 + $1.duration } / 60)
    var lastPR: (date: Date, exercise: Exercise, splitID: UUID?, text: String)?
    for session in finished.sorted(by: { $0.started > $1.started }) {
      if let gain = improvements(in: session).first {
        let text = gain.weightGainKG.map { "+" + formatNumber(GymStore.displayedWeight($0, unit: profile.unit)) + " " + profile.unit } ?? "+\(gain.repGain ?? 0) " + t("reps")
        lastPR = (session.ended ?? session.started, gain.exercise, session.splitID, text); break
      }
    }
    return HomeStats(grid: grid, weekStarts: weekStarts, streakWeeks: streak, thisWeek: thisWeek, goal: goal,
                     restsOnTime: onTime, averageRest: average, restCount: gaps.count, liftsUp: lifts, workoutsInWindow: recent.count,
                     totalWorkouts: finished.count, totalVolumeKG: finished.reduce(0) { $0 + $1.volumeKG }, todayIndex: todayIndex,
                     totalMinutes: totalMinutes, lastPR: lastPR)
  }
}

/// One exercise's improvement: its best comparable set per workout, reps or load held constant.
struct ExerciseTrend: Identifiable {
  var id: String { exercise.id + "-" + (splitName ?? "free") }
  let exercise: Exercise
  let splitID: UUID?
  let splitName: String?
  /// True: reps at a fixed weight. False: weight at a fixed rep count.
  let repMode: Bool
  let constant: String
  let points: [(date: Date, value: Double)]
  var gain: Double { (points.last?.value ?? 0) - (points.first?.value ?? 0) }
}

extension GymStore {
  /// Every exercise with two or more comparable workouts, the biggest gains first.
  func exerciseTrends(limit: Int = 6) -> [ExerciseTrend] {
    var trends: [ExerciseTrend] = []
    let groups = Dictionary(grouping: data.history.filter { !$0.completedSets.isEmpty }) { $0.splitID }
    for (splitID, sessions) in groups {
      let ordered = sessions.sorted { $0.started < $1.started }
      var seen = Set<String>()
      let exercises = ordered.flatMap(\.sets).map(\.exercise).filter { !$0.timed && seen.insert($0.id).inserted }
      let splitName = data.workouts.first { $0.id == splitID }?.name ?? ordered.last?.name
      for exercise in exercises {
        guard let latest = ordered.reversed().lazy.compactMap({ s in s.sets.last { $0.exercise.id == exercise.id && $0.comparable } }).first else { continue }
        func series(repMode: Bool) -> [(Date, Double)] {
          ordered.compactMap { session in
            let sets = session.sets.filter {
              $0.exercise.id == exercise.id && $0.comparable && (repMode ? abs($0.weightKG - latest.weightKG) < 0.001 : $0.reps == latest.reps)
            }
            guard let best = sets.max(by: { repMode ? $0.reps < $1.reps : $0.weightKG < $1.weightKG }) else { return nil }
            return (session.ended ?? session.started, repMode ? Double(best.reps) : GymStore.displayedWeight(best.weightKG, unit: profile.unit))
          }
        }
        let byWeight = series(repMode: false), byReps = series(repMode: true)
        let repMode = byWeight.count < 2 && byReps.count >= 2
        let points = repMode ? byReps : byWeight
        guard points.count >= 2 else { continue }
        let constant = repMode ? "\(t("at")) \(formatNumber(GymStore.displayedWeight(latest.weightKG, unit: profile.unit))) \(profile.unit)" : "\(t("at")) \(latest.reps) \(t("reps"))"
        trends.append(ExerciseTrend(exercise: exercise, splitID: splitID, splitName: splitID == nil ? nil : splitName, repMode: repMode, constant: constant,
                                    points: points.map { (date: $0.0, value: $0.1) }))
      }
    }
    return Array(trends.sorted { $0.gain > $1.gain }.prefix(limit))
  }

  /// A labelled example for a brand-new log, so Home never opens empty. Cleared by the first workout.
  static func exampleStats(goal: Int, now: Date = Date()) -> HomeStats {
    let calendar = Calendar.current
    var grid: [[Bool]] = []; var starts: [Date] = []
    let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    for offset in stride(from: 11, through: 0, by: -1) {
      let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek) ?? now
      starts.append(start)
      grid.append(offset == 0 ? [true, false, true, false, false, false, false] : [true, false, true, false, true, false, false])
    }
    return HomeStats(grid: grid, weekStarts: starts, streakWeeks: 5, thisWeek: 2, goal: goal, restsOnTime: 0.82, averageRest: 95, restCount: 60,
                     liftsUp: 9, workoutsInWindow: 12, totalWorkouts: 34, totalVolumeKG: 41_000, todayIndex: (calendar.component(.weekday, from: now) + 5) % 7,
                     totalMinutes: 34 * 42, lastPR: (calendar.date(byAdding: .day, value: -3, to: now) ?? now, Exercise.catalog.first { $0.id == "bench" } ?? Exercise.catalog[0], nil, "+5 kg"))
  }
  static func exampleTrends(unit: String, now: Date = Date()) -> [ExerciseTrend] {
    let lookup = Dictionary(uniqueKeysWithValues: Exercise.catalog.map { ($0.id, $0) })
    func make(_ id: String, _ values: [Double], reps: Int) -> ExerciseTrend? {
      guard let exercise = lookup[id] else { return nil }
      let points = values.enumerated().map { i, v in
        (date: Calendar.current.date(byAdding: .day, value: -7 * (values.count - 1 - i), to: now) ?? now,
         value: GymStore.displayedWeight(v, unit: unit).rounded())
      }
      return ExerciseTrend(exercise: exercise, splitID: nil, splitName: nil, repMode: false, constant: "at \(reps) reps", points: points)
    }
    return [make("bench", [60, 60, 62.5, 65, 65, 70], reps: 5), make("squat", [80, 85, 85, 90, 95, 100], reps: 5), make("curl", [12.5, 12.5, 15, 15, 15, 17.5], reps: 10)].compactMap { $0 }
  }
}
