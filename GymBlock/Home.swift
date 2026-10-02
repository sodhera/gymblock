import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GymStore
    @State private var settings = false
    @State private var history = false
    @State private var progress = false
    private var splitID: UUID? { store.profile.preferredSplitID }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("GYMBLOCK").font(.caption.weight(.bold)).tracking(2).foregroundStyle(GymColor.blue)
                    Spacer()
                    Button { settings = true } label: { Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 44, height: 44) }
                        .accessibilityLabel(store.t("Settings")).accessibilityIdentifier("home.preferences")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.profile.language == "es" ? "Hola, \(store.profile.name)." : "Hey, \(store.profile.name).")
                        .font(.largeTitle.weight(.bold))
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill").foregroundStyle(GymColor.red)
                        Text(store.profile.language == "es" ? "\(store.activeWeekStreak) semanas activas seguidas" : "\(store.activeWeekStreak) active weeks in a row")
                            .foregroundStyle(GymColor.dim)
                    }.font(.subheadline)
                }
                HStack(spacing: 0) {
                    ForEach(store.weekDays, id: \.self) { day in
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().fill(store.trained(on: day) ? GymColor.action : GymColor.wash).frame(width: 32, height: 32)
                                if store.trained(on: day) { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) }
                                else if Calendar.current.isDateInToday(day) { Circle().stroke(GymColor.red, lineWidth: 2).frame(width: 32, height: 32) }
                            }
                            Text(day, format: .dateTime.weekday(.narrow)).font(.caption).foregroundStyle(GymColor.dim)
                        }.frame(maxWidth: .infinity)
                            .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted) + (store.trained(on: day) ? ", trained" : ", no workout"))
                    }
                }
                VStack(spacing: 12) {
                    GymButton(title: store.t("Start workout"), icon: "play.fill", id: "home.start") {
                        store.startSession(workout: store.data.workouts.first { $0.id == splitID })
                    }
                    HStack {
                        Text(store.t("Workout")).font(.subheadline).foregroundStyle(GymColor.dim)
                        Spacer()
                        Menu {
                            Button(store.t("Free workout")) { store.updateProfile { $0.preferredSplitID = nil } }
                            ForEach(store.data.workouts) { split in Button(split.name) { store.updateProfile { $0.preferredSplitID = split.id } } }
                        } label: {
                            HStack { Text(store.data.workouts.first { $0.id == splitID }?.name ?? store.t("Free workout")); Image(systemName: "chevron.down").font(.caption) }
                                .font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                        }.accessibilityIdentifier("home.workout")
                    }
                    Text(store.t("Blocking is simulated in this prototype.")).font(.caption).foregroundStyle(GymColor.dim)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(store.t("Biggest lifts")).font(.headline)
                        Spacer()
                        Button(store.t("Progress")) { progress = true }.font(.subheadline.weight(.semibold)).frame(minHeight: 44).accessibilityIdentifier("home.progress")
                    }
                    if store.biggestLifts.isEmpty {
                        Text(store.t("Your lift records appear after your first workout.")).font(.subheadline).foregroundStyle(GymColor.dim)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(store.biggestLifts.prefix(3))) { record in
                                HStack {
                                    Text(store.t(record.set.exercise.name)).font(.body.weight(.medium))
                                    Spacer(minLength: 12)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(weightString(record.set.weightKG)) \(store.profile.unit)").font(.headline.monospacedDigit()).foregroundStyle(GymColor.blue)
                                        Text("× \(record.set.reps) " + store.t("reps")).font(.caption).foregroundStyle(GymColor.dim)
                                    }
                                }.padding(.vertical, 14)
                                if record.id != store.biggestLifts.prefix(3).last?.id { Divider() }
                            }
                        }.padding(.horizontal, 18).background(GymColor.surface, in: RoundedRectangle(cornerRadius: 18))
                        Text(store.t("Heaviest logged sets. Reps shown alongside.")).font(.caption).foregroundStyle(GymColor.dim)
                    }
                }
                HStack {
                    Text(store.t("Last workout")).font(.headline)
                    Spacer()
                    Button(store.t("History")) { history = true }.font(.subheadline.weight(.semibold)).frame(minHeight: 44).accessibilityIdentifier("home.history")
                }
                if let last = store.data.history.first { Card { WorkoutRecap(session: last) } }
                else { Text(store.t("No workouts yet.")).foregroundStyle(GymColor.dim) }
                if store.data.demoLoaded == true {
                    Text(store.t("Sample history loaded · new workouts save normally")).font(.caption).foregroundStyle(GymColor.dim)
                }
            }.padding(24)
        }
        .sheet(isPresented: $settings) { PreferencesView() }
        .sheet(isPresented: $history) { HistoryView() }
        .sheet(isPresented: $progress) { ProgressView() }
        .onChange(of: store.data.workouts.map(\.id)) { _, ids in if let splitID, !ids.contains(splitID) { store.updateProfile { $0.preferredSplitID = nil } } }
    }
    private func weightString(_ kg: Double) -> String { GymStore.displayedWeight(kg, unit: store.profile.unit).formatted(.number.precision(.fractionLength(0...1))) }
}
struct WorkoutRecap: View {
    @EnvironmentObject private var store: GymStore
    let session: Session
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(store.t(session.name)).font(.headline); Spacer(); Text(session.ended ?? session.started, format: .dateTime.month(.abbreviated).day()).font(.caption).foregroundStyle(GymColor.dim) }
            Text("\(session.sets.count) " + store.t("sets") + " · \(session.totalReps) " + store.t("reps") + " · \(max(1, Int(session.duration / 60))) " + store.t("min"))
                .font(.subheadline).foregroundStyle(GymColor.dim)
        }
    }
}
struct PreferencesView: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    @State private var favorites = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { SplitsView(onDone: { dismiss() }) } label: { Label(store.t("Splits"), systemImage: "list.bullet.rectangle") }.accessibilityIdentifier("settings.splits")
                }
                Section(store.t("Your preferences")) {
                    TextField(store.t("Name"), text: $store.data.profile.name).accessibilityIdentifier("preferences.name")
                    Picker(store.t("Language"), selection: $store.data.profile.language) { Text("English").tag("en"); Text("Español").tag("es") }
                    Picker(store.t("Weight unit"), selection: $store.data.profile.unit) { Text("kg").tag("kg"); Text("lb").tag("lb") }
                    Button(store.t("Edit favorites")) { favorites = true }
                }
                Section(store.t("Focus choice")) { BlockingPicker() }
                Section {
                    Text(store.t("Your data stays on this device. No account, cloud, or analytics.")).font(.footnote).foregroundStyle(GymColor.dim)
                    if store.data.history.isEmpty && store.data.workouts.isEmpty {
                        Button(store.t("Load sample workouts")) { store.loadDemoIfEmpty() }.accessibilityIdentifier("settings.demo")
                    }
                }
            }.scrollContentBackground(.hidden).background(GymColor.ground).navigationTitle(store.t("Settings"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) {
                    store.updateProfile { p in p.name = String(p.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40)); if p.name.isEmpty { p.name = "Friend" }; if !p.blockWholePhone && p.blockedApps.isEmpty { p.blockWholePhone = true } }
                    dismiss()
                }.accessibilityIdentifier("preferences.done") } }
                .onChange(of: store.data.profile.name) { _, _ in store.persist() }
                .onChange(of: store.data.profile.language) { _, _ in store.persist() }
                .onChange(of: store.data.profile.unit) { _, _ in store.persist() }
                .sheet(isPresented: $favorites) {
                    NavigationStack {
                        ScrollView { FavoritePicker().padding(24) }.background(GymColor.ground).navigationTitle(store.t("Your favorites"))
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { favorites = false } } }
                    }
                }
        }
    }
}
struct HistoryView: View {
    @EnvironmentObject private var store: GymStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if store.data.history.isEmpty { Text(store.t("No workouts yet.")).foregroundStyle(GymColor.dim) }
                    ForEach(store.data.history) { session in Card { VStack(alignment: .leading, spacing: 18) { WorkoutRecap(session: session); SetList(sets: session.sets) } } }
                }.padding(24)
            }.background(GymColor.ground).navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(store.t("Done")) { dismiss() }.accessibilityIdentifier("history.done") } }
        }
    }
}
struct SetList: View {
    @EnvironmentObject private var store: GymStore
    var sets: [LoggedSet]
    var body: some View {
        VStack(spacing: 14) {
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)").font(.caption.weight(.bold)).foregroundStyle(GymColor.blue)
                    Text(store.t(set.exercise.name)).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    if set.exercise.timed { Text("\(set.minutes.formatted(.number.precision(.fractionLength(0...1)))) " + store.t("min")).font(.subheadline.weight(.semibold)) }
                    else { Text("\(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit).formatted(.number.precision(.fractionLength(0...1)))) \(store.profile.unit) × \(set.reps)").font(.subheadline.weight(.semibold)).monospacedDigit() }
                }
            }
        }
    }
}
