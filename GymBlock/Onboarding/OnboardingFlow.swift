import SwiftUI

/// Sign-up: ask, reveal, ask, reveal — then commit, then account. Three cheap
/// inputs (days/week, session length, phone minutes) derive every reveal;
/// nothing is modelled or invented. Steps crossfade; one primary button per
/// step, plus the commitment hold. See DESIGN.md → "Sign-up flow".
struct OnboardingFlow: View {
    @Environment(AppStore.self) private var store
    @State private var step: Step = .welcome
    @State private var draft = OnboardingDraft()
    @State private var authMode: AuthView.Mode = .signUp

    enum Step: Int, CaseIterable {
        case welcome, days, session, phone, sessionReveal, yearReveal, goal, plan, name, demo, commit, account
    }

    /// Steps that show the progress bar (questionnaire through commit).
    private var progress: Double? {
        guard step != .welcome, step != .account else { return nil }
        return Double(step.rawValue) / Double(Step.commit.rawValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                topBar
            }
            ZStack {
                stepView
                    .id(step)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .paperBackground()
        .animation(.easeInOut(duration: 0.35), value: step)
        .onChange(of: store.account) { _, account in
            // Signed in from the "I already have an account" path with no
            // cloud profile: run the questionnaire, skip the account step.
            if account != nil, !store.profile.onboarded, step == .account, authMode == .signIn {
                go(.days)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: GBSpace.md) {
            GlassIconButton(systemName: "chevron.left", size: 40) { back() }
            if let progress {
                GeometryReader { geo in
                    Capsule().fill(GBColor.mist.opacity(0.6))
                        .overlay(alignment: .leading) {
                            Capsule().fill(GBColor.ink)
                                .frame(width: max(8, geo.size.width * progress))
                                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
                        }
                }
                .frame(height: 4)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, GBSpace.margin)
        .padding(.top, GBSpace.xs)
        .frame(height: 52)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .welcome:
            WelcomeStep(
                onStart: { authMode = .signUp; go(.days) },
                onSignIn: { authMode = .signIn; go(.account) }
            )
        case .days:
            DaysStep(draft: $draft) { go(.session) }
        case .session:
            SessionStep(draft: $draft) { go(.phone) }
        case .phone:
            PhoneStep(draft: $draft) { go(.sessionReveal) }
        case .sessionReveal:
            SessionRevealStep(draft: draft) { go(.yearReveal) }
        case .yearReveal:
            YearRevealStep(draft: draft) { go(.goal) }
        case .goal:
            GoalStep(draft: $draft) { go(.plan) }
        case .plan:
            PlanStep(draft: draft) { go(.name) }
        case .name:
            NameStep(draft: $draft) { go(.demo) }
        case .demo:
            ShieldDemoStep(draft: draft) { go(.commit) }
        case .commit:
            CommitStep(draft: draft) { commit() }
        case .account:
            AuthView(mode: authMode, draft: draft) { result in
                await finishAuth(result)
            } onSkip: {
                store.devSkippedAuth = true
                store.completeOnboarding(with: draft)
            }
        }
    }

    private func go(_ next: Step) {
        Haptics.tap()
        step = next
    }

    private func back() {
        switch step {
        case .account where authMode == .signIn: go(.welcome)
        case .days where store.account != nil: go(.account)
        default: go(Step(rawValue: step.rawValue - 1) ?? .welcome)
        }
    }

    private func commit() {
        if store.account != nil || !store.auth.isConfigured && store.devSkippedAuth {
            store.completeOnboarding(with: draft)
        } else {
            authMode = .signUp
            go(.account)
        }
    }

    private func finishAuth(_ result: AuthResult) async {
        if authMode == .signUp || step != .account {
            store.completeOnboarding(with: draft)
        }
        await store.signedIn(result)
        if !store.profile.onboarded {
            // Returning account with no saved profile — ask the questions.
            go(.days)
        } else if store.myPublicProfile == nil, !draft.name.isEmpty {
            // Best-effort: claim a username from their name so friends can
            // find them straight away. They can change it on the Friends tab.
            try? await store.claimUsername(Usernames.sanitize(draft.name.replacingOccurrences(of: " ", with: "")))
        }
    }
}

// MARK: - Shared step chrome

/// Title + optional subtitle + content + one primary button, the layout every
/// ask step shares.
struct StepScaffold<Content: View>: View {
    var title: String
    var subtitle: String?
    var buttonTitle = "Continue"
    var buttonEnabled = true
    var action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: GBSpace.sm) {
                Text(title)
                    .font(GBFont.hero(30))
                    .foregroundStyle(GBColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(GBFont.body(17))
                        .foregroundStyle(GBColor.steel)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, GBSpace.xl)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button(buttonTitle, action: action)
                .buttonStyle(.primary)
                .disabled(!buttonEnabled)
                .padding(.bottom, GBSpace.xs)
        }
        .padding(.horizontal, GBSpace.xl)
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    var onStart: () -> Void
    var onSignIn: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            BrandMark(size: 72)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
            Text("GymBlock")
                .font(GBFont.hero(44))
                .foregroundStyle(GBColor.ink)
                .padding(.top, GBSpace.xl)
            (Text("Your phone waits.\n") + Text("You lift.").foregroundStyle(GBColor.orange))
                .font(GBFont.title(26))
                .foregroundStyle(GBColor.ink2)
                .padding(.top, GBSpace.xs)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
            Spacer()
            Spacer()
            Button("Get started", action: onStart)
                .buttonStyle(.primary)
            Button("I already have an account", action: onSignIn)
                .buttonStyle(.quiet)
                .frame(maxWidth: .infinity)
                .padding(.vertical, GBSpace.md)
        }
        .padding(.horizontal, GBSpace.xl)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) { appeared = true }
            Task {
                try? await Task.sleep(for: .seconds(0.25))
                Haptics.lock()
            }
        }
    }
}

