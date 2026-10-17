# Gym Block: US Apple Ads campaign

Written 17 Oct 2026. The target is the US. The App Store fields it depends on, the search-demand tables and the custom product pages are in [docs/listing.md](../listing.md). This doc doesn't launch or change anything in Apple Ads.

## When it can start

Apple Ads needs a live app, so nothing starts until version 1.0 (build 4, with App Review on 17 Oct) is out. Apple only shows an ad on a search it thinks the app is relevant to, and it judges that mostly from the name, subtitle and keyword field.

**Phase 1, from the day 1.0 is live.** 1.0 carries the 10 Oct fields: name `Gym Block: Stop Scrolling`, subtitle `Workout Tracker & Rest Timer`, keywords `blocker,apps,reels,shorts,scroll,no,lock,doom,social,media,phone,addiction,log,lifting,pr,set,split`. That already makes most of the keywords below relevant. Run every keyword marked "1.0".

**Phase 2, once 1.0.1 ships the 17 Oct keyword field and the extra-language fields.** Add the keywords marked "1.0.1" (doomscrolling, gym focus and the long tail). Apple doesn't say whether the extra-language keyword fields count for ad relevance as they do for search; if a keyword that only they cover gets no impressions after 48 hours at a reasonable bid, leave it to organic search.

Before the first day, check the settings that can stop delivery:
- The campaign and ad group are on and their start dates have passed. There's a valid payment method, and the campaign isn't on hold.
- The country is United States, and the ad group has no age, gender or location limits.
- The ad schedule is all day. The device is iPhone only (blocking and the Live Activity are iPhone features).
- Each keyword's status is Running, not Paused or "on hold".

## Campaign structure

Five campaigns, all US, Search Results placement, customer type New users. Separate campaigns give each theme its own budget, so the expensive tracker searches can't use up the money for the cheap ones.

| Campaign | Match | Starting max CPT | Share of budget |
| --- | --- | ---: | ---: |
| Rest timer | Exact | $1.25 | 20% |
| Workout tracker | Exact | $2.00 | 30% |
| Stop scrolling | Exact | $1.50 | 30% |
| Brand | Exact | $0.75 | 5% |
| Discovery | Broad + Search Match | $1.00 | 15% |

A suggested start is $10 a day across all five for two weeks (about $140), then move money to whatever brings trials. The bids are guesses: Apple shows a suggested bid range and a 1–5 popularity score for each keyword when you add it. Use those, and write them into the table at the end. If a relevant keyword gets no impressions after 48 hours, raise it in $0.25 steps.

Why this split: "rest timer" is the best bet, because people searching it are at the gym, the subtitle says it, and the apps ranking for it are tiny (median 79 ratings), so taps should be cheap. "Workout tracker" has the most searches but Strong, Hevy and others bid on it, so it costs more and the ad has to win against apps with 100,000 ratings. "Stop scrolling" is Gym Block's own idea; its searchers want a blocker and need the screenshots to explain why it's for the gym.

Don't bid on the same keyword in two campaigns. Add every Exact keyword from the other campaigns as an exact-match negative in Discovery, so Discovery only finds new searches.

## Keywords

"Demand" is the number of letters typed before Apple's US autocomplete suggests the phrase: fewer means more searches. A dash means it wasn't suggested even in full, and "n/c" means it wasn't checked. "Top 10" is the median ratings count of the apps that rank for it. See [docs/listing.md#search-demand](../listing.md#search-demand).

### Rest timer campaign

**Ad group: Rest timer.** Custom product page: Rest timer.

| Keyword | Demand | Top 10 | Phase |
| --- | --- | ---: | --- |
| rest timer | 6 | 79 | 1.0 |
| gym rest timer | 5 | 61 | 1.0 |
| gym timer | 5 | 4,390 | 1.0 |
| workout timer | 5 | 23,751 | 1.0; many searchers want HIIT timers, so watch the search terms |
| lock screen timer | 13 | n/c | 1.0.1 |

### Workout tracker campaign

**Ad group: Workout tracker.** Custom product page: Workout log.

| Keyword | Demand | Top 10 | Phase |
| --- | --- | ---: | --- |
| workout tracker | 4 | 98,522 | 1.0 |
| gym tracker | 3 | 98,118 | 1.0 |
| gym workout tracker | 5 | 46,914 | 1.0 |
| gym app | 6 | n/c | 1.0.1 (`app` is new) |
| lifting tracker | 5 | 17,570 | 1.0 |
| set tracker | 5 | 4,366 | 1.0 |
| pr tracker | 4 | 3,094 | 1.0 |
| weightlifting tracker | 7 | 46,914 | 1.0.1 |

**Ad group: Gym log.** Custom product page: Workout log.

| Keyword | Demand | Top 10 | Phase |
| --- | --- | ---: | --- |
| gym log | 5 | 784 | 1.0 |
| workout log | 9 | 11,949 | 1.0 |
| lifting log | 9 | 11,949 | 1.0 |
| lift log | 6 | 501 | 1.0.1 |
| gym notebook | 5 | 2,579 | 1.0.1 |
| gym log book | 6 | 2,435 | 1.0.1 |
| workout journal | 9 | 11,949 | 1.0.1 |
| workout split | 9 | 17,570 | 1.0 |

### Stop scrolling campaign

**Ad group: Stop scrolling.** Default product page.

