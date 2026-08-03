# Response to product-review notes (2026-08-02)

Companion to `PRD.md` / `TECH_SPEC.md`. Product name going forward: **Renova**.

---

## 1. How long should the orthostatic test be? Research vs our protocol

### What research / clinical guidelines use

| Context | Typical protocol | Purpose |
|---------|------------------|---------|
| **Orthostatic hypotension (clinical)** | ~**5 min supine**, then BP/HR at **~3 min standing** (sometimes also 1 min) | Diagnose sustained BP drop / HR response |
| **Active stand / POTS screening** | Often **5–10 min supine**, then **up to 10 min standing** with serial HR/BP | Diagnose postural tachycardia (≥30 bpm rise sustained) |
| **Autonomic lab studies** | Sometimes **5+5 min** or longer (10 min stand) | Research-grade comparability to tilt |
| **Couzens (coaching tool)** | ~**60 s lie + 60 s stand**; track lying avg, standing avg, **peak standing**, gaps | **Daily readiness / ANS quadrant**, not clinical diagnosis |

Clinical orthostatic tests are **longer** because they are optimizing **diagnostic sensitivity** (POTS, OH), often with BP cuffs, not a 3-minute morning habit with a chest strap.

### Our current v3 protocol

~15 s settle + 60 s rMSSD + **30 s** lying HR + **60 s** stand ≈ **3 min** total.

- **Aligned with Couzens** on the *idea* (quick daily orthostatic, peak−lying gap).  
- **Not aligned** with clinical 3–10 min stand standards.  
- **Shorter lying sample (30 s)** after rMSSD is a habit tradeoff, not a research gold standard.

### Recommendation

| Goal | Protocol |
|------|----------|
| **Daily habit (v3 default)** | Keep ~**60 s stand** + peak/avg gaps; keep combined rMSSD session. Accept that this is a **trend tool**, not a POTS test. |
| **Better Couzens alignment** | Prefer **60 s lying HR** (not 30 s) after rMSSD if you can spare ~30 s more on the floor. |
| **Optional “long stand” mode (later)** | Settings: **60 s / 3 min stand** for occasional deeper check (still not a medical diagnosis). |
| **Do not** | Claim clinical OH/POTS diagnosis from this app. |

**Bottom line:** Research supports **minutes**, not seconds, for *clinical* orthostatic testing. For *daily coaching readiness*, Couzens-style **~1+1 min** is a deliberate lightweight proxy. We should **document that honestly** and optionally offer a longer stand later—not silently claim clinical equivalence.

---

## 2. Evidence behind green / yellow / red signals

### Honest answer (current v1.3)

Renova no longer uses arbitrary ±10% / ±3 bpm tables as the primary rule.

**Couzens’s actual method** (dashboard): compare **acute (≈7-day)** metrics to a **long-term norm (≈60-day mean)** and shade a **normal range ≈ ±1 SD**. Outside that band is “not normal for this athlete.” He does **not** publish a universal green/yellow/red product matrix.

**Renova G/Y/R** (TECH §5.4) implements that idea: green inside ±1 SD, yellow ~1–1.5 SD, red beyond ~1.5 SD, with concerning-direction labels.

### What *is* evidence-backed (directionally)

| Idea | Support |
|------|---------|
| **Compare to personal baseline, not population** | Couzens 7d vs 60d; HRV practice generally |
| **±1 SD as “normal range” visualization** | Couzens dashboard figures (explicit green band) |
| **HRV related to readiness for higher intensity** | Couzens / Vesterinen et al. type findings |
| **RHR + orthostatic response context** | Couzens quadrants; Hedelin et al. overreaching |
| **Subjective fatigue/mood/soreness/stress** | Couzens Ch.13; Morgan/Hooper swimming staleness work |
| **Composite > single commercial score** | Couzens critique of unanchored readiness apps |

### What is *not* proven

- That **1.0 / 1.5 SD** yellow/red edges are optimal for *you* (tunable later)  
- That a single traffic light predicts adaptation that day  

### Recommendation

Keep lights as **personal-band cues**, not medical scores; show direction in words; allow tuning after you have months of data.

---

## 3. Analytics: “no SDK” vs in-app analytics

