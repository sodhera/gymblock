# GymBlock workspace instructions

- Native Swift/SwiftUI only. `project.yml` is the XcodeGen source of truth; regenerate when adding files or changing configuration.
- Keep the app extremely simple and local-only. No accounts, backend, analytics or network SDKs.
- Preserve onboarding order: language, name, broad training multi-select, favorites by body area, blocking choice, prototype paywall, Home.
- Home offers an optional split choice; Start workout activates the simulated block and immediately opens exercise selection. Finish clears it before summary.
- Keep splits optional, preserve their IDs on edits and compare progress only within the same split, exercise and rep count.
- Demo loading must be explicit, idempotent and never overwrite existing local work. Keep the sample-history marker visible on Home.
- Blocking and purchases are prototype representations. Keep honest visible labels; do not claim real enforcement or billing.
- Read DESIGN.md before visual edits. Keep README.md and VALIDATION.md current for material changes.
- Prove visual changes with actual simulator screenshots or Device Hub. Build/install/launch alone is insufficient.
- Preserve read-only boundaries around SleepBlock and Speaking Coach reference sources.
- User has authorized local implementation and simulator validation. External publishing, purchases, release, account changes or consequential external actions require explicit approval.
- Personal identity: sirishjoshi24@gmail.com. Company identity: admin@sodhera.com. Never claim authentication without current verification.
