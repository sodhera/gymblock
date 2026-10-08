import SwiftUI

/// Home: the streak, workouts per week against the goal, and one button. Start workout opens the
/// chooser: a split, or a free workout.
struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var choosing = false
  @State private var settings = false
  @State private var history = false
  @State private var appeared = false
  private enum Detail: Hashable { case exercise(Exercise, UUID?), time }
  @State private var detail: Detail?
  /// A brand-new log shows a labelled example until the first workout is saved.
  private var example: Bool { store.data.history.isEmpty }
  private var stats: HomeStats { example ? GymStore.exampleStats(goal: min(7, max(1, store.profile.baseline?.trainingDays ?? 5))) : store.homeStats() }
  private var trends: [ExerciseTrend] { example ? GymStore.exampleTrends(unit: store.profile.unit) : store.exerciseTrends() }
  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid()
        VStack(alignment: .leading, spacing: 0) {
          if typeSize.isAccessibilitySize {
            ScrollView { content.padding(.bottom, 12) }.scrollIndicators(.hidden).frame(maxHeight: .infinity)
          } else {
            content
            Spacer(minLength: 0)
          }
          VStack(spacing: 10) {
            caption.frame(minHeight: 20)
            JourneyButton(title: store.t("Start workout"), id: "home.start") {
              JourneyHaptic.play(.medium, store.profile, intensity: 0.8)
              choosing = true
            }
            Color.clear.frame(height: 20)
          }.padding(.top, 8)
        }.padding(.horizontal, 24).padding(.bottom, 4)
      }
      .navigationTitle(greeting).navigationBarTitleDisplayMode(.inline).track(screen: "home", ["example": example])
      .navigationDestination(item: $detail) { which in
        switch which {
        case .exercise(let exercise, let splitID): ExerciseProgressView(exercise: exercise, split: store.data.workouts.first { $0.id == splitID })
        case .time: TimeTrainingView()
        }
      }
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button { history = true } label: { Label(store.t("History"), systemImage: "clock.arrow.circlepath") }
            .accessibilityIdentifier("home.history")
          Button { settings = true } label: { Label(store.t("Settings"), systemImage: "gearshape") }
            .accessibilityIdentifier("home.preferences")
        }
      }
      .navigationDestination(isPresented: $history) { HistoryHubView() }
      .sheet(isPresented: $settings) { PreferencesView() }
      .sheet(isPresented: $choosing) { WorkoutChoiceView() }
    }
  }

  /// Cards settle in one after another the first time Home appears.
  private var content: some View {
    let s = stats
    let trends = trends
    return VStack(alignment: .leading, spacing: 12) {
      StreakCard(stats: s) { history = true }.reveal(appeared, 0).padding(.top, 8)
      if !trends.isEmpty {
        ExerciseCarousel(trends: trends, example: example) { trend in
          if example { history = true } else { detail = .exercise(trend.exercise, trend.splitID) }
        }.reveal(appeared, 1)
      }
      HStack(spacing: 12) {
        InfoCard(symbol: "trophy.fill", value: s.lastPR.map { relative($0.date) } ?? "—", label: store.t("since last PR"),
                 detail: s.lastPR.map { store.t($0.exercise.name) + " " + $0.text } ?? store.t("Beat a set to earn one."), id: "home.pr") {
          if example { history = true } else if let pr = s.lastPR { detail = .exercise(pr.exercise, pr.splitID) } else { history = true }
        }
        InfoCard(symbol: "clock.fill", value: JourneyFormat.minutes(Double(s.totalMinutes)), label: store.t("time training"),
                 detail: "\(s.totalWorkouts) " + store.t("workouts"), id: "home.time") { if example { history = true } else { detail = .time } }
      }.reveal(appeared, 2)
    }
    .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.12)) { appeared = true } }
  }
  private var greeting: String {
    let hour = Calendar.current.component(.hour, from: Date())
    let base = hour < 5 ? "Good evening" : hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    let name = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.t(base) + (name.isEmpty ? "" : ", " + name)
  }
  private func relative(_ date: Date) -> String {
    let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
    if days == 0 { return store.t("today") }
    if days == 1 { return store.t("yesterday") }
    if days < 14 { return "\(days) " + store.t("days ago") }
    return "\(days / 7) " + store.t("weeks ago")
  }

  /// One honest line above the button, the same one the workout shows.
  @ViewBuilder private var caption: some View {
    if store.data.demoLoaded == true {
      Text(store.t("Sample data")).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).accessibilityIdentifier("home.sample")
    } else if example {
      Text(store.t("Example until your first workout")).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary)
    } else if store.profile.focusEnabled == true {
      let apps = store.profile.blockedApps
      HStack(spacing: 6) {
        Image(systemName: "lock.fill").font(.caption2).accessibilityHidden(true)
        Text((apps.isEmpty ? store.t("Apps") : apps.prefix(2).joined(separator: ", ") + (apps.count > 2 ? " +\(apps.count - 2)" : ""))
             + " · " + store.t("blocked while you train · preview"))
      }.font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).lineLimit(1)
        .accessibilityElement(children: .combine).accessibilityIdentifier("home.blocking")
    } else {
      Color.clear.frame(height: 20)
    }
  }
}

