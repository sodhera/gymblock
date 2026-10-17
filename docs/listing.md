# App Store listing — Gym Block

Drafted 10 Oct 2026; search fields reworked 17 Oct 2026 from Apple's own autocomplete and the apps that rank for each search (see [Search demand](#search-demand)). Every field is within Apple's limit (name 30, subtitle 30, keywords 100, promotional text 170), and no word repeats across the name, subtitle and keywords. Apple combines words from the name, subtitle and keywords of the same language into search phrases, so a word only needs to appear once. The Apple Ads plan that uses these fields is [docs/strategy/apple-ads-us-campaign.md](strategy/apple-ads-us-campaign.md).

**What's live (17 Oct 2026).** Nothing: version 1.0 (build 4) is with App Review, carrying the 10 Oct fields. Name and keyword changes only go live with a new version, and App Store Connect locks them while a version is in review. If build 4 is approved, ship the new keyword field with 1.0.1; if it's rejected, change the field before resubmitting. The name and subtitle don't change.

## Search fields

| Field | Text | Length |
| --- | --- | --- |
| Name | Gym Block: Stop Scrolling | 25 / 30 |
| Subtitle | Workout Tracker & Rest Timer | 28 / 30 |
| Keywords | `blocker,app,reels,shorts,scroll,doomscrolling,doom,no,social,media,phone,focus,log,lifting,pr,set` | 97 / 100 |

The 10 Oct keyword field was `blocker,apps,reels,shorts,scroll,no,lock,doom,social,media,phone,addiction,log,lifting,pr,set,split` (99).

Searches these cover together:

- **Scrolling:** stop scrolling, no scroll, doom scrolling, doomscrolling, stop doomscrolling, scroll blocker, reels blocker, shorts blocker, social media blocker, phone blocker, app blocker, app block, block app, gym focus
- **Gym:** workout tracker, gym tracker, gym app, gym workout tracker, rest timer, gym rest timer, gym timer, workout timer, gym log, workout log, lifting tracker, lifting log, PR tracker, set tracker

**Why the name and subtitle stay.** The name carries "stop scrolling", the reason to pick Gym Block over a plain tracker, and a search a new app can win: four of its top 10 apps have 3 ratings or fewer. The subtitle carries the gym side. "Workout tracker" and "gym tracker" are the biggest searches here (Apple suggests them after 3–4 letters), but Strong and Hevy hold them with about 100,000 ratings each, so they're for Apple Ads, not organic rank, for months. "Rest timer" and "gym rest timer" are the gym searches a new app can win: Apple suggests "rest timer" after 6 letters, and the apps ranking for it have a median of 79 ratings. Putting "Workout Tracker" in the name instead was considered and rejected: it can't rank there yet and would hide the hook.

**What changed in the keyword field, and why.**
- Added `doomscrolling` (one word is a different search from "doom scrolling": suggested after 5 letters, and "stop doomscrolling" after 6, where the top 10 has a median of 7 ratings).
- Added `focus` for "gym focus": the exact intent. It has no autocomplete demand yet, but every app ranking for it (GymLock, GymMonk, Lockr: Gym Focus) has 0–1 ratings. It also pairs with `app` for "focus app".
- `apps` → `app`. "App blocker" (suggested after 5 letters, 1st) and "gym app" (6 letters, 1st) are bigger than "block apps" (7). Apple doesn't promise to match plurals, so search "gym block apps" a week after release; if Gym Block isn't there, move `apps` back in place of `no`.
- Dropped `lock`: "lock apps" and "app lock" results are photo-vault apps, and "lock in" results are self-improvement apps.
- Dropped `addiction` for room; "phone addiction" moves to the Arabic field below. Dropped `split`: "workout split" is suggested only after 9 letters; it moves to the Korean field.

