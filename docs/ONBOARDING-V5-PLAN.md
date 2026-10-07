# GymBlock onboarding V5 — design spec

**7 Oct 2026 · Implemented (rev. 7: ember stage, Liquid Glass, one question per page, calmer motion).** Supersedes V4 and the first V5 draft (which was too red, too wordy and too busy).

The person should leave thinking: *“I lose a lot of my gym time to my phone. GymBlock blocks it, times my rests, and shows me I'm improving.”*

## Principles

1. **One idea per page.** One headline, no subtitles. Hard ideas take two pages that share a stage.
2. **Same place, every page.** Progress line → two-line headline → stage → one-line caption → actions. The primary action never moves.
3. **Colour has a job.** One ember stage (near-black, red-tinted dots) on every page; never a red background. Red is the signal only.
4. **Liquid Glass** for every control and card (iOS 26+), with translucent fallbacks.
5. **Apple type**, Dynamic Type everywhere.
6. **Calm motion, designed haptics.** Scenes start after the page settles; Continue waits for them; nothing advances on its own.
7. **Honest qualifiers**, one line long.

## Pages (19; 17 for Rarely, which skips minutes and hours)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1 | Stay focused. / Stay intentional. | Glass notifications stack, sweep away, a lock lands | Get started |
| 2 | What should we call you? | Glass name field, keyboard up | Continue |
| 3 | What’s your gender? | Male · Female · Other glass cards | Continue (after choosing) |
| 4 | How tall are you? | One wheel, cm / ft · in | Continue |
| 5 | How much do you weigh? | One wheel, kg / lb (sets the logging unit) | Continue |
| 6 | Do you use your phone between sets? | Notifications creep in; Every rest · Sometimes · Rarely | Continue (after choosing) |
| 7 | Between sets, how long are you on your phone? | One wheel, default 2 min | Continue |
| 8 | {Name}, here’s your phone time. | One ring for a typical workout: red arc = phone (34 min), white arc = training (12 min); glass legend | Continue |
| 9 | That’s 147 hours a year. | A dot per 45-minute workout fills; "= 196 workouts" | Continue |
| 10–11 | Scrolling weakens your mind-muscle connection. / Put it away. Feel every rep. | Brain, nerve, arm | Continue |
| 12–13 | Scroll between sets. Never hit the pump. / Time your rests. Hit the pump. | Pump chart (labelled axes) and arm | Continue |
| 14–15 | Memory forgets your progress. / Your log doesn’t. | Values fade to "?", then chart (labelled axes) | Continue |
| 16 | Block what distracts you. | Glass app tiles | Turn on blocking · Not now |
| 17 | Get a buzz when rest is up. | Rest ring to 1:30, glass notification | Turn on rest alerts → iOS prompt · Not now |
| 18 | {Name}, commit to focus. | Three pledges | Hold to commit |
| 19 | Stay focused, {Name}. | Benefits on a glass card | Subscribe · Restore purchases |

## Estimate

A typical workout is assumed: 6 exercises × 3 sets (40 s each), 2-minute rests, 5 workouts a week. Their answer is phone minutes per rest. `rests = 17` · `phone = 17 × minutes` · `training = workout − phone`, where `workout = 12 min lifting + 17 × max(2, minutes)` · `per year = phone × 5 × 52 ÷ 60` · `as workouts = per year ÷ 45 min`. With 2 min: 34 of 46 minutes on the phone, 12 training; 147 h a year = 196 workouts. Self-reported arithmetic — never measured phone use or a body-outcome prediction.

## Paywall

No preview bypass. With no product configured, Subscribe is disabled and the caption says subscriptions aren't available in this build. In Debug, launch with `--demo` to enter the app. A login step may follow the paywall later.

## Performance notes

- `DotGrid` is a single `Canvas` with no inputs, so it is drawn once.
- The arm is pre-rendered into 24 poses off the main thread (`ArmFrames`) and played back by index; warmth is a GPU `colorMultiply`.
- Brain, nerve, pulses, rings and chart are `Shape`s animated through `animatableData`/`trim`.
- No full-screen masks, blurs or per-frame drawing. A 10 s recording across the story stages on a memory-starved Mac: 447 of 450 frame gaps at 60 or 30 fps.
- The first-launch fade from the white launch screen is an overlay that removes itself after 0.5 s.
- The arm poses render in parallel from app launch (~1.3 s in the simulator).
