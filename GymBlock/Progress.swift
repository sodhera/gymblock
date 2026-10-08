import Charts
import SwiftUI

/// The exercises with records in one scope (a split, or free workouts). Opens on the scope of the
/// most recent workout, so someone who trains with splits lands on their own records.
struct ExerciseProgressList: View {
  @EnvironmentObject private var store: GymStore
  @State private var scopeID: UUID?
  @State private var resolved: Bool
  var title = "Exercise progress"
  init(scopeID: UUID? = nil, title: String = "Exercise progress") {
    _scopeID = State(initialValue: scopeID); _resolved = State(initialValue: scopeID != nil); self.title = title
  }
  private var scopes: [Workout] {
    var seen = Set<UUID>()
    return (store.data.workouts + store.data.history.compactMap { s in
      s.splitID.map { Workout(id: $0, name: s.name, exercises: s.exercises) }
    }).filter { seen.insert($0.id).inserted }
  }
  private var scope: Workout? { scopes.first { $0.id == scopeID } }
  private var sessions: [Session] { store.data.history.filter { $0.splitID == scopeID } }
  private var exercises: [Exercise] {
    var seen = Set<String>()
    return sessions.flatMap(\.sets).filter(\.completed).map(\.exercise).filter { seen.insert($0.id).inserted }
  }
  /// The newest comparable set of this exercise in the scope, as the row's number.
  private func latest(_ exercise: Exercise) -> LoggedSet? {
    sessions.sorted { $0.started > $1.started }
      .lazy.compactMap { $0.sets.last { $0.exercise.id == exercise.id && $0.comparable } }.first
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Eyebrow(text: scope?.name ?? store.t("Free workouts"))
        if exercises.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text(store.t("Nothing to compare in this scope yet.")).font(JourneyType.option).foregroundStyle(JourneyColor.text)
              .fixedSize(horizontal: false, vertical: true)
            Text(store.t("Finish a workout here and its exercises appear.")).font(.subheadline).foregroundStyle(JourneyColor.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        } else {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
              if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
              NavigationLink { ExerciseProgressView(exercise: exercise, split: scope) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                  Text(store.t(exercise.name)).font(.body).foregroundStyle(JourneyColor.text)
                    .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                  Spacer(minLength: 8)
                  if let set = latest(exercise) {
                    Text(setValue(set, store: store)).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(1)
                  }
                  Image(systemName: "chevron.right").font(.system(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
                    .accessibilityHidden(true)
                }.padding(.vertical, 14).contentShape(Rectangle())
              }.buttonStyle(.plain).accessibilityIdentifier("progress.exercise." + exercise.id)
            }
          }.padding(.horizontal, 20).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading)
            .journeySurface(cornerRadius: 24)
        }
      }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }.gymPage().navigationTitle(store.t(title)).navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Picker(store.t("Scope"), selection: $scopeID) {
            Text(store.t("Free workouts")).tag(Optional<UUID>.none)
            ForEach(scopes) { Text($0.name).tag(Optional($0.id)) }
          }.pickerStyle(.menu).accessibilityIdentifier("progress.scope")
        }
      }
      .onAppear {
        guard !resolved else { return }
        resolved = true
        scopeID = store.data.history.filter { !$0.completedSets.isEmpty }
          .max { ($0.ended ?? $0.started) < ($1.ended ?? $1.started) }?.splitID
      }
  }
}

