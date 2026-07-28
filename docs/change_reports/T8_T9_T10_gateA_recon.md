# T8 / T9 / T10 — Gate A recon (read-only)

**Task:** reference-state follow-on specs `Gayini_reference_state_specs_T7_T11.md`, three READ-ONLY recon gates.
**Date:** 28 July 2026
**Scope:** T10 Gate A, T9 Gate A, T8 Gate A. No DB writes, no builder run, no registered row touched.
**Verification:** every number below is live query / extraction output against `Output/database/Gayini_Results.sqlite` and the registry-resolved rasters, not a prose assertion.
**Design-seat amendments applied:** (a) T10 does not depend on T8 Gate B; (b) T9→T10 water prediction stated; (c) T8 Gate C docs/ lint out of scope. See spec STEP 6.

Session start: `git fetch --all --prune` clean; on `main`, up to date with `origin/main`, **main has not moved**. Rscript absent on this machine → all raster work done in Python/rasterio; paths resolved from `raster_asset` (I-21), no hardcoded drive letters.

---

## T10 Gate A — locate the five-period derivation

**Finding: no script in the repo produces the five-period split. Logged as I-29 (BLOCK).**

The deck's central §5 table uses periods **1988–92 / 1993–2002 / 2003–12 / 2013–18 / 2019–22**. Exhaustive search across all 429 tracked text files (`git ls-files`, excluding binaries) for files carrying ≥3 of the five boundary years {1992, 2002, 2012, 2018, 2022}:

| file | boundary-year hits | what it actually is |
|---|---|---|
| `Output/tables/task_J_gate3_*.csv`, `docs/Tier1_TaskJ_*` | 3–4 / 5 | Task J — 2018 bank-cut periods, **different split** |
| `docs/change_reports/T12_*`, `scripts/11_database/build_T12_gateD_assessment.py`, `scripts/13_dea_landcover/T12_close_figures.R` | 3–5 / 5 | T12 DEA **sensor eras** (1988–99 / 2000–02 / 2003–10 / 2011–12 / 2013–21 / 2022–25), **different split** |

No file carries the reference-state five-period boundaries. The three deck-figure build scripts (`26_build_veg_water_scatter_deck.R`, `27_build_veg_water_quantile_bands_deck.R`, `07_figures_dashboards/06_refresh_main_deck_figures.R`) contain none of the boundary years.

**What does exist:** `T2_gateE_figures.R:106,117` computes a **two-window** gap report — `early <- mean(yr_gap[yrs <= 1997])`, `late <- mean(yr_gap[yrs >= 2013])`, with a ±2 pp narrows/widens/holds rule → `T2_E_gap_report.csv`. That is not the five-period table.

This independently confirms `Gayini_reference_state_methods.md` §8 ("the five-period split in §5 is not produced by any script listed above … needs locating or rebuilding before these numbers go into a deliverable"). Per instruction the derivation was **not rebuilt**. Rebuild is T10 Gate B, a separate gated step.

---

## T9 Gate A — the open-water premise. **Premise FALSIFIED. T9 stops here.**

**Claim under test (spec):** the reference paddocks' longer low-cover tails are *standing water* reading as low fractional cover, not sparse vegetation. **Stopping rule (spec):** "If wet pixels are not materially lower in cover, the premise is wrong and the task stops here."

Pixel-level extraction at the 795,602 in-scope zoned census centroids (`T2_in_scope_points.csv`), veg = `total_veg_annual_mean_8058.tif`, wet/valid = `annual_wet_any/valid_any_1988_2023_8058.tif` (all three share one 4037×2422 / 35-band / EPSG:8058 / 24.9703 m grid). Encoding mirrors `T2_gateB_extract.R`: veg valid = `!is.na(v)`, inundation valid = `valid_any==1`, wet = `wet_any==1`. Comparison over observed pixel-years (99.8% coverage: 27.79 M of 27.85 M).

**(b) veg cover, WET vs DRY pixel-years — all in-scope pixels:**

| group | n (pixel-years) | mean | p05 | p10 | p25 | median |
|---|---|---|---|---|---|---|
| WET (`wet_any==1`) | 6,964,791 | 86.69 | **74.39** | 78.27 | 83.53 | 88.20 |
| DRY (valid, not wet) | 20,824,093 | 76.38 | **50.00** | 58.56 | 70.15 | 79.46 |
| **WET − DRY** | | **+10.31** | **+24.40** | +19.71 | +13.38 | +8.73 |

Wet pixels are **higher** in cover at every percentile, and the gap is **largest at the floor (p05: +24.4 pp)**. The low-cover tail is composed of DRY pixels, not standing water.

**Per reference paddock (WET − DRY, pp):**

| paddock | mean flood % | WET−DRY mean | WET−DRY p05 | WET−DRY median |
|---|---|---|---|---|
| Bala 26ca (wettest ref, 45.3%) | 45.3 | +8.25 | +20.77 | +6.19 |
| Bala 28ca (43.3%) | 43.3 | +8.83 | +23.49 | +6.41 |
| Bala 27ca (29.7%) | 29.7 | +8.18 | +18.80 | +7.20 |
| Bala 29ca (8.5%) | 8.5 | +11.41 | +31.30 | +9.41 |

In every reference paddock — including the two wet ones (26ca, 28ca) the premise names explicitly — wet pixels carry **more** cover, most strongly at the floor.

