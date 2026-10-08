import ActivityKit
import Foundation

/// The running workout on the Lock Screen and in the Dynamic Island, so a rest can be timed
/// without unlocking the phone. Shared by the app and the GymBlockLive extension.
struct WorkoutActivityAttributes: ActivityAttributes {
  enum Phase: String, Codable, Hashable { case ready, set, rest }
  struct ContentState: Codable, Hashable {
    var exercise: String
    var phase: Phase
    /// When the set or the rest began; the views count from it on their own.
    var since: Date
    var restSeconds: Int
    var setNumber: Int
    var setTarget: Int
    /// The next set's load, e.g. "80 kg × 5".
    var next: String
    var restUp: String
    var restLabel: String
    var setLabel: String
    var readyLabel: String
    /// "Set 2 of 3".
    var progress: String
    /// "Start set", "Finish set" or "Resume"; empty when the app needs you (e.g. a weight is missing).
    var action: String
    /// While paused, every clock shows this moment and nothing counts.
    var pausedAt: Date?
    var pausedLabel: String
  }
  var id: String
  var workoutName: String
  var started: Date
}
