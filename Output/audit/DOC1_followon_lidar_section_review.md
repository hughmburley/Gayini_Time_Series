# LiDAR section draft — review

**Read-only review, not an audit and not a rewrite.** 4 August 2026.
Draft reviewed: the three edits supplied at the design seat (§12.2 gaps row, §12.3 bullet, new §12.4).
Numbers taken from the rasters, the database and the Task U / LID-1 change reports — not from the handoff.

---

## 0 · Before anything else: the handoff supplied is superseded

**Two copies of `Gayini_LiDAR_section_handoff_to_methods.md` exist and they are different documents.**

| copy | modified | bytes |
|---|---|---|
| `docs/reference_update/…` — **the one I was pointed at** | 14:32 | 11,784 |
| `Output/audit/…` | **15:30** | **13,444** |

The newer copy adds four substantive passages, and **two of them contradict the draft**:

1. *"**Six height percentiles were usable, not seven.** The lowest percentile has no 2021 z55 tile"* —
   the draft says *"seven height percentiles at 5 m"*.
2. *"property-median first-return density rose from **1.0622 to 1.4672**, about **38%** more returns per
   unit area"* — the draft says *"approximately 40% more first returns"*.
3. *"**The LiDAR reaches 18,533 ha further than the Landsat census does**, which is why anything crossing a
   census product with a LiDAR product must be computed on the intersection rather than on either extent
   alone."* — bears directly on §2 below.
4. The stable-ground test's verdict and the rule that its floor's **full name is load-bearing**: a
   *change-detection floor on vegetated ground at 500 m grain*, **9.659 pp** against an observed
   **+0.2569**, *"never written as a 'sensor floor'"*.

This is discrepancy class #1 (issues log I-17): two dated copies of one artefact, and the older one was the
one in play. **Establish which copy governs before applying anything below.** The review that follows uses
the newer copy where they differ, and says so each time.

---

## 1 · Every number against source

### CONFIRMED — the 13.3%, exactly, on a fifth code path

Recomputed from the delivered rasters `Output/rasters/task_U/taskU_bbh_fpc_{2009,2021}_8058_10m.tif`
(6,407 × 4,375, uint8, nodata 255, EPSG:8058, 10 m):

| quantity | reproduced |
|---|---|
| both-valid cells | **8,588,260** → **85,882.60 ha** |
| FPC > 0 at either epoch | **1,144,925** → **11,449.25 ha** |
| share | **13.3313%** |

Matches your reproduction to every digit. Decomposition, which the record does not carry: **2009 only
165,964 · 2021 only 249,023 · both epochs 729,938.** `taskU_denominator_both_valid_ha` is registered at
85,882.6 and agrees.

### CONFIRMED — the census comparator

86,375 Floodplain Woodland / Forest cells of 1,080,157 = **7.997% → 8.00%**, over
1,080,157 × 0.062351428 = **67,349.33 ha**. Both as the handoff states.

### CONTRADICTED — "approximately 40% more first returns"

**1.0622 → 1.4672 is +38.13%.** The draft's "approximately 40%" is the **stale-era** figure: the withdrawn
1.4855 gives 1.4855 ÷ 1.0622 = **+39.85%**, which is where "~40%" came from.

**The qualitative form does not survive the correction**, and the error is live in three places in the record,
not only in the draft:

- `TaskU_gateU1_report.md:182` — *"The qualitative claim is unchanged — 1.0622 → 1.4672 is +38.1%, still ~40%"*
- `TaskU_gateU3_report.md:142` — the same sentence
- `TaskU_gateU3_report.md:137` — *"rose from 1.0622 to 1.4672, ~40% more"*

Each of those states +38.1% and then calls it ~40% in the same breath. **38.1% does not round to 40%.** The
newer handoff has already corrected to "about 38%"; the older handoff says "about 38%" in its body and
"roughly 40% … unchanged" in its parenthetical, and is internally inconsistent.

**The draft should read approximately 38%.** The direction and the "real instrument difference" conclusion
are untouched.

### FLAG — "seven height percentiles at 5 m"

Correct as a description of the **delivery**; the newer handoff says **six were usable** because the lowest
percentile has no 2021 z55 tile. If the newer copy governs, this sentence will be contradicted by the
handoff it is drawn from.

---

## 2 · The non-crossing rule — the draft commits the crossing it warns against

The warning sentence itself is well drafted. The two sentences **before** it are the problem.

### 2.1 · "At most 13.3% of **the property**" — the substitution the handoff rules out

The handoff is explicit: *"Do not round it to 'the whole property' — the 28.2 ha shortfall is what makes it a
measured figure rather than an assumption."* The 13.33% is over **both-valid, 85,882.6 ha**; the property is
**85,910.8 ha**. The draft writes "of the property" **without the inline denominator at that point**.

