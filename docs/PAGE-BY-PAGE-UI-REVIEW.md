# GymBlock — keep, remove, add, reposition

**4 October 2026 · Review and recommendations · App changes not implemented in this pass**

**Onboarding update:** [The revised journey](ONBOARDING-CLEAR-JOURNEY-V4.md) replaces the proposed onboarding wording and free-workout ending below. It uses the user's latest focus-led welcome and three benefit animations, followed by the paywall before the first workout. The remaining app review is unchanged.

This extends the welcome-screen critique to every current route, sheet, dialog and important state. The basis is the user's welcome screenshot, [actual V3 captures](../screenshots/ux-v3/README.md), and the current screen implementations. Pages without a current settled capture are reviewed from their composition and navigation in source; this is not a claim that every route was tested live. The user's running tryout was left untouched.

The main problem is composition, not simply the number of words. Many screens put a heading and a small piece of information at the top, then leave an unrelated expanse above the button. Removing useful information would make them harder to understand. Bring related elements together; remove elements that do not help the next decision.

The recommendations below are proposed refinements to [UX V3](UX-RESET-V3.md). They do not silently replace its approved specification. In particular, single-tap choice advancement and the Settings cuts are new recommendations.

## What to change first

1. Replace the disconnected welcome record with a short demonstration of the actual workflow.
2. Give questions, demonstrations, workouts and records different compositions. Stop treating them as the same sparse form.
3. Make visible values look editable when they are editable. Make navigation rows look tappable.
4. Remove the extra Continue tap from simple habit choices; retain explicit confirmation for sliders and wheels.
5. Make rest unmistakable: an upward timer, the previous result and the next exercise/weight. Close the keyboard.
6. Clarify progress scope and record labels. A filtered comparison must not look like all workout history.
7. Cut unused personal details and redundant Settings pages. Preserve stored data.

## Shared elements

| Element | Keep | Remove | Add / reposition |
|---|---|---|---|
| Font | DM Sans; semibold headings; regular supporting text; aligned timer digits | Oversized numbers for ordinary settings; tiny explanations; an identical heading treatment everywhere | Question headings around 28–32 pt, values around 40–56 pt, body around 16–17 pt. Scale naturally; these are starting sizes, not fixed limits. |
| Color | Warm canvas, dark text, red primary actions and selected state | Red on every label or number; gray slabs that dominate the content | Reserve emphasis for the next action and the meaningful result. Negative progress gets a signed, neutral result rather than celebratory treatment. |
| Liquid Glass | Native navigation, slider and interactive controls | Glass around static records, decorative floating cards, custom glow/shadows | Use material where something can be operated. Keep text, records and charts on a readable canvas. |
| Spacing | 24 pt side margins; a stable bottom action | Large gaps between a label and its control; fixed spacers that push useful content apart | About 8–12 pt inside one information group, 20–28 pt between groups. Compose against the available safe area, not a fixed device height. |
| Primary button | One obvious next action; readable verb | Button arrows, extra icon, duplicate bottom and inline actions | About 56 pt tall at normal text size. Keep clear of the tab bar and keyboard. Allow larger text to grow. |
| Secondary actions | A real alternative such as Not sure, Cancel or Just train | Several equally prominent routes; helper text styled like a button | Place beside the decision it affects. Keep a 44 pt target even when its text is quiet. |
| Navigation bars | Native Back, meaningful title, real trailing action | Repeated titles in both toolbar and body; overflow menus holding the main task | Back returns one level. Cancel abandons a draft. Done closes a view. Save commits an edit. These actions must not be interchangeable. |
| Onboarding header | Back, progress, Skip setup | Decorative step icons, chapter slogans, numerical percent text | One quiet horizontal line. Conditional questions must never make progress move backward. Skip setup enters a free workout. |
| Dividers | Boundaries in dense lists and Before/After comparisons | Lines beneath standalone hero content; a separator after every tiny label | Retain only where adjacent rows would otherwise merge visually. |
| Units and qualifiers | kg/lb, reps, minutes; Example, Estimated, sample marker, unknown timing | Repeated unit labels when the control already shows them clearly | Attach meaning to its value. Never remove these to make a screen look cleaner. |
| Keyboard | Native numeric/search keyboards when requested | A keyboard automatically appearing on every page; keyboard lingering during rest | Open after an input tap. Finish, selection, Cancel and Done dismiss it. Expose native dismissal for manual number entry. |

