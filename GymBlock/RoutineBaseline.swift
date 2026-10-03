import Foundation

struct ExerciseDraft: Codable {
  var weightKG: Double
  var reps: Int
  var minutes: Double
  var repsText: String?
  var weightIsSet: Bool?
}
struct BaselineExercise: Codable, Identifiable {
  var id = UUID()
  var name = ""
  var sets: Int?
  var reps = ""
  var valid: Bool {
    if let sets, !(1...50).contains(sets) { return false }
    if reps.isEmpty { return true }
    let values = reps.split(separator: ",", omittingEmptySubsequences: false)
    guard values.allSatisfy({ RoutineBaseline.repRange(String($0)) != nil }) else { return false }
    return sets == nil || values.count == 1 || values.count == sets
  }
  var repTotal: ClosedRange<Int>? {
    guard let sets, (1...50).contains(sets) else { return nil }
    let values = reps.split(separator: ",", omittingEmptySubsequences: false).map {
      RoutineBaseline.repRange(String($0))
    }
    guard !values.isEmpty, values.allSatisfy({ $0 != nil }),
      values.count == 1 || values.count == sets
    else { return nil }
    if values.count == 1, let r = values[0] { return (r.lowerBound * sets)...(r.upperBound * sets) }
    return values.reduce(0) {
      $0 + ($1?.lowerBound ?? 0)
    }...values.reduce(0) { $0 + ($1?.upperBound ?? 0) }
  }
}
struct RoutineBaseline: Codable {
  var distractions: [String] = []
  var duration: Int?
  var visits: Int?
  var exercises: Int?
  var sets: Int?
  var reps = ""
  var timed = false
  var details: [BaselineExercise] = []
  var scrolling: Int?
  var reductionGoal: Int?
  var scrollsBetweenSets: Bool?
  var minutesPerBreak: Int?
  var breakCount: Int? { totalSets.map { max(0, $0 - 1) } }
  var feedMinutes: Int? {
    guard let scrollsBetweenSets else { return scrolling } // Existing attributed survey answers.
    if !scrollsBetweenSets { return 0 }
    guard let minutesPerBreak, (1...600).contains(minutesPerBreak), let breakCount else { return nil }
    return breakCount * minutesPerBreak
  }
  var defaultReps: Int? {
    Self.repRange(reps).flatMap { $0.lowerBound == $0.upperBound ? $0.lowerBound : nil }
  }
  static func repRange(_ input: String) -> ClosedRange<Int>? {
    let parts = input.replacingOccurrences(of: "–", with: "-").split(
      separator: "-", omittingEmptySubsequences: false
    ).map {
      $0.trimmingCharacters(in: .whitespaces)
    }
    guard (1...2).contains(parts.count), let lower = Int(parts[0]), (1...999).contains(lower) else {
      return nil
    }
    let upper = parts.count == 2 ? Int(parts[1]) : lower
    guard let upper, (lower...999).contains(upper) else { return nil }
    return lower...upper
  }
  var totalSets: Int? {
    if !details.isEmpty {
      guard details.allSatisfy({ $0.sets.map { (1...50).contains($0) } == true }) else {
        return nil
      }
      return details.reduce(0) { $0 + ($1.sets ?? 0) }
    }
    guard let exercises, let sets, (1...50).contains(exercises), (1...50).contains(sets) else {
      return nil
    }
    return exercises * sets
  }
  var totalReps: ClosedRange<Int>? {
    guard !timed else { return nil }
    if !details.isEmpty {
      guard details.allSatisfy({ $0.repTotal != nil }) else { return nil }
      let lower = details.reduce(0) { $0 + ($1.repTotal?.lowerBound ?? 0) }
      let upper = details.reduce(0) { $0 + ($1.repTotal?.upperBound ?? 0) }
      return lower...upper
    }
    guard let totalSets, let range = Self.repRange(reps) else { return nil }
    return (totalSets * range.lowerBound)...(totalSets * range.upperBound)
  }
  var weeklyGymMinutes: Int? {
    guard let duration, let visits, (1...600).contains(duration), (0...21).contains(visits) else {
      return nil
    }
    return duration * visits
  }
  var weeklyFeedMinutes: Int? {
    guard let scrolling = feedMinutes, let visits, (0...600).contains(scrolling), (0...21).contains(visits),
      scrollingValid
    else { return nil }
    return scrolling * visits
  }
  var scrollingValid: Bool {
    guard let scrolling = feedMinutes, let duration else { return true }
    return scrolling <= duration
  }
}
