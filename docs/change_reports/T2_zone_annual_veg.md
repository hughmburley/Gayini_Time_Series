# T2 — Per-zone annual vegetation extraction · change report

**Task:** `docs/T2_zone_annual_veg_extraction.md` (v2 · 27 July 2026)
**Branch/commit:** `main` (T2 code `2a34caa`; this report + Gate E follow)
**Scope:** Gates A → B → B2 → C → D (approved) → E. Additive only; no builder re-run;
no pre-existing table/view modified or dropped.

A change report states findings and **points at the `Output/` artefact and registered
id** — it is not the home for a value. Re-derive numbers from the DB / the cited files.

---

## Artefacts produced (all values live here, not in this report)

| Artefact | Home | Registered id |
|---|---|---|
| Zone×year×variant facts | `fact_zone_veg_annual` (SQLite, 4356 rows) + `Output/tables/T2_fact_zone_veg_annual.csv` | — (internal table) |
| Consumption view | `v_zone_veg_annual` (SQLite, 4356 rows) | — |
| Zone×community×year grain (Gate E) | `fact_zone_community_veg_annual` (SQLite, 8142 rows) + `Output/tables/T2_fact_zone_community_veg_annual.csv` | — |
| Persistence-duration surface | `Output/rasters/veg_duration_8058/veg_persistence_duration_8058.tif` (10 bands) | `raster_asset` = `raster_veg_persistence_duration_8058` |
| Gate A evidence figure | `Output/figures/diagnostics/T2_A_stack_alignment.png` | `figure_asset` = `figure_t2_a_stack_alignment` |
| **Paddock floor trajectories (deliverable)** | `Output/figures/diagnostics/T2_E_paddock_trajectories.png` | `figure_t2_e_paddock_trajectories` |
| Paddock mean-cover (secondary) | `Output/figures/diagnostics/T2_E_paddock_trajectories_mean.png` | `figure_t2_e_paddock_trajectories_mean` |
| B2 duration map | `Output/figures/diagnostics/T2_B2_duration_map.png` | `figure_t2_b2_duration_map` |
| Drop log / gap report / community flood | `Output/tables/T2_dropped_zone_years.csv`, `…_E_gap_report.csv`, `…_community_year_flood.csv` | — |
| Extraction inputs (DB/sidecar-derived, repo-relative) | `Output/tables/T2_in_scope_points.csv`, `…_zone_denominator.csv` | — |

Scripts: `scripts/12_zone_stratum/T2_gateA_figure.R`, `T2_gateB_prep.py`,
`T2_gateB_extract.R`, `T2_gateB2_duration.R`, `T2_gateE_figures.R`,
`scripts/11_database/T2_gateC_load.py`.

---

## Gate A — recon (read-only)

- Four 8058 stacks resolved from `raster_asset`, headers verified via `terra`;
  `compareGeom()` TRUE for all four (ext, rowcol, crs=8058, res≈24.970268 m); 35 layers
  each; band 1 = WY1988 (label `1988-1989`, read not assumed).
- Nodata is **NaN, not 255** on the 8058 grid; no layer max ≥ 255; `valid_any` is
  presence-only ({1}+NA, min=max=1 every layer). No 255 can enter a mean.
- `dim_management_zone` = 64; sidecar reconciles **1,080,157 = 885,292 zoned + 194,865
  unzoned**; census parquet = 1,080,157.
- **Reference set = four `No grazing` zones, fids 1–4 (Bala 26ca/27ca/28ca/29ca)**,
  `zone_group='Bala'`. The "three paddocks" account is a miscount (issues-log C-02).
- **I-01 (>100 values) → CLOSED (C-10):** bilinear-resampling overshoot, traced to
  `legend_semantics`. 24 over-100 pixel-years / 143.1M (primary), 622 / 133.95M
  (jja_son). Not water contamination. Kept raw, flagged via counters.
- **I-02 (reference heterogeneity) → quantified, left OPEN as a spine item:** within-
  stratum `veg_p05` spread across the reference paddocks exceeds the reference-vs-grazed
  contrast in **6 of 9 strata** (all Riverine, all Inland Floodplain). A fixed
  distance-to-reference target is undefined there. Spine decision, not a build one.

## Gate B / B2 — extraction

- Scope chain (free assertion 1): `1,080,157 → 993,782` (`treed_context_flag=0` alone,
  the ten-strata trap) `→ 988,831` (`AND regime_band<>'context'` = `SCOPE_NON_TREED`)
  `→ 795,602` (`AND zone_fid IS NOT NULL`). The nine-stratum filter, not the =0 bug.
- 4356 kept / **124 dropped, all `jja_son`** (min-support = `max(500, 30% of zone
  non-treed px)`; `mean_of_seasons` complete 64×35). Drops in
  `Output/tables/T2_dropped_zone_years.csv`.
- `veg_p05_spatial` named long — no plain `veg_p05` in the table. Aggregates never
  exceed 100 (max veg_mean 96.2) though 145 raw pixel-years did; `n_px_over_100` /
  `pct_px_over_100` document it.
- **B2 denominator:** spec said `valid_any`, but `valid_any` is **uniformly 35**
  everywhere (non-discriminating). Used the veg-own `veg_valid_years` [0,35]; **both
  stored**. `pct_above_*` set NA where `veg_valid_years < 10` (min-n) so 1-of-1 cannot
  read 100%. Rule recorded in `legend_semantics`.

