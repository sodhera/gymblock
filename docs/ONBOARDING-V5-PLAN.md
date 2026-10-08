# GymBlock onboarding V5 — design spec

**8 Oct 2026 · Implemented (rev. 8: brand mark and icon, the paper palette and compact scale, large-title headlines, native Liquid Glass navigation bars, plain-spoken captions; the approved arm and brain scenes and the Continue fade-in are unchanged).** Rev. 7 (7 Oct) brought the ember stage, Liquid Glass, one question per page and calmer motion. Supersedes V4 and the first V5 draft (which was too red, too wordy and too busy).

Rev. 8 also removed the templated styling of an interim pass (tracked uppercase labels, monogram app tiles, a tagline under Get started, a numbered explainer card on Home, fixed-size hero fonts) in favour of Apple text styles and sentence case, and added directional motion: pages slide 18 pt in the direction of travel as they fade, and Home's cards settle in one after another.

Rev. 8 changes, page by page: the welcome page carries the wordmark (the padlock with a barbell keyhole, also the app icon) and an "I already have an account" link and a one-line promise under Get started; every headline is `.largeTitle` bold and centred in its two-line box; a chosen answer rises (brighter glass, white edge) and the red check is the only red on the page; the blocking tiles are monograms on glass with a live "3 apps blocked from Start to Finish." line; the pledges sit on one glass card; the offer is a membership card with the mark, three benefits with one-line details and the price row when a product exists. Captions: "Stays on this iPhone. Never shared.", "Illustrative, not a measurement.", "An example log, not your data.", "Blocking is a preview in this build: nothing is enforced yet.", "Hold the button until it fills."

The person should leave thinking: *“I lose a lot of my gym time to my phone. GymBlock blocks it, times my rests, and shows me I'm improving.”*

## Principles

1. **One idea per page.** One headline, no subtitles. Hard ideas take two pages that share a stage.
2. **Same place, every page.** Progress line → two-line headline → stage → one-line caption → actions. The primary action never moves.
3. **Colour has a job.** One paper stage (warm off-white, ink dots) on every page; never a coloured background. Emerald is the signal only (the red ember and a graphite scheme were retired on 8 Oct 2026).
4. **Liquid Glass** for every control and card (iOS 26+), with translucent fallbacks.
5. **Apple type**, Dynamic Type everywhere.
6. **Calm motion, designed haptics.** Scenes start after the page settles; Continue waits for them; nothing advances on its own.
7. **Honest qualifiers**, one line long.

## Pages (20; 18 for Rarely, which skips minutes and hours)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1 | Stay focused. / Stay intentional. | Glass notifications stack, sweep away, a lock lands | Get started |
| 2 | What should we call you? | Glass name field, keyboard up | Continue |
| 3 | What’s your gender? | Male · Female · Other glass cards | Continue (after choosing) |
| 4 | How tall are you? | One wheel, cm / ft · in | Continue |
| 5 | How much do you weigh? | One wheel, kg / lb (sets the logging unit) | Continue |
| 6 | Do you use your phone between sets? | Notifications creep in; Every rest · Sometimes · Rarely | Continue (after choosing) |
| 7 | Between sets, how long are you on your phone? | One wheel, default 2 min | Continue |
| 8 | {Name}, here’s your phone time. | One ring for a typical workout: emerald arc = phone (34 min), ink arc = training (12 min); glass legend | Continue |
| 9 | That’s 147 hours a year. | A dot per 45-minute workout fills; "= 196 workouts" | Continue |
| 10–11 | Scrolling weakens your mind-muscle connection. / Put it away. Feel every rep. | Brain, nerve, arm | Continue |
| 12–13 | Scroll between sets. Never hit the pump. / Time your rests. Hit the pump. | Pump chart (labelled axes) and arm | Continue |
| 14–15 | Memory forgets your progress. / Your log doesn’t. | Values fade to "?", then chart (labelled axes) | Continue |
| 16 | Block what distracts you. | Glass app tiles | Turn on blocking · Not now |
| 17 | Get a buzz when rest is up. | Rest ring to 1:30, glass notification | Turn on rest alerts → iOS prompt · Not now |
| 18 | {Name}, commit to focus. | Three pledges | Hold to commit |
| 18b | Keep your progress safe. | Account card: backed up as you train, same log on any iPhone, private | Continue with Apple · Continue with Google |
| 19 | Stay focused, {Name}. | Benefits on a glass card | Subscribe · Restore purchases |
| 20 | Set up your splits. | The splits added so far (name, exercises, edit/delete menu) and an Add split button that opens the split editor (name, Add exercises with search, reorder, delete) | Start training (Continue · Skip for now while empty) |

## Estimate

A typical workout is assumed: 6 exercises × 3 sets (40 s each), 2-minute rests, 5 workouts a week. Their answer is phone minutes per rest. `rests = 17` · `phone = 17 × minutes` · `training = workout − phone`, where `workout = 12 min lifting + 17 × max(2, minutes)` · `per year = phone × 5 × 52 ÷ 60` · `as workouts = per year ÷ 45 min`. With 2 min: 34 of 46 minutes on the phone, 12 training; 147 h a year = 196 workouts. Self-reported arithmetic — never measured phone use or a body-outcome prediction.

## Paywall

The account page comes before the offer, so the purchase is keyed to the account (RevenueCat app user id = Supabase user id). Signing in pulls the account's data; an account that already finished onboarding goes straight to Home, a new one carries on to the offer (or to the questions when it came from the welcome link). The offer shows RevenueCat's yearly and monthly plans as two selectable cards (yearly first, "Best value", the per-month equivalent under its price) and the primary reads "Subscribe · price / year". With no RevenueCat key configured, Subscribe is disabled and the caption says subscriptions aren't switched on in this build; in Debug a labelled skip appears on both the account and the offer page (offline runs only). Never in Release. The reveal ring is red for time on the phone and emerald for training; the dots on the hours-a-year page are red.

## Splits (page 20, after payment)

The person sets up the workouts they repeat before they reach Home. The page lists the splits added so far as glass rows (name, exercise names, count, an `…` menu to edit or delete) and a dashed Add split button; a new split opens the existing split editor as a sheet (name, Add exercises with search, drag to reorder, swipe to delete). Rows animate in with a spring. Splits stay optional: while the list is empty the primary reads Continue and a Skip for now link sits beneath; once a split exists the primary reads Start training and the first split becomes Home's `Up next`. Finishing here is what sets `onboarded`; the offer no longer does.

## Performance notes

- `DotGrid` (the ember stage: two radial glows, dots that brighten towards the core, a soft vignette) is drawn once into a cached bitmap per screen size.
- The arm is pre-rendered into 24 poses off the main thread (`ArmFrames`) and played back by index; warmth is a GPU `colorMultiply`. The arm poses render in parallel from app launch (~1.3 s in the simulator).
- Brain, nerve, pulses, rings and chart are `Shape`s animated through `animatableData`/`trim`.
- No full-screen masks, blurs or per-frame drawing.
- The launch screen is the stage colour; the first page fades and rises into it (no white cover, no flash).