// MARK: - Days

private struct DaysStep: View {
    @Binding var draft: OnboardingDraft
    var next: () -> Void

    var body: some View {
        StepScaffold(
            title: "How many days a week do you want to train?",
            subtitle: "Your streak counts weeks, so rest days never break it.",
            action: next
        ) {
            VStack(spacing: GBSpace.xl) {
                Text("\(draft.daysPerWeek)")
                    .font(GBFont.stat(96))
                    .foregroundStyle(GBColor.ink)
                    .contentTransition(.numericText(value: Double(draft.daysPerWeek)))
                    .animation(.snappy, value: draft.daysPerWeek)
                HStack(spacing: GBSpace.xs) {
                    ForEach(2...6, id: \.self) { n in
                        Button {
                            Haptics.tap()
                            draft.daysPerWeek = n
                        } label: {
                            Text("\(n)")
                                .font(GBFont.number(20, weight: .bold))
                                .foregroundStyle(draft.daysPerWeek == n ? .white : GBColor.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: GBRadius.sm, style: .continuous)
                                        .fill(draft.daysPerWeek == n ? GBColor.ink : Color.white)
                                )
                        }
                        .buttonStyle(ScaleOnPress())
                    }
                }
                Text(StarterTemplates.splitName(forDaysPerWeek: draft.daysPerWeek) + " split")
                    .font(GBFont.label(15))
                    .foregroundStyle(GBColor.steel)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: draft.daysPerWeek)
            }
        }
    }
}

// MARK: - Session length

private struct SessionStep: View {
    @Binding var draft: OnboardingDraft
    var next: () -> Void

    var body: some View {
        StepScaffold(title: "How long is a typical session?", action: next) {
            VStack(spacing: GBSpace.sm) {
                ForEach([45, 60, 75, 90], id: \.self) { minutes in
                    OptionTile(
                        title: minutes == 90 ? "90+ minutes" : "\(minutes) minutes",
                        isSelected: draft.sessionMinutes == minutes
                    ) { draft.sessionMinutes = minutes }
                }
            }
        }
    }
}

// MARK: - Phone minutes

private struct PhoneStep: View {
    @Binding var draft: OnboardingDraft
    var next: () -> Void

