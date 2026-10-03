import SwiftUI

struct BaselineNumber: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @ScaledMetric(relativeTo: .body) private var fieldWidth = 72.0
  @EnvironmentObject private var store: GymStore
  let title: String
  @Binding var value: Int?
  let choices: [Int]
  let id: String
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(store.t(title)).font(GymType.body(15))
        Spacer()
        TextField(
          "—", text: Binding(get: { value.map(String.init) ?? "" }, set: { value = Int($0) })
        ).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: fieldWidth)
          .textFieldStyle(.roundedBorder).accessibilityLabel(store.t(title))
          .accessibilityIdentifier(id)
      }
      if typeSize.isAccessibilitySize {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))]) { quickChoices }
        unknownChoice
      } else {
        HStack {
          quickChoices
          unknownChoice
        }
      }
    }.padding(20).gymCard()
  }
  private var quickChoices: some View {
    ForEach(choices, id: \.self) { n in
      Button("\(n)") {
        value = n
        OnboardingFeedback.shared.play(profile: store.profile, selection: true)
      }.buttonStyle(.bordered).tint(
        value == n ? GymColor.red : .secondary
      ).accessibilityIdentifier(id + ".\(n)")
    }
  }
  private var unknownChoice: some View {
    Button(store.t("Not sure")) { value = nil }.font(GymType.body(13)).frame(minHeight: 44)
      .accessibilityIdentifier(id + ".unknown")
  }
}

struct BaselineSummary: View {
  @EnvironmentObject private var store: GymStore
  var baseline: RoutineBaseline
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let duration = baseline.duration { Text("\(duration) " + store.t("min/workout")) }
      if let total = baseline.weeklyGymMinutes { Text("\(total) " + store.t("gym min/week")) }
      if let total = baseline.totalSets {
        Text(store.t("About") + " \(total) " + store.t("sets/workout"))
      }
      if let range = baseline.totalReps {
        Text(
          (range.lowerBound == range.upperBound
            ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)") + " "
            + store.t("estimated reps/workout"))
      }
      if baseline.duration == nil && baseline.totalSets == nil {
        Text(store.t("Not supplied")).foregroundStyle(GymColor.dim)
      }
    }.font(GymType.body(15)).frame(maxWidth: .infinity, alignment: .leading)
  }
}
struct RoutineDetailEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var rows: [BaselineExercise] = []
  var body: some View {
    NavigationStack {
      Form {
        ForEach($rows) { $row in
          Section {
            TextField(store.t("Exercise name (optional)"), text: $row.name)
            TextField(
              store.t("Sets"),
              text: Binding(get: { row.sets.map(String.init) ?? "" }, set: { row.sets = Int($0) })
            ).keyboardType(.numberPad)
            TextField(store.t("Reps · 8–12 or 12,10,8"), text: $row.reps)
          }
        }
        Button(store.t("Use typical values instead")) {
          store.updateProfile {
            $0.baseline?.details = []
            $0.baseline?.goalMinutesPerBreak = nil
            $0.baseline?.reductionGoal = nil
            $0.onboardingPreviewTarget = nil
          }
          dismiss()
        }
      }.gymPage().navigationTitle(store.t("Each exercise")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Save")) {
              store.updateProfile {
                $0.baseline?.details = rows
                $0.baseline?.goalMinutesPerBreak = nil
                $0.baseline?.reductionGoal = nil
                $0.onboardingPreviewTarget = nil
              }
              dismiss()
            }.disabled(
              !rows.allSatisfy(\.valid))
          }
        }
        .onAppear {
          let b = store.profile.baseline ?? RoutineBaseline()
          if !b.details.isEmpty {
            rows = b.details
          } else {
            rows = (0..<min(50, b.exercises ?? 1)).map { _ in
              BaselineExercise(sets: b.sets, reps: b.reps)
            }
          }
        }
    }
  }
}
func dismissKeyboard() {
  UIApplication.shared.sendAction(
    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct GoalEditor: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var value: Int?
  var body: some View {
    NavigationStack {
      Form {
        BaselineNumber(
          title: "Fewer feed minutes per workout", value: $value,
          choices: [1, 2, 5, 10].filter { $0 <= (store.profile.baseline?.feedMinutes ?? 0) },
          id: "baseline.goal")
      }
      .gymPage().navigationTitle(store.t("Choose a goal")).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(store.t("Save")) {
            store.updateProfile {
              $0.baseline?.reductionGoal = value
              $0.baseline?.goalMinutesPerBreak = nil
            }
            dismiss()
          }.disabled(
            value == nil || value! < 1 || value! > (store.profile.baseline?.feedMinutes ?? 0)
          )
          .accessibilityIdentifier("baseline.goal.save")
        }
      }
      .onAppear { value = store.profile.baseline?.reductionGoal }
    }.presentationDetents([.medium])
  }
}
