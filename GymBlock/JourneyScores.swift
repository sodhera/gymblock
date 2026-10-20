import CoreGraphics

/// Each onboarding scene's haptic and sound score, timed to its animation (t = 0 is when the scene
/// starts moving). A haptic only on a beat that means something, mostly single taps; sounds are
/// real ones (iOS's own, or recorded clips in Resources/Sounds), each placed on the frame it
/// belongs to, and nothing plays underneath as a bed.
enum JourneyScores {
  typealias H = JourneyScore.Haptic
  static func cue(_ t: Double, _ sound: JourneyScore.Sound, _ v: Float = 0.35) -> JourneyScore.Cue {
    JourneyScore.Cue(at: t, sound: sound, volume: v)
  }

  /// How long the screen takes to show a frame once it's drawn (about two frames at 60 Hz). Scenes
  /// draw that far ahead of their score's clock, so what's seen lands on the beat that's heard.
  static let displayLead = 0.03

  private static func bez(_ s: Double, _ a: Double, _ b: Double) -> Double { 3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * b + s * s * s }
  /// When SwiftUI's `.easeInOut` (the curve 0.42, 0, 0.58, 1) reaches `progress`, as a share of its
  /// duration: a beat that follows an eased count lands on the value, not on an even time.
  static func easeInOutTime(_ progress: Double) -> Double {
    var lo = 0.0, hi = 1.0
    for _ in 0..<40 { let mid = (lo + hi) / 2; if bez(mid, 0, 1) < progress { lo = mid } else { hi = mid } }
    return bez((lo + hi) / 2, 0.42, 0.58)
  }
  /// The same curve the other way round: how far along it is at `time` (a share of its duration).
  static func easeInOut(_ time: Double) -> Double {
    guard time > 0 else { return 0 }
    guard time < 1 else { return 1 }
    var lo = 0.0, hi = 1.0
    for _ in 0..<40 { let mid = (lo + hi) / 2; if bez(mid, 0.42, 0.58) < time { lo = mid } else { hi = mid } }
    return bez((lo + hi) / 2, 0, 1)
  }

  // MARK: Haptic vocabulary
  // More than a tap: each moment has its own feel, built from sharp or soft transients and short
  // continuous buzzes whose strength ramps (Haptic.swell). Where a sound has notes, the taps sit
  // under them.

  /// A button pressed in: a rounded hit with a short settling tail.
  static func press(_ t: Double) -> [H] { [.tap(t, 0.55, 0.3), .swell(t, 0.07, 0.3, 0, 0.15)] }
  /// The iPhone's message feel: two quick taps, the second lighter.
  static func ping(_ t: Double, _ i: Double) -> [H] { [.tap(t, i, 0.6), .tap(t + 0.09, 0.6 * i, 0.55)] }
  /// Something heavy landing: a deep hit and a low rumble that dies away.
  static func thud(_ t: Double, _ i: Double) -> [H] { [.tap(t, i, 0.12), .swell(t, 0.16, 0.6 * i, 0, 0.05)] }
  /// A latch closing: a crisp click and a small after-click.
  static func latch(_ t: Double, _ i: Double) -> [H] { [.tap(t, i, 0.95), .tap(t + 0.04, 0.35 * i, 0.8)] }
  /// A heartbeat: lub-dub.
  static func heartbeat(_ t: Double, _ i: Double) -> [H] { [.tap(t, i, 0.35), .tap(t + 0.14, 0.6 * i, 0.3)] }
  /// A light, crisp tick: a dial, a watch, a set logged.
  static func tick(_ t: Double, _ i: Double) -> [H] { [.tap(t, i, 0.9)] }
  /// Health's "reading failed" (`failAttack` in, its second, lower note 0.09 s later): two falling
  /// taps under the notes and a buzz that dies, sooner the weaker it is.
  static let failAttack = 0.03
  static func falter(_ t: Double, _ i: Double) -> [H] {
    [.tap(t, i, 0.45), .tap(t + 0.09, 0.55 * i, 0.3), .swell(t + 0.09, 0.08 + 0.25 * i, 0.4 * i, 0, 0.2)]
  }
  /// The Activity ring closing ("goal attained": notes `ringAttack`, +0.12 and +0.25 s in): three
  /// rising taps under them, then a shimmer.
  static let ringAttack = 0.03
  static func ring(_ t: Double) -> [H] {
    [.tap(t, 0.55, 0.5), .tap(t + 0.12, 0.75, 0.6), .tap(t + 0.25, 1, 0.75), .swell(t + 0.25, 0.4, 0.4, 0, 0.7)]
  }

  /// A notification arriving on the phone-habit page: the message double tap, no sound.
  static func notification(strength: Double) -> JourneyScore { JourneyScore(haptics: ping(0, strength)) }

  /// Welcome: four notifications land, each with the Messages ding and the message double tap; the
  /// kettlebell lands on the phone with a thud and the iPhone's lock click; once "Get jacked" has
  /// landed, the arm flexes on a rising buzz and peaks with a firm hit (WelcomeScene).
  static let welcome = JourneyScore(
    haptics: [0.35, 0.75, 1.1, 1.4].flatMap { ping($0, 0.4) } + thud(2.13, 1) + [.tap(2.16, 0.5, 0.95)]
      + [.swell(WelcomeScene.flex, WelcomeScene.peak - WelcomeScene.flex, 0.1, 0.55, 0.4), .tap(WelcomeScene.peak, 0.8, 0.5)],
    sounds: [cue(0.35, .notification, 0.28), cue(0.75, .notification, 0.28), cue(1.1, .notification, 0.28), cue(1.4, .notification, 0.28),
             cue(2.13, .lock, 0.5), cue(WelcomeScene.peak, .plateMedium, 0.4)])

