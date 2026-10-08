# GymBlock V6: the app after onboarding

7 October 2026 · Implemented on iPhone 18 Pro / iOS 27 simulator. Replaces the training and navigation parts of [UX-RESET-V3.md](UX-RESET-V3.md). Onboarding stays as in [ONBOARDING-V5-PLAN.md](ONBOARDING-V5-PLAN.md).

## Who, where, and what goes wrong

The person is between sets. Their hands are sweaty, they may have gloves on, and they glance at the phone for a second or two. They're interrupted: someone asks to work in, the bench is taken, a call comes in, the phone locks, iOS closes the app overnight. They forget to tap Start, forget to tap Finish, and sometimes forget to end the workout at all. The app's purpose is the opposite of most apps: **the less time they spend in it, the better it's working.**

The design follows from that:

1. **One screen, one button, one place.** The workout is a single screen. Its primary button sits exactly where Home's Start workout and onboarding's Continue sit, so the thumb learns one position. A UI test asserts the frames are identical.
2. **Everything is pre-filled.** Last time's weight and reps load for every exercise. The common case is that nothing needs changing.
3. **Every tap is reversible, and nothing is lost.** Each set, rest, draft and running set clock is saved as it happens, so it survives backgrounding, locking, a call or a relaunch.
4. **You don't need to unlock the phone.** The rest counts on the Lock Screen and in the Dynamic Island, and a button there starts and finishes sets.
5. **Same look as onboarding.** The app uses the same dark ember-dotted background, SF Pro Dynamic Type and Liquid Glass. White marks the primary action and red only marks the signal: the live set, a finished rest, today, a gain.

## Screens

**Home: one decision.**
- The headline is the workout (`Up next · Push` with its exercises) and the primary button is Start workout.
- The middle holds one glass card: this week as seven day dots (today in red), "2 of 5" against the onboarding goal, and the last workout. Tapping the card opens History.
- History and Settings are glass buttons at the top.
- There's no tab bar.
- Splits rotate: finishing Push makes Legs next, so the usual case is **one tap to start**. Tapping the workout name opens a chooser with Free workout, the splits and a New split option. Each split has an `…` menu to edit or delete it.

**Workout.** The layout is fixed from top to bottom:
- **Top bar:** the workout clock, which is also the **pause** control (⏸ 14:02; tap to pause, ▶ to resume), then Sets (the log) and End.
- **Exercise:** the name and a chevron, which opens the picker. Below it, set dots ("● ● ○ Set 3 of 3"): filled for done, red for the live set, outlined for the rest of the target.
- **Ring:** a Liquid Glass disc inside a ring.
  - Ready: last time's best set and its date.
  - Set: the set clock sweeps once a minute.
  - Rest: the ring fills toward the rest length, then turns red with "Rest's up" and a double haptic. The rest length ("of 1:30 ⌃⌄") is changed right there.
- **Weight and reps:** two glass steppers, always in the same place.
  - `−` and `+` step on the plate grid (2.5 kg / 5 lb), and holding repeats.
  - Tapping a value types it. While typing, the ring hides so the button stays above the keyboard; type 60 and tap Start set in one motion.
  - Dumbbell lifts read "kg each". Zero is BW (bodyweight).
- **Footnote:** "Last set 80 kg × 5 ›" (one tap to correct it), or Undo after a delete.
- **Actions:**
  - One honest caption: what's missing, or "Instagram, TikTok · blocking simulated".
  - The primary button: Start set → Finish set → (rest) → Start set.
  - Once you've done as many sets as last time, it offers `Next: Dumbbell shoulder press`, with `Another set` beneath. In a free workout it offers Next exercise; when a split is done, Finish workout.

**Summary.** The headline is "Nice work, Sirish.", then four glass tiles counting up: time, sets, weight moved, average rest.
- "Better than last time" lists only like-for-like gains in the same split: more weight for the same reps, or more reps at the same weight.
- A per-exercise recap follows. Done is the primary button; a free workout can be saved as a split.

**History, Settings, editors.** History has glass total tiles, exercise progress and the list of workouts, now with exercise names. A workout can be deleted from its detail page.

Settings is ordered by what matters mid-workout: rest length, rest alert, time each set; then blocking (simulated, labelled); then you (name, body, units, language, haptics, sound); then answers, data and account.

## Tap budget

| Task | Before (V3) | Now |
|---|---|---|
| Start a split workout | 1 (+ pick exercise in free) | **1** (next split is pre-chosen) |
| First set of a new exercise (free workout) | 6 + digits: Start workout, pick, weight sheet, Type weight, Done, Start set | **4 + digits**: Start workout, pick, weight, Start set (above the keyboard) |
| Log a set, same weight and reps | 2 | **2** (Start, Finish), or **1** with Time each set off |
| Change weight by one plate | 4 + digits | **1** (`+`) |
| Change reps | type, or `−`/`+` | **1** (`−`/`+`) |
| Next exercise in a split | 2 (chevron, pick) + weight | **1** (Next: …), weight pre-filled |
| Check the rest while the phone is locked | unlock, open | **0**: on the Lock Screen and Dynamic Island |
| Start or finish a set with the phone locked | not possible | **1**, on the Lock Screen |
| Correct the last set | 2 | **2** (Last set, edit) |
| End workout | 2 | **2** (End, confirm), with nothing to confirm if no sets |
| Pause, then resume | not possible | **1 + 1** (the clock; Resume is the main button, and on the Lock Screen) |

