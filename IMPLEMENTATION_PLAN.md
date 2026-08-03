# Renova — Implementation Plan: v3.1 → v4

**Status:** Ready for implementation · approved design directions: mockups **A** (Today, Control Grid v2) and **C** (Trends with baseline bands). Mockup B (Daybreak) is **rejected** — do not import anything from it.
**Companions:** [`PRD.md`](./PRD.md) · [`TECH_SPEC.md`](./TECH_SPEC.md) · design-review artifact (mockups A & C): https://claude.ai/code/artifact/4a2f8269-c11b-4522-ba9f-eeaed3074822
**Written:** 2026-08-03

This plan is written to be executed phase-by-phase by an implementing model. Every phase lists the files to touch, the exact behavior, and acceptance criteria. Phases are ordered by dependency; do not reorder. Complete and verify one phase before starting the next.

---

## 0. Ground rules (read first, apply everywhere)

1. **Do not touch** the following — they are correct and are the riskiest code in the app:
   - `Renova/Services/Bluetooth/*` (BLE stack)
   - `Packages/RecoveryKit/Sources/RecoveryKit/{RMSSDCalculator,ArtifactFilter,OrthostaticCalculator,HRMeasurementParser,GateLogic,LocalDate}.swift`
   - The measurement protocol itself (phase durations, 75s cap, confirm-based stand cue) in `MeasurementSessionViewModel` — Phase 5 *adds* cues to it but changes no timing logic.
   - Gating rules (questionnaire-first, history lock). Never weaken a gate.
2. **Brand laws** (from PRD §5): local-first, no network, no composite "readiness score," gate before glance. Any feature that would violate one is out of scope regardless of what seems helpful.
3. **Schema changes are additive only.** `DayRecord` / `MeasurementRecord` fields may be added with optional types; never renamed or removed. SwiftData lightweight migration must succeed on existing data.
4. **Visual system:** everything stays in the Control Grid language — flat surfaces, square corners (`cornerRadius: 0` on cards), 1px `CGTheme.line` hairlines, 3px ink band under screen headers, mono uppercase section labels. New UI must be indistinguishable in vocabulary from existing screens.
5. **Copy voice rule:** chrome speaks instrument (mono, uppercase, terse: `TO-DO`, `TRENDS`, `N=9`); any sentence addressed to the user speaks human ("All done. Here's your readout."). No "SYSTEM/OPERATOR" cosplay in new copy.
6. **Pure logic goes in RecoveryKit with tests.** Anything computable without UIKit/SwiftUI (trends, correlations, streaks, CSV) is a RecoveryKit source file plus a test file. Run `swift test` from `Packages/RecoveryKit` after each phase that touches it.
7. **Verification each phase:** `xcodebuild -project RecoveryDeck/Renova.xcodeproj -scheme Renova -destination 'generic/platform=iOS Simulator' build` (or open in Xcode), plus `swift test` in the package, plus the phase's acceptance criteria in the simulator. The project is generated from `RecoveryDeck/project.yml` (XcodeGen) — **if you add targets or files that the pbxproj doesn't pick up automatically, edit `project.yml` and run `xcodegen`**, don't hand-edit the pbxproj.
8. One git branch per phase (`phase-1-theme`, `phase-2-today-v2`, …), commit at each acceptance criterion.

---

## Phase 1 — Theme groundwork: status trio + coral semantics

*Everything later depends on these tokens. Small, mechanical, do it first.*

### 1.1 Add status colors to `CGTheme` (`Features/Questionnaire/ControlGridTheme.swift`)

```swift
// Status trio — CVD-validated. NEVER shown without an accompanying direction
// label (PRD §6.6 requires labeled direction anyway).
static let statusOk    = Color.dynamic(light: 0x0F7A5C, dark: 0x3DDCB8)  // inside ±1 SD band
static let statusWatch = Color.dynamic(light: 0xD4A017, dark: 0xE3B341)  // 1–1.5 SD out
static let statusAlert = Color.dynamic(light: 0xE8331B, dark: 0xFF5A3D)  // >1.5 SD out (== accent)
```

Add one shared helper (new file `Features/Shared/BaselineLight+Color.swift`):

```swift
extension BaselineLight {
    var color: Color {
        switch self {
        case .green: CGTheme.statusOk
        case .yellow: CGTheme.statusWatch
        case .red: CGTheme.statusAlert
        }
    }
}
```

