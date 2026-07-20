# Tier 2 · Task H — all-pixel census (v3, H3.0 complete, band definitions decided)

> ⚠️ **SUPERSEDED — the authoritative Task H spec is [`Tier2_TaskH_all_pixel_census_v4.md`](Tier2_TaskH_all_pixel_census_v4.md).** Retained for lineage only; do not action. *(D1 fix, 20 Jul 2026.)*

*Supersedes v2 (`Tier2_TaskH_all_pixel_census_v2.md`), which superseded v1. Follows Adrian's 15 Jul direction (`Gayini_Adrian_comments_20260715.xlsx`) and the sequenced plan (`Gayini_sequential_task_list_20260715.md`). Item numbers (#n) refer to Adrian's table.*

**Gate 1 CLOSED** (`docs/change_reports/tier2H_gate1_verified_20260715.md`).
**H1 done** except the archive commit (§4.1). **H3.0 COMPLETE and accepted** — branch `tier2h-track-a-census`, held.
**Work resumes at H3.1.** Branch-and-PR, held. Do not merge.

---

## 0. What changed in v3 — read this first

| # | Change | Why |
|---|---|---|
| 1 | **BAND DEFINITIONS DECIDED: option 2 (decouple).** Keep the F5 `regime_band_breaks.csv` tercile edges as band definitions; compute **all** flood-frequency arithmetic on the NN stack. | H3.0 found NN quantile bands are **not reproducible**. §3.7. |
| 2 | **v2's expected per-band counts were WRONG and are withdrawn.** v2 said per-band counts "stay ~equal regardless — only pixels within ~1 pp of a break swap band." That was an **inference from the breaks, never measured**. It is false wherever ties exist — which the n/35 signature guarantees. | Claude Code measured it and correctly refused to absorb it. §3.7. |
| 3 | **F6 tests the NINE STRATA, not the four communities.** The H3.0 report's scope claim ("does not touch F6") is wrong. The band decision **is** the F6 decision. | §4.3.2. |
| 4 | **New finding, promoted to a result:** **41.59% of Aeolian Chenopod never flooded once in 35 years.** | §3.7.3 — this is for Adrian and probably a slide. |
| 5 | **New documented limitation: tercile ties.** The Inland ⅓ break sits on a tie plateau with a **0.07 pp margin**; a 0.019% change in the pixel set moves the stratum by 14%. | §3.7.2 — the reason for option 2. |
| 6 | **H3.0 accepted.** All assertions pass; delta matches expectation. | §4.3.0. |
| 7 | **`scripts/_deprecated/` DROPPED from Task H.** It is B5 — a deferred human call with Adrian, discretionary hygiene, and it collides with the smoke test. Gate #9 amended. | §4.1, §7. |
| 8 | **`docs/archive/` must be un-ignored.** The `CLAUDE.md:56` fix currently points into a gitignored directory — **from a fresh clone it still dangles.** | §4.1. |
| 9 | Option 3 (tie-aware / absolute thresholds) flagged as the proper fix for a later round, gated on Adrian. | §9. |

**v2's §3 established facts are unchanged and still binding.** Nothing in Gate 1 was overturned.

---

## 1. Objective

First cut of the all-pixel (census) approach: replace *sampled* estimates with *every pixel* in each vegetation × wetness class. Deliver the census flood-frequency result (which removes the "thinly sampled / provisional" caveat by construction), plus a static total-veg percentile raster and the veg-vs-inundation census analysis.

**Additive only.** Nothing is deleted. Task F code (`gayini_stratum_allocation`, `gayini_draw_monte_carlo`) stays on `main`, uncalled — archived in *emphasis*, not removed.

## 2. Scope decisions (do not re-litigate)

