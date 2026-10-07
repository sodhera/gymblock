# GymBlock workspace instructions

- Native Swift/SwiftUI only. `project.yml` is the XcodeGen source of truth; regenerate when adding files or changing configuration.
- Keep the app extremely simple and local-only. No server accounts, backend, analytics or network SDKs. Settings' Log out / Delete account act on local data only (log out keeps workouts; delete erases everything) until a login exists.
- Follow docs/ONBOARDING-V5-PLAN.md for onboarding (minimal dark stage, fixed grid, one headline per page, ≤2% red, SF Pro Dynamic Type, paired story stages, blocking before the offer) and docs/UX-RESET-V3.md for training/navigation. Use Workout / History / Splits navigation; remove decorative icons and repeated copy in the running app. Live billing is deferred; the onboarding has no preview bypass at the user's request (use `--demo` in Debug). Keep one-word claim qualifiers. The approved mind-muscle headline is “Scrolling weakens your mind-muscle connection.” Do not invent body-outcome predictions.
- Home offers an optional split choice; Start workout activates the simulated block and opens the split’s first exercise or Free workout exercise selection. Finish clears it before summary.
- Keep splits optional, preserve their IDs on edits and compare progress only within the same split and exercise, with rep count or load held constant.
- Demo loading must be explicit, idempotent and never overwrite existing local work. Keep the sample-history marker visible on Home.
- Blocking is a prototype representation. No purchase flow is configured. Keep honest visible labels; do not claim real enforcement or billing.
- Read DESIGN.md before visual edits. Keep README.md and VALIDATION.md current for material changes.
- Prove visual changes with actual simulator screenshots or Device Hub. Build/install/launch alone is insufficient.
- Preserve read-only boundaries around SleepBlock and Speaking Coach reference sources.
- User has authorized local implementation and simulator validation. External publishing, purchases, release, account changes or consequential external actions require explicit approval.
- Personal identity: sirishjoshi24@gmail.com. Company identity: admin@sodhera.com. Never claim authentication without current verification.
