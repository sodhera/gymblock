import Charts
import SwiftUI

/// History is a progress page: the period total over weekly bars, exercise progress one tap away,
/// and every workout beneath. Reps and weight moved are the two metrics; the period is in the toolbar.
struct HistoryHubView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var fourWeeks = true
  @State private var volumeMetric = false
  private var since: Date? { fourWeeks ? Calendar.current.date(byAdding: .day, value: -28, to: Date()) : nil }
  private var sessions: [Session] { store.data.history.filter { since == nil || $0.started >= since! }.sorted { $0.started > $1.started } }
  private var points: [TrainingPoint] { store.trainingPoints(since: since) }
  private var weeks: [WeekTotal] { weekTotals(points, since: since, value: value) }
  private var total: Double { points.reduce(0) { $0 + value($1) } }
  private var unit: String { volumeMetric ? store.profile.unit : store.t("reps") }
  private func value(_ p: TrainingPoint) -> Double {
    volumeMetric ? GymStore.displayedWeight(p.volumeKG, unit: store.profile.unit) : Double(p.reps)
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        if store.data.history.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text(store.t("No workouts yet")).font(JourneyType.option).foregroundStyle(JourneyColor.text)
            Text(store.t("Finished workouts appear here.")).font(.subheadline).foregroundStyle(JourneyColor.secondary)
          }
        } else {
          if store.data.demoLoaded == true {
            Text(store.t("Sample data")).font(JourneyType.eyebrow).tracking(0.8).foregroundStyle(JourneyColor.tertiary)
              .accessibilityIdentifier("history.sample")
          }
          chartCard
          progressRow
          workoutList
        }
      }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }.gymPage().navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.large).track(screen: "history")
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

  /// The period total, its weekly bars and the metric pills. The total opens the full chart.
  private var chartCard: some View {
    VStack(alignment: .leading, spacing: 18) {
      NavigationLink { TrainingStatsView(initialMetric: volumeMetric ? 1 : 0, initialFourWeeks: fourWeeks) } label: {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: store.t(volumeMetric ? "Weight moved" : "Reps") + " · " + store.t(fourWeeks ? "Last 4 weeks" : "All time"))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(formatNumber(total.rounded())).font(.system(.largeTitle, weight: .bold)).monospacedDigit()
                .foregroundStyle(JourneyColor.text).lineLimit(1).minimumScaleFactor(0.5)
                .contentTransition(.numericText())
              Text(unit).font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
            }
          }
          Spacer(minLength: 8)
          Image(systemName: "chevron.right").font(.system(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
            .accessibilityHidden(true)
        }.contentShape(Rectangle())
      }.buttonStyle(.plain)
        .accessibilityLabel(store.t(volumeMetric ? "Weight moved" : "Reps") + ", " + formatNumber(total.rounded()) + " " + unit)
        .accessibilityIdentifier(volumeMetric ? "history.volume" : "history.reps")
      WeeklyBars(weeks: weeks).accessibilityHidden(true)
      if typeSize.isAccessibilitySize {
        VStack(alignment: .leading, spacing: 8) { pills }
      } else {
        JourneyGlassGroup(spacing: 8) { HStack(spacing: 8) { pills } }
      }
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).journeySurface()
      .animation(.smooth(duration: 0.35), value: volumeMetric)
  }
  @ViewBuilder private var pills: some View {
    pill("Reps", volume: false)
    pill("Weight moved", volume: true)
  }
  private func pill(_ title: String, volume: Bool) -> some View {
    let selected = volumeMetric == volume
    return Button {
      guard !selected else { return }
      JourneyHaptic.play(.selection, store.profile)
      volumeMetric = volume
    } label: {
      Text(store.t(title)).font(JourneyType.label).foregroundStyle(selected ? JourneyColor.text : JourneyColor.secondary)
        .lineLimit(1).padding(.horizontal, 16).frame(minHeight: 36).contentShape(Capsule())
        .journeyGlass(Capsule(), tint: selected ? JourneyColor.ink(0.16) : nil, interactive: true)
        .overlay(Capsule().strokeBorder(JourneyColor.ink(selected ? 0.55 : 0), lineWidth: 1.5))
    }.buttonStyle(JourneyPressStyle())
      .accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier(volume ? "history.metric.volume" : "history.metric.reps")
  }

  private var progressRow: some View {
    NavigationLink { ExerciseProgressList() } label: {
      HStack(spacing: 12) {
        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(.body, weight: .semibold))
          .foregroundStyle(JourneyColor.text).frame(width: 24).accessibilityHidden(true)
        Text(store.t("Exercise progress")).font(JourneyType.option).foregroundStyle(JourneyColor.text).lineLimit(1)
        Spacer(minLength: 8)
        Image(systemName: "chevron.right").font(.system(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
          .accessibilityHidden(true)
      }.padding(.horizontal, 20).frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .journeyGlass(RoundedRectangle(cornerRadius: 22, style: .continuous), interactive: true)
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("history.progress")
  }

  private var workoutList: some View {
    VStack(alignment: .leading, spacing: 0) {
      Eyebrow(text: store.t("Workouts")).padding(.top, 16).padding(.bottom, 4)
      if sessions.isEmpty {
        Text(store.t("No workouts in this period")).font(.subheadline).foregroundStyle(JourneyColor.secondary).padding(.vertical, 14)
      }
      LazyVStack(spacing: 0) {
        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
          if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
          NavigationLink { WorkoutDetailView(sessionID: session.id) } label: {
            HStack(alignment: .top, spacing: 10) {
              WorkoutRecap(session: session)
              Image(systemName: "chevron.right").font(.system(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
                .padding(.top, 3).accessibilityHidden(true)
            }.padding(.vertical, 14).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityIdentifier("history." + session.id.uuidString)
        }
      }
    }.padding(.horizontal, 20).padding(.bottom, 6).frame(maxWidth: .infinity, alignment: .leading)
      .journeySurface(cornerRadius: 24)
  }
}

/// A workout in one glance: name and date, sets and minutes, the exercises in full.
struct WorkoutRecap: View {
  @EnvironmentObject private var store: GymStore
  let session: Session
  private var exerciseNames: String {
    var seen = Set<String>()
    return session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }.map { store.t($0.name) }.joined(separator: " · ")
  }
  private var detail: String {
    var parts = [setCount(session.completedSets.count, store: store), "\(max(1, Int(session.duration / 60))) " + store.t("min")]
    if session.volumeKG > 0 {
      parts.append(formatNumber(GymStore.displayedWeight(session.volumeKG, unit: store.profile.unit).rounded()) + " " + store.profile.unit)
    }
    return parts.joined(separator: " · ")
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(store.t(session.name)).font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.text).lineLimit(1)
        Spacer(minLength: 8)
        Text(session.ended ?? session.started, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
          .font(JourneyType.caption).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(1)
      }
      Text(detail).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary)
      if !exerciseNames.isEmpty {
        Text(exerciseNames).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary)
          .lineLimit(2).fixedSize(horizontal: false, vertical: true)
      }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// One workout, set by set. A List on the stage: the summary's eyebrow and headline up top, then a
/// clean table per exercise. Sets open the editor; the workout can be deleted from the bottom.
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
            Text(store.t("Set in progress")).foregroundStyle(JourneyColor.secondary)
            Spacer()
            Button(store.t("Cancel set"), action: cancelSet).foregroundStyle(JourneyColor.signal).accessibilityIdentifier("set.cancel")
          }.frame(minHeight: 44)
        }
      }
      if let session {
        if !embedded { header(session) }
        ForEach(exercises) { exercise in
          Section {
            let sets = session.sets.filter { $0.exercise.id == exercise.id }
            HStack {
              Text(store.t("Set")).frame(width: 40, alignment: .leading)
              if !exercise.timed { Spacer(); Text(store.t("Weight") + " (" + store.profile.unit + ")") }
              Spacer()
              Text(store.t(exercise.timed ? "Time" : "Reps")).frame(width: 60, alignment: .trailing)
            }.font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).accessibilityHidden(true)
            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
              Button { editing = set } label: {
                if typeSize.isAccessibilitySize {
                  VStack(alignment: .leading, spacing: 6) {
                    Text(store.t("Set") + " \(index + 1)").foregroundStyle(JourneyColor.tertiary)
                    Text(setValue(set, store: store)).monospacedDigit().foregroundStyle(JourneyColor.text)
                  }
                } else {
                  HStack {
                    Text("\(index + 1)").font(.subheadline).foregroundStyle(JourneyColor.tertiary).frame(width: 40, alignment: .leading)
                    if !exercise.timed {
                      Spacer()
                      Text(set.weightKG == 0 ? store.t("Bodyweight") : formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)))
                        .foregroundStyle(JourneyColor.text)
                    }
                    Spacer()
                    Text(set.unsuccessful == true ? store.t("Attempt") : exercise.timed ? formatNumber(set.minutes) + " " + store.t("min") : String(set.reps))
                      .foregroundStyle(set.unsuccessful == true ? JourneyColor.secondary : JourneyColor.text)
                      .frame(minWidth: 60, alignment: .trailing)
                  }.monospacedDigit().frame(minHeight: 44)
                }
              }.accessibilityLabel(store.t("Set") + " \(index + 1), " + setValue(set, store: store))
                .accessibilityIdentifier("saved." + set.id.uuidString)
            }
          } header: {
            Text(store.t(exercise.name)).font(.headline).foregroundStyle(JourneyColor.text).textCase(nil)
          }
        }
        if session.sets.isEmpty { Text(store.t("No sets yet")).foregroundStyle(JourneyColor.secondary) }
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
  /// The summary's opening: the date as an eyebrow, the headline numbers, one caption.
  private func header(_ session: Session) -> some View {
    var seen = Set<String>()
    let exerciseCount = session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }.count
    var headline = ["\(max(1, Int(session.duration / 60))) " + store.t("min")]
    if session.totalReps > 0 { headline.append("\(session.totalReps) " + store.t("reps")) }
    var caption = [exerciseCount == 1 ? store.t("1 exercise") : "\(exerciseCount) " + store.t("exercises"), setCount(session.completedSets.count, store: store)]
    if session.volumeKG > 0 {
      caption.append(formatNumber(GymStore.displayedWeight(session.volumeKG, unit: store.profile.unit).rounded()) + " " + store.profile.unit)
    }
    return Section {
      VStack(alignment: .leading, spacing: 8) {
        Eyebrow(text: (session.ended ?? session.started).formatted(.dateTime.weekday(.wide).day().month(.abbreviated).year()))
        Text(headline.joined(separator: " · ")).font(.system(.title, weight: .bold)).tracking(-0.4).monospacedDigit()
          .foregroundStyle(JourneyColor.text).lineLimit(2).minimumScaleFactor(0.7)
        Text(caption.joined(separator: " · ")).font(JourneyType.caption).monospacedDigit().foregroundStyle(JourneyColor.secondary)
      }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
        .accessibilityElement(children: .combine)
    }.listRowBackground(Color.clear)
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
        Text(setValue(set, store: store)).monospacedDigit().foregroundStyle(JourneyColor.secondary)
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