A split of 6 exercises × 3 sets with no changes takes 1 + 36 + 5 + 2 + 1 = **45 taps** for the whole workout. Without set timing it takes **27**. Most of those taps can be made from the Lock Screen.

## Edge cases and interruptions

| What happens | What GymBlock does |
|---|---|
| You need a break: a call, the bathroom, a chat, waiting for a machine | **Pause.** The workout clock and the running rest or set freeze where they are; the ring dims and says "Paused". Rest alerts are held, blocking is lifted (simulated, labelled), and the Lock Screen shows "Paused" with a Resume button. Resume carries on from the same second. Paused time never counts as training, rest or set time. Starting or finishing a set resumes on its own. Ending while paused ends the workout when the pause began. Paused for an hour or more: "Still working out?" offers Resume or Finish. |
| Phone locks, app is backgrounded, a call comes in | Nothing is lost. Timers are timestamps, so they show the true time on return. The Lock Screen and Dynamic Island keep counting. |
| iOS closes the app mid-set or mid-rest | On relaunch the same set clock, draft reps and rest are back. Tested by terminating mid-set. |
| Rest length passes with the phone locked | A local "Rest's up" notification (if alerts are on). The Live Activity turns red as the rest goes stale. |
| Rest length passes in the app | A double haptic, the ring turns red, "Rest's up". No banner over the app. |
| Sweaty double tap | The primary button ignores a second tap within 0.6 s, so one tap can't start and finish a set. Tested with `doubleTap()`. |
| Forgot to tap Start (Start and Finish back to back) | The set is logged; a set clock under 3 s is marked unknown, never treated as measured. |
| Forgot to tap Finish | A rep set over 15 min is logged with its duration marked unknown. |
| Left the gym with the workout running | After an hour of inactivity, a "Still training?" notification. On the next open: "Still working out? Last activity at 19:42." Finish ends the workout **at its last set**, not hours later; an open, untrustworthy set isn't saved. |
| Bench taken: change exercise mid-rest | The rest keeps counting and the other exercise loads its own last weight. |
| Change exercise mid-set | "Finish this set first?" with Save and switch, Discard and switch, or Keep going. |
| End mid-set | Save set and end, Discard set and end, or Keep going. Saved sets always stay. |
| Tapped End by accident with sets logged | Confirmation. With no sets there's nothing to lose, so it ends at once and makes no summary or history. |
| Started a set by mistake | Sets → Cancel set (the rest before it is restored). |
| Missed rep, failed set | Step reps to 0 and Finish: it's a missed attempt, not a completed set. |
| Wrong weight or reps logged | "Last set ›" opens the editor, which can also delete; Undo restores a deletion. |
| Logged a junk workout | History → workout → Delete workout (confirmed). |
| First time on an exercise | No load is invented. "Add the weight for this set." Start set focuses the weight field. `+` starts from an empty bar (20 kg / 45 lb) or a light dumbbell (10 kg / 25 lb). Bodyweight lifts (pull-up, push-up, dip…) start at BW. |
| Supersets / alternating | "This workout" heads the picker with sets done; the rest keeps counting across switches. |
| More sets than last time | "Another set" sits under Next; the target follows last time's count. |
| Skipped an exercise in a split | Next wraps back to any exercise still short of its sets. |
| Timed work (run, row, plank) | Start and Finish time it; minutes come from the clock. |
| Unit change mid-workout | Values convert; steps switch to 5 lb. |
| Long weights (102.5) | The value scales down instead of breaking the row. |
| Large text | Steppers stack and everything stays reachable. Tested at Accessibility M. |
| Lock Screen display lags the app | The button carries its intent ("start" or "finish") and stale taps are ignored, so a set is never logged twice. |

## Boundaries kept

- **Blocking:** still simulated, and labelled wherever it's shown.
- **No server:** no account, database, analytics or network. The Live Activity is updated locally with no push.
- **No billing:** the paywall and login are out of scope for this pass.
- **Progress claims:** only like for like, within the same split.
- **Demo data:** loading stays explicit and labelled ("Sample data" on Home).

## Evidence

The captures of every state are in [screenshots/app-v6](../screenshots/app-v6/) (`overview.jpg`). The attention heatmaps from Apple's saliency model are in `heatmaps/`. On the set and rest screens the hot spot is the ring's clock. On Home and the ready screen it's the workout or exercise name. The bottom third gets little predicted attention, as in onboarding; the button's fixed place is what makes it findable. Test results are in [VALIDATION.md](../VALIDATION.md).
