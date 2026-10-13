import SwiftUI
import WidgetKit

/// One moment of a widget's timeline: the snapshot as the app last wrote it, read at `date`. The views
/// work out the phase (setup, idle, running, paused, stale) from the two, so a timeline needs entries
/// only where the picture changes on its own: midnights, and the moment a workout goes stale.
struct GlanceEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?
  let relevance: TimelineEntryRelevance?
}

extension WidgetSnapshot {
  /// The gallery and the placeholder: a new user's widget in the extension's own strings (the
  /// system language). A faint week with today ringed, "Your first workout", "Week 1"; never sample numbers.
  static func newUser(at now: Date) -> WidgetSnapshot {
    let t = WidgetGlance.local, hero = t("Your first workout"), short = t("Your first workout (short)")
    return WidgetSnapshot(
      state: .idle, hero: hero, heroShort: short == hero ? nil : short, detail: t("Pick exercises as you go."),
      caption: nil, sample: false, days: [], baseWeek: TrainingDays.key(TrainingDays.monday(of: now)), priorRun: 0,
      goal: 5, hasHistory: false, lastFinished: nil, running: nil, labels: .init(t: t))
  }
}

/// What the three providers share: the placeholder, the gallery, and the rule for no snapshot. Each
/// kind only says how a written, signed-in snapshot unfolds over time.
protocol GlanceProvider: TimelineProvider where Entry == GlanceEntry {
  func timeline(_ s: WidgetSnapshot, at now: Date) -> Timeline<GlanceEntry>
}

extension GlanceProvider {
  func placeholder(in context: TimelineProviderContext) -> GlanceEntry {
    GlanceEntry(date: Date(), snapshot: .newUser(at: Date()), relevance: nil)
  }

  /// The gallery shows a new user's widget rather than an empty one; everywhere else, what's true now.
  func getSnapshot(in context: TimelineProviderContext, completion: @escaping @Sendable (GlanceEntry) -> Void) {
    let now = Date(), s = WidgetSnapshot.load()
    if context.isPreview && (s == nil || s?.state == .setup) {
      return completion(GlanceEntry(date: now, snapshot: .newUser(at: now), relevance: nil))
    }
    completion(current(s, at: now).entries[0])
  }

  func getTimeline(in context: TimelineProviderContext, completion: @escaping @Sendable (Timeline<GlanceEntry>) -> Void) {
    completion(current(WidgetSnapshot.load(), at: Date()))
  }

  /// No snapshot (a fresh install, or before the first unlock) checks back hourly: the only polling,
  /// and it stops once the app has written. Setup (logged out or deleted) holds until the app writes again.
  private func current(_ s: WidgetSnapshot?, at now: Date) -> Timeline<GlanceEntry> {
    guard let s, s.state != .setup else {
      return Timeline(entries: [GlanceEntry(date: now, snapshot: s, relevance: nil)],
                      policy: s == nil ? .after(now.addingTimeInterval(3600)) : .never)
    }
    return timeline(s, at: now)
  }
}

/// Now and the next seven midnights in the device calendar (so daylight saving moves with the clock):
/// each entry redraws its own today ring, Monday reset and month.
private func days(_ s: WidgetSnapshot, from now: Date, relevance: TimelineEntryRelevance? = nil) -> [GlanceEntry] {
  let calendar = Calendar.current, today = calendar.startOfDay(for: now)
  let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
  return ([now] + midnights).map { GlanceEntry(date: $0, snapshot: s, relevance: relevance) }
}

