# GymBlock design

Onboarding follows **docs/ONBOARDING-CLEAR-JOURNEY-V4.md**. Training and navigation retain **docs/UX-RESET-V3.md**, especially section 13 for text, icons and placement.

## Visual system

DM Sans remains bundled with its license. Use a flat warm canvas (#FBF8F5), warm ink, quiet secondary text and GymBlock red. Dark appearance has semantic warm near-black surfaces. No dot grid or CTA glow. Titles use semibold, controls medium, body regular; text scales with Dynamic Type. Native navigation, glass actions and the discrete slider are the functional material layer. Content records and numbers stay plain and readable. Earlier OS versions use native bordered controls.

Keep 24-point page margins, related elements together and a stable bottom action. One question/control/primary action on numeric onboarding pages. Choice rows have a selected checkmark only; no empty rings, decorative question icons or paragraph beneath every heading. Icons remain for native Back, tabs, Settings, search, disclosure, selection and reps +/−. No pencils, flames, trophies, success seals or button arrows.

## Onboarding

Welcome → days/week → visit length → reps → sets → exercises → scrolling → conditional minutes and Sometimes break count → rest measurement → records/review → set measurement → brain comparison → rest illustration → record comparison → subscription offer.

Welcome says “Stay focused. Stay intentional.” Frequency uses the real seven-tick UISlider on iOS 26+, storing whole days 1–7. Other numeric questions use one inline UIPickerView. Continue confirms numbers; Not sure stores unknown. Full questions explain what is being asked. Habit choices save and advance with one tap. Timed exercises can skip reps while answering the other questions. Existing ranges/per-exercise details remain unchanged unless explicitly edited. Saved route IDs and completed onboarding persist.

Skip questions enters the benefits, not a real workout. Back preserves answers and follows the entry path. No scrolling clears obsolete minute/break answers and bypasses those questions while retaining all three benefit scenes. Estimates remain optional, self-reported and editable; no body-growth or transformation prediction is invented.

Two opaque brain characters shrink/frown or grow/smile beside red meters, with tired/social-logo or lightning particles behind them. The finite sequence lasts 9.2 seconds. The exact requested nervous-system sentence is preserved as quoted draft copy immediately labeled **Your proposed copy · Unverified health claim**. It is not presented as an established fact.

The original approved PNG arm illustration is tinted as a whole, with a blended elbow deformation. Both begin relaxed and blue. The chosen stylized model adds 25 points per contraction and loses 5/25 points in timed/longer rests; the timed meter reaches Perfect Pump on rep five. A single optional completion chime, brief bar vibration and aura mark the event. The 10.6-second sequence ends still. There are no numeric activation claims. **Stylized model · Not measured muscle activation** stays visible.

The record comparison shows five rows, chronological from Week 1 to Today. Older values are unknown on the left; right-hand weight × reps comparisons show +25%, −10%, +25%, +33.3%. Both have the same latest record. Examples never enter History. Normal text compares side by side; accessibility text stacks whole panels without shrinking their text. Scenes can replay, cancel on disappearance/backgrounding, and never disable Continue. Reduced Motion renders stable final states. Sound defaults off and can be enabled in the benefit header.

The final action opens the subscription offer before Workout home. StoreKit loading, verified purchase, pending/cancel/failure, restore and transaction updates are implemented behind explicit configuration. Actual product IDs, legal URLs and working shielding are absent, so live purchasing is disabled. No fake price/trial or false purchase success appears. Debug builds have a clearly labeled **Preview workout** entry to test the app without payment; Release does not have this bypass. Existing completed onboarding, records and active workouts are preserved.

## Training and navigation

Native tabs: **Workout / History / Splits**. Workout has a weekly activity line, optional selected split and Start workout. The exercise name and downward chevron form one full-width selector with a 56-point minimum target; its accessibility label says Change exercise. End workout is a quiet, 48-point bottom action beneath Start/Finish set, above the native tabs, including during initial exercise selection. Sets lives in the top bar when records or a draft exist. Ending during a set still resolves save/discard/keep, and switching exercises preserves the existing rest counter and records. Weight editing uses a wheel or typing, one at a time; units live in Settings. Zero is the supported Bodyweight value. First-use loads require an explicit choice.

Ready → Start set → actual reps/duration → Finish set → upward Rest → Start set. Record actual performance without enforcing onboarding averages. Rest uses persisted timestamps and survives exercise/tab changes and relaunch. An unfinished exercise change resolves finish/discard/keep; prior records retain their original exercise. Zero reps can record an attempt or be corrected/discarded. An empty ended session creates neither History nor summary. Sets is available when a draft or record exists; rare actions and detailed timing live there/in the editor.

History opens with reps and logged weight moved, exercise progress and chronological records. Totals open a metric detail with weekly bars and one filter menu. Before/After exercise progress uses dated like-for-like records within the same split identity, or free-workout scope. No Best lifts card, nested Workouts/Progress root or chart-style selector. Workout details group sets by exercise. Editing exposes weight/reps first and timing/date/warmup under Details; unknown timing stays unknown.

Splits are optional. A split detail shows its exercises, Start workout, Edit and Progress. Editors preserve IDs; adding exercises pushes within the editor rather than stacking sheets. Settings exposes compact preferences, training answers, honest Focus demo information and a separate Data page. Editing answers never restarts onboarding.

## Data and boundaries

Preserve local history, exercise/split IDs, actual reps, load conventions, timing provenance and sample markers. Demo loading is explicit/idempotent and never replaces existing work. Focus remains simulated and is labeled where active; no live billing/account/backend service is configured.

Build success does not prove visual quality. Verify actual simulator layouts, full routes, keyboard and larger text, appearance, corrections, counter continuity and before/after records. Hardware haptic feel, physical-device handling and user comprehension need separate evidence.
