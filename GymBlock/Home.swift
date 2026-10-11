import SwiftUI

/// Home: what's up next, and one button. The week as a quiet line at the top; the split the rotation
/// has queued as the headline with one line of what's ahead; Start workout begins it in one tap, and
/// "Up next" opens the chooser to pick another. The caption slot, the button and the 20-pt rest
/// under it stay in their fixed place. (Chosen 11 Oct 2026 over a streak-first and a launcher layout.)
struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var choosing = false
  @State private var appeared = false
  /// Free workout picked in the chooser; it lasts until the workout starts.
  @State private var free = false
  /// Nothing logged yet: Home shows the truth (an empty week) and guides to the first workout.
  private var firstRun: Bool { store.data.history.allSatisfy { $0.completedSets.isEmpty } }
  private var stats: HomeStats { store.homeStats() }
  @State private var creatingSplit = false
  /// The split the rotation has queued, else the first split; none means a free workout.
  private var nextSplit: Workout? {
    free ? nil : store.data.workouts.first { $0.id == store.profile.preferredSplitID } ?? store.data.workouts.first
  }
  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid()
        VStack(spacing: 0) {
          if typeSize.isAccessibilitySize {
            ScrollView { content.padding(.bottom, 24) }.scrollIndicators(.hidden).frame(maxHeight: .infinity)
          } else {
            content
          }
          VStack(spacing: 10) {
            caption.frame(minHeight: 20)
            JourneyButton(title: store.t("Start workout"), id: "home.start") {
              JourneyHaptic.play(.medium, store.profile, intensity: 0.8)
              startNext()
            }
            Color.clear.frame(height: 20)
          }.padding(.top, 8)
        }.padding(.horizontal, 24).padding(.bottom, 4)
      }
      .toolbar(.hidden, for: .navigationBar).track(screen: "home", ["first": firstRun])
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
    }
  }

  /// The week at the top, then the queued workout centred in the space above the button.
  private var content: some View {
    VStack(alignment: .leading, spacing: 0) {
      WeekLine(stats: stats).padding(.top, 24).reveal(appeared, 0)
      Spacer(minLength: 32)
      // No split yet and nothing logged: "Your first workout", with setting up a split one tap away.
      UpNext(split: nextSplit, detail: nextDetail,
             title: nextSplit == nil && firstRun ? store.t("Your first workout") : nil,
             link: nextSplit == nil && firstRun ? (store.t("Set up a split"), { creatingSplit = true }) : nil) { choosing = true }
        .reveal(appeared, 1)
      Spacer(minLength: 32)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  private var nextDetail: String { store.summary(of: nextSplit) }
  /// One tap: the queued split (or a free workout) starts at once; "Up next" above opens the chooser to change it.
  private func startNext() {
    if let split = nextSplit { store.updateProfile { $0.preferredSplitID = split.id } }
    store.startSession(workout: nextSplit)
  }
  /// One honest line above the button, the same one the workout shows.
  @ViewBuilder private var caption: some View {
    if store.data.demoLoaded == true && !StoreShots.on {
      Text(store.t("Sample data")).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).accessibilityIdentifier("home.sample")
    } else if store.profile.focusEnabled == true {
      HStack(spacing: 6) {
        Image(systemName: "lock.fill").font(.caption2).accessibilityHidden(true)
        BlockedIcons(size: 14, limit: 3)
        Text(blocking.ready ? blocking.summary(store.t) + " · " + store.t("blocked while you train")
             : store.t("Choose apps to block in Settings"))
      }.font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).lineLimit(1)
        .accessibilityElement(children: .combine).accessibilityIdentifier("home.blocking")
    } else {
      Color.clear.frame(height: 20)
    }
  }
}

extension GymStore {
  /// "3 exercises · 35 min last time": what's ahead and how long it took before, never a prediction.
  func summary(of split: Workout?) -> String {
    guard let split else { return t("Pick exercises as you go.") }
    let count = split.exercises.count
    var parts = [count == 1 ? t("1 exercise") : "\(count) " + t("exercises")]
    if let last = data.history.filter({ $0.splitID == split.id }).max(by: { $0.started < $1.started }) {
      parts.append("\(max(1, Int(last.duration / 60))) " + t("min last time"))
    } else {
      parts.append(t("first time"))
    }
    return parts.joined(separator: "  ·  ")
  }
}

/// Pick what's up next, opened from Home's "Up next". A 28-pt title with Edit, then plain ruled rows
/// (the name, one quiet line, an emerald check on the chosen one) and New split as the last row. Choosing only picks: Home's Start workout is the one place a workout starts (and blocking turns
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
                .font(.system(.body, weight: editMode ? .semibold : .regular))
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
                Text(store.t("New split")).font(.body)
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
        VStack(alignment: .leading, spacing: 3) {
          Text(split.map { store.t($0.name) } ?? store.t("Free workout")).font(.system(.title3, weight: .semibold))
            .foregroundStyle(JourneyColor.text).lineLimit(1)
          Text(store.summary(of: split)).font(.subheadline).monospacedDigit().foregroundStyle(JourneyColor.tertiary).lineLimit(1)
        }
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
