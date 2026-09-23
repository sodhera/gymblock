import DeviceActivity
import Foundation
import ManagedSettings

// The safety cap. When a workout starts the app schedules a DeviceActivity
// interval of `SharedSchedule.safetyCapHours`; the block is normally lifted
// long before by finishing the workout in the app (which also stops this
// monitoring). If that never happens — crash, dead battery, forgotten
// session — the interval ends here and the shield comes down anyway.
// A gym app must never leave someone's phone locked overnight.

nonisolated class GymBlockMonitor: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue == SharedSchedule.safetyActivity else { return }
        ManagedSettingsStore(named: .gymblock).clearAllSettings()
        SharedWorkoutState.clear()
    }
}
