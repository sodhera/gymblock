import SwiftUI

/// Home: what's up next, and one button. The week as a quiet line at the top; the split the rotation
/// has queued as the headline with one line of what's ahead; "Up next" opens the chooser to pick
/// another. Start workout slides the page up to the plan (13 Oct 2026, at the user's request, in
/// place of a line about blocking over the button): the exercises and the apps that lock, and the
/// same button, now Let’s go, begins it. The button and the 20-pt rest under it never move.
/// (Chosen 11 Oct 2026 over a streak-first and a launcher layout.)
struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  @ObservedObject private var router = AppRouter.shared
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var choosing = false
  @State private var appeared = false
  /// Free workout picked in the chooser; it lasts until the workout starts.
  @State private var free = false
  /// Nothing logged yet: Home shows the truth (an empty week) and guides to the first workout.
  private var firstRun: Bool { store.data.history.allSatisfy { $0.completedSets.isEmpty } }
  @State private var creatingSplit = false
  /// The plan is up (past halfway): the button reads Let’s go and starts it; the tabs step aside.
  @State private var planning = false
  /// Home and the plan are one scroll: where it is, read by the floating name alone, so a scroll
  /// doesn't redraw Home.
  @State private var scroll = PageScroll()
  /// Where the name sits on each page, in the pages' own coordinates.
  @State private var slots: [String: CGRect] = [:]
  /// The bottom inset with the tab bar showing, kept while it steps aside so nothing moves.
  @State private var bottomInset: CGFloat?
  @State private var scrollRequest: String?
  /// Only Start workout opens the plan: Home doesn't scroll until it has, and locks again once the
  /// plan is pulled back down to it.
  @State private var planOpen = false
  private var heroTitle: String {
    nextSplit == nil && firstRun ? store.t("Your first workout") : nextSplit.map { store.t($0.name) } ?? store.t("Free workout")
  }
  /// The split the rotation has queued, else the first split; none means a free workout.
  private var nextSplit: Workout? {
    free ? nil : store.data.workouts.first { $0.id == store.profile.preferredSplitID } ?? store.data.workouts.first
  }
  var body: some View {
    NavigationStack {
      GeometryReader { screen in
        ZStack {
          DotGrid(strength: 1.25)
          VStack(spacing: 0) {
            pages
            VStack(spacing: 10) {
              if store.data.demoLoaded == true && !StoreShots.on {
                Text(store.t("Sample data")).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary)
                  .accessibilityIdentifier("home.sample")
              }
              JourneyButton(title: store.t(planning ? "Let’s go" : "Start workout"), id: planning ? "plan.start" : "home.start") {
                if planning {
                  JourneyHaptic.play(.medium, store.profile, intensity: 0.8)
                  start()
                } else {
                  openPlan()
                }
              }
              Color.clear.frame(height: 20)
                // What Let’s go does, under it, in the room the tab bar leaves (13 Oct 2026).
                .overlay(alignment: .top) {
                  BlockingLine().padding(.top, 14)
                    .opacity(planning ? 1 : 0).animation(.easeOut(duration: 0.25), value: planning)
                    .allowsHitTesting(planning).accessibilityHidden(!planning)
                }
            }.padding(.top, 8).padding(.horizontal, 24)
          }
          // The bottom is laid out as if the tab bar were always there, so when it steps aside for the
          // plan, the button and the pages don't move.
          .padding(.bottom, (bottomInset ?? screen.safeAreaInsets.bottom) + 4)
          .ignoresSafeArea(.container, edges: .bottom)
        }
        .onChange(of: screen.safeAreaInsets.bottom, initial: true) { _, inset in if !planning { bottomInset = inset } }
      }
      .toolbar(.hidden, for: .navigationBar)
      // The plan is a step into the workout, so the tabs step aside.
      .toolbar(planning ? .hidden : .visible, for: .tabBar)
      .track(screen: "home", ["first": firstRun])
      .sheet(isPresented: $creatingSplit) {
        NavigationStack {
          SplitEditorContent(workout: Workout(name: "", exercises: [])) { split in
            store.updateProfile { $0.preferredSplitID = split.id }
            free = false
            creatingSplit = false
          }
        }.tint(JourneyColor.text)
      }
      .sheet(isPresented: $choosing) {
        WorkoutChoiceView(current: nextSplit?.id) { split in
          free = split == nil
          if let split { store.updateProfile { $0.preferredSplitID = split.id } }
        }
      }
      .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.12)) { appeared = true } }
      .onChange(of: planning) { _, now in
        JourneyHaptic.play(.selection, store.profile)
        if !now { Analytics.tap("home.plan.back") }
      }
      // The control's Start workout opens the plan, as the button does, and only while the press is
      // fresh; the workout itself still starts only from Let’s go.
      .onChange(of: router.ready, initial: true) { _, r in
        guard let r, r.route == .start else { return }
        router.consume(r)
        if r.fresh && store.session == nil { openPlan() }
      }
    }
  }

  /// Home and the plan as one page that scrolls once Start workout has opened the plan (never by a swipe
  /// on Home): a pull moves it under the finger and it settles on one or the other (`PlanSnap`); a long
  /// plan scrolls on past. The name floats above both.
  private var pages: some View {
    GeometryReader { box in
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 0) {
            home.frame(height: box.size.height).id("home")
              .accessibilityHidden(planning)
            StartPlan(split: nextSplit, title: heroTitle) { scrollRequest = "home" }
              .frame(minHeight: box.size.height, alignment: .top).id("plan")
              .accessibilityHidden(!planning)
          }
          .padding(.horizontal, 24)
          .coordinateSpace(name: "pageContent")
          .background {
            GeometryReader { content in
              Color.clear.preference(key: PageOffset.self, value: -content.frame(in: .named("pageScroll")).minY)
            }
          }
        }
        .coordinateSpace(name: "pageScroll")
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(PlanSnap(page: box.size.height))
        .scrollDisabled(!planOpen)
        .modifier(ScrollOffset { y in
          scroll.offset = y
          let past = y > box.size.height * 0.5
          if past != planning { planning = past }
          // Back on Home after the plan was up: Home stops scrolling again.
          if past { scroll.reachedPlan = true } else if scroll.reachedPlan && y < 1 {
            scroll.reachedPlan = false
            planOpen = false
          }
        })
        .onPreferenceChange(HeroSlots.self) { slots = $0 }
        .onChange(of: box.size.height, initial: true) { _, h in scroll.page = h }
        .onChange(of: scrollRequest) { _, id in
          guard let id else { return }
          withAnimation(.spring(duration: 0.55, bounce: 0.06)) { proxy.scrollTo(id, anchor: .top) }
          scrollRequest = nil
        }
        // The one visible name: it rides between its two places as the page scrolls.
        .overlay(alignment: .topLeading) {
          FloatingName(text: heroTitle, scroll: scroll, home: slots["home"], plan: slots["plan"])
            .opacity(appeared ? 1 : 0).animation(.spring(duration: 0.55, bounce: 0.12).delay(0.12), value: appeared)
        }
      }
    }
  }

  /// Home's own page; at the largest text sizes it scrolls.
  @ViewBuilder private var home: some View {
    if typeSize.isAccessibilitySize {
      ScrollView { content.padding(.bottom, 24) }.scrollIndicators(.hidden)
    } else {
      content
    }
  }

  /// The week, then progress in the middle of the page (an honest empty chart before there is a
  /// line), then the queued workout low on the page, just above the button.
  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      // The week and its streak on top (12 Oct 2026, decluttered: no greeting or carousel), then one
      // exercise's progress, or the empty chart that says how it fills in.
      WeekLine(stats: store.homeStats()).padding(.top, 24).reveal(appeared, 0)
      Spacer(minLength: 28)
      progressSection.reveal(appeared, 1)
      Spacer(minLength: 28)
      // No split yet and nothing logged: "Your first workout", with setting up a split one tap away.
      UpNext(split: nextSplit,
             title: nextSplit == nil && firstRun ? store.t("Your first workout") : nil,
             heroSlot: "home",
             link: nextSplit == nil && firstRun ? (store.t("Set up a split"), { creatingSplit = true }) : nil) { choosing = true }
        .reveal(appeared, 2)
        .padding(.bottom, 28)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }


  /// One exercise's progress, which opens it; until something is comparable, the empty chart.
  @ViewBuilder private var progressSection: some View {
    if let trend = progress {
      NavigationLink {
        ExerciseProgressView(exercise: trend.exercise, split: store.data.workouts.first { $0.id == trend.splitID })
      } label: { ProgressCard(trend: trend, hasHistory: true) }
        .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("home.trend.\(trend.exercise.id)")
    } else {
      ProgressCard(trend: nil, hasHistory: !firstRun)
    }
  }
  /// The biggest gain in the split that's up next, else anywhere; nil until some exercise has two
  /// comparable workouts.
  private var progress: ExerciseTrend? {
    let trends = store.exerciseTrends(limit: .max).filter { $0.points.count >= 2 }
    return trends.first { $0.splitID != nil && $0.splitID == nextSplit?.id } ?? trends.first
  }
  /// Start workout: the page scrolls up to the plan. Nothing starts until Let’s go.
  private func openPlan() {
    JourneyHaptic.play(.light, store.profile)
    Analytics.tap("home.plan.open")
    planOpen = true
    scrollRequest = "plan"
  }
  /// Let’s go: the queued split, or a free workout. With blocking on but Screen Time access off, the
  /// plan has already said the apps won't lock, with the way to allow it.
  private func start() {
    if let split = nextSplit { store.updateProfile { $0.preferredSplitID = split.id } }
    store.startSession(workout: nextSplit)
  }
}

