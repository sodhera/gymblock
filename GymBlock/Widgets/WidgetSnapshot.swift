import Foundation

/// The widget kinds. Permanent once someone has placed a widget: never rename them.
enum WidgetKind {
  static let upNext = "com.sodhera.gymblock.upnext", month = "com.sodhera.gymblock.month"
  static let week = "com.sodhera.gymblock.week", startControl = "com.sodhera.gymblock.control.start"
}

/// What the widgets know, written by the app into the App Group (the extension can't read the store).
/// Small and already in the reader's language: the app translates every string with `t()`. Dates stay
/// raw, so each timeline entry works out its own today ring, week and streak. Never the user's name,
/// an email, Screen Time tokens, set or rest state, or whether apps are blocked (that can change
/// behind the snapshot's back). Split names are the user's own text: they stay on the device.
struct WidgetSnapshot: Codable, Equatable {
  static let group = "group.com.sodhera.gymblock", key = "gymblock.widget.v1"
  /// Setup: not onboarded, logged out or deleted.
  enum State: String, Codable { case setup, idle, running }
  struct Running: Codable, Equatable {
    var exercise: String?        // t(selected.name); nil while choosing
    var clockStart: Date         // started + (pausedSeconds ?? 0)
    var pausedAt: Date?
    var lastActivity: Date       // GymStore.lastActivity
    /// The app's "Still working out?" hour, plus up to 15 minutes of Lock Screen sets that only move
    /// `lastActivity` and so don't reload the widget: never early, at most 15 minutes late.
    var activeUntil: Date { lastActivity.addingTimeInterval(3600 + 900) }
  }
  struct Labels: Codable, Equatable {
    var upNext, paused, stillWorkingOut, chooseExercise, training, sampleData, openGymBlock: String
    var weekStreak, weekStreakOne, week1, of, thisWeek, workout, workouts, startWorkout: String
  }
  var version = 1
  var state: State
  var hero: String              // idle: t(split.name) | t("Free workout") | t("Your first workout"); running: t(session.name)
  var heroShort: String?        // Spanish.widgetShort form when profile.language == "es" and one exists
  var detail: String?           // idle: summary(of: split) or t("Pick exercises as you go.")
  var caption: String?          // idle with split: "\(m) " + t("min last time") | t("First time"); else nil
  var sample: Bool              // data.demoLoaded == true
  var days: [Int]               // yyyymmdd of `started`, sessions with completedSets, last 42 days, sorted, unique
  var baseWeek: Int             // yyyymmdd of this Monday at write time
  var priorRun: Int             // consecutive trained Monday-weeks ending the week before baseWeek (uncapped)
  var goal: Int                 // min(7, max(1, baseline?.trainingDays ?? 5))
  var hasHistory: Bool          // any session with completedSets ("Week 1" rule)
  var lastFinished: Date?       // max `ended` of finished sessions (Smart Stack only)
  var running: Running?
  var labels: Labels

  /// The snapshot the app last wrote; nil before the first write (or before the first unlock), or if
  /// it's from a version this build doesn't read.
  static func load() -> WidgetSnapshot? {
    guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
          let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data), snapshot.version == 1
    else { return nil }
    return snapshot
  }

  func save() {
    guard let data = try? JSONEncoder().encode(self) else { return }
    UserDefaults(suiteName: Self.group)?.set(data, forKey: Self.key)
  }
}

extension WidgetSnapshot.Labels {
  /// Every label through one translate closure: the store's `t`, or `Spanish.translate` in the preview.
  init(t: (String) -> String) {
    self.init(
      upNext: t("Up next"), paused: t("Paused"), stillWorkingOut: t("Still working out?"),
      chooseExercise: t("Choose an exercise"), training: t("Training"), sampleData: t("Sample data"),
      openGymBlock: t("Open GymBlock"), weekStreak: t("week streak"), weekStreakOne: t("1 week streak"),
      week1: t("Week 1"), of: t("of"), thisWeek: t("this week"), workout: t("workout"), workouts: t("workouts"),
      startWorkout: t("Start workout"))
  }
}

/// What each widget kind depends on, so the app reloads only the kinds a change touches.
extension WidgetSnapshot {
  /// Up next: everything (the medium shows the week too) except `lastActivity`, which a Lock Screen
  /// set moves without changing what's shown. Its drift is measured separately.
  var upNextKey: WidgetSnapshot {
    var s = self
    s.running?.lastActivity = Date(timeIntervalSinceReferenceDate: 0)
    return s
  }
  struct DaysKey: Equatable {
    let days: [Int], baseWeek: Int, priorRun: Int, goal: Int, hasHistory: Bool, lastFinished: Date?
    let sample: Bool, state: State, labels: Labels
  }
  /// This month and This week.
  var daysKey: DaysKey {
    DaysKey(days: days, baseWeek: baseWeek, priorRun: priorRun, goal: goal, hasHistory: hasHistory,
            lastFinished: lastFinished, sample: sample, state: state, labels: labels)
  }
  struct ControlKey: Equatable { let state: State, hero: String, startWorkout: String }
  /// The Start workout control: its title.
  var controlKey: ControlKey { ControlKey(state: state, hero: hero, startWorkout: labels.startWorkout) }
}