Replace the two duplicated `private func color(for:)` helpers (in `TodayView` and `MeasurementSessionView`) with this extension. Raw `.green/.yellow/.red` must no longer appear anywhere in the app (the `.orange` quality note in `DayDetailView` becomes `CGTheme.statusWatch`).

### 1.2 Coral semantics sweep — "coral means attention, ink means fact"

Coral (`CGTheme.accent`) remains for: CTAs, pending markers, alerts/danger, the live "today" dot on charts, active-tab underline. It is **removed from metric values**:

| File | Change |
|---|---|
| `TodayView.readout()` | value text `CGTheme.accent` → `CGTheme.ink` |
| `MeasurementSessionView.metric()` | value text `CGTheme.accent` → `CGTheme.ink` |
| `DayDetailView.metricRow()` / `scoreRow()` | value text `CGTheme.accent` → `CGTheme.ink` |
| `QuestionnaireView.metricRow` | the selected-value numeral may stay coral (it *is* an interaction highlight) — leave as is |
| `DayDetailView.habitRow` | `YES` in coral / `NO` in teal is inverted semantics (yes-alcohol isn't an alert, no isn't "good") — set both to `CGTheme.ink`, keep the mono weight |

**Acceptance:** app builds; grepping the app target for `foregroundStyle(.green` / `.yellow` / `.red` / `.orange` returns nothing; visual pass of all screens in light and dark shows values in ink.

---

## Phase 2 — Shared chart component: `BandChart`

*One component powers the Today sparkline (Phase 3) and the Trends charts (Phase 4). Build it once, alone, with previews.*

### 2.1 RecoveryKit: trend series (new file `Sources/RecoveryKit/TrendSeries.swift` + tests)

```swift
public struct TrendPoint: Sendable, Equatable {
    public let localDate: String   // "yyyy-MM-dd"
    public let value: Double
}

public struct TrendSeries: Sendable, Equatable {
    public let points: [TrendPoint]      // oldest → newest, gaps simply absent
    public let normMean: Double?         // nil until >= BaselineCalculator.minimumPriorDays prior values
    public let normSD: Double?
    /// Per-point light using BaselineCalculator.assess against values strictly
    /// before that point (same semantics as AppViewModel.analyze).
    public func light(at index: Int, sdFloor: Double) -> BaselineLight?
}

public enum TrendBuilder {
    /// values: (localDate, value) unordered ok; windowDays: how many trailing
    /// days to include in `points`; band computed from ALL prior values via
    /// BaselineCalculator (60-day window, same sdFloor rules).
    public static func series(values: [(String, Double)], windowDays: Int, sdFloor: Double) -> TrendSeries
}
```

Tests (`TrendBuilderTests.swift`): empty input; fewer than 7 prior days → nil band; band matches `BaselineCalculator.assess` mean/SD for a known fixture; window trimming; per-point lights match direct `assess` calls.

### 2.2 App: `Features/Shared/BandChart.swift`

A SwiftUI view drawing with **`Path`/`Canvas` directly — do not add Swift Charts** (its default styling fights the Control Grid look and needs more override code than drawing four primitives).

Inputs: `series: TrendSeries`, `height: CGFloat`, `showXAxisDates: Bool`.
Renders, in this z-order, per mockup C:

1. Band rect: `mean ± 1 SD` mapped to y, fill `CGTheme.statusOk.opacity(0.10)` (skip if band nil).
2. Mean line: dashed 2-3, 1px, `CGTheme.lineStrong`.
3. Data polyline: 2px, `CGTheme.ink`, round joins; simple straight segments (no smoothing).
4. Off-band points (`light == .yellow || .red`): 3px dot in that light's color with a 1.5px `CGTheme.surface` ring.
5. Newest point: 4px dot `CGTheme.accent` with 2px `CGTheme.surface` ring — always drawn last.
6. Y-domain: min/max of (values ∪ band edges) padded 10%; never forced to zero (these are physiological ranges).
7. If `showXAxisDates`: first / middle / last date as `dd MMM` uppercased, `CGTheme.monoSmall`, `inkFaint`.

No touch interaction in this phase. Add SwiftUI previews: full band, building (no band), single point, dark mode.

**Acceptance:** previews match mockup C's chart anatomy; package tests green.

---

## Phase 3 — Today v2 (mockup A)

All in `Features/Today/TodayView.swift` unless noted. Screen order becomes: band → greeting → **TODAY'S READING** (hero) → tip → **TO-DO** → quote → **LEARN**.