    var body: some View {
        StepScaffold(
            title: "Be honest. How much of it is on your phone?",
            subtitle: "Scrolling between sets, replying, “just checking”.",
            action: next
        ) {
            VStack(spacing: GBSpace.xl) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(draft.phoneMinutes)")
                        .font(GBFont.stat(96))
                        .foregroundStyle(GBColor.orange)
                        .contentTransition(.numericText(value: Double(draft.phoneMinutes)))
                    Text("min").font(GBFont.title(24)).foregroundStyle(GBColor.steel)
                }
                .animation(.snappy(duration: 0.2), value: draft.phoneMinutes)

                Slider(
                    value: Binding(
                        get: { Double(draft.phoneMinutes) },
                        set: {
                            let v = Int($0.rounded())
                            if v != draft.phoneMinutes { Haptics.tap() }
                            draft.phoneMinutes = v
                        }
                    ),
                    in: 0...Double(min(45, draft.sessionMinutes)),
                    step: 1
                )
                .tint(GBColor.orange)
                HStack {
                    Text("0").font(GBFont.number(13)).foregroundStyle(GBColor.fog)
                    Spacer()
                    Text("\(min(45, draft.sessionMinutes)) min").font(GBFont.number(13)).foregroundStyle(GBColor.fog)
                }
                .padding(.top, -GBSpace.md)
            }
        }
    }
}

// MARK: - Reveal: one session

private struct SessionRevealStep: View {
    var draft: OnboardingDraft
    var next: () -> Void
    @State private var filled = false

    var body: some View {
        let share = PhoneMath.share(draft)
        StepScaffold(
            title: "\(draft.phoneMinutes) of every \(draft.sessionMinutes) minutes.",
            subtitle: shareSentence(share),
            buttonTitle: "Keep going",
            action: next
        ) {
            VStack(alignment: .leading, spacing: GBSpace.md) {
                Text("Your \(draft.sessionMinutes)-minute session").kicker()
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(GBColor.ink)
                            .frame(width: geo.size.width * (filled ? 1 - share : 1))
                        if share > 0 {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(GBColor.orange)
                                .frame(width: filled ? max(0, geo.size.width * share - 3) : 0)
                        }
                    }
                }
                .frame(height: 64)
                HStack {
                    Label("Lifting", systemImage: "circle.fill").foregroundStyle(GBColor.ink)
                    Spacer()
                    Label("Phone", systemImage: "circle.fill").foregroundStyle(GBColor.orange)
                }
                .font(GBFont.label(14))
                .labelStyle(DotLabelStyle())
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.4))
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { filled = true }
            Haptics.soft(0.7)
        }
    }

    private func shareSentence(_ share: Double) -> String {
        switch share {
        case 0: return "Not a minute? Then the block keeps it that way."
        case ..<0.15: return "Small, until you add it up."
        case ..<0.3: return "Roughly a quarter of every workout, gone to scrolling."
        default: return "A third of every workout, spent on a screen."
        }
    }
}

struct DotLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 8))
            configuration.title.foregroundStyle(GBColor.steel)
        }
    }
}

// MARK: - Reveal: the year

private struct YearRevealStep: View {
    var draft: OnboardingDraft
    var next: () -> Void
    @State private var lit = 0

    var body: some View {
        let sessions = PhoneMath.sessionsLost(draft)
        let hours = PhoneMath.yearlyHours(draft)
        let total = draft.daysPerWeek * 52
        StepScaffold(
            title: "That's \(hours) hours a year.",
            subtitle: sessions == 1
                ? "One whole workout you showed up for and didn't do."
                : "\(sessions) whole workouts you showed up for and didn't do.",
            buttonTitle: "I want them back",
            action: next
        ) {
            VStack(alignment: .leading, spacing: GBSpace.sm) {
                Text("\(total) sessions a year").kicker()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 16), spacing: 4) {
                    ForEach(0..<total, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                            .fill(i >= total - lit ? GBColor.orange : GBColor.mist.opacity(0.7))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
                Text("Orange: time spent on your phone, as full sessions.")
                    .font(GBFont.body(13))
                    .foregroundStyle(GBColor.fog)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(0.5))
            for i in 1...max(1, sessions) where sessions > 0 {
                try? await Task.sleep(for: .milliseconds(max(12, 700 / max(sessions, 1))))
                withAnimation(.easeOut(duration: 0.12)) { lit = i }
                if i % 3 == 0 { Haptics.soft(0.35) }
            }
            Haptics.lock()
        }
    }
}

// MARK: - Goal

private struct GoalStep: View {
    @Binding var draft: OnboardingDraft
    var next: () -> Void