## Onboarding: every page

Numeric questions remain distinct pages, in the requested workout-first order. They need no decorative illustration. The selected answer is their visual focus.

| Page / proposed text | Keep | Remove | Add / reposition |
|---|---|---|---|
| **Welcome — “Train without distractions.”** | GymBlock, language, Get started, Just train | Example / Dumbbell curl / 20 kg × 10 row; its divider; unrelated empty space | A compact phone-down → set → rest animation directly beneath the headline. Language gets a small down-chevron. Headline and animation form one central group; actions stay at the bottom. |
| **Frequency — “How many days a week?”** | Native discrete 1–7 slider; selected value; Continue; Not sure | Any extra presets, manual field, calendar illustration or duplicate value | Put the selected number and “days / week” immediately above the slider. Keep endpoint labels adjacent to the track. Bring this group closer to the question. |
| **Visit length — “How long is a usual gym visit?”** | One haptic minute wheel; Continue; Not sure | Preset buttons, editable field, stopwatch icon, explanatory card | One wheel below the question, with min in its selected row. “Gym visit” makes clear that this includes breaks. No separate giant duplicate number. |
| **Reps — “Average reps per set?”** | One rep wheel; Continue; unknown route | Repeating “reps” in several labels; hidden assumptions that this is a required target | Put “Use time instead” beside the wheel as a quiet alternative for timed training. Keep Not sure in the footer; do not bury the timed route inside it. |
| **Sets — “Average sets per exercise?”** | One set wheel; Continue; Not sure | Exercise-card examples, formula, additional picker | Same placement as reps. This answer estimates routine size; it must never restrict actual set logging. |
| **Exercises — “Exercises in a usual workout?”** | One exercise-count wheel; Continue; Not sure | Silhouettes, muscle-group chips, projected totals | Same placement as sets. No demand to choose or name exercises during onboarding. |
| **Scrolling — “Do you scroll between sets?”** | Yes / Sometimes / No; optional Not sure; Back | Selected choice plus a required Continue tap; phone/social icons | Tapping a choice saves and advances after a brief selection acknowledgement. Back restores the choice. No skips the minute estimate; Sometimes leads to minutes and actual break count. |
| **Scrolling duration — “Minutes scrolling per break?”** | One minute wheel; fractional values; Continue; Not sure | Total-rest wording; a second duration field | Keep one short clarification next to the wheel: “Scrolling only, not the whole rest.” This prevents a material misunderstanding. |
| **Sometimes count — “How many breaks include scrolling?”** | One count wheel; Continue; Not sure | Arbitrary-looking maximum; repeating the complete routine | If the routine is known, show “Out of 17 breaks” directly above the wheel, using their actual count. If unknown, do not invent a denominator or personal estimate. |
| **Rest habit — “Do you time your rests?”** | Yes / Sometimes / No; optional Not sure | Continue after an explicit choice; educational paragraph | Single-tap choice and advancement. Reuse the same row heights and positions as scrolling. |
| **Logging habit — “Do you keep a workout log?”** | Log and review / Log only / No; optional Not sure | Continue after selection; a separate analysis question | The answer rows capture logging and review in one decision. Advance on selection. No notebook icon or extra claim about growth. |
| **Set timing — “Do you time your sets?”** | Yes / Sometimes / No; optional Not sure | Continue after choice; implying set duration measures workout quality | Same single-tap treatment. This answer informs the demonstration; it does not impose an ideal set speed. |
| **Scrolling result — “Put the phone down.”** | Recognizable phone; estimated minutes; Estimate details; Continue | An isolated black phone that becomes the whole story; multiple competing hero elements | Make the estimate the main result, with “Estimated scrolling / workout” next to it. Use a smaller phone to demonstrate the action, not compete with the number. No separate weekly/monthly carousel. |
| **Rest demonstration — “Finish a set. Rest starts.”** | Labeled example set; upward counter; About rest; Continue | Giant standalone timer far from the set; static record that appears unrelated to the counter | Briefly show the set finishing, then reveal the counter in the same composition. Keep the example label near the record. About rest sits just beneath the timer. |
| **Progress demonstration — “See what changed.”** | Before / After, same load, actual displayed reps, Example, Start workout | Long slogan; duplicated delta explanation; extra graph or projected month grid | Stack two comparable records together and animate only 10 → 11. One line: “+1 rep · same weight.” Change Go to Workout to “Set up later” if it simply opens Home; keep its destination explicit. |

