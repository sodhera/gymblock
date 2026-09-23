import Foundation

// Plain Codable value types, persisted as JSON by `Persistence`. Every
// decoder is tolerant of missing keys so older saved data keeps loading when
// fields are added (same rule SleepBlock follows).

// MARK: - Muscles & equipment

enum Muscle: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest, shoulders, biceps, triceps, forearms
    case abs, obliques
    case lats, upperBack, lowerBack, traps
    case quads, hamstrings, glutes, calves, adductors, abductors
    case neck, cardio, fullBody

    var id: String { rawValue }

    var name: String {
        switch self {
        case .chest: "Chest"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .abs: "Abs"
        case .obliques: "Obliques"
        case .lats: "Lats"
        case .upperBack: "Upper back"
        case .lowerBack: "Lower back"
        case .traps: "Traps"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .calves: "Calves"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .neck: "Neck"
        case .cardio: "Cardio"
        case .fullBody: "Full body"
        }
    }

    /// Filter chips in the exercise library, in body order.
    static let filterOrder: [Muscle] = [
        .chest, .shoulders, .triceps, .biceps, .forearms, .lats, .upperBack, .traps, .lowerBack,
        .abs, .obliques, .quads, .hamstrings, .glutes, .calves, .adductors, .abductors, .fullBody, .cardio,
    ]
}

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, ezBar, smith, plate, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .machine: "Machine"
        case .cable: "Cable"
        case .bodyweight: "Bodyweight"
        case .kettlebell: "Kettlebell"
        case .band: "Band"
        case .ezBar: "EZ bar"
        case .smith: "Smith machine"
        case .plate: "Plate"
        case .other: "Other"
        }
    }
}

/// How a set is measured. Most lifts are weight × reps; some are reps only
/// (pull-ups), some are timed (planks), some are distance/time (cardio).
enum MetricKind: String, Codable, Hashable {
    case weightReps, reps, time, distanceTime
}

struct Exercise: Codable, Identifiable, Hashable {
    var id: String
    /// Base name without equipment: "Bench Press".
    var name: String
    var equipment: Equipment
    var primary: [Muscle]
    var secondary: [Muscle]
    var metric: MetricKind
    var isCustom: Bool

    init(
        id: String, name: String, equipment: Equipment, primary: [Muscle], secondary: [Muscle] = [],
        metric: MetricKind = .weightReps, isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.equipment = equipment
        self.primary = primary
        self.secondary = secondary
        self.metric = metric
        self.isCustom = isCustom
    }

    /// "Bench Press (Barbell)" — the Hevy-style display name users already
    /// know. Bodyweight/other lifts go without the parenthetical.
    var displayName: String {
        switch equipment {
        case .bodyweight, .other: name
        default: "\(name) (\(equipment.name))"
        }
    }

    var usesWeight: Bool { metric == .weightReps }
}

// MARK: - Sets & workouts

enum SetKind: String, Codable, Hashable, CaseIterable {
    case normal, warmup, drop, failure

    /// Marker shown in the set column instead of the number.
    var marker: String? {
        switch self {
        case .normal: nil
        case .warmup: "W"
        case .drop: "D"
        case .failure: "F"
        }
    }

    var name: String {
        switch self {
        case .normal: "Normal set"
        case .warmup: "Warm-up"
        case .drop: "Drop set"
        case .failure: "To failure"
        }
    }
}

struct SetEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: SetKind = .normal
    /// Always stored in kilograms; converted for display by `WeightUnit`.
    var weight: Double?
    var reps: Int?
    /// Seconds, for timed / cardio sets.
    var seconds: Int?
    var distanceMeters: Double?
    var isDone = false

    init(kind: SetKind = .normal, weight: Double? = nil, reps: Int? = nil, seconds: Int? = nil, isDone: Bool = false) {
        self.kind = kind
        self.weight = weight
        self.reps = reps
        self.seconds = seconds
        self.isDone = isDone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(SetKind.self, forKey: .kind) ?? .normal
        weight = try c.decodeIfPresent(Double.self, forKey: .weight)
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        seconds = try c.decodeIfPresent(Int.self, forKey: .seconds)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
    }

    /// Weight × reps, for volume. Warm-ups don't count toward volume.
    var volume: Double {
        guard kind != .warmup, let weight, let reps else { return 0 }
        return weight * Double(reps)
    }

    /// Epley estimated one-rep max — the number PRs are judged on, so 100×5
    /// beats 105×1.
    var estimatedOneRepMax: Double? {
        guard kind != .warmup, let weight, let reps, reps > 0, weight > 0 else { return nil }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }
}

struct ExerciseLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: [SetEntry]
    var note: String = ""
    /// Rest timer length after each set, seconds. 0 = off.
    var restSeconds: Int = 90

    init(exerciseID: String, sets: [SetEntry], note: String = "", restSeconds: Int = 90) {
        self.exerciseID = exerciseID
        self.sets = sets
        self.note = note
        self.restSeconds = restSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exerciseID = try c.decode(String.self, forKey: .exerciseID)
        sets = try c.decodeIfPresent([SetEntry].self, forKey: .sets) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
    }

    var completedSets: [SetEntry] { sets.filter(\.isDone) }
}

