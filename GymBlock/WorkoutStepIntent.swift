import AppIntents
import Foundation

/// The Live Activity's one button: Start set, or Finish set with the planned weight and reps.
/// It runs in the app, so a whole workout can be logged from the Lock Screen without unlocking.
struct WorkoutStepIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Start or finish a set"
  static var openAppWhenRun = false
  @Parameter(title: "Workout") var workoutID: String
  /// What the button showed: "start" or "finish". The Lock Screen can lag a moment behind the
  /// app, so a tap that no longer matches the workout's state is ignored, never applied twice.
  @Parameter(title: "Step") var step: String
  init() {}
  init(workoutID: String, step: String) { self.workoutID = workoutID; self.step = step }
  func perform() async throws -> some IntentResult {
    #if !LIVE_EXTENSION
      let update = await MainActor.run { () -> Task<Void, Never>? in
        _ = GymStore.live?.stepFromLockScreen(workoutID, expecting: step)
        return LiveWorkout.pending
      }
      await update?.value
    #endif
    return .result()
  }
}
