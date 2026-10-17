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

  /// Welcome: four apps ping, the kettlebell falls and lands, the phone locks, the arm swells and flexes.
  static let welcome = JourneyScore(
    haptics: [
      .tap(0.35, 0.6, 0.55), .tap(0.44, 0.4, 0.5), .tap(0.75, 0.6, 0.55), .tap(0.84, 0.4, 0.5),
      .tap(1.1, 0.62, 0.55), .tap(1.19, 0.42, 0.5), .tap(1.4, 0.64, 0.55), .tap(1.49, 0.44, 0.5),
      .swell(1.75, 0.38, 0.05, 0.35, 0.2), .tap(2.13, 1, 0.12), .tap(2.3, 0.35, 0.2), .tap(2.4, 0.3, 0.85),
      .swell(2.55, 0.5, 0.2, 0.95, 0.35), .tap(3.05, 1, 0.5), .tap(3.22, 0.6, 0.65),
    ],
    sounds: [
      cue(0.35, "ding-ig"), cue(0.75, "ding-tt"), cue(1.1, "ding-yt"), cue(1.4, "ding-msg"), cue(1.75, "fall"),
      cue(2.13, "thud"), cue(2.15, "clack", 0.7), cue(2.55, "swell"), cue(3.05, "chime-flex"), cue(3.22, "tick-high"),
    ])

  /// The phone-time ring: ticks that climb with the red count, then a light shimmer for the green. No bass.
  static func reveal(fill: Double) -> JourneyScore {
    let n = 12
    let ticks: [H] = (0..<n).map { .tap(fill * Double($0) / Double(n), 0.2 + 0.55 * Double($0) / Double(n - 1), 0.45) }
    let sounds = (0..<n).map { cue(fill * Double($0) / Double(n), String(format: "count-%02d", $0)) }
    let green = fill + 0.25
    return JourneyScore(haptics: ticks + [.swell(green, 0.5, 0.15, 0.45, 0.8), .tap(green + 0.55, 0.45, 0.7)],
                        sounds: sounds + [cue(green, "sparkle")])
  }

  /// The year in workouts: a fine rattle that builds as the dots fill, then one heavy hit.
  static func year(fill: Double) -> JourneyScore {
    let count = Int(fill / 0.06)
    return JourneyScore(
      haptics: [.swell(0, fill, 0.18, 0.55, 0.85), .tap(fill, 1, 0.3)],
      sounds: (0..<count).map { cue(Double($0) * 0.06, "rattle-\(min(3, $0 * 4 / max(1, count)))") } + [cue(fill, "thud")])
  }

  /// Scrolling weakens it: each signal down the nerve is shorter, softer and duller; only the first reaches the arm.
  static let mindFading = JourneyScore(
    haptics: [
      .swell(0.25, 0.62, 0.15, 0.5, 0.55), .tap(0.87, 0.85, 0.6), .swell(1.05, 0.55, 0.12, 0.32, 0.45), .tap(1.6, 0.5, 0.45),
      .swell(1.85, 0.38, 0.1, 0.2, 0.35), .tap(2.23, 0.28, 0.3), .swell(2.65, 0.22, 0.06, 0.1, 0.25), .tap(2.87, 0.12, 0.2),
      .tap(0.4, 0.6, 0.55), .tap(0.49, 0.4, 0.5), .tap(1.2, 0.6, 0.55), .tap(1.29, 0.4, 0.5),
    ],
    sounds: [
      cue(0, "pad-drain"), cue(0.25, "zap-full"), cue(0.87, "pluck"), cue(1.05, "zap-fading-1"), cue(1.85, "zap-fading-2"),
      cue(2.65, "zap-fading-3"), cue(0.4, "ding-ig", 0.9), cue(1.2, "ding-tt", 0.9),
    ])

  /// Put it away: three identical signals land at the same strength, like a heartbeat.
  static let mindSteady = JourneyScore(
    haptics: [0.35, 1.2, 2.05].flatMap { t -> [H] in [.swell(t, 0.6, 0.2, 0.6, 0.5), .tap(t + 0.63, 0.78, 0.55)] }
      + [.swell(2.8, 0.7, 0.15, 0.35, 0.8), .tap(3.3, 0.9, 0.5), .tap(3.42, 0.6, 0.5)],
    sounds: [cue(0, "pad-open")] + [0.35, 1.2, 2.05].flatMap { [cue($0, "zap-steady"), cue($0 + 0.63, "pluck")] }
      + [cue(2.8, "sparkle-soft"), cue(3.3, "chime-mind")])

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
      if up {
        if timed {
          let level = min(1, 0.35 + 0.16 * Double(rise))
          h += [.tap(t, level, 0.4 + 0.08 * Double(rise)), .swell(t, d, max(0.15, level - 0.15), level, 0.5)]
          s.append(cue(t, notes[min(notes.count - 1, rise)]))
        } else {
          h += [.tap(t, 0.5, 0.5), .swell(t, d, 0.5, 0.5, 0.4)]
          s.append(cue(t, "pump-flat", Float(1 - 0.12 * Double(rise))))
        }
        if timed && points[i].y >= 0.999 { h += [.tap(t + d, 1, 0.6), .tap(t + d + 0.12, 0.7, 0.6)]; s.append(cue(t + d, "chime-pump")) }
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

  /// The log: a tap on every logged week that follows the line up and down, then a double hit on +5 kg.
  static func remembering(step: Double, best: Double) -> JourneyScore {
    let levels = [0.35, 0.55, 0.45, 0.7, 0.9]
    return JourneyScore(
      haptics: (0..<5).map { .tap(Double($0) * step, levels[$0], 0.5) } + [.tap(best, 1, 0.55), .tap(best + 0.12, 0.7, 0.55)],
      sounds: (0..<5).map { cue(Double($0) * step, "log-\($0)") } + [cue(best, "chime-gain")])
  }

  /// The lock screen slides up and locks with one crisp click.
  static let shield = JourneyScore(
    haptics: [.swell(0.3, 0.55, 0.1, 0.3, 0.2), .tap(0.98, 0.9, 0.95), .tap(1.1, 0.35, 0.8)],
    sounds: [cue(0.3, "air"), cue(0.98, "clack"), cue(1.1, "tick-low", 0.8)])

  /// Rest alerts: three ticks for the last seconds, each firmer, then the real double buzz.
  static let restUp = JourneyScore(
    haptics: [.tap(1.32, 0.3, 0.5), .tap(1.64, 0.42, 0.5), .tap(1.96, 0.55, 0.5), .tap(2.7, 1, 0.6), .tap(2.83, 0.8, 0.6)],
    sounds: [cue(1.32, "tick-countdown"), cue(1.64, "tick-countdown"), cue(1.96, "tick-countdown"), cue(2.7, "buzz"), cue(2.75, "chime-rest")])

  /// The plan settles one line at a time.
  static let plan = JourneyScore(
    haptics: (0..<3).map { .tap(0.15 + Double($0) * 0.2, 0.2 + Double($0) * 0.05, 0.5) },
    sounds: (0..<3).map { cue(0.15 + Double($0) * 0.2, "tick-soft") })

  /// Committed: one heavy hit and a resolved chord.
  static let committed = JourneyScore(haptics: [.tap(0, 1, 0.4), .tap(0.13, 0.6, 0.5)], sounds: [cue(0, "thud-soft"), cue(0, "chime-commit")])
}
