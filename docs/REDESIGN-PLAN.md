# GymBlock: focus-first redesign

**Approved design specification · Implemented 2 October 2026**

GymBlock should help someone put their phone down and train. Open it, start the workout, record a set, and return to the exercise. Every screen must make the next action obvious without requiring an explanation.

The redesign uses one red accent, native Apple typography, and Liquid Glass for navigation and important controls. The larger change is removing decisions and information from moments when they are unnecessary.

The approved screen structure, onboarding and workout edge cases are implemented in the native prototype. `AGENTS.md` and `DESIGN.md` now reflect this specification. See [VALIDATION.md](../VALIDATION.md) for simulator evidence and remaining limits. Real Screen Time blocking and the proposed user study comparing animation preferences remain future work.

## 1. What the previous design got wrong

This reviews the previous SwiftUI screens and captured simulator UI, not an observed user study. The likely intent and confusion below are hypotheses to test.

| Current surface | What competes for attention | Why it gets in the way | Decision |
| --- | --- | --- | --- |
| Home | Brand label, large greeting, streak sentence, seven circles, workout button, selector, disclaimer, records, explanatory copy, last workout, history | Starting and reviewing feel equally important; the page reads as a dashboard | Remove the greeting and full recap. Keep the workout action, one short consistency line, and three compact lift rows |
| Onboarding | Language, name, training categories, favorites, blocking choices and a pretend subscription | People configure a product before understanding what it does | Explain the purpose first; ask quick routine/distraction questions, show a clearly attributed personal summary, then offer focus setup |
| Exercise selection | Large title, custom search box, separate rounded cards, category text and instructions | Styling makes a simple list feel like several different components | Native search and plain rows; recent exercises first |
| Set setup | Unit switch, weight panel, picker, steppers, two help sentences, previous set, full logged history | Too many ways to act are exposed together | One editable weight, one last-set line, one primary action |
| Active set | Focus header, session timer, exercise title, set status, set timer, weight, reps and history | Logging requires scanning a dashboard during a workout | Exercise, weight, reps and Finish set only; one compact focus status |
| Rest | Timer, three rest presets, weight controls, previous set, history and two actions | Rest becomes another configuration screen | Countdown, next set, Start next set; edits on demand |
| Progress | Duplicate split naming, big title, bars, replay control, chart and explanations | Several representations compete to explain one change | Before/after comparison first; detailed history one tap away |
| Summary | Celebration mark, recap card, set card, split toggle and name field | Finishing becomes another task | Short saved result and Done; optional actions in a menu |

The blue actions and blue numbers also overpower the intended red identity. Changing only those colors would leave the interaction problems intact.

## 2. Rules for every design decision

1. **One primary action per state.** Its label says exactly what happens: Start workout, Start set, Finish set, Start next set, Done.
2. **Show information when it changes a decision.** Rest settings belong behind the timer; history belongs outside the active set.
3. **Remember routine choices.** Preserve split, units, last weight, reps and rest duration. Never require the same setup every workout.
4. **Keep orientation stable.** Exercise title stays at the top; the primary action stays near the bottom. State changes update the same screen.
5. **Make recovery easy.** Correct a saved set, change exercises, and resume after closing the app without reentering everything.
6. **Minimal does not mean hidden or cryptic.** Use short text labels, recognizable controls and generous touch targets. Avoid gesture-only actions.

Visible copy budget at default text size: Home has no paragraphs; active set has no instructional prose; rest has no preset-button row; onboarding has one short paragraph per screen. Errors and accessibility needs can exceed these budgets. Never truncate essential information to satisfy a count.

## 3. Navigation and intent

Use one Home with two clear destinations: **Progress** and **Settings**. An active workout occupies its own full-screen flow. Do not add a tab bar just to showcase glass.

Settings retains **Splits**, units, language, focus apps and data preferences. The Home workout selector also offers **Manage splits**, so someone choosing a workout does not need to discover Settings first.

| Person's intent | What they press | What happens | Unnecessary step removed |
| --- | --- | --- | --- |
| “Let me train” | Start workout | Starts the session; opens recent exercises for Free workout | No workout naming or mandatory template |
| “Do my usual split” | Start workout with Arms visibly selected | Opens the first exercise ready to start, with previous values | No repeat exercise selection |
| “Do something different today” | Workout selector → Free workout or another split | Changes this session's starting choice | No editing the saved split |
| “Find dumbbell curls” | Search → type “dum” → result | Opens its weight and Start set | No category maze or detail page |
| “Use 22.5 kg” | Weight → type or use wheel → Done | Updates the same value, returns to ready state | No separate setup wizard |
| “Record the set I just finished” | Adjust reps if needed → Finish set | Saves once and starts rest immediately | No confirmation or log screen |
| “I'm ready again” | Start next set | Starts immediately with the retained values | No wait-for-timer gate |
| “Move to another exercise” | Next exercise or Change exercise | Opens the next split exercise or recent/search sheet | No trip through Home |
| “I'm finished” | End workout | Saves and ends focus, then shows a short result | No naming, ratings or required recap review |
| “Did I improve?” | Progress → exercise | Shows first/latest comparable sets in the selected split | No search through entire workout logs |

