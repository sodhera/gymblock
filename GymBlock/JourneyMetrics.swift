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

/// Onboarding's time maths (docs/ONBOARDING-V8-PLAN.md): the minutes scrolling runs past the rest
/// they need, multiplied out from their own answers. Every shown number rounds down; nothing is
/// shown that doesn't fit inside their own gym time. Self-reported arithmetic only — never a
/// measurement or a body-outcome claim.
struct TimeBack: Equatable {
  /// A set, as the old estimate timed it.
  static let setSeconds = 40.0
  /// What "Not sure" counts as.
  static let unsureRest = 2.0
  /// Minutes: the rest they need, and how long a scroll between sets lasts once it starts.
  var restNeed = 1.5
  var scrolling: Double?
  /// How many rests a scroll eats: every rest 1, sometimes ½, rarely 0.
  var share = 1.0
  var exercises: Int?
  var setsEach: Int?
  /// Minutes at the gym, walking in to walking out.
  var gym: Double?
  var days = 4

  init() {}
  init(_ b: RoutineBaseline, restSeconds: Int? = nil) {
    if b.restNeedUnsure == true { restNeed = Self.unsureRest }
    else if let s = b.restNeedSeconds ?? restSeconds, s > 0 { restNeed = Double(s) / 60 }
    share = b.scrollFrequency == .no ? 0 : b.scrollFrequency == .sometimes ? 0.5 : 1
    scrolling = b.scrollFrequency == .no ? 0 : b.scrollingMinutes.flatMap { $0 > 0 ? $0 : nil }
    exercises = b.exercises; setsEach = b.sets
    gym = b.duration.map(Double.init)
    days = min(7, max(1, b.trainingDays ?? 4))
  }

  enum Outcome: Equatable {
    /// Not answered far enough to say.
    case open
    /// Rarely scrolls, or the scrolling fits inside the rest they need.
    case ahead
    /// Their sets and the rest they need alone run past their gym time: no workout total, only the
    /// per-rest number (never a guess).
    case unfit
    /// Under ten minutes a workout: shown as it is, then every rest on time, with no year or
    /// promise (a 5-minute "we'll give you those back" rang hollow; inspection, 20 Oct 2026).
    case small
    /// The whole pitch: per rest, per workout, per year, given back.
    case full
  }

  /// Minutes past the rest they need, for one scroll.
  var lostPerRest: Double? { scrolling.map { max(0, $0 - restNeed) } }
  var sets: Int? { exercises.flatMap { e in setsEach.map { e * $0 } } }
  var rests: Int? { sets.map { max(0, $0 - 1) } }
  var lifting: Double? { sets.map { Double($0) * Self.setSeconds / 60 } }
  var neededRest: Double? { rests.map { Double($0) * restNeed } }
  /// What the answers multiply out to before it's checked against the gym time.
  var rawLost: Double? {
    guard let rests, let lostPerRest else { return nil }
    return Double(rests) * lostPerRest * share
  }
  /// What's left of the gym time once the sets and the rest they need are in.
  var room: Double? {
    guard let gym, let lifting, let neededRest else { return nil }
    return gym - lifting - neededRest
  }
  /// Minutes lost a workout, never more than their gym time leaves room for.
  var lost: Double? {
    guard let rawLost, let room, room > 0 else { return nil }
    return min(rawLost, room)
  }
  /// Whether the answers ran past their gym time and the lost minutes were cut to fit.
  var fitted: Bool { (rawLost ?? 0) > (room ?? .infinity) + 1e-9 }

  var outcome: Outcome {
    if share == 0 || lostPerRest == 0 { return .ahead }
    guard lostPerRest != nil, gym != nil, sets != nil else { return .open }
    guard let lost else { return .unfit }
    return lost < Self.smallLoss ? .small : .full
  }
  static let smallLoss = 10.0

  /// The lost minutes as shown: down to the nearest 5, or down to the whole minute (at least 1)
  /// under 10. Every later number is multiplied from this one, so the pages agree.
  var shownLost: Int {
    guard let lost else { return 0 }
    return lost < Self.smallLoss ? max(1, Int(lost)) : Int(lost / 5) * 5
  }
  /// "about an hour" reads truer than 55 or 65.
  var lostIsAnHour: Bool { (55...65).contains(shownLost) }
  /// Their workout with rests on time: the gym time less the lost minutes, up to the nearest 5.
  var workout: Int {
    guard let gym, lost != nil else { return Int(gym ?? 0) }
    return Int(((gym - Double(shownLost)) / 5 - 1e-9).rounded(.up)) * 5
  }
  var yearHours: Double { lost == nil ? 0 : Double(shownLost) * Double(days) * 52 / 60 }
  /// Down to the nearest 10 hours from 20 up.
  var shownYear: Int { yearHours >= 20 ? Int(yearHours / 10) * 10 : Int(yearHours.rounded(.down)) }
  /// The year's lost hours as workouts of their own length, down to the nearest 5 from 20 up.
  var extraWorkouts: Int {
    guard let gym, gym > 0 else { return 0 }
    let n = Int(yearHours * 60 / gym)
    return n >= 20 ? n / 5 * 5 : n
  }
  /// Hours back a month, down to the hour (0 says nothing: the offer leaves the line out).
  var monthHours: Int { lost == nil ? 0 : Int(Double(shownLost) * Double(days) * 52 / 12 / 60) }
}

/// Minutes as people say them: "1½ minutes", "2 hours", "45 minutes", "1 h 5 min".
enum TimeWords {
  static func half(_ m: Double) -> String {
    let whole = Int(m.rounded(.down)), half = m - Double(whole) >= 0.5
    return half ? (whole == 0 ? "½" : "\(whole)½") : "\(whole)"
  }
  static func clock(_ minutes: Double) -> String {
    let s = Int((minutes * 60).rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
  }
  static func duration(_ m: Int) -> String {
    m < 60 ? "\(m) min" : m % 60 == 0 ? (m == 60 ? "1 h" : "\(m / 60) h") : "\(m / 60) h \(m % 60) min"
  }
  /// 45, 60, 90, 120, 150 → the words the options use.
  static func gymLong(_ m: Double) -> String {
    switch Int(m) {
    case 60: return "1 hour"
    case 90: return "1½ hours"
    case 120: return "2 hours"
    case 150: return "2½ hours"
    default: return "\(Int(m)) minutes"
    }
  }
  static func gymShort(_ m: Double) -> String {
    switch Int(m) {
    case 90: return "1½ h"
    case 150: return "2½ h"
    default: return Int(m) % 60 == 0 ? "\(Int(m) / 60) h" : "\(Int(m)) min"
    }
  }
}

enum BodyUnits {
  static var defaultMetric: Bool { Locale.current.measurementSystem != .us }
  static func feet(_ inches: Double) -> String { "\(Int(inches) / 12)′ \(Int(inches) % 12)″" }
}
