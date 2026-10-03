# Validation — 3 October 2026

Native Swift/SwiftUI simulator prototype, Xcode 27 / iPhone 17 / iOS 27. Signing is disabled. No external services or package dependencies are configured.

## Workout-first Liquid Glass onboarding — current revision

The approved `docs/ONBOARDING-REDESIGN-PROPOSAL.md` is implemented. Welcome → workout frequency → visit duration → routine sketch comes before scrolling questions. Centered DM Sans, one visual focus, real native Liquid Glass controls, a fixed-length before/after timeline and deferred details replace the previous text/card-heavy setup. Just train immediately starts a free session; Go to Home completes setup without starting one. Existing workouts and survey drafts survive migration; sample data remains explicitly loaded.

**All 39 model checks passed, and nine distinct affected UI journeys passed across the targeted runs below.** Repeated journeys and device-size repeats are counted once. The entire historical UI suite was not rerun as one batch.

| Coverage | Evidence in ignored `build/` directory |
| --- | --- |
| All 39 model checks: prior workout/progress behavior plus stable onboarding migration, variable routines, actual scrolling breaks, fractional targets, impossible/unknown estimates, proposal persistence and survey deletion preserving training | `WorkoutFirstFinalModels.xcresult` — all 39 passed on final source |
| Personal setup/resume/goal/example/focus; manual minutes and inconsistent-answer correction/replay; Just train; missing/unknown answers; no scrolling/timed session/discard | `WorkoutFirstJourneys.xcresult` — five relevant journeys passed; its two outdated test expectations were corrected and rerun below |
| Empty History/Splits after finishing an empty skipped session; Spanish/back preservation; manual-entry comparison and reachable controls at 402 × 874 points | `WorkoutFirstFinalRoutes.xcresult` — all three passed |
| Small iPhone SE, 375 × 667 points, actual OS Reduce Motion and Reduce Transparency enabled; manual entry, complete comparison and duplicate-tap protection | `WorkoutFirstSmallFinal.xcresult` — compact UI journey and all 38 model checks existing at that stage passed |
| iPhone 17e, 390 × 844 points, standard effects; manual entry dismisses keyboard, full result and duplicate-tap protection | `WorkoutFirstMediumFinal.xcresult` — passed |
| iPhone 17, dark appearance, accessibility-large text and increased contrast; workout controls and onboarding duration/scrolling/minutes/before/after remain reachable | `WorkoutFirstAccessibility.xcresult` — passed |

The early preset run exposed native Form buttons triggering multiple preset actions; presets now use a borderless style. The medium-screen run exposed the keyboard surviving the manual-entry sheet; explicit keyboard dismissal fixed it. Visual inspection caught lower result controls overflowing the smallest screen; compact spacing now fits the complete result and actions together. The initial empty-history and Spanish tests expected an already-dismissed summary and an extra language submenu; final routes now follow the actual native navigation and pass. No invalid-frame or AttributeGraph warning appeared in the final normal, medium, small or accessibility UI logs.

The iOS 26.5 small-screen diagnostic confirmed UIKit reads **Reduce Motion = true and Reduce Transparency = true**. Its actual captures show opaque controls and the final comparison without animated interpolation. Main/medium devices use iOS 27. Large-text content scrolls where needed, with the primary action pinned. This verifies the selected simulator configurations, not a manual VoiceOver audit or every supported iOS release.

Actual app captures are in [`screenshots/onboarding-first/`](screenshots/onboarding-first/README.md), including compact, medium and dark/large-text routes. `before-after.mp4` is a short normal-speed simulator excerpt of the result transition; no audio is included. Screenshots and the clip were visually reviewed. The latest app is installed on the primary iPhone 17 simulator and left at the fresh welcome, in light appearance, standard text and normal contrast. Other review devices are shut down and the temporary SE device is removed after evidence export.

The estimate remains explicit: `(total sets − 1) × scrolling minutes`, or an edited actual count of scrolling breaks. Six exercises × three sets × two minutes between 17 gaps gives 34 minutes per visit and 102 across three visits. The timeline keeps visit duration fixed; proposed phone-free time includes necessary rest. Unknown or impossible inputs do not generate a fabricated reveal. Previewing/replaying a scenario creates no workout, achievement or saved goal; Use this goal is explicit.

Audio cues and independent mute/haptic preferences are implemented; prior decoder/playback checks remain in the final model suite. Physical-device sound levels and haptic feel, manual VoiceOver use, one-handed ergonomics and animation preference remain unverified. Focus blocking is still simulated. No body-composition or optimal-rest claim, account, billing, backend, signing or release work is included.

