# GymBond: train with a friend

**8 Nov 2026 · Built, not deployed.** Sulav's brief: the app is single-player, which gets boring and
churns; friends in the app make it fun and keep people. A paid user invites a friend with a code and
both get two weeks of GymBlock Pro ("Gift two weeks of GymBlock Pro to your friend"); each hears when
the other is losing a streak; an optional code page in onboarding; everything minimal and a subtle add
to what's there. The name is a placeholder. Screens: [screenshots/2026-11-08-gymbond/](../screenshots/2026-11-08-gymbond/).

## What it is, in the app's own words

A **bond** is two people who train. You have one six-letter **code** (on Profile → GymBond; tap to
copy, Share sends "I'm gifting you two weeks of GymBlock Pro. Use my code 7KD4QX when you sign up." and
the App Store link). A friend who joins with it is bonded to you, and **both get two weeks of GymBlock
Pro**: theirs starts at once (so a new friend skips the price page), yours starts when your current
plan ends (an App Store subscription can't be extended, so the gift waits for the moment you'd
otherwise pay or lapse; with no plan, yours starts at once too). Up to five bonds each.

Friends see **your first name, your week and when you finish a workout. Nothing else.** (The line is
on the page.) No feed, no likes, no leaderboards, no chat.

## Where it lives (the subtle adds)

