# GymBlock widgets: the final build spec

**Thesis.** There are three widget kinds, one control and one restyled Live Activity, and each does a single job. The widgets show information and open the app. Only the control and the app's own button start a workout. The Live Activity handles sets and rests. GymBlock is recognisable on every surface through the paper stage, a large DM Sans hero, the seven dots and a kettlebell whose keyhole is cut out.

**Base and what was added.** The base is Ive's proposal. These ideas were added from the other proposals:
- a systemMedium widget that is Home in miniature, with no button (Native);
- separate Month and Week kinds (Native);
- `ironCut` for the mark and the `Tone` resolver (Native);
- an uncapped streak and faded future days (Commitment);
- the stale rule `activeUntil` with a reload when it moves more than 15 minutes, plus a hard cap on the clock (Utility);
- SF Pro on the Lock Screen;
- week numbers stored as integer day keys;
- a `WeekMath` shared with Home.

**Ideas rejected, with reasons:**
- **Week dots on the small Up next widget.** They would repeat the month widget when the two sit side by side. The medium already carries the week.
- **A Start capsule in any widget.** It is a pill, and a stray tap would turn on blocking. AGENTS.md also says the primary action lives in one fixed place.
- **Any blocking wording or lock glyph.** The snapshot can go out of date: Screen Time can be revoked, and the one-minute pass can be running.
- **A number in the centre of the circular widget.**
- **A clock as the hero.**
- **Emerald on clocks.**

I checked the code these rules depend on in the repo:
- `BrandMark.swift:184-185`: the iron path has no keyhole hole.
- `LiveWorkout.swift`: a Live Activity exists only once `selected != nil`.
- `Account.handle` checks only the URL scheme.
- `homeStats` caps the streak at 12 weeks.
- The Spanish keys listed under strings below already exist.

DM Sans text widths come from `GymBlock/Fonts/DMSans.ttf` with its variation axes applied. Nothing in this spec has been built or run yet.

---

## 1. The suite

Kind strings are permanent once someone has placed a widget.

| # | Swift type | Kind | Families | Purpose | Why it earns its place |
|---|---|---|---|---|---|
| 1 | `UpNextWidget` | `com.sodhera.gymblock.upnext` | systemSmall, systemMedium, accessoryRectangular, accessoryInline | What you train next. While a workout runs, it shows that workout. | It answers the one question Home exists to answer. It is also where the shield sends you back to during a workout. |
| 2 | `MonthWidget` | `com.sodhera.gymblock.month` | systemSmall | Every day you trained this month. | It is the only look back, and GymBlock's most recognisable form (Profile's MonthDots). It also suits StandBy. |
| 3 | `WeekWidget` | `com.sodhera.gymblock.week` | accessoryCircular | This week as seven dots around the kettlebell. | It shows the rhythm on the Lock Screen at every pickup, which is the moment GymBlock exists to interrupt. It reads in monochrome. |
| C | `StartWorkoutControl` (iOS 18+) | `com.sodhera.gymblock.control.start` | Control Center, Lock Screen control slot, Action button | Start what's up next, or return to the running workout. | It is the only start outside the app. It opens the app, so the Screen Time question still shows and the offer wall still holds. |
| LA | `WorkoutLiveActivity` (exists) | unchanged | Lock Screen, Dynamic Island | The set and the rest. | Restyle only. Per-set state lives here and nowhere else. |

**Not built:** systemLarge, any progress chart, stat tiles, minutes or volume, the 12-week grid, blocking status, Pause, Finish or toggles, widget buttons, `Link` regions, configurable intents, an App Shortcut in v1, and anything relevance-related based on a predicted training hour.

**Pairings this suite is designed for:**
- Home Screen: Up next small next to This month small reads as Home in a strip. Up next medium stands alone.
- Lock Screen: the Week circular next to the Up next rectangular widget.

---

## 2. Shared foundations

### 2.1 Colour tokens

Create `GymBlock/Widgets/PaperPalette.swift` and compile it into both targets. Use the values that are in the code. `JourneyTheme.paper` in `OnboardingPremium.swift` is refactored to read these same constants, so the app and the extension can't drift apart.

| Token | Light | Dark |
|---|---|---|
| `Paper.stage` | (0.961, 0.953, 0.937) #F5F3EF | (0.082, 0.078, 0.071) #151412 |
| `Paper.ink` | (0.08, 0.08, 0.09) #141417 | (0.953, 0.941, 0.918) #F3F0EA |
| `Paper.secondary` | (0.40, 0.40, 0.42) #66666B | (0.69, 0.68, 0.66) #B0ADA8 |
| `Paper.signal` | (0.06, 0.60, 0.42) #0F996B | (0.20, 0.76, 0.54) #33C28A |

- `tertiary` and `danger` are never used in widgets.
- Colours are resolved explicitly from `colorScheme`. Widgets never use dynamic `UIColor` closures.

### 2.2 `WidgetTone`

`WidgetTone` lives in a shared file. The extension resolves it once per entry view; the preview injects it through `@Environment(\.widgetTone)`. It has four modes:

| Mode | When | ink | secondary | signal | Past-day dot | Future-day dot |
|---|---|---|---|---|---|---|
| `.paper` | fullColor, background shown | token for the scheme | token | emerald token | ink 0.12 | ink 0.05 |
| `.removed` | fullColor with `showsWidgetContainerBackground == false` (StandBy, CarPlay) | dark ink forced | dark secondary | #33C28A | 0.18 | 0.08 |
| `.accented` | tinted or clear Home Screen | `.primary` | `.secondary` | `.primary` plus `.widgetAccentable()` | 0.22 | 0.10 |
| `.vibrant` | Lock Screen, StandBy at night | `.primary` | `.secondary` | `.primary` | 0.30 | 0.12 |

```swift
static func resolve(_ r: WidgetRenderingMode, background: Bool, scheme: ColorScheme) -> WidgetTone {
  if r == .accented { return .init(mode: .accented, dark: true) }
  if r == .vibrant { return .init(mode: .vibrant, dark: true) }
  return background ? .init(mode: .paper, dark: scheme == .dark) : .init(mode: .removed, dark: true)
}
// `tint: Color?` exists for the DEBUG preview only: it simulates the accent group (`.primary` becomes white, accentable elements take the tint).
```

**What is accentable:** only trained dots and the "Up next" eyebrow. A widget has no `glassEffect`, no DotGrid or glow, no inner cards, and no tracked capitals.

### 2.3 Day dots

Every dot surface uses the same `DayMark` enum: `trained | today | past | future`.

| Mark | Drawn as |
|---|---|
| trained | `Circle().fill(tone.signal).widgetAccentable()` |
| today, not trained | `Circle().strokeBorder(tone.ink, lineWidth: size >= 11 ? 1.5 : 1.25)` |
| past | `tone.ink.opacity(tone.past)` |
| future | `tone.ink.opacity(tone.future)` |

- Fill, ring and opacity carry the meaning in every mode, so colour is never the only signal.
- Future days are faded on widgets. Home's WeekLine keeps its current look; whether Home should fade them too is a question for the user (§11).

### 2.4 Type

- **Home Screen words:** DM Sans at fixed sizes through `WidgetType.words(size, weight)`, which returns `Font(AppFont.uiFont(size:weight:)) ?? .system(size:weight:)`. There is one switch, `WidgetType.useDMSans = AppFont.dmSans`.
- **Every ticking clock:** `.system(size:, weight: .semibold).monospacedDigit()`. DM Sans has no `tnum` feature, so its digits would jitter.
- **Accessory families and the Live Activity:** SF Pro only, matching the system clock.
- DM Sans line height is 1.302 em. Measured: 13 → 16.9, 15 → 19.5, 26 → 33.9, 30 → 39.1, 34 → 44.3, 36 → 46.9, 40 → 52.1, 44 → 57.3.
- Hero tracking: −1 at sizes of 30 and above, −0.6 at 26–28, −0.4 at 22.