### Onboarding branches and detail sheets

| State / sheet | Keep | Remove | Add / reposition |
|---|---|---|---|
| Unknown answers | Training route; phone demonstration where appropriate; rest and progress examples | Personalized-looking zeroes or calculations from defaults the user skipped | Omit the estimated number. Keep the same composition with a nonnumeric phone-down message. Unknown is not zero. |
| Inconsistent estimate | “Check your answers”; Edit answers; continue without an estimate | Blaming language, fake revised estimate, red warning illustration | One sentence: “The estimate is longer than your visit.” Put Edit answers immediately below it. Continue remains usable. |
| Estimate details | Actual break count × minutes; Edit answers; Done; optional four-week total | Another hero animation; repeated onboarding questions; several rows stating the same qualification | Formula first, “Based on your answers” beside it, four-week total second. Keep one clarification that scrolling can overlap needed rest and is not guaranteed saved time. |
| About rest | Short explanation; existing research link; Done | A second headline repeating About rest; blanket “optimal” timer or muscle forecast | One concise paragraph and a clearly labeled source link beneath it. Keep the science in this optional sheet rather than on every question. |
| Language menu | Available language names; selected state | Flags, introduction or explanation | Native menu from “English ˅”. Respect the system language initially. Switching language must preserve answers and position. |

### Motion that earns its place

| Moment | Intended motion | Avoid |
|---|---|---|
| Welcome | A short, readable sequence: phone down, set begins, set finishes, rest starts. Finish in a stable frame. | Endless loop, tiny illegible fake UI, dramatic health promises. |
| Number input | Native wheel/slider movement and selection haptic; stable question and footer | Bouncing the entire page for each number; duplicate haptics. |
| Choice input | Checkmark/selection acknowledgement, then short transition | An extra confirmation tap, an imperceptible advance, blocking Back. |
| Page transition | Brief fade and small directional movement; Back reverses direction | A cinematic delay between ordinary questions; disabling input for a long animation. |
| Scrolling reveal | Phone action resolves; estimate appears once | Pretending an estimate is a live measurement; a number endlessly counting up. |
| Rest demo | Completed record settles; upward counter begins | Countdown, fake universal rest target, compulsory waiting. |
| Before/After | Keep weight fixed and update one rep value; delta appears adjacent | Changing several numbers at once; confetti; an animation-style settings page. |
| Actual workout | Quiet saved-state acknowledgement and clear switch to Rest | Celebrations between every set or sound that competes with gym audio. |

These are design proposals, not measured user preferences. Continue never waits for a film to finish. Reduce Motion preserves the final meaning without movement; optional sound stays off by default.

## Workout: every page and state

