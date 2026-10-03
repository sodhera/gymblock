# Visible finishing, training totals and expressive onboarding

The workout navigation bar now has a visible **End workout** button in initial exercise choice, ready, active and rest states. During an unfinished set, the existing save/discard/keep-training resolution still applies. Finishing clears the focus representation before showing the saved-session summary.

## Reps and workload

History → Progress → Training totals opens a dedicated page instead of adding charts to Home. Choose **Reps**, **Weight moved** or **Sets**, then **Trend** or **Bars**. All workouts and individual split scopes are available. The existing like-for-like exercise before/after comparison and supporting chart remain.

Weight moved is the sum of **logged load × actual completed reps** for every rep-based set. For example, 20 kg × 8 reps = 160 kg of recorded workload. It is work volume, not a strength estimate or physical muscle gain. Per-dumbbell input keeps its existing convention; it is not silently doubled. Bodyweight contributes reps with zero guessed external load. Completed warm-ups count in training totals; attempts and timed activities do not. Strength comparisons continue to exclude warm-ups and hold load or rep count constant.

Data derive from current saved records, so corrections, deletes and undo recalculate the same charts. Summary also displays completed reps and recorded workload. No fabricated bodyweight, estimated one-rep max, or cumulative strength score is added.

## Between-set scrolling

The fourth question page now asks **Do you scroll through your phone in between sets?** with Yes / No / Not sure. Yes reveals 1, 2, 3, 4, 5 minutes and More for a manual value. No yields zero; unknown stays unknown. Every person reaches this question, including those who selected None on distraction categories.

For N supplied sets, there are max(0, N − 1) breaks. The calculation assumes scrolling in each break, including transitions between exercises:

- 6 exercises × 3 sets = 18 sets.
- 18 − 1 = 17 breaks.
- 17 × 2 minutes = **34 estimated feed minutes per workout**.
- 34 × 3 visits = **102 estimated feed minutes per week**.

Individual exercise set answers replace typical counts when supplied. A one-set workout has no between-set break. Missing sets, minutes or visit count remain unknown. Estimates exceeding the supplied visit duration ask for an answer correction instead of silently clipping or treating necessary rest as waste. Earlier attributed total-minute answers still decode and display until edited; old workouts are never overwritten.

This is self-reported scrolling time, not measured phone use, added workout duration, time automatically recoverable, or an optimal-rest prescription. It never predicts pounds of muscle or fat change.

## Motion, touch and sound

Onboarding has forward/back slide-and-fade transitions, a one-time entrance symbol animation, animated numeric updates, and light selection haptics. Continue/Back use a short local cue; completion uses a two-note cue and success haptic. There is no loop, autoplay soundtrack or network audio. Sound can be muted from the first page; Sounds and Haptics are independently adjustable in Settings.

Reduce Motion replaces spatial transitions with a short fade and disables symbol/numeric/chart motion. The decorative symbols are hidden from accessibility. Larger text uses vertical answer choices and an adaptive minute grid.

Audio uses Apple's ambient category, which mixes with other audio and respects the device's Silent switch. [Apple: ambient](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/ambient). Motion follows the OS preference. [Apple: accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion).

Simulator tests validate the math, controls, saved answers, decoded audio files and successful playback requests. Hardware haptic feel and physical-device sound levels still need an iPhone check. See VALIDATION.md for actual run evidence and screenshot locations.