**Tap targets, excluding typing and optional value edits:** repeat a selected split to first active set: 2 taps; Free workout using a visible recent exercise: 3 taps; log unchanged reps: 1 tap; begin another set: 1 tap. These are design targets, not measured results.

The minimum is not always zero. Keep an explicit Start set so the user controls when lifting begins; never auto-start because they selected an exercise or the rest timer expired.

## 4. Screen specifications

### Home: “Start my workout”

Top: a small GymBlock title and standard Settings control. Below: **6-week streak** as a quiet single line, with details available on tap. This means consecutive weeks containing a logged workout; rest days do not break it.

The central action area contains **Arms ⌄** or **Free workout ⌄**, followed by the prominent red **Start workout** button. Remember the last selection and keep its name visible before starting. Do not silently choose a split based on the weekday.

Below the action: **Best lifts** with up to three plain rows, such as `Bench press · 85 kg × 5`, and **Progress**. Values use normal text color. History lives inside Progress. Empty accounts get one line, “Your best lifts will appear here.”

Remove the large personal greeting, decorative week circles, last-workout card, helper paragraphs and cards around every row. Do not remove the requested lift records or streak to achieve minimalism.

If a workout is already running, the primary action becomes **Resume workout** with its exercise name. Never create a second session accidentally. A sample-data build carries a compact **Demo** label; focus simulation has its own truthful status.

### Exercise choice: “What am I doing?”

Use a native search field, recent exercises and simple list rows. No card backgrounds or extra descriptions. Search remains optional when a recent exercise is visible. Show **Add “…”** only when a meaningful search has no suitable match; custom creation stays in a small sheet.

Within a split, start on the first exercise. Tapping its title opens the ordered exercise list, with completed-set counts. Users can skip, reorder their session or search beyond the split without changing the saved template.

### Ready: “What weight?”

Show the exercise name, `Set 1`, a large editable **20 kg**, a quiet `Last time: 20 kg × 10`, and **Start set**. The exercise name has a familiar disclosure affordance for changing it.

Tapping the weight opens one editor with manual entry and a native wheel. Support 1–500, fractional weights and an explicit bodyweight/zero case. Start near the current value; never require scrolling from 1. Keep quick +/− controls inside the editor. Selecting the number selects its contents for replacement. Remember units in Settings; an in-editor unit menu makes an occasional switch possible.

Invalid input gets one specific inline message and preserves the draft. Done commits a valid value; Cancel restores the previous value. Do not silently round a manually entered fraction to the wheel's step.

### Active set: “Finish and record”

Show exercise, weight, one editable **Reps completed** number, and **Finish set**. Reps default to the last set or last session and remain editable with +/− or direct input. Until Finish set is pressed, this value is only a draft: nothing is counted or saved as completed. The number is an entry, not a live sensor count. A compact **Set options** menu contains uncommon actions such as Cancel set and Record unsuccessful attempt. See section 9 for exact edge-case behavior.

Remove the running set timer for strength exercises, logged-set table and instructions. A duration-based exercise substitutes its timer and elapsed duration for reps. No animation asks for attention while the person is lifting.

Use **End workout** in the top toolbar, never the ambiguous **Finish** beside **Finish set**. If a set is active, ending presents clear choices: **Save set and end**, **Discard current set and end**, **Keep training**. Validate the entered reps before saving.

### Rest: “Recover, then go”

Finish set saves once and immediately changes the same screen to **Rest · 0:59**. Show one compact `Saved: 20 kg × 10` row that opens correction, a next-set weight value and **Start next set**. Tapping the countdown edits rest duration; retain the choice. Remove the permanent 30/60/90 controls.

At zero, give one optional gentle haptic and change the label to **Ready**. Stay on this screen. Do not auto-start or add a dismissal step. For a split, show **Next: Hammer curl** as the secondary action; freestyle uses **Change exercise**. Tapping either prepares that exercise but leaves the current rest deadline intact until Start set.

The set correction sheet supports changing reps/weight or deleting an accidental set. Edits update history once; they do not create another set or restart rest. Deleting the most recent accidental set cancels only its own rest, as specified in section 9. Full session records are available from a compact **Sets** toolbar item outside the active lifting state.

### Completion: “Put the phone away”

Show **Workout saved**, duration and set count, then **Done**. No mandatory celebration, full set list, score or rating. **View workout** and **Save as split** are optional menu actions; saving a split requests a name only after selection.

End focus before showing completion. Reopening after an interruption restores the correct state and elapsed rest time. An empty session can be discarded without creating false history or a streak.

