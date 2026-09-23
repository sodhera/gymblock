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

    // Dynamic, so the shield follows the phone's light/dark setting like the app.
    private static let ink = dynamic(0x111214, 0xF2F1EC)
    private static let onInk = dynamic(0xFFFFFF, 0x111214)
    private static let steel = dynamic(0x6E7178, 0x9A9DA3)
    private static let orange = rgb(0xFF5B1A)
    private static let paper = dynamic(0xF4F2ED, 0x0E0E0F)

    private static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? rgb(dark) : rgb(light) }
    }

    private func make(appName: String?) -> ShieldConfiguration {
        let reach = SharedWorkoutState.recordReach()
        let snapshot = SharedWorkoutState.current()
        let name = appName ?? "That"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterial,
            backgroundColor: Self.paper,
            icon: Self.lockIcon,
            title: .init(text: title(reach: reach), color: Self.ink),
            subtitle: .init(text: subtitle(appName: name, snapshot: snapshot), color: Self.steel),
            primaryButtonLabel: .init(text: "Back to the workout", color: Self.onInk),
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
