import DeviceActivity
import Foundation
import ManagedSettings

/// The block's one way past, and what GymBlock and its Screen Time extensions share to run it (12 Oct
/// 2026, after SleepBlock's snooze). With Strict mode off, the shield offers "Give me 1 minute" once per
/// exercise: the shield action lifts the block, and the monitor puts it back when the minute is up or a
/// minute has been spent in the blocked apps, whichever comes first. With Strict mode on there is no way
/// past until the workout ends. Everything here lives in the App Group on this iPhone: it is never synced
/// and never sent to analytics (the tokens are opaque anyway).
enum BlockingPass {
  static let group = "group.com.sodhera.gymblock"
  static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
  /// The one shield store, shared by GymBlock and its extensions.
  static var store: ManagedSettingsStore { ManagedSettingsStore(named: ManagedSettingsStore.Name("gymblock.workout")) }
  static let length: TimeInterval = 60
  /// Starts when the minute does; a minute's use of the blocked apps inside it ends the minute early.
  static let usage = DeviceActivityName("gymblock.pass.usage")
  /// Starts when the minute ends (DeviceActivity needs 15 minutes or more, so only its start counts).
  static let end = DeviceActivityName("gymblock.pass.end")
  static let used = DeviceActivityEvent.Name("gymblock.pass.used")

  static let strictKey = "gymblock.strict"
  private static let blockingKey = "gymblock.blocking"
  private static let placeKey = "gymblock.place"
  private static let spentKey = "gymblock.pass.spent"
  private static let untilKey = "gymblock.pass.until"
  private static let usesKey = "gymblock.pass.uses"
  private static let tokensKey = "gymblock.tokens"

  /// Strict mode: no minute, ever. On unless switched off (Settings → Blocking), so new users start
  /// strict, as GymBlock always was before the minute.
  static var strict: Bool { defaults.object(forKey: strictKey) as? Bool ?? true }
  /// Whether the block should be up, as GymBlock last saw it: a workout running, unpaused, blocking on
  /// with Screen Time access and something chosen. A minute in progress doesn't change it.
  static var blocking: Bool {
    get { defaults.bool(forKey: blockingKey) }
    set { defaults.set(newValue, forKey: blockingKey) }
  }
  /// Where the workout is (the workout and its exercise): the minute is once per place.
  static var place: String? {
    get { defaults.string(forKey: placeKey) }
    set { defaults.set(newValue, forKey: placeKey) }
  }
  /// When the minute in progress ends; nil when there isn't one.
  static var until: Date? {
    get { defaults.object(forKey: untilKey) as? Date }
    set { defaults.set(newValue, forKey: untilKey) }
  }
  /// How many minutes have been taken on this iPhone, for GymBlock to count.
  static var uses: Int { defaults.integer(forKey: usesKey) }
  private static var spent: String? { defaults.string(forKey: spentKey) }

  /// The shield offers the minute: not strict, the block is up, and this exercise's minute is unspent.
  static var available: Bool { !strict && blocking && place != nil && spent != place }
  /// A minute is running now.
  static var running: Bool { (until ?? .distantPast) > Date() }

  /// What the block covers, as tokens the extensions can apply without the app.
  struct Tokens: Codable, Equatable {
    var apps: Set<ApplicationToken> = []
    var categories: Set<ActivityCategoryToken> = []
    var domains: Set<WebDomainToken> = []
    var isEmpty: Bool { apps.isEmpty && categories.isEmpty && domains.isEmpty }
  }
  static var tokens: Tokens? {
    get { defaults.data(forKey: tokensKey).flatMap { try? JSONDecoder().decode(Tokens.self, from: $0) } }
    set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: tokensKey) }
  }

  /// Puts the block up over these tokens, or takes it down (nil).
  static func shield(_ tokens: Tokens?) {
    let store = store
    guard let tokens, !tokens.isEmpty else { store.clearAllSettings(); return }
    store.shield.applications = tokens.apps.isEmpty ? nil : tokens.apps
    store.shield.applicationCategories = tokens.categories.isEmpty ? nil : .specific(tokens.categories)
    store.shield.webDomains = tokens.domains.isEmpty ? nil : tokens.domains
    store.shield.webDomainCategories = tokens.categories.isEmpty ? nil : .specific(tokens.categories)
  }

  /// "Give me 1 minute": spends this exercise's minute, lifts the block and arranges its return. False if
  /// there was no minute to give (strict, already spent, or no workout).
  static func spend() -> Bool {
    guard available else { return false }
    let now = Date()
    let ends = now.addingTimeInterval(length)
    defaults.set(place, forKey: spentKey)
    until = ends
    defaults.set(uses + 1, forKey: usesKey)
    shield(nil)
    let calendar = Calendar.current
    let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    func schedule(_ from: Date) -> DeviceActivitySchedule {
      DeviceActivitySchedule(intervalStart: calendar.dateComponents(fields, from: from),
                             intervalEnd: calendar.dateComponents(fields, from: from.addingTimeInterval(16 * 60)), repeats: false)
    }
    let center = DeviceActivityCenter()
    center.stopMonitoring([usage, end])
    try? center.startMonitoring(end, during: schedule(ends))
    if let tokens {
      let event = DeviceActivityEvent(applications: tokens.apps, categories: tokens.categories, webDomains: tokens.domains,
                                      threshold: DateComponents(minute: 1))
      try? center.startMonitoring(usage, during: schedule(now), events: [used: event])
    }
    return true
  }

  /// The minute is over: the block comes back if the workout still wants it.
  static func restore() {
    until = nil
    DeviceActivityCenter().stopMonitoring([usage, end])
    if blocking { shield(tokens) }
  }

  /// The workout ended or paused: no minute carries over.
  static func clear() {
    guard until != nil else { return }
    until = nil
    DeviceActivityCenter().stopMonitoring([usage, end])
  }
}
