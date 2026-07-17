<!--
SUPERSEDED-BY: Gayini_sequential_task_list_20260715.md
               Tier2_TaskH_all_pixel_census_v2.md (the work that replaced this)
STATUS:        CANCELLED — not gated, not deferred. The production run never fired.
ARCHIVED:      2026-07-15
-->

# ARCHIVED — Tier 1 Task F production run was CANCELLED, not gated

> **Read this header before using anything below.**
>
> **What happened.** This spec was written to fire a ~100-draw proportional-with-floor Monte Carlo
> resampling run once Adrian signed off Q1 / Q3a / Q3b at the Wednesday sync. **That sync never
> reached those questions.** Adrian's review of **15 July 2026** (`Gayini_Adrian_comments_20260715.xlsx`,
> item #1) pivoted the project from *sampling* to an **all-pixel census**: use every pixel in each
> vegetation × wetness class, not a sample of them. The run below was therefore **cancelled outright**,
> and **Q1 / Q3a / Q3b were bypassed rather than answered**. Do not treat them as open questions
> awaiting a decision — the decision that mattered removed the need for them.
>
> **What replaced it.** `Tier2_TaskH_all_pixel_census_v2.md`. The census reaches the same goal —
> lifting the *"wettest, largest areas thinly sampled — provisional"* caveat — but does it **by
> construction** rather than by quantifying spatial-sampling uncertainty. There is no sampling
> uncertainty to quantify when every pixel is measured.
>
> **What is still live and must not be touched.** The Task F **code remains on `main`, uncalled**:
> `gayini_stratum_allocation()` (`R/gayini_sampling_allocation.R`) and `gayini_draw_monte_carlo()`
> (`R/gayini_monte_carlo_sampling.R`), plus the `allocation=` / `id_prefix=` params on
> `gayini_stratified_sampling_functions.R`. It is built, unit-tested and smoke-proven (5-draw, 8/8).
> **Archiving is a matter of emphasis, not deletion** — this is the standing additive-only rule.
> If a future question genuinely needs a *sample* rather than a census, the engine is ready and this
> spec is how you drive it.
>
> **What survived the pivot intellectually.** §1's core argument — *more spatial points add spatial
> representativeness, not temporal power; expect F6 to harden to 8 no-trend / 1 non-stationary /
> 0 directional, not overturn* — **carried straight through to Task H** and is stated in its H3.2.
> The reasoning was always about the 35-year record, and a census does not lengthen it either.
>
> **What has since been resolved or overtaken (do not action from §9 below):**
>
> | Item in this spec | Current status |
> |---|---|
> | §4 Q1 (near-plot 2 km vs community-wide) | **Bypassed.** No draw universe exists in a census. |
> | §4 Q3a (`MIN_VALID_COVERAGE = 40`) | **Reframed.** Task H established these are **two different knobs**: the census knob is `MIN_VALID_YEARS = 25/35`, and it is **non-binding** (drops 0.025%; `valid_count` ranges 22–35). `MIN_VALID_COVERAGE = 40` stays in the plot-extraction path. Neither was ever formally signed off. |
> | §4 Q3b (F9 retirement) | Framing/deliverables question; unaffected by this cancellation. Still Adrian's call. |
> | §9 CLAUDE.md post-build ordering wrong | **FIXED.** Corrected on `main`. |
> | §9 B7 — register the F5/F6 rasters in `raster_asset` | **Still outstanding**, now carried as Task H **correction C2**. Verified 15 Jul: `veg_regime_class_8058.tif` is *not* registered, and `raster_asset` contains **no 8058 raster at all**. |
> | §9 B5 archive convention | `scripts/_deprecated/` still present; carried into Task H H1. |
> | §3 headroom table (12–76× clearance) | Still accurate, still moot — headroom only constrains draws, and there are no draws. |
>
> **One correction to a number below.** §3 and the density table cite `census_stratum` counts that
> remain correct (988,831 focus-strata pixels; 1,080,157 including context). But note Task H
> correction **C1**: `census_stratum.farm_area_ha` (67,349.332 ha) is a **misnomer** — it holds the
> *mapped* area, not the farm. The true farm is **85,910.8 ha**. Any "% of farm" reasoning built on
> that field understates the denominator by ~21.6%.
>
> ---
>
> *Everything below is the original document, preserved verbatim for provenance.*

---

# Tier 1 · Task F — Spatial Resampling: production-run spec (v2)

*Supersedes the pre-audit v1. This is the **Wednesday production-run** spec: the mechanics are already built and smoke-proven, and the foundation is merged. After Adrian signs off Q1/Q3a/Q3b, this run is a **parameter flip, not new code**. Design-and-review authored; Claude Code executes; **hold at the acceptance gate — branch-and-PR, human-reviewed. Do not merge; do not fire the 100-draw run before the Wednesday sync.***

---

## 0. What changed since v1 (fold these in)