Ruling AA's own wording makes the same slip — *"FPC > 0 covers 13.33% of the property"* — but immediately
supplies *"(11,449.25 ha of 85,882.6 ha both-valid)"*. The draft carries the slip without the repair.

### 2.2 · "The cover floor is therefore measured on country that is approximately 87% non-woody" — this is the crossing

**The cover floor is not measured on the both-valid extent.** It is measured on the census extent —
67,349.33 ha mapped, 61,655 ha non-treed. The 87% is over the **LiDAR** extent, 85,882.6 ha. Per the newer
handoff the LiDAR reaches **18,533 ha further than the census**.

So the sentence takes a statistic computed on one footprint and predicates it of an object measured on
another — **two sentences before warning the reader not to do exactly that.** The footprint on which the two
instruments are comparable is **census ∩ LiDAR = 67,268.0 ha**, registered as
`taskU_denominator_census_x_lidar_ha` = 67,268.002 — **and the 13.33% was not computed on it.**

This is the most consequential finding in the review. It is not a wording nicety: the inference
*"the floor is overwhelmingly a ground-layer signal"* is the paragraph's payload, and it is carried by a
denominator that does not match the thing it describes.

### 2.3 · The census denominator is missing where the census number appears

The draft's own sentence claims the two differ by *"different numerators, different denominators"* — and
then gives only the LiDAR denominator. **8.0% appears with no denominator at all.** The handoff supplies
67,349 ha. If the rule is that each number carries its denominator inline, the sentence enforcing the rule
should be the first to obey it.

---

## 3 · "Specified but not run" and "pinned in advance and unexercised"

**The pre-registration claim is CONFIRMED, precisely.** LID-1 Gate L3:

> **U-Q2** are the persistent-floor refugia woody or ground-layer — **not run, deferred.** Its two decision
> rules (R3 shrub class `bbd` ∈ [1.0, 3.0) m; R5 census-pixel inclusion at coverage ≥ 0.99) **are already
> pre-registered**

