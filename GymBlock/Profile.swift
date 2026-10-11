import FamilyControls
import SwiftUI

/// Profile, after SleepBlock's (11 Oct 2026): the title and Settings; one honest number (the average
/// workout over the last seven, with how many and the total); the apps GymBlock blocks, on a glass
/// card that opens the picker; your training as a calendar of dots (a column per week); then the
/// recent workouts as ruled rows, each opening its page. A new account sees no numbers, never examples.
struct ProfileTab: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  @State private var settings = false
  @State private var picking = false
  @State private var pickDraft = FamilyActivitySelection()
  private var sessions: [Session] { store.data.history.sorted { $0.started > $1.started } }
  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid()
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            header
            if let recent { summary(recent).padding(.top, 26) }
            BlockedAppsCard(action: chooseApps).padding(.top, 26)
            if sessions.isEmpty {
              empty.padding(.top, 40)
            } else {
              TrainingCalendar(sessions: sessions).padding(.top, 40)
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
      .familyActivityPicker(headerText: store.t("Choose what to block from Start workout to Finish."), isPresented: $picking, selection: $pickDraft)
      .onChange(of: pickDraft) { _, chosen in blocking.choose(chosen) }
    }
    .sheet(isPresented: $settings) { PreferencesView() }
  }

  private var header: some View {
    HStack(alignment: .center) {
      Text(store.t("Profile")).font(.system(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 12)
      RoundGlassButton(symbol: "gearshape", label: store.t("Settings")) { settings = true }
        .accessibilityIdentifier("profile.settings")
    }.padding(.top, 8)
  }

  // MARK: The number

  private struct Recent { let count: Int; let average: Int; let total: Int }
  /// The last seven workouts: their average length, how many, and the total.
  private var recent: Recent? {
    let last = sessions.prefix(7).map(workoutMinutes)
    guard !last.isEmpty else { return nil }
    let total = last.reduce(0, +)
    return Recent(count: last.count, average: Int((Double(total) / Double(last.count)).rounded()), total: total)
  }
  private func summary(_ r: Recent) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(r.count == 1 ? store.t("Last workout") : store.t("Avg workout") + " · " + store.t("last") + " \(r.count) " + store.t("workouts"))
        .font(.system(.subheadline, weight: .medium)).foregroundStyle(JourneyColor.secondary)
      Text(durationText(r.average)).font(.system(size: 40, weight: .semibold)).tracking(-1).monospacedDigit()
        .foregroundStyle(JourneyColor.text).accessibilityIdentifier("profile.average")
      Text("\(r.count) " + store.t(r.count == 1 ? "workout" : "workouts") + "  ·  " + durationText(r.total) + " " + store.t("total"))
        .font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
    }.accessibilityElement(children: .combine)
  }

  // MARK: The log

  private var recentList: some View {
    VStack(alignment: .leading, spacing: 0) {
      PageLabel(text: store.t("Recent workouts")).padding(.bottom, 4)
      ForEach(Array(sessions.prefix(7).enumerated()), id: \.element.id) { index, session in
        NavigationLink { WorkoutEntryView(sessionID: session.id) } label: { WorkoutRow(session: session) }
          .buttonStyle(.plain)
          .overlay(alignment: .top) { if index > 0 { SettingsDivider() } }
          .accessibilityIdentifier("history." + session.id.uuidString)
      }
      if sessions.count > 7 {
        NavigationLink { AllWorkoutsView() } label: {
          HStack {
            Text(store.t("All") + " \(sessions.count) " + store.t("workouts")).font(.system(.subheadline, weight: .medium))
              .foregroundStyle(JourneyColor.secondary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
          }.padding(.vertical, 16).contentShape(Rectangle())
        }.buttonStyle(.plain).overlay(alignment: .top) { SettingsDivider() }
          .accessibilityIdentifier("profile.allWorkouts")
      }
    }
  }

  private var empty: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: "calendar").font(.system(size: 17, weight: .medium)).foregroundStyle(JourneyColor.signal)
        .frame(width: 40, height: 40).background(Circle().fill(JourneyColor.signal.opacity(0.12))).accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 3) {
        Text(store.t("No workouts yet")).font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
        Text(store.t("Your first workout lands here.")).font(.subheadline).foregroundStyle(JourneyColor.secondary)
      }.padding(.top, 2)
    }
  }

  /// The card opens the system picker (asking for Screen Time first, and turning blocking on); if
  /// access is refused, Settings opens, where the blocking note says how to allow it.
  private func chooseApps() {
    Task { @MainActor in
      guard await blocking.requestAccess() else { settings = true; return }
      if store.profile.focusEnabled != true { store.updateProfile { $0.focusEnabled = true } }
      pickDraft = blocking.selection
      picking = true
    }
  }
}