### Splits and progress: “Plan once; see what changed”

Split creation stays one native editor: name, ordered exercises, Add exercises and Save. No required days, schedule, targets or rest configuration. Existing saved splits and stable IDs survive the redesign.

Progress opens with the current split already selected. Show its exercise rows and a History entry. Each exercise opens **15 kg → 20 kg**, labeled with dates and **at 10 reps**. A neutral first bar and red latest bar animate once for about half a second. Put the detailed chart and session list behind **History**; remove the dedicated replay button.

For load changes, compare only the same exercise, split and rep count. For rep changes, hold exercise, split and weight constant; section 9 specifies how to choose the comparison. Show an honest decrease or unchanged result without a celebration. One matching session says **First recorded set**. Free workouts remain visible in history; do not pretend their records belong to a split. Do not invent an overall strength score. Reduced Motion shows the final comparison immediately.

## 5. Onboarding: understand their routine, then make the benefit personal

This replaces the earlier two-screen proposal. Include language, name, distracting apps, usual gym duration, exercise count, sets and reps. Ask for rough answers through familiar controls; do not make someone build a full training program before trying the app.

**Sequence:** Welcome → Distractions → Gym time → Usual workout → Scrolling time → Personal summary → Focus setup → Home.

Seven short app screens, with optional system authorization/selection sheets at the end. Design target: roughly 60–90 seconds for a person who knows their routine, excluding system permissions; validate this rather than advertising it as proven. Back preserves answers. Skip setup always leads to a usable Home. No automatic page advance when selecting an answer.

### Screen 1 — language, name and purpose

Title: **Your workout deserves your attention.**

Body: “A quick scroll can become a long break. Keep your attention on the next rep.”

Use a small **Language** menu, initialized from a supported device language, and one optional field: **What should we call you?** Name is optional; skipping gives Home a neutral title rather than inventing a name. Changing language immediately translates the remaining flow and preserves the name. Use localized number entry and units.

Primary: **Continue**. Secondary: **Skip setup**. No account, email, training-category grid or decorative hero graphic. This screen earns the questions that follow by explaining the purpose first.

### Screen 2 — what pulls them into scrolling

Title: **Where do you get caught scrolling?**

Present six plain multi-select rows: **Short videos**, **Social feeds**, **Video platforms**, **News & forums**, **Other**, **None**. Optional familiar examples such as Instagram or YouTube can be secondary text; a row must not imply the app is installed. None is exclusive. Include **Not sure** as a skip answer. No category is preselected.

Primary: **Continue**. Store self-reported categories only. These answers personalize the summary and focus explanation; they are not permission to access usage or block every app in a category. Choosing None bypasses the scrolling-time question and yields a tracking-first result.

Actual apps to block are selected later through the supported system flow. This separation avoids asking for system permission before the person understands the benefit and prevents the questionnaire from pretending to inspect their device.

### Screen 3 — their time in the gym

Title: **How long is a usual gym visit?**

One large editable minutes value, with quick choices **30 / 45 / 60 / 90 / Other**. No answer is silently submitted by default. Define the interval in one short line: **From starting your workout to finishing.** It includes rests and exercise changes, not travel or changing clothes.

Below, a single optional row: **Workouts per week**, using direct number entry or a small picker. This makes weekly totals possible without a separate question page. Include **It varies / Not sure** for both values; uncertain answers stay unknown rather than becoming the midpoint of a fabricated estimate.

Primary: **Continue**. These are descriptions of their current routine, not recommended durations or frequency.

### Screen 4 — enough workout detail, without a programming task

Title: **What does a usual workout look like?**

One compact native form with three rows:

| Row | Quick entry | Why ask |
| --- | --- | --- |
| Exercises | Common counts 3 / 4 / 5 / 6, plus direct entry | Describe the approximate size of a usual session |
| Sets per exercise | 2 / 3 / 4, plus direct entry or Varies | Estimate total sets when the routine is reasonably uniform |
| Reps per set | 5 / 8 / 10 / 12, plus direct entry, range or Varies | Capture their usual logging preference and approximate rep volume |

The choices are shortcuts, not recommendations, and no value is treated as an answer until selected. Show one summary, for example **6 exercises · usually 3 sets of 10**. Do not animate counters or add an explanatory paragraph under every field.

**Different for each exercise?** opens an optional editor using the entered count: Exercise 1, Exercise 2, and so on. Each row has sets and reps; names are optional. Allow a rep range such as 8–12 and per-set overrides such as 12, 10, 8 without making these mandatory. The person can return to the typical-values answer. If there are many exercises, use a scrollable list and never add another onboarding screen per exercise.

Include **Mostly timed exercise** and **Not sure yet**. Timed/mixed routines can skip rep estimates; never coerce cardio into a strength model. Do not require exercise search, weights, a split name or a schedule here.

