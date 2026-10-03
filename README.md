# GymBlock

A native SwiftUI workout prototype built around one action at a time. The visual design uses Speaking Coach’s DM Sans, warm paper, soft content surfaces and deliberate type hierarchy, with GymBlock’s red as the only brand accent. Native Liquid Glass controls sit above readable workout content.

## Try it

Open **GymBlock.xcodeproj**, select **GymBlock** and an iPhone simulator, then Run. Xcode 26+ with an iOS 17+ simulator is required. Liquid Glass uses the supported native controls on iOS 26+; earlier versions use native materials or bordered controls. The verified environment is Xcode 27 / iPhone 17 / iOS 27.

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

The workout-first flow uses Speaking Coach’s centered onboarding composition: **Welcome → frequency → visit length → routine sketch → scrolling → minutes → before/after → ready**. No/unknown scrolling bypasses the estimate. One editable value or visual focus sits on each screen; the routine sketch groups exercises, sets and reps. Tap values for a compact editor, presets or manual entry. Rep ranges and mostly timed routines are supported. Name stays in Settings; language, sound and haptics are in the onboarding options menu. App categories appear only in the optional final Focus demo sheet.

**Just train** immediately opens free-workout exercise selection with focus off. **Start workout** on the last scene starts training; **Go to Home** does not. The optional example shows Start set → actual reps → Stop → upward rest, without saving records. No sample history is automatically created by onboarding; use Settings → Load sample workouts or the explicit Debug `--demo` route to populate the prototype.

The default estimate is `(total sets − 1) × scrolling minutes per break`, with an editable actual-break override. Six exercises × three sets and two minutes gives 34 minutes per workout; three weekly visits gives 102. Inconsistent estimates request correction instead of being capped. Unknown values stay unknown. The same fixed-length visit timeline transforms estimated scrolling into a possible phone-free scenario, including necessary rest. Half/no-scrolling can be previewed and replayed; **Use this goal** explicitly saves a goal. No muscle/fat prediction is made and survey/demo values never become History achievements.

Draft answers, stable scene identifiers and the proposed scenario survive relaunch. Older step indices and survey data migrate without deleting workouts. Sequential fades prevent overlapping pages; numeric changes, a responsive sketch and the timeline provide purposeful animation. Sound/haptic preferences are independent. Reduce Motion shortens transitions; reduced transparency has an opaque fallback. Physical-device sound/haptic tuning and user preference testing remain separate verification.

## Actual simulator screens

<img src="screenshots/onboarding-first/01-welcome.png" alt="Centered GymBlock welcome" width="240"> <img src="screenshots/onboarding-first/onboarding-03-duration.png" alt="One editable visit duration" width="240"> <img src="screenshots/onboarding-first/onboarding-08-after.png" alt="Possible phone-free time" width="240">

Current onboarding captures and motion evidence are in [screenshots/onboarding-first](screenshots/onboarding-first/README.md). Workout and progress captures remain in [screenshots/enhanced](screenshots/enhanced/README.md); earlier folders document previous revisions.

## Boundaries

Focus blocking remains a simulator representation. No Screen Time restriction, installed-app discovery or real permission prompt exists. **Focus demo** explicitly labels the session. Logging works with focus disabled. No purchases, paywall, account, network API, analytics, backend or cloud sync are configured. UserDefaults persists local data; iOS may include it in system backups.

This is a simulator prototype. Physical-iPhone handling, real system enforcement, billing, signing and App Store delivery are separate work. Previous implementations remain in Git history.

## Development and verification

`project.yml` is authoritative; `xcodegen generate` regenerates the included project. No package dependencies are required. Product → Test runs model checks and simulator UI journeys. Use `-parallel-testing-enabled NO` for UI tests against one simulator.

The current [onboarding specification](docs/ONBOARDING-REDESIGN-PROPOSAL.md) covers the new flow, calculations and motion. The page-by-page review and competitor references are in [docs/GYM-FLOW-REVIEW.md](docs/GYM-FLOW-REVIEW.md). The design and edge-case decisions are in [docs/REDESIGN-PLAN.md](docs/REDESIGN-PLAN.md). Current verification evidence and limits are in [VALIDATION.md](VALIDATION.md).
