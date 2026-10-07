# Onboarding review against onboarding principles

7 Oct 2026 · Re-reviewed: the 19-page flow (17 for "Rarely") as built on iPhone 18 Pro / iOS 27.

Flow: Welcome → Name → Gender → Height → Weight → Phone between sets → Minutes per rest → **Your phone time** → **Hours a year** → Mind-muscle ×2 → Pump ×2 → Memory vs log ×2 → Block apps → **Rest alerts** → **Hold to commit** → Paywall.

| Principle | Status | Notes |
|---|---|---|
| **Show value before asking** | ✅ | The welcome demonstrates the product (notifications pile up → cleared → lock) before any question. |
| **Start with the easiest ask** | ✅ | Name first: one field, keyboard already up, Return advances. |
| **Ask only for what you use** | ✅ / ⚠️ | Name personalises headlines. Gender, height and weight now share one page (saving a page), set sensible defaults, set kg/lb for logging, and are editable in Settings → Body. Their deeper use (bodyweight exercises, strength relative to bodyweight) is still to come. |
| **One idea per screen** | ✅ | One headline, one control, no subtitles. Paired pages split hard ideas in two. |
| **Personalised "aha" moment** | ✅ | "Sirish, here's your phone time: 34 min every workout", then "That’s 147 hours a year = 196 workouts of 45 min". It's built entirely from their own answers, it can be adjusted live, and it isn't an invented statistic. |
| **Make the abstract concrete** | ✅ | Minutes become a ring of rests, hours become a grid of 45-minute workouts, pump becomes a chart that never reaches the line. |
| **Momentum and progress** | ✅ / ⚠️ | A thin progress line; one question per page. Answers no longer auto-advance (Continue confirms), which is calmer but adds taps; at 19 pages (~90 s) every page has to earn its place. |
| **Pacing / don't let people skip the point** | ✅ | Continue appears only after each scene finishes (all ≤ 3 s), with a 6 s safety net. |
| **Feedback** | ✅ | Haptics on every page change, answer, notification, ring segment, workout dot, set and pledge, plus a ramp during the hold. |
| **Commitment & consistency** | ✅ | Three pledges and a 1.6 s hold, placed right before the paywall so the purchase follows a public-to-self commitment. Releasing early drains it. |
| **Permission priming** | ✅ / ⚠️ | Rest alerts: a priming page shows exactly what they'll get, then the real iOS prompt, and the alert works in the app (one local notification when a rest reaches 1:30, editable in Settings). Screen Time blocking still isn't wired: it needs Apple's Family Controls entitlement and a signed build. |
| **Reversibility** | ✅ | Back works everywhere; answers persist; relaunch resumes on the same page. Settings has Log out (keeps workouts on this iPhone) and Delete account (erases everything, with a confirmation). |
| **Honest claims** | ⚠️ | "Scrolling weakens your mind-muscle connection" is your approved copy, but it's a causal health claim with limited evidence (App Store guideline 1.4.1 risk). Scenes are labelled "Illustration"/"Example". "Perfect pump" is a stylised metaphor. |
| **Paywall best practice** | ❌ (deferred) | No price, trial, annual-vs-monthly anchor, social proof or "what happens next". This is expected while billing is unconfigured; plan these before launch. |
| **Social proof** | ❌ | No reviews, user counts or testimonials anywhere. Add one line before the paywall once real numbers exist; never fabricate. |
| **Accessibility** | ✅ | Dynamic Type everywhere, Reduce Motion shows final states, VoiceOver labels on every scene, an accessibility action for the hold. |

## Done in this pass

- Gender, height and weight merged into one page; editable in Settings → Body.
- Rest-alert priming page with the system prompt, and working rest notifications.
- Log out and Delete account in Settings.
- Workout: ending a workout with saved sets now asks first; number fields can't overwrite what was just typed; "1 set" instead of "1 sets".

## Still to do (needs decisions or Apple setup)

1. **Real Screen Time blocking**: Family Controls entitlement, a signed build and the app picker.
2. **Real paywall**: free trial, annual plan anchored against monthly, one honest proof line, and "Cancel anytime in Settings". Billing is deferred by decision.
3. **Login after the paywall**: Log out and Delete account are ready to call into it.
4. **Measure it**: completion per page, time on page and drop-off, especially pages 2–3 and the paywall.
