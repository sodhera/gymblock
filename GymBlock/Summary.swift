import SwiftUI

/// After a workout, designed from a clean slate on 11 Oct 2026: the time it took as the one large
/// number (start to end, never paused), the split and date above it, sets and load as one grey
/// line; then, only when something improved like for like, what you beat (the gain in emerald);
/// then every exercise as a ruled row with its sets and its time. Done sits in the fixed place.
struct SummaryView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  let session: Session
  @State private var shown = false
  @State private var naming = false
  @State private var splitName = ""
  @State private var saved = false
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  private var gains: [Improvement] { Array(store.improvements(in: session).prefix(3)) }
  private var canSaveSplit: Bool { session.splitID == nil && !session.completedSets.isEmpty && !saved }
  private var first: Bool { store.data.history.filter { !$0.completedSets.isEmpty }.count <= 1 }
  private var exercises: [Exercise] {
    var seen = Set<String>()
    return session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }
  }

  var body: some View {
    ZStack {
      DotGrid()
      ScrollView {
        VStack(alignment: .leading, spacing: 36) {
          hero.reveal(shown, 0)
          if !gains.isEmpty {
            section(store.t("Better than last time"), id: "summary.gains") {
              ForEach(Array(gains.enumerated()), id: \.element.id) { index, gain in
                if index > 0 { SettingsDivider() }
                gainRow(gain)
              }
            }.reveal(shown, 1)
          }
          section(store.t("Exercises"), id: "summary.recap") {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
              if index > 0 { SettingsDivider() }
              exerciseRow(exercise)
            }
          }.reveal(shown, 2)
        }.frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 32)
      }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { dock }
    .track(screen: "summary", ["gains": gains.count, "first": first])
    .alert(store.t("Save as split"), isPresented: $naming) {
      TextField(store.t("Split name"), text: $splitName).accessibilityIdentifier("summary.splitName")
      Button(store.t("Save")) {
        let name = splitName.trimmingCharacters(in: .whitespacesAndNewlines)
        store.saveWorkout(from: session, name: name.isEmpty ? store.t("My split") : name)
        saved = true
        JourneyHaptic.play(.success, store.profile)
      }
      Button(store.t("Cancel"), role: .cancel) {}
    } message: { Text(store.t("Start it from Home next time.")) }
    .task {
      guard !shown else { return }
      if reduceMotion { shown = true; return }
      try? await Task.sleep(for: .seconds(0.15))
      withAnimation(.spring(duration: 0.6, bounce: 0.12)) { shown = true }
      try? await Task.sleep(for: .seconds(0.5))
      JourneyHaptic.land(store.profile)
    }
  }

  /// "ARMS · OCT 11", then the minutes, large, then sets and load in grey.
  private var hero: some View {
    let minutes = max(1, Int((session.duration / 60).rounded()))
    var figures = [setCount(session.completedSets.count, store: store)]
    if session.volumeKG > 0 {
      figures.append(formatNumber(GymStore.displayedWeight(session.volumeKG, unit: store.profile.unit).rounded()) + " " + store.profile.unit)
    }
    let date = (session.ended ?? session.started).formatted(.dateTime.month(.abbreviated).day())
    return VStack(alignment: .leading, spacing: 4) {
      Text((first ? store.t("First workout") : store.t(session.name)) + " · " + date)
        .font(.system(.caption, weight: .semibold)).tracking(1.4).textCase(.uppercase)
        .foregroundStyle(JourneyColor.secondary).accessibilityIdentifier("summary.title")
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("\(minutes)").font(.system(size: 80, weight: .bold)).tracking(-2).monospacedDigit()
          .foregroundStyle(JourneyColor.text).lineLimit(1).minimumScaleFactor(0.5)
        Text(store.t("min")).font(.system(.title2, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
      }.accessibilityElement(children: .combine).accessibilityIdentifier("summary.time")
      Text(figures.joined(separator: "  ·  ")).font(.body).monospacedDigit().foregroundStyle(JourneyColor.secondary)
        .accessibilityIdentifier("summary.figures")
    }
  }

  private func section<Content: View>(_ label: String, id: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label).font(.system(.caption, weight: .semibold)).tracking(1.4).textCase(.uppercase)
        .foregroundStyle(JourneyColor.secondary).accessibilityAddTraits(.isHeader).padding(.bottom, 4)
      content()
    }.accessibilityElement(children: .contain).accessibilityIdentifier(id)
  }

  /// What you beat: the exercise and what was held constant, the gain in emerald on the right.
  private func gainRow(_ gain: Improvement) -> some View {
    let held = gain.weightGainKG != nil ? "\(gain.reps) " + store.t("reps") : weightText(gain.weightKG)
    let delta = gain.weightGainKG.map { "+" + formatNumber(GymStore.displayedWeight($0, unit: store.profile.unit)) + " " + store.profile.unit }
      ?? "+\(gain.repGain ?? 0) " + store.t("reps")
    return row(name: store.t(gain.exercise.name), detail: held) {
      Text(delta).font(.system(.body, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.signal)
    }
  }

  /// One exercise: its sets ("3 × 19 kg × 10", or the count and the best) and its time on the right.
  private func exerciseRow(_ exercise: Exercise) -> some View {
    let sets = session.sets.filter { $0.exercise.id == exercise.id }
    return row(name: store.t(exercise.name), detail: setsText(exercise, sets: sets)) {
      if let time = store.exerciseTime(sets) {
        Text(time).font(.body).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
      }
    }.accessibilityIdentifier("summary.exercise.\(exercise.id)")
  }

  private func row<Trailing: View>(name: String, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(name).font(.system(.body, weight: .medium)).foregroundStyle(JourneyColor.text).lineLimit(1)
        Text(detail).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(1)
      }
      Spacer(minLength: 8)
      trailing()
    }.frame(minHeight: 64).accessibilityElement(children: .combine)
  }

  private func setsText(_ exercise: Exercise, sets: [LoggedSet]) -> String {
    let done = sets.filter(\.completed)
    guard let best = done.max(by: { exercise.timed ? $0.minutes < $1.minutes
      : ($0.weightKG == $1.weightKG ? $0.reps < $1.reps : $0.weightKG < $1.weightKG) }) else {
      return store.t("Attempt")
    }
    let value = { (set: LoggedSet) in
      exercise.timed ? formatNumber(set.minutes) + " " + store.t("min") : weightText(set.weightKG) + " × \(set.reps)"
    }
    if done.allSatisfy({ value($0) == value(best) }) { return "\(done.count) × " + value(best) }
    return setCount(done.count, store: store) + "  ·  " + store.t("best") + " " + value(best)
  }
  private func weightText(_ kg: Double) -> String {
    kg == 0 ? store.t("BW") : formatNumber(GymStore.displayedWeight(kg, unit: store.profile.unit)) + " " + store.profile.unit
  }

  /// Done in the fixed place; Save as split sits quietly above it for a free workout.
  private var dock: some View {
    VStack(spacing: 6) {
      if canSaveSplit {
        Button(store.t("Save as split")) { splitName = session.name == "Free workout" ? "" : session.name; naming = true }
          .font(.system(.body, weight: .medium)).foregroundStyle(JourneyColor.secondary).frame(minHeight: 44)
          .accessibilityIdentifier("summary.saveSplit")
      } else if saved {
        Text(store.t("Saved as a split.")).font(.subheadline).foregroundStyle(JourneyColor.secondary).frame(minHeight: 44)
      }
      JourneyButton(title: store.t("Done"), id: "summary.done") { store.summary = nil }
    }
    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
    .background {
      VStack(spacing: 0) {
        LinearGradient(colors: [JourneyColor.stage.opacity(0), JourneyColor.stage], startPoint: .top, endPoint: .bottom).frame(height: 28)
        JourneyColor.stage
      }.padding(.top, -28).ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
    }
  }
}
