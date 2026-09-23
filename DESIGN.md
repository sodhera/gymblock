# GymBlock Design System — Lock In

GymBlock locks your distracting apps while you train, logs the workout, and
counts the weeks you showed up. The interface should feel like good gym
equipment: plain, heavy where it matters, and precise. It's a tool you use
between sets with chalky hands and a raised heart rate, so everything
important is **big, one tap, and at the thumb**.

The voice and the double meaning of **"locked in"** carry the personality:
you're focused, and your phone is literally locked. It names the streak
("12 weeks locked in") and the shield ("You're locked in."). The main
button is plainly **Start Workout**.

## Principles

1. **Color is earned.** The app is ink on bone paper. Safety orange appears
   only for "locked in" moments: starting a workout, days trained, finished
   sets, PRs, the lock itself. If you want orange to decorate something,
   don't.
2. **One glance.** Anything shown on Today or a friend row must read in
   under a second with no legend. That's why the week is seven circles.
3. **One primary action per screen**, pinned at the bottom.
4. **Consequential exits are holds, harmless ones are taps.** Finishing a
   workout (which unlocks your apps) is *Hold to finish*. Collapsing the
   logger is a tap.
5. **Honest numbers only.** No sample data, no invented stats. Onboarding
   reveals are plain arithmetic on the user's own three answers.