### 3.1 Hero readout block (replaces `readoutsGrid`)

Only when questionnaire + measurement are both done. One bordered card (`CGTheme.line` 1px):

- Top row: label `RMSSD` (`monoSmall`, `inkFaint`) left; delta right — `"+7 VS 7-DAY"` in `monoSmall` bold, colored by sign *relative to what's good for that metric* (rMSSD up = `statusOk`; if the 7-day avg is unavailable, omit). Delta = today − mean of last 7 prior measured days, formatted `%+.0f`.
- Number: rMSSD at **44pt bold monospaced, `CGTheme.ink`**, unit ` ms` at 14pt `inkFaint`.
- Sparkline: `BandChart` of the last **14** measured days of rMSSD (`TrendBuilder`, `sdFloor: 1`), height 44, no x-axis dates.
- Context line: status dot (7px square, radius 2 — matches existing dot vocabulary) + human sentence from the existing `BaselineStatus`:
  - established+green: `"Inside your 60-day normal range"`
  - established+yellow/red: direction-labeled, e.g. `"Below your usual range"` / `"Higher than your usual range"`
  - building: `"Baseline building — N of 7 days"` with `lineStrong` dot.
- Sub-row (1px divider above, vertical divider between): `RHR` and `GAP (PEAK)` — 17pt bold mono value in ink, label above in `monoSmall`, and a small direction line below each (`▪ usual` / `▪ higher than usual` etc.) in that metric's status color. Orthostatic-skipped → gap cell shows `skipped` in `inkFaint`.

Data: extend `AppViewModel` with

```swift
struct TrendData { let rmssd: TrendSeries; let rhr: TrendSeries; let gapPeak: TrendSeries }
func trendData(windowDays: Int) -> TrendData   // from historyDays(limit: 90), measured days only
func sevenDayDelta(for metric: ...) -> Double? // today vs mean of last 7 prior measured days
```

### 3.2 Tip card

Keep `ResultsAnalyzer` output but retitle the card content: bold `Read:` prefix then the tip sentence (per mockup A), on `surface2`. The per-line light rows move out of the tip card — their information now lives in the hero block; keep only the `maturityNote` lines if present.

### 3.3 To-do rows

- Remove `.opacity(state == .done ? 0.6 : 1)` — done rows stay full-opacity.
- Done questionnaire row: subtitle becomes `7 SCORES LOGGED`, trailing tag becomes `EDIT` in `inkFaint` (it opens the editor — now it says so).
- Done measurement row: subtitle `SESSION HH:MM · QUALITY OK` (from `measurement.measuredAt` + `hrvQuality`), tag `DONE` in `statusOk`.
- Marker/tag colors: pending stays coral; done uses `statusOk` (replaces `accent2` here).

### 3.4 Quote demoted

Move `quoteBlock` below `todoTable`, above `LEARN`. Show it **only after both tasks are done** (the reward). Delete nothing — `DailyQuote` is untouched.

**Acceptance:** with seeded history (see §Seeding below), Today matches mockup A: 44pt hero, band sparkline, status sentence, sub-row with direction lines, quote at bottom; zero-history day still renders sanely (hero hidden until measurement exists, building copy correct); dark mode pass.

---

## Phase 4 — Trends tab (mockup C)

### 4.1 Rename

`AppTab.history` label `HISTORY` → `TRENDS` (`App/ControlGridTabBar.swift`). Keep the glyph. Header band in `HistoryView`: title `TRENDS`, right meta `28 DAYS · N LOGGED`.

### 4.2 Charts (top of `HistoryView`, above LOG, only when unlocked and ≥ 2 measured days)

Two chart cards, each: section label (`RMSSD · MS`, `RHR · BPM`), then a bordered card containing a header row — left `60-DAY MEAN 58 ± 9` (`monoSmall`, from series band, omit if building), right `TODAY 62` — and a `BandChart` (28-day window; rMSSD height 84 with x-axis dates, RHR height 56 without). If today has no measurement, the "TODAY" slot shows `—`.

Add a third card `GAP (PEAK) · BPM` **only if** ≥ 7 non-skipped orthostatic days exist in the window.

### 4.3 Log list

Existing `dayRow` gains a status dot: compute the day's rMSSD light via `TrendSeries.light(at:)` (or `inkFaint` square for partial days, as now). Right side becomes `62 ms · 46 bpm` (mono, `inkDim`). Keep `PARTIAL` tag and the chevron. `DayDetailView` unchanged apart from Phase 1 colors.

