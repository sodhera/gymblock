# GymBlock

A local SwiftUI workout prototype: a warm paper stage with one emerald signal, SF Pro Dynamic Type and native Liquid Glass. Open the app, tap Start, lift, tap Finish, and put the phone away — the rest counts on the Lock Screen.

## Run

Open **GymBlock.xcodeproj** and run **GymBlock** on an iPhone simulator. The app supports iOS 17+; native Liquid Glass and discrete tick configuration are available on iOS 26+. The current development environment is Xcode 27 / iOS 27.

The Debug scheme opens onboarding for a new store. Add `--demo` when needed: an empty store gets Arms, Push and Legs plus six weeks of labeled sample history. It never overwrites existing history, splits or an active workout. Leave that argument off for onboarding on a fresh install. Debug-only `--ui-reset` is for disposable test data, not a normal onboarding reset. **Settings → Training answers** edits baseline information without replaying setup or deleting workouts. Sample loading also lives in **Settings → Data** when the store is empty.


## App blocking

Real blocking through Apple's Screen Time (`AppBlocking.swift`). On the blocking page (or in Settings → Apps to block) GymBlock asks for Screen Time access, then opens Apple's app picker; apps, whole categories and websites can be chosen. From **Start workout** to **Finish** they are shielded; **pause** lifts the shield and **resume** puts it back. Opening a blocked app shows "You're mid-workout." with a **Back to training** button (`GymBlockShield`, `GymBlockShieldAction`). iOS keeps the shield if GymBlock is closed and removes it if GymBlock is deleted; a launch with no running workout clears any shield left behind.

- The choice is Screen Time's opaque tokens, saved on this iPhone only (`gymblock.blocking.selection`): GymBlock never learns the app names, so nothing about them is synced or sent to analytics (only counts). Delete account clears it. `Profile.blockedApps` is the old simulated list and is no longer shown.
- Needs the `com.apple.developer.family-controls` entitlement (app and both shield extensions). Development builds work with automatic signing; **App Store distribution needs Apple to approve the Family Controls (Distribution) request** for `com.sodhera.gymblock`, `.shield` and `.shield-action`.
- Works on a real iPhone only. In the simulator the access prompt appears but stops at the iPhone passcode, so the picker, shield and icons must be checked on a device.

## Experience

Full design, tap budget and edge cases: [docs/WORKOUT-V6-PLAN.md](docs/WORKOUT-V6-PLAN.md). Screens: [screenshots/app-v6](screenshots/app-v6/).

