import SwiftUI
import UIKit

/// The workout: one screen with a fixed grid, as in onboarding. The exercise sits where a headline
/// would, the clock ring is the stage, weight and reps are always in the same place, and the one
/// primary action never moves. Everything is saved as it happens, so a call, a locked phone or a
/// relaunch never loses a set or a rest.
struct WorkoutView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var picker = false
  @State private var records = false
  @State private var editing: LoggedSet?
  @State private var confirmEnd = false
  @State private var confirmEndSet = false
  @State private var confirmSwitch = false
  @State private var pendingExercise: Exercise?
  @State private var weightText = ""
  @State private var repsText = ""
  @State private var guardUntil = Date.distantPast
  @State private var screenHeight: CGFloat = 0
  @FocusState private var field: Field?
  enum Field { case weight, reps }

  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  private var session: Session { store.session ?? Session() }
  private var exercise: Exercise? { session.selected }
  private var stage: Stage { session.selected == nil ? .exercise : session.stage }
  private var active: Bool { stage == .active || stage == .log }
  private var timed: Bool { exercise?.timed == true }
  private var weightMissing: Bool { !timed && session.weightIsSet == false }
  private var oneTap: Bool { !store.timesSets && !timed }
  private var done: Int { store.doneSets(exercise) }
  private var target: Int { store.targetSets(exercise) }

  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid()
        VStack(spacing: 0) {
          topBar.padding(.top, 6)
          // Scrolls only at accessibility text sizes; otherwise a plain column, so nothing in it
          // ever loses its place (or its accessibility frame) when the keyboard comes and goes.
          if typeSize.isAccessibilitySize {
            ScrollView { middle }.scrollBounceBehavior(.basedOnSize).scrollDismissesKeyboard(.interactively)
          } else {
            middle.frame(maxHeight: .infinity)
          }
          actions
        }.padding(.horizontal, 24).padding(.bottom, 4)
          .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: field)
      }
      // The tallest measurement is the screen without the keyboard, so the ring keeps its size.
      .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { screenHeight = max(screenHeight, $0) }
      .toolbar(.hidden, for: .navigationBar)
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button(store.t("Done")) { field = nil }.fontWeight(.semibold).accessibilityIdentifier("set.keyboard.done")
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
    .sheet(isPresented: $records) { SessionRecordsView() }
    .sheet(item: $editing) { SetEditor(set: $0, sessionID: session.id) }
    .confirmationDialog(store.t("Finish this set first?"), isPresented: $confirmEndSet, titleVisibility: .visible) {
      Button(store.t("Save set and end")) { if finishSet() { store.finish() } }
        .disabled(!setValid).accessibilityIdentifier("session.saveEnd")
      Button(store.t("Discard set and end"), role: .destructive) { store.cancelSet(); store.finish() }
        .accessibilityIdentifier("session.discardEnd")
      // Not a cancel role: iOS can hide those in action sheets, and this choice must stay visible.
      Button(store.t("Keep going")) {}.accessibilityIdentifier("session.keepGoing")
    } message: { Text(store.t("Saved sets stay.")) }
    .confirmationDialog(store.t("End workout?"), isPresented: $confirmEnd, titleVisibility: .visible) {
      Button(store.t("End workout")) { store.finish() }.accessibilityIdentifier("session.endConfirm")
      Button(store.t("Keep going"), role: .cancel) {}
    } message: { Text(setCount(session.completedSets.count, store: store) + " " + store.t("will be saved.")) }
    .confirmationDialog(store.t("Finish this set first?"), isPresented: $confirmSwitch, titleVisibility: .visible) {
      Button(store.t("Save set and switch")) { resolveSwitch(saving: true) }
        .disabled(!setValid).accessibilityIdentifier("switch.save")
      Button(store.t("Discard set and switch"), role: .destructive) { resolveSwitch(saving: false) }
        .accessibilityIdentifier("switch.discard")
      Button(store.t("Keep going")) { pendingExercise = nil }.accessibilityIdentifier("switch.cancel")
    } message: { Text(store.t("Saved sets stay.")) }
    .onChange(of: confirmSwitch) { _, shown in if !shown { pendingExercise = nil } }
    .onAppear { sync(); if stage == .exercise { picker = true } }
    .onChange(of: session.selected?.id) { _, _ in sync() }
    .onChange(of: session.weightKG) { _, _ in sync() }
    .onChange(of: session.weightIsSet) { _, _ in sync() }
    .onChange(of: session.draftRepsText) { _, _ in sync() }
    .onChange(of: store.profile.unit) { _, _ in sync() }
    .onChange(of: field) { _, _ in sync() }
    .onChange(of: weightText) { _, text in
      guard field == .weight, let value = parseNumber(text), value.isFinite, (0...500).contains(value) else { return }
      store.updateWeight(value, unit: store.profile.unit)
    }
    .onChange(of: repsText) { _, text in if field == .reps { store.updateRepText(text) } }
    .task(id: restKey) { await restAlarm() }
  }

  /// Fixed heights between two flexible spacers: every state puts the ring, the values and the
  /// last set in exactly the same place.
  private var middle: some View {
    VStack(spacing: 0) {
      header.padding(.top, 18)
      Spacer(minLength: 16)
      // While typing, the ring folds away in place (never removed and re-inserted), so the
      // steppers and the button sit above the keyboard.
      hero(size: min(250, max(170, (screenHeight - 216) * 0.46)))
        .scaleEffect(field == nil ? 1 : 0.96)
        .frame(height: field == nil ? nil : 0).opacity(field == nil ? 1 : 0).clipped()
        .padding(.bottom, field == nil ? 24 : 0)
        .accessibilityHidden(field != nil)
      values
      footnote.frame(height: 44).padding(.top, 10)
      Spacer(minLength: 8)
    }
  }

  // MARK: Top bar

  private var topBar: some View {
    HStack(spacing: 10) {
      TimelineView(.periodic(from: .now, by: 1)) { context in
        let seconds = Int(context.date.timeIntervalSince(session.started))
        HStack(spacing: 8) {
          Circle().fill(JourneyColor.signalRed).frame(width: 7, height: 7)
          Text(clockText(seconds)).font(.system(.subheadline, weight: .semibold)).monospacedDigit()
            .foregroundStyle(JourneyColor.secondary)
        }.accessibilityElement(children: .ignore)
          .accessibilityLabel(store.t("Workout time") + " " + clockText(seconds))
          .accessibilityIdentifier("workout.clock")
      }
      Spacer()
      if !session.sets.isEmpty || active {
        GlassIconButton(symbol: "list.bullet", label: store.t("Sets"), id: "session.sets") { field = nil; records = true }
      }
      GlassPillButton(title: store.t("End"), id: "session.finish", action: end)
    }.frame(height: 60)
  }

  // MARK: Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      Button { field = nil; picker = true } label: {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text(store.t(exercise?.name ?? "Choose exercise")).font(.system(.title, weight: .bold))
            .foregroundStyle(JourneyColor.text).multilineTextAlignment(.leading)
            .lineLimit(2).minimumScaleFactor(0.75).accessibilityIdentifier("set.exercise")
          Image(systemName: "chevron.down").font(.system(.subheadline, weight: .bold))
            .foregroundStyle(JourneyColor.secondary).accessibilityHidden(true)
          Spacer(minLength: 0)
        }.contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier("set.change")
        .accessibilityLabel(store.t("Change exercise") + ", " + store.t(exercise?.name ?? ""))
      if exercise != nil { SetDots(done: done, target: target, live: active) }
    }.frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Stage

  @ViewBuilder private func hero(size: CGFloat) -> some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let now = context.date
      switch stage {
      case .active, .log:
        let seconds = Int(now.timeIntervalSince(session.setStarted ?? now))
        WorkoutRing(progress: Double(seconds % 60) / 60, signal: false, size: size, tick: seconds) {
          Text(store.t("Set time")).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
          ringTime(seconds).accessibilityIdentifier("set.elapsed")
          Text(" ").font(JourneyType.label).frame(minHeight: 44).accessibilityHidden(true)
        }.id("active")
      case .rest:
        let seconds = Int(now.timeIntervalSince(session.restStarted ?? now))
        let up = seconds >= store.restTarget
        WorkoutRing(progress: min(1, Double(seconds) / Double(store.restTarget)), signal: up, size: size, tick: seconds) {
          Text(store.t(up ? "Rest’s up" : "Rest")).font(JourneyType.label)
            .foregroundStyle(up ? JourneyColor.signalRed : JourneyColor.secondary)
            .accessibilityIdentifier("rest.state")
          ringTime(seconds).accessibilityIdentifier("rest.elapsed")
          restMenu
        }.id("rest")
      default:
        WorkoutRing(progress: 0, signal: false, size: size, tick: 0) { readyContent }.id("ready")
      }
    }.animation(reduceMotion ? nil : .smooth(duration: 0.4), value: stage)
  }

  private func ringTime(_ seconds: Int) -> some View {
    Text(clockText(seconds)).font(.system(size: seconds >= 3600 ? 42 : 60, weight: .semibold)).monospacedDigit()
      .foregroundStyle(JourneyColor.text).lineLimit(1).minimumScaleFactor(0.5)
      .contentTransition(.numericText()).animation(reduceMotion ? nil : .smooth(duration: 0.3), value: seconds)
  }

  /// Change the rest length right where it's counting.
  private var restMenu: some View {
    Menu {
      Picker(store.t("Rest"), selection: Binding(get: { store.restTarget }, set: { store.setRestTarget($0) })) {
        ForEach(GymStore.restChoices, id: \.self) { Text(clockString($0)).tag($0) }
      }
    } label: {
      HStack(spacing: 4) {
        Text(store.t("of") + " " + clockString(store.restTarget)).monospacedDigit()
        Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.semibold))
      }.font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
        .padding(.horizontal, 12).frame(minHeight: 44).contentShape(Rectangle())
    }.accessibilityLabel(store.t("Rest length") + " " + clockString(store.restTarget))
      .accessibilityIdentifier("rest.target")
  }

  @ViewBuilder private var readyContent: some View {
    if let exercise {
      if let previous = store.previousBest(exercise) {
        Text(store.t("Last time")).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
        Text(shortValue(previous.set)).font(.system(.title2, weight: .bold)).monospacedDigit()
          .foregroundStyle(JourneyColor.text).lineLimit(1).minimumScaleFactor(0.6)
          .accessibilityIdentifier("set.lastTime")
        Text(previous.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
          .font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary)
      } else {
        Text(store.t("First time")).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
        Text(store.t(weightMissing ? "Add a weight" : "Set 1")).font(.system(.title2, weight: .bold))
          .foregroundStyle(JourneyColor.text)
      }
    } else {
      Text(store.t("Pick an exercise")).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
    }
  }

  // MARK: Values

  @ViewBuilder private var values: some View {
    if let exercise, !exercise.timed {
      // Side by side, always; stacked only at accessibility text sizes.
      if typeSize.isAccessibilitySize {
        VStack(spacing: 12) { weightStepper; repsStepper }
      } else {
        HStack(spacing: 12) { weightStepper; repsStepper }
      }
    } else if timed {
      Text(store.t(active ? "Tap Finish when you stop." : "The clock times this exercise."))
        .font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).frame(maxWidth: .infinity, minHeight: 84)
    }
  }

  private var weightStepper: some View {
    let bodyweight = !weightMissing && session.weightKG == 0
    let unit = store.profile.unit + (exercise?.perDumbbell == true ? " " + store.t("each") : "")
    return ValueStepper(label: bodyweight && field != .weight ? store.t("bodyweight") : unit, id: "set.weight", length: weightText.count,
                        noun: store.t("weight"), decrease: { step { store.stepWeight(-1) } }, increase: { step { store.stepWeight(1) } },
                        focus: { field = .weight }) {
      TextField(weightMissing ? "—" : "0", text: $weightText)
        .keyboardType(.decimalPad).focused($field, equals: .weight)
        .modifier(SelectNumberOnFocus())
        .overlay {
          if bodyweight && field != .weight {
            Text(store.t("BW")).font(.system(size: 30, weight: .semibold)).foregroundStyle(JourneyColor.text)
              .allowsHitTesting(false).accessibilityHidden(true)
          }
        }
        .accessibilityLabel(store.t("Weight")).accessibilityIdentifier("set.weight")
        .accessibilityValue(weightMissing ? store.t("Not set") : bodyweight ? store.t("Bodyweight") : weightText + " " + unit)
    }.overlay {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .strokeBorder(JourneyColor.signalRed.opacity(weightMissing && stage != .exercise ? 0.7 : 0), lineWidth: 1.5)
    }
  }

  private var repsStepper: some View {
    ValueStepper(label: store.t("reps"), id: "set.reps", length: repsText.count, noun: store.t("reps"),
                 decrease: { step { store.stepReps(-1) } }, increase: { step { store.stepReps(1) } },
                 focus: { field = .reps }) {
      TextField("—", text: $repsText).keyboardType(.numberPad).focused($field, equals: .reps)
        .modifier(SelectNumberOnFocus())
        .accessibilityLabel(store.t("Reps")).accessibilityIdentifier("set.reps")
    }
  }

  /// The last logged set, one tap from a correction; or Undo right after a delete.
  @ViewBuilder private var footnote: some View {
    Group {
      if store.deletedSet != nil {
        Button(store.t("Undo delete")) { store.undoDelete() }.font(JourneyType.label)
          .foregroundStyle(JourneyColor.text).accessibilityIdentifier("set.undo")
      } else if stage == .rest, let last = session.sets.last {
        Button { field = nil; editing = last } label: {
          HStack(spacing: 6) {
            Text(store.t("Last set")).foregroundStyle(JourneyColor.secondary)
            Text((last.exercise.id == exercise?.id ? "" : store.t(last.exercise.name) + " · ") + setValue(last, store: store))
              .foregroundStyle(JourneyColor.text).lineLimit(1)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(JourneyColor.tertiary)
          }.font(JourneyType.label).monospacedDigit().contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier("set.saved")
          .accessibilityLabel(store.t("Edit last set") + ", " + setValue(last, store: store))
      } else {
        Color.clear
      }
    }
  }

  // MARK: Actions

  private enum Primary: Equatable { case choose, start, log, finish, next(Exercise), pick, end }
  private var primary: Primary {
    switch stage {
    case .workout, .exercise: return .choose
    case .active, .log: return .finish
    case .setup, .rest:
      if stage == .rest, done >= target {
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
    }
  }
  private var showsAnotherSet: Bool {
    switch primary { case .next, .pick, .end: return true; default: return false }
  }

  private var actions: some View {
    VStack(spacing: 10) {
      caption.frame(minHeight: 20)
      JourneyButton(title: primaryTitle, id: "workout.primary", action: runPrimary)
      Group {
        if showsAnotherSet {
          JourneyTextButton(title: store.t("Another set"), id: "workout.another") { begin() }
        } else {
          Color.clear.frame(height: 44)
        }
      }
    }.padding(.top, 8)
  }

  /// One honest line above the button: what's missing, or that blocking is simulated.
  @ViewBuilder private var caption: some View {
    if weightMissing && stage != .exercise && !active {
      Text(store.t("Add the weight for this set.")).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
    } else if store.profile.focusEnabled == true {
      let apps = store.profile.blockedApps
      HStack(spacing: 6) {
        Image(systemName: "lock.fill").font(.caption2).accessibilityHidden(true)
        Text((apps.isEmpty ? store.t("Apps") : apps.prefix(2).joined(separator: ", ") + (apps.count > 2 ? " +\(apps.count - 2)" : ""))
             + " · " + store.t("blocking simulated"))
      }.font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary).lineLimit(1)
        .accessibilityElement(children: .combine).accessibilityIdentifier("session.blocking")
    } else {
      Color.clear
    }
  }

  private func runPrimary() {
    // Sweaty double taps never start and finish a set at once.
    guard Date() >= guardUntil else { return }
    switch primary {
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

  private func step(_ change: () -> Void) {
    field = nil
    change()
    JourneyHaptic.play(.selection, store.profile)
  }

  // MARK: Sync and rest alarm

  private func sync() {
    if field != .weight {
      weightText = weightMissing || session.weightKG == 0 ? "" : inputNumber(GymStore.displayedWeight(session.weightKG, unit: store.profile.unit))
    }
    if field != .reps { repsText = store.draftRepCount.map(String.init) ?? "" }
  }

  private var restKey: String {
    "\(session.stage == .rest ? session.restStarted?.timeIntervalSince1970 ?? 0 : 0)-\(store.restTarget)"
  }
  /// In the app, rest's up is a double tap you can feel. With the phone locked, the notification does it.
  private func restAlarm() async {
    guard session.stage == .rest, let start = session.restStarted else { return }
    let due = start.addingTimeInterval(Double(store.restTarget))
    guard due.timeIntervalSinceNow > 0 else { return }
    try? await Task.sleep(for: .seconds(due.timeIntervalSinceNow))
    guard !Task.isCancelled, store.session?.stage == .rest, store.session?.restStarted == start,
      UIApplication.shared.applicationState == .active, abs(due.timeIntervalSinceNow) < 2
    else { return }
    JourneyHaptic.notification(store.profile)
    try? await Task.sleep(for: .milliseconds(450))
    JourneyHaptic.notification(store.profile)
    _ = await OnboardingFeedback.shared.playSound(profile: store.profile)
  }

  private func shortValue(_ set: LoggedSet) -> String {
    if set.exercise.timed { return formatNumber(set.minutes) + " " + store.t("min") }
    let weight = set.weightKG == 0 ? store.t("BW") : formatNumber(GymStore.displayedWeight(set.weightKG, unit: store.profile.unit)) + " " + store.profile.unit
    return weight + " × \(set.reps)"
  }
}

/// Completed sets as filled dots, the live set in red, the rest of the target as outlines.
struct SetDots: View {
  @EnvironmentObject private var store: GymStore
  let done: Int
  let target: Int
  let live: Bool
  var body: some View {
    let current = done + 1
    let count = max(target, done + (live ? 1 : 0))
    let text = done >= target && !live ? "\(done) " + store.t("of") + " \(target) " + store.t("done")
      : store.t("Set") + " \(current) " + store.t("of") + " \(target)"
    HStack(spacing: 12) {
      HStack(spacing: 6) {
        ForEach(0..<min(count, 12), id: \.self) { i in
          Circle()
            .fill(i < done ? JourneyColor.text : i == done && live ? JourneyColor.signalRed : Color.clear)
            .overlay(Circle().strokeBorder(i < done || (i == done && live) ? Color.clear : Color.white.opacity(i == done ? 0.6 : 0.22), lineWidth: 1.5))
            .frame(width: 9, height: 9)
        }
      }
      Text(text).font(JourneyType.label).foregroundStyle(JourneyColor.secondary).monospacedDigit()
    }.accessibilityElement(children: .ignore)
      .accessibilityLabel(text)
      .accessibilityIdentifier("set.progress")
      .animation(.smooth(duration: 0.35), value: done)
  }
}

/// The stage: a ring on glass. Active sets sweep once a minute; rests fill to the rest length,
/// then the ring turns red.
struct WorkoutRing<Content: View>: View {
  let progress: Double
  let signal: Bool
  let size: CGFloat
  let tick: Int
  @ViewBuilder var content: Content
  var body: some View {
    let line: CGFloat = 9
    ZStack {
      Circle().fill(Color.clear).frame(width: size - 34, height: size - 34)
        .journeyGlass(Circle())
      Circle().stroke(Color.white.opacity(0.1), lineWidth: line)
      Circle().trim(from: 0, to: max(0.0001, progress))
        .stroke(signal ? JourneyColor.signalRed : JourneyColor.text, style: StrokeStyle(lineWidth: line, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .opacity(progress > 0 ? 1 : 0)
        // Each second eases forward like a watch hand, then rests, so the app is idle most of the
        // time (cheap on battery, and UI tests can run); it jumps back when a minute wraps.
        .animation(progress < 0.02 ? nil : .smooth(duration: 0.4), value: tick)
        .animation(.smooth(duration: 0.4), value: signal)
      VStack(spacing: 4) { content }.padding(.horizontal, 28)
    }.frame(width: size, height: size).padding(line / 2)
  }
}

/// Weight or reps: − value +, on glass. Tap the value to type it.
struct ValueStepper<Field: View>: View {
  let label: String
  let id: String
  /// Characters shown, so long values step down in size instead of breaking the row.
  let length: Int
  let noun: String
  let decrease: () -> Void
  let increase: () -> Void
  /// The whole middle of the stepper is the target for typing, not just the digits.
  let focus: () -> Void
  @ViewBuilder var field: Field
  @EnvironmentObject private var store: GymStore
  var body: some View {
    HStack(spacing: 4) {
      StepButton(symbol: "minus", label: store.t("Less") + " " + noun, id: id + ".minus", action: decrease)
      VStack(spacing: 0) {
        field.font(.system(size: length <= 3 ? 30 : length == 4 ? 25 : 21, weight: .semibold)).monospacedDigit()
          .multilineTextAlignment(.center)
          .foregroundStyle(JourneyColor.text).minimumScaleFactor(0.5).frame(minHeight: 40)
        Text(label).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).lineLimit(1)
      }.frame(maxWidth: .infinity, minHeight: 64).contentShape(Rectangle()).onTapGesture(perform: focus)
      StepButton(symbol: "plus", label: store.t("More") + " " + noun, id: id + ".plus", action: increase)
    }.padding(8).frame(minHeight: 84)
      .journeyGlass(RoundedRectangle(cornerRadius: 26, style: .continuous))
  }
}
