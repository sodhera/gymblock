import CoreGraphics

/// Each onboarding scene's haptic and sound score, timed to its animation (t = 0 is when the scene
/// starts moving). Restraint is the rule (18 Oct 2026): a haptic only on a beat that means
/// something, single taps rather than swells, and sound only where life has one: a notification
/// arriving, the phone locking, rest's up. Everything else is silent.
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
    sounds: [cue(0.35, .notification, 0.28), cue(0.75, .notification, 0.28), cue(1.1, .notification, 0.28), cue(1.4, .notification, 0.28), cue(2.13, .lock, 0.5)])

  /// The phone-time ring: one soft tap when the red count lands, one when the green does.
  static func reveal(fill: Double) -> JourneyScore {
    JourneyScore(haptics: [.tap(fill, 0.45, 0.35), .tap(fill + 0.25 + 0.5, 0.35, 0.6)])
  }

  /// The year in workouts: one tap on the total.
  static func year(fill: Double) -> JourneyScore { JourneyScore(haptics: [.tap(fill, 0.6, 0.3)]) }

  /// Scrolling weakens it: one tap per signal where it lands on the arm's twitch (or dies), each
  /// weaker than the last (70%, 45%, 25%, 10%). The fading focus is felt, not heard (MindState.fading).
  static let mindFading: JourneyScore = {
    let beats = [0.25 + 0.62 + 0.25, 1.05 + 0.66 + 0.225, 1.85 + 0.7 + 0.2, 2.65 + 0.62]
    let strength = [0.7, 0.45, 0.25, 0.1], sharp = [0.55, 0.45, 0.3, 0.2]
    return JourneyScore(haptics: (0..<4).map { .tap(beats[$0], strength[$0], sharp[$0]) })
  }()

  /// Put it away: three identical taps on the arm's squeeze (0.235 s after each signal arrives),
  /// steady like a heartbeat (MindState.steady).
  static let mindSteady = JourneyScore(haptics: [0.35, 1.2, 2.05].map { .tap($0 + 0.63 + 0.235, 0.6, 0.5) })

  /// The pump (the user's favourite pages, kept as they were): each set swells to its peak and
  /// lands as the arm's contraction peaks. Scrolling: the same middle strength every time, nothing
  /// in the long rests. Timed: stronger every set, a second tap when it's full. No sound.
  static func pump(_ points: [CGPoint], timed: Bool, durations: [Double]) -> JourneyScore {
    var h: [H] = []
    var t = 0.0, rise = 0
    for i in 1..<points.count {
      let d = durations[i - 1]
      if points[i].y > points[i - 1].y + 0.001 {
        if timed {
          let level = min(1, 0.35 + 0.16 * Double(rise))
          h += [.swell(t, d, max(0.1, level - 0.3), level, 0.5), .tap(t + d, level, 0.4 + 0.08 * Double(rise))]
          if points[i].y >= 0.999 { h.append(.tap(t + d + 0.12, 0.7, 0.6)) }
        } else {
          h += [.swell(t, d, 0.25, 0.5, 0.4), .tap(t + d, 0.5, 0.5)]
        }
        rise += 1
      }
      t += d
    }
    if !timed { h.append(.tap(t + 0.05, 0.25, 0.2)) }
    return JourneyScore(haptics: h)
  }

  /// Memory: a fainter tap as each number fades to "?".
  static func forgetting(period: Double, fade: Double) -> JourneyScore {
    JourneyScore(haptics: (0..<4).map { .tap(Double($0) * period + fade, [0.4, 0.3, 0.2, 0.12][$0], 0.3) })
  }

  /// The log: a light tap the moment the line reaches each week's dot, following it up and down,
  /// and one firmer tap on +5 kg.
  static func remembering(hits: [Double], best: Double) -> JourneyScore {
    let levels = [0.3, 0.45, 0.38, 0.55, 0.65]
    return JourneyScore(haptics: hits.enumerated().map { .tap($0.element, levels[min(4, $0.offset)], 0.5) } + [.tap(best, 0.8, 0.55)])
  }

  /// The lock screen locks: the iPhone's lock click and one crisp tap, on the kettlebell's squeeze (1.07 s).
  static let shield = JourneyScore(haptics: [.tap(1.07, 0.75, 0.9)], sounds: [cue(1.07, .lock, 0.45)])

  /// Rest alerts: the Live Activity's digits change every `countdownStep` from 0:05, silently; on
  /// 0:00 the real thing: the double buzz and the tri-tone (LockScreenRest).
  static let countdownStep = 0.4
  static let restUp: JourneyScore = {
    let zero = 5 * countdownStep
    return JourneyScore(haptics: [.tap(zero, 0.9, 0.6), .tap(zero + 0.13, 0.7, 0.6)], sounds: [cue(zero, .alert, 0.35)])
  }()

  /// Committed: one firm tap.
  static let committed = JourneyScore(haptics: [.tap(0, 0.85, 0.4)])
}
