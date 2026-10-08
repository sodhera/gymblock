import SwiftUI

/// No tabs: Home, the workout or its summary fills the screen. A running workout always comes
/// back first, on relaunch too; one left running for an hour asks before anything else.
struct GymNavigationView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.scenePhase) private var scenePhase
  @State private var stale = false
  private enum Screen { case home, workout, summary }
  private var screen: Screen { store.summary != nil ? .summary : store.session != nil ? .workout : .home }
  var body: some View {
    ZStack {
      switch screen {
      case .summary: if let summary = store.summary { SummaryView(session: summary).transition(.opacity) }
      case .workout: WorkoutView().transition(.opacity)
      case .home: HomeView().transition(.opacity)
      }
    }
    .animation(.smooth(duration: 0.45), value: screen)
    .onAppear { stale = store.isStale() }
    .onChange(of: scenePhase) { _, phase in if phase == .active { stale = store.isStale() } }
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
