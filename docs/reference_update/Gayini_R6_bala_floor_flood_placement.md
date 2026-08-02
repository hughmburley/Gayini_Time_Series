# R6 — Do the Bala reference paddocks sit where their wetness predicts?

**Stream:** reference-state · **not** a Task U finding (design-seat Gate U3 STOP §3)
**Rule:** pre-registered as R6 in `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md`,
1 August 2026, **before any value was computed**
**Date:** 2 August 2026 · **Status:** DRAFT
**Script:** `scripts/14_lidar/R6_bala_floor_flood_placement.py`
**Artefact:** `Output/tables/taskU_R6_bala_floor_flood_placement.csv` (121 rows)

Database query only. No LiDAR. Read-only; nothing registered, nothing modified.

---

## The question, and why it is not a LiDAR question

The spine says flood frequency sets the drought floor, and that p05 rises ~2.2× faster
than p50 across the gradient. Gate U2 then measured that **Bala 29ca floods at roughly
one fifth its neighbours' rate** — 13.9% against 66–81% in WY2021, the wettest year in
the gauge record.

So a low floor at 29ca is **what the spine predicts.** The reference-state anomaly may
be an ordinary instance of the project's own published result rather than a rival
hypothesis to clearing. R6 tests that directly:

> Fit floor against long-run flood frequency, **within community**, at **pixel support**,
> over all non-treed census pixels. Place each Bala paddock-community part on its
> community's fit. Report the signed residual and the fit's own scatter.

**Variable discipline.** This uses the **census long-run flood frequency** —
`100 × Σwet ÷ Σvalid` over 35 water years, `MIN_VALID_YEARS = 25` — **not** the Gate U2
single-year annual wet fraction. Different variables, different scales, never
substituted. **L-01 is honoured by construction**: every paddock is decomposed into its
community parts before any residual is taken, because Bala 29ca is the extreme case
(Inland 35% / Riverine 33% / Aeolian 32%) and a whole-paddock residual would describe
no real place.

## The within-community fits

988,829 non-treed census pixels.

| Community | n px | slope | intercept | r | residual SD |
|---|---:|---:|---:|---:|---:|
| Aeolian Chenopod Shrublands | 77,544 | 0.2585 | 44.474 | 0.189 | 12.34 |
| Riverine Chenopod Shrublands | 193,658 | 0.5133 | 37.415 | 0.457 | 12.06 |
| Inland Floodplain Shrublands / Swamps | 717,627 | 0.5303 | 46.185 | 0.659 | 10.64 |

The slopes reproduce the spine's mechanism: **the floor rises about half a percentage
point for every point of long-run flood frequency**, in the two wetter communities. The
fits are loose (residual SD 10.6–12.3 pp), and that scatter is the yardstick every
residual below is read against.

## Where the four reference paddocks land

| Paddock | Community | n px | flood % | observed p05 | predicted | **residual** | in SD |
|---|---|---:|---:|---:|---:|---:|---:|
| Bala 26ca | Riverine | 636 | 13.34 | 26.86 | 44.26 | **−17.41** | −1.44 |
| Bala 26ca | Inland | 32,399 | 45.92 | 71.12 | 70.54 | +0.59 | +0.06 |
| Bala 27ca | Inland | 23,908 | 29.69 | 59.90 | 61.93 | −2.02 | −0.19 |
| Bala 28ca | Aeolian | 10 | 12.86 | 59.99 | 47.80 | +12.19 | +0.99 *small n* |
| Bala 28ca | Riverine | 3,704 | 12.16 | 50.03 | 43.66 | +6.37 | +0.53 |
| Bala 28ca | Inland | 18,272 | 49.68 | 74.92 | 72.53 | +2.39 | +0.22 |
| **Bala 29ca** | **Aeolian** | 11,848 | 2.82 | 46.77 | 45.20 | **+1.57** | +0.13 |
| **Bala 29ca** | **Riverine** | 12,141 | 6.38 | 50.30 | 40.69 | **+9.61** | +0.80 |
| **Bala 29ca** | **Inland** | 12,687 | 15.92 | 55.77 | 54.63 | **+1.15** | +0.11 |

Against the grazed distribution of residuals in the same community:

