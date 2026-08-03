# Technical Specification — Renova (iOS)

**Companion:** [`PRD.md`](./PRD.md) · [`REVIEW_NOTES_RESPONSE.md`](./REVIEW_NOTES_RESPONSE.md)  
**Product name:** **Renova**  
**Version:** 1.3  
**Date:** 2026-08-02  
**Status:** Draft for approval (no implementation until approved)  
**Changelog 1.2:** Rename Renova; local analytics; 1–7 questionnaire + habits; displayName; export schema.  
**Changelog 1.3:** Baselines Couzens-style 7d vs 60d ±1 SD; caffeine time/amount + last meal fields; short orthostatic kept.

---

## 1. Overview

Native **iOS** application (Swift + SwiftUI) that:

1. Enforces a **per-local-day questionnaire gate**  
2. Streams **Polar H10** BLE heart rate / RR intervals  
3. Computes **rMSSD** (Elite HRV replacement)  
4. Runs a guided **orthostatic** protocol  
5. Persists all data **on-device only**

Target: personal sideload / TestFlight to owner. Architecture must not preclude App Store later.

---

## 2. Platform and project setup

| Choice | Decision |
|--------|----------|
| Language | **Swift 5.9+** |
| UI | **SwiftUI** |
| Min iOS | **iOS 17** (adjust to owner’s phone if needed; document at kickoff) |
| Architecture | **MVVM** + protocol-oriented services |
| Concurrency | **Swift async/await** + `AsyncStream` for HR samples |
| Persistence | **SwiftData** (preferred) or Core Data; v3 single store |
| BLE | **CoreBluetooth** |
| Package manager | Xcode SPM only if needed (prefer zero deps v3) |
| Bundle ID (suggested) | `com.zringstrom.recoverydeck` (final at Xcode create) |
| Display name | Renova |

### 2.1 Xcode project layout (suggested)

```
Renova/
  App/
    RenovaApp.swift
  Features/
    Onboarding/
    Questionnaire/
    Today/
    MorningMeasurement/   # combined rMSSD + orthostatic session
    History/
    Settings/
  Services/
    Bluetooth/
      HeartRateClient.swift
      PolarH10Identifiers.swift
    Metrics/
      RMSSDCalculator.swift
      OrthostaticCalculator.swift
      BaselineCalculator.swift
    Persistence/
      Models.swift
      DayRepository.swift
    Notifications/
      NotificationScheduler.swift
  Resources/
    Info.plist keys (BLE usage strings)
  Tests/
    RMSSDCalculatorTests.swift
    OrthostaticCalculatorTests.swift
    BaselineCalculatorTests.swift
    GateLogicTests.swift
```

---

## 3. Permissions and Info.plist

| Key | Purpose | User-facing string (draft) |
|-----|---------|----------------------------|
| `NSBluetoothAlwaysUsageDescription` | H10 | “Bluetooth is used to connect to your Polar H10 for morning heart-rate measurements.” |
| `NSBluetoothPeripheralUsageDescription` | if required by target | same spirit |
| Notifications | morning reminder | Standard request at end of onboarding |

**Not used in v3:** HealthKit, Motion (unless later for stand detect — **out of scope**), Background Modes for BLE (sessions are **foreground only**).

---

## 4. Bluetooth / Polar H10

### 4.1 Services and characteristics

Use standard BLE SIG profiles (H10 supports these):

| Item | UUID (standard) |
|------|-----------------|
| Heart Rate Service | `0x180D` |
| Heart Rate Measurement | `0x2A37` |
| Body Sensor Location | `0x2A38` (optional) |
| Battery Service | `0x180F` (optional UX) |

**RR intervals — what they are (reference):** An RR interval is the time gap, in milliseconds, between two successive heartbeats — the raw data HRV math is actually built from (rMSSD is literally "root mean square of successive differences" *of RR intervals*, §5.1). A plain BPM number is just an average; it throws away the beat-to-beat timing that HRV needs. Some cheap HR sensors only report rounded BPM and never transmit RR intervals at all, making true HRV computation impossible from them — that's the failure mode `H10_NO_RR` / the "HRV DATA WAITING" UI state (formerly labeled "RR OK/RR waiting" — renamed for a general audience since "RR" is jargon) guards against. "HRV DATA OK" in the UI means: the strap is actually sending RR intervals, not just BPM, so the rMSSD we're about to compute is real.

**RR intervals:** Parse HR Measurement flags per Bluetooth HR Profile:

