# Task U · Gate U3 — Sensor step-change test · **DRAFT · STOP**

**Spec:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md`, Gate U3 items 1–6 (U3.6 by amendment)
**Date:** 1 August 2026 · **Status:** DRAFT, at the Gate U3 STOP
**Scripts:** `scripts/14_lidar/U3_sensor_step_change.py` · `scripts/14_lidar/U3_stable_ground_figure.R`
**Artefacts:** `Output/tables/taskU_gateU3_{stable_ground,density_scaling,u36_blocks,facts}.csv` ·
`Output/figures/task_U/U3_sensor_step_change.png` (registered `figure_u3_sensor_step_change`)

**The verdict is a science decision. What follows is its evidence and my reading; the
decision is not mine to take.**

---

## 1 · The spec's suggested derivation is circular, and was not used for the FPC test

Item 1 offers *"otherwise derive from persistently-zero FPC in both epochs"*. Selecting
pixels where FPC = 0 at **both** epochs forces the FPC difference to zero **by
construction**, so it would return a flawless "no sensor offset" verdict that means
nothing. The same objection applies to defining stable ground on LiDAR height and then
measuring a height offset.

Stable ground is therefore derived from **Landsat and the vegetation class map** —
sources entirely independent of the instrument under test. No existing roads,
hardstand or building layer exists in the repo; `cuts.shp` is the 2018 bank cuts, not
infrastructure.

| Set | Definition (no LiDAR value enters it) | Area |
|---|---|---|
| **S1 bare stable** | `flood_zone ∈ {0,1}` (never/rarely flooded) **and** census `total_veg p50 < 30%` | **124.3 ha** |
| **S2 treed stable** | `veg_regime_class = 40` (Floodplain Woodland/Forest) **and** ≥ 250 m from any 2018 bank cut | **4,799.1 ha** |

The `p50 < 30%` cut is set from the **meaning of the variable**: `total_veg = PV + NPV`
includes litter and dry grass, so the property median is ~82% and genuinely hard ground
sits far below it. Sensitivity: 77.6 ha at `<25`, 124.3 ha at `<30`, 247.2 ha at `<40`.

---

## 2 · Both controls fail, in opposite and instructive ways

**S1 has no dynamic range.** Only **0.46%** of S1 pixels read non-zero FPC at either
epoch. Its FPC offset is median **0.000**, mean **+0.006**, block |p95| **0.024 pp** —
but a control that reads zero at both epochs bounds an **additive offset at zero** and
nothing else. It cannot bound a vegetation-dependent or multiplicative sensor
difference, which is the kind ALS-50 → ALS-80 would produce. Its height offset is
likewise 0.000 m for the same reason.

**S2 is not stable.** Item 3 asks for "mature black box stands expected to be stable".
**Gate U2 has already established that nothing vegetated on this property is stable
across these two dates** — 2009 is the drought trough (farm cover percentile 0.0 at
WY2008), 2021 follows the 2016 and 2020–21 floods. Black box grew. S2's FPC offset of
median **+1.000**, mean **+1.889** is therefore **an upper bound on the sensor effect
that includes twelve years of real drought recovery**, not an estimate of it.

**Between them we cannot bound the sensor effect where vegetation exists.** That is the
honest position, and it is a consequence of the two dates the delivery gives us, not of
the method.

---

## 3 · The 13.33% — a spine finding, not a caveat

*Promoted from a limitation to a finding, 1 August 2026 (design-seat C3).*

> **Only 13.33% of the Task U both-valid area — 11,449 ha of 85,882.6 ha — reads
> LiDAR FPC > 0 at either epoch.**

The mechanical consequence first: FPC is a **woody** cover product and Gayini is largely
treeless chenopod shrubland, so the whole-of-property FPC difference is dominated by
ground where the instrument has no dynamic range, and the property mean of +0.257 pp is
diluted rather than informative. `bbh` is the weakest LiDAR product here; U-Q1 and U-Q2
rightly rest on the height ladder.

**The larger consequence is for S6.** The drought floor — the project's headline metric
— is measured on country that is **87% non-woody by area**. The floor is therefore
overwhelmingly a **ground-layer** signal, not a canopy one.

That is one of the two outcomes **U-Q2 was built to distinguish**, arriving early and
from a different product. It **weakens the S6 cover-versus-structure caveat across most
of the property**, and it bounds U-Q2 before U-Q2 runs: **at most 13.33% of the property
could have a woody explanation for its floor.**

It does **not** settle U-Q2 — the persistent-floor refugia could concentrate inside that
13.33%, which is exactly what U-Q2's concordance would test. But it stands as a finding
in its own right, with its denominator named, **whether or not U-Q2 ever runs.**

It also independently justifies T-4: LiDAR FPC and Landsat `total_veg` are not measuring
the same country, let alone the same variable.

---

## 4 · Item 4 — the floor against the observed change

FPC difference, 2021 − 2009, percentage points:

| Set | grain | n | median | mean | IQR | p05 | p95 |
|---|---|---:|---:|---:|---:|---:|---:|
| S1 bare stable | pixel 10 m | 12,457 | 0.000 | 0.006 | 0.000 | 0.000 | 0.000 |
| S1 bare stable | 500 m block | 39 | 0.000 | 0.015 | 0.000 | −0.002 | **0.024** |
| S2 treed stable | pixel 10 m | 477,336 | 1.000 | 1.889 | 6.000 | −9.000 | 15.000 |
| S2 treed stable | 500 m block | 582 | 0.856 | 2.126 | 4.139 | −2.017 | **9.659** |
| **OBSERVED** whole property | pixel 10 m | 8,588,260 | **0.000** | **0.257** | 0.000 | 0.000 | 2.000 |
| **OBSERVED** whole property | 500 m block | 3,620 | 0.001 | 0.265 | 0.059 | −0.256 | 1.909 |
| **OBSERVED** woody subset | pixel 10 m | 1,144,925 | **1.000** | **1.927** | 5.000 | −7.000 | 14.000 |

**Floor** = 95th percentile of |block-mean difference| over 500 m blocks of stable
ground. It answers the question a reader actually asks — *how big a difference can an
area of this size show when nothing changed?* — which a per-pixel spread does not.

Two things fall out, and the second is the more damning.

**(a) The floor exceeds the observed change by a factor of 38.** The only vegetated
control gives **9.659 pp**; the observed whole-of-property mean change is **+0.257 pp**.
The spec's own criterion fires: *"If that floor exceeds the observed mean change, then
the whole-of-property FPC change is not interpretable."*

**(b) The observed woody-country change resembles the control's — but the two are not
independent samples, and the resemblance carries much less than it appears to.**

| | area | median | mean |
|---|---:|---:|---:|
| S2 treed **stable** | 4,799 ha | +1.000 | +1.889 |
| OBSERVED, all woody country | 11,449 ha | +1.000 | +1.927 |

*Amended 1 August 2026 (design-seat C2).* **S2 is roughly 42% of the set it is being
compared against and sits inside it almost by construction.** An earlier draft read this
as two independent samples moving identically; it is substantially a set agreeing with
its own largest component. The observation is real, the inference drawn from it was
stronger than the evidence supports, and it is restated here with the overlap declared.

**The verdict does not rest on (b).** Point (a)'s 38× margin carries it alone. (b) is
retained only as a consistency note, and does not reach the findings note.

---

## 5 · U3.6 — the density-scaling test · **no relationship**

The property-median `bb5` first-return density rose from **1.0622 to 1.4855**, ~40% more
returns per unit area at the second epoch. That is the ALS-50 → ALS-80 step made
quantitative, and it is the mechanism by which T-2 would operate. Does the FPC offset
scale with it?

| Set | n blocks | slope (FPC pp per return m⁻²) | r | R² | residual SD |
|---|---:|---:|---:|---:|---:|
| S1 bare stable | 39 | +0.0102 | 0.1095 | **0.0120** | 0.0790 |
| S2 treed stable | 582 | −0.0409 | −0.0094 | **0.000088** | 3.9362 |

**It does not scale.** R² is 0.012 and 0.0001; the two slopes even have opposite signs.
The density difference explains essentially none of the block-to-block variation in FPC
difference in either control.

Per U3.6's own instruction: *"If it does not scale, say so plainly; the Gate U3 floor
stands unmodified and U-Q4c is limited to large, spatially coherent, locally-contrasted
change."* **No correction is derivable and none is proposed.** The hazard U3.6 was
written to manage — a silently-applied density correction — does not arise.

---

## 6 · Item 5 — the vertical offset · **this is the product that survives**

`bb0`, 50 cm decimated 1/20, on stable ground, metres:

| Set | n | median | mean | IQR | **MAD** | p05 | p95 |
|---|---:|---:|---:|---:|---:|---:|---:|
| S1 bare stable | 12,397 | **+0.3032** | +0.3018 | 0.0485 | **0.0243** | +0.2229 | +0.3599 |
| S2 treed stable | 479,779 | +0.2244 | +0.2336 | 0.0827 | 0.0413 | +0.1294 | +0.3747 |

**S1 is the estimate to use: +0.303 m, MAD 2.4 cm.** Hard bare ground, no canopy, no
ground-classification ambiguity. S2's +0.224 m sits 8 cm lower, which is what canopy
effects on ground-point classification would do, and its spread is nearly double.

This is a genuinely good result and it is the one place Gate U3 clears the way rather
than closing it down:

- 2021 sits **+0.30 m above** 2009 on stable ground. Whether that is datum, calibration,
  or both is unresolved and does not matter — **only departures from it are signal.**
- The **MAD is 2.4 cm**. A 30 cm bank cut is **twelve MADs** above the noise; a
  half-metre earthwork is twenty.
- So the **difference DEM is strongly interpretable**, and U-Q4c's earthworks check —
  including the Task J **L10 unblock** — is viable.

The vertical-datum question to Adrian stands, but it is now clearly **not gating**: the
offset is measured on common ground exactly as the spec requires, and no absolute
elevation is interpreted anywhere.

---

## 7 · Height ladder

`bbd` (95th percentile) offset: **0.000 m** on S1 (no dynamic range — all zeros) and
**+0.158 m** median / +0.556 m mean on S2 (confounded with growth). All six stages at
both epochs are in `taskU_gateU3_stable_ground.csv`.

One number worth flagging for U-Q4a: on S2, the **difference of medians** is +1.42 m
(1.658 → 3.082) while the **median of differences** is +0.158 m. That gap is large, and
it means the two epochs are not cleanly comparable pixel-by-pixel in structurally
complex canopy at 5 m. **U-Q4a should use zonal medians of each epoch separately rather
than a per-pixel difference** — which is what the spec already requires ("report zonal
medians"), now with a measured reason.

---

## 8 · My reading of the verdict — for decision, not for adoption

| Product | Status | Basis |
|---|---|---|
| **FPC change** | **Not interpretable** | Floor 9.659 pp vs observed 0.257 pp; stable and unselected woody ground moved identically; only 13.33% of the property has any FPC signal |
| **Height change** | **Not separable** from drought recovery | S1 has no range; S2 is not stable |
| **Difference DEM** | **Interpretable** | Offset +0.303 m, MAD 2.4 cm; earthworks are 12–20 MADs above noise |
| **U-Q1 / U-Q4a** | **Unaffected** | A within-epoch between-paddock contrast; no change statistic involved |

**Pinned floor (design-seat D1, 1 August 2026) — and its name is load-bearing:**

> **Change-detection floor on vegetated ground, 500 m grain: 9.7 FPC pp.** Conflates
> sensor difference with real ecological change. S2-derived. An **upper bound** on the
> sensor effect, **not an estimate of it.** The sensor effect alone is **unbounded above
> zero** on vegetated ground with the controls this delivery permits.

**It is not a sensor floor and must never be registered or written as one.** S2 is the
control this gate has just shown is not stable; it carries twelve years of drought
recovery. Labelled "sensor floor", a later reader takes it to mean *the ALS-50 → ALS-80
difference is 9.7 pp*. The data does not say that. The long form above travels into
`legend_semantics` on every row that cites it.

No FPC change below 9.7 pp at 500 m grain may be claimed anywhere in Task U. Since the
observed change is 0.257 pp, **no whole-of-property FPC change claim survives** — a
legitimate reportable outcome, pre-authorised as one, and stated as a finding rather
than omitted.

**What still works.** U-Q4a is the priority question and is untouched. U-Q4c's
difference DEM is viable and may be the most valuable single product in the task, since
it also speaks to Task J's L10 blocker. U-Q4b is a within-epoch concordance and does not
depend on this gate.

---

## 9 · Acceptance criteria touched

- [x] Stable surfaces identified; derivation stated, and the spec's own suggestion
      rejected with reasons
- [x] FPC **and** height distributions reported on stable ground at both epochs
- [x] The same reported on treed reference areas — **and shown not to be stable**
- [x] Verdict carries a numeric floor (**9.7 FPC pp at 500 m**) — proposed, for decision
- [x] Separate vertical offset for `bb0` (**+0.303 m, MAD 0.024 m**), on common ground
- [x] U3.6 run; no scaling found; **no correction derived and none applied**
- [x] No wording implies either sensor validates the other
- [x] LiDAR FPC and Landsat `total_veg` never shared an axis or differenced
- [x] Change report in `docs/change_reports/`

## 10 · For the issues log

| Id | Item | Triage |
|---|---|---|
| U-I7 | Gate U3 item 1's suggested derivation (persistently-zero FPC in both epochs) is circular for the FPC test. Not used; Landsat-based derivation substituted | Would have changed the verdict from "not interpretable" to a false "no offset". Recorded so it is not reintroduced |
| U-I8 | No roads / hardstand / infrastructure layer exists in the repo. S1 is a proxy built from Landsat persistence | Limits S1's interpretation; does not change a number |
| U-I9 | `bbh` has 13.33% dynamic range on-property. Any future task planning to use LiDAR FPC at Gayini should know this before scoping | **To the limitations register** (design-seat D4). Also promoted to a finding — see §3 |
| U-I10 | **There is no stable vegetated ground on Gayini between 2009 and 2021.** S2's failure as a control is a property of the *delivery*, not a method defect, and Gate U2 predicted it | **To the limitations register** as a limitation of the two-epoch LiDAR comparison, not of Gate U3 (design-seat D4) |

---

## STOP — what is being asked

1. **Pin or revise the FPC change floor.** I propose **9.7 pp at 500 m grain**, which
   makes whole-of-property FPC change unreportable.
2. **Confirm the reading that no FPC or height change claim survives**, and that U-Q4c
   proceeds on the **difference DEM only**.
3. **Accept the vertical offset of +0.303 m (MAD 2.4 cm)** as the difference-DEM
   calibration, S1-derived.
4. **Note that S2 failed as a control** and that this was predictable from Gate U2 —
   there is no stable vegetated ground on this property between these two dates.