**Acceptance:** matches mockup C with seeded data; empty and locked states unchanged; building state (< 7 days) shows charts without band and a `BASELINE BUILDING — N/7` note in the card header; scrolling smooth with 90 days seeded.

---

## Phase 5 — Session cues: voice + haptic (PRD §6.5)

### 5.1 Setting

`@AppStorage("cueStyle")` with `enum CueStyle: String { case haptic, voice, both }`, default `.both`. Settings → RITUAL section, row "Session cues" with the segmented control styled like the existing baseline-window `Picker` (`HAPTIC / VOICE / BOTH`).

### 5.2 `Services/Cues/SessionCueService.swift` (new)

```swift
@MainActor final class SessionCueService {
    func speak(_ line: String)   // AVSpeechSynthesizer, rate ~0.5, en-US
    func cue(_ event: CueEvent)  // reads cueStyle; haptic and/or speech
}
enum CueEvent { case settleStart, lyingStart, standNow, standingStart, done }
```

Spoken lines: settleStart `"Lie still"`, lyingStart `"Measuring. Stay lying."`, standNow `"Stand up now"`, standingStart `"Sixty seconds. Stand still."`, done `"Done"`.
Audio session: `AVAudioSession` category `.playback`, options `[.duckOthers]`, activated on first speech, deactivated (`notifyOthersOnDeactivation`) after. `.playback` intentionally sounds through the silent switch — the user's eyes are closed and this is the whole point; PRD notes the open question, this is the decision.

### 5.3 Wiring (`MeasurementSessionViewModel`)

Inject `SessionCueService` (default instance). Call sites — *add lines only, change no timing logic*:
- `runSettle()` start → `.settleStart`
- `runLying()` start → `.lyingStart`
- `enterWaitingForStand()` → `.standNow` (keep the existing double-buzz as the haptic half)
- `runStanding()` start → `.standingStart`
- `finish()` → `.done` (keep `celebrate()`)

Haptic-only style must reproduce exactly today's behavior. `cancel()` also stops any in-flight speech.

**Acceptance:** with VOICE or BOTH, phone speaks at each transition with screen untouched and eyes-closed timing intact; HAPTIC behaves byte-identical to current; silent switch does not mute voice; cancel stops speech immediately.

---

## Phase 6 — Notifications that actually fire, with deep link

**Current bug:** onboarding requests permission but nothing ever schedules anything; the Settings toggle and time are dead. Fix properly.

### 6.1 `Services/Notifications/ReminderScheduler.swift` (new)

```swift
enum ReminderScheduler {
    static let identifier = "renova.morning.checkin"
    static func sync()  // reads notificationsEnabled/hour/minute from UserDefaults;
                        // removes pending with identifier, then if enabled schedules
                        // UNCalendarNotificationTrigger(hour:minute:, repeats: true)
                        // title "Morning check-in", body "Questionnaire first — then H10."
}
```

Call `sync()`: after onboarding finishes; on any change to the three settings (use `.onChange` in `SettingsView` / `OnboardingView`); and on app foreground (`scenePhase == .active` in `RenovaApp`) so permission changes are picked up.

### 6.2 Minute-precision time

Replace the hour-only `Stepper` in `SettingsView` with a compact `DatePicker(displayedComponents: .hourAndMinute)` bound to hour+minute via a computed `Date` binding. Same row layout.

### 6.3 Deep link to questionnaire

`RenovaApp` gains a `UNUserNotificationCenterDelegate` (small `NotificationRouter: NSObject, ObservableObject` with `@Published var openQuestionnaireRequested`). On tap of our identifier: set the flag. `TodayView` observes it (via environment object) — if questionnaire incomplete, set `showQuestionnaire = true` and clear the flag. Also set the delegate's `willPresent` to show banner+sound in foreground.

**Acceptance:** set reminder 2 minutes out, background the app → notification arrives; tap → app opens directly onto the questionnaire sheet when incomplete, plain Today when complete; toggling off removes the pending request (verify via `getPendingNotificationRequests` debug print or a second scheduled test).

---

## Phase 7 — CSV export

