import SwiftUI

/// Routes between launch, onboarding, the paywall, the Screen Time primer and
/// the main app. Every gate crossfades — steps fade, they don't slide
/// (SleepBlock's rule, kept here).
struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            switch store.route {
            case .launching:
                LaunchView().transition(.opacity)
            case .onboarding:
                OnboardingFlow().transition(.opacity)
            case .paywall:
                PaywallView().transition(.opacity)
            case .screenTimePrimer:
                ScreenTimePrimerView().transition(.opacity)
            case .main:
                MainTabs().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: store.route)
    }
}

struct LaunchView: View {
    var body: some View {
        BrandMark(size: 76)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .paperBackground()
    }
}

/// The app mark: a white lock on a safety-orange rounded square — the same
/// grammar as the app icon and the shield.
struct BrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(GBColor.orange)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: GBColor.orange.opacity(0.35), radius: size * 0.25, y: size * 0.1)
            .accessibilityLabel("GymBlock")
    }
}

// MARK: - Main tabs

enum MainTab: Hashable { case today, history, friends, profile }

struct MainTabs: View {
    @Environment(AppStore.self) private var store
    @State private var tab: MainTab = .today

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Today", systemImage: "circle.circle", value: MainTab.today) {
                TodayView()
            }
            Tab("History", systemImage: "list.bullet.rectangle", value: MainTab.history) {
                HistoryView()
            }
            Tab("Friends", systemImage: "person.2", value: MainTab.friends) {
                FriendsView()
            }
            .badge(store.friends.incoming.count)
            Tab("Profile", systemImage: "person.crop.circle", value: MainTab.profile) {
                ProfileView()
            }
        }
        .tint(GBColor.ink)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: store.activeWorkout != nil) {
            WorkoutAccessory()
        }
        .onChange(of: tab) { _, _ in Haptics.tap() }
        .onChange(of: store.pendingInvite) { _, invite in
            if invite != nil { tab = .friends }
        }
        .fullScreenCover(isPresented: $store.isWorkoutPresented) {
            ActiveWorkoutView()
        }
        .sheet(item: $store.finishedWorkout) { workout in
            WorkoutSummaryView(workout: workout, records: store.finishedRecords)
        }
    }
}

/// The glass pill above the tab bar while a workout runs with its screen
/// collapsed: title, live clock, lock state. Tap to go back in.
struct WorkoutAccessory: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var rest

    var body: some View {
        Button {
            Haptics.press()
            store.isWorkoutPresented = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(GBColor.orange)
                if let workout = store.activeWorkout {
                    Text(workout.title)
                        .font(GBFont.label(15))
                        .foregroundStyle(GBColor.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        if rest.isRunning {
                            Text("Rest \(Format.clock(TimeInterval(rest.remaining(at: context.date))))")
                                .foregroundStyle(GBColor.orange)
                        } else {
                            Text(Format.clock(context.date.timeIntervalSince(workout.start)))
                                .foregroundStyle(GBColor.steel)
                        }
                    }
                    .font(GBFont.number(15))
                }
            }
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
