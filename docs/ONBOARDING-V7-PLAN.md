# GymBlock onboarding V7 — design spec

**17 Oct 2026 · Implemented.** Supersedes [ONBOARDING-V5-PLAN.md](ONBOARDING-V5-PLAN.md) for the page list, the copy, the haptics and the sound. The stage, type, Liquid Glass, compact sizing, the approved arm and brain art, the one-line qualifiers and the account-before-offer order are unchanged. The proposal, with captures of the V5 flow beside playable mockups, is [docs/onboarding-mockups/index.html](onboarding-mockups/index.html).

The person should leave thinking: *"I lose a lot of my gym time to my phone. GymBlock locks it, times my rests and keeps an honest record. Someone who trains built it."*

## What changed from V5

- **Opening:** the welcome shows the change, not the mechanism. "Stop scrolling → Stay focused" and "Record everything → Get jacked" (the user's wording) sit around a lock screen that fills with notifications until the kettlebell falls onto it and locks it, while the approved arm flexes and turns green.
- **Sulav's note:** his founder's note follows as the second page.
- **Voice:** every page after the note speaks as "we", plainly ("First, what should we call you?").
- **Questions:** gender, height and weight left onboarding; they were saved but used for nothing (they stay editable in Profile). One question replaces them, how many days a week you lift. It feeds the yearly number, Home's weekly goal and the widgets.
- **Splits:** they're asked after the offer, as one tap on a template, and onboarding ends one tap from the first workout instead of on a blank split editor.
- **Haptics and sound:** each animation has a designed haptic pattern (Core Haptics) and sound on one clock, see below. Sound is on in onboarding unless turned off in Settings, and the silent switch silences it.
- **Offer:** it sells the change in the person's own numbers and shows the trial as a timeline.

## Pages (21; 19 for Rarely, which skips minutes and hours)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1 | (the stage carries the words) | Stop scrolling → Stay focused / Record everything → Get jacked; lock screen, notifications, falling kettlebell, flexing arm (`WelcomeScene`) | Get started · I already have an account |
| 2 | "Perfection is lots of little things done right." | Sulav's note on one card; no animation, no sound (`FounderStage`) | Continue |
| 3 | First, what should we call you? | Name field | Continue |
| 4 | Nice to meet you, {Name}. How many days a week do you work out? | 2 · 3 · 4 · 5 · 6+ (`TrainingDaysStage`) | Continue (after choosing) |
| 5 | Be honest. Do you check your phone between sets? | Notifications creep in, each with a double tap (haptics only, no sound) | Every rest · Sometimes · Rarely |
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
| 20 | You're in. How do you usually split your training? | Push · Pull · Legs, Upper · Lower, Full body, One muscle a day, No fixed plan (or Keep my splits) with a preview (`SplitTemplateStage`) | Continue |
| 21 | Ready? Your first workout is {split}. | Its exercises, Edit (`FirstWorkoutStage`) | Start workout · I'm not at the gym yet |

Old saved progress on gender, height or weight resumes at the days question; nothing stored is discarded.

## The offer

- **Bars:** the same arithmetic as the reveal, drawn as two bars. Today: 34 min on your phone, 12 min lifting. With GymBlock: 34 min of timed rest, 12 min lifting, phone 0 min. Rests stay rests; it never claims they become lifting.
- **Promises:** apps locked from first set to last; a buzz the moment rest is up; every set saved, and what to beat next time.
- **Timeline:** Today (full access), Day 5 (we remind you), Day 7 (plan starts). Day 5 shows only when notifications are allowed, because the reminder is a local notification scheduled at purchase (`RestAlert.scheduleTrialReminder`).
- **Plans:** both cards show the price a month large; the yearly card carries the trial badge.
- **Terms:** the automatic-charge line App Review requires is unchanged. The wall still has no close button.

## Haptics and sound

Each scene's score is in `JourneyScores.swift`; `JourneyScorePlayer` (`JourneyScore.swift`) plays the Core Haptics pattern and schedules the sounds on an audio engine at the same start time. Strength follows the story; sharpness follows the material; silence carries meaning.

- **Welcome:** a notification double tap and ding per app, a rumble that grows as the kettlebell falls, one heavy dull impact and a crisp lock click, a swell through the flex that peaks in a firm hit.
- **Notifications (welcome only; the phone-habit page is haptics only):** each app has its own ding. They are GymBlock's own sounds, not Instagram's or TikTok's, which belong to those companies.
- **Ring:** ticks climb with the red count; the green lands with a light shimmer, no bass.
- **Hours a year:** a fine rattle that builds as the dots fill, then one heavy hit.
- **Mind A:** each signal down the nerve is shorter, softer and duller (85%, 50%, 28%, 12%); only the first reaches the arm. A warm chord loses its brightness underneath.
- **Mind B:** three identical signals at the same strength, like a heartbeat; the chord opens up; a major chord to finish.
- **Pump A:** every set swells to the same middle strength and never higher. The long rests get nothing but faint scroll flicks, then a dull tap.
- **Pump B:** each set lands stronger, on a rising scale, with a double hit when it's full.
- **Memory:** each number fades with a fainter tap and a falling, out-of-tune note. The log taps follow the line, with a double hit on +5 kg.
- **Shield:** a soft rise, then one sharp click as it locks.
- **Rest alerts:** three countdown ticks, each firmer, then the real double buzz.
- **Hold to commit:** one continuous buzz that climbs while the finger stays down, then a heavy hit and a chord.

Sounds are synthesized by `scripts/generate-onboarding-sounds.py` into `GymBlock/Resources/Sounds/onboarding/` (no third-party audio). Haptic feel needs a real iPhone; the simulator has no Taptic Engine.

## Motion

The welcome and both mind-muscle pages are drawn from one clock (`SceneClock`, a `TimelineView` at the display's refresh rate). Springs and easing are computed per frame, and the arm blends between neighbouring pre-rendered poses, so it bends continuously. Reduce Motion shows each scene's last frame and skips its score. Continue fades in the moment a scene ends: no hold and no minimum time on the page, and each scene's clock ends with its last movement. kg or lb is no longer asked; it follows the phone's region the first time and can be changed in Profile.
