import SwiftUI

extension Notification.Name { static let returnToWorkout = Notification.Name("GymBlock.returnToWorkout") }
enum GymTab: Hashable { case home, history, splits }
struct GymNavigationView: View {
  @EnvironmentObject private var store: GymStore
  @State private var selected: GymTab = .home
  var body: some View {
    TabView(selection: $selected) {
      Group {
        if let summary = store.summary { SummaryView(session: summary) }
        else if store.session != nil { SessionView() }
        else { HomeView(onSplits: { selected = .splits }) }
      }.tabItem { Label(store.t("Workout"), systemImage: "dumbbell") }.tag(GymTab.home)
      HistoryHubView(onResume: { selected = .home })
        .tabItem { Label(store.t("History"), systemImage: "clock.arrow.circlepath") }.tag(GymTab.history)
      NavigationStack { SplitsView() }
        .tabItem { Label(store.t("Splits"), systemImage: "list.bullet") }.tag(GymTab.splits)
    }.onChange(of: store.session?.id) { old, new in if old == nil && new != nil { selected = .home } }
      .onReceive(NotificationCenter.default.publisher(for: .returnToWorkout)) { _ in selected = .home }
  }
}

struct HistoryHubView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  let onResume: () -> Void
  @State private var fourWeeks = true
  private var since: Date? { fourWeeks ? Calendar.current.date(byAdding: .day, value: -28, to: Date()) : nil }
  private var sessions: [Session] { store.data.history.filter { since == nil || $0.started >= since! }.sorted { $0.started > $1.started } }
  private var points: [TrainingPoint] { store.trainingPoints(since: since) }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          if store.data.history.isEmpty {
            Text(store.t("No workouts yet")).font(GymType.body(17)).foregroundStyle(GymColor.dim)
            Button(store.t("Start workout")) { if store.session == nil { store.startSession() }; onResume() }
              .frame(minHeight: 44)
          } else {
            if store.data.demoLoaded == true { Text(store.t("Demo")).font(GymType.body(13)).foregroundStyle(GymColor.dim) }
            if typeSize.isAccessibilitySize {
              VStack(alignment: .leading, spacing: 24) { totals }
            } else {
              HStack(alignment: .top, spacing: 24) { totals }
            }
            NavigationLink { ExerciseProgressList() } label: {
              HStack { Text(store.t("Exercise progress")); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12)).accessibilityHidden(true) }
                .foregroundStyle(GymColor.ink).frame(minHeight: 44)
            }.accessibilityIdentifier("history.progress")
            if sessions.isEmpty { Text(store.t("No workouts in this period")).foregroundStyle(GymColor.dim) }
            LazyVStack(spacing: 0) {
              ForEach(sessions) { session in
                NavigationLink { WorkoutDetailView(sessionID: session.id) } label: {
                  WorkoutRecap(session: session).foregroundStyle(GymColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 18)
                }.accessibilityIdentifier("history." + session.id.uuidString)
                Divider().opacity(0.5)
              }
            }
          }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
      }.gymPage().navigationTitle(store.t("History")).navigationBarTitleDisplayMode(.large)
        .toolbar {
          if !store.data.history.isEmpty {
            ToolbarItem(placement: .topBarTrailing) {
              Picker(store.t("Period"), selection: $fourWeeks) {
                Text(store.t("Last 4 weeks")).tag(true); Text(store.t("All time")).tag(false)
              }.pickerStyle(.menu).accessibilityIdentifier("history.period")
            }
          }
        }
    }
  }
  @ViewBuilder private var totals: some View {
    total("Reps", amount: Double(points.reduce(0) { $0 + $1.reps }), metric: 0)
    total("Weight moved", amount: GymStore.displayedWeight(points.reduce(0) { $0 + $1.volumeKG }, unit: store.profile.unit), metric: 1)
  }
  private func total(_ title: String, amount: Double, metric: Int) -> some View {
    NavigationLink { TrainingStatsView(initialMetric: metric, initialFourWeeks: fourWeeks) } label: {
      VStack(alignment: .leading, spacing: 8) {
        Text(store.t(title)).font(GymType.body(15)).foregroundStyle(GymColor.dim)
        Text(formatNumber(amount)).font(GymType.title(28)).monospacedDigit().foregroundStyle(GymColor.ink)
        if metric == 1 { Text(store.profile.unit).font(GymType.body(13)).foregroundStyle(GymColor.dim) }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }.accessibilityIdentifier(metric == 0 ? "history.reps" : "history.volume")
  }
}
