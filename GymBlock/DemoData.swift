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
            session.sets.append(
              LoggedSet(
                exercise: exercise, weightKG: weight, reps: heavy ? 5 : 10, minutes: 0,
                date: date.addingTimeInterval(Double(setIndex + 1) * 180)))
          }
        }
        data.history.append(session)
      }
    }
    data.history.sort { $0.started > $1.started }
    data.demoLoaded = true
    persist()
    return true
  }
}
