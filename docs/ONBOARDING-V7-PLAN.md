# GymBlock onboarding V7 — design spec

**17 Oct 2026 · Implemented.** Supersedes [ONBOARDING-V5-PLAN.md](ONBOARDING-V5-PLAN.md) for the page list, the copy, the haptics and the sound. The stage, type, Liquid Glass, compact sizing, the approved arm and brain art, the one-line qualifiers and the account-before-offer order are unchanged. The proposal, with captures of the V5 flow beside playable mockups, is [docs/onboarding-mockups/index.html](onboarding-mockups/index.html).

The person should leave thinking: *"I lose a lot of my gym time to my phone. GymBlock locks it, times my rests and keeps an honest record. Someone who trains built it."*

## What changed from V5

- **Opening:** the welcome shows the change, not the mechanism. "Stop scrolling → Stay focused" and "Record everything → Get jacked" (the user's wording) sit around a lock screen that fills with notifications until the kettlebell falls onto it and locks it, while the approved arm flexes and turns green.
- **Sulav's note:** his founder's note follows as the second page.
- **Voice:** every page after the note speaks as "we", plainly ("First, what should we call you?").
- **Questions:** gender, height and weight left onboarding; they were saved but used for nothing (they stay editable in Profile). One question replaces them, how many days a week you lift. It feeds the yearly number, Home's weekly goal and the widgets.
- **Splits:** they're asked after the offer, as one tap on a template, and onboarding ends one tap from the first workout instead of on a blank split editor.
- **Haptics and sound:** designed haptics on the beats that matter, and iOS's own sounds at three moments only, see below. Sound is on in onboarding unless turned off in Settings, and the silent switch silences it.
- **Offer:** it sells the change in the person's own numbers and shows the trial as a timeline.

## Pages (21; 19 for Rarely, which skips minutes and hours)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1 | (the stage carries the words) | Stop scrolling → Stay focused / Record everything → Get jacked; lock screen, notifications, falling kettlebell, flexing arm (`WelcomeScene`) | Get started · I already have an account |
| 2 | "Perfection is lots of little things done right." | Sulav's short note, set on the paper with no card (the largest text that fits; scrolls only at accessibility sizes); no animation, no sound (`FounderStage`) | Continue |
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

Restraint is the rule (18 Oct 2026, after testing on an iPhone SE). Haptics go only on beats that mean something, mostly single taps. Sound is used only where life has one, and only iOS's own sounds (`/System/Library/Audio/UISounds`, played with `AVAudioPlayer` at low volume). Nothing is synthesized, and there's no background hum. Each scene's score is in `JourneyScores.swift`; `JourneyScorePlayer` (`JourneyScore.swift`) schedules the haptics and the sound for one shared moment, ahead by the audio route's latency, and the scene starts moving on that same moment.

| Page | Haptics | Sound |
|---|---|---|
| Welcome | A light tap per notification, one firm hit when the kettlebell lands, one tap on the flex's peak | The Messages ding per notification; the iPhone's lock click on the landing |
| Phone between sets | One light tap per card, a little stronger each time | None |
| Ring / hours a year | One soft tap when the red count lands and one when the green does / one tap on the total | None |
| Mind A / B | One tap per signal: weaker each time (70, 45, 25, 10%) / the same three times (60%) | None |
| Pump A / B (unchanged; the user's favourite pages) | Each set swells and lands as the arm peaks: the same middle strength, nothing in the long rests / stronger every set, a second tap when full | None |
| Memory / log | A fainter tap as each number fades / a light tap when the line reaches each dot, a firmer one on +5 kg | None |
| Blocking | One crisp tap as the shield locks | The iPhone's lock click |
| Rest alerts | The real double buzz on 0:00 | The tri-tone on 0:00 |
| Hold to commit | A buzz that climbs while held; one firm tap when committed | None |

Page changes have no haptic. Haptic feel needs a real iPhone; the simulator has no Taptic Engine.

## Motion

The welcome and both mind-muscle pages are drawn from one clock (`SceneClock`, a `TimelineView` at the display's refresh rate). Springs and easing are computed per frame, and the arm blends between neighbouring pre-rendered poses, so it bends continuously. Reduce Motion shows each scene's last frame and skips its score. Continue fades in the moment a scene ends: no hold and no minimum time on the page, and each scene's clock ends with its last movement. kg or lb is no longer asked; it follows the phone's region the first time and can be changed in Profile.
