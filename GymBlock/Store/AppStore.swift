import Foundation
import SwiftUI
import UserNotifications

/// Built-in catalog + the user's custom exercises, looked up by id.
@MainActor
final class ExerciseLibrary {
    static let shared = ExerciseLibrary()
    var custom: [Exercise] = []

    func exercise(_ id: String) -> Exercise? {
        ExerciseCatalog.byID[id] ?? custom.first { $0.id == id }
    }

    var all: [Exercise] { custom + ExerciseCatalog.all }
}

/// The app's single source of truth. Views read it from the environment and
/// call its intents; it owns persistence and talks to the services.
@MainActor
@Observable
final class AppStore {
    // MARK: Data

    var profile: Profile { didSet { Persistence.save(profile, to: .profile) } }
    private(set) var workouts: [Workout] { didSet { Persistence.save(workouts, to: .workouts) } }
    var templates: [WorkoutTemplate] { didSet { Persistence.save(templates, to: .templates) } }
    private(set) var customExercises: [Exercise] {
        didSet {
            Persistence.save(customExercises, to: .customExercises)
            ExerciseLibrary.shared.custom = customExercises
        }
    }
    var activeWorkout: Workout? {
        didSet {
            Persistence.save(activeWorkout, to: .activeWorkout)
            publishWorkoutToShield()
        }
    }
    var flags: AppFlags { didSet { Persistence.save(flags, to: .flags) } }
    private(set) var account: AppAccount? { didSet { Persistence.save(account, to: .account) } }

    // MARK: Session state

    var entitlement: EntitlementState = .unknown
    var subscriptionStatus: SubscriptionStatus?
    var isRestoringSession = true
    /// Shown full-screen when true; the workout keeps running when collapsed.
    var isWorkoutPresented = false
    /// Set by finishing a workout; drives the summary sheet.
    var finishedWorkout: Workout?
    /// PRs hit in the workout that just finished.
    var finishedRecords: [PersonalRecord] = []
    var friends = FriendsSnapshot()
    var myPublicProfile: PublicProfile?
    /// Username from a `gymblock://add/<username>` invite link, waiting for
    /// the Friends tab to offer the request.
    var pendingInvite: String?

    let rest = RestTimer()

    // MARK: Services

    let auth: AuthProviding
    let subscriptions: SubscriptionProviding
    let friendsService: FriendsProviding
    let screenTime: ScreenTimeController

    init(
        auth: AuthProviding = AuthService.makeDefault(),
        subscriptions: SubscriptionProviding = Subscription.makeDefault(),
        friends: FriendsProviding = FriendsService.makeDefault(),
        screenTime: ScreenTimeController? = nil
    ) {
        self.auth = auth
        self.subscriptions = subscriptions
        self.friendsService = friends
        self.screenTime = screenTime ?? ScreenTimeController()

        profile = Persistence.load(Profile.self, from: .profile) ?? Profile()
        workouts = Persistence.load([Workout].self, from: .workouts) ?? []
        templates = Persistence.load([WorkoutTemplate].self, from: .templates) ?? []
        customExercises = Persistence.load([Exercise].self, from: .customExercises) ?? []
        activeWorkout = Persistence.load(Workout.self, from: .activeWorkout)
        flags = Persistence.load(AppFlags.self, from: .flags) ?? AppFlags()
        account = Persistence.load(AppAccount.self, from: .account)
        ExerciseLibrary.shared.custom = customExercises

        #if DEBUG
        applyDebugLaunchArguments()
        #endif
    }

    // MARK: - Launch

    func start() async {
        Haptics.prepare()
        subscriptions.start { [weak self] state, status in
            self?.entitlement = state
            self?.subscriptionStatus = status
        }
        if !subscriptions.isConfigured { entitlement = .entitled }

        if let restored = await auth.currentAccount {
            account = restored
            await subscriptions.logIn(accountID: restored.id)
        } else if auth.isConfigured {
            account = nil
        }
        isRestoringSession = false

        // A workout survived a relaunch: keep the block honest.
        if activeWorkout != nil, profile.blockingEnabled, !screenTime.isLocked {
            screenTime.lock()
        } else if activeWorkout == nil, screenTime.isLocked {
            screenTime.unlock()
        }
        await refreshFriends()
    }

    // MARK: - Routing

    enum Route: Equatable {
        case launching, onboarding, paywall, screenTimePrimer, main
    }

    /// DEBUG-only escape hatch when Supabase isn't configured: lets the full
    /// flow run in the Simulator without an account.
    var devSkippedAuth = false

    var route: Route {
        if isRestoringSession { return .launching }
        if !profile.onboarded || (account == nil && !devSkippedAuth && auth.isConfigured) { return .onboarding }
        if entitlement == .unknown { return .launching }
        if entitlement == .notEntitled { return .paywall }
        if !flags.seenScreenTimePrimer { return .screenTimePrimer }
        return .main
    }

