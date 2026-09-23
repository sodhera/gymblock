import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// The workout on the Lock Screen and in the Dynamic Island. See
// DESIGN.md → "Live Activity". Two states:
//
//   lifting  — lock glyph + workout clock; next set underneath
//   resting  — orange countdown + progress bar, with +15s and Skip buttons
//
// The island is always black, so text is white and orange carries the
// countdown. The Lock Screen banner is bone paper with ink, like the app.

@main
struct GymBlockWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(ActivityPalette.paper)
                .activitySystemActionForegroundColor(ActivityPalette.ink)
        } dynamicIsland: { context in
            let resting = isResting(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resting ? "REST" : context.attributes.title.uppercased())
                            .font(.system(size: 11, weight: .semibold).width(.expanded))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                        BigClock(context: context, resting: resting, color: resting ? ActivityPalette.orange : .white)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if resting {
                        HStack(spacing: 6) {
                            IslandButton(intent: AddRestIntent(seconds: 15), label: "+15")
                            IslandButton(intent: SkipRestIntent(), label: "Skip", filled: true)
                        }
                        .padding(.top, 6)
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("SETS")
                                .font(.system(size: 11, weight: .semibold).width(.expanded))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(context.state.setsDone)/\(context.state.setsTotal)")
                                .font(.system(size: 26, weight: .bold).width(.expanded).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                        .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        if resting, let start = context.state.restStart, let end = context.state.restEnd {
                            ProgressView(timerInterval: start...end, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                                .progressViewStyle(.linear)
                                .tint(ActivityPalette.orange)
                        }
                        NextSetLine(state: context.state, stale: context.isStale, onDark: true)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: resting ? "timer" : "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ActivityPalette.orange)
            } compactTrailing: {
                CompactClock(context: context, resting: resting)
            } minimal: {
                if resting, let start = context.state.restStart, let end = context.state.restEnd {
                    ProgressView(timerInterval: start...end, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: "timer").font(.system(size: 10, weight: .bold))
                    }
                    .progressViewStyle(.circular)
                    .tint(ActivityPalette.orange)
                } else {
                    Image(systemName: "lock.fill").foregroundStyle(ActivityPalette.orange)
                }
            }
            .keylineTint(ActivityPalette.orange)
        }
    }
}

/// Resting and the rest hasn't gone stale (the system marks the activity
/// stale at `restEnd`, even while the app is suspended).
private func isResting(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> Bool {
    context.state.restEnd != nil && !context.isStale
}

// MARK: - Pieces

private struct BigClock: View {
    var context: ActivityViewContext<WorkoutActivityAttributes>
    var resting: Bool
    var color: Color

    var body: some View {
        Group {
            if resting, let start = context.state.restStart, let end = context.state.restEnd {
                Text(timerInterval: start...end, countsDown: true)
            } else {
                Text(context.attributes.start, style: .timer)
            }
        }
        .font(.system(size: 34, weight: .bold).width(.expanded).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct CompactClock: View {
    var context: ActivityViewContext<WorkoutActivityAttributes>
    var resting: Bool

    var body: some View {
        Group {
            if resting, let start = context.state.restStart, let end = context.state.restEnd {
                Text(timerInterval: start...end, countsDown: true)
                    .foregroundStyle(ActivityPalette.orange)
            } else {
                Text(context.attributes.start, style: .timer)
                    .foregroundStyle(.white)
            }
        }
        .font(.system(size: 14, weight: .semibold).monospacedDigit())
        .multilineTextAlignment(.trailing)
        .frame(width: 50)
    }
}

private struct NextSetLine: View {
    var state: WorkoutActivityAttributes.ContentState
    var stale: Bool
    var onDark: Bool

    var body: some View {
        HStack(spacing: 6) {
            if stale && state.restEnd != nil {
                Text("Rest's over.")
                    .foregroundStyle(ActivityPalette.orange)
                    .fontWeight(.semibold)
            }
            if let exercise = state.exercise {
                Text(stale && state.restEnd != nil ? "Next: \(exercise)" : exercise)
                    .foregroundStyle(onDark ? .white : ActivityPalette.ink)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("· set \(state.setNumber) of \(state.setCount)")
                    .foregroundStyle(onDark ? .white.opacity(0.6) : ActivityPalette.steel)
            } else {
                Text("All sets done. Hold to finish.")
                    .foregroundStyle(onDark ? .white.opacity(0.8) : ActivityPalette.steel)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 14))
    }
}

private struct IslandButton<I: AppIntent>: View {
    var intent: I
    var label: String
    var filled = false

    var body: some View {
        Button(intent: intent) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(filled ? ActivityPalette.ink : .white)
                .frame(width: 52, height: 36)
                .background(filled ? ActivityPalette.orange : .white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    var context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        let resting = isResting(context)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: context.state.appsLocked ? "lock.fill" : "figure.strengthtraining.traditional")
                            .foregroundStyle(ActivityPalette.orange)
                        Text(resting ? "REST · \(context.attributes.title.uppercased())" : context.attributes.title.uppercased())
                            .foregroundStyle(ActivityPalette.steel)
                            .lineLimit(1)
                    }
                    .font(.system(size: 11, weight: .semibold).width(.expanded))

                    BigClock(context: context, resting: resting, color: resting ? ActivityPalette.orange : ActivityPalette.ink)
                }
                Spacer()
                if resting {
                    HStack(spacing: 8) {
                        LockButton(intent: AddRestIntent(seconds: 15), label: "+15")
                        LockButton(intent: SkipRestIntent(), label: "Skip", filled: true)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SETS")
                            .font(.system(size: 11, weight: .semibold).width(.expanded))
                            .foregroundStyle(ActivityPalette.steel)
                        Text("\(context.state.setsDone)/\(context.state.setsTotal)")
                            .font(.system(size: 24, weight: .bold).width(.expanded).monospacedDigit())
                            .foregroundStyle(ActivityPalette.ink)
                    }
                }
            }
            if resting, let start = context.state.restStart, let end = context.state.restEnd {
                ProgressView(timerInterval: start...end, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(ActivityPalette.orange)
            }
            NextSetLine(state: context.state, stale: context.isStale, onDark: false)
        }
        .padding(16)
    }
}

private struct LockButton<I: AppIntent>: View {
    var intent: I
    var label: String
    var filled = false

    var body: some View {
        Button(intent: intent) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(filled ? .white : ActivityPalette.ink)
                .frame(width: 58, height: 40)
                .background(filled ? ActivityPalette.ink : .white, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Island expanded — resting", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes(title: "Push", start: .now.addingTimeInterval(-1800))) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(
        restStart: .now, restEnd: .now.addingTimeInterval(90), exercise: "Bench Press",
        setNumber: 3, setCount: 4, setsDone: 6, setsTotal: 18, appsLocked: true
    )
}

#Preview("Lock screen — lifting", as: .content, using: WorkoutActivityAttributes(title: "Push", start: .now.addingTimeInterval(-1800))) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutActivityAttributes.ContentState(
        restStart: nil, restEnd: nil, exercise: "Bench Press",
        setNumber: 3, setCount: 4, setsDone: 6, setsTotal: 18, appsLocked: true
    )
}
