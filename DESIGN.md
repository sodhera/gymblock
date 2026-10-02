# GymBlock design

The home screen puts weekly consistency and one Start workout action first. A compact chooser underneath selects Free workout or an optional split. There is no required workout setup step after starting: focus simulation is active as soon as the exercise search appears.

## Red and blue

Neutral ground, blue ink, blue primary actions and red progress/rest accents. Primary action blue is #2452B5 and finish-set red is #C2263B with white labels. Light and dark semantic surfaces adapt to system appearance. No gradients, background textures, decorative outlines, large motivational cards or social navigation. System typography, 24-point page margins, 14–18-point corners, 56-point primary actions and 44-point secondary targets.

## Workout loop

Start workout → search or choose an exercise in the selected split → adjust weight → Start set → adjust reps and Finish set → automatic 60-second rest. Start next set can interrupt rest at any time. Change exercise is available between sets. Reps and weights carry forward from the last logged set of that exercise. A picker and manual input share the same number; fractional weights are supported. The displayed weight range is 0–500 kg or lb, with zero reserved for bodyweight. The wheel advances by 0.5; typing allows hundredths. Reps are 1–100. Cardio and stretching log minutes.

The exercise list initially shows the split or recent/favorite exercises. Typing "dum" filters dumbbell exercises. Search can add exercises outside the split without altering its saved template. Custom exercise entry remains available.

## Splits and progress

Settings → Splits supports naming, adding, removing and reordering exercises. Each split has a stable ID: renaming or editing it preserves its session links. Deleting a split retains workout history. Splits are optional; Free workout is always available.

Home shows the three heaviest logged lifts with reps alongside. These are historical max-weight sets, not estimated strength or a combined score.

Progress starts at a split and opens each exercise. Compare the first and latest sessions at the latest set's rep count. Only sessions launched from the same split count. Different exercises, different rep counts and freestyle sessions are excluded from that comparison. One observation is a baseline, not evidence of improvement. An existing split's past exercises remain in History if removed from its template.

Progress animation keeps the first result still and moves the latest bar and number over 0.55 seconds, followed by an accessible date/weight chart. Replay is optional. Reduce Motion shows final values immediately. This is a chosen design, not a tested claim about universal user preference.

## Sample data and boundaries

The debug --demo argument or Settings → Load sample workouts seeds Arms, Push and Legs with approximately six weeks of sample history, only when local history, splits and active session are empty. The seeded marker is visible on Home. New workouts save normally and relaunch preserves them. A repeat seed never overwrites existing data. --ui-reset is a debug-only test reset.

Preserve the six-step onboarding, English/Spanish selection, local-only storage, no accounts, backend, analytics or SDKs. Blocking and purchases are explicitly simulated. Real system restriction, StoreKit and release delivery remain outside this prototype.
