import SwiftUI

/// A looping recreation of reaching for a distracting app mid-workout and
/// meeting the shield. It's an illustration, not real blocking — the icons
/// are generic, never real brands. Real permission and app choice happen in
/// Apple's Screen Time flow after the paywall.
struct ShieldDemoStep: View {
    var draft: OnboardingDraft
    var next: () -> Void
    @State private var phase = 0 // 0 home, 1 tap, 2 shield

    var body: some View {
        StepScaffold(
            title: "This is your phone at the gym now.",
            buttonTitle: "That's what I want",
            action: next
        ) {
            phone
                .padding(.vertical, GBSpace.lg)
        }
        .task { await loop() }
    }

    private var phone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.08), radius: 24, y: 10)

            homeScreen
                .opacity(phase == 2 ? 0 : 1)
                .scaleEffect(phase == 2 ? 0.94 : 1)

            shield
                .opacity(phase == 2 ? 1 : 0)
                .scaleEffect(phase == 2 ? 1 : 1.04)
        }
        .aspectRatio(0.56, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .strokeBorder(GBColor.ink.opacity(0.9), lineWidth: 6)
        )
        .frame(maxHeight: 400)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: phase)
    }

    private var homeScreen: some View {
        let icons: [(String, Color)] = [
            ("camera.fill", Color(hex: 0xE1306C)), ("play.rectangle.fill", Color(hex: 0x111214)),
            ("bubble.left.fill", Color(hex: 0x34C759)), ("music.note", Color(hex: 0xFA2D48)),
            ("photo.fill", Color(hex: 0xFF9F0A)), ("envelope.fill", Color(hex: 0x0A84FF)),
            ("newspaper.fill", Color(hex: 0x5E5CE6)), ("gamecontroller.fill", Color(hex: 0x30B0C7)),
        ]
        return VStack {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 16) {
                ForEach(Array(icons.enumerated()), id: \.offset) { index, icon in
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(icon.1.gradient)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: icon.0)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .overlay {
                            if index == 0 && phase == 1 {
                                Circle()
                                    .fill(GBColor.ink.opacity(0.25))
                                    .frame(width: 44, height: 44)
                                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                            }
                        }
                        .scaleEffect(index == 0 && phase == 1 ? 0.88 : 1)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 44)
            Spacer()
        }
    }

    private var shield: some View {
        VStack(spacing: 0) {
            Spacer()
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GBColor.orange)
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "lock.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                }
            Text("You're locked in.")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(GBColor.ink)
                .padding(.top, 18)
            Text("Scrolling can wait.\n3 sets of Bench Press left.")
                .font(.system(size: 13))
                .foregroundStyle(GBColor.steel)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
            Spacer()
            Text("Back to the workout")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(GBColor.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GBColor.paper, in: RoundedRectangle(cornerRadius: 38, style: .continuous))
    }

    private func loop() async {
        while !Task.isCancelled {
            phase = 0
            try? await Task.sleep(for: .seconds(1.2))
            phase = 1
            Haptics.tap()
            try? await Task.sleep(for: .seconds(0.35))
            phase = 2
            Haptics.lock()
            try? await Task.sleep(for: .seconds(2.6))
        }
    }
}