/// A running workout: the clock until `activeUntil`, then "Still working out?" at that same moment,
/// and the midnights still, because the medium's week row turns over under a workout (or a forgotten
/// one) like any other day. The app reloads it when the workout changes; a Lock Screen set moves
/// `activeUntil` without a reload, which is why it runs up to 15 minutes late and never early.
struct UpNextProvider: GlanceProvider {
  func timeline(_ s: WidgetSnapshot, at now: Date) -> Timeline<GlanceEntry> {
    guard s.state == .running, let r = s.running else {
      return Timeline(entries: days(s, from: now, relevance: TimelineEntryRelevance(score: 0.1)), policy: .atEnd)
    }
    // Top of the stack while it runs, halfway for the hour after it goes stale, then as when idle.
    let faded = r.activeUntil.addingTimeInterval(3600)
    func relevance(_ d: Date) -> TimelineEntryRelevance {
      d < r.activeUntil ? TimelineEntryRelevance(score: 1, duration: r.activeUntil.timeIntervalSince(d))
        : d < faded ? TimelineEntryRelevance(score: 0.5, duration: faded.timeIntervalSince(d))
        : TimelineEntryRelevance(score: 0.1)
    }
    let dates = Set(days(s, from: now).map(\.date) + [r.activeUntil]).filter { $0 >= now }.sorted()
    return Timeline(entries: dates.map { GlanceEntry(date: $0, snapshot: s, relevance: relevance($0)) }, policy: .atEnd)
  }
}

/// This month rises in a Smart Stack for two hours after a finish ("today's dot just turned emerald").
struct MonthProvider: GlanceProvider {
  func timeline(_ s: WidgetSnapshot, at now: Date) -> Timeline<GlanceEntry> {
    var entries = days(s, from: now, relevance: TimelineEntryRelevance(score: 0.1))
    if let finished = s.lastFinished, now < finished.addingTimeInterval(7200) {
      entries[0] = GlanceEntry(date: now, snapshot: s,
                               relevance: TimelineEntryRelevance(score: 0.6, duration: finished.addingTimeInterval(7200).timeIntervalSince(now)))
    }
    return Timeline(entries: entries, policy: .atEnd)
  }
}

struct WeekProvider: GlanceProvider {
  func timeline(_ s: WidgetSnapshot, at now: Date) -> Timeline<GlanceEntry> {
    Timeline(entries: days(s, from: now), policy: .atEnd)
  }
}

/// Every entry view's frame (§2.7): the tone for this rendering, resolved once; flat paper behind
/// the Home Screen sizes, the system's backdrop behind the circle, nothing behind the Lock Screen
/// text; and the one tap target. No `Link`, no buttons.
private struct GlanceChrome: ViewModifier {
  let url: URL
  @Environment(\.widgetFamily) private var family
  @Environment(\.widgetRenderingMode) private var mode
  @Environment(\.showsWidgetContainerBackground) private var background
  @Environment(\.colorScheme) private var scheme
  func body(content: Content) -> some View {
    let tone = WidgetTone.resolve(mode, background: background, scheme: scheme)
    content
      .environment(\.widgetTone, tone)
      .containerBackground(for: .widget) {
        switch family {
        case .systemSmall, .systemMedium: tone.stage
        case .accessoryCircular: AccessoryWidgetBackground()
        default: Color.clear
        }
      }
      .widgetURL(url)
  }
}

struct UpNextEntryView: View {
  let entry: GlanceEntry
  @Environment(\.widgetFamily) private var family
  var body: some View {
    let route = WidgetGlance(entry.snapshot, at: entry.date).route
    Group {
      switch family {
      case .systemMedium: UpNextMediumView(snapshot: entry.snapshot, date: entry.date)
      case .accessoryRectangular: UpNextRectView(snapshot: entry.snapshot, date: entry.date)
      case .accessoryInline: UpNextInlineView(snapshot: entry.snapshot, date: entry.date)
      default: UpNextSmallView(snapshot: entry.snapshot, date: entry.date)
      }
    }
    .modifier(GlanceChrome(url: AppRoute.url(route, from: source)))
  }
  private var source: String {
    switch family {
    case .systemMedium: "medium"
    case .accessoryRectangular: "rect"
    case .accessoryInline: "inline"
    default: "small"
    }
  }
}

