# GymBlock workspace instructions

- Native Swift/SwiftUI only. `project.yml` is the XcodeGen source of truth; regenerate when adding files or changing configuration.
- Keep the app extremely simple and local-only. No accounts, backend, analytics or network SDKs.
- Follow docs/REDESIGN-PLAN.md: welcome/language/name, distractions, gym time, routine, scrolling estimate, personal summary, optional focus demo. No placeholder paywall or unsupported body-outcome predictions.
- Home offers an optional split choice; Start workout activates the simulated block and opens the split’s first exercise or Free workout exercise selection. Finish clears it before summary.
- Keep splits optional, preserve their IDs on edits and compare progress only within the same split and exercise, with rep count or load held constant.
- Demo loading must be explicit, idempotent and never overwrite existing local work. Keep the sample-history marker visible on Home.
- Blocking is a prototype representation. No purchase flow is configured. Keep honest visible labels; do not claim real enforcement or billing.
- Read DESIGN.md before visual edits. Keep README.md and VALIDATION.md current for material changes.
- Prove visual changes with actual simulator screenshots or Device Hub. Build/install/launch alone is insufficient.
- Preserve read-only boundaries around SleepBlock and Speaking Coach reference sources.
- User has authorized local implementation and simulator validation. External publishing, purchases, release, account changes or consequential external actions require explicit approval.
- Personal identity: sirishjoshi24@gmail.com. Company identity: admin@sodhera.com. Never claim authentication without current verification.
