import Foundation

extension GymStore {
  /// Explicit, repeat-safe demo loading. Preserve saved workouts and supplied routine answers.
  @discardableResult func loadDemoIfEmpty(now: Date = Date()) -> Bool {
    guard data.history.isEmpty, data.workouts.isEmpty, data.session == nil, data.demoLoaded != true
    else { return false }
    let lookup = Dictionary(uniqueKeysWithValues: Exercise.catalog.map { ($0.id, $0) })
    let arms = Workout(
      name: "Arms", exercises: ["curl", "hammer", "triceps"].compactMap { lookup[$0] })
    let push = Workout(
      name: "Push", exercises: ["bench", "dumbbell-press", "lateral"].compactMap { lookup[$0] })
    let legs = Workout(
      name: "Legs", exercises: ["squat", "deadlift", "lunge"].compactMap { lookup[$0] })
    data.workouts = [arms, push, legs]
    if !profile.onboarded {
      if data.profile.language.isEmpty { data.profile.language = "en" }
      if data.profile.name.isEmpty { data.profile.name = "Alex" }
      data.profile.onboarded = true
      data.profile.onboardingStep = 5
      data.profile.training = ["Weightlifting", "Cardio"]
      data.profile.favorites = ["curl", "bench", "squat"]
    }
    let calendar = Calendar.current
    let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
    let base: [String: Double] = [
      "curl": 15, "hammer": 12.5, "triceps": 17.5, "bench": 60, "dumbbell-press": 15, "lateral": 5,
      "squat": 80, "deadlift": 90, "lunge": 12.5,
    ]
    for week in 0..<6 {
      for (day, split) in [(1, arms), (3, push), (5, legs)] {
        guard
          let dayDate = calendar.date(byAdding: .day, value: -7 * (5 - week) + day, to: weekStart),
          dayDate <= now
        else { continue }
        let date = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: dayDate)!
        guard date.addingTimeInterval(35 * 60) <= now else { continue }
        var session = Session()
        session.name = split.name
        session.splitID = split.id
        session.started = date
        session.ended = date.addingTimeInterval(35 * 60)
        session.exercises = split.exercises
        session.stage = .rest
        for exercise in split.exercises {
          let heavy = ["bench", "squat", "deadlift"].contains(exercise.id)
          let weight = (base[exercise.id] ?? 10) + Double(week) * (heavy ? 5 : 1)
          for setIndex in 0..<3 {
            let elapsed = Double(35 + setIndex * 5)
            let previous = session.sets.last
            session.sets.append(
              LoggedSet(
                exercise: exercise, weightKG: weight, reps: heavy ? 5 : 10, minutes: 0,
                date: date.addingTimeInterval(Double(session.sets.count + 1) * 180),
                elapsedSetSeconds: elapsed,
                gapBeforeSeconds: previous == nil ? nil : 180 - elapsed,
                gapSourceID: previous?.id))
          }
        }
        data.history.append(session)
      }
    }
    data.history.sort { $0.started > $1.started }
    // Splits rotate: the one after the most recent sample workout is up next.
    if let last = data.history.first?.splitID, let i = data.workouts.firstIndex(where: { $0.id == last }) {
      data.profile.preferredSplitID = data.workouts[(i + 1) % data.workouts.count].id
    }
    data.demoLoaded = true
    persist()
    return true
  }
}

#if DEBUG
extension GymStore {
  /// Puts a sample split workout into one state for screenshots: ready, active, rest, restUp,
  /// next (target reached), stale or summary. Debug builds only.
  func debugWorkout(_ stage: String) {
    loadDemoIfEmpty()
    updateProfile { $0.onboarded = true; $0.name = $0.name.isEmpty ? "Sirish" : $0.name; $0.focusEnabled = true }
    guard session == nil, let split = data.workouts.first(where: { $0.id == profile.preferredSplitID }) ?? data.workouts.first else { return }
    startSession(workout: split)
    data.session?.started = Date().addingTimeInterval(-14 * 60)
    func logOne(ago: TimeInterval) {
      let unit = profile.unit
      startSet(weight: Self.displayedWeight(session?.weightKG ?? 0, unit: unit), unit: unit)
      data.session?.setStarted = Date().addingTimeInterval(-ago - 38)
      finishSet(reps: draftRepCount ?? 8, minutes: 0)
      data.session?.restStarted = Date().addingTimeInterval(-ago)
      if let i = data.session?.sets.indices.last { data.session?.sets[i].date = Date().addingTimeInterval(-ago) }
    }
    switch stage {
    case "active":
      logOne(ago: 150)
      startSet(weight: Self.displayedWeight(session?.weightKG ?? 0, unit: profile.unit), unit: profile.unit)
      data.session?.setStarted = Date().addingTimeInterval(-24)
    case "rest": logOne(ago: 41)
    case "restUp": logOne(ago: 104)
    case "next": logOne(ago: 400); logOne(ago: 250); logOne(ago: 70)
    case "stale":
      data.session?.started = Date().addingTimeInterval(-2.5 * 3600)
      logOne(ago: 2 * 3600)
    case "summary":
      logOne(ago: 400); logOne(ago: 250); logOne(ago: 70)
      // Realistic measured rests between the sample sets.
      for (i, gap) in [(1, 96.0), (2, 108.0)] { data.session?.sets[i].gapBeforeSeconds = gap }
      finish()
    default: break
    }
    persist()
  }
}
#endif