| Page / state | Keep | Remove | Add / reposition |
|---|---|---|---|
| **Workout Home** | Weekly activity line; current Free workout/split; Settings; Start workout; tabs | Separate best-lifts/streak card; greeting/name; dashboard decorations | Group activity and workout choice so they read as one starting point. A selected split can show one quiet exercise-count line. Keep Start workout above tabs, not separated from all context by accidental fixed spacing. |
| **Choose workout** | Free workout, saved split names, selected checkmark, Create split, Cancel | Statistics, thumbnails, a second Start button inside the chooser | Compact native sheet. Selecting a row returns immediately; Create split sits after existing choices. Preserve the previous choice when cancelled. |
| **Choose exercise / search** | Search, This workout, Recent, catalog, End workout, selected checkmark | Empty group headings; duplicates; muscle illustrations; Create as a promoted action for every partial search | Show useful recent/current options before typing. During search use one results list. Put Create ‘name’ at the end only when there is no exact match. Selecting immediately opens the ready state. |
| **No exercise matches** | Search text; explicit Create ‘name’; Cancel if presented as a sheet | Empty-state artwork, long explanation, replacing the query | One “No matches” line and the creation action immediately below. Keep the keyboard and search available. |
| **New exercise** | Name; Reps/Time measure; Save; Cancel | Icon/category/description fields; repeating Name as both label and placeholder | Name first and prefilled from search. One compact measure control below. Save creates and selects/adds it; Cancel returns without saving. |
| **Ready to lift** | Exercise + Change; chosen weight/unit; last result; Start set; End workout | Dominant full-width gray weight slab; separate Set 1 line if the button already carries it | Put a smaller native editable weight control directly under the exercise. Last time sits nearby. “Start set 1” can carry the ordinal without another label. Unset weight shows Choose weight; do not invent Bodyweight. |
| **Weight wheel** | One wheel; Bodyweight = 0; 1–500 range; Type weight; Done; Cancel | Simultaneous manual field, +/− controls, unit picker, presets | Compact native sheet. Keep the current value visible in the selection band and the alternate input route beneath it. Preserve fractions and existing exact values. |
| **Weight typing** | Large editable value; adjacent unit; Use picker; Done; Cancel | Second displayed copy of the value; instructions about tapping | Open the numeric keyboard; keep Done visible. Invalid input gets a short field-level error. Switching modes must not silently turn an invalid value into 0/Bodyweight, as the current source does. |
| **Active lifting set** | Exercise; read-only load; editable actual reps; +/−; Finish set; Change; End workout | Another large weight control; multiple prominent timers; forced rep target | Reps are the central focus. Make set time smaller and subordinate. Sets becomes “Sets (2)” when useful rather than another headline. Finish set closes the keyboard and enters Rest immediately. |
| **Timed exercise** | Exercise; elapsed set timer; Finish set; Change; End workout | Weight, reps, empty load totals, both seconds and a separate manual minutes field | Timer is the single central value. Corrections belong in the record editor. Timed exercises must still have clear saved history. |
| **Rest, same exercise** | Upward counter; last-set result; next weight; Start set; Change; End workout | Extra rest guidance, countdown, duplicated last-result panels | Close the keyboard. Keep Last set immediately above the timer and next weight immediately below it. The counter remains the visual focus; Start set ends rest. |
| **Rest, changed exercise** | New selected exercise; ongoing rest; prior record with its original exercise | Resetting rest; suggesting the old result belongs to the new exercise | Clearly pair the previous exercise name with its result in one compact group. Show the new exercise at the top and its next weight near Start set. No extra confirmation between finished sets. |
| **Sets sheet** | Exercise-grouped table; row editing; Add set; Done | Cancel set and Record attempt as two permanent body buttons competing with records | Keep rare active-set actions in one small “Current set” menu, only while a set is active. Records take the main space. Add set opens one editor in the same navigation stack. |
| **Edit / add completed set** | Weight + reps or duration; Save/Cancel; collapsed Details; Delete existing set; Undo afterward | Always-expanded timing/date fields; general error far from the wrong value | Put fields in performance order. Identify the exercise once. Give editable rows a native disclosure affordance. Details contains warm-up, date and recorded timing; show unknown as Not recorded. |
| **Workout saved** | Short saved heading; elapsed duration; sets/reps; recorded load; View workout; Done | Each total as an unrelated hero block; success seal; motivational copy | One compact summary group. Example arrangement: “42 min”, then “18 sets · 180 reps”, then labeled load. View workout stays secondary, Done remains the bottom action. Empty sessions return directly to Home. |

The rest screenshot in the gallery still shows a number keyboard. It may be a transition frame, so it does not prove the settled keyboard is stuck; it does make keyboard dismissal a required live review item. Do not accept a frame with obscured tabs as the final rest composition.

