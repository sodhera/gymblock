import SwiftUI

/// The brand mark: a cast-iron kettlebell with a keyhole. A thick handle, wider than the bell, whose
/// legs lean in and curve into the bell's shoulders; a round bell with a flat base; and the keyhole
/// in the emerald signal, the only colour and the only lock cue. The handle was traced from a photo
/// of a real kettlebell the user picked on 12 Oct 2026 (it replaced the trapezoid handle of 9 Oct).
/// The outline is `KettlebellOutline` in Widgets/KettlebellShape.swift (shared with the widgets),
/// word for word the same as in `scripts/generate-app-icon.swift`.
struct BrandMark: View {
  var size: CGFloat = 28
  var body: some View {
    ZStack {
      KettlebellShape(part: .iron).fill(JourneyColor.text, style: FillStyle(eoFill: true))
      KettlebellShape(part: .keyhole).fill(JourneyColor.signal)
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

/// The mark as a padlock, for the launch screen (11 Oct 2026): the kettlebell's handle is the shackle.
/// It appears unlocked (handle raised and swivelled open on one leg, the keyhole an empty cut-out),
/// the handle swings shut and drops into the bell, it clicks (a crisp haptic, the bell gives a
/// little), and the keyhole lights emerald: locked. Then `done`.
struct KettlebellLock: View {
  var size: CGFloat = 96
  var done: () -> Void = {}
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var shown = false
  @State private var swung = false
  @State private var dropped = false
  @State private var locked = false
  /// Shrunk away into its bell: the exit, in solid ink rather than a fade (12 Oct 2026).
  @State private var gone = false
  var body: some View {
    ZStack {
      // Raised only a little: the legs lean in, so a long lift would show them meeting inside the bell.
      KettlebellShape(part: .handle).fill(JourneyColor.text, style: FillStyle(eoFill: true))
        .rotationEffect(.degrees(swung ? 0 : -16), anchor: UnitPoint(x: 0.60, y: 0.70))
        .offset(y: dropped ? 0 : -size * 0.15)
      ZStack {
        KettlebellShape(part: .bell).fill(JourneyColor.text)
        // The curves where the legs meet the bell, once they have.
        KettlebellShape(part: .joins).fill(JourneyColor.text).opacity(locked ? 1 : 0)
      }
      .scaleEffect(x: 1, y: locked ? 1 : 0.985, anchor: .bottom)
      KettlebellShape(part: .keyhole).fill(locked ? JourneyColor.signal : JourneyColor.stage)
        .scaleEffect(locked ? 1 : 0.82, anchor: UnitPoint(x: 0.5, y: 0.71))
    }
    .frame(width: size, height: size)
    // One piece: faded part by part, the handle and bell overlap into darker seams.
    .compositingGroup()
    .scaleEffect(gone ? 0.001 : 1, anchor: UnitPoint(x: KettlebellOutline.bell.x, y: KettlebellOutline.bell.y))
    .padding(.top, size * 0.3)  // Room for the raised handle.
    .opacity(shown ? 1 : 0)
    .accessibilityHidden(true)
    .task {
      if reduceMotion {
        swung = true; dropped = true; locked = true; shown = true
        try? await Task.sleep(for: .milliseconds(350))
        done(); return
      }
      // About 2 s in all (12 Oct 2026: the user found 1.45 s too fast); time to see it open, and locked.
      JourneyHaptic.prepare(.rigid)  // So the click lands with the handle, not after it.
      withAnimation(.easeOut(duration: 0.3)) { shown = true }
      try? await Task.sleep(for: .milliseconds(450))
      withAnimation(.easeInOut(duration: 0.34)) { swung = true }
      try? await Task.sleep(for: .milliseconds(380))
      withAnimation(.spring(duration: 0.36, bounce: 0.26)) { dropped = true }
      try? await Task.sleep(for: .milliseconds(220))  // It lands: the spring first reaches the bell.
      JourneyHaptic.play(.rigid, store.profile, intensity: 1)
      withAnimation(.spring(duration: 0.36, bounce: 0.4)) { locked = true }
      try? await Task.sleep(for: .milliseconds(650))
      // Out, solid all the way: it tucks into its bell, then the page arrives over the same paper.
      withAnimation(.easeIn(duration: 0.32)) { gone = true }
      try? await Task.sleep(for: .milliseconds(320))
      done()
    }
  }
}
