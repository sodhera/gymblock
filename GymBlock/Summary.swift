import SwiftUI

/// After a workout: what you did, and anything you beat like for like. One tap back to Home.
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
  private var canSaveSplit: Bool {
    session.splitID == nil && !session.completedSets.isEmpty && !saved
  }
  var body: some View {
    ZStack {
      DotGrid()
      VStack(alignment: .leading, spacing: 0) {
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
        VStack(alignment: .leading, spacing: 8) {
          Text(store.profile.name.isEmpty ? store.t("Workout saved.") : store.t("Nice work,") + " " + store.profile.name + ".")
            .font(JourneyType.headline).foregroundStyle(JourneyColor.text)
            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("summary.title")
          Text(store.t(session.name) + " · " + (session.ended ?? session.started).formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            .font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
        }.padding(.top, 64).padding(.bottom, 32)
        JourneyGlassGroup(spacing: 12) {
          VStack(spacing: 12) {
            HStack(spacing: 12) {
              tile("Time", value: Double(max(1, Int(session.duration / 60))), format: { "\(Int($0)) " + store.t("min") }, id: "summary.time")
              tile("Sets", value: Double(session.completedSets.count), format: { "\(Int($0))" }, id: "summary.sets")
            }
            HStack(spacing: 12) {
              if session.volumeKG > 0 {
                tile("Weight moved", value: GymStore.displayedWeight(session.volumeKG, unit: store.profile.unit),
                     format: { formatNumber($0.rounded()) + " " + store.profile.unit }, id: "summary.volume")
              } else {
                tile("Reps", value: Double(session.totalReps), format: { "\(Int($0))" }, id: "summary.reps")
              }
              if let rest = session.averageRest {
                tile("Average rest", value: rest, format: { clockString(Int($0)) }, id: "summary.rest")
              } else {
                tile("Reps", value: Double(session.totalReps), format: { "\(Int($0))" }, id: "summary.reps")
                  .opacity(session.volumeKG > 0 ? 1 : 0).accessibilityHidden(session.volumeKG == 0)
              }
            }
          }
        }
        if !gains.isEmpty {
          VStack(alignment: .leading, spacing: 14) {
            Text(store.t("Better than last time")).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
            ForEach(gains) { gain in
              HStack(alignment: .firstTextBaseline) {
                Text(store.t(gain.exercise.name)).font(.body).foregroundStyle(JourneyColor.text).lineLimit(1)
                Spacer(minLength: 8)
                Text(gainText(gain)).font(.system(.body, weight: .semibold)).monospacedDigit()
                  .foregroundStyle(JourneyColor.signalRed).lineLimit(1).minimumScaleFactor(0.8)
              }.accessibilityElement(children: .combine)
            }
          }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .journeyGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.top, 12).accessibilityIdentifier("summary.gains")
            .opacity(shown ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 8)
        }
        recap.padding(.top, 12).opacity(shown ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 8)
        }.padding(.top, 0).padding(.bottom, 16)
        }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
        VStack(spacing: 10) {
          Color.clear.frame(height: 20)
          JourneyButton(title: store.t("Done"), id: "summary.done") { store.summary = nil }
          if canSaveSplit {
            JourneyTextButton(title: store.t("Save as split"), id: "summary.saveSplit") {
              splitName = session.name == "Free workout" ? "" : session.name; naming = true
            }
          } else {
            Text(saved ? store.t("Saved as a split.") : " ").font(JourneyType.caption)
              .foregroundStyle(JourneyColor.secondary).frame(height: 44)
          }
        }.padding(.top, 8)
      }.padding(.horizontal, 24).padding(.bottom, 4)
    }
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
      withAnimation(.easeOut(duration: 1.0)) { shown = true }
      try? await Task.sleep(for: .seconds(0.9))
      JourneyHaptic.land(store.profile)
    }
  }
  /// What you did, exercise by exercise: sets and the best set.
  private var recap: some View {
    var seen = Set<String>()
    let exercises = session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }
    return VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(exercises.prefix(6).enumerated()), id: \.element.id) { index, exercise in
        let sets = session.sets.filter { $0.exercise.id == exercise.id && $0.completed }
        let best = sets.max { exercise.timed ? $0.minutes < $1.minutes : ($0.weightKG == $1.weightKG ? $0.reps < $1.reps : $0.weightKG < $1.weightKG) }
        if index > 0 { Rectangle().fill(JourneyColor.hairline).frame(height: 1) }
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          VStack(alignment: .leading, spacing: 3) {
            Text(store.t(exercise.name)).font(.body).foregroundStyle(JourneyColor.text).lineLimit(1)
            if let best { Text(setValue(best, store: store)).font(.subheadline).foregroundStyle(JourneyColor.secondary).monospacedDigit() }
          }
          Spacer(minLength: 8)
          Text(setCount(sets.count, store: store)).font(.subheadline).foregroundStyle(JourneyColor.secondary).monospacedDigit()
        }.padding(.vertical, 12).accessibilityElement(children: .combine)
      }
      if exercises.count > 6 {
        Text("+\(exercises.count - 6) " + store.t("more")).font(.subheadline).foregroundStyle(JourneyColor.tertiary).padding(.vertical, 10)
      }
    }.padding(.horizontal, 20).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
      .journeyGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
      .accessibilityIdentifier("summary.recap")
  }
  private func tile(_ title: String, value: Double, format: @escaping (Double) -> String, id: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(store.t(title)).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
      CountingText(value: shown ? value : 0, format: format)
        .font(.system(.title, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        .lineLimit(1).minimumScaleFactor(0.6)
    }.padding(18).frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
      .journeyGlass(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(store.t(title) + ", " + format(value)).accessibilityIdentifier(id)
  }
  private func gainText(_ gain: Improvement) -> String {
    if let kg = gain.weightGainKG {
      return "+" + formatNumber(GymStore.displayedWeight(kg, unit: store.profile.unit)) + " " + store.profile.unit
        + " · \(gain.reps) " + store.t("reps")
    }
    return "+\(gain.repGain ?? 0) " + store.t("reps") + " · "
      + (gain.weightKG == 0 ? store.t("BW") : formatNumber(GymStore.displayedWeight(gain.weightKG, unit: store.profile.unit)) + " " + store.profile.unit)
  }
}
