# GymBlock design

Onboarding follows **docs/ONBOARDING-V5-PLAN.md**. The app after onboarding follows **docs/WORKOUT-V6-PLAN.md** (V6 replaces the training and navigation parts of docs/UX-RESET-V3.md).

## Visual system

One look everywhere, set by onboarding: the dark ember stage (near-black, red-tinted dots, a low glow) behind every page, in dark appearance only. SF Pro with Dynamic Type; titles bold, labels medium, numbers monospaced. Liquid Glass on iOS 26 for every control: prominent white glass for the one primary action, glass steppers, rings, tiles, chooser rows and round icon buttons, with translucent fallbacks before iOS 26. Native Lists and Forms (settings, editors, history details) sit on the same stage.

White is the action; red (#FF626B) is the signal and nothing else — the live set, a finished rest, today in the week, a like-for-like gain, the "on" state of a toggle. Picker values are grey. Never a red background.

Keep 24-point margins and a fixed grid. The primary action sits in exactly the same place on Home, the workout and the summary (as on every onboarding page); a 20-point caption slot above it and a 44-point secondary slot below it are always reserved, so it never moves.

## Onboarding

Full spec: docs/ONBOARDING-V5-PLAN.md. Nineteen pages (seventeen for Rarely), one question or idea each: welcome; name; gender; height; weight; phone between sets; minutes per rest; phone time against training time; hours a year as 45-minute workouts; paired story stages (mind-muscle, pump, progress); app blocking; rest alerts; hold to commit; offer.

**Colour.** One dark *ember* stage on every page: near-black with warm red-tinted dots and a low glow. No page uses a red background. Red (#FF626B, the app's dark-mode red) is the signal — ≤2% of a screen, always the one thing to look at. Captions meet WCAG AA (≥ 4.5:1).

**Material.** Liquid Glass (iOS 26) for every control: prominent white glass for the primary action, glass answer cards, back button, notification cards, tiles and info cards; translucent fallbacks before iOS 26.

**Motion and touch.** Calm, one clock per page change: everything that changes fades out (0.18 s), the page swaps unseen, everything fades in (0.35 s); a stage shared by two pages stays put. Low-bounce springs; scenes start after the page settles; Continue fades in when a scene ends. Selecting an answer only selects; Continue moves on. Haptics are designed per moment: iOS-style double taps for notifications, crescendos for counting, a landing thud for reveals, rising impacts for each set, a ramp for the hold.

## Training and navigation

No tabs. Home, the workout or its summary fills the screen; a running workout always comes back first.

**Home** — the workout as the headline (`Up next · Push` with its exercises; splits rotate after each workout), one glass week card (seven day dots, today red, "2 of 5" against the goal, last workout; opens History), glass History and Settings buttons, and Start workout. "Sample data" stays visible when demo history is loaded. Tapping the workout name opens the chooser (Free workout, splits with an `…` edit/delete menu, New split).

**Workout** — top bar (clock with red live dot, Sets, End); exercise name + chevron (opens the picker) with set dots ("Set 2 of 3", target = last time's set count, else 3); the ring (ready: last time's best; set: the set clock; rest: fills to the rest length, then red with "Rest's up" and a double haptic; the length is changed in place); weight and reps glass steppers (plate-grid steps, hold to repeat, tap to type; typing hides the ring so the button stays above the keyboard); "Last set ›" for one-tap correction; one honest caption; the primary button. Start set → Finish set → rest → Start set; after last time's number of sets it becomes `Next: <exercise>` with `Another set` beneath (free workout: Next exercise; split done: Finish workout). A 0.6 s guard stops double taps. Zero reps finishes as a missed attempt. Settings → Time each set off makes it one tap per set (timing marked unknown, never guessed).

**Interruptions** — everything is a saved timestamp, so locking, calls and relaunches lose nothing. Rest's up is a local notification when locked; the Live Activity (Lock Screen and Dynamic Island) shows the set or rest clock, the next set and a Start/Finish button that carries its intent so a lagging display can't double-log. A workout idle for an hour gets a "Still training?" reminder and, on return, an offer to finish it at its last set. Implausible set clocks (< 3 s, or > 15 min for a rep set) are kept but marked unknown.

**Summary** — the headline, four counting glass tiles (time, sets, weight moved, average rest), "Better than last time" (same split, reps or load held constant), a per-exercise recap, Done; Save as split for free workouts.

History keeps reps and weight-moved totals (glass tiles → weekly bars), exercise progress (dated Before/After within one split or free scope) and the workout list with exercise names; a workout can be deleted from its detail page. Editing exposes weight/reps first and timing/date/warm-up under Details; unknown timing stays unknown. Settings order: workout (rest length, rest alert, time each set), blocking (simulated, labelled), you (name, body, units, language, haptics, sound), answers and data, account.

## Data and boundaries

Preserve local history, exercise/split IDs, actual reps, load conventions, timing provenance and sample markers. Demo loading is explicit/idempotent and never replaces existing work. Blocking remains simulated and is labelled wherever it appears; no live billing/account/backend service is configured. The Live Activity is local (no push).

Build success does not prove visual quality. Verify actual simulator layouts, full routes, keyboard and larger text, appearance, corrections, counter continuity and before/after records. Hardware haptic feel, physical-device handling and user comprehension need separate evidence.
