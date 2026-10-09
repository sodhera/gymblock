# Validation — 8 October 2026

Native Swift/SwiftUI simulator prototype with one app extension (GymBlockLive, the Live Activity). Latest checks use Xcode 27 / iPhone 18 Pro / iOS 27.0. Signing is disabled. No external services or package dependencies are configured.

## Redesign pass (8 October 2026)

The review in [docs/UX-REVIEW-2026-10-08.md](docs/UX-REVIEW-2026-10-08.md) was implemented in full the same day. What changed, and how it was checked:

- **Brand and launch.** App icon rendered by `scripts/generate-app-icon.swift` (paper stage, ink rest ring, emerald dot); the wordmark on the welcome page and the offer card. The white launch cover is gone: a screen recording of a cold launch measured per-frame brightness and no longer shows the spike the old build had (old: 0 → 114 → 0 on a 0–255 scale over ~10 frames; new: Home Screen → stage colour with no rise).
- **Palette and scale.** The red ember was rejected (alarming), then a graphite-and-mint scheme (still black). Three directions were rendered on the same four screens (paper, an indigo dusk, a slate) and the person chose **paper**: warm off-white stage, ink type, white Liquid Glass, an ink primary button, emerald (#0F9A6B) as the only signal, light appearance. Every colour comes from `JourneyTheme.paper`; literal whites in views became `JourneyColor.ink(_:)` so tracks and hairlines read on a light stage. In the same pass every element was scaled down (28-pt headlines, 50-pt buttons, 52-pt rows, 18–20-pt radii, 16-pt padding, 160–220-pt ring, 44-pt hero numbers). The Live Activity keeps its dark palette because it sits on the Lock Screen.
- **Type and voice.** Headlines are `.largeTitle` bold, centred in the two-line box; eyebrows label blocks. Captions and qualifiers rewritten in plain words (listed in DESIGN.md); the Debug paywall link reads "Continue without subscribing · Debug".
- **Illustration.** The approved arm and brain scenes are unchanged (an interim replacement was reverted the same day). Blocked apps are monograms on glass.
- **Onboarding.** A chosen answer rises with a white edge and a red check instead of a red block. Continue fades in when a scene ends, as before.
- **Navigation.** The global transparent navigation-bar appearance is gone, so History, Settings and every editor get the native iOS 26 Liquid Glass bar; Home and the workout put their controls (History, Settings; the pause clock, Sets, End) in that bar as glass toolbar items instead of custom buttons.
- **Home.** Greeting, the split's exercises with last time's best set, the last gain on the week card, a "How it works" card before the first workout. A plain column at normal text sizes (nothing moves), a scroll view at accessibility sizes.
- **Workout.** Ember glow behind the ring disc, a visible track, larger set dots, the pause control as a white play/pause disc, the End confirmation as an alert so Keep going is always visible, and accessibility sizes no longer clip the reps stepper or the ring clock (ring 176 pt, clock 44 pt, captions on two lines).
- **Summary.** A headline that changes with the workout (gain / first workout / otherwise), one hero number with a glow, three small tiles, red arrows on gains.
- **History and progress.** Weekly bar chart with this week in red and Reps / Weight moved pills; exercise progress defaults to the most recent workout's scope (it opened on an empty "Free workouts" scope before); Before/After tiles, the difference as a headline, the line chart inline; workout list without truncated exercise names.
- **Spanish.** Every new string has an entry in `JourneyLanguage.swift`.

Proof: [screenshots/redesign-2026-10-08](screenshots/redesign-2026-10-08/) (31 captures: icon, every onboarding page, Home empty and with sample data, the workout in ready, rest and rest's-up states, the End alert, Summary, History, exercise progress, a workout detail, Home and the workout at Accessibility M). The previous state is in [screenshots/review-2026-10-08](screenshots/review-2026-10-08/) for comparison.

**Splits step and de-templating (8 October, later).** A twentieth onboarding page, Set up your splits, follows the offer: add a split (the existing editor as a sheet: name, Add exercises with search, reorder, delete), rows spring in, the first split becomes Home's Up next, Start training finishes onboarding; Skip for now while empty. The interim templated styling was removed (tracked uppercase labels, monogram tiles, the Get started tagline, the numbered How-it-works card, fixed-size hero fonts) and directional page motion plus staggered Home reveals were added. Proven by a fresh-install walk from welcome to Home: `screenshots/redesign-2026-10-08/onboarding-*.png` and `onboarding-overview.png`. No test suite was run after this change (running tests spawns hidden simulator clones; see the note below).

**Split editor, exercise picker, Home progress (8 October, later still).** The editor shows the name as a title-sized field, numbered rows with the exercise's area, drag/swipe editing and a count; the picker groups by area with signal-coloured checks and a count pill on Done. Home's week card became a Progress card: weekly weight-moved line (Swift Charts, animated draw-in), a guarded four-week comparison, a streak and the week dots. First build crashed on a chart axis type mismatch (Int x against a Double domain), fixed by using Double x values; the first chart frame takes about half a second on first launch while Charts compiles its pipeline. Captures: `21-home.png`, `20-home-first-run.png`, `onboarding-21`–`24`.

**Home scoreboard (8 October, evening).** The person found the exercise card and the "Up next" headline noise and asked what stats the app should actually show. Home now measures the three onboarding promises: a Consistency card (twelve-week day grid, streak, this week vs goal; `HomeStats.swift`), Rests on time (rests within target + 30 s grace over 28 days, average shown) and Lifts up (like-for-like improvements over 28 days). Start workout opens the chooser, whose rows now start the workout; the up-next split is marked. UI tests were updated for the new start path (`freeWorkout()` and `start(_:)` helpers, `choice.Push` taps) but not run. That scoreboard was then cut back on request to what the mainstream gym apps show: the streak number, "2/5 this week", and a bar chart of workouts per week with a goal line (`HomeScoreboard.swift`). That read as empty, so the final Home is the gamified one: streak card with flame, goal ring and day dots; three chips (workouts, PRs, rests on time); then, on request, an auto-advancing per-exercise carousel (`ExerciseCarousel`, `exerciseTrends`) instead of the weekly chart, the day dots removed from the streak card (the ring already says 2/5), the greeting removed from the bar, and a labelled example scoreboard for a new log. Then: day dots back on the streak card, dots under the carousel card, the greeting back as the title, Start 24 pt lower, the counters replaced by Since-last-PR and Time-training cards, and every card tappable (streak → History, a graph → that exercise's progress, PR → its exercise, time → `TimeTrainingView`). Captures: `21-home.png`, `20-home-first-run.png`, `23-home-pr-detail.png`, `24-home-time-detail.png`. Streaks count consecutive weeks with any workout, as Hevy does. Captures: `21-home.png`, `20-home-first-run.png`, `22-start-chooser.png`.

Tests (earlier the same day): **all 72 model checks pass and all 17 UI tests pass** (BenefitLayout, GymBlockFlow, JourneyV5, WorkoutActions; iPhone 18 Pro / iOS 27.0, `-parallel-testing-enabled NO`). One UI test string was updated for the reworded minutes headline ("How long on your phone, each rest?"). The UI run was made on the build before the last two layout fixes (a fixed-height caption spacer on Home and the workout, and the large-text ring size); those were re-checked by hand with captures of Home and the workout at Accessibility M and at the default size.

## V6 rev. 1 — pause (8 October 2026)

The workout clock in the top bar is now also the pause control.
- **While paused:**
  - The workout clock and whatever is counting (a rest or a set) freeze where they are. The ring dims and says "Paused" in red, and Resume becomes the primary action.
  - Rest alerts are held and the simulated block lifts (the caption says so).
  - The Lock Screen activity shows "Paused" with frozen clocks and a Resume button.
- **On resume:** the set and rest anchors move forward by the pause, so paused time never counts as training, rest or set time, and the clocks carry on from the same second.
- **Edge cases:** starting or finishing a set while paused resumes first. Ending while paused ends the workout when the pause began. A pause of an hour or more brings up "Still working out? Paused at 19:42." with Resume or Finish.

Two new model checks cover frozen and shifted clocks, a set paused mid-way, Lock Screen resume ignoring a stale Start, and the stale prompt and end time while paused. A new UI test pauses mid-rest, confirms both clocks stay frozen for 2.5 s, then resumes. Two tests had depended on the weekday through the rotating sample split and now choose it explicitly.

**All 72 model checks pass, and the 12 workout UI tests pass**, including the new pause journey (iPhone 18 Pro / iOS 27.0).
- The pause, resume and Next tests and the split journey passed on the final build.
- The other five flow journeys passed on the build just before; the only change since was a label's test identifier.

The first run caught two real problems, both fixed:
- Glass applied to the clock's label swallowed the tap.
- The rest label's identifier overrode "Paused".

Checked by hand in the simulator:
- Resume continues the workout clock from 9:00 and the rest from 1:20.
- The Lock Screen shows Paused with a Resume button.

Screens: `screenshots/app-v6/16-paused.png`, `17-lock-screen-paused.png`.

## V6 — the app after onboarding (7 October 2026)

[docs/WORKOUT-V6-PLAN.md](docs/WORKOUT-V6-PLAN.md) is implemented. The app now matches onboarding (ember stage, SF Pro, Liquid Glass, white action and red signal only; DM Sans removed) and has no tab bar.
- **Home** is one decision: the split that's up next (splits rotate) and Start workout, plus a glass week card.
- **The workout** is one screen whose primary button sits in exactly the same frame as Home's Start and the summary's Done:
  - a ring for the set clock and the rest (red with a double haptic when rest's up, length changed in place)
  - weight and reps glass steppers on the plate grid, with typing and Start set above the keyboard
  - "Next: <exercise>" after last time's number of sets
- **Interruptions:** everything is a saved timestamp. A workout idle for an hour offers to finish at its last set. Implausible set clocks are marked unknown, a 0.6 s guard stops double taps, and zero reps is a missed attempt.
- **Live Activity:** a new **GymBlockLive** extension shows the set or rest clock, the next set and a Start/Finish set button on the Lock Screen and in the Dynamic Island. The button carries its intent so a lagging display can't double-log.
- **Summary:** counting glass tiles, like-for-like "Better than last time" (same split, reps or load held constant), a recap and Save as split.
- **History and Settings:** History gains exercise names and Delete workout. Settings is reordered and adds Time each set (one-tap logging) and the rest length.
- **Debug:** `-workoutStage <state>` opens a sample workout in any state, and a Debug-only "Skip paywall (Debug build)" enters the app when no product is configured.

**All 70 model checks pass**, including 12 new ones:
- plate-grid stepping, first-use loads, bodyweight lifts, zero reps as a miss
- targets from last time, and Next wrapping to skipped exercises
- one-tap logging without invented timing, and implausible set clocks marked unknown
- a forgotten workout ending at its last set, split rotation and like-for-like gains
- Lock Screen steps ignoring stale taps, rest length bounds, average rest, deleting a workout

**All 11 workout UI tests pass** on the final build (iPhone 18 Pro / iOS 27.0), each a whole gym flow:
- a free workout with typing, a correction, a mid-rest exercise switch and a mid-set app kill and relaunch
- log out and delete account
- creating a split, then rotation to the next one, then Before/After progress
- a missed attempt, one-tap logging and an empty workout
- larger text across History, Settings and the workout
- a custom exercise with no invented load and typed "60" saved exactly
- the primary button in the same frame on Home, ready, set, rest and summary
- a double tap neither finishing nor restarting a set
- Next after the last set, with the rest still counting
- a workout left running finishing at its last set (30 min, not 2.5 h)

**The 5 onboarding UI tests passed on the preceding build**; later changes touched only the workout screen, its tests and Debug sample data.

What earlier runs caught, all fixed and rerun:
- The ring animated continuously, so the app was never idle and UI tests crawled. It now eases each second, then rests.
- Removing and re-inserting the ring while typing left its container with infinite accessibility frames. It now folds in place, and the column scrolls only at accessibility sizes.
- iOS hid a cancel-role "Keep going" button.
- Settings rows below the fold load lazily, and the tests now scroll to them.
- A long weight like 102.5 made the steppers stack; long values now scale down instead.
- The stepper label wasn't a tap target for typing; now it is.

Verified by hand in the simulator:
- The Lock Screen and Dynamic Island activity, plus Start set and Finish set from the Lock Screen with the app in the background.
- The rest turning red when stale.
- Typing a weight, which updates the Lock Screen.

Screenshots of every state are in [screenshots/app-v6](screenshots/app-v6/) (overview.jpg). The attention heatmaps (heatmaps/) put the predicted peak on the ring's clock during sets and rests, and on the workout or exercise name on Home and ready.

Not verified: haptic feel on hardware, Live Activity behaviour on a physical device and with Live Activities declined (iOS's "Allow Live Activities" prompt was left unanswered in the simulator), and real gym use.

## V5 rev. 7 — ember stage, Liquid Glass, one question per page (7 October 2026)

Every onboarding page uses the dark ember stage (near-black, red-tinted dots, low glow); a trial red background for Welcome/Commit/Offer was rejected and removed, and red remains a signal only. Controls are Liquid Glass on iOS 26 (prominent white glass primary, glass answer cards, back button, notification cards, tiles, info cards) with translucent fallbacks. Gender, height and weight each have their own page; answers only select and Continue moves on. The phone-time page has no adjusters: one ring sets phone time (red, 34 min) against training (white, 12 min) in an assumed typical workout of 6 exercises × 3 sets with 2-minute rests, and the next page converts 5 workouts a week into 147 h = 196 workouts of 45 min. Motion is slower and low-bounce (0.6 s pages, scenes start after the page settles); haptics are designed per moment. The arm poses render in parallel from launch (1.3 s). Captions now meet WCAG AA (4.7:1, previously 2.7:1). Hidden Continue buttons are hidden from accessibility too.

Page changes now run on one clock: everything that changes fades out (0.18 s), the page swaps unseen, everything fades in (0.35 s); shared stages stay put. A 30 fps recording previously showed the old content ghosting for ~0.7 s under the new headline; it now shows no overlap. **All 58 model checks and the five onboarding UI tests pass** on the final build (iPhone 18 Pro / iOS 27.0). The seven workout/account UI tests passed on the immediately preceding build of this revision; later changes only touched onboarding. The first run exposed a Continue button that VoiceOver and XCUITest could reach before it was visible, and glass buttons taller than the hold button; both were fixed and rerun.

## V5 rev. 6 — review fixes, rest alerts, Log out / Delete account (7 October 2026)

Fixes from the principles and heatmap reviews: gender, height and weight merged into one "Tell us about you." page (heatmap middle-third attention 21% → 51%), editable later in Settings → Body; a rest-alert priming page followed by the real iOS prompt, plus working local rest notifications (one pending alert when a rest reaches the chosen length, default 1:30; Settings → Rest alert). Workout fixes from the first UX review: ending a workout with saved sets asks for confirmation; number fields never select-all after typing has begun; "1 set" pluralisation. Settings adds **Log out** (back to onboarding, workouts kept) and **Delete account** (erases all local data after a confirmation; only that button is red). Debug-only `--skip-onboarding` re-enters the app for development; it is not in Release.

**Full suite: all 58 model checks and all 13 UI tests pass** on iPhone 18 Pro / iOS 27.0, including the new account journey (log out keeps history; delete leaves nothing to resume), a typed "60" saving exactly 60 kg, the End-workout confirmation, the merged profile page with gender-based defaults, and the rest-alert prompt. The "typed 60 → 6 kg" issue from the first review did not reproduce with realistic typing and was most likely simulator keystroke injection; the field logic was hardened regardless. The final tint-only change was followed by a rerun of the account test (passed). Heatmaps re-run for all 18 states.

## V5 rev. 5 — hours as workouts, labelled axes, heatmap review (7 October 2026)

The yearly page now reads "That’s 147 hours a year." with a dot per 45-minute workout (= 196 workouts at defaults); no name or "days". Both pump charts label the y-axis (Pump), x-axis (Time →), each rest ("Rest 3:40" / "Rest 1:30") and the target (FULL PUMP); the progress chart labels Weight × reps and Week →. An attention-heatmap review using Apple's on-device saliency model ([docs/HEATMAP-REVIEW.md](docs/HEATMAP-REVIEW.md)) led to three changes, each re-measured: the pump chart now precedes a smaller arm (peak moved from the arm to the chart), the memory values are larger (middle-third attention 31% → 40%), and the mind-muscle notifications are brighter. **Full suite on the final build: all 55 model checks and all 12 UI tests pass** (5 onboarding journeys, 5 workout/history/splits flows, 2 workout-action placement checks), iPhone 18 Pro / iOS 27.0.

## V5 rev. 4 — notifications, minutes made concrete, pump, hold to commit (7 October 2026)

Welcome and first question replace the outline phone with real-looking notification cards (stack, cascade away, lock). The phone-time page fills a ring with one segment per rest while the count climbs; a new page turns the yearly total into calendar days and one-hour workouts. The rest pair is rebuilt around a pump-over-time chart: 3:40 phone rests drain every set to zero and never reach PUMP; 1:30 rests stair-step up to it. Continue appears only after each scene finishes (≤ 3 s; 6 s safety net). A hold-to-commit page with three pledges precedes the paywall. Default workouts per week is 5. Haptics fire on every page change and animation beat. A principles review is in docs/ONBOARDING-PRINCIPLES-REVIEW.md.

**55 model checks and five onboarding UI journeys pass** (iPhone 18 Pro / iOS 27.0), including 46 min → "8 days a year" / "199 one-hour workouts", an early release that does not commit, a full hold that does, blocking and Not now both routing to commit, and the primary action (including the hold button) staying at one height. Walkthrough review caught and fixed: Turn on blocking skipping the commit page, the ring lighting at 0 min, a stray partial calendar tile, overlapping headlines during transitions, and awkward headline line breaks. Two test assertions were corrected (XCUITest waits for animations, so the hidden-Continue state is verified visually instead).

## V5 rev. 3 — profile questions, plain estimate, faster motion (7 October 2026)

After review: the estimate page was hard to read and the motion felt slow. The estimate now states one fact (“34 min on your phone, every workout”, ≈ 118 h a year) with four labelled − / + rows; the lifting comparison and its 3 s/rep assumption were removed. Name, gender and height/weight (Metric/Imperial, defaults from gender, weight unit sets kg/lb) follow the welcome; the name personalises the estimate and offer headlines. The persistent full-screen iris mask, which forced every animation through an offscreen pass, was replaced by a 0.35 s white cover that removes itself; the dotted background is a cached bitmap. Transitions are 0.32 s, one-tap answers advance after 0.18 s and story sequences finish in 1.5–2.5 s. A 10 s recording across the story stages on a heavily swapping 16 GB Mac had 447 of 450 frame gaps at 60 or 30 fps.

**All 54 model checks and five onboarding UI journeys pass** (iPhone 18 Pro / iOS 27.0), including the required name, gender-based height defaults, imperial conversion (178 cm → 5′ 10″), a + tap updating 34 → 46 min, personalised headlines, the Rarely route and relaunch on the offer. One journey initially failed on a test assertion about the VoiceOver label format; it was corrected and rerun.

## V5 — minimal onboarding redesign (7 October 2026)

[docs/ONBOARDING-V5-PLAN.md](docs/ONBOARDING-V5-PLAN.md) is implemented after design feedback on the first V5 pass (too red, too much text, rudimentary and laggy motion). Changes: near-black stage with a static dotted grid; white primary button; red reserved for one focal element per page; SF Pro Dynamic Type; a fixed grid where the headline box, stage and primary action never move; one headline per page with no subtitles or progress text; the minutes question now asks per rest (default 2 min); a live estimate page with five native dials; paired story pages that morph a shared stage; no Preview bypass on the paywall.

Performance: the animated ember backdrop, button shimmer, per-word blur, full-page blur transitions and per-frame Canvas/filters were removed. The arm's CPU mesh is now pre-rendered once into 24 poses off the main thread and played back as a flipbook with a GPU tint. A 75-second recorded walkthrough had 1,583 of 1,638 frames at ≥ 40 fps cadence in the simulator (gaps were page settles), versus visibly stuttering playback before. Hardware frame rates remain unmeasured.

**All 53 model checks and five onboarding UI journeys pass on GymBlock Review, iPhone 18 Pro / iOS 27.0.** Model checks cover the route, legacy step migration, shared stages and the estimate (34 min phone vs 11 min lifting, ≈ 118 h/year at defaults; dial persistence; Rarely = 0; Sometimes = 1 min). UI journeys cover the full flow with a live dial change (sets 3 → 4 updates phone time to 46 min), blocking selection and recap, the disabled Subscribe with no Preview; Rarely skipping the minutes page; Sometimes, Not now and relaunch resuming on the offer; accessibility-medium text with Reduced Motion through every page; and the primary action staying within 3 pt of the same height on every page. The first UI run had three test-script errors (picker value label, two Continue counts), fixed and rerun.

Every page was inspected in simulator captures (`screenshots/onboarding-v5/`). Visual review fixed: the welcome glow inflating the phone frame, a locked phone shown beside “Do you use your phone?”, dial rows overlapping labels, the nerve stopping short of the bicep, a loud overrun ring, too much red on the timed-rest end state, faint memory values and a left-hugging offer list.

Unverified: hardware haptic feel and frame rate, full VoiceOver navigation, small screens, Spanish layouts and user comprehension. Blocking and purchases remain unconfigured; nothing was pushed or purchased.

## Workout action placement

The exercise name and downward chevron are a single full-width Change exercise selector. End workout sits below Start/Finish set with eight points of separation and a 48-point minimum target, above the native tabs. It also stays available during first exercise selection. Sets moves to the top bar. An active set still offers finish/discard/keep before ending; changing exercises retains rest timing and previous records. Numeric editing now has a native keyboard Done action so the tabs can be reached reliably after entering reps.

**The build, 52 model checks and five distinct workout UI checks pass across targeted runs.** `/tmp/gymblock-actions-checks.xcresult` supplies the model pass and custom-exercise/attempt/discard journeys. The free-workout correction, switching, tab navigation, rest, relaunch and summary journey passed in `/tmp/gymblock-actions-final.xcresult` after the keyboard fix. `/tmp/gymblock-actions-confirmed.xcresult` executes and passes both new placement checks, including larger text and ending with the reps keyboard open; it also repeats the compact onboarding-benefit smoke check successfully. Cancelling End preserves the 12-rep draft, finishing afterwards saves exactly one set, and discarding an empty active workout produces no summary. Final native captures in `screenshots/workout-actions/` were inspected.

Earlier failures exposed keyboard-covered tabs and adjacent action hit bounds; these were repaired and rerun. A class-only retry discovered zero tests and is not counted as a pass. A transient invalid-frame warning still occurs when opening the numeric keyboard on this simulator; the checked controls remain reachable and the ending/cancellation flow passes. Its cause is not established. Hardware ergonomics and haptic feel remain unverified. This change is prepared for the explicitly requested main push; live purchases and real blocking remain deferred.

## V4 — native onboarding implementation

The workout-first V4 journey and three benefit scenes are implemented in the native SwiftUI app. Welcome uses “Stay focused. Stay intentional.” Questions use complete wording, one native glass slider/wheel, and single-tap habits. The original generated arm artwork is preserved; the timed meter reaches Perfect Pump on rep five. Record tables include the week-three dip and weight × reps changes. Examples do not populate History. Subscription products, price and legal-link setup were explicitly deferred by the user; the offer remains a clearly labeled local preview with live purchasing disabled.

**Build passes. All 52 model checks and five distinct UI checks passed across targeted runs on GymBlock Tryout, iPhone 17 Pro / iOS 26.5.** The UI checks cover the complete questions/benefits/offer journey and empty History; skip/back/persisted resume without bypassing the offer; Sometimes → No conditional correction; accessibility-medium text with Reduced Motion; and final normal-text dark benefit layouts/replay with both tables, their messages and the arithmetic caption visible without scrolling. Larger-text panels stack and scroll while navigation stays available. A second larger-text run passed in dark appearance after the final table spacing change.

The original arm mesh was clipped because the raw image occupancy map was inverted. Actual recorded playback exposed this; the map was repaired, and the intact relaxed/flexed artwork, heat fill, meter progression and final comparison were inspected again. Normal-size comparisons initially stacked and the record explanation sat below the fold. Panels now stay side by side at normal text size; record cells use two lines so the complete comparison fits. Replay/preview accessibility IDs inherited from container IDs were repaired. Earlier failing runs are not counted as passes.

Model pass evidence: the GymBlockTests group in `/tmp/gymblock-v4-final.log` and its result bundle (the UI group in that earlier bundle failed). Passing UI evidence: `/tmp/gymblock-v4-verified.xcresult` (four checks), `/tmp/gymblock-v4-layout.xcresult` (one repeated larger-text check), and `/tmp/gymblock-v4-compact.xcresult` (the fifth distinct check). An attempted method-specific selection omitted the new compact-layout method; it was moved into a dedicated UI class and actually executed successfully. The final build includes that class and the regenerated default scheme, which no longer skips onboarding with automatic sample loading.

Durable native images and a normal-speed simulator recording are in [screenshots/ux-v4/README.md](screenshots/ux-v4/README.md). These are native runtime captures, separate from the browser motion preview. The exact nervous-system sentence remains quoted proposed copy with its visible **Unverified health claim** attribution; arm dynamics remain labeled a stylized model. No physiological activation percentages or transformation prediction are presented as measured results.

At the end of the V4 implementation turn, the simulator was left on fresh, normal-text onboarding in light appearance. Only the disposable Tryout test store was reset. Existing completed onboarding, saved workouts, other simulators and unrelated repository changes were preserved. That turn did not push, release, change accounts or configure payments. Physical haptic feel, audible sound levels, full VoiceOver interaction, smaller-device coverage, actual shielding and live StoreKit outcomes remain unverified. The Reduced Motion automation used a Debug override of the same native rendering branch; it is not proof of changing the system Accessibility preference on hardware.

## Benefit-story motion preview — design review only

The latest copy-only revision removes **Attention pulled away** and preserves the user's nervous-system sentence in quotation marks with **Your proposed copy · Unverified health claim** directly below it. The disclaimer identifies the sentence as proposed wording, not an established health fact. Motion, artwork and the native app are unchanged by this copy revision.

The [V4 onboarding proposal](docs/ONBOARDING-CLEAR-JOURNEY-V4.md) restores the original generated arm PNG in place of the rejected vector hand. The original anatomical detail is retained with a gentle relaxed-to-flexed deformation and theme-aware heat fill. A wider deformation was rejected after inspecting the distorted elbow. Fine lines were strengthened for compact rendering. Both arms begin blue at zero. Each contraction adds at most 25 points; timed rest removes 5 and longer rest removes 25. Timed cycles remain 1.7 seconds, longer-rest cycles 2.4 seconds. The illustration remains visibly labeled **Stylized model · Not measured muscle activation**.

Desktop rest, first contraction, intermediate poses and the finish were captured and inspected. Dark compact playback, Reduced Motion, replay, mute, interruption, unchanged progress values and keyboard navigation were checked again. A few pixels of overflow during the bar vibration were found and corrected by reserving room at its right edge. The desktop viewport was 768 px; a 352 px viewport gave a 320 px inner preview, with a further check at a 320 px viewport. No horizontal overflow or page-script errors appeared in the completed checks.

The desktop run sampled 120 states. The observed right-hand peaks were 0.245, 0.449, 0.645, 0.847 and 1.00, matching the intended 25/45/65/85/100 progression within frame-sampling tolerance. The left never exceeded 0.25. Four left and five right contractions finished at 0.25 versus 1.00. Exactly one bell event occurred, first observed about 7.96 seconds into that run, with the Web Audio context running. The final sequence is 10.6 seconds, including the celebration hold; its ending explicitly clears the aura and bar offset. This verifies the audio graph/event, not perceived loudness on the user's speakers.

Muted playback emitted zero bell events. Replay restored zero bars and the relaxed rest poses. Switching scenes interrupted playback and cleared the celebration. Reduced Motion retained the final comparison and Perfect Pump without moving limbs, aura or vibration. The preceding brain review established neutral-to-frown/smile faces, 0.88/1.10 drawing scales and embedded social-logo particles; that scene is unchanged. The progress tables remain unchanged and their +25%, −10%, +25%, +33.3% values were checked again. Keyboard tabs remained functional.

The source and `five-rep-*.png` / `five-rep-*.json` captures and verification records remain in the chat's `gymblock-benefit-story.html` visualization folder. These are browser design checks, not simulator or native-app verification. App code, installed simulator state, purchases and actual blocking are unchanged. User comprehension and anatomical/animation preference remain unverified.

## UX V3 — previous implementation

The approved [UX reset](docs/UX-RESET-V3.md), including its copy, icons and placement rules, is implemented. The interface uses a flat warm canvas, DM Sans, red native Liquid Glass controls and less supporting text. Onboarding has a native seven-tick days slider, separate numeric wheels, short habit questions and three readable demonstrations: phone down, upward rest and labeled comparable records. Workout / History / Splits uses native navigation. Weight is selected with either a wheel or typing; sets are grouped, timing details are collapsed, and End workout remains visible.

**The latest simulator build succeeded. All 49 model checks passed, and six distinct V3 UI journeys passed across targeted runs.** They cover free workout logging/correction/relaunch, split editing and scoped progress, custom exercise/search, full onboarding/native slider/resume, Sometimes and No-scrolling branches, and unknown/invalid estimates. These counts come from the targeted results, not a single complete final suite. Model coverage includes preserved history/drafts, actual reps/load totals, timing, attempts, comparable records and explicit sample loading. Later changes were confined to the interface: stable conditional progress, contained phone artwork, divider placement, weight accessibility wording and the zero-rep alert.

The zero-rep test initially exposed a native confirmation popover that stayed open. The final implementation uses a centered native alert. On 4 October, direct Device Hub interaction on the latest build verified all three choices: Record attempt returns to upward rest; Start set starts another set; Edit reps retains the active set; Discard restores the previous rest. This used disposable review data, separate from the original saved workout. Actual captures show the alert and resulting rest state. This is direct interaction evidence, not a subsequently passing automated zero-rep test.

Normal-size onboarding, workout, correction, summary, weekly reps and split comparison captures were visually inspected. The phone illustration now stays inside its phone silhouette, with visible cameras; numeric input and the short Before / After comparison remain readable. Dark appearance, accessibility-large text and increased contrast were directly reviewed for the phone/rest/comparison scenes; the example record stacks at larger text. A complete V3 accessibility journey, small-screen journey and manual VoiceOver audit remain unverified. The strengthened History-tab selection assertion and the newer History/settings larger-text test were not successfully rerun.

Later simulator automation became unstable: mixed runs stalled around the keyboard, and fresh test runners were killed before connecting to the app. Those attempts are failures or incomplete runs, not passes. The valid targeted repair bundle is `/tmp/gymblock-ux-v3-repairs.xcresult`; model pass logs are `/tmp/gymblock-ux-v3-final.log` and `/tmp/gymblock-ux-v3-final-normal.log`; the latest build log is `/tmp/gymblock-ux-v3-delivery-build.log`. Temporary logs and result bundles may not persist. Durable visual evidence is in [the screenshot gallery](screenshots/ux-v3/README.md), including a 22-second normal-speed excerpt of the actual phone/rest/progress recording.

The review device is the disposable **GymBlock Final Review** iPhone 17e / iOS 27. Its temporary attempt fixture was removed and fresh onboarding restored. The final attempt to reopen the preview failed with the simulator error “Application launch … did not return a process handle nor launch error”; therefore the preview is not claimed to be visibly running at handoff. Labeled sample workouts remain available through Settings → Data → Load sample workouts after setup. The original iPhone 17e's saved workout was compared with its pre-review snapshot and remained unchanged. No repository push, account, billing, signing or release work is included. Focus blocking remains simulated. Physical haptic feel, sound levels, one-handed use, full VoiceOver navigation and animation preference require observed iPhone/user review. Onboarding arithmetic is qualified self-reported time; examples never create workout history or predict muscle/fat outcomes.

### Simulator handoff — 4 October

The iOS 27 review remained unable to launch; its app lookup returned an absent bundle folder and reinstall stalled. A fresh **GymBlock Tryout** iPhone 17 Pro / iOS 26.5 (`42EA9CB9-0FA4-49DD-A9C5-384784619D1C`) successfully installed the same latest build. Device Hub visibly shows the fresh welcome with Get started and Just train. It is left selected and open for the user. Extra iOS 27 simulators were shut down to reduce memory use; their saved data was not reset or deleted. This verifies visible launch on iOS 26.5, not an additional full test run.

## Previous workout questions, focus/rest/month story

The approved `docs/ONBOARDING-JOURNEY-V2.md` is implemented. Days/week is one 1–7 selector. Visit length, reps, sets, exercises and optional scrolling minutes use inline native wheels; the three lifting questions are separate. Rest timing, logging/review and set timing follow the workout questions. Only then do focus, rest, comparison and prospective four-week scenes explain the answers. Back/options/progress/Continue stay in a shared shell. No extra example-set detour or paywall appears.

Personal arithmetic distinguishes days from visits, requires actual scrolling-break counts for Sometimes, supports half-minutes and supersets, and bypasses invalid/unknown/multiple-visit time estimates. The standard example gives 34 min/visit, 408 min/four weeks, 216 sets and about 2,160 reps. The fixed visit stays the same length, including necessary rest. Rest resolves upward to a labeled illustrative 2:00; the 20 kg / 10→11 rep / 35 sec comparison is labeled Example. Month entries are future outlines. These values never become saved training or body-change predictions.

Real workouts persist elapsed Start-to-Finish set time and source-linked gaps independently of timed-activity minutes. History and its editor expose these values. Editing completion dates invalidates related gap meaning; deleting a gap source hides that gap until undo. Cancelling an unfinished set restores the prior rest timestamp. Manual/historical sets retain unknown timing. Training totals can filter actual sessions from the past 28 days.

The first implementation run passed **all 45 model checks** (`JourneyV2Model.xcresult`) and **six distinct onboarding journeys** (`JourneyV2UI.xcresult`): complete personalized flow/resume/no fabricated History; Sometimes with half-minute input and actual breaks; No scrolling/Just train; correcting an impossible estimate; skipped/unknown timed routine; and 7-day/back preservation. Model coverage includes timing persistence, exclusion of log-entry delay, exercise changes, cancel, date correction, deletion/undo, older data and exact four-week filtering. The subsequent `JourneyV2Final.xcresult` passed all 45 models, freestyle logging/corrections/relaunch, visible ending/totals and Spanish/back preservation. It exposed three test/editor issues: a recent exercise row's tap was obscured by native floating search, timing fields fell below a medium sheet, and native LabeledContent combines the rep value with its label. The switch route now uses actual search selection; opening timing expands the editor; the projection assertion reads the combined row. **All three affected journeys then passed** in `JourneyV2Repairs.xcresult`, including resumed story beats, the 2,160-rep detail, empty History, actual timing corrections and the 28-day report. `JourneyV2FinalModels.xcresult` passed **all 46 checks**, including coherent source-linked sample timings and repeat-safe explicit demo loading.

The visual review removed the old unused preset/ruler/editor/example components. It also caught schematic marks spilling from a very small timeline segment; each region now contains its own marks. Native wheel typography uses DM Sans and scales for larger text. Current screenshots are in [onboarding-v2](screenshots/onboarding-v2/README.md).

Across these targeted runs, **46 model checks and 11 distinct affected UI journeys passed**; device repeats are not counted again. The historical UI suite was not rerun as one batch. `JourneyV2AccessibleJourney.xcresult` passed the complete personalized route in dark appearance, accessibility-large text and increased contrast. `JourneyV2AccessibleTiming.xcresult` passed timing corrections, saved History and the four-week report under the same settings. That review exposed merged native timing-field labels; the final editor uses separate persistent labels and individually accessible inputs, with stacked rows at accessibility sizes.

A temporary iPhone SE simulator reported actual system Reduce Motion and Reduce Transparency as enabled (`JourneyV2CompactAccessibility.log`). Its UI runner installation stalled before any test body on both attempts, including after restart; a process sample confirms an installation wait. Those attempts are not passes or full compact-layout/reduced-effects proof. The temporary device was removed; no unrelated simulator or test process was removed. Manual VoiceOver and the complete compact route remain unverified.

`JourneyV2Medium.xcresult` passed both the fractional/Sometimes story and saved-timing/four-week-report journeys on iPhone 17e (390 × 844 points), with normal text and light appearance. The narrow timeline segment stays contained; the settled rep example shows 10→11 and rest shows its labeled 2:00. Final timing fields have visible labels. All of those pages and the dark/large-text route were visually inspected. The actual simulator recording is trimmed into `screenshots/onboarding-v2/focus-rest-progress.mp4`; it demonstrates the implemented motion, not a measured user preference. No invalid-frame or AttributeGraph warning appeared in the successful final targeted runs.

The installed final source is left on iPhone 17e at a fresh welcome, with light appearance, standard text and normal contrast. The primary simulator was in use by a separate project; this preview uses the existing 17e instead. This reset affects only GymBlock's prototype data. Explicitly labeled sample workouts remain available through Settings → Load demo or the shared Debug scheme's `--demo` argument.

Timing fields retain their visible labels when values are entered; they are distinct from the raw rep/load fields. Physical haptic feel, sound levels, manual VoiceOver use and animation preference still require an iPhone and observed user review. Sound assets/mute/playback requests remain covered by the model suite. System picker feedback follows iOS preferences; app feedback has its own preference. Focus remains simulated; no enforcement, billing, account, signing or release is included.

## Previous workout-first Liquid Glass onboarding

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

## Account, cloud, analytics, billing and logo (8 Oct 2026, evening)

Built and run on the iOS 27.0 iPhone simulator (`GymBlock Review`), bundle id `com.sodhera.gymblock`, with the Supabase and RevenueCat Swift packages resolved (supabase-swift 2.55, purchases-ios 5.x). Captures in `screenshots/redesign-2026-10-08/`:

| Capture | Shows |
| --- | --- |
| `30-reveal-red-green.png` | The phone arc is red, the training arc emerald, legend dots match. |
| `31-days-red.png` | The hours-a-year dots are red. |
| `32-welcome-signin.png` | The new padlock-barbell wordmark and "I already have an account". |
| `33-account.png` | The account page: card with the mark, three promises, Continue with Apple, and (offline Debug run) the labelled skip in place of Google. |
| `34-offer.png` | GymBlock Pro card with the mark; with no RevenueCat key the primary is disabled and the caption says subscriptions aren't switched on. |
| `35-settings-account.png` | Settings with the Account and Legal sections. |
| `logo-1024.png`, `logo-180.png`, `logo-60.png` | The fallback icon at three sizes (masked previews; the asset itself is opaque). |
| `40-icon-homescreen-light-dark.png`, `41-homescreen-light.png` | The icon on the Home Screen, light and dark, 9 Oct 2026 (flat emerald-on-black; the layered glass version was rejected). |

**Later the same evening, with the dashboards driven from this Mac** (Safari through a trusted Swift CGEvent helper plus AppleScript page text): the schema was run in the Supabase SQL editor and verified by query; the Apple provider was enabled with the bundle id; `gymblock://auth/callback` was added to the redirect URLs; a RevenueCat project, App Store app, both products, the `pro` entitlement and the `default` offering were created. The app was then launched `--ui-reset -journeyStep subscription --online`: the offer page loaded the two plans from RevenueCat (`36-offer-live.png`), Subscribe showed the Test Store sheet (`37-test-purchase.png`), a valid test purchase granted the entitlement and the journey moved to the splits page. Analytics rows from that run were read back from `gb_events` in the SQL editor. Later, with the user's say-so on Google's policy checkbox, a Google Cloud project `gymblock` with a GymBlock consent screen and a web OAuth client was created and its credentials entered into Supabase's Google provider; both Apple and Google now read ENABLED. The consent screen was published to production. On the simulator, Continue with Google on the account page showed the iOS consent for the Supabase domain and then Google's own sign-in page (`38-google-sheet.png`); completing it needs a real Google account and was left to the user.

What was verified by running: build, launch, every onboarding page above, Home with sample data, Settings, the live offer and test purchase, analytics inserts. What was verified by reading, not running, because the dashboards could not be reached from this machine (no Safari scripting, no Chrome, expired tokens): the SQL migration (repeat-safe statements, owner-only RLS, insert-only analytics for anon, `gb_delete_account` security definer), the Apple id-token and Google OAuth paths, the sync push/pull and the RevenueCat purchase path. They follow the same calls the shipped Speaking Coach app uses. Sign-in, sync, analytics inserts and purchases cannot succeed until the steps in `supabase/README.md` are done; until then the app reports the provider's error and never pretends.

Tests, run non-parallel on the one simulator: all 72 model checks pass (`GymBlockTests`, 1.0 s). UI: `BenefitLayoutUITests` (the primary action, now Continue with Apple on the account page, never moves), `JourneyV5UITests/testFullJourney…` (through the account page's Debug skip to the offer), `JourneyV5UITests/testRelaunchResumesWithoutBypassingOffer` (relaunch resumes on the offer; Back passes the account page), and `GymBlockFlowTests/testLogOutKeepsWorkoutsAndDeleteAccountErasesEverything` (device-only semantics in offline runs) all pass. The remaining UI classes were not re-run in this round.

## Limits

Real Screen Time blocking is not implemented. Accounts, sync, analytics and billing are implemented but their dashboards (Supabase providers and schema, RevenueCat, App Store Connect) are not yet configured; signing uses team 6LYZDNCM4M with automatic signing and App Store delivery has not been attempted. Physical-iPhone ergonomics and manual VoiceOver navigation remain unverified. The current onboarding revision above verifies OS Reduce Motion/Reduce Transparency on an iOS 26.5 simulator; iOS 17–25 runtime appearance remains unverified. The source uses native system materials, scaled DM Sans typography and a Reduce Motion branch, with an iOS 17–25 native-control fallback.

Animation preference and usability claims still require the proposed friend/user study. No muscle-gain, fat-loss or optimal-workout-time prediction is made.