/// Minutes from Start workout to End.
func workoutMinutes(_ session: Session) -> Int { max(1, Int((session.duration / 60).rounded())) }
/// "38m", "1h 12m", "2h".
func durationText(_ minutes: Int) -> String {
  guard minutes >= 60 else { return "\(minutes)m" }
  return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
}

/// The apps GymBlock blocks, on glass: their real icons with "Blocked while you train", or what's
/// missing ("Choose apps to block", "App blocking is off"). Tapping it opens the picker.
private struct BlockedAppsCard: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        content
        Spacer(minLength: 8)
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
      }
      .padding(18).frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("profile.blocking")
  }
  @ViewBuilder private var content: some View {
    if store.profile.focusEnabled != true {
      row(icon: "lock.open", tint: JourneyColor.secondary, title: store.t("App blocking is off"))
    } else if blocking.isEmpty {
      row(icon: "lock.fill", tint: JourneyColor.signal, title: store.t("Choose apps to block"))
    } else {
      VStack(alignment: .leading, spacing: 12) {
        BlockedIcons(size: 30, limit: 6).foregroundStyle(JourneyColor.secondary)
        Text(store.t("Blocked while you train")).font(.body).foregroundStyle(JourneyColor.secondary)
      }
    }
  }
  private func row(icon: String, tint: Color, title: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint)
        .frame(width: 36, height: 36).background(Circle().fill(tint.opacity(0.12))).accessibilityHidden(true)
      Text(title).font(.system(.body, weight: .medium)).foregroundStyle(JourneyColor.text)
    }
  }
}

/// Training as a calendar of dots: a column per week (Monday on top), the newest week on the right,
/// the last 16 weeks. Emerald for a day trained, a faint dot for a day without, a ring on today; no
/// dot before your first workout or after today, so nothing reads as missed that couldn't have been.
/// Months are named above their first column. It echoes the paper's own dots, and each column is a
/// week the streak counts.
private struct TrainingCalendar: View {
  @EnvironmentObject private var store: GymStore
  let sessions: [Session]
  private let weeks = 16
  private let dot: CGFloat = 11
  var body: some View {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    let today = calendar.startOfDay(for: Date())
    let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    let starts = (0..<weeks).map { calendar.date(byAdding: .weekOfYear, value: $0 - (weeks - 1), to: thisWeek) ?? thisWeek }
    let trained = Set(sessions.map { calendar.startOfDay(for: $0.started) })
    let first = trained.min() ?? today
    let shown = sessions.filter { $0.started >= (starts.first ?? thisWeek) }.count
    return VStack(alignment: .leading, spacing: 10) {
      // Month names over the column where each month starts.
      HStack(spacing: 0) {
        Color.clear.frame(width: 18)
        ForEach(0..<weeks, id: \.self) { column in
          let start = starts[column]
          let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
          let opens = column == 0 || days.contains { calendar.component(.day, from: $0) == 1 }
          Text(opens ? (days.first { calendar.component(.day, from: $0) == 1 } ?? start).formatted(.dateTime.month(.abbreviated)) : "")
            .font(.system(size: 10, weight: .medium)).foregroundStyle(JourneyColor.tertiary)
            .lineLimit(1).fixedSize().frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      HStack(alignment: .top, spacing: 0) {
        // M · W · F down the side.
        VStack(spacing: 0) {
          ForEach(0..<7, id: \.self) { row in
            Text(row % 2 == 0 && row < 6 ? ["M", "T", "W", "T", "F", "S", "S"][row] : "")
              .font(.system(size: 9, weight: .medium)).foregroundStyle(JourneyColor.tertiary)
              .frame(width: 18, height: dot + 9, alignment: .leading)
          }
        }
        ForEach(0..<weeks, id: \.self) { column in
          VStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { row in
              let day = calendar.date(byAdding: .day, value: row, to: starts[column]) ?? today
              cell(day: day, trained: trained.contains(day), today: day == today, empty: day < first || day > today)
                .frame(height: dot + 9)
            }
          }.frame(maxWidth: .infinity)
        }
      }
      Text("\(shown) " + store.t(shown == 1 ? "workout" : "workouts") + "  ·  " + store.t("last") + " \(weeks) " + store.t("weeks"))
        .font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.tertiary).padding(.top, 4)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(store.t("Training calendar") + ", \(shown) " + store.t("workouts") + ", " + store.t("last") + " \(weeks) " + store.t("weeks"))
    .accessibilityIdentifier("profile.calendar")
  }
  @ViewBuilder private func cell(day: Date, trained: Bool, today: Bool, empty: Bool) -> some View {
    if trained {
      Circle().fill(JourneyColor.signal).frame(width: dot, height: dot)
    } else if today {
      Circle().strokeBorder(JourneyColor.text, lineWidth: 1.5).frame(width: dot, height: dot)
    } else if empty {
      Color.clear.frame(width: dot, height: dot)
    } else {
      Circle().fill(JourneyColor.ink(0.12)).frame(width: dot, height: dot)
    }
  }
}

/// A workout as a ruled row: the day, then the split and when it ran; its length on the right.
private struct WorkoutRow: View {
  @EnvironmentObject private var store: GymStore
  let session: Session
  var body: some View {
    let end = session.ended ?? session.started.addingTimeInterval(session.duration)
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 5) {
        Text(session.started.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
          .font(.system(.body, weight: .medium)).foregroundStyle(JourneyColor.text)
        Text(store.t(session.name) + " · " + session.started.formatted(date: .omitted, time: .shortened) + " → " + end.formatted(date: .omitted, time: .shortened))
          .font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(1)
      }
      Spacer(minLength: 8)
      Text(durationText(workoutMinutes(session))).font(.system(.title3, weight: .semibold)).monospacedDigit()
        .foregroundStyle(JourneyColor.text)
    }.padding(.vertical, 14).contentShape(Rectangle()).accessibilityElement(children: .combine)
  }
}