/// Choose today's workout and go: the split that's up next is marked, a free workout is one row,
/// and splits are created and edited here too.
struct WorkoutChoiceView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var creating = false
  @State private var editing: Workout?
  @State private var deleting: Workout?
  private var next: UUID? { store.profile.preferredSplitID }
  var body: some View {
    NavigationStack {
      ScrollView {
        JourneyGlassGroup(spacing: 10) {
          VStack(spacing: 10) {
            ForEach(store.data.workouts) { split in
              row(split.name, detail: split.exercises.map { store.t($0.name) }.joined(separator: " · "), id: split.id, split: split)
            }
            row(store.t("Free workout"), detail: store.t("Pick exercises as you go."), id: nil)
            Button { creating = true } label: {
              Label(store.t("New split"), systemImage: "plus").font(JourneyType.option).foregroundStyle(JourneyColor.secondary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .strokeBorder(JourneyColor.ink(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])))
            }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("split.add")
          }
        }.padding(.horizontal, 20).padding(.vertical, 12)
      }.gymPage().navigationTitle(store.t("Start workout")).navigationBarTitleDisplayMode(.inline).track(screen: "home.choose")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } } }
        .navigationDestination(isPresented: $creating) {
          SplitEditorContent(workout: Workout(name: "", exercises: [])) { split in
            store.updateProfile { $0.preferredSplitID = split.id }; creating = false
          }
        }
        .navigationDestination(item: $editing) { split in
          SplitEditorContent(workout: split) { _ in editing = nil }
        }
        .confirmationDialog(store.t("Delete this split?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { split in
          Button(store.t("Delete split"), role: .destructive) { store.deleteSplit(split.id) }
          Button(store.t("Cancel"), role: .cancel) {}
        } message: { _ in Text(store.t("Past workouts stay in History.")) }
    }.presentationDetents([.medium, .large])
  }
  private func row(_ name: String, detail: String, id: UUID?, split: Workout? = nil) -> some View {
    let upNext = split != nil && next == id
    return HStack(spacing: 12) {
      Button {
        JourneyHaptic.play(.medium, store.profile, intensity: 0.8)
        store.updateProfile { $0.preferredSplitID = id }
        store.startSession(workout: split)
        dismiss()
      } label: {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text(name).font(JourneyType.option).foregroundStyle(JourneyColor.text).lineLimit(1)
              if upNext {
                Text(store.t("Up next")).font(.caption.weight(.semibold)).foregroundStyle(JourneyColor.onAccent)
                  .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(JourneyColor.signal))
              }
            }
            Text(detail).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).lineLimit(1)
          }
          Spacer(minLength: 8)
          Image(systemName: "arrow.right").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.tertiary).accessibilityHidden(true)
        }.frame(maxWidth: .infinity, minHeight: 46, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier(split.map { "choice.\($0.name)" } ?? "choice.free")
        .accessibilityHint(store.t("Starts this workout"))
      if let split {
        Menu {
          Button(store.t("Edit split"), systemImage: "pencil") { editing = split }
          Button(store.t("Delete split"), systemImage: "trash", role: .destructive) { deleting = split }
        } label: {
          Image(systemName: "ellipsis").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
            .frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityLabel(store.t("Edit") + " " + name).accessibilityIdentifier("split.menu.\(split.name)")
      }
    }.padding(.leading, 20).padding(.trailing, split == nil ? 20 : 8).padding(.vertical, 6)
      .journeyGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: upNext ? JourneyColor.ink(0.06) : nil, interactive: true)
  }
}