> **Retired directions** (don't bring these back):
> - **"Load the bar":** a barbell whose plates loaded per workout. It was
>   clever but needed a legend (plate colors and loading order), so it
>   failed the one-glance rule.
> - **The dark graphite theme:** the user found it too dark. A gym is
>   bright, so GymBlock is light-first.
> - **"Lock in" as the CTA label:** replaced by "Start Workout".
> - **Exercise figures / muscle-map pictograms / exercise photos:** tried
>   and rejected. Exercises are identified by **name + muscle text**
>   ("Bench Press (Barbell)", "Chest · Triceps"). There are no figures
>   anywhere in the app.

## Palette (`Theme.swift → GBColor`)

| Token | Hex | Use |
| --- | --- | --- |
| `paper` | `#F4F2ED` | app background (warm bone) |
| `paperDeep` | `#EAE7E0` | pressed rows, input wells |
| white | `#FFFFFF` | cards, tiles |
| `ink` | `#111214` | primary text, ink buttons |
| `ink2` | `#3A3C40` | strong secondary |
| `steel` | `#6E7178` | secondary text, kickers |
| `fog` | `#A3A5AA` | tertiary, placeholders, "Previous" |
| `mist` | `#D9D6CF` | untrained days, empty bars |
| `hairline` | black 7% | dividers |
| `orange` | `#FF5B1A` | **the only accent** |
| `orangeSoft` | orange 12% | finished-set row tint |
| `danger` | `#C8372D` | destructive actions |
| `warmup` | `#D89A00` | the "W" set marker (a label, not an accent) |

v1 is **light only** (`UIUserInterfaceStyle = Light`). Tokens are
centralised so dark mode can be added later without touching views.

## Typography (`GBFont`)

SF Pro only, with no bundled fonts.

- **Heroes, titles, kickers:** SF Pro **Expanded** width. It reads like
  lettering stamped on equipment. Navigation bar titles use it too (set in
  `GymBlockApp.init`).
- **Body:** SF Pro regular width.
- **Numbers in columns** (weights, reps, timers, stats): monospaced digits,
  so logs line up like a logbook.
- Kickers are uppercase, tracked 1.2, steel: `WEDNESDAY · WEEK 39`.

## Containers

- **Liquid Glass** (native `glassEffect`, iOS 26.1+) is for things you
  touch or that float: primary/secondary buttons, icon buttons, the rest
  timer pill, the tab bar and its workout accessory.
- **Solid white cards** (`solidCard`) hold dense content: set tables,
  lists, settings groups. Glass refraction behind numbers hurts legibility
  mid-set.
- Static text sits directly on paper. Never nest cards.
- 20pt screen margins, 8pt grid, 58pt primary actions, ≥44pt targets.

## Haptics (`Haptics.swift`)

One pattern per physical moment. The same feeling always means the same
thing.

| Pattern | Moment | Feel |
| --- | --- | --- |
| `tap` | toggles, chips, steppers, tab switch | selection tick |
| `press` | every button (wired into button styles) | medium impact |
| `setDone` | set checked | crisp rigid double |
| `lock` | Start Workout, apps locked, week circle fills | heavy hit + low rumble: a shackle snapping shut |
| `unlock` | workout finished, purchase complete | two rising taps + soft bloom |
| `ratchet` | each tick of a hold | intensity climbs with progress |
| `countdown` | last 3s of rest | soft tick |
| `restEnd` | rest over | double knock |
| `pr` | personal record | swelling rumble into one big hit |
| `warning` | guarded / refused actions | rigid then soft |

## Signature element: the week strip

`WeekStrip.swift`. Monday to Sunday as seven circles. Trained days are
filled orange with a white check, today is outlined in ink, and every other
day is mist. The large version (labelled) is on Today and the summary; the
compact version (14pt, no labels) is on friend rows. Weeks are ISO (Monday
start) everywhere so friends agree on "this week".

## Screens

**Today:** kicker (weekday · week number), hero `3 of 4 / this week.`
(second line in fog; `Week's done.` in orange when complete), a week card
(strip + `12 weeks locked in`), then templates as selectable rows. Pinned
bottom: **Start {Template}** (the least-recently-used template is
suggested, so a split rotates on its own), a blocking status line ("6 apps
lock when you start", or a tappable fix), and a quiet *Empty workout*.

**Workout logger** (full-screen cover; the chevron collapses it into the
tab bar accessory): a stats row (time, volume, sets, apps locked), then
one card per exercise. The column grammar is borrowed from Hevy because
lifters already know it: **SET · PREVIOUS · KG · REPS · ✓**.
- Sets start empty. Last session's numbers show as fog placeholders and
  fill in when the set is checked, so logging is one tap per set.
- Tap *Previous* to copy it into the row. Tap the set number to mark
  warm-up (W, amber), drop (D), failure (F), or delete.
- A checked row tints `orangeSoft` and its check turns solid orange.
- A PR replaces the Previous cell with an orange **PR** tag and fires the
  `pr` haptic. A first-ever set is a baseline, not a PR.
- Checking a set starts the rest timer: a glass pill above the Finish
  button with −15 / +15 / Skip and a thin orange progress bar. A local
  notification fires at zero when the app is backgrounded.
- **Hold to finish** (ink capsule, 1.2s, ratchet haptics). With fewer than
  3 completed sets it asks "Finish early?": the workout won't count toward
  the week. With none, it offers to discard.

**Summary:** "Apps unlocked" kicker, the week hero, and the strip with
today's circle filling in after a beat (with the `lock` haptic). Then
stats, new records (orange-washed card), exercises with best set, and a
share toggle. *Save as template* for workouts that didn't start from one.

**History:** segmented *Workouts / Records*. Workouts are grouped by
training week with "n of target" per week (orange when hit). Detail shows
every set, the share toggle, save as template, and delete.

**Friends:** a list of weeks, not a feed. Each row shows avatar initials,
name, streak, last workout, n/target, and the compact strip. Detail shows
the big strip, streak / consistency / workouts, records, and recent
workouts (shared ones open; private ones show a lock). The only social verb
is **Nudge**, offered when their week isn't done. No likes, no comments.
Invites are `gymblock://add/<username>` via the share sheet.

**Profile:** name, @username, a stats band (workouts, streak, 12-week
consistency), a 12-week bar chart (orange bars hit the target, dashed
target line), and best lifts. The gear opens Settings.

**Settings:** kicker-titled groups: Profile, Training (weekly target,
units, default rest, share by default), Blocking (toggle, apps; locked
while a workout runs), Subscription, Account (sign out; *Delete account*
as faded text requiring "delete" typed).

## Sign-up flow

Ask → reveal, the same rhythm as SleepBlock. The steps crossfade (they
don't slide).

> welcome → days/week → session length → phone minutes → *one session,
> split* → *the year* → goal → the plan → name + units → shield demo →
> **Hold to commit** → account → paywall → Screen Time + notifications

- **Three inputs derive everything** (`PhoneMath`): phone minutes ×
  days × 52 = hours a year, then divided by session length = "whole
  workouts you showed up for and didn't do".
- *One session* shows a bar splitting lifting (ink) from phone (orange).
- *The year* is a grid of every session in a year, with the lost ones
  lighting orange one by one from the bottom.
- The plan shows the week strip plus the starter templates generated for
  the chosen days (≤3 Full body A/B, 4 Upper/Lower, 5+ Push/Pull/Legs).
- The shield demo is a looping illustration with **generic** app icons,
  never real brands.
- *Hold to commit* (1.6s): "I'll train N days a week, and my phone stays
  locked until each workout's done."
- Account: Sign in with Apple first, email as the alternative.

## Paywall

A hard wall with no ✕. The headline hands back the onboarding number:
**"Get your 52 hours back."** Then three feature lines, a trial timeline
(Today: full access → Day N−2: reminder → Day N: billed), and plan cards
(yearly first, "Save N%" badge, per-week price on the right). CTA: *Start
7-day free trial*. The Day N−2 reminder is a real local notification,
scheduled on purchase.

## The block

- **Earn your unlock.** Start Workout shields the chosen apps in the named
  `ManagedSettingsStore(.gymblock)`. Finishing (or discarding) clears it.
- **Safety cap:** a 4-hour DeviceActivity interval. If a session is never
  finished, `GymBlockMonitor` clears the shield when the interval ends.
  Nobody's phone stays locked overnight.
- **Shield** (`ShieldConfigProvider`): paper background, orange lock
  square, title "You're locked in." (then "Still locked in." / "Third
  time. Still no." / "You know the answer." on repeat reaches), and a
  subtitle with *this* workout's progress: "Instagram can wait. 3 sets of
  Bench Press left." There's one button, *Back to the workout*, and no
  escape hatch on the shield.
- Blocking settings are disabled while a workout runs.

## Live Activity (Dynamic Island + Lock Screen)

`GymBlockWidget/WorkoutLiveActivity.swift`, with shared attributes and
intents in `SharedActivity/WorkoutActivity.swift`. **One activity runs for
the whole workout** (started by Start Workout, ended by finishing or
discarding) and has two states:

- **Lifting:** a lock glyph, the workout clock, `SETS 6/18`, and the next
  set ("Bench Press · set 3 of 4").
- **Resting** (after every checked set): an orange countdown, a thin orange
  progress bar, and **+15** / **Skip** buttons. The buttons are
  `LiveActivityIntent`s that run in the app and adjust the same `RestTimer`
  the logger uses, so the pill, the island, and the notification always
  agree.

| Surface | Lifting | Resting |
| --- | --- | --- |
| Compact | orange lock · white clock | orange timer glyph · orange countdown |
| Minimal | orange lock | circular orange countdown ring |
| Expanded | title kicker, big clock · SETS n/m · next set | REST, big orange countdown · +15 / Skip · bar · next set |
| Lock Screen | bone paper + ink (like the app) | same, orange countdown + buttons + bar |

The island is always black, so text there is white and orange carries the
countdown. The Lock Screen banner uses the app's paper and ink. All timers
are system-rendered (`Text(timerInterval:)`, `ProgressView(timerInterval:)`),
with no per-second updates from the app. The activity's `staleDate` is the
rest end: if the app is suspended when rest runs out, the system flips it
to "Rest's over. Next: Bench Press" by itself. The local "Rest's over"
notification still provides the sound.

## App icon

A white padlock on a safety-orange field
(`scripts/generate-app-icon.swift`). It uses the same shape as the
in-app `BrandMark` and the shield icon.

## What to avoid

- Orange as decoration, gradients as decoration, confetti.
- Exercise figures or illustrations of any kind.
- Exclamation marks and "Great job!" copy. The voice is dry and terse.
- A second primary button on a screen.
- Disabled toggles as "locks". Remove or disable the whole control with a
  line saying when it opens.
