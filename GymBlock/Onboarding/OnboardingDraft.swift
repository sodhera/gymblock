import Foundation

/// Answers collected during sign-up. Three cheap inputs — days per week,
/// session length, phone minutes per session — derive every reveal in the
/// flow (`PhoneMath`), the same "your own answers handed back as arithmetic"
/// approach SleepBlock uses.
struct OnboardingDraft: Codable, Equatable {
    var daysPerWeek: Int = 4
    var sessionMinutes: Int = 60
    var phoneMinutes: Int = 15
    var goal: TrainingGoal = .muscle
    var unit: WeightUnit = Locale.current.measurementSystem == .us ? .lb : .kg
    var name: String = ""
}

enum PhoneMath {
    /// Minutes on the phone per year, at the gym.
    static func yearlyMinutes(_ d: OnboardingDraft) -> Int { d.phoneMinutes * d.daysPerWeek * 52 }
    static func yearlyHours(_ d: OnboardingDraft) -> Int { Int((Double(yearlyMinutes(d)) / 60).rounded()) }
    /// Those minutes expressed as whole sessions — "workouts you paid for".
    static func sessionsLost(_ d: OnboardingDraft) -> Int {
        guard d.sessionMinutes > 0 else { return 0 }
        return Int((Double(yearlyMinutes(d)) / Double(d.sessionMinutes)).rounded())
    }
    /// Share of each session spent on the phone, 0…1.
    static func share(_ d: OnboardingDraft) -> Double {
        guard d.sessionMinutes > 0 else { return 0 }
        return min(1, Double(d.phoneMinutes) / Double(d.sessionMinutes))
    }
}
