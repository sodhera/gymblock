# GymBlock onboarding V7 — design spec

**17 Oct 2026 · Implemented.** Supersedes [ONBOARDING-V5-PLAN.md](ONBOARDING-V5-PLAN.md) for the page list, the copy, the haptics and the sound. The stage, type, Liquid Glass, compact sizing, the approved arm and brain art, the one-line qualifiers and the account-before-offer order are unchanged. The proposal, with captures of the V5 flow beside playable mockups, is [docs/onboarding-mockups/index.html](onboarding-mockups/index.html).

The person should leave thinking: *"I lose a lot of my gym time to my phone. GymBlock locks it, times my rests and keeps an honest record. Someone who trains built it."*

## What changed from V5

- **Opening:** the welcome shows the change, not the mechanism. "Stop scrolling → Stay focused" and "Record everything → Get jacked" (the user's wording) sit around a lock screen that fills with notifications until the kettlebell falls onto it and locks it, while the approved arm flexes and turns green.
- **Sulav's note:** his founder's note follows as the second page.
- **Voice:** every page after the note speaks as "we", plainly ("First, what should we call you?").
- **Questions:** gender, height and weight left onboarding; they were saved but used for nothing (they stay editable in Profile). One question replaces them, how many days a week you lift. It feeds the yearly number, Home's weekly goal and the widgets.
- **Splits:** they're asked after the offer, as one tap on a template, and onboarding ends one tap from the first workout instead of on a blank split editor.
- **Haptics and sound:** designed haptics on the beats that matter, and iOS's own sounds at three moments only, see below. Sound is on in onboarding unless turned off in Settings. It plays with the Ring/Silent switch on silent too (the user's choice, 18 Oct 2026: a playback audio session, mixed with others, so music keeps playing); the volume buttons still set how loud. The workout's own sounds, off unless turned on in Settings, still follow the switch.
- **Offer:** it sells the change in the person's own numbers: Today, red phone time and green lifting; With GymBlock, one fully green bar ("34 min focused workout"). The trial shows as a timeline.

## Pages (21; 19 for Rarely, which skips minutes and hours)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1 | (the stage carries the words) | Stop scrolling → Stay focused / Record everything → Get jacked; lock screen, notifications, falling kettlebell, flexing arm (`WelcomeScene`) | Get started · I already have an account |
| 2 | "Perfection is lots of little things done right." | Sulav's note (approved 18 Oct 2026), set on the paper with no card. It uses the largest text that fits and scales down slightly on small screens; it scrolls only at accessibility sizes. No animation, no sound (`FounderStage`) | Continue |
| 3 | First, what should we call you? | Name field | Continue |
| 4 | Nice to meet you, {Name}. How many days a week do you work out? | 2 · 3 · 4 · 5 · 6+ (`TrainingDaysStage`) | Continue (after choosing) |
| 5 | Be honest. Do you check your phone between sets? | Three cards land 0.45 s apart, each on a light tap, scaled to fit the space (iPhone SE, large text) | Every rest · Sometimes · Rarely |
| 6 | Roughly how long, each rest? | Wheel | Continue |
| 7 | {Name}, here's where your workout time goes. | The ring (34 of 46 min) | Continue |
| 8 | At your {days} workouts a week, that's {h} hours a year. | A dot per 45-minute workout | Continue |
| 9–10 | Scrolling weakens your mind-muscle connection. / Put it away. Feel every rep. | Brain, nerve and arm, drawn from a clock (`MindStage`, `MindState`) | Continue |
| 11–12 | Long scrolls between sets? The pump never builds. / Rest on time, and it keeps building. | Pump chart and arm | Continue |
| 13–14 | Quick: what did you bench last week? / Your log remembers. Every set. | Values fade to "?", then the log | Continue |
| 15 | Which apps should we lock while you train? | The shield's real words slide up and lock (`OnboardingShield`), then the tiles | Choose apps (iOS asks first) |
| 16 | We'll buzz you when rest is up. | The Live Activity counts the last seconds, the notification lands (`LockScreenRest`) | Continue → iOS prompt |
| 17 | {Name}, here's your plan. | Three lines on the paper: days a week, what's locked, rests (`PlanStage`) | Hold to commit |
| 18 | Let's save your plan to your account. | Account card | Sign up with Apple / Google |
| 19 | (offer) {Name}, your best sessions start today. | Your workout two ways, three promises, trial timeline, plans | Start 7-day free trial |
| 20 | You're in. How do you usually split your training? | Push · Pull · Legs, Upper · Lower, Full body, One muscle a day, No fixed plan (or Keep my splits) with a preview, and Build my own split, which opens the split editor (`SplitTemplateStage`) | Continue |
| 21 | Ready? Your first workout is {split}. | Its exercises, Edit (`FirstWorkoutStage`) | Start workout · I'm not at the gym yet |

