import Foundation

/// A day on any dot surface: trained, today (not yet trained), or a day before or after today.
enum DayMark: Equatable { case trained, today, past, future }

/// The calendar maths Home and the widgets share, so they can't disagree. Days and weeks are integer
/// keys (yyyymmdd; a week is its Monday's key), weeks run Monday first, and a session counts on the
/// day it `started`. Pure: no store, no clock but the date passed in.
enum TrainingDays {
  /// The device calendar with Monday as the first weekday.
  static var calendar: Calendar {
    var c = Calendar.current
    c.firstWeekday = 2
    return c
  }

  /// yyyymmdd from the calendar's components, so it means the same day in either process.
  static func key(_ d: Date, _ c: Calendar = TrainingDays.calendar) -> Int {
    let x = c.dateComponents([.year, .month, .day], from: d)
    return (x.year ?? 0) * 10000 + (x.month ?? 0) * 100 + (x.day ?? 0)
  }

  /// The start of the day a key names.
  static func date(key: Int, _ c: Calendar = TrainingDays.calendar) -> Date {
    c.date(from: DateComponents(year: key / 10000, month: key / 100 % 100, day: key % 100)) ?? .distantPast
  }

  /// The start of the Monday on or before `d`, whatever the calendar's first weekday.
  static func monday(of d: Date, _ c: Calendar = TrainingDays.calendar) -> Date {
    let start = c.startOfDay(for: d)
    let back = (c.component(.weekday, from: start) + 5) % 7
    return c.date(byAdding: .day, value: -back, to: start).map { c.startOfDay(for: $0) } ?? start
  }

  /// Consecutive trained weeks counting back from the week of `monday`, which must itself be in `weeks`
  /// for the run to be more than 0.
  static func run(endingAt monday: Date, weeks: Set<Int>, _ c: Calendar = TrainingDays.calendar) -> Int {
    var n = 0, m = monday
    while weeks.contains(key(m, c)) {
      n += 1
      guard let earlier = c.date(byAdding: .day, value: -7, to: m) else { break }
      m = earlier
    }
    return n
  }

  /// Home's rule, uncapped: this week counts once trained; an empty current week is skipped.
  static func streak(at d: Date, weeks: Set<Int>, _ c: Calendar = TrainingDays.calendar) -> Int {
    let m = monday(of: d, c)
    if weeks.contains(key(m, c)) { return run(endingAt: m, weeks: weeks, c) }
    guard let last = c.date(byAdding: .day, value: -7, to: m) else { return 0 }
    return run(endingAt: last, weeks: weeks, c)
  }

  /// From a snapshot, for any entry date. W = week of d, B = baseWeek, tB = days has a day in week B:
  /// W ≤ B → (tB ? 1 : 0) + priorRun;  W == B+1 → tB ? 1 + priorRun : 0;  W ≥ B+2 → 0.
  /// The snapshot was written in week B, so later weeks hold no days yet; an empty week only breaks
  /// the streak once it is over.
  static func streak(at d: Date, baseWeek: Int, priorRun: Int, days: Set<Int>, _ c: Calendar = TrainingDays.calendar) -> Int {
    let w = key(monday(of: d, c), c)
    let base = date(key: baseWeek, c)
    let next = c.date(byAdding: .day, value: 7, to: base).map { key($0, c) } ?? baseWeek
    let trainedInBase = days.contains { $0 >= baseWeek && $0 < next }
    if w <= baseWeek { return (trainedInBase ? 1 : 0) + priorRun }
    if w == next { return trainedInBase ? 1 + priorRun : 0 }
    return 0
  }

  /// Distinct trained days in the week of `d` (two workouts on one day make one dot).
  static func thisWeek(at d: Date, days: Set<Int>, _ c: Calendar = TrainingDays.calendar) -> Int {
    week(at: d, days: days, c).filter { $0 == .trained }.count
  }

  /// The week of `d`, seven marks, Monday first.
  static func week(at d: Date, days: Set<Int>, _ c: Calendar = TrainingDays.calendar) -> [DayMark] {
    let start = monday(of: d, c), today = key(d, c)
    return (0..<7).map { i in
      mark(c.date(byAdding: .day, value: i, to: start).map { key($0, c) } ?? 0, today: today, days: days)
    }
  }

  /// The month of `d`: the empty cells before its first day (Monday first), its length, and a mark per day.
  static func month(at d: Date, days: Set<Int>, _ c: Calendar = TrainingDays.calendar) -> (lead: Int, length: Int, marks: [DayMark]) {
    let first = c.date(from: c.dateComponents([.year, .month], from: d)) ?? c.startOfDay(for: d)
    let length = c.range(of: .day, in: .month, for: first)?.count ?? 30
    let lead = (c.component(.weekday, from: first) + 5) % 7
    let today = key(d, c), monthKey = key(first, c) / 100 * 100
    return (lead, length, (1...length).map { mark(monthKey + $0, today: today, days: days) })
  }

  /// The day keys of the week of `d`, Monday first, matching `week(at:)`.
  static func weekKeys(at d: Date, _ c: Calendar = TrainingDays.calendar) -> [Int] {
    let start = monday(of: d, c)
    return (0..<7).map { c.date(byAdding: .day, value: $0, to: start).map { key($0, c) } ?? 0 }
  }

  /// The day key of day `n` (1-based) of the month of `d`, matching `month(at:)`.
  static func monthKey(_ n: Int, at d: Date, _ c: Calendar = TrainingDays.calendar) -> Int {
    let first = c.date(from: c.dateComponents([.year, .month], from: d)) ?? c.startOfDay(for: d)
    return key(first, c) / 100 * 100 + n
  }

  private static func mark(_ day: Int, today: Int, days: Set<Int>) -> DayMark {
    days.contains(day) ? .trained : day == today ? .today : day < today ? .past : .future
  }
}
