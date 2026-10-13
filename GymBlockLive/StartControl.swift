import AppIntents
import SwiftUI
import WidgetKit

/// Start workout in Control Center, the Lock Screen control slot or on the Action button: the only
/// start outside the app. It only opens GymBlock, which starts what's up next through Home's own
/// Start, so the Screen Time question still shows and the offer wall still holds. While a workout runs,
/// it opens that workout. The symbol is interim until the user picks a kettlebell from rendered options.
@available(iOS 18.0, *)
struct StartWorkoutControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: WidgetKind.startControl, provider: StartControlProvider()) { value in
      ControlWidgetButton(action: OpenGymBlockIntent(value.running ? .workout : .start)) {
        Label(value.title, systemImage: "dumbbell.fill")  // interim; never figure.*
      }
      // Control Center is always dark. The title only: no subtitle API for buttons is confirmed.
      .tint(Paper.signal.dark.color)
    }
    .displayName("Start workout")
    .description("Opens GymBlock and starts what's up next.")
  }
}

/// The running workout's name, or "Start workout" in the app's language; the extension's own string
/// before the app has written anything.
@available(iOS 18.0, *)
struct StartControlProvider: ControlValueProvider {
  struct Value {
    let running: Bool
    let title: String
  }

  var previewValue: Value { Value(running: false, title: String(localized: "Start workout")) }

  func currentValue() async throws -> Value {
    guard let s = WidgetSnapshot.load() else { return previewValue }
    return s.state == .running ? Value(running: true, title: s.hero) : Value(running: false, title: s.labels.startWorkout)
  }
}