| Community | grazed residual p05 / median / p95 | n | reference paddocks |
|---|---|---:|---|
| Aeolian | −13.2 / −1.5 / +10.8 | 12 | 29ca **+1.6** |
| Riverine | −7.3 / +1.6 / +15.0 | 32 | 26ca **−17.4** · 28ca +6.4 · 29ca **+9.6** |
| Inland | −9.8 / +0.7 / +8.1 | 57 | 26ca +0.6 · 27ca −2.0 · 28ca +2.4 · 29ca **+1.1** |

---

## The finding

> **Bala 29ca's residual is positive in all three communities: +1.57, +9.61, +1.15.**
> Once you condition on long-run flood frequency within community, **29ca is not
> deficient at all.** Its floor is at or slightly above what its dryness predicts, and
> at or above the grazed median in every community it occupies.

Applying R6's own pre-registered reading: *"If 29ca sits **on** the curve, dryness
accounts for the deficit and there is no reference-state anomaly left to explain."*
**It sits on the curve — marginally above it.** There is no residual left for a
clearing hypothesis to explain, and therefore no residual for the LiDAR structure test
to aim at.

The raw 42 pp reference–grazed gap is a **composition-and-hydrology artefact**: 29ca is
much drier than the paddocks it is grouped with, and it is a three-community mosaic. L-01
predicted exactly this, and this is the cleanest demonstration of L-01 the project has.

### The inversion, which is the uncomfortable part

**The only large negative residual among the four belongs to Bala 26ca: −17.41 pp in
Riverine, −1.44 SD, below the grazed p05 of −7.3.** The paddock the project treated as
well-behaved carries the deficit; the paddock treated as anomalous does not.

Two reasons not to make anything of it yet. Its **n is 636 pixels** — the smallest part
in the table by a factor of five, ~40 ha. And 26ca's Inland part, 51× larger, sits at
+0.59, essentially on the curve. So this is a small, atypical corner of one paddock, and
it is reported because R6 pre-committed to reporting every residual whatever its sign —
not because it supports a conclusion.

### What R6 does not say

It does not say 29ca is undisturbed. A cleared paddock that is also dry would show the
same placement, and R6 cannot separate those. It says only that **its floor is fully
accounted for by its wetness**, so the floor carries no evidence of disturbance.

It does not license a change to the reference set — see below.

---

## Pre-registration hazard — on the record, unchanged

Dropping 29ca from the reference set would **raise the reference floor and narrow the
reference-versus-grazed gap**: a convergence-favourable move made after seeing the data,
on a project that pre-registered specifically to guard against that pressure.

**No change to the reference set is made here.** R6 was pre-registered with that
constraint and it holds. If these residuals argue for a redefinition, it returns to the
design seat as a decision, must be justified on a rule stated **independently of its
effect on the answer**, and **both versions must be reported**.

Note that the honest reading actually cuts the other way from the convenient one: the
paddock with a real negative residual is **26ca**, not 29ca. Any rule written to exclude
"the anomalous reference paddock" would now exclude a different one than the project
expected — which is a good reason to write the rule before looking again, not after.

---

## What this closes

- **T2 Gate E's finding** that the reference set is heterogeneous enough to make
  distance-to-reference undefined as specified now has its **mechanism**: one of the four
  reference paddocks sits in a different hydrological regime, and the group's floor
  differences are wetness differences.
- **The 27 July reference-state finding** — that 29ca's deficit is "substantially
  explained by dryness" — is upgraded from a qualitative reading to a **quantitative
  result with a pre-registered rule and a stated scatter.**
- **U-Q4a's target.** The structure test no longer has a residual to aim at. That is
  reported in the Task U stream, not here.

## Caveats carried

- Aggregation order: paddock-community **means** of both variables are placed on a
  **pixel-level** fit. A part's mean sits on the fit line by construction only if the
  relationship is linear across its internal range; it is close to linear here, but the
  residuals are means-of-parts, not pixel residuals.
- `Bala 28ca / Aeolian` has **n = 10** and is reported, not interpreted.
- The fits are loose (r 0.19–0.66). A residual under ~1 SD is not distinguishable from
  ordinary scatter, and **all four of 29ca's and 27ca's residuals are well under 1 SD.**
  That is the point — they are unremarkable.
