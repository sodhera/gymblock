# GymBlock — focus, rest and visible progress

**4 October 2026 · V4 native implementation and motion specification**

This revision adopts the user's latest direction: **“Stay focused. Stay intentional.”**, then a benefit-led story about stopping scrolling, measuring rest and set time, and seeing progress. It removes the interactive set-recording tutorial. The latest progress scene replaces the earlier Before and after pair with two five-row record tables.

**Latest animation revision:** The earlier generated arm PNG replaces the rejected vector drawing. Its original fist, wrist and muscle contours are preserved, with a gentler relaxed-to-flexed movement. Timed rest now removes 5 points after each 25-point rise, producing peaks of 25, 45, 65, 85 and 100: **Perfect Pump on rep five**. The left still loses all 25 points. The 1.7-second timed rhythm, bell, aura, bar vibration, brain scene and progress tables are preserved. The finite sequence lasts approximately 10.6 seconds. Its values describe the stylized animation, not measured muscle activation.

The route is now **Welcome → workout questions → habit questions → three animated benefits → paywall → first real workout**. The earlier paywall decision still applies: explain the value before purchase; require subscription before the first real workout. The explanation is now an animated benefit story, rather than a logging lesson.

[UX V3](UX-RESET-V3.md) describes the running app. This document replaces the onboarding recommendations in [the page review](PAGE-BY-PAGE-UI-REVIEW.md). The V4 flow and scenes are now implemented in the native app. Actual subscription products and app blocking remain unconfigured; see VALIDATION.md for native proof and release limits.

## 1. The product story

The person should leave onboarding thinking: **“This helps me stay with my workout, measure my breaks, and see whether I am improving.”**

The three benefits are:

1. **Stop scrolling during your workout.** Keep attention on training instead of repeatedly returning to feeds.
2. **Measure your rest and set time.** Make the time between sets visible; keep enough recovery for the next set.
3. **See your workout progress.** Compare what you completed, so the next workout starts from a useful record.

The welcome can be aspirational. The explanation pages must be concrete. There is no Record a set tutorial, pretend lifting exercise, mandatory demo interaction, commitment ritual, or empty “Your plan is ready” page.

## 2. Illustration scope and evidence

The preview follows the requested visual story. Its brain and arm states are artistic parameters. Research does not establish them as measured recovery or activation curves, so the draft labels this distinction directly and makes no numerical physiological claim.

| Proposed claim / picture | What the evidence permits | Design decision |
|---|---|---|
| Stopping scrolling makes goals X% faster | Some mental-fatigue studies find worse immediate resistance-exercise performance. They do not establish GymBlock's effect on months of muscle growth or goal achievement. | Show estimated phone time and actual recorded reps/load. Do not invent a personal transformation rate. |
| “Scrolling fries your nervous system which ruins your mind muscle connection.” | Smartphone use can induce mental fatigue in specific experimental conditions. These studies do not establish nervous-system damage or destruction of the mind–muscle connection. | Preserve the user's exact sentence in quotation marks for draft review, immediately labeled **Your proposed copy · Unverified health claim**. This is attributed proposed wording, not an established health fact or approved release claim. |
| “If you do not measure how long you rest, you will not get the full benefits of exercise.” | Rest duration can affect training, but timing is not a prerequisite for benefiting from exercise. Longer rests are not inherently a loss of activation. | Use **Time your rests.** The requested differing peaks belong to a visibly labeled stylized boost model, not a claim about weaker physiological contractions. |
| Timing automatically optimizes rest | A timer measures elapsed time. It does not determine every person's physiological recovery or optimal interval. | Say **Measure your rest**, rather than claiming an automatic recovery algorithm. |
| Untimed rest yields 50% activation; measured rest yields 100% activation | This effect is not established by the reviewed rest studies. | Remove numerical activation labels. A midpoint mark and full gauge visualize the requested toy rule under **Stylized model · Not measured muscle activation.** These are chosen drawing dynamics, not efficacy percentages. |
| Keeping records makes someone gain muscle faster | Records make comparisons possible. This is not proof that logging alone accelerates hypertrophy. | Show five chronological example records beside an otherwise identical table with missing history. Both have the same latest result. |

### Evidence reviewed for this revision