### 2.5 `HeroFit`

`HeroFit` lives in shared `GymBlock/Widgets/HeroFit.swift`. It measures text; it never relies on a `minimumScaleFactor` floor.

```swift
struct HeroFit { let text: String; let size: CGFloat; let tracking: CGFloat; let lines: Int; let showsCaption: Bool; let nudge: CGFloat; let scaled: Bool }
static func pick(hero: String, short: String?, width W: CGFloat, budget H: CGFloat,
                 ladder: [CGFloat], maxLines: Int, preferFullDownTo floor: CGFloat,
                 caption: Bool, captionRequired: Bool) -> HeroFit
```

The algorithm:
1. Candidates are `hero`, then `short`. Stop trying `hero` below `floor` if a `short` exists.
2. For each size in the ladder, word-wrap greedily at `W − 1`. Each line is measured with `NSString.size(withAttributes: [.font: uiFont, .kern: tracking])`, using `AppFont.uiFont(size:, weight: .bold)` with SF bold as the fallback.
3. A size fails if any single word is wider than `W − 1`, so a word is never broken.
4. A size fits when `lines ≤ (captionRequired ? 1 : maxLines)` and `lines × uiFont.lineHeight + (lines == 1 && caption ? 18.9 : 0) ≤ H`.
5. The caption shows only when the hero takes one line, except when `captionRequired` (sample data) reserves it.
6. If nothing fits: use the last candidate at `ladder.last`, `lineLimit(maxLines)`, `.minimumScaleFactor(0.8)`, tail truncation. This only happens for an unbreakable word in a user's own split name.
7. `nudge = −(LSB(hero first glyph) − LSB(status first glyph))`, clamped to −4…0, via `CTFontGetBoundingRectsForGlyphs`. It lines the hero's stem up with the eyebrow.
8. Render with `.font(...)`, `.tracking(t)`, `.lineLimit(lines)`, `.allowsTightening(false)`, `.offset(x: nudge)`.
9. Wrap the content in a `GeometryReader` so W and H are the real content box.

Results on the 14 Pro, measured with the bundled font:

| Hero | Small (126×126) | Medium (306×126) |
|---|---|---|
| Push / Brazos | 40, 1 line, with caption | 44 |
| Upper body | 36, 2 lines | 44 |
| Chest & shoulders | 26, 2 lines | 36 |
| Free workout | 34, 2 lines | 44 |
| Entrenamiento libre | does not fit at any size, so "Entreno libre" at 36, 2 lines | 34 (full form) |
| Your first workout | 30, 2 lines | 40 |
| Tu primer entrenamiento | does not fit, so "Tu primer entreno" at 26, 2 lines | 26 is below the floor, so "Tu primer entreno" at 40 |
| Mi entrenamiento | does not fit, so "Mi entreno" at 36, 2 lines | 40 (full form) |

"Entrenamiento" is 180 pt wide even at 26 bold, which is why the short forms exist. They appear only where the full form can't fit (§3.7).

### 2.6 The mark

1. Move `BrandMarkShape` out of `BrandMark.swift` into shared `GymBlock/Widgets/KettlebellShape.swift` as an internal `struct KettlebellShape: Shape { enum Part { case iron, keyhole, handle, bell, joins, ironCut } }`.
2. Move the whole `// BEGIN KETTLEBELL OUTLINE … // END` block into the same file, unchanged.
3. Update the comment on line 2 of `scripts/generate-app-icon.swift` to name the new file.
4. `BrandMark` and `KettlebellLock` stay in `BrandMark.swift` and use `KettlebellShape`.

`ironCut` is computed outside the mirrored block. Naively adding the keyhole and filling even-odd would refill the area where the keyhole's head and slot overlap, so use boolean operations (iOS 16+):

```swift
case .ironCut:
  unit = paths.iron.normalized(using: .evenOdd)
           .subtracting(paths.keyhole.normalized(using: .winding))
// fill with FillStyle(eoFill: true)
```

`WidgetMark(size:)`:
- **fullColor (paper or removed):** iron in `tone.ink` (even-odd) with the keyhole in `tone.signal` on top.
- **Accented and vibrant:** `ironCut` in `tone.ink`, so the keyhole is a real hole.
- Always `.unredacted()` and `.accessibilityHidden(true)`.

### 2.7 Background, margins and tap targets

- **Background:** systemSmall and systemMedium use `.containerBackground(for: .widget) { tone.stage }`, flat paper. Circular uses `{ AccessoryWidgetBackground() }`. Rectangular and inline use `{ Color.clear }`.
- **Margins:** keep the system content margins (16 pt on the iPhone Home Screen). Never call `.contentMarginsDisabled()`.
- **Taps:** one `.widgetURL` per widget, with no `Link` and no `Button`.
  - Idle or setup: `gymblock://home?from=<f>`.
  - Running, paused or stale: `gymblock://workout?from=<f>`.
  - The month widget: `gymblock://profile?from=month`.
  - `f` is one of `small | medium | rect | inline | circular | month`.
- **CarPlay:** every configuration gets `.disfavoredLocations(WidgetPlacement.disfavored, for: [.systemSmall])`, where `disfavored` is `[.carPlay]` when `#available(iOS 26, *)`, otherwise `[]`.

---

## 3. Families

**What changes with the state.** Every Home Screen widget keeps the same layout in every state: a status line on top, the hero at the bottom, and at most one grey line under it. Only the status line changes with the state. A rest looks the same as running, because rests belong to the Live Activity.

### 3.1 Up next, systemSmall

The 14 Pro widget is 158 pt with a 126×126 content box. Other sizes: SE 148 → 116, Pro Max 170 → 138.

```
GeometryReader { box in
  VStack(alignment: .leading, spacing: 0) {
    status                     // DM Sans 15 medium (wght 500), 1 line, height 19.5
    Spacer(minLength: 8)
    hero                       // HeroFit(ladder: [40,36,34,30,26,22], maxLines: 2, floor: 30,
                               //         budget: box.height - 19.5 - 8)
    if fit.showsCaption {
      caption.padding(.top, 2) // DM Sans 13 regular, secondary, 1 line, minimumScaleFactor 0.9
    }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
}
```

| State | Status (top) | Hero | Caption |
|---|---|---|---|
| **Setup:** not onboarded, logged out, deleted, or no snapshot | `WidgetMark(32)` | none | "Open GymBlock", 15 medium, secondary, bottom-leading |
| **New user, no split** (`!hasHistory`) | "Up next", emerald, accentable | "Your first workout" (30) / ES "Tu primer entreno" (26) | none |
| **No splits, has history** | "Up next" | "Free workout" (34) / ES "Entreno libre" (36) | none |
| **Split never done** | "Up next" | "Legs" | "First time" / "Primera vez" |
| **Normal** | "Up next" | "Push" (40) | "48 min last time" / "48 min la última vez" |
| **Running, including rest** | `Text(timerInterval: clockStart...max(clockStart, activeUntil), countsDown: false, showsHours: true)`, SF 15 semibold monospaced, ink | the workout name | the exercise, or "Choose an exercise" / "Elige un ejercicio" |
| **Paused** | "Paused" / "En pausa", secondary | the workout name | the exercise, or "Choose an exercise" |
| **Stale** (entry date ≥ `activeUntil`) | "Still working out?" / "¿Sigues entrenando?", secondary, `minimumScaleFactor(0.75)` | the workout name | none |
| **Always-On** (`isLuminanceReduced`) while running | "Training" / "Entrenando", ink, static | the workout name | as running |
| **Sample** (`sample == true`) | as the state | as the state, with `captionRequired: true` (one line) | "Sample data" / "Datos de ejemplo" |

