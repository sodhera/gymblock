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

private struct OnboardingGlass: ViewModifier {
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

struct SurveyNumber: View {
  @EnvironmentObject private var store: GymStore
  let value: Int?
  let unit: String
  let id: String
  let edit: () -> Void
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    VStack(spacing: 8) {
      Button(action: edit) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(value.map(String.init) ?? "—").font(
            GymType.hero(typeSize.isAccessibilitySize ? 52 : 76)
          )
          .monospacedDigit().contentTransition(.numericText())
          Image(systemName: "pencil").font(.system(size: 14)).foregroundStyle(GymColor.dim)
        }.foregroundStyle(GymColor.ink)
      }.buttonStyle(.plain).accessibilityIdentifier(id)
        .accessibilityLabel((value.map(String.init) ?? "—") + " " + unit)
        .accessibilityHint(store.t("Tap to edit"))
      Text(unit).font(GymType.body(16)).foregroundStyle(GymColor.dim).multilineTextAlignment(
        .center)
    }
  }
}

struct WorkoutRhythm: View {
  let count: Int
  var body: some View {
    HStack(spacing: 10) {
      ForEach(0..<7, id: \.self) { i in
        Capsule().fill(i < count ? GymColor.red : GymColor.ink.opacity(0.08))
          .frame(width: 12, height: i < count ? 36 : 20)
      }
      if count > 7 { Text("+\(count - 7)").font(GymType.body(14)) }
    }.frame(height: 38).accessibilityHidden(true)
  }
}

struct VisitRuler: View {
  let value: Int?
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .leading) {
        HStack(alignment: .center, spacing: 0) {
          ForEach(0..<25, id: \.self) { index in
            Rectangle().fill(GymColor.ink.opacity(0.13))
              .frame(width: 1, height: index % 6 == 0 ? 28 : 12).frame(maxWidth: .infinity)
          }
        }
        if let value {
          Capsule().fill(GymColor.red).frame(width: 3, height: 40)
            .offset(x: max(0, min(g.size.width - 3, g.size.width * Double(value) / 120)))
        }
      }
    }.frame(height: 40).accessibilityHidden(true)
  }
}

struct RoutineSketch: View {
  let baseline: RoutineBaseline
  var body: some View {
    let exercises = baseline.exercises ?? baseline.details.count
    let sets = baseline.sets ?? 0
    HStack(alignment: .center, spacing: 10) {
      ForEach(0..<max(3, min(exercises, 8)), id: \.self) { column in
        VStack(spacing: 7) {
          ForEach(0..<max(3, min(sets, 5)), id: \.self) { row in
            Capsule().fill(
              column < exercises && row < sets
                ? GymColor.red.opacity(0.85) : GymColor.ink.opacity(0.07)
            )
            .frame(height: 9)
          }
        }.frame(width: 24)
      }
    }.frame(height: 84).accessibilityHidden(true)
  }
}

struct WorkoutTimeline: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let duration: Int
  let scrolling: Double
  let gain: Double
  var animateEntrance = true
  var compact = false
  @State private var appeared = false
  var body: some View {
    let remaining = max(0, scrolling - gain)
    let freeFraction = max(0, min(1, (Double(duration) - remaining) / Double(max(duration, 1))))
    VStack(spacing: compact ? 8 : 12) {
      Text("\(duration) " + store.t("minute visit")).font(GymType.body(14)).foregroundStyle(
        GymColor.dim)
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 14).fill(GymColor.ink.opacity(0.1))
          RoundedRectangle(cornerRadius: 14).fill(GymColor.red.gradient)
            .frame(
              width: max(
                0,
                geometry.size.width * freeFraction
                  * (appeared || reduceMotion || !animateEntrance ? 1 : 0)))
          HStack(spacing: 0) {
            ForEach(0..<30, id: \.self) { _ in
              Rectangle().fill(.white.opacity(0.22)).frame(width: 1).frame(maxWidth: .infinity)
            }
          }.padding(.vertical, 14)
        }.clipShape(RoundedRectangle(cornerRadius: 14))
          .opacity(appeared || reduceMotion ? 1 : 0)
          .offset(y: appeared || reduceMotion ? 0 : 8)
      }.frame(height: compact ? 44 : 66)
      HStack {
        Label(store.t("Phone-free"), systemImage: "circle.fill").foregroundStyle(GymColor.red)
        Spacer()
        if remaining > 0 {
          Label(store.t("Scrolling"), systemImage: "circle").foregroundStyle(GymColor.dim)
        }
      }.font(GymType.body(13))
    }.accessibilityElement(children: .ignore)
      .accessibilityLabel(
        store.t("minute visit") + ": \(duration). " + store.t("Phone-free") + ": "
          + OnboardingView.minutes(Double(duration) - remaining) + ". " + store.t("Scrolling")
          + ": " + OnboardingView.minutes(remaining)
      )
      .onAppear {
        withAnimation(reduceMotion || !animateEntrance ? nil : .easeOut(duration: 1)) {
          appeared = true
        }
      }
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

