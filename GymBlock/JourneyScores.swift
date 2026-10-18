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

  /// When SwiftUI's `.easeInOut` (the curve 0.42, 0, 0.58, 1) reaches `progress`, as a share of its
  /// duration: a beat that follows an eased count lands on the value, not on an even time.
  static func easeInOutTime(_ progress: Double) -> Double {
    func bez(_ s: Double, _ a: Double, _ b: Double) -> Double { 3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * b + s * s * s }
    var lo = 0.0, hi = 1.0
    for _ in 0..<40 { let mid = (lo + hi) / 2; if bez(mid, 0, 1) < progress { lo = mid } else { hi = mid } }
    return bez((lo + hi) / 2, 0.42, 0.58)
  }

  /// A notification arriving on the phone-habit page: one light tap, no sound.
  static func notification(strength: Double) -> JourneyScore { JourneyScore(haptics: [.tap(0, strength, 0.5)]) }

  /// Welcome: four notifications land, each with the Messages ding and a light tap; the kettlebell
  /// locks the phone with the iPhone's lock click and one firm hit; one tap on the flex's peak (2.87 s).
  static let welcome = JourneyScore(
    haptics: [.tap(0.35, 0.4, 0.5), .tap(0.75, 0.4, 0.5), .tap(1.1, 0.4, 0.5), .tap(1.4, 0.4, 0.5), .tap(2.13, 0.9, 0.2), .tap(2.87, 0.6, 0.45)],
    sounds: [cue(0.35, .notification, 0.28), cue(0.75, .notification, 0.28), cue(1.1, .notification, 0.28), cue(1.4, .notification, 0.28),
             cue(2.13, .lock, 0.5), cue(2.87, .plateMedium, 0.4)])

  /// The phone-time ring: a clock ticks the red phone time away (the ticks follow the eased count),
  /// one soft tap when it lands; the green training time lands with a light clink.
  static func reveal(fill: Double) -> JourneyScore {
    let ticks = (1...10).map { cue(fill * easeInOutTime(Double($0) / 10), .tock, 0.35) }
    return JourneyScore(haptics: [.tap(fill, 0.45, 0.35), .tap(fill + 0.25 + 0.5, 0.35, 0.6)],
                        sounds: ticks + [cue(fill + 0.25, .clink1, 0.3)])
  }

  /// The year in workouts: a run of ticks and light taps that follows the dots as they light (eased,
  /// like the fill), each a touch firmer, then a heavy plate drop on the total.
  static func year(fill: Double) -> JourneyScore {
    let n = 16
    let times = (1...n).map { fill * easeInOutTime(Double($0) / Double(n + 1)) }
    return JourneyScore(
      haptics: times.enumerated().map { .tap($0.element, 0.15 + 0.2 * Double($0.offset) / Double(n - 1), 0.75) } + [.tap(fill, 0.9, 0.25)],
      sounds: times.map { cue($0, .tock, 0.3) } + [cue(fill, .plateDrop, 0.55)])
  }

  /// Scrolling weakens it: one tap per signal where it lands on the arm's twitch (or dies), each
  /// weaker than the last (70%, 45%, 25%, 10%). The trombone's three notes (Mixkit's "Trombone
  /// disappoint") are heard on the first three twitches, the contraction and the two half ones, with
  /// the tap: womp, womp, and the long wommmp as the last one fades and the fourth signal fizzles
  /// (MindState.fading: twitch peaks at 1.12, 1.935 and 2.75 s).
  static let mindFading: JourneyScore = {
    let beats = [0.25 + 0.62 + 0.25, 1.05 + 0.66 + 0.225, 1.85 + 0.7 + 0.2, 2.65 + 0.62]
    let strength = [0.7, 0.45, 0.25, 0.1], sharp = [0.55, 0.45, 0.3, 0.2]
    let notes: [JourneyScore.Sound] = [.womp1, .womp2, .womp3]
    return JourneyScore(haptics: (0..<4).map { .tap(beats[$0], strength[$0], sharp[$0]) },
                        sounds: (0..<3).map { cue(beats[$0] - JourneyScore.wompAttack, notes[$0], 0.45) })
  }()

  /// Put it away: three identical taps on the arm's squeeze (0.235 s after each signal arrives),
  /// steady like a heartbeat, and a metal clink on each that gets heavier: a light clink, a brighter
  /// one, then a clink over an iron plate (MindState.steady).
  static let mindSteady: JourneyScore = {
    let beats = [0.35, 1.2, 2.05].map { $0 + 0.63 + 0.235 }
    return JourneyScore(
      haptics: beats.map { .tap($0, 0.6, 0.5) },
      sounds: [cue(beats[0], .clink1, 0.3), cue(beats[1], .clink2, 0.45), cue(beats[2], .clink3, 0.55), cue(beats[2], .plateHeavy, 0.5)])
  }()

  /// The pump (the user's favourite pages): each set swells to its peak and lands as the arm's
  /// contraction peaks, with a plate sound on the peak. Scrolling: the same dull clank every set and
  /// nothing in the long rests or after the last one. Timed: plates getting heavier every set; when
  /// it's full, the bright clink, the heaviest plate and the strongest tap are one beat.
  static func pump(_ points: [CGPoint], timed: Bool, durations: [Double]) -> JourneyScore {
    var h: [H] = [], s: [JourneyScore.Cue] = []
    var t = 0.0, rise = 0
    let plates: [(JourneyScore.Sound, Float)] = [(.plateLight, 0.25), (.plateLight, 0.35), (.plateMedium, 0.4), (.plateMedium, 0.5), (.plateHeavy, 0.6)]
    for i in 1..<points.count {
      let d = durations[i - 1]
      if points[i].y > points[i - 1].y + 0.001 {
        if timed {
          let level = min(1, 0.35 + 0.16 * Double(rise)), full = points[i].y >= 0.999
          h += [.swell(t, d, max(0.1, level - 0.3), level, 0.5), .tap(t + d, full ? 1 : level, full ? 0.7 : 0.4 + 0.08 * Double(rise))]
          let plate = plates[min(plates.count - 1, rise)]
          s.append(cue(t + d, plate.0, plate.1))
          if full { s.append(cue(t + d, .clink2, 0.35)) }
        } else {
          h += [.swell(t, d, 0.25, 0.5, 0.4), .tap(t + d, 0.5, 0.5)]
          s.append(cue(t + d, .clankDull, 0.35))
        }
        rise += 1
      }
      t += d
    }
    return JourneyScore(haptics: h, sounds: s)
  }

  /// Memory: a fainter tap as each number fades to "?".
  static func forgetting(period: Double, fade: Double) -> JourneyScore {
    JourneyScore(haptics: (0..<4).map { .tap(Double($0) * period + fade, [0.4, 0.3, 0.2, 0.12][$0], 0.3) })
  }

  /// The log: a light tap and a key click (a set being logged) the moment the line reaches each
  /// week's dot, following it up and down, and a firmer tap with a clink on +5 kg.
  static func remembering(hits: [Double], best: Double) -> JourneyScore {
    let levels = [0.3, 0.45, 0.38, 0.55, 0.65]
    return JourneyScore(haptics: hits.enumerated().map { .tap($0.element, levels[min(4, $0.offset)], 0.5) } + [.tap(best, 0.8, 0.55)],
                        sounds: hits.map { cue($0, .typing, 0.4) } + [cue(best, .clink2, 0.4)])
  }

  /// The lock screen locks: the iPhone's lock click and one crisp tap, on the kettlebell's squeeze (1.07 s).
  static let shield = JourneyScore(haptics: [.tap(1.07, 0.75, 0.9)], sounds: [cue(1.07, .lock, 0.45)])

  /// Rest alerts: the Live Activity's digits change every `countdownStep` from 0:05, each second a
  /// light, crisp tick like a watch's, silently; on 0:00 the real thing: the double buzz and the
  /// tri-tone (LockScreenRest).
  static let countdownStep = 0.4
  static let restUp: JourneyScore = {
    let zero = 5 * countdownStep
    let ticks: [H] = (1...4).map { .tap(Double($0) * countdownStep, 0.4, 0.85) }
    return JourneyScore(haptics: ticks + [.tap(zero, 0.9, 0.6), .tap(zero + 0.13, 0.7, 0.6)], sounds: [cue(zero, .alert, 0.35)])
  }()

  /// Committed: one firm tap and the clank of a plate going back on the rack.
  static let committed = JourneyScore(haptics: [.tap(0, 0.85, 0.4)], sounds: [cue(0, .plateHeavy, 0.5)])

  /// Start workout, at the end of onboarding: the apps lock.
  static let startWorkout = JourneyScore(haptics: [.tap(0, 0.8, 0.8)], sounds: [cue(0, .lock, 0.45)])
}
