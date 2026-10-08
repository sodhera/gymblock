import SwiftUI

/// After a workout: one headline number, the rest of the story beneath it, and anything you beat
/// like for like. One tap back to Home. The first workout and a workout with gains each get their
/// own headline, so the page never reads the same twice in a row.
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
  private var first: Bool { store.data.history.filter { !$0.completedSets.isEmpty }.count <= 1 }
  private var name: String { store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var title: String {
    if !gains.isEmpty { return store.t("Stronger than last time") + (name.isEmpty ? "." : ", " + name + ".") }
    if first { return store.t("First one in the log") + (name.isEmpty ? "." : ", " + name + ".") }
    return name.isEmpty ? store.t("Workout saved.") : store.t("Nice work,") + " " + name + "."
  }
  var body: some View {
    ZStack {
      DotGrid()
      VStack(alignment: .leading, spacing: 0) {
        ScrollView {
          Color.clear.frame(height: 0).track(screen: "summary", ["sets": session.completedSets.count])
          VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
              Eyebrow(text: store.t(session.name) + " · " + (session.ended ?? session.started).formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
              Text(title).font(JourneyType.headline).tracking(-0.4).foregroundStyle(JourneyColor.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("summary.title")
            }.padding(.top, 48).padding(.bottom, 10)
            hero
            JourneyGlassGroup(spacing: 12) {
              HStack(spacing: 12) {
                tile("Time", value: Double(max(1, Int(session.duration / 60))), format: { "\(Int($0)) " + store.t("min") }, id: "summary.time")
                tile("Sets", value: Double(session.completedSets.count), format: { "\(Int($0))" }, id: "summary.sets")
                if let rest = session.averageRest {
                  tile("Avg rest", value: rest, format: { clockString(Int($0)) }, id: "summary.rest")
                } else {
                  tile("Reps", value: Double(session.totalReps), format: { "\(Int($0))" }, id: "summary.reps")
                }
              }
            }
            if !gains.isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: store.t("Better than last time"))
                ForEach(gains) { gain in
                  HStack(alignment: .firstTextBaseline) {
                    Text(store.t(gain.exercise.name)).font(.body).foregroundStyle(JourneyColor.text).lineLimit(1)
                    Spacer(minLength: 8)
                    HStack(spacing: 4) {
                      Image(systemName: "arrow.up").font(.system(.caption, weight: .bold))
                      Text(gainText(gain)).font(.system(.body, weight: .semibold)).monospacedDigit()
                    }.foregroundStyle(JourneyColor.signal).lineLimit(1).minimumScaleFactor(0.8)
                  }.accessibilityElement(children: .combine)
                }
              }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .journeySurface()
                .accessibilityIdentifier("summary.gains")
                .opacity(shown ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 8)
            }
            recap.opacity(shown ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 8)
          }.padding(.bottom, 16)
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

  /// The headline number: weight moved, or reps for bodyweight and timed work.
  private var hero: some View {
    let volume = session.volumeKG > 0
    let value = volume ? GymStore.displayedWeight(session.volumeKG, unit: store.profile.unit) : Double(session.totalReps)
    return VStack(alignment: .leading, spacing: 6) {
      Eyebrow(text: store.t(volume ? "Weight moved" : "Reps"))
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        CountingText(value: shown ? value : 0) { formatNumber($0.rounded()) }
          .font(.system(.largeTitle, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
          .lineLimit(1).minimumScaleFactor(0.5)
        if volume { Text(store.profile.unit).font(.system(.title2, weight: .semibold)).foregroundStyle(JourneyColor.secondary) }
      }
      Text(heroNote).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
      .background(alignment: .topTrailing) {
        Circle().fill(RadialGradient(colors: [JourneyColor.glow.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: 130))
          .frame(width: 260, height: 260).offset(x: 60, y: -90).allowsHitTesting(false)
      }
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .journeySurface()
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(store.t(volume ? "Weight moved" : "Reps") + ", " + formatNumber(value.rounded()) + (volume ? " " + store.profile.unit : ""))
      .accessibilityIdentifier(volume ? "summary.volume" : "summary.reps")
  }
  private var heroNote: String {
    var seen = Set<String>()
    let count = session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }.count
    let exercises = count == 1 ? store.t("1 exercise") : "\(count) " + store.t("exercises")
    return exercises + " · " + setCount(session.completedSets.count, store: store)
  }
  /// What you did, exercise by exercise: sets and the best set.
  private var recap: some View {
    var seen = Set<String>()
    let exercises = session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }
    return VStack(alignment: .leading, spacing: 0) {
      Eyebrow(text: store.t("Exercises")).padding(.top, 14).padding(.bottom, 4)
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
    }.padding(.horizontal, 16).padding(.bottom, 4).frame(maxWidth: .infinity, alignment: .leading)
      .journeySurface()
      .accessibilityIdentifier("summary.recap")
  }
  private func tile(_ title: String, value: Double, format: @escaping (Double) -> String, id: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(store.t(title)).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).lineLimit(1).minimumScaleFactor(0.8)
      CountingText(value: shown ? value : 0, format: format)
        .font(.system(.title3, weight: .bold)).monospacedDigit().foregroundStyle(JourneyColor.text)
        .lineLimit(1).minimumScaleFactor(0.6)
    }.padding(.horizontal, 14).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
      .journeySurface(cornerRadius: 18)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(store.t(title) + ", " + format(value)).accessibilityIdentifier(id)
  }
  private func gainText(_ gain: Improvement) -> String {
    if let kg = gain.weightGainKG {
      return formatNumber(GymStore.displayedWeight(kg, unit: store.profile.unit)) + " " + store.profile.unit
        + " · \(gain.reps) " + store.t("reps")
    }
    return "\(gain.repGain ?? 0) " + store.t("reps") + " · "
      + (gain.weightKG == 0 ? store.t("BW") : formatNumber(GymStore.displayedWeight(gain.weightKG, unit: store.profile.unit)) + " " + store.profile.unit)
  }
}
