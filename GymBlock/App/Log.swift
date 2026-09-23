import OSLog

/// Unified logging categories. Filter in Console.app by subsystem
/// `com.sulav.gymblock`.
nonisolated enum AppLog {
    static let subsystem = "com.sulav.gymblock"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let paywall = Logger(subsystem: subsystem, category: "paywall")
    static let block = Logger(subsystem: subsystem, category: "block")
    static let store = Logger(subsystem: subsystem, category: "store")
    static let cloud = Logger(subsystem: subsystem, category: "cloud")
}
