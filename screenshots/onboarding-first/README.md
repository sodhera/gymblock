# Workout-first onboarding — actual simulator evidence

Captured from the native app on 3 October 2026. These are rendered screens, not mockups. Earlier screenshot folders show previous designs.

- [Final installed welcome](01-welcome.png): fresh setup on the primary iPhone 17, light appearance and standard text.
- [Frequency](onboarding-02-frequency.png), [visit duration](onboarding-03-duration.png), [routine sketch](onboarding-04-routine.png), then [scrolling question](onboarding-05-scroll-question.png) and [minutes](onboarding-06-minutes.png).
- [Before](onboarding-07-before.png) and [after](onboarding-08-after.png): a 60-minute visit stays fixed while the proposed phone-free share changes. Rest remains part of phone-free time.
- [Normal-speed transition clip](before-after.mp4): actual simulator excerpt, about 2.7 seconds, without audio. It shows the estimate entrance and before/after transformation, not measured training gains.
- [Ready](onboarding-09-ready.png), [example rest counter](onboarding-10-example-rest.png) and [honest Focus demo](onboarding-11-focus-demo.png).
- `final-normal/`: 402 × 874-point device; manual-entry keyboard, routine, result and Spanish setup.
- `medium/`: 390 × 844-point iPhone 17e; final manual-entry and comparison route.
- `small-reduced/`: 375 × 667-point iPhone SE; actual OS Reduce Motion and Reduce Transparency enabled, opaque controls and complete comparison visible.
- `dark-large/`: iPhone 17 with dark appearance, accessibility-large text and increased contrast. Longer content scrolls while the primary action remains pinned.

See [VALIDATION.md](../../VALIDATION.md) for exact test runs, corrected failures and limits. The final model suite passed 39 checks; nine distinct affected UI journeys passed across targeted runs. Physical haptics/sound tuning, manual VoiceOver navigation and user preference testing remain separate work. Real Screen Time enforcement is not implemented.
