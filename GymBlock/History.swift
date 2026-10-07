import Charts
import SwiftUI

struct HistoryHubView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var fourWeeks = true
  private var since: Date? { fourWeeks ? Calendar.current.date(byAdding: .day, value: -28, to: Date()) : nil }
  private var sessions: [Session] { store.data.history.filter { since == nil || $0.started >= since! }.sorted { $0.started > $1.started } }
  private var points: [TrainingPoint] { store.trainingPoints(since: since) }
  var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          if store.data.history.isEmpty {
            Text(store.t("No workouts yet")).font(GymType.body(17)).foregroundStyle(GymColor.dim)
            Text(store.t("Finished workouts appear here.")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
          } else {
            if store.data.demoLoaded == true { Text(store.t("Sample data")).font(GymType.body(13)).foregroundStyle(GymColor.dim) }
            if typeSize.isAccessibilitySize {
              VStack(alignment: .leading, spacing: 12) { totals }
            } else {
              HStack(alignment: .top, spacing: 12) { totals }
            }
            NavigationLink { ExerciseProgressList() } label: {
              HStack {
                Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(GymColor.red).accessibilityHidden(true)
                Text(store.t("Exercise progress")); Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(JourneyColor.tertiary).accessibilityHidden(true)
              }.foregroundStyle(GymColor.ink).padding(.horizontal, 20).frame(minHeight: 60)
                .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
            }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("history.progress")
            if sessions.isEmpty { Text(store.t("No workouts in this period")).foregroundStyle(GymColor.dim) }
            LazyVStack(spacing: 0) {
              ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1).padding(.leading, 20) }
                NavigationLink { WorkoutDetailView(sessionID: session.id) } label: {
                  WorkoutRecap(session: session).foregroundStyle(GymColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 16).padding(.horizontal, 20)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("history." + session.id.uuidString)
              }
            }.journeyGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
          }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
      }.gymPage().navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.large)
        .toolbar {
          if !store.data.history.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
              Picker(store.t("Period"), selection: $fourWeeks) {
                Text(store.t("Last 4 weeks")).tag(true); Text(store.t("All time")).tag(false)
              }.pickerStyle(.menu).accessibilityIdentifier("history.period")
            }
          }
        }
  }
  @ViewBuilder private var totals: some View {
    total("Reps", amount: Double(points.reduce(0) { $0 + $1.reps }), metric: 0)
    total("Weight moved", amount: GymStore.displayedWeight(points.reduce(0) { $0 + $1.volumeKG }, unit: store.profile.unit), metric: 1)
  }
  private func total(_ title: String, amount: Double, metric: Int) -> some View {
    NavigationLink { TrainingStatsView(initialMetric: metric, initialFourWeeks: fourWeeks) } label: {
      VStack(alignment: .leading, spacing: 6) {
        Text(store.t(title)).font(JourneyType.label).foregroundStyle(GymColor.dim)
        Text(formatNumber(amount.rounded())).font(.system(.title, weight: .bold)).monospacedDigit().foregroundStyle(GymColor.ink)
          .lineLimit(1).minimumScaleFactor(0.6)
        Text(metric == 1 ? store.profile.unit : store.t("total")).font(JourneyType.caption).foregroundStyle(GymColor.dim)
      }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .journeyGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: true)
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier(metric == 0 ? "history.reps" : "history.volume")
  }
}

