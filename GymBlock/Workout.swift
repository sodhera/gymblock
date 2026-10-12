import SwiftUI
import UIKit

/// The workout as a live page, the entry page while it's still happening (designed from a clean
/// slate on 11 Oct 2026). The split is the title; every exercise is a section: the sets done in
/// ink, the set you're on as two fields you type into, the sets still to come in grey from last
/// time. Tap another exercise's name to switch to it. A dock at the bottom holds the clock (the set
/// or the rest, emerald once the rest is up) and the one primary action, which never moves.
/// Everything is saved as it happens, so a call, a locked phone or a relaunch never loses a set.
struct WorkoutView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var picker = false
  @State private var editing: LoggedSet?
  @State private var confirmEnd = false
  @State private var confirmEndSet = false
  @State private var confirmSwitch = false
  @State private var pendingExercise: Exercise?
  @State private var weightText = ""
  @State private var repsText = ""
  /// What the open field showed before you tapped it: its placeholder while you type, kept if you don't.
  @State private var editingFrom = ""
  @State private var guardUntil = Date.distantPast
  @State private var screenHeight: CGFloat = 800
  /// Hold an exercise's name to lift it; drag to reorder in a compact list of names.
  @State private var lifted: String?
  @State private var reorder: Reorder?
  /// True only while the hold-and-drag gesture is alive; it resets by itself when the gesture is cancelled.
  @GestureState private var holding = false
  /// The held exercise, the order so far, where it started, the list's top and how far the finger moved.
  private struct Reorder { var id: String; var order: [String]; var start: Int; var top: CGFloat; var dy: CGFloat }
  private let pitch: CGFloat = 56
  @FocusState private var field: Field?
  enum Field { case weight, reps }

  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  private var session: Session { store.session ?? Session() }
  private var exercise: Exercise? { session.selected }
  private var stage: Stage { session.selected == nil ? .exercise : session.stage }
  private var active: Bool { stage == .active || stage == .log }
  private var timed: Bool { exercise?.timed == true }
  /// "Set 2 is still going.": the set a mid-set End or switch would save or throw away.
  private var runningSet: String { store.t("Set") + " \(done + 1) " + store.t("is still going.") }
  private var weightMissing: Bool { !timed && session.weightIsSet == false }
  private var oneTap: Bool { !store.timesSets && !timed }
  private var done: Int { store.doneSets(exercise) }
  private var paused: Bool { session.pausedAt != nil }
  private var target: Int { store.targetSets(exercise) }
  /// The very first workout, before its first set: two one-line hints show, then never again.
  private var firstEver: Bool { session.sets.isEmpty && store.data.history.allSatisfy { $0.completedSets.isEmpty } }
  /// The workout's exercises in order: the split's, then any added along the way.
  private var exercises: [Exercise] {
    var seen = Set<String>()
    return (session.exercises + session.sets.map(\.exercise) + [exercise].compactMap { $0 }).filter { seen.insert($0.id).inserted }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid().track(screen: "workout", ["stage": store.session?.stage.rawValue])
        ScrollViewReader { proxy in
          ScrollView {
            VStack(alignment: .leading, spacing: 30) {
              if store.deletedSet != nil {
                Button(store.t("Undo delete")) { store.undoDelete() }.font(.app(.subheadline, weight: .semibold))
                  .foregroundStyle(JourneyColor.text).accessibilityIdentifier("set.undo")
              }
              ForEach(exercises) { item in section(item).id(item.id) }
              addExercise
            }.frame(maxWidth: .infinity, alignment: .leading)
              .padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 32)
          }
          .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
          .scrollDisabled(reorder != nil)
          .modifier(SoftTopEdge())
          .onAppear { reveal(proxy, animated: false) }
          .onChange(of: session.selected?.id) { _, _ in reveal(proxy) }
          .onChange(of: field) { _, focused in if focused != nil { reveal(proxy) } }
        }
      }
      .overlay { if let reorder { reorderLayer(reorder) } }
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { screenHeight = $0 }
      .coordinateSpace(name: "screen")
      .safeAreaInset(edge: .bottom, spacing: 0) { dock }
      // The native Liquid Glass bar: the workout's name leads, large; End trails (12 Oct 2026: the
      // workout clock left the bar at the user's request; the summary still has the time).
      .navigationTitle(store.t(session.name))
      .toolbarTitleDisplayMode(.inlineLarge)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          // Until the first set is logged there's nothing to keep: Cancel throws the workout away
          // (no summary, nothing in Profile) and unlocks the apps. After that it's End.
          Button(store.t(session.sets.isEmpty && !active ? "Cancel" : "End"), action: end)
            .accessibilityIdentifier("session.finish")
        }
      }
    }
    .sheet(isPresented: $picker, onDismiss: { if pendingExercise != nil { confirmSwitch = true } }) {
      NavigationStack {
        ExercisePickerContent(onChoose: choose)
          .navigationTitle(store.t("Choose exercise")).navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button(store.t("Cancel")) { picker = false }.accessibilityIdentifier("exercise.cancel")
            }
          }
      }
    }
    .sheet(item: $editing) { SetEditor(set: $0, sessionID: session.id) }
    // Asked what you tapped (End, or another exercise), then what's at stake: the set that's running.
    .confirmationDialog(store.t("End workout?"), isPresented: $confirmEndSet, titleVisibility: .visible) {
      Button(store.t("Save set and end")) { if finishSet() { store.finish() } }
        .disabled(!setValid).accessibilityIdentifier("session.saveEnd")
      Button(store.t("Discard set and end"), role: .destructive) { store.cancelSet(); store.finish() }
        .accessibilityIdentifier("session.discardEnd")
      // Not a cancel role: iOS can hide those in action sheets, and this choice must stay visible.
      Button(store.t("Keep going")) {}.accessibilityIdentifier("session.keepGoing")
    } message: { Text(runningSet) }
    // An alert, not an action sheet: both choices stay visible, so there is always a way back.
    .alert(store.t("End workout?"), isPresented: $confirmEnd) {
      Button(store.t("End workout")) { store.finish() }.accessibilityIdentifier("session.endConfirm")
      Button(store.t("Keep going"), role: .cancel) {}
    } message: { Text(setCount(session.completedSets.count, store: store) + " " + store.t("will be saved.")) }
    .confirmationDialog(store.t("Switch exercise?"), isPresented: $confirmSwitch, titleVisibility: .visible) {
      Button(store.t("Save set and switch")) { resolveSwitch(saving: true) }
        .disabled(!setValid).accessibilityIdentifier("switch.save")
      Button(store.t("Discard set and switch"), role: .destructive) { resolveSwitch(saving: false) }
        .accessibilityIdentifier("switch.discard")
      Button(store.t("Keep going")) { pendingExercise = nil }.accessibilityIdentifier("switch.cancel")
    } message: { Text(runningSet) }
    .onChange(of: confirmSwitch) { _, shown in if !shown { pendingExercise = nil } }
    // A drag that was cancelled rather than finished never reaches onEnded: drop it without saving.
    .onChange(of: holding) { _, alive in
      if !alive, reorder != nil || lifted != nil { withAnimation(.smooth(duration: 0.3)) { reorder = nil; lifted = nil } }
    }
    .onAppear {
      if paused { store.resume() }
      sync(); if stage == .exercise { picker = true }
    }
    .onChange(of: session.selected?.id) { _, _ in sync() }
    .onChange(of: session.weightKG) { _, _ in sync() }
    .onChange(of: session.weightIsSet) { _, _ in sync() }
    .onChange(of: session.draftRepsText) { _, _ in sync() }
    .onChange(of: store.profile.unit) { _, _ in sync() }
    .onChange(of: field) { _, opened in
      sync()
      // Tapping a number opens it empty, with the old value as its placeholder: typing replaces it,
      // and leaving it empty keeps it (sync restores it from the store). No selection handles.
      switch opened {
      case .weight: editingFrom = weightText; weightText = ""
      case .reps: editingFrom = repsText; repsText = ""
      case nil: editingFrom = ""
      }
    }
    .onChange(of: weightText) { _, text in
      guard field == .weight, let value = parseNumber(text), value.isFinite, (0...500).contains(value) else { return }
      store.updateWeight(value, unit: store.profile.unit)
    }
    .onChange(of: repsText) { _, text in if field == .reps && !text.isEmpty { store.updateRepText(text) } }
    .task(id: restKey) { await restAlarm() }
  }

  /// Keeps the set you're on in view: on open, on a switch, and when a field takes the keyboard.
  private func reveal(_ proxy: ScrollViewProxy, animated: Bool = true) {
    guard exercise != nil else { return }
    withAnimation(animated && !reduceMotion ? .smooth(duration: 0.4) : nil) { proxy.scrollTo("live", anchor: .center) }
  }

  // MARK: Top bar

  // MARK: The page

  /// One exercise: its name (in ink while you're on it; tap another to switch to it, hold and drag
  /// to move it), how many sets it gets ("− 3 sets +") or, once done, its time; then the sets done,
  /// the set you're on as fields, and the sets still to come in grey.
  private func section(_ item: Exercise) -> some View {
    let current = item.id == exercise?.id
    let logged = session.sets.filter { $0.exercise.id == item.id }
    let planned = store.targetSets(item)
    let finished = store.doneSets(item) >= planned
    let live = current && (active || !finished)
    let remaining = max(0, planned - store.doneSets(item) - (live ? 1 : 0))
    let plan = plannedValue(item)
    return VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .center, spacing: 8) {
        Text(store.t(item.name)).font(.app(.caption, weight: .semibold)).tracking(1.4).textCase(.uppercase)
          .foregroundStyle(current ? JourneyColor.text : JourneyColor.secondary).lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier(current ? "set.exercise" : "")
        if !current && !logged.isEmpty && finished, let time = store.exerciseTime(logged) {
          HStack(spacing: 4) {
            Image(systemName: "clock").font(.system(size: 11, weight: .medium)).accessibilityHidden(true)
            Text(time).monospacedDigit()
          }.font(.app(.footnote, weight: .medium)).foregroundStyle(JourneyColor.tertiary)
        } else {
          setStepper(item, planned: planned)
        }
      }
      .frame(minHeight: 38).contentShape(Rectangle())
      .scaleEffect(lifted == item.id ? 1.03 : 1, anchor: .leading)
      .animation(.spring(duration: 0.25, bounce: 0.3), value: lifted)
      // Tap the name to switch to this exercise; hold it, then drag, to move it.
      .onTapGesture { switchTo(item) }
      .gesture(reorderGesture(item))
      .accessibilityElement(children: .contain).accessibilityAddTraits(.isHeader)
      .accessibilityHint(current ? "" : store.t("Switch to this exercise"))
      .accessibilityIdentifier("exercise.section.\(item.id)")
      ForEach(Array(logged.enumerated()), id: \.element.id) { index, set in loggedRow(set, number: index + 1) }
      // In the order things happen: the set just done, the rest, then the set that's next.
      if current && stage == .rest { restStrip }
      if live { liveRow(number: logged.count + 1).id("live") } else if current { Color.clear.frame(height: 0).id("live") }
      if live && !timed && !active && (weightMissing || firstEver) {
        Text(store.t(weightMissing ? "Add the weight for this set." : "Tap a number to type it.")).font(.app(.footnote))
          .foregroundStyle(weightMissing ? JourneyColor.signal : JourneyColor.tertiary)
          .padding(.leading, 32).padding(.bottom, 4).accessibilityIdentifier("hint.type")
      }
      ForEach(0..<remaining, id: \.self) { i in
        plannedRow(number: logged.count + (live ? 2 : 1) + i, value: plan)
      }
    }
  }

  /// "− 3 sets +": how many sets this exercise gets in this workout. Never fewer than are done.
  private func setStepper(_ item: Exercise, planned: Int) -> some View {
    let running = item.id == exercise?.id && active ? 1 : 0
    return HStack(spacing: 0) {
      Button { store.changeTarget(item, by: -1); JourneyHaptic.play(.selection, store.profile) } label: {
        Image(systemName: "minus").frame(width: 34, height: 36).contentShape(Rectangle())
      }.disabled(planned <= store.doneSets(item) + running)
        .accessibilityLabel(store.t("Fewer sets")).accessibilityIdentifier("sets.minus.\(item.id)")
      Text("\(planned) " + store.t(planned == 1 ? "set" : "sets")).monospacedDigit()
        .accessibilityIdentifier("sets.count.\(item.id)")
      Button { store.changeTarget(item, by: 1); JourneyHaptic.play(.selection, store.profile) } label: {
        Image(systemName: "plus").frame(width: 34, height: 36).contentShape(Rectangle())
      }.accessibilityLabel(store.t("More sets")).accessibilityIdentifier("sets.plus.\(item.id)")
    }.font(.app(.footnote, weight: .medium)).foregroundStyle(JourneyColor.tertiary).buttonStyle(.plain)
  }

  /// Hold (0.35 s) then drag. The page gives way to a compact list of names with the held one under
  /// the finger; the others slide out of its way, and letting go saves the order.
  private func reorderGesture(_ item: Exercise) -> some Gesture {
    LongPressGesture(minimumDuration: 0.35)
      .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("screen")))
      .updating($holding) { value, state, _ in if case .second(true, _) = value { state = true } }
      .onChanged { value in
        guard case .second(true, let drag) = value else { return }
        if lifted == nil {
          field = nil
          lifted = item.id
          JourneyHaptic.play(.medium, store.profile, intensity: 0.7)
        }
        guard let drag else { return }
        if reorder == nil {
          let order = exercises.map(\.id)
          let start = order.firstIndex(of: item.id) ?? 0
          // The list sits so the held name starts under the finger, kept on screen.
          let wanted = drag.startLocation.y - (CGFloat(start) + 0.5) * pitch
          let top = min(max(wanted, 16), max(16, screenHeight - CGFloat(order.count) * pitch - 16))
          withAnimation(.smooth(duration: 0.25)) { reorder = Reorder(id: item.id, order: order, start: start, top: top, dy: 0) }
        }
        guard var state = reorder else { return }
        // Relative to where it lifted: every row's height of travel passes one exercise.
        state.dy = drag.location.y - drag.startLocation.y
        let index = min(max(0, state.start + Int((state.dy / pitch).rounded())), state.order.count - 1)
        if let from = state.order.firstIndex(of: state.id), from != index {
          state.order.move(fromOffsets: IndexSet(integer: from), toOffset: index > from ? index + 1 : index)
          JourneyHaptic.play(.selection, store.profile)
          withAnimation(.smooth(duration: 0.2)) { reorder = state }
        } else {
          reorder = state
        }
      }
      .onEnded { _ in
        if let state = reorder { store.setExerciseOrder(state.order) }
        withAnimation(.smooth(duration: 0.3)) { reorder = nil; lifted = nil }
      }
  }

  /// While reordering: the page dims to paper and the exercises become one column of names.
  private func reorderLayer(_ state: Reorder) -> some View {
    let names = Dictionary(exercises.map { ($0.id, store.t($0.name)) }, uniquingKeysWith: { first, _ in first })
    return ZStack(alignment: .topLeading) {
      // The page itself, solid: nothing of the sets shows through behind the names.
      DotGrid()
      ForEach(Array(state.order.enumerated()), id: \.element) { index, id in
        let held = id == state.id
        Text(names[id] ?? "").font(.app(.title3, weight: held ? .semibold : .medium))
          .foregroundStyle(held ? JourneyColor.text : JourneyColor.secondary).lineLimit(1)
          .frame(maxWidth: .infinity, minHeight: pitch - 8, alignment: .leading).padding(.horizontal, 18)
          .background {
            if held {
              RoundedRectangle(cornerRadius: 16, style: .continuous).fill(JourneyColor.raised)
                .shadow(color: JourneyColor.ink(0.12), radius: 16, y: 6)
            } else {
              // Ruled like the page: a hairline under each name.
              VStack { Spacer(); SettingsDivider() }.padding(.horizontal, 18).offset(y: 4)
            }
          }
          .padding(.horizontal, 6)
          .position(x: UIScreen.main.bounds.width / 2,
                    y: state.top + (CGFloat(held ? state.start : index) + 0.5) * pitch + (held ? state.dy : 0))
          .zIndex(held ? 1 : 0)
      }
    }
    .allowsHitTesting(false).transition(.opacity)
    .accessibilityHidden(true)
  }

  /// A set already done, in ink; tap to correct it.
  private func loggedRow(_ set: LoggedSet, number: Int) -> some View {
    Button { field = nil; editing = set } label: {
      HStack(alignment: .firstTextBaseline, spacing: 14) {
        setNumber(number, color: JourneyColor.tertiary)
        Text(setValue(set, store: store)).font(.app(.title3)).monospacedDigit()
          .foregroundStyle(set.unsuccessful == true ? JourneyColor.secondary : JourneyColor.text).lineLimit(1)
        Spacer(minLength: 0)
      }.frame(minHeight: 40).contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityLabel(store.t("Set") + " \(number), " + setValue(set, store: store))
      .accessibilityIdentifier("saved." + set.id.uuidString)
  }

  /// The set you're on: weight and reps as fields to type into (the keyboard bar has − and +). Its
  /// number turns emerald while the set runs; a running set can be cancelled from here.
  private func liveRow(number n: Int) -> some View {
    HStack(alignment: .center, spacing: 12) {
      setNumber(n, color: active && !paused ? JourneyColor.signal : JourneyColor.text)
      if timed {
        Text(store.t(active ? "Tap Finish when you stop." : "The clock times this exercise.")).font(.app(.body))
          .foregroundStyle(JourneyColor.secondary).lineLimit(2)
      } else {
        weightField
        // Just the unit, as on every other row; VoiceOver still says "each" for dumbbells.
        Text(store.profile.unit).font(.app(.body)).foregroundStyle(JourneyColor.tertiary).lineLimit(1).fixedSize()
        Text("×").font(.app(.title3)).foregroundStyle(JourneyColor.tertiary).accessibilityHidden(true)
        repsField
      }
      Spacer(minLength: 0)
      if active {
        Button(store.t("Cancel")) { field = nil; store.cancelSet() }.font(.app(.subheadline)).foregroundStyle(JourneyColor.tertiary)
          .accessibilityLabel(store.t("Cancel set")).accessibilityIdentifier("set.cancel")
      }
    }.frame(minHeight: 56)
  }

  /// The rest, between the set just done and the next (12 Oct 2026, moved up from the dock), read as one line: "Rest", a
  /// bar that fills as the rest runs, the time left. When it's up the word and the bar turn emerald
  /// ("Rest's up": the one signal, meaning go) and the time turns to how far over, in grey, since
  /// resting long is nothing to cheer. Tap the time to change the rest length (also in Settings).
  private var restStrip: some View {
    HStack(spacing: 12) {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let up = restElapsed(at: context.date) >= Double(store.restTarget)
        Text(store.t(up ? "Rest’s up" : "Rest")).font(.app(.subheadline, weight: .medium))
          .foregroundStyle(up ? JourneyColor.signal : JourneyColor.secondary).lineLimit(1).fixedSize()
          .accessibilityHidden(true)
      }
      TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 15)) { context in
        let progress = min(1, max(0, restElapsed(at: context.date) / Double(max(1, store.restTarget))))
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule().fill(JourneyColor.ink(0.08))
            Capsule().fill(progress >= 1 ? JourneyColor.signal : JourneyColor.ink(0.45))
              .frame(width: max(3, geometry.size.width * progress))
          }
        }.frame(height: 3).animation(.easeOut(duration: 0.3), value: progress >= 1)
      }.accessibilityHidden(true).accessibilityIdentifier("rest.strip")
      restMenu
    }.padding(.vertical, 4)
  }

  private func restElapsed(at date: Date) -> Double {
    let now = session.pausedAt ?? date
    return now.timeIntervalSince(session.restStarted ?? now)
  }

  /// A set still to come: last time's numbers, in grey.
  private func plannedRow(number n: Int, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 14) {
      setNumber(n, color: JourneyColor.tertiary)
      Text(value).font(.app(.title3)).monospacedDigit().foregroundStyle(JourneyColor.tertiary).lineLimit(1)
      Spacer(minLength: 0)
    }.frame(minHeight: 40).accessibilityElement(children: .combine)
  }

  private func setNumber(_ n: Int, color: Color) -> some View {
    Text("\(n)").font(.app(.subheadline, weight: .medium)).monospacedDigit().foregroundStyle(color)
      .frame(width: 20, alignment: .leading)
  }

  private var weightField: some View {
    let bodyweight = !weightMissing && session.weightKG == 0
    let unit = store.profile.unit + (exercise?.perDumbbell == true ? " " + store.t("each") : "")
    return TextField(field == .weight && !editingFrom.isEmpty ? editingFrom : weightMissing ? "—" : bodyweight ? "" : "0", text: $weightText)
      .keyboardType(.decimalPad).focused($field, equals: .weight).tint(JourneyColor.signal)
      .font(.app(.title3, weight: .semibold)).monospacedDigit().multilineTextAlignment(.center)
      .foregroundStyle(JourneyColor.text).minimumScaleFactor(0.6)
      .overlay {
        if bodyweight && field != .weight {
          Text(store.t("BW")).font(.app(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text)
            .allowsHitTesting(false).accessibilityHidden(true)
        }
      }
      .modifier(InputBox(focused: field == .weight, signal: weightMissing && stage != .exercise, width: 78))
      .accessibilityLabel(store.t("Weight")).accessibilityIdentifier("set.weight")
      .accessibilityValue(weightMissing ? store.t("Not set") : bodyweight ? store.t("Bodyweight") : weightText + " " + unit)
  }

  private var repsField: some View {
    TextField(field == .reps && !editingFrom.isEmpty ? editingFrom : "—", text: $repsText)
      .keyboardType(.numberPad).focused($field, equals: .reps).tint(JourneyColor.signal)
      .font(.app(.title3, weight: .semibold)).monospacedDigit().multilineTextAlignment(.center)
      .foregroundStyle(JourneyColor.text).minimumScaleFactor(0.6)
      .modifier(InputBox(focused: field == .reps, signal: false, width: 58))
      .accessibilityLabel(store.t("Reps")).accessibilityIdentifier("set.reps")
  }

  private var addExercise: some View {
    Button { field = nil; picker = true } label: {
      HStack(spacing: 10) {
        Image(systemName: "plus").font(.system(.body, weight: .semibold))
        Text(store.t(exercises.isEmpty ? "Choose exercise" : "Add exercise")).font(.app(.body))
      }.foregroundStyle(JourneyColor.signal).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
    }.buttonStyle(.plain).accessibilityIdentifier("set.change")
  }

  /// What a set still to come should be: the set you're drafting for this exercise, its saved draft,
  /// or last time's; a dash when there's nothing to go on (never an invented load).
  private func plannedValue(_ item: Exercise) -> String {
    if item.id == exercise?.id {
      return weightMissing ? "—" : value(kg: session.weightKG, reps: store.draftRepCount, timed: item.timed, minutes: session.draftMinutes)
    }
    if let draft = session.drafts?[item.id], draft.weightIsSet != false {
      return value(kg: draft.weightKG, reps: draft.reps, timed: item.timed, minutes: draft.minutes)
    }
    if let last = store.lastSet(for: item) { return value(kg: last.weightKG, reps: last.reps, timed: item.timed, minutes: last.minutes) }
    return "—"
  }
  private func value(kg: Double, reps: Int?, timed: Bool, minutes: Double?) -> String {
    if timed { return minutes.map { formatNumber($0) + " " + store.t("min") } ?? "—" }
    let weight = kg == 0 ? store.t("Bodyweight") : formatNumber(GymStore.displayedWeight(kg, unit: store.profile.unit)) + " " + store.profile.unit
    return weight + " × " + (reps.map(String.init) ?? "—")
  }

  // MARK: The dock

  /// The clock and the one primary action, fixed at the bottom (on the keyboard while you type, with
  /// − + and Next or Done instead); the page scrolls under a paper fade.
  private var dock: some View {
    VStack(spacing: 12) {
      if field != nil {
        // While you type, the dock sits on the keyboard and holds its controls: − and +, wide, step the
        // open number; Next, compact, moves from weight to reps, where it becomes Done and closes the keyboard.
        HStack(spacing: 12) {
          HStack(spacing: 0) {
            Button { stepFocused(-1) } label: { Image(systemName: "minus").frame(maxWidth: .infinity, minHeight: 50).contentShape(Rectangle()) }
              .accessibilityLabel(store.t("Less")).accessibilityIdentifier("set.keyboard.minus")
            Rectangle().fill(JourneyColor.ink(0.14)).frame(width: 1, height: 24).accessibilityHidden(true)
            Button { stepFocused(1) } label: { Image(systemName: "plus").frame(maxWidth: .infinity, minHeight: 50).contentShape(Rectangle()) }
              .accessibilityLabel(store.t("More")).accessibilityIdentifier("set.keyboard.plus")
          }
          .buttonStyle(.plain).font(.app(size: 22, weight: .semibold)).foregroundStyle(JourneyColor.text)
          .journeyGlass(Capsule(), interactive: true)
          doneButton
        }
      } else {
        // The clock only while a set runs; the rest's time sits between the sets (restStrip).
        if active { clockLine }
        JourneyButton(title: primaryTitle, id: "workout.primary", action: runPrimary)
      }
    }
    .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 8)
    .background {
      VStack(spacing: 0) {
        LinearGradient(colors: [JourneyColor.stage.opacity(0), JourneyColor.stage], startPoint: .top, endPoint: .bottom).frame(height: 28)
        JourneyColor.stage
      }.padding(.top, -28).ignoresSafeArea(edges: .bottom).allowsHitTesting(false)
    }
  }

  /// Compact, in the primary style, beside the wide − and +. On the weight it's Next and opens the
  /// reps, so a set is typed in one go; on the reps it's Done and closes the keyboard.
  private var doneButton: some View {
    let next = field == .weight
    let id = next ? "set.keyboard.next" : "set.keyboard.done"
    let close = {
      Analytics.tap(id)
      if next { field = .reps; JourneyHaptic.play(.selection, store.profile) } else { field = nil }
    }
    // Both words take the same room, so the button keeps its width when Next turns to Done.
    let label = ZStack {
      Text(store.t("Next")).opacity(next ? 1 : 0)
      Text(store.t("Done")).opacity(next ? 0 : 1)
    }.font(JourneyType.button).foregroundStyle(JourneyColor.onButton).padding(.horizontal, 10)
      .accessibilityElement(children: .ignore).accessibilityLabel(store.t(next ? "Next" : "Done"))
    return Group {
      if #available(iOS 26.0, *) {
        Button(action: close) { label }.buttonStyle(.glassProminent).tint(JourneyColor.button)
      } else {
        Button(action: close) { label.frame(minHeight: 50).padding(.horizontal, 12).background(Capsule().fill(JourneyColor.button)) }
          .buttonStyle(JourneyPressStyle())
      }
    }.controlSize(.large).buttonBorderShape(.capsule).fixedSize().accessibilityIdentifier(id)
  }

  /// The running set as a large clock with "Set time" beside it.
  private var clockLine: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      // While paused, every clock reads the moment the pause began.
      let now = session.pausedAt ?? context.date
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        switch stage {
        case .active, .log:
          clock(Int(now.timeIntervalSince(session.setStarted ?? now)), signal: false).accessibilityIdentifier("set.elapsed")
          Spacer(minLength: 8)
          stateLine(store.t("Set time"))
        default:
          EmptyView()
        }
      }
    }.frame(height: 52)
  }

  private func clock(_ seconds: Int, signal: Bool) -> some View {
    // Ticks like a watch: a rolling digit every second is restless.
    Text(clockText(seconds)).font(.app(size: 44, weight: .semibold)).monospacedDigit().tracking(-1)
      .foregroundStyle(paused ? JourneyColor.tertiary : signal ? JourneyColor.signal : JourneyColor.text)
      .lineLimit(1).minimumScaleFactor(0.6)
  }

  /// The line beside the clock; while paused it says so, whatever is underneath.
  @ViewBuilder private func stateLine(_ text: String, signal: Bool = false, id: String = "") -> some View {
    if paused {
      Text(store.t("Paused")).font(.app(.body, weight: .medium)).foregroundStyle(JourneyColor.secondary)
        .accessibilityIdentifier("workout.paused")
    } else if !text.isEmpty {
      Text(text).font(.app(.body, weight: .medium)).foregroundStyle(signal ? JourneyColor.signal : JourneyColor.secondary)
        .lineLimit(1).minimumScaleFactor(0.7).accessibilityIdentifier(id)
    }
  }

  /// The time left in the rest, then how far over; tap it to change the rest length.
  private var restMenu: some View {
    Menu {
      Picker(store.t("Rest length"), selection: Binding(get: { store.restTarget }, set: { store.setRestTarget($0) })) {
        ForEach(GymStore.restChoices, id: \.self) { Text(clockString($0)).tag($0) }
      }
    } label: {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let left = Double(store.restTarget) - restElapsed(at: context.date)
        Text(left > 0 ? clockString(Int(left.rounded(.up))) : "+" + clockString(Int(-left))).monospacedDigit()
          .font(.app(.title3, weight: .semibold))
          .foregroundStyle(left > 0 ? JourneyColor.text : JourneyColor.secondary)
          .accessibilityIdentifier("rest.elapsed")
          .accessibilityLabel(left > 0 ? store.t("Rest") + ", " + clockString(Int(left.rounded(.up))) : store.t("Rest’s up"))
      }.frame(minHeight: 44).contentShape(Rectangle())
    }.accessibilityHint(store.t("Rest length") + " " + clockString(store.restTarget))
      .accessibilityIdentifier("rest.target")
  }

  // MARK: Actions

  private enum Primary: Equatable { case choose, start, log, finish, next(Exercise), pick, end, resume }
  private var primary: Primary {
    if paused { return .resume }
    switch stage {
    case .workout, .exercise: return .choose
    case .active, .log: return .finish
    case .setup, .rest:
      if done >= target {
        if let next = store.nextExercise { return .next(next) }
        if store.splitComplete { return .end }
        if session.splitID == nil { return .pick }
      }
      return oneTap ? .log : .start
    }
  }
  private var primaryTitle: String {
    switch primary {
    case .choose: return store.t("Choose exercise")
    case .start: return store.t("Start set")
    case .log: return store.t("Log set")
    case .finish: return store.t("Finish set")
    case .next(let next): return store.t("Next:") + " " + store.t(next.name)
    case .pick: return store.t("Next exercise")
    case .end: return store.t("Finish workout")
    case .resume: return store.t("Resume")
    }
  }
  private func runPrimary() {
    // Sweaty double taps never start and finish a set at once.
    guard Date() >= guardUntil else { return }
    switch primary {
    case .resume: store.resume()
    case .choose, .pick: field = nil; picker = true; return
    case .next(let next):
      field = nil
      store.chooseExercise(next)
      JourneyHaptic.play(.soft, store.profile, intensity: 0.7)
    case .end: field = nil; confirmEnd = true; return
    case .finish:
      field = nil
      guard finishSet() else { field = timed ? nil : .reps; return }
    case .start, .log: begin()
    }
    guardUntil = Date().addingTimeInterval(0.6)
  }

  /// Start a set, or with one-tap logging, log it.
  private func begin() {
    field = nil
    guard exercise != nil else { picker = true; return }
    if weightMissing { field = .weight; JourneyHaptic.play(.light, store.profile, intensity: 0.6); return }
    if oneTap {
      guard store.logQuickSet() else { field = .reps; return }
      JourneyHaptic.land(store.profile)
      Task { await OnboardingFeedback.shared.playSound(profile: store.profile, completion: true) }
    } else {
      store.startSet(weight: GymStore.displayedWeight(session.weightKG, unit: store.profile.unit), unit: store.profile.unit)
      JourneyHaptic.play(.rigid, store.profile, intensity: 0.9)
    }
    guardUntil = Date().addingTimeInterval(0.6)
  }

  private var setValid: Bool {
    timed ? setMinutes > 0 : store.draftRepCount.map { (0...999).contains($0) } ?? false
  }
  private var setMinutes: Double { max(0, Date().timeIntervalSince(session.setStarted ?? Date()) / 60) }

  /// Zero reps records a missed attempt; the set clock gives a timed exercise its duration.
  @discardableResult private func finishSet() -> Bool {
    guard active else { return false }
    if timed {
      guard setMinutes > 0 else { return false }
      store.finishSet(reps: 0, minutes: setMinutes)
    } else {
      guard let reps = store.draftRepCount, (0...999).contains(reps) else { return false }
      if reps == 0 { store.recordAttempt() } else { store.finishSet(reps: reps, minutes: 0) }
    }
    JourneyHaptic.land(store.profile)
    Task { await OnboardingFeedback.shared.playSound(profile: store.profile, completion: true) }
    return true
  }


  private func end() {
    field = nil
    if active { confirmEndSet = true } else if session.sets.isEmpty { store.finish() } else { confirmEnd = true }
  }

  private func choose(_ next: Exercise) {
    picker = false
    guard next.id != exercise?.id else { return }
    if active { pendingExercise = next } else { store.chooseExercise(next) }
  }

  private func resolveSwitch(saving: Bool) {
    guard let next = pendingExercise else { return }
    if saving { finishSet() } else { store.cancelSet() }
    store.chooseExercise(next)
    pendingExercise = nil
  }

  /// − and + on the keyboard bar step whichever field is open, without closing it.
  private func stepFocused(_ direction: Int) {
    switch field {
    case .weight:
      store.stepWeight(direction)
      weightText = session.weightKG == 0 ? "" : inputNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit))
    case .reps:
      store.stepReps(direction)
      repsText = store.draftRepCount.map(String.init) ?? ""
    case nil: return
    }
    JourneyHaptic.play(.selection, store.profile)
  }

  /// Tap another exercise's name to move to it; mid-set it asks what to do with the running set first.
  private func switchTo(_ item: Exercise) {
    field = nil
    guard item.id != exercise?.id else { return }
    if active { pendingExercise = item; confirmSwitch = true } else {
      store.chooseExercise(item)
      JourneyHaptic.play(.selection, store.profile)
    }
  }

  // MARK: Sync and rest alarm

  private func sync() {
    if field != .weight {
      weightText = weightMissing || session.weightKG == 0 ? "" : inputNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit))
    }
    if field != .reps { repsText = store.draftRepCount.map(String.init) ?? "" }
  }

  private var restKey: String {
    "\(session.stage == .rest ? session.restStarted?.timeIntervalSince1970 ?? 0 : 0)-\(store.restTarget)-\(paused)"
  }
  /// In the app, rest's up is a double tap you can feel. With the phone locked, the notification does it.
  private func restAlarm() async {
    guard session.stage == .rest, !paused, let start = session.restStarted else { return }
    let due = start.addingTimeInterval(Double(store.restTarget))
    guard due.timeIntervalSinceNow > 0 else { return }
    try? await Task.sleep(for: .seconds(due.timeIntervalSinceNow))
    guard !Task.isCancelled, store.session?.stage == .rest, store.session?.restStarted == start, !store.isPaused,
      UIApplication.shared.applicationState == .active, abs(due.timeIntervalSinceNow) < 2
    else { return }
    JourneyHaptic.notification(store.profile)
    try? await Task.sleep(for: .milliseconds(450))
    JourneyHaptic.notification(store.profile)
    _ = await OnboardingFeedback.shared.playSound(profile: store.profile)
  }
}

/// A number field as a soft rounded box: ink outline while typing, emerald when it's the one thing missing.
private struct InputBox: ViewModifier {
  let focused: Bool
  let signal: Bool
  let width: CGFloat
  func body(content: Content) -> some View {
    content.frame(width: width, height: 40)
      .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(JourneyColor.ink(0.05)))
      .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(focused ? JourneyColor.text : signal ? JourneyColor.signal : .clear, lineWidth: 1.5))
  }
}

/// The soft Liquid Glass edge under the top bar on iOS 26, so rows fade instead of running under it.
private struct SoftTopEdge: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 26.0, *) { content.scrollEdgeEffectStyle(.soft, for: .top) } else { content }
  }
}
