# GymBlock onboarding V8: time back

**20 Oct 2026 · Implemented.** Supersedes [ONBOARDING-V7-PLAN.md](ONBOARDING-V7-PLAN.md) for pages 5–14, the offer's headline and bars, the plan's last line and the rest-alert headline. Everything else in V7 is unchanged: the welcome, Sulav's note, the name and days questions, the stage, type, Liquid Glass, compact sizing, the account-before-offer order, the shield and apps pages, splits after the offer. The approved mockups are [docs/onboarding-mockups/time-back.html](onboarding-mockups/time-back.html) (round 2; round 1 is `time-back-round1.html`).

## Why

Sulav, the founder, on 18 Oct 2026: the pump argument doesn't convince. People get a pump with their phone out, so when they check the claim against their own experience, it fails. What they do feel is time. A one-hour session turns into two because rests that should last a minute or two last five. "If the app conveyed that it's saving me an hour every workout, just that simple message would make me pay."

So onboarding sells one thing, in the person's own numbers: the minutes scrolling runs past the rest they need, per rest, per workout and per year, and that GymBlock gives them back.

The person should leave thinking: *"My phone turns my rests into extra time at the gym. GymBlock locks it, buzzes me when rest is up, and gives me that time back."*

## Rules

- **Their numbers only.** Every number comes from their answers (`TimeBack` in `JourneyMetrics.swift`), with a one-line qualifier ("From your answers: 14 rests × 2½ minutes.", "Your numbers, multiplied out.").
- **Rest they need is never lost.** Only the scrolling past the rest they need counts: 4 minutes of scrolling against a 1½-minute rest is 2½ minutes lost. That was Sulav's objection to the V7 ring.
- **No graph while they answer.** The question pages show something they recognise that answers back. The first graph comes on page 8, once both rest answers are in.
- **Round down, never guess.** Lost minutes round down to 5, years down to 10 hours, extra workouts down to 5; their workout with rests on time rounds up to 5. If their sets and the rest they need alone don't fit their gym time, there is no workout total, only the per-rest number.
- **No body claims.** "A better workout" means only what GymBlock does: every rest on time, every set saved.

## Pages (22; 15 for Rarely)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1–3 | Welcome ("Focused workouts." under the locking phone and the arm), name, days a week (Sulav's note removed 20 Oct 2026) | | |
| 5 | Be honest. Does your phone suck you in between sets? (20 Oct 2026: checking is fine, getting sucked in is the problem) | A phone scrolling its feed pulls the kit around it in, piece by piece, each on a soft tap, a faint red growing behind it; then it loops. No words (`SuckedInStage`); caption "No judgement. We did too." | Every rest · Sometimes · Rarely |
| 6 | How long do you need to rest between sets? | A stopwatch on a five-minute dial winds to the answer (`RestWatchStage`). The answer is also their rest timer. "Not sure" counts as 2 minutes. | 1 min · 1½ · 2 · 3 · Not sure |
| 7 | Once you start scrolling, how many minutes go by? | A phone scrolling a feed above a wheel (1 to 15+ minutes, starting at 1); a pill shows the answer (`ScrollMinutesStage`) | Continue |
| 8 | That's 2½ minutes lost. Every rest. | The first graph: "Rest you need" against "Scrolling" on one axis. The part under the rest is light red, the part past it red and counted up (`PerRestStage`) | Continue |
| 9 | How many exercises per workout? | A rack fills with one piece of kit per exercise; each lands with a plate's clank (`RackStage`) | 3 or fewer · 4 · 5 · 6 · 7 or more |
| 10 | And how many sets of each? | Today's log, a tally mark per set ("15 sets, so 14 rests.") (`LogTallyStage`) | 2 · 3 · 4 · 5 or more |
| 11 | How long are you at the gym? | The gym clock's hands run from six for that long (`GymClockStage`); "From walking in to walking out." | 45 min · 1 hour · 1½ · 2 · 2½ hours or more |
| 12 | {Name}, 35 minutes of your 1½ hours goes to scrolling. | Page 8's bars at workout size: "Your workout, rests on time", against "Your time at the gym" with the red past it (`WorkTimeStage`) | Continue |
| 13 | That's about 120 hours a year. (caption: "At 4 workouts a week.") | A dot per extra workout of their own length, "= 80 extra workouts" (`ExtraWorkoutsStage`) | Continue |
| 14 | We'll give you those 35 minutes back. And a better workout. | Page 12's last frame, then the red slides away and the gym bar closes onto the workout: "about 55 min, with GymBlock", "35 min back" | Continue |
| 15–16 | The shield; which apps to lock | Unchanged | |
| 17 | We'll buzz you when your 1:30 is up. | Unchanged scene, their rest in the headline | Continue → iOS prompt |
| 18 | {Name}, here's your plan. | Adds "Each workout: About 55 min" in the signal colour | Hold to commit |
| 19 | Account | Unchanged | |
| 20 | (offer) {Name}, get your 35 minutes back. | "Your time at the gym: 1½ hours". Today: the workout in green, then "35 min scrolling" in red. With GymBlock: the green alone, "About 55 min". "From your answers. About 10 hours back a month." Promises, trial timeline and plans unchanged | Start 7-day free trial |
| 21–22 | Splits; first workout | Unchanged | |

From 55 to 65 minutes, the words are "about an hour": "about an hour of your 2 hours goes to scrolling", "We'll give you that hour back.", "get your hour back."

## Paths (`OnboardingRoute`, `TimeBack.Outcome`)

- **Rarely:** 6, then "Then you're already ahead." (the same stopwatch with "Rests on time"), then 15. The plan has no workout line; the offer reads "{Name}, keep every rest on time." with no bars.
- **Scrolling that fits inside the rest:** page 8 reads "Then your scrolling fits inside your rest.", then 15; the offer is Rarely's.
- **Sometimes:** half the rests count ("That's 2½ minutes lost each time you scroll."; "about half of 14 rests × 2½ minutes").
- **Under 5 minutes a workout:** page 12 says it as it is, then 15; the offer is Rarely's.
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
