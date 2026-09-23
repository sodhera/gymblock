# GymBlock launch setup checklist

The integration code is done: Supabase auth and friends, RevenueCat
paywall, Screen Time, and the Live Activity. What's left needs your
accounts. Until the keys exist, the app runs in dev mode: sign-in shows
"Skip — dev build", and the paywall stands down.

## 1. Supabase (≈5 min)

1. Create the project in the dashboard (name `gymblock`, pick a region
   near your users). It's done by hand because it adds a project to your
   paid org.
2. Copy the **project ref** (Project Settings → General).
3. Run:

   ```bash
   scripts/setup-supabase.sh <project-ref>
   ```

   This links the repo, applies `supabase/migrations/001_init.sql` (tables
   and RLS), enables Sign in with Apple (`com.sulav.gymblock`), deploys
   `delete-account`, and writes the URL and anon key into
   `GymBlock/Config/Config.xcconfig`.
4. Check that **Auth → Providers → Apple** is on with client ID
   `com.sulav.gymblock`. The native flow needs no secret.

## 2. Apple Developer (≈10 min)

1. **Identifiers:** register `com.sulav.gymblock` plus the extensions
   `.shield-config`, `.shield-action`, `.monitor`, and `.widget`. Automatic
   signing usually creates these on the first device build.
2. **App Group:** `group.com.sulav.gymblock`, added to the app and the
   three Screen Time extensions.
3. **Capabilities** on the app ID: Sign in with Apple, Family Controls,
   and App Groups.
4. **Family Controls (Distribution):** request the entitlement for all
   four Screen Time bundle IDs (the same form you used for SleepBlock).
   Development builds work before it's granted.

## 3. App Store Connect (≈10 min)

1. Create the app, bundle ID `com.sulav.gymblock`.
2. Create a subscription group, **GymBlock Pro**, with:
   - `com.sulav.gymblock.pro.annual`: yearly, with a **7-day free trial**
     intro offer
   - `com.sulav.gymblock.pro.monthly`: monthly

   The preview paywall uses $39.99/yr and $7.99/mo as placeholders; set
   your real prices.

## 4. RevenueCat (≈10 min)

1. New project, then add an **App Store** app with bundle ID
   `com.sulav.gymblock`, plus the App Store Connect API key / in-app
   purchase key.
2. Import both products.
3. **Entitlement:** identifier exactly `GymBlock Pro`, with both products
   attached.
4. **Offering:** `default`, marked current, with packages `$rc_annual` and
   `$rc_monthly`.
5. Copy the public **Apple API key** (`appl_…`) into
   `GymBlock/Config/Config.xcconfig` as `REVENUECAT_API_KEY`.

## 5. Before submitting

- [ ] Replace the placeholder privacy URL in `PaywallView.swift`
      (`gymblock.app/privacy`) with your real one. Add a support URL in
      App Store Connect.
- [ ] Test on a real iPhone: the block and shield, the Live Activity
      buttons, and haptics.
- [ ] Sandbox purchase: trial → entitled → Settings shows "Free trial",
      and Manage opens the App Store sheet.
- [ ] Delete account works end to end (the Edge Function is deployed).
- [ ] App Review notes: explain Screen Time use ("locks only the apps the
      user picks, only during a workout they start") and provide a demo
      account.