    // MARK: - Onboarding

    func completeOnboarding(with draft: OnboardingDraft) {
        profile.name = draft.name.trimmingCharacters(in: .whitespaces)
        profile.weeklyTarget = draft.daysPerWeek
        profile.goal = draft.goal
        profile.sessionMinutes = draft.sessionMinutes
        profile.phoneMinutes = draft.phoneMinutes
        profile.unit = draft.unit
        if templates.isEmpty {
            templates = StarterTemplates.templates(forDaysPerWeek: draft.daysPerWeek)
        }
        profile.onboarded = true
        Haptics.success()
    }

    func signedIn(_ result: AuthResult) async {
        account = result.account
        await subscriptions.logIn(accountID: result.account.id)
        // Returning user on a fresh install: restore the public profile.
        if let remote = await friendsService.myProfile() {
            myPublicProfile = remote
            if !profile.onboarded {
                profile.name = remote.displayName
                profile.weeklyTarget = remote.weeklyTarget
                if templates.isEmpty {
                    templates = StarterTemplates.templates(forDaysPerWeek: remote.weeklyTarget)
                }
                profile.onboarded = true
            }
            profile.username = remote.username
        }
        await refreshFriends()
    }

    func signOut() async {
        if activeWorkout != nil { discardWorkout() }
        await auth.signOut()
        await subscriptions.logOut()
        account = nil
        myPublicProfile = nil
        friends = FriendsSnapshot()
        profile.onboarded = false
        flags = AppFlags()
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        await subscriptions.logOut()
        if activeWorkout != nil { discardWorkout() }
        Persistence.wipe()
        account = nil
        profile = Profile()
        workouts = []
        templates = []
        customExercises = []
        flags = AppFlags()
        friends = FriendsSnapshot()
    }

    // MARK: - Derived

    var week: WeekProgress { Streak.week(containing: .now, workouts: workouts, target: profile.weeklyTarget) }
    var streakWeeks: Int { Streak.weeks(workouts: workouts, target: profile.weeklyTarget) }
    var consistency: Double? { Streak.consistency(workouts: workouts, target: profile.weeklyTarget) }
    var records: [String: PersonalRecord] { Records.best(workouts) }
    var sortedWorkouts: [Workout] { workouts.sorted { $0.start > $1.start } }

    /// The template to suggest on Today: least recently used, so a split
    /// rotates naturally (Push → Pull → Legs → Push…).
    var suggestedTemplate: WorkoutTemplate? {
        templates.min { ($0.lastUsed ?? .distantPast) < ($1.lastUsed ?? .distantPast) }
    }

    func exercise(_ id: String) -> Exercise? { ExerciseLibrary.shared.exercise(id) }

    func previousSets(for exerciseID: String) -> [SetEntry] {
        Records.previousSets(for: exerciseID, in: workouts, excluding: activeWorkout?.id)
    }

    // MARK: - Workout lifecycle

    func startWorkout(from template: WorkoutTemplate? = nil) {
        guard activeWorkout == nil else {
            isWorkoutPresented = true
            return
        }
        var workout = Workout(
            title: template?.name ?? Self.defaultTitle(),
            templateID: template?.id,
            isShared: profile.shareWorkoutsByDefault
        )
        if let template {
            // Sets start empty: last time's numbers show as placeholders and
            // fill in when the set is checked (one tap per set).
            workout.exercises = template.exercises.map { item in
                let sets = (0..<max(1, item.sets)).map { _ in SetEntry(targetReps: item.reps.flatMap { $0 > 0 ? $0 : nil }) }
                return ExerciseLog(exerciseID: item.exerciseID, sets: sets, restSeconds: item.restSeconds)
            }
            if let i = templates.firstIndex(where: { $0.id == template.id }) {
                templates[i].lastUsed = .now
            }
        }
        activeWorkout = workout
        if profile.blockingEnabled { screenTime.lock() }
        Haptics.lock()
        isWorkoutPresented = true
    }

