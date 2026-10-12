import Combine
import FamilyControls
import ManagedSettings
import SwiftUI

/// Real blocking through Apple's Screen Time. The apps, categories and sites chosen in the system
/// picker are shielded from Start workout to Finish and lifted while paused. The choice is a set of
/// opaque tokens that stays on this iPhone: GymBlock never learns the app names, so they are neither
/// synced nor sent to analytics. iOS keeps the shield up even if GymBlock is closed, and removes it
/// if GymBlock is deleted. With Strict mode off the shield offers one minute per exercise, run by the
/// extensions through the App Group (`BlockingPass`).
@MainActor final class AppBlocking: ObservableObject {
  static let shared = AppBlocking()
  static let selectionKey = "gymblock.blocking.selection"
  @Published private(set) var selection: FamilyActivitySelection
  @Published private(set) var status: AuthorizationStatus
  /// What the shield was last set to, and around which minute (the extensions change it too). Unknown
  /// (nil) until the first sync, so a launch always clears a shield the last run left behind.
  private var shielded: Shielded?
  private struct Shielded: Equatable { var tokens: BlockingPass.Tokens?; var uses: Int; var until: Date? }
  private var shared: BlockingPass.Tokens?
  private var watch: AnyCancellable?
  private static var enabled: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil }

  private init() {
    let saved = UserDefaults.standard.data(forKey: Self.selectionKey)
    selection = saved.flatMap { try? JSONDecoder().decode(FamilyActivitySelection.self, from: $0) } ?? FamilyActivitySelection()
    status = AuthorizationCenter.shared.authorizationStatus
    // iOS settles the answer a moment after launch, and changes it when access is turned off in iOS
    // Settings, so this follows it rather than trusting one read.
    watch = AuthorizationCenter.shared.$authorizationStatus.receive(on: DispatchQueue.main).sink { [weak self] now in
      MainActor.assumeIsolated {
        guard let self, now != self.status else { return }
        self.status = now
        if let store = GymStore.live { self.sync(store) }
      }
    }
  }

  var authorized: Bool {
    if status == .approved { return true }
    if #available(iOS 26.4, *) { return status == .approvedWithDataAccess }
    return false
  }
  var apps: Int { selection.applicationTokens.count }
  var categories: Int { selection.categoryTokens.count }
  var sites: Int { selection.webDomainTokens.count }
  var isEmpty: Bool { apps + categories + sites == 0 }
  /// Ready to block: Screen Time access and something chosen.
  var ready: Bool { authorized && !isEmpty }

  /// What blocking will do at the next Start workout: nothing (the switch is off), nothing because
  /// Screen Time access is off (turned off in iOS Settings, or never allowed on this iPhone), nothing
  /// because no apps are chosen, or block.
  enum State { case off, noAccess, noApps, on }
  func state(_ profile: Profile) -> State {
    guard profile.focusEnabled == true else { return .off }
    guard authorized else { return .noAccess }
    return isEmpty ? .noApps : .on
  }

  /// Asks iOS for Screen Time access (once; later calls return the answer straight away). A request
  /// that comes back without an error is a yes, even if iOS's own answer is a moment behind.
  func requestAccess() async -> Bool {
    var granted = false
    do {
      try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
      granted = true
    } catch {
      AppLog.error("Screen Time access: \(error.localizedDescription)")
    }
    refresh()
    if granted && !authorized {
      status = .approved
      if let store = GymStore.live { sync(store) }
    }
    Analytics.track("blocking_access", ["granted": authorized])
    return authorized
  }

  /// Asks again for Screen Time access. If iOS answers at once without asking, the switch is in iOS
  /// Settings, so that opens on GymBlock instead.
  func allow() async -> Bool {
    let asked = Date()
    if await requestAccess() { return true }
    if Date().timeIntervalSince(asked) < 1, let url = URL(string: UIApplication.openSettingsURLString) {
      Analytics.track("blocking_settings_opened")
      await UIApplication.shared.open(url)
    }
    return false
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
    BlockingPass.defaults.removePersistentDomain(forName: BlockingPass.group)
    UserDefaults.standard.removeObject(forKey: "gymblock.pass.reported")
    shared = nil
  }

  /// Shields while a workout runs, unpaused, with blocking on, except during a minute taken from the
  /// shield. Called after every save and on every return to the app.
  func sync(_ store: GymStore) {
    guard Self.enabled else { return }
    let on = store.profile.focusEnabled == true && store.session != nil && store.session?.pausedAt == nil && ready
    // The extensions run the minute without the app: what's blocked, whether it should be, and where
    // the workout is (the minute is once per exercise).
    let tokens = BlockingPass.Tokens(apps: selection.applicationTokens, categories: selection.categoryTokens,
                                     domains: selection.webDomainTokens)
    if tokens != shared { BlockingPass.tokens = tokens; shared = tokens }
    BlockingPass.blocking = on
    BlockingPass.place = store.session.map { session in "\(session.id)-" + (session.selected.map { $0.id } ?? "") }
    if !on { BlockingPass.clear() }
    reportMinutes()
    let want = on && !BlockingPass.running ? tokens : nil
    let now = Shielded(tokens: want, uses: BlockingPass.uses, until: BlockingPass.until)
    guard now != shielded else { return }
    shielded = now
    BlockingPass.shield(want)
  }

  /// Minutes taken from the shield since GymBlock last looked, counted (never which app).
  private func reportMinutes() {
    let uses = BlockingPass.uses
    let seen = UserDefaults.standard.integer(forKey: "gymblock.pass.reported")
    guard uses > seen else { return }
    UserDefaults.standard.set(uses, forKey: "gymblock.pass.reported")
    Analytics.track("blocking_minute_used", ["count": uses - seen])
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
