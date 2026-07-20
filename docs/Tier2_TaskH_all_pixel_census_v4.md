# Tier 2 · Task H — all-pixel census (v4)

> ✅ **AUTHORITATIVE — current, committed Task H spec. v1–v3 are superseded.**

> **SUPERSESSION NOTE (2026-07-20).** §4.3.2 and §7 item 8 carry the pre-finalisation 8/1/0 F6 expectation. The census verdict is 9/0/0 — the Riverine-low non-stationary flag was a 40-point sparsity artefact. Where the body reads 8/1/0, read 9/0/0.

*Supersedes v3 → v2 → v1. Follows Adrian's 15 Jul direction (`Gayini_Adrian_comments_20260715.xlsx`) and the sequenced plan (`Gayini_sequential_task_list_20260715.md`). Item numbers (#n) refer to Adrian's table.*

**Gate 1 CLOSED.** **H3.0 COMPLETE and accepted.** **Band definitions decided: option 2.**
**Work resumes at H3.1.** Branch `tier2h-track-a-census`, held. Do not re-branch. Do not merge.

---

## 0. What changed in v4 — read this first

| # | Change | Why |
|---|---|---|
| 1 | **v3's "Aeolian split is a smoothing artefact" framing is WRONG and is withdrawn.** Measured: the committed Aeolian **low band is 100.0% never-flooded**. The ⅓ split landed almost exactly on the never-wet/ever-wet boundary. It is a real, defensible separation. | §3.8.1 |
| 2 | **Gate #11's "label Aeolian's edge as a smoothing artefact" requirement is REMOVED.** It was based on #1. | §7 |
| 3 | **NEW requirement: put frequencies in the legend, not band names.** "never flooded / about 1 year in 35 / about 5 years in 35", per community. | §3.8.2, §7.11 |
| 4 | **NEW finding — the staircase.** Bands are **not comparable across communities** and the numbers are stark: **Aeolian's wettest band (~5 yrs in 35) is wetter than Inland's driest (~3 yrs)**. Riverine mid ≈ Inland low; Riverine high ≈ Inland mid. | §3.8.2 |
| 5 | **NEW: H6 — absolute flood-frequency zones.** Cheap, stable, comparable, plain-language, and it answers the Nari Nari panel problem. Breaks and cross-tab computed. | §4.7 |
| 6 | **v3's other Aeolian claim is CONFIRMED and sharpened:** Aeolian low is **100.0%** never-wet → flat zero series → its F6 "no trend" is **trivially true**. | §3.8.1, §4.3.2 |
| 7 | New established fact: **95.768% of pixels have `valid_count = 35`** — the n/35 step structure holds. | §3.4a |

**The option-2 decision is UNCHANGED.** It rests on the stability argument (§3.7.2), which #1 does not touch.
**v2/v3's §3 established facts are unchanged and still binding.** Nothing in Gate 1 or H3.0 was overturned.

---

## 1. Objective

First cut of the all-pixel (census) approach: replace *sampled* estimates with *every pixel* in each vegetation × wetness class. Deliver the census flood-frequency result (removing the "thinly sampled / provisional" caveat by construction), plus a static total-veg percentile raster and the veg-vs-inundation census analysis.

**Additive only.** Task F code (`gayini_stratum_allocation`, `gayini_draw_monte_carlo`) stays on `main`, uncalled.

## 2. Scope decisions (do not re-litigate)

