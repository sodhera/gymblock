# GymBlock

A native SwiftUI workout prototype built around one action at a time. The visual design uses Speaking Coach’s DM Sans, warm paper, soft content surfaces and left-aligned hierarchy, with GymBlock’s red as the only brand accent. Native Liquid Glass controls sit above readable workout content.

## Try it

Open **GymBlock.xcodeproj**, select **GymBlock** and an iPhone simulator, then Run. Xcode 26+ with an iOS 17+ simulator is required. Liquid Glass uses the supported native controls on iOS 26+; earlier versions use native bordered controls. The verified environment is Xcode 27 / iPhone 17 / iOS 27.

The shared Debug scheme passes `--demo`. An empty store opens Home with **Arms, Push and Legs**, six weeks of sample history and lift records. The Home **Demo** label identifies that history. New test workouts and split edits save locally; relaunch keeps them. Demo loading never replaces existing history, splits or an active workout.

To try the complete onboarding, remove `--demo` on a fresh install. With existing data, **Settings → Edit routine answers** opens it without deleting workouts. For a clean test, Debug-only `--ui-reset` clears this app's data; use it only when resetting test data intentionally. Alternatively run `./run-simulator.sh` to build and launch the populated simulator.

## Workout flow

- Native navigation: **Home · History · Splits**. Home contains the streak, **Free workout** or optional split choice, and **Start workout**. It contains no lift-stat card.
- A split opens its first exercise ready to start. Free workout opens recent exercises and native search; type `dum` for dumbbell exercises.
- Choose a weight on the first use of an exercise; later sets remember it. Tap the weight for manual entry, a native wheel or +/−. Weight is 0–500 in the chosen kg/lb unit; fractions are supported. Zero is labeled **Bodyweight**. Changing units preserves the load and converts its display.
- **Start set → enter actual completed reps → Finish set.** Previous reps are a draft, not a target. Extra or fewer reps use the same flow. Reps support 1–999.
- **Rest elapsed** starts at 0:00 and counts up. **Start next set** works whenever you are ready. Changing exercises, switching tabs and relaunching preserve its original start; there is no expiry or configured rest duration.
- **Change exercise** and the exercise title stay tappable in every set state. After saving, switch immediately. During an unfinished set, choose **Save set and switch**, **Discard current set and switch** or **Keep training**. Earlier sets stay saved under their original movement. The session picker shows this workout, recent exercises and search.
- Tap the saved-set row to correct, delete or mark a warm-up. The visible **End workout** button stays in the workout navigation bar. **Workout options** contains uncommon actions, including cancelling an unperformed set, recording a zero-rep unsuccessful attempt, inspecting sets and adding a missed completed set.
- The **End workout** button saves completed work and ends the focus representation. An active set offers save/discard/keep-training choices. Unsuccessful attempts stay in history but never become lift records or completed-workout streaks.

The **Splits** tab is the direct route to the optional editor. Home’s **Manage splits** also selects that tab; the existing Settings shortcut remains available. Rename/reorder without losing progress identity. Deleting a split retains history. **History → Workouts** shows older sessions and editable sets. **History → Progress** contains best lifts as plain content, split comparisons, and **Training totals** with Reps / Weight moved / Sets trend and bar charts. Weight moved sums logged load × completed reps; bodyweight adds no guessed load, warm-ups count, and timed activity/attempts stay separate. You can browse these during training and use **Resume workout** or Home to return without losing the draft or counter. Progress compares either load at identical reps or reps at identical load, within the same exercise and split. The chosen before/after animation respects Reduce Motion; the chart is behind History.

## Onboarding

Seven short screens: language/name and purpose, distractions, gym time/frequency, usual exercises/sets/reps, between-set scrolling and minutes per break, personal summary, optional focus demo. Questions can be skipped. Typical values, ranges, per-exercise differences and per-set rep lists are supported. Unknown stays unknown; values are not silently filled in. Answers save locally and survive reopening.

Scrolling estimates use (sets − 1) × minutes per break × weekly visits, with the every-break assumption visible. Onboarding uses short transitions, entrance/numeric animations, selection/success haptics and local sound cues. A mute control is present from the first page; Settings also has Sounds and Haptics toggles. Reduce Motion keeps a short fade. Time totals are clearly attributed to the user's estimates. Reduction goals are goals. Necessary rest is never called wasted time, and no muscle-gain/fat-loss prediction is made. These survey answers are separate from completed workout records and demo history. Edit or delete them in Settings.

## Actual simulator screens

<img src="screenshots/enhanced/enhanced-01-visible-end-choice.png" alt="Workout with visible End workout button" width="240"> <img src="screenshots/enhanced/enhanced-05-volume-bars.png" alt="Total weight moved and workload bars" width="240"> <img src="screenshots/enhanced/enhanced-07-between-sets.png" alt="Between-set scrolling question and calculation" width="240">

Current captures and a short recording of onboarding transitions are in [screenshots/enhanced](screenshots/enhanced/README.md). Earlier captures in `screenshots/gym-flow/`, `screenshots/coach-style/` and `screenshots/redesign/` document previous revisions.

## Boundaries

Focus blocking remains a simulator representation. No Screen Time restriction, installed-app discovery or real permission prompt exists. **Focus demo** explicitly labels the session. Logging works with focus disabled. No purchases, paywall, account, network API, analytics, backend or cloud sync are configured. UserDefaults persists local data; iOS may include it in system backups.

This is a simulator prototype. Physical-iPhone handling, real system enforcement, billing, signing and App Store delivery are separate work. Previous implementations remain in Git history.

## Development and verification

`project.yml` is authoritative; `xcodegen generate` regenerates the included project. No package dependencies are required. Product → Test runs model checks and simulator UI journeys. Use `-parallel-testing-enabled NO` for UI tests against one simulator.

The latest [progress and onboarding details](docs/PROGRESS-AND-ONBOARDING.md) cover calculations and feedback. The page-by-page review and competitor references are in [docs/GYM-FLOW-REVIEW.md](docs/GYM-FLOW-REVIEW.md). The design and edge-case decisions are in [docs/REDESIGN-PLAN.md](docs/REDESIGN-PLAN.md). Current verification evidence and limits are in [VALIDATION.md](VALIDATION.md).
