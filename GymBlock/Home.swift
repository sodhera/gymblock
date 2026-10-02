import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @State private var settings = false
  @State private var progress = false
  @State private var splits = false
  @State private var consistency = false
  private var split: Workout? {
    store.data.workouts.first { $0.id == store.profile.preferredSplitID }
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          VStack(alignment: .leading, spacing: 18) {
            HStack {
              Button {
                consistency = true
              } label: {
                Text(
                  store.profile.language == "es"
                    ? "\(store.activeWeekStreak) semanas seguidas"
                    : "\(store.activeWeekStreak)-week streak"
                ).font(.subheadline).foregroundStyle(Color.secondary)
              }.buttonStyle(.plain).accessibilityIdentifier("home.streak").frame(minHeight: 44)
              Spacer()
              if store.data.demoLoaded == true {
                Text(store.t("Demo")).font(.caption).foregroundStyle(Color.secondary)
              }
            }
            Menu {
              Button(store.t("Free workout")) { store.updateProfile { $0.preferredSplitID = nil } }
              ForEach(store.data.workouts) { split in
                Button(split.name) { store.updateProfile { $0.preferredSplitID = split.id } }
              }
              Divider()
              Button(store.t("Manage splits")) { splits = true }
            } label: {
              HStack(spacing: 6) {
                Text(split?.name ?? store.t("Free workout")).font(.title2.weight(.semibold))
                Image(systemName: "chevron.down").font(.footnote)
              }.foregroundStyle(Color.primary).frame(minHeight: 44)
            }.accessibilityIdentifier("home.workout")
            GymButton(title: store.t("Start workout"), id: "home.start") {
              store.startSession(workout: split)
            }
          }
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text(store.t("Best lifts")).font(.headline)
              Spacer()
              Button(store.t("Progress")) { progress = true }.font(.subheadline).frame(
                minHeight: 44
              ).accessibilityIdentifier("home.progress")
            }
            if store.biggestLifts.isEmpty {
              Text(store.t("Your best lifts will appear here.")).font(.subheadline).foregroundStyle(
                Color.secondary)
            }
            ForEach(Array(store.biggestLifts.prefix(3))) { record in
              HStack {
                Text(store.t(record.set.exercise.name)).font(.body)
                Spacer(minLength: 16)
                Text(setValue(record.set, store: store)).font(.subheadline.monospacedDigit())
                  .foregroundStyle(Color.secondary)
              }.frame(minHeight: 44)
              Divider()
            }
          }
        }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 24)
      }
      .navigationTitle("GymBlock").navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            settings = true
          } label: {
            Image(systemName: "gearshape")
          }.accessibilityLabel(store.t("Settings")).accessibilityIdentifier("home.preferences")
        }

      }
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
          }.navigationTitle(store.t("Consistency")).navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button(store.t("Done")) { consistency = false }
            }
          }
        }.presentationDetents([.medium, .large])
      }
    }
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
      }.navigationTitle(store.t("Settings")).navigationBarTitleDisplayMode(.inline)
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
        Text(store.t(session.name)).font(.headline)
        Spacer()
        Text(session.ended ?? session.started, format: .dateTime.month(.abbreviated).day()).font(
          .caption
        ).foregroundStyle(Color.secondary)
      }
      Text(
        "\(session.completedSets.count) " + store.t("sets")
          + " · \(max(1, Int(session.duration / 60))) " + store.t("min")
      ).font(.subheadline).foregroundStyle(Color.secondary)
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
          Text(store.t("No workouts yet.")).foregroundStyle(Color.secondary)
        }
        ForEach(store.data.history) { session in
          NavigationLink {
            WorkoutDetailView(sessionID: session.id)
          } label: {
            WorkoutRecap(session: session)
          }.accessibilityIdentifier("history." + session.id.uuidString)
        }
      }.navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.inline)
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
              Text(store.t(set.exercise.name)).foregroundStyle(Color.primary)
              Spacer()
              Text(setValue(set, store: store)).foregroundStyle(Color.secondary).font(.subheadline)
            }
          }.accessibilityIdentifier("saved." + set.id.uuidString)
        }
        if session.sets.isEmpty {
          Text(store.t("No sets logged yet.")).foregroundStyle(Color.secondary)
        }
      }
      if store.deletedSet != nil { Button(store.t("Undo delete")) { store.undoDelete() } }
    }.navigationTitle(store.t(session?.name ?? "Workout")).navigationBarTitleDisplayMode(.inline)
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
        Text(setValue(set, store: store)).foregroundStyle(Color.secondary)
      }.font(.subheadline)
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
