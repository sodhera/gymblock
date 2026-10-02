import Foundation

struct LiftRecord: Identifiable {
  var id: String { self.set.exercise.id }
  let set: LoggedSet
}
struct ProgressPoint: Identifiable {
  var id: UUID { sessionID }
  let sessionID: UUID
  let date: Date
  let weightKG: Double
  var reps: Int = 0
}
extension GymStore {
  var biggestLifts: [LiftRecord] {
    let sets = data.history.flatMap(\.sets).filter {
      $0.comparable && !$0.exercise.timed && $0.weightKG > 0
    }
    let groups = Dictionary(grouping: sets, by: { $0.exercise.id })
    return groups.values.compactMap { sets in
      sets.max { a, b in a.weightKG == b.weightKG ? a.reps < b.reps : a.weightKG < b.weightKG }.map(
        LiftRecord.init)
    }.sorted { $0.set.weightKG > $1.set.weightKG }
  }
  /// An active week has at least one logged workout. The current week does not break a streak.
  var activeWeekStreak: Int {
    let calendar = Calendar.current
    guard let current = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
    let weeks = Set(
      data.history.filter { !$0.completedSets.isEmpty }.compactMap {
        calendar.dateInterval(of: .weekOfYear, for: $0.ended ?? $0.started)?.start
      })
    var cursor =
      weeks.contains(current)
      ? current : calendar.date(byAdding: .weekOfYear, value: -1, to: current)!
    var count = 0
    while weeks.contains(cursor) {
      count += 1
      cursor = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor)!
    }
    return count
  }
  func splitSessions(_ split: Workout) -> [Session] {
    data.history.filter { $0.splitID == split.id && !$0.completedSets.isEmpty }
  }
  /// Compare like for like: the same exercise and the same rep count within this split.
  func progress(for exercise: Exercise, split: Workout, reps: Int) -> [ProgressPoint] {
    splitSessions(split).compactMap { session in
      let sets = session.sets.filter {
        $0.exercise.id == exercise.id && $0.comparable && !$0.exercise.timed && $0.reps == reps
      }
      guard let best = sets.max(by: { $0.weightKG < $1.weightKG }) else { return nil }
      return ProgressPoint(
        sessionID: session.id, date: session.ended ?? session.started, weightKG: best.weightKG)
    }.sorted { $0.date < $1.date }
  }
  func repProgress(for exercise: Exercise, split: Workout, weightKG: Double) -> [ProgressPoint] {
    splitSessions(split).compactMap { session in
      let sets = session.sets.filter {
        $0.exercise.id == exercise.id && $0.comparable && !$0.exercise.timed
          && abs($0.weightKG - weightKG) < 0.001
      }
      guard let best = sets.max(by: { $0.reps < $1.reps }) else { return nil }
      return ProgressPoint(
        sessionID: session.id, date: session.ended ?? session.started, weightKG: best.weightKG,
        reps: best.reps)
    }.sorted { $0.date < $1.date }
  }
  func latestSet(for exercise: Exercise, split: Workout) -> LoggedSet? {
    let latest = splitSessions(split).filter {
      $0.sets.contains { $0.exercise.id == exercise.id && $0.comparable }
    }.max { $0.started < $1.started }
    return latest?.sets.filter { $0.exercise.id == exercise.id && $0.comparable }.max {
      $0.weightKG == $1.weightKG ? $0.reps < $1.reps : $0.weightKG < $1.weightKG
    }
  }
}
