import DeviceActivity
import Foundation

/// Puts the block back after "Give me 1 minute" (see `BlockingPass`): when the minute's end arrives, or
/// once a minute has been spent in the blocked apps, whichever comes first. GymBlock does the same when
/// it's next opened, in case iOS is late with either.
final class PassMonitor: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    // The usage window starts with the minute; only the end window's start means it's over.
    guard activity == BlockingPass.end else { return }
    BlockingPass.restore()
  }
  override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)
    guard activity == BlockingPass.usage, event == BlockingPass.used else { return }
    BlockingPass.restore()
  }
}
