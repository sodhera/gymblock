import XCTest

@testable import GymBlock

/// The widgets' data contract (docs/WIDGETS-PLAN.md §10): the shared week maths, the snapshot the app
/// writes, the reload rule and the deep-link routes. Pure where it can be; stores use a throwaway suite.
@MainActor final class WidgetTests: XCTestCase {
  private var defaults: UserDefaults!
  private var domain: String!
  override func setUp() {
    super.setUp()
    domain = "WidgetTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: domain)!
  }
  override func tearDown() {
    defaults.removePersistentDomain(forName: domain)
    super.tearDown()
  }

  // MARK: Fixtures

  /// Madrid: daylight saving ends on Sunday 25 Oct 2026 and starts on Sunday 29 Mar 2026.
  private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Madrid")!
    c.locale = Locale(identifier: "en_US_POSIX")
    c.firstWeekday = 2
    return c
  }()
  private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
  }
  /// SplitMix64: random histories that are the same on every run.
  private struct Seeded: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var z = state
      z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
      z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
      return z ^ (z >> 31)
    }
  }
  /// Workout start times on random days within `days` before `now` (today included, never after now).
  private func history(_ rng: inout Seeded, now: Date, days: Int, chance: Double) -> [Date] {
    (0..<days).compactMap { back -> Date? in
      guard Double.random(in: 0..<1, using: &rng) < chance else { return nil }
      let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -back, to: now)!)
      return min(now, start.addingTimeInterval(9 * 3600))
    }
  }
  private func weeks(_ starts: [Date]) -> Set<Int> {
    Set(starts.map { TrainingDays.key(TrainingDays.monday(of: $0, cal), cal) })
  }
  /// Home's streak before the widgets (HomeStats.swift at f1b0ff5): a 12-week grid, counted back.
  private func oldHomeStreak(_ starts: [Date], now: Date, weeks: Int = 12) -> Int {
    let trainedDays = Set(starts.map { cal.startOfDay(for: $0) })
    let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)!.start
    var grid: [[Bool]] = []
    for offset in stride(from: weeks - 1, through: 0, by: -1) {
      guard let start = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) else { continue }
      grid.append((0..<7).map { d in
        guard let date = cal.date(byAdding: .day, value: d, to: start) else { return false }
        return trainedDays.contains(cal.startOfDay(for: date))
      })
    }
    var streak = 0
    for (index, week) in grid.enumerated().reversed() {
      if week.contains(true) { streak += 1 } else if index == grid.count - 1 { continue } else { break }
    }
    return streak
  }
  private func set(_ date: Date, failed: Bool = false) -> LoggedSet {
    LoggedSet(exercise: Exercise.catalog[0], weightKG: 20, reps: failed ? 0 : 10, minutes: 0, date: date,
              unsuccessful: failed ? true : nil)
  }
  private func finished(_ started: Date, minutes: Double = 40, split: UUID? = nil, failed: Bool = false) -> Session {
    var s = Session()
    s.started = started
    s.ended = started.addingTimeInterval(minutes * 60)
    s.name = "Push"
    s.splitID = split
    s.sets = [set(started.addingTimeInterval(60), failed: failed)]
    return s
  }
  private func onboardedStore(language: String = "en") -> GymStore {
    let store = GymStore(defaults: defaults)
    store.updateProfile { $0.onboarded = true; $0.language = language; $0.name = "Sirish" }
    return store
  }

  // MARK: TrainingDays

  func testStreakMatchesOldHomeRuleWithinTwelveWeeks() {
    var rng = Seeded(state: 42)
    for trial in 0..<400 {
      let now = cal.date(byAdding: .hour, value: Int.random(in: 10...23, using: &rng),
                         to: cal.startOfDay(for: cal.date(byAdding: .day, value: trial, to: day(2026, 1, 5))!))!
      // Inside the old grid: this week so far and the eleven before it.
      let grid = 78 + (cal.component(.weekday, from: now) + 5) % 7
      let starts = history(&rng, now: now, days: grid, chance: [0.04, 0.1, 0.2, 0.45][trial % 4])
      XCTAssertEqual(TrainingDays.streak(at: now, weeks: weeks(starts), cal), oldHomeStreak(starts, now: now), "trial \(trial)")
    }
  }

  func testTwentyWeekRunReadsTwentyAndHomeIsUncapped() {
    let now = day(2026, 10, 14, 18)
    let starts = (0..<20).map { cal.date(byAdding: .day, value: -7 * $0, to: now)! }
    XCTAssertEqual(TrainingDays.streak(at: now, weeks: weeks(starts), cal), 20)
    // Home reads the same function: no 12-week cap any more.
    let store = onboardedStore()
    let recent = Date().addingTimeInterval(-60)
    store.data.history = (0..<20).map { finished(TrainingDays.calendar.date(byAdding: .day, value: -7 * $0, to: recent)!) }
    XCTAssertEqual(store.homeStats().streakWeeks, 20)
  }

  func testEmptyCurrentWeekIsSkippedAndFirstEmptyEarlierWeekBreaks() {
    let now = day(2026, 10, 14, 18)  // Wednesday
    let lastWeeks = (1...3).map { cal.date(byAdding: .day, value: -7 * $0, to: now)! }
    XCTAssertEqual(TrainingDays.streak(at: now, weeks: weeks(lastWeeks), cal), 3)
    // This week joins once trained.
    XCTAssertEqual(TrainingDays.streak(at: now, weeks: weeks(lastWeeks + [now]), cal), 4)
    // A gap four weeks back stops the count; the weeks before it don't add up.
    let older = (5...9).map { cal.date(byAdding: .day, value: -7 * $0, to: now)! }
    XCTAssertEqual(TrainingDays.streak(at: now, weeks: weeks(lastWeeks + older), cal), 3)
    // Two empty weeks: nothing.
    let stale = (2...4).map { cal.date(byAdding: .day, value: -7 * $0, to: now)! }
    XCTAssertEqual(TrainingDays.streak(at: now, weeks: weeks(stale), cal), 0)
  }

  func testSnapshotStreakFormulaMatchesFullStreakForTwoWeeks() {
    var rng = Seeded(state: 7)
    for trial in 0..<200 {
      let now = cal.date(byAdding: .hour, value: Int.random(in: 10...23, using: &rng),
                         to: cal.startOfDay(for: cal.date(byAdding: .day, value: trial * 2, to: day(2026, 1, 1))!))!
      // Longer than the grid, so the uncapped runs are covered too.
      let starts = history(&rng, now: now, days: 210, chance: [0.08, 0.2, 0.5, 0.9][trial % 4])
      let w = weeks(starts), monday = TrainingDays.monday(of: now, cal)
      let since = TrainingDays.key(cal.date(byAdding: .day, value: -41, to: now)!, cal)
      let days = Set(starts.map { TrainingDays.key($0, cal) }).filter { $0 >= since }
      let prior = TrainingDays.run(endingAt: cal.date(byAdding: .day, value: -7, to: monday)!, weeks: w, cal)
      for ahead in 0...13 {
        let d = cal.date(byAdding: .day, value: ahead, to: now)!
        XCTAssertEqual(
          TrainingDays.streak(at: d, baseWeek: TrainingDays.key(monday, cal), priorRun: prior, days: days, cal),
          TrainingDays.streak(at: d, weeks: w, cal), "trial \(trial), \(ahead) days on")
      }
    }
  }

  func testWeekMarksAcrossDaylightSavingAndBoundaries() {
    let trained: Set<Int> = [20261019, 20261021]
    // The autumn change happens on this Sunday; late on it, the week is still the one from Monday 19th.
    XCTAssertEqual(TrainingDays.key(TrainingDays.monday(of: day(2026, 10, 25, 23, 59), cal), cal), 20261019)
    XCTAssertEqual(TrainingDays.week(at: day(2026, 10, 25, 22), days: trained, cal),
                   [.trained, .past, .trained, .past, .past, .past, .today])
    XCTAssertEqual(TrainingDays.thisWeek(at: day(2026, 10, 25, 22), days: trained, cal), 2)
    // Just after midnight the new week starts empty: today ringed, the rest to come.
    XCTAssertEqual(TrainingDays.key(TrainingDays.monday(of: day(2026, 10, 26, 0, 30), cal), cal), 20261026)
    XCTAssertEqual(TrainingDays.week(at: day(2026, 10, 26, 0, 30), days: trained, cal), [.today] + Array(repeating: .future, count: 6))
    XCTAssertEqual(TrainingDays.thisWeek(at: day(2026, 10, 26, 0, 30), days: trained, cal), 0)
    // Spring change, Sunday 29 March, before and after the missing hour.
    for h in [1, 4, 23] {
      XCTAssertEqual(TrainingDays.week(at: day(2026, 3, 29, h), days: [20260323], cal),
                     [.trained, .past, .past, .past, .past, .past, .today])
    }
    // A week that spans a month and one that spans a year.
    XCTAssertEqual(TrainingDays.week(at: day(2026, 11, 1, 9), days: [20261027], cal),
                   [.past, .trained, .past, .past, .past, .past, .today])
    XCTAssertEqual(TrainingDays.week(at: day(2027, 1, 1, 9), days: [20261228, 20270101], cal),
                   [.trained, .past, .past, .past, .trained, .future, .future])
    // Day keys survive the round trip on both change days.
    for key in [20260329, 20261025, 20261026] {
      XCTAssertEqual(TrainingDays.key(TrainingDays.date(key: key, cal), cal), key)
      XCTAssertEqual(TrainingDays.date(key: key, cal), cal.startOfDay(for: TrainingDays.date(key: key, cal)))
    }
  }

  func testMonthMarksAcrossDaylightSavingAndBoundaries() {
    // October 2026 starts on a Thursday and holds the autumn change.
    let october = TrainingDays.month(at: day(2026, 10, 25, 22), days: [20261001, 20261025, 20260930], cal)
    XCTAssertEqual(october.lead, 3)
    XCTAssertEqual(october.length, 31)
    XCTAssertEqual(october.marks[0], .trained)
    XCTAssertEqual(october.marks[23], .past)
    XCTAssertEqual(october.marks[24], .trained)  // Today, trained: filled, not ringed.
    XCTAssertEqual(october.marks[25], .future)
    XCTAssertEqual(october.marks.filter { $0 == .trained }.count, 2)  // 30 September isn't in it.
    // The last minutes of October, then the first of November (a Sunday).
    let last = TrainingDays.month(at: day(2026, 10, 31, 23, 50), days: [], cal)
    XCTAssertEqual(last.marks[30], .today)
    XCTAssertEqual(last.marks.filter { $0 == .past }.count, 30)
    let november = TrainingDays.month(at: day(2026, 11, 1, 0, 10), days: [20261031], cal)
    XCTAssertEqual(november.lead, 6)
    XCTAssertEqual(november.length, 30)
    XCTAssertEqual(november.marks, [.today] + Array(repeating: .future, count: 29))
    // March 2026 holds the spring change; February 2027 starts on a Monday; February 2028 is a leap month.
    let march = TrainingDays.month(at: day(2026, 3, 29, 4), days: [20260329], cal)
    XCTAssertEqual(march.lead, 6)
    XCTAssertEqual(march.length, 31)
    XCTAssertEqual(march.marks[28], .trained)
    XCTAssertEqual(TrainingDays.month(at: day(2027, 2, 10), days: [], cal).lead, 0)
    XCTAssertEqual(TrainingDays.month(at: day(2027, 2, 10), days: [], cal).length, 28)
    XCTAssertEqual(TrainingDays.month(at: day(2028, 2, 10), days: [], cal).lead, 1)
    XCTAssertEqual(TrainingDays.month(at: day(2028, 2, 10), days: [], cal).length, 29)
  }

  // MARK: Snapshot

  func testLogOutAndDeleteLeaveSetupWithNothingOfTheUsers() {
    let store = onboardedStore()
    store.data.workouts = [Workout(name: "Chest day", exercises: [Exercise.catalog[0]])]
    store.data.history = [finished(Date().addingTimeInterval(-3600))]
    let idle = store.widgetSnapshot()
    XCTAssertEqual(idle.state, .idle)
    XCTAssertEqual(idle.hero, "Chest day")
    XCTAssertFalse(idle.days.isEmpty)

    store.logOut()
    var s = store.widgetSnapshot()
    XCTAssertEqual(s.state, .setup)
    XCTAssertEqual(s.hero, "")
    XCTAssertTrue(s.days.isEmpty)
    XCTAssertNil(s.heroShort); XCTAssertNil(s.detail); XCTAssertNil(s.caption); XCTAssertNil(s.running)
    XCTAssertFalse(s.hasHistory)

    store.updateProfile { $0.onboarded = true }
    store.startSession()
    store.deleteAccount()
    s = store.widgetSnapshot()
    XCTAssertEqual(s.state, .setup)
    XCTAssertEqual(s.hero, "")
    XCTAssertTrue(s.days.isEmpty)
    XCTAssertNil(s.running)
  }

  func testSnapshotNeverCarriesTheName() throws {
    let store = onboardedStore()
    store.data.history = [finished(Date().addingTimeInterval(-3600))]
    store.startSession()
    let json = String(decoding: try JSONEncoder().encode(store.widgetSnapshot()), as: UTF8.self)
    XCTAssertFalse(json.contains("Sirish"))
  }

  func testSampleAfterLoadingDemo() {
    let store = GymStore(defaults: defaults)
    XCTAssertFalse(store.widgetSnapshot().sample)
    XCTAssertTrue(store.loadDemoIfEmpty())
    let s = store.widgetSnapshot()
    XCTAssertTrue(s.sample)
    XCTAssertEqual(s.state, .idle)
    XCTAssertTrue(s.hasHistory)
  }

  func testShortFormsOnlyInSpanishAndOnlyForTheThreeNames() {
    // Spanish, nothing logged, no split: "Your first workout".
    let es = onboardedStore(language: "es")
    var s = es.widgetSnapshot()
    XCTAssertEqual(s.hero, "Tu primer entrenamiento")
    XCTAssertEqual(s.heroShort, "Tu primer entreno")
    // History but no split: "Free workout".
    es.data.history = [finished(Date().addingTimeInterval(-3600))]
    s = es.widgetSnapshot()
    XCTAssertEqual(s.hero, "Entrenamiento libre")
    XCTAssertEqual(s.heroShort, "Entreno libre")
    // A running workout with no split chosen: "My workout".
    es.startSession()
    es.chooseWorkout(nil)
    s = es.widgetSnapshot()
    XCTAssertEqual(s.state, .running)
    XCTAssertEqual(s.hero, "Mi entrenamiento")
    XCTAssertEqual(s.heroShort, "Mi entreno")
    es.data.session = nil
    // A split of the user's own: never shortened.
    es.data.workouts = [Workout(name: "Brazos", exercises: [Exercise.catalog[0]])]
    XCTAssertNil(es.widgetSnapshot().heroShort)
    // English: never.
    let en = GymStore(defaults: UserDefaults(suiteName: domain + ".en")!)
    defer { UserDefaults().removePersistentDomain(forName: domain + ".en") }
    en.updateProfile { $0.onboarded = true; $0.language = "en" }
    XCTAssertEqual(en.widgetSnapshot().hero, "Your first workout")
    XCTAssertNil(en.widgetSnapshot().heroShort)
    en.data.history = [finished(Date().addingTimeInterval(-3600))]
    XCTAssertEqual(en.widgetSnapshot().hero, "Free workout")
    XCTAssertNil(en.widgetSnapshot().heroShort)
  }

  func testFailedSetsOnlyDontCountAsTrained() {
    let store = onboardedStore()
    store.data.history = [finished(Date().addingTimeInterval(-3600), failed: true)]
    let s = store.widgetSnapshot()
    XCTAssertTrue(s.days.isEmpty)
    XCTAssertFalse(s.hasHistory)
    XCTAssertNil(s.lastFinished)
    XCTAssertEqual(s.hero, "Your first workout")
  }

  func testSnapshotDaysWeeksAndRunning() {
    let store = onboardedStore()
    let now = Date()
    let c = TrainingDays.calendar
    // Trained in each of the last three weeks, plus once 60 days ago (outside the 42-day window).
    let starts = [7, 14, 21, 60].map { c.date(byAdding: .day, value: -$0, to: now)! }
    store.data.history = starts.map { finished($0) }
    store.updateProfile { $0.baseline = RoutineBaseline(); $0.baseline?.trainingDays = 9 }
    var s = store.widgetSnapshot(now: now)
    XCTAssertEqual(s.baseWeek, TrainingDays.key(TrainingDays.monday(of: now)))
    XCTAssertEqual(s.days, starts.prefix(3).map { TrainingDays.key($0) }.sorted())
    XCTAssertEqual(s.priorRun, 3)
    XCTAssertEqual(s.goal, 7)
    XCTAssertEqual(s.lastFinished, starts.map { $0.addingTimeInterval(40 * 60) }.max())
    // Running: the clock leaves out paused time; stale an hour and a quarter after the last activity.
    store.startSession()
    store.data.session?.pausedSeconds = 120
    s = store.widgetSnapshot(now: now)
    let session = store.session!
    XCTAssertEqual(s.state, .running)
    XCTAssertEqual(s.running?.clockStart, session.started.addingTimeInterval(120))
    XCTAssertNil(s.running?.exercise)
    XCTAssertEqual(s.running?.activeUntil, store.lastActivity!.addingTimeInterval(4500))
    store.chooseExercise(Exercise.catalog[0])
    XCTAssertEqual(store.widgetSnapshot().running?.exercise, Exercise.catalog[0].name)
  }

  func testIdleCaptionAndDetailFollowTheSplit() {
    let store = onboardedStore()
    let push = Workout(name: "Push", exercises: Array(Exercise.catalog.prefix(3)))
    store.data.workouts = [push]
    var s = store.widgetSnapshot()
    XCTAssertEqual(s.hero, "Push")
    XCTAssertEqual(s.caption, "First time")
    XCTAssertEqual(s.detail, "3 exercises  ·  first time")
    store.data.history = [finished(Date().addingTimeInterval(-86400), minutes: 48.7, split: store.data.workouts[0].id)]
    s = store.widgetSnapshot()
    XCTAssertEqual(s.caption, "48 min last time")
    XCTAssertEqual(s.detail, "3 exercises  ·  48 min last time")
  }

  /// Home's line before `splitSummary` was split out (Home.swift at f1b0ff5).
  private func oldSummary(_ store: GymStore, _ split: Workout?) -> String {
    guard let split else { return store.t("Pick exercises as you go.") }
    let count = split.exercises.count
    var parts = [count == 1 ? store.t("1 exercise") : "\(count) " + store.t("exercises")]
    if let last = store.data.history.filter({ $0.splitID == split.id }).max(by: { $0.started < $1.started }) {
      parts.append("\(max(1, Int(last.duration / 60))) " + store.t("min last time"))
    } else {
      parts.append(store.t("first time"))
    }
    return parts.joined(separator: "  ·  ")
  }

  func testSummaryUnchangedByTheRefactor() {
    for language in ["en", "es"] {
      let store = GymStore(defaults: UserDefaults(suiteName: domain + language)!)
      defer { UserDefaults().removePersistentDomain(forName: domain + language) }
      store.updateProfile { $0.onboarded = true; $0.language = language }
      let one = Workout(name: "One", exercises: [Exercise.catalog[0]])
      let three = Workout(name: "Three", exercises: Array(Exercise.catalog.prefix(3)))
      store.data.workouts = [one, three]
      store.data.history = [
        finished(Date().addingTimeInterval(-3 * 86400), minutes: 0.2, split: one.id),
        finished(Date().addingTimeInterval(-9 * 86400), minutes: 75, split: three.id),
        finished(Date().addingTimeInterval(-2 * 86400), minutes: 48.9, split: three.id),
      ]
      for split in [nil, one, three, Workout(name: "New", exercises: [])] {
        XCTAssertEqual(store.summary(of: split), oldSummary(store, split), "\(language) \(split?.name ?? "nil")")
      }
      XCTAssertEqual(store.splitSummary(three).lastMinutes, 48)
      XCTAssertEqual(store.splitSummary(one).lastMinutes, 1)
    }
  }

  func testSpanishWidgetLabels() {
    let l = WidgetSnapshot.Labels(t: Spanish.translate)
    XCTAssertEqual(l.weekStreakOne, "1 semana de racha")
    XCTAssertEqual(l.openGymBlock, "Abre GymBlock")
    XCTAssertEqual(l.upNext, "Siguiente")
    XCTAssertEqual(l.stillWorkingOut, "¿Sigues entrenando?")
    XCTAssertEqual(Spanish.translate("First time"), "Primera vez")
    XCTAssertEqual(onboardedStore(language: "es").t("1 week streak"), "1 semana de racha")
  }

  func testSnapshotRoundTripsThroughJSON() throws {
    let store = onboardedStore()
    store.data.history = [finished(Date().addingTimeInterval(-3600))]
    store.startSession()
    let s = store.widgetSnapshot()
    XCTAssertEqual(try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(s)), s)
  }

  // MARK: Reloads

  private func running(lastActivity: Date, exercise: String? = "Bench press") -> WidgetSnapshot {
    WidgetSnapshot(
      state: .running, hero: "Push", sample: false, days: [20261012], baseWeek: 20261012, priorRun: 2, goal: 4,
      hasHistory: true,
      running: .init(exercise: exercise, clockStart: Date(timeIntervalSinceReferenceDate: 800_000_000), pausedAt: nil,
                     lastActivity: lastActivity),
      labels: .init(t: { $0 }))
  }

  func testLastActivityAloneReloadsUpNextOnlyPastFifteenMinutes() {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let base = running(lastActivity: start)
    XCTAssertTrue(WidgetSync.upNextNeedsReload(base, since: nil))
    XCTAssertFalse(WidgetSync.upNextNeedsReload(base, since: base))
    XCTAssertFalse(WidgetSync.upNextNeedsReload(running(lastActivity: start.addingTimeInterval(900)), since: base))
    XCTAssertTrue(WidgetSync.upNextNeedsReload(running(lastActivity: start.addingTimeInterval(901)), since: base))
    // Either way: a deleted last set moves it back.
    XCTAssertTrue(WidgetSync.upNextNeedsReload(running(lastActivity: start.addingTimeInterval(-901)), since: base))
    // Anything shown reloads at once.
    XCTAssertTrue(WidgetSync.upNextNeedsReload(running(lastActivity: start.addingTimeInterval(60), exercise: "Squat"), since: base))
    // `lastActivity` never touches the other kinds.
    XCTAssertEqual(running(lastActivity: start.addingTimeInterval(5000)).daysKey, base.daysKey)
    XCTAssertEqual(running(lastActivity: start.addingTimeInterval(5000)).controlKey, base.controlKey)
  }

  func testLockScreenSetsAddUpAndStayWithinBudget() {
    // Twenty sets logged from the Lock Screen, one every three minutes: only `lastActivity` moves.
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    var reloaded = running(lastActivity: start), reloads = 0
    for n in 1...20 {
      let s = running(lastActivity: start.addingTimeInterval(Double(n) * 180))
      // `reloaded` moves only on a reload (WidgetSync.flush), so the drift adds up across sets.
      if WidgetSync.upNextNeedsReload(s, since: reloaded) { reloads += 1; reloaded = s }
      if n == 5 { XCTAssertEqual(reloads, 0) }  // 15 minutes exactly: not yet.
      if n == 6 { XCTAssertEqual(reloads, 1) }
    }
    XCTAssertLessThanOrEqual(reloads, 6)
    XCTAssertEqual(reloads, 3)
  }

  // MARK: Routes

  func testRoutesParseByHostAndLeaveTheSignInCallbackAlone() {
    XCTAssertNil(AppRoute(url: URL(string: "gymblock://auth/callback?code=x")!))
    XCTAssertNil(AppRoute(url: URL(string: "com.sodhera.gymblock://home")!))
    XCTAssertNil(AppRoute(url: URL(string: "https://www.orecci.com/gymblock/")!))
    let small = URL(string: "gymblock://home?from=small")!
    XCTAssertEqual(AppRoute(url: small), .home)
    XCTAssertEqual(AppRoute.source(small), "small")
    XCTAssertEqual(AppRoute(url: URL(string: "gymblock://profile?from=month")!), .profile)
    XCTAssertEqual(AppRoute(url: URL(string: "gymblock://workout")!), .workout)
    // `from` is a fixed word or nothing: never free text into analytics.
    XCTAssertEqual(AppRoute.source(URL(string: "gymblock://home")!), "link")
    XCTAssertEqual(AppRoute.source(URL(string: "gymblock://home?from=Sirish%20Joshi")!), "link")
    XCTAssertEqual(AppRoute.source(URL(string: "gymblock://home?from=averyveryverylongword")!), "link")
    XCTAssertEqual(AppRoute.url(.workout, from: "rect").absoluteString, "gymblock://workout?from=rect")
    XCTAssertEqual(AppRoute.url(.home, from: "Bad Word").absoluteString, "gymblock://home?from=link")
  }

  func testRouterHoldsThroughLaunchAndDropsOutsideTheApp() {
    let router = AppRouter()
    router.openURL(URL(string: "gymblock://profile?from=month")!)
    XCTAssertNil(router.ready)  // The splash is still up.
    router.screen = .app
    XCTAssertEqual(router.ready?.route, .profile)
    router.consume(router.ready!)
    XCTAssertNil(router.ready)
    // Onboarding, sign-in, a notice or the offer drop it, and it doesn't come back.
    router.screen = .launch
    router.openURL(URL(string: "gymblock://workout?from=small")!)
    router.screen = .other
    router.screen = .app
    XCTAssertNil(router.ready)
    // While on them, nothing is held at all.
    router.screen = .other
    router.open(.start, source: "control")
    router.screen = .app
    XCTAssertNil(router.ready)
  }

  func testStartByLinkIsRefusedWhenLinksCantStart() {
    let router = AppRouter()
    router.screen = .app
    router.settled = true
    router.linksStart = false  // Release.
    router.openURL(URL(string: "gymblock://start?from=test")!)
    XCTAssertNil(router.ready)
    // The control still can.
    router.open(.start, source: "control")
    XCTAssertEqual(router.ready?.route, .start)
    router.consume(router.ready!)
    router.linksStart = true  // Debug.
    router.openURL(URL(string: "gymblock://start?from=test")!)
    XCTAssertEqual(router.ready?.route, .start)
  }

  func testStartWaitsUntilTheOfferWallCantFollow() {
    let router = AppRouter()
    // The hold's 4-second cap let the app show before the entitlement answered.
    router.screen = .app
    router.open(.start, source: "control")
    XCTAssertNil(router.ready)
    // Answered with Pro: the start goes on (HomeView still drops it if it's no longer fresh).
    router.settled = true
    XCTAssertEqual(router.ready?.route, .start)
    router.consume(router.ready!)
    // Answered without: the offer wall drops it, and it doesn't come back.
    router.settled = false
    router.open(.start, source: "control")
    router.screen = .other
    router.screen = .app
    router.settled = true
    XCTAssertNil(router.ready)
    // Other routes only move between pages, so they don't wait.
    router.settled = false
    router.open(.profile, source: "month")
    XCTAssertEqual(router.ready?.route, .profile)
  }

  func testStartRequestGoesStaleAfterTenSeconds() {
    XCTAssertTrue(AppRouter.Request(route: .start, at: Date().addingTimeInterval(-9)).fresh)
    XCTAssertFalse(AppRouter.Request(route: .start, at: Date().addingTimeInterval(-11)).fresh)
  }

  // MARK: What a widget shows at an entry's date

  func testGlancePhaseClockAndRoute() {
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let s = running(lastActivity: start)
    let until = s.running!.activeUntil
    XCTAssertEqual(WidgetGlance(s, at: start).phase, .running)
    XCTAssertEqual(WidgetGlance(s, at: until.addingTimeInterval(-1)).phase, .running)
    XCTAssertEqual(WidgetGlance(s, at: until).phase, .stale)
    // The clock's range ends where the stale entry takes over.
    XCTAssertEqual(WidgetGlance(s, at: start).clock.upperBound, until)
    XCTAssertEqual(WidgetGlance(s, at: start).route, .workout)
    XCTAssertEqual(WidgetGlance(s, at: until).route, .workout)
    var paused = s
    paused.running?.pausedAt = start
    XCTAssertEqual(WidgetGlance(paused, at: start).phase, .paused)
    var idle = s
    idle.state = .idle
    idle.running = nil
    XCTAssertEqual(WidgetGlance(idle, at: start).phase, .idle)
    XCTAssertEqual(WidgetGlance(idle, at: start).route, .home)
    XCTAssertEqual(WidgetGlance(nil, at: start).phase, .setup)
    XCTAssertEqual(WidgetGlance(nil, at: start).route, .home)
  }

  func testGlanceWeekLabelFollowsHome() {
    let now = Date()
    var s = WidgetSnapshot(
      state: .idle, hero: "Push", sample: false, days: [], baseWeek: TrainingDays.key(TrainingDays.monday(of: now)),
      priorRun: 0, goal: 4, hasHistory: false, labels: .init(t: { $0 }))
    XCTAssertEqual(WidgetGlance(s, at: now).weekLabel, "Week 1")
    s.hasHistory = true
    XCTAssertEqual(WidgetGlance(s, at: now).weekLabel, "0 of 4 this week")
    s.days = [TrainingDays.key(now)]
    XCTAssertEqual(WidgetGlance(s, at: now).weekLabel, "1 week streak")
    s.priorRun = 2
    XCTAssertEqual(WidgetGlance(s, at: now).weekLabel, "3 week streak")
    // Sample history is always marked where it shows.
    s.sample = true
    XCTAssertEqual(WidgetGlance(s, at: now).caption, "Sample data")
    XCTAssertEqual(WidgetGlance(s, at: now).detail, "Sample data")
  }
}
