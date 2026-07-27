# T6 — The third grazing arm · change report

**Task:** `docs/T6_third_grazing_arm.md` (v1 · 27 July 2026)
**Depends on:** T1 (sidecar), T2 (extraction method). **T2 not reopened.**
**Scope:** Gates A → B → B2(components) → C → D (STOP) → E. Additive only; no builder
re-run; `fact_zone_community_veg_annual` and all T2 objects **unmodified**.

A change report states findings and points at the `Output/` artefact + registered id.
Re-derive numbers from the DB / cited files.

## Artefacts

| Artefact | Home | Registered id |
|---|---|---|
| Three-arm stratum facts | `fact_three_arm_stratum_veg_annual` (3356) + `v_three_arm_veg_annual` | — |
| Unzoned per-component facts | `fact_unzoned_community_veg_annual` (7911; band + `ALL`) | — |
| Three-arm gap decomposition | `fact_three_arm_gap_decomposition` (144) + `v_three_arm_gap_decomposition` | — |
| Connected-components raster | `Output/rasters/unzoned_components_8058/unzoned_components_8058.tif` | `raster_asset` = `raster_unzoned_components_8058` |
| **Three-arm floor grid** | `Output/figures/diagnostics/T6_A_three_arm_grid.png` | `figure_t6_a_three_arm_grid` |
| **Deck cut (4-panel)** | `T6_A_three_arm_deck.png` | `figure_t6_a_three_arm_deck` |
| **Mean-cover grid** | `T6_B_three_arm_mean.png` | `figure_t6_b_three_arm_mean` |
| Component table | `Output/tables/T6_components.csv` | — |

Scripts: `T6_gateB_prep.py`, `T6_gateB_components.R`, `T6_gateB_extract.R` (12_zone_stratum);
`T6_gateC_load.py`, `T6_gateD_decomposition.py` (11_database); `T6_gateE_figures.R`.

## Gate A — the unzoned area is a usable but caveated arm
- Composition: 194,865 unzoned px = 12,150.1 ha; **99.2% in the nine vegetation strata**,
  88.7 ha treed + 13.3 ha other. No water/road/infrastructure class; no open water
  (max flood-freq 85.7%, 1.4 ha ≥80%). Not roads/water/remnants → clears the spec's
  falsification test.
- **Systematically drier** than zoned (flood_zone 0–2: 75.9% vs 49.7%) — a confound,
  **fixed** at Gate B by extracting at stratum (community × regime_band), not caveated
  (Gate D residual ≤3.3 pp vs 26 pp gross skew).
- Coherence (in-scope): 522 components, **18 ≥100 ha (10,890.9 ha, 91.8%)**; four big
  blocks 2,743 / 2,022 / 1,972 / 1,611 ha.
- Plot evidence: **8 of 15 standard plots** on qualifying components, in **3 of 18**
  (comp 377 holds 6). 17 of 18 components have no plot.
- **Correction 4 confirmed:** all 15 standard plots have `management_zone_coverage_pct=0`;
  the 7 unplaced = the 7 **outside the mapped census** (same set) — see L-T6-b.

## Gate B/C — three-arm extraction at stratum grain
- One pass over 988,831 in-scope pixels; arm = `zone_fid IS NULL` → `unzoned_inferred_standard`,
  else `grazing_excluded` → `not_grazed` / `grazed_14day`. Same `SCOPE_NON_TREED`, same
  method as T2. Fourth arm `unzoned_plot_confirmed` (the 3 plot-confirmed components).
- Grain: arm × community × regime_band (+ `ALL` roll-up) × year × variant; unzoned also
  per component. `below_min_support`, `plot_confirmed`, `n_plots` carried.
- `v_three_arm_veg_annual` unions the arms on a common `treatment_arm`.

## Gate D — the three-arm comparison (report, not decide)
**Within stratum (wetness controlled), floor deficit vs 14-day, above-14-day count across 9 strata:**

| arm | above 14-day | mean deficit |
|---|---|---|
| not_grazed | 5 of 9 | −4.8 pp |
| unzoned inferred standard | 6 of 9 | +4.3 pp |
| unzoned **plot-confirmed** | 8 of 9 | +5.9 pp |

The inferred-standard arm sits **at or above** the 14-day floor; the plot-confirmed
subset is **highest of the three**. **Two readings, both carried (do not present (a) as
the finding):**
- **(a)** grazing intensity does not register — the ordering is noise.
- **(b)** the unzoned land is **less** grazed, not more — "unzoned" = outside the
  rotational system (remote/unwatered/unfenced), so the ordering is a real intensity
  gradient with the inference **inverted**. The monotonic ordering and the plot-confirmed
  subset being highest favour (b); (a) must treat both as coincidence.

Honest statement: *the inferred-standard arm sits at or above the 14-day arm on the floor
within stratum, which is inconsistent with heavier grazing degrading the floor, and may
instead indicate the unzoned land is less grazed rather than more.* → **L-T6-a** (top
external data request to Nari Nari).

**Mean-vs-floor** now has a DB home (`fact_three_arm_gap_decomposition`, community roll-up):
not_grazed matches 14-day on **mean** but sits below on the **floor** (Aeolian floor −19.6
vs mean −3.0; Riverine −11.7 vs −0.8). Magnitudes differ from T2 (pixel-pooled vs
paddock-averaged); the contrast is the finding.

**Plot-confirmed agrees with the full unzoned arm** (Aeolian +10.5/+12.1, Inland −3.2/−4.2,
Riverine +4.2/+4.9) → agreement supports treating the whole unzoned area as one arm.

**Replication flag on every figure:** not_grazed is **n=1** in Aeolian (Bala 29ca; the
−27.4 pp mid cell is one paddock); the unzoned arm is **n=3–17** — the better-replicated
arm in every stratum.

## Gate E — figures
`T6_A_three_arm_grid.png` (arm × community, one line per panel over the 14-day IQR
comparator, flood years shaded, per-panel deficit + n, rows ordered by deficit),
`T6_A_three_arm_deck.png` (4-panel cut), `T6_B_three_arm_mean.png` (mean-cover). Every
caption carries both readings, the inference label `unzoned mapped area (8 of 15
standard-grazing plots)`, and the n=1 Aeolian flag.

## Acceptance
All criteria met. `fact_zone_community_veg_annual` unmodified; no existing object dropped.
`lint_guardrails.py` exits 0. Two readings reported, (a) not presented as the finding.
Limitations staged (`Gayini_limitations_register_additions_T6.md`); T2 confound logged
(I-25). Convergence proven by re-run (below).
