import SwiftUI

// The three steps that make the problem personal. The flow gathers it in
// the user's own terms (which apps, what it costs them), then hands it back
// in their own words. No statistics about "people". This person, this phone.

// MARK: - What pulls you in

struct AppsStep: View {
    @Binding var draft: OnboardingDraft
    var next: () -> Void

    var body: some View {
        StepScaffold(
            title: "What pulls you in?",
            buttonEnabled: !draft.distractions.isEmpty,
            action: next
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: GBSpace.xs), count: 3), spacing: GBSpace.xs) {
                ForEach(OnboardingApps.all, id: \.self) { app in
                    let selected = draft.distractions.contains(app)
                    Button {
                        Haptics.tap()
                        withAnimation(.snappy(duration: 0.2)) {
                            if let i = draft.distractions.firstIndex(of: app) {
                                draft.distractions.remove(at: i)
                            } else {
                                draft.distractions.append(app)
                            }
                        }
                    } label: {
                        Text(app)
                            .font(GBFont.label(16))
                            .foregroundStyle(selected ? GBColor.onInk : GBColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: GBRadius.sm, style: .continuous)
                                    .fill(selected ? GBColor.ink : GBColor.card)
                            )
                    }
                    .buttonStyle(ScaleOnPress())
                }
            }
        }
    }
}

// MARK: - What it costs you

struct CostsStep: View {
    @Binding var draft: OnboardingDraft
    var next: () -> Void

    var body: some View {
        StepScaffold(
            title: "What does it cost you?",
            buttonEnabled: !draft.costs.isEmpty,
            action: next
        ) {
            VStack(spacing: GBSpace.xs) {
                ForEach(OnboardingCost.allCases) { cost in
                    OptionTile(title: cost.title, isSelected: draft.costs.contains(cost.rawValue)) {
                        if let i = draft.costs.firstIndex(of: cost.rawValue) {
                            draft.costs.remove(at: i)
                        } else {
                            draft.costs.append(cost.rawValue)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Sound familiar?

/// Plays their chosen costs back as quotes, one at a time, then reframes:
/// it isn't a willpower problem, it's a design problem, and that's
/// something a tool can fix. That's the bridge to the plan and the paywall.
struct MirrorStep: View {
    var draft: OnboardingDraft
    var next: () -> Void
    @State private var shown = 0
    @State private var verdict = false

    private var quotes: [String] {
        draft.costs.compactMap { OnboardingCost(rawValue: $0)?.title }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sound familiar?")
                .font(GBFont.hero(30))
                .foregroundStyle(GBColor.ink)
                .padding(.top, GBSpace.xl)

            VStack(alignment: .leading, spacing: GBSpace.lg) {
                ForEach(Array(quotes.enumerated()), id: \.offset) { index, quote in
                    Text("“\(quote).”")
                        .font(GBFont.title(20))
                        .foregroundStyle(GBColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, GBSpace.md)
                        .overlay(alignment: .leading) {
                            Capsule().fill(GBColor.orange).frame(width: 3)
                        }
                    .opacity(index < shown ? 1 : 0)
                    .offset(y: index < shown ? 0 : 10)
                }
            }
            .padding(.top, GBSpace.xxl)

            (Text("It's not discipline.\n") + Text("\(draft.mainDistraction == "your phone" ? "Your phone" : draft.mainDistraction) is built to win.").foregroundStyle(GBColor.orange))
                .font(GBFont.hero(26))
                .foregroundStyle(GBColor.ink)
                .opacity(verdict ? 1 : 0)
                .scaleEffect(verdict ? 1 : 0.96, anchor: .leading)
                .padding(.top, GBSpace.huge + GBSpace.md)

            Spacer()

            Button("Fix it", action: next)
                .buttonStyle(.primary)
                .opacity(verdict ? 1 : 0.4)
                .disabled(!verdict)
                .padding(.bottom, GBSpace.xs)
        }
        .padding(.horizontal, GBSpace.xl)
        .task {
            try? await Task.sleep(for: .seconds(0.4))
            for i in 1...max(1, quotes.count) where !quotes.isEmpty {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { shown = i }
                Haptics.soft(0.6)
                try? await Task.sleep(for: .seconds(0.7))
            }
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { verdict = true }
            Haptics.lock()
        }
    }
}
