import Foundation

enum HabitAnswer: String, Codable, CaseIterable { case yes, sometimes, no }
enum LoggingHabit: String, Codable, CaseIterable { case review, logOnly, neither }

extension RoutineBaseline {
  var attentionMinutes: Double? {
    if scrollFrequency == .no || (scrollFrequency == nil && scrollsBetweenSets == false) {
      return 0
    }
    guard scrollFrequency != nil || scrollsBetweenSets == true,
      scrollFrequency != .sometimes || scrollingBreaks != nil,
      let minutes = scrollingMinutes ?? minutesPerBreak.map(Double.init),
      minutes.isFinite, minutes > 0, minutes <= 600,
      let breaks = effectiveScrollingBreaks, breakAssumptionValid,
      visitsPerTrainingDay == nil || visitsPerTrainingDay == 1
    else { return nil }
    return Double(breaks) * minutes
  }
  var attentionValid: Bool {
    guard let minutes = attentionMinutes, let duration else { return true }
    return minutes < Double(duration)
  }
  var canShowAttention: Bool {
    guard let minutes = attentionMinutes, let duration else { return false }
    return minutes > 0 && (1...600).contains(duration) && attentionValid
  }
  var fourWeekTrainingDays: Int? {
    guard let trainingDays, (1...7).contains(trainingDays) else { return nil }
    return trainingDays * 4
  }
  var fourWeekSets: Int? {
    guard !timed, let days = fourWeekTrainingDays, let sets = totalSets else { return nil }
    return days * sets
  }
  var fourWeekReps: ClosedRange<Int>? {
    guard let days = fourWeekTrainingDays, let reps = totalReps else { return nil }
    return (days * reps.lowerBound)...(days * reps.upperBound)
  }
  var fourWeekAttention: Double? {
    guard visitsPerTrainingDay == 1, canShowAttention,
      let days = fourWeekTrainingDays, let minutes = attentionMinutes
    else { return nil }
    return Double(days) * minutes
  }
}

extension LoggedSet {
  var validTiming: Bool {
    [elapsedSetSeconds, gapBeforeSeconds].allSatisfy {
      $0 == nil || ($0!.isFinite && $0! >= 0 && $0! <= 604800)
    }
  }
  var displayedSetSeconds: Double? { timingUnknown == true ? nil : elapsedSetSeconds }
}

extension Session {
  func gapSeconds(before set: LoggedSet) -> Double? {
    guard set.gapUnknown != true, let source = set.gapSourceID,
      sets.contains(where: { $0.id == source })
    else { return nil }
    return set.gapBeforeSeconds
  }
  func gapCrossesExercises(before set: LoggedSet) -> Bool {
    sets.first { $0.id == set.gapSourceID }?.exercise.id != set.exercise.id
  }
}

enum JourneyFormat {
  static func number(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)))
  }
  static func time(_ seconds: Double) -> String {
    let value = max(0, Int(seconds))
    return String(format: "%d:%02d", value / 60, value % 60)
  }
  static func minutes(_ value: Double) -> String {
    if value < 60 { return number(value) + " min" }
    let hours = Int(value / 60)
    let rest = Int(value.truncatingRemainder(dividingBy: 60).rounded())
    return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
  }
}

/// The onboarding estimate: their own minutes per rest, with typical routine defaults they can adjust.
/// Self-reported time arithmetic only — never a measured or body-outcome claim.
struct GymTimeEstimate: Equatable {
  var minutesPerRest = 2.0
  var exercises = 6
  var sets = 3
  var days = 5
  var rests: Int { max(0, exercises * sets - 1) }
  var phoneMinutes: Double { Double(rests) * minutesPerRest }
  var yearlyPhoneHours: Double { phoneMinutes * Double(days) * 52 / 60 }
  static let workoutMinutes = 45.0
  /// The yearly phone time expressed as 45-minute workouts.
  var yearlyWorkouts: Int { Int((yearlyPhoneHours * 60 / Self.workoutMinutes).rounded()) }
  init() {}
  init(_ b: RoutineBaseline) {
    if b.scrollFrequency == .no { minutesPerRest = b.scrollingMinutes ?? 0 }
    else { minutesPerRest = b.scrollingMinutes ?? (b.scrollFrequency == .sometimes ? 1 : 2) }
    if let e = b.exercises, (1...15).contains(e) { exercises = e }
    if let s = b.sets, (1...10).contains(s) { sets = s }
    if let d = b.trainingDays, (1...7).contains(d) { days = d }
  }
  func write(into b: inout RoutineBaseline) {
    b.scrollingMinutes = minutesPerRest
    b.minutesPerBreak = nil
    b.details = []
    b.exercises = exercises; b.sets = sets
    b.trainingDays = days
  }
}

enum BodyUnits {
  static var defaultMetric: Bool { Locale.current.measurementSystem != .us }
  static func feet(_ inches: Double) -> String { "\(Int(inches) / 12)′ \(Int(inches) % 12)″" }
}
