import SwiftUI

/// Profile (11 Oct 2026): the title and Settings; one honest number (the average workout over the
/// last seven); the apps GymBlock blocks, on a glass card that opens Blocked
/// apps; this month as a calendar of dots; then the latest five workouts as cards, each opening its
/// page, and every workout behind "All". A new account sees no numbers, never examples.
struct ProfileTab: View {
  @EnvironmentObject private var store: GymStore
  @State private var settings = false
  private var sessions: [Session] { store.data.history.sorted { $0.started > $1.started } }
  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid()
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            header
            // The month first (13 Oct 2026, at the user's request), then the average, blocking and the list.
            if !sessions.isEmpty { MonthDots(sessions: sessions).padding(.top, 26) }
            if let recent { summary(recent).padding(.top, 40) }
            NavigationLink { BlockedAppsView() } label: { BlockedAppsCard() }
              .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("profile.blocking").padding(.top, 26)
            if sessions.isEmpty {
              empty.padding(.top, 40)
            } else {
              recentList.padding(.top, 40)
            }
          }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        // No bar on this page, so rows fade out under the status bar instead of running into it.
        GeometryReader { geometry in
          LinearGradient(stops: [.init(color: JourneyColor.stage, location: 0.6), .init(color: JourneyColor.stage.opacity(0), location: 1)],
                         startPoint: .top, endPoint: .bottom)
            .frame(height: geometry.safeAreaInsets.top + 16).ignoresSafeArea(edges: .top)
        }.allowsHitTesting(false).accessibilityHidden(true)
      }
      .toolbar(.hidden, for: .navigationBar)
      .track(screen: "profile", ["workouts": sessions.count])
    }
    .sheet(isPresented: $settings) { PreferencesView() }
  }

  private var header: some View {
    HStack(alignment: .center) {
      Text(store.t("Profile")).font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 12)
      RoundGlassButton(symbol: "gearshape", label: store.t("Settings")) { settings = true }
        .accessibilityIdentifier("profile.settings")
    }.padding(.top, 8)
  }

  // MARK: The number

  private struct Recent { let count: Int; let average: Int }
  /// The last seven workouts: how many, and their average length.
  private var recent: Recent? {
    let last = sessions.prefix(7).map(workoutMinutes)
    guard !last.isEmpty else { return nil }
    return Recent(count: last.count, average: Int((Double(last.reduce(0, +)) / Double(last.count)).rounded()))
  }
  /// How long a workout takes, in plain words: "Average workout", the length large with its units
  /// spelled out small ("35 min", "1 hr 12 min"), then what it's the average of.
  private func summary(_ r: Recent) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(store.t(r.count == 1 ? "Last workout" : "Average workout"))
        .font(.app(.subheadline, weight: .medium)).foregroundStyle(JourneyColor.secondary)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        ForEach(Array(durationParts(r.average).enumerated()), id: \.offset) { index, part in
          Text("\(part.value)").font(.app(size: 40, weight: .semibold)).tracking(-1).monospacedDigit()
            .foregroundStyle(JourneyColor.text).padding(.leading, index > 0 ? 8 : 0)
          Text(store.t(part.unit)).font(.app(size: 20, weight: .medium)).foregroundStyle(JourneyColor.secondary)
        }
      }.accessibilityIdentifier("profile.average")
      if r.count > 1 {
        Text(store.t("Over your last") + " \(r.count) " + store.t("workouts")).font(.app(.subheadline)).foregroundStyle(JourneyColor.tertiary)
      }
    }.accessibilityElement(children: .combine)
  }

  // MARK: The log

  private var recentList: some View {
    VStack(alignment: .leading, spacing: 12) {
      PageLabel(text: store.t("Recent workouts"))
      ForEach(sessions.prefix(5)) { session in
        NavigationLink { WorkoutEntryView(sessionID: session.id) } label: { WorkoutEntryCard(session: session) }
          .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("history." + session.id.uuidString)
      }
      if sessions.count > 5 {
        NavigationLink { AllWorkoutsView() } label: {
          HStack {
            Text(store.t("All") + " \(sessions.count) " + store.t("workouts")).font(.app(.subheadline, weight: .medium))
              .foregroundStyle(JourneyColor.secondary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
          }.padding(.horizontal, 20).padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(.hapticPlain).accessibilityIdentifier("profile.allWorkouts")
      }
    }
  }

  private var empty: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "calendar").font(.system(size: 17, weight: .medium)).foregroundStyle(JourneyColor.signal)
        .frame(width: 40, height: 40).background(Circle().fill(JourneyColor.signal.opacity(0.12))).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(store.t("No workouts yet")).font(.app(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
        Text(store.t("Your first workout lands here.")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary)
      }.padding(.top, 2)
    }
  }
}