/// The plan, under Home: the workout's name large and its exercises with what each was last time (what locks sits under the button: `BlockingLine`). Pulling down scrolls back to Home (no button, at the
/// user's request); Home's button, now Let’s go, begins it. No cards or pills: plain rows on the paper.
struct StartPlan: View {
  @EnvironmentObject private var store: GymStore
  let split: Workout?
  let title: String
  let back: () -> Void
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // The name's place on the plan; Home's floating name settles here.
      HeroTitle(text: title).heroSlot("plan").padding(.top, 28)
        .overlay { Color.clear.accessibilityLabel(title).accessibilityAddTraits(.isHeader) }
      exercises.padding(.top, 28)
    }
    .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 24)
    // VoiceOver has no pull, so it gets an action instead.
    .accessibilityAction(named: store.t("Back"), back)
  }

  /// The exercises in order, each with its last set; a free workout says how it goes instead.
  @ViewBuilder private var exercises: some View {
    if let split, !split.exercises.isEmpty {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          PageLabel(text: store.t("Exercises"))
          Text(store.t("Last time")).font(.app(.caption)).foregroundStyle(JourneyColor.tertiary).fixedSize()
        }
        ForEach(Array(split.exercises.enumerated()), id: \.element.id) { index, exercise in
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(index + 1)").font(.app(.subheadline, weight: .medium)).monospacedDigit()
              .foregroundStyle(JourneyColor.tertiary).frame(width: 20, alignment: .leading)
            Text(store.t(exercise.name)).font(.app(.body)).foregroundStyle(JourneyColor.text).lineLimit(1)
            Spacer(minLength: 8)
            // What it was, never a guess at what it will be.
            Text(store.lastSet(for: exercise).map { setValue($0, store: store) } ?? store.t("first time"))
              .font(.app(.subheadline)).monospacedDigit().foregroundStyle(JourneyColor.secondary).lineLimit(1)
          }.frame(minHeight: 48).accessibilityElement(children: .combine)
          SettingsDivider()
        }
      }
    } else {
      Text(store.t("Pick exercises as you go.")).font(.app(.body)).foregroundStyle(JourneyColor.secondary)
    }
  }
}

