# GymBlock onboarding V5 — design spec

**7 Oct 2026 · Implemented (rev. 3: profile questions, plain-language estimate, faster motion).** Supersedes V4 and the first V5 draft (which was too red, too wordy and too busy).

The person should leave thinking: *“I lose a lot of my gym time to my phone. GymBlock blocks it, times my rests, and shows me I'm improving.”*

## Principles

1. **One idea per page.** One headline, no subtitles. If an idea needs more, it gets a second page that shares the same visual.
2. **Same place, every page.** Thin progress line → headline box (always two lines tall, centred) → stage → one-line caption → actions. The primary action sits at exactly the same height on every page; answer options stack upward from it. The eye goes top → centre → bottom and never hunts.
3. **Colour has a job.** ~90% near-black stage with a faint dotted grid, ~8% neutrals (white, two greys), ≤2% red. Red marks the one thing to look at on a screen — the lock, the phone-time bar, the pumped arm, the new best. The primary button is white with black text.
4. **Apple type.** SF Pro text styles throughout (`.title` bold headlines, `.title3` options, `.headline` buttons, `.footnote`/`.caption` captions) so everything follows Dynamic Type; headlines scale down slightly before wrapping to a third line.
5. **Motion is calm and cheap.** Native SwiftUI animations (`.smooth`, gentle springs) on opacity, transforms, shape trims and an animatable arm flipbook. Nothing is redrawn per frame by the app; the background is drawn once; scenes run once and stop. Text transitions fade and drift a few points — no blur. Reduce Motion shows final states.
6. **Honest qualifiers, one word long.** “Illustration”, “Example”, “Lifting time assumes 3 s per rep.”, “Blocking is simulated in this build.”

## Pages (17; 15 for Rarely, which skips minutes and days)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1 | Stay focused. / Stay intentional. | Four real-looking notifications drop in (haptic each), sweep away in a cascade, one red lock lands: "Apps locked while you train" | Get started (appears after the scene) |
| 2 | What should we call you? | Large centred field, keyboard up | Continue / Return |
| 3 | What’s your gender? | — | Male · Female · Other |
| 4 | Your height and weight. | Metric/Imperial switch + two wheels, defaults from gender | Continue |
| 5 | Do you use your phone between sets? | The notifications creep back in | Every rest · Sometimes · Rarely |
| 6 | Between sets, how long are you on your phone? | One wheel, default 2 min | Continue |
| 7 | {Name}, here’s your phone time. | A ring with one segment per rest fills (tick per segment) as the count climbs to 34; "17 rests × 2 min"; four − / + rows adjust it live | Continue |
| 8 | That’s 147 hours a year. | A grid of dots fills red, one per 45-minute workout; "= 196 workouts", "Each dot is one 45-min workout." | Continue |
| 9–10 | Scrolling weakens your mind-muscle connection. / Put it away. Feel every rep. | Brain, nerve, arm; notifications pull attention, then signals reach the arm | Continue |
| 11 | Scroll between sets. / Never hit the pump. | A pump chart (y: Pump, x: Time →, "Rest 3:40" under each rest) draws; every phone rest drains it to zero; dashed FULL PUMP line "Never reached". A small arm below flexes each set | Continue |
| 12 | Time your rests. / Hit the pump. | Same chart with "Rest 1:30": the line stair-steps up to FULL PUMP, "Reached", and the arm turns red | Continue |
| 13–14 | Memory forgets your progress. / Your log doesn’t. | Values dissolve into "?", then rebuild as a chart (y: Weight × reps, x: Week →), "+5 kg" | Continue |
| 15 | Block what distracts you. | App tiles; Turn on stamps locks | Turn on blocking · Not now |
| 16 | {Name}, commit to focus. | Three pledges | **Hold to commit**: 1.6 s fill, ramping haptics, pledges check off; releasing early drains it |
| 17 | Stay focused, {Name}. | Benefit rows | Subscribe · Restore purchases |

Continue on animated pages appears only when the scene finishes (all ≤ 3 s; 6 s safety net). Defaults: 6 exercises × 3 sets, 2 min per rest, 5 workouts a week. Principles review: [ONBOARDING-PRINCIPLES-REVIEW.md](ONBOARDING-PRINCIPLES-REVIEW.md). Attention heatmaps: [HEATMAP-REVIEW.md](HEATMAP-REVIEW.md). Every chart labels both axes.

## Estimate

`rests = exercises × sets − 1` · `phone per workout = rests × minutes per rest` · `per year = phone × workouts per week × 52 ÷ 60`. Defaults 6 exercises × 3 sets, 5 workouts a week. With 2 min/rest: 34 min per workout, ≈ 147 h a year = 196 workouts of 45 min. These are the person's own answers multiplied out — never measured phone use or a body-outcome prediction. Adjustments persist to Settings → Training answers. Height, weight and gender are stored locally only; nothing uses them yet.

## Paywall

No preview bypass. With no product configured, Subscribe is disabled and the caption says subscriptions aren't available in this build. In Debug, launch with `--demo` to enter the app. A login step may follow the paywall later.

## Performance notes

- `DotGrid` is a single `Canvas` with no inputs, so it is drawn once.
- The arm is pre-rendered into 24 poses off the main thread (`ArmFrames`) and played back by index; warmth is a GPU `colorMultiply`.
- Brain, nerve, pulses, rings and chart are `Shape`s animated through `animatableData`/`trim`.
- No full-screen masks, blurs or per-frame drawing. A 10 s recording across the story stages on a memory-starved Mac: 447 of 450 frame gaps at 60 or 30 fps.
- The first-launch fade from the white launch screen is an overlay that removes itself after 0.35 s.