    var body: some View {
        StepScaffold(title: "What are you training for?", action: next) {
            VStack(spacing: GBSpace.sm) {
                ForEach(TrainingGoal.allCases) { goal in
                    OptionTile(title: goal.title, icon: goal.icon, isSelected: draft.goal == goal) {
                        draft.goal = goal
                    }
                }
            }
        }
    }
}

// MARK: - Plan

private struct PlanStep: View {
    var draft: OnboardingDraft
    var next: () -> Void

    var body: some View {
        let templates = StarterTemplates.templates(forDaysPerWeek: draft.daysPerWeek)
        let week = WeekProgress(
            days: TrainingCalendar.weekDays(containing: .now),
            trained: Set(planDays(draft.daysPerWeek)),
            target: draft.daysPerWeek
        )
        StepScaffold(
            title: "Here's your plan.",
            subtitle: "\(draft.daysPerWeek) days a week, \(StarterTemplates.splitName(forDaysPerWeek: draft.daysPerWeek)). Every workout locks your distracting apps until you finish.",
            action: next
        ) {
            VStack(alignment: .leading, spacing: GBSpace.lg) {
                WeekStrip(week: week, now: .distantPast)
                    .padding(GBSpace.lg)
                    .solidCard()
                VStack(alignment: .leading, spacing: GBSpace.xs) {
                    Text("Starter templates").kicker()
                    ForEach(templates) { t in
                        HStack {
                            Text(t.name).font(GBFont.headline(16)).foregroundStyle(GBColor.ink)
                            Spacer()
                            Text("\(t.exercises.count) exercises").font(GBFont.body(14)).foregroundStyle(GBColor.steel)
                        }
                        .padding(.vertical, 6)
                    }
                    Text("Edit them any time.").font(GBFont.body(13)).foregroundStyle(GBColor.fog)
                }
            }
        }
    }

    /// Spread N training days across the week sensibly (for illustration).
    private func planDays(_ n: Int) -> [Int] {
        switch n {
        case ...2: [0, 3]
        case 3: [0, 2, 4]
        case 4: [0, 1, 3, 4]
        case 5: [0, 1, 2, 4, 5]
        default: [0, 1, 2, 3, 4, 5]
        }
    }
}

// MARK: - Name

private struct NameStep: View {
    @Binding var draft: OnboardingDraft
    var next: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        StepScaffold(
            title: "What should we call you?",
            subtitle: "Friends see this.",
            buttonEnabled: !draft.name.trimmingCharacters(in: .whitespaces).isEmpty,
            action: next
        ) {
            VStack(alignment: .leading, spacing: GBSpace.xl) {
                TextField("Your name", text: $draft.name)
                    .font(GBFont.title(26))
                    .textContentType(.givenName)
                    .submitLabel(.continue)
                    .focused($focused)
                    .onSubmit { if !draft.name.isEmpty { next() } }
                    .padding(.horizontal, GBSpace.md)
                    .frame(height: 64)
                    .solidCard(cornerRadius: GBRadius.md)

                HStack {
                    Text("You lift in").font(GBFont.body(16)).foregroundStyle(GBColor.steel)
                    Spacer()
                    Picker("Units", selection: $draft.unit) {
                        ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                Spacer()
            }
            .padding(.top, GBSpace.xxl)
        }
        .onAppear { focused = true }
    }
}

// MARK: - Commit

private struct CommitStep: View {
    var draft: OnboardingDraft
    var commit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(GBColor.orange)
            Text("Lock it in.")
                .font(GBFont.hero(40))
                .foregroundStyle(GBColor.ink)
                .padding(.top, GBSpace.lg)
            Text("I'll train \(draft.daysPerWeek) days a week, and my phone stays locked until each workout's done.")
                .font(GBFont.title(20))
                .foregroundStyle(GBColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, GBSpace.md)
            Spacer()
            Spacer()
            HoldButton(title: "Hold to commit", holdingTitle: "Keep holding…", duration: 1.6, tint: GBColor.ink) {
                Haptics.lock()
                commit()
            }
            Text(draft.name.isEmpty ? " " : "— \(draft.name)")
                .font(GBFont.body(15))
                .foregroundStyle(GBColor.fog)
                .frame(maxWidth: .infinity)
                .padding(.vertical, GBSpace.md)
        }
        .padding(.horizontal, GBSpace.xl)
    }
}
