import Foundation
import WidgetKit

extension GymStore {
  /// What the widgets show, in the reader's language (docs/WIDGETS-PLAN.md §6). Never the user's name,
  /// an email, Screen Time tokens, set or rest state, or blocking; split names stay in the App Group on
  /// this iPhone. Cheap enough for every save: one pass over history, never `homeStats()` or
  /// `exerciseTrends()`.
  func widgetSnapshot(now: Date = Date()) -> WidgetSnapshot {
    let c = TrainingDays.calendar
    let monday = TrainingDays.monday(of: now, c)
    var s = WidgetSnapshot(state: .setup, hero: "", sample: false, days: [], baseWeek: TrainingDays.key(monday, c),
                           priorRun: 0, goal: 5, hasHistory: false, labels: WidgetSnapshot.Labels(t: t))
    // Not onboarded, logged out or deleted: the labels and nothing of the user's, so a wipe clears the
    // Home Screen and the Lock Screen too.
    guard profile.onboarded else { return s }

    // Home's rule: a workout counts once it has a completed set, on the day it started.
    let finished = data.history.filter { !$0.completedSets.isEmpty }
    let weeks = Set(finished.map { TrainingDays.key(TrainingDays.monday(of: $0.started, c), c) })
    // Six weeks of days covers this month, this week and the week the streak formula reads.
    let since = TrainingDays.key(c.date(byAdding: .day, value: -41, to: now) ?? now, c)
    s.days = Set(finished.map { TrainingDays.key($0.started, c) }).filter { $0 >= since }.sorted()
    s.priorRun = c.date(byAdding: .day, value: -7, to: monday).map { TrainingDays.run(endingAt: $0, weeks: weeks, c) } ?? 0
    s.goal = min(7, max(1, profile.baseline?.trainingDays ?? 5))
    s.hasHistory = !finished.isEmpty
    s.lastFinished = finished.compactMap(\.ended).max()
    s.sample = data.demoLoaded == true
    // The Spanish short form, for where the full one can't fit; keyed by the English name.
    let short = { (name: String) in self.profile.language == "es" ? Spanish.widgetShort[name] : nil }

    if let session {
      s.state = .running
      s.hero = t(session.name)
      s.heroShort = short(session.name)
      s.running = .init(exercise: session.selected.map { t($0.name) },
                        clockStart: session.started.addingTimeInterval(session.pausedSeconds ?? 0),
                        pausedAt: session.pausedAt, lastActivity: lastActivity ?? session.started)
      return s
    }

    s.state = .idle
    // Home's split; Home's Free workout pick is view state that's never saved, so it can't be seen here.
    let split = data.workouts.first { $0.id == profile.preferredSplitID } ?? data.workouts.first
    let name = split?.name ?? (s.hasHistory ? "Free workout" : "Your first workout")
    s.hero = t(name)
    s.heroShort = short(name)
    s.detail = summary(of: split)
    if let split {
      s.caption = splitSummary(split).lastMinutes.map { "\($0) " + t("min last time") } ?? t("First time")
    }
    return s
  }
}

/// Writes the snapshot into the App Group and reloads only the widget kinds it changed. Saves come on
/// every keystroke, so an unchanged snapshot stops at once and a changed one lands a second later;
/// a wipe (log out, delete) lands at once, so no split name outlives it. Reloads cost budget only
/// in the background, where Lock Screen sets are the worry: they only move `lastActivity`, which
/// reloads Up next once it has drifted more than 15 minutes.
@MainActor enum WidgetSync {
  private static var written: WidgetSnapshot?
  /// What each kind last reloaded with, so a change reloads only the kinds it touches.
  private static var reloadedUpNext, reloadedDays, reloadedControl: WidgetSnapshot?
  private static var pending: Task<Void, Never>?
  /// Unit tests make their own stores on a shared simulator; they never touch the real widgets.
  private static var enabled: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil }
  #if DEBUG
    /// Reloads asked for this run, by kind: the Lock Screen budget check (VALIDATION.md).
    private(set) static var reloads: [String: Int] = [:]
  #endif

  static func sync(_ store: GymStore) {
    guard enabled, GymStore.live === store else { return }
    let next = store.widgetSnapshot()
    // Per-keystroke saves stop here.
    guard next != written else { return }
    let wiped = next.state == .setup && written?.state != .setup
    written = next
    pending?.cancel()
    // Log out or delete: the names go now, not in a second.
    if wiped { flush(); return }
    pending = Task { @MainActor in
      try? await Task.sleep(for: .seconds(1))
      if !Task.isCancelled { flush() }
    }
  }

  /// Writes now: when the app is about to be suspended (backgrounded, or after a Lock Screen tap), a
  /// pending write would never land.
  static func flush() {
    pending?.cancel()
    pending = nil
    guard enabled, let s = written else { return }
    s.save()
    if upNextNeedsReload(s, since: reloadedUpNext) {
      reload(WidgetKind.upNext)
      reloadedUpNext = s
    }
    if s.daysKey != reloadedDays?.daysKey {
      reload(WidgetKind.month)
      reload(WidgetKind.week)
      reloadedDays = s
    }
    if s.controlKey != reloadedControl?.controlKey {
      if #available(iOS 18.0, *) {
        ControlCenter.shared.reloadControls(ofKind: WidgetKind.startControl)
        count(WidgetKind.startControl)
      }
      reloadedControl = s
    }
  }

  /// Up next reloads when what it shows changes, or when its stale moment (`activeUntil`) has drifted
  /// more than 15 minutes from the one it last reloaded with. `since` moves only on a reload, so the
  /// drift adds up across Lock Screen sets: an hour logged there costs about four reloads.
  nonisolated static func upNextNeedsReload(_ s: WidgetSnapshot, since last: WidgetSnapshot?) -> Bool {
    s.upNextKey != last?.upNextKey || drift(s, last) > 900
  }

  /// How far `lastActivity` has moved, either way: a deleted last set moves it back.
  nonisolated static func drift(_ s: WidgetSnapshot, _ last: WidgetSnapshot?) -> TimeInterval {
    guard let a = s.running?.lastActivity, let b = last?.running?.lastActivity else { return 0 }
    return abs(a.timeIntervalSince(b))
  }

  private static func reload(_ kind: String) {
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
    count(kind)
  }

  private static func count(_ kind: String) {
    #if DEBUG
      reloads[kind, default: 0] += 1
      NSLog("GymBlock widgets: reload \(kind) (\(reloads[kind] ?? 0) this run)")
    #endif
  }
}
