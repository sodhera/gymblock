import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        MuscleMapIcon(exercise: ExerciseCatalog.byID["bench-press-bb"], size: 200)
    }
}
