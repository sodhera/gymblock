# Validation — 3 October 2026

Native Swift/SwiftUI simulator prototype, Xcode 27 / iPhone 17 / iOS 27. Signing is disabled. No external services or package dependencies are configured.

## Gym-floor navigation and flexible exercise revision

The latest user correction is implemented: minimal Home with no lift-stat card, native Home / History / Splits navigation, upward rest counter, unrestricted exercise selection and explicit resolution of an unfinished set. Red and the Speaking Coach DM Sans visual system remain. The complete page review and primary competitor references are in `docs/GYM-FLOW-REVIEW.md`.

**27 model checks and nine distinct simulator journeys passed across the runs below.** Repeated journeys are counted once.

| Coverage | Evidence in ignored `build/` directory |
| --- | --- |
| All 27 model checks, including rest persistence/migration, save/discard switching with original exercise attribution, invalid-save rejection, timed switching, independent drafts, unchanged split templates, corrections and delete/undo | `NavigationModels.xcresult` — all 27 passed |
| Eight simulator journeys: empty History/Progress and split navigation, freestyle logging/correction/relaunch, reachable controls, native split editing and kg/lb, personal onboarding/resume, Spanish onboarding, split start/progress, skipped/zero answers and timed activity | `NavigationUI.xcresult` — eight passed; the ninth exposed the hidden native cancel option |
| All three unfinished-set choices, navigation/resume with active drafts, counter growth across tabs and reopening, preservation of the original exercise, saved set count, completed History and detail | `NavigationVerified.xcresult` — passed in 96 seconds on the final source |
| Native navigation, ready/active/rest actions, editable weight and onboarding with actual dark appearance, accessibility-large text and increased contrast | `NavigationAccessibilityFinal.xcresult` — passed in 78 seconds on the final source |

The initial native confirmation popover hid a cancel-role action. Keep training is now an explicit visible action for switching and ending. A screenshot review then caught clipped timer digits at large text size; elapsed timers now fit one line. The final dark/large-text captures show the complete value, and Home supporting text wraps to the left. A targeted test initially read the old exercise label during the dismissal animation; persisted data confirmed the correct saved set and selection. The final journey waits for the visible exercise transition and passes. No invalid-frame or AttributeGraph runtime warning appeared in either final UI run.

Current actual captures are in `screenshots/gym-flow/`, with final dark/large-text/increased-contrast screens in its `dark-large/` folder. Home, History, progress, splits, switch choices, original-set attribution, rest, corrections and onboarding were visually reviewed. The switched rest screen is captured after reopening, with 0:14 elapsed. Final Home is recaptured from the installed build. The simulator is restored to light appearance, standard text and normal contrast, on Home with Arms/Push/Legs and six weeks of sample history; Demo identifies sample data. Test resets affect only this prototype.

The rest source is a persisted start timestamp. Switching exercises, tabs or relaunching never resets it; starting a set clears it. Older countdown data migrate from the source record or legacy deadline/duration. Physical one-handed usability and animation preference remain unverified; this is simulator proof.

## Previous Speaking Coach visual revision

The user's latest correction replaces the earlier SF/flat UI with Speaking Coach's actual bundled DM Sans, warm paper, dot-grid backdrop, soft content surfaces, left-aligned headers and spacing. GymBlock keeps its red theme and existing workout behavior. Speaking Coach's source and reference screenshots were read only.

Four affected simulator journeys passed across two runs:

- `CoachStyleFlows.xcresult`: free workout/search, wheel/manual weight, actual reps, correction, relaunch and missed warm-up; personal onboarding and resumed answers; direct split start and before/after progress. All three passed.
- `CoachStyleAccessibility.xcresult`: final source build, actual dark appearance, accessibility-large text and increased contrast. Home, ready/active/rest, manual weight entry, welcome and routine setup remained usable. Passed in 67 seconds.

Actual screenshots from these runs are in `screenshots/coach-style/` and `screenshots/coach-style/dark-large/`. Home, workout, rest, onboarding and progress were visually inspected. Final Home was recaptured after installing the final build. The registered `UIAppFonts` entry and bundled unmodified font were verified; final built version remains 0.1.0 (1), iPhone only. No model/data logic changed, so earlier model evidence below is retained rather than reported as a fresh run. No invalid-frame or AttributeGraph runtime warning appeared in either new test run.

The simulator is restored to light appearance, standard text size and normal contrast, with the seeded Arms/Push/Legs and six weeks of sample data, on Home. The Demo marker identifies this data.

## Previous behavior verification

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

## Earlier visual evidence and simulator state

Actual captures are in `screenshots/redesign/`, with dark/large-text/increased-contrast captures in `screenshots/redesign/dark-large/`. Home, active set, rest, weight entry, onboarding and progress were inspected. These are rendered app screens with sample data, not design mockups. The parent screenshot folder contains the previous design.

The simulator is left in light appearance with its original text-size/contrast settings, on Home with Arms, Push and Legs splits and six weeks of sample workouts. The Demo label identifies sample history. Test resets apply only to this prototype's local storage.

## Limits

Real Screen Time blocking, billing, accounts, backend, signing and App Store delivery are not configured. Physical-iPhone ergonomics, VoiceOver navigation, OS Reduce Motion/Reduce Transparency behavior and older-iOS runtime appearance were not certified by these runs. The source uses native system materials, scaled DM Sans typography and a Reduce Motion branch, with an iOS 17–25 native-control fallback.

Animation preference and usability claims still require the proposed friend/user study. No muscle-gain, fat-loss or optimal-workout-time prediction is made.