- **Home** keeps score: the week streak with a goal ring, a carousel of one-exercise improvement graphs that advances on its own (swipe to take over), time since your last PR, and total time training; every card opens its detail. A new log shows a labelled example until the first workout. **Start workout** opens the chooser, where the split that's up next is marked and a tap starts it (or a free workout). History and Settings sit in the native Liquid Glass navigation bar. No tab bar.
- **Workout** is one screen with one button in a fixed place: **Start set → Finish set → rest → Start set**. Last time's weight and reps are pre-filled; `−`/`+` step one plate (2.5 kg / 5 lb), or tap a value to type it. The ring times the set, then fills toward the rest length and turns emerald when rest’s up. After last time's number of sets the button offers **Next: <exercise>**. Tap the exercise name to switch; the rest keeps counting.
- **Need a break?** Tap the workout clock to **pause**: every clock freezes, rest alerts hold and blocking lifts; **Resume** (in the app or on the Lock Screen) carries on from the same second. Paused time never counts as training or rest.
- **Interrupted?** Everything is saved as it happens: locking, calls and relaunches lose nothing. The **Live Activity** shows the rest on the Lock Screen and in the Dynamic Island with a Start/Finish set button, so sets can be logged without unlocking. A workout left running for an hour asks to finish at its last set. Double taps, Start/Finish back to back, forgotten Finishes, zero-rep misses and first-time loads are all handled (see the plan).
- **Summary** leads with weight moved (or reps) as one counting number, then time, sets and average rest, lists like-for-like gains over the last same-split workout ("Stronger than last time" is the headline when there are any; "First one in the log" for the first workout), and offers Save as split for free workouts.
- **History** opens on a weekly bar chart of reps or weight moved, then exercise progress (Before/After tiles, the difference as a headline, an inline line chart, within one split or free scope; the scope defaults to the most recent workout's) and every workout, which can be corrected or deleted. Settings → **Time each set** off makes logging one tap per set.

## Onboarding

Twenty short pages, one question each: name, gender, height, weight; how often and how long you use your phone between sets; then one ring that sets phone time against training time in a typical workout ("34 of 46 minutes on your phone"), and the year in 45-minute workouts ("147 hours = 196 workouts"). Paired animated stages follow — mind-muscle connection, timed rests, memory vs log — then app blocking, rest alerts, a hold-to-commit pledge, the offer, and a last page to set up your splits (add a split, name it, pick its exercises; optional, skippable). Paper stage on every page (light, no coloured backgrounds); Liquid Glass controls; SF Pro Dynamic Type; large-title headlines; the wordmark (the open rest ring with its signal dot, also the app icon) on the welcome page; the approved arm and brain scenes. See [DESIGN.md](DESIGN.md) and [docs/ONBOARDING-V5-PLAN.md](docs/ONBOARDING-V5-PLAN.md); screens in [screenshots/redesign-2026-10-08](screenshots/redesign-2026-10-08/).

The estimate is the person's own minutes multiplied out — not measured phone use or a body-outcome prediction. Height, weight and gender stay on the device and are not used yet; the weight unit sets kg/lb for logging. The mind-muscle headline is the user-approved “Scrolling weakens your mind-muscle connection.”; scenes carry the caption "Illustrative, not a measurement.", the log pages "An example log, not your data.", examples never create workout history, and the blocking page says how it works ("Uses Apple’s Screen Time. Pausing your workout lifts it.").

The splits page ends onboarding, after the offer; there is no preview bypass (Debug builds with no product configured show a labelled **Continue without subscribing · Debug** link for simulator use). StoreKit handling exists behind explicit configuration, but no live subscription, product price or legal URL is configured, so Subscribe stays disabled with an honest caption. In Debug, launch with `--demo` to enter the app. Real purchasing requires `GymBlockPurchasesEnabled`, `GymBlockMonthlyProductID`, `GymBlockTermsURL` and `GymBlockPrivacyURL`, plus blocking checked on a real iPhone and release validation.

## Account, cloud and billing

Sign in with Apple or Google (Supabase Auth) on the account page before the offer, or from the welcome page's "I already have an account". Everything the app stores is synced to the account as it happens (`CloudSync.swift`: profile and answers, splits, every workout and set, the subscription snapshot) and comes back on any iPhone; the device copy stays the working copy, so the app works offline. First-party analytics (`Analytics.swift`) record every screen and its duration, every tap and choice, every workout, set, rest and pause with timings, purchases, sign-ins and errors into the account's own Supabase tables, never names, free text or emails. GymBlock Pro is USD 4.99/month or 49.99/year through RevenueCat and the App Store. Rest alerts are local notifications; a Live Activity shows the rest on the Lock Screen. Settings shows who is signed in, Log out (keeps the account, clears this iPhone), Delete account (server and device), and the Privacy Policy, Terms of Service and Support pages at https://www.orecci.com/gymblock/.

The schema is `supabase/migrations/20261008000100_gymblock.sql`; the dashboard steps still to do (run the SQL, enable the Apple and Google providers, create the RevenueCat app and products, the App Store subscriptions) are in `supabase/README.md`. Until they are done the app says so on its pages rather than pretending.

## Current design and proof

The native onboarding follows [docs/ONBOARDING-V5-PLAN.md](docs/ONBOARDING-V5-PLAN.md); the app after it follows [docs/WORKOUT-V6-PLAN.md](docs/WORKOUT-V6-PLAN.md). [DESIGN.md](DESIGN.md) records the implemented decisions. Runtime evidence and remaining limits are in [VALIDATION.md](VALIDATION.md). The browser motion preview is a reference, distinct from native simulator evidence.

`project.yml` is the XcodeGen source of truth. It builds the app and three extensions: **GymBlockLive** (the Live Activity), **GymBlockShield** (the screen over a blocked app) and **GymBlockShieldAction** (its Back to training button). Product → Test runs model checks and simulator journeys; the scheme runs the UI journeys on simulator clones in parallel (`xcodebuild test -parallel-testing-worker-count 4`), which brings the suite from about 24 minutes to about 7.

## Prototype boundaries

Blocking uses Apple's Screen Time (see below). The Live Activity is updated locally, with no push. Accounts, cloud sync and analytics are implemented against the real Supabase project; Apple/Google providers, the SQL schema, RevenueCat products and App Store subscriptions still have to be switched on in their dashboards (`supabase/README.md`). Records persist on the iPhone and in the account. Physical-device usability, haptic feel, audible sound levels and release delivery need separate verification.