/// Every workout, newest first, as the same ruled rows.
private struct AllWorkoutsView: View {
  @EnvironmentObject private var store: GymStore
  var body: some View {
    SettingsSubpage(title: store.t("All workouts")) {
      ForEach(store.data.history.sorted { $0.started > $1.started }) { session in
        NavigationLink { WorkoutEntryView(sessionID: session.id) } label: { WorkoutRow(session: session) }.pageRow()
      }
    }.track(screen: "profile.all")
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
              Button(store.t("Undo")) { store.undoDelete() }.font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
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
          Button(store.t("Delete workout"), systemImage: "trash", role: .destructive) { deleting = true }
            .accessibilityIdentifier("workout.delete")
        } label: {
          // Bare glyph: iOS draws the round glass button behind a toolbar item.
          Image(systemName: "ellipsis").font(.system(size: 16, weight: .semibold)).foregroundStyle(JourneyColor.text)
        }.accessibilityLabel(store.t("Workout options")).accessibilityIdentifier("workout.options")
      }
    }
    // An alert, not a dialog: raised from a toolbar menu, a dialog anchors to the bar and covers the title.
    .alert(store.t("Delete this workout?"), isPresented: $deleting) {
      Button(store.t("Delete workout"), role: .destructive) { store.deleteWorkout(sessionID); dismiss() }
        .accessibilityIdentifier("workout.delete.confirm")
      Button(store.t("Cancel"), role: .cancel) {}
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
      Text(store.t(session.name)).font(.system(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
        .lineLimit(2).accessibilityAddTraits(.isHeader)
      Text(figures.joined(separator: "  ·  ")).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
    }
  }

  /// The exercise as a small label, then one line per set: its number quiet, the set in large type.
  private func section(_ exercise: Exercise, sets: [LoggedSet]) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline) {
        Text(store.t(exercise.name)).font(.system(.caption, weight: .semibold)).tracking(1.4).textCase(.uppercase)
          .foregroundStyle(JourneyColor.secondary).accessibilityAddTraits(.isHeader)
        Spacer(minLength: 8)
        if let time = store.exerciseTime(sets) {
          HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 11, weight: .medium)).accessibilityHidden(true)
            Text(time).monospacedDigit()
          }.font(.system(.footnote, weight: .medium)).foregroundStyle(JourneyColor.tertiary)
            .accessibilityLabel(store.t("Time") + ", " + time)
        }
      }.padding(.bottom, 6)
      ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
        Button { editing = set } label: {
          HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text("\(index + 1)").font(.system(.subheadline, weight: .medium)).monospacedDigit()
              .foregroundStyle(JourneyColor.tertiary).frame(width: 20, alignment: .leading)
            Text(setValue(set, store: store)).font(.system(.title3)).monospacedDigit()
              .foregroundStyle(set.unsuccessful == true ? JourneyColor.secondary : JourneyColor.text)
            Spacer(minLength: 0)
          }.frame(minHeight: 40).contentShape(Rectangle())
        }.buttonStyle(.plain)
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
