# GymBlock onboarding V7 — design spec

**17 Oct 2026 · Implemented; revised 18 Oct 2026 after a tester's review (the review round in VALIDATION.md).** Supersedes [ONBOARDING-V5-PLAN.md](ONBOARDING-V5-PLAN.md) for the page list, the copy, the haptics and the sound. The stage, type, Liquid Glass, compact sizing, the approved arm and brain art, the one-line qualifiers and the account-before-offer order are unchanged. The proposal, with captures of the V5 flow beside playable mockups, is [docs/onboarding-mockups/index.html](onboarding-mockups/index.html).

The person should leave thinking: *"I lose a lot of my gym time to my phone. GymBlock locks it, times my rests and keeps an honest record. Someone who trains built it."*

## What changed from V5

- **Opening:** the welcome shows the change, not the mechanism. "Stop scrolling → Stay focused" and "Record everything → Get jacked" (the user's wording) sit around a lock screen that fills with notifications until the kettlebell falls onto it and locks it. One thing moves at a time: the phone locks, then "Stay focused"; then "Record everything" and "Get jacked"; only then does the approved arm flex and turn green.
- **Sulav's note:** his founder's note follows as the second page.
- **Voice:** every page after the note speaks as "we", plainly ("First, what should we call you?").
- **Questions:** gender, height and weight left onboarding; they were saved but used for nothing (they stay editable in Profile). One question replaces them, how many days a week you lift. It feeds the yearly number, Home's weekly goal and the widgets.
- **Splits:** they're asked after the offer, as one tap on a template, and onboarding ends one tap from the first workout instead of on a blank split editor.
- **Haptics and sound:** each moment has its own designed haptic and a real sound placed on its frame, see below. Sound is on in onboarding unless turned off in Settings. It plays with the Ring/Silent switch on silent too (the user's choice, 18 Oct 2026: a playback audio session, mixed with others, so music keeps playing); the volume buttons still set how loud. The workout's own sounds, off unless turned on in Settings, still follow the switch.
- **Offer:** it sells the change in the person's own numbers: Today, red phone time and green lifting; With GymBlock, one fully green bar for the whole workout ("46 min focused workout"). The trial shows as a timeline.

## Pages (22; 20 for Rarely, which skips minutes and hours)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1 | (the stage carries the words) | Stop scrolling → Stay focused / Record everything → Get jacked; lock screen, notifications, falling kettlebell, flexing arm (`WelcomeScene`) | Get started · I already have an account |
| 2 | "Perfection is lots of little things done right." | Sulav's note (approved 18 Oct 2026), set on the paper with no card. It uses the largest text that fits (18.5 pt on the largest phones) and scales down slightly on small screens; it scrolls only at accessibility sizes. No animation, no sound (`FounderStage`) | Continue |
| 3 | First, what should we call you? | Name field | Continue |
| 4 | Nice to meet you, {Name}. How many days a week do you work out? | Glass rows, 2 days to 6 or more, the same as every other question (`TrainingDaysStage`) | Continue (after choosing) |
| 5 | Be honest. Do you check your phone between sets? | Three cards land 0.45 s apart, each on a light tap, scaled to fit the space (iPhone SE, large text) | Every rest · Sometimes · Rarely |
| 6 | Roughly how long, each rest? | Wheel | Continue |
| 7 | {Name}, here's where your workout time goes. | The ring (34 of 46 min), red and green meeting with no gap; under it "On your phone" and "Lifting", each with its sum (17 rests × 2 min, 18 sets × 40 s) | Continue |
| 8 | At {days} workouts a week, that's {h} hours a year on your phone. | A dot per 45-minute workout | Continue |
| 9–10 | Scrolling weakens your mind-muscle connection. / Put it away. Feel every rep. | Brain, nerve and arm, drawn from a clock (`MindStage`, `MindState`) | Continue |
| 11–12 | Long scrolls between sets? The pump never builds. / Rest on time, and it keeps building. | Pump chart and arm | Continue |
| 13–14 | It's easy to forget how well you did. / Your log remembers. Every set. | Values fade to "?", then the log | Continue |
| 15 | Open a locked app while you train, and you'll see this. | The shield's real words slide up and lock (`ShieldStage`, `OnboardingShield`) | Continue |
| 16 | Which apps should we lock while you train? | The tiles: two rows of slots before anything is chosen (`BlockStage`) | Choose apps (iOS asks first) |
| 17 | We'll buzz you / when rest is up. | The Live Activity counts the last seconds, the notification lands (`LockScreenRest`) | Continue → iOS prompt |
| 18 | {Name}, here's your plan. | Three lines on the paper: days a week, what's locked, rests (`PlanStage`) | Hold to commit |
| 19 | Let's save your plan to your account. | Account card | Sign up with Apple / Google |
| 20 | (offer) {Name}, your best sessions start today. | Your workout two ways, three promises, trial timeline, plans | Start 7-day free trial |
| 21 | You're in. How do you usually split your training? | Push · Pull · Legs, Upper · Lower, Full body, One muscle a day, No fixed plan (or Keep my splits) with a preview, and Build my own split, which opens the split editor (`SplitTemplateStage`) | Continue |
| 22 | Ready? Your first workout is {split}. | Its exercises, Edit (`FirstWorkoutStage`) | Start workout · I'm not at the gym yet |

Old saved progress on gender, height or weight resumes at the days question; nothing stored is discarded.

## The offer

- **Bars:** the same arithmetic as the reveal, drawn as two bars under "Your 46-minute workout". Today: 34 min on your phone in red, then the lifting in green. With GymBlock: one fully green bar, "46 min focused workout" (18 Oct 2026: the whole workout, not the phone minutes). It never claims the rests become lifting.
- **Promises:** apps locked from first set to last; a buzz the moment rest is up; every set saved, and what to beat next time.
- **Timeline:** Today (full access), Day 5 (we remind you), Day 7 (plan starts). Day 5 shows only when notifications are allowed, because the reminder is a local notification scheduled at purchase (`RestAlert.scheduleTrialReminder`).
- **Plans:** both cards show the price a month large; the yearly card carries the trial badge.
- **Terms:** the automatic-charge line App Review requires is unchanged. The wall still has no close button.

## Haptics and sound

Haptics land only on beats that mean something, and each moment has its own feel rather than a plain tap: the vocabulary in `JourneyScores.swift` builds them from sharp or soft transients and short continuous buzzes whose strength ramps. Where a sound has notes, the taps sit under them.

| Feel | What it's made of | Where |
|---|---|---|
| Press | A rounded hit with a short settling tail | Continue and onboarding's other main buttons |
| Ping | Two quick taps, the second lighter, the iPhone's message feel | Each notification |
| Thud | A deep hit and a low rumble that dies away | The kettlebell landing, the yearly total, committing |
| Latch | A crisp click and a small after-click | The shield locking, Start workout |
| Heartbeat | Lub-dub | Mind B's first two squeezes |
| Tick | A light, crisp tap | The hours-a-year dots, the log's dots, the countdown |
| Falter | Two falling taps under "reading failed" and a buzz that dies, sooner the weaker it is | Mind A's twitches |
| Ring | Three rising taps under the Activity ring's chime, then a shimmer | Mind B's third squeeze, the full pump, today's log dot |

Every sound is real: iOS's own sounds (`/System/Library/Audio/UISounds`, including the Health and Activity sounds Apple Watch uses, which are recorded far quieter, so the app raises them to the others' level as it opens them), or recorded clips bundled in `GymBlock/Resources/Sounds` (Kenney's CC0 metal and plate impacts, see CREDITS.md). Each is placed on the frame it belongs to, and nothing plays underneath as a bed. Each scene's score is in `JourneyScores.swift`. `JourneyScorePlayer` (`JourneyScore.swift`) gives each cue its own `AVAudioPlayer`, scheduled ahead by the audio route's latency, and the scene starts moving on that same moment. The sounds were picked by ear on 18 Oct 2026 from a review page that played today's clips beside iOS's.

| Page | Haptics | Sound |
|---|---|---|
| Welcome | A ping per notification, a thud with a click when the kettlebell lands, a rising buzz as the arm flexes and a firm hit on its peak | The Messages ding per notification, the lock click on the landing, a plate on the flex |
| Phone between sets | A ping per card, a little stronger each time | None |
| Ring | A soft hit when the red count lands, a rising shimmer as the green fills | A clock tock ticking the phone time away (following the eased count); a light clink as the green lands |
| Hours a year | Ticks that follow the dots as they light, each a touch firmer, then a thud as the last dot lights | Tocks with the ticks, then a heavy plate drop on the last dot |
| Mind A | A falter on each of the first three twitches, weaker each time (75, 45, 22%); the fourth signal only fizzles | Health's "reading failed" on each twitch, clearly quieter each time |
| Mind B | A heartbeat on the first two squeezes, the ring on the third | A soft tick on the first two, the Activity ring's "goal attained" on the third |
| Pump A / B (the user's favourite) | Each set swells and lands as the arm peaks: the same middle strength, nothing in the long rests or after the last set / stronger every set, the ring when full | The same soft tock every set / a tick that builds every set; when full, "goal attained" |
| Memory / log | A fainter tap as each number fades / a tick as each week's dot pops at its fullest, where the line reaches it; the ring on today's dot as it turns green and +5 kg lands | None / a soft tick per logged week; "goal attained" on today |
| Blocking | A latch as the shield locks | The lock click |
| Rest alerts | A tick each second as the Live Activity counts down, then the real double buzz on 0:00 | The tri-tone on 0:00 |
| Hold to commit | A buzz that climbs while held; a thud when committed | A plate going back on the rack |
| Start workout (last page) | A latch | The lock click, as the apps lock |

Page changes have no haptic of their own; the button that changes the page presses in. Haptic feel needs a real iPhone; the simulator has no Taptic Engine.

## Small screens

`JourneyLayout.compact` (screens under 700 pt tall: iPhone SE and other 4.7-inch phones) keeps every page from filling the screen edge to edge:
- **Text and rows:** headlines one size smaller (title 2), answer rows 44 pt instead of 52.
- **Spacing:** wider side margins around every scene (32 pt instead of 24).
- **Scenes:**
  - the welcome drawn at no more than 74% of its design size;
  - a 160-pt ring;
  - a narrower dot grid;
  - a shorter pump chart and smaller arm;
  - tighter plan rows;
  - a smaller offer headline;
  - five exercises (plus "+ N more") on the first-workout card;
  - on the split page, no preview card: the line above Continue says what we'll set up ("We'll set up Push, Pull and Legs: 6 exercises each."). With six options (when you already have splits) the card pushed the page past the screen.
- **Fit to the space:** the phone-habit notifications, the blocking page and Sulav's note scale to fit what's left. The split page scrolls if it still runs over (large text, longer Spanish).

## Motion

The welcome, both mind-muscle pages, the hours-a-year dots and the log are drawn from one clock (`SceneClock`, a `TimelineView` at the display's refresh rate), the same clock as their score. Every scene draws about two frames (0.03 s, `JourneyScores.displayLead`) ahead, the time the screen takes to show a frame, so what's seen lands on what's heard. Springs and easing are computed per frame, and the arm blends between neighbouring pre-rendered poses, so it bends continuously. Reduce Motion shows each scene's last frame and skips its score. Continue fades in the moment a scene ends: no hold and no minimum time on the page, and each scene's clock ends with its last movement. kg or lb is no longer asked; it follows the phone's region the first time and can be changed in Profile.