- If **RR-Interval bit** present, extract RR values in **1/1024 s** units → convert to ms:  
  `rr_ms = rr_raw * 1000 / 1024`

If a firmware/connection path yields HR-only without RR:

- **Cannot compute true rMSSD** from integer BPM alone.  
- UX: error “RR intervals not available — ensure H10 is snug, charged, and not connected exclusively elsewhere; prefer H10 in heart rate mode.”  
- Optional degraded mode: store mean HR only; mark `rmssd` null — **do not fake rMSSD from BPM**.

### 4.2 Connection UX

1. User taps **Connect Polar H10**  
2. Scan for peripherals advertising HR service (or known Polar name prefix `Polar H10`)  
3. Connect + subscribe to HR Measurement notifications  
4. Show live BPM + “HRV DATA OK” indicator when RR present  
5. On disconnect mid-test: pause, offer Resume/Restart  
6. Only one session owns the peripheral at a time  

**Note:** iPhone may already be bonded; handle reconnect. Instruct user to disconnect H10 from other apps (Elite HRV, Polar Beat) during measurement.

### 4.3 Sample model

```swift
struct HRSample: Sendable {
  let timestamp: Date
  let bpm: Double?          // from HR field when present
  let rrIntervalsMs: [Double] // zero or more RR since last notification
}
```

Feed `AsyncStream<HRSample>` into session VMs.

---

## 5. Metric algorithms

### 5.1 rMSSD

**Definition:** Root mean square of successive differences of valid NN (RR) intervals.

For successive valid intervals \(RR_i\), \(RR_{i+1}\) (ms):

\[
rMSSD = \sqrt{ \frac{1}{N-1} \sum_{i=1}^{N-1} (RR_{i+1} - RR_i)^2 }
\]

**Window (normative, v3.1 revised):** rMSSD is no longer captured in its own dedicated phase — it's computed from the RR stream collected during the single **Lying** phase, which also serves as the orthostatic lying reference (§6.1). Target **60 s wall-clock minimum** (matching the classic Couzens lying duration), extendable to a **75 s hard cap** if `sum(accepted RR) < 60_000 ms` hasn't been reached yet at 60 s (protects data quality for a slow resting HR without letting the phase run away). Fail quality if `sum(RR) < 60_000 ms` or accepted count `< 45` even at the 75 s cap.

*(v3.0 originally used a separate ~60 s rMSSD phase plus a dedicated 30 s lying-HR phase — TECH_SPEC §O2. Revised: one 60–75 s lying phase now serves both rMSSD and RHR, since both are legitimately drawn from the same heartbeats — this is standard practice elsewhere (Whoop/Oura/Elite HRV) and shortens the session from ~3 min to ~2–2.5 min with no loss of rigor.)*

**Settle:** 15.0 s wall-clock after user confirms still; discard RR during settle for rMSSD (may still show live HR).

**Artifact rejection (v3, simple and documented):**

1. Drop RR &lt; **300 ms** or &gt; **2000 ms**  
2. Drop RR where successive difference &gt; **20%** of previous RR (ectopic/motion heuristic)  
3. Track `artifactRatio = rejected / (accepted+rejected)`  
4. If `artifactRatio > 0.20` **or** accepted count &lt; 45 → quality **fail**, prompt retry  

**Also store:** mean RR, mean HR = 60000/meanRR, SDNN optional (not primary UI).

**Unit tests:** golden vectors of RR lists → known rMSSD (hand-calculated fixtures).

### 5.2 Mean HR over a phase

- **Lying (avgLyingHR):** `60000 / meanRR` from the same accepted-RR set used for rMSSD (§5.1) — not a separate raw-BPM average. One window, one set of real heartbeats, feeding both numbers.
- **Standing:** mean of raw BPM samples in the 60 s standing window.
- **Peak standing HR:** **max BPM over the full 60 s standing window** (includes early rise; Couzens peak response)

### 5.3 Orthostatic derived

```
avgLyingHR
avgStandingHR
peakStandingHR
gapAvg  = avgStandingHR - avgLyingHR
gapPeak = peakStandingHR - avgLyingHR
```

### 5.4 Baselines and green / yellow / red (Couzens-aligned)

Couzens dashboard approach (Ch.13 materials): **7-day rolling mean** (acute) vs **60-day rolling mean** (norm), with a **normal band ≈ ±1 SD** around the long-term mean. Values inside the band look “normal for this athlete”; outside is highlighted.