- RecoveryKit: `Sources/RecoveryKit/CSVBuilder.swift` — generic escaper: quotes fields containing `",\n`; doubles inner quotes; CRLF line endings; header row. Tests: quoting, empty fields, unicode.
- App: `Services/Export/ExportCSV.swift` — flattens `ExportDay` (reuse existing `exportRecord` mapping) into **one row per day**, stable column order matching `ExportDay` field order, dates ISO-8601, booleans `true/false`, blanks for nil. `AppViewModel.exportCSV() -> Data`.
- Settings DATA section: second row `EXPORT DATA` … `CSV` mirroring the JSON row; same share-sheet flow, filename `renova-export-yyyy-MM-dd.csv`.

**Acceptance:** exported CSV opens in Numbers with correct columns for seeded data incl. a note containing a comma and a quote; package tests green.

---

## Phase 8 (v4) — Patterns: habit-chip correlations

*The highest-value v4 feature. Pure math in RecoveryKit; honest presentation in UI.*

### 8.1 RecoveryKit: `Sources/RecoveryKit/CorrelationEngine.swift` + tests

```swift
public struct ChipEffect: Sendable, Equatable {
    public let chip: String            // stable key, e.g. "alcohol"
    public let nWith: Int, nWithout: Int
    public let rmssdPctDelta: Double?  // (meanWith − meanWithout) / meanWithout, as %
    public let rhrBpmDelta: Double?    // absolute bpm
}

public enum CorrelationEngine {
    public static let minGroupSize = 5
    /// days: (chipValue: Bool?, rmssd: Double?, rhr: Double?) — one entry per day.
    /// Returns nil unless both groups have >= minGroupSize days with the metric.
    public static func effect(chip: String, days: [(Bool?, Double?, Double?)]) -> ChipEffect?
    /// All seven chips, sorted by |rmssdPctDelta| descending, nils filtered out.
    public static func effects(from days: [DayInputs]) -> [ChipEffect]
}
```

No p-values, no ML — group means only, exactly as pitched. Tests: threshold behavior at n=4/5, nil chips excluded, sign correctness on a fixture where alcohol days have lower rMSSD, division-by-zero guard.

### 8.2 UI: `PATTERNS` section on Trends, below charts, above LOG

Bordered table, one row per available effect (max 4 shown):
`ALCOHOL NIGHTS` + `N=9` (`monoSmall`, `inkFaint`) left; right `rMSSD −18% · RHR +4bpm` in mono, ink. Direction coloring only on the rMSSD half: worse (negative rMSSD delta) `statusWatch`, better `statusOk` — no alerts here, it's a pattern, not a state.
Footer caption inside the card (`monoSmall`, `inkFaint`): `Small-sample averages on your own log. Correlation, not causation.`
Section hidden entirely until at least one chip clears the threshold. Chip display names: `ALCOHOL NIGHTS`, `INTENSE TRAINING`, `LONG TRAINING`, `TRAVEL DAYS`, `LATE NIGHTS`, `SICK DAYS`, `BREATHWORK DAYS`.

**Acceptance:** with seeded data engineered so alcohol (n≥5 both groups) shows a negative rMSSD effect, the row appears with correct arithmetic (hand-check one); below-threshold chips absent; section absent on fresh install.

---

## Phase 9 (v4) — Adherence: streak + 28-day calendar strip

- RecoveryKit: `Sources/RecoveryKit/Adherence.swift` + tests — `currentStreak(days:today:)` (consecutive complete days ending today-or-yesterday; a complete day = questionnaire complete AND measurement present), `completionRate(days:, last: 30)`. LocalDate strings in, ints/doubles out.
- Today: in the band's right meta, add a third line `STREAK 12` (only when ≥ 2).
- Trends: `ADHERENCE` section under the header — a 28-cell grid strip (7 columns per row, most recent last): filled `statusOk` square = complete day, `lineStrong` outline = partial, `line` = missed; caption `LAST 30 DAYS: 87% COMPLETE`.