Old saved progress on gender, height or weight resumes at the days question; nothing stored is discarded.

## The offer

- **Bars:** the same arithmetic as the reveal, drawn as two bars. Today: 34 min on your phone, 12 min lifting. With GymBlock: 34 min of timed rest, 12 min lifting, phone 0 min. Rests stay rests; it never claims they become lifting.
- **Promises:** apps locked from first set to last; a buzz the moment rest is up; every set saved, and what to beat next time.
- **Timeline:** Today (full access), Day 5 (we remind you), Day 7 (plan starts). Day 5 shows only when notifications are allowed, because the reminder is a local notification scheduled at purchase (`RestAlert.scheduleTrialReminder`).
- **Plans:** both cards show the price a month large; the yearly card carries the trial badge.
- **Terms:** the automatic-charge line App Review requires is unchanged. The wall still has no close button.

## Haptics and sound

Haptics land only on beats that mean something, mostly single taps. Every sound is real: iOS's own sounds (`/System/Library/Audio/UISounds`), or recorded clips bundled in `GymBlock/Resources/Sounds` (Mixkit's sad trombone and Kenney's CC0 metal and plate impacts, see CREDITS.md). Each is placed on the frame it belongs to, and nothing plays underneath as a bed. Each scene's score is in `JourneyScores.swift`. `JourneyScorePlayer` (`JourneyScore.swift`) gives each cue its own `AVAudioPlayer`, scheduled ahead by the audio route's latency, and the scene starts moving on that same moment.

| Page | Haptics | Sound |
|---|---|---|
| Welcome | A light tap per notification, one firm hit when the kettlebell lands, one tap on the flex's peak | The Messages ding per notification, the lock click on the landing, a plate on the flex |
| Phone between sets | One light tap per card, a little stronger each time | None |
| Ring | One soft tap when the red count lands, one when the green does | A clock tock ticking the phone time away (following the eased count); a light clink as the green lands |
| Hours a year | A run of light taps that follows the dots as they light, each a touch firmer, then one heavy hit as the last dot lights | Tocks with the taps, then a heavy plate drop on the last dot |
| Mind A | One tap per signal, weaker each time (70, 45, 25, 10%) | Mixkit's "Trombone disappoint", cut into its three notes. Each note is heard on a twitch, with its tap: womp on the contraction, womp on the half contraction, then the long wommmp on the last small twitch, carrying through as the fourth signal fizzles |
| Mind B | The same tap three times (60%) | A clink on each squeeze, heavier each time; the last over an iron plate |
| Pump A / B (the user's favourite) | Each set swells and lands as the arm peaks: the same middle strength, nothing in the long rests or after the last set / stronger every set, the strongest tap when full | The same dull clank every set / plates getting heavier every set; when full, a bright clink on the same instant as the plate and the tap |
| Memory / log | A fainter tap as each number fades / a light tap as each week's dot pops at its fullest, where the line reaches it; today's dot gets one firmer tap as it turns green and +5 kg lands | None / a key click per logged week; today's key click and a clink on the same beat |
| Blocking | One crisp tap as the shield locks | The lock click |
| Rest alerts | A light, crisp tick each second as the Live Activity counts down, then the real double buzz on 0:00 | The tri-tone on 0:00 |
| Hold to commit | A buzz that climbs while held; one firm tap when committed | A plate going back on the rack |
| Start workout (last page) | One tap | The lock click, as the apps lock |

Page changes have no haptic. Haptic feel needs a real iPhone; the simulator has no Taptic Engine.

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