struct WorkoutRecap: View {
  @EnvironmentObject private var store: GymStore
  let session: Session
  private var exerciseNames: String {
    var seen = Set<String>()
    return session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }.map { store.t($0.name) }.joined(separator: " · ")
  }
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
        setCount(session.completedSets.count, store: store)
          + " · \(max(1, Int(session.duration / 60))) " + store.t("min")
      ).font(GymType.body(15)).foregroundStyle(GymColor.dim)
      Text(exerciseNames).font(GymType.body(13)).foregroundStyle(JourneyColor.tertiary).lineLimit(1)
    }
  }
}
struct WorkoutDetailView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  let sessionID: UUID
  var embedded = false
  /// Shown during a set: drop it without touching saved sets or the rest before it.
  var cancelSet: (() -> Void)? = nil
  @Environment(\.dismiss) private var dismiss
  @State private var editing: LoggedSet?
  @State private var deletingWorkout = false
  private var session: Session? {
    store.data.history.first { $0.id == sessionID } ?? store.session.flatMap { $0.id == sessionID ? $0 : nil }
  }
  private var exercises: [Exercise] {
    var seen = Set<String>()
    return (session?.sets ?? []).map(\.exercise).filter { seen.insert($0.id).inserted }
  }
  var body: some View {
    List {
      if let cancelSet {
        Section {
          HStack {
            Text(store.t("Set in progress")).foregroundStyle(GymColor.dim)
            Spacer()
            Button(store.t("Cancel set"), action: cancelSet).foregroundStyle(GymColor.red).accessibilityIdentifier("set.cancel")
          }.frame(minHeight: 44)
        }
      }
      if let session {
        if !embedded {
          Section {
            Text(session.ended ?? session.started, format: .dateTime.month(.wide).day().year())
              .foregroundStyle(GymColor.dim)
            Text("\(max(1, Int(session.duration / 60))) " + store.t("min") + " · \(session.totalReps) " + store.t("reps"))
          }.listRowBackground(Color.clear)
        }
        ForEach(exercises) { exercise in
          Section {
            let sets = session.sets.filter { $0.exercise.id == exercise.id }
            HStack {
              Text(store.t("Set")).frame(width: 40, alignment: .leading)
              if !exercise.timed { Spacer(); Text(store.t("Weight") + " (" + store.profile.unit + ")") }
              Spacer()
              Text(store.t(exercise.timed ? "Time" : "Reps")).frame(width: 60, alignment: .trailing)
            }.font(GymType.body(13)).foregroundStyle(GymColor.dim).accessibilityHidden(true)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
              Button { editing = set } label: {
                if typeSize.isAccessibilitySize {
                  VStack(alignment: .leading, spacing: 6) {
                    Text(store.t("Set") + " \(index + 1)")
                    Text(setValue(set, store: store))
                  }.foregroundStyle(GymColor.ink)
                } else {
                  HStack {
                    Text("\(index + 1)").frame(width: 40, alignment: .leading)
                    if !exercise.timed {
                      Spacer()
                      Text(set.weightKG == 0 ? store.t("Bodyweight") : formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)))
                    }
                    Spacer()
                    Text(set.unsuccessful == true ? store.t("Attempt") : exercise.timed ? formatNumber(set.minutes) + " " + store.t("min") : String(set.reps))
                      .frame(minWidth: 60, alignment: .trailing)
                  }.monospacedDigit().foregroundStyle(GymColor.ink).frame(minHeight: 44)
                }
              }.accessibilityLabel(store.t("Set") + " \(index + 1), " + setValue(set, store: store))
                .accessibilityIdentifier("saved." + set.id.uuidString)
            }
          } header: { Text(store.t(exercise.name)).font(GymType.label(17)).textCase(nil) }
        }
        if session.sets.isEmpty { Text(store.t("No sets yet")).foregroundStyle(GymColor.dim) }
      }
      if store.deletedSet != nil { Button(store.t("Undo")) { store.undoDelete() } }
      if !embedded, session != nil {
        Section {
          Button(store.t("Delete workout"), role: .destructive) { deletingWorkout = true }
            .foregroundStyle(Color(uiColor: .systemRed)).accessibilityIdentifier("workout.delete")
        }
      }
    }.gymPage().navigationTitle(embedded ? store.t("Sets") : store.t(session?.name ?? "Workout"))
      .confirmationDialog(store.t("Delete this workout?"), isPresented: $deletingWorkout, titleVisibility: .visible) {
        Button(store.t("Delete workout"), role: .destructive) { store.deleteWorkout(sessionID); dismiss() }
          .accessibilityIdentifier("workout.delete.confirm")
        Button(store.t("Cancel"), role: .cancel) {}
      } message: { Text(store.t("Its sets leave History and progress. This can’t be undone.")) }
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
        if let editing { SetEditor(set: editing, sessionID: sessionID, embedded: true) }
      }
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
