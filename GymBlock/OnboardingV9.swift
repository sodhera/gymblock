import SwiftUI

// Onboarding V9 (1 Nov 2026): the answers in the person's own words, kept by V10. "And what does
// that cost you?" comes back as the promise's line; "What have you tried?" gets one page of why
// (`WhyStage`, OnboardingV10.swift). Fixed answers only, never free text.

extension CostAnswer {
  /// The row's words (English keys; `store.t` translates).
  var title: String {
    switch self {
    case .runLong: return "My workouts run long"
    case .loseFocus: return "I lose focus between sets"
    case .loseTrack: return "I lose track of my sets"
    case .skipSets: return "I skip the last sets"
    case .homeLate: return "I get home late"
    case .other: return "Something else"
    case .notMuch: return "Not much, honestly"
    }
  }
}

extension TriedAnswer {
  var title: String {
    switch self {
    case .locker: return "Phone in the locker"
    case .limits: return "Screen Time limits"
    case .doNotDisturb: return "Do Not Disturb"
    case .willpower: return "Just willpower"
    case .nothing: return "Nothing yet"
    }
  }
  /// Why it didn't hold, in one plain line: what the fix leaves open, never a guess about them.
  var reason: String {
    switch self {
    case .locker: return "No timer, no log, no music."
    case .limits: return "Ignore Limit is one tap away."
    case .doNotDisturb: return "Stops the pings, not the feed."
    case .willpower: return "Every rest is a fight."
    case .nothing: return ""
    }
  }
}

extension GymStore {
  /// The promise in the words they chose on the cost page, with their own minutes ("Home 35 minutes
  /// earlier."): the same arithmetic as the promise's headline, said back. Nil when they named no cost
  /// or lose nothing, so the caller keeps its own line.
  func promiseLine(_ time: TimeBack, baseline: RoutineBaseline) -> String? {
    guard (time.lostPerRest ?? 0) > 0 else { return nil }
    let minutes = "\(time.shownLost)"
    switch baseline.spokenCost {
    case .homeLate?:
      if time.perRestOnly { return t("Home earlier, every workout.") }
      return time.lostIsAnHour ? t("Home about an hour earlier.") : String(format: t("Home %@ minutes earlier."), minutes)
    case .runLong?:
      if time.perRestOnly { return t("Every rest on time, and a shorter workout.") }
      return time.lostIsAnHour ? t("A workout about an hour shorter.") : String(format: t("A workout %@ minutes shorter."), minutes)
    case .skipSets?: return t("Time for every last set.")
    case .loseTrack?: return t("Every set counted, every rest timed.")
    case .loseFocus?: return t("And your focus back, every set.")
    default: return nil
    }
  }
  /// "1,440 hours", "2 years": hours of life as people feel them.
  func lifeWords(_ hours: Double) -> String {
    let s = LifeWords.span(hours: hours)
    return s.text + " " + t(s.unit)
  }
}