## Gate C — persist

- `CREATE TABLE IF NOT EXISTS` + `INSERT OR REPLACE` keyed on
  `(zone_fid, water_year, series_variant)` — never `OR IGNORE`, never `DROP TABLE`.
- **Convergence proof (not stability):** dropped both tables, re-ran twice — run 1
  builds from empty (4356 / 8142), run 2 (upsert path) yields identical row counts and
  identical content md5. Inputs are DB/sidecar-derived, repo-relative — no absolute or
  session-temp paths anywhere (scanned).

## Gate D — sanity checks (reported unadjusted)

- **Flood_frac vs T1 (free assertion 2):** per-zone T2 zone-mean `flood_frac_pct` vs
  T1 `v_census_by_zone_stratum.flood_freq_mean`: **r = 1.0000, |diff| = 0.000 pp** across
  64 zones. Exact because census `valid_years` = 35 for every nine-strata pixel and
  `valid_any` = 35, making the two derivations algebraically identical — so it proves
  **join/scope integrity** (no pixel misassignment or scope leak), not statistical
  independence. Reported as such; nothing tuned.
- Per-year zoned flood 25.20 pp vs census all-pixel 23.32 pp (18% unzoned drier; not equal).
- Variant correlation (`veg_p05_spatial`, per zone): median r=0.904, min 0.739. Two
  below 0.8: fid 49 Mara 5a (0.739), fid 14 Bala 15 (0.752) — both grazed.
- B2 `pct_above_70` vs census `veg_p05` (diagnostic): r=0.888. Related, not identical.

## Gate E — the deliverable

- Built from `fact_zone_community_veg_annual` (mean_of_seasons); reference paddocks
  shown individually per community facet, grazed as IQR band + median, top-tercile
  flood years shaded, faceted by community. The zone×community grain matters: e.g. Bala
  29ca reads `veg_p05_spatial` ≈ 29 / 67 / 35 across Aeolian / Inland / Riverine — a
  dominant-community label would hide it.
- **Gap (reference mean p05 − grazed median p05), early 1988–97 vs late 2013–22** — in
  `Output/tables/T2_E_gap_report.csv`. Reported, **not interpreted**, no convergence
  statistic: in all three communities the reference paddocks sit **below** the grazed
  median; the separation **NARROWS** in Aeolian and Riverine and **HOLDS** in Inland.
  (Consistent with I-02: the reference paddocks are not a clean high benchmark.)

## Gate F — the reference-gap finding gets a DB home (post-Gate-E addition)

The Gate E gap finding lived only in `Output/tables/T2_E_gap_report.csv` and a chat
window — the C-1 condition rebuilt (T4 `claim_register` deferred, I-20). Added:

- **`fact_community_year_flood`** (105 rows) — community×year `flood_frac_pct` + the
  top-tercile `flood_class` (per-community, R type-7 quantile matching Gate E). The
  flood classification previously existed only in a CSV.
- **`fact_reference_gap_decomposition`** + **`v_reference_gap_decomposition`** (27 rows
  = 3 communities × {early_8897, late_1322, all} × {flood, non_flood, all}). Columns:
  `ref_p05_mean`, `grazed_p05_median`, `gap_pp`, `ref_change_pp`, `grazed_change_pp`,
  `gap_change_pp`, `n_ref_paddocks`, `n_grazed_zones`. `gap_change_pp = ref_change_pp −
  grazed_change_pp` (pp, additive) — a single narrowing number cannot hide which side
  moved. **Materialised** (SQLite has no MEDIAN; the metric is a two-stage per-year-then-
  per-window aggregation) and rebuilt deterministically by
  `scripts/11_database/T2_gateF_gap_decomposition.py` — rerun if the fact table changes.
- **Independently reproduced** the chat-computed values with **zero disagreement**:
  Aeolian ref 24.2→39.0 / grazed 60.6→67.0 / gap −36.41→−27.98; Riverine 49.1→53.6 /
  68.5→59.5 / −19.41→−5.88; Inland 76.1→70.5 / 78.5→73.7 / −2.38→−3.15; flood/non-flood
  `gap_change_pp` +6.49/+9.72, +14.88/+12.30, −1.91/+0.57.
- **Mechanism (reported, not interpreted):** Aeolian narrows via the reference side
  rising (+14.8 pp); Riverine via the grazed side falling (−9.0 pp); Inland holds (both
  drift down). Narrowing appears in flood and non-flood years alike — not flood-only.
- Figure **`T2_F_gap_decomposition.png`** (`figure_t2_f_gap_decomposition`, deck-grade).

**Test-1 fixes:** `fact_zone_community_veg_annual` gained `below_min_support` (1 where
`n_pixels_valid < 30`; 209 rows flagged, incl. Bala 28ca's 10-px/0.62 ha Aeolian slice)
so a direct query cannot pick up a sub-support cell. Usable reference paddocks per
community are now data — `n_ref_paddocks` in the decomposition: Aeolian 1, Riverine 3,
Inland 4. (Bala 27ca has no Aeolian/Riverine rows.)

## Acceptance

All acceptance items met; `lint_guardrails.py` exits 0 (the T2 acceptance signal —
15 baselined legacy violations, of which `magic_number` = 5 tracked debt, **0 new**;
"PASS" means no new bare literals, not that none exist). No distance-to-reference metric
or convergence statistic computed (out of scope; spine decision — see I-02).