| Keyword | Demand | Top 10 | Phase |
| --- | --- | ---: | --- |
| stop scrolling | 6 | 1,687 | 1.0 |
| doom scrolling | 4 | 51,150 | 1.0 |
| no scroll | 4 | n/c | 1.0 |
| doomscrolling | 5 | 4,797 | 1.0.1 |
| stop doomscrolling | 6 | 7 | 1.0.1 |

**Ad group: Reels & app blockers.** Custom product page: Reels blocker.

| Keyword | Demand | Top 10 | Phase |
| --- | --- | ---: | --- |
| reels blocker | 5 | 1 | 1.0 |
| shorts blocker | 6 | 84 | 1.0 |
| scroll blocker | 8 | 37 | 1.0 |
| app blocker | 5 | 11,642 | 1.0 |
| block apps | 7 | 9,236 | 1.0 |
| social media blocker | 8 | 23,715 | 1.0 |
| phone blocker | 7 | 51,806 | 1.0 |
| phone addiction | 7 | 16,314 | 1.0 |

These searchers want an all-day blocker, and Gym Block only blocks during a workout. Expect a lower install rate than the gym searches; keep the bid at the start level until the numbers say otherwise.

**Ad group: Gym + phone.** Default product page. The exact idea, with little search volume yet, so these are cheap insurance that Gym Block is first when someone does search it.

| Keyword | Demand | Top 10 | Phase |
| --- | --- | ---: | --- |
| workout blocker | 9 | 1,620 | 1.0 |
| gym focus | – | 1 | 1.0.1 |
| screen time gym | 13 | 1,557 | 1.0.1 |
| gym lock | – | 1,157 | 1.0 (from 1.0.1 through the Vietnamese field's `lock`) |
| gym blocker | – | n/c | 1.0 |

### Brand campaign

| Keyword | Notes |
| --- | --- |
| gym block | No searches yet, and today the results are block-puzzle games. Defends the name against the small GymLock apps. |
| gymblock | |

### Discovery campaign

Broad match on `rest timer`, `workout tracker`, `stop scrolling` and `app blocker`, plus a separate ad group with only Search Match on. Check the Search Terms report every 3–4 days. Move searches that bring trials into the matching Exact ad group, and add them to Discovery's negatives. Add searches that bring taps but no installs as negatives.

Phase 2 candidates to try here first, from the extra-language fields: screen time, dopamine detox, discipline, lock in, hypertrophy, push pull legs, one rep max, gym motivation.

### Competitor names (later)

Apple Ads allows bidding on other apps' names (not putting them in the listing). Leave it until after the first two weeks; these taps usually cost more and convert worse. Candidates: strong, hevy, opal, brick, one sec, screenzen, gymlock, scrolltoll.

## Negative keywords

Add these to every campaign as phrase-match negatives. Each comes from unrelated apps seen in the results:

| Negative | Why |
| --- | --- |
| puzzle, game, games, color, wood | Block-puzzle games ("gym block", "block apps") |
| hiit, tabata, boxing | Interval timers for other sports |
| running, steps, yoga, pilates, calorie, diet | Other fitness apps |
| vault, photo, hide, private | "App lock" photo vaults |
| kids, parental, child | Parental controls |
| porn | Porn blockers ("scroll block") |
| bible | Bible apps ("stop doomscrolling") |
| tally | Counter apps ("set counter") |

Don't add broad negatives like `free`, `app` or `workout`, because they cut out relevant people. Watch, but don't block yet: `pushup` and `push up` (exercise-to-unlock apps; their searchers might want Gym Block).

## Ads

Use custom product pages as ad variations so each ad group's first screenshot matches the search: Rest timer uses the Rest timer page, Workout tracker and Gym log use the Workout log page, Reels & app blockers uses the Reels blocker page, and Stop scrolling, Gym + phone and Brand use the default page. Apple shows the first three screenshots in an ad. The Workout log page can be set up as soon as 1.0 is live (it only reorders existing slides); the other two need their new first cards (see [docs/listing.md#custom-product-pages](../listing.md#custom-product-pages)). Until then those ad groups use the default page.

## Measuring and decisions

Turn on attribution first: the app has to call `Purchases.shared.attribution.enableAdServicesAttributionTokenCollection()` (not done yet, see the listing's Before submitting list) and RevenueCat's Apple Search Ads integration has to be on, so each trial and subscription is linked to its keyword. Judge keywords by trials and paid subscriptions, not installs. The offer is a wall at the end of onboarding, so an install with no trial means the person left during onboarding or at the offer; compare each keyword's install-to-trial rate with organic installs before blaming the keyword.

At $49.99 a year (with a 1-week free trial) or $4.99 a month, a yearly subscriber is worth about $35–42 after Apple's cut (30% or 15% under the Small Business Program), and a monthly one about $4 a month while they stay.

- **No impressions 48 hours after a keyword became relevant:** check relevance (search "gym block rest timer" in the App Store), then raise the bid in $0.25 steps.
- **15 taps and no installs on a keyword:** pause it and check its search terms.
- **$25 spent on a keyword with no trial:** pause it.
- **Cost per trial under $8 after a week:** raise that keyword's bid 20% and its campaign budget.
- **Wait for the trial to end**, 1 week plus three days, before judging paid conversion.

Every week, write down each keyword's popularity score, suggested bid, impressions, taps, installs, trials and paid subscriptions in the table below.

| Week | Keyword | Popularity | Suggested bid | Impr. | Taps | Installs | Trials | Paid |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| | | | | | | | | |
