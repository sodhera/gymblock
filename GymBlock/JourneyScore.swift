import AudioToolbox
import AVFoundation
import CoreHaptics

/// One onboarding scene's haptics and sounds on a single clock (docs/ONBOARDING-V7-PLAN.md).
/// Strength follows the story: focus that fades gets weaker taps, a pump that builds gets stronger
/// ones, a long phone rest gets nothing. Sound is rare and real: iOS's own sounds, for the three
/// moments that are sounds in life (a notification arriving, the phone locking, rest's up).
struct JourneyScore {
  enum Haptic {
    /// A single tap: strength and crispness, 0–1.
    case tap(Double, Double, Double)
    /// A continuous buzz from one strength to another: time, duration, from, to, sharpness.
    case swell(Double, Double, Double, Double, Double)
  }
  /// The sounds onboarding uses: iOS's own (/System/Library/Audio/UISounds) and recorded clips
  /// bundled in Resources/Sounds (CREDITS.md). Never synthesized.
  enum Sound: CaseIterable {
    /// The Messages "received" ding: a notification arriving.
    case notification
    /// The iPhone's lock click: the kettlebell locking the phone, the shield locking an app.
    case lock
    /// The tri-tone: rest's up.
    case alert
    /// The keyboard's tock: a clock ticking away the phone time.
    case tock
    /// A key press: a set being logged.
    case typing
    /// Mixkit's "Trombone disappoint", cut into its three notes (womp, womp, wommmp) so each lands
    /// on its own beat. Every clip reaches half its loudness `wompAttack` seconds in.
    case womp1, womp2, womp3
    /// Recorded metal clinks, brightest and lightest first (Kenney Impact Sounds, CC0).
    case clink1, clink2, clink3
    /// Recorded iron-plate hits, light to heavy, and a deep drop.
    case plateLight, plateMedium, plateHeavy, plateDrop
    /// A short, dull metal clank: the same set again.
    case clankDull
    var file: String {
      switch self {
      case .notification: return "ReceivedMessage"
      case .lock: return "lock"
      case .alert: return "sms-received1"
      case .tock: return "Tock"
      case .typing: return "key_press_click"
      case .womp1: return "gb-womp-1"
      case .womp2: return "gb-womp-2"
      case .womp3: return "gb-womp-3"
      case .clink1: return "gb-clink-1"
      case .clink2: return "gb-clink-2"
      case .clink3: return "gb-clink-3"
      case .plateLight: return "gb-plate-light"
      case .plateMedium: return "gb-plate-medium"
      case .plateHeavy: return "gb-plate-heavy"
      case .plateDrop: return "gb-plate-drop"
      case .clankDull: return "gb-clank-dull"
      }
    }
    /// Recorded clips ship in the app; the rest are iOS's.
    var bundled: Bool { file.hasPrefix("gb-") }
    /// An iOS sound by system sound ID, if its file can't be opened.
    var systemID: SystemSoundID? {
      switch self {
      case .notification: return 1003
      case .lock: return 1100
      case .alert: return 1007
      case .tock: return 1104
      case .typing: return 1306
      default: return nil
      }
    }
  }
  /// How far into a womp clip its note is heard (half its peak loudness): cue it this much early.
  static let wompAttack = 0.04
  struct Cue {
    let at: Double
    let sound: Sound
    var volume: Float = 0.35
  }
  var haptics: [Haptic] = []
  var sounds: [Cue] = []
  init(haptics: [Haptic] = [], sounds: [Cue] = []) { self.haptics = haptics; self.sounds = sounds }
}

/// Plays scores: Core Haptics patterns for the feel, AVAudioPlayer scheduled on the device clock for
/// the sound. The audio session is ambient, so the silent switch silences it and music keeps playing.
@MainActor final class JourneyScorePlayer {
  static let shared = JourneyScorePlayer()
  private var engine: CHHapticEngine?
  private var hapticPlayers: [CHHapticPatternPlayer] = []
  /// Each sound's audio, read once. Every cue gets its own player (a player holds one scheduled
  /// start), so a run of ticks or four notifications in a row never drop a beat.
  private var clips: [JourneyScore.Sound: Data] = [:]
  /// Players still to play or playing, with when they're done; kept alive until then.
  private var live: [(player: AVAudioPlayer, done: Date)] = []
  private var pending: [DispatchWorkItem] = []
  private var audioReady = false

  /// Wakes the Taptic Engine and opens the sounds, so the first scene doesn't start late.
  func prepare() {
    setUpHaptics()
    setUpAudio()
  }