- **Tap:** opens `home` when idle or setup, and `workout` otherwise.
- **VoiceOver:** one combined element, for example "Up next, Push, 48 min last time".

### 3.2 Up next, systemMedium

The 14 Pro widget is 338×158 with a 306×126 content box (SE 289×116). It is Home in miniature, with no button.

```
VStack(alignment: .leading, spacing: 0) {
  HStack(spacing: 14) {
    WeekDots(size: 9, gap: 7)     // 105 × 9; marks for the entry date
    Text(weekLabel)               // DM Sans 15 medium, secondary, lineLimit 1, minimumScaleFactor 0.85
  }                               // row height 19.5
  Spacer(minLength: 8)
  status                          // as in small: "Up next" emerald / clock / Paused / Still working out?
  hero                            // HeroFit(ladder: [44,40,36,34,30,26], maxLines: 1, floor: 34,
                                  //         budget: H - 19.5 - 8 - 19.5 - 19.5)
  detail                          // DM Sans 15 regular, secondary, lineLimit 1, minimumScaleFactor 0.85
}
```

**`weekLabel`** follows Home's rule for each entry date:

| Condition | English | Spanish |
|---|---|---|
| streak > 1 | "N week streak" | "N semanas de racha" |
| streak = 1 | "1 week streak" | "1 semana de racha" |
| `!hasHistory` | "Week 1" | "Semana 1" |
| otherwise | "X of G this week" | "X de G esta semana" |

**`detail`:**

| State | Detail |
|---|---|
| Idle | the full `summary(of:)` line: "6 exercises  ·  48 min last time" (210 pt; ES 237 pt) |
| No split | "Pick exercises as you go." |
| Running or paused | the exercise, or "Choose an exercise" |
| Stale | empty |
| Sample | "Sample data" |

**Other states:**
- The week row stays in every state. Today stays ringed until Finish.
- Setup is the same as small: no dots, the mark at 32 pt and "Open GymBlock".
- Taps work as in small.

### 3.3 Up next, accessoryRectangular

The widget is 160×72 on the 14 Pro (SE 153×68, Pro Max 172×76). It uses SF only and has no background.

```
VStack(alignment: .leading, spacing: 1) {
  status    // SF 13 semibold
  ViewThatFits(in: .horizontal) {
    Text(hero).lineLimit(1)
    Text(heroShort ?? hero).lineLimit(1)
    Text(heroShort ?? hero).lineLimit(1).minimumScaleFactor(0.7)
  }         // SF 22 bold, .primary
  caption   // SF 13 regular, .secondary, 1 line
}
.frame(maxWidth: .infinity, alignment: .leading)
```

| State | Status | Hero | Caption |
|---|---|---|---|
| **Idle** | "Up next", accentable | split / Free workout / Your first workout | "48 min last time", "First time" or none |
| **Running** | the clock (SF 13 semibold monospaced) | the workout name | the exercise, or "Choose an exercise" |
| **Paused** | "Paused", `.secondary` | the workout name | the exercise |
| **Stale** | "Still working out?", `.secondary` | the workout name | none |
| **Always-On** | "Training" replaces the clock | | |
| **Sample** | as the state | | "Sample data" |

- **Setup:** an `HStack(spacing: 6) { WidgetMark(22); Text("Open GymBlock") SF 15 semibold }`.
- **Tap:** as in small, with `from=rect`.

### 3.4 Up next, accessoryInline

The system font, one line, each state wrapped in `ViewThatFits`.

| State | Long form | Short form |
|---|---|---|
| Idle | "Up next · Push" / "Siguiente · Brazos" | "Push" |
| New user | "Your first workout" | short form |
| Running | `Text(hero + " · ") + Text(timerInterval:…)` **[verify that the concatenation renders]** | fallback: `Label { Text(timerInterval:…) } icon: { Image(systemName: "timer") }` |
| Paused | "Push · Paused" / "Brazos · En pausa" | — |
| Stale | "Still working out?" | — |
| Always-On while running | "Push · Training" | — |
| Setup | "Open GymBlock" | — |
| Sample | "Sample data · Push" | "Sample data" |

### 3.5 This month, systemSmall

The content box is W×H, 126×126 on the 14 Pro.

```
VStack(alignment: .leading, spacing: 0) {
  MonthGrid                 // top-aligned
  Spacer(minLength: 8)
  Text(monthName)           // DM Sans 15 medium, secondary, 1 line, bottom-leading
}
```

**Grid geometry** (stable for every month length):
- `pitchY = floor((H − 19.5 − 8) / 6)`: 16 on the 14 Pro, 18 on Pro Max, 14 on SE.
- `dot = round(min(W/7, pitchY) × 0.62)`: 10, 11 and 9.
- Column centre `x_i = dot/2 + i·(W − dot)/6`, so the first and last dots sit flush with the text edge.
- Row centre `y_j = dot/2 + j·pitchY`.
- `lead = (weekday(first) + 5) % 7` and `rows = (lead + length + 6) / 7`, Monday first, as in MonthDots.
- No weekday letters.

**Line and accessibility:**
- `monthName` is `entryDate.formatted(.dateTime.month(.wide))` with the first letter uppercased in `Locale.current`, the same locale rule as Profile ("October", "Octubre").
- There is no tally on the face. The accessibility label is "October, 12 workouts", using t()'d `workout`/`workouts`.

**Trained rule:** a session counts only with non-empty `completedSets`, by `started`, which is Home's rule. Profile's MonthDots counts every session; see §11. Don't touch `Profile.swift`.

| State | Grid | Line |
|---|---|---|
| Setup | none; `WidgetMark(32)` top-leading | "Open GymBlock" |
| New user | all past and future faint, today ringed | month name |
| Normal | emerald trained days | month name |
| Running, rest, paused or stale | unchanged; today fills only after Finish | month name |
| Sample | sample dots | "Sample data" replaces the month name |

**Tap:** `gymblock://profile?from=month`.

### 3.6 This week, accessoryCircular

`side` is the widget size: 72 on the 14 Pro (68 on SE, 76 on Pro Max).
- **Dots:** `d = round(side × 0.097)` (7) on radius `R = side/2 − d/2 − side × 0.07` (27.5). Monday sits at 12 o'clock, `θ_i = −π/2 + i·2π/7`, running clockwise.
- **Centre:** `WidgetMark(side × 0.40)` (about 29 pt), always `ironCut` here. There is never a number in the centre.

| State | Ring | Centre |
|---|---|---|
| New user | all faint, today ringed | mark |
| Normal | trained dots solid and accentable | mark |
| Running, paused or stale | unchanged | mark |
| Setup | none | mark at side × 0.47 |
| Sample | hidden, so sample dots are never shown unlabelled | mark |

- **VoiceOver:** "2 of 5 this week, 3 week streak".
- **Tap:** `home?from=circular`. A running workout opens anyway, because the app shows it first.

### 3.7 Strings

- Every string is pre-localised by the app with `store.t()` and travels in the snapshot.
- The only exceptions are setup without a snapshot, the gallery preview, the placeholder and the control fallback. These use the extension's `Localizable.strings` (en, es).