Checked and left out of this field: "rep counter" (suggested after 5 letters, but many of its results count reps with the camera; it's tested in the Chinese (Simplified) field below), "habit tracker" and "weight tracker" (other intents), "workout planner" and "strength training" (median top-10 above 60,000 ratings), and app names such as Instagram, TikTok or YouTube, which Apple rejects in keywords even though "instagram blocker" is searched.

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
Gym Block Pro is $4.99 per month or $49.99 per year (US prices). The yearly plan starts with a 1-week free trial for new subscribers. Payment is charged to your Apple Account when you confirm. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel anytime in your Apple Account settings.

Terms of Service: https://www.orecci.com/gymblock/terms-of-service
Privacy Policy: https://www.orecci.com/gymblock/privacy-policy
```

## Screenshots

Captions chosen 11 Oct 2026 after a look at Hevy, Strong, Fitbod, RepCount, Setgraph, Opal, ScreenZen, one sec, Brick and others: a verb-led headline with a short second line, one word in red. Search results show the first three. Recaptured 12 Oct 2026 after the workout, Home, Profile and DM Sans redesign: recaptured again 13 Oct 2026 after the tab bar and Home changes: captures are 1320×2868 (iPhone 17 Pro Max, iOS 26.5) in `screenshots/store-2026-10-13/`; the framed versions (deep blue stage, white headline with one red word, a thick phone running off the bottom edge) are in `screenshots/store-final/6.9/` (1320×2868) and `screenshots/store-final/6.3/` (1206×2622), made by `python3 scripts/frame-store-screenshots.py`.

| # | Headline | Second line | Screen |
|---|---|---|---|
| 1 | Stop **scrolling** in the gym | Block apps | The blocking page with six locked apps (`-storeShots YES -journeyStep blocking`) |
| 2 | Track your **workouts** | Time your rests | Arms mid-rest after set 1 (`-workoutStage rest -storeShots YES`) |
| 3 | Plan your **progress** | Stay motivated | Home: 6 week streak, Squat +20 kg, Up next Legs (after the workout below) |
| 4 | Beat your **record** | | Squat before/after, +20 kg (Home → Up next → Legs → tap the chart) |
| 5 | Keep your **streak** alive | | Profile: October's training dots and blocked apps |

Slides 3–5 come from one seeded run on a fresh install: `-workoutStage next -storeShots YES`, End → End workout → Done → Home (3) → tap the chart (4) → Profile tab (5). The status bar is `simctl status_bar … --time 09:41 --batteryState discharging --batteryLevel 100`. The rebuilt shield over Instagram (`-shieldPreview Instagram`) and the workout summary were tried for slides 1 and 5 on 12 Oct and rejected. The sample history's weeks start on Monday, so on a Monday only the day's own workout fills this week's dot.

Keep the onboarding phone-time estimates ("34 of 46 minutes") out of the screenshots. They are the user's own numbers, not a measurement.

## Custom product pages

A custom product page is another version of the App Store page with its own screenshots and promotional text; the name, subtitle and icon stay the same. Apple shows a page in search results for the keywords assigned to it (each keyword from the keyword field, each on one page only), and Apple Ads ad groups can use a page as their ad. Searches made only of name and subtitle words, such as "stop scrolling", "workout tracker" and "rest timer", can't be assigned and always get the default page. That's why the default page leads with blocking and keeps the workout in slide 2.

Four pages (the default plus three) is enough for a new app: more would split a small amount of traffic too thinly to learn which pages work. Set them up once the 17 Oct keyword field is live. Pages are reviewed separately from builds. Compare each page's conversion with the default page in App Analytics after 2–3 weeks.

| Page | Assign these keywords | Apple Ads ad groups | Promotional text |
| --- | --- | --- | --- |
| Default | none: gets every search not assigned elsewhere | Stop scrolling, Gym + phone, Brand | The listing's promotional text |
| Workout log | `log`, `lifting`, `pr`, `set` | Workout tracker, Gym log | `Every set is one tap, with last time's weight and reps already filled in. Rest counts down on the Lock Screen, and your feed stays locked until Finish.` (151) |
| Reels blocker | `reels`, `shorts`, `scroll`, `doomscrolling`, `doom`, `no`, `social`, `media`, `phone`, `blocker` | Reels & app blockers | `Reels and shorts stay locked from Start workout to Finish, even with Gym Block closed. Pause for a call and they unlock; resume and they lock again.` (148) |
| Rest timer | none (its words are in the subtitle) | Rest timer | `Rest counts down on your Lock Screen and in the Dynamic Island, so there's nothing to unlock between sets. An alert tells you when rest is up.` (142) |

`app` and `focus` stay on the default page, because they also make "gym app" and "gym focus".

Each page reuses the five framed slides from [Screenshots](#screenshots) (made by `scripts/frame-store-screenshots.py`) in a new order, plus two new cards. Only the first three slides show in search results and ads, so they must tell the story on their own.

| Page | Upload order |
| --- | --- |
| Workout log | Track your **workouts** · Beat your **record** · Plan your **progress** · Stop **scrolling** in the gym · Keep your **streak** alive |
| Reels blocker | *(new)* Block **reels** between sets / Shorts and feeds too (the blocking capture, `1-blocking-apps.png`) · Track your **workouts** · Beat your **record** · Plan your **progress** · Keep your **streak** alive |
| Rest timer | *(new)* **Rest** on your Lock Screen / No unlocking, no scrolling (a new capture: the rest Live Activity on the simulator's Lock Screen) · Track your **workouts** · Stop **scrolling** in the gym · Beat your **record** · Keep your **streak** alive |

The two new cards aren't made yet. The rest card needs a real Lock Screen capture with the Live Activity running (`-workoutStage rest`, then lock the simulator); it must be a capture, not a mock-up.

## US keywords from other languages

The US App Store also searches the listings in nine other languages: Spanish (Mexico), French, Portuguese (Brazil), Korean, Chinese (Simplified), Chinese (Traditional), Russian, Arabic and Vietnamese. Each adds another 100-character keyword field, and the words don't have to be in that language. Gym Block is English only, so add these nine localizations in App Store Connect with the English name, subtitle, description, promotional text and screenshots, and an English keyword field from the table below. People in those countries see the same English page they see today; only the hidden keyword field differs.

Rules:
- **Apple doesn't combine words across languages.** Each field combines only with its own localization's name and subtitle (the same English words: gym, block, stop, scrolling, workout, tracker, rest, timer), so a word from the U.S. field must be repeated when a phrase here needs it, as `blocker` is in the Chinese (Traditional) and Russian fields.
- **A small risk.** Apple doesn't require a localization's text to be in its language, and many apps use these fields this way, but a reviewer can query it. If one does, remove the extra localizations; nothing else depends on them.
- No app names (Instagram, TikTok, YouTube, Hevy, Strong, Opal) in any field.
- These are long-tail searches. They're cheap to add, but the U.S. fields matter far more. Search "gym block" with a phrase from each field about a week after release (for example "gym block hypertrophy") to check it's picked up.

| Language | Theme | Keywords | Example searches (autocomplete letters) |
| --- | --- | --- | --- |
| Spanish (Mexico) | Lock Screen timer | `lock,screen,live,activity,dynamic,island,widget,countdown,interval,stopwatch,alert,between,sets` (95) | lock screen timer (13), countdown timer (6), stopwatch (4), interval timer (3), rest between sets |
| French | Log book | `lift,log,logbook,notebook,journal,book,exercise,training,weightlifting,weight,strength,lifting` (94) | lift log (6), gym notebook (5), gym log book (6), workout journal (9), exercise log (5), weightlifting tracker (7) |
| Portuguese (Brazil) | Records and progress | `pr,personal,record,progress,progressive,overload,one,rep,max,gains,stronger,strength,lift` (89) | progress tracker (4), gym progress (6), one rep max (6), progressive overload (13), PR tracker (4) |
| Korean | Splits | `split,push,pull,legs,ppl,upper,lower,body,routine,planner,plan,program,bodybuilding,hypertrophy` (95) | push pull legs (6), PPL (2), gym planner (5), gym routine (5), workout routine (9), hypertrophy (6), bodybuilding (5) |
| Chinese (Simplified) | Sets and reps | `rep,counter,set,sets,reps,count,superset,dumbbell,barbell,powerlifting,squat,bench,press` (88) | rep counter (5), set counter (5), superset (6), powerlifting (6), bench press (7), dumbbell (5) |
| Chinese (Traditional) | Feeds | `feed,blocker,brainrot,brain,rot,attention,span,swipe,scroller,endless,infinite,short,video,content` (98) | feed blocker (6), brainrot (3), brain rot (7), attention span (6) |
| Russian | Screen Time | `screen,time,limit,limiter,control,usage,app,apps,blocker,lock,limits,distracting,restrict,manager` (97) | screen time (4), limit screen time (4), screen time control (4), app limit (5), block apps (7) |
| Arabic | Phone habits | `phone,addiction,detox,dopamine,digital,distraction,blocker,habit,quit,social,media,free,mindful` (95) | dopamine detox (4), detox (4), digital detox (9), phone addiction (7), distraction blocker (5), quit social media (7) |
| Vietnamese | Discipline | `discipline,motivation,self,control,lock,in,locked,grind,consistency,streak,habit,accountability` (95) | discipline (5), lock in (4), gym motivation (5), workout motivation (9), self control (6), gym streak (5) |

Some of these are tests with a different intent behind them: "screen time" and "dopamine detox" searchers want all-day blockers, "rep counter" searchers often want camera counting, and "interval timer" searchers often want HIIT timers. If a field brings installs that don't start a trial (App Analytics → Sources → App Store Search can't split by field, so judge by the Apple Ads search terms), swap it for more phrases from a field that converts.

## Search demand

Checked 17 Oct 2026 with Apple's US App Store autocomplete, the only free source of Apple's own search data: it ranks suggestions by how often people search them. "Letters" is the shortest prefix that makes the phrase appear, "Pos" its position there; fewer letters and a higher position mean more searches, and a dash means it never appeared. "Top 10" is the ratings count of the apps ranking for it in Apple's public search API (close to, not identical to, App Store search): the median, and how many of the ten have under 1,000 ratings. A new app can rank where the median is low.

To rerun: `python3 scripts/aso_autocomplete.py "rest timer" "app blocker"` and `python3 scripts/aso_competition.py -v "rest timer"`.

**Gym**

| Search | Letters | Pos | Top 10 median | Under 1k | Covered by |
| --- | ---: | ---: | ---: | ---: | --- |
| gym tracker | 3 | 8 | 98,118 | 1 | name + subtitle |
| workout tracker | 4 | 8 | 98,522 | 1 | subtitle |
| pr tracker | 4 | 5 | 3,094 | 5 | keywords |
| gym workout tracker | 5 | 4 | 46,914 | 0 | name + subtitle |
| lifting tracker | 5 | 1 | 17,570 | 2 | keywords |
| set tracker | 5 | 1 | 4,366 | 3 | keywords |
| gym log | 5 | 2 | 784 | 6 | keywords |
| gym timer | 5 | 2 | 4,390 | 3 | name + subtitle |
| gym rest timer | 5 | 7 | 61 | 7 | name + subtitle |
| workout timer | 5 | 6 | 23,751 | 1 | subtitle |
| gym app | 6 | 1 | n/c | n/c | name + keywords |
| rest timer | 6 | 2 | 79 | 6 | subtitle |
| lift log | 6 | 1 | 501 | 6 | French |
| workout log | 9 | 1 | 11,949 | 3 | subtitle + keywords |
| lifting log | 9 | 3 | 11,949 | 2 | keywords |
| workout split | 9 | 9 | 17,570 | 1 | Korean |
| workout planner | 4 | 10 | 146,321 | 0 | not used |
| strength training | 5 | 2 | 61,876 | 0 | not used |
| rep counter | 5 | 2 | 37 | 7 | Chinese (Simplified) |

**Scrolling and blocking**

| Search | Letters | Pos | Top 10 median | Under 1k | Covered by |
| --- | ---: | ---: | ---: | ---: | --- |
| screen time | 4 | 9 | 23,715 | 2 | Russian |
| doom scrolling | 4 | 4 | 51,150 | 3 | name + keywords |
| no scroll | 4 | 2 | n/c | n/c | name + keywords |
| dopamine detox | 4 | 8 | 1,863 | 5 | Arabic |
| app blocker | 5 | 1 | 11,642 | 2 | keywords |
| app block | 5 | 2 | 23,715 | 0 | name + keywords |
| doomscrolling | 5 | 3 | 4,797 | 5 | keywords |
| reels blocker | 5 | 5 | 1 | 9 | keywords |
| stop scrolling | 6 | 5 | 1,687 | 5 | name |
| stop doomscrolling | 6 | 3 | 7 | 7 | name + keywords |
| shorts blocker | 6 | 7 | 84 | 8 | keywords |
| block apps | 7 | 2 | 9,236 | 3 | name + Russian |
| phone blocker | 7 | 1 | 51,806 | 2 | keywords |
| phone addiction | 7 | 5 | 16,314 | 2 | Arabic |
| scroll blocker | 8 | 2 | 37 | 8 | keywords |
| social media blocker | 8 | 2 | 23,715 | 2 | keywords |
| workout blocker | 9 | 5 | 1,620 | 4 | subtitle + keywords |
| screen time gym | 13 | 2 | 1,557 | 5 | Russian |
| gym focus | – | – | 1 | 8 | name + keywords |
| gym lock, gym blocker, gym block | – | – | – | – | no demand yet |

**Direct competitors.** Several small apps already lock apps for the gym, all with 0–1 US ratings: GymLock: Screen Time Focus, GymLock: Workout Tracker, GymMonk, Lockr: Gym Focus, LockLift and Gym Detox App Lock. Exercise-to-unlock apps are bigger: ScrollToll (544 ratings), PushUpLock (1,178) and Pushscroll. The trackers (Strong 108,535, Hevy 98,522, Fitbod 287,607) and the blockers (Opal 89,933, Brick 57,538, ScreenZen 51,806, one sec 23,715) don't combine the two. Ratings are what moves a new app up most of these searches, so ask for them (see [Before submitting](#before-submitting)).

Free tools' "popularity" scores aren't Apple's numbers. The only real ones (1–5) are in Apple Ads, under Add Keywords in a US campaign; write them into the Apple Ads plan when you first add the keywords.

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
| Fitness (workouts, sets, splits; onboarding answers such as phone time per rest, height and weight in 5-unit bands) | Yes | Yes | No | App functionality (sync), Analytics |
| Product interaction (screens, taps, timings) | Yes | Yes | No | Analytics |
| Purchase history | Yes | Yes | No | App functionality |
| Crash and error data | Yes | Yes | No | App functionality |

The chosen apps, names and free text are never sent to analytics. Since 11 Oct 2026 onboarding answers are (gender, height and weight in 5-unit bands, phone time per rest and the resulting estimate), so declare gender under Other Data if Apple asks. Data does not leave our own Supabase project, and no third-party ads or tracking SDKs are used.

## Before submitting

- [ ] The RevenueCat products and App Store subscriptions are live (yearly with its 1-week free trial, `supabase/README.md`).
- [ ] **Ratings.** The app never asks for one. Add `AppStore.requestReview` after a clear win, such as the summary of the third finished workout or a new record. In these searches ratings count is what separates the top 3 from the rest.
- [ ] **Apple Ads attribution.** Call `Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()` after `Purchases.configure` (`Subscriptions.swift`) and turn on RevenueCat's Apple Search Ads integration, so each trial and subscription is tied to its keyword. Not done yet. Check the App Privacy answers after (Apple's AdServices token isn't tracking and needs no ATT prompt).
- [ ] **EU.** The Digital Services Act trader status is Rejected, so the 27 EU countries are blocked until it's fixed under Business.
- [ ] Four weeks after launch: drop any keyword still outside the top 50 and replace it with a search term that converted in Apple Search Ads.
