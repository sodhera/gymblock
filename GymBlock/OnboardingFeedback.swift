import AVFoundation
import UIKit

@MainActor final class OnboardingFeedback {
  static let shared = OnboardingFeedback()
  private let audio = OnboardingAudio()
  func play(profile: Profile, completion: Bool = false, selection: Bool = false) {
    if profile.hapticsEnabled ?? true {
      if completion { UINotificationFeedbackGenerator().notificationOccurred(.success) }
      else { UISelectionFeedbackGenerator().selectionChanged() }
    }
    guard !selection else { return }
    Task { await playSound(profile: profile, completion: completion) }
  }
  @discardableResult func playSound(profile: Profile, completion: Bool = false) async -> Bool {
    guard profile.soundEnabled ?? true,
      let url = Bundle.main.url(forResource: completion ? "complete" : "advance", withExtension: "wav")
    else { return false }
    return await audio.play(url)
  }
}

// Only this serial queue accesses the player. Audio activation must not block UI transitions.
private final class OnboardingAudio: @unchecked Sendable {
  private let queue = DispatchQueue(label: "com.sirish.gymblock.onboarding-audio")
  private var player: AVAudioPlayer?
  func play(_ url: URL) async -> Bool {
    await withCheckedContinuation { continuation in
      queue.async {
        do {
          try AVAudioSession.sharedInstance().setCategory(.ambient)
          self.player = try AVAudioPlayer(contentsOf: url)
          self.player?.volume = 0.35
          continuation.resume(returning: self.player?.play() ?? false)
        } catch {
          self.player = nil
          continuation.resume(returning: false)
        }
      }
    }
  }
}
