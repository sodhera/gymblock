# GymBlock

A local SwiftUI workout prototype: a dark ember stage, SF Pro Dynamic Type and native Liquid Glass. Open the app, tap Start, lift, tap Finish, and put the phone away — the rest counts on the Lock Screen.

## Run

Open **GymBlock.xcodeproj** and run **GymBlock** on an iPhone simulator. The app supports iOS 17+; native Liquid Glass and discrete tick configuration are available on iOS 26+. The current development environment is Xcode 27 / iOS 27.

The Debug scheme opens onboarding for a new store. Add `--demo` when needed: an empty store gets Arms, Push and Legs plus six weeks of labeled sample history. It never overwrites existing history, splits or an active workout. Leave that argument off for onboarding on a fresh install. Debug-only `--ui-reset` is for disposable test data, not a normal onboarding reset. **Settings → Training answers** edits baseline information without replaying setup or deleting workouts. Sample loading also lives in **Settings → Data** when the store is empty.

## Experience

Full design, tap budget and edge cases: [docs/WORKOUT-V6-PLAN.md](docs/WORKOUT-V6-PLAN.md). Screens: [screenshots/app-v6](screenshots/app-v6/).

- **Home** is one decision: the workout that's up next (splits rotate after each workout) and **Start workout**. A glass week card shows this week's days and the last workout and opens History; Settings and History are glass buttons. No tab bar.
- **Workout** is one screen with one button in a fixed place: **Start set → Finish set → rest → Start set**. Last time's weight and reps are pre-filled; `−`/`+` step one plate (2.5 kg / 5 lb), or tap a value to type it. The ring times the set, then fills toward the rest length and turns red when rest's up. After last time's number of sets the button offers **Next: <exercise>**. Tap the exercise name to switch; the rest keeps counting.
- **Interrupted?** Everything is saved as it happens: locking, calls and relaunches lose nothing. The **Live Activity** shows the rest on the Lock Screen and in the Dynamic Island with a Start/Finish set button, so sets can be logged without unlocking. A workout left running for an hour asks to finish at its last set. Double taps, Start/Finish back to back, forgotten Finishes, zero-rep misses and first-time loads are all handled (see the plan).
- **Summary** counts up time, sets, weight moved and average rest, lists like-for-like gains over the last same-split workout, and offers Save as split for free workouts.
- **History** shows reps and weight-moved totals, exercise progress (Before/After within one split or free scope) and every workout, which can be corrected or deleted. Settings → **Time each set** off makes logging one tap per set.

## Onboarding

Nineteen short pages, one question each: name, gender, height, weight; how often and how long you use your phone between sets; then one ring that sets phone time against training time in a typical workout ("34 of 46 minutes on your phone"), and the year in 45-minute workouts ("147 hours = 196 workouts"). Paired animated stages follow — mind-muscle connection, timed rests, memory vs log — then app blocking, rest alerts, a hold-to-commit pledge and the offer. Ember-dotted dark stage on every page (no red backgrounds); Liquid Glass controls; SF Pro Dynamic Type; see [DESIGN.md](DESIGN.md) and [docs/ONBOARDING-V5-PLAN.md](docs/ONBOARDING-V5-PLAN.md).

The estimate is the person's own minutes multiplied out — not measured phone use or a body-outcome prediction. Height, weight and gender stay on the device and are not used yet; the weight unit sets kg/lb for logging. The mind-muscle headline is the user-approved “Scrolling weakens your mind-muscle connection.”; scenes are labelled illustrations, examples never create workout history, and blocking remains simulated and labelled.

The offer ends onboarding; there is no preview bypass (Debug builds with no product configured show a labelled **Skip paywall (Debug build)** for simulator use). StoreKit handling exists behind explicit configuration, but no live subscription, product price, legal URL or shielding service is configured, so Subscribe stays disabled with an honest caption. In Debug, launch with `--demo` to enter the app. Real purchasing requires `GymBlockPurchasesEnabled`, `GymBlockMonthlyProductID`, `GymBlockTermsURL` and `GymBlockPrivacyURL`, plus verified blocking and release validation; do not enable billing to sell simulated blocking.

## Account and alerts

Settings → **Log out** returns to onboarding and keeps workouts, splits and history on the iPhone. **Delete account** permanently erases everything GymBlock stores, after a confirmation. There is no server account yet; both act on this device only and are ready for the planned login. **Rest alert** sends one local notification when a rest reaches the chosen length (default 1:30; changed in Settings or right on the rest ring). **Body** edits gender, height and weight. In Debug, `--skip-onboarding` re-enters the app after logging out, `-journeyStep <page>` opens onboarding on one page with sample answers, and `-workoutStage ready|active|rest|restUp|next|stale|summary` opens a sample Push workout in that state (none are in Release).

## Current design and proof

The native onboarding follows [docs/ONBOARDING-V5-PLAN.md](docs/ONBOARDING-V5-PLAN.md); the app after it follows [docs/WORKOUT-V6-PLAN.md](docs/WORKOUT-V6-PLAN.md). [DESIGN.md](DESIGN.md) records the implemented decisions. Runtime evidence and remaining limits are in [VALIDATION.md](VALIDATION.md). The browser motion preview is a reference, distinct from native simulator evidence.

`project.yml` is the XcodeGen source of truth. It builds the app and **GymBlockLive**, the Live Activity extension. Product → Test runs model checks and simulator journeys; use `-parallel-testing-enabled NO` for UI testing on one simulator.

## Prototype boundaries

Blocking remains simulated and labelled wherever it appears. The Live Activity is updated locally, with no push. Actual prices, payments, Screen Time enforcement, accounts, backend, analytics and cloud sync are not configured. Records persist locally. Physical-device usability, haptic feel, audible sound levels and release delivery need separate verification.
