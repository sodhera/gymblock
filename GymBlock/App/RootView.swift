import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        Text("GymBlock").font(GBFont.hero())
    }
}
