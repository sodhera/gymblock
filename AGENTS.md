# AGENTS.md

GymBlock: a native SwiftUI iOS app (iOS 26.1+) that locks distracting apps
during gym workouts, logs training, and keeps a weekly streak with friends.

Before changing anything:

- Read `DESIGN.md` before touching UI, and update it when design decisions
  change.
- `docs/development.md` covers setup, architecture, and debug flags.
  `docs/product-brief.md` covers product rules.
- The project is generated: run `xcodegen generate` after adding or removing
  files. Never hand-edit `GymBlock.xcodeproj`.
- Keep documentation current and commit frequently.

Hard product decisions (don't re-litigate without the owner):

- Light-first brand: bone paper, ink, a single safety-orange accent.
- No exercise figures, muscle maps, or exercise illustrations anywhere.
- The CTA reads "Start Workout". The streak counts weeks against a weekly
  target.
- Hard paywall after sign-up. The block runs from Start to Hold-to-finish,
  with a 4h safety cap.

Sibling reference app: `../Sulav-Sleep` (SleepBlock). It uses the same
stack (Supabase, RevenueCat, Screen Time extensions) and the same
documentation habits.
