# GymBlock gym-floor review — 3 October 2026

The person decides what to lift after seeing what is available. The app should hold their session while they walk, change their mind, look up previous work or move between exercises. A split supplies choices; it does not impose an order.

This revision supersedes the previous Home records panel, nested Progress/History navigation, suggested-next-exercise footer and countdown timer. It retains the Speaking Coach typography, warm surfaces, red theme and native controls.

## The gym-floor journey

1. Open Home, glance at the streak, and tap Start workout. Free workout needs no setup; a saved split is an optional remembered choice.
2. Walk to an available machine or pick up dumbbells. Choose the exercise from recent movements or the workout list. Search only when necessary.
3. Confirm the remembered load, or choose it on first use. Start the set explicitly.
4. Return to the phone, record actual completed reps and finish the set. More or fewer reps use exactly this flow.
5. Rest elapsed starts at 0:00 and counts upward. The person decides when they are ready.
6. Repeat the movement or tap Change exercise. The session list makes it easy to alternate movements; the saved set stays associated with the movement actually performed.
7. Browse History or Splits at any point. Returning to Home or Resume workout restores the same session, draft and counter. These actions never finish or create a second workout.
8. End workout when finished. Completed work appears in History. The focus representation ends before the summary.

An occupied machine needs no special mode: tap Change exercise, choose another movement, and continue. Alternating curls and triceps also needs no superset setup. The app follows the selected movement and retains separate load/rep drafts.

## Navigation

The native bottom navigation has three stable destinations: **Home, History, Splits**. Home becomes the current workout while one is running. Each destination has its own navigation stack. Sheets are reserved for small edits and exercise selection; History is a real destination rather than a sheet buried behind Progress.

History has **Workouts** and **Progress**. Workouts lists finished sessions, date, set count and duration. Progress holds the earlier lift records and split/exercise comparisons. All-time records are labeled Best lifts; values are not treated as muscle gain or a combined strength score. Each old workout opens its sets and correction sheet.

Splits provides the optional reusable exercise lists. Adding an exercise during a live session does not rewrite the split. Renaming or reordering a saved split retains its identity. Editing or deleting one while training does not remove completed sets from the active session.

Settings stays a small sheet reached from Home. Its existing split shortcut remains an optional secondary entry point; the bottom Splits tab is the direct route.

## Changing your mind

| State | Interaction | What happens |
| --- | --- | --- |
| Choosing an initial movement | Tap a recent/list/search result | Open its remembered values; do not start lifting automatically |
| Ready, before Start set | Tap the exercise title or Change exercise | Switch immediately, preserving separate drafts |
| Rest after a saved set | Tap Change exercise, then any movement | Switch immediately; preserve the rest counter's original start and every completed set |
| Unfinished set | Choose another movement | Ask Save set and switch / Discard current set and switch / Keep training |
| Save and switch | Confirm actual reps or timed duration | Save to the original exercise, start rest, then select the new exercise |
| Discard and switch | Explicitly discard the current unfinished set | Keep earlier completed sets; switch to ready with no fabricated work or rest |
| Keep training / dismiss | Cancel the switch | Preserve the current exercise, draft and start time |
| Return to an earlier movement | Select it from This workout | Restore its own values, not the values of the movement just left |

Saving an unfinished set is disabled if its actual reps/duration are invalid. Choosing the same exercise closes selection without a resolution prompt. Saved-set labels name the original movement when it differs from the currently selected one, avoiding attribution ambiguity.

## Rest semantics

Rest elapsed is a stopwatch from the moment a set is saved, including an unsuccessful attempt. It continues while selecting an exercise, switching tabs, or reopening the app. Starting a new set clears it; completing that set starts a new counter. There is no target duration, expiry, alarm, wait gate or automatic Start set.

Correcting a record does not move the counter. Deleting the most recent set clears only its own rest. Undo restores the original start, including time already elapsed. Deleting an older set leaves the current rest untouched. Older persisted countdown sessions migrate from their source set's timestamp, falling back to their old deadline and duration; they do not reset at launch.

## Review of every page and sheet

