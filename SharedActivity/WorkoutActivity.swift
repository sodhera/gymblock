import ActivityKit
import AppIntents
import SwiftUI

// The workout Live Activity, shared by the app (which starts and updates it)
// and GymBlockWidget (which draws it on the Lock Screen and in the Dynamic
// Island). One activity runs for the whole workout: it shows the workout
// clock while you lift and becomes a rest countdown after each set.
//
// Every live number is a system-driven timer (`Text(timerInterval:)`,
// `ProgressView(timerInterval:)`), so the countdown ticks with no updates
// from the app. When rest runs out while the app is suspended, the
// activity's `staleDate` (= rest end) flips it to "Rest's over".

nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Set while resting; both nil otherwise.
        var restStart: Date?
        var restEnd: Date?
        /// The exercise with the next unfinished set.
        var exercise: String?
        /// 1-based number of that next set, and the exercise's set count.
        var setNumber: Int
        var setCount: Int
        var setsDone: Int
        var setsTotal: Int
        var appsLocked: Bool

        var isResting: Bool {
            guard let restEnd else { return false }
            return restEnd > .now
        }
    }

    var title: String
    var start: Date
}

// MARK: - Interactive buttons (+15s, Skip)

/// Bridge from the intents (which the system runs in the app's process) to
/// the running store. The app installs these at launch; in the widget
/// process they stay nil, which is fine — `LiveActivityIntent.perform()` is
/// always executed in the app.
nonisolated enum RestIntentBridge {
    nonisolated(unsafe) static var addSeconds: (@MainActor (Int) -> Void)?
    nonisolated(unsafe) static var skip: (@MainActor () -> Void)?
}

nonisolated struct AddRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add rest time"
    static let isDiscoverable = false

    @Parameter(title: "Seconds") var seconds: Int

    init() { seconds = 15 }
    init(seconds: Int) { self.seconds = seconds }

    func perform() async throws -> some IntentResult {
        let s = seconds
        await MainActor.run { RestIntentBridge.addSeconds?(s) }
        return .result()
    }
}

nonisolated struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip rest"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run { RestIntentBridge.skip?() }
        return .result()
    }
}

// MARK: - Palette (mirrors GBColor; the widget can't import the app)

nonisolated enum ActivityPalette {
    static let orange = Color(red: 1, green: 0x5B / 255, blue: 0x1A / 255)
    static let paper = Color(red: 0xF4 / 255, green: 0xF2 / 255, blue: 0xED / 255)
    static let ink = Color(red: 0x11 / 255, green: 0x12 / 255, blue: 0x14 / 255)
    static let steel = Color(red: 0x6E / 255, green: 0x71 / 255, blue: 0x78 / 255)
    static let mist = Color(red: 0xD9 / 255, green: 0xD6 / 255, blue: 0xCF / 255)
}