**(a) per paddock-year wet share (reference paddocks, inundation-valid basis):** 26ca median 44.5% (max 96.8%), 28ca 36.3% (max 99.2%), 27ca 7.1%, 29ca 6.9%. Full per-paddock-year counts are in `fact_zone_veg_annual` (`wet_pixels`, `valid_pixels`, `flood_frac_pct`).

**Interpretation.** At Gayini's in-scope non-treed pixels, inundation *greens up* the floodplain (the F7 inundation↔cover signal); it does not read as bare open water. Open water reading as low FC is a real mechanism for deep permanent water bodies, but those are largely outside scope (`MIN_SEASONS`/treed/in-scope filtering). **Masking wet pixels would remove the highest-cover observations and push the floor down, not up** — the opposite of the correction T9 was designed to make.

**Consequence for the T9→T10 prediction (spec STEP 6b).** The design-seat prediction rests on "water reads as low cover, so it depresses the floor in wet paddocks." The data shows the reverse at these pixels. Per STEP 5's rule ("if you disagree, the disagreement is the finding — stop and report it"), this is flagged, not worked around. It does **not** by itself resolve T10 — T10's wetness control is a *between-paddock* relationship (drier paddocks have lower floors), a different support from this *within-paddock pixel* result — but it removes open-water contamination as the explanation for the wet paddocks' tails.

**Recommendation:** close T9 at Gate A; do not run Gate B. The methods §7 / limitation L-3 "open water is inside the floor metric" concern is **answered** (masking changes the floor in the wrong direction and by construction cannot raise it) and should graduate to the limitations register (design-seat action; xlsx not edited here).

---

## T8 Gate A — headline-number inventory. **Blocked on a missing source; spread mechanisms reproduce live.**

**`Gayini_reference_state_results_catalogue.xlsx` does not exist** anywhere in the repo (`find -iname '*results_catalogue*'` → nothing). Gate A as written ("start from the `Headline_numbers` sheet … 18 rows") cannot enumerate its 18 numbers. **Row count: N/A — file absent.**

**DB-native headline objects that do exist** (per provenance discipline, the DB is the authority anyway):

| object | rows | holds |
|---|---|---|
| `v_presentation_headlines_live` (view) | 9 | census / F6 headlines, with `support`, `source_artefact`, `source_asset_id`, `caveat` columns |
| `v_biodiversity_presentation_headlines` | 8 | biodiversity deck headlines |
| `taskM_headline_source` | 9 | Task M floor source |
| `v_presentation_headlines`, `bio_monitoring_headline`, `bio_planning_headline` | 4 / 4 / 4 | — |

**None is 18 rows, and none holds the reference-state floor/gap numbers** the spec's Gate A example is about. Those live in `fact_reference_gap_decomposition`, `v_zone_veg_annual`, `v_three_arm_gap_decomposition`, `fact_three_arm_stratum_veg_annual`. So the "18 catalogue numbers" are not materialised in any one DB object — the enumeration itself is the missing input.

**The spread is real — both named ambiguities reproduce exactly against live data:**

1. **Three-arm floor-deficit rollup** (`v_three_arm_gap_decomposition`, `window='all'`). The view returns nine real strata **and** three `regime_band='ALL'` rollup rows; nothing flags which to use:

   | arm | EXCL 'ALL' (9 strata) | INCL 'ALL' rollup |
   |---|---|---|
   | not_grazed | **−4.8** | **−6.1** |
   | unzoned_inferred_standard | +4.3 | +4.2 |
   | unzoned_plot_confirmed | +5.9 | +5.5 |

   Matches the spec's quoted −4.8/+4.3/+5.9 vs −6.1/+4.2/+5.5 to 0.1 pp. This is exactly the Gate D target (`is_rollup` flag).

2. **Reference-minus-grazed floor gap**, zone grain, 1988–92, `mean_of_seasons` (`fact_zone_veg_annual`, ref = fids 1–4, grazed = 60 zones `grazing_excluded=0`):

   | aggregation order | ref | grazed median | gap | spec |
   |---|---|---|---|---|
   | year-first (within-year then mean) | 68.1 | 81.1 | **−13.1** | −13.1 |
   | zone-first (per-zone mean then across) | 68.1 | 81.3 | **−13.2** | −13.2 |

   Matches spec rows 1–2. The full 8-way spread (adding the `jja_son` variant and the zone×community grain) spans −9.1 to −14.8 pp per the spec's measured table.

**No number chosen** — choosing is a design-seat decision. **STOP:** T8 Gate A cannot complete the 18-number inventory until the design seat either supplies `results_catalogue.xlsx` or designates which DB objects/rows constitute the 18 headline numbers.

---

## Standing invariants at close

- No DB write, no builder run, no registered row modified or deleted.
- Writes this gate: this change report + I-29 in `Gayini_issues_log.md` (documentation only).
- Rasters resolved from `raster_asset`; no hardcoded absolute paths; scratchpad-only extraction script.

## Gate outcomes

- **T10 Gate A:** five-period derivation **absent** → I-29 (BLOCK). Rebuild deferred to Gate B. STOP.
- **T9 Gate A:** premise **falsified** (wet pixels higher cover, +24.4 pp at p05). **Recommend close at Gate A; do not run Gate B.** STOP.
- **T8 Gate A:** **blocked** on missing catalogue; spread mechanisms reproduce live; no number chosen. STOP.
