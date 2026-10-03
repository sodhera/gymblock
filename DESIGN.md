# GymBlock design

Follow `docs/ONBOARDING-JOURNEY-V2.md` for the current onboarding; `docs/PROGRESS-AND-ONBOARDING.md` for visible finishing and training totals, `docs/GYM-FLOW-REVIEW.md` for the latest page review and navigation/rest corrections, and `docs/REDESIGN-PLAN.md` for the complete intent map, onboarding, screen budgets and edge-case rules. The approved redesign replaces the earlier blue dashboard and six-step preference/paywall onboarding.

## Visual system

The 3 October visual revision uses the native Speaking Coach as a read-only reference, following the user's explicit correction to copy its font and placement. Its Home, welcome and live-practice screenshots and `Typography.swift`, `Theme.swift`, `HomeView.swift` and `MorningStage.swift` informed the implementation. This supersedes the earlier SF-only, flat-background and single-line-streak visual direction.

Red remains the sole accent: #C92535 in light appearance and #FF626B in dark appearance, with higher-contrast variants. Warm paper #F3EFEB, warm ink #231A1B, and soft #FFFCF9 content surfaces reproduce Speaking Coach's temperature while retaining GymBlock's deeper red. Dark appearance has its own warm near-black ground and lighter ink. A restrained 22-point dot grid appears behind content; it is removed with increased contrast or Reduce Transparency.

Bundle the same unmodified DM Sans variable font and its SIL Open Font License. Use its weight and optical-size axes: hero 600, titles/labels 500, body 400. Use scaled text for accessibility, with 28-point Home greetings, 22-point section headings, 32-point exercise/onboarding titles, 17-point body and 12–15-point supporting copy. Weight/reps/rest use an already-scaled 72-point numeric role; weight units use a smaller baseline-aligned label. Elapsed timers remain on one line and fit their available width at large text sizes without clipping digits. Native navigation titles use the same family. Do not substitute another font silently.

Use 24-point page margins, 20–24-point card insets and 24–28-point section spacing. Speaking Coach's soft 26-point surfaces group distinct tasks: streak and the current set. Do not put every row in a separate card. The streak has a large value and a truthful seven-day activity row. Home starts with a personal time-of-day greeting and has no duplicate navigation wordmark.

Keep native Liquid Glass on functional controls and navigation, with native bordered fallback below iOS 26. Solid workout content provides clear numbers. Shadows are subtle; the primary red action has a restrained glow. No new routes, setup steps, explanatory paragraphs or extra workout controls are added for decoration.

## Structure

Native bottom navigation has Home, History and Splits. Home has a compact streak, a plain workout choice and a bottom Start workout action; it has no lift records or separate workout card. History owns finished workouts, older stats, lift records and split progress. Settings remains a small sheet. A split starts directly at its first exercise; Free workout starts at native search/recent exercises.

Ready → Start set → actual Reps completed → Finish set → rest → Start next set. One primary action stays near the bottom. Rest elapsed counts upward from saving and continues across exercise selection, tabs and relaunch. Change exercise is visible before, during and after a set. During an unfinished set it offers save/discard/keep training; completed work retains its original exercise and the split template stays unchanged. Exercise changes retain rest and independent values. End workout stays visible in the native workout navigation bar. Uncommon actions belong in Workout options or the saved-set editor, not a grid of controls.

First-time exercise weight is explicitly chosen; unknown reps stay blank. Record actual completed reps regardless of prior values. Attempts are distinct from completed sets and never count as lift records or training streaks. Corrections update the same record. Deleting the most recent accidental set cancels only its own rest; undo restores its original rest start when no new active set has started. Timed exercise records actual elapsed duration or an explicit correction.

Progress has a neutral first result and red latest result. Compare weight with reps held constant, or reps with weight held constant. History → Progress also offers a dedicated Training totals page with reps, logged-load volume and set counts in trend/bar views, scoped to all workouts or a split. These show work performed, not strength. Charts live behind History. Reduced Motion shows the final comparison immediately. Never invent a combined strength or body-change score.

## Onboarding and data

The onboarding follows `docs/ONBOARDING-JOURNEY-V2.md`: Welcome → days/week → visit length → reps → sets → exercises → scrolling → optional minutes → rest timing → logging/review → set timing → focus → rest → progress → ready. Each number question has one inline wheel; frequency has one seven-value rail, replaced by a wheel at accessibility sizes. No duplicate hero values, preset pills, pencils or routine summary compete with the answer. One pinned Continue confirms the working value. Skipped/unconfirmed values remain unknown.

Questions come before explanations. Three chapter indicators remain stationary. The center uses DM Sans medium 28-point questions, red numerical story values, a warm red/paper stage and actual native Liquid Glass for functional controls. Brief numerical traces connect the lifting answers; the same set/gap marks carry into rest and the neutral prospective four-week record. The fixed-length visit does not shrink as scrolling withdraws. The rest example counts upward to a clearly labeled illustrative 2:00. The comparison labels its 20 kg / 10→11 reps / 35 sec values as Example. Future workouts are outlines, not completed achievements.

Name/language remain in Settings/options; apps appear only in the optional Focus demo. Yes/Sometimes scrolling opens the minutes wheel; Sometimes requires an actual scrolling-break count before a personal estimate. The later estimate detail handles supersets and multiple visits. Training days stay distinct from older weekly visits. A one-visit/day assumption is visible; multiple daily visits bypass time projections. Partial/invalid answers get qualitative scenes. Four-week projected sets and reps are routine volume, not predicted improvement or body change. Example records never enter History. Just train opens free training with focus disabled; Ready offers Start workout and Go to Home without another feature detour.

Actual Start-to-Finish duration is stored separately from timed-activity minutes. Each recorded gap keeps its source set ID; changed dates invalidate affected gap meaning and deleted sources hide their gaps until undo. Cancelling an unfinished set restores the prior counter. Missed/manual records have unknown timing. History exposes set time and gaps, and Training totals can filter the last 28 days. Corrections never manufacture progress.

Local-only storage and stable split IDs remain required. Demo seeds are explicit, repeat-safe and marked on Home. Existing data must decode without new optional fields. Native large-text layout, increased contrast, light/dark and reduced motion/transparency remain part of review. Capture actual simulator UI for visual changes.

Focus remains simulated: use Focus demo and honest onboarding copy. No real restriction, billing or distribution claim follows from the prototype.

See `docs/ONBOARDING-JOURNEY-V2.md` for the current flow, arithmetic, animation, cue and accessibility contracts. `docs/PROGRESS-AND-ONBOARDING.md` documents the previous revision.
