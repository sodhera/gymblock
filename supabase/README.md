# GymBlock cloud: Supabase, RevenueCat, App Store

Everything the app needs from the dashboards, in the order to do it, with what is already done.

| Step | State (last updated 10 Oct 2026) |
| --- | --- |
| 1. Schema | **Done** (run in the SQL editor; 7 tables, 3 views, `gb_delete_account`). Since 8 Nov 2026 the CLI is linked and later migrations go with `supabase db push`: GymBond (`20261108000100`), `gb_notify` (`…0200`), and `gb_register_device` / `gb_set_push_token` (`…0300`, which fixed device rows never landing: the app had no read right on `gb_devices`, which an upsert needs). |
| 2. Apple provider | **Done** (enabled, client id `com.sodhera.gymblock`). Apple Developer capability: pending until the App ID exists. |
| 3. Google provider | **Done**: Google Cloud project `gymblock` (org sodhera.com, account authuser=2), consent screen "GymBlock" (External, admin@sodhera.com), web client "GymBlock Supabase" with the Supabase callback; ID and secret saved in Supabase → Google. |
| 3b. Redirect URL | **Done** (`gymblock://auth/callback`). |
| 4. RevenueCat | **Done**: project GymBlock (65ed1e99), App Store app `com.sodhera.gymblock` with valid In-App Purchase key (34ZCA5L925) and App Store Connect API key (ZH27RWPG5Q), issuer `5f9e6892-8b98-4334-97fb-1c6ca8ad9229`; entitlement `pro`; offering `default` (`$rc_annual`, `$rc_monthly`, and since 28 Oct `$rc_weekly` → `com.sodhera.gymblock.pro.weekly`); paywall "GymBlock Pro" (`wfb627051e8de44707`, built in the dashboard 28 Oct, connected to `default`, published 28 Oct). Since 10 Oct every build (Debug too) uses the App Store app's `appl_` key in `Secrets.xcconfig`; the Test Store is no longer used, and Debug purchases go through Apple's sandbox (Sandbox Apple Account on the device). Verified on the simulator: the offer loads the real products ($49.99 yearly with the 1-week trial, $4.99 monthly). |
| 5. App Store Connect | **Done except submission** (10 Oct): app "Gym Block" (Apple ID 6821339641, SKU `gymblock`, bundle `com.sodhera.gymblock`); subscription group "Gym Block Pro" (22461908) with `com.sodhera.gymblock.pro.yearly` (1 year, $49.99, 1-week free trial, Apple ID 6821340362) and `com.sodhera.gymblock.pro.monthly` (1 month, $4.99); all countries, App Store only, no multiseat; display name "Gym Block Pro"; review screenshot `screenshots/app-store-review/subscription-review-paywall.png`. The first subscriptions go to review with version 1.0 (tick them on the version page) — not "Add for Review" on their own. Paid Apps agreement, bank and tax are active; the EU Digital Services Act status is **Rejected**, so the EU is blocked until it's fixed under Business. |

Until a step is done the app degrades honestly (sign-in reports the provider error, the offer page
says subscriptions are off and shows the Debug-only skip, analytics inserts fail quietly and retry).

Project: https://supabase.com/dashboard/project/tlcmpgxuyngsbjuhring (shared with premiumaccess;
GymBlock's tables are prefixed `gb_`). Client values live in `GymBlock/AppConfig.swift`.

## 1. Schema (5 minutes)

SQL Editor → New query → paste `supabase/migrations/20261008000100_gymblock.sql` → Run.
It is repeat-safe. Or, with the CLI logged in to the account that owns the project:

```bash
supabase link --project-ref tlcmpgxuyngsbjuhring
supabase db push
```

Check: Table Editor shows `gb_profiles`, `gb_splits`, `gb_workouts`, `gb_sets`, `gb_devices`,
`gb_subscriptions`, `gb_events`; Database → Functions shows `gb_delete_account`.

## 2. Sign in with Apple

Authentication → Providers → Apple → enable.
- Client IDs: `com.sodhera.gymblock` (the app's bundle id; native sign-in sends an id token, so
  no Services ID or secret key is needed for iOS).
- Save.

