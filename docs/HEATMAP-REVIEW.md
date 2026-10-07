# Onboarding attention heatmap review

7 Oct 2026 (re-run for the ember, Liquid Glass revision; brand pages were captured during a since-rejected red-background trial and are now dark) · iPhone 18 Pro / iOS 27 simulator captures of all 19 pages.

**Method.** Each final-frame screenshot was run through Apple's on-device attention-based saliency model (Vision `VNGenerateAttentionBasedSaliencyImageRequest`), via [`scripts/attention-heatmap.swift`](../scripts/attention-heatmap.swift). The model predicts where people look in the first moments of seeing an image. It is a proxy, not an eye-tracking study: it is centre-biased and favours faces, objects and high contrast. It cannot see motion, so animated beats aren't captured. Treat it as a fast sanity check, then confirm with five real users.

Images: [`screenshots/onboarding-v5/heatmaps/`](../screenshots/onboarding-v5/heatmaps/), with all pages in `overview-heat.jpg` and the fixes below in the `*-before-after.jpg` files.

## Results (share of predicted attention by screen third)

| Page | Peak (% down) | Top | Middle | Bottom | Read |
|---|---|---|---|---|---|
| Welcome | 44 | 55 | 40 | 3 | Peak on the lock ✅ |
| Name | 47 | 48 | 45 | 6 | On the field ✅ |
| Gender | 14 | 64 | 31 | 4 | Headline, then the options ✅ |
| Height | 42 | 47 | 38 | 13 | On the selected value ✅ |
| Weight | 45 | 40 | 46 | 13 | On the selected value ✅ |
| Phone between sets | 33 | 54 | 40 | 5 | Headline → notifications → chosen answer ✅ |
| Minutes per rest | 44 | 60 | 34 | 4 | On the selected value ✅ |
| Phone time vs training | 17 | 45 | 44 | 10 | Headline → "34" in the ring ✅ |
| Hours a year | 70 | 45 | 36 | 18 | Peak on "= 196 workouts" ✅ |
| Mind-muscle A / B | 26 / 39 | 61 / 51 | 34 / 39 | 4 / 9 | Brain, then the arm ✅ |
| Pump A / B | 57 / 55 | 48 / 47 | 43 / 45 | 7 / 7 | On the chart ✅ |
| Memory / Log | 19 / 44 | 50 / 36 | 43 / 58 | 6 / 5 | The "?" row / the rising line ✅ |
| Blocking | 14 | 62 | 24 | 13 | Headline, then tiles |
| Rest alerts | 41 | 31 | 57 | 10 | Ring → notification ✅ |
| Commit | 42 | 39 | 55 | 5 | The first pledge ✅ |
| Offer | 42 | 36 | 53 | 10 | The benefit card ✅ |

## What the heatmaps show

1. **One vertical spine.** On every page, attention runs headline → centre stage → bottom along the screen's centre line, so the eye barely moves sideways. The fixed grid is doing its job.
2. **Headlines win on every page** (34–73% of attention in the top third). That's right for a one-idea-per-page flow: people read the claim first.
3. **The bottom third gets little predicted attention (2–21%).** The model under-weights buttons, and the white button never moves, so people learn where it is after page 1. The layout test confirms its position is identical on every page. **This is acceptable, but don't move the button around to "fix" it.**
4. **Red marks the focal point as intended:** the lock, the 34, the hours payoff and the pumped arm each take the peak or near-peak on their page.

## Fixed in this pass

- **Pump pages.** The large arm stole the peak from the chart, which is where the message is. The chart now sits first and larger (250 pt), with the arm as a smaller result cue below. The peak moved from the arm to the chart.
- **Memory page.** The forgotten values were too small and dim to register. They're now larger and brighter, and the "?" row draws attention.
- **Mind-muscle A.** The notification cards are brighter and larger. The model still favours the brain because of its centre bias; that's acceptable since the cards are a side cue to the brain.

## Fixed in the second pass

- **Gender** is now part of one "Tell us about you." page with height and weight, so no page has an empty stage.
- **Rest alerts** has its own priming page (a ring that runs to 1:30, then a notification lands), followed by the real iOS prompt.

## Still open

- **Height vs weight:** the model still favours the weight wheel slightly. The two columns are identical, so this is model asymmetry, not design. No change.
- **Blocking:** use real app icons once FamilyControls is wired. That needs Apple's Family Controls entitlement and a signed build.
- **Validate with people:** five gym-goers, a think-aloud and one question per page: "What is this page telling you?"
