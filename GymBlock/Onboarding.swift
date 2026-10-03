import SwiftUI

struct OnboardingView: View {
  @EnvironmentObject private var store: GymStore
  @State private var details = false
  @State private var why = false
  @State private var goal = false
  @State private var pendingCount: Int?
  @State private var reduceDetails = false
  private var step: Int { min(6, store.profile.onboardingStep) }
  private var baseline: RoutineBaseline { store.profile.baseline ?? RoutineBaseline() }
  private func update(_ body: (inout RoutineBaseline) -> Void) {
    store.updateProfile { p in
      var b = p.baseline ?? RoutineBaseline()
      body(&b)
      if let goal = b.reductionGoal, goal > (b.scrolling ?? 0) { b.reductionGoal = nil }
      p.baseline = b
    }
  }
  private func number(_ path: WritableKeyPath<RoutineBaseline, Int?>) -> Binding<Int?> {
    Binding(
      get: { baseline[keyPath: path] },
      set: { value in
        if path == \.exercises, let value, (1...50).contains(value), !baseline.details.isEmpty,
          value < baseline.details.count
        {
          pendingCount = value
          reduceDetails = true
        } else {
          update { b in
            b[keyPath: path] = value
            if path == \.exercises, let value, !b.details.isEmpty, value > b.details.count,
              value <= 50
            {
              b.details += (b.details.count..<value).map { _ in
                BaselineExercise(sets: b.sets, reps: b.reps)
              }
            }
          }
        }
      })
  }
  private var problem: String? {
    if let n = baseline.duration, !(1...600).contains(n) {
      return "Enter 1–600 minutes, or leave it blank."
    }
    if let n = baseline.visits, !(0...21).contains(n) {
      return "Enter 0–21 visits, or leave it blank."
    }
    if let n = baseline.exercises, !(1...50).contains(n) {
      return "Enter 1–50 exercises, or leave it blank."
    }
    if let n = baseline.sets, !(1...50).contains(n) { return "Enter 1–50 sets, or leave it blank." }
    if !baseline.timed && !baseline.reps.isEmpty && RoutineBaseline.repRange(baseline.reps) == nil {
      return "Use a rep count or range, such as 8–12."
    }
    if let n = baseline.scrolling, !(0...600).contains(n) {
      return "Enter 0–600 minutes, or leave it blank."
    }
    if !baseline.scrollingValid { return "Scrolling time exceeds your visit. Edit either answer." }
    return nil
  }
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            if step > 0 {
              HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                  Capsule().fill(index <= step ? GymColor.red : GymColor.ink.opacity(0.08)).frame(
                    height: 3)
                }
              }.accessibilityHidden(true).padding(.bottom, 4)
            }
            content
            if let problem {
              Text(store.t(problem)).font(GymType.body(13)).foregroundStyle(GymColor.red)
                .accessibilityIdentifier("onboarding.error")
            }
          }.padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 24)
        }.scrollDismissesKeyboard(.interactively)
        VStack(spacing: 8) {
          GymButton(
            title: store.t(step == 5 ? "Set up focus" : step == 6 ? "Try demo" : "Continue"),
            enabled: problem == nil, id: "onboarding.continue"
          ) { advance() }
          Button(store.t(step >= 5 ? "Start without blocking" : "Skip setup")) {
            complete(focus: false)
          }
          .frame(minHeight: 44).font(GymType.body(15)).accessibilityIdentifier("onboarding.skip")
        }.padding(.horizontal, 24).padding(.bottom, 12)
      }
      .gymPage().navigationTitle(step == 0 ? "GymBlock" : "")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if step > 0 {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              let previous =
                step == 5 && baseline.distractions.contains("None") ? 3 : max(0, step - 1)
              store.updateProfile { $0.onboardingStep = previous }
            } label: {
              Image(systemName: "chevron.left")
            }.accessibilityLabel(store.t("Back")).accessibilityIdentifier("onboarding.back")
          }
        }
      }
      .confirmationDialog(
        store.t("Remove extra exercise answers?"), isPresented: $reduceDetails,
        titleVisibility: .visible
      ) {
        Button(store.t("Remove extra answers"), role: .destructive) {
          if let count = pendingCount {
            update {
              $0.exercises = count
              $0.details = Array($0.details.prefix(count))
            }
          }
        }
        Button(store.t("Keep answers"), role: .cancel) {}
      }
      .sheet(isPresented: $goal) { GoalEditor() }
      .sheet(isPresented: $details) { RoutineDetailEditor() }
      .sheet(isPresented: $why) {
        NavigationStack {
          Text(
            store.t(
              "Keep your attention on the movement and the muscle you're working. This demo previews focus mode; it doesn't measure attention or predict muscle gain."
            )
          ).padding(24).gymPage().navigationTitle(store.t("Why focus?"))
            .navigationBarTitleDisplayMode(
              .inline
            ).toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button(store.t("Done")) { why = false }
              }
            }
        }.presentationDetents([.medium])
      }
      .onAppear {
        store.updateProfile {
          if $0.language.isEmpty {
            $0.language = Locale.preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
          }
          if $0.onboardingVersion != 2 {
            $0.onboardingStep = 0
            $0.onboardingVersion = 2
          }
          if $0.baseline == nil { $0.baseline = RoutineBaseline() }
        }
      }
    }
  }
  private func title(_ text: String, subtitle: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(store.t(text)).font(GymType.hero(32)).fixedSize(
        horizontal: false, vertical: true
      ).accessibilityAddTraits(.isHeader)
      if let subtitle {
        Text(store.t(subtitle)).font(GymType.body(17)).foregroundStyle(GymColor.dim)
          .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
      }
    }
  }
  @ViewBuilder private var content: some View {
    switch step {
    case 0:
      Image(systemName: "dumbbell.fill").font(.system(size: 32, weight: .medium))
        .foregroundStyle(.white).frame(width: 80, height: 80)
        .background(GymColor.red, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: GymColor.red.opacity(0.18), radius: 20, y: 10)
        .accessibilityHidden(true).padding(.top, 24).padding(.bottom, 8)
      title(
        "Your workout deserves your attention.",
        subtitle: "A quick scroll can become a long break. Keep your attention on the next rep.")
      VStack(alignment: .leading, spacing: 16) {
        Picker(
          store.t("Language"),
          selection: Binding(
            get: { store.profile.language },
            set: { value in store.updateProfile { $0.language = value } })
        ) {
          Text("English").tag("en")
          Text("Español").tag("es")
        }.pickerStyle(.menu).accessibilityIdentifier("onboarding.language")
        TextField(
          store.t("What should we call you?"),
          text: Binding(
            get: { store.profile.name },
            set: { value in store.updateProfile { $0.name = String(value.prefix(40)) } })
        )
        .textContentType(.givenName).textFieldStyle(.roundedBorder).accessibilityIdentifier(
          "name.field")
        Text(store.t("Optional. No account needed.")).font(GymType.body(13)).foregroundStyle(
          GymColor.dim)
      }.padding(20).frame(maxWidth: .infinity, alignment: .leading).gymCard()
    case 1:
      title("Where do you get caught scrolling?")
      VStack(spacing: 0) {
        ForEach(
          [
            "Short videos", "Social feeds", "Video platforms", "News & forums", "Other", "None",
            "Not sure",
          ], id: \.self
        ) { category in
          Button {
            update { b in
              if ["None", "Not sure"].contains(category) {
                b.distractions = [category]
                if category == "None" { b.scrolling = 0 } else { b.scrolling = nil }
              } else {
                b.distractions.removeAll { ["None", "Not sure"].contains($0) }
                if b.distractions.contains(category) {
                  b.distractions.removeAll { $0 == category }
                } else {
                  b.distractions.append(category)
                }
                b.scrolling = nil
              }
            }
          } label: {
            HStack {
              Text(store.t(category)).foregroundStyle(GymColor.ink)
              Spacer()
              if baseline.distractions.contains(category) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(GymColor.red)
              } else {
                Image(systemName: "circle").foregroundStyle(GymColor.dim.opacity(0.35))
              }
            }.frame(minHeight: 50)
          }
          .accessibilityIdentifier("distraction." + category).accessibilityAddTraits(
            baseline.distractions.contains(category) ? .isSelected : [])
          Divider()
        }
      }.padding(.horizontal, 20).padding(.vertical, 8).gymCard()
    case 2:
      title("How long is a usual gym visit?", subtitle: "From starting your workout to finishing.")
      BaselineNumber(
        title: "Minutes", value: number(\.duration), choices: [30, 45, 60, 90],
        id: "baseline.duration")
      BaselineNumber(
        title: "Workouts per week", value: number(\.visits), choices: [2, 3, 4, 5],
        id: "baseline.visits")
    case 3:
      title("What does a usual workout look like?")
      Toggle(
        store.t("Mostly timed exercise"),
        isOn: Binding(get: { baseline.timed }, set: { value in update { $0.timed = value } })
      ).accessibilityIdentifier("baseline.timed")
      BaselineNumber(
        title: "Exercises", value: number(\.exercises), choices: [3, 4, 5, 6],
        id: "baseline.exercises")
      BaselineNumber(
        title: "Sets per exercise", value: number(\.sets), choices: [2, 3, 4], id: "baseline.sets")
      if !baseline.timed {
        VStack(alignment: .leading, spacing: 8) {
          Text(store.t("Reps per set")).font(GymType.body(15))
          TextField(
            store.t("Count or range · 8–12"),
            text: Binding(
              get: { baseline.reps },
              set: { value in update { $0.reps = String(value.prefix(15)) } })
          ).textFieldStyle(.roundedBorder).accessibilityIdentifier("baseline.reps")
          HStack {
            ForEach(["5", "8", "10", "12"], id: \.self) { value in
              Button(value) { update { $0.reps = value } }.buttonStyle(.bordered).tint(
                baseline.reps == value ? GymColor.red : .secondary)
            }
            Button(store.t("Varies")) { update { $0.reps = "" } }.font(GymType.body(13))
          }
        }.padding(20).gymCard()
      }
      Button(store.t("Different for each exercise?")) { details = true }.frame(minHeight: 44)
        .accessibilityIdentifier("baseline.details")
      if !baseline.details.isEmpty {
        Text(store.t("Individual exercise answers saved")).font(GymType.body(13)).foregroundStyle(
          GymColor.dim)
      }
    case 4:
      title(
        "How much of that visit goes to scrolling?",
        subtitle: "Think feeds and videos, not music or logging sets.")
      BaselineNumber(
        title: "Minutes on feeds", value: number(\.scrolling), choices: [0, 5, 10, 15],
        id: "baseline.scrolling")
    case 5:
      title(
        (baseline.scrolling ?? 0) > 0
          ? "Make more room for your workout." : "Keep your workout simple.")
      if let total = baseline.weeklyFeedMinutes {
        Text("\(total) " + store.t("min/week on feeds")).font(GymType.hero(24))
          .accessibilityIdentifier("baseline.result")
        Text(
          store.t("Based on your estimate:") + " \(baseline.scrolling ?? 0) "
            + store.t("min/workout")
        ).font(GymType.body(13)).foregroundStyle(GymColor.dim)
      } else if let minutes = baseline.scrolling {
        Text("\(minutes) " + store.t("min/workout on feeds")).font(GymType.hero(24))
      } else {
        Text(store.t("Find your rhythm over your next few workouts.")).foregroundStyle(
          GymColor.dim)
      }
      DisclosureGroup(store.t("Your routine")) {
        BaselineSummary(baseline: baseline).padding(.top, 8)
      }
      Text(store.t("Keep the rest you need. Leave the feed for later.")).font(GymType.body(15))
      if let minutes = baseline.scrolling, minutes > 0 {
        Menu {
          ForEach([5, 10, 15].filter { $0 <= minutes }, id: \.self) { value in
            Button("\(value) " + store.t("fewer feed minutes per workout")) {
              update { $0.reductionGoal = value }
            }
          }
          Button(store.t("Custom goal")) { goal = true }.accessibilityIdentifier(
            "baseline.customgoal")
          Button(store.t("No goal")) { update { $0.reductionGoal = nil } }
        } label: {
          Text(
            baseline.reductionGoal.map {
              store.t("Goal:") + " \($0) " + store.t("fewer feed minutes per workout")
            } ?? store.t("Choose a goal"))
        }.frame(minHeight: 44).accessibilityIdentifier("baseline.goalmenu")
      }
      Button(store.t("Why focus?")) { why = true }.frame(minHeight: 44)
    default:
      title(
        "Try workout focus", subtitle: "This demo previews focus mode. It doesn't block other apps."
      )
      Text(store.t("You can end your workout whenever you need to.")).foregroundStyle(
        GymColor.dim)
    }
  }
  private func advance() {
    dismissKeyboard()
    if step == 6 {
      complete(focus: true)
    } else {
      let next = step == 3 && baseline.distractions.contains("None") ? 5 : step + 1
      store.updateProfile { $0.onboardingStep = next }
    }
  }
  private func complete(focus: Bool) {
    dismissKeyboard()
    store.updateProfile {
      $0.name = $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
      $0.onboarded = true
      $0.focusEnabled = focus
      $0.onboardingStep = 6
    }
  }
}
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
      Button("\(n)") { value = n }.buttonStyle(.bordered).tint(
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
          store.updateProfile { $0.baseline?.details = [] }
          dismiss()
        }
      }.gymPage().navigationTitle(store.t("Each exercise")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Save")) {
              store.updateProfile { $0.baseline?.details = rows }
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
          choices: [1, 2, 5, 10].filter { $0 <= (store.profile.baseline?.scrolling ?? 0) },
          id: "baseline.goal")
      }
      .gymPage().navigationTitle(store.t("Choose a goal")).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(store.t("Save")) {
            store.updateProfile { $0.baseline?.reductionGoal = value }
            dismiss()
          }.disabled(
            value == nil || value! < 1 || value! > (store.profile.baseline?.scrolling ?? 0)
          )
          .accessibilityIdentifier("baseline.goal.save")
        }
      }
      .onAppear { value = store.profile.baseline?.reductionGoal }
    }.presentationDetents([.medium])
  }
}
