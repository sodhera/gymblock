import SwiftUI

enum SurveyField: String, Identifiable {
  case visits, duration, exercises, sets, reps, minutes, breaks
  var id: String { rawValue }
  var title: String {
    switch self {
    case .visits: return "Workouts per week"
    case .duration: return "Visit minutes"
    case .exercises: return "Exercises"
    case .sets: return "Sets each"
    case .reps: return "Reps"
    case .minutes: return "Minutes per break"
    case .breaks: return "Scrolling breaks"
    }
  }
  var controlID: String {
    switch self {
    case .minutes: return "baseline.break.minutes"
    case .breaks: return "baseline.break.count"
    default: return "baseline." + rawValue
    }
  }
  var choices: [String] {
    switch self {
    case .visits: return ["2", "3", "4", "5"]
    case .duration: return ["30", "45", "60", "90"]
    case .exercises: return ["3", "4", "5", "6"]
    case .sets: return ["2", "3", "4", "5"]
    case .reps: return ["6", "8", "10", "8–12"]
    case .minutes: return ["6", "7", "8", "10"]
    case .breaks: return ["0", "3", "5", "10"]
    }
  }
  func read(_ b: RoutineBaseline) -> String {
    switch self {
    case .visits: return b.visits.map(String.init) ?? ""
    case .duration: return b.duration.map(String.init) ?? ""
    case .exercises:
      return b.details.isEmpty ? (b.exercises.map(String.init) ?? "") : String(b.details.count)
    case .sets:
      if !b.details.isEmpty {
        let values = Set(b.details.map(\.sets))
        return values.count == 1 ? b.details.first?.sets.map(String.init) ?? "" : ""
      }
      return b.sets.map(String.init) ?? ""
    case .reps:
      if !b.details.isEmpty {
        let values = Set(b.details.map(\.reps))
        return values.count == 1 ? b.details.first?.reps ?? "" : ""
      }
      return b.reps
    case .minutes: return b.minutesPerBreak.map(String.init) ?? ""
    case .breaks: return b.scrollingBreaks.map(String.init) ?? ""
    }
  }
  func write(_ value: String, into b: inout RoutineBaseline) {
    if [.exercises, .sets, .reps].contains(self), !b.details.isEmpty {
      let count = b.details.count
      let commonSets = Int(SurveyField.sets.read(b))
      let commonReps = SurveyField.reps.read(b)
      b.exercises = count
      b.sets = commonSets
      b.reps = commonReps
      b.details = []
    }
    switch self {
    case .visits: b.visits = Int(value)
    case .duration: b.duration = Int(value)
    case .exercises:
      b.exercises = Int(value)
      b.details = []
    case .sets:
      b.sets = Int(value)
      b.details = []
    case .reps:
      b.reps = value
      b.details = []
    case .minutes: b.minutesPerBreak = Int(value)
    case .breaks: b.scrollingBreaks = Int(value)
    }
  }
  func valid(_ text: String, baseline: RoutineBaseline) -> Bool {
    if text.isEmpty { return true }
    if self == .reps { return RoutineBaseline.repRange(text) != nil }
    guard let n = Int(text) else { return false }
    switch self {
    case .visits: return (0...21).contains(n)
    case .duration, .minutes: return (1...600).contains(n)
    case .exercises, .sets: return (1...50).contains(n)
    case .breaks: return (0...(baseline.breakCount ?? 2500)).contains(n)
    case .reps: return false
    }
  }
  func validationText(_ b: RoutineBaseline) -> String {
    switch self {
    case .reps: return "Use a rep count or range, such as 8–12."
    case .visits: return "0–21"
    case .duration, .minutes: return "1–600"
    case .exercises, .sets: return "1–50"
    case .breaks: return "0–\(b.breakCount ?? 2500)"
    }
  }
}

struct FocusPreview: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      FocusSettingsForm().toolbar {
        ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() } }
      }
    }.presentationDetents([.medium, .large])
  }
}