| English | Spanish | Status |
|---|---|---|
| Up next | Siguiente | exists |
| Paused | En pausa | exists |
| Still working out? | ¿Sigues entrenando? | exists (148 pt, scaled to 0.75 in small) |
| Choose an exercise | Elige un ejercicio | exists |
| Training | Entrenando | exists |
| Sample data | Datos de ejemplo | exists |
| N week streak | N semanas de racha | exists |
| Week 1 | Semana 1 | exists |
| of / this week | de / esta semana | exists |
| min last time | min la última vez | exists |
| Pick exercises as you go. | Elige ejercicios sobre la marcha. | exists |
| 1 exercise / exercises | 1 ejercicio / ejercicios | exists |
| Start workout | Iniciar entrenamiento | exists |
| workout / workouts | entrenamiento / entrenamientos | exists |
| Rest / Rest’s up | Descanso / Descanso terminado | exists |
| **1 week streak** | **1 semana de racha** | NEW in `Spanish.v6`; Home's WeekLine uses it too, which fixes "1 semanas" |
| **First time** | **Primera vez** | NEW in `Spanish.v6` |
| **Open GymBlock** | **Abre GymBlock** | NEW in `Spanish.v6` |

**Short forms, used only when the full form can't fit:** a new `Spanish.widgetShort` in `JourneyLanguage.swift`:
- "Free workout" → "Entreno libre"
- "Your first workout" → "Tu primer entreno"
- "My workout" → "Mi entreno"

"Entreno" is already in the app ("Avg workout" → "Entreno medio").

**Gallery strings** (extension `en.lproj` / `es.lproj` `Localizable.strings`):

| Key | English | Spanish |
|---|---|---|
| Up next | "Up next" / "What's next, or the workout you're in." | "Siguiente" / "Lo siguiente, o el entrenamiento en curso." |
| This month | "This month" / "The days you trained this month." | "Este mes" / "Los días que entrenaste este mes." |
| This week | "This week" / "The days you trained this week." | "Esta semana" / "Los días que entrenaste esta semana." |
| Control | "Start workout" / "Opens GymBlock and starts what's up next." | "Iniciar entrenamiento" / "Abre GymBlock e inicia lo siguiente." |

The extension strings also need "Open GymBlock", "Your first workout" and "Week 1" for the placeholder.

Also add a `Spanish.translate(_:)` static that holds the lookup chain. `GymStore.t()` calls it, so the DEBUG preview can translate without a store.

---

## 4. Control: Start workout

This lives in `GymBlockLive/StartControl.swift` and is added to the bundle inside `if #available(iOS 18.0, *)`.

```swift
@available(iOS 18.0, *)
struct StartWorkoutControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: WidgetKind.startControl, provider: StartControlProvider()) { value in
      ControlWidgetButton(action: OpenGymBlockIntent(value.running ? .workout : .start)) {
        Label(value.title, systemImage: "dumbbell.fill")   // interim; never figure.*
      }
    }
    .displayName("Start workout")
    .description("Opens GymBlock and starts what's up next.")
  }
}
// Provider: previewValue = (running: false, title: localized "Start workout")
//           currentValue() = WidgetSnapshot.load(): running → (true, hero), else (false, labels.startWorkout)
```

**Title and tint:**
- The title only. A subtitle API for buttons isn't confirmed, so don't ship one.
- `.tint(Paper.signal.dark.color)`, because Control Center is always dark.

**`OpenGymBlockIntent`** lives in shared `GymBlock/Widgets/OpenGymBlockIntent.swift`, compiled into both targets:

```swift
enum GymDestination: String, AppEnum { case start, workout
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Destination"
  static var caseDisplayRepresentations: [GymDestination: DisplayRepresentation] = [.start: "Start workout", .workout: "Workout"] }
struct OpenGymBlockIntent: OpenIntent {
  static var title: LocalizedStringResource = "Open GymBlock"
  @Parameter(title: "Destination") var target: GymDestination
  init() {}
  init(_ target: GymDestination) { self.target = target }
  func perform() async throws -> some IntentResult {
    #if !LIVE_EXTENSION
      await MainActor.run { AppRouter.shared.open(target == .start ? .start : .workout, source: "control") }
    #endif
    return .result()
  }
}
```

**In the app:**
- `.start` runs `HomeView.startNext()`, so the Screen Time question stays.
- Only after the splash, only on the `.app` screen, only once the launch hold's questions (the account, a signed-in account's entitlement) are answered and lead to the app, and only within 10 seconds. The hold gives up after 4 seconds, so the app can show before the entitlement answers and the offer wall still follow; a start waits out that gap (or expires in it) rather than leave a workout running, apps shielded, behind the wall. It can never pass onboarding or the offer wall.
- If a workout is already running, the press just shows it.
- A mistaken start is undone by Finish with no sets, which saves nothing.

**Symbol:** the final icon is a custom `gymblock.kettlebell.symbolset` drawn from `KettlebellOutline`, with the keyhole as negative space. The user picks it from rendered options (§11).

---

## 5. Live Activity restyle (`GymBlockLive/GymBlockLive.swift`)

**Colours:** it always uses the dark paper tokens:
- `activityBackgroundTint(Paper.stage.dark.color.opacity(0.92))`;
- text #F3F0EA, secondary #B0ADA8, signal #33C28A;
- `activitySystemActionForegroundColor` is text;
- `keylineTint` is signal.

