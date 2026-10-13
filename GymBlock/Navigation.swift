import SwiftUI

/// Home and Profile sit under a floating Liquid Glass tab bar; the workout and its summary fill the
/// screen without it. A running workout always comes back first, on relaunch too; one left running
/// for an hour asks before anything else.
struct GymNavigationView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.scenePhase) private var scenePhase
  @ObservedObject private var router = AppRouter.shared
  @State private var stale = false
  private enum Screen { case home, workout, summary }
  private var screen: Screen { store.summary != nil ? .summary : store.session != nil ? .workout : .home }
  var body: some View {
    ZStack {
      switch screen {
      case .summary: if let summary = store.summary { SummaryView(session: summary).transition(.opacity) }
      case .workout: WorkoutView().transition(.opacity)
      case .home: MainTabs().transition(.opacity)
      }
    }
    .animation(.smooth(duration: 0.45), value: screen)
    .onAppear { stale = store.isStale() }
    .onChange(of: scenePhase) { _, phase in if phase == .active { stale = store.isStale() } }
    // A running workout and its summary come first: a widget or the control just opens them.
    .onChange(of: router.ready, initial: true) { _, r in
      if let r, screen != .home { router.consume(r) }
    }
    .alert(store.t("Still working out?"), isPresented: $stale) {
      Button(store.t("Finish workout")) { store.finishStale() }.accessibilityIdentifier("stale.finish")
      // A paused workout comes back paused; this is the one-tap way back in.
      Button(store.t(store.isPaused ? "Resume" : "Keep going"), role: .cancel) { store.resume() }
        .accessibilityIdentifier("stale.keep")
    } message: {
      Text(staleMessage)
    }
  }
  private var staleMessage: String {
    guard let last = store.lastActivity else { return "" }
    let time = { (date: Date) in date.formatted(date: Calendar.current.isDateInToday(date) ? .omitted : .abbreviated, time: .shortened) }
    let open = store.session?.stage == .active ? " " + store.t("The unfinished set won’t be saved.") : ""
    if let paused = store.session?.pausedAt {
      return store.t("Paused at") + " " + time(paused) + ". " + store.t("Finishing ends it at your last set.") + open
    }
    return store.t("Last activity at") + " " + time(last) + ". " + store.t("Finishing ends it then.") + open
  }
}

/// The two places outside a workout. The system tab bar is Liquid Glass and floats over the page on
/// iOS 26; earlier versions get the standard bar. Ink marks the chosen tab, as it marks every action.
struct MainTabs: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var router = AppRouter.shared
  private enum Place: String { case home, profile }
  @State private var place = Place.home
  /// The tab was moved by a widget or the control, not tapped.
  @State private var routed = false
  var body: some View {
    TabView(selection: $place) {
      // Ink inside each page, so its questions, menus and back buttons aren't emerald.
      HomeView().tint(JourneyColor.text)
        .tabItem { Label(store.t("Home"), systemImage: "house.fill") }
        .tag(Place.home)
      ProfileTab().tint(JourneyColor.text)
        .tabItem { Label(store.t("Profile"), systemImage: "person.crop.circle.fill") }
        .tag(Place.profile)
    }
    // The chosen tab is the accent; ink stays the action colour everywhere else.
    .tint(JourneyColor.signal)
    .onChange(of: place) { _, chosen in
      // A route's move isn't a tap: no event, no haptic (`widget_opened` already said why).
      if routed { routed = false; return }
      Analytics.tap("tab." + chosen.rawValue)
      JourneyHaptic.play(.selection, store.profile)
    }
    // Widgets and the control: Home, or Profile from the month; a start goes on to HomeView, which begins it.
    .onChange(of: router.ready, initial: true) { _, r in
      guard let r else { return }
      go(r.route == .profile ? .profile : .home)
      if r.route != .start { router.consume(r) }
    }
  }
  private func go(_ p: Place) {
    guard place != p else { return }
    routed = true
    place = p
  }
}

