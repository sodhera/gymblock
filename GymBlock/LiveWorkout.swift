import ActivityKit
import Foundation

/// Keeps one Live Activity in step with the running workout: started with it, updated when a set
/// or rest begins, ended with it. Everything is local; there are no push updates.
@MainActor enum LiveWorkout {
  private static var last: WorkoutActivityAttributes.ContentState?
  /// The latest update, so a Lock Screen button can wait for it before the app is suspended again.
  private(set) static var pending: Task<Void, Never>?
  private static var enabled: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil }
  static func sync(_ store: GymStore) {
    guard enabled else { return }
    guard let session = store.session, let exercise = session.selected else { end(); return }
    let phase: WorkoutActivityAttributes.Phase =
      session.stage == .active || session.stage == .log ? .set : session.stage == .rest ? .rest : .ready
    let since = phase == .set ? session.setStarted : phase == .rest ? session.restStarted : session.started
    let done = store.doneSets(exercise), target = store.targetSets(exercise)
    let weight = session.weightIsSet == false ? "" : session.weightKG == 0 ? store.t("Bodyweight")
      : formatNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit)) + " " + store.profile.unit
    let next = exercise.timed ? store.t("Timed") : weight + (store.draftRepCount.map { " × \($0)" } ?? "")
    let state = WorkoutActivityAttributes.ContentState(
      exercise: store.t(exercise.name), phase: phase, since: since ?? session.started,
      restSeconds: store.restTarget, setNumber: done + 1, setTarget: target, next: next,
      restUp: store.t("Rest’s up"), restLabel: store.t("Rest"), setLabel: store.t("Set time"),
      readyLabel: store.t("Ready"),
      progress: done >= target && phase != .set ? "\(done) " + store.t("of") + " \(target) " + store.t("done")
        : store.t("Set") + " \(done + 1) " + store.t("of") + " \(target)",
      action: session.pausedAt != nil ? store.t("Resume") : phase == .set ? store.t("Finish set")
        : !exercise.timed && session.weightIsSet == false ? ""
        : store.timesSets || exercise.timed ? store.t("Start set") : store.t("Log set"),
      pausedAt: session.pausedAt, pausedLabel: store.t("Paused"))
    guard state != last else { return }
    last = state
    let stale = phase == .rest && session.pausedAt == nil ? state.since.addingTimeInterval(Double(state.restSeconds)) : nil
    let content = ActivityContent(state: state, staleDate: stale)
    let id = session.id.uuidString
    let activities = Activity<WorkoutActivityAttributes>.activities
    for old in activities where old.attributes.id != id {
      Task { await old.end(nil, dismissalPolicy: .immediate) }
    }
    if let current = activities.first(where: { $0.attributes.id == id }) {
      // Always update one that exists, even while iOS is still asking whether to allow them.
      pending = Task { await current.update(content) }
    } else if ActivityAuthorizationInfo().areActivitiesEnabled {
      _ = try? Activity.request(
        attributes: WorkoutActivityAttributes(id: id, workoutName: store.t(session.name), started: session.started),
        content: content)
    }
  }
  static func end() {
    last = nil
    for activity in Activity<WorkoutActivityAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
  }
}
