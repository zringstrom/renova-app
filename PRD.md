# Product Requirements Document — Renova

**Product name:** **Renova**  
**Owner:** Zachery Ringstrom  
**Status:** Approved (2026-08-02) — implementation in progress  
**Version:** 1.4  
**Date:** 2026-08-02  
**Changelog 1.2:** Rename Renova; local analytics; 1–7 scales; Alan + WHOOP-style questionnaire; optional display name; TP/Intervals future; evidence notes.  
**Changelog 1.3:** Keep short orthostatic; G/Y/R reframed to Couzens 7d vs 60d ±1 SD; optional caffeine time/amount + last meal time; HealthKit not v3 confirmed.  
**Changelog 1.4:** Merged rMSSD + lying-HR into one 60–75 s Lying phase (O2 superseded), session now ~2–2.5 min; questionnaire revised to 7 scores (stress split 3 ways, Fatigue/Stress now amount-scaled); habit chips split/renamed + default on; export added; Control Grid visual system adopted for the real app (not just mockups).  
**Companion:** [`TECH_SPEC.md`](./TECH_SPEC.md) · [`REVIEW_NOTES_RESPONSE.md`](./REVIEW_NOTES_RESPONSE.md)

---

## 1. Summary

**Renova** is a **privacy-first, local-first iOS app** for a single primary user (Zach) that runs a fixed morning ritual:

1. **Forced questionnaire** (cannot skip into measurements)  
2. **Polar H10 measurements** that **replace Elite HRV** (rMSSD) and add an **orthostatic HR test**  
3. **Simple history + traffic-light context** vs personal baselines  

The app supports Couzens-style **recovery-on-demand** decisions: composite signals (subjective + HRV + RHR + orthostatic), **not** a black-box commercial “readiness score.”

**Scope for first ship:** everything through **v3** (questionnaire gate + H10 rMSSD + H10 orthostatic + local history). Optional App Store distribution for friends is a **future** phase and must not drive v1–v3 feature bloat.

---

## 2. Problem

| Pain | Today |
|------|--------|
| Subjective readiness never logged | No daily fatigue/mood/soreness/stress answers |
| Recovery signals fragmented | Oura (sleep/RHR/HRV), Elite HRV (1 min rMSSD), training feel — separate apps |
| Elite HRV is an extra hop | User wants **one** morning app that owns rMSSD |
| Orthostatic not automated | Couzens-valued test; no easy 2–3 min guided flow with H10 |
| Commercial readiness scores untrusted | Oura Readiness etc. not anchored to “ready for *what*” (Couzens critique) |

**Cost of status quo:** decisions about down weeks / easy days under-weight subjective state; orthostatic unused; habit friction.

---

## 3. Goals and non-goals

### 3.1 Goals (v3 = “done for personal daily use”)

1. **Questionnaire-first gate** every local calendar morning before any measurement or stats that reveal trends.  
2. **Replace Elite HRV** with in-app **~60 s rMSSD** via Polar H10.  
3. **Guided orthostatic test** (~2–3 min) via H10; store lying avg HR, standing avg HR, peak standing HR, and gaps.  
4. **RHR** defined as **lying average HR** from the orthostatic (or dedicated lying segment) — primary RHR for the day.  
5. **Local-first storage**; no account required; **no third-party cloud analytics SDK**; no required cloud.  
6. **On-device analytics** (adherence, quality fails, completion time, etc.) stored **only on the phone**.  
7. **History** of questionnaire + metrics with simple **vs personal baseline** indicators (green / yellow / red) — heuristic, not clinical cutoffs (see §6.6).  
8. **Installable on owner’s iPhone** (Xcode / TestFlight to self).  
9. Architecture that **does not block** later App Store, optional display name, or optional TrainingPeaks / Intervals export.  
10. Optional **display name** for greetings (not an account).

### 3.2 Non-goals (v3)

