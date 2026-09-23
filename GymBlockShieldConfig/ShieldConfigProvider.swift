import ManagedSettings
import ManagedSettingsUI
import UIKit

// The screen someone sees when they reach for a blocked app mid-workout.
// Instead of Apple's generic grey "Restricted" card it speaks in GymBlock's
// voice and — the point of the whole feature — tells you what's left of
// *this* workout: "Instagram can wait. 3 sets of Bench Press left."
//
// Runs in its own sandboxed process with a tight memory limit: no SwiftUI,
// no app assets, only what's drawn here. Workout facts come from
// `SharedWorkoutState` (app group), which the app updates on every set.

nonisolated class ShieldConfigProvider: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(appName: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(appName: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(appName: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(appName: webDomain.domain)
    }

    // MARK: - Palette (mirrors GBColor in Theme.swift)

    private static let ink = UIColor(red: 0x11 / 255, green: 0x12 / 255, blue: 0x14 / 255, alpha: 1)
    private static let steel = UIColor(red: 0x6E / 255, green: 0x71 / 255, blue: 0x78 / 255, alpha: 1)
    private static let orange = UIColor(red: 0xFF / 255, green: 0x5B / 255, blue: 0x1A / 255, alpha: 1)
    private static let paper = UIColor(red: 0xF4 / 255, green: 0xF2 / 255, blue: 0xED / 255, alpha: 1)

    private func make(appName: String?) -> ShieldConfiguration {
        let reach = SharedWorkoutState.recordReach()
        let snapshot = SharedWorkoutState.current()
        let name = appName ?? "That"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialLight,
            backgroundColor: Self.paper,
            icon: Self.lockIcon,
            title: .init(text: title(reach: reach), color: Self.ink),
            subtitle: .init(text: subtitle(appName: name, snapshot: snapshot), color: Self.steel),
            primaryButtonLabel: .init(text: "Back to the workout", color: .white),
            primaryButtonBackgroundColor: Self.ink,
            secondaryButtonLabel: nil
        )
    }

    /// The title escalates, gently, on repeat reaches — dry, never scolding.
    private func title(reach: Int) -> String {
        switch reach {
        case ...1: "You're locked in."
        case 2: "Still locked in."
        case 3: "Third time. Still no."
        default: "You know the answer."
        }
    }

    private func subtitle(appName: String, snapshot: SharedWorkoutState.Snapshot?) -> String {
        guard let snapshot else {
            return "\(appName) can wait until you're done."
        }
        let lead = "\(appName) can wait."
        if let exercise = snapshot.currentExercise, snapshot.currentExerciseSetsLeft > 0 {
            let sets = snapshot.currentExerciseSetsLeft == 1 ? "1 set" : "\(snapshot.currentExerciseSetsLeft) sets"
            return "\(lead)\n\(sets) of \(exercise) left."
        }
        if snapshot.remainingSets > 0 {
            let sets = snapshot.remainingSets == 1 ? "1 set" : "\(snapshot.remainingSets) sets"
            return "\(lead)\n\(sets) left in \(snapshot.title)."
        }
        return "\(lead)\nFinish your workout to unlock."
    }

    /// Orange rounded square with a white lock — the app icon's grammar.
    private static let lockIcon: UIImage = {
        let size = CGSize(width: 120, height: 120)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            orange.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 36).fill()
            let config = UIImage.SymbolConfiguration(pointSize: 52, weight: .bold)
            if let lock = UIImage(systemName: "lock.fill", withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
                let s = lock.size
                lock.draw(in: CGRect(x: (size.width - s.width) / 2, y: (size.height - s.height) / 2, width: s.width, height: s.height))
            }
        }
    }()
}
