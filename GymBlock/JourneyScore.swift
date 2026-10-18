import AudioToolbox
import AVFoundation
import CoreHaptics

/// One onboarding scene's haptics and sounds on a single clock (docs/ONBOARDING-V7-PLAN.md).
/// Strength follows the story: focus that fades gets weaker, a pump that builds gets stronger, a
/// long phone rest gets nothing. Sound is real: iOS's own sounds and a few recorded plates and a
/// clink, each on its frame.
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
    /// The keyboard's tock: a clock ticking away the phone time, the same set again.
    case tock
    /// A recorded metal clink (Kenney Impact Sounds, CC0): the green time landing.
    case clink1
    /// Recorded iron-plate hits (Kenney, CC0): the flex, committing, and a deep drop on the year's total.
    case plateMedium, plateHeavy, plateDrop
    /// iOS's keyboard tick: a set logged, a pump building.
    case tink
    /// The Health app's "reading failed": focus slipping.
    case readingFail
    /// The Activity ring closing ("goal attained"): full pump, a new best.
    case goalAttained
    var file: String {
      switch self {
      case .notification: return "ReceivedMessage"
      case .lock: return "lock"
      case .alert: return "sms-received1"
      case .tock: return "Tock"
      case .clink1: return "gb-clink-1"
      case .plateMedium: return "gb-plate-medium"
      case .plateHeavy: return "gb-plate-heavy"
      case .plateDrop: return "gb-plate-drop"
      case .tink: return "Tink"
      case .readingFail: return "nano/HealthReadingFail_Haptic"
      case .goalAttained: return "nano/Alert_ActivityGoalAttained_Haptic"
      }
    }
    /// Recorded clips ship in the app; the rest are iOS's.
    var bundled: Bool { file.hasPrefix("gb-") }
    /// The Apple Watch sounds are recorded far quieter than the rest (about 12 to 18 dB), so they're
    /// raised to the others' level when they're opened.
    var raised: Bool { file.hasPrefix("nano/") }
    /// An iOS sound by system sound ID, if its file can't be opened.
    var systemID: SystemSoundID? {
      switch self {
      case .notification: return 1003
      case .lock: return 1100
      case .alert: return 1007
      case .tock: return 1104
      case .tink: return 1103
      default: return nil
      }
    }
  }
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
/// the sound. The audio session is playback mixed with others: the sounds play with the Ring/Silent
/// switch on silent (the user's choice, 18 Oct 2026), and music or a podcast keeps playing under them.
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
  private var sessionOn = false

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
  /// A primary button pressed (onboarding's Continue and the like).
  func press() { playHaptics(JourneyScores.press(0), lead: 0) }
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
    if sessionOn {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
      sessionOn = false
    }
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
    if !sessionOn {
      // Playback, not ambient, so silent mode doesn't mute onboarding; the volume buttons still do.
      try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
      try? AVAudioSession.sharedInstance().setActive(true, options: [])
      sessionOn = true
    }
    guard !audioReady else { return }
    for sound in JourneyScore.Sound.allCases {
      // On a phone iOS's sounds are in its own folder; the simulator keeps them under its runtime root.
      let root = ProcessInfo.processInfo.environment["IPHONE_SIMULATOR_ROOT"] ?? ""
      guard let url = sound.bundled ? Bundle.main.url(forResource: sound.file, withExtension: "caf")
        : URL(fileURLWithPath: root + "/System/Library/Audio/UISounds/\(sound.file).caf"),
        let data = sound.raised ? Self.raised(url) : try? Data(contentsOf: url) else { continue }
      clips[sound] = data
    }
    audioReady = true
    #if DEBUG
      NSLog("GymBlock sounds: %d of %d opened", clips.count, JourneyScore.Sound.allCases.count)
    #endif
  }
  /// A quiet clip brought up to a -3 dB peak in memory, as 16-bit WAV for AVAudioPlayer.
  private static func raised(_ url: URL) -> Data? {
    guard let file = try? AVAudioFile(forReading: url),
      let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
      (try? file.read(into: buffer)) != nil, let samples = buffer.floatChannelData
    else { return nil }
    let frames = Int(buffer.frameLength), channels = Int(buffer.format.channelCount)
    var peak: Float = 0
    for c in 0..<channels { for i in 0..<frames { peak = max(peak, abs(samples[c][i])) } }
    guard peak > 0 else { return nil }
    let gain = powf(10, -3 / 20) / peak, rate = UInt32(buffer.format.sampleRate), frameBytes = UInt16(2 * channels)
    var data = Data()
    func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    data.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + frames * Int(frameBytes))); data.append(contentsOf: Array("WAVEfmt ".utf8))
    put(UInt32(16)); put(UInt16(1)); put(UInt16(channels)); put(rate); put(rate * UInt32(frameBytes)); put(frameBytes); put(UInt16(16))
    data.append(contentsOf: Array("data".utf8)); put(UInt32(frames * Int(frameBytes)))
    for i in 0..<frames { for c in 0..<channels { put(Int16(max(-1, min(1, samples[c][i] * gain)) * 32767)) } }
    return data
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
