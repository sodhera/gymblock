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
        .init(id: "boxing", name: "Boxing", area: "Martial arts", timed: true)
    ]
    static let areas = ["Arms", "Chest & shoulders", "Back", "Legs & compound", "Core", "Cardio", "Stretching", "Martial arts"]
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
}
struct LoggedSet: Codable, Identifiable {
    var id = UUID()
    var exercise: Exercise
    var weightKG: Double
    var reps: Int
    var minutes: Double
    var date = Date()
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
    var restEnds: Date?
    var weightKG = 0.0
    var splitID: UUID?
    var draftReps: Int?
    var draftMinutes: Double?
    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    var volumeKG: Double { sets.reduce(0) { $0 + $1.weightKG * Double($1.reps) } }
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
    let defaults: UserDefaults
    static let storageKey = "gymblock.local.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let encoded = defaults.data(forKey: Self.storageKey), let decoded = try? JSONDecoder().decode(LocalData.self, from: encoded) { data = decoded }
        else { data = LocalData() }
    }
    var profile: Profile { data.profile }
    var session: Session? { data.session }
    func persist() {
        do { defaults.set(try JSONEncoder().encode(data), forKey: Self.storageKey); storageError = false }
        catch { storageError = true }
    }
    func updateProfile(_ body: (inout Profile) -> Void) { body(&data.profile); persist() }
    func startSession(workout: Workout? = nil) {
        guard data.session == nil else { return }
        var session = Session()
        session.stage = .exercise
        session.name = workout?.name ?? "Free workout"
        session.splitID = workout?.id
        session.exercises = workout?.exercises ?? []
        data.session = session
        persist()
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
        guard data.session != nil else { return }
        data.session?.selected = exercise
        let previous = lastSet(for: exercise)
        data.session?.weightKG = previous?.weightKG ?? 10
        data.session?.draftReps = previous?.reps ?? 10
        data.session?.draftMinutes = previous?.minutes ?? 5
        if data.session?.exercises.contains(exercise) == false { data.session?.exercises.append(exercise) }
        data.session?.restEnds = nil
        data.session?.stage = .setup
        persist()
    }
    func startSet(weight: Double, unit: String) {
        guard weight.isFinite, weight >= 0, weight <= 500, data.session?.selected != nil,
              data.session?.stage == .setup || data.session?.stage == .rest else { return }
        data.session?.weightKG = Self.kilograms(weight, unit: unit)
        data.session?.restEnds = nil
        data.session?.stage = .active
        data.session?.setStarted = Date()
        persist()
    }
    func showLog() { data.session?.stage = .log; persist() }
    func logSet(reps: Int, minutes: Double) {
        guard let s = data.session, let exercise = s.selected, s.stage == .log else { return }
        guard exercise.timed ? minutes.isFinite && minutes > 0 : (1...100).contains(reps) else { return }
        data.session?.sets.append(.init(exercise: exercise, weightKG: exercise.timed ? 0 : s.weightKG, reps: exercise.timed ? 0 : reps, minutes: exercise.timed ? minutes : 0))
        data.session?.stage = .rest
        data.session?.restEnds = Date().addingTimeInterval(60)
        persist()
    }
    func finishSet(reps: Int, minutes: Double) {
        guard let s = data.session, let exercise = s.selected, s.stage == .active else { return }
        guard exercise.timed ? minutes.isFinite && minutes > 0 : (1...100).contains(reps) else { return }
        data.session?.stage = .log
        data.session?.draftReps = reps
        data.session?.draftMinutes = minutes
        logSet(reps: reps, minutes: minutes)
    }
    func updateDraft(reps: Int? = nil, minutes: Double? = nil) {
        if let reps, (1...100).contains(reps) { data.session?.draftReps = reps }
        if let minutes, minutes.isFinite && minutes > 0 { data.session?.draftMinutes = minutes }
        persist()
    }
    func lastSet(for exercise: Exercise) -> LoggedSet? {
        data.session?.sets.last(where: { $0.exercise.id == exercise.id }) ??
        data.history.flatMap(\.sets).filter { $0.exercise.id == exercise.id }.max(by: { $0.date < $1.date })
    }
    var allExercises: [Exercise] {
        var seen = Set<String>()
        return (Exercise.catalog + data.workouts.flatMap(\.exercises) + data.history.flatMap(\.sets).map(\.exercise))
            .filter { seen.insert($0.id).inserted }
    }
    func saveSplit(id: UUID, name: String, exercises: [Exercise]) -> Bool {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        guard !clean.isEmpty, !exercises.isEmpty,
              !data.workouts.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return false }
        var seen = Set<String>()
        let workout = Workout(id: id, name: clean, exercises: exercises.filter { seen.insert($0.id).inserted })
        if let i = data.workouts.firstIndex(where: { $0.id == id }) { data.workouts[i] = workout }
        else { data.workouts.append(workout) }
        persist()
        return true
    }
    func deleteSplit(_ id: UUID) {
        data.workouts.removeAll { $0.id == id }
        if profile.preferredSplitID == id { data.profile.preferredSplitID = nil }
        persist()
    }
    func anotherSet() { data.session?.stage = .setup; data.session?.restEnds = nil; persist() }
    func changeExercise() { data.session?.stage = .exercise; data.session?.restEnds = nil; persist() }
    func setRest(seconds: Int?) { data.session?.restEnds = seconds.map { Date().addingTimeInterval(Double($0)) }; persist() }
    func finish() {
        guard var session = data.session else { return }
        session.ended = Date()
        session.restEnds = nil
        if !session.sets.isEmpty { data.history.insert(session, at: 0) }
        summary = session
        data.session = nil // The simulated block ends before the summary appears.
        persist()
    }
    func saveWorkout(from session: Session, name: String) {
        var seen = Set<String>()
        let exercises = session.sets.map(\.exercise).filter { seen.insert($0.id).inserted }
        guard !exercises.isEmpty else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var workout = Workout(name: cleanName.isEmpty ? session.name : String(cleanName.prefix(50)), exercises: exercises)
        if let index = data.workouts.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(workout.name) == .orderedSame }) {
            workout.id = data.workouts[index].id
            data.workouts[index] = workout
        }
        else { data.workouts.append(workout) }
        persist()
    }
    var favoriteWorkout: Workout? {
        let exercises = Exercise.catalog.filter { profile.favorites.contains($0.id) }
        return exercises.isEmpty ? nil : Workout(name: "My favorites", exercises: exercises)
    }
    func trained(on date: Date, calendar: Calendar = .current) -> Bool {
        data.history.contains { calendar.isDate($0.ended ?? $0.started, inSameDayAs: date) }
    }
    var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    var weekCount: Int { weekDays.filter { trained(on: $0) }.count }
    static func kilograms(_ weight: Double, unit: String) -> Double { unit == "lb" ? weight * 0.45359237 : weight }
    static func displayedWeight(_ kg: Double, unit: String) -> Double { unit == "lb" ? kg / 0.45359237 : kg }
}
