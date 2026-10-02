# Validation — 2 October 2026

GymBlock native Swift/SwiftUI simulator prototype. Xcode 27, iPhone 17, iOS 27. Code signing disabled; no external services configured.

All 16 checks passed: 12 model tests and 4 simulator UI tests. They cover direct set logging and automatic rest, fractional/manual/wheel entry, kg/lb conversion, state persistence across relaunch, optional split creation/editing, stable progress identity, comparisons at matching reps, repeat-safe demo seeding and clean onboarding. The final split identity change was followed by another successful run of all 12 model tests.

Actual simulator screenshots are in `screenshots/`: Home, exercise search, editable weight picker, active set, automatic rest, workout summary, split settings, starting a split and before/after progress. The simulator is populated with Arms, Push and Legs splits and six weeks of sample workouts so the complete experience can be tried immediately.

Local test results: `build/Verified.xcresult` and `build/FinalModelChecks.xcresult` (ignored by Git). Both runs ended with `TEST SUCCEEDED`.

This does not verify physical-iPhone blocking, billing, release signing, App Store upload or production accessibility certification. Blocking and purchases are simulated.
