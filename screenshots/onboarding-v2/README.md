# Onboarding V2 — actual simulator captures

These are captures of the running SwiftUI app, not mockups. The default gallery uses iPhone 17 / iOS 27; its settled rest/comparison and workout-record captures use iPhone 17e. `dark-large/` uses dark appearance, accessibility-large text and increased contrast. `medium/` contains the iPhone 17e route (390 × 844 points), including fractional scrolling minutes and the final labeled timing editor.

## Workout questions

One answer at a time: days/week, visit duration, reps, sets and exercises. Only then do scrolling, rest timing, logging/review and set timing appear.

<img src="journey-02-days.png" width="220" alt="One selector for 1–7 training days"> <img src="journey-03-visit-picker.png" width="220" alt="One inline minutes wheel"> <img src="journey-04-reps.png" width="220" alt="One reps question and wheel">

<img src="journey-09-rest-habit.png" width="220" alt="Rest timing question"> <img src="journey-10-log-habit.png" width="220" alt="Logging and review question"> <img src="journey-11-set-time-habit.png" width="220" alt="Set timing question">

## A connected explanation

Reported scrolling becomes possible phone-free time while visit duration and necessary rest remain. An illustrative upward rest counter and a same-weight rep example lead into an outlined future record. The personal example shows 34 minutes/visit, 6 h 48 min over four weeks and 216 sets that could be tracked. None creates saved workouts or a prediction of body changes.

[Watch the actual focus → rest → progress sequence](focus-rest-progress.mp4). This example uses five scrolling breaks at half a minute each: 2.5 min/visit and 30 min over four weeks. The four-week training record remains 216 sets and approximately 2,160 reps. The recording is a continuous excerpt from the successful simulator test; it has no recorded sound.

<img src="journey-12-attention-before.png" width="220" alt="Reported scrolling time"> <img src="journey-13-attention-after.png" width="220" alt="Same visit with possible phone-free time"> <img src="journey-18-four-week-record.png" width="220" alt="Outlined prospective four-week record">

## Real workout records

Saved sets show elapsed set time and gaps. The timing editor keeps persistent labels. The actual last-four-week report counts recorded sessions, separately from onboarding projections.

<img src="journey-workout-timing-editor.png" width="220" alt="Timing correction fields"> <img src="journey-workout-saved-timing.png" width="220" alt="Saved set and gap timings"> <img src="journey-workout-four-week-reps.png" width="220" alt="Recorded reps in the last four weeks">

## Larger text

The complete personalized route and timing/history/report route passed with dark appearance, accessibility-large text and increased contrast. Question content scrolls when necessary while Continue stays reachable. Frequency becomes a single wheel at accessibility sizes.

<img src="dark-large/journey-02-days.png" width="220" alt="Large text day wheel"> <img src="dark-large/journey-08-scroll-minutes.png" width="220" alt="Large text scrolling minutes"> <img src="dark-large/journey-workout-timing-editor.png" width="220" alt="Persistent timing labels at large text">

These captures prove visible simulator behavior. They do not establish physical haptic feel, sound volume, manual VoiceOver usability or users' animation preferences. See [validation](../../VALIDATION.md) for the test runs and remaining limits.