- A [2021 crossover study](https://pubmed.ncbi.nlm.nih.gov/34000894/) in 16 adults found higher perceived mental fatigue and lower subsequent squat volume-load after 30 minutes of social-network use. This was a pre-exercise exposure, not brief scrolling between sets or a long-term app trial. Its reported physiological measures did not establish a “drained nervous system” explanation.
- A [2025 smartphone-during-training study](https://dergipark.org.tr/tr/download/article-file/4380109) in 20 students reported lower enjoyment and perceived productivity with unrestricted phone use, but no significant difference in volume-load or exercise intensity. Do not omit this because it complicates the sales story.
- A [2026 systematic review](https://pubmed.ncbi.nlm.nih.gov/42168782/) reports an adverse effect of cognitively demanding tasks on resistance-exercise volume across 11 studies. Tasks and protocols vary, and the abstract cautions about evidence quality. A standardized effect size is not a percentage of faster muscle growth.
- A small [2024 crossover study](https://pubmed.ncbi.nlm.nih.gov/38953795/) in eight participants found better force, exercise volume and neuromuscular measures with five-minute versus two-minute rests during maximal isometric work. It does not prescribe five minutes for everyone; it directly undermines the idea that longer rest inherently prevents activation.
- A [2024 rest-interval systematic review](https://pubmed.ncbi.nlm.nih.gov/39205815/) suggests a small hypertrophic benefit from rests longer than 60 seconds, while noting uncertainty across protocols. It does not establish that measuring rest is necessary to get benefits, or a universal deadline for the next set.
- A [2018 attentional-focus study](https://onlinelibrary.wiley.com/doi/abs/10.1080/17461391.2018.1447020) in 30 untrained men found a greater elbow-flexor thickness increase with internal focus, without the same difference in quadriceps thickness. Coaching attentional cues are different from app blocking. Do not turn that study into a universal mind–muscle or subscription claim.

The reasoning above is our interpretation of these studies, not a tested GymBlock outcome. This evidence belongs in optional Learn more details, not a paragraph on every onboarding page.

## 3. Welcome and overall navigation

**Exact headline, two lines:**

> Stay focused.
> Stay intentional.

**One supporting line:** “Less scrolling. More attention on your workout.”

Keep GymBlock and the supported-language selector in the header. Put headline, supporting line and one restrained animated subject together in the center. Use a single phone outline: moving feed marks stop, the phone settles aside, and the word **Workout** remains. Do not add a second brand icon, workout example row, large card, wall of text or benefit checklist to the welcome.

**Get started** begins workout questions. **Skip questions** opens the first benefit scene. Neither starts a free real workout. Existing subscribers restore access through the paywall/entry route and do not have to answer the questions again.

Question pages retain Back, quiet progress and Skip questions. Back preserves answers; selecting No scrolling removes obsolete minute/break answers. Unknown answers remain unknown. The progress track reflects **Your workouts → Your habits → How GymBlock helps**, rather than a page count that changes mid-flow. Its section name is available to VoiceOver without becoming another large visible heading.

On the three benefit pages, replace survey progress with three quiet step marks. One **Continue** action advances the first two scenes; **View subscription** ends the third. Back reverses one scene. Animation never controls when the user may proceed. Show no set-entry controls or quiz inside these scenes.

## 4. Questions: keep the workout-first order

Welcome is followed by five distinct workout questions. Habits come afterwards. Nothing on the question screens is decorative.

| Page | Exact visible question / headline | Answer control and next action | Why it exists |
|---|---|---|---|
| Welcome | **Stay focused. Stay intentional.** | GymBlock identity; supported-language menu. **Get started** starts questions. **Skip questions** opens the benefit scenes. | Tell the person what this product does before collecting information. |
| Days | **How many days a week do you workout?** | Native Liquid Glass slider, 1–7 whole days. One selected readout, such as **4 days a week**. **Continue** / **Not sure**. | Describes training frequency. Can support a four-week estimate when the visit assumption is valid. |
| Visit duration | **How long is a usual gym visit?** | One haptic wheel: 5–240 minutes, in five-minute steps. **Continue** / **Not sure**. | Checks whether the scrolling estimate is plausible. No preset buttons, text field, or duplicate large number. |
| Reps | **How many reps do you do per set, on average?** | One wheel: 1–50 reps. **Continue** / **Not sure**. A quiet **I use timed sets** alternative. | Supplies an editable starting value for rep-based sets. This is not a prescribed target. |
| Sets | **How many sets do you do per exercise, on average?** | One wheel: 1–20 sets. **Continue** / **Not sure**. | Estimates the usual number of sets. Never restricts the sets they may log. |
| Exercises | **How many exercises in a day?** | One wheel: 1–30 exercises. **Continue** / **Not sure**. | Estimates routine size. Do not ask the person to search for all these exercises during onboarding. |
| Scrolling | **Do you scroll through your phone in between sets?** | **Yes, every break** / **Sometimes** / **No**. Quiet **Not sure**. Selecting an answer saves and advances. | Determines whether to ask scrolling minutes. The first answer explicitly defines the “every break” assumption. |
| Scrolling minutes, conditional | **How many minutes do you scroll between sets?** | One wheel: 0.5–15 minutes, half-minute steps; includes 1, 2, 3, 4 and 5. Caption: **Count scrolling time only.** **Continue** / **Not sure**. | Measures their estimate of phone use, separately from total rest. |
| Break count, only Sometimes | **How many breaks include scrolling?** | One count wheel. If known, **Out of 17 possible breaks**, using their own routine. **Continue** / **Not sure**. | Avoids treating occasional scrolling as scrolling after every set. Unknown routine size has no invented denominator. |
| Rest measurement | **Do you measure how long you rest between sets?** | **Yes** / **Sometimes** / **No**; quiet **Not sure**. Select to advance. | Chooses whether the rest explanation introduces measurement or reinforces their existing habit. |
| Workout records | **Do you record your workouts and look at those records later?** | **I record and review them** / **I record them only** / **I do not record them**. Quiet **Not sure**. Select to advance. | Distinguishes recording from reviewing; selects the relevant comparison instruction. |
| Set measurement | **Do you measure how long each set takes?** | **Yes** / **Sometimes** / **No**; quiet **Not sure**. Select to advance. | Selects whether to introduce or reinforce automatic set timing. It does not assess rep quality or an ideal set duration. |

Wheel ranges above are practical survey ranges, not exercise restrictions. Preserve previously stored valid values outside them rather than clamping those values. Someone who cannot give a representative average can use Not sure. **Continue** is navigation; “wheel only” means no second method of entering the same number.

Defaults position the controls at 3 days, 60 minutes, 10 reps, 3 sets and 6 exercises. Only Continue confirms them. Not sure stores an unknown value, not the visible default. The timed-set alternative leaves average reps unknown and enters the same remaining questions; rep-dependent personal totals are omitted.

On single-tap answer pages, briefly acknowledge selection, then advance. Do not show a redundant Continue button. Back allows correction, including selecting the same answer again. Respect assistive-technology focus and do not advance before the selection can be perceived.

## 5. Benefit scene one — stop scrolling

**Headline:** “Let your mind rest between sets.”

**Supporting line:** “Scrolling can add mental fatigue.”

**Visual:** Two matching brain characters, labeled **Scrolling** and **No scrolling**. Each has two dot eyes, one simple mouth, and a slim vertical meter beside it. Both faces start neutral. Keep folds away from the faces. Size, expression and particles carry the story. Draw particles behind the opaque brain silhouette. TikTok and Instagram use embedded Simple Icons 15.17.0 brand assets (CC0), with no runtime network request. No percentage scale or neuroscience dashboard.

### Storyboard, approximately nine seconds

1. Both brains begin at the same scale and both meters at the same middle level, with **After a set** under both figures. Hold briefly.
2. The scrolling brain eases down to about 88% of its original drawing size while its neutral mouth becomes a frown. Small tired emojis — 😮‍💨, 🥱 and 😴 — mix with Instagram and TikTok symbols, drift outward and fade. Its meter falls. Remove the assistant-written **Attention pulled away** caption.
3. At the same time, the no-scrolling brain eases up to about 110% drawing size and develops a smile. Small ⚡ bolts drift outward and fade. Its meter rises and the caption becomes **Attention on workout**. Use the same red fill on both meters.
4. Stop particles before the ending holds. For draft review, show the user's exact proposed sentence in quotation marks: **“Scrolling fries your nervous system which ruins your mind muscle connection.”** Immediately below, display **Your proposed copy · Unverified health claim**. Replay returns both brains and meters to their initial states. No endless loop.

Keep **Visual metaphor · Not a nervous-system measurement.** during the opening, then replace it with **Your proposed copy · Unverified health claim** when the quoted draft sentence appears. Scale values are drawing parameters, not actual brain shrinkage, growth or measured recovery. The ending preserves proposed wording for review without asserting it as a health fact. This draft-copy inclusion does not establish a scientific claim or change the native app.

### Personalized number, only when supported

An optional line below the visual reads **“About {minutes} min scrolling per gym visit.”** Beneath it: **“Estimated from your answers.”** A small **Estimate details** action explains the calculation and lets them correct it. With No or unknown scrolling, omit the number; the ordinary focus explanation still works without telling them they have a problem they did not report.

The simple model is `(exercises × sets − 1) × scrolling minutes`, using their stated count of scrolling breaks when appropriate. For six exercises, three sets and two minutes in all 17 possible gaps, it yields **34 estimated scrolling minutes**. The detail sheet makes the one-visit-per-training-day and break-count assumptions explicit; multiple visits, supersets and fewer actual breaks need correction before treating daily answers as per-visit figures. The optional four-week total requires confirmed visit frequency.

An estimate at or beyond total visit duration shows **“The estimate leaves no time for your sets.”**, with **Edit answers** and **Continue without an estimate**. Missing or implausible information never creates a fake number.

## 6. Benefit scene two — measure rest and sets

**Headline:** “Time your rests.” No supporting sentence.

**Visual:** Two instances of the earlier generated arm PNG, labeled **Longer rest** and **Timed rest**. Use the original detailed fist, wrist, biceps, triceps and shoulder. Remove the rejected hand-drawn arm and dumbbell. Blue–pale–red shading fills the artwork while retaining its anatomy lines. A gentle mesh deformation opens the forearm during rest and returns it to the exact original flexed image during contraction. This is a relaxed bend rather than a forced fully straight pose; the wider attempted deformation distorted the elbow and was rejected in visual review. A narrow red gauge with a midpoint mark accompanies each arm.

### Storyboard, approximately eleven seconds

1. **Rest first:** Both arms start in the relaxed pose, still and blue, with empty bars. Hold this state for 0.6 seconds. Their first contractions start together.
2. **Equal contraction:** Each curl takes 0.65 seconds and adds at most 25 percentage points. Use smooth acceleration and deceleration for the forearm, with the heat and gauge rising together. The first peak is the same on both sides.
3. **Different illustrated retention:** Timed rest lasts 1.05 seconds and removes 5 points. Longer rest lasts 1.75 seconds and removes all 25. The forearm relaxes during the first 0.35 seconds, then holds still. The timed cycle remains 1.7 seconds; the longer-rest cycle remains 2.4 seconds. These chosen rates and durations serve the illustration, not physiological claims or workout recommendations.
4. **Visible accumulation:** The left repeats 0→25→0 and never reaches the midpoint. The right retains 20 points after each complete cycle. Its peaks are 25, 45, 65, 85 and 100, capped at 100 on the fifth contraction. The colors and bars convey this without phase words, percentage badges, cycle counts or checkpoint confetti.
5. **Finish at full:** At the first touch of 100, ring one quiet bell, vibrate the bar briefly and show a soft red aura. **Perfect Pump** appears just above the right bar. The vibration settles within 0.85 seconds; the aura fades over approximately 2.4 seconds. Hold the final pose and label. The left completes four curls and the right five. Stop the whole sequence after 10.6 seconds; Replay resets both to rest.

No **Rest** or **Contract** text appears under the drawings. Keep only the comparison labels, the eventual **Perfect Pump**, and **Stylized model · Not measured muscle activation.** The phrase names the illustration's full state; it is not a diagnosis or a measurement of an actual pump. The preview includes a Sound on/off control. The bell uses a local synthesized chime, plays only after the person starts the scene, and is cancelled when switching scenes or muting. There is no automatic sound on load. Reduced Motion presents the final comparison and label without vibration, aura motion or sound. User interpretation still needs review before shipping; this toy accumulation rule is not evidence that shorter rest produces better training outcomes.

In the product, rest counts upward from the end of one set to the start of the next. It includes any walking or equipment setup during that interval. Set time is Start-to-Finish time, not a measurement of rep tempo.

The midpoint line belongs only to the illustrative gauge. Do not add 50%/100% activation labels. A biceps color change cannot substantiate EMG, recovery capacity, hypertrophy or nervous-system claims. A counter cannot promise “optimal exercise” without a separately designed and validated recommendation system.

If we later add a rest target, it must be explicitly user/coach selected, adjustable, and compatible with the upward counter. Do not infer a universal target from the onboarding averages or sell timer output as measured recovery.

## 7. Benefit scene three — see progress

**Headline:** “See what your work adds up to.”

**Supporting line:** “Dumbbell curl · Example records”

**Visual:** Two clean tables, aligned side by side when space permits. Both have exactly five data rows. Older workouts are at the top; the latest one is at the bottom. Headers are **Without a record** and **With a record**. The columns are **Workout** and **Weight × reps**. No card, chart, extra illustration or trophy.

| Workout | Without a record | With a record |
|---|---|---|
| Week 1 | Unknown | 20 kg × 8 |
| Week 2 | Unknown | 20 kg × 10 |
| Week 3 | Unknown | 20 kg × 9 |
| Week 4 | Unknown | 22.5 kg × 10 |
| Today | 25 kg × 12 | 25 kg × 12 |

Under the left table, use the user's text: **You can't tell if you're doing well or not.** Under the right table: **This looks motivating.** In context, the left means this missing history cannot show the trend. It does not imply records are the only way to notice any benefit from exercise.

The same latest result on both sides is essential: the comparison shows information gained from recording. It does not pretend that merely using the app caused a stronger latest workout. Week 3 deliberately dips by one rep before progress resumes. Values are sample records, not a promised four-week result or a recommended load. Use the person's selected units in the eventual app.

Add an upward arrow and green percentage inside each right-hand value cell that improves. Week 3 gets a downward arrow and red percentage. Define the measure below the tables: **Percentages compare weight × reps with the previous record.** The sequence is 160 → 200 → 180 → 225 → 300 kg logged weight moved: **Baseline, ↑25%, ↓10%, ↑25%, ↑33.3%**. Compute each change as `(current − previous) / previous × 100`. The first row is Baseline because no earlier record exists. The latest left-hand row has no percentage because its previous records are unknown. Do not invent a comparison for either.

### Storyboard, approximately three seconds

1. Keep the left table steady: four Unknown rows and the latest known result.
2. On replay, reveal the right-hand records in chronological order, one row at a time. Keep table geometry stable so no rows jump.
3. Reveal the latest bottom row last, with the same quiet red-tinted treatment as the latest row on the left. Settle. No perpetually rising line or confetti.

This scene sells the usefulness of a record, without asking the person to record a set during onboarding. No Start set, Finish set, rep picker, search, or pretend workout is required here.

Optional **Recorded totals** details can show `22.5 × 10 = 225 kg` and `25 × 12 = 300 kg` for the final two example records. State that this is logged weight moved, not measured muscle gain or a like-for-like strength percentage. Real History must also show flat and declining performance clearly; a missed target is not automatically a failed workout. Comparisons must preserve exercise, split scope, unit and load convention.

The final action is **View subscription**. Do not append another motivational page or repeat all questionnaire answers as a “personal plan.”

## 8. How to make the promise tangible

The desired commercial idea is improved workout habits. The app can support that story with concrete operations and records. It cannot currently calculate how many months sooner someone will reach an arbitrary goal.

### The proposed three-versus-four-month claim

As written, moving from three months to four months is slower. If the intended example is **four months without the app → three months with it**, that would mean **25% less time**, or **33.3% faster progress rate** under a constant-rate assumption. Those are different calculations. Neither percentage is evidence of a real GymBlock benefit.

Do not implement `growthBoost = scrollingLoss + timedRestBonus + loggingBonus`, or multiply a survey answer by a borrowed study percentage. These effects are not interchangeable, independent, or validated for this product.

### Numbers we can use now

| Number | What it describes | Where it belongs |
|---|---|---|
| About 34 min scrolling per visit | A self-report estimate under stated routine/break assumptions. | Optional line on focus scene; arithmetic and corrections in details. |
| 6 h 48 min over four weeks | 34 min × 3 visits/week × 4, only if that visit frequency is confirmed. | Estimate details, not another compulsory page. |
| 50% less scrolling in a scenario | Reducing reported scrolling from 2 to 1 minute in the same 17 gaps gives 34→17 scrolling minutes. | Optional, explicitly labeled **If you halve your scrolling**. It is not 50% faster growth or guaranteed shorter gym time. |
| 33.3% more logged weight moved | The change from 225 to 300 kg in the final two example records. Both load and reps change; this is not a pure strength or muscle-growth measure. | Progress table and optional details. |
| Recorded weight moved | Sum of entered load × actual completed reps, with the load convention stated. | Progress details and real History. |

Scrolling can overlap useful recovery. Replacing scrolling with an equally long phone-free rest does not save that entire interval. Show zero removal when the replacement rest is equally long; distinguish **phone time avoided** from **workout time saved**. Workout elapsed time also includes sets, recovery, walking and equipment setup, so duration alone cannot identify wasted time.

### What would justify an outcome claim later

A specific goal would need a defined outcome and a prospective controlled comparison. Keep training program, adherence and other relevant inputs comparable; compare a clearly defined GymBlock condition with a control; measure the outcome, uncertainty and time-to-goal. Do not predict an individual deadline from a group average or convert an acute training-volume result into a muscle-growth rate.

Until then, the persuasive promise is **fewer distractions, visible timing, and useful progress records**. No Brain power %, Muscle activation %, Transformation date or X% faster badge belongs in the shipped onboarding.

## 9. Visual direction and placement

Use existing DM Sans, warm canvas `#FBF8F5`, dark text `#231A1B`, and red `#C92535`, with adaptive dark/high-contrast variants. Blue is confined to the cool states within the concept illustrations; it does not become a second app theme.

| Element | Placement / treatment | Cut |
|---|---|---|
| Welcome headline | Central group, two deliberate lines, roughly 32–36 pt semibold. One supporting line directly below. | Separate example row, divider and large brand card. |
| Complete questions | Consistent upper-middle position, 28–32 pt semibold, natural wrapping. | Shortened fragments, duplicate subtitles, automatic font shrinking. |
| Number controls | One native slider or wheel directly beneath the question. | Presets, extra text fields, duplicate giant wheel values. |
| Brain pair | Neutral faces become frown/smile; slight opposing size changes; tired emoji and social logos / lightning from behind; adjacent meters. | Damaged tissue, numerical brain-power scale, particles obscuring faces or text. |
| Arm pair | Original generated PNG anatomy, gentle continuous movement, full heatmap, rest-first opening and full bar on rep five. | Rejected vector hand, distorted elbow, disconnected cut-outs, outline-only tint, extra counters. |
| Figure labels | Brain labels below; arm comparison labels above. Perfect Pump appears above the full right bar. One quiet qualifier below each pair. | Rest/Contract captions, checkpoint sentences, cycle counts, repeated takeaways and physiological axes. |
| Progress records | Two five-row chronological tables, matching latest results and direct messages below. Stack complete tables on compact widths rather than shrinking text. | An unexplained rising line, fake growth forecast, muscle pounds. |
| Primary action | One stable bottom action; red native glass treatment. | Competing next buttons, CTA arrows, animations that delay tapping. |
| Optional evidence/details | One quiet text action next to the relevant concept; native sheet on demand. | Research paragraphs, formulas and implementation explanations on the main scene. |

Liquid Glass belongs on native interactive controls and navigation, not inside static brain or muscle figures. Use native appearance rather than stacking blur, borders and shadows. Figures are illustrations; labels are ordinary text. No repeated decorative clock, flame, sparkle or lock icons. The preview is a composition/motion concept, not evidence of actual brain or muscle measurements.

Each scene has one headline, at most one supporting sentence, two direct labels where needed, one essential qualifier and one next action. A supported estimate may add one number plus its qualification. Do not add icon lists, paragraph footnotes or a second headline to fill space.

## 10. Motion, haptics and sound

- Use simple 2D figures, full fills and restrained movement. Reuse line weight and proportions between paired subjects.
- The focus scene changes the brains' drawing scale, emits the requested tired emoji / lightning bursts, and moves adjacent meters from the same middle level. Keep the metaphor qualifier visible and clear particles before the final hold.
- The rest scene begins with two red Lifting arms, then repeats extended rest and articulated lift phases. Its 50%/100% visual checkpoints throw exactly one paper particle each. No measured activation claim is made.
- The progress scene reveals five chronological rows, oldest to latest, including a realistic dip and colored percentage arrows. The left-hand Unknown rows and matching latest record stay visible.
- Play a scene once, then keep its final meaning visible. Manual replay is optional and accessible; do not add a loud control to every page.
- Page changes take about 250–350 ms. Reverse gently for Back. Keep the action position stable.
- One light selection haptic on an actual choice. No haptic for scrolling time lost, brain “drain,” color recovery, or a pressure-based purchase moment.
- Sound stays off by default and is not necessary for comprehension. Keep its setting outside the main onboarding.
- Reduce Motion shows the same labeled final comparison. Reduced transparency and high contrast retain readable controls. VoiceOver receives one description of the scene, not every animation frame.
- Transitions are not timers: Continue remains usable throughout. Test haptic feel on a physical device rather than claiming simulator proof.

The durations above are design starting points. Do not claim that they are the animation style users prefer until we have watched users try them.

## 11. Subscription after the animated explanation

The paywall follows the progress scene and precedes the first real workout. Skipping questions still reaches these benefit scenes and the subscription offer.

**Proposed headline:** “Stay focused with GymBlock.”

**Three paid benefits, only when actually available:**

- “Block distracting apps during workouts.”
- “Measure your set and rest time.”
- “See your workout progress.”

Show **GymBlock Monthly**, the actual localized **{price} per month**, and **Subscribe for {price}/month**. Keep **Renews monthly until cancelled**, **Restore purchases**, **Terms of Use** and **Privacy Policy** readable. Price is actual configured product data; there is no fabricated price, discount, trial or “most popular” label. If a trial exists and the person is eligible, disclose its actual duration and subsequent charge.

Back returns to the explanation. Remove Just train, Skip setup and other routes that start a first real workout without verified access. Existing subscribers should not see a paywall flash while entitlement is being checked. Keep previous local records readable and preserve an in-progress workout if access changes mid-session.

| Purchase state | Required behavior |
|---|---|
| Loading / unavailable product | No placeholder price or enabled purchase button. Retry, Back and Restore remain available. |
| Purchase started | Native confirmation; prevent duplicate requests. |
| Cancelled | Stay on the offer without an error or repeated pressure. |
| Pending approval | State that approval is pending; wait for a verified transaction update. |
| Failed | Clear failure message and retry; preserve answers. |
| Verified purchase or restore | Enter Workout home; Start workout begins the first real workout. |
| No active purchase restored | Explain the result; do not falsely unlock access. |
| Returning / offline uncertainty | Check entitlement; do not treat temporary verification failure as proof of expiry. |

**Release dependency:** Actual app shielding must work before we sell or present blocking as a working product feature. The current simulated Focus demo does not satisfy that requirement. If this benefit-first direction is implemented before shielding, the review build must clearly identify simulated focus and purchase fixtures; it cannot collect payment for an unimplemented promise.

App selection/permission belongs at the first meaningful focus setup. Explain what will be blocked, use the system picker, and keep an honest declined-permission route to logging. No extra account, notifications survey or irrelevant data collection is needed for this onboarding.

## 12. Implementation and review checklist

1. Apply the exact welcome copy and preserve the full questions. Verify translations and natural wrapping.
2. Remove the set-recording tutorial routes and all real-workout/paywall bypasses in the proposed flow. Preserve existing stored data.
3. Build the three benefit animations as finite, understandable scenes. The examples and survey estimates stay separate from real records.
4. Verify estimate assumptions, unknown answers, no-scrolling route, Sometimes counts, multiple visits, supersets and inconsistent durations.
5. Implement and verify real focus authorization, selected-app shielding, unblocking on End workout, crash/relaunch recovery and permission denial before advertising blocking as available.
6. Configure actual subscription products and implement purchase verification, pending/cancel/failure/restore states. Financial/account configuration and release remain separate external actions.
7. After access is verified, enter Workout with Free workout or an existing selected split. Keep Workout / History / Splits navigation and a visible End workout action. Do not force a split or exercise program before training.
8. Review every question, final animation frame, transition and purchase state visibly. Capture the full animation sequence and verify accessibility and a compact device layout.

Comprehension checks: **What do the brain pictures represent? Are the biceps colors actual measurements? Does the app measure rest or know your muscle recovery? What does that percentage measure? What is included in the subscription?** The conceptual animation must remain distinguishable from an actual brain-power, muscle-activation or growth measurement. Review this before shipping; avoid adding a paragraph of explanation to the main scene.

This revision is ready as a direction for implementation. It does not constitute a tested outcome claim, a working paywall, or approval to publish the app.