/// Minutes from Start workout to End.
func workoutMinutes(_ session: Session) -> Int { max(1, Int((session.duration / 60).rounded())) }
/// A length as numbers with their units: 35 min, 1 hr 12 min, 2 hr.
func durationParts(_ minutes: Int) -> [(value: Int, unit: String)] {
  guard minutes >= 60 else { return [(minutes, "min")] }
  return minutes % 60 == 0 ? [(minutes / 60, "hr")] : [(minutes / 60, "hr"), (minutes % 60, "min")]
}

/// The apps GymBlock blocks, on glass: their real icons with "Blocked while you train", or what's
/// missing ("Choose apps to block", "App blocking is off", Screen Time access). It opens Blocked apps.
private struct BlockedAppsCard: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  var body: some View {
    HStack(spacing: 14) {
      content
      Spacer(minLength: 8)
      Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
    }
    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
  }
  @ViewBuilder private var content: some View {
    if !StoreShots.apps.isEmpty {
      // Development only (`-storeShots YES`): the six sample apps, as on the blocking page.
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 7.5) {
          ForEach(StoreShots.apps, id: \.self) { app in
            Image(app.asset).resizable().scaledToFill().frame(width: 30, height: 30)
              .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
          }
        }
        Text(store.t("Blocked while you train")).font(.app(.body)).foregroundStyle(JourneyColor.secondary)
      }.frame(maxWidth: .infinity, alignment: .leading)
    } else {
      switch blocking.state(store.profile) {
      case .off: row(icon: "lock.open", tint: JourneyColor.secondary, title: store.t("App blocking is off"))
      case .noAccess:
        row(icon: "lock.open", tint: JourneyColor.secondary, title: store.t("Apps won’t be blocked"),
            detail: store.t("Screen Time access is off"))
      case .noApps: row(icon: "lock.fill", tint: JourneyColor.signal, title: store.t("Choose apps to block"))
      case .on:
        VStack(alignment: .leading, spacing: 12) {
          BlockedIcons(size: 30, limit: 6).foregroundStyle(JourneyColor.secondary)
          Text(store.t("Blocked while you train")).font(.app(.body)).foregroundStyle(JourneyColor.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
  private func row(icon: String, tint: Color, title: String, detail: String? = nil) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
        .frame(width: 36, height: 36).background(Circle().fill(tint.opacity(0.12))).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.app(.body, weight: .medium)).foregroundStyle(JourneyColor.text)
        if let detail { Text(detail).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary) }
      }
    }
  }
}

