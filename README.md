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
- Tap the saved-set row to correct, delete or mark a warm-up. **Workout options** contains uncommon actions, including cancelling an unperformed set, recording a zero-rep unsuccessful attempt, inspecting sets and adding a missed completed set.
- **End workout** saves completed work and ends the focus representation. An active set offers save/discard/keep-training choices. Unsuccessful attempts stay in history but never become lift records or completed-workout streaks.

The **Splits** tab is the direct route to the optional editor. Home’s **Manage splits** also selects that tab; the existing Settings shortcut remains available. Rename/reorder without losing progress identity. Deleting a split retains history. **History → Workouts** shows older sessions and editable sets. **History → Progress** contains best lifts as plain content and split comparisons. You can browse these during training and use **Resume workout** or Home to return without losing the draft or counter. Progress compares either load at identical reps or reps at identical load, within the same exercise and split. The chosen before/after animation respects Reduce Motion; the chart is behind History.

## Onboarding

Seven short screens: language/name and purpose, distractions, gym time/frequency, usual exercises/sets/reps, self-reported scrolling time, personal summary, optional focus demo. Questions can be skipped. Typical values, ranges, per-exercise differences and per-set rep lists are supported. Unknown stays unknown; values are not silently filled in. Answers save locally and survive reopening.

Time totals are clearly attributed to the user's estimates. Reduction goals are goals. Necessary rest is never called wasted time, and no muscle-gain/fat-loss prediction is made. These survey answers are separate from completed workout records and demo history. Edit or delete them in Settings.

## Actual simulator screens

<img src="screenshots/gym-flow/gym-flow-01-home.png" alt="Minimal Home with streak and native navigation" width="240"> <img src="screenshots/gym-flow/gym-flow-02-history.png" alt="History with dated workout records" width="240"> <img src="screenshots/gym-flow/gym-flow-07-switched-with-rest-counter.png" alt="Elapsed rest after switching exercises, with the original saved set labeled" width="240">

Current captures are in [screenshots/gym-flow](screenshots/gym-flow/). Earlier captures in `screenshots/coach-style/` and `screenshots/redesign/` document earlier designs.

## Boundaries

Focus blocking remains a simulator representation. No Screen Time restriction, installed-app discovery or real permission prompt exists. **Focus demo** explicitly labels the session. Logging works with focus disabled. No purchases, paywall, account, network API, analytics, backend or cloud sync are configured. UserDefaults persists local data; iOS may include it in system backups.

This is a simulator prototype. Physical-iPhone handling, real system enforcement, billing, signing and App Store delivery are separate work. Previous implementations remain in Git history.

## Development and verification

`project.yml` is authoritative; `xcodegen generate` regenerates the included project. No package dependencies are required. Product → Test runs model checks and simulator UI journeys. Use `-parallel-testing-enabled NO` for UI tests against one simulator.

The latest page-by-page review and competitor references are in [docs/GYM-FLOW-REVIEW.md](docs/GYM-FLOW-REVIEW.md). The design and edge-case decisions are in [docs/REDESIGN-PLAN.md](docs/REDESIGN-PLAN.md). Current verification evidence and limits are in [VALIDATION.md](VALIDATION.md).
