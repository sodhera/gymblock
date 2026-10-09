import FamilyControls
import ManagedSettings
import SwiftUI

/// Real blocking through Apple's Screen Time. The apps, categories and sites chosen in the system
/// picker are shielded from Start workout to Finish and lifted while paused. The choice is a set of
/// opaque tokens that stays on this iPhone: GymBlock never learns the app names, so they are neither
/// synced nor sent to analytics. iOS keeps the shield up even if GymBlock is closed, and removes it
/// if GymBlock is deleted.
@MainActor final class AppBlocking: ObservableObject {
  static let shared = AppBlocking()
  static let selectionKey = "gymblock.blocking.selection"
  @Published private(set) var selection: FamilyActivitySelection
  @Published private(set) var status: AuthorizationStatus
  private let shield = ManagedSettingsStore(named: ManagedSettingsStore.Name("gymblock.workout"))
  /// What the shield holds now: nil while lifted. Unknown (`applied == false`) until the first sync,
  /// so a launch always clears a shield the last run left behind.
  private var shielded: FamilyActivitySelection?
  private var applied = false
  private static var enabled: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil }

  private init() {
    let saved = UserDefaults.standard.data(forKey: Self.selectionKey)
    selection = saved.flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) } ?? FamilyActivitySelection()
    status = AuthorizationCenter.shared.authorizationStatus
  }

  var authorized: Bool { status == .approved }
  var apps: Int { selection.applicationTokens.count }
  var categories: Int { selection.categoryTokens.count }
  var sites: Int { selection.webDomainTokens.count }
  var isEmpty: Bool { apps + categories + sites == 0 }
  /// Ready to block: Screen Time access and something chosen.
  var ready: Bool { authorized && !isEmpty }

  /// Asks iOS for Screen Time access (once; later calls return the answer straight away).
  func requestAccess() async -> Bool {
    do { try await AuthorizationCenter.shared.requestAuthorization(for: .individual) } catch {
      AppLog.error("Screen Time access: \(error.localizedDescription)")
    }
    refresh()
    Analytics.track("blocking_access", ["granted": authorized])
    return authorized
  }

  /// Picks up a change made in iOS Settings while GymBlock was in the background.
  func refresh() {
    let now = AuthorizationCenter.shared.authorizationStatus
    if now != status { status = now }
    if let store = GymStore.live { sync(store) }
  }

  func choose(_ chosen: FamilyActivitySelection) {
    selection = chosen
    if let data = try? JSONEncoder().encode(chosen) { UserDefaults.standard.set(data, forKey: Self.selectionKey) }
    Analytics.track("blocking_chosen", ["apps": apps, "categories": categories, "sites": sites])
    if let store = GymStore.live { sync(store) }
  }

  /// Delete account: the choice goes with the rest of the device copy.
  func forget() {
    selection = FamilyActivitySelection()
    UserDefaults.standard.removeObject(forKey: Self.selectionKey)
  }

  /// Shields while a workout runs, unpaused, with blocking on. Called after every save.
  func sync(_ store: GymStore) {
    guard Self.enabled else { return }
    let on = store.profile.focusEnabled == true && store.session != nil && store.session?.pausedAt == nil && ready
    let want = on ? selection : nil
    guard !applied || want != shielded else { return }
    applied = true
    shielded = want
    guard let want else { shield.clearAllSettings(); return }
    shield.shield.applications = want.applicationTokens.isEmpty ? nil : want.applicationTokens
    shield.shield.applicationCategories = want.categoryTokens.isEmpty ? nil : .specific(want.categoryTokens)
    shield.shield.webDomains = want.webDomainTokens.isEmpty ? nil : want.webDomainTokens
    shield.shield.webDomainCategories = want.categoryTokens.isEmpty ? nil : .specific(want.categoryTokens)
  }

  /// "3 apps", "2 apps, 1 category", "1 site".
  func summary(_ t: (String) -> String) -> String {
    func part(_ n: Int, _ one: String, _ many: String) -> String? { n == 0 ? nil : n == 1 ? t(one) : "\(n) " + t(many) }
    return [part(apps, "1 app", "apps"), part(categories, "1 category", "categories"), part(sites, "1 site", "sites")]
      .compactMap { $0 }.joined(separator: ", ")
  }
}

/// The chosen apps as their real icons (iOS draws them; GymBlock never sees which apps they are),
/// then categories, then a "+N" for the rest.
struct BlockedIcons: View {
  @ObservedObject var blocking = AppBlocking.shared
  var size: CGFloat = 16
  var limit = 4
  var body: some View {
    let apps = Array(blocking.selection.applicationTokens).prefix(limit)
    let categories = Array(blocking.selection.categoryTokens).prefix(max(0, limit - apps.count))
    let more = blocking.apps + blocking.categories - apps.count - categories.count
    HStack(spacing: size * 0.25) {
      ForEach(Array(apps), id: \.self) { Label($0).labelStyle(.iconOnly).frame(width: size, height: size) }
      ForEach(Array(categories), id: \.self) { Label($0).labelStyle(.iconOnly).frame(width: size, height: size) }
      if more > 0 { Text("+\(more)").monospacedDigit() }
    }.accessibilityHidden(true)
  }
}
