import ActivityKit
import Foundation

/// Owns the one workout Live Activity. The store calls `sync` whenever the
/// workout or rest timer changes; this starts, updates or ends the activity
/// to match, skipping updates that wouldn't change anything.
@MainActor
final class WorkoutActivityController {
    private var activity: Activity<WorkoutActivityAttributes>?
    private var lastState: WorkoutActivityAttributes.ContentState?

    init() {
        activity = Activity<WorkoutActivityAttributes>.activities.first
    }

    func sync(workout: Workout?, state: WorkoutActivityAttributes.ContentState?) {
        guard let workout, let state else {
            end()
            return
        }
        if activity == nil || activity?.activityState == .ended || activity?.activityState == .dismissed {
            start(workout: workout, state: state)
        } else if state != lastState {
            update(state)
        }
    }

    /// Ends any activity left over from a previous launch with no workout.
    func endOrphans(hasWorkout: Bool) {
        guard !hasWorkout else { return }
        for orphan in Activity<WorkoutActivityAttributes>.activities {
            Task { await orphan.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
    }

    private func start(workout: Workout, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for old in Activity<WorkoutActivityAttributes>.activities {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
        do {
            activity = try Activity.request(
                attributes: WorkoutActivityAttributes(title: workout.title, start: workout.start),
                content: ActivityContent(state: state, staleDate: state.restEnd)
            )
            lastState = state
        } catch {
            AppLog.app.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        lastState = state
        // staleDate = rest end: if the app is suspended when rest runs out,
        // the system flips the activity to its "Rest's over" state itself.
        let content = ActivityContent(state: state, staleDate: state.restEnd)
        Task { await activity.update(content) }
    }

    private func end() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