### Clarification

| Kind | v3 intent |
|------|-----------|
| **Third-party analytics SDK** (Amplitude, Firebase Analytics cloud, Mixpanel, etc.) | **No** — privacy-first, no phone-home |
| **On-device analytics / instrumentation** | **Yes** — local event + metric store so *you* can see adherence, completion, quality fails, time-to-complete |

Examples of **local analytics** (stay on phone):

- Days completed / streak  
- % mornings with orthostatic skipped  
- HRV quality fail rate  
- Median time for full session  
- Questionnaire item distributions over time  

**We will update the PRD wording** from “no analytics” → **“no third-party cloud analytics SDK; first-party local analytics OK.”**

---

## 4. TrainingPeaks / Intervals.icu sync later

**Agreed:** not in v3, but **optional future** (v4+), not a hard forever-no.

Architecture implication (tech): keep `DayRecord` / `MeasurementRecord` export-friendly (stable JSON schema) so a later exporter can push:

- Morning metrics as TrainingPeaks “metrics” style fields, or  
- Intervals wellness / notes / custom fields  

**No implementation now.**

---

## 5. Scale 1–5 vs 1–7

### Research (psychometrics, brief)

- **5- and 7-point Likert scales** are both widely used and considered adequate.  
- **7-point** often gives **slightly higher reliability / more variance** (more discrimination); diminishing returns above ~7–11.  
- **5-point** is faster and often better for general populations / less fatigue.  
- “Weird numbers” (e.g. 1–10, 0–100) help mainly by **more resolution**, not magic—**odd midpoints** (5 or 7) give a true center.

### Recommendation for Renova

**Default to 1–7** for core feeling items (athlete daily use, high motivation, want nuance).

| Scale | When |
|-------|------|
| **1–7** | Fatigue, mood, soreness, stress, sleep quality (core) |
| **Yes / No** | WHOOP-style habit tags (alcohol, late caffeine, etc.) |

Update traffic-light subjective bands when switching (e.g. green mean ≥ 5.0, yellow ≥ 3.5 on 1–7).

---

## 6. Questionnaire: Alan + WHOOP-inspired

### What Alan actually uses / models (archive)

From Couzens dashboard / readiness materials, morning metrics fed into readiness include:

| Field | Role |
|-------|------|
| **HRV** | Measured (not questionnaire) |
| **Pulse / RHR** | Measured |
| **Fatigue** | Subjective |
| **Mood** | Subjective |
| **Soreness** | Subjective (incl. “heavy legs”) |
| **Stress** (life stress) | Subjective |

He emphasizes: multi-input composite; low HRV ≠ ban all easy work; soreness = muscular readiness; life stress often early warning.

### WHOOP Journal (what you likely liked)

WHOOP separates:

1. **How you feel / recovery-adjacent ratings** (mood, etc., product evolves)  
2. **Behavior tags (yes/no)** correlated later with recovery: e.g. **alcohol**, **caffeine**, shared bed, meditation, late meals, etc.

The power is **habit ↔ recovery association**, not a long feelings essay.

### Proposed Renova questionnaire (v3)

**Block A — required (Alan core), scale 1–7**  
Higher = better for all feeling items (consistent polarity).

1. **Fatigue** — Exhausted → Fresh  
2. **Mood** — Very low → Great  
3. **Soreness / heavy legs** — Very sore → None  
4. **Life stress** — Very high → Very low  

**Block B — required short (WHOOP-inspired sleep feel)**  

5. **Sleep quality (subjective)** — Terrible → Excellent  
   *(complements Oura; captures “I slept 8h but feel wrecked”)*

**Block C — optional habit chips (WHOOP-style, yes/no, default off until user enables)**  

Suggested starter set (user can toggle in Settings later):

- Alcohol last night  
- Caffeine after 2pm (or “late caffeine”)  
- Hard training yesterday (self-tag)  
- Travel / late night  
- Illness / sick feel  

**Block D — optional free text Notes**

**Gate:** Block A + B required before measurements. Block C can be same screen, optional.

---

## 7. Name without account

**Yes — optional display name** in onboarding/Settings.

- Stored only on device  
- Used for “Good morning, Zach”  
- Not identity verification; no login  
- Default: empty → “Good morning”

