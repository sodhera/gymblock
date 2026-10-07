# Onboarding review against onboarding principles

7 Oct 2026 · Reviews the 17-page flow (16 for "Rarely") as built on iPhone 18 Pro / iOS 27.

Flow: Welcome → Name → Gender → Height & weight → Phone between sets → Minutes per rest → **Your phone time** → **Hours a year** → Mind-muscle ×2 → Pump ×2 → Memory vs log ×2 → Block apps → **Hold to commit** → Paywall.

| Principle | Status | Notes |
|---|---|---|
| **Show value before asking** | ✅ | The welcome demonstrates the product (notifications pile up → cleared → lock) before any question. |
| **Start with the easiest ask** | ✅ | Name first: one field, keyboard already up, Return advances. |
| **Ask only for what you use** | ⚠️ | Name is used (headlines). **Gender, height and weight are stored but not used anywhere yet.** Unused personal questions cost trust and add 2 pages. Either use them soon (body-weight exercises, strength-to-bodyweight progress) or move them after the paywall. |
| **One idea per screen** | ✅ | One headline, one control, no subtitles. Paired pages split hard ideas in two. |
| **Personalised "aha" moment** | ✅ | "Sirish, here's your phone time: 34 min every workout", then "That’s 147 hours a year = 196 workouts of 45 min". It's built entirely from their own answers, it can be adjusted live, and it isn't an invented statistic. |
| **Make the abstract concrete** | ✅ | Minutes become a ring of rests, hours become a grid of 45-minute workouts, pump becomes a chart that never reaches the line. |
| **Momentum and progress** | ✅ / ⚠️ | A thin progress line and one-tap answers that auto-advance. The flow is long, though (about 60–75 s): every added page has to earn its place. |
| **Pacing / don't let people skip the point** | ✅ | Continue appears only after each scene finishes (all ≤ 3 s), with a 6 s safety net. |
| **Feedback** | ✅ | Haptics on every page change, answer, notification, ring segment, workout dot, set and pledge, plus a ramp during the hold. |
| **Commitment & consistency** | ✅ | Three pledges and a 1.6 s hold, placed right before the paywall so the purchase follows a public-to-self commitment. Releasing early drains it. |
| **Permission priming** | ⚠️ | "Block what distracts you" correctly primes before a system prompt, but the real Screen Time (FamilyControls) request isn't wired yet. **Rest-timer alerts will need notification permission, and there is no priming page for it.** |
| **Reversibility** | ✅ | Back works everywhere; answers persist; relaunch resumes on the same page. |
| **Honest claims** | ⚠️ | "Scrolling weakens your mind-muscle connection" is your approved copy, but it's a causal health claim with limited evidence (App Store guideline 1.4.1 risk). Scenes are labelled "Illustration"/"Example". "Perfect pump" is a stylised metaphor. |
| **Paywall best practice** | ❌ (deferred) | No price, trial, annual-vs-monthly anchor, social proof or "what happens next". This is expected while billing is unconfigured; plan these before launch. |
| **Social proof** | ❌ | No reviews, user counts or testimonials anywhere. Add one line before the paywall once real numbers exist; never fabricate. |
| **Accessibility** | ✅ | Dynamic Type everywhere, Reduce Motion shows final states, VoiceOver labels on every scene, an accessibility action for the hold. |

## Recommended next changes (in order)

1. **Decide on gender/height/weight.** Use them, or move them after the paywall. That makes the flow 15 pages.
2. **Add a notification priming page** ("Get a tap when your rest is up") after blocking, followed by the system prompt.
3. **Wire the real Screen Time picker** on the blocking page.
4. **Build the real paywall**: free trial, annual plan anchored against monthly, one honest proof line, and "Cancel anytime in Settings".
5. **Login after the paywall** as planned, offering Sign in with Apple only.
6. **Measure it**: completion per page, time on page and where people drop off, especially pages 2–4 and the paywall.