Delete the private `stage` and `signal` constants (#3EE8B5 mint).

**Type:** SF throughout, with `.monospacedDigit()` on every clock.

**Lock Screen banner** (padding 16, spacing 12):

```
HStack(alignment: .top) {
  VStack(alignment: .leading, spacing: 3) {
    workoutName + " · " + progress   // SF 13 medium, secondary (the 6-pt mint dot is removed)
    exercise                         // SF 17 semibold, text, 1 line
    next                             // SF 15 regular, secondary
  }
  Spacer(minLength: 8)
  VStack(alignment: .trailing, spacing: 2) {
    phaseLabel                       // SF 13 semibold: secondary, or signal when the rest is up
    clock                            // SF 36 semibold monospaced, text, maxWidth 130 trailing
  }
}
bar      // rest: system linear ProgressView tinted text at 0.45, signal when up; other phases: Capsule text 0.12, height 4
button   // Capsule fill text #F3F0EA, label stage #151412, SF 15 semibold, minHeight 36 (existing WorkoutStepIntent)
```

**Clocks.** No range may have its lower bound above its upper bound.

| Phase | Clock |
|---|---|
| Set | `Text(timerInterval: since...Date.distantFuture, pauseTime: pausedAt, countsDown: false)` |
| Ready | the same expression. In `LiveWorkout.sync`, set ready `since = session.started + (session.pausedSeconds ?? 0)`, and `ClockText` uses `state.since` in every phase. This fixes the ready clock that ignored pauses. |
| Rest | time left, as in the app: `Text(timerInterval: since...since.addingTimeInterval(Double(restSeconds)), pauseTime: pausedAt, countsDown: true)` |
| Rest's up (`context.isStale && pausedAt == nil`) | `HStack(spacing: 0) { Text("+"); Text(timerInterval: restEnd...Date.distantFuture, countsDown: false) }` in secondary, with "Rest’s up" and the bar in signal **[verify on a device that it redraws at `staleDate`]** |

**Symbols:** paused `pause.fill`, rest `timer`, set `dumbbell.fill`, ready `dumbbell`. Remove `figure.strengthtraining.traditional`. Once the user approves, the 18-pt mark can replace the ready symbol and the minimal presentation.

**Comment:** fix the stale "turns red" comment.

---

## 6. Data contract

### 6.1 Shared files (app and `GymBlockLive`)

**`GymBlock/Widgets/WidgetSnapshot.swift`**

```swift
import Foundation
enum WidgetKind {
  static let upNext = "com.sodhera.gymblock.upnext", month = "com.sodhera.gymblock.month"
  static let week = "com.sodhera.gymblock.week", startControl = "com.sodhera.gymblock.control.start"
}
struct WidgetSnapshot: Codable, Equatable {
  static let group = "group.com.sodhera.gymblock", key = "gymblock.widget.v1"
  enum State: String, Codable { case setup, idle, running }
  struct Running: Codable, Equatable {
    var exercise: String?        // t(selected.name); nil while choosing
    var clockStart: Date         // started + (pausedSeconds ?? 0)
    var pausedAt: Date?
    var lastActivity: Date       // GymStore.lastActivity
    var activeUntil: Date { lastActivity.addingTimeInterval(3600 + 900) }   // never early, ≤15 min late
  }
  struct Labels: Codable, Equatable {
    var upNext, paused, stillWorkingOut, chooseExercise, training, sampleData, openGymBlock: String
    var weekStreak, weekStreakOne, week1, of, thisWeek, workout, workouts, startWorkout: String
  }
  var version = 1
  var state: State
  var hero: String              // idle: t(split.name) | t("Free workout") | t("Your first workout"); running: t(session.name)
  var heroShort: String?        // Spanish.widgetShort form when profile.language == "es" and one exists
  var detail: String?           // idle: summary(of: split) or t("Pick exercises as you go.")
  var caption: String?          // idle with split: "\(m) " + t("min last time") | t("First time"); else nil
  var sample: Bool              // data.demoLoaded == true
  var days: [Int]               // yyyymmdd of `started`, sessions with completedSets, last 42 days, sorted, unique
  var baseWeek: Int             // yyyymmdd of this Monday at write time
  var priorRun: Int             // consecutive trained Monday-weeks ending the week before baseWeek (uncapped)
  var goal: Int                 // min(7, max(1, baseline?.trainingDays ?? 5))
  var hasHistory: Bool          // any session with completedSets ("Week 1" rule)
  var lastFinished: Date?       // max `ended` of finished sessions (Smart Stack only)
  var running: Running?
  var labels: Labels
  static func load() -> WidgetSnapshot?   // UserDefaults(suiteName: group)?.data(forKey: key) → JSONDecoder; nil if version != 1
  func save()                             // JSONEncoder (default dates) → set(_:forKey:)
}
```

**Never in the snapshot:** the user's name, emails, Screen Time tokens, set or rest state, or blocking state. Split names are the user's own text and stay in the App Group on the device. They never go in URLs or analytics.

**`GymBlock/Widgets/TrainingDays.swift`** holds the pure math used by both Home and the widgets:

```swift
enum DayMark: Equatable { case trained, today, past, future }
enum TrainingDays {
  static var calendar: Calendar   // Calendar.current with firstWeekday = 2
  static func key(_ d: Date, _ c: Calendar) -> Int                 // yyyymmdd from components
  static func date(key: Int, _ c: Calendar) -> Date
  static func monday(of d: Date, _ c: Calendar) -> Date
  static func run(endingAt monday: Date, weeks: Set<Int>, _ c: Calendar) -> Int  // count back while weeks ∋ key
  /// Home's rule, uncapped: this week counts once trained; an empty current week is skipped.
  static func streak(at d: Date, weeks: Set<Int>, _ c: Calendar) -> Int
  /// From a snapshot, for any entry date. W = week of d, B = baseWeek, tB = days has a day in week B:
  /// W ≤ B → (tB ? 1 : 0) + priorRun;  W == B+1 → tB ? 1 + priorRun : 0;  W ≥ B+2 → 0.
  static func streak(at d: Date, baseWeek: Int, priorRun: Int, days: Set<Int>, _ c: Calendar) -> Int
  static func thisWeek(at d: Date, days: Set<Int>, _ c: Calendar) -> Int
  static func week(at d: Date, days: Set<Int>, _ c: Calendar) -> [DayMark]                        // 7, Monday first
  static func month(at d: Date, days: Set<Int>, _ c: Calendar) -> (lead: Int, length: Int, marks: [DayMark])
}
```

`HomeStats.swift` changes in two ways:
- `streakWeeks` becomes `TrainingDays.streak(at: now, weeks: Set(finished.map { key(monday(of: $0.started)) }))`. This removes the 12-week cap; the grid stays 12 weeks.
- `WeekLine` uses `t("1 week streak")` when the streak is 1.

**Other shared files:** `PaperPalette.swift` (with `WidgetTone` and the `widgetTone` environment key), `KettlebellShape.swift`, `HeroFit.swift`, `WidgetViews.swift`, `AppRoute.swift` and `OpenGymBlockIntent.swift`.

`WidgetViews.swift` holds `UpNextSmallView`, `UpNextMediumView`, `UpNextRectView`, `UpNextInlineView`, `MonthSmallView`, `WeekCircularView`, `WeekDots`, `DayDot` and `WidgetMark`. They are pure SwiftUI views that take `(snapshot: WidgetSnapshot?, date: Date)` and read `widgetTone` and `isLuminanceReduced`. They contain no `containerBackground` and no `widgetURL`; the extension's entry views add those.

### 6.2 App side: building and writing (app-only `GymBlock/WidgetSync.swift`)

**`extension GymStore { func widgetSnapshot(now: Date = Date()) -> WidgetSnapshot }`:**
1. `labels` comes from `WidgetSnapshot.Labels(t: t)`. A shared initializer takes the translate closure, so the preview can pass `Spanish.translate`.
2. If `!profile.onboarded`, return `.setup`: labels only, with empty `hero` and `days`.
3. `finished = data.history.filter { !$0.completedSets.isEmpty }`. Weeks, days, `baseWeek`, `priorRun = run(endingAt: thisMonday − 7 days)`, `goal`, `hasHistory` and `lastFinished` all come from it.
4. If `session != nil`, the state is `.running`:
   - `hero = t(session.name)` and `heroShort` from the short forms;
   - `running = .init(exercise: session.selected.map { t($0.name) }, clockStart: session.started + (pausedSeconds ?? 0), pausedAt: session.pausedAt, lastActivity: lastActivity ?? session.started)`.
5. Otherwise the state is `.idle`:
   - `split = workouts.first { $0.id == profile.preferredSplitID } ?? workouts.first` (Home's rule; Home's view-only `free` can't be seen);
   - `firstRun = !hasHistory`;
   - `hero`, `detail` and `caption` as in the struct comments.
6. In `Home.swift`, split `summary(of:)` into `splitSummary(_:) -> (count: String, lastMinutes: Int?)`, keeping `max(1, Int(duration/60))`. `summary(of:)` joins the parts with `"  ·  "` and the widget caption uses `lastMinutes`, so the truncation is the same in both places.

Never call `homeStats()` or `exerciseTrends()` here.

**`@MainActor enum WidgetSync`:**

```swift
private static var written: WidgetSnapshot?
private static var reloadedUpNext, reloadedDays, reloadedControl: WidgetSnapshot?   // per kind
private static var pending: Task<Void, Never>?
private static var enabled: Bool { ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil }

static func sync(_ store: GymStore) {
  guard enabled, GymStore.live === store else { return }
  let next = store.widgetSnapshot()
  guard next != written else { return }           // per-keystroke saves stop here
  let wiped = next.state == .setup && written?.state != .setup
  written = next; pending?.cancel()
  if wiped { flush(); return }                     // log out / delete: names gone now, not in 1 s
  pending = Task { @MainActor in try? await Task.sleep(for: .seconds(1)); if !Task.isCancelled { flush() } }
}
static func flush() {
  pending?.cancel(); pending = nil
  guard enabled, let s = written else { return }
  s.save()
  if s.upNextKey != reloadedUpNext?.upNextKey || drift(s, reloadedUpNext) > 900 {
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.upNext); reloadedUpNext = s }
  if s.daysKey != reloadedDays?.daysKey {
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.month)
    WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.week); reloadedDays = s }
  if s.controlKey != reloadedControl?.controlKey {
    if #available(iOS 18.0, *) { ControlCenter.shared.reloadControls(ofKind: WidgetKind.startControl) }
    reloadedControl = s }
}
```

The reload keys:

| Key | Contents |
|---|---|
| `upNextKey` | the whole snapshot with `running.lastActivity` zeroed (the medium shows the week, so days are included) |
| `drift` | `s.running.lastActivity − reloaded.running.lastActivity`, or 0 |
| `daysKey` | days, baseWeek, priorRun, goal, hasHistory, lastFinished, sample, state, labels |
| `controlKey` | state, hero, labels.startWorkout |

`reloadedUpNext` updates only when Up next actually reloads, so the drift adds up across Lock Screen set taps. A Lock Screen set that only moves `lastActivity` gets written but reloads at most once every 15 minutes. A 60-minute workout logged from the Lock Screen costs about 4 background reloads. Start, exercise changes, pause, resume and finish mostly happen in the foreground, where reloads are free.

**Call sites:**

| File | Change |
|---|---|
| `Model.swift`, `persist()` | `WidgetSync.sync(self)` right after `LiveWorkout.sync(self)`. Never touch `onPersist`, which `CloudSync` owns. This also covers `finish`, `deleteAccount`, `logOut`, the CloudSync merge, demo loading, pause, resume and split edits. |
| `GymBlockApp.init` | after `GymStore.live = store`: `WidgetSync.sync(store); WidgetSync.flush()`. This covers `--ui-reset`, `--demo` and `-workoutStage`, which persist before `live` is set. |
| `GymBlockApp`, scene phase | `.onChange(of: scenePhase)`: `.background` runs `WidgetSync.flush()`; `.active` runs `WidgetSync.sync(store)`. |
| `WorkoutStepIntent.perform()` | under `#if !LIVE_EXTENSION`, after `await update?.value`: `await MainActor.run { WidgetSync.flush() }`. The app is suspended right after a Lock Screen tap, so the debounce would never fire. |

### 6.3 Extension side: timelines (`GymBlockLive/GymBlockWidgets.swift`)

`struct GlanceEntry: TimelineEntry { let date: Date; let snapshot: WidgetSnapshot?; let relevance: TimelineEntryRelevance? }`. The views derive their phase from `(snapshot, date)`: `setup | idle | running | stale`, where stale means `date ≥ activeUntil`.

`midnights(now)` is `(1...7).map { cal.date(byAdding: .day, value: $0, to: cal.startOfDay(for: now))! }` in `Calendar.current`, so daylight saving is handled.

**`UpNextProvider.getTimeline`:**

| Snapshot | Entries | Policy |
|---|---|---|
| none (fresh install, or before the first unlock) | `[setup(now)]` | `.after(now + 1 h)`; this is the only polling, and it stops once a snapshot exists |
| `.setup` | `[setup(now)]` | `.never` |
| `.idle` | `[now] + midnights` (the medium's week line), relevance 0.1 | `.atEnd` |
| `.running`, `now ≥ activeUntil` | `[stale(now)] + midnights`, relevance 0.5 until `activeUntil + 1 h`, then 0.1 | `.atEnd` |
| `.running`, otherwise | `[running(now)` with relevance 1.0 until `activeUntil`, `stale(activeUntil)` with 0.5 for 3600 s`] + midnights` (1.0 before `activeUntil`, 0.5 in the stale hour, 0.1 after) | `.atEnd` |

- The clock's range ends at `activeUntil`, so a forgotten workout can never read 14:32:10. The stale entry replaces it at the same moment.
- The midnights stay in while a workout runs or sits stale: the medium's week row and its label are drawn from the entry's date, so without them a workout left running on Sunday would keep Sunday's week up until the app was opened.
- When activity resumes, `lastActivity` jumps by more than 15 minutes, so the drift rule reloads the widget. Stale can't get stuck.

**`MonthProvider`:** entries at `[now] + midnights`, policy `.atEnd`. If `now < lastFinished + 2 h`, the first entry gets relevance 0.6 with duration `lastFinished + 2h − now` ("today's dot just turned emerald"). Otherwise 0.1.

**`WeekProvider`:** entries at `[now] + midnights`, policy `.atEnd`, with no relevance.

Each entry recomputes the marks, streak, `thisWeek`, the month grid and the month name for its own date. That covers the today ring, the Monday reset and the month rollover without app reloads.

**Gallery and placeholder:**
- `getSnapshot`: when `context.isPreview` and there is no snapshot, or it is a setup snapshot, show a **new-user** fixture built from the extension's strings (faint week with today ringed, "Your first workout", "Week 1"). Never sample numbers. Otherwise show the first timeline entry.
- `placeholder`: the new-user fixture, redacted by the system except the mark.

**Configurations:**

```swift
StaticConfiguration(kind: WidgetKind.upNext, provider: UpNextProvider()) { UpNextEntryView(entry: $0) }
  .configurationDisplayName("Up next").description("What's next, or the workout you're in.")
  .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
  .disfavoredLocations(WidgetPlacement.disfavored, for: [.systemSmall])
// MonthWidget: [.systemSmall]; WeekWidget: [.accessoryCircular]
```

The bundle:

```swift
@main struct GymBlockLiveBundle: WidgetBundle {
  var body: some Widget {
    WorkoutLiveActivity(); UpNextWidget(); MonthWidget(); WeekWidget()
    if #available(iOS 18.0, *) { StartWorkoutControl() }
  }
}
```

Each entry view resolves `WidgetTone` from `widgetRenderingMode`, `showsWidgetContainerBackground` and `colorScheme`, sets `.environment(\.widgetTone, tone)`, then applies `.containerBackground` and `.widgetURL` as described in §2.7.

---

## 7. Deep-link routing

**`GymBlock/Widgets/AppRoute.swift`** (shared):

```swift
enum AppRoute: String { case home, start, workout, profile
  init?(url: URL) { guard url.scheme == "gymblock", let h = url.host, let r = AppRoute(rawValue: h) else { return nil }; self = r }
  static func url(_ r: AppRoute, from: String) -> URL { URL(string: "gymblock://\(r.rawValue)?from=\(from)")! }
  static func source(_ url: URL) -> String   // "from" query item, whitelisted to [a-z]{1,12}, else "link"
}
```

**`GymBlock/AppRouter.swift`** (app only):

```swift
@MainActor final class AppRouter: ObservableObject {
  static let shared = AppRouter()
  struct Request: Equatable { let route: AppRoute; let at: Date; var fresh: Bool { Date().timeIntervalSince(at) <= 10 } }
  enum Screen { case launch, app, other }
  @Published private(set) var ready: Request?          // pending, but only while screen == .app
  private var pending: Request? { didSet { update() } }
  var screen: Screen = .launch { didSet { if screen == .other { pending = nil }; update() } }
  private func update() { ready = screen == .app ? pending : nil }
  func openURL(_ url: URL) {                           // widgets and links
    guard let r = AppRoute(url: url) else { return }
    #if !DEBUG
      if r == .start { return }                        // a link can never start a workout in Release
    #endif
    open(r, source: AppRoute.source(url))
  }
  func open(_ r: AppRoute, source: String) {           // also called by OpenGymBlockIntent
    Analytics.track("widget_opened", ["route": r.rawValue, "from": source])
    guard screen != .other else { return }
    pending = Request(route: r, at: Date())
  }
  func consume(_ r: Request) { if pending == r { pending = nil } }
}
```

**Wiring:**

| Where | Change |
|---|---|
| `GymBlockApp.swift:53` | `.onOpenURL { url in if AppRoute(url: url) != nil { AppRouter.shared.openURL(url) } else { account.handle(url) } }`. The auth callback (`gymblock://auth/callback`) has host `auth`, so it still reaches `account.handle` unchanged. `Account.swift` is untouched. |
| `RootView` | `.onChange(of: shown, initial: true) { _, s in AppRouter.shared.screen = s == .app ? .app : s == .launch ? .launch : .other }`. `shown == .app` means the splash has lifted. Onboarding, sign-in, notices and the paywall drop any route. Also `.onChange(of: settled, initial: true) { _, s in AppRouter.shared.settled = s }`, where `settled` is `screen == .app` with the launch hold's questions answered; the router holds a `.start` (only) until it is true. |
| `GymNavigationView` | observe the router. In `.onChange(of: router.ready, initial: true)`, consume and drop the route when the screen is `.workout` or `.summary`. A running workout and the summary come first; the "Still working out?" alert only exists in `.workout`. |
| `MainTabs` | in `.onChange(of: router.ready, initial: true)`: `.home` and `.workout` set `place = .home` and consume; `.profile` sets `place = .profile` and consumes; `.start` sets `place = .home` and leaves the request for HomeView. |
| `HomeView` | in `.onChange(of: router.ready, initial: true)`: if `ready?.route == .start`, consume it, then call `startNext()` only if it is `fresh`. `startNext()` keeps the Screen Time question and the same `nextSplit`. |
| `AppConfig.offline` | add `$0.hasPrefix("-widgetPreview")`. |

---

## 8. Project, entitlements and Info.plist

**New file `GymBlockLive/GymBlockLive.entitlements`:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.application-groups</key>
  <array><string>group.com.sodhera.gymblock</string></array>
</dict></plist>
```

**`project.yml`, the `GymBlockLive` target** (then run `xcodegen`):

```yaml
  GymBlockLive:
    type: app-extension
    platform: iOS
    sources:
      - path: GymBlockLive
        excludes: ["*.entitlements"]          # includes en.lproj / es.lproj Localizable.strings
      - GymBlock/Widgets                       # shared: snapshot, TrainingDays, palette, mark, HeroFit, views, route, intent
      - GymBlock/WorkoutActivity.swift
      - GymBlock/WorkoutStepIntent.swift
      - GymBlock/AppFont.swift
      - GymBlock/Fonts/DMSans.ttf              # resources phase
    info:
      path: GymBlockLive/Info.plist
      properties:
        CFBundleDisplayName: GymBlock
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        UIAppFonts: [DMSans.ttf]
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.sodhera.gymblock.live
        CODE_SIGN_ENTITLEMENTS: GymBlockLive/GymBlockLive.entitlements
        SWIFT_ACTIVE_COMPILATION_CONDITIONS: $(inherited) LIVE_EXTENSION
        TARGETED_DEVICE_FAMILY: '1'
        MARKETING_VERSION: '1.0.0'
        CURRENT_PROJECT_VERSION: '1'
        SKIP_INSTALL: YES
```

The app target already picks up everything under `GymBlock/` automatically, so it needs no change.

**What may not go into `GymBlockLive`:**
- `Shared/BlockingPass.swift` (it uses ManagedSettings and DeviceActivity);
- `GymStore`, `Analytics`, `CloudSync`, `AppBlocking`, `AppRouter` or `WidgetSync`;
- Supabase, RevenueCat or any other package.

Shared files reach app-only types only inside `#if !LIVE_EXTENSION`.

**Edits to existing files:**
- `AppFont.swift`: wrap `styleBars()` in `#if !LIVE_EXTENSION`.
- `BrandMark.swift`: the shape moves out (§2.6).
- `OnboardingPremium.swift`: `JourneyTheme.paper` reads the `Paper.*` constants. The values are identical.
- `Design.swift`: add `Spanish.translate`.
- `JourneyLanguage.swift`: new `v6` keys and `widgetShort`.
- `LiveWorkout.swift`: the ready `since`.
- `scripts/generate-app-icon.swift`: the comment.

**`Profile.swift` is untouched.**

**Signing.** Adding the App Group to `com.sodhera.gymblock.live` changes that App ID's provisioning profile on the first device build. The simulator needs nothing.

---

## 9. DEBUG-only preview: `-widgetPreview`

**Files and launch:**
- `GymBlock/WidgetPreview.swift`, entirely inside `#if DEBUG`.
- In `GymBlockApp.body`, the WindowGroup shows `WidgetPreviewScreen()` when `ProcessInfo.processInfo.arguments` contains `-widgetPreview`; otherwise it shows `RootView` as today.
- Usage is `-widgetPreview <page>`, where page is `home` (the default), `dark`, `tinted`, `lock`, `standby`, `spanish` or `live`.
- A segmented picker at the top switches pages by hand.
- The preview never writes the snapshot and never creates a `GymStore`. Spanish strings come from `Spanish.translate`.

**True sizes:**
- `WidgetMetrics.for(screenWidth:)` holds Apple's published iPhone sizes:

| Screen width | Small | Medium | Circular | Rectangular | Inline |
|---|---|---|---|---|---|
| 430 / 428 | 170 | 364×170 | 76 | 172×76 | 257×26 |
| 393 / 390 (14 Pro, the user's) | 158 | 338×158 | 72 | 160×72 | 234×26 |
| 375×812 | 155 | 329×155 | 72 | 157×72 | 225×26 |
| 375×667 | 148 | 321×148 | 68 | 153×68 | 225×26 |

- Any other width falls back to the 393 values.
- System families get 16-pt content margins and a continuous corner radius of `22 × side / 158`.

**Pages:**

| Page | Background | Widgets |
|---|---|---|
| `home` | wallpaper gradient #8FA3B5 → #D9C7B0 | `.paper`, light scheme |
| `dark` | wallpaper #1D2530 → #3A2F27 | `.paper`, dark scheme |
| `tinted` | dark wallpaper | `.accented` with `tint: #E8C07A`, the background replaced by `.white.opacity(0.12)` |
| `lock` | dark photo-like gradient | accessories in `.vibrant`; a circle of `.white.opacity(0.15)` stands in for `AccessoryWidgetBackground`; a second row sets `.environment(\.isLuminanceReduced, true)` over a dimmed background (Always-On) |
| `standby` | black | `.removed` |
| `spanish` | as `home` | Spanish fixtures, with each short form shown next to the full form it replaces |
| `live` | as `home` and `dark` | `WidgetSnapshot.load()` from the App Group in every family, which proves the app's write path |

**Rows on each page:** one row per state:
- setup, new user, normal, split never done, Free workout with history, running, paused, stale and sample;
- each row has an Up next small and a This month small side by side, then the medium full width, then the circular and rectangular together, then inline;
- under each row, an 11-pt grey label for the state;
- at the foot of `home`, the same hero ("Push" at 40 bold) rendered in DM Sans and in SF Pro, to catch a silent fallback to SF.

**Fixtures:**
- Built in code, with clocks relative to `Date()`.
- Running started 14 minutes ago with "Bench press"; paused 5 minutes ago; stale has `lastActivity` 2 hours ago; streak 3; trained days on this week's Monday and Wednesday.
- Fixture numbers appear only in this debug screen.

**Screenshot recipe** (on a throwaway simulator):

```
xcrun simctl launch booted com.sodhera.gymblock -widgetPreview <page>
xcrun simctl io booted screenshot <file>.png
```

Also add `#Preview(as: .systemSmall) { UpNextWidget() } timeline: { … }` for each family, for the canvas.

---

## 10. Acceptance checklist

### Build and boundaries
- [ ] `xcodegen` runs; the app and the embedded `GymBlockLive` build for the simulator with no new warnings.
- [ ] `nm`/link check: `GymBlockLive` has no symbols from Supabase, RevenueCat, ManagedSettings, `GymStore`, `Analytics` or `CloudSync`.
- [ ] `Profile.swift` is unchanged (`git diff` shows only the user's own edits).
- [ ] The `KettlebellOutline` block is byte-identical in `KettlebellShape.swift` and `scripts/generate-app-icon.swift`. Running `swift scripts/generate-app-icon.swift 180 /tmp/i.png --mask` still produces the same icon.

### Tests (`GymBlockTests`)
- [ ] **`TrainingDays`:**
  - `streak(at:weeks:)` equals the old `homeStats` streak on fixtures of 12 weeks or fewer;
  - a 20-week run reads 20;
  - an empty current week is skipped;
  - the first empty earlier week breaks the streak;
  - the snapshot formula equals `streak(at:weeks:)` for `now` and for `now + 1…13 days`;
  - week and month marks are correct across a daylight-saving change and at the month and week boundaries.
- [ ] **Snapshot:**
  - after `logOut()` and after `deleteAccount()` it is `.setup`, with an empty `hero` and `days`;
  - `sample` is true after `loadDemoIfEmpty`;
  - `heroShort` is set only in Spanish and only for "Free workout", "My workout" and "Your first workout";
  - a session with only failed sets doesn't count as trained;
  - `summary(of:)` output is unchanged after the refactor.
- [ ] **WidgetSync:** a change only to `lastActivity` of 900 s or less doesn't reload Up next; a cumulative drift above 900 s does. Verify with a `#if DEBUG` reload counter.
- [ ] **Routes:**
  - `gymblock://auth/callback?code=x` goes to `account.handle` and is not parsed as a route;
  - `gymblock://home?from=small` parses with source `small`;
  - `start` arriving by URL is refused when `DEBUG` is off (test through an injectable flag).

### Screenshots (AGENTS.md requires real ones)
- [ ] The `-widgetPreview` pages home, dark, tinted, lock, standby, spanish and live, at least once each.
- [ ] Real simulator Home Screen, with widgets added through long-press → Edit → Add widget:
  - Up next small and medium with This month, in light, dark, and the iOS 26 tinted and clear modes;
  - in tinted and clear modes, the keyhole shows as a hole, trained dots carry the accent and future days are fainter than past ones.
- [ ] Real Lock Screen: Week circular, Up next rectangular and inline. Also StandBy (landscape, charging): dark tokens, with ink never on black.
- [ ] States, each on a throwaway simulator:

| Launch | State to check |
|---|---|
| `--ui-reset` | setup ("Open GymBlock", the mark), then the new-user state after `--skip-onboarding` |
| `--demo` | "Sample data" on small, medium, rectangular and month; the circular hides its ring |
| `-workoutStage active` | ticking SF clock, workout name as hero, exercise caption |
| `-workoutStage rest` | identical to active |
| `-workoutStage paused` | "Paused", no clock |
| `-workoutStage stale` | "Still working out?", no clock |

- [ ] Spanish (`profile.language = "es"`):
  - "Entreno libre" at 36 on two lines in small, "Entrenamiento libre" at 34 in medium;
  - "¿Sigues entrenando?" fits;
  - "1 semana de racha" (also on Home).
- [ ] **DM Sans really renders in the real widget**: its glyphs match the in-app preview and differ from the SF reference row. If the variation axes are lost in the widget archive (bold renders as regular), set `WidgetType.useDMSans = false` and re-shoot.
- [ ] The running clock stops at the upper bound of its range and doesn't count past it. Check with a fixture whose `activeUntil` is 2 minutes away.
- [ ] Live Activity on the Lock Screen and Dynamic Island for `-workoutStage active`, `rest`, `restUp` and `paused`:
  - dark paper tokens, no mint and no figure symbol;
  - the rest counts down; at rest's up it shows "Rest’s up" in emerald and a grey `+0:12` overtime;
  - the ready clock leaves out paused time.

### Behaviour
- [ ] Deep links:
  - `xcrun simctl openurl booted "gymblock://home?from=test"`, `…profile…` and `…workout…` land correctly;
  - the same links during onboarding and on the paywall do nothing, and nothing happens 10 seconds later.
- [ ] Control (iOS 18+ simulator Control Center):
  - idle: the app opens and the workout starts, with the "Apps won’t be blocked" question when access is off;
  - running: the press opens the workout;
  - pressed from the paywall: nothing starts.
- [ ] Wipe: `logOut()` and `deleteAccount()` remove every split name from every widget at once, with no 1-second window.
- [ ] Budget: a 20-set workout driven from the Lock Screen logs 6 or fewer Up next reloads (`#if DEBUG` NSLog in `flush`).
- [ ] No widget shows "blocked", a lock glyph, red, a pill, a capsule, a chart, a number in the circular's centre, or a clock as the hero.

### Docs
- [ ] README.md: the widgets, the control, `-widgetPreview`, and the App Group on the live extension.
- [ ] VALIDATION.md: these checks and the screenshots.
- [ ] DESIGN.md: a Widgets section covering tokens, Tone, the hero ladder, and where emerald may be used.

---

## 11. Decisions for the user, and follow-ups

None of these block the build; the build uses the default shown. A few need a yes or no before release.

1. **The mark at 24–32 pt with the keyhole cut out**, in tinted mode, on the Lock Screen and in StandBy. AGENTS.md doesn't allow shipping one guess at the mark.
   - Render the true geometry next to a keyhole enlarged 1.25× for small sizes, and ask.
   - Default during development: the true geometry.
2. **The control symbol:** render 2–3 kettlebell `.symbolset` options in Control Center and the Lock Screen slot, and ask. Interim: `dumbbell.fill`.
3. **Spanish short forms** ("Entreno libre", "Tu primer entreno", "Mi entreno") appear only where the full form can't fit. The `spanish` preview page shows them next to the full forms. Default: on.
4. **Home's streak is no longer capped at 12 weeks**, because Home and the widgets share one function. This is a truth fix: today a 20-week run reads "12 week streak". Tell the user it changed. To restore the cap, pass it in one place in `TrainingDays.streak`.
5. **Fading future days on Home's WeekLine** to match the widgets. Default: Home unchanged.
6. **Follow-up:** Profile's MonthDots counts sessions with no completed sets, unlike Home and the widgets. Align it after the user's uncommitted `Profile.swift` edits land.
7. **Device build:** the App Group on `com.sodhera.gymblock.live` changes that App ID's provisioning profile. Ask before the first build to the user's iPhone 14 Pro.