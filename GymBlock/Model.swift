import SwiftUI

struct Exercise: Codable, Identifiable, Equatable {
  var id: String
  var name: String
  var area: String
  var timed: Bool = false
  var icon: String { timed ? "figure.run" : "dumbbell.fill" }
  static let catalog: [Exercise] = [
    .init(id: "curl", name: "Dumbbell curl", area: "Arms"),
    .init(id: "hammer", name: "Dumbbell hammer curl", area: "Arms"),
    .init(id: "incline-curl", name: "Incline dumbbell curl", area: "Arms"),
    .init(id: "triceps", name: "Triceps extension", area: "Arms"),
    .init(id: "bench", name: "Bench press", area: "Chest & shoulders"),
    .init(id: "dumbbell-bench", name: "Dumbbell bench press", area: "Chest & shoulders"),
    .init(id: "dumbbell-press", name: "Dumbbell shoulder press", area: "Chest & shoulders"),
    .init(id: "lateral", name: "Dumbbell lateral raise", area: "Chest & shoulders"),
    .init(id: "press", name: "Shoulder press", area: "Chest & shoulders"),
    .init(id: "row", name: "Dumbbell row", area: "Back"),
    .init(id: "pulldown", name: "Lat pulldown", area: "Back"),
    .init(id: "squat", name: "Squat", area: "Legs & compound"),
    .init(id: "deadlift", name: "Deadlift", area: "Legs & compound"),
    .init(id: "lunge", name: "Lunge", area: "Legs & compound"),
    .init(id: "crunch", name: "Crunch", area: "Core"),
    .init(id: "run", name: "Running", area: "Cardio", timed: true),
    .init(id: "cycle", name: "Cycling", area: "Cardio", timed: true),
    .init(id: "stretch", name: "Full-body stretch", area: "Stretching", timed: true),
    .init(id: "boxing", name: "Boxing", area: "Martial arts", timed: true),
  ]
  static let areas = [
    "Arms", "Chest & shoulders", "Back", "Legs & compound", "Core", "Cardio", "Stretching",
    "Martial arts",
  ]
}

struct Profile: Codable {
  var language = ""
  var name = ""
  var training: [String] = []
  var favorites: [String] = []
  var blockWholePhone = true
  var blockedApps: [String] = ["Instagram", "TikTok"]
  var unit = "kg"
  var onboardingStep = 0
  var onboarded = false
  var preferredSplitID: UUID?
  var baseline: RoutineBaseline?
  var restSeconds: Int?
  var focusEnabled: Bool?
  var onboardingVersion: Int?
  var onboardingStepID: String?
  var onboardingScrollAnswered: Bool?
  var onboardingPreviewTarget: Double?
  var onboardingRevealSeen: Bool?
  var onboardingStoryStage: Int?
  var onboardingSkippedQuestions: Bool?
  var soundEnabled: Bool?
  var hapticsEnabled: Bool?
  var gender: String?
  var heightCM: Double?
  var bodyWeightKG: Double?
}
struct LoggedSet: Codable, Identifiable {
  var id = UUID()
  var exercise: Exercise
  var weightKG: Double
  var reps: Int
  var minutes: Double
  var date = Date()
  var unsuccessful: Bool?
  var warmup: Bool?
  var timingUnknown: Bool?
  var elapsedSetSeconds: Double?
  var gapBeforeSeconds: Double?
  var gapSourceID: UUID?
  var gapUnknown: Bool?
  var completed: Bool { unsuccessful != true && (exercise.timed ? minutes > 0 : reps > 0) }
  var comparable: Bool { completed && warmup != true }
}
struct Workout: Codable, Identifiable {
  var id = UUID()
  var name: String
  var exercises: [Exercise]
}
struct Session: Codable, Identifiable {
  var id = UUID()
  var started = Date()
  var ended: Date?
  var name = "My workout"
  var sets: [LoggedSet] = []
  var exercises: [Exercise] = []
  var selected: Exercise?
  var stage: Stage = .workout
  var setStarted: Date?
  var setStopped: Date?
  var pendingGapStarted: Date?
  var pendingGapSourceID: UUID?
  var pendingGapSeconds: Double?
  var restEnds: Date?  // Decode-only legacy countdown deadline.
  var restStarted: Date?
  var weightKG = 0.0
  var splitID: UUID?
  var draftReps: Int?
  var draftMinutes: Double?
  var draftRepsText: String?
  var weightIsSet: Bool?
  var drafts: [String: ExerciseDraft]?
  var restSourceID: UUID?
  var completedSets: [LoggedSet] { sets.filter(\.completed) }
  var repSets: [LoggedSet] { completedSets.filter { !$0.exercise.timed } }
  var totalReps: Int { repSets.reduce(0) { $0 + $1.reps } }
  var volumeKG: Double { repSets.reduce(0) { $0 + $1.weightKG * Double($1.reps) } }
  var duration: TimeInterval { max(0, (ended ?? Date()).timeIntervalSince(started)) }
  var isBlockingSimulated: Bool { ended == nil }
}
enum Stage: String, Codable { case workout, exercise, setup, active, log, rest }
struct LocalData: Codable {
  var profile = Profile()
  var history: [Session] = []
  var workouts: [Workout] = []
  var session: Session?
  var demoLoaded: Bool?
}