- Oura API integration (optional later; notes OK)  
- **TrainingPeaks / Intervals.icu sync in v3** — **deferred to v4+ optional**, schema should stay export-friendly  
- HealthKit read/write in v3 (optional later; see REVIEW_NOTES)  
- Coaching dashboard, multi-athlete, teams  
- Diagnosing medical conditions or “overtraining syndrome” as a clinical claim  
- AI / ML readiness models  
- Android  
- Background continuous HR monitoring  
- Social features, login accounts, ads  
- Third-party analytics SDKs that phone home  
- Perfect reproduction of Elite HRV’s proprietary pipeline

### 3.3 Success metrics (personal)

| Metric | Target (first 30 days after install) |
|--------|--------------------------------------|
| Morning completion rate | ≥ **80%** of days with full questionnaire + rMSSD |
| Orthostatic adherence | ≥ **60%** of days (skippable after confirm per locked O1; still count as completed morning if rMSSD saved) |
| Elite HRV usage | **Zero** intentional uses after parallel validation week |
| Subjective capture | **100%** of measurement days have all required questionnaire fields |
| Trust | User prefers this app’s morning flow over prior stack |

---

## 4. Users

| Persona | Role |
|---------|------|
| **Primary: Zach** | Endurance athlete (~18–22 h/wk, AeT-capped base). Owns Oura + Polar H10. Trains with Couzens-informed principles. |
| **Future: friends** | Possible App Store users; same solo morning ritual; no coach portal in v3. |

**Assumptions:** iPhone recent enough for current iOS LTS−1; Polar H10; English UI; America/Los_Angeles local calendar days.

---

## 5. Product principles

1. **Gate first, measure second** — No peeking at trends to bias answers.  
2. **Composite, not oracle** — Show numbers + simple baselines; user decides training.  
3. **Privacy first** — Data never leaves the device unless user explicitly exports.  
4. **Repeatable protocol** — Same posture, timing, and order every day.  
5. **Couzens-aligned language** — Ready to *load* vs ready to *recover*; low HRV ≠ ban all easy work.  
6. **Boring reliability** — Prefer a rock-solid H10 connection over flashy charts.  
7. **Personal now, public-ready later** — No hard-coded secrets; no medical overclaim.

---

## 6. User experience

### 6.1 Happy path (full morning, ~4–6 minutes)

**v3 primary UX = one combined H10 session** after the questionnaire (not two separate “Start HRV” / “Start Orthostatic” products). Separate re-run of orthostatic-only is allowed only as a recovery path after a failed standing segment.

```
Launch app
  → If questionnaire incomplete for today:
        Questionnaire screen (blocking)
  → Home / Today (post-questionnaire):
        [Start morning measurement]  → combined: settle → rMSSD → lying HR → stand → done
        optional: [Skip orthostatic today] only as confirm during/after rMSSD path (see O1)
  → Results for today + optional “What this might mean” plain-language tips
  → History available only after questionnaire submitted for today
```

### 6.2 Gating rules (normative)

| Destination | Allowed if questionnaire **not** done today? |
|-------------|-----------------------------------------------|
| Questionnaire | Yes |
| **Start morning measurement** (combined session) | **No** |
| Today’s metric numbers (after measure) | Only after questionnaire; metrics appear as completed |
| History / charts / baselines | **No** until questionnaire submitted for **today** |
| Settings | Yes (always) |
| Export | Yes (always); **History blocked** until questionnaire done |

**Day boundary:** `localDate` in device timezone (default `America/Los_Angeles`, user-overridable in Settings).

**Resubmit questionnaire:** Allowed; overwrites today’s answers; does not delete measurements already taken (flag `questionnaireEditedAfterMeasure` if edit after first measurement).

**Remeasure (same day):** At most **one active measurement bundle** per `localDate`. User may re-run the combined session (or HRV-only if orthostatic skipped) only after **confirm overwrite**. Overwrite replaces the previous bundle for that day (no multi-version history in v3).

### 6.3 Questionnaire (v3 fields)

#### Block A — required (Alan Couzens core), scale **1–7**

Higher = better (consistent polarity). Midpoint = 4.

| Field | 1 | 7 |
|-------|---|---|
| **Fatigue** | Exhausted | Fresh |
| **Mood** | Very low | Great |
| **Soreness / heavy legs** | Very sore | None |
| **Life stress** | Very high | Very low |