- **Percentile = across-the-whole-series, ONE value per pixel.** Five rasters: 5/10/20/30/50th of total veg (green + dead).
- **Consequence, accepted:** a static raster cannot feed the lag analysis (#3). Stays on the per-plot method.
- **Canonical CRS = EPSG:8058.**
- **Out of scope:** gauge × RS mixed-effects model (#12) — research only, parked.

---

## 3. Established facts (verified — do not re-derive)

### 3.1 – 3.6 — unchanged from v2/v3

- **§3.1 FC source.** 153 seasonal composites, 30 m, **EPSG:3577 proven from WKT**, nodata **255**, **plain percent — NO +100 offset**, `total_veg = band2 + band3`, `PV+NPV+BS` ≈ 98.5 (median 99). 1987-12 → 2026-02.
- **§3.2 Geometry.** Farm **85,910.8 ha** · mapped **67,349.332 ha** (78.39%) · unmapped **21.61%** · census **1,080,157 px** · pixel **24.970268 m** / **0.0623514 ha**. FC covers **100.0000%** of the farm. Grid 4037 × 2422, origin (5.264715, 0.749231).
- **§3.3 The bridge.** `freq` computed in 28355 → `project(…, "bilinear")` to 8058 (`gayini_stratified_sampling_functions.R:96`). `veg_regime_class_8058.tif`, `census_stratum`, `regime_band_breaks.csv` all descend from that one surface → `diff = 0` between them is shared construction, never evidence.
- **§3.4 The stack.** `wet ∈ {0,1,255}`, `valid ∈ {1,255}` — **no zero**. `wet ⊆ valid` exact. `valid_count` 22–35.
- **§3.5 `MIN_VALID_YEARS = 25` is NON-BINDING** — drops 2,418 px = **0.025%**.
- **§3.6 Seven CRSs** — 8058 · 28355 · 3577 · 9473 · 7854 · 4283 · 4326.

### 3.4a NEW — the n/35 structure holds

`valid_count` distribution across observed pixels: **35 yrs = 95.768%** · 33 yrs = 3.339% · 34 yrs = 0.733% · all others < 0.1%.

So `freq` values are overwhelmingly **k/35** (granularity 2.857 pp), with a small tail at k/33 and k/34. This is why NN terciles land exactly on n/35 steps, and why tie plateaus are real (§3.7.2).

### 3.7 The tercile problem (H3.0) — decision stands

#### 3.7.1 What was found

NN preserves the honest discrete measurement. Recomputing terciles on NN reshuffles within-community bands by tens of thousands of pixels (Aeolian low 26,786 → **0**; Inland low 238,328 → 205,332). Per-*community* totals are **+0**.

#### 3.7.2 The decisive failure — instability

The Inland ⅓ break sits on a **tie plateau with a 0.07 pp margin**:

```
Inland — cumulative % at each n/35 step
   5/35 = 14.286%   38,473 px   cum <= step: 28.61%
   6/35 = 17.143%   33,368 px   cum <= step: 33.26%   <- the 1/3 break lands here
   7/35 = 20.000%   34,945 px   cum <= step: 38.13%
```

33.33% falls **inside** that jump. Two computations of the same quantity differing by **138 px (0.019%)** produced breaks of 6/35 vs 7/35 and low-band sizes of **205,364 vs 238,732 px (14% swing)**.

> **A 0.02% change in input → a 14% change in stratum membership. Quantile bands on discrete n/35 data are not reproducible.** This is why option 2 was chosen, and it is unaffected by §3.8.1.

#### 3.7.3 The decision — option 2 (decouple)

**Band definitions:** F5 `regime_band_breaks.csv` edges. **All flood-frequency arithmetic:** NN stack.

Fixed CSV edges are reproducible; NN quantiles wobble by whole 2.86 pp steps. Option 2 is also the only option that leaves H3.2's 8/1/0 expectation testable (§4.3.2). Options 1 and 3 are recorded in §9; option 3 is the proper long-run fix, gated on Adrian.

### 3.8 NEW — what the committed bands actually contain

#### 3.8.1 The Aeolian bands are REAL — v3's "artefact" claim is withdrawn

Taking the **committed** (bilinear-derived) edges and measuring what sits inside them, on NN:

| Aeolian band | n | NN never-wet | NN mean freq |
|---|---:|---:|---:|
| **low** (0.00–0.18%) | 26,864 | **100.0%** | 0.00 |
| mid (0.18–5.71%) | 23,635 | 22.7% | 2.65 |
| high (5.71–76.02%) | 27,046 | 0.1% | 15.12 |

**Aeolian low is 100.0% never-flooded.** The ⅓ split did **not** divide smoothing noise — it landed almost exactly on the never-wet/ever-wet boundary, and structurally so: bilinear leaves *interior* never-wet pixels at zero and smears only those adjacent to wet ground, so "low" = interior never-wet, "mid" = edge never-wet + rarely-wet. **The boundary is meaningful and defensible on a map. Do not caveat it as an artefact.**

**Confirmed and sharpened:** because Aeolian low is **100.0%** never-wet, its annual flood-frequency series is **all zeros for 35 years**, so its F6 "no trend" verdict is **trivially true — a flat zero series cannot trend.** Report it as a vacuous verdict, not as evidence (§4.3.2).

#### 3.8.2 The real hazard — the staircase

Band means converted to years-in-35:

| | low | mid | high |
|---|---|---|---|
| **Aeolian** | never | ~1 yr | **~5 yrs** |
| **Riverine** | ~1 yr | **~3 yrs** | **~10 yrs** |
| **Inland** | **~3 yrs** | **~10 yrs** | ~17 yrs |

**Riverine mid ≈ Inland low (~3 yrs). Riverine high ≈ Inland mid (~10 yrs). Aeolian's wettest band (~5 yrs) is wetter than Inland's driest (~3 yrs).**

On a 9-colour bivariate map, *"darker = wetter"* is true **within** each community and **false across the map**. A dark-gold Aeolian paddock floods more often than a pale-blue Inland one. The standing rule *never compare band labels across communities* is exactly this — but **a caption cannot enforce it against a map read at a glance.**

**Requirement (§7.11):** put the **frequencies in the legend, not the band names** — "never flooded / about 1 year in 35 / about 5 years in 35", per community. The incomparability then renders *on the figure* instead of living in a caveat, and the staircase becomes visible rather than hidden.

**The staircase is itself a result** — three communities offset by roughly one band each is the cleanest expression of the dry→wet gradient, i.e. paper question **B1**. Surface it; don't treat it as a legend problem.

---

## 4. Work

### 4.1 H1 · Quick wins — status

| Item | Status |
|---|---|
| Dashboard label #21 → "Total veg (green + dead)" | ✅ done |
| `CLAUDE.md:56` dangling ref | ⚠️ **half done** — points into a gitignored dir |
| Archive Task F specs | ⚠️ **blocked by gitignore** (C9) |
| Reconcile `scripts/_deprecated/` | ❌ **DROPPED — B5, deferred to Adrian** |

**C9 — `docs/archive/` is gitignored (`.gitignore:37`). Un-ignore it.** The `CLAUDE.md:56` fix points into an ignored directory, so **from a fresh clone it still dangles** — the reference was relocated, not fixed. Repo docs **are** the memory system (Claude Code has no cross-session memory); a gitignored archive is not memory. Add `!docs/archive/`; commit `Tier1_TaskF_spatial_resampling_spec_v2.md` and `Gayini_subsampling_approach.md` (both headered); then remove the `docs/` root duplicates. Task F **code** untouched.

**`scripts/_deprecated/` — DROPPED from Task H.** This is **B5** (Task F §9: deferred, "a human call with Adrian"), discretionary hygiene, and it collides with a real contradiction: the smoke test hard-fails if `scripts/archive/` exists (`run_spine_smoke_test.R:104-112`, `folder_scripts/archive_absent`) while `CLAUDE.md:44` instructs archived scripts *into* `scripts/archive/`. **Leave it untouched. Do not modify the smoke test.** Log the contradiction in **CLAUDE.md** under known tooling conflicts. Resolve with Adrian post-presentation.

### 4.2 H2 · Total-veg percentile rasters (#6, #7)

Source and encoding settled (§3.1).

- **Compute at native 30 m in EPSG:3577** — `total_veg = band2 + band3`, nodata 255 excluded → 5 rasters (5/10/20/30/50th). **Then** reproject only those 5 to the 8058 grid.
  - **Bilinear IS appropriate here** (continuous cover %). This is the **opposite** of the H3.0 rule. Keep the two rules distinct.
- **Clip the pool to WY1988–WY2023**; state the window and **n retained**. Full-span variant secondary and clearly labelled.
- **Resolution caveat:** natively 30 m, reported on a 24.97 m grid. Do not over-interpret fine detail.
- **Assert `terra::compareGeom()`** against `veg_regime_class_8058.tif` before any zonal join.
- **Register in `raster_asset`** — schema adequate; populate, don't alter.
- **Rationale for the code header (#7):** lower percentiles are the **floor** of the system — "when the veg is really struggling, if there's still something left, that's a sign of a healthy ecosystem". **Resilience, not average condition.**

### 4.3 H3 · Track A — census inundation (#1, #2, #24)

#### 4.3.0 H3.0 — COMPLETE AND ACCEPTED (do not redo)

`scripts/03_inundation_products/11_reproject_annual_stack_8058_nn.R`.

| Check | Result |
|---|---|
| `compareGeom()` vs `veg_regime_class_8058.tif` | **TRUE** both layers |
| Legal value set | `wet ⊆ {0,1}`, **`valid ⊆ {1}`**, **255 absent from both** (nodata → NA) |
| Footprint NN vs bilinear | 9,754,250 = 9,754,250 → **+0** |
| Per-community px vs **committed** `census_stratum` | **+0 for all 5** (77,544 · 193,658 · 717,629 · 86,375 · 4,951 = 1,080,157) |
| Frequency delta | mean **−0.0000 pp**, median 0, sd 1.207, 16.9% >1 pp, 1.0% >5 pp |
| n/35 signature | confirmed |

Products registered as `product='annual_inundation_stack_8058'`, `crs_epsg=8058`, checksums populated, `legend_status='confirmed'`. **Post-build mutation — re-run after any full DB rebuild.**

`veg_regime_class_8058.tif`, `census_stratum`, `regime_band_breaks.csv` untouched — and under option 2 they **stay canonical**.

#### 4.3.1 H3.1 (#1) · Census veg × wetness matrix (p18)

Annual flood frequency per class, every pixel, per year, **computed on the NN 8058 stack**, partitioned by the **F5 `regime_band_breaks.csv` edges**. Headline: **`100 × wet-valid-years ÷ valid-years`**. Wet-rule via the neutral file.

> The neutral wet-rule (`wet ∈ {1,2}`, `mask = 3`) describes the **per-scene** product; the annual stack consumed here is already collapsed to §3.4's binary form. Do not conflate the value sets.

#### 4.3.2 H3.2 (#2) · F6 re-run on the census

**F6 tests the NINE STRATA, not the four communities.** The gate result is 8 no-trend / 1 non-stationary / 0 directional = **nine verdicts**, and the single non-stationary case is **Riverine Chenopod low band** (which loses 5,795 px under NN bands). **The band decision is the F6 decision:**

| Option | Effect on H3.2 |
|---|---|
| 1 — accept NN bands | Aeolian low empty → 8 strata → the 8/1/0 comparison **impossible** |
| 3 — redefine | strata change composition → **signal indistinguishable from re-stratification** |
| **2 — decouple** | **strata identical**; only freq inside them changes (mean Δ ≈ 0) → **reproduces cleanly** |

Same robust test as the shut gate (Theil–Sen + Mann–Kendall, LOESS shape, drop-two-floods). Adrian's framing: **systematic vs stochastic**.

**Expectation:** a census removes *spatial* sampling uncertainty and adds **zero temporal power** — this is a question about 35 annual observations regardless of pixel count. Expect the verdict to **harden to 8/1/0** with the "thinly sampled" caveat gone. **That is the win.** **If the verdict changes, STOP and report — do not continue to H3.3.**

**Also report:** Aeolian low is 100.0% never-wet (§3.8.1) → flat zero series → its "no trend" is **trivially true**. State it as vacuous rather than counting it as evidence.

#### 4.3.3 H3.3 (#24) · Per-year cut

Each year rather than only whole-record aggregates. Cheap; likely informative given the episodic signal.

#### 4.3.4 `MIN_VALID_YEARS`

Census knob is **`MIN_VALID_YEARS = 25/35`** (C4). Sensitivity line, supplied verbatim: *"the threshold is non-binding; at 25/35 it removes 0.025% of observed pixels (2,418 of 9,756,630); valid_count ranges 22–35, so any threshold ≤22 is inert."* Leave `MIN_VALID_COVERAGE = 40` untouched in the extraction path. Neither formally signed off — flag for Adrian.

### 4.4 H4 · Census veg vs inundation (#8)

Per pixel: **static veg floor** (chosen percentile) vs **flood frequency**, all valid pixels, grouped by veg × wetness class. Report per-class relationship strength. Static analogue of F7 — **do not present it as the lag result**.

### 4.5 H5 · Census display convention (#18) — blocks every census figure

- No raw points at scale: **kernel-density / hex-bin surface and/or a CI band around the trend**.
- Existing sqrt-x scatter (α ≈ 0.1 + binned mean ± 95% CI) is already halfway there. **Keep the plot-scale version; add** a census variant swapping points for hexbin/2-D density at ~1.08M points.
- **Never a naive large-N CI.** 1,080,157 pixels are not 1,080,157 independent observations — the surface is spatially autocorrelated. *(Inherited verbatim from the archived sub-sampling note §3; applies with more force to a census.)*
- Adrian has examples from his own work — request them.

### 4.6 Infrastructure (#11) — DECIDED

**Parquet** for the wide per-pixel census (~1.08M rows × ~10 cols), outside the relational DB, registered as an asset. Track A needs no giant table — raster zonal stats. Rejected: CSV; per-pixel-per-year long SQLite.

### 4.7 H6 · NEW — absolute flood-frequency zones

**Why it's here:** §3.8.2 shows the relative bands cannot be read across communities, and a Nari Nari review panel is precisely a cross-community read. *"This country floods about one year in three"* is checkable against knowledge; *"this is the wet third of its vegetation type"* is a statistical construct about a distribution that nobody holds knowledge of. Asking people to validate the latter misuses their expertise. This product is already on the roadmap ("static flood-zone products — classified absolute frequency zones × vegetation communities").

**Cost: low.** It is a reclassify of the NN freq surface plus a zonal cross-tab. Compute it in Track A.

**Class breaks — FIXED CONSTANTS, not quantiles:**

| Zone | Rule | Plain language |
|---|---|---|
| **Z0** | `freq == 0` | never flooded |
| **Z1** | `0 < freq < 10` | rarely — less than about 1 year in 10 |
| **Z2** | `10 <= freq < 25` | occasionally — about 1 year in 10 to 1 in 4 |
| **Z3** | `25 <= freq < 50` | regularly — about 1 year in 4 to 1 in 2 |
| **Z4** | `freq >= 50` | frequently — more than 1 year in 2 |

**Stability — the point of the whole exercise.** The breaks are **fixed constants that cannot move**, unlike a data-derived quantile. Measured: **zero pixels sit exactly on 10%, 25% or 50%**, so classification is unambiguous. State the `<` / `<=` convention in code anyway; k/33 and k/34 values (§3.4a) could in principle land on a break in a future rebuild.

**Expected cross-tab — zones × community, % within community (verify against this):**

| Community | Z0 never | Z1 rarely | Z2 occasionally | Z3 regularly | Z4 frequently |
|---|---:|---:|---:|---:|---:|
| Aeolian Chenopod | **41.6** | 36.7 | 17.4 | 3.6 | 0.7 |
| Riverine Chenopod | 14.0 | 38.6 | 28.7 | 18.1 | 0.7 |
| Inland Floodplain | 2.7 | 15.2 | 25.4 | **46.6** | 10.1 |
| Floodplain Woodland *(context)* | 0.6 | 17.1 | 16.8 | 44.4 | **21.1** |

Farm-wide (mapped area): Z0 **7.4%** · Z1 **21.1%** · Z2 **24.7%** · Z3 **38.2%** · Z4 **8.6%**.

**This is the dry→wet gradient (B1) in its cleanest form** — a monotonic shift of mass left-to-right, comparable across communities because the breaks are shared. Note Floodplain Woodland is the *wettest* unit (21.1% frequently) despite being context-only in the analysis.

**Deliverables (this task):** the 5-class raster on the 8058 grid, registered in `raster_asset`; the zones × community cross-tab as a small results table; the farm-wide roll-up. **Panel design is NOT in scope here** — rendering for Nari Nari is a separate piece of work.

**Rendering note for later:** because absolute zones are comparable across communities, they do **not** need a bivariate map. A single 5-class sequential blue map (`gayini_flood_frequency_ramp()`) answers "how often does this country flood", with vegetation as outlines or a separate panel. That is far more legible than a 20-cell bivariate legend.

---

## 5. Numbers to propagate

- Census pixels **1,080,157** (focus strata **988,831**). **Not ~240k**.
- Farm **85,910.8 ha** · mapped **67,349.332 ha** · unmapped **18,561.4 ha (21.61%)**.
- Census pixel **24.970268 m** / **0.0623514 ha**. The 28355 stack **is** 25.0 m.
- **Aeolian never-wet: 41.59%.** **Aeolian low band: 100.0% never-wet.**
- **`valid_count = 35` for 95.768% of pixels.**
- FC: 153 composites, 1987-12 → 2026-02; clip to WY1988–WY2023, report n retained.

## 6. Corrections (binding)

| # | Object | Sev | Action |
|---|---|---|---|
| **C1** | `census_stratum.farm_area_ha` | **HIGH** | **MISNOMER** — holds the *mapped* 67,349.332 ha, not the farm's **85,910.8 ha**. Add `mapped_area_ha` + `farm_area_total_ha`; deprecate the label. **Additive. Audit any existing "% of farm" claim sourced from it.** |
| **C2** | `veg_regime_class_8058.tif` | **HIGH** | **NOT REGISTERED.** Register it, the 5 percentile rasters, the H6 zone raster; confirm the NN stack rows. *(= Task F §9's deferred "B7".)* |
| **C3** | 153 FC rasters | MED | **NOT REGISTERED.** Register with §3.1 legend semantics; `legend_status = confirmed`. |
| **C4** | `MIN_VALID_COVERAGE` vs `MIN_VALID_YEARS` | **HIGH** | Two knobs. Census knob = `MIN_VALID_YEARS = 25/35`. §4.3.4. |
| **C5** | Data dictionary `metrics` sheet | MED | **STALE** — 39 vs 43. Regenerate at end of Task H. `Gayini_analysis_variable_LUT_20260715.xlsx` supersedes meanwhile. |
| **C6** | "25 m" pixel | LOW | Census pixel is **24.970268 m**. Reserve "25 m" for the 28355 stack. |
| **C7** | FC catalogue metadata | LOW | **DRIFT** — nodata **is** set (255); `legend_status` still "needs_check" ×153; series runs to 2026-02. Refresh from files. |
| **C8** | `inundation_annual_occurrence_pct` | MED | **NAME TRAP** — within-year area metric, not the headline. LUT: *LIVE — SECONDARY (never headline)*. |
| **C9** | **`docs/archive/` gitignored** | **HIGH** | Add `!docs/archive/`; commit both Task F docs; remove `docs/` root duplicates. §4.1. |

---

## 7. Acceptance gate

1. ~~Gate 1 recon.~~ **CLOSED.**
2. **Everything analytical is EPSG:8058**, aligned exactly to the `veg_regime_class_8058.tif` grid — asserted via `compareGeom()`. Originals unmutated; new products registered with crs/extent/checksum populated.
2a. ~~Binary stack NN + legal-value assertions.~~ **PASSED at H3.0.**
2b. ~~NN-vs-bilinear delta.~~ **PASSED at H3.0.** `diff = 0` against the old product is **never** accepted as evidence.
2c. **FC percentiles at native 30 m / 3577**, then reprojected once to 8058. `PV+NPV+BS ≈ 100%` asserted. Pool clipped to WY1988–WY2023, **n reported**.
3. Headline = between-year flood frequency; `annual_occurrence_pct` never headline.
4. 4-class `simplified_vegetation_group` only; no `vegetation_adrian_group` / `period` leakage; no pre/post language.
5. Wet-rule sourced from the neutral file.
6. **`MIN_VALID_YEARS = 25` flagged with the §3.5 sensitivity line.** `MIN_VALID_COVERAGE = 40` untouched.
7. No census figure plots raw points at scale (H5); **no naive large-N CI anywhere**.
8. **F6 reported against 8/1/0 across the NINE STRATA** — divergence → STOP and report. Aeolian low's trivially-flat series noted as vacuous.
9. Task F code untouched; **`docs/archive/` un-ignored, both Task F docs committed**, `CLAUDE.md:56` resolves from a fresh clone. **`scripts/_deprecated/` left untouched (B5); smoke test unmodified.**
10. Corrections **C1–C9** actioned or explicitly deferred with reason.
11. **Band definitions = F5 `regime_band_breaks.csv` edges (option 2); all frequency arithmetic on the NN stack.** ~~Aeolian's edge labelled a smoothing artefact~~ — **REMOVED (it is real; §3.8.1).** Instead: **every figure using the relative bands carries the frequencies in the legend, not the band names** (§3.8.2), so cross-community incomparability renders on the figure.
12. **H6 zone raster and cross-tab reconcile to §4.7's expected table**; breaks are fixed constants; `<` / `<=` convention stated.
13. Post-build guard passes; spine validation clean *(the pre-existing `scripts/10_downstream_optional/` smoke failure is unrelated and out of scope)*.
14. Branch-and-PR, **held — do not merge**.

## 8. Handoff

- **STOP and report at the end of Track A** — or immediately on F6 divergence.
- Review bundle → `Output/review_bundles/tier2H_all_pixel_census/`, zipped.
- Change report → `docs/change_reports/tier2H_all_pixel_census_<date>.md` (local). Commit code + small tables only — **never** the census extraction.
- Keep **both** Gate 1 documents: `tier2H_gate1_recon_20260715.md` (provenance, kept as-is despite superseded parts) and `tier2H_gate1_verified_20260715.md` (the authority).

## 9. Open questions (flag; do not guess)

- **Band definitions, round 2 — option 3.** Tie-aware or absolute thresholds are the proper long-run fix for §3.7.2. Option 2 is a first-cut choice made for **stability and F6 comparability**, not a permanent answer. **Gated on Adrian, post-presentation.** H6 (§4.7) is the candidate replacement and is already built by then — the conversation with Adrian is whether the 9-cell relative matrix survives at all, or whether absolute zones × communities becomes the primary structure.
- **Nari Nari panel rendering.** Recommend absolute zones (H6), single 5-class sequential map, plain-language legend. Separate piece of work; not in Task H.
- **Which percentile becomes canonical (#9)?** Compute all five, report which shows the strongest relationship with inundation, **recommend one** — Hugh's decision, then used consistently.
- **Adrian's examples of the density/CI display convention (#18).**
- **C1 blast radius:** does any shipped figure or slide already quote a "% of farm" from `census_stratum.farm_area_ha`? Report; do not fix silently.
- **B5 archive convention** — `scripts/archive/` vs the smoke test's `archive_absent`. Human call with Adrian; logged in CLAUDE.md.

---
*Deliverable 1 (updated database) is the target this task feeds. Site reports (Deliverable 2) are next and largely un-gated — do not start them here.*
