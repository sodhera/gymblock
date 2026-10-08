# GymBlock cloud: Supabase, RevenueCat, App Store

Everything the app needs from the dashboards, in the order to do it, with what is already done.

| Step | State on 8 Oct 2026 |
| --- | --- |
| 1. Schema | **Done** (run in the SQL editor; 7 tables, 3 views, `gb_delete_account`). |
| 2. Apple provider | **Done** (enabled, client id `com.sodhera.gymblock`). Apple Developer capability: pending until the App ID exists. |
| 3. Google provider | **Done**: Google Cloud project `gymblock` (org sodhera.com, account authuser=2), consent screen "GymBlock" (External, admin@sodhera.com), web client "GymBlock Supabase" with the Supabase callback; ID and secret saved in Supabase → Google. |
| 3b. Redirect URL | **Done** (`gymblock://auth/callback`). |
| 4. RevenueCat | **Done**: project GymBlock (65ed1e99), App Store app `com.sodhera.gymblock`, products, entitlement `pro`, offering `default`; keys in `Secrets.xcconfig` (Test Store for Debug, App Store for Release). |
| 5. App Store Connect | **Pending**: the session had expired; sign in, then create the app and the two subscriptions. |

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
5. Apps → GymBlock → copy the *Public app-specific API key* (`appl_…`) into `Secrets.xcconfig`:
   `REVENUECAT_API_KEY = appl_…` — then rebuild. The key is public; commit it. Debug builds use the
   project's *Test Store* key (`REVENUECAT_API_KEY[config=Debug]`), so `--online` runs on the
   simulator show real offerings and a RevenueCat test purchase sheet without App Store Connect.

## 5. App Store Connect

1. My Apps → + → iOS app → GymBlock, bundle id `com.sodhera.gymblock`, SKU `gymblock`.
2. Subscriptions → Subscription group "GymBlock Pro":
   - `com.sodhera.gymblock.pro.monthly` — 1 month — USD 4.99 (tier equivalent elsewhere)
   - `com.sodhera.gymblock.pro.yearly` — 1 year — USD 49.99
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
`gb_workout_stats`. Useful queries:

```sql
-- Where people drop off in onboarding
select screen, count(distinct install_id) from gb_events where name = 'screen' and screen like 'onboarding.%' group by 1 order by 2 desc;
-- Rest discipline: median gap before a set, per week
select date_trunc('week', logged_at) as week, percentile_cont(0.5) within group (order by gap_before_seconds) from gb_sets where gap_before_seconds is not null group by 1 order by 1;
-- Purchases
select name, count(*) from gb_events where name like 'purchase_%' or name in ('entitled', 'restore') group by 1;
```