/// One exercise within one scope: Before and After like for like (reps or load held constant),
/// the difference as the headline, the line over time, and the records beneath.
struct ExerciseProgressView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  let exercise: Exercise
  var split: Workout? = nil
  @State private var repMode = true
  private var sessions: [Session] {
    store.data.history.filter { $0.splitID == split?.id }.sorted { $0.started < $1.started }
  }
  private var latest: LoggedSet? {
    sessions.reversed().first { $0.sets.contains { $0.exercise.id == exercise.id && $0.comparable } }?
      .sets.last { $0.exercise.id == exercise.id && $0.comparable }
  }
  private func comparable(repMode: Bool) -> [ProgressPoint] {
    guard let latest, !exercise.timed else { return [] }
    return sessions.compactMap { session in
      let sets = session.sets.filter {
        $0.exercise.id == exercise.id && $0.comparable &&
          (repMode ? abs($0.weightKG - latest.weightKG) < 0.001 : $0.reps == latest.reps)
      }
      let best = sets.max { repMode ? $0.reps < $1.reps : $0.weightKG < $1.weightKG }
      return best.map { ProgressPoint(sessionID: session.id, date: session.ended ?? session.started, weightKG: $0.weightKG, reps: $0.reps) }
    }
  }
  private var points: [ProgressPoint] { comparable(repMode: repMode) }
  private var records: [LoggedSet] { sessions.flatMap(\.sets).filter { $0.exercise.id == exercise.id && $0.completed } }
  private var unit: String { repMode ? store.t("reps") : store.profile.unit }
  private func amount(_ p: ProgressPoint) -> Double { repMode ? Double(p.reps) : GymStore.displayedWeight(p.weightKG, unit: store.profile.unit) }
  private func setText(_ p: ProgressPoint) -> String {
    (p.weightKG == 0 ? store.t("BW") : formatNumber(GymStore.displayedWeight(p.weightKG, unit: store.profile.unit)) + " " + store.profile.unit) + " × \(p.reps)"
  }
  private let shownRecords = 6
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Eyebrow(text: split?.name ?? store.t("Free workouts"))
        if comparable(repMode: true).count > 1 && comparable(repMode: false).count > 1 {
          Picker(store.t("Compare"), selection: $repMode) {
            Text(store.t("Reps")).tag(true); Text(store.t("Weight")).tag(false)
          }.pickerStyle(.segmented)
        }
        if let first = points.first, let last = points.last, points.count > 1 {
          beforeAfter(first, last)
          let difference = amount(last) - amount(first)
          VStack(alignment: .leading, spacing: 6) {
            Text((difference > 0 ? "+" : "") + formatNumber(difference) + " " + unit)
              .font(.system(.largeTitle, weight: .bold)).monospacedDigit()
              .foregroundStyle(difference > 0 ? JourneyColor.signal : JourneyColor.text)
              .lineLimit(1).minimumScaleFactor(0.5)
              .accessibilityIdentifier("progress.change")
            if let latest {
              Text(repMode ? store.t("Same weight") + " · " + (latest.weightKG == 0 ? store.t("Bodyweight") : formatNumber(GymStore.displayedWeight(latest.weightKG, unit: store.profile.unit)) + " " + store.profile.unit)
                   : store.t("Same reps") + " · \(latest.reps)")
                .font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
            }
          }.padding(.horizontal, 4).padding(.vertical, 6)
          chart
          recordsCard
        } else {
          if !exercise.timed {
            Text(store.t("No matching comparison yet")).font(JourneyType.option).foregroundStyle(JourneyColor.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          if !records.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
              Eyebrow(text: store.t("All records")).padding(.top, 16).padding(.bottom, 4)
              ForEach(Array(records.reversed().enumerated()), id: \.element.id) { index, set in
                if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
                HStack(alignment: .firstTextBaseline) {
                  Text(set.date, format: .dateTime.day().month(.abbreviated)).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary)
                  Spacer(minLength: 8)
                  Text(setValue(set, store: store)).font(.system(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(JourneyColor.text)
                }.padding(.vertical, 12).accessibilityElement(children: .combine)
              }
            }.padding(.horizontal, 20).padding(.bottom, 6).frame(maxWidth: .infinity, alignment: .leading).journeySurface()
          }
        }
      }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }.gymPage().navigationTitle(store.t(exercise.name)).navigationBarTitleDisplayMode(.inline).track(screen: "progress.exercise", ["exercise": exercise.id])
      .animation(.smooth(duration: 0.35), value: repMode)
      .onAppear { repMode = comparable(repMode: true).count > 1 || comparable(repMode: false).count < 2 }
  }

  /// Two glass tiles with an arrow between; After carries the signal.
  @ViewBuilder private func beforeAfter(_ first: ProgressPoint, _ last: ProgressPoint) -> some View {
    if typeSize.isAccessibilitySize {
      VStack(alignment: .leading, spacing: 10) {
        tile("Before", point: first, red: false)
        Image(systemName: "arrow.down").font(.system(.body, weight: .bold)).foregroundStyle(JourneyColor.tertiary)
          .frame(maxWidth: .infinity).accessibilityHidden(true)
        tile("After", point: last, red: true)
      }
    } else {
      JourneyGlassGroup(spacing: 10) {
        HStack(spacing: 10) {
          tile("Before", point: first, red: false)
          Image(systemName: "arrow.right").font(.system(.body, weight: .bold)).foregroundStyle(JourneyColor.tertiary)
            .accessibilityHidden(true)
          tile("After", point: last, red: true)
        }
      }
    }
  }
  private func tile(_ label: String, point: ProgressPoint, red: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Eyebrow(text: store.t(label) + " · " + point.date.formatted(.dateTime.day().month(.abbreviated)))
      Text(setText(point)).font(.system(.title2, weight: .bold)).monospacedDigit()
        .foregroundStyle(red ? JourneyColor.signal : JourneyColor.text).lineLimit(1).minimumScaleFactor(0.6)
    }.padding(16).frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
      .journeySurface(cornerRadius: 22)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(store.t(label) + ", " + point.date.formatted(.dateTime.day().month(.abbreviated)) + ", " + setText(point))
  }
  /// The best comparable set per workout, over time.
  private var chart: some View {
    VStack(alignment: .leading, spacing: 12) {
      Eyebrow(text: unit)
      Chart(points) { point in
        LineMark(x: .value("Date", point.date), y: .value(unit, amount(point)))
          .foregroundStyle(JourneyColor.signal).interpolationMethod(.monotone)
          .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        PointMark(x: .value("Date", point.date), y: .value(unit, amount(point)))
          .foregroundStyle(JourneyColor.signal).symbolSize(40)
      }
      .chartXAxis {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
          AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.caption2).foregroundStyle(JourneyColor.tertiary)
        }
      }
      .chartYAxis {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
          AxisGridLine().foregroundStyle(JourneyColor.hairline)
          AxisValueLabel().font(.caption2).foregroundStyle(JourneyColor.tertiary)
        }
      }
      .frame(height: 160)
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).journeySurface()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(unit + ", \(points.count) " + store.t("workouts"))
      .accessibilityIdentifier("progress.chart")
  }
  /// The newest records; the full list is one tap away when there are more.
  private var recordsCard: some View {
    let shown = Array(points.reversed().prefix(shownRecords))
    return VStack(alignment: .leading, spacing: 0) {
      Eyebrow(text: store.t("All records")).padding(.top, 16).padding(.bottom, 4)
      ForEach(Array(shown.enumerated()), id: \.element.id) { index, point in
        if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
        HStack(alignment: .firstTextBaseline) {
          Text(point.date, format: .dateTime.day().month(.abbreviated)).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary)
          Spacer(minLength: 8)
          Text(setText(point)).font(.system(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(JourneyColor.text)
        }.padding(.vertical, 12).accessibilityElement(children: .combine)
      }
      if points.count > shownRecords {
        Rectangle().fill(JourneyColor.hairline).frame(height: 1)
        NavigationLink { ComparisonHistory(points: points, repMode: repMode, unit: unit) } label: {
          HStack {
            Text(store.t("All records")).font(.subheadline).foregroundStyle(JourneyColor.text)
            Spacer()
            Text("\(points.count)").font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary)
            Image(systemName: "chevron.right").font(.system(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
              .accessibilityHidden(true)
          }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain)
      }
    }.padding(.horizontal, 20).padding(.bottom, 6).frame(maxWidth: .infinity, alignment: .leading).journeySurface()
  }
}

/// Every comparable record, newest first.
struct ComparisonHistory: View {
  @EnvironmentObject private var store: GymStore
  let points: [ProgressPoint]
  let repMode: Bool
  let unit: String
  private func value(_ point: ProgressPoint) -> Double { repMode ? Double(point.reps) : GymStore.displayedWeight(point.weightKG, unit: store.profile.unit) }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(points.reversed().enumerated()), id: \.element.id) { index, point in
          if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
          HStack(alignment: .firstTextBaseline) {
            Text(point.date, format: .dateTime.day().month(.abbreviated).year()).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary)
            Spacer(minLength: 8)
            Text(formatNumber(value(point)) + " " + unit).font(.system(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(JourneyColor.text)
          }.padding(.vertical, 12).accessibilityElement(children: .combine)
        }
      }.padding(.horizontal, 20).padding(.vertical, 4).frame(maxWidth: .infinity, alignment: .leading).journeySurface()
        .padding(24)
    }.gymPage().navigationTitle(store.t("All records")).navigationBarTitleDisplayMode(.inline).track(screen: "progress.records")
  }
}