## Previous visible End workout, training totals and onboarding feedback

The workout toolbar has a visible End workout action in every session state. History → Progress → Training totals shows actual reps, recorded weight moved (load × completed reps) and sets, with trend and bar views and optional split scope. Summary includes reps and workload. Onboarding asks about between-set scrolling, reveals 1–5 minutes or manual More, and shows the break-count calculation. Short page/symbol/numeric animations, independent sound/haptic settings and a first-page mute control are implemented.

**32 model checks and five distinct affected simulator journeys passed across these runs.** Repeated journeys are counted once; the full older navigation suite was not rerun.

| Coverage | Evidence in ignored `build/` directory |
| --- | --- |
| All 32 model checks, including gap arithmetic, unknown and legacy answers, individual sets, inconsistent estimates, actual reps/workload, bodyweight/warm-up/timed/attempt handling, corrected/deleted/undone records, stable split scope, both bundled audio files and successful playback request/mute | `EnhancedJourneys.xcresult` — all 32 passed |
| Personal onboarding/resume; new scrolling question, mute, manual More, invalid-duration rejection and No correction; visible End/save and rep/workload/set charts; unknown/zero answers, timed activity and discard | `EnhancedJourneys.xcresult` — four journeys passed |
| Onboarding transitions, saved answers and weekly estimate with the final entrance/numeric motion implementation | `OnboardingMotionFinal.xcresult` — passed; actual simulator recording trimmed into `screenshots/enhanced/onboarding-motion.mp4` |
| Dark appearance, accessibility-large text and increased contrast: workout controls, routine entry and between-set answers | `EnhancedAccessibilityFinal.xcresult` — passed; the subsequent minute-grid refinement is verified in `OnboardingAccessibilityFinal.xcresult` |
| Dark/large-text/increased-contrast End/save and totals charts, stacked filters and readable date ticks | `TrainingStatsAccessibilityFinal.xcresult` — passed in 50 seconds |
| Final audio implementation, all 32 model checks, normal-size onboarding calculation/resume/mute and visible End/training totals | `EnhancementsFinal.xcresult` — all 32 model checks and both journeys passed |

The first totals run exposed an invalid-frame warning during a chart's animated unit change. The chart now rebuilds its scale without interpolating incompatible units; the numeric total still transitions. No invalid-frame or AttributeGraph warning appeared in the final accessibility chart run or the final normal-size run. The final run also has no audio activation warning about blocking the UI thread. Screenshot review caught overlapping large-text filters and narrow minute labels; filters stack vertically and minute choices use wider columns at accessibility sizes. The initial large-text test also searched for a lazily created control before scrolling; the test now scrolls to bring it into view.

The estimate is explicit: six exercises × three sets gives 18 sets and 17 gaps; two minutes of scrolling per gap gives 34 minutes per workout, or 102 minutes over three weekly visits. This is self-reported time, not measured phone use, unnecessary rest, or guaranteed time savings. No muscle-gain/fat-loss prediction is made.

Actual captures are in `screenshots/enhanced/`, including dark/large-text/increased-contrast captures. The short simulator video demonstrates visible page transitions; it does not establish animation preference. The final installed app is restored to light appearance and standard text/contrast on Home with Arms/Push/Legs and six weeks of labeled sample history.

Audio assets decode and the playback request succeeds in tests; mute prevents playback. Audio activation and playback run on a dedicated serial queue to avoid blocking UI transitions; haptic requests stay on the UI thread. Hardware haptic feel and physical-device sound levels remain unverified. OS Reduce Motion/Reduce Transparency runtime behavior and VoiceOver navigation were not certified. The source follows Reduce Motion and uses ambient sound that respects Silent mode and mixes with music. Focus blocking remains simulated.

## Previous gym-floor navigation and flexible exercise revision

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

Real Screen Time blocking, billing, accounts, backend, signing and App Store delivery are not configured. Physical-iPhone ergonomics and manual VoiceOver navigation remain unverified. The current onboarding revision above verifies OS Reduce Motion/Reduce Transparency on an iOS 26.5 simulator; iOS 17–25 runtime appearance remains unverified. The source uses native system materials, scaled DM Sans typography and a Reduce Motion branch, with an iOS 17–25 native-control fallback.

Animation preference and usability claims still require the proposed friend/user study. No muscle-gain, fat-loss or optimal-workout-time prediction is made.