  /// How long the audio path takes to reach the ear: the hardware buffer plus the route's own delay
  /// (much longer over Bluetooth).
  private var audioLatency: Double {
    let session = AVAudioSession.sharedInstance()
    return max(0, session.outputLatency) + max(0, session.ioBufferDuration)
  }
  /// Plays a whole score and returns the moment its t = 0 lands. Sound is scheduled that much
  /// earlier than its latency, the Taptic Engine for the same moment, and the scene starts moving
  /// then too, so a ding, its tap and the card arriving are one event. Sound is on in onboarding
  /// unless the person has turned it off.
  @discardableResult func play(_ score: JourneyScore, profile: Profile) -> Date {
    let sound = (profile.soundEnabled ?? true) && !score.sounds.isEmpty
    let latency = sound ? audioLatency : 0
    let lead = max(0.05, latency + 0.02)
    playHaptics(score.haptics, lead: lead)
    if sound { playSounds(score.sounds, lead: lead - latency) }
    return Date().addingTimeInterval(lead)
  }
  /// One designed moment, now.
  func tap(_ intensity: Double, _ sharpness: Double) { playHaptics([.tap(0, intensity, sharpness)], lead: 0) }
  func swell(_ duration: Double, from: Double, to: Double, sharpness: Double) {
    playHaptics([.swell(0, duration, from, to, sharpness)], lead: 0)
  }
  /// The page changed: whatever was still to come is dropped.
  func stop() {
    for p in hapticPlayers { try? p.stop(atTime: CHHapticTimeImmediate) }
    hapticPlayers.removeAll()
    for w in pending { w.cancel() }
    pending.removeAll()
    for p in live { p.player.stop() }
    live.removeAll()
  }
  /// Onboarding is over: the engines sleep.
  func shutDown() {
    stop()
    engine?.stop()
  }

  // MARK: Haptics

  private func setUpHaptics() {
    guard engine == nil, CHHapticEngine.capabilitiesForHardware().supportsHaptics,
      let e = try? CHHapticEngine()
    else { return }
    e.playsHapticsOnly = true
    e.isAutoShutdownEnabled = true
    e.resetHandler = { [weak e] in try? e?.start() }
    try? e.start()
    engine = e
  }
  private func playHaptics(_ list: [JourneyScore.Haptic], lead: Double) {
    setUpHaptics()
    guard let engine, !list.isEmpty else { return }
    var events: [CHHapticEvent] = []
    var curves: [CHHapticParameterCurve] = []
    for h in list {
      switch h {
      case let .tap(t, i, s):
        events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(i)),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(s)),
        ], relativeTime: t))
      case let .swell(t, d, a, b, s):
        let peak = max(a, b, 0.01)
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
          CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(peak)),
          CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(s)),
        ], relativeTime: t, duration: d))
        curves.append(CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
          CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: Float(a / peak)),
          CHHapticParameterCurve.ControlPoint(relativeTime: d, value: Float(b / peak)),
        ], relativeTime: t))
      }
    }
    do {
      try engine.start()
      let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameterCurves: curves))
      try player.start(atTime: engine.currentTime + lead)
      hapticPlayers.append(player)
      if hapticPlayers.count > 24 { hapticPlayers.removeFirst(hapticPlayers.count - 24) }
    } catch {}
  }

  // MARK: Sound

  private func setUpAudio() {
    guard !audioReady else { return }
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    try? AVAudioSession.sharedInstance().setActive(true, options: [])
    for sound in JourneyScore.Sound.allCases {
      // On a phone iOS's sounds are in its own folder; the simulator keeps them under its runtime root.
      let root = ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] ?? ""
      guard let url = sound.bundled ? Bundle.main.url(forResource: sound.file, withExtension: "caf")
        : URL(fileURLWithPath: root + "/System/Library/Audio/UISounds/\(sound.file).caf"),
        let data = try? Data(contentsOf: url) else { continue }
      clips[sound] = data
    }
    audioReady = true
    #if DEBUG
      NSLog("GymBlock sounds: %d of %d opened", clips.count, JourneyScore.Sound.allCases.count)
    #endif
  }
  private func playSounds(_ list: [JourneyScore.Cue], lead: Double) {
    setUpAudio()
    let lead = max(0, lead)
    live.removeAll { $0.done < Date() }
    for cue in list {
      if let data = clips[cue.sound], let player = try? AVAudioPlayer(data: data) {
        player.volume = cue.volume
        player.prepareToPlay()
        player.play(atTime: player.deviceCurrentTime + lead + cue.at)
        live.append((player, Date().addingTimeInterval(lead + cue.at + player.duration + 0.5)))
      } else if let id = cue.sound.systemID {
        // The file couldn't be opened: the same iOS sound by ID, on the moment (no volume control).
        let work = DispatchWorkItem { AudioServicesPlaySystemSound(id) }
        pending.append(work)
        DispatchQueue.main.asyncAfter(deadline: .now() + lead + cue.at, execute: work)
      }
    }
  }
}