struct Workout: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var templateID: UUID?
    var start: Date
    var end: Date?
    var exercises: [ExerciseLog]
    var note: String = ""
    /// Whether friends may see the full log (exercises, sets, notes). Friends
    /// always see that a workout happened; the contents are opt-in.
    var isShared: Bool = false

    init(title: String, templateID: UUID? = nil, start: Date = .now, exercises: [ExerciseLog] = [], isShared: Bool = false) {
        self.title = title
        self.templateID = templateID
        self.start = start
        self.exercises = exercises
        self.isShared = isShared
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Workout"
        templateID = try c.decodeIfPresent(UUID.self, forKey: .templateID)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decodeIfPresent(Date.self, forKey: .end)
        exercises = try c.decodeIfPresent([ExerciseLog].self, forKey: .exercises) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        isShared = try c.decodeIfPresent(Bool.self, forKey: .isShared) ?? false
    }

    var duration: TimeInterval { (end ?? .now).timeIntervalSince(start) }
    var completedSetCount: Int { exercises.reduce(0) { $0 + $1.completedSets.count } }
    var totalSetCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var remainingSetCount: Int { totalSetCount - completedSetCount }
    var volume: Double {
        exercises.reduce(0) { total, log in total + log.completedSets.reduce(0) { $0 + $1.volume } }
    }

    /// A workout counts toward the week when it has real work in it. A
    /// session opened and abandoned in the car park doesn't.
    var counts: Bool {
        completedSetCount >= Workout.minimumSetsToCount
    }

    static let minimumSetsToCount = 3
}

// MARK: - Templates

struct TemplateExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: Int = 3
    var reps: Int? = nil
    var restSeconds: Int = 90

    init(exerciseID: String, sets: Int = 3, reps: Int? = nil, restSeconds: Int = 90) {
        self.exerciseID = exerciseID
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exerciseID = try c.decode(String.self, forKey: .exerciseID)
        sets = try c.decodeIfPresent(Int.self, forKey: .sets) ?? 3
        reps = try c.decodeIfPresent(Int.self, forKey: .reps)
        restSeconds = try c.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 90
    }
}

struct WorkoutTemplate: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var exercises: [TemplateExercise]
    var lastUsed: Date?

    init(name: String, exercises: [TemplateExercise], lastUsed: Date? = nil) {
        self.name = name
        self.exercises = exercises
        self.lastUsed = lastUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Template"
        exercises = try c.decodeIfPresent([TemplateExercise].self, forKey: .exercises) ?? []
        lastUsed = try c.decodeIfPresent(Date.self, forKey: .lastUsed)
    }
}

// MARK: - Profile

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg, lb
    var id: String { rawValue }

    static let lbPerKg = 2.2046226218

    func display(_ kg: Double) -> Double {
        self == .kg ? kg : kg * Self.lbPerKg
    }

    func storage(_ value: Double) -> Double {
        self == .kg ? value : value / Self.lbPerKg
    }

    /// Increment used by the ± steppers and plate math.
    var step: Double { self == .kg ? 2.5 : 5 }
}

enum TrainingGoal: String, Codable, CaseIterable, Identifiable {
    case muscle, strength, consistency, leaner
    var id: String { rawValue }

    var title: String {
        switch self {
        case .muscle: "Build muscle"
        case .strength: "Get stronger"
        case .consistency: "Actually show up"
        case .leaner: "Get leaner"
        }
    }

    var icon: String {
        switch self {
        case .muscle: "figure.strengthtraining.traditional"
        case .strength: "scalemass.fill"
        case .consistency: "calendar"
        case .leaner: "flame.fill"
        }
    }
}

struct Profile: Codable, Equatable {
    var name: String = ""
    var username: String = ""
    var weeklyTarget: Int = 4
    var unit: WeightUnit = .kg
    var goal: TrainingGoal = .muscle
    var sessionMinutes: Int = 60
    var phoneMinutes: Int = 15
    var defaultRestSeconds: Int = 90
    /// Default for new workouts' `isShared`.
    var shareWorkoutsByDefault: Bool = true
    var onboarded: Bool = false
    /// Block the chosen apps when a workout starts.
    var blockingEnabled: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? d.username
        weeklyTarget = try c.decodeIfPresent(Int.self, forKey: .weeklyTarget) ?? d.weeklyTarget
        unit = try c.decodeIfPresent(WeightUnit.self, forKey: .unit) ?? d.unit
        goal = try c.decodeIfPresent(TrainingGoal.self, forKey: .goal) ?? d.goal
        sessionMinutes = try c.decodeIfPresent(Int.self, forKey: .sessionMinutes) ?? d.sessionMinutes
        phoneMinutes = try c.decodeIfPresent(Int.self, forKey: .phoneMinutes) ?? d.phoneMinutes
        defaultRestSeconds = try c.decodeIfPresent(Int.self, forKey: .defaultRestSeconds) ?? d.defaultRestSeconds
        shareWorkoutsByDefault = try c.decodeIfPresent(Bool.self, forKey: .shareWorkoutsByDefault) ?? d.shareWorkoutsByDefault
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? d.onboarded
        blockingEnabled = try c.decodeIfPresent(Bool.self, forKey: .blockingEnabled) ?? d.blockingEnabled
    }
}