- **Headroom resolved — Q1 is no longer a feasibility gate.** The audit's near-plot recount (reconciled to `census_stratum`, diff = 0) shows every stratum has **12–76× more valid pixels within 2 km than any target draw needs** (tightest: Inland·low at 31× under Scheme A). The `clip(…, H_s)` cap is retained defensively but is **confirmed inert under both Q1 options**. Q1 is now a design-philosophy choice (near-plot vs community-wide), not a constraint on reachable draw sizes.
- **Census verified live.** `census_stratum` = 11 rows (9 analytical + 2 context); per-band pixel counts confirmed against the shipped DB. Allocation below uses these live counts.
- **Mechanics built (B1/B2), foundation merged (B3/B4/B6).** See §2. This spec no longer asks Claude Code to build the engine — it asks it to take the engine from smoke → production with the locked allocation.

## 1. Objective (unchanged)

Replace the provisional flat-40 sample with **proportional-with-floor, ~100-draw Monte-Carlo** stratified sampling, then re-run F6. Purpose: lift the *"wettest, largest areas thinly sampled — provisional"* caveat by giving the wet strata sampling density proportional to their extent, and report honest **spatial-sampling uncertainty**.

**Not a trend hunt.** More spatial points add **spatial representativeness, not temporal power** — trend detection is bounded by the 35-year record. Expected outcome is the F6 verdicts **hardened**, not overturned: **8 no-trend · 1 non-stationary · 0 directional**. No change to the headline metric, the strata, the wet-rule, or the gate logic.

## 2. Starting point (already in the repo)

| Component | State | Location |
|---|---|---|
| Post-build guard (B4), spine validation, `demo_spine.R` | **Merged to `main`** (`05c28ff`), validated green | `R/gayini_db_validation.R`, `run_db_validation.R`, `demo_spine.R` |
| B3 (allocation-aware census gate), B6 (neutral wet-rule file) | **Merged to `main`** | `scripts/…/09_build_pixel_census_view.R`, `R/gayini_inundation_wet_rule.R` |
| Per-stratum allocation (B1) | Built, unit-tested, **held** | `R/gayini_sampling_allocation.R` → `gayini_stratum_allocation()` |
| Seeded Monte-Carlo loop + per-draw F6 (B2) | Built, smoke-proven (5-draw, 8/8), **held** | `R/gayini_monte_carlo_sampling.R` → `gayini_draw_monte_carlo()`, `gayini_f6_verdicts_for_points()` |
| Draw fn `allocation=` / `id_prefix=` params | Built, backward-compatible, **held** | `R/gayini_stratified_sampling_functions.R` |
| Smoke script (throwaway budget=90) | Held | `scripts/…/13_run_sampling_rebalance_smoke.R` |

Branch `feature/tier1f-rebalance-mechanics` carries the held items. The production run promotes the smoke script (or a sibling `14_run_sampling_rebalance_production.R`) with the locked allocation below.

## 3. Locked allocation — Scheme A (Inland-anchored)

Confirmed 13 Jul 2026. **Derived, never hardcoded** — feed these parameters to `gayini_stratum_allocation()` and verify the output matches the expected `target_n` table.

**Parameters:** `method = "proportional"`, `min_n = 50` (floor), `budget = 4149` (chosen so the Inland bands land ≈ 1,000/draw), `max_n =` near-plot headroom `H_s` (defensive cap; non-binding).

**Expected per-stratum `target_n` (live census, largest-remainder rounding → sums to budget):**

| Community | band | n_pixels (census) | near-plot pool (2 km) | **target_n /draw** | headroom × |
|---|---|---:|---:|---:|---:|
| Aeolian Chenopod | low | 26,786 | 16,751 | **112** | 150× |
| Aeolian Chenopod | mid | 23,720 | 12,086 | **100** | 121× |
| Aeolian Chenopod | high | 27,038 | 18,002 | **113** | 159× |
| Riverine Chenopod | low | 65,781 | 34,163 | **276** | 124× |
| Riverine Chenopod | mid | 64,326 | 24,576 | **270** | 91× |
| Riverine Chenopod | high | 63,551 | 19,293 | **267** | 72× |
| Inland Floodplain | low | 238,328 | 31,186 | **1,000** | 31× |
| Inland Floodplain | mid | 239,666 | 61,039 | **1,006** | 61× |
| Inland Floodplain | high | 239,635 | 76,385 | **1,005** | 76× |
| **Total /draw** | | **988,831** | | **4,149** | |

**~4,149 pts/draw × 100 draws ≈ 415k point-draws.** Floor (`min_n=50`) is inert (smallest target = 100). Cap (`H_s`) is inert (tightest headroom 31×). Both are carried as guards, not active constraints — assert they didn't bind and flag if they ever do.

*If Adrian selects community-wide at Q1, `H_s` becomes the full census count (even larger) — allocation is unchanged; only the draw universe widens.*

## 4. Wednesday parameters

Two come from Adrian; the rest are locked.

| Param | Value | Source |
|---|---|---|
| **Q1 — draw neighbourhood** | default **2 km near-plot**; alt = community-wide | **Adrian** (design choice; either is a one-param change) |
| **Q3a — `MIN_VALID_COVERAGE`** | default **40** | **Adrian** (confirm or adjust) |
| Q3b — F9 retirement | ship static F5 surface as flood-probability product | **Adrian** sign-off (affects framing/deliverables, not this run) |
| Allocation | Scheme A params (§3) | **locked** |
| `n_draws` | **100** | locked |
| `SEED` | recorded, deterministic (e.g. `20260715`) | locked |
| CRS | extract 28355 · centroids from 9473 · map 8058 | locked |

