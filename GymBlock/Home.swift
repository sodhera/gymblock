import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @State private var settings = false
  var onSplits: () -> Void = {}
  @State private var consistency = false
  private var split: Workout? {
    store.data.workouts.first { $0.id == store.profile.preferredSplitID }
  }
  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 28) {
          HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
              Text(greeting).font(GymType.hero(28)).foregroundStyle(GymColor.ink)
                .accessibilityAddTraits(.isHeader)
              if store.data.demoLoaded == true {
                Text(store.t("Demo")).font(GymType.body(12)).foregroundStyle(GymColor.dim)
              }
            }
            Spacer(minLength: 0)
            Button {
              settings = true
            } label: {
              Image(systemName: "gearshape").font(.system(size: 18, weight: .medium))
                .foregroundStyle(GymColor.ink).frame(width: 44, height: 44)
            }.buttonStyle(.bordered).buttonBorderShape(.circle)
              .accessibilityLabel(store.t("Settings")).accessibilityIdentifier("home.preferences")
          }
          streakCard
          Menu {
            Button(store.t("Free workout")) { store.updateProfile { $0.preferredSplitID = nil } }
            ForEach(store.data.workouts) { split in
              Button(split.name) { store.updateProfile { $0.preferredSplitID = split.id } }
            }
            Divider()
            Button(store.t("Manage splits")) { onSplits() }
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 6) {
                Text(split?.name ?? store.t("Free workout")).font(GymType.title(24))
                  .foregroundStyle(GymColor.ink).multilineTextAlignment(.leading)
                Text(
                  split.map { "\($0.exercises.count) " + store.t("exercises") }
                    ?? store.t("Choose exercises as you go")
                )
                .font(GymType.body(15)).foregroundStyle(GymColor.dim)
                .multilineTextAlignment(.leading)
              }
              Spacer(minLength: 8)
              Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GymColor.dim)
            }.frame(minHeight: 60).contentShape(Rectangle())
          }.accessibilityIdentifier("home.workout").padding(.top, 8)
        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
      }.gymPage().toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
          GymButton(title: store.t("Start workout"), id: "home.start") {
            store.startSession(workout: split)
          }.padding(.horizontal, 24).padding(.vertical, 16)
        }
        .sheet(isPresented: $settings) { PreferencesView() }
        .sheet(isPresented: $consistency) {
          NavigationStack {
            List {
              Text(
                store.t(
                  "A week counts when you finish at least one set. Rest days don't break your streak."
                ))
              ForEach(store.weekDays, id: \.self) { day in
                HStack {
                  Text(day, format: .dateTime.weekday(.wide))
                  Spacer()
                  if store.trained(on: day) {
                    Image(systemName: "checkmark").foregroundStyle(GymColor.red)
                  }
                }
              }
            }.gymPage().navigationTitle(store.t("Consistency")).navigationBarTitleDisplayMode(
              .inline
            ).toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button(store.t("Done")) { consistency = false }
              }
            }
          }.presentationDetents([.medium, .large])
        }
    }
  }
  private var greeting: String {
    let name = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let hour = Calendar.current.component(.hour, from: .now)
    let key = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
    let text = store.t(key)
    return name.isEmpty ? text : text + ", " + name
  }
  private var streakCard: some View {
    Button {
      consistency = true
    } label: {
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          Image(systemName: "flame.fill").font(.system(size: 29)).foregroundStyle(GymColor.red)
          Text("\(store.activeWeekStreak)").font(GymType.hero(38)).foregroundStyle(GymColor.ink)
          Text(store.t("Week streak")).font(GymType.label(14)).foregroundStyle(GymColor.dim)
          Spacer(minLength: 0)
        }
        HStack(spacing: 0) {
          ForEach(store.weekDays, id: \.self) { day in
            VStack(spacing: 8) {
              Text(day, format: .dateTime.weekday(.narrow)).font(GymType.body(11))
                .foregroundStyle(GymColor.dim)
              ZStack {
                Circle().fill(store.trained(on: day) ? GymColor.red : GymColor.ink.opacity(0.06))
                if store.trained(on: day) {
                  Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                }
              }.frame(width: 26, height: 26)
            }.frame(maxWidth: .infinity)
          }
        }.accessibilityHidden(true)
      }.padding(20).gymCard()
    }.buttonStyle(.plain).accessibilityIdentifier("home.streak")
      .accessibilityLabel(
        store.profile.language == "es"
          ? "\(store.activeWeekStreak) semanas seguidas" : "\(store.activeWeekStreak)-week streak")
  }

}
struct PreferencesView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var deleting = false
  @State private var routineDetails = false
  var body: some View {
    NavigationStack {
      Form {
        Section {
          NavigationLink {
            SplitsView(onDone: { dismiss() })
          } label: {
            Text(store.t("Splits"))
          }.accessibilityIdentifier("settings.splits")
          Button(store.t("Edit routine answers")) {
            store.updateProfile {
              $0.onboarded = false
              $0.onboardingStep = 0
              $0.onboardingStepID = OnboardingStep.frequency.rawValue
              $0.onboardingStoryStage = 0
            }
            dismiss()
          }.accessibilityIdentifier("settings.baseline")
          Button(store.t("Each exercise")) { routineDetails = true }
            .accessibilityIdentifier("settings.routineDetails")
        }
        Section {
          TextField(
            store.t("Name (optional)"),
            text: Binding(
              get: { store.profile.name },
              set: { value in store.updateProfile { $0.name = String(value.prefix(40)) } }))
          Picker(
            store.t("Language"),
            selection: Binding(
              get: { store.profile.language },
              set: { value in store.updateProfile { $0.language = value } })
          ) {
            Text("English").tag("en")
            Text("Español").tag("es")
          }
          Picker(
            store.t("Weight unit"),
            selection: Binding(
              get: { store.profile.unit }, set: { value in store.updateProfile { $0.unit = value } }
            )
          ) {
            Text("kg").tag("kg")
            Text("lb").tag("lb")
          }
        }
        Section {
          Toggle(
            store.t("Sounds"),
            isOn: Binding(
              get: { store.profile.soundEnabled ?? true },
              set: { value in store.updateProfile { $0.soundEnabled = value } }))
          Toggle(
            store.t("Haptics"),
            isOn: Binding(
              get: { store.profile.hapticsEnabled ?? true },
              set: { value in store.updateProfile { $0.hapticsEnabled = value } }))
          Toggle(
            store.t("Focus demo"),
            isOn: Binding(
              get: { store.profile.focusEnabled ?? true },
              set: { value in store.updateProfile { $0.focusEnabled = value } }))
        } footer: {
          Text(store.t("This demo doesn't block other apps."))
        }
        Section {
          if store.data.history.isEmpty && store.data.workouts.isEmpty {
            Button(store.t("Load sample workouts")) { store.loadDemoIfEmpty() }
              .accessibilityIdentifier("settings.demo")
          }
          Button(store.t("Delete routine answers"), role: .destructive) { deleting = true }
        } footer: {
          Text(store.t("Saved on this device. No account or analytics."))
        }
      }.gymPage().navigationTitle(store.t("Settings"))
        .sheet(isPresented: $routineDetails) { RoutineDetailEditor() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("preferences.done")
          }

        }
        .confirmationDialog(
          store.t("Delete routine answers?"), isPresented: $deleting, titleVisibility: .visible
        ) {
          Button(store.t("Delete"), role: .destructive) {
            store.deleteRoutineAnswers()
          }
        } message: {
          Text(store.t("Your workouts and splits will stay saved."))
        }
    }
  }
}
struct WorkoutRecap: View {
  @EnvironmentObject private var store: GymStore
  let session: Session
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(store.t(session.name)).font(GymType.label(17))
        Spacer()
        Text(session.ended ?? session.started, format: .dateTime.month(.abbreviated).day()).font(
          GymType.body(12)
        ).foregroundStyle(GymColor.dim)
      }
      Text(
        "\(session.completedSets.count) " + store.t("sets")
          + " · \(max(1, Int(session.duration / 60))) " + store.t("min")
      ).font(GymType.body(15)).foregroundStyle(GymColor.dim)
    }
  }
}
struct WorkoutDetailView: View {
  @EnvironmentObject private var store: GymStore
  let sessionID: UUID
  @State private var editing: LoggedSet?
  private var session: Session? {
    store.data.history.first { $0.id == sessionID }
      ?? store.session.flatMap { $0.id == sessionID ? $0 : nil }
  }
  var body: some View {
    List {
      if let session {
        ForEach(session.sets) { set in
          Button {
            editing = set
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(store.t(set.exercise.name)).foregroundStyle(GymColor.ink)
                Spacer()
                Text(setValue(set, store: store)).foregroundStyle(GymColor.dim).font(
                  GymType.body(15))
              }
              if let seconds = set.displayedSetSeconds {
                Text(store.t("Set time") + " " + JourneyFormat.time(seconds))
                  .font(GymType.body(13)).foregroundStyle(GymColor.dim)
              }
              if let gap = session.gapSeconds(before: set) {
                Text(
                  store.t(
                    session.gapCrossesExercises(before: set) ? "Gap across exercises" : "Gap before"
                  ) + " " + JourneyFormat.time(gap)
                )
                .font(GymType.body(13)).foregroundStyle(GymColor.dim)
              }
            }
          }.accessibilityIdentifier("saved." + set.id.uuidString)
        }
        if session.sets.isEmpty {
          Text(store.t("No sets logged yet.")).foregroundStyle(GymColor.dim)
        }
      }
      if store.deletedSet != nil { Button(store.t("Undo delete")) { store.undoDelete() } }
    }.gymPage().navigationTitle(store.t(session?.name ?? "Workout")).navigationBarTitleDisplayMode(
      .inline
    )
    .sheet(item: $editing) { SetEditor(set: $0, sessionID: sessionID) }
  }
}
struct SetList: View {
  @EnvironmentObject private var store: GymStore
  var sets: [LoggedSet]
  var body: some View {
    ForEach(sets) { set in
      HStack {
        Text(store.t(set.exercise.name))
        Spacer()
        Text(setValue(set, store: store)).foregroundStyle(GymColor.dim)
      }.font(GymType.body(15))
    }
  }
}
@MainActor func setValue(_ set: LoggedSet, store: GymStore) -> String {
  if set.unsuccessful == true {
    return store.t("Attempt") + " · "
      + formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)) + " "
      + store.profile.unit
  }
  if set.exercise.timed { return formatNumber(set.minutes) + " " + store.t("min") }
  let weight =
    set.weightKG == 0
    ? store.t("Bodyweight")
    : formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)) + " "
      + store.profile.unit
  return weight + " × \(set.reps)" + (set.warmup == true ? " · " + store.t("Warm-up") : "")
}
func formatNumber(_ value: Double) -> String {
  value.formatted(.number.precision(.fractionLength(0...2)))
}