    private static func defaultTitle() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        return switch hour {
        case 5..<12: "Morning workout"
        case 12..<17: "Afternoon workout"
        default: "Evening workout"
        }
    }

    /// Ends the workout and lifts the block. Returns whether it counted.
    @discardableResult
    func finishWorkout() -> Bool {
        guard var workout = activeWorkout else { return false }
        let before = records
        workout.end = .now
        // Drop sets that were never done; drop exercises left empty.
        workout.exercises = workout.exercises.compactMap { log in
            var log = log
            log.sets = log.sets.filter(\.isDone)
            return log.sets.isEmpty ? nil : log
        }
        rest.stop()
        activeWorkout = nil
        screenTime.unlock()
        isWorkoutPresented = false

        guard !workout.exercises.isEmpty else {
            Haptics.unlock()
            return false
        }
        workouts.append(workout)
        let after = records
        let newRecords = after.values.filter { record in
            guard let prior = before[record.exerciseID] else { return false }
            return record.estimatedOneRepMax > prior.estimatedOneRepMax + 0.01 && record.date == workout.start
        }
        finishedRecords = newRecords.sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
        finishedWorkout = workout
        Haptics.unlock()
        Task { await friendsService.upload(workout, records: Array(after.values.filter { $0.date == workout.start })) }
        return workout.counts
    }

    func discardWorkout() {
        rest.stop()
        activeWorkout = nil
        screenTime.unlock()
        isWorkoutPresented = false
    }

    func deleteWorkout(_ id: UUID) {
        workouts.removeAll { $0.id == id }
        Task { await friendsService.deleteWorkout(id) }
    }

    func updateWorkout(_ workout: Workout) {
        guard let i = workouts.firstIndex(where: { $0.id == workout.id }) else { return }
        workouts[i] = workout
        Task { await friendsService.upload(workout, records: []) }
    }

    // MARK: - Active workout editing

    func addExercises(_ ids: [String]) {
        guard activeWorkout != nil else { return }
        for id in ids {
            let count = min(max(previousSets(for: id).filter { $0.kind != .warmup }.count, 3), 5)
            let sets = (0..<count).map { _ in SetEntry() }
            activeWorkout?.exercises.append(ExerciseLog(exerciseID: id, sets: sets, restSeconds: profile.defaultRestSeconds))
        }
        Haptics.tap()
    }

    func removeExercise(_ logID: UUID) {
        activeWorkout?.exercises.removeAll { $0.id == logID }
    }

    func moveExercise(from source: IndexSet, to destination: Int) {
        activeWorkout?.exercises.move(fromOffsets: source, toOffset: destination)
    }

    func addSet(to logID: UUID) {
        guard let e = activeWorkout?.exercises.firstIndex(where: { $0.id == logID }) else { return }
        let last = activeWorkout?.exercises[e].sets.last
        activeWorkout?.exercises[e].sets.append(SetEntry(targetReps: last?.targetReps))
        Haptics.tap()
    }

    func removeSet(_ setID: UUID, from logID: UUID) {
        guard let e = activeWorkout?.exercises.firstIndex(where: { $0.id == logID }) else { return }
        activeWorkout?.exercises[e].sets.removeAll { $0.id == setID }
    }

    func updateSet(_ set: SetEntry, in logID: UUID) {
        guard let e = activeWorkout?.exercises.firstIndex(where: { $0.id == logID }),
              let s = activeWorkout?.exercises[e].sets.firstIndex(where: { $0.id == set.id }) else { return }
        activeWorkout?.exercises[e].sets[s] = set
    }

    func updateLog(_ log: ExerciseLog) {
        guard let e = activeWorkout?.exercises.firstIndex(where: { $0.id == log.id }) else { return }
        activeWorkout?.exercises[e] = log
    }

    /// Checks a set off (or back on). Checking fills empty fields from the
    /// placeholder values, starts the rest timer, and fires the PR moment.
    /// Returns true when the set is a new personal record.
    @discardableResult
    func toggleSetDone(_ setID: UUID, in logID: UUID, placeholderWeight: Double?, placeholderReps: Int?) -> Bool {
        guard let e = activeWorkout?.exercises.firstIndex(where: { $0.id == logID }),
              let s = activeWorkout?.exercises[e].sets.firstIndex(where: { $0.id == setID }),
              var set = activeWorkout?.exercises[e].sets[s],
              let log = activeWorkout?.exercises[e]
        else { return false }

        if set.isDone {
            set.isDone = false
            activeWorkout?.exercises[e].sets[s] = set
            Haptics.setUndone()
            return false
        }

        if set.weight == nil { set.weight = placeholderWeight }
        if set.reps == nil { set.reps = placeholderReps }
        let exercise = exercise(log.exerciseID)
        let needsWeight = exercise?.usesWeight ?? true
        guard set.reps != nil || set.seconds != nil, !needsWeight || set.weight != nil else {
            Haptics.warning()
            return false
        }
        set.isDone = true
        activeWorkout?.exercises[e].sets[s] = set

        let isPR = Records.isRecord(set, exerciseID: log.exerciseID, previous: records)
        if isPR { Haptics.pr() } else { Haptics.setDone() }
        if log.restSeconds > 0 { rest.start(seconds: log.restSeconds) }
        return isPR
    }

    // MARK: - Templates & exercises

    func saveTemplate(_ template: WorkoutTemplate) {
        if let i = templates.firstIndex(where: { $0.id == template.id }) {
            templates[i] = template
        } else {
            templates.append(template)
        }
    }

    func deleteTemplate(_ id: UUID) { templates.removeAll { $0.id == id } }

    func templateFrom(_ workout: Workout) -> WorkoutTemplate {
        WorkoutTemplate(
            name: workout.title,
            exercises: workout.exercises.map {
                TemplateExercise(exerciseID: $0.exerciseID, sets: max(1, $0.sets.count), reps: $0.sets.last?.reps, restSeconds: $0.restSeconds)
            }
        )
    }

    @discardableResult
    func createCustomExercise(name: String, equipment: Equipment, primary: Muscle, metric: MetricKind) -> Exercise {
        let exercise = Exercise(
            id: "custom-\(UUID().uuidString.lowercased())", name: name, equipment: equipment,
            primary: [primary], metric: metric, isCustom: true
        )
        customExercises.append(exercise)
        return exercise
    }

    // MARK: - Friends

    func refreshFriends() async {
        guard friendsService.isConfigured, account != nil else { return }
        if myPublicProfile == nil { myPublicProfile = await friendsService.myProfile() }
        if let snapshot = try? await friendsService.snapshot() {
            friends = snapshot
        }
    }

    func claimUsername(_ username: String) async throws {
        let p = try await friendsService.claimUsername(username, displayName: profile.name, weeklyTarget: profile.weeklyTarget)
        myPublicProfile = p
        profile.username = p.username
    }

    /// `gymblock://add/<username>` — a friend's invite link.
    func handle(url: URL) {
        guard url.scheme == "gymblock", url.host == "add" else { return }
        let username = Usernames.sanitize(url.lastPathComponent)
        if Usernames.isValid(username) { pendingInvite = username }
    }

    // MARK: - Shield mirror

    /// Mirrors the facts the shield shows ("3 sets of Bench Press left") into
    /// the app group every time the workout changes.
    private func publishWorkoutToShield() {
        guard let workout = activeWorkout else { return }
        let current = workout.exercises.first { $0.sets.contains { !$0.isDone } }
        SharedWorkoutState.publish(
            title: workout.title,
            start: workout.start,
            remainingSets: workout.remainingSetCount,
            currentExercise: current.flatMap { exercise($0.exerciseID)?.name },
            currentExerciseSetsLeft: current?.sets.filter { !$0.isDone }.count ?? 0
        )
    }

    // MARK: - Debug

    #if DEBUG
    private func applyDebugLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-reset") {
            Persistence.wipe()
            profile = Profile()
            workouts = []
            templates = []
            activeWorkout = nil
            flags = AppFlags()
            account = nil
        }
        if args.contains("-skip-onboarding") {
            devSkippedAuth = true
            if !profile.onboarded {
                profile.name = "Sulav"
                profile.onboarded = true
                templates = StarterTemplates.templates(forDaysPerWeek: 5)
            }
            flags.seenScreenTimePrimer = true
        }
        if args.contains("-demo-history"), workouts.isEmpty {
            workouts = DemoData.history(templates: templates)
        }
    }
    #endif
}