**But "Two analyses are specified and not yet run" OVERSTATES the record.** In the record there is **one**
such analysis — U-Q2 — carrying **two decision rules**. The draft splits it into two analyses and gives the
pre-registered rules to only the second, leaving the first ("spatial concordance between the persistence
surfaces and an independent structural measure") described as "specified" with nothing named behind it.
Gate L3's own recommended wording treats them as one:

> The concordance test between the persistence surface and an independent structural measure is specified
> and its decision rules pre-registered; it has not been run.

The genuinely separate deferred item is **U-Q3's difference-DEM component**, which the draft does not mention.

**Note also that the draft is internally inconsistent:** Edit 1 says *"the concordance analysis is specified
but not run"* — singular, and correct. Edit 2 says two. Edit 1 is the accurate one.

---

## 4 · Overstatement, and one understatement

| draft phrase | verdict |
|---|---|
| "processed to a common frame and cross-checked" | **Supported.** Warped once to EPSG:8058, co-registration r = 0.897298 at zero offset, Gate L1 reproduced nine of nine claims |
| "a test for whether it could be corrected for found no derivable correction" | **Supported.** R² 0.0120 and 0.000088 with **opposite-sign** slopes; *"no correction is derivable and none was proposed"* |
| "2009 … end of the Millennium Drought and 2021 follows the 2016 and 2020–21 flood years" | **Supported** |
| "two of the three community results change sign" | **Supported** — +1.57 → −29.04 (−2.60 SD), +9.61 → −18.67 (−1.93 SD) |
| **"establishing a numeric floor below which nothing is claimed"** | **UNDERSTATED, and in the direction the record forbids.** The newer handoff: the floor's *"full name is load-bearing and the section must not shorten it"* — a **change-detection floor on vegetated ground at 500 m grain**, **9.659 pp**, an **upper bound on the sensor effect, never an estimate of it**, and *"never written as a 'sensor floor'"*. The draft gives it no name and no value, and places it immediately after the sensor sentence — which invites precisely the sensor-floor reading that is ruled out |
| **"each epoch is known only to within a water year"** | **UNSUPPORTED.** The record says capture dates are unrecoverable — no readme, no delivery note, no dated file tags. It does not establish water-year precision. The epoch labels are calendar years. This asserts a precision the record does not have |
| "one community fit reversing sign" (in the record, absent from the draft) | The draft drops the **fit reversal**, which is the stronger methodological point. Not an error — a loss |

---

## 5 · The four reasons for §12 placement — one is wrong, one does not discriminate

**Reason 4 (the metric collision) — CORRECT, exactly as stated.** +1.57 / +9.61 → −29.04 / −18.67, Aeolian
community fit reversing sign (`LID1_gateL1_verification.md:58-59`, `LID1_gateL3_L4_recommendations.md:200-201`).

**Reason 1 (every Task U raster is REVIEW) — true, but it does not discriminate.**
**All 191 rasters in `raster_asset` carry `qa_status = REVIEW`** — not only Task U's 20. If REVIEW status is
disqualifying, it disqualifies every census raster behind every figure already in the document. As a reason
to treat the LiDAR material differently from the rest of the document, it does not hold. It may still be a
sound reason to ship nothing on REVIEW rasters — but then it is an argument about the whole deliverable.

**Reason 3 (ten quantities ruled for registration and never inserted) — WRONG as stated.** The record says
the opposite. **Ruling AA is titled "the ten stay unpinned"**:

> **Not inserted.** … Every Task U quantity except the two denominators is unpinned and outside
> `test_T8_headline_reproduction.py`. The 13.33% **ships as a bounding statement in `METHODS_DOC`** and
> **must quote its denominator inline — 11,449.25 ha of 85,882.6 ha both-valid — because there is no
> `number_id` to cite.**

They were **ruled to remain unpinned**, deliberately, logged as I-40's tenth instance — not ruled for
registration and forgotten. And **two Task U denominators are registered**
(`taskU_denominator_both_valid_ha` 85,882.6; `taskU_denominator_census_x_lidar_ha` 67,268.002). So the
absence of a `number_id` for the 13.33% is a decision with a stated mitigation **that the draft already
follows**, not an omission counting against the material.

**Reason 2 (cultural review) — supported, but narrower in the record than stated.** See §6.

---

## 6 · The governance question — what the record says

**Reporting, not deciding.** The record does not define "LiDAR-derived product" in the abstract. What it
does is scope the requirement to **50 cm terrain products**, in every place it is stated:

- Gate L4-4: *"**Fifty-centimetre terrain** reveals channels, earthworks and scarring that a Landsat product
  does not. This requires Nari Nari Tribal Council review before anything leaves."*
- Rulings W–AB: *"the **50 cm DEMs** require Nari Nari review before anything leaves. **It is on the DEM rows
  now**"* — attached to specific registry rows, not to a class of derived quantities.
- *"The two DEMs are 97% of the volume, and they are **also the governance-sensitive layers**."*
- Ruling AJ provides a deferral path specifically for *"the two 50 cm"* products.

**And the record positively contemplates the 13.33% shipping.** Ruling AA: *"The 13.33% **ships as a bounding
statement in `METHODS_DOC`**."* Gate L3-5's recommended §12.3 wording includes the figure in full.

**So the ruling-level record and the handoff's §5 disagree.** The rulings attach the requirement to the
terrain rasters and separately authorise the percentage; the handoff's §5 generalises to *"any LiDAR-derived
product"*, which read literally would withdraw a number the same body of work authorised. **Only the design
seat can settle which governs** — but the record as written supports retaining the 13.33%, and no ruling
extends the review requirement to a summary statistic.

---

## 7 · Not in scope, noted as asked

**U2** (`Output/figures/task_U/U2_epoch_context_35yr.png`, `qa_status = REVIEW`) is the stronger of the two
figures and the handoff argues it should lead the section — it draws the epoch-placement argument the §12.4
prose makes in words. It cannot ship on the tenth under the same REVIEW and governance constraints.
**Noted for the version after; not developed.**

No new LiDAR analysis is proposed anywhere in this review.

---

## Summary

**Wrong:** "approximately 40%" (it is 38.1%) · "two analyses are specified" (the record has one, plus a
separate deferred component) · reason 3 in the placement argument (Ruling AA ruled the ten **stay** unpinned).

**Unsupported:** "known only to within a water year" · "seven height percentiles" if the newer handoff governs.

**Overstates by crossing denominators:** "at most 13.3% of **the property**" · "the cover floor is measured
on country that is approximately 87% non-woody" — the second is the crossing the same paragraph warns
against, and it carries the paragraph's conclusion.

**Understates:** the change-detection floor, which the record says must be named in full and never shortened
to a sensor floor.

**Confirmed:** 13.3313% exactly, on a fifth code path · the 8.00% census comparator and its 67,349.33 ha ·
pre-registered decision rules · no derivable sensor correction · the Bala 29ca sign reversals · reason 4.

**Governance:** the record scopes cultural review to the 50 cm terrain products and separately authorises the
13.33% to ship in the methods document. The handoff's §5 is broader than the rulings it summarises.
