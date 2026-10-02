# GymBlock design

Follow `docs/REDESIGN-PLAN.md` for the complete intent map, onboarding, screen budgets and edge-case rules. The approved redesign replaces the earlier blue dashboard and six-step preference/paywall onboarding.

## Visual system

Red is the sole accent. The adaptive action/link tint uses #C92535 in light appearance and #FF626B in dark appearance, with higher-contrast variants. The filled primary glass button uses deep red with a light label. Use system backgrounds and primary/secondary label colors; no navy headings, blue numbers, decorative textures or repeated cards.

Use the default San Francisco system family with semantic text styles. Exercise titles are Title 2, ordinary rows are Body/Subheadline, and the actionable number uses a scalable semibold numeric style with monospaced digits. Native margins, controls and shapes define the UI. Numbers are content; glass is reserved for functional controls and navigation. Important workout buttons use native glassProminent on iOS 26+ and native bordered controls on earlier supported releases.

## Structure

Home has a quiet weekly streak, an explicit workout choice, Start workout and three compact lift records. Progress and Settings are its secondary destinations. A split starts directly at its first exercise; Free workout starts at native search/recent exercises.

Ready → Start set → actual Reps completed → Finish set → rest → Start next set. One primary action stays near the bottom. Rest starts after saving and can be interrupted. Exercise changes retain rest and independent values. Uncommon actions belong in Workout options or the saved-set editor, not a grid of controls.

First-time exercise weight is explicitly chosen; unknown reps stay blank. Record actual completed reps regardless of prior values. Attempts are distinct from completed sets and never count as lift records or training streaks. Corrections update the same record. Deleting the most recent accidental set cancels only its own rest; undo restores its original deadline when no new active set has started. Timed exercise records actual elapsed duration or an explicit correction.

Progress has a neutral first result and red latest result. Compare weight with reps held constant, or reps with weight held constant. Charts live behind History. Reduced Motion shows the final comparison immediately. Never invent a combined strength or body-change score.

## Onboarding and data

Language/optional name → distractions → duration/frequency → exercise/sets/reps → self-reported scrolling → attributed summary → optional focus demo. Skip/unknown paths lead to a usable Home. Routine baselines support ranges, per-exercise differences and per-set reps; they never masquerade as workout logs. No placeholder paywall or predicted pounds of muscle/fat change.

Local-only storage and stable split IDs remain required. Demo seeds are explicit, repeat-safe and marked on Home. Existing data must decode without new optional fields. Native large-text layout, increased contrast, light/dark and reduced motion/transparency remain part of review. Capture actual simulator UI for visual changes.

Focus remains simulated: use Focus demo and honest onboarding copy. No real restriction, billing or distribution claim follows from the prototype.