### Workout decisions

| Decision | Keep | Remove | Add / reposition |
|---|---|---|---|
| Change during an active set | Finish and change / Discard set and change / Keep going | Generic title that hides which exercise is pending | Short native dialog: “Change to Hammer curl?” Preserve the unfinished set when dismissed. Saving attributes it to its original exercise. |
| End during an active set | Finish and end / Discard set and end / Keep going | Reusing the change dialog's generic title; hiding End behind an icon | Title “End workout?” and compact actions. End remains visible on the workout page. Invalid/zero reps need a clear resolution, not a mysteriously disabled save action. |
| Zero reps | Edit reps / Record attempt / Discard set | Treating an attempt as a completed set; extra explanatory paragraph | Keep the centered native alert titled “No reps recorded.” Editing retains the active set; attempt enters Rest; discard restores prior rest. |
| Delete a saved set | Explicit Delete set; Undo | A red delete icon on every record row | Delete stays inside the editor. Show one temporary Undo where the user returns. Preserve correct timing meaning after corrections/deletion. |

## History and progress: every page and state

| Page / state | Keep | Remove | Add / reposition |
|---|---|---|---|
| **History with records** | One period filter; actual reps/load totals; Exercise progress; dated workout list | Another Workouts/Progress segment; card for each metric; separate best-lifts panel | Keep the two totals in one compact group. Add a small native disclosure cue to tappable totals. Workout rows show name, date, sets and duration; avoid both a second date header and repeated dates unless grouping helps a long list. |
| **Empty History** | “No workouts yet”; Start workout | Zero totals, blank chart, illustration, explanatory paragraph | Short content at the normal list start. If a session is already running, label the action “Return to workout” and resume it rather than showing Start workout. |
| **No workouts in selected period** | Period filter; honest empty message | Hiding existing older workouts behind unexplained zeroes | Inline “View all time” action next to the empty state. Do not create a new page. |
| **Workout detail** | Workout name/date; concise totals; exercise groups; Weight/Reps or Time headings; edit access | Dense per-set timing rows by default; repeating kg in every row under a kg header | Use a compact table with consistent columns. A native row disclosure signals editability without a pencil beside every number. Timing stays in Details. |
| **Reps / weight-moved detail** | Total, weekly bars, date/unit axes, one filter menu; exact values below | Chart-style switches; explanation above every chart; heavy background card | Put total directly above its chart. Name rows “By workout” instead of Workout values. Keep counting explanation collapsed. Never imply load × reps measures muscle gained. |
| **Timed-only records** | Dates, exercise duration, completed training | Default rep/load hero totals that misleadingly read 0 | Omit irrelevant load metrics for this state. Use recorded time as the meaningful value; do not estimate bodyweight load or rep equivalents. |
| **Exercise-progress list from History** | Exercises that have actual records; their workout context | Default Free workouts scope silently appearing empty when the user trained in splits | Group exercises by Free workouts / named split, or visibly show the selected scope before the list. Choose one treatment. Prefer grouping here; each row opens that exact scope. |
| **Exercise-progress list from a split** | That split's name and exercises with records | A scope menu that allows the user to silently leave the split they just opened | Keep the list scoped to that split. Back returns to its detail. If no records, say “No records for this split yet.” |
| **Exercise comparison** | Dated Before / After, two comparable records, one signed change; same-weight/same-reps condition | Delta far from its condition; trophy/strength score; all controls shown regardless of available comparisons | Combine “+1 rep · at 20 kg” into one concise result line. Keep dates next to records. Offer Reps/Weight only when usable. Retain exact split identity. |
| **No comparable pair** | Actual dated records; one short known reason | Fake 0% progress; optimistic animation; empty chart | “No matching comparison yet.” If known, add “Compare sets at the same weight” or the held-reps condition. Show existing records beneath, rather than telling people they have no training. |
| **Matching record history** | Real chart; date/value rows; known fixed weight/reps | “All records” when the page contains only the matching subset | Rename to “Matching records” and keep the held condition above the chart. If all raw sets are needed, the workout detail already exposes them. |