Apple Developer → Identifiers → App IDs → `com.sodhera.gymblock` (team 6LYZDNCM4M, created by
Xcode automatic signing on first device build) → enable the *Sign In with Apple* capability.

## 3. Sign in with Google

Google Cloud Console (the sodhera.com account, project `gymblock`) → Google Auth Platform → Clients →
"GymBlock Supabase" (*Web application*):
- Authorized redirect URI: `https://tlcmpgxuyngsbjuhring.supabase.co/auth/v1/callback`
- The client secret is shown only once, at creation; it lives in Supabase now. To rotate it, create a
  new secret on the client and paste it into Supabase → Authentication → Google.
- Branding carries the orecci.com home, privacy and terms links; authorized domains are the Supabase
  host and orecci.com. Audience is published to production (basic email/profile scopes need no
  verification), so any Google account can sign in.

Supabase → Authentication → Providers → Google → enable → paste client ID and secret → Save.
Authentication → URL Configuration → Redirect URLs → add `gymblock://auth/callback`.

## 4. RevenueCat

https://app.revenuecat.com → the Sodhera project (or a new "GymBlock" project):
1. Apps → + New → App Store → name GymBlock, bundle id `com.sodhera.gymblock`, paste the
   App Store Connect *In-App Purchase Key* (App Store Connect → Users and Access → Integrations →
   In-App Purchase) and the app's shared secret.
2. Products → + New: `com.sodhera.gymblock.pro.monthly` and `com.sodhera.gymblock.pro.yearly`.
3. Entitlements → + New: identifier `pro`, attach both products.
4. Offerings → `default` → packages: `$rc_monthly` → monthly product, `$rc_annual` → yearly product.
5. Weekly plan (optional): add `com.sodhera.gymblock.pro.weekly` here, attach it to `pro`, and add a
   `$rc_weekly` package to `default`. Only the dashboard paywall (below) shows it; the app's own
   page shows monthly and yearly.
6. Paywalls → + New → attach it to the `default` offering. From then on the app shows this paywall
   instead of its own page, with no release: words, layout, colours and which packages appear are
   changed here. Keep it a wall (no close button) with a "Sign out" button in the footer row whose action is the
   deep link `gymblock://paywall/sign-out` (the app catches it in `RemotePaywall`), and include Restore, Terms (`https://www.orecci.com/gymblock/terms-of-service.html`) and
   Privacy (`https://www.orecci.com/gymblock/privacy-policy.html`) links (App Review 3.1.2). Custom
   variables the app passes, to define under the paywall's variables with fallbacks: `phone_minutes`
   (only when their phone runs past their rest), `workout_minutes`, `gym_minutes`; use them as
   `{{ custom.workout_minutes }}`. The headline is fixed text, "Get your time back.". Deleting the
   paywall or detaching it brings the app's own page back.
7. Apps → GymBlock → copy the *Public app-specific API key* (`appl_…`) into `Secrets.xcconfig`:
   `REVENUECAT_API_KEY = appl_…` — then rebuild. The key is public; commit it. Debug and Release use
   the same key; Debug purchases are sandbox purchases (Settings → Developer → Sandbox Apple Account).

## 5. App Store Connect