struct SurveyEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let field: SurveyField
  let baseline: RoutineBaseline
  let save: (String) -> Void
  @State private var value = ""
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(store.t(field.title), text: $value)
            .keyboardType(field == .reps ? .numbersAndPunctuation : .numberPad)
            .accessibilityIdentifier(field.controlID + ".manual")
          if typeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) { presets }
          } else {
            HStack { presets }
          }

          if !field.valid(value, baseline: baseline) {
            Text(store.t(field.validationText(baseline))).foregroundStyle(GymColor.red)
          }
        }
        if field != .breaks {
          Button(store.t("Not sure")) {
            save("")
            dismissKeyboard()
            dismiss()
          }
        }
        if field == .breaks {
          Button(store.t("Use every break")) {
            save("")
            dismissKeyboard()
            dismiss()
          }
        }
      }.navigationTitle(store.t(field.title)).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(store.t("Cancel")) {
              dismissKeyboard()
              dismiss()
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) {
              save(value)
              dismissKeyboard()
              dismiss()
            }.disabled(!field.valid(value, baseline: baseline))
              .accessibilityIdentifier("survey.done")
          }
        }
        .onAppear { value = field.read(baseline) }
        .onDisappear { dismissKeyboard() }
    }.presentationDetents([.medium, .large])
  }
  private var presets: some View {
    ForEach(field.choices, id: \.self) { choice in
      Button(choice) {
        value = choice
        OnboardingFeedback.shared.play(profile: store.profile, selection: true)
      }
      .buttonStyle(.borderless).disabled(!field.valid(choice, baseline: baseline))
      .frame(maxWidth: .infinity, minHeight: 44)
      .accessibilityIdentifier(field.controlID + "." + choice)
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

struct OneSetPreview: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var stage = 0
  @State private var reps = 10
  @State private var restStarted = Date()
  var body: some View {
    NavigationStack {
      VStack(spacing: 28) {
        Spacer()
        Text(store.t("Dumbbell curl")).font(GymType.title(28))
        if stage == 2 {
          TimelineView(.periodic(from: restStarted, by: 1)) { context in
            Text(
              "0:"
                + String(format: "%02d", max(0, Int(context.date.timeIntervalSince(restStarted))))
            )
            .font(GymType.hero(52)).monospacedDigit()
          }
          Text(store.t("Rest elapsed")).foregroundStyle(GymColor.dim)
        } else {
          Text("10 kg").font(GymType.hero(52))
          if stage == 1 {
            Stepper("\(reps) " + store.t("reps"), value: $reps, in: 0...999).padding(.horizontal)
          }
        }
        Spacer()
        Button(store.t(stage == 1 ? "Stop set" : stage == 2 ? "Start again" : "Start set")) {
          if stage == 1 {
            stage = 2
            restStarted = .now
          } else {
            stage = 1
          }
          OnboardingFeedback.shared.play(profile: store.profile, selection: true)
        }.font(GymType.label(17)).frame(maxWidth: .infinity, minHeight: 58)
          .buttonStyle(OnboardingGlassStyle(primary: true)).accessibilityIdentifier("example.set")
      }.padding(24).background(OnboardingStage(depth: 1))
        .navigationTitle(store.t("Example")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() } }
        }
    }.presentationDetents([.medium, .large])
  }
}
