import CoreHaptics
import UIKit

// GymBlock's haptic vocabulary. Every physical moment in the app has exactly
// one pattern, so the same feeling always means the same thing. See DESIGN.md
// → "Haptics".
//
//   tap        light selection tick — toggles, chips, steppers
//   press      medium impact — every button (wired into the button styles)
//   setDone    crisp rigid double — a set checked off
//   lock       the clunk: heavy hit + low rumble tail — Start Workout, apps locked
//   unlock     spring release: two rising taps + soft bloom — workout finished
//   ratchet    a single hold-to-finish tick (intensity climbs with progress)
//   restEnd    double knock — rest timer done
//   countdown  soft tick — last 3 seconds of rest
//   pr         building rumble into one big hit — personal record
//   warning    rigid-soft — a guarded action (end early, delete)
//
// Core Haptics where the hardware supports it; UIKit feedback generators as a
// fallback (and on the Simulator, where both are silent anyway).

@MainActor
enum Haptics {
    private static var engine: CHHapticEngine?
    private static let supportsCore = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private static let selection = UISelectionFeedbackGenerator()
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notify = UINotificationFeedbackGenerator()

    /// Call once at launch; cheap if haptics are unsupported.
    static func prepare() {
        guard supportsCore, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak engine] in try? engine?.start() }
            try engine.start()
            self.engine = engine
        } catch {
            AppLog.app.error("Haptic engine failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Simple

    static func tap() { selection.selectionChanged() }
    static func press() { medium.impactOccurred(intensity: 0.8) }
    static func soft(_ intensity: CGFloat = 0.6) { soft.impactOccurred(intensity: intensity) }

    static func setDone() {
        play([
            transient(at: 0, intensity: 0.9, sharpness: 0.9),
            transient(at: 0.07, intensity: 0.45, sharpness: 0.7),
        ]) {
            rigid.impactOccurred(intensity: 1)
        }
    }

    static func setUndone() {
        play([transient(at: 0, intensity: 0.4, sharpness: 0.3)]) { soft.impactOccurred(intensity: 0.5) }
    }

    /// The lock clunk: a heavy, dull hit with a short low rumble — the feel of
    /// a padlock shackle snapping shut.
    static func lock() {
        play([
            transient(at: 0, intensity: 1, sharpness: 0.25),
            continuous(at: 0.01, duration: 0.16, intensity: 0.55, sharpness: 0.05, decay: true),
            transient(at: 0.09, intensity: 0.5, sharpness: 0.6),
        ]) {
            heavy.impactOccurred(intensity: 1)
        }
    }

    /// The release: two quick rising taps and a soft bloom — the shackle
    /// springing open.
    static func unlock() {
        play([
            transient(at: 0, intensity: 0.5, sharpness: 0.8),
            transient(at: 0.08, intensity: 0.8, sharpness: 0.9),
            continuous(at: 0.14, duration: 0.3, intensity: 0.4, sharpness: 0.2, decay: true),
        ]) {
            notify.notificationOccurred(.success)
        }
    }

    /// One ratchet click of a hold gesture; `progress` 0…1 raises intensity so
    /// the hold feels like it's winding up.
    static func ratchet(_ progress: Double) {
        let p = Float(min(max(progress, 0), 1))
        play([transient(at: 0, intensity: 0.35 + 0.55 * p, sharpness: 0.55 + 0.35 * p)]) {
            rigid.impactOccurred(intensity: CGFloat(0.4 + 0.6 * p))
        }
    }

    static func countdown() {
        play([transient(at: 0, intensity: 0.45, sharpness: 0.4)]) { light.impactOccurred() }
    }

    static func restEnd() {
        play([
            transient(at: 0, intensity: 1, sharpness: 0.5),
            transient(at: 0.14, intensity: 1, sharpness: 0.5),
        ]) {
            notify.notificationOccurred(.warning)
        }
    }

    /// A personal record: a rumble that swells for ~0.5s and lands one big hit.
    static func pr() {
        play([
            continuous(at: 0, duration: 0.5, intensity: 0.2, sharpness: 0.3, ramp: 0.85),
            transient(at: 0.52, intensity: 1, sharpness: 0.7),
            transient(at: 0.62, intensity: 0.6, sharpness: 0.9),
        ]) {
            notify.notificationOccurred(.success)
        }
    }

    static func warning() {
        play([
            transient(at: 0, intensity: 0.8, sharpness: 0.8),
            transient(at: 0.1, intensity: 0.4, sharpness: 0.2),
        ]) {
            notify.notificationOccurred(.warning)
        }
    }

    static func success() { notify.notificationOccurred(.success) }

    // MARK: Core Haptics plumbing

    private static func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = [], fallback: () -> Void) {
        guard supportsCore else { fallback(); return }
        if engine == nil { prepare() }
        guard let engine else { fallback(); return }
        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.start()
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }

    private static func transient(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time
        )
    }

    private static func continuous(
        at time: TimeInterval,
        duration: TimeInterval,
        intensity: Float,
        sharpness: Float,
        decay: Bool = false,
        ramp: Float? = nil
    ) -> CHHapticEvent {
        var params = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
        ]
        if decay {
            params.append(CHHapticEventParameter(parameterID: .decayTime, value: Float(duration)))
            params.append(CHHapticEventParameter(parameterID: .sustained, value: 0))
        }
        if let ramp {
            // Swell: attack over the whole duration toward `ramp` intensity.
            params = [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: ramp),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                CHHapticEventParameter(parameterID: .attackTime, value: Float(duration)),
            ]
        }
        return CHHapticEvent(eventType: .hapticContinuous, parameters: params, relativeTime: time, duration: duration)
    }
}
