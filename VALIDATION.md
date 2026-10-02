# Validation — 2 October 2026

Native Swift/SwiftUI simulator prototype, Xcode 27 / iPhone 17 / iOS 27. Signing is disabled. No external services or package dependencies are configured.

## Checks completed

22 model checks and seven distinct simulator journeys have passed across the redesign and targeted verification runs. Repeated runs are not counted as additional checks.

| Coverage | Evidence in ignored `build/` directory |
| --- | --- |
| All 22 model checks: migration, duplicate/invalid logging, extra/fewer reps, attempts, cancellation, relaunch, independent exercise drafts, rest preservation, corrections, delete/undo, missed warm-ups, like-for-like progress and onboarding estimates | `FinalModelAndUnits.xcresult` — 22 model checks plus the split/unit journey, all 23 passed; no runtime warnings |
| Free workout: search, wheel/manual weight, actual reps, correction, relaunch, missed warm-up during an active set, exercise change and unsuccessful attempt | `FinalWorkoutVisuals.xcresult` — both final workout journeys passed |
| Split creation, manual weight, kg/lb conversion, deletion and undo restoring rest | `UnitIdentityVerified.xcresult` — passed; stored JSON confirms 10 kg remains exactly 10 kg after displaying 22.05 lb |
| Personal onboarding: answers survive relaunch, 60 min × 3 visits = 180 gym min/week, 10 feed min × 3 visits = 30 feed min/week, custom reduction goal | `EntryVerified.xcresult` — this individual journey passed |
| None/unknown answers, skipped setup, timed activity and discarding an unfinished set | `FinalWorkoutVisuals.xcresult` — passed |
| Two-tap split start and progress; Spanish onboarding and Back preserving answers | `RedesignFinal.xcresult` — complete 28-check run passed before the final keyboard/color refinements |
| Reachable workout/onboarding controls and editable weight, with actual simulator dark appearance, accessibility-large text and increased contrast | `FinalAccessibility.xcresult` — passed on the final UI |

The model and unit-entry results were repeated after the data and keyboard fixes. Unit-only edits preserve the exact canonical mass rather than re-saving the rounded display value; `build/unit-identity-storage-proof.json` records the inspected 10 kg example. The accessibility journey was repeated after the final semantic text-color correction. Keyboard entry uses the same Save/Finish action; redundant keyboard toolbars were removed. A unit conversion check commits the typed load before reopening the editor to avoid stale simulator hit positions during keyboard movement.

## Visual evidence and simulator state

Actual captures are in `screenshots/redesign/`, with dark/large-text/increased-contrast captures in `screenshots/redesign/dark-large/`. Home, active set, rest, weight entry, onboarding and progress were inspected. These are rendered app screens with sample data, not design mockups. The parent screenshot folder contains the previous design.

The simulator is left in light appearance with its original text-size/contrast settings, on Home with Arms, Push and Legs splits and six weeks of sample workouts. The Demo label identifies sample history. Test resets apply only to this prototype's local storage.

## Limits

Real Screen Time blocking, billing, accounts, backend, signing and App Store delivery are not configured. Physical-iPhone ergonomics, VoiceOver navigation, OS Reduce Motion/Reduce Transparency behavior and older-iOS runtime appearance were not certified by these runs. The source uses native system materials, semantic styles and a Reduce Motion branch, with an iOS 17–25 native-control fallback.

Animation preference and usability claims still require the proposed friend/user study. No muscle-gain, fat-loss or optimal-workout-time prediction is made.
