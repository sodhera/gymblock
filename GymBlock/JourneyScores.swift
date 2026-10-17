import CoreGraphics

/// Each onboarding scene's haptic and sound score, timed to its animation (t = 0 is when the scene
/// starts moving). The same scores are drawn and playable in docs/onboarding-mockups/index.html.
enum JourneyScores {
  typealias H = JourneyScore.Haptic
  static func cue(_ t: Double, _ name: String, _ v: Float = 1) -> JourneyScore.Cue { JourneyScore.cue(t, name, v) }

  /// The iOS notification feel (two quick taps) under GymBlock's own ding for that app.
  static func notification(_ app: String, strength: Double = 0.6) -> JourneyScore {
    JourneyScore(haptics: [.tap(0, strength, 0.55), .tap(0.09, strength * 0.67, 0.5)], sounds: [cue(0, "ding-" + ding(app))])
  }
  static func ding(_ app: String) -> String {
    switch app { case "Instagram": return "ig"; case "TikTok": return "tt"; case "YouTube": return "yt"; default: return "msg" }
  }

  /// When SwiftUI's `.easeInOut` (the curve 0.42, 0, 0.58, 1) reaches `progress`, as a share of its
  /// duration: ticks that follow an eased count land on the values, not on even times.
  static func easeInOutTime(_ progress: Double) -> Double {
    func bez(_ s: Double, _ a: Double, _ b: Double) -> Double { 3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * b + s * s * s }
    var lo = 0.0, hi = 1.0
    for _ in 0..<40 { let mid = (lo + hi) / 2; if bez(mid, 0, 1) < progress { lo = mid } else { hi = mid } }
    return bez((lo + hi) / 2, 0.42, 0.58)
  }

  /// Welcome: four apps ping, the kettlebell falls and lands, the phone locks, the arm swells and flexes.
  /// The firm hit lands on the flex's peak (its spring's first crest, 2.87 s).
  static let welcome = JourneyScore(
    haptics: [
      .tap(0.35, 0.6, 0.55), .tap(0.44, 0.4, 0.5), .tap(0.75, 0.6, 0.55), .tap(0.84, 0.4, 0.5),
      .tap(1.1, 0.62, 0.55), .tap(1.19, 0.42, 0.5), .tap(1.4, 0.64, 0.55), .tap(1.49, 0.44, 0.5),
      .swell(1.75, 0.38, 0.05, 0.35, 0.2), .tap(2.13, 1, 0.12), .tap(2.3, 0.35, 0.2), .tap(2.4, 0.3, 0.85),
      .swell(2.55, 0.32, 0.2, 0.95, 0.35), .tap(2.87, 1, 0.5), .tap(3.2, 0.6, 0.65),
    ],
    sounds: [
      cue(0.35, "ding-ig"), cue(0.75, "ding-tt"), cue(1.1, "ding-yt"), cue(1.4, "ding-msg"), cue(1.75, "fall"),
      cue(2.13, "thud"), cue(2.15, "clack", 0.7), cue(2.55, "swell"), cue(2.87, "chime-flex"), cue(3.2, "tick-high"),
    ])

  /// The phone-time ring: a tick each time the eased count passes another twelfth of its total, then
  /// a light shimmer for the green. No bass.
  static func reveal(fill: Double, total: Double = 34) -> JourneyScore {
    let n = 12
    let times = (1...n).map { fill * easeInOutTime(Double($0) / Double(n)) }
    let ticks: [H] = times.enumerated().map { .tap($0.element, 0.2 + 0.55 * Double($0.offset) / Double(n - 1), 0.45) }
    let sounds = times.enumerated().map { cue($0.element, String(format: "count-%02d", $0.offset)) }
    let green = fill + 0.25
    return JourneyScore(haptics: ticks + [.swell(green, 0.5, 0.15, 0.45, 0.8), .tap(green + 0.55, 0.45, 0.7)],
                        sounds: sounds + [cue(green, "sparkle")])
  }