**Acceptance:** streak math verified by tests incl. the today-not-yet-done case (streak counts through yesterday, doesn't zero at 6 a.m.); strip renders correct states for seeded data.

---

## Phase 10 (v4) — Weekly readout

- `Features/Trends/WeeklyReadoutView.swift`: one screen, Control Grid vocabulary — `WEEK 31 · 28 JUL–03 AUG` band; rows: 7-day vs 60-day mean for rMSSD/RHR/gap with direction dots; band-exit count (`2 DAYS OUTSIDE BAND`); subjective 7-day average (mean of the four higher=better scores, note the polarity split in `Models.swift` comments — fatigue/stress are amount scales, convert with `8 − x` before averaging); top chip effect if any.
- Entry point: a row on Trends above LOG: `WEEKLY READOUT →` (visible once ≥ 7 logged days).
- Share: `ImageRenderer` snapshot of the view → existing `ShareSheet`. Fixed 390pt width render so the shared image is stable.

**Acceptance:** numbers agree with Trends charts for the same window; share produces a legible PNG in light mode; polarity conversion correct (a week of fatigue=7 must *lower* the subjective average).

---

## Phase 11 (v4) — Home/lock-screen widget

*The only phase requiring project surgery — do it last.*

1. **Data bridge:** App Group `group.com.zach.renova` (add to `project.yml` entitlements for both targets, run `xcodegen`). After every `refresh()` / `recordMeasurement()` / `submitQuestionnaire()`, `AppViewModel` writes a `WidgetSnapshot` (Codable: `localDate`, `tasksPending: Int`, `rmssdMs: Double?`, `light: String?`) to the shared `UserDefaults`, then `WidgetCenter.shared.reloadAllTimelines()`.
2. **Target:** new WidgetKit extension `RenovaWidget` declared in `project.yml`. `TimelineProvider` reads the snapshot; one timeline entry now + one at next local midnight (so a stale "done" flips back to "2 TASKS" on the new day without the app opening).
3. **Views** (small + accessory-rectangular): pre-ritual — `MORNING` label, `2 TASKS PENDING`, coral marker; post — `RMSSD` label, big mono number, status square. Match Control Grid: flat, mono labels, no gradients. `containerBackground(CGTheme.surface, for: .widget)` — CGTheme must therefore live in a file target-membership-shared with the widget (add membership, don't duplicate).
4. Tapping opens the app (default deep link is fine; questionnaire routing from Phase 6 takes over).

**Acceptance:** widget shows pending state before the ritual, flips to today's rMSSD after, resets at midnight; both light/dark; app still builds from a clean `xcodegen` run.

---

## Phase 12 (v4) — Dynamic Type pass

- Add to `CGTheme`: `static func scaled(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font` using `UIFontMetrics(forTextStyle: .body).scaledValue(for:)` via a `@ScaledMetric`-style wrapper (or plain `Font.system(size:)` swapped for `.custom` with `relativeTo:`). Simplest robust route: replace `Font.system(size: X, …)` call sites with `CGTheme.scaled(X, …)` returning `.system(size: metrics.scaledValue(for: X), …)` computed in views via `@Environment(\.sizeCategory)`-reactive helper. Choose one mechanism and apply it uniformly.
- Sweep every `font(.system(size:` in the app target (they are all fixed today). Chrome labels (`monoSmall`, section labels) may cap at `.accessibilityMedium` scaling; body copy and metric values must scale fully.
- Audit at `AX1` and `AX3` in the simulator: no clipped bands, hero number allowed to wrap unit to a second line, to-do rows grow vertically.

**Acceptance:** every screen usable at AX3; no truncated `…` on any label at XL; default (Large) renders pixel-identical to pre-phase screenshots.

---

## Seeding (build once in Phase 2, reuse everywhere)

Add `DEBUG`-only `DayRepository.seedDemoData(days: 45)` invoked from a hidden Settings row (`DEBUG` builds only): generates plausible history — rMSSD ~N(58, 9) clamped 30–90, RHR ~N(47, 3), gap ~N(25, 6), full questionnaires with varied scores, ~20% alcohol nights with rMSSD drawn 15% lower and RHR +3 (so Phase 8 has real signal), ~10% partial days, 2 orthostatic skips. Deterministic seed so screenshots are reproducible.

## Explicitly out of scope (do not build even if tempting)

Watch app, HealthKit, Oura, TrainingPeaks/Intervals export, App Store prep, any-strap testing, evening check-in, training log, coach view, Daybreak styling, any composite readiness score.

---

## Suggested execution order recap

| # | Phase | Size | Risk |
|---|---|---|---|
| 1 | Theme + semantics | S | trivial |
| 2 | TrendSeries + BandChart | M | low (pure + previews) |
| 3 | Today v2 | M | low |
| 4 | Trends tab | M | low |
| 5 | Session cues | S | medium (audio session) |
| 6 | Notifications + deep link | S | medium (delegate wiring) |
| 7 | CSV | S | trivial |
| 8 | Correlations | M | low (pure + tests) |
| 9 | Adherence | S | low |
| 10 | Weekly readout | M | low |
| 11 | Widget | M | **high** (new target, App Group, xcodegen) |
| 12 | Dynamic Type | M | medium (wide mechanical sweep) |
