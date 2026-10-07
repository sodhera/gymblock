# Onboarding attention heatmap review

7 Oct 2026 · iPhone 18 Pro / iOS 27 simulator captures of all 18 onboarding states.

**Method.** Each final-frame screenshot was run through Apple's on-device attention-based saliency model (Vision `VNGenerateAttentionBasedSaliencyImageRequest`), via [`scripts/attention-heatmap.swift`](../scripts/attention-heatmap.swift). The model predicts where people look in the first moments of seeing an image. It is a proxy, not an eye-tracking study: it is centre-biased and favours faces, objects and high contrast. It cannot see motion, so animated beats aren't captured. Treat it as a fast sanity check, then confirm with five real users.

Images: [`screenshots/onboarding-v5/heatmaps/`](../screenshots/onboarding-v5/heatmaps/), with all pages in `overview-heat.jpg` and the fixes below in the `*-before-after.jpg` files.

## Results (share of predicted attention by screen third)

| Page | Peak (% down the screen) | Top | Middle | Bottom | Read |
|---|---|---|---|---|---|
| Welcome (notifications) | 25 | 73 | 24 | 2 | Headline first, then the notification stack ✅ |
| Welcome (locked) | 45 | 52 | 43 | 3 | Peak sits exactly on the red lock ✅ |
| Name | 27 | 52 | 36 | 10 | Headline → field ✅ |
| Gender | 16 | 61 | 21 | 17 | Headline, then an empty stage ⚠️ |
| Height & weight | 48 | 33 | 59 | 7 | The weight wheel is the hot spot; height is weaker ⚠️ |
| Phone between sets | 41 | 50 | 43 | 5 | Headline → notifications (the subject of the question) ✅ |
| Minutes per rest | 50 | 59 | 35 | 4 | Headline → selected value ✅ |
| Phone time (ring) | 22 | 51 | 38 | 10 | Headline → "34" ✅; adjust rows are secondary, by design |
| Hours a year | 70 | 36 | 42 | 21 | Peak on "= 196 workouts", the payoff ✅ |
| Mind-muscle A | 27 | 54 | 34 | 10 | Brain dominates; the notifications (the cause) are peripheral ⚠️ |
| Mind-muscle B | 39 | 47 | 41 | 10 | Brain → red arm ✅ |
| Pump: never reached | 58 | 45 | 44 | 9 | Fixed: was 32 (arm); now on the chart ✅ |
| Pump: reached | 57 | 45 | 45 | 8 | Same ✅ |
| Memory | 19 | 53 | 40 | 5 | Fixed: the "?" row now gets attention (middle 31% → 40%) ✅ |
| Log | 45 | 35 | 58 | 6 | Peak on the rising line ✅; the red "+5 kg" draws secondary attention |
| Blocking | 14 | 62 | 22 | 14 | Headline; tiles get moderate attention |
| Commit | 42 | 37 | 56 | 6 | The first pledge ✅ |
| Offer | 44 | 34 | 54 | 11 | The first benefit row ✅ |

## What the heatmaps show

1. **One vertical spine.** On every page, attention runs headline → centre stage → bottom along the screen's centre line, so the eye barely moves sideways. The fixed grid is doing its job.
2. **Headlines win on every page** (34–73% of attention in the top third). That's right for a one-idea-per-page flow: people read the claim first.
3. **The bottom third gets little predicted attention (2–21%).** The model under-weights buttons, and the white button never moves, so people learn where it is after page 1. The layout test confirms its position is identical on every page. **This is acceptable, but don't move the button around to "fix" it.**
4. **Red marks the focal point as intended:** the lock, the 34, the hours payoff and the pumped arm each take the peak or near-peak on their page.

## Fixed in this pass

- **Pump pages.** The large arm stole the peak from the chart, which is where the message is. The chart now sits first and larger (250 pt), with the arm as a smaller result cue below. The peak moved from the arm to the chart.
- **Memory page.** The forgotten values were too small and dim to register. They're now larger and brighter, and the "?" row draws attention.
- **Mind-muscle A.** The notification cards are brighter and larger. The model still favours the brain because of its centre bias; that's acceptable since the cards are a side cue to the brain.

## Recommended (not changed)

- **Gender:** the stage is empty, so the second fixation lands on nothing. Either drop the page (the principles review already flags that gender is unused) or give it a small visual.
- **Height & weight:** height reads weaker than weight. Making the two wheel columns identical in weight, or putting height first in a stacked layout, would balance them.
- **Blocking:** consider real app icons once FamilyControls is wired. Generic glyphs carry less meaning than recognisable logos.
- **Validate with people:** five gym-goers, a think-aloud and one question per page: "What is this page telling you?"