  /// The year in workouts: a fine rattle that follows the dots as they light (eased, like the fill),
  /// then one heavy hit on the total.
  static func year(fill: Double) -> JourneyScore {
    let count = 30
    return JourneyScore(
      haptics: [.swell(0, fill, 0.18, 0.55, 0.85), .tap(fill, 1, 0.3)],
      sounds: (1...count).map { cue(fill * easeInOutTime(Double($0) / Double(count)), "rattle-\(min(3, ($0 - 1) * 4 / count))") } + [cue(fill, "thud")])
  }

  /// Scrolling weakens it: each signal runs down the nerve and lands on the arm's twitch (or where it
  /// dies), each shorter, softer and duller; only the first reaches the arm (MindState.fading).
  static let mindFading: JourneyScore = {
    let starts = [0.25, 1.05, 1.85, 2.65]
    // The arm's twitch peaks (bump centre) for the first three; the last fizzles where it fades out.
    let beats = [0.25 + 0.62 + 0.25, 1.05 + 0.66 + 0.225, 1.85 + 0.7 + 0.2, 2.65 + 0.62]
    let strength = [0.85, 0.5, 0.28, 0.12], sharp = [0.6, 0.45, 0.3, 0.2], peak = [0.5, 0.32, 0.2, 0.1]
    var h: [H] = [.tap(0.4, 0.6, 0.55), .tap(0.49, 0.4, 0.5), .tap(1.2, 0.6, 0.55), .tap(1.29, 0.4, 0.5)]
    for i in 0..<4 { h += [.swell(starts[i], beats[i] - starts[i], 0.1, peak[i], sharp[i]), .tap(beats[i], strength[i], sharp[i])] }
    let zaps = ["zap-full", "zap-fading-1", "zap-fading-2", "zap-fading-3"]
    return JourneyScore(haptics: h, sounds: [cue(0, "pad-drain"), cue(beats[0], "pluck"), cue(0.4, "ding-ig", 0.9), cue(1.2, "ding-tt", 0.9)]
      + (0..<4).map { cue(starts[$0], zaps[$0]) })
  }()

  /// Put it away: three identical signals; each lands on the arm's squeeze (its spring's first crest,
  /// 0.235 s after the signal arrives), like a heartbeat.
  static let mindSteady: JourneyScore = {
    let starts = [0.35, 1.2, 2.05]
    let beats = starts.map { $0 + 0.63 + 0.235 }
    return JourneyScore(
      haptics: zip(starts, beats).flatMap { s, b -> [H] in [.swell(s, b - s, 0.2, 0.6, 0.5), .tap(b, 0.78, 0.55)] }
        + [.swell(2.8, 0.7, 0.15, 0.35, 0.8), .tap(3.3, 0.9, 0.5), .tap(3.42, 0.6, 0.5)],
      sounds: [cue(0, "pad-open")] + starts.map { cue($0, "zap-steady") } + beats.map { cue($0, "pluck") }
        + [cue(2.8, "sparkle-soft"), cue(3.3, "chime-mind")])
  }()

  /// The pump, from the chart's own segments and their durations (RestStage). Scrolling: every set
  /// swells to the same middle strength and the long rests get nothing but faint scroll flicks.
  /// Timed: each set lands stronger, and a double hit when it's full.
  static func pump(_ points: [CGPoint], timed: Bool, durations: [Double]) -> JourneyScore {
    var h: [H] = [], s: [JourneyScore.Cue] = []
    var t = 0.0, rise = 0
    let notes = ["pump-c4", "pump-e4", "pump-g4", "pump-c5", "pump-e5"]
    for i in 1..<points.count {
      let d = durations[i - 1]
      let up = points[i].y > points[i - 1].y + 0.001
      // The beat lands where the set peaks: the top of the rise, as the arm's contraction peaks.
      if up {
        if timed {
          let level = min(1, 0.35 + 0.16 * Double(rise))
          h += [.swell(t, d, max(0.1, level - 0.3), level, 0.5), .tap(t + d, level, 0.4 + 0.08 * Double(rise))]
          s.append(cue(t + d, notes[min(notes.count - 1, rise)]))
        } else {
          h += [.swell(t, d, 0.25, 0.5, 0.4), .tap(t + d, 0.5, 0.5)]
          s.append(cue(t + d, "pump-flat", Float(1 - 0.12 * Double(rise))))
        }
        if timed && points[i].y >= 0.999 { h += [.tap(t + d + 0.12, 0.7, 0.6)]; s.append(cue(t + d + 0.02, "chime-pump")) }
        rise += 1
      } else if !timed {
        var f = t + 0.15
        while f < t + d - 0.1 { s.append(cue(f, "scroll-flick")); f += 0.2 }
      }
      t += d
    }
    if !timed { h.append(.tap(t + 0.05, 0.25, 0.2)); s.append(cue(t + 0.05, "thud-soft")) }
    return JourneyScore(haptics: h, sounds: s)
  }

