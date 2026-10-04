# GymBlock: onboarding and app UX reset

**3 October 2026 · Implemented locally, reviewed 4 October 2026**

The approved reset below is implemented. The opening critique describes the previous interface. See [current verification](../VALIDATION.md) and [actual app captures](../screenshots/ux-v3/README.md) for results and remaining limits.

**Next onboarding proposal:** [Clear journey V4](ONBOARDING-CLEAR-JOURNEY-V4.md) documents the user's latest wording corrections and confirmed paywall placement. It is not implemented; V3's onboarding ending remains a description of the current prototype, not the next proposed route.

**Latest refinement:** [Section 13](#13-exact-text-icons-and-placement-contract) defines the final screen copy, five placement templates, icon decisions and additional cuts. Use it over earlier illustrative wording.

This is a critical review of the current app and a concrete replacement specification. It covers the onboarding, the workout loop, navigation, History, Splits, settings, and their secondary screens. It proposes changes to the visual direction in `ONBOARDING-JOURNEY-V2.md`; it does not replace the app's existing data or authorize a broader product rebuild.

The intended experience: **open GymBlock, choose what you are about to lift, start a set, record what happened, and get back to training.** Onboarding should demonstrate that experience. Every visible element must help someone answer a question, take an action, or understand their own record.

## 1. What went wrong

The previous iteration made screens sparse without making them clear. Large empty areas, oversized numbers, rounded boxes, and animated marks are not enough to establish a visual language. The user still has to decode what the app means.

The screenshot is the clearest example:

- **“34 min” has visual authority without enough semantic precision.** It is an estimate of scrolling, not measured wasted time, recoverable workout duration, or a prediction of better results.
- **The pink and gray rectangles do not depict a recognizable thing.** Their internal dashes could be sets, apps, activity, or decoration. A legend explains colors but not the objects.
- **“Phone-free” labels the remainder of a visit as though it were measured attention.** We do not know that. The visit also includes necessary rest, walking, equipment setup, and other activity.
- **“One visit a day · every break · Adjust” exposes a calculation underneath a sales-like reveal.** The assumptions should be reviewable in a clearly named detail sheet, not compete with the main message.
- **“See the difference” promises a transformation the next screens cannot establish.** Another arrangement of the same shapes is not evidence of change.

The problem continues inside the app: the Home tab becomes a workout screen, the exercise name and “Change exercise” do the same job, the weight editor presents several methods simultaneously, History has navigation inside navigation, and Settings contains an ambiguous second routine editor.

Passing tests proves specific behaviors and arithmetic. It does not prove that these screens communicate well. The next implementation must be judged by visible comprehension and task completion as well as correctness.

### Evidence reviewed

| Evidence | What it supports | Limit |
|---|---|---|
| User's supplied 34-minute screenshot | Current reveal hierarchy, confusing shapes, labels and assumptions | One frame, not a recording of its motion |
| Live iPhone 17e simulator | Home, Settings, “Each exercise” editor, exercise search, ready-to-start workout | Did not complete a new set or exhaustively traverse every screen live |
| Current SwiftUI sources | Routes, conditional questions, workout states, editing behaviors, navigation and calculations | Source review does not prove visual quality on every device |
| Stored onboarding captures, including rep comparison and four-week record | Current later-story composition and density | Captures are prior runtime evidence, not a fresh recording |
| Stored Speaking Coach question reference | Typography placement, clear grouping, restrained hierarchy | A reference image, not an audit of its complete current onboarding |
| Apple design guidance listed at the end | Native slider behavior, material placement, hierarchy and controls | Our screen structure and timing choices remain design proposals |

Sources inspected include `OnboardingJourney.swift`, `JourneyArt.swift`, `Navigation.swift`, `Home.swift`, `Session.swift`, `Splits.swift`, `Progress.swift`, and `TrainingStats.swift`.

## 2. Decisions to make before drawing another screen

1. **Use real native Liquid Glass controls.** The seven-day rail becomes a native discrete slider. Do not approximate it with seven custom pill buttons.
2. **Remove the red/gray visit diagrams completely.** Do not polish their corners or add a longer legend.
3. **Replace the explanation tail with three demonstrations: put the phone down, finish a set and see rest begin, compare two recorded sets.** These are things the user can recognize immediately.
4. **Remove the separate “216 sets” presentation page and the empty final readiness page.** Keep useful calculations in optional details. End the last demonstration with “Start workout.”
5. **Use three stable tabs: Workout, History, Splits.** The first tab is the place to train, including its idle state. Settings is a small toolbar destination.
6. **One way to perform each primary action on a screen.** No duplicate exercise switch, no simultaneous wheel plus text field plus stepper for one weight.
7. **Keep the red theme, remove background noise.** No dotted wallpaper, persistent red glow, or white cards around every isolated value.
8. **Explain value through useful records and reduced friction.** Do not promise pounds of muscle, fat loss, or a percentage improvement that our answers cannot establish.

This remains a very small, local workout app. There are no new accounts, social features, coaching feeds, analytics SDKs, billing flows, or real app-blocking implementation in this proposal.

## 3. The visual language

### Typography and composition

Keep DM Sans if its bundled weights render correctly; stop changing fonts to compensate for weak hierarchy. Borrow Speaking Coach's consistent heading position and clear answer grouping, then use a more compact working layout inside the gym.

| Role | Starting specification | Rule |
|---|---|---|
| Onboarding question | 28–30 pt, semibold, centered, natural two-line wrap | One question, no duplicate subtitle paraphrasing it |
| Main numeric answer | 48–56 pt, medium, tabular digits where appropriate | Only when the number is the actual answer or result |
| Workout exercise heading | 24–28 pt, semibold, leading aligned | Can wrap; never truncate the identity of the exercise |
| Body and controls | 17 pt, regular/medium | Familiar labels and explicit units |
| Secondary explanation | 15 pt | One short sentence only when meaning needs it |
| Metadata | 13 pt minimum at default size | Never use tiny text to fit essential qualifications |

These are starting sizes with Dynamic Type scaling, not fixed boxes. At accessibility sizes, allow the content to scroll while keeping navigation usable. Do not shrink text to preserve a screenshot composition.

Use 24 pt side margins at ordinary phone sizes and a consistent bottom action area. Place onboarding headings in a stable upper region, the answer or demonstration in the middle, and the primary action within easy thumb reach. Avoid both top-heavy forms and enormous dead space. At compact heights the spacing contracts before type does.

### Color and material

Use a flat warm near-white canvas, near-black primary text, and a tested secondary gray. Preserve GymBlock red for primary actions and selected state. Red must not simultaneously mean a selected value, failure, danger, and background decoration on one screen.

Liquid Glass belongs to interactive surfaces: the slider thumb, system tab bar, toolbar controls, and suitable native selection controls. Charts, paragraphs, tables, and large numeric answers sit directly on the content canvas. A transparent panel around ordinary text is not inherently an improvement. Apple's guidance places this material in the functional layer and emphasizes hierarchy over decoration. [Apple: new design system](https://developer.apple.com/videos/play/wwdc2025/356/)

Dark mode needs intentionally chosen semantic colors, not an inverted cream screenshot. Reduced Transparency replaces decorative translucency with a solid readable surface. Remove dotted backgrounds and broad colored shadows in both appearances.

### Control matrix: what “Liquid Glass slider” means here

| Input or element | Use | Do not use |
|---|---|---|
| Days per week, 1–7 | Native horizontal slider with seven discrete tick values and the system glass thumb | Custom button rail, seven independent chips, a second editor icon |
| Visit length, reps, sets, exercise count, scrolling minutes | One precise native vertical picker per page, with selection feedback | Preset buttons plus a picker plus a text box |
| Yes / Sometimes / No | Three concise native choice rows with one selected checkmark | A numeric slider for categories, decorative icons, explanatory cards |
| Workout logging habit | “Log and review,” “Log only,” “No” choice rows | Combining two questions into a misleading Yes/No |
| Workout weight | Compact value button; editing sheet with wheel and a switch to direct typing | A 1–500 slider or three input methods visible together |
| Tab navigation | System tab bar with icon and text | A custom floating capsule bar with ambiguous symbols |
| Journey progress | Quiet read-only progress indicator | A draggable-looking handle or seven ornamental status strips |

The frequency slider displays one value, for example **“3 days / week,”** above its track. Show endpoints 1 and 7 and seven tick positions; no second row of seven large numbers. Dragging and supported track interaction snap to whole days. One selection haptic occurs per changed value, not continuously while resting on a tick. VoiceOver announces the value and supports increment/decrement.

Use the native slider configuration available on the supported OS. Apple's UIKit demonstration explicitly supports a Liquid Glass thumb, tick marks, and restricting values to ticks. If SwiftUI cannot express the needed discrete behavior faithfully, wrap the native control; do not recreate its material. Verify on the actual deployment target and provide a conventional accessible native fallback where necessary. [Apple: UIKit design update](https://developer.apple.com/videos/play/wwdc2025/284/)

A slider is appropriate for seven choices. It is not appropriate for precise selection among hundreds of weights. Apple's slider guidance distinguishes approximate selection from exact entry. [Apple: Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders)

## 4. Onboarding: the route and every page

### Shared structure

The route is **your workout → your habits → see how GymBlock helps → start**. The user should never need to understand those as named product concepts.

Keep Back in the top leading position and one quiet progress indicator. Move global sound/haptic preferences out of the repeated overflow menu. Offer “Skip setup” as a quiet trailing text action; keep “Just train” directly available on the welcome page. The relevant “Not sure” action belongs next to the current question, not buried alongside replay, language, and unrelated preferences.

Every question has a single primary control and a bottom Continue action. Here, “picker only” means no competing answer buttons or input fields; Continue still gives explicit control over navigation. Selecting a value must not unexpectedly advance the screen while the user is adjusting it.

Suggested values can initialize a control, but become answers only when the user confirms Continue. “Not sure” stores unknown, never a fabricated default. Back preserves the previous answer without replaying a long animation. The current step survives an interruption.

### Page-by-page replacement

| Page | Critique of current presentation | Exact content and controls to keep | Remove / change | Next and motion |
|---|---|---|---|---|
| 1. Welcome | A generic introduction does not show the app's job; earlier name/language forms asked for effort too soon | GymBlock wordmark; “Make room for your workout.”; one recognizable workout-set preview; **Get started**; quiet **Just train**; optional language link | Name form, explanatory paragraph, giant app-icon tile, sound button | Preview settles once. Get started opens days; Just train opens free-workout exercise selection |
| 2. Frequency | Custom rail and oversized answer area still feel assembled; seven choices do not need several selectors | “How many days a week?”; one value with unit; native 1–7 glass slider; Continue; Not sure | All preset chips, pencil, extra day glyphs, duplicate number editor | Thumb moves directly under the finger; no page animation while adjusting |
| 3. Duration | A number should not need a card and a second method of entry | “How long is a usual workout?”; one minutes wheel; Continue; Not sure | Preset duration buttons, extra field, decorative clock | Wheel replaces slider in the same answer region; 5-minute steps, current supported bounds |
| 4. Reps | The answer is simple, the language need not be a survey paragraph | “Reps per set?”; one wheel; Continue; one Not sure action with unknown/timed choices | Secondary number displays and illustrative rep marks | Timed option stores unknown reps, does not assume zero; continues to sets |
| 5. Sets | Average routine data currently risks looking like a workout prescription | “Sets per exercise?”; one wheel; Continue; Not sure | Rep recap, exercise card, completion marks | Previous number fades; new wheel is immediately usable |
| 6. Exercises | Long wording and repeated explanations add effort | “Exercises per workout?”; one wheel; Continue; Not sure | A routine builder, named exercise inputs, set/repetition recap | Ends the workout-information portion without a separate chapter page |
| 7. Scrolling | This belongs after workout context, not in the introduction | “Do you scroll between sets?”; Yes / Sometimes / No; Continue | App logos, guilt statements, a list of social platforms | No bypasses scrolling-duration questions |
| 8. Scrolling duration | “Minutes between sets” can mean necessary rest rather than time on the phone | “How long do you scroll per break?”; minutes wheel; short qualifier “Only time spent scrolling.”; Continue; Not sure | A rest-duration assumption disguised as scrolling | Yes continues to habits; Sometimes goes to break count |
| 8a. Sometimes only | Asking this late interrupts the explanation to repair missing data | “How many breaks include scrolling?”; wheel bounded by estimated available breaks; Continue; Not sure | Late break question inside the reveal | Answer here, while the user still remembers the scrolling question |
| 9. Rest habit | Current story later risks turning a habit question into a prescribed timer | “Do you time your rests?”; Yes / Sometimes / No; Continue | A suggested optimal rest target or countdown preview | Store the answer; do not add another advice screen |
| 10. Workout logging | Current compound question cannot distinguish logging from reviewing | “Do you log your workouts?”; Log and review / Log only / No; Continue | Long question plus explanatory paragraph | Adapt one later sentence, not the whole route |
| 11. Set timing | Timing needs to mean something the app can actually measure | “Do you time your sets?”; Yes / Sometimes / No; Continue | Claims about precise muscle tension or training quality | Leads into demonstrations; no artificial processing screen |
| 12. Focus demonstration | Current 34-minute screen and follow-up repeat a number using abstract rectangles | Recognizable phone; one estimated scrolling value with unit; one sentence; **Continue**; “Estimate details” link | Both rectangles, internal dashes, color legend, visit split, assumption footer, separate monthly-number page | Short phone interaction described below; no automatic advance |
| 13. Rest demonstration | Accelerated 2:00 can look like a universal prescription; example marks resemble a diagram | “Finish a set. Rest starts.”; actual saved-set row and upward rest counter; **Continue**; optional “About rest” | Accelerated two-minute counter, set-mark timeline, two teaching paragraphs | A set visibly finishes, then rest counts normally |
| 14. Record demonstration and handoff | 10→11 is useful but buried under many fragments; 216-set page adds another abstract story; final empty page adds no value | “Know what to build on.”; explicitly labeled example comparison; one +1 rep change; **Start workout**; quiet **Go to Workout** | 35-second example, repeated weight labels, four-week capsule grid, extra readiness page | Comparison resolves and stays readable; Start enters free exercise selection |

This changes the common Yes route from roughly 18 visible main states to 14. Sometimes adds one question. No skips the scrolling duration and personalized focus estimate, leaving 12. These are route counts, not a claim about conversion or completion time. Unknown answers keep a short nonnumeric focus demonstration where relevant; they must not manufacture a personalized figure.

### Welcome preview

Show a simplified real set record: exercise name, weight and reps, with a persistent “Example” label. Do not draw a fake Start set button. One gentle transition between clear record states establishes the purpose; the page has only one real primary action, Get started.

### The 34-minute screen: replacement composition

```text
                     Back       progress

               Put the phone down.

              [recognizable phone]
             screen turns face down

                    34 min
           Estimated scrolling per workout
                Estimate details

                    Continue
```

This is a hierarchy wireframe, not an instruction to reproduce its blank spaces literally. The large number remains stable; it does not count down to zero or turn green as though the user has already saved it.

The phone has a visible bezel and generic content lines. It is clearly a phone, not an unlabeled rounded rectangle standing in for time. A brief vertical scroll stops, then the phone settles face down. No app logos, notification storm, guilt copy, or confetti. The implication is an action the user can choose.

The detail sheet shows the inputs and arithmetic with an Edit answers action. If the estimate is 34 minutes, the main claim is exactly that much **estimated scrolling**. Do not call it 34 minutes of unnecessary rest or guarantee a 34-minute shorter visit. If there is no scrolling, skip this result and move to the useful training demonstrations.

### Rest demonstration

Use the same saved-set row and rest counter that will appear during a real workout. Show an **Example** label throughout.

```text
              Finish a set. Rest starts.

       Example
       Dumbbell curl         20 kg × 10

                    Rest
                    0:03

                    Continue
```

The example transitions from an active set to its saved row. Rest then counts upward in real seconds. Do not speed a three-second animation into a two-minute “ideal.” Do not imply that the example is the user's actual completed set. The same component later becomes familiar in the app.

“About rest” opens a short optional explanation: rest needs vary with the session, and the app helps the user notice and record their own intervals. Any more specific training recommendation requires a supported source and context. There is no universal optimal number in this onboarding.

### Record demonstration

Use a readable comparison that stands on its own when paused:

```text
                 Know what to build on.

       Example · Dumbbell curl

       Before                         After
       20 kg × 10 reps        →        20 kg × 11 reps

                  +1 rep · same weight

                   Start workout
                   Go to Workout
```

On narrow screens stack the two labeled records. The first record appears, then the second, then the single difference. No arrow without labels, no unexplained bar height, and no extra time statistic. This demonstrates what a record lets you compare; it does not predict the user's next set.

Do not add an adaptive supporting sentence. The labeled before-and-after records already communicate the value, whether someone currently logs or not.

Remove the four-week record projection from this demonstration, including its detail link. The arithmetic remains documented below for reference, but it does not need a product surface. Seeing the same planned volume counted over four weeks is not evidence of becoming bigger faster.

## 5. Motion: a coherent short journey

The sense of a journey should come from seeing the same meaningful object change state. Avoid filling pauses with decoration. All controls remain usable while decorative motion runs; nothing waits for an animation to grant permission to continue.

| Moment | Choreography to prototype | Purpose | Reduced Motion |
|---|---|---|---|
| Between questions | 180–240 ms crossfade with no more than a small vertical displacement; keep chrome and CTA stationary | Continuity without making every answer feel like a new app | Crossfade only |
| Frequency selection | Native thumb interaction; number updates on discrete changes | Immediate cause and effect | Native accessible interaction unchanged |
| Numeric wheel | Native motion and selection feedback; no separate bouncing hero number | The input itself is the animation | Respect system behavior |
| Enter focus scene | Number and label appear together; phone content briefly scrolls, stops, then turns face down; total about 1.5–2 seconds | Show the proposed behavior, not an abstract metric transformation | Static phone with “Phone down” caption; stable number |
| Enter rest scene | Example set row resolves into saved state over about 300 ms; rest starts at 0:00 and runs in real time | Teach exactly when the counter starts | Immediate saved state and normal counter |
| Enter record scene | Before row appears; After row follows after a short beat; difference appears last; total under 1.2 seconds | Lead the eye through a real comparison | All labeled values appear together |
| Start workout | Normal navigation to exercise selection; preserve familiar control positions | Convert the story into an action | Standard reduced system transition |

These durations are prototype targets, not research-established optima. Do not add a perpetual breathing animation or replay a sequence every time a sheet closes. Returning with Back shows the final readable state. Optional replay belongs in the demonstration's detail view, not a permanent toolbar button.

Use one gentle selection haptic for a changed picker value and a distinct confirmation on saving a real set. Avoid adding app-generated feedback on top of identical system feedback. Do not vibrate for every second of a timer. Sound is optional and off by default for a gym context; respect existing user preferences and audio. No sound is needed to understand any screen.

### What to compare in a small design test

Prototype two versions of the **same** record comparison: sequential reveal and one restrained transition between labeled states. Keep copy, numbers, exposure time, and layout otherwise equivalent. Ask what changed and what the user would do next before asking which animation they prefer. If the beautiful version reduces comprehension, reject it. Do not add an animation-style preference screen to the product.

## 6. Numbers: tangible and honest

The app can connect answers to useful numbers without inventing a body transformation.

For a uniform example routine:

- 6 exercises × 3 sets = approximately 18 sets per workout.
- At most 17 between-set gaps under the simple sequential-session assumption.
- 17 scrolling breaks × 2 minutes of actual scrolling = approximately 34 minutes of scrolling.
- At 3 such workouts a week: 102 minutes; over four weeks: 408 minutes, or 6 h 48 min.
- The same routine over four weeks: approximately 216 sets and, at 10 reps each, 2,160 reps.

Only show the first relevant figure on the main scene. Relevant scrolling-time calculations can appear in estimate details; set and rep projections are reference arithmetic, not additional onboarding content. Four weeks is four weeks, not every calendar month.

The break count must be editable: supersets, warmups, variable exercise structure, and scrolling during only some rests invalidate a blind `(exercises × sets − 1)` assumption. “Sometimes” uses the user's specified scrolling-break count. Multiple visits per training day must be an explicit adjustment, not silently inferred from days per week.

When any required input is unknown, do not show a personalized number. When scrolling would consume the entire stated visit or more, suppress the result and offer “Check your answers” with the relevant fields. Do not cap an impossible estimate to a plausible-looking number.

Do not subtract estimated scrolling from visit length and label everything remaining “focused lifting.” Do not turn estimated phone time into additional sets, muscle gained, fat lost, or subscription return on investment. Saved app records may support later comparisons; onboarding answers cannot prove those outcomes.

## 7. Navigation that follows gym intent

### Stable destinations

```text
Workout                         History                         Splits
  idle / current workout          recent workouts                 saved splits
  exercise selection              exercise progress               split detail
  set → rest → next set           totals and trends                 start / edit / progress
  end → summary                   workout detail

Settings: toolbar destination from the idle Workout screen.
```

Rename Home to **Workout**. It remains the opening screen, but its tab name still makes sense once training starts. Keep the native tab bar available. Switching to History or Splits must not finish a set, restart a rest, or clear a draft. Tapping Workout returns to the active state. Do not introduce a separate mini-player, a second Resume workout banner, and a full-screen workout presentation simultaneously.

If a workout is active, starting a different split must not silently replace it. Split detail shows **Return to workout** and allows an explicit later choice to use that split for the next workout. Keep this simple; do not add workout queues.

Use one navigation stack per tab. Use sheets for choosing or editing something in the current task, with navigation inside the sheet for necessary substeps. Do not stack sheets on sheets. Back restores the prior search, scroll position, and draft. Cancel does not commit edits.

### Main paths

| Intent | Path | Design target |
|---|---|---|
| Walk in without a plan | Workout → Start workout → choose exercise → Start set | Three taps when an exercise is visible and remembered load is usable; search or changing load adds necessary input |
| Repeat a split | Workout's remembered split → Start workout → Start set | Two taps; first exercise and last applicable load already available |
| Change exercise during rest | Change → choose exercise | Two taps for a visible exercise; ongoing rest continues |
| Check last performance | Exercise's compact “Last time” row → relevant record | No forced split creation or broad dashboard |
| Finish | End → summary | One action when no set is running; an active set requires resolving its unsaved result |
| Review reps | History → Reps total | Value visible on History; one further tap opens the trend |
| Make a split | Splits → Add split → name and exercises → Save | Optional preparation, never a gate before training |

Tap targets apply to the stated conditions. They are not promises that searching, entering new weights, or resolving an active set costs no effort.

## 8. App screen audit and replacement inventory

### A. Workout and logging

| Screen or state | Every persistent element and its job | Remove or relocate | Behavior |
|---|---|---|---|
| Workout, idle | Toolbar title and Settings; small “This week” activity count; one selected workout row, Free workout or split name; primary Start workout | Large greeting, dominant flame/streak card, unexplained day dots, duplicate Manage splits link, decorative footer | Activity is context, not the hero. Preserve streak data; show its precise weekly meaning only in history/detail |
| Workout choice sheet | Title “Choose workout”; Free workout; saved split names; Create split row | Split descriptions and multiple management links | Select dismisses. Create pushes the split editor within this sheet; Cancel restores choice |
| Exercise selection | Search; genuinely recent exercises; catalog results; Create exercise only when useful; Cancel | “Recent exercises” heading over fallback catalog items; muscle-group decorations and empty suggestion cards | Selecting sets the exercise and dismisses. Search retained if reopened during the same selection task |
| Empty search | Exact query; “No exercise found”; Create “[name]”; clear-search control | Big empty illustration or unrelated exercise recommendations | Keep keyboard and entered name; creation returns the new exercise |
| Ready for set | Workout name and visible End; exercise name with **one** Change action; set number; tappable weight with unit; compact Last time row if real data exists; Start set; small Sets link when records exist | Duplicate dropdown title + Change exercise; large weight card; permanent Focus off label; repeated per-dumbbell paragraph | Weight unit semantics stay visible compactly, e.g. “kg / dumbbell.” No fabricated last result |
| Weight editing | Sheet title “Weight”; current value and unit; one wheel; “Type value” switches to keypad entry; Done/Cancel | Simultaneous large field, stepper, wheel, presets and unit picker | Support 1–500 and existing valid increments; preserve supported bodyweight/assisted cases. Units are settings, not an accidental change during a set |
| Set running | Exercise identity; current load; elapsed time secondary; editable reps value; primary Finish set; End remains visible; Sets link | Timed-exercise correction field while timer runs, secondary instructional paragraphs, progress rings | Do not count reps automatically. For timed exercise, replace reps control with duration context; correction comes after finish |
| Rest | Exercise name with Change; saved weight × actual reps; tappable correction on that row; **Rest 0:42** counting up; next load; Start set; End; Sets link | Countdown, duplicated success message, motivational text, target-duration warnings | Counter remains continuous while browsing or changing exercise. Finishing the next set begins the next rest |
| Change while a set is active | Small resolution sheet: Finish and change / Discard current set / Keep going | Silent exercise reassignment of an in-progress set | Never attach the previous exercise's work to the newly selected exercise. Discard requires a clear description of what is lost |
| Recorded sets sheet | Grouped records with exercise headers; set number, load and actual reps/duration; tap row to edit; close | Repeating full exercise name in every row, all timestamps displayed by default | While a set is running, also show its current draft and a Cancel current set action that returns to ready without ending the workout. Includes warmup/attempt flags where relevant; editing preserves identity |
| Missed or zero-rep set | Compact outcome choice: Record attempt / Edit reps / Discard | Treating every zero as a completed successful set, automatic shame copy | An attempt can be recorded honestly and excluded from completed-rep totals as appropriate |
| Set editor | Visible Weight and Reps labels; Save/Cancel; optional Details for timing, warmup, notes if already supported; Delete separate | Placeholder-only inputs, timestamps competing with primary corrections | Correcting repetitions must not silently rewrite measured timestamps. Unknown times stay unknown |
| End with no records | Return to idle directly | Empty success summary or empty workout saved to History | No user work exists to preserve |
| End during a running set | Resolve current set: Finish and end / Discard current set and end / Keep working | Ambiguous “Are you sure?” without specifying the unsaved work | Previously saved sets remain intact |
| Workout summary | “Workout saved”; duration; exercises/sets/reps in a compact line; weight moved where meaningful; View workout; Done primary | Multiple stat cards, confetti, separate score, coaching content | Expose useful receipt, then return to idle; no automatic next-workout creation |

**Ready-state composition**

```text
Free workout                              End workout

Dumbbell curl                                  Change
Set 1

                    7.5 kg / dumbbell

Last time                              7.5 kg × 10 reps

                    Start set
                       Sets

             Workout       History       Splits
```

The weight value uses a clear button treatment and accessibility label. If it cannot communicate editability without an instruction, fix its affordance.

**Rest-state composition**

```text
Free workout                              End workout
Dumbbell curl                                  Change

Last set                               7.5 kg × 10 reps

                       Rest
                       0:42

Next weight                                  7.5 kg

                    Start set
                       Sets

             Workout       History       Splits
```

Hide the Sets link before the first set starts; show it once there is an active draft or a saved record. Do not present an empty destination as an action.

The user does not need a new page to choose another exercise. Change stays in the same position through ready and rest. Actual reps can be above or below an earlier expectation. Onboarding averages must never create a hard “3 of 3” ceiling or prevent more sets.

### B. History and progress

The current hierarchy makes users configure a dashboard before answering a simple question. Remove the Workouts/Progress segmented root and the Trend/Bars style selector. The app chooses a useful presentation for each kind of data.

| Screen | Elements to show | Remove / simplify | Interaction and meaning |
|---|---|---|---|
| History root | Title; one period/filter button; compact unboxed Reps and Weight moved totals; Exercise progress row; chronological workouts | Separate Progress tab within History, best-lifts card, several rows of filter controls | Default recent four weeks, clearly labeled. Totals open their detail; workouts open records |
| Empty History | “Your workouts will appear here”; Start workout | Empty charts, zero streaks, projected achievements | Start opens or returns to the current workout |
| Workout detail | Date and duration; split/free label; groups by exercise; Set / Weight / Reps or Time columns | Full exercise name repeated on every set, verbose timing for every row | Tap a row to edit; timing is in row details; preserve mixed exercise types |
| Metric detail | Metric title and unit; selected period/scope in one filter button; one chart; exact values below or in disclosure | Chart-style selector, duplicate hero values, tutorial paragraphs | Weekly totals use bars; show date ranges and real totals. Empty periods are distinguished from missing data |
| Exercise progress | Exercise picker/search; one scope choice; dated comparable records; a clear change label | Requirement to create a split to view freestyle progress; nested History button leading to another near-identical page | Free-workout comparison uses free-workout records. Split comparison uses the same stable split and exercise IDs; never pool them silently |
| Longer exercise trend | One selected measure; dates; legible trend with selected-point values | A dashboard of every possible metric | Load comparisons hold rep count constant; rep comparisons hold load constant. If no comparable pair exists, show records instead of an invented improvement |
| Split progress | Split name; exercise rows with latest comparable change or “Not enough comparable records” | Separate decorative split-performance score | Tap an exercise to open that scoped comparison |

Keep reps plainly visible: per set in workout records, per workout in its summary, and total reps in History. Weight moved means the existing correctly defined sum of load × completed reps for eligible records; show its unit and load convention. Do not invent load for bodyweight movements or multiply per-dumbbell entries inconsistently. Different metrics need different eligibility rules, explained in a short detail note rather than a persistent essay.

First/latest comparisons must retain dates, exercise identity, load and rep context. A higher bar alone does not prove strength improvement. Do not compare unlike exercises simply because they share a split name.

### C. Splits, editing and Settings

| Screen | Elements to show | Remove / relocate | Behavior |
|---|---|---|---|
| Splits list | Title, Add, saved names and exercise counts | Permanent edit controls and descriptions under every row | Tap opens a useful split detail, not an editor by surprise |
| Empty Splits | “Save exercises you often do together”; Create split; quiet Free workout | Setup checklist or pressure to create a plan | Free training remains fully available |
| Split detail | Name; ordered exercises; Start workout primary; Edit toolbar action; Progress row | Always-on red minus controls, reordering handles outside editing | Starts this split's first exercise; active workout is protected |
| Split editor | Name field with visible label; ordered exercise list; Add exercises; Save/Cancel | Advanced programming fields, muscle-group taxonomy, per-exercise onboarding estimates | Preserve split ID and historical records through edits |
| Add exercises | Search, current selection, Done | Another modal piled over the editor | Push within the editor's navigation; retain draft on Back |
| Custom exercise | Name; necessary measurement type; Save/Cancel | Media uploads, descriptions, muscle maps and other metadata | Return immediately to the task that requested it |
| Settings | Units; optional name; language; haptics/sound; training answers; clearly identified prototype Focus information; separate data-management section | Second ambiguous “Each exercise” routine editor; verbose local-storage/analytics explanation; duplicate Splits management | Ordinary settings are compact rows. Destructive actions are separated and named precisely |
| Training answers | Labeled values grouped into Workout and Habits; edit individual fields; Save/Cancel | Re-running the full onboarding narrative to fix one answer | This is baseline information, not a second saved split. Remove per-exercise unnamed rows |
| Estimate details | The inputs that produced the result; short formula; Edit answers | Promotional paragraphs and unnecessary charts | Recalculate after explicit edits; retain unknowns honestly |
| Rest information | One short explanation and source links where claims need them | Long research report inside onboarding | Optional depth; dismiss returns to the exact previous screen |
| Prototype Focus | “Focus demo”; brief explanation that blocking is simulated; explicit demo control if retained | A permanent “Focus off” message on every training state | Never imply other apps are actually blocked. If demo is enabled, keep a compact **Demo** marker in the affected experience |
| Demo data and deletion | Separate, clearly labeled prototype/data controls; consequence-specific confirmation | Demo loading alongside everyday training actions | Loading is explicit and idempotent; never overwrite real records. Preserve existing sample-data marker wherever sample history is presented |

Removing clutter must not remove honesty. A real app-blocking permission flow is a separate product task. The current prototype must still disclose simulation where it could otherwise mislead.

## 9. State and edge cases the design must respect

- **Actual performance wins.** More reps, fewer reps, another set, a different exercise, or a changed load are normal. No congratulatory or failure state should depend on matching an onboarding average.
- **Rest is elapsed time.** Use persisted timestamps; opening History, switching exercise, backgrounding, and returning must not reset it. Do not derive rest from the current screen's animation clock.
- **Set time is app-recorded elapsed time.** Tapping Start and Finish records that interval, not laboratory time under tension. Do not turn it into an unsupported quality score.
- **Timed exercises remain first class.** Their records use duration and do not create fake repetitions for totals.
- **Cancelled inputs are not edits.** Search cancellation, weight Cancel, split editor Cancel, and training-answer Cancel leave existing records untouched.
- **Empty sessions are not history.** Starting and leaving without a saved set must not create a completed workout or inflate a streak.
- **History survives redesign.** Preserve exercise IDs, split IDs, actual reps, load conventions, timing provenance and sample flags. Do not rebuild the model around a new visual metaphor.
- **Partial onboarding survives updates.** Map existing route identifiers to the nearest meaningful question or demonstration; do not lose answers or replay setup for someone who already finished.
- **Long names and localization are normal layouts.** Reserve room for full exercise identities and translated labels; do not hide unit meaning to fit a title.
- **No app-enforced rest prescription.** The primary action stays available while resting. Necessary recovery is not wasted time.

## 10. What must be visibly proven before calling the redesign good

### Comprehension checks

Show the focus scene for five seconds, then hide it. A person should be able to say what 34 minutes measures, that it is an estimate, and what action is suggested. If they describe it as guaranteed saved time or extra muscle growth, the screen has failed.

Pause each demonstration at its first and final frame. It must still make sense without motion, a legend, sound, or an explanation from us. Ask what will happen when Continue or Start workout is pressed. Confusion is a design defect, not a need for more tooltip text.

Show the rest state to someone who has not read this document. They should find Change, Start set, their last reps, the counting-up rest time, and End immediately. They should not need to open an overflow menu to discover the core workout loop.

### Runtime verification matrix

| Area | Required proof |
|---|---|
| Glass slider | Actual supported-OS recording of drag, step snapping, 1 and 7 endpoints, VoiceOver adjustment, and no duplicate control |
| Onboarding branches | Yes, Sometimes, No, unknown values, timed exercises, corrected inconsistent estimates, Back and resumed setup |
| Story scenes | First/final screenshots, short motion recordings, readable qualifications, no numeric body-outcome promises |
| Workout loop | Free workout, split, extra/fewer reps, failed attempt, exercise switch during rest and active set, end empty/active/completed |
| History | Reps and weight-moved totals, real record dates, free and split scopes, mixed timed/rep records, no comparable-pair state |
| Data preservation | Existing user history remains identical unless deliberately edited; cancelled changes do not persist; demo remains separate |
| Accessibility | Small phone, larger text, VoiceOver, Reduce Motion, Reduce Transparency, light/dark, long names, translated copy and keyboard visibility |
| Navigation | Tab changes preserve active workout; each sheet has a clear exit; no duplicate primary actions or modal stacks |

Builds and targeted tests are necessary for routing, arithmetic and preservation. Screenshots prove layout only at captured states. A recording proves that an animation runs, not that someone understands it. State these boundaries in validation notes.

## 11. Implementation order and reviewable checkpoints

1. **Establish the visual foundation and real workout states.** Remove dot/glow decoration, apply type hierarchy, simplify ready/rest screens, unify Change, make End obvious, and rename the first tab Workout. Capture idle, ready and rest.
2. **Replace question controls.** Implement the native seven-value slider and consistent wheels, tighten copy, relocate Sometimes break count, simplify chrome, preserve all stored answers and skip paths. Capture and record the slider before building decorative animation.
3. **Replace the story tail.** Build the phone, actual rest component and actual comparison component. Delete the visit rectangles, duplicate focus reveals, four-week capsule page and separate readiness page. Review paused frames before tuning motion.
4. **Simplify History, Splits and Settings.** Remove nested root segments and chart-style choices; make split detail useful; remove the second routine editor; preserve data and prototype disclosures.
5. **Run the route and comprehension checks above.** Repair concrete failures, then record the final end-to-end journey. Do not declare completion from a passing build.

The first visual checkpoint should present the **frequency slider, replacement focus scene, and rest state** together. These three screens establish whether the new controls, storytelling and actual product finally share one clear language. The rest of the app should follow that language, not invent another set of cards.

## 12. Source and evidence index

### Current project references

- [Current onboarding specification](ONBOARDING-JOURNEY-V2.md)
- [Earlier gym flow review](GYM-FLOW-REVIEW.md)
- [Speaking Coach question reference](onboarding-references/speaking-coach-question.png)
- [Current recorded rep comparison](../screenshots/onboarding-v2/journey-17-rep-comparison.png)
- [Current recorded four-week page](../screenshots/onboarding-v2/journey-18-four-week-record.png)
- [Onboarding implementation](../GymBlock/OnboardingJourney.swift)
- [Current onboarding art and picker implementation](../GymBlock/JourneyArt.swift)
- [Workout implementation](../GymBlock/Session.swift)
- [Navigation](../GymBlock/Navigation.swift)
- [Home and Settings](../GymBlock/Home.swift)
- [History and progress](../GymBlock/Progress.swift)
- [Training totals](../GymBlock/TrainingStats.swift)
- [Splits](../GymBlock/Splits.swift)

### External design references

- [Apple — Get to know the new design system, WWDC25](https://developer.apple.com/videos/play/wwdc2025/356/): material purpose, functional layers and hierarchy.
- [Apple — Build a UIKit app with the new design, WWDC25](https://developer.apple.com/videos/play/wwdc2025/284/): native slider material, discrete tick configuration and native navigation controls.
- [Apple — Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders): slider affordances and suitability for the choice being made.

The proposed copy, route cuts, layout sizes, motion timings and navigation structure are GymBlock design decisions to validate. They are not requirements claimed to have been prescribed by Apple or proven by a conversion study.

## 13. Exact text, icons and placement contract

**Added 3 October, after the text-and-placement review.** This section tightens the earlier proposal. Where an earlier wireframe or inventory shows more copy, a different label, or optional decoration, use this section. Everything shown on a screen needs an entry here or a specific functional reason. Do not fill available space with additional copy.

The selected direction for progress is **before and after**. Use two legible, labeled records; do not add an animation-style setting or a carousel of visualization choices.

### 13.1 What earns space

There are four valid reasons for visible text: identify the current task, label a control, show the user's value, or prevent a material misunderstanding. A screen does not also need a slogan, a reassurance, an instruction, and a recap.

- Default question screen: **one question, one answer control, Continue, one secondary route if needed.** No subtitle by default.
- Default explanation screen: **one message, one demonstration, one primary action.** Keep estimate/example labels because they change meaning; remove marketing sentences before removing those labels.
- Default working screen: **identify the exercise, show the relevant numbers, expose the next action.** No motivational copy.
- Default list: title and meaningful rows. No paragraph explaining what a list is.
- Default edit screen: named fields and Save/Cancel. No permanent “Enter…” helper under a field that already has a label.
- Do not replace understandable text with unfamiliar icons to meet a word budget. “End workout” is worth its space. An unlabeled stop square is not an improvement.

At ordinary text sizes, aim for a question of two lines or fewer and no more than one line of optional explanatory copy. These are editing targets, not reasons to truncate translated text, hide units, or shrink accessibility text.

### 13.2 Global placement rules

Use five layout templates, not a separately invented composition for every screen. Measurements below are starting layout values in points, relative to safe areas. They need verification at different text sizes; they are not fixed screen coordinates.

| Template | Top | Main content | Bottom | Alignment |
|---|---|---|---|---|
| **Q — question** | Native Back leading; quiet progress centered; **Skip setup** trailing | Question starts about 32 pt below toolbar; 24–32 pt to one answer control. Numeric wheel about 200–216 pt high; choices fit their actual rows | Continue, 56 pt minimum, full available width; secondary route in a 44 pt target underneath; 12–16 pt safe-area clearance | Question centered; numeric value centered; choice text leading |
| **S — demonstration** | Same navigation; no new chapter title | Headline, then one demonstration, separated by 24 pt. A qualification stays immediately beside its number or example, never at the distant bottom | Primary action in the same position as Q; one optional detail link belongs beside the relevant content | Headline centered; record rows leading with values trailing |
| **W — workout** | Workout/split name leading; **End workout** trailing; exercise name and **Change** in next content row | Weight/rep/rest control occupies the useful middle area; last-set context immediately next to that control | Primary action above native tabs with at least 12 pt separation; Sets text action above the primary button when applicable | Exercise and labels leading; the current primary number centered; row values trailing |
| **L — list/history** | Native title; at most one relevant trailing action/filter | Rows start 16–24 pt below header; section labels only where they distinguish groups | Native tabs; no floating CTA over list rows except a genuine creation/start task | Leading aligned; dates and numbers consistently aligned |
| **E — edit/detail sheet** | Cancel leading, concise title centered, Save/Done trailing | Explicit field labels above or alongside controls, 16 pt between groups; keyboard-safe scrolling | No second Save button at the bottom; no extra close X | Leading aligned; units beside their values |

Use 24 pt horizontal content margins on ordinary phones. Text and controls share the same edges. Related items use 8 pt gaps; groups use 16–24 pt; major regions use 24–32 pt. A thin divider can separate table rows; it does not need to become a card border.

Q and S have flexible space **between the main content and footer**, not an enormous gap between the question and its answer. The question must feel attached to the control. On short screens or large text, that flexible space goes to zero and content scrolls. A pinned footer must not cover the final option or keyboard-focused field.

W keeps Change and the primary action in stable locations across ready, active and rest. Do not move Start set upward when a helper disappears. Remove hidden controls from accessibility and hit testing; do not leave invisible tappable circles.

### 13.3 Onboarding copy: the complete visible inventory

Text in quotation marks is proposed final English copy. Dynamic examples illustrate format, not prefilled user facts. Shared Back, progress and Skip setup come from Q/S and must not be repeated in content. Progress has an accessibility label but no visible “Step 4 of 14” subtitle. Continue never gets a decorative arrow.

| Screen / template | Exact content, in reading order | Actions | Icons / illustration | Explicit deletions |
|---|---|---|---|---|
| Welcome / S | Small “GymBlock”; headline **“Make room for your workout.”** | **Get started**; **Just train** beneath; “English” or current language in top trailing position | One simplified set-record illustration, not an interactive-looking Start set button. It has a persistent “Example” label and only exercise, weight and reps | Remove separate Preview label, tagline, name request, app-icon tile, sound icon and description paragraph. No progress bar before setup begins |
| Frequency / Q | **“How many days a week?”**; `3 days / week`; one seven-tick slider with endpoints `1`, `7` | Continue; Not sure | No calendar icon, dots, flames or pencil | No heading “Frequency,” no instructional subtitle, no second answer display |
| Duration / Q | **“How long is a usual workout?”**; one wheel with selected value and `min` | Continue; Not sure | No clock illustration | No “From starting your workout…” sentence, presets, separate hero number or input field |
| Reps / Q | **“Reps per set?”**; one wheel with `reps` | Continue; **Not sure** opens two short choices: “I’m not sure” and “I do timed exercises” | No dumbbell icon | No “On average” subtitle, helper paragraph or repeated rep number. One secondary button handles both exceptions |
| Sets / Q | **“Sets per exercise?”**; one wheel with `sets` | Continue; Not sure | None | No workout summary or decorative set marks |
| Exercises / Q | **“Exercises per workout?”**; one wheel with `exercises` | Continue; Not sure | None | No example routine, names or recap of previous answers |
| Scrolling / Q | **“Do you scroll between sets?”**; “Yes”, “Sometimes”, “No” | Continue; Not sure | Checkmark only on selected row | No social logos, phone icon above the question, empty circles on all unselected rows or explanatory subtitle |
| Scrolling minutes / Q | **“How long do you scroll per break?”**; one wheel with `min`; “Only time spent scrolling.” directly below the wheel | Continue; Not sure | None | No reference to “optimal” rest, total gym time or time wasted on this input page |
| Scrolling breaks / Q, conditional | **“How many breaks include scrolling?”**; one wheel with `breaks` | Continue; Not sure | None | No embedded calculation or miniature timeline |
| Rest timing / Q | **“Do you time your rests?”**; “Yes”, “Sometimes”, “No” | Continue; Not sure | Selected checkmark only | No stopwatch icon, benefit paragraph or suggested duration |
| Logging / Q | **“Do you log your workouts?”**; “Log and review”, “Log only”, “No” | Continue; Not sure | Selected checkmark only | No journal icon or “and analyze them later” heading extension |
| Set timing / Q | **“Do you time your sets?”**; “Yes”, “Sometimes”, “No” | Continue; Not sure | Selected checkmark only | No history recap or explanation of muscle tension |
| Focus estimate / S | **“Put the phone down.”**; recognizable phone motion; `34 min`; **“Estimated scrolling per workout”** immediately under the number | Continue; **“Estimate details”** directly beneath the qualification | Phone is the one visual object; no extra phone SF Symbol above the headline | Remove “Based on your answers,” “60 minute visit,” color legend, 408-minute follow-up page, instruction sentence, assumption footer and See the difference. Estimate details contains the basis |
| Focus, unknown estimate / S | **“Put the phone down.”**; same phone demonstration | Continue | Same phone; no number | No made-up default estimate, “0 min,” empty chart or apology about missing data |
| Rest / S | **“Finish a set. Rest starts.”**; “Example”; `Dumbbell curl`; `20 kg × 10 reps`; label **“Rest”** and upward timer | Continue; **“About rest”** beside/below demonstration | Actual saved-set component, no clock badge | Remove “Set saved,” “Start again when you’re ready,” timeline marks and second headline. Those words duplicate the demonstration |
| Progress / S | **“Know what to build on.”**; “Example · Dumbbell curl”; **“Before”**, `20 kg × 10 reps`; **“After”**, `20 kg × 11 reps`; **“+1 rep · same weight”** | **Start workout**; **Go to Workout** beneath | No trophy, trending-up arrow, medal, comparison bars or confetti | Remove Remember what you did / Keep your last set close adaptive sentences, Example 35 sec, 216-set page, record-projection detail link and separate readiness page |

The focus layout above replaces the earlier number-first wireframe: lead with the behavioral message, then the phone, then the qualified estimate. This groups cause and meaning without adding a caption to every object. Do not render both the earlier “Put the phone down between sets” sentence and the new headline.

For progress, both labels remain visible after the transition. Before/after values in onboarding are explicitly examples; the actual History comparison also requires dates. At narrow widths use two stacked rows, not tiny side-by-side numbers. The selection of this animation does not justify additional explanatory screens.

**No-scrolling path:** skip the focus estimate entirely. Do not replace it with a praise page. **Unknown:** show the nonnumeric focus scene if scrolling remains relevant. **Invalid estimate:** use “Check your answers” plus “The scrolling estimate is longer than your workout.” and **Edit answers**; remove the number. Keep Continue available to proceed without the estimate. This is a recoverable condition, not a full-screen error illustration.

### 13.4 App copy and placement: complete persistent inventory

The same native tab labels appear throughout the main app: **Workout · History · Splits**. Do not repeat the selected tab label as a giant decorative title and a small eyebrow. A normal navigation title is enough. Values use localized formatting and correct singular/plural wording.

| Screen / template | Exact labels and data | Placement and actions | Remove |
|---|---|---|---|
| Workout idle / W adapted | Title **“Workout”**; `2 workouts this week`; selected `Free workout` or split name | Settings top trailing. Weekly activity is one secondary line below title. Workout-choice row below it, with one disclosure. **Start workout** in bottom action area | Greeting, “Week streak,” flame, seven day indicators, description beneath selected split, Start arrow |
| Workout choice / E list | **“Choose workout”**; “Free workout”; saved split names; **“Create split”** | Cancel top leading; one selected checkmark trailing; choosing a row applies and dismisses | Done, explanatory subtitle, split icons |
| Exercise search / E list | **“Choose exercise”**; search placeholder **“Search exercises”**; “Recent” only for actual recent records, “Exercises” for the catalog | Search directly below title; names in full-width rows; Cancel leading. Current selection gets one checkmark | Exercise-use count badges, decorative movement icons, a chevron on every result |
| No exercise matches | **“No matches”**; **“Create ‘{query}’”** | Two short lines below search; creation is a text button | Giant magnifying glass, restatement of query as a paragraph, unrelated recommendations |
| Ready / W | Session name; exercise name; `Set 1`; tappable `7.5 kg / dumbbell`; `Last time` and `7.5 kg × 10 reps` when known | **End workout** top trailing; **Change** beside exercise name; **Start set** bottom; **Sets** immediately above CTA only when records exist | Pencil, “Tap to edit,” Next set heading, Per dumbbell paragraph, Focus off, duplicate Change exercise button |
| Active rep set / W | Exercise and load; label **“Reps”** with editable value; secondary **“Set time”** and elapsed value | **− / +** beside reps; **Finish set** bottom; Sets above it; Change and End workout retain positions | “Reps completed” paragraph, play/pause/stop icons in labeled buttons, instructions about returning to the app |
| Active timed set / W | Exercise; **“Set time”** with elapsed value; relevant load only if this exercise uses it | **Finish set** bottom; no reps control | Correction field, target-reps row, unused weight field |
| Rest / W | Exercise; **“Last set”** and its editable record; **“Rest”** with elapsed value; **“Next weight”** and its value | Last-set row below exercise header; rest central; next-weight row above bottom action area; **Start set** primary | “Rest elapsed,” success checkmark, repeated set number, extra Last time row and correction pencil |
| Weight editor / E | **“Weight”**; value plus unit | Cancel / Done in toolbar; wheel center; **“Type weight”** below switches to numeric field. In typing mode this becomes **“Use picker”** | ± controls, second field, unit selector, permanent bounds instruction |
| Sets sheet / E list | **“Sets”**; exercise section names; `Set`, `Weight`, `Reps` or `Time` column labels; values | **Done** trailing; **Add set** leading when supported; current draft first, with **Cancel set** action if running | Duplicate exercise text on every row, a large plus circle, all timing details visible at once |
| Edit set / E | **“Edit set”**; **“Weight”**, **“Reps”** or **“Time”**; optional **“Details”** disclosure | Cancel / Save toolbar; **Delete set** separated at the bottom of content | Placeholder-only labels, generic warning always visible, duplicate exercise headline if already clear in title/context |
| Summary / S compact | **“Workout saved”**; duration; compact `18 sets · 180 reps`; eligible weight moved with label | **Done** bottom; **View workout** secondary above it | Success seal, giant checkmark, Focus demo ended, motivational sentence and share-like celebration |
| History / L | **“History”**; **“Last 4 weeks”** filter; **“Reps”** total; **“Weight moved”** total; **“Exercise progress”**; dated workout rows | One compact totals group below title; progress row below totals; chronological list follows | Workouts/Progress segments, workouts-saved count, Best lifts card, duplicate Resume workout control |
| Empty History / L | **“No workouts yet”**; **“Start workout”** | Short content near the list's normal starting position | Chart outline, zero metrics, empty-state illustration, longer explanatory sentence |
| Workout detail / L | Date; workout/split name; duration; exercise headers; set table | Standard Back; row tap edits; units in column heading where consistent | Repeated “Workout details” title if date/title already identifies the view, per-row explanatory timing sentences |
| Metric detail / L | **“Reps”** or **“Weight moved”**; selected period/scope; total; chart with units and date labels | Filter top trailing; value next to/above chart; exact values below | “Training totals” repeated above metric, Across X workouts unless it changes interpretation, Trend/Bars toggle |
| Exercise progress / L | Exercise name; scope; **“Before”**, **“After”** with dates and comparable records; one delta | Scope top trailing; records directly below title; **“All records”** below comparison | Trophy, strength score, unlabeled bars, repeated First recorded/Latest/Previous terminology on one view |
| No comparable records | **“No matching comparison yet”**; actual dated records | One short reason only when known, e.g. **“Weight differs.”** Keep records visible | Fake zero improvement, prompt to create a split, tutorial on statistics |
| Splits / L | **“Splits”**; saved names; exercise counts | **Add split** top trailing; row opens detail | Permanent footer explaining splits are optional, plus beside a clearly labeled Add split |
| Empty Splits / L | **“Save a group of exercises.”**; **Create split**; **Free workout** | One short sentence and two clear routes in normal content area | Illustrated clipboard, checklist, duplicated Add split toolbar action in this empty state |
| Split detail / L | Split name; ordered exercise names; **“Progress”** | **Edit** top trailing; **Start workout** above tabs | Reorder grips, delete badges, per-exercise descriptions outside edit mode |
| Split edit / E | **“Edit split”** or **“New split”**; **“Name”**; exercises; **“Add exercises”** | Cancel / Save toolbar; reorder controls only on exercise rows in this editor | A second Done CTA, constant unique-name instruction, icons beside every field |
| Add exercises / E list | **“Add exercises”**; **“Search exercises”**; exercise names | Back leading; Done trailing; selected checkmarks | Separate modal close X, long selection instructions |
| Custom exercise / E | **“New exercise”**; **“Name”**; **“Measure”** with supported choices | Cancel / Save toolbar | Muscle-group icons, example paragraphs, unused fields |
| Settings / E list | **“Settings”**; “Units”, “Name”, “Language”, “Haptics”, “Sound”, “Training answers”, “Focus demo”, “Data” | Done trailing; values/toggles trailing; use plain native rows | Colored icons for every preference, explanatory footer, redundant section headers |
| Training answers / E | **“Training answers”**; labels **“Days / week”**, **“Workout length”**, **“Reps / set”**, **“Sets / exercise”**, **“Exercises / workout”**, then relevant habit fields | Cancel / Save; values trailing; one field editor at a time | Each exercise editor, unlabeled numbers, replayed onboarding story |
| Focus demo / E | **“Focus demo”**; **“This demo doesn’t block other apps.”**; existing enabled control | Plain explanation next to demo control | Fake permission statuses, reassuring lock icon, enforcement claims |
| Data / E list | **“Data”**; **“Load sample workouts”** when available; **“Delete training answers”** | Separate rows; deletion requires the specific confirmation below | Destructive action beside everyday preferences, database/storage terminology |

During an active session, Split detail's primary action becomes **Return to workout**. Do not also show Start workout disabled with a paragraph. When demo records or simulated Focus are visible, keep the required **Demo** marker in the relevant header/context. That label is not decorative clutter.

### 13.5 Short copy for sheets, errors and exceptional states

These screens are part of the product, not permission to revert to long paragraphs. Show only when the condition occurs.

| Condition | Exact title / message | Actions |
|---|---|---|
| Switch exercise during active set | **“Finish this set?”**; “Saved sets stay.” | **Finish and change**, **Discard set and change**, **Keep going** |
| End during active set | **“Finish this set?”**; “Saved sets stay.” | **Finish and end**, **Discard set and end**, **Keep going** |
| Finish with zero reps | **“No reps recorded”** | **Edit reps**, **Record attempt**, **Discard set** |
| Weight invalid | **“Use a weight from 1 to 500.”** beneath the field, only for a loaded exercise with those bounds | Existing Done remains disabled until valid; bodyweight is a separate supported value, not an invalid zero |
| Invalid reps | **“Enter a whole number.”** if fractional/non-numeric; otherwise specific supported range | Keep entered text and focus; no generic Check all values alert |
| Duplicate split name | **“This name is already used.”** beneath Name | Save once resolved; retain exercise selection |
| Empty split | **“Add an exercise to save.”** near Add exercises, only after attempted save or when explaining disabled Save | Add exercises |
| Unknown recorded time | **“Not recorded”** in time details | Never `0:00` masquerading as measured time |
| Set deleted | **“Set deleted”** with **Undo** in a temporary accessible notice | Undo; no second confirmation toast |
| Delete training answers | **“Delete training answers?”**; “Workouts and splits stay saved.” | **Delete answers**, **Cancel** |
| Empty workout ended | No message | Return to idle; no success screen |

The copy must name what is lost when discarding. Do not shorten “Discard set and end” to an unexplained trash icon. Confirming a discarded active draft must not delete earlier saved sets.

### 13.6 Icon audit: default to fewer

Icons have three jobs here: standard navigation, selection state, or an input action. They do not exist to make a plain screen feel designed. Use a consistent native symbol weight; validate the named symbols on the supported OS during implementation.

| Icon / location | Decision | Placement / appearance / accessibility |
|---|---|---|
| `chevron.left` / Back | Keep native back affordance | Top leading, standard navigation sizing and 44 pt minimum target; accessibility “Back.” No extra custom glowing disc |
| `dumbbell` / Workout tab | Use as the tab identity | Native tab bar with visible **Workout** label; selected tint red, system inactive style |
| `clock.arrow.circlepath` / History tab | Keep | Native tab bar with **History** label; do not repeat this icon next to the page title |
| `list.bullet` / Splits tab | Keep | Native tab bar with **Splits** label |
| `gearshape` / Settings | Keep one | Idle Workout toolbar trailing; accessibility **Settings**; no label necessary in that familiar context |
| `checkmark` / selection | Keep only for selected state | Trailing in selected choice/list row; hidden from separate VoiceOver focus because row announces selection. No empty ring on every other row |
| `magnifyingglass` / search field | Native search field only | System affordance; no oversized empty-state copy of it |
| `chevron.down` / selected workout | Keep one disclosure cue | Trailing in the workout-choice row; not on the exercise title when Change already exists |
| `chevron.right` / navigable rows | Use native disclosure where it clarifies navigation | No disclosure on immediate-selection results, toggle rows, or every stat value |
| `minus`, `plus` / reps | Keep | 44 pt minimum targets flanking the value; accessibility Decrease reps / Increase reps; no symbol in Finish set |
| Reorder grips / split editor | Keep only in explicit edit mode | Trailing, standard native controls; absent from split detail |
| `pencil` / weight and saved set | Remove | Make the value a recognizable native button/row; accessibility names the edit action |
| `flame.fill` / streak | Remove from landing screen | The weekly activity text carries the information without a motivational badge |
| `checkmark.seal.fill`, trophy, medal | Remove | Summary heading already states success; actual progress uses measured values |
| Clock icon above a timer | Remove | “Rest” or “Set time” already identifies the value |
| Phone icon above scrolling question | Remove | The question is sufficient; reserve one actual phone illustration for the demonstration |
| Social app logos | Remove | They distract from the habit question and are not needed for the current prototype |
| Play / stop arrows in labeled CTAs | Remove | **Start set**, **Finish set**, **Start workout** carry the action without duplicate glyphs |
| `ellipsis` / every onboarding page | Remove | Direct **Skip setup** plus relevant secondary action replaces the overloaded menu |
| Speaker / haptic controls in onboarding chrome | Remove | Preferences live in Settings; the journey is fully understandable without sound |
| Info-circle badges beside every label | Remove | Use one descriptive detail link only where optional explanation is useful |
| Decorative arrow between Before/After | Remove | Labels and order carry the comparison; the value transition supplies motion |

A tappable icon gets a meaningful accessibility label; a decorative image is excluded from the accessibility tree. Glass must not reduce hit area, contrast or focus visibility. Keep symbols at a consistent optical scale rather than making every glyph fill a 44 pt box; the larger box is the target, not the artwork.

### 13.7 Removal checklist for the implementation review

A screen fails review if it adds back any of these without a documented functional reason:

- A section title repeating the navigation title.
- An icon repeating the nearby text, or a caption describing an already labeled icon.
- A helper sentence telling users to scroll a familiar picker.
- A second copy of the selected numeric value outside the picker.
- A white or glass card containing only one word or number.
- A decorative shape that needs a legend to be understood.
- A success slogan after an ordinary save.
- A visible technical explanation of local storage, analytics, state, or calculation internals on the main path.
- Two controls that open the same exercise selector or edit the same weight in parallel.
- A new illustration because a simplified screen now has empty space.

For each final screenshot, annotate the remaining elements with their purpose: **question, answer, action, context, qualification, navigation**. If an element has no purpose, delete it. If two elements have the same purpose, justify both or keep one. Review the annotated layout with large text and with all optional context absent, not only a perfect seeded screenshot.
