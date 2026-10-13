import ActivityKit
import SwiftUI
import WidgetKit

@main struct GymBlockLiveBundle: WidgetBundle {
  var body: some Widget {
    WorkoutLiveActivity()
    UpNextWidget()
    MonthWidget()
    WeekWidget()
    if #available(iOS 18.0, *) { StartWorkoutControl() }
  }
}

/// The Live Activity always wears the dark paper tokens: the Lock Screen and the Dynamic Island
/// are dark whatever the app's appearance. Emerald is the only signal, as in the app.
private enum Dark {
  static let stage = Paper.stage.dark.color
  static let text = Paper.ink.dark.color
  static let secondary = Paper.secondary.dark.color
  static let signal = Paper.signal.dark.color
}

/// The set and the rest on the Lock Screen and in the Dynamic Island, so you never need to unlock
/// the phone between sets. When the rest length passes the activity goes stale: "Rest’s up" and
/// the bar turn emerald, and the clock counts how far over, in grey.
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      LockScreenWorkout(context: context)
        .activityBackgroundTint(Dark.stage.opacity(0.92))
        .activitySystemActionForegroundColor(Dark.text)
    } dynamicIsland: { context in
      let state = context.state
      let up = state.phase == .rest && context.isStale && state.pausedAt == nil
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text(label(state, up: up)).font(.system(size: 13, weight: .semibold))
              .foregroundStyle(up ? Dark.signal : Dark.secondary)
            Text(state.exercise).font(.system(size: 17, weight: .semibold)).foregroundStyle(Dark.text).lineLimit(1)
          }.padding(.leading, 6)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ClockText(state: state, up: up).font(.system(size: 30, weight: .semibold))
            .frame(maxWidth: 110, alignment: .trailing).padding(.trailing, 6)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 10) {
            if state.phase == .rest { RestBar(state: state, up: up) } else { Capsule().fill(Dark.text.opacity(0.12)).frame(height: 4) }
            HStack {
              Text(state.next)
              Spacer()
              Text(state.progress)
            }.font(.system(size: 13)).foregroundStyle(Dark.secondary).monospacedDigit()
            StepButton(state: state, id: context.attributes.id)
          }.padding(.horizontal, 6)
        }
      } compactLeading: {
        Image(systemName: icon(state)).foregroundStyle(up ? Dark.signal : Dark.text)
      } compactTrailing: {
        ClockText(state: state, up: up).frame(width: 48)
      } minimal: {
        Image(systemName: icon(state)).foregroundStyle(up ? Dark.signal : Dark.text)
      }.keylineTint(Dark.signal)
    }
  }
}

private func label(_ state: WorkoutActivityAttributes.ContentState, up: Bool) -> String {
  if state.pausedAt != nil { return state.pausedLabel }
  switch state.phase {
  case .rest: return up ? state.restUp : state.restLabel
  case .set: return state.setLabel
  case .ready: return state.readyLabel
  }
}
/// No figures: a dumbbell, filled during a set and outlined while ready.
private func icon(_ state: WorkoutActivityAttributes.ContentState) -> String {
  state.pausedAt != nil ? "pause.fill" : state.phase == .rest ? "timer" : state.phase == .set ? "dumbbell.fill" : "dumbbell"
}

private extension WorkoutActivityAttributes.ContentState {
  /// When the rest runs out (the activity's stale date). Never before `since`, so no range is backwards.
  var restEnd: Date { since.addingTimeInterval(Double(max(0, restSeconds))) }
}

/// The phase's clock, counted by the system with no updates. The set, and the workout while ready
/// (`since` leaves out paused time), count up; the rest counts down the time left, as in the app,
/// then how far over in grey. Never emerald: the label and the bar carry rest's up.
private struct ClockText: View {
  let state: WorkoutActivityAttributes.ContentState
  let up: Bool
  /// Rest's up, or paused after the rest ran out (frozen at how far over, as the app shows it).
  private var over: Bool { up || (state.phase == .rest && state.pausedAt.map { $0 >= state.restEnd } == true) }
  var body: some View {
    Group {
      if state.phase != .rest {
        Text(timerInterval: state.since...Date.distantFuture, pauseTime: state.pausedAt, countsDown: false)
          .foregroundStyle(Dark.text)
      } else if over {
        HStack(spacing: 0) {
          Text(verbatim: "+")
          Text(timerInterval: state.restEnd...Date.distantFuture, pauseTime: state.pausedAt, countsDown: false)
        }.foregroundStyle(Dark.secondary).accessibilityElement(children: .combine)
      } else {
        Text(timerInterval: state.since...state.restEnd, pauseTime: state.pausedAt, countsDown: true)
          .foregroundStyle(Dark.text)
      }
    }
    .monospacedDigit()
    .multilineTextAlignment(.trailing)
  }
}

/// Fills as the rest runs, as in the app; emerald once it's up.
private struct RestBar: View {
  let state: WorkoutActivityAttributes.ContentState
  let up: Bool
  var body: some View {
    if let paused = state.pausedAt {
      // Frozen where the pause began.
      ProgressView(value: min(1, max(0, paused.timeIntervalSince(state.since) / Double(max(1, state.restSeconds)))))
        .tint(Dark.text.opacity(0.45)).progressViewStyle(.linear)
    } else {
      ProgressView(timerInterval: state.since...state.restEnd, countsDown: false) {
        EmptyView()
      } currentValueLabel: { EmptyView() }
        .tint(up ? Dark.signal : Dark.text.opacity(0.45)).progressViewStyle(.linear)
    }
  }
}

/// Start set / Finish set without unlocking. Runs in the app; the activity updates itself after.
private struct StepButton: View {
  let state: WorkoutActivityAttributes.ContentState
  let id: String
  var body: some View {
    if !state.action.isEmpty {
      Button(intent: WorkoutStepIntent(workoutID: id, step: state.pausedAt != nil ? "resume" : state.phase == .set ? "finish" : "start")) {
        Text(state.action).font(.system(size: 15, weight: .semibold)).foregroundStyle(Dark.stage)
          .frame(maxWidth: .infinity, minHeight: 36)
      }.buttonStyle(.plain).background(Capsule().fill(Dark.text))
    }
  }
}

private struct LockScreenWorkout: View {
  let context: ActivityViewContext<WorkoutActivityAttributes>
  var body: some View {
    let state = context.state
    let up = state.phase == .rest && context.isStale && state.pausedAt == nil
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        // One line each: the banner is at its 160-pt height limit.
        VStack(alignment: .leading, spacing: 3) {
          Text(context.attributes.workoutName + " · " + state.progress)
            .font(.system(size: 13, weight: .medium)).foregroundStyle(Dark.secondary).lineLimit(1)
          Text(state.exercise).font(.system(size: 17, weight: .semibold)).foregroundStyle(Dark.text).lineLimit(1)
          Text(state.next).font(.system(size: 15)).foregroundStyle(Dark.secondary).monospacedDigit().lineLimit(1)
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 2) {
          Text(label(state, up: up)).font(.system(size: 13, weight: .semibold))
            .foregroundStyle(up ? Dark.signal : Dark.secondary)
          ClockText(state: state, up: up).font(.system(size: 36, weight: .semibold))
            .frame(maxWidth: 130, alignment: .trailing)
        }
      }
      // The bar's place is kept in every phase, so the button never moves under your thumb.
      if state.phase == .rest { RestBar(state: state, up: up) } else { Capsule().fill(Dark.text.opacity(0.12)).frame(height: 4) }
      StepButton(state: state, id: context.attributes.id)
    }.padding(16)
  }
}