## 5. Method (production run)

1. **Pre-flight:** call `gayini_assert_post_build_objects()` and `gayini_validate_spine()` — abort if either fails. (Guard already asserts `raster_asset`/stack/`census_stratum`/spine; this is the B4 gate doing its job.)
2. **Allocate:** `gayini_stratum_allocation()` with the §3 params; assert output == expected `target_n` table and that neither floor nor cap bound.
3. **Draw ~100×:** `gayini_draw_monte_carlo()` under the recorded `SEED`, `id_prefix` per seed (`SP_<seed>_####`), per-seed output fan-out. Draw within the Q1 neighbourhood, footprints + 100 m excluded, in the raster CRS (28355).
4. **Per-draw F6:** `gayini_f6_verdicts_for_points()` — same robust test as the shut gate (Theil–Sen + Mann–Kendall τ, LOESS shape, drop-two-floods episodic check). Recommended addition: block-bootstrap MK (`modifiedmk`) to preserve serial dependence.
5. **Across-draw summary (the deliverable core):** per stratum — median per-year flood-frequency series + **percentile band (10/25/50/75/90)**; F6 verdict as **modal verdict + fraction of draws supporting it**; Theil–Sen slope and τ as across-draw medians with percentile intervals. Give **Riverine·low** (the non-stationary flag) explicit attention: report whether the flag is **stable across draws**. Farm-wide roll-ups use census area/pixel weights.

**Uncertainty comes from across-draw spread — never a naive n≈415k CI.** The surface is spatially autocorrelated; effective N ≪ nominal. A single draw's percentiles describe within-stratum spatial spread only.

## 6. Figure pair

- **Concept:** proportional-with-floor allocation + repeated-draw logic — why draw size scales with extent, and what the across-draw band means vs a single-sample CI.
- **Data:** per-stratum median flood-frequency series with across-draw percentile band + a verdict-stability panel (modal verdict + support fraction per stratum). Q1 basis and Q3a threshold annotated on-figure. One figure = one file = one slide; register in `figures_manifest.csv`.

## 7. Acceptance gate (assert all)

1. Pre-flight guard + spine validation PASS before any draw.
2. Allocation reproduces the §3 `target_n` table; floor and cap both confirmed non-binding (flag if either bound).
3. Only 4-class `simplified_vegetation_group`; no `vegetation_adrian_group`/`period` leakage in outputs.
4. Extraction in 28355; centroids reprojected from 9473; mapping in 8058. No CRS conflation.
5. Wet-rule via the neutral `gayini_inundation_wet_rule.R` (`wet∈{1,2}`, `valid∈{0,1,2}`, `mask=3`).
6. Headline = between-year flood frequency; `annual_occurrence_pct` not presented as headline.
7. `SEED` recorded; `n_draws = 100`; per-seed IDs unique and namespaced; runs reproducible.
8. Uncertainty reported as across-draw median + percentiles; **no naive large-N CI** anywhere.
9. F6 reported as modal verdict + support fraction; **expected 8 no-trend · 1 non-stationary · 0 directional**, hardened, not a new trend.
10. Q1 basis + Q3a threshold flagged on figures and in the summary.
11. Riverine·low non-stationary flag tested for across-draw stability.
12. Figure pair registered; concept + data; insets never overlap captions.

## 8. Handoff

- Copy deliverables to `Output/review_bundles/tier1F_spatial_resampling/` and **zip** — the zip is what gets opened.
- Change report at `docs/change_reports/tier1F_production_<date>.md`; commit code + small results tables only, never large spatial data.
- **Stop at the gate. Branch-and-PR; hand back for the human to merge.**

## 9. Open flags (not part of this run)

- **CLAUDE.md post-build ordering is wrong** — it implies `03 → 05`, but the verified working order is **`builder → 05 → 03 → 09`** (`05` registers the stack rows whose CRS/legend `03` then completes). Fix in CLAUDE.md before any full rebuild; a session trusting the current wording could rebuild out of order and leave `03` with nothing to annotate. *(Human edit — CLAUDE.md is authoritative.)*
- **B6 is partial by design** — the load-bearing wet-rule fn is extracted and the active stack (`05`) is decoupled, but the old pre/post file retains an aggregation helper still sourced by the `01/02/04` impls. Fine now; means that file can't be *fully* archived until those callers are checked (one `04` impl is ACTIVE). Defer to the post-rebalance cleanup pass.
- **B5 (archive convention)** and **B7 (register the two F5/F6 rasters in `raster_asset`)** — deferred; B5 is a human call with Adrian, B7 is LOW (reproducible from code).

---
*Gated on Adrian Q1 (draw neighbourhood) + Q3a (`MIN_VALID_COVERAGE`); Q3b sign-off affects deliverables framing, not this run. On confirmation: set the two params, run production, hold the result at the gate.*