- **Percentile = across-the-whole-series, ONE value per pixel.** Not per-year. Five rasters: 5th / 10th / 20th / 30th / 50th of total veg (green + dead).
- **Consequence, accepted:** a static raster cannot feed the lag analysis (#3). That stays on the per-plot method. A sequencing choice, not a gap.
- **Canonical CRS = EPSG:8058.** All census arithmetic, all new rasters, all products.
- **Out of scope:** the gauge × RS mixed-effects / residual model (#12) — research only, parked.

---

## 3. Established facts (verified — build against these, do not re-derive)

### 3.1 – 3.6 — unchanged from v2

Carried forward verbatim and still binding:

- **§3.1 FC source.** 153 seasonal composites, 30 m, **EPSG:3577 proven from WKT**, nodata **255**, **plain percent — NO +100 offset**, `total_veg = band2 + band3`, `PV+NPV+BS` ≈ 98.5 (median 99). Temporal 1987-12 → 2026-02.
- **§3.2 Geometry.** Farm **85,910.8 ha** · mapped **67,349.332 ha** (78.39%) · unmapped **21.61%** · census **1,080,157 px** · pixel **24.970268 m** / **0.0623514 ha**. FC covers **100.0000%** of the farm (S clearance +2,956 m). Grid: 4037 × 2422, origin (5.264715, 0.749231).
- **§3.3 The bridge.** `freq` computed in 28355 (exact integers) → `project(…, method="bilinear")` to 8058 (`gayini_stratified_sampling_functions.R:96`). `veg_regime_class_8058.tif`, `census_stratum` and `regime_band_breaks.csv` **all descend from that one bilinear surface**, so `diff = 0` between them is shared construction, not evidence.
- **§3.4 The stack.** `wet ∈ {0,1,255}`, `valid ∈ {1,255}` — **no zero**. `wet ⊆ valid` exact. `valid_count` 22–35.
- **§3.5 `MIN_VALID_YEARS = 25` is NON-BINDING** — drops 2,418 px = **0.025%**.
- **§3.6 Seven CRSs** — 8058 canonical · 28355 stack · 3577 FC · 9473 `dim_plot` · 7854 plots · 4283 boundary/veg · 4326 gauges.

### 3.7 NEW — the tercile problem (H3.0 finding)

#### 3.7.1 What was found

NN preserves the honest discrete measurement: `freq` lands **only on n/35 steps** (~2.86 pp granularity), because the measurement genuinely is "how many of ≤35 years were wet". Bilinear smeared those exact values into a continuum. Recomputing terciles on the NN surface **reshuffles the within-community bands by tens of thousands of pixels**:

| Community · band | NN | bilinear (committed) | Δ |
|---|---:|---:|---:|
| **Aeolian · low** | **0** | 26,786 | **−26,786** |
| Aeolian · mid | 47,225 | 23,720 | +23,505 |
| Aeolian · high | 30,319 | 27,038 | +3,281 |
| Riverine · low | 59,986 | 65,781 | −5,795 |
| Inland · low | 205,332 | 238,328 | −32,996 |
| Inland · high | 271,493 | 239,635 | +31,858 |

Per-*community* totals are **+0** (identical). Only the *within-community* split moves.

#### 3.7.2 Two distinct failures — both real

**(a) Aeolian is degenerate.** **41.59% of Aeolian Chenopod pixels are exactly never-wet** (freq = 0 across all 35 years). Since that exceeds ⅓, the ⅓ quantile *is* 0, so the "low" band (`freq < 0`) is **empty by construction** and every never-wet pixel lands in "mid". Bilinear hid this by smearing exact-zeros into a fake 0.001–0.18% continuum — **it was splitting smoothing noise, not signal**.

**(b) Inland is unstable — this is the worse one.** The ⅓ break sits on a **tie plateau with a 0.07 pp margin**:

```
Inland Floodplain — cumulative % at each n/35 step
   5/35 = 14.286%   38,473 px   cum <= step: 28.61%
   6/35 = 17.143%   33,368 px   cum <= step: 33.26%   <- the 1/3 break lands here
   7/35 = 20.000%   34,945 px   cum <= step: 38.13%
```

33.33% falls **inside** the 28.61% → 33.26% → 38.13% jump. Two independent computations of the same quantity, differing by **138 px (0.019%)** in the community mask, produced breaks of **6/35 and 7/35** — and low-band sizes of **205,364 vs 238,732 px (a 14% swing)**.

> **A 0.02% change in input produces a 14% change in stratum membership.** Quantile bands on discrete n/35 data are **not reproducible**. This is the decisive fact.

#### 3.7.3 The Aeolian result — report it, don't bury it

**42% of Aeolian Chenopod never flooded once in 35 years.** The driest community has **no real internal wetness gradient at the low end**; its low/mid split has only ever existed under smoothing.

**Consequence worth stating explicitly:** Aeolian low was *always* effectively a never-wet stratum (committed band = 0.00–0.18%, i.e. ≤ 0.063 wet-years), so **its "no trend" verdict is trivially true** — a flat zero series cannot trend. This is a finding for Adrian and probably a slide, not a nuisance to be worked around.

#### 3.7.4 The decision — option 2 (decouple)

**Band definitions:** keep the F5 `regime_band_breaks.csv` tercile edges. **All flood-frequency arithmetic:** NN stack.

**Reason — stability, not cosmetics.** The F5 edges are fixed numbers in a CSV; NN quantiles wobble by whole 2.86 pp steps on trivial input changes (§3.7.2). Option 2 is the only option yielding reproducible band edges, and (see §4.3.2) the only one that leaves the H3.2 expectation testable.

**Cost, documented not hidden:** the band edges derive from the bilinear surface while the values inside them derive from NN. For Riverine and Inland the edges are serviceable; **for Aeolian the low/mid edge is an artefact and must be labelled as such wherever the 9-cell matrix or checkerboard appears.**

Options **1** (accept NN bands) and **3** (tie-aware/absolute thresholds) are recorded in §9. Option 3 is the proper fix, gated on Adrian, post-presentation.

---

## 4. Work

### 4.1 H1 · Quick wins — status

| Item | Status |
|---|---|
| Dashboard label #21 → "Total veg (green + dead)" | ✅ **done** (`R/gayini_dashboard_panels.R`) |
| `CLAUDE.md:56` dangling ref | ⚠️ **half done** — see below |
| Archive Task F specs | ⚠️ **blocked by gitignore** — see below |
| Reconcile `scripts/_deprecated/` | ❌ **DROPPED from Task H** — see below |

**`docs/archive/` is gitignored (`.gitignore:37`) — un-ignore it.** `CLAUDE.md:56` was repointed at `docs/archive/Gayini_subsampling_approach.md`, **which is gitignored — so from a fresh clone the pointer still dangles.** The broken reference has been *moved*, not fixed. Repo docs **are** the memory system precisely because Claude Code has no cross-session memory; a gitignored archive is not memory.

- Add a `!docs/archive/` negation to `.gitignore`.
- Commit the two headered Task F docs: `Tier1_TaskF_spatial_resampling_spec_v2.md`, `Gayini_subsampling_approach.md`.
- Then remove the duplicate copies at `docs/` root (Hugh placed them; Hugh's call).
- Task F **code** on `main` stays untouched.

**`scripts/_deprecated/` → DROPPED from Task H.** This is **B5**, which the Task F spec §9 already flagged as *deferred, "a human call with Adrian"*, and which the plan classes as discretionary hygiene. It collides with a real tooling contradiction: the spine smoke test hard-fails if `scripts/archive/` exists (`run_spine_smoke_test.R:104-112`, check `folder_scripts/archive_absent`), while `CLAUDE.md:44` instructs archived scripts *into* `scripts/archive/`. **Leave `scripts/_deprecated/` untouched. Do not modify the smoke test.** Log the contradiction in **CLAUDE.md** under known tooling conflicts — CLAUDE.md is the memory mechanism. Resolve with Adrian after the presentation.

### 4.2 H2 · Total-veg percentile rasters (#6, #7)

Source and encoding settled (§3.1) — no band investigation needed.

- **Compute at native 30 m in EPSG:3577**, pooling seasonal composites per pixel: `total_veg = band2 + band3`, nodata 255 excluded → **5 rasters** (5/10/20/30/50th). **Then** reproject only those 5 to the 8058 grid.
  - **Bilinear IS appropriate here** — these are continuous cover percentages. This is the opposite of the H3.0 rule. **Keep the two rules distinct; do not copy one to the other.**
- **Clip the pool to the inundation window (WY1988–WY2023)**; state the window and **n retained**. Full-span variant, if produced, stays secondary and clearly labelled.
- **Resolution caveat:** FC is natively 30 m, reported on a 24.97 m grid. Record it; do not over-interpret fine spatial detail.
- **Assert `terra::compareGeom()`** against `veg_regime_class_8058.tif` before any zonal join.
- **Register in `raster_asset`** — schema is already adequate; **populate, do not alter**.
- **Rationale for the code header (#7):** lower percentiles are the **floor** of the system — "when the veg is really struggling, if there's still something left, that's a sign of a healthy ecosystem". **Resilience, not average condition.**

### 4.3 H3 · Track A — census inundation (#1, #2, #24)

#### 4.3.0 H3.0 — COMPLETE AND ACCEPTED

Script `scripts/03_inundation_products/11_reproject_annual_stack_8058_nn.R`. All assertions pass; all deltas match expectation.

| Check | Result |
|---|---|
| `compareGeom()` vs `veg_regime_class_8058.tif` | **TRUE** both layers |
| Legal value set | `wet ⊆ {0,1}`, **`valid ⊆ {1}`** (no zero), **255 absent from both** — nodata survived as NA |
| Footprint NN vs bilinear | 9,754,250 = 9,754,250 → **+0** |
| Per-community px vs **committed** `census_stratum` | **+0 for all 5** (77,544 · 193,658 · 717,629 · 86,375 · 4,951 = 1,080,157) |
| Frequency value delta | mean **−0.0000 pp**, median 0, sd 1.207, 16.9% >1 pp, 1.0% >5 pp |
| n/35 signature | confirmed (5.714 = 2/35, 17.143 = 6/35, 34.286 = 12/35) |

Products (additive; originals untouched): `annual_{wet,valid}_any_1988_2023_8058.tif` (35 lyr, NN), registered in `raster_asset` as `product='annual_inundation_stack_8058'`, `crs_epsg=8058`, checksums populated, `legend_status='confirmed'`. Registration is a **post-build mutation — re-run after any full DB rebuild.**

**`veg_regime_class_8058.tif`, `census_stratum` and `regime_band_breaks.csv` remain untouched — and under option 2 they stay canonical.**

#### 4.3.1 H3.1 (#1) · Census veg × wetness matrix (p18)

Annual flood frequency per class using **every pixel**, per year, **computed on the NN 8058 stack**, partitioned by the **F5 `regime_band_breaks.csv` edges** (option 2, §3.7.4).

Headline metric unchanged: **`100 × wet-valid-years ÷ valid-years`**. Wet-rule via the neutral `gayini_inundation_wet_rule.R`.

> The neutral wet-rule (`wet ∈ {1,2}`, `mask = 3`) describes the **per-scene** product. The **annual stack** consumed here is already collapsed to the binary form in §3.4. Both are true; do not conflate the value sets.

#### 4.3.2 H3.2 (#2) · F6 re-run on the census

**CORRECTION — F6 tests the NINE STRATA, not the four communities.** The gate result is **8 no-trend / 1 non-stationary / 0 directional** = nine verdicts, and the single non-stationary case is **Riverine Chenopod low band**. The H3.0 report's claim that the band divergence "does not touch F6" is **wrong**: under NN bands, Riverine low loses 5,795 px, so its series would change composition.

**This is why option 2 is load-bearing, not cosmetic:**

| Option | Effect on H3.2 |
|---|---|
| 1 — accept NN bands | Aeolian low empty → **8 strata** → the 8/1/0 comparison is **impossible** |
| 3 — redefine | strata change composition → if the non-stationary flag moves, **signal is indistinguishable from re-stratification** |
| **2 — decouple** | **strata identical**; only freq values inside them change (mean Δ ≈ 0) → **F6 reproduces cleanly against 8/1/0** |

Same robust test as the shut gate (Theil–Sen + Mann–Kendall, LOESS shape, drop-two-floods). Adrian's framing: **systematic vs stochastic**.

**Expectation, state it in the change report:** a census removes *spatial* sampling uncertainty but adds **zero temporal power** — this is a question about 35 annual observations regardless of pixel count. Expect the verdict to **harden to 8 no-trend · 1 non-stationary · 0 directional** (episodic, climate-paced) with the "thinly sampled" caveat gone. **That is the win.** If the verdict *changes*, investigate — do not celebrate.

**Also report:** whether Aeolian low's "no trend" is trivially true (a flat zero series — §3.7.3). It is a real verdict but a vacuous one, and saying so is more honest than counting it as evidence.

#### 4.3.3 H3.3 (#24) · Per-year cut

Analyse each year rather than only whole-record aggregates. Cheap; likely informative given the episodic signal.

#### 4.3.4 `MIN_VALID_YEARS`

The census knob is **`MIN_VALID_YEARS = 25/35`**, not `MIN_VALID_COVERAGE = 40` (correction C4). Sensitivity line, supplied by §3.5: *"the threshold is non-binding; at 25/35 it removes 0.025% of observed pixels (2,418 of 9,756,630); valid_count ranges 22–35, so any threshold ≤22 is inert."* Leave `MIN_VALID_COVERAGE = 40` untouched in the extraction path. Neither was formally signed off — flag both for Adrian.

### 4.4 H4 · Census veg vs inundation (#8)

- Per pixel: **static veg floor** (chosen percentile) vs **flood frequency**, all valid pixels, grouped by veg × wetness class.
- Report per-class relationship strength. Static analogue of F7 — **do not present it as the lag result**.

### 4.5 H5 · Census display convention (#18) — blocks every census figure

- No raw points at scale: **kernel-density / hex-bin surface and/or a CI band around the trend**.
- The existing sqrt-x scatter (α ≈ 0.1 + binned mean ± 95% CI) is already halfway there. **Keep the plot-scale version; add** a census variant swapping the point layer for hexbin/2-D density at ~1.08M points.
- **Never a naive large-N CI.** 1,080,157 pixels are not 1,080,157 independent observations — the surface is spatially autocorrelated. (This argument is inherited verbatim from the archived sub-sampling note §3 and applies with *more* force to a census.)
- Adrian has examples from his own work — request them rather than inventing a convention.

### 4.6 Infrastructure (#11) — DECIDED

**Parquet** for the wide per-pixel census (~1.08M rows × ~10 cols), outside the relational results DB, registered as an asset. Track A needs no giant table — it is raster zonal stats. Rejected: CSV (size/types); per-pixel-per-year long SQLite (~38M rows/var, unnecessary).

---

## 5. Numbers to propagate

- Census pixels **1,080,157** (focus strata **988,831**). **Not ~240k** — v1 was 4.5× low.
- Farm **85,910.8 ha** · mapped **67,349.332 ha** · unmapped **18,561.4 ha (21.61%)**.
- Census pixel **24.970268 m** / **0.0623514 ha**. The 28355 stack **is** 25.0 m.
- **Aeolian never-wet: 41.59%.**
- FC: 153 composites, 1987-12 → 2026-02; clip to WY1988–WY2023, report n retained.

## 6. Corrections (binding — unchanged from v2 unless noted)

| # | Object | Sev | Action |
|---|---|---|---|
| **C1** | `census_stratum.farm_area_ha` | **HIGH** | **MISNOMER** — holds the *mapped* 67,349.332 ha, not the farm's **85,910.8 ha** (78.39%; the missing 21.61% matches the known "~21.6% unmapped"). Add `mapped_area_ha` + `farm_area_total_ha`; deprecate the label. **Additive — do not drop the column. Audit any existing "% of farm" claim sourced from it.** |
| **C2** | `veg_regime_class_8058.tif` | **HIGH** | **NOT REGISTERED.** (`raster_asset` had no 8058 raster at all before H3.0 added the NN stack.) Register it, the 5 percentile rasters, and confirm the NN stack rows. Schema adequate — populate, don't alter. *(Also = Task F §9's deferred "B7".)* |
| **C3** | 153 FC rasters | MED | **NOT REGISTERED.** Register with the §3.1 legend semantics; `legend_status = confirmed`. |
| **C4** | `MIN_VALID_COVERAGE` vs `MIN_VALID_YEARS` | **HIGH** | Two knobs. Census knob = `MIN_VALID_YEARS = 25/35`. See §4.3.4. |
| **C5** | Data dictionary `metrics` sheet | MED | **STALE** — 39 rows vs `dim_metric` 43 live. Regenerate at end of Task H. `Gayini_analysis_variable_LUT_20260715.xlsx` supersedes it meanwhile. |
| **C6** | "25 m" pixel | LOW | Census pixel is **24.970268 m**. Reserve "25 m" for the 28355 stack. |
| **C7** | FC catalogue metadata | LOW | **DRIFT** — nodata **is** set (255); `legend_status` still "needs_check" ×153; series runs to 2026-02, not 2025-12. Refresh from the files. |
| **C8** | `inundation_annual_occurrence_pct` | MED | **NAME TRAP** — within-year area metric, not the headline. LUT status: *LIVE — SECONDARY (never headline)*. |
| **C9** | **`docs/archive/` gitignored** | **HIGH** | **NEW.** The `CLAUDE.md:56` fix points into a gitignored dir — still dangles from a fresh clone. Add `!docs/archive/`; commit both Task F docs; remove `docs/` root duplicates. |

---

## 7. Acceptance gate

1. ~~Gate 1 recon.~~ **CLOSED.**
2. **Everything analytical is EPSG:8058**, aligned exactly to the `veg_regime_class_8058.tif` grid — asserted via `compareGeom()`. Originals unmutated; new products registered in `raster_asset` with crs/extent/checksum populated.
2a. ~~Binary stack NN + legal-value assertions.~~ **PASSED at H3.0.**
2b. ~~NN-vs-bilinear delta reported.~~ **PASSED at H3.0.** `diff = 0` against the old product is **never** accepted as evidence (shared construction).
2c. **FC percentiles computed at native 30 m / 3577**, then reprojected once to 8058 — not the reverse. `PV+NPV+BS ≈ 100%` asserted in code. Pool clipped to WY1988–WY2023, **n reported**.
3. Headline = between-year flood frequency; `annual_occurrence_pct` never presented as headline.
4. 4-class `simplified_vegetation_group` only; no `vegetation_adrian_group` / `period` leakage; no pre/post language.
5. Wet-rule sourced from the neutral file.
6. **`MIN_VALID_YEARS = 25` flagged with the §3.5 one-line sensitivity note.** `MIN_VALID_COVERAGE = 40` untouched.
7. No census figure plots raw points at scale (H5); **no naive large-N CI anywhere**.
8. **F6 census verdict reported against the expected 8/1/0 across the NINE STRATA** — divergence investigated, not celebrated. Aeolian low's trivially-flat series noted.
9. Task F code untouched on `main`; **`docs/archive/` un-ignored and both Task F docs committed** with superseded-by headers; `CLAUDE.md:56` resolves from a fresh clone. ~~`scripts/_deprecated/` reconciled~~ — **DROPPED (B5, deferred to Adrian); leave untouched, do not modify the smoke test.**
10. Corrections **C1–C9** actioned or explicitly deferred with reason.
11. **Band definitions are the F5 `regime_band_breaks.csv` edges (option 2); all frequency arithmetic on the NN stack.** Aeolian's low/mid edge labelled as a smoothing artefact wherever the 9-cell matrix or checkerboard appears.
12. Post-build guard (`gayini_assert_post_build_objects()`) passes; spine validation clean *(the pre-existing `scripts/10_downstream_optional/` smoke failure is unrelated to Task H and out of scope)*.
13. Branch-and-PR, **held — do not merge**.

## 8. Handoff

- Review bundle → `Output/review_bundles/tier2H_all_pixel_census/`, zipped.
- Change report → `docs/change_reports/tier2H_all_pixel_census_<date>.md` (local). Commit code + small tables only — **never** the census extraction.
- Keep **both** Gate 1 documents: `tier2H_gate1_recon_20260715.md` (Claude Code's recon, provenance — kept as-is despite superseded parts) and `tier2H_gate1_verified_20260715.md` (the authority). Additive.

## 9. Open questions (flag; do not guess)

- **Band definitions, round 2 — option 3.** Tie-aware or absolute thresholds are the *proper* fix for §3.7. Option 2 is a first-cut choice made for stability and F6 comparability, not a permanent answer. **Gated on Adrian; post-presentation.** Framing for him: the driest community has no real internal wetness gradient — 42% of it never floods — so a within-community tercile is the wrong instrument there. Absolute flood-frequency zones (already on the roadmap as "static flood-zone products") may be the better device.
- **Which percentile becomes canonical (#9)?** Compute all five, report which shows the strongest relationship with inundation, **recommend one** — Hugh's decision, then used consistently everywhere.
- **Adrian's examples of the density/CI display convention (#18).**
- **C1 blast radius:** does any shipped figure or slide already quote a "% of farm" from `census_stratum.farm_area_ha`? Report; do not fix silently.
- **`MIN_VALID_YEARS` / `MIN_VALID_COVERAGE`** — neither formally signed off. Now a philosophy choice, not a constraint (§3.5).
- **B5 archive convention** — `scripts/archive/` vs the smoke test's `archive_absent` check. Human call with Adrian; log in CLAUDE.md, resolve after the presentation.

---
*Deliverable 1 (updated database) is the target this task feeds. Site reports (Deliverable 2) are the next task and are largely un-gated — do not start them here.*
