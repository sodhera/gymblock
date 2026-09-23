import SwiftUI

@main
struct GymBlockApp: App {
    @State private var store = AppStore()

    init() {
        // Navigation titles in the brand's expanded width, so pushed screens
        // ("History", "Legs") speak the same type as the heroes.
        let ink = UIColor(red: 0x11 / 255, green: 0x12 / 255, blue: 0x14 / 255, alpha: 1)
        func expanded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            let descriptor = base.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.width: 0.2, UIFontDescriptor.TraitKey.weight: weight.rawValue],
            ])
            return UIFont(descriptor: descriptor, size: size)
        }
        let appearance = UINavigationBar.appearance()
        appearance.largeTitleTextAttributes = [.font: expanded(32, .bold), .foregroundColor: ink]
        appearance.titleTextAttributes = [.font: expanded(16, .semibold), .foregroundColor: ink]
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(store.screenTime)
                .environment(store.rest)
                .tint(GBColor.orange)
                .preferredColorScheme(.light)
                .task { await store.start() }
                .onOpenURL { store.handle(url: $0) }
        }
    }
}