/// This month as a calendar of dots, Monday first: Home's week-line dots, emerald for a day trained,
/// a ring on today, a faint dot for a day without, fainter still for the days to come (so the rest of
/// the month never reads as missed). How often, at a glance; no minutes, no scale.
private struct MonthDots: View {
  @EnvironmentObject private var store: GymStore
  let sessions: [Session]
  private let dot: CGFloat = 12
  var body: some View {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    let today = calendar.startOfDay(for: Date())
    let first = calendar.dateInterval(of: .month, for: today)?.start ?? today
    let length = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
    let lead = (calendar.component(.weekday, from: first) + 5) % 7
    let monday = calendar.date(byAdding: .day, value: -lead, to: first) ?? first
    let rows = (lead + length + 6) / 7
    let trained = Set(sessions.map { calendar.startOfDay(for: $0.started) })
    let colors = store.dayColors
    let count = sessions.filter { calendar.isDate($0.started, equalTo: today, toGranularity: .month) }.count
    let tally = "\(count) " + store.t(count == 1 ? "workout" : "workouts")
    return VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        PageLabel(text: today.formatted(.dateTime.month(.wide)))
        Text(tally).font(.app(.caption, weight: .medium)).monospacedDigit().foregroundStyle(JourneyColor.tertiary).fixedSize()
      }
      HStack(spacing: 0) {
        ForEach(0..<7, id: \.self) { column in
          Text((calendar.date(byAdding: .day, value: column, to: monday) ?? monday).formatted(.dateTime.weekday(.narrow)))
            .font(.app(size: 11, weight: .medium)).foregroundStyle(JourneyColor.tertiary).frame(maxWidth: .infinity)
        }
      }
      VStack(spacing: 0) {
        ForEach(0..<rows, id: \.self) { row in
          HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { column in
              let index = row * 7 + column - lead
              let day = calendar.date(byAdding: .day, value: index, to: first) ?? first
              Group {
                if index >= 0 && index < length {
                  let on = trained.contains(day)
                  Circle().fill(on ? Color.paper((colors[TrainingDays.key(day)] ?? .emerald).paper) : day == today ? Color.clear : JourneyColor.ink(day > today ? 0.05 : 0.12))
                    .overlay(Circle().strokeBorder(JourneyColor.text, lineWidth: day == today && !on ? 1.5 : 0))
                } else {
                  Color.clear
                }
              }.frame(width: dot, height: dot).frame(maxWidth: .infinity).frame(height: 34)
            }
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(today.formatted(.dateTime.month(.wide)) + ", " + tally)
    .accessibilityIdentifier("profile.calendar")
  }
}

/// One workout as its own card, after JournalBlock's entries: the day, large and light, over its
/// month; the split, with its time and exercise count as one quiet line, the same voice as the entry page.
private struct WorkoutEntryCard: View {
  @EnvironmentObject private var store: GymStore
  let session: Session
  /// Selecting: whether this one is chosen. Nil shows the chevron.
  var selected: Bool? = nil
  private var detail: String {
    var seen = Set<String>()
    let count = session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }.count
    let exercises = count == 1 ? store.t("1 exercise") : "\(count) " + store.t("exercises")
    return "\(max(1, Int(session.duration / 60))) " + store.t("min") + "  ·  " + exercises
  }
  var body: some View {
    HStack(alignment: .center, spacing: 18) {
      VStack(spacing: 0) {
        Text(session.started.formatted(.dateTime.day())).font(.app(.title, weight: .light)).monospacedDigit()
          .foregroundStyle(JourneyColor.text)
        Text(session.started.formatted(.dateTime.month(.abbreviated))).font(.app(.caption2, weight: .medium)).tracking(0.8)
          .textCase(.uppercase).foregroundStyle(JourneyColor.tertiary)
      }.frame(minWidth: 44)
      VStack(alignment: .leading, spacing: 3) {
        Text(store.t(session.name)).font(.app(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text).lineLimit(1)
        Text(detail).font(.app(.subheadline)).monospacedDigit().foregroundStyle(JourneyColor.tertiary).lineLimit(1)
      }.frame(maxWidth: .infinity, alignment: .leading)
      if let selected {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
          .symbolRenderingMode(.palette)
          .foregroundStyle(selected ? JourneyColor.onAccent : JourneyColor.ink(0.25), selected ? JourneyColor.signal : JourneyColor.ink(0.25))
          .accessibilityHidden(true)
      } else {
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
          .accessibilityHidden(true)
      }
    }
    .padding(.horizontal, 20).padding(.vertical, 16)
    .journeySurface(cornerRadius: 20)
    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
    .accessibilityAddTraits(selected == true ? .isSelected : [])
  }
}

/// Every workout, newest first, as the same cards. Select (15 Oct 2026) turns each card into a
/// checkbox and puts Delete where the tab bar was, for clearing several at once.
private struct AllWorkoutsView: View {
  @EnvironmentObject private var store: GymStore
  @State private var selecting = false
  @State private var chosen: Set<UUID> = []
  @State private var confirming = false
  private var sessions: [Session] { store.data.history.sorted { $0.started > $1.started } }
  var body: some View {
    ZStack {
      DotGrid()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          Text(store.t("All workouts")).font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
            .accessibilityAddTraits(.isHeader).padding(.bottom, 8)
          ForEach(sessions) { session in
            if selecting {
              Button { toggle(session.id) } label: { WorkoutEntryCard(session: session, selected: chosen.contains(session.id)) }
                .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("history." + session.id.uuidString)
            } else {
              NavigationLink { WorkoutEntryView(sessionID: session.id) } label: { WorkoutEntryCard(session: session) }
                .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("history." + session.id.uuidString)
            }
          }
        }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 32)
      }.scrollIndicators(.hidden)
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(store.t(selecting ? "Done" : "Select")) { JourneyHaptic.pressLight()
          withAnimation(JourneyMotion.gentle) { selecting.toggle(); chosen = [] }
        }.accessibilityIdentifier("history.select")
      }
      if selecting {
        ToolbarItem(placement: .topBarLeading) {
          Button(store.t(chosen.count == sessions.count ? "Deselect all" : "Select all")) { JourneyHaptic.pressLight()
            chosen = chosen.count == sessions.count ? [] : Set(sessions.map(\.id))
          }.accessibilityIdentifier("history.selectAll")
        }
      }
    }
    .navigationBarBackButtonHidden(selecting)
    .toolbar(selecting ? .hidden : .visible, for: .tabBar)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if selecting {
        JourneyButton(title: deleteTitle, symbol: nil, id: "history.delete", enabled: !chosen.isEmpty) { confirming = true }
          .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
          .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .alert(store.t(chosen.count == 1 ? "Delete this workout?" : "Delete these workouts?"), isPresented: $confirming) {
      Button(store.t("Delete"), role: .destructive) { JourneyHaptic.pressLight()
        store.deleteWorkouts(chosen)
        JourneyHaptic.play(.success, store.profile)
        withAnimation(JourneyMotion.gentle) { chosen = []; selecting = false }
      }
      Button(store.t("Cancel"), role: .cancel) { JourneyHaptic.pressLight() }
    } message: {
      Text(store.t("Their sets go too. This can't be undone."))
    }
    .track(screen: "profile.all")
  }
  private var deleteTitle: String {
    chosen.isEmpty ? store.t("Delete") : chosen.count == 1 ? store.t("Delete 1 workout") : String(format: store.t("Delete %@ workouts"), "\(chosen.count)")
  }
  private func toggle(_ id: UUID) {
    if chosen.remove(id) == nil { chosen.insert(id) }
    JourneyHaptic.play(.selection, store.profile)
  }
}

