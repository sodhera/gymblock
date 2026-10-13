#if DEBUG
  import SwiftUI
  import UIKit

  /// Development only (docs/WIDGETS-PLAN.md §9): every widget in every state at its true point size,
  /// on stand-ins for the surfaces iOS draws them on. Fixtures are built in code, relative to now; the
  /// screen never makes a store and never writes the snapshot. Only the Live page reads the App Group,
  /// to prove what the app wrote. `-widgetPreview <page> [row]`: home (the default), dark, tinted,
  /// lock, standby, spanish or live, and optionally a row to scroll to (`stale`, `type` for the font check).
  struct WidgetPreviewScreen: View {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-widgetPreview") }
    /// The words after `-widgetPreview`, up to the next flag: the page, then a row.
    private static var words: [String] {
      let args = ProcessInfo.processInfo.arguments
      guard let i = args.firstIndex(of: "-widgetPreview") else { return [] }
      return Array(args[(i + 1)...].prefix { !$0.hasPrefix("-") })
    }

    @State private var page = PreviewPage(rawValue: Self.words.first ?? "") ?? .home
    @State private var now = Date()
    /// The Live page's snapshot, read from the App Group each time the page opens.
    @State private var stored: WidgetSnapshot?
    @State private var jumped = false

    var body: some View {
      let screen = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.size ?? CGSize(width: 393, height: 852)
      let metrics = WidgetMetrics.for(screenWidth: screen.width, height: screen.height)
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 28) {
            Text("\(Int(screen.width)) × \(Int(screen.height)) screen · small \(Int(metrics.small)) · medium \(Int(metrics.medium.width))")
              .font(.system(size: 11)).foregroundStyle(page.label)
            ForEach(rows) { PreviewStateRow(row: $0, page: page, metrics: metrics, now: now).id($0.id) }
            if page == .home { TypeReference(width: metrics.medium.width).id("type") }
          }
          .padding(.vertical, 20)
          .frame(maxWidth: .infinity)
        }
        .id(page)
        .task {
          // Once, for the launch line's row: screenshots of a state far down the page.
          guard !jumped, let row = Self.words.dropFirst().first else { return }
          jumped = true
          try? await Task.sleep(for: .milliseconds(300))
          proxy.scrollTo(row, anchor: .top)
        }
      }
      .background { page.surfaces[0].wallpaper.ignoresSafeArea() }
      .safeAreaInset(edge: .top, spacing: 0) {
        Picker("Page", selection: $page) {
          ForEach(PreviewPage.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.bar)
      }
      .preferredColorScheme(page.dark ? .dark : .light)
      .task(id: page) {
        now = Date()
        if page == .live { stored = WidgetSnapshot.load() }
      }
    }

    private var rows: [PreviewRow] {
      switch page {
      case .live:
        let label = stored.map { s in
          "From the App Group, as the app wrote it: \(s.state.rawValue)\(s.sample ? ", sample" : ""), \(s.days.count) trained days in six weeks"
        }
        return [PreviewRow(id: "live", label: label ?? "No snapshot in the App Group (\(WidgetSnapshot.group), \(WidgetSnapshot.key))",
                           snapshot: stored)]
      case .spanish: return Fixtures(now: now, es: true).rows
      default: return Fixtures(now: now, es: false).rows
      }
    }
  }

  /// Apple's published widget sizes, in points, for the iPhone screens below; any other screen gets the
  /// 393-pt sizes (the 14 Pro, the user's). Width alone can't tell the two 375-pt screens apart, so the
  /// height comes too.
  struct WidgetMetrics: Equatable {
    let small: CGFloat
    let medium: CGSize
    let circular: CGFloat
    let rectangular: CGSize
    let inline: CGSize
    /// The Home Screen sizes' content margin.
    static let margin: CGFloat = 16

    static func `for`(screenWidth w: CGFloat, height h: CGFloat) -> WidgetMetrics {
      switch (w, h) {
      case (430, _), (428, _): return .init(170, medium: 364, circular: 76, rect: 172, inline: 257)
      case (375, 812): return .init(155, medium: 329, circular: 72, rect: 157, inline: 225)
      case (375, 667): return .init(148, medium: 321, circular: 68, rect: 153, inline: 225)
      default: return .init(158, medium: 338, circular: 72, rect: 160, inline: 234)
      }
    }

    /// A system family's continuous corner radius: 22 at 158 pt, in proportion.
    func radius(_ side: CGFloat) -> CGFloat { 22 * side / 158 }

    private init(_ small: CGFloat, medium: CGFloat, circular: CGFloat, rect: CGFloat, inline: CGFloat) {
      self.small = small
      self.medium = CGSize(width: medium, height: small)
      self.circular = circular
      rectangular = CGSize(width: rect, height: circular)
      self.inline = CGSize(width: inline, height: 26)
    }
  }

  private enum PreviewPage: String, CaseIterable, Identifiable {
    case home, dark, tinted, lock, standby, spanish, live
    var id: Self { self }
    var title: String {
      switch self {
      case .home: "Home"
      case .dark: "Dark"
      case .tinted: "Tinted"
      case .lock: "Lock"
      case .standby: "StandBy"
      case .spanish: "ES"
      case .live: "Live"
      }
    }
    /// The wallpaper is dark: the status bar, the picker and the grey labels follow it.
    var dark: Bool { self != .home && self != .spanish && self != .live }
    var label: Color { dark ? .white.opacity(0.6) : .black.opacity(0.5) }
    /// Where each state is drawn, in order; the first is the page's own wallpaper, the others sit on
    /// bands of theirs. Each surface shows only the families that live there.
    var surfaces: [Surface] {
      switch self {
      case .home: [.homeLight]
      case .dark: [.homeDark]
      case .tinted: [.tinted]
      case .lock: [.lock, .alwaysOn]
      case .standby: [.standby]
      case .spanish: [.homeLight, .lock]
      case .live: [.homeLight, .homeDark, .lock]
      }
    }
  }

  /// A place iOS draws widgets, and how it draws them there: the tone, the scheme `.primary` reads,
  /// the wallpaper, and what stands in for the container background.
  private enum Surface {
    case homeLight, homeDark, tinted, lock, alwaysOn, standby

    /// As `WidgetTone.resolve` would pick it there. Tinted simulates the accent group with #E8C07A.
    var tone: WidgetTone {
      switch self {
      case .homeLight: .init(mode: .paper, dark: false)
      case .homeDark: .init(mode: .paper, dark: true)
      case .tinted: .init(mode: .accented, dark: true, tint: rgb(0xE8C07A))
      case .lock, .alwaysOn: .init(mode: .vibrant, dark: true)
      case .standby: .init(mode: .removed, dark: true)
      }
    }
    var scheme: ColorScheme { self == .homeLight ? .light : .dark }
    /// The Lock Screen's families, not the Home Screen's.
    var accessories: Bool { self == .lock || self == .alwaysOn }
    /// Paper; a tinted Home Screen's glass; nothing in StandBy (the system takes it away).
    var plate: Color {
      switch self {
      case .homeLight, .homeDark: tone.stage
      case .tinted: .white.opacity(0.12)
      default: .clear
      }
    }

    @ViewBuilder var wallpaper: some View {
      switch self {
      case .homeLight: LinearGradient(colors: [rgb(0x8FA3B5), rgb(0xD9C7B0)], startPoint: .top, endPoint: .bottom)
      case .homeDark, .tinted: LinearGradient(colors: [rgb(0x1D2530), rgb(0x3A2F27)], startPoint: .top, endPoint: .bottom)
      case .lock: Self.photo
      case .alwaysOn: Self.photo.overlay(Color.black.opacity(0.78))
      case .standby: Color.black
      }
    }

    /// A dark, photo-like Lock Screen: cool sky, warm light from one corner.
    private static var photo: some View {
      LinearGradient(colors: [rgb(0x46566B), rgb(0x1C2431), rgb(0x0B0D12)], startPoint: .top, endPoint: .bottom)
        .overlay(RadialGradient(colors: [rgb(0xC9A27A).opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 320))
    }
  }

  private func rgb(_ hex: UInt32) -> Color {
    Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
  }

  /// One state, as the app would have written it.
  private struct PreviewRow: Identifiable {
    /// Also the launch word that scrolls to it (`-widgetPreview lock stale`).
    let id: String
    let label: String
    let snapshot: WidgetSnapshot?
    /// Spanish: the same snapshot with no short form, drawn beside it, so each short form shows next
    /// to the full form it replaces.
    var full: WidgetSnapshot? = nil
  }

  /// The fixtures, in code and relative to now: a 3-week streak (this week's Monday and Wednesday,
  /// never a day still to come, after two trained weeks), a workout started 14 minutes ago on Bench
  /// press, one paused 5 minutes ago, one last touched 2 hours ago. Their numbers exist only here.
  private struct Fixtures {
    let now: Date
    let es: Bool

    var rows: [PreviewRow] {
      let t: (String) -> String = es ? Spanish.translate : { $0 }
      let c = TrainingDays.calendar, monday = TrainingDays.monday(of: now, c)
      func days(_ offsets: [Int]) -> [Int] {
        offsets.compactMap { c.date(byAdding: .day, value: $0, to: monday) }.filter { $0 <= now }.map { TrainingDays.key($0, c) }.sorted()
      }
      let week = days([0, 2]), streak = days([-14, -12, -7, -5, -3, 0, 2])
      func idle(_ name: String, days: [Int], priorRun: Int) -> WidgetSnapshot {
        WidgetSnapshot(state: .idle, hero: t(name), heroShort: es ? Spanish.widgetShort[name] : nil, sample: false, days: days,
                       baseWeek: TrainingDays.key(monday, c), priorRun: priorRun, goal: 5, hasHistory: !days.isEmpty,
                       labels: .init(t: t))
      }
      func running(_ name: String, exercise: String?, started: TimeInterval, paused: TimeInterval? = nil,
                   touched: TimeInterval) -> WidgetSnapshot {
        var s = idle(name, days: streak, priorRun: 2)
        s.state = .running
        s.running = .init(exercise: exercise.map(t), clockStart: now - started, pausedAt: paused.map { now - $0 },
                          lastActivity: now - touched)
        return s
      }

      var setup = idle("", days: [], priorRun: 0)
      setup.state = .setup
      var newUser = idle("Your first workout", days: [], priorRun: 0)
      newUser.detail = t("Pick exercises as you go.")
      var normal = idle(es ? "Arms" : "Push", days: streak, priorRun: 2)
      normal.detail = "6 " + t("exercises") + "  ·  48 " + t("min last time")
      normal.caption = "48 " + t("min last time")
      var never = idle(es ? "Back & lats" : "Legs", days: week, priorRun: 0)
      never.detail = "5 " + t("exercises") + "  ·  " + t("first time")
      never.caption = t("First time")
      var free = idle("Free workout", days: streak, priorRun: 2)
      free.detail = t("Pick exercises as you go.")
      var sample = normal
      sample.sample = true
      let workout = es ? "Chest & shoulders" : "Push"

      var list = [
        PreviewRow(id: "setup", label: "Setup: not onboarded, logged out or deleted", snapshot: setup),
        PreviewRow(id: "new", label: "New user: no split, no workout yet", snapshot: newUser),
        PreviewRow(id: "normal", label: "Normal: a split done before, 3-week streak", snapshot: normal),
        PreviewRow(id: "never", label: "Split never done, 1-week streak", snapshot: never),
        PreviewRow(id: "free", label: "Free workout, with history", snapshot: free),
        PreviewRow(id: "running", label: "Running: started 14 min ago, Bench press",
                   snapshot: running(workout, exercise: "Bench press", started: 14 * 60, touched: 60)),
        PreviewRow(id: "paused", label: "Paused 5 min ago",
                   snapshot: running(workout, exercise: "Bench press", started: 14 * 60, paused: 5 * 60, touched: 5 * 60)),
        PreviewRow(id: "stale", label: "Stale: last touched 2 h ago",
                   snapshot: running(workout, exercise: "Bench press", started: 160 * 60, touched: 2 * 3600)),
        PreviewRow(id: "sample", label: "Sample data: the normal state on demo history", snapshot: sample),
      ]
      if es {
        // "Mi entrenamiento" has a short form too, and no exercise chosen yet.
        list.insert(PreviewRow(id: "mine", label: "Running “My workout”, choosing an exercise",
                               snapshot: running("My workout", exercise: nil, started: 3 * 60, touched: 60)), at: 6)
        return list.map { row in
          guard let s = row.snapshot, s.heroShort != nil else { return row }
          var full = s
          full.heroShort = nil
          return PreviewRow(id: row.id, label: row.label + " · right: no short form", snapshot: s, full: full)
        }
      }
      // The clock's cap: it reads 1:20:00 and stops at 1:22:00, where the stale entry takes over.
      list.insert(PreviewRow(id: "cap", label: "Running, 2 min before stale: the clock stops at 1:22:00",
                             snapshot: running(workout, exercise: "Bench press", started: 80 * 60, touched: 73 * 60)), at: 6)
      return list
    }
  }

  /// One state on each of the page's surfaces, then its grey label.
  private struct PreviewStateRow: View {
    let row: PreviewRow
    let page: PreviewPage
    let metrics: WidgetMetrics
    let now: Date
    var body: some View {
      VStack(spacing: 10) {
        ForEach(page.surfaces, id: \.self) { surface in
          SurfaceBlock(row: row, surface: surface, metrics: metrics, now: now, band: surface != page.surfaces[0])
        }
        Text(row.label).font(.system(size: 11)).foregroundStyle(page.label)
          .frame(width: metrics.medium.width, alignment: .leading)
      }
    }
  }

  /// The families a surface holds, at their true sizes. Home Screen: an Up next small and This month
  /// small side by side (in Spanish, Up next with no short form takes the month's place), then the
  /// medium; StandBy only the smalls. Lock Screen: the circular and rectangular together, then inline.
  private struct SurfaceBlock: View {
    let row: PreviewRow
    let surface: Surface
    let metrics: WidgetMetrics
    let now: Date
    let band: Bool
    var body: some View {
      Group {
        if surface.accessories { lock } else { home }
      }
      .frame(width: metrics.medium.width)
      .environment(\.widgetTone, surface.tone)
      .environment(\.colorScheme, surface.scheme)
      .environment(\.isLuminanceReduced, surface == .alwaysOn)
      .padding(band ? 14 : 0)
      .background {
        if band { surface.wallpaper.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) }
      }
    }

    /// Two smalls and the gap between them make one medium, as on the Home Screen grid.
    private var home: some View {
      let gap = metrics.medium.width - 2 * metrics.small, square = CGSize(width: metrics.small, height: metrics.small)
      return VStack(spacing: gap) {
        HStack(spacing: gap) {
          plate(square) { UpNextSmallView(snapshot: row.snapshot, date: now) }
          if let full = row.full {
            plate(square) { UpNextSmallView(snapshot: full, date: now) }
          } else {
            plate(square) { MonthSmallView(snapshot: row.snapshot, date: now) }
          }
        }
        if surface != .standby { plate(metrics.medium) { UpNextMediumView(snapshot: row.snapshot, date: now) } }
      }
    }

    /// 16 pt between Lock Screen slots (a rectangular is two circulars and a gap). The system draws the
    /// inline line in its own font; 17 semibold stands in for it here.
    private var lock: some View {
      VStack(spacing: 12) {
        HStack(spacing: 16) {
          WeekCircularView(snapshot: row.snapshot, date: now)
            .frame(width: metrics.circular, height: metrics.circular)
            .background(Circle().fill(.white.opacity(0.15)))
            .clipShape(Circle())
          UpNextRectView(snapshot: row.snapshot, date: now)
            .frame(width: metrics.rectangular.width, height: metrics.rectangular.height)
            .clipped()
        }
        UpNextInlineView(snapshot: row.snapshot, date: now)
          .font(.system(size: 17, weight: .semibold))
          .frame(width: metrics.inline.width, height: metrics.inline.height)
          .clipped()
      }
    }

    /// A Home Screen widget: content margins, the surface's container background, the system's corners.
    private func plate<V: View>(_ size: CGSize, @ViewBuilder _ content: () -> V) -> some View {
      let shape = RoundedRectangle(cornerRadius: metrics.radius(size.height), style: .continuous)
      return content()
        .padding(WidgetMetrics.margin)
        .frame(width: size.width, height: size.height)
        .background(surface.plate, in: shape)
        .clipShape(shape)
    }
  }

  /// The same hero in DM Sans and in SF Pro, at the bottom of Home: if the two match, DM Sans fell
  /// back to SF Pro without a word.
  private struct TypeReference: View {
    let width: CGFloat
    var body: some View {
      let font = AppFont.uiFont(size: 40, weight: .bold)
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline, spacing: 32) {
          sample(WidgetType.words(40, .bold), "DM Sans")
          sample(.system(size: 40, weight: .bold), "SF Pro")
        }
        Text("\(font?.fontName ?? "DM Sans didn't register") · useDMSans \(WidgetType.useDMSans ? "on" : "off")")
          .font(.system(size: 11)).foregroundStyle(Paper.secondary.light.color)
      }
      .padding(WidgetMetrics.margin)
      .frame(width: width, alignment: .leading)
      .background(Paper.stage.light.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func sample(_ font: Font, _ name: String) -> some View {
      VStack(alignment: .leading, spacing: 2) {
        Text("Push").font(font).tracking(-1).foregroundStyle(Paper.ink.light.color)
        Text(name).font(.system(size: 11)).foregroundStyle(Paper.secondary.light.color)
      }
    }
  }
#endif
