import ActivityKit
import SwiftUI
import WidgetKit

@main struct GymBlockLiveBundle: WidgetBundle {
  var body: some Widget {
    WorkoutLiveActivity()
    UpNextWidget()
    MonthWidget()
    WeekWidget()
    StreakWidget()
    if #available(iOS 18.0, *) { StartWorkoutControl() }
  }
}

/// The Lock Screen wears the app's light paper (2 Nov 2026, at the user's request: the dark card read
/// as heavy); the Dynamic Island is always black, so it keeps the dark tokens. Emerald is the only
/// signal, as in the app.
private struct Tone {
  let stage, text, secondary, signal: Color
  static let paper = Tone(stage: Paper.stage.light.color, text: Paper.ink.light.color,
                          secondary: Paper.secondary.light.color, signal: Paper.signal.light.color)
  static let island = Tone(stage: Paper.stage.dark.color, text: Paper.ink.dark.color,
                           secondary: Paper.secondary.dark.color, signal: Paper.signal.dark.color)
}

/// The set and the rest on the Lock Screen and in the Dynamic Island, so you never need to unlock
/// the phone between sets. When the rest length passes the activity goes stale: "Rest’s up" and the
/// mark's iron turn emerald, and the clock counts how far over, in grey.
struct WorkoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
      LockScreenWorkout(context: context)
        .activityBackgroundTint(Tone.paper.stage)
        .activitySystemActionForegroundColor(Tone.paper.text)
    } dynamicIsland: { context in
      let state = context.state
      let up = state.phase == .rest && context.isStale && state.pausedAt == nil
      let tone = Tone.island
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 10) {
            IslandMark(state: state, up: up).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
              Text(state.exercise).font(.system(size: 17, weight: .semibold)).foregroundStyle(tone.text).lineLimit(1)
              Text(detail(state)).font(.system(size: 13)).foregroundStyle(tone.secondary).monospacedDigit().lineLimit(1)
            }
          }.padding(.leading, 6)
        }
        DynamicIslandExpandedRegion(.trailing) {
          VStack(alignment: .trailing, spacing: 0) {
            Text(label(state, up: up)).font(.system(size: 13, weight: .medium)).foregroundStyle(up ? tone.signal : tone.secondary)
            ClockText(state: state, up: up, tone: tone).font(.system(size: 30, weight: .semibold))
          }.frame(maxWidth: 110, alignment: .trailing).padding(.trailing, 6)
        }
        DynamicIslandExpandedRegion(.bottom) {
          StepButton(state: state, id: context.attributes.id, tone: tone).padding(.horizontal, 6).padding(.top, 6)
        }
      } compactLeading: {
        IslandMark(state: state, up: up).frame(width: 22, height: 22)
      } compactTrailing: {
        ClockText(state: state, up: up, tone: tone).frame(width: 48)
      } minimal: {
        IslandMark(state: state, up: up).frame(width: 20, height: 20)
      }.keylineTint(tone.signal)
    }
  }
}

/// The brand mark in the Dynamic Island, in place of a timer symbol: the iron in the island's white
/// (emerald once the rest is up, dimmed while paused), the keyhole always emerald.
private struct IslandMark: View {
  let state: WorkoutActivityAttributes.ContentState
  let up: Bool
  var body: some View {
    ZStack {
      KettlebellShape(part: .iron).fill(up ? Tone.island.signal : Tone.island.text, style: FillStyle(eoFill: true))
      KettlebellShape(part: .keyhole).fill(Tone.island.signal)
    }
    .opacity(state.pausedAt != nil ? 0.5 : 1)
    .accessibilityHidden(true)
  }
}

/// "Set 2 of 3 · 80 kg × 5": where they are and what's next, on one grey line.
private func detail(_ state: WorkoutActivityAttributes.ContentState) -> String {
  state.next.isEmpty ? state.progress : state.progress + " · " + state.next
}