1. My Apps → + → iOS app → GymBlock, bundle id `com.sodhera.gymblock`, SKU `gymblock`.
2. Subscriptions → Subscription group "Gym Block Pro":
   - `com.sodhera.gymblock.pro.monthly` — 1 month — USD 4.99 (tier equivalent elsewhere)
   - `com.sodhera.gymblock.pro.yearly` — 1 year — USD 49.99, introductory offer: free, 1 week
   - Optional: `com.sodhera.gymblock.pro.weekly` — 1 week. A new product goes to review with an app
     version the first time. Prices are changed under each product's Subscription Prices, with no
     review and no app change (the app reads every price from the store).
   - Purchase options: App Store only, no multiseat (it's a personal, account-bound subscription).
   - Review screenshot: `screenshots/app-store-review/subscription-review-paywall.png`.
   - Localised name "GymBlock Pro", description "Blocks the apps you choose while you train, times
     every rest and keeps your like-for-like progress."
3. App Privacy → Privacy Policy URL `https://www.orecci.com/gymblock/privacy-policy.html`.
4. App Information → EULA: Apple standard; Support URL `https://www.orecci.com/gymblock/support.html`.

## What the app does with it

| Area | Code | Table / service |
| --- | --- | --- |
| Account | `GymBlock/Account.swift` | Supabase Auth (Apple id token, Google OAuth via `gymblock://auth/callback`) |
| Sync | `GymBlock/CloudSync.swift` | `gb_profiles`, `gb_splits`, `gb_workouts`, `gb_sets`, `gb_subscriptions` |
| Analytics | `GymBlock/Analytics.swift` | `gb_events` (every screen, tap, choice, set, purchase, error), `gb_devices` |
| Subscription | `GymBlock/Subscriptions.swift` | RevenueCat entitlement `pro` |
| Delete account | Settings → Delete account | `gb_delete_account()` then local wipe |

Reporting views for the dashboard (service role only): `gb_daily_actives`, `gb_onboarding_funnel`,
`gb_workout_stats`, and from `20261011000100_onboarding_funnel.sql` (run in the SQL editor on
11 Oct 2026) `gb_onboarding_dwell`, `gb_onboarding_answers`, `gb_onboarding_summary`.

### Onboarding events

Besides a `screen` / `screen_left` pair per page (with `step` and the time it was open) and a `tap`
per button, onboarding sends:

| Event | When | Properties |
| --- | --- | --- |
| `onboarding_started` | Get started, once per install | |
| `onboarding_step` | every page change | `from`, `to`, `direction` (forward/back), `index`, `total`, `dwell_ms` |
| `onboarding_answer` | Continue on a question | `question` plus `value` (gender, scrolling), `minutes_per_rest`, `cm_band` / `kg_band` (5-unit bands) with `unit`, `answered` (name; never the name itself), or the estimate (`phone_minutes`, `training_minutes`, `yearly_phone_hours`) on the reveal and days pages |
| `onboarding_blocking` | Turn on blocking / Not now | `choice`, app/category/site counts or `chosen` |
| `onboarding_alerts` | Turn on rest alerts / Not now | `choice`, `granted` |
| `onboarding_committed` | the hold completes | `hold_ms` |
| `onboarding_completed` | into the app from splits | `splits`, `splits_skipped`, `blocking`, `rest_alerts`, `subscribed`, `signed_in`, `pages`, `total_ms` |

Sign-in (`sign_in_started`, `sign_in`, `sign_in_cancelled`), the offer (`paywall_loaded`, `plan.*` taps,
`purchase_*`) and Screen Time (`blocking_access`, `blocking_chosen`) have their own events. Events from
Debug builds run with `--online` carry `debug: true`. Useful queries:

```sql
-- Where people drop off in onboarding
select screen, count(distinct install_id) from gb_events where name = 'screen' and screen like 'onboarding.%' group by 1 order by 2 desc;
-- Rest discipline: median gap before a set, per week
select date_trunc('week', logged_at) as week, percentile_cont(0.5) within group (order by gap_before_seconds) from gb_sets where gap_before_seconds is not null group by 1 order by 1;
-- Purchases
select name, count(*) from gb_events where name like 'purchase_%' or name in ('entitled', 'restore') group by 1;
```

## 5b. Anonymous sign-ins (8 November 2026): the silent account

Authentication → Sign In / Providers → User Signups → **Allow anonymous sign-ins** → on. The commit
page makes one for every new user (`Account.signInAnonymously`); "Save your progress" after the
price links Apple or Google onto it. Optional: Authentication → Rate Limits → anonymous sign-ins
(the default, 30 an hour per IP, is fine). **Not done yet.**

## 6. GymBond (8 November 2026): friends, the two-week gift, pushes

Everything the feature needs is in `supabase/migrations/20261108000100_gymbond.sql` (the tables,
the functions the app calls, the gift through RevenueCat, the hourly cron, the push trigger) and
`supabase/functions/gymbond-push/` (the APNs sender). The app works without any of this being set up:
the section on Profile asks the server, gets nothing, and shows the invite card. Design and copy:
`docs/GYMBOND-PLAN.md`. **State (8 Nov 2026): steps 1 to 6 done** (the migrations and the function from this Mac, with the CLI linked to the project and the three earlier migrations recorded as applied in its history; the APNs key, the RevenueCat key and the three Vault entries by the user in the dashboards); 7 (the two-account test) and 8 (the privacy policy) still to do.

1. **Extensions.** Done by the migration's `create extension if not exists` lines (`http` in schema `extensions`, `pg_net`, `pg_cron`).
2. **Migration.** Done 8 Nov 2026 (`supabase db push`, applied without error). Checked from here: the five
   `gb_bond_*` tables exist and `gb_devices` has `apns_token`. Still worth a look in the dashboard:
   Database → Functions shows the `gb_bond_*` functions, Integrations → Cron shows `gymbond-hourly`.
3. **RevenueCat secret key** (the gift). RevenueCat → project GymBlock → API keys → a *secret* key
   (v1, `sk_…`) with permission to grant promotional entitlements. Supabase → Integrations → Vault →
   Add secret: name `revenuecat_secret_key`, the key. Until it's there, bonds form and `gb_bond_grants`
   rows wait with `last_error = 'no revenuecat_secret_key in the Vault'`; the hourly run grants them
   once it is.
4. **APNs key** (the pushes). Apple Developer → Keys → new key with *Apple Push Notifications service*
   → download the `.p8` (Key ID on the page; Team ID `6LYZDNCM4M`). Apple Developer → Identifiers →
   `com.sodhera.gymblock` → Push Notifications on (Xcode's automatic signing adds it on the next device
   build, since the entitlement is now in `GymBlock.entitlements`).
5. **Edge Function.** Deployed 8 Nov 2026 (`gymbond-push`, version 1, ACTIVE; JWT verification off; it answers 403 to any call without the shared secret, checked). Secrets set 8 Nov 2026 from this Mac (APNs key GSFT458HU5, Sandbox & Production, team scoped; the shared secret generated with `openssl rand -hex 32` and kept in `~/Downloads/gymbond_push_key.txt` for the Vault step). With the CLI linked to the project:
   ```bash
   supabase secrets set APNS_TEAM_ID=6LYZDNCM4M APNS_KEY_ID=<key id> APNS_TOPIC=com.sodhera.gymblock GYMBOND_PUSH_KEY=<a long random string>
   supabase secrets set APNS_PRIVATE_KEY="$(cat AuthKey_<key id>.p8)"
   supabase functions deploy gymbond-push --no-verify-jwt
   ```
   (`--no-verify-jwt` because the database calls it with its own shared secret, not a user's token;
   the function refuses anything without that secret.)
6. **Vault, for the trigger.** Two more secrets: `gymbond_push_url` =
   `https://tlcmpgxuyngsbjuhring.supabase.co/functions/v1/gymbond-push` and `gymbond_push_key` = the
   same string as `GYMBOND_PUSH_KEY`. Until both exist, rows wait in `gb_bond_notifications`
   (`sent_at` null); calling the function with no body sends them all.
7. **Check.** `select * from gb_bond_summary;` (service role). Two sandbox accounts: share a code from
   one, join from the other at onboarding's code page; the joiner's Pro should appear within a minute
   (`gb_bond_grants.granted_at`), the inviter should get "… joined your GymBond" on a device that
   allowed notifications and has a bond (its `gb_devices.apns_token` set). A Debug build registers
   with APNs' sandbox (`apns_environment = 'development'`); the App Store build with production.
8. **Privacy policy.** A line for the bond: a friend you bond with sees your first name, the days you
   trained this week and when you finish a workout. And one for pushes: a push token is kept for a
   signed-in iPhone while notifications are allowed.
9. **A message to one account** (`supabase/migrations/20261108000200_notify.sql`, 8 Nov 2026; pushed the same day). From the SQL editor, service role: `select gb_notify('<user id>', 'Title',
   'Body');` queues it; the trigger and the function send it to that account's iPhones that have a
   token (signed in, notifications allowed, launched since the build that registers them). Check
   `gb_bond_notifications` for `sent_at` and `error`.
