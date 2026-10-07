# GymBlock design

Onboarding follows **docs/ONBOARDING-V5-PLAN.md** (V5 replaces V4). Training and navigation retain **docs/UX-RESET-V3.md**, especially section 13 for text, icons and placement.

## Visual system

DM Sans remains bundled with its license. Use a flat warm canvas (#FBF8F5), warm ink, quiet secondary text and GymBlock red. Dark appearance has semantic warm near-black surfaces. No dot grid or CTA glow. Titles use semibold, controls medium, body regular; text scales with Dynamic Type. Native navigation, glass actions and the discrete slider are the functional material layer. Content records and numbers stay plain and readable. Earlier OS versions use native bordered controls.

Keep 24-point page margins, related elements together and a stable bottom action. One question/control/primary action on numeric onboarding pages. Choice rows have a selected checkmark only; no empty rings, decorative question icons or paragraph beneath every heading. Icons remain for native Back, tabs, Settings, search, disclosure, selection and reps +/−. No pencils, flames, trophies, success seals or button arrows.

## Onboarding

Full spec: docs/ONBOARDING-V5-PLAN.md. Seventeen pages (fifteen for Rarely): welcome; name, gender, height and weight; phone between sets and minutes per rest; one plain estimate (“34 min on your phone, every workout”) with four live − / + rows; an hours-a-year page shown as 45-minute workouts; three paired story stages (mind-muscle, pump, progress); app blocking; hold to commit; offer. Continue appears only after each scene finishes. Every page must be understood at a glance — no charts that need decoding, no jargon.

Onboarding has its own system, separate from the warm light app: near-black stage with a faint static dotted grid; white and two greys; one red accent reserved for the single thing to notice on a page; white primary button. SF Pro Dynamic Type text styles. A fixed grid — progress line (no text), two-line headline box, stage, one-line caption, bottom actions — keeps every element in the same place; the primary action never moves. One headline per page, no subtitles. Paired pages share a stage that morphs in place while only the words change. Motion uses native SwiftUI animations on shapes, trims, opacity and a pre-rendered arm flipbook; nothing is redrawn per frame by the app. No preview bypass: the offer is the end of onboarding.

## Training and navigation

Native tabs: **Workout / History / Splits**. Workout has a weekly activity line, optional selected split and Start workout. The exercise name and downward chevron form one full-width selector with a 56-point minimum target; its accessibility label says Change exercise. End workout is a quiet, 48-point bottom action beneath Start/Finish set, above the native tabs, including during initial exercise selection. Sets lives in the top bar when records or a draft exist. Ending during a set still resolves save/discard/keep, and switching exercises preserves the existing rest counter and records. Weight editing uses a wheel or typing, one at a time; units live in Settings. Zero is the supported Bodyweight value. First-use loads require an explicit choice.

Ready → Start set → actual reps/duration → Finish set → upward Rest → Start set. Record actual performance without enforcing onboarding averages. Rest uses persisted timestamps and survives exercise/tab changes and relaunch. An unfinished exercise change resolves finish/discard/keep; prior records retain their original exercise. Zero reps can record an attempt or be corrected/discarded. An empty ended session creates neither History nor summary. Sets is available when a draft or record exists; rare actions and detailed timing live there/in the editor.

History opens with reps and logged weight moved, exercise progress and chronological records. Totals open a metric detail with weekly bars and one filter menu. Before/After exercise progress uses dated like-for-like records within the same split identity, or free-workout scope. No Best lifts card, nested Workouts/Progress root or chart-style selector. Workout details group sets by exercise. Editing exposes weight/reps first and timing/date/warmup under Details; unknown timing stays unknown.

Splits are optional. A split detail shows its exercises, Start workout, Edit and Progress. Editors preserve IDs; adding exercises pushes within the editor rather than stacking sheets. Settings exposes compact preferences, training answers, honest Focus demo information and a separate Data page. Editing answers never restarts onboarding.

## Data and boundaries

Preserve local history, exercise/split IDs, actual reps, load conventions, timing provenance and sample markers. Demo loading is explicit/idempotent and never replaces existing work. Focus remains simulated and is labeled where active; no live billing/account/backend service is configured.

Build success does not prove visual quality. Verify actual simulator layouts, full routes, keyboard and larger text, appearance, corrections, counter continuity and before/after records. Hardware haptic feel, physical-device handling and user comprehension need separate evidence.