// MARK: - Rest timer

/// Rest countdown between sets. Wall-clock based so it survives backgrounding;
/// a local notification fires at zero when the app isn't in front.
@MainActor
@Observable
final class RestTimer {
    private(set) var endsAt: Date?
    private(set) var total: Int = 0
    private var tickTask: Task<Void, Never>?
    private static let notificationID = "rest-timer"

    var isRunning: Bool { endsAt != nil }

    func remaining(at date: Date = .now) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(date).rounded(.up)))
    }

    func start(seconds: Int) {
        total = seconds
        endsAt = Date().addingTimeInterval(TimeInterval(seconds))
        scheduleNotification(in: seconds)
        runTicks()
    }

    func add(_ seconds: Int) {
        guard let endsAt else { return }
        let new = endsAt.addingTimeInterval(TimeInterval(seconds))
        if new <= .now { stop(); return }
        self.endsAt = new
        total = max(total + seconds, remaining())
        scheduleNotification(in: remaining())
        Haptics.tap()
    }

    func stop() {
        tickTask?.cancel()
        endsAt = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func runTicks() {
        tickTask?.cancel()
        tickTask = Task { @MainActor [weak self] in
            var lastHaptic = -1
            while !Task.isCancelled {
                guard let self, self.endsAt != nil else { return }
                let left = self.remaining()
                if left <= 3, left > 0, left != lastHaptic {
                    Haptics.countdown()
                    lastHaptic = left
                }
                if left == 0 {
                    Haptics.restEnd()
                    self.endsAt = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func scheduleNotification(in seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Rest's over"
        content.body = "Next set."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
    }
}
