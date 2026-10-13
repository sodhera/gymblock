import AppIntents
import Foundation

/// Where the Start workout control takes the app.
enum GymDestination: String, AppEnum {
  case start, workout
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Destination"
  static var caseDisplayRepresentations: [GymDestination: DisplayRepresentation] = [.start: "Start workout", .workout: "Workout"]
}

/// Opens GymBlock from the control: starts what's up next, or shows the running workout. It only opens
/// the app, never starts anything itself, so the Screen Time question still shows and onboarding and
/// the offer wall still hold (`AppRouter` acts only on the app screen, within 10 seconds). It belongs
/// to the app and the GymBlockLive extension both, or the system won't open the app.
struct OpenGymBlockIntent: OpenIntent {
  static var title: LocalizedStringResource = "Open GymBlock"
  /// The control's alone: kept out of Shortcuts, so no automation can start a workout.
  static var isDiscoverable: Bool { false }
  @Parameter(title: "Destination") var target: GymDestination
  init() {}
  init(_ target: GymDestination) { self.target = target }
  func perform() async throws -> some IntentResult {
    #if !LIVE_EXTENSION
      let route: AppRoute = target == .start ? .start : .workout
      await MainActor.run { AppRouter.shared.open(route, source: "control") }
    #endif
    return .result()
  }
}