**Per metric series** (rMSSD, avgLyingHR, gapPeak, gapAvg, subjectiveMean):

| Quantity | Definition |
|----------|------------|
| `normMean` | Rolling mean of last **60** complete days (excluding today); require ≥ **7** prior days else `baselineStatus = .building`. Real comparisons start at 7 days but keep sharpening — `BaselineAssessment.isFullyMature` is only true once 60 days are behind it (Couzens' actual long-term norm window). UI surfaces this via a "still improving — N/60 days" note until then. |
| `normSD` | Sample SD over same 60-day window (min floor: rMSSD 1 ms, HR 1 bpm, gap 1 bpm, subjective 0.25) |
| `acute` | Prefer **today’s value** for daily UI; optional secondary display of **7-day** rolling mean (Couzens acute line) |
| **Normal band** | `[normMean − 1×normSD, normMean + 1×normSD]` |

**Traffic lights (normative):**

| Light | Rule |
|-------|------|
| **Green** | `acute` inside normal band **or** still `.building` |
| **Yellow** | outside band by **≤ 0.5×normSD** beyond the edge (i.e. between 1.0 and 1.5 SD from mean) |
| **Red** | outside band by **> 0.5×normSD** beyond the edge (beyond ~1.5 SD from mean) |

**Concerning directions** (for tips / emphasis, not for ignoring the opposite side):

| Series | Emphasize when… |
|--------|------------------|
| rMSSD | **Low** vs band |
| avgLyingHR | **High** vs band (elevated); very **low** + poor subjective → tip “deep fatigue pattern?” |
| gapPeak | **Smaller** gap vs band (blunted stand response) |
| Subjective mean (5× 1–7) | **Low** scores (worse feel) |

**Absolute subjective fallback** if not enough history: mean ≥ 5.0 green-ish, ≥ 3.5 yellow-ish, else red-ish (same polarity as before).

**Composite chip (optional):** majority of channel lights; ties → yellow. Label **“rough signal — not medical.”**

Not clinical cutoffs; personal statistical bands after Couzens’ visualization pattern.

---

## 6. Session state machines

### 6.1 Combined morning measurement flow (v3.1 revised)

Single CTA: **Start morning measurement**. Matches PRD §6.1 / §6.5.

```
State: Idle
  → Connecting
  → ConnectedLive (show BPM)
  → User confirms lying down (must be post-questionnaire)
  → SettleLying (15 s, discarded)
  → CaptureLying (60 s target / 75 s cap — feeds BOTH rMSSD §5.1 and avgLyingHR §5.2)
  → PromptStand (haptic; user confirms "I've stood up" — no blind timer)
  → CaptureStanding (60 s wall)
  → Complete (persist MeasurementBundle; overwrite if same localDate confirm)
  → Error/Cancel from any state
```

**Total:** 15 + 60–75 lying + standing 60 ≈ **~2–2.5 min** + connect (was ~3 min in v3.0 — see §5.1 note on why the dedicated lying-HR phase was retired).

**Remeasure:** If `MeasurementRecord` exists for `localDate`, require confirm → overwrite same row (v3: no version history).

### 6.2 HRV-only path

If orthostatic skipped (PRD O1b), offered during the Lying phase:

```
Settle 15 s → Lying 60–75 s → persist HRV partial → Today shows orthostatic missing
```

Skip requires confirm: “Skip orthostatic today?”

### 6.3 Gate logic (pure function — unit test)

```swift
func canAccessHistory(today: LocalDate, questionnaire: DayRecord?) -> Bool
func canStartMeasurement(today: LocalDate, questionnaire: DayRecord?) -> Bool
```

Rules per PRD §6.2.

---

## 7. Data model

### 7.1 SwiftData entities (conceptual)

**DayRecord**

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| localDate | String `yyyy-MM-dd` | unique |
| timezoneIdentifier | String | |
| fatigue | Int 1…7 | |
| mood | Int 1…7 | |
| soreness | Int 1…7 | |
| lifeStress | Int 1…7 | |
| sleepQuality | Int 1…7 | |
| lastCaffeineAt | Date? | optional; local time of last caffeine |
| caffeineAmountMg | Double? | optional; mg if known |
| caffeineAmountBand | String? | optional: none/small/medium/large if mg unknown |
| lastMealAt | Date? | optional; time last meal finished |
| habitAlcohol | Bool? | optional chip |
| habitHardTrainingYesterday | Bool? | |
| habitTravelLate | Bool? | |
| habitSick | Bool? | |
| notes | String? | |
| questionnaireCompletedAt | Date | |
| questionnaireEditedAfterMeasure | Bool | default false |

**MeasurementRecord**

| Field | Type | Notes |
|-------|------|-------|
| id | UUID | |
| localDate | String | FK logical to day |
| measuredAt | Date | |
| protocolVersion | String | e.g. `"v3.0"` |
| rmssdMs | Double? | |
| meanHrBpm | Double? | during RMSSD |
| rrAcceptedCount | Int? | |
| artifactRatio | Double? | |
| hrvQuality | enum ok/fail | |
| avgLyingHr | Double? | |
| avgStandingHr | Double? | |
| peakStandingHr | Double? | |
| gapAvg | Double? | |
| gapPeak | Double? | |
| orthostaticSkipped | Bool | |
| orthostaticQuality | enum ok/fail/skipped | |
| deviceName | String? | |
| rawDebugPath | String? | optional debug only, off by default |

**AppSettings**

| Field | Type | Default |
|-------|------|---------|
| displayName | String? | optional greeting |
| notificationHour/Minute | Int | 6:30 |
| notificationsEnabled | Bool | true |
| normWindowDays | Int | **60** (Couzens long-term norm) |
| acuteWindowDays | Int | **7** (optional chart line) |
| dayStartTimezone | String | auto |
| enabledHabitChips | [String] | which Block D chips show |

### 7.3 Local analytics (on-device only)

Store lightweight events in the same sandbox (separate entity or append-only log), e.g.:

- `morning_completed`, `orthostatic_skipped`, `hrv_quality_fail`, `session_duration_ms`, `ble_connect_fail`

**No** network upload. Surface a simple Settings → Analytics summary. Export may include analytics if user exports “full backup.”

### 7.4 Future export (v4+ — not implemented)

Stable JSON `protocolVersion` so a later module can map fields → TrainingPeaks metrics / Intervals wellness without schema thrash.

### 7.2 Completeness

`day.isComplete` = questionnaire done && rmssd present && quality ok && (orthostatic ok || skipped).

---

## 8. Persistence and privacy

| Topic | Spec |
|-------|------|
| Location | App sandbox only |
| Encryption | iOS Data Protection default; no custom crypto required v3 |
| iCloud | **Off** |
| Backup | Participates in iCloud device backup unless excluded — **v3 accept default**; document that iCloud backup may include data if user backs up phone |
| Export | JSON (full) + CSV (days flat) via `UIActivityViewController` |
| Delete all | Wipe SwiftData store + reset onboarding flag optional keep |

**No** network client in v3 targets. CI should fail if new URLSession analytics appear.

---

## 9. UI specifications (behavioral)

### 9.1 Questionnaire

- **Five required** steppers / tappable **1–7** chips (Block A+B)  
- Optional Block C: last caffeine time, caffeine amount, last meal time (skippable)  
- Optional Block D habit chips + Block E notes  
- Large touch targets; submit sticky  
- Cannot navigate to History via Tab until required scores submitted

### 9.2 Session UI

- Large phase title  
- Countdown / progress  
- Live BPM  
- Cancel always available  
- Success checkmark → auto-return Today  

### 9.3 Accessibility

- Dynamic Type support for questionnaire  
- VoiceOver labels on scores  
- Haptics for stand cue (respect reduce motion: visual flash)

### 9.4 Appearance

- System light/dark  
- Calm, minimal; no gamification streaks required in v3 (optional later)

---

## 10. Notifications

- `UNUserNotificationCenter`  
- Daily calendar trigger  
- ID: `morning-checkin-daily`  
- Reschedule on settings change  
- No critical alerts  

---

## 11. Testing strategy

### 11.1 Unit tests (required before calling v3 done)

| Module | Cases |
|--------|-------|
| RMSSDCalculator | empty, single, monotonic, known fixture, artifact heavy |
| OrthostaticCalculator | gaps, peak |
| BaselineCalculator | building, green/yellow/red bands |
| GateLogic | before/after questionnaire, day rollover |

### 11.2 Manual test checklist (H10)

1. Fresh install → onboarding → notification permission  
2. Questionnaire gate blocks History and Start  
3. Connect H10; RR indicator green  
4. Full combined session completes; values plausible (rMSSD typically tens of ms; not 0; not 500)  
5. Kill app mid-session; no corrupt day  
6. Skip orthostatic path  
7. Second launch same day: questionnaire done; can remeasure with confirm overwrite  
8. Next calendar day: gate resets  
9. Export JSON non-empty  
10. Delete all data  

### 11.3 Parallel Elite HRV (user)

7 days: record both rMSSD; expect similar order of magnitude and co-movement, not equality.

---

## 12. Implementation milestones

| Milestone | Scope | Done when |
|-----------|-------|-----------|
| **M0** | Xcode project, folder structure, SwiftData models, gate + questionnaire + Today shell | UI flow without BLE |
| **M1** | HeartRateClient + live BPM | Connect H10 reliably |
| **M2** | RMSSD session + persist + History | Elite replacement usable |
| **M3** | Combined orthostatic + baselines + notifications + export + tests | **v3 complete** |

Estimated effort (solo, familiar with iOS): **M0–M1** 1–2 days, **M2** 1–2 days, **M3** 1–2 days — **~1 week calendar** part-time, not a commitment.

---

## 13. Error catalog (user-visible)

| Code | Message (draft) |
|------|-----------------|
| BT_POWER | Turn on Bluetooth |
| BT_DENIED | Allow Bluetooth in Settings |
| H10_NOT_FOUND | Polar H10 not found — wear it, press button, close other HR apps |
| H10_NO_RR | Connected but no RR intervals — cannot compute HRV |
| H10_DROP | Connection lost — retry |
| QUALITY_HRV | Too much noise — lie still and retry |
| QUALITY_ORTHO | Standing segment invalid — retry orthostatic |
| GATE | Complete today’s questionnaire first |

---

## 14. Security notes

- No API keys in repo  
- No logging of health samples to third parties  
- Debug RR dumps **off by default**; if enabled, local file only + setting  

---

## 15. App Store readiness (non-blocking notes)

When/if public:

1. Privacy policy URL  
2. App Review notes: Polar H10 required for full function; demo mode with simulator RR fixture for reviewers  
3. **Simulator demo mode:** inject synthetic RR for UI review without hardware  
4. Avoid HealthKit until justified  
5. Medical disclaimer in App Description  

**v3 demo mode:** compile-flag `DEMO_RR` for SwiftUI previews and unit-free UI dev without strap.

---

## 16. PRD decisions (locked for v3)

| PRD | Implementation |
|-----|----------------|
| O1 skip orthostatic | **Allow skip** with confirm → HRV-only path §6.2 |
| O2 lying duration | ~~30 s lying HR after rMSSD~~ **SUPERSEDED (v3.1):** single 60–75 s lying phase serves both rMSSD and avgLyingHR — see §5.1, §6.1 |
| O3 gap display | **gapPeak** primary, gapAvg secondary |
| O4 history gate | Block until questionnaire |
| O5 posture | **Lying** for rMSSD |
| Remeasure | Overwrite after confirm |

---

## 17. Explicit non-implementations

- Frequency-domain HRV (LF/HF) — Couzens notes need ~5 min for LF; v3 stays rMSSD + orthostatic  
- ECG authentication modes beyond standard HR BLE  
- Auto-stand detection via accelerometer  
- Cloud sync  

---

## 18. Acceptance criteria (v3)

1. Questionnaire required before measurements and history.  
2. rMSSD computed from H10 RR with documented artifact rules; saved per day.  
3. Orthostatic produces lying avg, standing avg, peak, gaps (or skip recorded).  
4. Baselines: `.building` until ≥7 complete days; then G/Y/R vs 60-day ±1 SD band, flagged "still improving" until the full 60 days are in.  
5. No network calls in core paths.  
6. Export and delete work.  
7. Unit tests for calculators and gate pass.  
8. Manual H10 checklist completed by owner.  

---

## 19. References (product science)

- Alan Couzens, readiness composite (HRV, RHR, fatigue, mood, soreness, stress) — training-plan dashboard / Ch.13 materials in local archive  
- Alan Couzens, orthostatic 60s+60s, peak vs lying gap — `taking-your-understanding-of-hrv.md`  
- Alan Couzens, HRV alone insufficient; commercial readiness skepticism — distilled monitoring notes  
- Bluetooth SIG Heart Rate Profile (RR intervals)

---

## 20. Approval

| Role | Status |
|------|--------|
| Engineering spec author | Complete for review |
| Owner (Zach) | Pending |

**No implementation until PRD + this spec are approved and Zach requests build.**
