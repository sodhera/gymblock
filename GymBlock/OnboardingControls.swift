import SwiftUI

struct OnboardingStage: View {
  var depth: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    LinearGradient(
      colors: [
        GymColor.adaptive(light: 0xFBF8F5, dark: 0x191617),
        GymColor.adaptive(light: 0xFBF8F5, dark: 0x201819),
        GymColor.adaptive(light: 0xF5E6E4, dark: 0x321F23).opacity(0.45 + depth * 0.35),
      ],
      startPoint: .top, endPoint: .bottom
    )
    .background(GymColor.adaptive(light: 0xFBF8F5, dark: 0x191617))
    .ignoresSafeArea().animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: depth)
    .allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct OnboardingGlass: ViewModifier {
  var tint: Color?
  @Environment(\.accessibilityReduceTransparency) private var opaque
  @Environment(\.colorSchemeContrast) private var contrast
  @ViewBuilder func body(content: Content) -> some View {
    if opaque {
      content.background(tint ?? GymColor.surface, in: Capsule())
        .overlay { Capsule().strokeBorder(GymColor.dim.opacity(0.6), lineWidth: 1) }
    } else if #available(iOS 26.0, *) {
      content.glassEffect(
        tint.map { .regular.tint($0).interactive() } ?? .regular.interactive(), in: .capsule)
    } else {
      content.background(tint ?? .clear, in: Capsule())
        .background(.regularMaterial, in: Capsule())
        .overlay {
          Capsule().strokeBorder(
            GymColor.dim.opacity(contrast == .increased ? 0.6 : 0.15), lineWidth: 1)
        }
    }
  }
}

struct OnboardingGlassStyle: ButtonStyle {
  var primary = false
  var selected = false
  @Environment(\.isEnabled) private var enabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(primary ? Color.white : GymColor.ink)
      .contentShape(Capsule())
      .modifier(
        OnboardingGlass(tint: primary ? GymColor.adaptive(light: 0xC92535, dark: 0xC92535) : nil)
      )
      .overlay { if selected { Capsule().strokeBorder(GymColor.red, lineWidth: 1.5) } }
      .opacity(enabled ? 1 : 0.4)
      .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
  }
}

struct WorkoutMark: View {
  var assembled: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    GeometryReader { g in
      let unit = g.size.width / 116
      ZStack {
        RoundedRectangle(cornerRadius: 32 * unit).fill(GymColor.red.gradient)
          .shadow(color: GymColor.red.opacity(0.15), radius: 24 * unit, y: 12 * unit)
        HStack(spacing: 4 * unit) {
          Capsule().frame(width: 7 * unit, height: 27 * unit)
          Capsule().frame(width: 10 * unit, height: 40 * unit)
          Capsule().frame(width: 20 * unit, height: 8 * unit)
          Capsule().frame(width: 10 * unit, height: 40 * unit)
          Capsule().frame(width: 7 * unit, height: 27 * unit)
        }.foregroundStyle(.white)
          .scaleEffect(assembled || reduceMotion ? 1 : 0.65)
          .opacity(assembled || reduceMotion ? 1 : 0)
      }
    }.accessibilityHidden(true)
  }
}

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
      Form {
        Section {
          Text(store.t("This demo previews focus mode. It doesn't block other apps."))
          Toggle(
            store.t("Focus demo"),
            isOn: Binding(
              get: { store.profile.focusEnabled ?? false },
              set: { flag in
                store.updateProfile { $0.focusEnabled = flag }
              })
          ).accessibilityIdentifier("focus.enabled")
        }
        Section(store.t("Apps you tend to scroll")) {
          ForEach(["Social feeds", "Videos", "News", "Other"], id: \.self) { category in
            Toggle(
              store.t(category),
              isOn: Binding(
                get: { store.profile.baseline?.distractions.contains(category) == true },
                set: { flag in
                  store.updateProfile {
                    var b = $0.baseline ?? RoutineBaseline()
                    b.distractions.removeAll { $0 == category }
                    if flag { b.distractions.append(category) }
                    $0.baseline = b
                  }
                }))
          }
        }
      }.navigationTitle(store.t("Focus demo")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() } }
        }
    }.presentationDetents([.medium, .large])
  }
}