Primary: **Continue**. Store these values as a baseline questionnaire, not completed sets, a prescribed program or an automatically created split. Unnamed Exercise 1 must never appear as a fake exercise in real history. Actual prior workout values take priority over these rough defaults; the completed-rep field stays editable as specified in section 9.

### Screen 5 — ask about scrolling instead of guessing it

Title: **About how much of that visit goes to scrolling?**

Quick choices: **None / 5 min / 10 min / 15 min / Other / Not sure**. Direct entry remains possible. Helper text: **Think feeds and videos, not music or logging sets.** The response is explicitly self-reported.

Primary: **Continue**. Keep this separate from necessary recovery time: scrolling can happen during a rest someone still needs. Ask no follow-up demanding that the person account for every minute. If the answer exceeds their total session duration, offer to edit either answer; do not silently clamp it. If gym time was skipped, accept scrolling time without inventing a session duration.

### Screen 6 — a useful personal result

Title: **Make more room for your workout.**

For a person who entered 60 minutes, 3 visits per week, 6 exercises, 3 sets of 10 and 10 scrolling minutes per visit, show:

- Main statement: **About 30 minutes a week on feeds.**
- Small attribution: **Based on your estimate of 10 minutes per workout.**
- One collapsed **Your routine** row: **60 min · about 18 sets**, with the editable answers and weekly gym-time total inside.
- One short purpose line: **Keep the rest you need. Leave the feed for later.**

Do not show a wall of statistics. Reps inform the routine detail and logging defaults; they need not become another prominent number. A neutral-to-red transition may show estimated feed time beside a user-chosen reduction goal, but only after a goal is explicitly selected. Never label a hypothetical smaller value **With GymBlock** or treat an animation as a prediction.

Primary: **Set up focus**. Secondary: **Start without blocking**. The primary advances to screen 7; the secondary goes to Home. If desired, an optional **Choose a goal** control opens a sheet: **5 fewer minutes on feeds per workout**, editable. That goal describes intended behavior, not measured saved time or a faster optimal workout.

For None/zero scrolling, show **Keep your workout simple**, with their routine if known. For unknown scrolling time, show **Find your rhythm over your next few workouts**. Do not invent a loss estimate to make this screen persuasive. An occasional optional self-report after a workout can supply a later baseline without interrupting every session.

### Screen 7 — turn intent into a focus choice

Title: **Keep your attention on the next rep.**

Production copy, only once real blocking works: “Choose the apps to pause while you train. They return when you end your workout.” Primary: **Choose apps**; secondary: **Not now**. Request authorization here, explain denial without pressure, and use the native app selector when available. Selecting distractions earlier does not automatically select or block installed apps.

After selection, go directly to Home. Do not add a success page, repeat the questionnaire or require a first split. Keep blocking active during rest and provide an explicit end-workout route. Never condition release on completing reps, a set target or an estimated optimal time.

**Current simulator version:** heading **Try workout focus**; body “This demo previews focus mode. It doesn't block other apps.” Primary **Try demo**, secondary **Not now**. No fake permission prompt. Active sessions say **Focus demo**; a future denied/unavailable capability says **Focus off**. Logging must work without blocking.

Remove the placeholder paywall from this prototype's first-run path. Subscription placement is a separate decision once the paid capability works. No fake analysis/loading screen, compulsory body measurements, guilt copy or multi-page sales reveal.

### What we can calculate honestly

Use user answers, preserve unknown values, and keep units and assumptions attached to every result:

| Quantity | Calculation and interpretation |
| --- | --- |
| Estimated weekly gym time | Usual session minutes × reported visits/week. Description of their routine, not measured attendance |
| Estimated sets per session | Sum of per-exercise sets, or exercise count × typical sets. Label approximate for typical values |
| Estimated reps per session | Sum of per-set reps; for uniform input, exercises × sets × reps. Carry ranges through; do not turn 8–12 into an exact 10 without saying so |
| Estimated weekly feed time | Reported scrolling minutes/session × visits/week. Show only when both are supplied |
| Desired reduction | User-selected fewer feed minutes/session × visits/week. Label Goal, never Time saved |
| Observed workout elapsed time | Saved workout end minus start, with interruptions and corrections represented honestly. This is an app-timed interval, not automatically actual gym attendance |

For the example: 60 × 3 = **180 gym minutes/week**; 6 × 3 = **18 sets/session**; 18 × 10 = **about 180 reps/session**; 10 × 3 = **about 30 feed minutes/week**. A chosen five-minute reduction is a **15-minute weekly goal**, not a predicted app result. Do not extrapolate a year of savings from one rough answer by default.

Never calculate **wasted time = gym duration − reps × supposedly optimal seconds per rep**. That remainder includes legitimate rest, warm-up, exercise transitions, equipment waits and other unknowns. Even measured phone use is not automatically removable gym time. Removing a feed from necessary rest can improve the person's experience without shortening the visit.