*Rationale:* Couzens morning inventory / dashboard features use **Fatigue, Mood, Soreness, Stress** (+ measured HRV & Pulse).

#### Block B — required (short), scale **1–7**

| Field | 1 | 7 |
|-------|---|---|
| **Sleep quality (how it felt)** | Terrible | Excellent |

*Rationale:* Captures “slept long but feel wrecked”; complements Oura without API.

#### Block C — optional context (skippable fields; not required for gate)

Shown on the same questionnaire screen; each can be left blank / “Skip.”

| Field | Type | Notes |
|-------|------|--------|
| **Last caffeine time (previous day → morning)** | Time of day (or “none”) | When caffeine was *last* consumed before this check-in |
| **Caffeine amount** | Optional amount | Free number + unit picker default **mg**, or coarse chips (e.g. none / small / medium / large) if exact mg unknown |
| **Last meal time** | Time of day | When the last meal/substantial snack was finished |

*Rationale:* Timing/dose of caffeine and last meal affect sleep, overnight HRV proxies, morning RHR, and how “fasted” the measurement is—useful context without forcing perfection.

#### Block D — optional habit chips (WHOOP-inspired), **Yes / No**

Defaults **on**; user may disable in Settings:

- Alcohol last night  
- Hard training yesterday  
- Travel / late night  
- Feeling sick / under the weather  

(Late caffeine is largely covered by Block C time field.)

#### Block E — optional free-text **Notes**

**Submit** enabled when Block A + B complete (5 scores on **1–7**). Blocks C–E optional.

### 6.4 Measurement: rMSSD (replaces Elite HRV)

| Item | Spec |
|------|------|
| Hardware | Polar H10 via Bluetooth LE |
| Posture | **Lying supine**, still, normal breathing (aligned with orthostatic lying; one posture for whole session) |
| Duration | **60 seconds** of accepted RR intervals after a short settle |
| Settle | **15 s** countdown after “connected & still” before RR window starts |
| Output | rMSSD (ms), mean HR (bpm), artifact %, sample count |
| Failures | Disconnect, too many artifacts → prompt retry; do not save junk without confirmation |

**Caffeine / timing guidance (in-app copy, not enforced):** before coffee when possible; same time of day; bathroom OK; after waking ~5–15 min.

### 6.5 Measurement: orthostatic (Couzens-style)

**Science reference (Couzens):** classic standalone orthostatic is often described as **~60 s lying + ~60 s standing**, tracking avg lying, avg standing, peak standing, and especially **peak − lying**.