/// One workout, read back, after JournalBlock's entry page: typeset like a page rather than a
/// table. The split above the date, the time, sets and load as tags, then each exercise as a
/// section of lines, one per set; a set opens the editor. Delete sits in the ••• menu.
struct WorkoutEntryView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let sessionID: UUID
  @State private var editing: LoggedSet?
  @State private var deleting = false
  private var session: Session? { store.data.history.first { $0.id == sessionID } }
  private var exercises: [Exercise] {
    var seen = Set<String>()
    return (session?.sets ?? []).map(\.exercise).filter { seen.insert($0.id).inserted }
  }
  var body: some View {
    ZStack {
      DotGrid()
      if let session {
        ScrollView {
          VStack(alignment: .leading, spacing: 32) {
            header(session)
            ForEach(exercises) { exercise in section(exercise, sets: session.sets.filter { $0.exercise.id == exercise.id }) }
            if store.deletedSet != nil {
              Button(store.t("Undo")) { JourneyHaptic.pressLight(); store.undoDelete() }.font(.app(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
            }
          }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 40)
        }.scrollIndicators(.hidden)
      }
    }
    .navigationTitle(session.map { started in
      Calendar.current.isDate(started.started, equalTo: .now, toGranularity: .year)
        ? started.started.formatted(.dateTime.month(.abbreviated).day())
        : started.started.formatted(.dateTime.month(.abbreviated).day().year())
    } ?? "")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button(store.t("Delete workout"), systemImage: "trash", role: .destructive) { JourneyHaptic.pressLight(); deleting = true }
            .accessibilityIdentifier("workout.delete")
        } label: {
          // Bare glyph: iOS draws the round glass button behind a toolbar item.
          Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(JourneyColor.text)
        }.accessibilityLabel(store.t("Workout options")).accessibilityIdentifier("workout.options")
      }
    }
    // An alert, not a dialog: raised from a toolbar menu, a dialog anchors to the bar and covers the title.
    .alert(store.t("Delete this workout?"), isPresented: $deleting) {
      Button(store.t("Delete workout"), role: .destructive) { JourneyHaptic.pressLight(); store.deleteWorkout(sessionID); dismiss() }
        .accessibilityIdentifier("workout.delete.confirm")
      Button(store.t("Cancel"), role: .cancel) { JourneyHaptic.pressLight() }
    } message: { Text(store.t("Its sets leave History and progress. This can’t be undone.")) }
    .navigationDestination(isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
      if let editing { SetEditor(set: editing, sessionID: sessionID, embedded: true) }
    }
    .track(screen: "profile.workout")
  }

  /// The split, with its figures as one quiet line under it. The date is the bar's title.
  private func header(_ session: Session) -> some View {
    var figures = ["\(max(1, Int(session.duration / 60))) " + store.t("min"), setCount(session.completedSets.count, store: store)]
    if session.volumeKG > 0 {
      figures.append(formatNumber(GymStore.displayedWeight(session.volumeKG, unit: store.profile.unit).rounded()) + " " + store.profile.unit)
    }
    return VStack(alignment: .leading, spacing: 4) {
      Text(store.t(session.name)).font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
        .lineLimit(2).accessibilityAddTraits(.isHeader)
      Text(figures.joined(separator: "  ·  ")).font(.app(.subheadline)).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
    }
  }

  /// The exercise as a small label, then one line per set: its number quiet, the set in large type.
  private func section(_ exercise: Exercise, sets: [LoggedSet]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline) {
        Text(store.t(exercise.name)).font(.app(.caption, weight: .semibold)).tracking(1.4).textCase(.uppercase)
          .foregroundStyle(JourneyColor.secondary).accessibilityAddTraits(.isHeader)
        Spacer(minLength: 8)
        if let time = store.exerciseTime(sets) {
          HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 11, weight: .medium)).accessibilityHidden(true)
            Text(time).monospacedDigit()
          }.font(.app(.footnote, weight: .medium)).foregroundStyle(JourneyColor.tertiary)
            .accessibilityLabel(store.t("Time") + ", " + time)
        }
      }.padding(.bottom, 6)
      ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
        Button { editing = set } label: {
          HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(index + 1)").font(.app(.subheadline, weight: .medium)).monospacedDigit()
              .foregroundStyle(JourneyColor.tertiary).frame(width: 20, alignment: .leading)
            Text(setValue(set, store: store)).font(.app(.title3)).monospacedDigit()
              .foregroundStyle(set.unsuccessful == true ? JourneyColor.secondary : JourneyColor.text)
            Spacer(minLength: 0)
          }.frame(minHeight: 40).contentShape(Rectangle())
        }.buttonStyle(.hapticPlain)
          .accessibilityLabel(store.t("Set") + " \(index + 1), " + setValue(set, store: store))
          .accessibilityIdentifier("saved." + set.id.uuidString)
      }
    }
  }
}