  /// The year in extra workouts: crisp ticks that follow the dots as they light (eased, like the
  /// fill), each a touch firmer, then a heavy thud and plate drop as the last dot lights
  /// (ExtraWorkoutsStage draws the dots from this score's clock).
  static func year(fill: Double) -> JourneyScore {
    let n = 16
    let times = (1...n).map { fill * easeInOutTime(Double($0) / Double(n + 1)) }
    return JourneyScore(
      haptics: times.enumerated().flatMap { tick($0.element, 0.15 + 0.2 * Double($0.offset) / Double(n - 1)) } + thud(fill, 1),
      sounds: times.map { cue($0, .tock, 0.3) } + [cue(fill, .plateDrop, 0.55)])
  }

  // MARK: Onboarding V8: time back (docs/ONBOARDING-V8-PLAN.md)

  /// The stopwatch winding to the rest they need: a light tick, and the keyboard's tick quietly, for
  /// every 15 seconds the hand passes.
  static func windUp(from: Double, to: Double, duration: Double) -> JourneyScore {
    let steps = min(16, Int((abs(to - from) * 4).rounded()))
    guard steps > 0 else { return JourneyScore() }
    let times = (1...steps).map { duration * Double($0) / Double(steps) }
    return JourneyScore(haptics: times.flatMap { tick($0, 0.3) }, sounds: times.map { cue($0, .tink, 0.18) })
  }

  /// A red count (the lost minutes per rest, then per workout): the clock's tock follows the eased
  /// count, and it lands with a soft hit, or a heavier one for the workout.
  static func lostCount(at start: Double, fill: Double, heavy: Bool) -> JourneyScore {
    let ticks = (1...10).map { start + fill * easeInOutTime(Double($0) / 10) }
    let end = start + fill
    let land: [H] = heavy ? thud(end, 0.8) : [.tap(end, 0.5, 0.3), .swell(end, 0.12, 0.3, 0, 0.2)]
    return JourneyScore(haptics: land, sounds: ticks.map { cue($0, .tock, 0.32) } + (heavy ? [cue(end, .plateDrop, 0.4)] : []))
  }

  /// The minutes given back: a rising shimmer while the red slides away, then a latch and a clink as
  /// the gym bar closes onto the workout.
  static func giveBack(at start: Double, slide: Double) -> JourneyScore {
    JourneyScore(haptics: [.swell(start, slide, 0.08, 0.4, 0.7)] + latch(start + slide, 0.7), sounds: [cue(start + slide, .clink1, 0.35)])
  }

  /// Kit landing on the rack: a thud and a plate's clank for each piece, `gap` apart, starting `at`.
  static func rack(pieces: Int, at: Double, gap: Double) -> JourneyScore {
    guard pieces > 0 else { return JourneyScore() }
    let times = (0..<pieces).map { at + Double($0) * gap }
    let plates: [JourneyScore.Sound] = [.plateMedium, .plateHeavy]
    return JourneyScore(haptics: times.flatMap { thud($0, 0.55) },
                        sounds: times.enumerated().map { cue($0.element, plates[$0.offset % 2], 0.3) })
  }

  /// Today's log filling: a light tick for each tally mark and the keyboard's tick at the end of each row.
  static func tally(marks: [[Double]]) -> JourneyScore {
    JourneyScore(haptics: marks.flatMap { $0.flatMap { tick($0, 0.22) } },
                 sounds: marks.compactMap { $0.last.map { cue($0, .tink, 0.3) } })
  }

  /// The gym clock running: its tock, faster as the hands speed up, and a tick when they stop.
  static func clockRun(duration: Double) -> JourneyScore {
    let n = 12
    let times = (1..<n).map { duration * easeInOutTime(Double($0) / Double(n)) }
    return JourneyScore(haptics: times.flatMap { tick($0, 0.18) } + tick(duration, 0.45), sounds: times.map { cue($0, .tock, 0.26) } + [cue(duration, .tink, 0.5)])
  }

  /// The shield locks: a latch and the iPhone's lock click, on the kettlebell's squeeze (1.07 s).
  static let shield = JourneyScore(haptics: latch(1.07, 0.8), sounds: [cue(1.07, .lock, 0.45)])

  /// Rest alerts: the Live Activity's digits change every `countdownStep` from 0:05, each second a
  /// light, crisp tick like a watch's, silently; on 0:00 the real thing: the double buzz and the
  /// tri-tone (LockScreenRest).
  static let countdownStep = 0.4
  static let restUp: JourneyScore = {
    let zero = 5 * countdownStep
    let ticks: [H] = (1...4).flatMap { tick(Double($0) * countdownStep, 0.4) }
    return JourneyScore(haptics: ticks + [.tap(zero, 0.9, 0.6), .tap(zero + 0.13, 0.7, 0.6)], sounds: [cue(zero, .alert, 0.35)])
  }()

  /// Committed: a heavy thud and the clank of a plate going back on the rack.
  static let committed = JourneyScore(haptics: thud(0, 0.9), sounds: [cue(0, .plateHeavy, 0.5)])

  /// Start workout, at the end of onboarding: the apps lock with a latch.
  static let startWorkout = JourneyScore(haptics: latch(0, 0.85), sounds: [cue(0, .lock, 0.45)])
}
