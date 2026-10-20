# GymBlock onboarding V8: time back

**20 Oct 2026 · Implemented.** Supersedes [ONBOARDING-V7-PLAN.md](ONBOARDING-V7-PLAN.md) for pages 5–14, the offer's headline and bars, the plan's last line and the rest-alert headline. Everything else in V7 is unchanged: the welcome, Sulav's note, the name and days questions, the stage, type, Liquid Glass, compact sizing, the account-before-offer order, the shield and apps pages, splits after the offer. The approved mockups are [docs/onboarding-mockups/time-back.html](onboarding-mockups/time-back.html) (round 2; round 1 is `time-back-round1.html`).

## Why

Sulav, the founder, on 18 Oct 2026: the pump argument doesn't convince. People get a pump with their phone out, so when they check the claim against their own experience, it fails. What they do feel is time. A one-hour session turns into two because rests that should last a minute or two last five. "If the app conveyed that it's saving me an hour every workout, just that simple message would make me pay."

So onboarding sells one thing, in the person's own numbers: the minutes scrolling runs past the rest they need, per rest, per workout and per year, and that GymBlock gives them back.

The person should leave thinking: *"My phone turns my rests into extra time at the gym. GymBlock locks it, buzzes me when rest is up, and gives me that time back."*

## Rules

- **Their numbers only.** Every number comes from their answers (`TimeBack` in `JourneyMetrics.swift`), with a one-line qualifier ("From your answers: 14 rests × 2.5 minutes.", "Your numbers, multiplied out.").
- **Rest they need is never lost.** Only the scrolling past the rest they need counts: 4 minutes of scrolling against a 1.5-minute rest is 2.5 minutes lost. That was Sulav's objection to the V7 ring.
- **No graph while they answer.** The question pages show something they recognise that answers back. The first graph comes on page 8, once both rest answers are in.
- **Round down, never guess.** Lost minutes round down to 5 (to the whole minute under 10), years down to 10 hours, extra workouts down to 5; their workout with rests on time rounds up to 5. Every later number (the year, the extra workouts, the hours back a month, the workout) is multiplied from the minutes as shown, so the pages agree. If their sets and the rest they need alone don't fit their gym time, there is no workout total, only the per-rest number.
- **No body claims.** "A better workout" means only what GymBlock does: every rest on time, every set saved.

## Pages (22; 15 for Rarely)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1–4 | Welcome ("Focused workouts." under the locking phone and the arm), Sulav's note, name, days a week | | |
| 5 | Be honest. Do you check your phone between sets? | A phone scrolling its feed pulls the kit around it in, piece by piece, each on a soft tap, a faint red growing behind it; then it loops. No words (`SuckedInStage`); caption "No judgement. We did too." | Every rest · Sometimes · Rarely |
| 6 | How long do you need to rest between sets? | A stopwatch on a five-minute dial winds to the answer (`RestWatchStage`). The answer is also their rest timer. "Not sure" counts as 2 minutes. | 1 min · 1.5 · 2 · 3 · Not sure |
| 7 | How long are you on your phone each time? | A phone scrolling a feed above a wheel (1 to 15+ minutes, starting at 1); a pill shows the answer (`ScrollMinutesStage`) | Continue |
| 8 | That's 2.5 minutes lost. Every rest. | The first graph: "Rest you need" against "Scrolling" on one axis. The part under the rest is light red, the part past it red and counted up (`PerRestStage`) | Continue |
| 9 | How many exercises per workout? | A rack fills with one piece of kit per exercise; each lands with a plate's clank (`RackStage`) | 3 or fewer · 4 · 5 · 6 · 7 or more |
| 10 | And how many sets of each? | Today's log, a tally mark per set ("15 sets, so 14 rests.") (`LogTallyStage`) | 2 · 3 · 4 · 5 or more |
| 11 | How long are you at the gym? | The gym clock's hands run from six for that long (`GymClockStage`); "From walking in to walking out." | 45 min · 1 hour · 1.5 · 2 · 2.5 hours or more |
| 12 | 35 minutes go to your phone, every workout. | Page 8's bars at workout size: "Your workout, rests on time", against "Your time at the gym" with the red past it (`WorkTimeStage`) | Continue |
| 13 | That's about 120 hours a year. (caption: "At 4 workouts a week.") | A dot per extra workout of their own length, "= 80 extra workouts" (`ExtraWorkoutsStage`) | Continue |
| 14 | We'll give you those 35 minutes back. And a better workout. | Page 12's last frame, then the red slides away and the gym bar closes onto the workout: "about 55 min, with GymBlock", "35 min back" | Continue |
| 15–16 | The shield; which apps to lock | Unchanged | |
| 17 | We'll buzz you when your 1:30 is up. | Unchanged scene, their rest in the headline | Continue → iOS prompt |
| 18 | {Name}, here's your plan. | Adds "Each workout: About 55 min" in the signal colour | Hold to commit |
| 19 | Account | Unchanged | |
| 20 | (offer) {Name}, get your time back. (Rarely, or a phone that fits the rest: keep every rest on time.) | "Your time at the gym: 1.5 hours". Today: the workout in green, then the red with a phone and "35 min" inside it (the phone alone when the red is too short; no line of its own under the bar). With GymBlock: the green alone, "About 55 min". "From your answers. About 10 hours back a month." Promises, trial timeline and plans unchanged | Start 7-day free trial |
| 21–22 | Splits; first workout | Unchanged | |

From 55 to 65 minutes, the words are "about an hour": "about an hour of your 2 hours goes to your phone", "We'll give you that hour back.", "get your hour back."

## Paths (`OnboardingRoute`, `TimeBack.Outcome`)