| Page / sheet | Person's intent | Review and resulting behavior |
| --- | --- | --- |
| Home | Begin quickly | Removed all lift records and the workout card wrapper. Keep greeting, streak, plain workout choice and one bottom Start action above navigation |
| Consistency | Understand the streak | Detail remains behind its tap; rest days do not become failures |
| Initial exercise choice | Decide after seeing equipment | Native search, recent exercises; no mandatory plan |
| Change exercise | Select any movement | This workout first, then recent alternatives/search. Current movement and completed-set counts stay visible |
| Ready | Confirm load and begin | Large editable load, previous set when available, Start set; title and Change exercise both open selection |
| Weight sheet | Type a precise value | Manual entry, fractional +/- and native wheel; explicit Done/Cancel; kg/lb conversion preserves canonical load |
| Active lifting | Return and log actual reps | Reps/elapsed activity and Finish. Change exercise is also visible and resolves unfinished work explicitly |
| Rest | Recover, choose what comes next | Upward counter fits all digits at large text sizes, clear saved-set attribution, next load and Start next set. Replace the single suggested-next footer with unrestricted Change exercise |
| Unfinished-set switch | Keep or discard current effort | Three explicit choices; no silent reassignment or deletion of earlier sets |
| Workout options | End or handle uncommon actions | End workout, sets, cancellation and unsuccessful attempts remain out of the primary flow |
| Saved sets | Check/correct a log | List and + for a missed set; completed work stays associated with its original movement |
| Set correction | Fix a mistake | Weight, actual reps/duration, warm-up, timestamp, save/delete; undo follows existing rest ownership rules |
| Summary | Know the session saved | Short outcome, set count/duration, Done; save-as-split remains optional |
| History / Workouts | Inspect older sessions | Dedicated tab with dated rows and set/duration information; empty state is honest |
| Workout detail | Inspect a specific old session | Sets open the existing correction sheet; no second root navigation stack |
| History / Progress | See records and comparable progress | Records live here as plain content. Split picker and exercise rows lead to comparisons |
| Exercise comparison | Understand change | Same reps or same load, first/latest values, dates and explicit delta; reduced motion uses the final result |
| Comparison history | Inspect supporting data | Dated records and chart behind the comparison's History link |
| Splits | Manage optional plans | Dedicated tab. Add/edit/reorder/remove; no dead Done button on the root page |
| Split editor | Name a reusable exercise list | One name, ordered exercises and Save. IDs persist; unique nonempty names remain required |
| Split exercise picker | Populate the plan | Select multiple exercises, use search, then Done; custom movements remain available |
| Custom exercise | Log a missing movement | Name and timed/non-timed toggle, Add. No account or unrelated fields |
| Settings | Change preferences/data | Name, language, units, focus demo and local routine-answer management; native form |
| Welcome | Understand purpose without commitment | Optional language/name, Continue and Skip; no forced account |
| Distractions | Identify scrolling sources | Simple multi-selection; None and Not sure retain their distinct meanings |
| Gym time | Describe usual visits | Minutes/frequency with optional quick choices and unknown values |
| Routine | Describe usual exercise/sets/reps | Timed option, typical values and rep ranges; per-exercise detail remains optional |
| Routine detail / goal sheets | Describe exceptions precisely | Details and goals remain explicit, local and separate from logged workouts |
| Scrolling estimate | Attribute time honestly | Self-reported feed/video minutes; no measurement claim |
| Personal result | See a useful calculation | Attributed estimates; no universal optimal duration or predicted muscle/fat loss |
| Focus setup / why-focus sheet | Understand the prototype | Honest Focus demo language and optional entry; no claim of system enforcement |

## What the reference apps do

Hevy documents improvised empty workouts, live exercise additions, and reorder/replace/remove controls. Its use of previous values supports recalling a movement's own history. [Hevy: Log & Track Workouts](https://www.hevyapp.com/features/track-workouts/)

Strong's iPhone/Android guide supports empty workouts or routines, modifying exercises and sets during a workout, finishing whenever needed, and reviewing the result in History. [Strong: Perform a workout](https://help.strongapp.io/article/229-my-first-workout)

Strong's Apple Watch overview explicitly separates workout overview from the set screen and exposes replacing exercises. That is a reference for separating navigation from the current set, not evidence about the exact iPhone layout. [Strong: Apple Watch overview](https://help.strongapp.io/article/224-workout-on-apple-watch)

GymBlock adopts the flexibility and history separation. The upward rest counter and visible Change exercise action follow this user's requirements. No claim is made that these sources establish a universally best layout.

## Verification and remaining usability work

Verify navigation with a running set, return/resume, counter growth across tabs/relaunch, save/discard/cancel switching, old-set attribution, independent values and stable split templates. Inspect standard and dark/large-text screens. Detailed result evidence belongs in VALIDATION.md.

A friend should try the occupied-machine, alternating-exercise and mid-set-change scenarios without instructions. Observe mistaken taps and hesitation. Simulator checks establish behavior and rendered layout; physical one-handed use and user preference still need that session.
