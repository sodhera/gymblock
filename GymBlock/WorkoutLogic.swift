import Foundation

/// The rules behind the workout screen: what comes next, how values step, and what happens
/// when a workout is interrupted or left running.
extension GymStore {
  /// A workout with no activity for this long is treated as left running.
  static let staleAfter: TimeInterval = 60 * 60
  static let restChoices = [30, 45, 60, 90, 120, 150, 180, 240, 300]

  var restTarget: Int { profile.restSeconds ?? 90 }
  /// Start set → Finish set (true), or one tap logs a set (false).
  var timesSets: Bool { profile.timeSets ?? true }

  func setRestTarget(_ seconds: Int) {
    guard (10...900).contains(seconds) else { return }
    updateProfile { $0.restSeconds = seconds }
  }

  /// Completed working sets of `exercise` in the current workout. Warm-ups and missed attempts don't count.
  func doneSets(_ exercise: Exercise?) -> Int {
    guard let exercise, let session else { return 0 }
    return session.sets.filter { $0.exercise.id == exercise.id && $0.completed && $0.warmup != true }.count
  }

  /// How many sets you did of this exercise last time; three when there's no history.
  func targetSets(_ exercise: Exercise?) -> Int {
    guard let exercise else { return 3 }
    let last = data.history.filter { $0.id != session?.id }
      .sorted { ($0.ended ?? $0.started) > ($1.ended ?? $1.started) }
      .lazy.map { $0.sets.filter { $0.exercise.id == exercise.id && $0.completed && $0.warmup != true }.count }
      .first { $0 > 0 }
    return min(10, max(1, last ?? profile.baseline?.sets ?? 3))
  }

  /// The next exercise in this workout's order that still has sets to do, wrapping around.
  var nextExercise: Exercise? {
    guard let session, let current = session.selected,
      let i = session.exercises.firstIndex(where: { $0.id == current.id })
    else { return nil }
    let order = session.exercises[(i + 1)...] + session.exercises[..<i]
    return order.first { doneSets($0) < targetSets($0) }
  }

  /// Every exercise of a split has reached its target.
  var splitComplete: Bool {
    guard let session, session.splitID != nil, !session.exercises.isEmpty else { return false }
    return session.exercises.allSatisfy { doneSets($0) >= targetSets($0) }
  }

  /// The best set of this exercise from the most recent earlier workout, for "Last time".
  func previousBest(_ exercise: Exercise) -> (set: LoggedSet, date: Date)? {
    let past = data.history.filter { $0.id != session?.id && $0.started < (session?.started ?? .distantFuture) }
      .sorted { ($0.ended ?? $0.started) > ($1.ended ?? $1.started) }
    for workout in past {
      let sets = workout.sets.filter { $0.exercise.id == exercise.id && $0.comparable }
      if let best = sets.max(by: { exercise.timed ? $0.minutes < $1.minutes
        : ($0.weightKG == $1.weightKG ? $0.reps < $1.reps : $0.weightKG < $1.weightKG) }) {
        return (best, workout.ended ?? workout.started)
      }
    }
    return nil
  }

  var weightStep: Double { profile.unit == "lb" ? 5 : 2.5 }

  /// One step on the plate grid (2.5 kg or 5 lb). A first-time exercise starts from an empty bar
  /// or a light dumbbell; stepping down from nothing means bodyweight.
  func stepWeight(_ direction: Int) {
    guard let s = session, let exercise = s.selected, !exercise.timed, direction != 0 else { return }
    let unit = profile.unit, step = weightStep
    var shown = Self.displayedWeight(s.weightKG, unit: unit)
    if s.weightIsSet == false {
      shown = direction > 0 ? (exercise.perDumbbell ? (unit == "lb" ? 25 : 10) : (unit == "lb" ? 45 : 20)) : 0
    } else if direction > 0 {
      shown = (floor(shown / step + 1e-6) + 1) * step
    } else {
      shown = (ceil(shown / step - 1e-6) - 1) * step
    }
    updateWeight(min(500, max(0, shown)), unit: unit)
  }

  /// Reps can go down to zero during a set: zero logs a missed attempt.
  func stepReps(_ direction: Int) {
    guard let s = session, s.selected != nil else { return }
    let current = Int(s.draftRepsText ?? "") ?? s.draftReps ?? 10
    let next = min(999, max(0, current + direction))
    data.session?.draftRepsText = String(next)
    if next >= 1 { data.session?.draftReps = next }
    saveCurrentDraft()
    persist()
  }

  var draftRepCount: Int? {
    guard let s = session else { return nil }
    if let text = s.draftRepsText { return Int(text) }
    return s.draftReps
  }

  /// One tap: log the set with the shown weight and reps, and start the rest.
  /// Without a set clock the set's duration and the rest before it are unknown, never guessed.
  @discardableResult func logQuickSet() -> Bool {
    guard let s = session, let exercise = s.selected, !exercise.timed,
      s.stage == .setup || s.stage == .rest, s.weightIsSet != false,
      let reps = draftRepCount, (1...999).contains(reps)
    else { return false }
    data.session?.sets.append(
      LoggedSet(
        exercise: exercise, weightKG: s.weightKG, reps: reps, minutes: 0, timingUnknown: true,
        gapSourceID: s.restSourceID, gapUnknown: s.restSourceID == nil ? nil : true))
    data.session?.pendingGapStarted = nil
    data.session?.pendingGapSeconds = nil
    data.session?.pendingGapSourceID = nil
    data.session?.stage = .rest
    data.session?.restStarted = Date()
    data.session?.restSourceID = data.session?.sets.last?.id
    deletedSet = nil
    saveCurrentDraft()
    persist()
    return true
  }

