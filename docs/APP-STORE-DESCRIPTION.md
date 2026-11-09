# App Store description (9 Nov 2026, for Sulav's review)

**Status: draft, nothing changed in App Store Connect.** The promotional text can go live now on 1.0.4 (no new version needed). The description, What's New and the in-app purchase names change only with the next version.

Built from the live US descriptions of 15 apps people compare us with (GYMTIME, Unrot, PushUp Time, Cal AI, ScrollToll, one sec, Opal, Brick, Pushscroll, ScreenZen, ClearSpace, Hevy, Strong, Ladder, Liftoff). The shape follows GYMTIME, Unrot and PushUp Time: a slogan, one line on how it works, three steps, short sections, then the subscription. Every claim was checked against the code of the live build (1.0.4 (12), `840b39e`) and of `main`.

## Promotional text (123 / 170, can go live now)

Fills the three lines iPhone shows above "more" on its own, so it carries what it does, the difference and the offer.

```
Lock the apps you pick until you finish your workout. No Ignore button. New subscribers get 7 days free on the yearly plan.
```

## Description (1,857 / 4,000, next version)

```
Stop scrolling between sets.

GymBlock locks the apps you pick, like TikTok, Instagram and YouTube, until you finish your workout. No Ignore button.

Scroll one minute past the rest you need, every rest, and an 18-set workout runs 17 minutes over. Three workouts a week: 44 hours a year.

HOW IT WORKS
1. Pick the apps you scroll between sets.
2. Start your workout. They lock, even with GymBlock closed.
3. Finish your workout. They open again.

STRICT BY DEFAULT
No way past the lock until you finish. Want some slack? Turn Strict mode off and the block screen offers 1 minute, once per exercise.

REST ON YOUR LOCK SCREEN
Your rest counts down on the Lock Screen and in the Dynamic Island. Start and finish sets from the Lock Screen too, so there's nothing to unlock.

THE GYM LOG
• One button for every set, with last time's weight and reps already filled in.
• A summary after every workout: time, sets, weight lifted and what beat last time.
• Progress compared fairly: same exercise, same split, same reps or weight.
• Splits that rotate, or a free workout.
• Widgets and a Start workout button in Control Center.
• Works offline. No sign-up needed.

PRIVATE
Apple's Screen Time does the locking. We never see which apps you pick.

SUBSCRIPTION
GymBlock requires a GymBlock Pro subscription: weekly, monthly or yearly. New subscribers get 7 days free on the yearly plan. Payment is charged to your Apple Account when you confirm, or when the free trial ends. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Terms of Service: https://www.orecci.com/gymblock/terms-of-service.html
Privacy Policy: https://www.orecci.com/gymblock/privacy-policy.html
```

## What's New (next version)

Apple wants the big changes listed (guideline 2.3.12); the live note is a generic "bug fixes" line. Drop the first bullet if GymBond isn't in the build.

```
• Train with a friend: share your code and they get two weeks of GymBlock Pro, and so do you (if you already pay, yours starts when your plan ends).
• No sign-up to start. Save your progress with Apple or Google whenever you like.
• A cleaner, all-white look.
```

## Friend section (only once GymBond passes a two-account test)

Goes before SUBSCRIPTION.

```
TRAIN WITH A FRIEND
• Share your code. A friend who joins with it gets two weeks of GymBlock Pro, and so do you. If you already pay, yours starts when your plan ends.
• See each other's week, and get a notification when they finish a workout.
```

## Why the live text has to change

- Three lines are false since 11 Oct (`5f8212e`): Pause (there is no pause), "time since your last PR" (the card is gone) and rest in the summary (it shows time, sets, weight lifted and what beat last time).
- It lists $3.99 a month and $29.99 a year only. It leaves out the $0.99 weekly plan and the 7-day trial on the yearly plan, and never says Pro is required (guideline 2.3.2; the offer is a wall).
- It labels Apple's standard EULA "Terms of Service", and spells the name "Gym Block".
- No dollar prices in the new text, on purpose: Apple's product-page advice is to leave them out of the description, prices differ by country, and the page's In-App Purchases list shows them. Ours already went stale once.

## Where each claim comes from

| Claim | Code |
| --- | --- |
| Locked until you finish, no Ignore button, Strict mode on by default, 1 minute once per exercise with it off | `Shared/BlockingPass.swift`, `GymBlock/Settings.swift`, `GymBlockShield/WorkoutShield.swift` |
| No pause | `WorkoutLogic.pause()` has no callers since `5f8212e` |
| Locked with GymBlock closed; apps, categories and websites | `Shared/BlockingPass.swift`, `GymBlock/AppBlocking.swift` |
| We never see which apps you pick | `GymBlock/AppBlocking.swift` (opaque Screen Time tokens, kept on the iPhone, never synced) |
| 44 hours a year | `GymBlock/JourneyMetrics.swift` (rests = sets − 1): 17 rests × 1 min × 3 a week × 52 = 44.2 h, rounded down |
| "Start your workout" / "Finish your workout" | `GymBlock/Home.swift` (Start workout, then Let's go), `GymBlock/Workout.swift` (End, End workout); deliberately no button names |
| Rest on the Lock Screen and Dynamic Island, sets from the Lock Screen | `GymBlockLive/GymBlockLive.swift`, `GymBlock/WorkoutStepIntent.swift` |
| Last time filled in, summary, fair progress | `GymBlock/Model.swift`, `GymBlock/Summary.swift`, `GymBlock/WorkoutLogic.swift` |
| Widgets and the Control Center button | `GymBlockLive/GymBlockWidgets.swift`, `GymBlockLive/StartControl.swift` |
| Weekly, monthly, yearly; 7 days free on yearly for new subscribers | `GymBlock/Subscriptions.swift`, `GymBlock/AccountGate.swift`; the intro offer itself is set in App Store Connect |
| No sign-up needed | `main` only: the silent account (`7a25b83`) |

## Before it ships

1. "No sign-up needed" is true only in a build with the silent account. Cut it otherwise.
2. `docs/legal/terms-of-service.md` §6.1 still calls Pro "optional" at USD 4.99 / 49.99, and `docs/legal/privacy-policy.md` says "we run no push notification server", which GymBond changes. Fix and republish both before the next version.
3. In App Store Connect, confirm the yearly plan's 1-week free intro offer and the $0.99 weekly plan.
4. Rename the three in-app purchases from "Gym Block Pro" to "GymBlock Pro Weekly", "GymBlock Pro Monthly" and "GymBlock Pro Yearly", so the price list on the page explains itself.
5. If GymBond ships, explain the code-to-Pro gift in the App Review notes (guideline 3.1.1 bars apps' own unlock mechanisms).
6. The paywall's first review is signed with Sirish's name (`PaywallView.reviews` in `GymBlock/AccountGate.swift`). US rules (FTC, 2024) require a founder's review to say so: label it or drop it.

## For Sulav

- "No Ignore button" (promo and opening): keep? True with Strict mode on, the default; with it off, the block screen offers a minute per exercise, which the description says.
- The 44-hour line: keep? It's an example, labelled by its "if", rounded down.
- Cut anything that doesn't earn its place.
