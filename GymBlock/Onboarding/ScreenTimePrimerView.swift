import SwiftUI
import UserNotifications

/// One-time setup after the paywall, two asks in sequence:
///   1. Screen Time — the permission blocking needs — then Apple's app picker.
///   2. Notifications — so the rest timer can tap you on the shoulder while
///      the phone's locked in your pocket.
/// Each has an honest "Not now"; both are reachable later from Settings.
struct ScreenTimePrimerView: View {
    @Environment(AppStore.self) private var store
    @Environment(ScreenTimeController.self) private var screenTime
    @State private var phase: Phase = .screenTime
    @State private var picking = false
    @State private var working = false

    enum Phase { case screenTime, notifications }

    var body: some View {
        ZStack {
            switch phase {
            case .screenTime: screenTimeAsk.transition(.opacity)
            case .notifications: notificationsAsk.transition(.opacity)
            }
        }
        .paperBackground()
        .animation(.easeInOut(duration: 0.35), value: phase)
        .sheet(isPresented: $picking, onDismiss: { phase = .notifications }) {
            BlockedAppsPicker()
        }
    }

    // MARK: Screen Time

    private var screenTimeAsk: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            BrandMark(size: 64)
            Text("Choose what gets locked.")
                .font(GBFont.hero(32))
                .foregroundStyle(GBColor.ink)
                .padding(.top, GBSpace.xl)
            Text("GymBlock uses Screen Time to lock the apps you pick — only while a workout is running.")
                .font(GBFont.body(17))
                .foregroundStyle(GBColor.steel)
                .padding(.top, GBSpace.sm)

            VStack(alignment: .leading, spacing: GBSpace.md) {
                point("lock.fill", "Locks when you tap Start Workout")
                point("lock.open.fill", "Unlocks the moment you finish")
                point("phone.fill", "Calls and messages always work")
                point("eye.slash.fill", "Apple keeps your app list private — we never see it")
            }
            .padding(.top, GBSpace.xl)

            Spacer()
            Spacer()

            Button {
                allowScreenTime()
            } label: {
                if working { ProgressView().tint(.white) } else { Text("Continue") }
            }
            .buttonStyle(.primary)
            .disabled(working)

            Button("Not now") { phase = .notifications }
                .buttonStyle(.quiet)
                .frame(maxWidth: .infinity)
                .padding(.vertical, GBSpace.md)
        }
        .padding(.horizontal, GBSpace.xl)
    }

    private func point(_ icon: String, _ text: String) -> some View {
        HStack(spacing: GBSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GBColor.ink)
                .frame(width: 32, height: 32)
                .background(GBColor.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(text).font(GBFont.body(16)).foregroundStyle(GBColor.ink)
        }
    }

    private func allowScreenTime() {
        guard screenTime.isSupported else {
            // Simulator: nothing to authorize; move on honestly.
            phase = .notifications
            return
        }
        working = true
        Task {
            let granted = await screenTime.requestAuthorization()
            working = false
            if granted {
                Haptics.lock()
                picking = true
            } else {
                phase = .notifications
            }
        }
    }

    // MARK: Notifications

    private var notificationsAsk: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "timer")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(GBColor.onInk)
                .frame(width: 64, height: 64)
                .background(GBColor.ink, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            Text("Know when rest is over.")
                .font(GBFont.hero(32))
                .foregroundStyle(GBColor.ink)
                .padding(.top, GBSpace.xl)
            Text("Your phone will be locked in your pocket. We'll tap you when it's time for the next set — and when a friend nudges you.")
                .font(GBFont.body(17))
                .foregroundStyle(GBColor.steel)
                .padding(.top, GBSpace.sm)
            Spacer()
            Spacer()
            Button("Allow notifications") {
                Task {
                    _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                    finish()
                }
            }
            .buttonStyle(.primary)
            Button("Not now") { finish() }
                .buttonStyle(.quiet)
                .frame(maxWidth: .infinity)
                .padding(.vertical, GBSpace.md)
        }
        .padding(.horizontal, GBSpace.xl)
    }

    private func finish() {
        Haptics.success()
        store.flags.seenScreenTimePrimer = true
        store.flags.seenNotificationPrimer = true
    }
}
