import SwiftUI

@main
struct GymBlockApp: App {
    @State private var store = AppStore()
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    init() {
        // Navigation titles in the brand's expanded width, so pushed screens
        // ("History", "Legs") speak the same type as the heroes.
        let ink = UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: 0xF2F1EC) : UIColor(hex: 0x111214) }
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
                .tint(GBColor.ink) // chrome is ink; orange is applied explicitly where earned
                .preferredColorScheme(appearance.colorScheme)
                .task { await store.start() }
                .onOpenURL { store.handle(url: $0) }
        }
    }
}

/// System / Light / Dark, chosen in Settings. System is the default.
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    static let storageKey = "appearance"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