@MainActor final class GymStore: ObservableObject {
  @Published var data: LocalData
  @Published var summary: Session?
  @Published var storageError = false
  @Published var deletedSet: LoggedSet?
  private var deletionSessionID: UUID?
  private var deletionRest: Date?
  private var deletionWasRest = false
  let defaults: UserDefaults
  static let storageKey = "gymblock.local.v1"
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let encoded = defaults.data(forKey: Self.storageKey),
      let decoded = try? JSONDecoder().decode(LocalData.self, from: encoded)
    {
      data = decoded
    } else {
      data = LocalData()
    }
    if var current = data.session, current.restStarted == nil, current.restEnds != nil {
      current.restStarted =
        current.sets.first { $0.id == current.restSourceID }?.date
        ?? current.restEnds?.addingTimeInterval(-Double(data.profile.restSeconds ?? 60))
      current.restEnds = nil
      data.session = current
      persist()
    }
  }
  var profile: Profile { data.profile }
  var session: Session? { data.session }
  func persist() {
    do {
      defaults.set(try JSONEncoder().encode(data), forKey: Self.storageKey)
      storageError = false
    } catch { storageError = true }
  }
  func updateProfile(_ body: (inout Profile) -> Void) {
    body(&data.profile)
    persist()
  }
  func deleteRoutineAnswers() {
    updateProfile {
      $0.baseline = nil
      $0.onboardingPreviewTarget = nil
      $0.onboardingScrollAnswered = nil
      $0.onboardingRevealSeen = nil
      $0.onboardingStoryStage = nil
    }
  }
  func startSession(workout: Workout? = nil) {
    guard data.session == nil else { return }
    var session = Session()
    session.stage = .exercise
    session.name = workout?.name ?? "Free workout"
    session.splitID = workout?.id
    session.exercises = workout?.exercises ?? []
    data.session = session
    if let first = workout?.exercises.first { chooseExercise(first) } else { persist() }
  }
  func chooseWorkout(_ workout: Workout?) {
    guard data.session != nil else { return }
    data.session?.name = workout?.name ?? "My workout"
    data.session?.splitID = workout?.id
    data.session?.exercises = workout?.exercises ?? []
    data.session?.stage = .exercise
    persist()
  }
  func chooseExercise(_ exercise: Exercise) {
    guard let current = data.session, current.stage != .active && current.stage != .log else {
      return
    }
    saveCurrentDraft()
    let saved = data.session?.drafts?[exercise.id]
    let previous = lastSet(for: exercise)
    data.session?.selected = exercise
    data.session?.weightKG = saved?.weightKG ?? previous?.weightKG ?? 0
    data.session?.weightIsSet =
      saved?.weightIsSet ?? (previous != nil || exercise.timed || exercise.id == "crunch")
    data.session?.draftRepsText =
      saved?.repsText ?? previous.map { String($0.reps) } ?? profile.baseline?.defaultReps.map(
        String.init) ?? ""
    data.session?.draftReps = saved?.reps ?? previous?.reps ?? profile.baseline?.defaultReps ?? 10
    data.session?.draftMinutes =
      saved?.minutes ?? (previous?.minutes).flatMap { $0 > 0 ? $0 : nil } ?? 5
    if data.session?.exercises.contains(exercise) == false {
      data.session?.exercises.append(exercise)
    }
    data.session?.stage = current.restStarted == nil ? .setup : .rest
    persist()
  }
  private func saveCurrentDraft() {
    guard let s = session, let exercise = s.selected else { return }
    if data.session?.drafts == nil { data.session?.drafts = [:] }
    data.session?.drafts?[exercise.id] = ExerciseDraft(
      weightKG: s.weightKG, reps: s.draftReps ?? 10, minutes: s.draftMinutes ?? 5,
      repsText: s.draftRepsText, weightIsSet: s.weightIsSet)
  }
  func updateWeight(_ displayed: Double, unit: String) {
    guard displayed.isFinite, (0...500).contains(displayed), session?.stage != .active else {
      return
    }
    data.session?.weightKG = Self.kilograms(displayed, unit: unit)
    data.session?.weightIsSet = true
    saveCurrentDraft()
    persist()
  }
  func startSet(weight: Double, unit: String) {
    guard weight.isFinite, weight >= 0, weight <= 500, data.session?.selected != nil,
      data.session?.stage == .setup || data.session?.stage == .rest
    else { return }
    data.session?.weightKG = Self.kilograms(weight, unit: unit)
    data.session?.weightIsSet = true
    data.session?.pendingGapStarted = session?.restStarted ?? session?.pendingGapStarted
    data.session?.pendingGapSourceID = session?.restSourceID ?? session?.pendingGapSourceID
    data.session?.pendingGapSeconds = (session?.restStarted ?? session?.pendingGapStarted).map {
      max(0, Date().timeIntervalSince($0))
    }
    data.session?.setStopped = nil
    data.session?.restEnds = nil
    data.session?.restStarted = nil
    data.session?.restSourceID = nil
    deletedSet = nil
    data.session?.stage = .active
    data.session?.setStarted = Date()
    if data.session?.selected?.timed == true { data.session?.draftMinutes = 0 }
    persist()
  }
  func showLog() {
    guard session?.stage == .active else { return }
    data.session?.setStopped = Date()
    data.session?.stage = .log
    persist()
  }
  func logSet(reps: Int, minutes: Double) {
    guard let s = data.session, let exercise = s.selected, s.stage == .log else { return }
    guard exercise.timed ? minutes.isFinite && minutes > 0 : (1...999).contains(reps) else {
      return
    }
    let elapsed = s.setStarted.map { max(0, (s.setStopped ?? Date()).timeIntervalSince($0)) }
    data.session?.sets.append(
      .init(
        exercise: exercise, weightKG: exercise.timed ? 0 : s.weightKG,
        reps: exercise.timed ? 0 : reps, minutes: exercise.timed ? minutes : 0,
        elapsedSetSeconds: elapsed, gapBeforeSeconds: s.pendingGapSeconds,
        gapSourceID: s.pendingGapSourceID))
    clearPendingTiming()
    data.session?.stage = .rest
    data.session?.restStarted = Date()
    data.session?.restSourceID = data.session?.sets.last?.id
    data.session?.draftReps = exercise.timed ? s.draftReps : reps
    if !exercise.timed { data.session?.draftRepsText = String(reps) }
    data.session?.draftMinutes = exercise.timed ? minutes : s.draftMinutes
    saveCurrentDraft()
    persist()
  }
  func finishSet(reps: Int, minutes: Double) {
    guard let s = data.session, let exercise = s.selected, s.stage == .active else { return }
    guard exercise.timed ? minutes.isFinite && minutes > 0 : (1...999).contains(reps) else {
      return
    }
    data.session?.setStopped = Date()
    data.session?.stage = .log
    data.session?.draftReps = reps
    data.session?.draftMinutes = minutes
    logSet(reps: reps, minutes: minutes)
  }
  func updateDraft(reps: Int? = nil, minutes: Double? = nil) {
    if let reps, (1...999).contains(reps) {
      data.session?.draftReps = reps
      data.session?.draftRepsText = String(reps)
    }
    if let minutes, minutes.isFinite && minutes > 0 { data.session?.draftMinutes = minutes }
    saveCurrentDraft()
    persist()
  }
  func updateRepText(_ text: String) {
    data.session?.draftRepsText = String(text.prefix(5))
    if let reps = Int(text), (1...999).contains(reps) { data.session?.draftReps = reps }
    saveCurrentDraft()
    persist()
  }
  func lastSet(for exercise: Exercise) -> LoggedSet? {
    data.session?.sets.last(where: { $0.exercise.id == exercise.id && $0.comparable })
      ?? data.history.flatMap(\.sets).filter { $0.exercise.id == exercise.id && $0.comparable }.max(
        by: { $0.date < $1.date })
  }
  var allExercises: [Exercise] {
    var seen = Set<String>()
    return
      (Exercise.catalog + (session?.exercises ?? []) + data.workouts.flatMap(\.exercises)
      + data.history.flatMap(\.sets).map(\.exercise))
      .filter { seen.insert($0.id).inserted }
  }
  func saveSplit(id: UUID, name: String, exercises: [Exercise]) -> Bool {
    let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
    guard !clean.isEmpty, !exercises.isEmpty,
      !data.workouts.contains(where: {
        $0.id != id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame
      })
    else { return false }
    var seen = Set<String>()
    let workout = Workout(
      id: id, name: clean, exercises: exercises.filter { seen.insert($0.id).inserted })
    if let i = data.workouts.firstIndex(where: { $0.id == id }) {
      data.workouts[i] = workout
    } else {
      data.workouts.append(workout)
    }
    persist()
    return true
  }
  func deleteSplit(_ id: UUID) {
    data.workouts.removeAll { $0.id == id }
    if profile.preferredSplitID == id { data.profile.preferredSplitID = nil }
    persist()
  }
  func anotherSet() {
    data.session?.pendingGapStarted = session?.restStarted
    data.session?.pendingGapSourceID = session?.restSourceID
    data.session?.stage = .setup
    data.session?.restEnds = nil
    data.session?.restStarted = nil
    persist()
  }
  func changeExercise() {
    guard session?.stage != .active else { return }
    saveCurrentDraft()
    data.session?.stage = .exercise
    persist()
  }
  func restElapsed(at date: Date = Date()) -> Int {
    guard let start = session?.restStarted else { return 0 }
    return max(0, Int(date.timeIntervalSince(start)))
  }
  /// Resolve the current set before switching; completed sets retain their original exercise.
  @discardableResult func switchExercise(
    to exercise: Exercise, savingCurrent: Bool, reps: Int = 0, minutes: Double = 0
  ) -> Bool {
    guard let current = session, current.selected?.id != exercise.id else { return false }
    if current.stage == .active || current.stage == .log {
      if savingCurrent {
        guard
          current.selected?.timed == true
            ? minutes.isFinite && minutes > 0 : (1...999).contains(reps)
        else { return false }
        if current.stage == .active {
          finishSet(reps: reps, minutes: minutes)
        } else {
          logSet(reps: reps, minutes: minutes)
        }
      } else {
        cancelSet()
      }
    }
    chooseExercise(exercise)
    return session?.selected?.id == exercise.id
  }
  func cancelSet() {
    guard session?.stage == .active || session?.stage == .log else { return }
    let source = session?.pendingGapSourceID
    let exists = source != nil && session?.sets.contains(where: { $0.id == source }) == true
    data.session?.restStarted = exists ? session?.pendingGapStarted : nil
    data.session?.restSourceID = exists ? source : nil
    data.session?.stage = session?.restStarted == nil ? .setup : .rest
    clearPendingTiming()
    persist()
  }
  private func clearPendingTiming() {
    data.session?.setStarted = nil
    data.session?.setStopped = nil
    data.session?.pendingGapStarted = nil
    data.session?.pendingGapSeconds = nil
    data.session?.pendingGapSourceID = nil
  }
  func recordAttempt() {
    guard let s = session, let exercise = s.selected, !exercise.timed, s.stage == .active else {
      return
    }
    let attempt = LoggedSet(
      exercise: exercise, weightKG: s.weightKG, reps: 0, minutes: 0, unsuccessful: true,
      elapsedSetSeconds: s.setStarted.map { max(0, Date().timeIntervalSince($0)) },
      gapBeforeSeconds: s.pendingGapSeconds, gapSourceID: s.pendingGapSourceID)
    data.session?.sets.append(attempt)
    clearPendingTiming()
    data.session?.stage = .rest
    data.session?.restSourceID = attempt.id
    data.session?.restStarted = Date()
    persist()
  }
  func editSet(_ set: LoggedSet, sessionID: UUID) -> Bool {
    guard set.validTiming, set.weightKG.isFinite,
      (0...500).contains(Self.displayedWeight(set.weightKG, unit: profile.unit)),
      set.date <= Date(),
      set.unsuccessful == true
        ? set.reps == 0 && !set.exercise.timed
        : (set.exercise.timed
          ? set.minutes.isFinite && set.minutes > 0 : (1...999).contains(set.reps))
    else { return false }
    if session?.id == sessionID, let i = data.session?.sets.firstIndex(where: { $0.id == set.id }) {
      let changedDate = data.session?.sets[i].date != set.date
      var corrected = set
      if changedDate { corrected.gapUnknown = true }
      data.session?.sets[i] = corrected
      if changedDate {
        for index in data.session!.sets.indices
        where data.session!.sets[index].gapSourceID == set.id {
          data.session?.sets[index].gapUnknown = true
        }
        if data.session?.pendingGapSourceID == set.id { data.session?.pendingGapSeconds = nil }
      }
    } else if let h = data.history.firstIndex(where: { $0.id == sessionID }),
      let i = data.history[h].sets.firstIndex(where: { $0.id == set.id })
    {
      let changedDate = data.history[h].sets[i].date != set.date
      var corrected = set
      if changedDate { corrected.gapUnknown = true }
      data.history[h].sets[i] = corrected
      if changedDate {
        for index in data.history[h].sets.indices
        where data.history[h].sets[index].gapSourceID == set.id {
          data.history[h].sets[index].gapUnknown = true
        }
      }
    } else {
      return false
    }
    persist()
    return true
  }
  func deleteSet(_ set: LoggedSet, sessionID: UUID) {
    deletedSet = set
    deletionSessionID = sessionID
    deletionWasRest = false
    deletionRest = nil
    if session?.id == sessionID {
      deletionWasRest = session?.stage == .rest && session?.restSourceID == set.id
      if deletionWasRest {
        deletionRest = session?.restStarted
        data.session?.restEnds = nil
        data.session?.restStarted = nil
        data.session?.restSourceID = nil
        data.session?.stage = .setup
      }
      data.session?.sets.removeAll { $0.id == set.id }
    } else if let h = data.history.firstIndex(where: { $0.id == sessionID }) {
      data.history[h].sets.removeAll { $0.id == set.id }
    }
    persist()
  }
  func undoDelete() {
    guard let set = deletedSet, let id = deletionSessionID else { return }
    if session?.id == id {
      data.session?.sets.append(set)
      data.session?.sets.sort { $0.date < $1.date }
      if deletionWasRest && session?.stage == .setup && session?.restSourceID == nil {
        data.session?.stage = .rest
        data.session?.restStarted = deletionRest
        data.session?.restSourceID = set.id
      }
    } else if let h = data.history.firstIndex(where: { $0.id == id }) {
      data.history[h].sets.append(set)
      data.history[h].sets.sort { $0.date < $1.date }
    }
    deletedSet = nil
    persist()
  }
  func addCompletedSet(
    exercise: Exercise, weight: Double, reps: Int, minutes: Double, warmup: Bool = false
  ) -> Bool {
    guard session != nil, weight.isFinite, (0...500).contains(weight),
      exercise.timed ? minutes.isFinite && minutes > 0 : (1...999).contains(reps)
    else { return false }
    data.session?.sets.append(
      LoggedSet(
        exercise: exercise,
        weightKG: exercise.timed ? 0 : Self.kilograms(weight, unit: profile.unit),
        reps: exercise.timed ? 0 : reps, minutes: exercise.timed ? minutes : 0, warmup: warmup,
        timingUnknown: true)
    )
    persist()
    return true
  }
  func finish() {
    guard var session = data.session else { return }
    session.ended = Date()
    session.restEnds = nil
    session.restStarted = nil
    if !session.sets.isEmpty { data.history.insert(session, at: 0) }
    summary = session.sets.isEmpty ? nil : session
    data.session = nil  // The simulated block ends before the summary appears.
    persist()
  }
  func saveWorkout(from session: Session, name: String) {
    var seen = Set<String>()
    let exercises = session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }
    guard !exercises.isEmpty else { return }
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    var workout = Workout(
      name: cleanName.isEmpty ? session.name : String(cleanName.prefix(50)), exercises: exercises)
    if let index = data.workouts.firstIndex(where: {
      $0.name.localizedCaseInsensitiveCompare(workout.name) == .orderedSame
    }) {
      workout.id = data.workouts[index].id
      data.workouts[index] = workout
    } else {
      data.workouts.append(workout)
    }
    persist()
  }
  var favoriteWorkout: Workout? {
    let exercises = Exercise.catalog.filter { profile.favorites.contains($0.id) }
    return exercises.isEmpty ? nil : Workout(name: "My favorites", exercises: exercises)
  }
  func trained(on date: Date, calendar: Calendar = .current) -> Bool {
    data.history.contains {
      !$0.completedSets.isEmpty && calendar.isDate($0.ended ?? $0.started, inSameDayAs: date)
    }
  }
  var weekDays: [Date] {
    let calendar = Calendar.current
    let start = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }
  var weekCount: Int { weekDays.filter { trained(on: $0) }.count }
  static func kilograms(_ weight: Double, unit: String) -> Double {
    unit == "lb" ? weight * 0.45359237 : weight
  }
  static func displayedWeight(_ kg: Double, unit: String) -> Double {
    unit == "lb" ? kg / 0.45359237 : kg
  }
}
