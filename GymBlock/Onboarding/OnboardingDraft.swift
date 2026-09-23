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
    /// Apps that pull them in, in the order tapped ("TikTok", "Instagram").
    var distractions: [String] = []
    /// What scrolling costs them, as chosen (`OnboardingCost` raw values).
    var costs: [String] = []

    /// The app to name in reveals: their first pick, else "your phone".
    var mainDistraction: String { distractions.first ?? "your phone" }
}

/// The costs someone can admit to. Phrased in their voice, because the
/// mirror step plays them back as quotes.
enum OnboardingCost: String, CaseIterable, Identifiable {
    case longRests, lostFocus, shortSets, dragOn, forget
    var id: String { rawValue }

    var title: String {
        switch self {
        case .longRests: "My 90s rest turns into 5 minutes"
        case .lostFocus: "I lose my focus"
        case .shortSets: "I cut sets short"
        case .dragOn: "My workouts drag on"
        case .forget: "I forget what I lifted last time"
        }
    }
}

enum OnboardingApps {
    /// Plain names, no logos.
    static let all = ["TikTok", "Instagram", "YouTube", "X", "Snapchat", "Reddit", "WhatsApp", "Messages", "Email", "News", "Games", "Other"]
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