/// What Let’s go does, under the button on the plan: a lock and the apps' own icons, or plainly why
/// nothing will lock, with the one way to fix it. No label: the icons under the button say it.
struct BlockingLine: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  var body: some View {
    let state = blocking.state(store.profile)
    HStack(spacing: 8) {
      switch state {
      case .on:
        Image(systemName: "lock.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
        BlockedIcons(size: 22, limit: 6).font(.app(.subheadline)).foregroundStyle(JourneyColor.tertiary)
      case .noAccess:
        Text(store.t("Apps won’t be blocked")).foregroundStyle(JourneyColor.tertiary)
        Button(store.t("Allow Screen Time")) {
          Analytics.track("blocking_unavailable", ["choice": "allow", "where": "plan"])
          Task { @MainActor in _ = await blocking.allow() }
        }.fontWeight(.semibold).foregroundStyle(JourneyColor.signal).accessibilityIdentifier("plan.allow")
      case .noApps, .off:
        Text(store.t(state == .off ? "App blocking is off" : "Choose apps to block")).foregroundStyle(JourneyColor.tertiary)
        NavigationLink { BlockedAppsView() } label: {
          Text(store.t(state == .off ? "Turn on" : "Choose apps")).fontWeight(.semibold).foregroundStyle(JourneyColor.signal)
        }.accessibilityIdentifier("plan.blocking")
      }
    }
    .font(.app(.subheadline)).lineLimit(1).minimumScaleFactor(0.8)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: state == .on ? .ignore : .contain)
    .accessibilityLabel(state == .on ? blocking.summary(store.t) + ", " + store.t("blocked while you train") : "")
  }
}

