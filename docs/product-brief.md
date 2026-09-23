# GymBlock Product Brief

GymBlock is a gym app with one promise: **your phone waits, you lift.**
Start a workout and the apps you chose lock until you finish. The same app
is your logbook (sets, reps, weights, notes, templates) and keeps a weekly
streak you can share with friends.

## The loop

1. **Start Workout** from Today (a template, or empty). The chosen apps
   lock.
2. Log sets. Last time's numbers are pre-filled as placeholders, so it's one
   tap per set. The rest timer starts automatically. PRs are flagged the
   moment they happen.
3. Reach for Instagram and the shield says what's left: "3 sets of Bench
   Press left."
4. **Hold to finish.** Apps unlock, today's circle fills in, and PRs land.

Throughout, a Live Activity keeps the workout in the Dynamic Island and on
the Lock Screen. It shows the clock while lifting and a rest countdown with
+15 / Skip after each set, so the phone never needs unlocking mid-workout.

## Rules

- **Streak = weeks.** The user picks a weekly target (1–7 days). A week
  counts when that many distinct days have a counting workout (≥3 completed
  sets). The current week adds once it's complete, but never breaks the
  streak while days remain. Rest days can't break it.
- **Consistency** = share of the last 12 finished weeks that hit the target.
- **PRs** are judged on Epley estimated 1RM, so 100×5 beats 105×1.
  Warm-ups never count, and a first-ever set is a baseline, not a PR.
- **The block** lasts from Start to Finish, with a 4-hour safety cap.
  There's no escape on the shield; finishing early is allowed but won't
  count toward the week.

## Friends

Add by username or invite link. Friends always see your week, streak,
consistency, and PRs. They see a workout's contents (exercises, sets, notes)
only if you shared it (the default is set in Settings, and each workout has
its own toggle). The only interaction is a nudge. No feed, likes, or
comments.

## Business

A hard paywall after sign-up (RevenueCat): yearly with a 7-day free trial,
or monthly. The trial reminder is a real notification two days before
billing.

## Not in v1 (candidates)

- Auto-start the block on arriving at the gym (geofence)
- Apple Watch logging
- Push notifications for nudges and friend requests (the table exists)
- Dark mode
- Plate calculator, supersets, charts per exercise
- Custom-designed app icon (v1 uses the lock mark)