| Place | What | Why it's enough |
|---|---|---|
| **Home**, under the week line | Each friend's week as smaller ink dots in the same columns as yours, with their first name. Two at most. | The one glance that creates accountability: your week over theirs, every time you open the app. No card, no number. Emerald stays yours; a friend's trained day is ink. |
| **Profile**, under the blocking card | No bond yet: one glass card, "Train with a friend · Two weeks of Pro, for both of you." With bonds: a GYMBOND label, "Invite", and a card per friend (name, "6 week streak" / "2 this week" / "Nothing yet this week", their dots), each opening the page. | The same shape as the blocking card and the workout cards. |
| **GymBond page** (from Profile) | Your code large (tap to copy), Share your code (the ink button, the share sheet); "Have a code?" with a field and Add; your friends with a **Nudge** each (one a day; a long press removes the bond); the privacy line. | One page holds all of it. |
| **Onboarding**, after the commit, before the wall | As Cal AI's referral page (8 Nov 2026, at the user's request): "Enter referral code (optional)" / "You can skip this step.", one glass row low on the page with the field and an inline Submit, Skip as the page's button, Back, and no keyboard until a tap. Joined, "You're bonded with Sirish." and, once RevenueCat shows the gift, straight to You're in (the trial pages and the price are skipped); if the gift hasn't landed yet, the trial pages as usual and the price page steps aside by itself when it does. No Back (the account exists). | The friend's gift is redeemed by the account that just got made, so Pro is real before the price page. |
| **Onboarding**, the setup page after the split is chosen | The GymBuddy invite (9 Nov 2026, at the user's request): "Invite a friend to be your GymBuddy." / the gift line, a card in the middle (a gift mark, "2 weeks of Pro", "For your friend, free.", their code on glass), Invite a friend as the ink button (the share sheet with the gift text and code, `BondShareButton`), Skip below. `OnboardingStep.bondInvite`; the code is fetched on the page if Profile hasn't yet. | The code exists from the commit's silent account, so the invite is real before they reach Home. |
| **Pushes** (server) | *Joined:* "Sirish joined your GymBond" / "Two weeks of GymBlock Pro, on us." (or "Your two weeks of Pro start when your current plan ends."). *Finished:* "Sirish just finished Push" / "32 min · 15 sets. Your move." *Streak:* Sunday at 4 pm in the friend's time zone, nothing logged this week after a week with something: "Sirish hasn't trained this week" / "One workout today keeps their streak. Send a nudge." *Nudge:* "Sirish nudged you" / "They're asking when your next workout is." In the recipient's language. | Three moments that matter and one they chose; never a daily drip. |

Not built, for later if the first version earns it: the friend's dots on the week widget; a mark on a
day you both trained; "Sirish is training now" (presence, from the Live Activity's start); a line on
the summary ("Sirish will hear you finished"); a shared month on Profile.

## How it works

- **Server** (`supabase/migrations/20261108000100_gymbond.sql`): `gb_bond_codes` (one per account,
  made by `gb_bond_code()`; the alphabet has no 0/O or 1/I, and a typed 0 or 1 is read as the letter),
  `gb_bonds` (inviter, friend, ended_at; one active bond per pair), `gb_bond_grants` (the gift per
  side, due_at, granted_at), `gb_bond_nudges` (one a day per direction), `gb_bond_notifications`
  (the push queue, never readable from the app), and `apns_token` / `apns_environment` on `gb_devices`.
  The app only calls functions: `gb_bond_code`, `gb_bond_redeem(code)` (→ bonded · not_found ·
  own_code · already_bonded · limit), `gb_bond_friends()` (each bond with the other side's first name,
  their finished workouts over ten weeks, their latest workout, your last nudge, your gift's state),
  `gb_bond_nudge(bond)`, `gb_bond_end(bond)`. Row-level security lets a party read its own rows and
  nobody write them directly.
- **The gift** is a RevenueCat *promotional entitlement* (`pro`, `two_week`), granted by the database
  itself (`gb_bond_grant`, the `http` extension, the secret key from the Vault): the friend's during
  the redeem call, the inviter's by the hourly cron once their plan has ended (while
  `gb_subscriptions` says they're entitled, the due date follows their expiry). A grant that fails is
  retried hourly with its error kept on the row. The app never holds the secret key.
- **Pushes**: a trigger on `gb_workouts` queues "finished" for each bond partner when a workout gets
  its `ended_at` (sets > 0, within six hours, never twice); the hourly `gb_bond_streak_check` queues
  the Sunday one; the redeem and nudge functions queue theirs. A trigger on the queue asks the
  `gymbond-push` Edge Function (pg_net, shared secret from the Vault) to send each row to the
  recipient's iPhones through APNs (`supabase/functions/gymbond-push/index.ts`: provider JWT with the
  `.p8` key, sandbox or production per device, dead tokens cleared). The dashboard steps are
  `supabase/README.md` §6.
- **App** (`GymBond.swift`, `BondViews.swift`): `GymBond.shared` keeps the code and the friends,
  cached per account on the iPhone so Profile and Home draw offline; refreshed at sign-in, on every
  return to the foreground and on the page. The friend's week and streak are computed on the phone
  with `TrainingDays`, the same calendar Home uses. The push token is asked for only while the account
  has a bond and notifications are allowed (`PushDelegate`), saved on the install's `gb_devices` row,
  and cleared before Log out; Delete account clears it on the server. Development runs have no
  account and show nothing; `-bondPreview friends` (or `empty`) seeds two sample friends for
  screenshots. Analytics: `bond_redeem` (status, where), `bond_nudge`, `bond_ended`, `bond_skipped`,
  `bond_push_token`, taps `bond.share` / `bond.copy` / `bond.nudge`, screens `profile.bond` and
  `onboarding.bondCode`; never the code or a name.
- **Spanish** in `JourneyLanguageBond.swift`; the server writes each push in the recipient's language.

## Decisions to confirm

1. **The inviter's two weeks wait for their plan to end.** RevenueCat can't add days to an App Store
   subscription, and a promotional entitlement runs alongside one, so granting it at once would give
   a subscriber nothing. Waiting makes it a real two weeks, at the moment it keeps them. The
   alternative, Apple offer codes for existing subscribers, is a bigger build. The "joined" push says
   which case applies.
2. **Anyone with an account can share a code** (the brief said a paid user). The friend's gift is the
   acquisition lever either way, and a free inviter's own gift simply starts at once. Easy to restrict
   to subscribers in `gb_bond_redeem` if wanted.
3. **First names are shared with a friend.** The app's rule is never names in analytics; a bond is
   the one place a name travels, to the person you gave your code to, and the page says so. The
   privacy policy needs a line (supabase/README.md §6.8).
4. **The code page is always shown** after the account (skippable), not only to people who picked
   "A friend" on the source question.

## Checked

Built first time (`xcodegen generate`, Debug, iPhone 17 Pro simulator, iOS 26.5). On the throwaway
simulator: Home with two sample friends' lines under the week; Profile with the invite card
(`-bondPreview empty`) and with the two friend cards; the GymBond page (code, Share, the field, two
friends, Nudge / Nudged); onboarding's code page empty, with a code typed (Continue turns ink), and
after Continue offline ("Sign in to use a code." under the field). The onboarding route tests
(`BenefitSceneTests`, `JourneyV2Tests`) pass with the new step: 22 run, 1 skipped, 0 failures.
**Not checked:** anything against the real server (the migration hasn't been run; its SQL was read
through, not executed), a real redeem, the gift landing in RevenueCat, a push arriving, the share
sheet on a device, the push entitlement on a device build, Spanish, the iPhone SE, accessibility sizes.
