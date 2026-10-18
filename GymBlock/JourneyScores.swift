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

  /// The phone-time ring: a clock ticks the red phone time away (the ticks follow the eased count);
  /// the red lands with a soft hit, the green rises on a shimmer and lands with a light clink.
  static func reveal(fill: Double) -> JourneyScore {
    let ticks = (1...10).map { cue(fill * easeInOutTime(Double($0) / 10), .tock, 0.35) }
    return JourneyScore(haptics: [.tap(fill, 0.5, 0.3), .swell(fill, 0.12, 0.3, 0, 0.2), .swell(fill + 0.25, 0.5, 0.1, 0.35, 0.7), .tap(fill + 0.75, 0.4, 0.7)],
                        sounds: ticks + [cue(fill + 0.25, .clink1, 0.3)])
  }

  /// The year in workouts: crisp ticks that follow the dots as they light (eased, like the fill),
  /// each a touch firmer, then a heavy thud and plate drop as the last dot lights (DaysStage draws
  /// the dots from this score's clock).
  static func year(fill: Double) -> JourneyScore {
    let n = 16
    let times = (1...n).map { fill * easeInOutTime(Double($0) / Double(n + 1)) }
    return JourneyScore(
      haptics: times.enumerated().flatMap { tick($0.element, 0.15 + 0.2 * Double($0.offset) / Double(n - 1)) } + thud(fill, 1),
      sounds: times.map { cue($0, .tock, 0.3) } + [cue(fill, .plateDrop, 0.55)])
  }

  /// Scrolling weakens it: Health's "reading failed" on the first three twitches (the contraction and
  /// the two half ones), each clearly weaker than the last, with a falter under its two notes that
  /// dies sooner each time; the fourth signal only fizzles (MindState.fading: twitch peaks at 1.12,
  /// 1.935 and 2.75 s, the fizzle at 3.27 s).
  static let mindFading: JourneyScore = {
    let beats = [0.25 + 0.62 + 0.25, 1.05 + 0.66 + 0.225, 1.85 + 0.7 + 0.2, 2.65 + 0.62]
    let strength = [0.75, 0.45, 0.22], volume: [Float] = [0.5, 0.3, 0.17]
    return JourneyScore(haptics: (0..<3).flatMap { falter(beats[$0], strength[$0]) } + [.swell(beats[3], 0.12, 0.12, 0, 0.2)],
                        sounds: (0..<3).map { cue(beats[$0] - failAttack, .readingFail, volume[$0]) })
  }()

  /// Put it away: a heartbeat and a soft tick on the first two squeezes (0.235 s after each signal
  /// arrives), then the Activity ring closing on the third (MindState.steady).
  static let mindSteady: JourneyScore = {
    let beats = [0.35, 1.2, 2.05].map { $0 + 0.63 + 0.235 }
    return JourneyScore(
      haptics: heartbeat(beats[0], 0.55) + heartbeat(beats[1], 0.6) + ring(beats[2]),
      sounds: [cue(beats[0], .tink, 0.7), cue(beats[1], .tink, 0.85), cue(beats[2] - ringAttack, .goalAttained, 0.45)])
  }()

  /// The pump (the user's favourite pages; their swells unchanged): each set swells to its peak and
  /// lands as the arm's contraction peaks. Scrolling: the same soft tock every set and nothing in the
  /// long rests or after the last one. Timed: a tick that builds every set; when it's full, the
  /// Activity ring closes, its three rising taps under its notes.
  static func pump(_ points: [CGPoint], timed: Bool, durations: [Double]) -> JourneyScore {
    var h: [H] = [], s: [JourneyScore.Cue] = []
    var t = 0.0, rise = 0
    let ticks: [Float] = [0.45, 0.6, 0.8, 0.9]
    for i in 1..<points.count {
      let d = durations[i - 1]
      if points[i].y > points[i - 1].y + 0.001 {
        if timed {
          let level = min(1, 0.35 + 0.16 * Double(rise)), full = points[i].y >= 0.999
          h.append(.swell(t, d, max(0.1, level - 0.3), level, 0.5))
          if full {
            h += ring(t + d); s.append(cue(t + d - ringAttack, .goalAttained, 0.45))
          } else {
            h.append(.tap(t + d, level, 0.4 + 0.08 * Double(rise))); s.append(cue(t + d, .tink, ticks[min(3, rise)]))
          }
        } else {
          h += [.swell(t, d, 0.25, 0.5, 0.4), .tap(t + d, 0.5, 0.5)]
          s.append(cue(t + d, .tock, 0.8))
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

  /// The log: a crisp tick and a soft tick sound as each week's dot pops, the moment the line reaches
  /// it, following it up and down. Today's dot is the gain: the Activity ring closes as it turns
  /// green and +5 kg lands (LogFrame).
  static func remembering(hits: [Double]) -> JourneyScore {
    let levels = [0.3, 0.45, 0.38, 0.55], volume: [Float] = [0.6, 0.7, 0.65, 0.8], today = hits.count - 1
    return JourneyScore(haptics: (0..<today).flatMap { tick(hits[$0], levels[min(3, $0)]) } + ring(hits[today]),
                        sounds: (0..<today).map { cue(hits[$0], .tink, volume[min(3, $0)]) } + [cue(hits[today] - ringAttack, .goalAttained, 0.45)])
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
