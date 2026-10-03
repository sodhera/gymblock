import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var settings = false
  @State private var progress = false
  @State private var splits = false
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
          VStack(alignment: .leading, spacing: 12) {
            Text(store.t("Your workout")).font(GymType.hero(22)).foregroundStyle(GymColor.ink)
            VStack(alignment: .leading, spacing: 22) {
              HStack(spacing: 16) {
                Image(systemName: "dumbbell.fill").font(.system(size: 26, weight: .medium))
                  .foregroundStyle(GymColor.red).frame(width: 62, height: 70)
                  .background(GymColor.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                Menu {
                  Button(store.t("Free workout")) {
                    store.updateProfile { $0.preferredSplitID = nil }
                  }
                  ForEach(store.data.workouts) { split in
                    Button(split.name) { store.updateProfile { $0.preferredSplitID = split.id } }
                  }
                  Divider()
                  Button(store.t("Manage splits")) { splits = true }
                } label: {
                  HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) {
                      Text(split?.name ?? store.t("Free workout")).font(GymType.title(24))
                        .foregroundStyle(GymColor.ink).multilineTextAlignment(.leading)
                      Text(
                        split.map { "\($0.exercises.count) " + store.t("exercises") }
                          ?? store.t("One move at a time.")
                      )
                      .font(GymType.body(14)).foregroundStyle(GymColor.dim)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                      .foregroundStyle(GymColor.dim)
                  }.frame(minHeight: 60).contentShape(Rectangle())
                }.accessibilityIdentifier("home.workout")
              }
              GymButton(title: store.t("Start workout"), icon: "arrow.right", id: "home.start") {
                store.startSession(workout: split)
              }
            }.padding(20).gymCard()
          }
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text(store.t("Best lifts")).font(GymType.hero(22)).foregroundStyle(GymColor.ink)
              Spacer()
              Button {
                progress = true
              } label: {
                HStack(spacing: 5) {
                  Text(store.t("Progress")).font(GymType.label(14))
                  Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                }.frame(minHeight: 44)
              }.accessibilityIdentifier("home.progress")
            }
            VStack(alignment: .leading, spacing: 0) {
              if store.biggestLifts.isEmpty {
                Text(store.t("Your best lifts will appear here.")).font(GymType.body(15))
                  .foregroundStyle(GymColor.dim).padding(.vertical, 16)
              }
              ForEach(Array(store.biggestLifts.prefix(3)).indices, id: \.self) { index in
                let record = Array(store.biggestLifts.prefix(3))[index]
                if typeSize.isAccessibilitySize {
                  VStack(alignment: .leading, spacing: 8) {
                    Text(store.t(record.set.exercise.name)).font(GymType.body(16)).foregroundStyle(
                      GymColor.ink)
                    Text(setValue(record.set, store: store)).font(GymType.label(15))
                      .monospacedDigit().foregroundStyle(GymColor.dim)
                  }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 15)
                } else {
                  HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(store.t(record.set.exercise.name)).font(GymType.body(16)).foregroundStyle(
                      GymColor.ink)
                    Spacer(minLength: 0)
                    Text(setValue(record.set, store: store)).font(GymType.label(15))
                      .monospacedDigit().foregroundStyle(GymColor.dim).fixedSize(
                        horizontal: true, vertical: false)
                  }.padding(.vertical, 15)
                }
                if index < min(2, store.biggestLifts.count - 1) { Divider().opacity(0.45) }
              }
            }.padding(.horizontal, 20).gymCard()
          }
        }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 28)
      }.gymPage().toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $settings) { PreferencesView() }
        .sheet(isPresented: $progress) { ProgressView() }
        .sheet(isPresented: $splits) { NavigationStack { SplitsView(onDone: { splits = false }) } }
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
            }
            dismiss()
          }.accessibilityIdentifier("settings.baseline")
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
      }.gymPage().navigationTitle(store.t("Settings")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("preferences.done")
          }

        }
        .confirmationDialog(
          store.t("Delete routine answers?"), isPresented: $deleting, titleVisibility: .visible
        ) {
          Button(store.t("Delete"), role: .destructive) {
            store.updateProfile { $0.baseline = nil }
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
struct HistoryView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      List {
        if store.data.history.isEmpty {
          Text(store.t("No workouts yet.")).foregroundStyle(GymColor.dim)
        }
        ForEach(store.data.history) { session in
          NavigationLink {
            WorkoutDetailView(sessionID: session.id)
          } label: {
            WorkoutRecap(session: session)
          }.accessibilityIdentifier("history." + session.id.uuidString)
        }
      }.gymPage().navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("history.done")
          }
        }
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
            HStack {
              Text(store.t(set.exercise.name)).foregroundStyle(GymColor.ink)
              Spacer()
              Text(setValue(set, store: store)).foregroundStyle(GymColor.dim).font(GymType.body(15))
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