---

## 8. “Friends will break BLE” — what that means

**Not** “Bluetooth is nonstandard.” BLE HR is exactly what Elite HRV, HRV4Training, Polar Beat use.

It means **support reality** when people other than you use the app:

| Issue | Why friends hit it |
|-------|---------------------|
| H10 connected to **two apps** | iOS often only streams cleanly to one |
| Wrong strap fit / dry electrodes | No RR → no rMSSD |
| Bluetooth permission denied | Silent fail |
| Backgrounded mid-test | Session dies (we’re foreground-only by design) |
| Non-H10 strap | May send HR without RR |
| “It worked yesterday” | Watch OS / phone OS updates |

Elite HRV has years of edge-case UX and support docs. For **you**, fine. For **App Store friends**, expect support load unless troubleshooting is excellent.

---

## 9. HealthKit — would it ever make sense?

| Write to HealthKit | Sense? |
|--------------------|--------|
| **Heart rate samples** during test | Low value (transient; Apple already has workouts from watch) |
| **HRV (SDNN)** | Possible; Apple’s type is often SDNN-oriented, not rMSSD—mapping is messy |
| **Mindful / sleep** | Not our domain |
| **Read: sleep analysis, resting HR from watch** | Maybe later if you drop Oura manual path |
| **Read: workouts** | Could contextualize “hard day yesterday” without Intervals |

**Recommendation:**

- **v3:** **No HealthKit** (simpler privacy story, fewer review issues).  
- **Later (optional):**  
  - **Read** last-night sleep duration / workouts for context chips  
  - **Write** optional “mindful session” or a single daily summary only if users want Apple Health graphs  
- Avoid writing clinical-sounding “recovery diagnosis.”

---

## 10. App name: **Renova**

Approved as product name. Bundle ID suggestion: `com.zringstrom.recoverydeck`.

---

## Product decisions (updated 2026-08-02 follow-up)

| ID | Decision |
|----|----------|
| Name | **Renova** |
| Local analytics | **Yes** (on-device only) |
| Cloud analytics SDK | **No** (v3) |
| TP / Intervals | **v4+ optional**, not v3 |
| Likert | **1–7** for feeling items |
| Questionnaire | Alan core + sleep quality; **optional** last caffeine time + amount; **optional** last meal time; optional habit chips |
| Display name | Optional onboarding field |
| Orthostatic duration | **Keep short daily proxy** (v3 combined ~60 s stand) |
| HealthKit | **Not v3** (confirmed) |
| G/Y/R | **Couzens-style:** acute vs **60-day mean ± 1 SD** band (see TECH §5.4)—not arbitrary ±10% |

### Couzens on green / yellow / red (short)

He does **not** ship a branded traffic-light product table. He:

- Compares **7-day** (acute) metrics to a **60-day norm**  
- Shades a **normal range ≈ ±1 SD** (green band in his dashboard figures)  
- Flags when the athlete is **outside their own range**  
- Uses **“red light”** for serious overtraining-type states (e.g. orthostatic Q4), not every off morning  

Renova’s G/Y/R is an **implementation of that normal-band idea**, not a quote of Couzens cutoffs.

### BLE “friends will break it” (plainer)

Bluetooth itself is fine—Elite HRV uses it too. The hard part is **everything around the radio**:

Imagine a friend installs Renova, wears an H10, and taps Start:

1. **Polar Beat is still connected** in the background → phone won’t give clean RR to Renova → “no HRV.”  
2. They **didn’t enable Bluetooth permission** → blank scan.  
3. Strap is **loose / dry skin** → HR jumps, RR missing → quality fail.  
4. They switch to Messages mid-test → app backgrounds → connection drops.  
5. They use a **generic $30 strap** that only sends BPM, not RR → we refuse to invent rMSSD.  
6. They’re in a gym full of BLE devices → slow pairing, flaky connect.

**You** already know “close other apps, wet electrodes, stay in the app.” Friends often don’t—so they think the app is broken when it’s the setup. That’s all “friends will break BLE” meant: **support/education**, not “BLE is wrong.”

Docs updated in PRD/TECH to reflect the above (see changelog).