  /// The store the Lock Screen button acts on (set once by the app).
  static weak var live: GymStore?

  /// What the Live Activity's button does: start the next set, or finish the running one with the
  /// planned weight and reps. Does nothing if that workout has ended or a weight is still missing.
  @discardableResult func stepFromLockScreen(_ workoutID: String, expecting step: String) -> Bool {
    guard let s = session, s.id.uuidString == workoutID, let exercise = s.selected else { return false }
    let running = s.stage == .active || s.stage == .log
    guard step == (running ? "finish" : "start") else { return false }
    switch s.stage {
    case .active, .log:
      if exercise.timed {
        let minutes = max(0, Date().timeIntervalSince(s.setStarted ?? Date()) / 60)
        guard minutes > 0 else { return false }
        finishSet(reps: 0, minutes: minutes)
      } else {
        guard let reps = draftRepCount, (0...999).contains(reps) else { return false }
        if reps == 0 { recordAttempt() } else { finishSet(reps: reps, minutes: 0) }
      }
      return true
    case .setup, .rest:
      if !exercise.timed && s.weightIsSet == false { return false }
      if timesSets || exercise.timed {
        startSet(weight: Self.displayedWeight(s.weightKG, unit: profile.unit), unit: profile.unit)
        return session?.stage == .active
      }
      return logQuickSet()
    case .exercise, .workout:
      return false
    }
  }

  /// The most recent thing that happened in the running workout.
  var lastActivity: Date? {
    guard let s = session else { return nil }
    return ([s.started, s.setStarted, s.restStarted] + s.sets.map(\.date)).compactMap { $0 }.max()
  }

  /// A workout with no activity for an hour was most likely left running.
  func isStale(now: Date = Date()) -> Bool {
    guard let last = lastActivity else { return false }
    return now.timeIntervalSince(last) >= Self.staleAfter
  }

  /// Ends a forgotten workout at its last activity. An open set can't be trusted, so it isn't saved.
  func finishStale() {
    guard session != nil else { return }
    if session?.stage == .active || session?.stage == .log { cancelSet() }
    let end = session.map { ([$0.started] + $0.sets.map(\.date)).max()! }
    finish(endedAt: end)
  }

  /// Removes a finished workout, e.g. one logged by mistake.
  func deleteWorkout(_ id: UUID) {
    data.history.removeAll { $0.id == id }
    persist()
  }

  /// A set clock under 3 s means Start and Finish were tapped back to back (the set happened
  /// before Start); a rep set over 15 min means Finish was forgotten. Neither duration is kept as fact.
  static func implausible(_ elapsed: TimeInterval?, timed: Bool) -> Bool {
    guard let elapsed else { return false }
    return elapsed < 3 || (!timed && elapsed > 15 * 60)
  }
}

/// A like-for-like gain over the previous workout of the same split (or free workouts):
/// more weight for the same reps, or more reps at the same weight. Never a guessed strength score.
struct Improvement: Identifiable {
  var id: String { exercise.id }
  let exercise: Exercise
  let weightGainKG: Double?
  let repGain: Int?
  let reps: Int
  let weightKG: Double
}
extension GymStore {
  func improvements(in workout: Session) -> [Improvement] {
    var seen = Set<String>()
    let exercises = workout.sets.map(\.exercise).filter { !$0.timed && seen.insert($0.id).inserted }
    return exercises.compactMap { exercise in
      let now = workout.sets.filter { $0.exercise.id == exercise.id && $0.comparable }
      guard !now.isEmpty, let before = data.history
        .filter({ $0.id != workout.id && $0.splitID == workout.splitID && $0.started < workout.started })
        .sorted(by: { $0.started > $1.started })
        .lazy.map({ $0.sets.filter { $0.exercise.id == exercise.id && $0.comparable } })
        .first(where: { !$0.isEmpty })
      else { return nil }
      // Same reps, more weight.
      var best: Improvement?
      for reps in Set(now.map(\.reps)) {
        let current = now.filter { $0.reps == reps }.map(\.weightKG).max() ?? 0
        guard let previous = before.filter({ $0.reps == reps }).map(\.weightKG).max(), current - previous > 0.001 else { continue }
        if best == nil || current - previous > best!.weightGainKG! {
          best = Improvement(exercise: exercise, weightGainKG: current - previous, repGain: nil, reps: reps, weightKG: current)
        }
      }
      if best != nil { return best }
      // Same weight, more reps.
      for set in now {
        guard let previous = before.filter({ abs($0.weightKG - set.weightKG) < 0.001 }).map(\.reps).max(), set.reps > previous else { continue }
        if best == nil || set.reps - previous > best!.repGain! {
          best = Improvement(exercise: exercise, weightGainKG: nil, repGain: set.reps - previous, reps: set.reps, weightKG: set.weightKG)
        }
      }
      return best
    }
  }
}

extension Session {
  /// Mean timed rest between sets, when there are any.
  var averageRest: TimeInterval? {
    let gaps = sets.compactMap { set -> Double? in
      guard set.gapUnknown != true, let gap = set.gapBeforeSeconds, gap > 0, gap < 30 * 60 else { return nil }
      return gap
    }
    return gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count)
  }
}
