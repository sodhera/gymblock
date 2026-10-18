import AVFoundation
import CoreHaptics

/// One onboarding scene's haptics and sounds on a single clock (docs/ONBOARDING-V7-PLAN.md).
/// Strength follows the story: focus that fades gets weaker taps, a pump that builds gets stronger
/// ones, a long phone rest gets nothing. Sounds are GymBlock's own (scripts/generate-onboarding-sounds.py).
struct JourneyScore {
  enum Haptic {
    /// A single tap: strength and crispness, 0–1.
    case tap(Double, Double, Double)
    /// A continuous buzz from one strength to another: time, duration, from, to, sharpness.
    case swell(Double, Double, Double, Double, Double)
  }
  struct Cue {
    let at: Double
    let name: String
    var volume: Float = 1
  }
  var haptics: [Haptic] = []
  var sounds: [Cue] = []
  init(haptics: [Haptic] = [], sounds: [Cue] = []) { self.haptics = haptics; self.sounds = sounds }
  static func cue(_ at: Double, _ name: String, _ volume: Float = 1) -> Cue { Cue(at: at, name: name, volume: volume) }
}

/// Plays scores: Core Haptics patterns for the feel, an audio engine for sample-accurate sound.
/// The audio session is ambient, so the silent switch silences it and music keeps playing.
@MainActor final class JourneyScorePlayer {
  static let shared = JourneyScorePlayer()
  private var engine: CHHapticEngine?
  private var players: [CHHapticPatternPlayer] = []
  private let audio = AVAudioEngine()
  private var nodes: [AVAudioPlayerNode] = []
  private var nextNode = 0
  private var buffers: [String: AVAudioPCMBuffer] = [:]
  private var audioReady = false
  private var loading = false
  private let format = AVAudioFormat(standardFormatWithSampleRate: 32000, channels: 1)!

  /// Wakes the Taptic Engine, starts the audio engine and loads every cue, so the first scene's
  /// sounds don't pay the engine's start-up time.
  func prepare() {
    setUpHaptics()
    setUpAudio()
    startAudio()
    guard buffers.isEmpty, !loading else { return }
    loading = true
    Task.detached(priority: .userInitiated) {
      let loaded = Self.loadAll()
      await MainActor.run { self.buffers.merge(loaded) { a, _ in a }; self.loading = false }
    }
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
  func sound(_ name: String, volume: Float = 1, profile: Profile) {
    guard profile.soundEnabled ?? true else { return }
    playSounds([JourneyScore.cue(0, name, volume)], lead: 0.005)
  }
  /// The page changed: whatever was still to come is dropped.
  func stop() {
    for p in players { try? p.stop(atTime: CHHapticTimeImmediate) }
    players.removeAll()
    for n in nodes where n.isPlaying { n.stop() }
  }
  /// Onboarding is over: the engines sleep.
  func shutDown() {
    stop()
    if audio.isRunning { audio.stop() }
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
      players.append(player)
      if players.count > 24 { players.removeFirst(players.count - 24) }
    } catch {}
  }

  // MARK: Sound

  private func setUpAudio() {
    guard !audioReady else { return }
    try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    for _ in 0..<14 {
      let n = AVAudioPlayerNode()
      audio.attach(n)
      audio.connect(n, to: audio.mainMixerNode, format: format)
      nodes.append(n)
    }
    audio.prepare()
    audioReady = true
  }
  nonisolated private static func loadAll() -> [String: AVAudioPCMBuffer] {
    var out: [String: AVAudioPCMBuffer] = [:]
    for url in Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? [] {
      let name = url.deletingPathExtension().lastPathComponent
      if let b = read(url) { out[name] = b }
    }
    return out
  }
  nonisolated private static func read(_ url: URL) -> AVAudioPCMBuffer? {
    guard let file = try? AVAudioFile(forReading: url),
      let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
    else { return nil }
    do { try file.read(into: b) } catch { return nil }
    return b
  }
  private func buffer(_ name: String) -> AVAudioPCMBuffer? {
    if let b = buffers[name] { return b }
    guard let url = Bundle.main.url(forResource: name, withExtension: "wav"), let b = Self.read(url) else { return nil }
    buffers[name] = b
    return b
  }
  private func startAudio() {
    guard !audio.isRunning else { return }
    try? AVAudioSession.sharedInstance().setActive(true, options: [])
    try? audio.start()
    if audio.isRunning { for n in nodes where !n.isPlaying { n.play() } }
  }
  private func playSounds(_ list: [JourneyScore.Cue], lead: Double) {
    setUpAudio()
    startAudio()
    guard audio.isRunning, !list.isEmpty else { return }
    let lead = max(0, lead)
    let now = mach_absolute_time()
    for cue in list.sorted(by: { $0.at < $1.at }) {
      guard let b = buffer(cue.name), b.format == format else { continue }
      let node = nodes[nextNode]
      nextNode = (nextNode + 1) % nodes.count
      if !node.isPlaying { node.play() }
      node.volume = cue.volume
      let when = AVAudioTime(hostTime: now + AVAudioTime.hostTime(forSeconds: lead + cue.at))
      node.scheduleBuffer(b, at: when, options: [], completionHandler: nil)
    }
  }
}