private func label(_ state: WorkoutActivityAttributes.ContentState, up: Bool) -> String {
  if state.pausedAt != nil { return state.pausedLabel }
  switch state.phase {
  case .rest: return up ? state.restUp : state.restLabel
  case .set: return state.setLabel
  case .ready: return state.readyLabel
  }
}
private extension WorkoutActivityAttributes.ContentState {
  /// When the rest runs out (the activity's stale date). Never before `since`, so no range is backwards.
  var restEnd: Date { since.addingTimeInterval(Double(max(0, restSeconds))) }
}

/// The phase's clock, counted by the system with no updates. The set, and the workout while ready
/// (`since` leaves out paused time), count up; the rest counts down the time left, as in the app,
/// then how far over in grey. Never emerald: the label and the mark carry rest's up.
private struct ClockText: View {
  let state: WorkoutActivityAttributes.ContentState
  let up: Bool
  let tone: Tone
  /// Rest's up, or paused after the rest ran out (frozen at how far over, as the app shows it).
  private var over: Bool { up || (state.phase == .rest && state.pausedAt.map { $0 >= state.restEnd } == true) }
  var body: some View {
    Group {
      if state.phase != .rest {
        Text(timerInterval: state.since...Date.distantFuture, pauseTime: state.pausedAt, countsDown: false)
          .foregroundStyle(tone.text)
      } else if over {
        HStack(spacing: 0) {
          Text(verbatim: "+")
          Text(timerInterval: state.restEnd...Date.distantFuture, pauseTime: state.pausedAt, countsDown: false)
        }.foregroundStyle(tone.secondary).accessibilityElement(children: .combine)
      } else {
        Text(timerInterval: state.since...state.restEnd, pauseTime: state.pausedAt, countsDown: true)
          .foregroundStyle(tone.text)
      }
    }
    .monospacedDigit()
    .multilineTextAlignment(.trailing)
  }
}

/// Start set / Finish set without unlocking. Runs in the app; the activity updates itself after.
/// The ink button, as the app's one primary action.
private struct StepButton: View {
  let state: WorkoutActivityAttributes.ContentState
  let id: String
  let tone: Tone
  var body: some View {
    if !state.action.isEmpty {
      Button(intent: WorkoutStepIntent(workoutID: id, step: state.pausedAt != nil ? "resume" : state.phase == .set ? "finish" : "start")) {
        Text(state.action).font(.system(size: 15, weight: .semibold)).foregroundStyle(tone.stage)
          .frame(maxWidth: .infinity, minHeight: 40)
      }.buttonStyle(.plain).background(Capsule().fill(tone.text))
    }
  }
}

/// One focal point, the clock; the exercise and one grey line beside it; the button below. No bar,
/// no workout name: the banner stays light and nothing moves between phases.
private struct LockScreenWorkout: View {
  let context: ActivityViewContext<WorkoutActivityAttributes>
  var body: some View {
    let state = context.state
    let up = state.phase == .rest && context.isStale && state.pausedAt == nil
    let tone = Tone.paper
    VStack(spacing: 14) {
      HStack(alignment: .lastTextBaseline) {
        VStack(alignment: .leading, spacing: 4) {
          Text(state.exercise).font(.system(size: 19, weight: .semibold)).foregroundStyle(tone.text).lineLimit(1)
          Text(detail(state)).font(.system(size: 15)).foregroundStyle(tone.secondary).monospacedDigit().lineLimit(1)
        }
        Spacer(minLength: 12)
        VStack(alignment: .trailing, spacing: 0) {
          Text(label(state, up: up)).font(.system(size: 13, weight: .medium)).foregroundStyle(up ? tone.signal : tone.secondary)
          ClockText(state: state, up: up, tone: tone).font(.system(size: 40, weight: .semibold))
            .frame(maxWidth: 140, alignment: .trailing)
        }
      }
      StepButton(state: state, id: context.attributes.id, tone: tone)
    }.padding(.horizontal, 18).padding(.vertical, 16)
  }
}