struct MonthEntryView: View {
  let entry: GlanceEntry
  var body: some View {
    MonthSmallView(snapshot: entry.snapshot, date: entry.date)
      .modifier(GlanceChrome(url: AppRoute.url(.profile, from: "month")))
  }
}

/// Opens Home; a running workout shows first anyway, because the app puts it there.
struct WeekEntryView: View {
  let entry: GlanceEntry
  var body: some View {
    WeekCircularView(snapshot: entry.snapshot, date: entry.date)
      .modifier(GlanceChrome(url: AppRoute.url(.home, from: "circular")))
  }
}

/// CarPlay has nothing to open, so there the gallery files the widgets under Other (iOS 26).
enum WidgetPlacement {
  static var disfavored: [WidgetLocation] {
    if #available(iOS 26.0, *) { return [.carPlay] }
    return []
  }
}

/// What you train next, or the workout you're in. Where the shield sends you back to.
struct UpNextWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: WidgetKind.upNext, provider: UpNextProvider()) { UpNextEntryView(entry: $0) }
      .configurationDisplayName("Up next")
      .description("What's next, or the workout you're in.")
      .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
      .disfavoredLocations(WidgetPlacement.disfavored, for: [.systemSmall])
  }
}

/// Every day you trained this month: the only look back, and Profile's month as a widget.
struct MonthWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: WidgetKind.month, provider: MonthProvider()) { MonthEntryView(entry: $0) }
      .configurationDisplayName("This month")
      .description("The days you trained this month.")
      .supportedFamilies([.systemSmall])
      .disfavoredLocations(WidgetPlacement.disfavored, for: [.systemSmall])
  }
}

/// This week round the kettlebell on the Lock Screen, at every pickup.
struct WeekWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: WidgetKind.week, provider: WeekProvider()) { WeekEntryView(entry: $0) }
      .configurationDisplayName("This week")
      .description("The days you trained this week.")
      .supportedFamilies([.accessoryCircular])
      .disfavoredLocations(WidgetPlacement.disfavored, for: [.systemSmall])
  }
}

#if DEBUG
/// The canvas only: a new user, and a workout fourteen minutes in. Real states are checked through
/// the app's -widgetPreview screen and on the simulator's own Home and Lock Screens.
private enum CanvasFixture {
  static var running: WidgetSnapshot {
    var s = WidgetSnapshot.newUser(at: .now)
    s.state = .running
    s.hero = "Push"
    s.heroShort = nil
    s.running = .init(exercise: "Bench press", clockStart: .now.addingTimeInterval(-14 * 60), pausedAt: nil, lastActivity: .now)
    return s
  }
  static var entries: [GlanceEntry] {
    [GlanceEntry(date: .now, snapshot: nil, relevance: nil),
     GlanceEntry(date: .now, snapshot: .newUser(at: .now), relevance: nil),
     GlanceEntry(date: .now, snapshot: running, relevance: nil)]
  }
}

#Preview("Up next small", as: .systemSmall) {
  UpNextWidget()
} timeline: {
  CanvasFixture.entries[0]
  CanvasFixture.entries[1]
  CanvasFixture.entries[2]
}

#Preview("Up next medium", as: .systemMedium) {
  UpNextWidget()
} timeline: {
  CanvasFixture.entries[1]
  CanvasFixture.entries[2]
}

#Preview("Up next rect", as: .accessoryRectangular) {
  UpNextWidget()
} timeline: {
  CanvasFixture.entries[1]
  CanvasFixture.entries[2]
}

#Preview("Up next inline", as: .accessoryInline) {
  UpNextWidget()
} timeline: {
  CanvasFixture.entries[1]
  CanvasFixture.entries[2]
}

#Preview("This month", as: .systemSmall) {
  MonthWidget()
} timeline: {
  CanvasFixture.entries[0]
  CanvasFixture.entries[1]
}

#Preview("This week", as: .accessoryCircular) {
  WeekWidget()
} timeline: {
  CanvasFixture.entries[0]
  CanvasFixture.entries[1]
}
#endif
