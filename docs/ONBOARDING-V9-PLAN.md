# GymBlock onboarding V9: in their own words

**1 Nov 2026 · Implemented, then superseded the same day by [ONBOARDING-V10-PLAN.md](ONBOARDING-V10-PLAN.md), which keeps its two questions.** Supersedes [ONBOARDING-V8-PLAN.md](ONBOARDING-V8-PLAN.md) for the page list and the promise's caption; everything else in V8 (the time-back arithmetic, the scenes, the stage, the rules) is unchanged. What it takes from Brainrot and Unrot, and why, is in [onboarding-references/BRAINROT-UNROT-ONBOARDING.md](onboarding-references/BRAINROT-UNROT-ONBOARDING.md).

## Why

Both reference apps make the person say the problem themself, then close off every free fix before the price. V8 asked only numbers, so its later pages could speak in the person's numbers but never in their words, and nothing answered "I'll just use Screen Time" before the offer. V9 adds two questions in their words and one page that answers the second.

The person should leave thinking: *"I said what it costs me. I said what I tried. They told me why it didn't hold, and the promise came back in my own words."*

## Rules (unchanged, and applied to words)

- **Their words only.** The promise's caption, the plan's number and the offer's line come from what they picked. Nothing is claimed about them that they didn't say; the reasons on the why page say what each fix leaves open, never what they did.
- **Fixed answers.** Multi-select rows, never free text, so analytics and sync stay clean (`gb_events` gets the picks joined with commas).
- **No invented proof.** No counts, no testimonials, no fake loaders, no tracking prompt, no mascot. The paper stage stays; emerald the only signal, red only for time on the phone.

## Pages (24; 16 for a phone that fits the rest)

| # | Headline | Stage | Action |
|---|---|---|---|
| 1–5 | Welcome, name, days a week, "Be honest. Do you check your phone between sets?" | Unchanged | |
| 6 | **And what does that cost you?** | The phone keeps pulling the kit in (the "Be honest" scene stays in place) | Multi-select: My workouts run long · I lose focus between sets · I get home late · Not much, honestly. Continue with the first pick |
| 7–13 | Rest, phone minutes, per rest, exercises, sets, workout, year | Unchanged | |
| 14 | **What have you tried?** | The feed, with iOS's time limit over it and its Ignore Limit button (`TriedStage`) | Multi-select: Phone in the locker · Screen Time limits · Do Not Disturb · Just willpower · Nothing yet |
| 15 | **Here's why that didn't hold.** (those, for more than one) | Each pick lands with why in red, on a falter: "No timer, no log, no music." / "Ignore Limit is one tap away." / "Stops the pings, not the feed." / "Every rest is a fight." Then GymBlock, in the signal colour, on the lock: "Locked from your first set to your last." (`WhyFailsStage`). Caption: "No Ignore button. It lifts when you finish." Skipped for Nothing yet | Continue |
| 16 | We'll give you those 35 minutes back. | Unchanged scene. **Caption in their words:** "Home 35 minutes earlier." / "A workout 35 minutes shorter." / "And your focus back, every set." (home late first, then long, then focus; the plain line when they picked Not much) | Continue |
| 17–19 | Sulav's note, the shield, which apps | Unchanged | |
| 20 | Rest alerts | Unchanged | |
| 21 | {Name}, here's your plan. | **The plan's one number is now "35 min back" under "Each workout"**, in the signal colour (it had no number since the gym-time question went on 28 Oct) | Hold to commit |
| 22–24 | Account, the offer (the in-app page carries the same line under its headline; the dashboard paywall is unchanged), splits, first workout | | |

Pages 6 and 14 are asked on every path; 15 only when something tried didn't hold. The per-rest-only path (answers that don't fit an earlier gym time) gets 14, 15 and the promise too, with "Home earlier, every workout." / "Every rest on time, and a shorter workout."

## Answers

`RoutineBaseline.costs: [CostAnswer]?` and `.tried: [TriedAnswer]?` (JourneyMetrics.swift), synced with the rest of the baseline as JSON; no migration. `spokenCost` picks the one the pages speak to; `triedThatFailed` is the picks less Nothing yet. Analytics: `onboarding_answer` with `question` cost or tried and `value` the picks joined ("runLong,homeLate"). Development runs seed run long + home late and limits + willpower; `-journeyCosts loseFocus` and `-journeyTried nothing` override.

## Haptics and sound (`JourneyScores.whyFails`)

| Page | Feel | Sound |
|---|---|---|
| 6, 14 | The selection tap per row, the press on Continue | None |
| 15 | A falter (two falling taps and a buzz that dies) as each failed fix lands; the latch as GymBlock's line lands | Health's "reading failed", quietly, under each; the lock click under GymBlock |

## Checked

Captured on the throwaway iPhone 17 Pro simulator (iOS 26.5, `--ui-reset -journeyStep …`, the sample answers: 1½ min rest, 4 min scrolls, 5 × 3, 4 days; run long + home late; limits + willpower): [screenshots/2026-11-01-v9](../screenshots/2026-11-01-v9/overview.png). The cost page keeps the phone scene in place under the question; the tried page draws iOS's limit card on the feed phone at its design size (a flexible frame first collapsed it to 62 pt and the card truncated); the why page lands two reasons in red and GymBlock's line in the signal colour, in English and Spanish; the promise's caption reads "Home 35 minutes earlier."; the plan's number is "35 min back". **Not checked:** the iPhone SE (no simulator on this Mac), the haptics and sounds (no Taptic Engine in the simulator), the unit tests (their route expectations were updated but not run), the in-app offer's new line, and a real run through from the welcome.

## Not done, on purpose

- **The dashboard paywall** (RevenueCat) still says only "Get your time back."; Brainrot's three beats (the product shown, the reminder in writing, "No payment due now") are a dashboard edit for Sulav to approve. The in-app fallback page carries the new line.
- **A rating ask** after the first finished workout, and real ratings on the welcome once they exist: separate work.
- **The wheel answering back** on the phone-minutes page, and a decade number: left out; the per-workout number is what sells.