Do not collect tempo and rest prescriptions merely to produce a more authoritative-looking number. A future workout planner may estimate a time range from explicitly chosen set durations, recovery, warm-up and transitions; it must call that a schedule estimate, not physiological optimal time or proof of distraction.

### Mind–muscle connection and body-change claims

Use the phrase in an optional **Why focus?** detail, not as another required page:

**Put your mind back on the muscle.** “Keep your attention on the movement and the muscle you're working. GymBlock helps you keep distracting apps out of the way while you train.” Use “previews keeping distracting apps out of the way” in the simulator version. Do not imply the app senses attention or verifies technique.

There is no defensible conversion from these onboarding answers to **pounds of muscle gained with GymBlock versus without**, or **pounds of fat lost because of GymBlock**. Do not create these numbers, before/after bodies, percentage multipliers or a fake control-group curve. Marking an invented body prediction “estimated” would not provide evidence for it.

Evidence informing this decision:

- The 2026 ACSM position stand reports that resistance-training outcomes depend on the training variables considered and that time under tension did not consistently change outcomes. It does not supply one universally optimal session duration. Our product inference: reps and sets alone cannot diagnose wasted gym time. [ACSM position stand](https://pmc.ncbi.nlm.nih.gov/articles/PMC12965823/)
- In one randomized eight-week study of 21 trained men, three-minute rests produced better results on several strength/muscle measures than one-minute rests. This is not a universal prescription; it is evidence against treating shorter rest as automatically better. [Rest-interval trial](https://pubmed.ncbi.nlm.nih.gov/26605807/)
- An eight-week internal-versus-external attention study involved 30 untrained college-aged men. It found a difference in elbow-flexor thickness, while quadriceps changes were similar. It did not test GymBlock, compare scrolling with blocking, measure whole-body pounds of new muscle or establish fat-loss effects. Do not translate its results into an app-specific outcome promise. [Attentional-focus trial](https://pubmed.ncbi.nlm.nih.gov/29533715/)
- Health-related product claims need evidence relevant to the actual product and claimed outcome. A general exercise study is not evidence for an app's pounds-gained or pounds-lost claim. [FTC health-products guidance](https://www.ftc.gov/business-guidance/resources/health-products-compliance-guidance)

The immediate benefit to demonstrate is fewer chosen distractions and easier workout logging. Future outcome claims would need properly designed product-specific research and appropriate outcome measurements, not a more elaborate onboarding formula. Self-reported goals can personalize language without making a body-composition prediction.

### Other decisions needed for a usable onboarding

- **Every answer has a purpose:** name is optional personalization; categories inform focus setup; duration/frequency explain time; sets/reps describe the routine; scrolling minutes support the estimate. Drop questions that do not affect a visible result or useful preference.
- **Usual does not mean every:** allow Varies, ranges, unknown values, mixed routines and different sets per exercise. Do not force precise recall or treat skipped input as zero.
- **One consistent pattern:** short title, native entry controls, one primary Continue action, Back, and a quiet skip route. Keep choices on one screen at standard text size; allow scrolling and reflow at larger sizes. No dense card grid.
- **No hidden defaults:** show suggestions as suggestions. Only explicitly supplied values become self-reported facts. Existing exercise-specific history overrides general onboarding hints.
- **Edit and resume:** persist a draft after each answer; survive closing the app; resume on the same page. Editing gym duration, frequency or scrolling updates downstream summaries. Reducing exercise count must confirm before discarding detailed answers.
- **Uncertainty stays visible:** ranges generate ranges; missing values suppress the associated result. A zero answer is valid. Inconsistent inputs prompt a simple correction, never an accusation of lying or wasting time.
- **Time is not attention:** foreground/background events, blocked launch attempts, a timer running and total session duration do not establish doomscrolling time, mind–muscle connection or causal savings. Any future device-usage measurement needs a capability/permission review before promising it in the UI.
- **Local data and privacy:** store baseline answers locally, separate from real workout history and demo data. App categories and routines do not need analytics or account creation. Provide edit/reset/delete controls in Settings. Do not request body photos, body weight, sex or age just to fabricate more personalized predictions.
- **Honest comparison later:** show self-reported baseline and observed/self-reported follow-up with dates and clear source labels. A shorter session could reflect fewer sets; compare like routines and never attribute the difference to the app automatically.
- **First-use testing:** include a beginner, someone with variable splits, a non-strength routine, a zero-scrolling person, a permission-denied case and a returning user. All must reach a functional Home without invented data or a blocked path.

### Onboarding acceptance checks

1. A person can supply language, name, distractions, duration, exercises, sets and reps without searching for individual exercises.
2. Varies/Not sure/Skip never blocks access to the workout and never generates fake data.
3. The 60-minute / 3-visit / 6-exercise / 3-set / 10-rep / 10-scrolling-minute example produces the totals above, with approximate/self-report labels.
4. Per-exercise variations and rep ranges produce the correct totals/ranges; unknown timed portions remain unknown.
5. Zero scrolling produces no warning or deficit; missing frequency produces no weekly extrapolation.
6. No screen calls necessary rest wasted time, promises pounds of muscle/fat change or labels a target as a measured app benefit.
7. Questionnaire selections never masquerade as installed-app access, granted permissions, completed workouts or a configured split.
8. Local answers survive Back/relaunch, can be edited/deleted, and stay separate from sample history.
9. Observe completion time and hesitation with new users. If the flow exceeds the target or people struggle with exact routine recall, shorten optional detail before adding explanations.

## 6. Red, typography and Liquid Glass

### Red is the only brand accent

| Role | Treatment |
| --- | --- |
| Primary action | Deep red starting candidate `#C92535`, light label; final contrast verified in rendered controls |
| Selected controls | Adaptive red tint; selection also has a checkmark or native selected shape |
| Dark appearance accent | Brighter red starting candidate `#FF626B`; keep filled-button label contrast separate from link tint |
| Text and numbers | System primary/secondary label colors; remove blue ink and navy headings |
| Background | System neutral background, white in light appearance and near-black in dark appearance |
| Progress | Neutral baseline and red latest value, with dates and explicit numeric change |
| Destructive action | Native destructive role and explicit “Delete”/“Discard” wording in a separate menu or confirmation |

These hex values are starting design candidates, not certified accessible colors. Create light, dark and increased-contrast variants. Red communicates brand emphasis; never rely on it alone to distinguish normal completion from deletion or a positive from a negative change. Apple recommends consistent color meaning and appearance-specific contrast. [Apple: Color](https://developer.apple.com/design/human-interface-guidelines/color?changes=_5_2)

### Typography should feel native and calm

Use the system San Francisco family, default design. No rounded display font, condensed gym font, spaced all-caps eyebrow labels or repeated giant headings. Apple identifies SF as its neutral system typeface. [Apple: Fonts](https://developer.apple.com/fonts/)

Proposed hierarchy: native inline navigation title; exercise title in Title 2 semibold; labels/body in Body; supporting information in Subheadline; weight/reps/rest in a scalable 44–56 pt semibold numeric style with monospaced digits. Only the number currently being acted on gets display-scale emphasis.

Use semantic text styles and layouts that reflow at accessibility sizes, including vertical stacking and taller rows. Never shrink important text to preserve an attractive screenshot. [Apple: Layout](https://developer.apple.com/design/human-interface-guidelines/layout?changes=lat_3__1_2)

### Glass has a job

Use Liquid Glass on the native navigation/toolbar layer, sheets' system chrome and the important action control. Keep weight, rep numbers, records and charts on quiet content surfaces. Avoid glass cards nested inside glass, translucent number panels, simulated reflections and decorative blurred backgrounds. Prefer regular glass over the clear variant for these text-heavy controls. This follows Apple's separation of controls from content. [Apple: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)

Prefer standard SwiftUI components and supported glass button styles. Remove custom toolbar backgrounds that hide the native treatment. On older supported iOS versions, retain ordinary native controls with the same hierarchy. System appearance, Reduce Transparency and Reduce Motion must remain effective. [Apple: Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass?changes=la__9)

Use standard margins and native shapes; introduce custom components only where the workout interaction needs them. Minimum touch regions are 44 × 44 pt; aim for a 52–56 pt primary workout action. Labels remain visible, with VoiceOver names and values. [Apple: Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)

## 7. Trace intent and verify the design

For each walkthrough, record **starting state → intended task → expected next button → actual button → resulting state → hesitation or recovery**. A wrong turn is evidence to revise the interface, not evidence that someone needs a tutorial.

Begin with observed sessions and local test traces. Do not add production analytics or upload workout data for this redesign. An optional debug trace can record screen/state, action and transition with elapsed time; exclude names, exercise search text, weights, reps and app-selection details. Clear it after the study.

| Test task, without coaching | Success condition |
| --- | --- |
| Explain the app and personal summary after onboarding | Person understands focus, self-reported time estimates, and that the current build is a demo |
| Start Arms, then deliberately choose Free workout | Selection is understood before starting; no accidental split modification |
| Find a dumbbell exercise, enter 22.5, then enter 120 manually | No long wheel scrolling or help sentence needed |
| Start a set, log 8 reps, then begin another before rest ends | Correct record, automatic rest, no uncertainty about Finish set versus End workout |
| Correct the saved set and switch exercises | No duplicate record, no lost workout, no need to return Home |
| Close and reopen during rest | Same workout and correct remaining time |
| Create Monday and inspect its progress | Split creation is discoverable; comparison labels are understood |
| Use large text, VoiceOver and reduced visual effects | Controls stay reachable; numbers and state remain understandable |

Try with five people who have not seen the design. Target at least four completing each core task without coaching; any data-loss error or confusion between ending a set and a workout requires a fix regardless of the count. Record time-to-first-set and number of wrong turns, but treat a small sample as directional evidence rather than proof that everyone prefers the design.

The progress animation is the previously selected before/after concept. Test whether people understand the change and can ignore it when busy; do not equate a visual preference with better workout focus.

## 8. Implementation order and completion criteria

1. **Approve the structure:** low-detail layouts for Home, Ready, Active set and Rest, plus the revised onboarding sequence in section 5. Verify button destinations before adding materials.
2. **Build the workout state flow:** preserve existing data, splits and identifiers; implement resume, saved-set correction, rest continuity and safe session ending.
3. **Apply the visual system:** red tokens, system typography, standard navigation and restrained Liquid Glass. Remove old blue accents and custom card patterns throughout, including onboarding, Settings and progress.
4. **Simplify secondary pages:** compact records, optional split editor, comparison-first progress and short completion.
5. **Verify on device-sized UI:** clean first run and populated demo; light/dark, large text, Reduce Motion, Reduce Transparency and increased contrast. Capture actual simulator screens and the Ready → Active → Rest loop. Follow with physical-iPhone handling tests before calling the workout ergonomics proven.
6. **Run the intent walkthroughs:** fix hesitation and wrong turns, then review the final screens against this document.

Done means every core state has one obvious next action; the user never has to scroll to Finish set or Start next set at normal text size; ordinary repetition meets the tap targets; a split is optional; records and progress remain accessible; data survives interruptions; red is the sole brand accent; and focus capability is described truthfully.

Real Screen Time blocking, purchases, release delivery and new backend services are not implemented by this design plan. The focus-onboarding production copy is conditional on that capability being verified. The immediate deliverable is a coherent, minimal simulator experience whose limitations are clear.

## 9. Real workouts: exceptions without extra screens

### The central rule: record what happened

**Planned reps, previous reps and completed reps are different things.** The first version does not require a rep target. `Last time: 20 kg × 10` is context, not an instruction to achieve ten. If targets are added later, store them separately and never replace the actual result with the target.

For example, someone previously did ten reps. Today they do twelve: change the number to 12 and Finish set. Tomorrow they manage seven: enter 7 and Finish set. Both use the ordinary flow and start rest. Neither requires a reason, a special completion screen or permission to deviate.

GymBlock is recording these decisions, not prescribing what weight or rep count is appropriate. Do not automatically increase the weight after extra reps, reduce it after fewer reps, or label either result good or bad without the relevant context.

### Behavior by situation

| Situation and likely intent | User action | App response and saved result |
| --- | --- | --- |
| “I did 12 instead of 10” | Change Reps completed to 12 → Finish set | Save 12 at the recorded weight; begin rest. No target ceiling or extra confirmation |
| “I stopped at 7 instead of 10” | Enter 7 → Finish set | Save 7; begin rest. No failure warning, penalty or demand to finish the remaining reps |
| “I completed 7, then couldn't finish the eighth” | Enter 7 → Finish set | Record seven completed reps. Do not infer why the set ended or invent an eighth rep |
| “I couldn't complete even one rep” | Set options → Record unsuccessful attempt | Save a separate attempt with zero completed reps and the attempted weight; begin rest. Display Attempt recorded, not Set completed. Exclude it from lift records, completed-set totals and progress comparisons |
| “I pressed Start but never lifted” | Set options → Cancel set | Return to Ready with the draft weight retained. Save no set or attempt; do not start a new rest period |
| “That weight was too heavy; I'll use less next set” | Tap next-set weight during rest | Update only the upcoming set. Keep the completed set's original weight and reps |
| “I entered the wrong weight or reps” | Tap the saved-set row → edit → Save | Correct the existing record, recompute records/progress, and retain the current rest deadline |
| “I finished by accident” | Saved-set row → Delete set | Remove the erroneous record. If rest belongs to that just-deleted set and no new set has started, return to Ready and cancel that rest. Deleting an older set never changes the current timer |
| “I did an extra set” | Start next set | Add another set normally. No fixed set count, required template edit or workout restart |
| “The bench is busy” | Next exercise or exercise selector → another exercise | Keep completed sets and per-exercise drafts. Permit returning later; do not mark the skipped exercise complete or alter the saved split |
| “I want a longer rest” | Tap the countdown → adjust | Change this rest deadline and remember the preference for later sets; never demand that the person resume at zero |
| “I don't need the rest” | Start next set | End the countdown and begin the set immediately; one tap |
| “I forgot to tap Start set” | Sets → Add completed set | Open a small weight/reps editor, prefilled from the selected exercise. Save once and return to the current state. Mark timing unknown; do not invent a start time or restart rest |
| “I forgot to tap Finish set” | Enter the actual reps → Finish set | Save when explicitly confirmed. Allow correction of completion time from set details; do not present the app's running strength-set time as actual lifting duration |
| “I want to stop the workout early” | End workout | Keep completed work and end focus. When a set is active, offer the save/discard/keep-training choices already specified. Never require completion of the split or a rep target to exit |
| “I double-tapped Finish set” | Two rapid taps | Save exactly one record and start one rest timer; disable repeat submission during the transition |
| “The app closed or my phone locked” | Reopen | Restore the workout and any unconfirmed draft. Rest uses its saved deadline. Never turn elapsed time into completed reps or silently finish a set |
| “I changed kg to lb” | Change unit in the weight editor | Convert the stored load; do not reinterpret the same number as a different weight. Existing history and records remain equivalent |

**Deletion clarification:** ordinary edits never restart rest. Removing the most recent accidental set cancels only the rest created by that record; this is the explicit exception to section 4's general timer-preservation rule. Offer Undo for deletion while preserving the record's identity and original rest deadline, without removing a newer active set.

An unsuccessful attempt belongs in workout details as context. A session with only attempts can be retained as an **Attempt-only session**, but does not generate a lift record or the existing completed-workout streak. An empty session has neither attempts nor completed work. These are distinct states, not interchangeable zero-value records.

### Extra reps must also make sense in Progress

The current same-rep weight comparison cannot explain every improvement. Keep two explicitly labeled comparisons, shown only when relevant:

- **Same reps:** `20 kg × 10 → 22.5 kg × 10`. Compare load within the same exercise and split.
- **Same weight:** `20 kg × 10 → 20 kg × 12`. Compare completed reps within the same exercise and split.

Show the comparison matching the latest set when there is a valid earlier match. If both exist, default to the same-rep weight comparison and make the alternative available in a small comparison menu. The menu is unnecessary when only one comparison exists.

If both load and reps changed and neither comparison has a matching baseline, show the two actual sets and dates without a strength percentage or claim that one is better. A reduction also displays plainly, without assuming regression or criticizing the person. Extra reps do not justify changing the next weight automatically.

The before/after animation must use the relevant unit: kilograms/pounds for load, reps for repetition count. Do not animate a load bar for a rep-only change. Attempted weights are never personal records. Home's Best lifts remains heaviest completed load **with reps beside it**; it is not an estimated maximum-strength score.

### Other workout types: support only what the record can describe honestly

| Case | First-version decision |
| --- | --- |
| Bodyweight movements | Show Bodyweight instead of an unexplained 0 kg. Record reps; weighted bodyweight uses added load. Do not treat zero external load as zero exercise |
| Dumbbells and unilateral exercises | Define load convention per exercise in its details: per dumbbell, and reps per side when applicable. Surface the short unit label when needed and preserve it across sessions. Do not guess totals or compare incompatible conventions |
| Timed holds/cardio | Substitute duration for reps. Allow correction and early finish. Zero duration cannot become completed work |
| Warm-up sets | Optional Mark as warm-up in set details; never a required question. Preserve them in history and separate them from working-set comparisons |
| Supersets | Allow switching and returning between exercises without losing their previous values. Dedicated superset grouping is deferred; do not enforce finishing one exercise first |
| Drop sets | Log each load/repetition segment separately using the normal flow and optional rest skip. Do not merge several weights into a misleading single-weight record. Dedicated grouped editing is deferred |
| Assisted or partial reps | Do not silently mix them with standard complete-rep records. Dedicated tracking and comparison are deferred. If captured in the first version, use a clearly named custom exercise variant so records stay separate |

Do not turn this table into onboarding questions or add every option to the active screen. The visible loop remains **weight → Start set → reps completed → Finish set → rest**. Only Set options and the saved-set editor reveal exception handling. Advanced formats must not delay a usable basic workout.

### Additional acceptance cases before implementation is called complete

1. Given a previous set of ten, twelve and seven both save through the ordinary flow without another screen.
2. A zero-rep attempt at a heavier weight cannot replace a completed lift record or inflate completed-set totals.
3. Cancelling before lifting leaves no false work. A double tap cannot create duplicate work.
4. Editing or deleting a saved set updates all dependent records, history, streaks and progress consistently; the correct timer survives.
5. Switching exercises during rest preserves both their drafts and the rest deadline. Returning does not reset the session.
6. An added historical set does not change an active set or claim precise lifting duration.
7. More reps at the same weight are visible as a rep change; different weights and reps do not produce an unsupported improvement score.
8. A person can end a workout at any time, including after fewer reps, an unsuccessful attempt or an unfinished split. Focus release never depends on a performance goal.

These cases extend the design proposal and require changes to the existing model and tests. They are not claims about behavior already implemented in the current app.
