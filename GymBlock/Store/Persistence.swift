import Foundation

/// JSON files in Application Support. Small, human-inspectable, and atomic
/// per file. A year of training is a few hundred KB; if it ever gets big
/// enough to matter, move workouts to SwiftData without touching the models.
enum Persistence {
    enum File: String {
        case profile = "profile.json"
        case workouts = "workouts.json"
        case templates = "templates.json"
        case customExercises = "custom-exercises.json"
        case activeWorkout = "active-workout.json"
        case flags = "flags.json"
        case account = "account.json"
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GymBlock", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func load<T: Decodable>(_ type: T.Type, from file: File) -> T? {
        let url = directory.appendingPathComponent(file.rawValue)
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            AppLog.store.error("Decode \(file.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func save<T: Encodable>(_ value: T?, to file: File) {
        let url = directory.appendingPathComponent(file.rawValue)
        guard let value else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            AppLog.store.error("Save \(file.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func wipe() {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// One-off flags that gate first-run screens.
struct AppFlags: Codable, Equatable {
    var seenScreenTimePrimer = false
    var seenNotificationPrimer = false

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seenScreenTimePrimer = try c.decodeIfPresent(Bool.self, forKey: .seenScreenTimePrimer) ?? false
        seenNotificationPrimer = try c.decodeIfPresent(Bool.self, forKey: .seenNotificationPrimer) ?? false
    }
}
