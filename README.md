# GymBlock

A local SwiftUI workout prototype with a red theme, DM Sans typography and native Liquid Glass controls. Open the app, pick an exercise, start a set, record actual reps and get back to training.

## Run

Open **GymBlock.xcodeproj** and run **GymBlock** on an iPhone simulator. The app supports iOS 17+; native Liquid Glass and discrete tick configuration are available on iOS 26+. The current development environment is Xcode 27 / iOS 27.

The Debug scheme opens onboarding for a new store. Add `--demo` when needed: an empty store gets Arms, Push and Legs plus six weeks of labeled sample history. It never overwrites existing history, splits or an active workout. Leave that argument off for onboarding on a fresh install. Debug-only `--ui-reset` is for disposable test data, not a normal onboarding reset. **Settings → Training answers** edits baseline information without replaying setup or deleting workouts. Sample loading also lives in **Settings → Data** when the store is empty.

## Experience

- **Workout / History / Splits** are stable native tabs. Tab changes preserve the active set and rest counter.
- Workout opens with weekly activity, Free workout or a remembered split, and Start workout. Splits start at their first exercise; freestyle opens exercise search.
- Weight uses either a native wheel or direct typing. Fractions and loads up to 500 in the selected unit are supported; zero is Bodyweight. Change units in Settings.
- **Start set → actual reps → Finish set → Rest → Start set.** Rest counts up and survives exercise changes and relaunch. Timed exercises record actual elapsed duration.
- Tap the **exercise name and chevron** to change exercises; an active set offers finish/discard/keep. **End workout** sits below Start/Finish set, above the tabs. Empty sessions create no saved workout or summary.
- **Sets** in the top bar opens grouped records and uncommon actions; tap a saved row to correct it. Timing/date/warmup live in Details. Missing timing is not invented.
- History shows reps, logged weight moved and workout records immediately. Exercise progress shows dated Before/After comparisons, holding weight or reps constant within the same exercise/split or free-workout scope. Metric details show weekly bars; weight moved is logged load × completed reps, with no guessed bodyweight load.
- Splits have a useful detail page with Start, Edit and Progress. Editing retains identity; deleting a split retains history.

## Onboarding

Seventeen short pages: name, gender, height and weight; one tap for how often you use your phone between sets and one wheel for how long; then one plain fact (“Sirish, here’s your phone time — 34 min every workout, ≈ 147 hours a year, or 196 workouts of 45 min”) with − / + rows for exercises, sets, minutes per rest and workouts per week. Three paired animated stages follow — mind-muscle connection, timed rests, memory vs log — then choosing apps to block, a hold-to-commit pledge and the offer. Minimal dark stage, SF Pro Dynamic Type, one red accent; see [DESIGN.md](DESIGN.md) and [docs/ONBOARDING-V5-PLAN.md](docs/ONBOARDING-V5-PLAN.md).

The estimate is the person's own minutes multiplied out — not measured phone use or a body-outcome prediction. Height, weight and gender stay on the device and are not used yet; the weight unit sets kg/lb for logging. The mind-muscle headline is the user-approved “Scrolling weakens your mind-muscle connection.”; scenes are labelled illustrations, examples never create workout history, and blocking remains simulated and labelled.

The offer ends onboarding; there is no preview bypass. StoreKit handling exists behind explicit configuration, but no live subscription, product price, legal URL or shielding service is configured, so Subscribe stays disabled with an honest caption. In Debug, launch with `--demo` to enter the app. Real purchasing requires `GymBlockPurchasesEnabled`, `GymBlockMonthlyProductID`, `GymBlockTermsURL` and `GymBlockPrivacyURL`, plus verified blocking and release validation; do not enable billing to sell simulated blocking.

## Current design and proof

The native onboarding follows [docs/ONBOARDING-V5-PLAN.md](docs/ONBOARDING-V5-PLAN.md); training/navigation retain [docs/UX-RESET-V3.md](docs/UX-RESET-V3.md). [DESIGN.md](DESIGN.md) records the implemented decisions. Runtime evidence and remaining limits are in [VALIDATION.md](VALIDATION.md). The browser motion preview is a reference, distinct from native simulator evidence.

`project.yml` is the XcodeGen source of truth. Product → Test runs model checks and simulator journeys; use `-parallel-testing-enabled NO` for UI testing on one simulator.

## Prototype boundaries

Focus blocking remains simulated and labeled where active. Actual prices, payments, Screen Time enforcement, accounts, backend, analytics and cloud sync are not configured. Records persist locally. Physical-device usability, haptic feel, audible sound levels and release delivery need separate verification.