Before/After remains the progress direction selected by the user. Do not add an animation-preference carousel or chart customization page. Use a brief, truthful transition for a real comparison, with no celebratory treatment for a decline or an incomparable pair.

## Splits: every page and state

| Page / state | Keep | Remove | Add / reposition |
|---|---|---|---|
| **Split list** | Names, exercise counts, native disclosure, Add split | Muscle-group artwork, progress preview card on every row, always-visible delete/reorder controls | Compact standard rows. Add split stays top trailing. A split is a saved option, not a compulsory next workout. |
| **Empty Splits** | “Save a group of exercises”; Create split | Free workout action duplicating the always-visible Workout tab; empty clipboard illustration | One creation action under the short description. Workout remains one tab away. |
| **Split detail** | Ordered exercises, Edit, Progress, Start workout | Set-edit controls or reorder handles outside editing; descriptions for every exercise | Name in navigation, exercises first, Progress as one disclosure row. Start workout above tabs. If another session is active, show Return to workout and preserve it. |
| **New / edit split** | Name, ordered exercises, Add exercises, Cancel/Save | Name repeated as both heading and placeholder; large explanation; second Done button | Label Name once; placeholder “Arms or Monday”. Reorder/remove only on exercise rows in this editor. Error appears beside the duplicate name or empty exercise list. |
| **Add exercises** | Search, multi-selection checkmarks, New exercise, Done | Preview cards, separate Add button on every row, duplicated selected list | Row taps toggle selection. Done returns to the draft. Creation uses the shared New exercise page. Cancelling the enclosing editor discards draft split changes. |
| **Delete split** | Explicit deletion; explanation that workout history stays | Immediate permanent removal with no recovery or confirmation | One short native confirmation on the destructive action. Existing saved workout records retain their original split context. |

## Settings and utility states

| Page / element | Keep | Remove | Add / reposition |
|---|---|---|---|
| **Settings** | Units, language, haptics, sound, Training answers, Done | Name field: it is stored but not used elsewhere in the current interface; decorative row icons | Preferences first, Training answers next, prototype/sample controls last. Preserve any existing name in storage even if the input disappears. |
| **Training answers** | Editable routine/habits; Save/Cancel; unknown answers | One long form with all branches visible; generic error at the bottom | Collapsed Workout / Scrolling / Habits sections. Show scrolling minutes only when relevant, actual break count only for Sometimes. Put validation beside the field. Saved answers do not restart onboarding. |
| **Focus demo** | Honest disclosure that the prototype does not block apps | A separate page whose toggle changes only the demo label; duplicate Focus demo title/toggle | Move prototype status to a concise Settings information row. If simulated-state testing still needs a switch, keep it in the prototype section with the limitation beside it. Do not suggest actual enforcement. |
| **Data** | Explicit Load sample workouts; safe Delete training answers | A separate page for only these two unrelated actions | Put sample loading at Settings' bottom, labeled as sample data; put deletion at the bottom of Training answers. Keep deletion confirmation and “Workouts and splits stay saved.” |
| **Sample data marker** | Visible indication that displayed training is sample history | Demo repeated beside every set or chart point | Prefer the clear word “Sample” on Home and History. Keep records identifiable without turning the marker into a banner. |
| **Unsaved editor dismissal** | Cancel / Save with different outcomes | Silently saving on Back/swipe; a warning when nothing changed | Ask Discard changes? only for a genuinely changed draft. Otherwise close directly. |
| **Storage failure** | Error, Try again, the user's unsaved work | A success summary despite failed storage; repeated technical details | One native alert, “Couldn’t save this workout.” Keep retry and preserve input. Do not replace useful error handling with visual minimalism. |
| **Missing/deleted record** | Back, understandable empty state | Entirely blank page if a record or split disappears while open | One line identifying that it is unavailable. Return to the parent list; do not create replacement records. |

## Icons: the entire allowed vocabulary