/// A round Liquid Glass icon button (translucent before iOS 26), the same as Settings' close button.
struct RoundGlassButton: View {
  let symbol: String
  let label: String
  let action: () -> Void
  var body: some View {
    let action = { JourneyHaptic.pressLight(); self.action() }
    let icon = Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(JourneyColor.text)
    Group {
      if #available(iOS 26.0, *) {
        // The glass style adds its own padding, so the icon's frame is smaller to land on 44 pt.
        Button(action: action) { icon.frame(width: 28, height: 28) }.buttonStyle(.glass).buttonBorderShape(.circle)
      } else {
        Button(action: action) { icon.frame(width: 44, height: 44).background(Circle().fill(JourneyColor.fill)) }.buttonStyle(JourneyPressStyle())
      }
    }.accessibilityLabel(label)
  }
}

extension GymStore {
  /// Time on an exercise: its sets plus the rests between them. Nothing when any of that timing is
  /// unknown, so a forgotten Start or Finish never shows as a number.
  func exerciseTime(_ sets: [LoggedSet]) -> String? {
    guard !sets.isEmpty else { return nil }
    var seconds = 0.0
    for (index, set) in sets.enumerated() {
      guard set.timingUnknown != true, let elapsed = set.elapsedSetSeconds, elapsed > 0 else { return nil }
      seconds += elapsed
      // Only a rest that followed this exercise's own previous set belongs to it.
      if index > 0, set.gapSourceID == sets[index - 1].id {
        guard set.gapUnknown != true, let gap = set.gapBeforeSeconds, gap >= 0, gap < 30 * 60 else { return nil }
        seconds += gap
      }
    }
    let minutes = Int((seconds / 60).rounded())
    return minutes < 1 ? "<1 " + t("min") : "\(minutes) " + t("min")
  }
}
