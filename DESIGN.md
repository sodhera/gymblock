# GymBlock design

Onboarding follows **docs/ONBOARDING-V5-PLAN.md** (V5 replaces V4). Training and navigation retain **docs/UX-RESET-V3.md**, especially section 13 for text, icons and placement.

## Visual system

DM Sans remains bundled with its license. Use a flat warm canvas (#FBF8F5), warm ink, quiet secondary text and GymBlock red. Dark appearance has semantic warm near-black surfaces. No dot grid or CTA glow. Titles use semibold, controls medium, body regular; text scales with Dynamic Type. Native navigation, glass actions and the discrete slider are the functional material layer. Content records and numbers stay plain and readable. Earlier OS versions use native bordered controls.

Keep 24-point page margins, related elements together and a stable bottom action. One question/control/primary action on numeric onboarding pages. Choice rows have a selected checkmark only; no empty rings, decorative question icons or paragraph beneath every heading. Icons remain for native Back, tabs, Settings, search, disclosure, selection and reps +/−. No pencils, flames, trophies, success seals or button arrows.

## Onboarding

Full spec: docs/ONBOARDING-V5-PLAN.md. Nineteen pages (seventeen for Rarely), one question or idea each: welcome; name; gender; height; weight; phone between sets; minutes per rest; phone time against training time; hours a year as 45-minute workouts; paired story stages (mind-muscle, pump, progress); app blocking; rest alerts; hold to commit; offer.

**Colour.** One dark *ember* stage on every page: near-black with warm red-tinted dots and a low glow. No page uses a red background. Red (#FF626B, the app's dark-mode red) is the signal — ≤2% of a screen, always the one thing to look at. Captions meet WCAG AA (≥ 4.5:1).

**Material.** Liquid Glass (iOS 26) for every control: prominent white glass for the primary action, glass answer cards, back button, notification cards, tiles and info cards; translucent fallbacks before iOS 26.

**Motion and touch.** Calm, one clock per page change: everything that changes fades out (0.18 s), the page swaps unseen, everything fades in (0.35 s); a stage shared by two pages stays put. Low-bounce springs; scenes start after the page settles; Continue fades in when a scene ends. Selecting an answer only selects; Continue moves on. Haptics are designed per moment: iOS-style double taps for notifications, crescendos for counting, a landing thud for reveals, rising impacts for each set, a ramp for the hold.

## Training and navigation

Native tabs: **Workout / History / Splits**. Workout has a weekly activity line, optional selected split and Start workout. The exercise name and downward chevron form one full-width selector with a 56-point minimum target; its accessibility label says Change exercise. End workout is a quiet, 48-point bottom action beneath Start/Finish set, above the native tabs, including during initial exercise selection. Sets lives in the top bar when records or a draft exist. Ending during a set still resolves save/discard/keep, and switching exercises preserves the existing rest counter and records. Weight editing uses a wheel or typing, one at a time; units live in Settings. Zero is the supported Bodyweight value. First-use loads require an explicit choice.

Ready → Start set → actual reps/duration → Finish set → upward Rest → Start set. Record actual performance without enforcing onboarding averages. Rest uses persisted timestamps and survives exercise/tab changes and relaunch. An unfinished exercise change resolves finish/discard/keep; prior records retain their original exercise. Zero reps can record an attempt or be corrected/discarded. An empty ended session creates neither History nor summary. Sets is available when a draft or record exists; rare actions and detailed timing live there/in the editor.

History opens with reps and logged weight moved, exercise progress and chronological records. Totals open a metric detail with weekly bars and one filter menu. Before/After exercise progress uses dated like-for-like records within the same split identity, or free-workout scope. No Best lifts card, nested Workouts/Progress root or chart-style selector. Workout details group sets by exercise. Editing exposes weight/reps first and timing/date/warmup under Details; unknown timing stays unknown.

Splits are optional. A split detail shows its exercises, Start workout, Edit and Progress. Editors preserve IDs; adding exercises pushes within the editor rather than stacking sheets. Settings exposes compact preferences, training answers, honest Focus demo information and a separate Data page. Editing answers never restarts onboarding.

## Data and boundaries

Preserve local history, exercise/split IDs, actual reps, load conventions, timing provenance and sample markers. Demo loading is explicit/idempotent and never replaces existing work. Focus remains simulated and is labeled where active; no live billing/account/backend service is configured.

Build success does not prove visual quality. Verify actual simulator layouts, full routes, keyboard and larger text, appearance, corrections, counter continuity and before/after records. Hardware haptic feel, physical-device handling and user comprehension need separate evidence.