| Icon | Where / meaning | Rule |
|---|---|---|
| Native Back chevron | Previous page | No extra circle on ordinary content; native material treatment is sufficient. |
| Down-chevron | Language/workout/filter selection | Use where plain text otherwise looks inert. |
| Right-chevron | Detail/editor disclosure | Use for rows that open another view, not rows that immediately choose an option. |
| Magnifying glass | Search | Inside the native search control, not beside the page title. |
| Native clear control | Clear a nonempty query | Do not create a second Cancel-shaped search button. |
| Checkmark | Selected option | No empty circles beside every unselected option. Expose selection to accessibility. |
| Plus / minus | Actual rep adjustment | At least 44 pt targets; no decorative red halo. |
| Gear | Settings from Workout | One entry point; do not repeat it on every screen. |
| Dumbbell / history clock / list | Workout / History / Splits tabs | Keep labels. The icons are navigation landmarks, not an explanation of the product. |
| Native reorder/remove | Split editing only | Never permanently visible on the normal split detail. |

Use text for **Change**, **End workout**, **Finish set**, **Save**, **Cancel** and **Done**. Do not replace these with ambiguous arrows, stop squares or tiny pencils. No flames, trophies, success seals, unrelated question icons, tab badges or decorative illustrations on data-entry pages.

## Navigation and placement contract

| User intent | Shortest understandable route | Placement |
|---|---|---|
| Arrive and start anything | Workout → Start workout → choose exercise → weight → Start set | One dominant action per step. Recent exercises are available before typing. |
| Use an existing split | Selected split → Start workout → first exercise | Selecting a saved split does not require rebuilding it. |
| Switch after a set | Change → choose exercise → Start set | Rest continues. No confirmation for an already-finished set. |
| Switch during a set | Change → choose → resolve unfinished set | One native decision; old records keep their exercise attribution. |
| Correct a result | Last set, or Sets → row → Save | Direct last-result editing; no extra edit menu. |
| Stop the visit | Visible End workout → summary if there are completed records | No hidden stop icon; no empty summary. |
| Inspect older training | History → workout or metric | One top-level History page, not another internal tab system. |
| Compare a split | Splits → split → Progress → exercise | Scope remains visible and stable. |
| Edit a split | Splits → split → Edit | Save/Cancel commits or discards one draft. |

Keep the native **Workout / History / Splits** bar after onboarding. Opening History or Splits does not end a workout, reset rest or replace the selected exercise. Workout returns to the active state. Do not add a permanent resume card or a fourth Progress tab.

On normal screens, keep the title and its immediate context together; put useful controls in the upper-middle area and the primary action in the bottom safe area. A question gets one control, a rest screen gets one focal timer, a comparison gets a paired record, and a list gets readable rows. More empty space is acceptable when it preserves these relationships; arbitrary separation is not.

At larger text sizes, stack values and let the content scroll. Never shrink essential labels or push the primary action offscreen to preserve the normal-size composition. Native keyboard and sheet toolbars must retain reachable Cancel/Save/Done controls.

## Coverage and implementation checks

Reviewed current onboarding branches, its two reachable explanatory sheets and language menu; Workout Home/choice/search/custom exercise/ready/weight/active/timed/rest/sets/edit/summary; unfinished-set/end/zero-rep decisions; History/detail/totals/scoped comparisons; Splits/list/detail/edit/picker; Settings/answers/focus/data and shared error/empty states.

Legacy `BaselineNumber`, `BaselineSummary`, `RoutineDetailEditor`, `GoalEditor`, `SetList` and the currently uninvoked Focus preview are not additional active pages in this inventory. Do not restore these older card-heavy routes. Before removing unused source, check references and preserve saved-answer migration and decoding.

Before calling a later implementation complete, review settled actual frames and operate: numeric and unknown branches; choice/Back/resume; keyboard dismissal; each unfinished-set choice; different-exercise rest attribution; split creation/edit/cancel; scoped records including missing comparisons; sample markers; larger text and reduced motion. Appearance and source alone do not establish comprehension or user preference.

No advanced coaching, social features, accounts, paywall, body-transformation forecasts or new onboarding questions are proposed. The additions above earn their space by explaining an action, exposing an existing capability or preventing loss/misinterpretation of training data.