**v3.1 normative product protocol (combined morning session — revised):**  
One lie-down; rMSSD and the orthostatic lying reference now come from the **same single lying phase** rather than a dedicated rMSSD segment followed by a separate lying-HR segment (v3.0's approach — see O2, superseded). Both numbers are legitimately drawn from the same heartbeats, matching standard practice elsewhere (Whoop/Oura/Elite HRV), and it trims the session from ~3 min to ~2–2.5 min with no loss of rigor.

| Phase | Duration | User action | Record |
|-------|----------|-------------|--------|
| Prep | — | Connect strap; lie down | — |
| Settle | **15 s** | Stay lying, still | discard for rMSSD |
| Lying | **60 s target, 75 s cap** | Stay lying | **rMSSD**, **avg lying HR** (primary **RHR** for the day) — same window, same heartbeats |
| Cue | confirm-based | “Stand up now” (haptic and/or spoken); user taps "I've stood up" — no blind timer | — |
| Standing | **60 s** | Stand still | **Avg standing HR**, **Peak standing HR** |

The 75 s cap only triggers if `sum(RR) < 60,000 ms` hasn't been reached by 60 s (e.g. a slow resting HR) — it protects data quality without letting the phase run away.

**Cue delivery (new, open for v3):** Settings should offer **Haptic**, **Voice (spoken cue)**, or **Both** for the "stand up now" cue (and ideally the phase transitions generally — settle done, rMSSD done, standing done). Rationale: eyes may be closed while lying; haptic alone can be missed if phone isn't on-body; a spoken cue ("stand up now") is more reliable and lets the user keep eyes closed through the whole session. Default: **Both**. Needs TECH_SPEC follow-up (AVSpeechSynthesizer vs pre-recorded clips; respect silent/mute switch and Focus modes).

**Derived (store all):**

- `gap_avg` = avg_standing − avg_lying  
- `gap_peak` = peak_standing − avg_lying  

**Primary gap in UI:** `gap_peak` (Couzens). Show `gap_avg` secondary.

**Total guided time:** ~15 + 60–75 lying + 60 standing ≈ **~2–2.5 min** + connection → product copy “about 2 minutes.”

**Standalone classic 60+60** is **not** a v3 UI mode (may be added later). Skip-orthostatic path: settle + Lying only (see O1).

### 6.6 Results interpretation (non-prescriptive)

**What Couzens actually does** (dashboard / Ch.13 materials)—not a branded G/Y/R product table:

1. **Long-term norm** ≈ **60-day** rolling mean (starting point; window can be experimented with).  
2. **Acute signal** ≈ **7-day** rolling mean (less noisy than raw daily).  
3. **Normal band** ≈ **±1 standard deviation** around the long-term mean (he plots this as a pale green “normal range”).  
4. Flag when the athlete is **outside their own range**.  
5. Combine HRV, pulse, fatigue, mood, soreness, stress; be skeptical of commercial single “readiness scores.”  
6. **“Red light”** language for serious overtraining-type states (e.g. orthostatic Q4)—not every slightly off morning.

**Renova mapping:** full rules in **`TECH_SPEC.md` §5.4** (Couzens-aligned):

| Light | Meaning |
|-------|---------|
| **Green** | Today (acute) inside personal **60-day mean ± 1 SD** band, or still building history |
| **Yellow** | Mildly outside that band (~1–1.5 SD) |
| **Red** | Clearly outside (~&gt;1.5 SD), especially in a concerning direction |

UI must **label direction** (“RHR higher than your usual range”, “orthostatic gap smaller than usual”), not only color. Not a medical diagnosis.

**Plain-language tips (examples, not medical advice):**

- Low rMSSD + high RHR + small gap → bias easy / recovery; avoid intensity.  
- Low rMSSD but good subjective + large gap → still prefer easy if unsure; easy AeT work may be OK.  
- Heavy legs (soreness **1–2** on 1–7 scale) → respect muscular recovery even if HRV “looks fine.”  

**Never:** “You have overtraining syndrome.”  
**Never:** auto-change training calendar.

### 6.7 History

- List by day: scores + rMSSD + RHR + gaps  
- Simple charts: 14–28 day rMSSD, RHR, gap_avg, subjective average  
- Filter: incomplete days visible as partial  

### 6.8 Notifications

- One daily local notification (default **06:30** local, user-editable)  
- Title: “Morning check-in”  
- Body: “Questionnaire first — then H10.”  
- Tapping opens app to questionnaire if incomplete  

### 6.9 Settings

- **Display name** (optional; greetings only)  
- Notification time on/off  
- Timezone / day-boundary note  
- Baseline window (7 vs 14 days)  
- Habit chips enable/disable (Block D)  
- **Session cue style**: Haptic / Voice / Both (default Both) — for orthostatic stand-up cue and phase transitions (new, see §6.5)
- H10 pairing / BLE troubleshooting help  
- Export JSON/CSV  
- Local analytics summary (adherence, etc.)  
- Delete all data  
- About / disclaimer  
- Orthostatic always skippable with confirm (O1)

---

## 7. Information architecture (screens)

1. **Onboarding** (first launch): purpose, privacy, H10 requirement, disclaimer, optional display name, notification permission  
2. **Questionnaire** (blocking when incomplete)  
3. **Today** hub (post-questionnaire): **Start morning measurement** + today’s results  
4. **Morning measurement session** (combined guided flow; skip-orthostatic variant)  
5. **History** (gated)  
6. **Day detail**  
7. **Settings**  

---

## 8. Privacy and trust

| Rule | Detail |
|------|--------|
| Local first | All data in app sandbox |
| No account | Optional display name only |
| No third-party cloud analytics SDK | None in v3 |
| First-party local analytics | Yes — events/metrics on device only |
| No ads | None |
| Network | None required for core flow; BLE only |
| Export | User-initiated share sheet |
| Delete | One-tap wipe |
| Future App Store | Privacy Nutrition Labels: Data Not Collected (if still true); privacy policy URL when shipping publicly |

**Disclaimer (onboarding + About):**  
Not a medical device. Not for diagnosis or treatment. For personal training journaling only. If you have a heart condition or dizziness on standing, consult a clinician before orthostatic testing; stop if lightheaded.

---

## 9. Hardware and environment

| Item | Requirement |
|------|-------------|
| Phone | iPhone, iOS version per tech spec |
| Strap | Polar H10 (BLE Heart Rate + RR if available) |
| Optional | Oura — **not integrated** in v3; user may type RHR in notes if desired |

---

## 10. Rollout plan

| Phase | Deliverable | Exit criteria |
|-------|-------------|---------------|
| **Docs** | PRD + TECH_SPEC approved | Zach sign-off |
| **v1 vertical** | Questionnaire gate + local store + Today shell | Forced gate works |
| **v2** | H10 connect + 60 s rMSSD + history | Replaces Elite for 7-day parallel check |
| **v3** | Orthostatic + baselines + notifications + export | Daily driver |
| **v3.1 (optional)** | Polish, widgets, CSV to Files | Nice-to-have |
| **v4+** | Optional TP/Intervals export, Oura import, HealthKit read (maybe), longer orthostatic mode, App Store | Separate PRD addendum |

**Parallel validation (recommended):** For **7 mornings**, run Elite HRV *after* this app’s rMSSD (or vice versa, fixed order) and note both values in Notes to sanity-check magnitude — not for pixel-perfect match.

---

## 11. Future: App Store for friends

Does **not** block v3. When considered:

| Area | Implication |
|------|-------------|
| Legal | Privacy policy, stronger medical disclaimer, maybe “wellness” not “diagnosis” |
| Support | Friends will break BLE; need troubleshooting screen |
| Signing | Apple Developer Program, review |
| Features to avoid until ready | HealthKit write of “clinical” types without care; unsubstantiated readiness claims |
| Features that help later | Clean architecture, settings-driven thresholds, export already built |

---

## 12. Product decisions (locked for v3)

| ID | Question | Options | Recommendation |
|----|----------|---------|----------------|
| **O1** | Can user skip orthostatic after HRV? | (a) Required daily (b) Skippable with confirm (c) Required 4×/week | **LOCKED (b)** Skippable with confirm |
| **O2** | Lying HR duration in combined flow | (a) 60 s after rMSSD (b) reuse rMSSD mean HR (c) 30 s after rMSSD | ~~LOCKED (c)~~ **SUPERSEDED (v3.1):** single 60–75 s lying phase serves both rMSSD and avg lying HR (effectively option (b), merged rather than sequential) — see §6.5 |
| **O3** | Orthostatic gap primary display | gap_peak vs gap_avg | **LOCKED** both stored; **gap_peak** primary in UI |
| **O4** | Strict history gate | Block history until questionnaire | **LOCKED Yes** |
| **O5** | rMSSD posture | Lie vs sit | **LOCKED Lie** |

---

## 13. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| BLE flaky on iOS | Clear reconnect UX; foreground-only session; tested checklist |
| rMSSD ≠ Elite exactly | Document method; parallel week; don’t chase identity |
| User stands too slow/fast | Large cues, haptics, invalidation if peak too late |
| Dizziness | Warning in onboarding; cancel button always visible |
| Habit drop | Notification + <5 min full path |
| Scope creep (Oura, TP, AI) | Non-goals list; new PRD revision required |

---

## 14. Out of scope copy / compliance

- Do not claim FDA clearance or medical accuracy.  
- Do not use the word “diagnose.”  
- Prefer “training journal,” “morning check-in,” “personal baselines.”

---

## 15. Approval

| Role | Name | Status |
|------|------|--------|
| Product owner | Zach | **Approved (2026-08-02)** |
| Spec author | Grok (session 2026-08-01) | Complete for review |

**Next step after approval:** implement per `TECH_SPEC.md` milestones; no code until Zach says go.