/// Where Home and the plan's scroll is; observed by the floating name alone.
@Observable final class PageScroll {
  var offset: CGFloat = 0
  var page: CGFloat = 1
  /// The plan has been reached since Start workout; read only by Home's scroll handler.
  @ObservationIgnored var reachedPlan = false
}

/// Home and the plan settle on one page or the other, by where a pull or flick was heading; past the
/// plan's top, a long plan scrolls freely.
struct PlanSnap: ScrollTargetBehavior {
  let page: CGFloat
  func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
    guard page > 1, target.rect.minY < page else { return }
    target.rect.origin.y = target.rect.minY > page * 0.5 ? page : 0
  }
}

/// Reports where the scroll is: from the scroll view itself on iOS 18 and later (a scroll doesn't
/// re-lay out its content, so geometry readers inside it don't always hear of it), else from inside.
private struct ScrollOffset: ViewModifier {
  let changed: (CGFloat) -> Void
  func body(content: Content) -> some View {
    if #available(iOS 18.0, *) {
      content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, y in changed(y) }
    } else {
      content.onPreferenceChange(PageOffset.self, perform: changed)
    }
  }
}
private struct PageOffset: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
struct HeroSlots: PreferenceKey {
  static let defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue()) { $1 } }
}

/// The workout's name, drawn once over Home and the plan: at Home's headline when the page is on Home,
/// at the plan's when it's on the plan, and between them in step with the scroll, so it follows a
/// pull under the finger.
private struct FloatingName: View {
  let text: String
  let scroll: PageScroll
  let home: CGRect?
  let plan: CGRect?
  var body: some View {
    if let home, let plan {
      let o = scroll.offset, page = max(scroll.page, 1)
      let p = min(max(o / page, 0), 1)
      // In the pages' own coordinates, Home's headline is seen at the top of the scroll and the plan's
      // a page down; past either end it moves with the page.
      let y = home.minY + (plan.minY - page - home.minY) * p - (o - min(max(o, 0), page))
      HeroTitle(text: text)
        .frame(width: home.width + (plan.width - home.width) * p, alignment: .leading)
        .offset(x: home.minX + (plan.minX - home.minX) * p, y: y)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
  }
}

extension GymStore {
  /// "3 exercises · 35 min last time": what's ahead and how long it took before, never a prediction.
  func summary(of split: Workout?) -> String {
    guard let split else { return t("Pick exercises as you go.") }
    let parts = splitSummary(split)
    return parts.count + "  ·  " + (parts.lastMinutes.map { "\($0) " + t("min last time") } ?? t("first time"))
  }
  /// The parts of `summary(of:)`: "3 exercises", and the minutes the last one took (nil: never done).
  /// The widgets' caption uses the minutes, so both count them the same way.
  func splitSummary(_ split: Workout) -> (count: String, lastMinutes: Int?) {
    let count = split.exercises.count
    let last = data.history.filter { $0.splitID == split.id }.max { $0.started < $1.started }
    return (count == 1 ? t("1 exercise") : "\(count) " + t("exercises"), last.map { max(1, Int($0.duration / 60)) })
  }
}

/// Pick what's up next, opened from Home's "Up next". A 28-pt title with Edit, then plain ruled rows
/// (the name and an emerald check on the chosen one) and New split as the last row. Choosing only picks: Home's Start workout is the one place a workout starts (and blocking turns
/// on). Edit turns the split rows into editor links with a delete button; a long press does the same.
struct WorkoutChoiceView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  /// The split up next now; nil when Free workout is.
  let current: UUID?
  let choose: (Workout?) -> Void
  @State private var picked: UUID??
  @State private var editMode = false
  @State private var creating = false
  @State private var editing: Workout?
  @State private var deleting: Workout?
  /// Half height to pick; full height to make or edit a split.
  @State private var detent: PresentationDetent = .medium
  private var chosen: UUID? { picked ?? current }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .firstTextBaseline) {
            Text(store.t("Up next")).font(JourneyType.headline).tracking(-0.3).foregroundStyle(JourneyColor.text)
              .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 12)
            if !store.data.workouts.isEmpty {
              Button(store.t(editMode ? "Done" : "Edit")) { withAnimation(.smooth(duration: 0.25)) { editMode.toggle() } }
                .font(.app(.body, weight: editMode ? .semibold : .regular))
                .foregroundStyle(editMode ? JourneyColor.text : JourneyColor.secondary).accessibilityIdentifier("split.edit")
            }
          }
          // No card: the sheet is already the surface, so the rows sit on it ruled like an index.
          VStack(alignment: .leading, spacing: 0) {
            ForEach(store.data.workouts) { split in
              row(split)
              SettingsDivider()
            }
            if !editMode {
              row(nil)
              SettingsDivider()
            }
            Button { creating = true } label: {
              HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(.body, weight: .semibold))
                Text(store.t("New split")).font(.app(.body))
              }.foregroundStyle(JourneyColor.signal).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("split.add")
          }
        }.padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 24)
      }
      .scrollIndicators(.hidden).gymPage().toolbar(.hidden, for: .navigationBar).track(screen: "home.choose")
      .navigationDestination(isPresented: $creating) {
        SplitEditorContent(workout: Workout(name: "", exercises: [])) { split in pick(split) }
      }
      .navigationDestination(item: $editing) { split in
        SplitEditorContent(workout: split) { _ in editing = nil }
      }
      .alert(store.t("Delete this split?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
             presenting: deleting) { split in
        Button(store.t("Delete split"), role: .destructive) {
          store.deleteSplit(split.id)
          if store.data.workouts.isEmpty { editMode = false }
        }
        Button(store.t("Cancel"), role: .cancel) {}
      } message: { _ in Text(store.t("Past workouts stay in Profile.")) }
    }.presentationDetents([.medium, .large], selection: $detent).presentationDragIndicator(.visible)
      .onChange(of: creating) { _, open in if open { withAnimation { detent = .large } } }
      .onChange(of: editing) { _, split in if split != nil { withAnimation { detent = .large } } }
  }

  /// A split, or Free workout when nil.
  private func row(_ split: Workout?) -> some View {
    let selected = !editMode && chosen == split?.id
    return Button {
      if editMode, let split { editing = split } else { pick(split) }
    } label: {
      HStack(spacing: 12) {
        // Just the name (13 Oct 2026): what's in it is on the plan Start workout opens.
        Text(split.map { store.t($0.name) } ?? store.t("Free workout")).font(.app(.title3, weight: .semibold))
          .foregroundStyle(JourneyColor.text).lineLimit(1)
        Spacer(minLength: 8)
        if editMode, let split {
          Button { deleting = split } label: {
            Image(systemName: "trash").font(.system(.body, weight: .medium)).foregroundStyle(JourneyColor.tertiary)
              .frame(width: 44, height: 44).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityLabel(store.t("Delete split")).accessibilityIdentifier("split.delete.\(split.name)")
          Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
            .accessibilityHidden(true)
        } else if selected {
          Image(systemName: "checkmark").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.signal)
            .transition(.scale.combined(with: .opacity)).accessibilityHidden(true)
        }
      }.padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu {
      if let split {
        Button(store.t("Edit split"), systemImage: "pencil") { editing = split }
        Button(store.t("Delete split"), systemImage: "trash", role: .destructive) { deleting = split }
      }
    }
    .accessibilityAddTraits(selected ? .isSelected : [])
    .accessibilityIdentifier(split.map { "choice.\($0.name)" } ?? "choice.free")
  }

  /// The check moves to the row, then the sheet closes and Home shows the choice.
  private func pick(_ split: Workout?) {
    JourneyHaptic.play(.selection, store.profile)
    withAnimation(.spring(duration: 0.3, bounce: 0.2)) { picked = .some(split?.id) }
    choose(split)
    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(280))
      dismiss()
    }
  }
}
