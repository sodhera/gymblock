# GymBlock onboarding V10: the clean flow

**1 Nov 2026 · Implemented** (after two rounds of Sulav's picks on the board). Sulav's call after seeing Cal AI's onboarding beside Brainrot's and Unrot's: the current flow (V8/V9, animated scenes on every question) isn't what he wants. This is a clean-slate replacement, mocked page by page in [onboarding-mockups/v10-clean.html](onboarding-mockups/v10-clean.html) ([one picture](onboarding-mockups/img/v10-clean.jpg)). The analysis behind it is [onboarding-references/BRAINROT-UNROT-ONBOARDING.md](onboarding-references/BRAINROT-UNROT-ONBOARDING.md); Cal AI's screens are in Sulav's message of 1 Nov 2026.

## The grammar (from Cal AI, in GymBlock's clothes)

- **One frame for every page.** A round glass Back button and a thin ink progress line at the top; the question left-aligned in 28-pt bold; one grey line under it; the content; the one ink Continue at the bottom, disabled until there's an answer. Nothing animates while the person answers.
- **Questions are rows.** Glass rows with the emerald check on the chosen one, as today. No wheels (the phone minutes become rows), no stopwatch, rack, log or feed phone above the answers. The scenes go; the questions take ten seconds each.
- **The product lives in interstitials, not on questions.** The shield as the proof after the why page (17), the rest alert on the Lock Screen (21), the workout screen in a phone on the welcome and the first trial page.
- **Their numbers stay, as big numbers.** The per-rest and per-workout results are a 72-pt red number with a one-line strip under it, the same arithmetic as V8 (`TimeBack`), the same rounding down, the same one-line qualifier. Then their age, and the number in life ("5 months of your life"), and after the promise what those months are for (Brainrot's pivot).
- **Their words stay** (V9): the cost they named comes back as the promise's caption and the plan's number; what they tried gets its why.
- **The last stretch is Brainrot's then Cal AI's:** the hold ("Ready to get your time back?"), "Save your progress" with Apple and Google, then two trial pages ("Try GymBlock free for 7 days" with the product, "We'll remind you before your trial ends") before the price, each with "No payment due now". No loader, no plan.
- **Paper, ink, emerald, red for time on the phone.** No coloured backgrounds, no mascot, no invented counts or reviews, no tracking prompt.

## Revised the same day, on Sulav's five points

1. The shield was at page 7, before any problem had been built; it now follows the why page as its proof (17).
2. The year page is gone. After the workout number comes one more question, their age, then the number in life: "That's 5 months of your life." (their minutes × their days × 52 × the years until 65 from the top of their age band, so it rounds down; days under two months, months under two years, then years; the qualifier says the assumption). After the promise, Brainrot's pivot: "5 more months of" and one word at a time on a loop: Living · Reading · Sleeping · Cooking · Lifting (19).
3. On the why page only the lock answers "why those didn't hold": "Locked from your first set to your last. No Ignore button." The buzz and the log aren't answers to that question and are gone from it.
4. "Which apps should we lock?" leaves onboarding. It's asked in the app after the paywall: a card on Home, "Lock your apps while you train", with Choose apps (the system picker), until it's done; Start workout says blocking isn't set up yet. Sulav's call: the picker after they pay.
5. No loader and no plan card: Brainrot never shows a plan. Its ending is the hold, so ours is "Ready to get your time back? Hold the button." → "Let's go. You're committed." then the account, the two trial pages and the price.

## Pages (26 in onboarding, 18 when the phone fits the rest; then Home)

| # | Page | Content | Action |
|---|---|---|---|
| 1 | Welcome | "Focused workouts." / "Your apps lock from your first set to your last." The workout screen in a phone | Get started · Already have an account? Sign in |
| 2 | Name | "What should we call you?" | Continue |
| 3 | Days | "How many days a week do you train?" 2 · 3 · 4 · 5 · 6 or more | Continue |
| 4 | Source | "Where did you hear about us?" TikTok · Instagram · YouTube · App Store · A friend · Somewhere else (a fixed answer for the ads) | Continue |
| 5 | Be honest | "Do you check your phone between sets?" Every rest · Sometimes · Rarely | Continue |
| 6 | Cost | "And what does that cost you?" multi-select: My workouts run long · I lose focus between sets · I lose track of my sets · I skip the last sets · I get home late · Something else ("Not much, honestly" dropped 1 Nov 2026, at the user's request; the enum keeps it so saved answers decode) | Continue |
| 7 | Rest | "How long do you rest between sets?" / "This becomes your rest timer." 1 · 1.5 · 2 · 3 min · Not sure | Continue |
| 8 | Phone minutes | "How long are you on your phone each time?" About 2 · 3 · 4 · 6 · 8 · 10 or more (rows, not a wheel), starting a whole minute above the rest they picked, as the wheel did (1.5 min → 3, 4, 6, 8, 10+) | Continue |
| 9 | Per rest | "That's 2.5 minutes lost. Every rest." big number, strip. Fits: "Then your phone time fits inside your rest.", then 15 | Continue |
| 10 | Exercises | 3 or fewer · 4 · 5 · 6 · 7 or more | Continue |
| 11 | Sets | "And how many sets of each exercise?" (no line under it, 1 Nov 2026) | Continue |
| 12 | Workout | "35 minutes of every workout go to your phone." big number, strip | Continue |
| 13 | Age | "How old are you?" / "For one more number." Under 18 · 18–24 · 25–34 · 35–44 · 45–54 · 55 or over | Continue |
| 14 | Year dots | "This is your next year at the gym." one dot a workout, lighting up; then "110 of them go to your phone." the phone's share red; then Life: "That's 3,760 hours of your life." the hours large | Continue |
| 15 | Tried | "What have you tried?" multi-select (V9) | Continue |
| 16 | Why | "Here's why those didn't hold." What you tried (✕ lines); with GymBlock: the lock, no Ignore button. Skipped for Nothing yet | Continue |
| 17 | The shield | "This is what you'll see with GymBlock." / "A locked app, mid-workout." the real shield card. "It lifts the moment you finish." | Continue |
| 18 | Promise | "We'll give you those 35 minutes back." caption in their words; Today's bar against With GymBlock's, "35 min back" | Continue |
| 19 | Life back | "5 more months of" + Living · Reading · Sleeping · Cooking · Lifting, one word at a time on a loop | Let's do this |
| 20 | ~~Sulav's note~~ | Removed on 5 Nov 2026 at the user's request: the shield goes straight to the rest alerts | |
| 21 | Rest alerts | "We'll buzz you when your rest is up." iOS's prompt, drawn, with working buttons and an arrow bobbing under Allow (1 Nov 2026): Allow brings the real request while iOS hasn't been asked; once refused it opens Settings and the page waits for them to come back; already allowed (a reinstall) the page isn't shown at all, since there's nothing to ask. Not now moves on without it. No Continue | Allow · Not now |
| 22 | Commit | "Ready to get your time back?" / "Here's what you're signing." A pledge in their numbers on a card ("I rest 1:30, then lift." · "My apps stay locked, first set to last." · "I get 35 minutes back, every workout." · "3,760 hours of my life, back." in emerald) with a signature line; "Hold to sign" signs it: as they hold, emerald floods the page from the fingerprint (Brainrot's commit), driven as one linear animation the hold's length so the render server draws every frame (fed from the hold's 40 ms ticks it stuttered; a simulator recording showed dropped frames every fifth frame before and none after), and the words turn white exactly where the edge passes them (a white twin masked by the same circle); the checks go emerald and their name lands on the line (1 Nov 2026: the mark alone was empty) | Hold |
| 23 | Account | "Save your progress." / "Every workout syncs to your account and comes back on any iPhone." | Sign in with Apple · Google |
| 24 | Trial 1 (button lower: no secondary slot on the wall) | "Try GymBlock for free" ("for free" in emerald, as Brainrot colours it; no line under it, 1 Nov 2026) The app's two things, played on the phone: first a set is logged on the workout screen (a tap on Log set, the set ticks into the log, the rest starts), then the phone goes home, TikTok is tapped and the shield lands (the shield page's scene with a prologue, `ShieldStage(logFirst:)`; 1 Nov 2026, replacing a still workout screen), "No payment due now". From here to the price it's one wall, as Brainrot's (1 Nov 2026): no Back from this first page, Back within the wall (the paywall's own Back, a glass button over RevenueCat's page, returns to the trial page before it), the pages sliding sideways as a pager, the dots staying put (the price is a page of onboarding's own pager, `PaywallView(inOnboarding:)` under the top bar, so all three slide the same way; the root shows its paywall only as the gate for an onboarded account; checked at a slowed speed with measured positions, since the simulator's recorder emits frames at irregular times and reads as cuts and ghosts; 1 Nov 2026), and page dots (three, or two when the reminder page is skipped) in place of the progress line | Try for $0.00 (always those words, as Brainrot's) |
| 25 | Trial 2 | "We'll remind you before your trial ends." (no line under it; always shown, as the wall's second page) | Continue for free |
| 26 | Paywall | The app's own page (1 Nov 2026, replacing the dashboard paywall at the user's request, laid out as that one was: the icon on a tile, "Get your time back.", the reviews from the dashboard on a carousel with dots, Weekly · Yearly (BEST VALUE, the price a week in emerald) · Monthly side by side, the selected plan's terms line, Continue, then Terms · Privacy · Restore · Sign out; `PaywallView` in AccountGate.swift, the weekly package now in `GymSubscription.Plan` with a `period`). Formerly: RevenueCat dashboard, "Start your 7-day free trial", yearly preselected with the trial badge, monthly and weekly without a trial, "No payment due now", "Start my free trial", the terms line, Sign out. **A dashboard edit for Sulav** | |
| 27 | Home (in the app) | "Lock your apps while you train" card with Choose apps until it's done; Start workout | |
| 28 | First workout | As today, after splits | Start workout · I'm not at the gym yet |

Paths: Rarely, or a phone that fits inside the rest, reads page 9's fitting line and goes to 15; 18 reads "Keep every rest on time." with no bars and 19 is skipped. Answers that don't fit an earlier gym time keep V8's per-rest promise. The splits template page stays after the paywall, before the first workout, as today.

## 8 Nov 2026: no account page before the wall

At Sulav's request, after Cal AI: the commit makes a silent (anonymous Supabase) account, the GymBond
code page ("Got a code from a friend?") follows, then the wall. "Save your progress" (Apple or
Google, linked onto the same account; Not now) is the first setup page after the price, before the
permissions. See docs/GYMBOND-PLAN.md and VALIDATION.md.

## What goes

The welcome scene (lock screen, kettlebell, arm), the sucked-in phone, the stopwatch, the feed phone and wheel, the rack, the tally log, the two-bar lanes on the question pages, the year page and its dots, the plan page, the apps page in onboarding, and their scores. The haptics stay where a thing happens (a pick, Continue, the lock on page 7, the alert on 20, the loader's ticks, the hold); the sounds stay only on the lock, the alert and the commit.

## Sulav's second round (1 Nov 2026), all built

1. The welcome stays as it was (the locking phone, the arm, "Focused workouts.").
2. Days a week is a range with a mark and a second line, as Cal AI asks it: 0–2 "Now and then", 3–5 "A few a week", 6+ "Nearly every day"; the higher value in the range (2, 5, 6) is the weekly goal and the number the year multiplies.
3. "Where did you hear about us?" has a mark per row: the real icons of TikTok, Instagram and YouTube (`app.*` in Assets; the user's call on 1 Nov 2026, as Cal AI ships them, after drawn glyphs read as fake), the App Store's glyph on its blue, Google's own G, a friend, somewhere else. The shield and trial pages' phone draws its home screen with the real icons too: Apple's (Calendar, Photos, Reminders, News, Maps, Health, Wallet, Settings, Safari, Messages, taken from the simulator's home screen at 3×) and TikTok, Instagram, YouTube and X. They are other companies' marks: a known risk, taken knowingly.
4. The life number is Brainrot's dots: a hundred dots, their time at the gym until 65, light up one by one with a tick ("This is your time at the gym until you're 65." / "9 months, at 4 workouts a week."); on the next page the share on the phone turns red from the end and lands on a thud ("That's 5 months of your life." / "Of 9 months at the gym. Your numbers, multiplied out."). The two pages share the grid (`LifeDotsStage`).
5. "This is what you'll see instead." plays the whole phone (`ShieldStage`, as before: the home screen, the tap, the app, the shield landing with the lock).
6. The notification page shows only iOS's prompt, drawn (`AlertPromptStage`); Continue brings the real one.
7. The commit page keeps the fingerprint hold (`FingerprintHold`), under the mark; "Let's go. You're committed." appears when it completes.
8. The questions' rows sit in the middle of the screen; the interstitials (life, words, alerts, commit, trial) centre their headline too, as Cal AI does.
9. The trial reminder is a plain bell with one badge (`TrialBellStage`); the bell is the symbol (`bell.fill`, the one the user liked; a bell drawn from paths was rejected) with its own clapper masked off and a matching half-ellipse drawn in its place, on a clock: the body swings from its crown and dies away, the clapper swings on its own, a beat behind and wider, then a rest, on a loop; the badge pops onto the shoulder and rides the body; 40 pt of room so the swing never clips (1 Nov 2026). The symbol's geometry (glyph top 7%, rim bottom 76.5%, clapper 82 to 93% of the frame's height, 26.5% of its width) was measured from a render.

## Sulav's third round (1 Nov 2026, from the phone), all built

1. 6+ reads "Dedicated athlete".
2. The source rows carry the brands' own glyphs: Simple Icons' TikTok, Instagram, YouTube and App Store marks (CC0, fetched 1 Nov 2026 at the user's request) as template images in each brand's colours (`Assets.xcassets/brand.*`), and Google's own G.
3. "Do you check your phone between sets?" and "How long do you rest between sets?" have no line under them; the phone-minutes line is "Your best guess is fine."; the exercises question is "How many exercises do you do per workout?".
4. A disabled Continue is a solid grey button with its white label (`JourneyColor.disabledButton`), not a ghost at 38%.
5. One number per result page: the headline is a sentence that points at the big number ("Every rest, you lose this much." → 2.5 min; "Every workout, your phone takes this much." → 28 min; the open-ended "Every rest, you lose" read as a verdict, 1 Nov 2026), the strip names the parts, and the working ("From your answers: 14 rests × 2 minutes.", "The first 1.5 minutes were rest you'd take anyway.") sits above the button.
6. The dots mean something, in a lifter's unit (the seventh round: "a day at the gym" meant nothing, and "2 months of your life" sounded small): one dot for every workout in their next year, "This is your next year at the gym." / "Each dot is one workout: 208, at 4 a week." as they light; then "110 of them go to your phone." / "35 of every 66 minutes, between sets." as the phone's share turns red from the end (`TimeBack.yearWorkouts`, `yearPhoneWorkouts`, `LifeDotsStage`); then the number in life in the unit people feel, hours ("That's 3,760 hours of your life." / "At 4 workouts a week until you're 65."; years from two years up; `LifeWords`, `LifeNumberStage`). The promise and the word loop carry the same hours ("We'll give you those 3,760 hours back.", "3,760 more hours of").
7. The order is Brainrot's: the promise comes right after the life number ("We'll give you those 5 months back." / "35 minutes back, every workout.", the cost line above the button), then "5 more months of" with a picture of each one (Apple's emoji at full size, the fifth round, after ink figures read as lifeless: Family time and Your kids as separate faces side by side, since iOS 17.4 draws joined family emoji as grey silhouettes; a guitar, a boot, a dancer, a swimmer, two friends; the old word fades out before the next fades in, and a long word scales to one line). The progress line is emerald, the app's colour (it was ink), then what they tried, why it didn't hold, and the shield.

## Sulav's later rounds (1 Nov 2026, from the phone), all built

- The headline box keeps reserving two lines and a subtitle line, but the words sit at its top, so a one-line question's grey line hugs it (it floated half a line below).
- On the why page the thing they tried is semibold and the reason regular; GymBlock's line carries no lead, since its card is titled "With GymBlock".
- The shield page reads "This is what you'll see with GymBlock."
- "And how many sets of each exercise?" with no line under it; "Something else" on the cost question.
- The alerts page's Allow reads what iOS has recorded first: it asks while undetermined (checked on the simulator after a reinstall: the real prompt comes up over the drawn one), opens Settings once refused and waits for them to come back, and the page isn't in the route at all when notifications are already allowed, which is what a reinstall on Sulav's phone hit on 1 Nov 2026 ("Allow just continued").

## Checked

All 28 pages captured on the throwaway iPhone 17 Pro simulator (the third round's changed pages again in [round3-changed-pages.jpg](../screenshots/2026-11-01-v10/round3-changed-pages.jpg)) (iOS 26.5, `--ui-reset -journeyStep …`, the sample answers: 4 days, every rest, 1½-minute rests, 4-minute scrolls, 5 × 3, 25–34, TikTok, limits + willpower): [screenshots/2026-11-01-v10/board.jpg](../screenshots/2026-11-01-v10/board.jpg), and the name, why, and Spanish life and words pages again in [recheck-name-why-spanish.jpg](../screenshots/2026-11-01-v10/recheck-name-why-spanish.jpg). The build compiled first time; the why page's lines lost a lowercasing that had turned "Ignore Limit" into "ignore Limit". **Not checked:** the iPhone SE (no simulator here), haptics and sounds (no Taptic Engine), a real run from the welcome through the account and the paywall on a device, the unit tests (their route and animation expectations were rewritten but not run), the accessibility audit, and Home's new "Lock your apps" card on a device with Screen Time.

## Build notes (as built)

- One page frame in `OnboardingView` (OnboardingJourney.swift, rewritten): top bar, the headline left or centred with its line, the content, the caption slot, the action slot. `JourneyOption` rows as they are; `JourneyIconOption` adds a mark and a second line.
- Results: `BigNumberStage` (number + strip) on the per-rest and workout pages; the promise keeps `WorkStripStage` (the red sliding away) and the fitting path `RestFitsStage`.
- New (OnboardingV10.swift): `DaysRange`, `AgeAnswer`, `SourceAnswer` (fixed answers; `age` and `source` on the baseline, synced as JSON), rows for phone minutes, `TimeBack.lifeLostHours` / `lifeGymHours` / `lifeDots` and `LifeWords` (JourneyMetrics.swift), `LifeDotsStage`, `WhyStage` (two cards), `WordsStage`, `AlertPromptStage`, `CommitMarkStage`, `TrialPhoneStage`, `TrialBellStage`, `JourneyScores.dots`, and Home's `LockAppsCard` (Home.swift), which links to the blocked-apps page until apps are chosen.
- Route and resume mapping (`.yearTime` → age, `.blocking` → alerts, `.ahead` → per rest), analytics (`onboarding_answer` for source and age; the life hours and years on the result pages), Spanish (JourneyLanguageV10.swift), the route and animation tests, the audit list, and the development seeds (`-journeyAge`, `-journeySource`). The old scene views (the stopwatch, feed phone, rack, log, year dots, plan page, slider) stay in the code unused for now, to be removed once V10 is accepted.
- The dashboard paywall is Sulav's: the mockup's page 26 is the brief.