  /// Memory: each week's numbers appear with a light tick and fade to "?" with a fainter tap and a falling, out-of-tune note.
  static func forgetting(period: Double, fade: Double) -> JourneyScore {
    var h: [H] = [], s: [JourneyScore.Cue] = []
    for i in 0..<5 {
      let r = Double(i) * period
      h.append(.tap(r, 0.3, 0.5)); s.append(cue(r, "tick-soft"))
      if i < 4 { h.append(.tap(r + fade, [0.5, 0.38, 0.26, 0.15][i], 0.3)); s.append(cue(r + fade, "forget-\(i)")) }
    }
    return JourneyScore(haptics: h, sounds: s)
  }

  /// The log: a tap on every logged week the moment the line reaches its dot, following the line up
  /// and down, then a double hit on +5 kg.
  static func remembering(hits: [Double], best: Double) -> JourneyScore {
    let levels = [0.35, 0.55, 0.45, 0.7, 0.9]
    return JourneyScore(
      haptics: hits.enumerated().map { .tap($0.element, levels[min(4, $0.offset)], 0.5) } + [.tap(best, 1, 0.55), .tap(best + 0.12, 0.7, 0.55)],
      sounds: hits.enumerated().map { cue($0.element, "log-\(min(4, $0.offset))") } + [cue(best, "chime-gain")])
  }

  /// The lock screen slides up and locks with one crisp click, on the kettlebell's squeeze (1.07 s).
  static let shield = JourneyScore(
    haptics: [.swell(0.3, 0.6, 0.1, 0.3, 0.2), .tap(1.07, 0.9, 0.95), .tap(1.22, 0.35, 0.8)],
    sounds: [cue(0.3, "air"), cue(1.07, "clack"), cue(1.22, "tick-low", 0.8)])

  /// Rest alerts: the Live Activity's digits change every `countdownStep` from 0:05; a tick on each
  /// change, each firmer, and the real double buzz on 0:00 (LockScreenRest).
  static let countdownStep = 0.4
  static let restUp: JourneyScore = {
    let changes = (1...4).map { Double($0) * countdownStep }
    let zero = 5 * countdownStep
    return JourneyScore(
      haptics: changes.enumerated().map { .tap($0.element, 0.25 + 0.1 * Double($0.offset), 0.5) } + [.tap(zero, 1, 0.6), .tap(zero + 0.13, 0.8, 0.6)],
      sounds: changes.map { cue($0, "tick-countdown") } + [cue(zero, "buzz"), cue(zero + 0.05, "chime-rest")])
  }()

  /// The plan settles one line at a time.
  static let plan = JourneyScore(
    haptics: (0..<3).map { .tap(0.15 + Double($0) * 0.2, 0.2 + Double($0) * 0.05, 0.5) },
    sounds: (0..<3).map { cue(0.15 + Double($0) * 0.2, "tick-soft") })

  /// Committed: one heavy hit and a resolved chord.
  static let committed = JourneyScore(haptics: [.tap(0, 1, 0.4), .tap(0.13, 0.6, 0.5)], sounds: [cue(0, "thud-soft"), cue(0, "chime-commit")])
}
