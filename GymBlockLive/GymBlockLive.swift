import ActivityKit
import SwiftUI
import WidgetKit

@main struct GymBlockLiveBundle: WidgetBundle {
  var body: some Widget { WorkoutLiveActivity() }
}

private let stage = Color(red: 0.043, green: 0.047, blue: 0.059)
private let signal = Color(red: 0x3E / 255, green: 0xE8 / 255, blue: 0xB5 / 255)

/// The rest counts on the Lock Screen and in the Dynamic Island, so you never need to unlock
/// the phone between sets. When the rest length passes, the activity goes stale and turns red.
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      LockScreenWorkout(context: context)
        .activityBackgroundTint(stage.opacity(0.92))
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      let state = context.state
      let up = state.phase == .rest && context.isStale && state.pausedAt == nil
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          VStack(alignment: .leading, spacing: 2) {
            Text(label(state, up: up)).font(.caption).foregroundStyle(up ? signal : .secondary)
            Text(state.exercise).font(.headline).lineLimit(1)
          }.padding(.leading, 6)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ClockText(state: state, started: context.attributes.started)
            .font(.system(size: 30, weight: .semibold)).monospacedDigit()
            .foregroundStyle(up ? signal : .white).frame(maxWidth: 110, alignment: .trailing).padding(.trailing, 6)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(spacing: 10) {
            if state.phase == .rest { RestBar(state: state, up: up) } else { Capsule().fill(.white.opacity(0.12)).frame(height: 4) }
            HStack {
              Text(state.next).foregroundStyle(.secondary)
              Spacer()
              Text(state.progress).foregroundStyle(.secondary)
            }.font(.caption).monospacedDigit()
            StepButton(state: state, id: context.attributes.id)
          }.padding(.horizontal, 6)
        }
      } compactLeading: {
        Image(systemName: icon(state)).foregroundStyle(up ? signal : .white)
      } compactTrailing: {
        ClockText(state: state, started: context.attributes.started).monospacedDigit()
          .foregroundStyle(up ? signal : .white).frame(width: 48)
      } minimal: {
        Image(systemName: icon(state)).foregroundStyle(up ? signal : .white)
      }.keylineTint(signal)
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
private func icon(_ state: WorkoutActivityAttributes.ContentState) -> String {
  state.pausedAt != nil ? "pause.fill" : state.phase == .rest ? "timer" : state.phase == .set ? "dumbbell.fill" : "figure.strengthtraining.traditional"
}

/// Counts up from the set or rest start (or the workout start when ready), with no updates needed.
private struct ClockText: View {
  let state: WorkoutActivityAttributes.ContentState
  let started: Date
  var body: some View {
    Text(timerInterval: (state.phase == .ready ? started : state.since)...Date.distantFuture,
         pauseTime: state.pausedAt, countsDown: false)
      .multilineTextAlignment(.trailing)
  }
}

private struct RestBar: View {
  let state: WorkoutActivityAttributes.ContentState
  let up: Bool
  var body: some View {
    if let paused = state.pausedAt {
      // Frozen where the pause began.
      ProgressView(value: min(1, max(0, paused.timeIntervalSince(state.since) / Double(state.restSeconds))))
        .tint(.white.opacity(0.4)).progressViewStyle(.linear)
    } else {
      ProgressView(timerInterval: state.since...state.since.addingTimeInterval(Double(state.restSeconds)), countsDown: false) {
        EmptyView()
      } currentValueLabel: { EmptyView() }
        .tint(up ? signal : .white).progressViewStyle(.linear)
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
        Text(state.action).font(.system(.subheadline, weight: .semibold)).foregroundStyle(.black)
          .frame(maxWidth: .infinity, minHeight: 36)
      }.buttonStyle(.plain).background(Capsule().fill(.white))
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
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Circle().fill(signal).frame(width: 6, height: 6)
            Text(context.attributes.workoutName + " · " + state.progress)
          }.font(.caption).foregroundStyle(.white.opacity(0.64))
          Text(state.exercise).font(.headline).foregroundStyle(.white).lineLimit(1)
          Text(state.next).font(.subheadline).foregroundStyle(.white.opacity(0.64)).monospacedDigit()
        }
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 2) {
          Text(label(state, up: up)).font(.caption.weight(.semibold)).foregroundStyle(up ? signal : .white.opacity(0.64))
          ClockText(state: state, started: context.attributes.started)
            .font(.system(size: 36, weight: .semibold)).monospacedDigit().foregroundStyle(.white)
            .frame(maxWidth: 130, alignment: .trailing)
        }
      }
      // The bar's place is kept in every phase, so the button never moves under your thumb.
      if state.phase == .rest { RestBar(state: state, up: up) } else { Capsule().fill(.white.opacity(0.12)).frame(height: 4) }
      StepButton(state: state, id: context.attributes.id)
    }.padding(16)
  }
}
