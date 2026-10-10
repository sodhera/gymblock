# App Store listing — Gym Block

English (U.S.) only. Drafted 10 Oct 2026. Every field is within Apple's limit, and no word repeats across the name, subtitle and keywords.

## Search fields

| Field | Text | Length |
| --- | --- | --- |
| Name | Gym Block: Stop Scrolling | 25 / 30 |
| Subtitle | Workout Tracker & Rest Timer | 28 / 30 |
| Keywords | `blocker,apps,reels,shorts,scroll,no,lock,doom,social,media,phone,addiction,log,lifting,pr,set,split` | 99 / 100 |

Searches these cover together:

- **Scrolling:** stop scrolling, no scroll, scroll blocker, doom scrolling, reels blocker, shorts blocker, social media blocker, block apps, app blocker, lock apps, phone addiction
- **Gym:** workout tracker, gym tracker, rest timer, gym timer, workout timer, gym log, workout log, lifting tracker, lifting log, PR tracker, set tracker, workout split

## Promotional text

170 characters. Not indexed for search. Can be changed without a new version.

```
Your feed stays locked from Start workout to Finish. Rest counts down on the Lock Screen, and every set is one tap, with last time already filled in.
```

## Description

```
Stop scrolling between sets.

Gym Block locks the apps that eat your rest, from the moment you tap Start workout until you tap Finish. Your rest counts down on the Lock Screen, so there's nothing to unlock and nothing to scroll. Open a locked app mid-workout and you'll see one line: "You're mid-workout."

LOCK YOUR FEED WHILE YOU TRAIN
• Choose apps, whole categories or websites with Apple's Screen Time picker
• They stay locked from Start workout to Finish, even if Gym Block is closed
• Pause for a call or a break: blocking lifts, and comes back when you resume
• Your choices stay on your iPhone. Gym Block never sees which apps you picked

A REST TIMER ON YOUR LOCK SCREEN
• Rest counts down in a Live Activity and the Dynamic Island
• Start and finish sets from the Lock Screen
• An alert tells you when rest is up

A GYM LOG THAT TAKES ONE TAP
• One button: Start set, Finish set, rest, repeat
• Last time's weight and reps are already filled in
• Step one plate at a time (2.5 kg / 5 lb) or type a number
• Everything saves as it happens: calls, locks and relaunches lose nothing

SEE IF YOU GOT STRONGER
• A summary after every workout: weight moved, time, sets and rest
• Gains compared like for like, against your last workout of the same split
• History with weekly charts, progress for every exercise and time since your last PR

SPLITS THAT ROTATE
• Push, pull, legs or any split you like, or a free workout
• Home shows the split that's up next

YOUR LOG, EVERYWHERE
• Sign in with Apple or Google, and your workouts sync to your account
• Works offline in the gym

GYM BLOCK PRO
Gym Block Pro is $4.99 per month or $49.99 per year (US prices). Payment is charged to your Apple Account when you confirm. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.

Terms of Service: https://www.orecci.com/gymblock/terms-of-service
Privacy Policy: https://www.orecci.com/gymblock/privacy-policy
```

## Screenshots

These are the captions, in order. Search results show the first three.

| # | Caption | Screen |
| --- | --- | --- |
| 1 | Stop scrolling between sets. | The "You're mid-workout." shield over a locked app |
| 2 | Your rest counts down on the Lock Screen. | Live Activity and Dynamic Island |
| 3 | One tap per set. Last time already filled in. | Workout screen |
| 4 | Stronger than last time? See it, like for like. | Summary |
| 5 | Splits that rotate: push, pull, legs, or free. | Start workout chooser |
| 6 | Every set saved as it happens, and synced. | History |

Keep the onboarding phone-time estimates ("34 of 46 minutes") out of the screenshots. They are the user's own numbers, not a measurement.

## What's New (version 1.0)

```
The first version of Gym Block. Lock your feed while you lift, rest on the Lock Screen, and log every set in one tap.
```

## In-app purchases

| Field | Monthly | Yearly |
| --- | --- | --- |
| Subscription group | Gym Block Pro | Gym Block Pro |
| Display name (30 max) | Gym Block Pro Monthly | Gym Block Pro Yearly |
| Description (45 max) | Lock your feed, rest timer and gym log | Lock your feed, rest timer and gym log |
| Price (US) | $4.99 | $49.99 |
| Product ID | as set in App Store Connect and RevenueCat | as set in App Store Connect and RevenueCat |

## App information

| Field | Value |
| --- | --- |
| Primary category | Health & Fitness |
| Secondary category | Productivity |
| Age rating | 4+ (no objectionable content; answer the questionnaire to confirm) |
| Price | Free download with an auto-renewing subscription |
| Support URL | https://www.orecci.com/gymblock/support |
| Marketing URL | https://www.orecci.com/gymblock/ |
| Privacy Policy URL | https://www.orecci.com/gymblock/privacy-policy |
| Copyright | 2026 Sodhera Intelligence Private Limited |

## App Review notes

```
Gym Block locks the apps a user chooses while a workout is running, using Apple's Screen Time API (FamilyControls with individual authorization, ManagedSettings, and a ShieldConfiguration extension).

To test blocking (it needs a physical iPhone, because Screen Time shields don't work in the simulator):
1. Sign in with Apple or Google on the account page.
2. In Settings, turn on "Block apps during workouts", allow Screen Time access, and choose one or more apps in the system picker.
3. Tap Start workout, then open a chosen app. It shows "You're mid-workout."
4. Tap the workout clock to pause: the apps unlock. Resume or Finish to see the lock return or lift.

Gym Block never learns which apps were chosen. The choice is kept on the device as opaque Screen Time tokens and is never synced or sent to analytics.

Subscriptions use StoreKit through RevenueCat. Use a sandbox account to buy.
```

## App Privacy (for the questionnaire)

This is based on what the code does today. Check it against `CloudSync.swift`, `Analytics.swift` and `Account.swift` before submitting.

| Data type | Collected | Linked to the user | Used for tracking | Purpose |
| --- | --- | --- | --- | --- |
| User ID | Yes | Yes | No | App functionality (account and sync) |
| Email address (from Apple or Google sign-in) | Yes | Yes | No | App functionality (account) |
| Fitness (workouts, sets, splits) | Yes | Yes | No | App functionality (sync) |
| Product interaction (screens, taps, timings) | Yes | Yes | No | Analytics |
| Purchase history | Yes | Yes | No | App functionality |
| Crash and error data | Yes | Yes | No | App functionality |

The chosen apps, the onboarding phone-time estimates and free text are never sent to analytics. Data does not leave our own Supabase project, and no third-party ads or tracking SDKs are used.

## Before submitting

- [ ] The RevenueCat products and App Store subscriptions are live, with no introductory offer (`supabase/README.md`).
- [ ] Four weeks after launch: drop any keyword still outside the top 50 and replace it with a search term that converted in Apple Search Ads.