- **Rarely:** 6, then "Then you're already ahead." (the same stopwatch with "Rests on time"), then 15. The plan has no workout line; the offer reads "{Name}, keep every rest on time." with no bars.
- **Scrolling that fits inside the rest:** page 8 reads "Then your scrolling fits inside your rest.", then 15; the offer is Rarely's.
- **Sometimes:** half the rests count ("That's 2.5 minutes lost each time you scroll."; "about half of 14 rests × 2.5 minutes").
- **Under 10 minutes a workout:** page 12 says it as it is, then 15; the plan has no workout line and the offer is Rarely's ("keep every rest on time"). A 5-minute "we'll give you those back" rang hollow, and its labels were slivers (inspection, 20 Oct 2026).
- **Answers that don't fit their gym time:** if the sets and the rest they need alone run past it, pages 12–13 are skipped and page 14 gives back the per-rest number ("We'll give you those 4 minutes back. Every rest.", page 8's bars with the red sliding away); the offer says "get 4 minutes back every rest". If only the scrolling runs over, it's cut to fit ("From your answers, fitted into your 1 hour.").

Old saved progress on V7's removed pages (phone minutes, ring, hours, mind-muscle, pump, memory) resumes at the rest question; nothing stored is discarded.

## Answers

Stored on `RoutineBaseline` (synced as part of the profile's answers): `restNeedSeconds` and `restNeedUnsure` (new), `scrollingMinutes`, `exercises`, `sets`, `duration` (gym minutes), `scrollFrequency`, `trainingDays`. The rest they need also sets `Profile.restSeconds`, their rest timer. Analytics record each answer and the reveal's numbers (`onboarding_answer`), never free text.

## Haptics and sound (`JourneyScores`)

| Page | Feel | Sound |
|---|---|---|
| 6 | A light tick for every 15 seconds the hand winds | The keyboard tick, quietly |
| 7 | The wheel's own detents | None (the feed loops silently) |
| 8 | A soft hit as the red lands | The clock tock following the count |
| 9 | A thud as each piece lands | Plate clanks, alternating |
| 10 | A light tick per tally mark | The keyboard tick at the end of each row |
| 11 | Ticks as the hands run, a firmer one when they stop | Tocks, then a tick |
| 12 | A thud as the red lands | Tocks with the count, a plate drop |
| 13 | Ticks with the dots, a thud on the last | Tocks, a plate drop (as V7's year page) |
| 14 | A rising shimmer as the red slides, a latch as the bar closes | A clink |

## Removed

The V7 ring, the mind-muscle pages (and the brain-and-nerve art), the pump pages, the memory and log pages, and the 6 × 3 assumed workout (`GymTimeEstimate`). The arm stays on the welcome.

## After the inspection (20 Oct 2026)

Every page was inspected on an iPhone SE (the user's phone) and the iPhone 18 Pro Max, at the largest text sizes, in Spanish, with Reduce Motion, frame by frame, with Apple's accessibility audit and a code review ([screenshots/2026-10-20-inspection](../screenshots/2026-10-20-inspection/index.html)). What changed:

- **Large text.** At accessibility sizes the page scrolls and the scene keeps a 300-pt floor; headlines, captions and rows wrap instead of truncating; the two-bar labels stack above their values when they don't fit; axis ticks that would collide are left out. The app's font now follows the text size live (`Font.custom(relativeTo:)`), hero numbers included.
- **Rarely.** "Then you're already ahead." reports its scene done at once (it shared the stopwatch with the rest question and used to wait 20 s for Continue).
- **Spanish.** The language comes from the phone's preferred languages (a phone set to Spanish got English). VoiceOver's Back is "Volver", not "Espalda".
- **Contrast.** Small emerald and red text use darker shades (`JourneyColor.signalText`, `dangerText`: 4.8:1 and 5.1:1); the offer's bars use them as fills under white labels. The bars' grey is ink at 50% (3.4:1 on the paper). Scrolling inside the rest they need is the rest's grey, not light red: it isn't lost.
- **Notes outside slivers.** "+35 min" and "35 min back" sit under the bar, centred on their part and kept inside the width; the offer's red label moves under its bar when the bar is too narrow. No "About 0 hours back a month".
- **VoiceOver.** Each page change moves focus to the question; Continue is there at once for VoiceOver; the wheel is "Minutes you scroll"; the stopwatch, workout and promise bars say what they show; decorative scenes are hidden; the progress line is a full-height element; the hold says how to commit.
- **Motion.** The workout and per-rest counts stay hidden until they start (no "+0 min"); the promise's hero swaps one after the other, not as a cross-fade; under Reduce Motion the rack's pieces fade in place. The feed steps on a timer and only the clock's second hand turns, instead of redrawing every frame.
- **Taps.** Restore, Terms, Privacy and Edit are 44 pt; a second tap on Continue while the page leaves does nothing; Back waits while an account is signing in.


## Picks from the side-by-side (20 Oct 2026)

Both versions were installed side by side ("GB Sirish", "GB Sulav") and compared page by page on an iPhone SE; the user picked per page.

- Sulav's: the welcome, the phone picture (with our question, "Be honest. Do you check your phone between sets?"), the shorter headlines (minutes scrolling, exercises, sets, gym, year, shield, choose apps, account, splits), the rack built to the count with a plain kettlebell, the straight log, the shield played on a phone, the commit page's spacing.
- Ours: Sulav's note (kept second), the per-rest, workout and promise pages, the offer.
- The four number questions answer on rows again (Sulav's), not tiles. The stopwatch and the gym clock lost the time under them and grew into that room.
- The offer's red part says it inside itself: a phone and "35 min", not "35 min on your phone" on a line under the bar.
