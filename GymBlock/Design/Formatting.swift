import Foundation

enum Format {
    /// "82.5", "80", "176.4" — no trailing zeros, at most one decimal.
    static func weight(_ kg: Double?, unit: WeightUnit) -> String {
        guard let kg else { return "" }
        return number(unit.display(kg))
    }

    static func number(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded)
    }

    /// Big volume numbers: "12,450 kg", "1.2t" is too cute — keep kg/lb.
    static func volume(_ kg: Double, unit: WeightUnit) -> String {
        let v = unit.display(kg)
        return "\(v.formatted(.number.precision(.fractionLength(0)))) \(unit.rawValue)"
    }

    /// Workout clock: "4:07", "1:02:45".
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// "58 min", "1h 12m".
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// Rest length: "90s", "2:00", "Off".
    static func rest(_ seconds: Int) -> String {
        if seconds == 0 { return "Off" }
        if seconds < 60 { return "\(seconds)s" }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// "Today", "Yesterday", "Tue", "Mar 4".
    static func day(_ date: Date, now: Date = .now) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: now)
        return sameYear ? date.formatted(.dateTime.month(.abbreviated).day()) : date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    /// "Chest · Triceps" — primary muscles, then the first secondary.
    static func muscles(_ exercise: Exercise?) -> String {
        guard let exercise else { return "" }
        let names = (exercise.primary + exercise.secondary.prefix(1)).map(\.name)
        return names.joined(separator: " · ")
    }

    /// One set as text: "80 kg × 8", "× 12", "1:00".
    static func set(_ set: SetEntry, unit: WeightUnit, metric: MetricKind) -> String {
        switch metric {
        case .weightReps:
            let w = set.weight.map { "\(number(unit.display($0))) \(unit.rawValue)" } ?? "—"
            return "\(w) × \(set.reps.map(String.init) ?? "—")"
        case .reps:
            let extra = set.weight.flatMap { $0 > 0 ? " +\(number(unit.display($0)))" : nil } ?? ""
            return "\(set.reps.map(String.init) ?? "—") reps\(extra)"
        case .time, .distanceTime:
            return clock(TimeInterval(set.seconds ?? 0))
        }
    }
}
