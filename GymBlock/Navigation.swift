import SwiftUI

enum GymTab: Hashable { case home, history, splits }

struct GymNavigationView: View {
  @EnvironmentObject private var store: GymStore
  @State private var selected: GymTab = .home
  var body: some View {
    TabView(selection: $selected) {
      Group {
        if let summary = store.summary {
          SummaryView(session: summary)
        } else if store.session != nil {
          SessionView()
        } else {
          HomeView(onSplits: { selected = .splits })
        }
      }.tabItem { Label(store.t("Home"), systemImage: "house") }.tag(GymTab.home)
      HistoryHubView(onResume: { selected = .home })
        .tabItem { Label(store.t("History"), systemImage: "clock.arrow.circlepath") }.tag(
          GymTab.history)
      NavigationStack {
        SplitsView()
          .toolbar {
            if store.session != nil {
              ToolbarItem(placement: .topBarTrailing) {
                Button(store.t("Resume workout")) { selected = .home }
                  .accessibilityIdentifier("splits.resume")
              }
            }
          }
      }.tabItem { Label(store.t("Splits"), systemImage: "list.bullet") }.tag(GymTab.splits)
    }
  }
}

struct HistoryHubView: View {
  @EnvironmentObject private var store: GymStore
  let onResume: () -> Void
  @State private var progress = false
  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 24) {
          Text(store.t("History")).font(GymType.hero(32)).accessibilityAddTraits(.isHeader)
          if store.session != nil {
            Button(action: onResume) {
              Label(store.t("Resume workout"), systemImage: "arrow.uturn.left")
                .font(GymType.label(16)).frame(minHeight: 44)
            }.accessibilityIdentifier("history.resume")
          }
          Picker(store.t("History view"), selection: $progress) {
            Text(store.t("Workouts")).tag(false)
            Text(store.t("Progress")).tag(true)
          }.pickerStyle(.segmented).accessibilityIdentifier("history.mode")
          if progress {
            ProgressContent()
          } else if store.data.history.isEmpty {
            Text(store.t("No workouts yet.")).foregroundStyle(GymColor.dim)
          } else {
            Text("\(store.data.history.count) " + store.t("workouts saved"))
              .font(GymType.body(14)).foregroundStyle(GymColor.dim)
            LazyVStack(spacing: 0) {
              ForEach(store.data.history) { session in
                NavigationLink {
                  WorkoutDetailView(sessionID: session.id)
                } label: {
                  HStack(spacing: 12) {
                    WorkoutRecap(session: session).foregroundStyle(GymColor.ink)
                    Image(systemName: "chevron.right").font(.system(size: 12))
                      .foregroundStyle(GymColor.dim)
                  }.padding(.vertical, 18)
                }.accessibilityIdentifier("history." + session.id.uuidString)
                Divider().opacity(0.45)
              }
            }
          }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
      }.gymPage().navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
  }
}
