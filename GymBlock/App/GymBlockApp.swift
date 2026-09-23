import SwiftUI

@main
struct GymBlockApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(store.screenTime)
                .environment(store.rest)
                .tint(GBColor.orange)
                .preferredColorScheme(.light)
                .task { await store.start() }
        }
    }
}
