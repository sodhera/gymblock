# GymBlock UX V3 — actual app captures

These are simulator captures of the implemented interface, not design mockups. Normal-size captures use iPhone 17e, iOS 27, light appearance and DM Sans. Sample history is explicitly labeled Demo; onboarding examples do not become saved workouts.

## Onboarding

| Page | Capture |
|---|---|
| Welcome | [Set-record introduction](v3-01-welcome.png) |
| Days per week | [Native seven-tick Liquid Glass slider](v3-02-glass-slider.png) |
| Workout length | [Minute wheel](v3-03-minutes.png) |
| Reps, sets, exercises | [Reps](v3-04-reps.png), [sets](v3-05-sets.png), [exercises](v3-06-exercises.png) |
| Scrolling | [Choice](v3-07-scrolling.png), [minutes](v3-08-scrolling-minutes.png) |
| Habits | [Rest timing](v3-09-rest-question.png), [logging](v3-10-log-question.png), [set timing](v3-11-time-question.png) |
| Demonstrations | [Phone down](v3-12-phone-down.png), [upward rest counter](v3-13-rest-demo.png), [before and after](v3-14-before-after.png) |
| Arrival | [Workout](v3-15-workout-home.png), [empty History](v3-16-empty-history.png) |

## Training

| Task | Capture |
|---|---|
| Start and choose | [Workout](v3-app-01-home.png), [exercise search](v3-app-02-search.png), [ready](v3-app-03-ready.png) |
| Set weight | [Wheel](v3-app-04-weight-picker.png), [typing](v3-app-05-weight-manual.png) |
| Log and rest | [Active set](v3-app-06-active.png), [rest](v3-app-07-rest.png), [correct a set](v3-app-08-edit-set.png), [change during rest](v3-app-09-switch-rest.png) |
| Review | [Grouped sets](v3-app-11-grouped-sets.png), [15 reps / 295 kg summary](v3-app-12-summary.png), [weekly reps](v3-app-13-reps-chart.png) |
| Splits | [List](v3-app-14-splits.png), [Monday detail](v3-app-15-split-detail.png), [comparable progress](v3-app-16-before-after.png) |

## Motion and larger text

[Phone down → rest → progress](phone-rest-progress.mp4) is a 22-second, normal-speed excerpt of the actual simulator recording, with cuts between the three scenes and no audio. It demonstrates implemented motion, not a measured user preference.

[Rest at larger text](v3-accessible-rest.png) and [comparison at larger text](v3-accessible-comparison.png) show dark appearance and increased contrast. These captures do not certify the entire accessibility journey.

[Zero-rep choices](v3-zero-reps.png) and [recorded attempt returning to rest](v3-attempt-rest.png) come from a temporary review fixture. Record attempt, Edit reps and Discard set were operated directly; the fixture was removed from the review preview afterward.

See [VALIDATION.md](../../VALIDATION.md) for test results, device configurations and remaining limits. Physical haptic feel, sound levels and user preference cannot be established by screenshots. Focus remains simulated.
