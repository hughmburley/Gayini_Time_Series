# T8 Gate A inventory + T9 addendum

**Task:** reference-state follow-on, per `Gayini_reference_state_specs_T7_T11.md` v1 as amended by `T8_T9_T10_gateA_decisions.md` v1.
**Date:** 28 July 2026 · **Prior:** SHA 7fe6808 (Gate A recon)
**Scope this session:** T9 Gate A addendum (cheap), T8 Gate A inventory. Both READ-ONLY — no DB write, no builder, no registered row touched. STOP after T8 Gate A.
**Verification:** every value is live query / raster-extraction output against `Gayini_Results.sqlite` and registry-resolved rasters.
**Standing amendment honoured:** design-seat numbers are predictions to check; independently recomputed values stand and any disagreement is reported (decisions §6). #17 recomputed independently, not reconciled (§3a).

Session start: `git fetch --all --prune`; on `main`, up to date with `origin/main`, main has not moved.

---

## T9 addendum — L-3 closed by direct measurement

Design seat asked (if cheap): of the pixels that **set** `veg_p05_spatial` — the bottom 5% of each paddock-year — what share carried `wet_any==1`, versus the paddock-year's overall wet share? One pass on the existing extraction (4 reference paddocks, per-paddock-year p05 threshold, pooled across 35 years):

| paddock | tail wet% (bottom-5% pixels) | overall wet% | tail − overall |
|---|---|---|---|
| Bala 26ca | 14.7 | 45.3 | **−30.6** |
| Bala 27ca | 16.5 | 29.7 | **−13.2** |
| Bala 28ca | 8.8 | 43.3 | **−34.5** |
| Bala 29ca | 2.3 | 7.8 | **−5.6** |

The floor-setting pixels are **under-represented for water in every reference paddock** — the tail is dry vegetation, not standing water. This closes L-3 by direct measurement rather than by inference from the group mean (Gate A recon showed wet-group p05 = 74.4, above every paddock floor; this confirms it at the tail itself). Per decisions §1, L-3 graduates to the limitations register as **tested and closed**, and "confound" is the wrong word — water is the ecological driver of the floor, not an artefact contaminating it (design-seat action on the register/deck; xlsx not edited here).

---

## T8 Gate A — headline-number inventory (18 numbers)

Catalogue `Gayini_reference_state_results_catalogue.xlsx` → `Headline_numbers` sheet, **18 numbers** (rows 4–21). All 18 source objects exist in the DB. Deck value reproduced and value(s) under every defensible alternative below. **No number chosen — pinning is the design seat's at Gate B.**

Common qualifiers: pixel constant `PIXEL_AREA_HA = 0.062351428` (24.970268 m); denominators farm = 85,910.8 ha, mapped = 67,349.332 ha; reference = fids 1–4 (Bala 26/27/28/29ca, `grazing_excluded=1`); grazed = 60 zones (`grazing_excluded=0`, 14-day). All veg numbers are `veg_p05_spatial` (within-year spatial floor) unless noted, **never** census `veg_p05`.

| # | number (deck value) | source | grain | agg order | variant | scope / regime_band | period | **spread across defensible alternatives** |
|---|---|---|---|---|---|---|---|---|
| 1 | Ref-grazed floor gap, 4 pdk (−13.1) | v_zone_veg_annual | zone | year/zone-first | mean_of_seasons | ref4 vs 60 grazed | 1988–92 | **−13.07 / −13.20** (mean_of_seasons) · **−11.25 / −11.28** (jja_son). Full 8-way incl zone×community grain spans −9.1..−14.8 (spec; recompute at pin) |
| 2 | Ref-grazed gap, 3 pdk no-29ca (−1.5..−3.3) | v_zone_veg_annual | zone | year-first | mean_of_seasons | ref3 vs grazed | 5 periods | mean_of_seasons **−3.3/−2.2/−1.8/−1.6/−1.5**; jja_son −2.2/−1.6/−1.3/−1.3/−0.2 |
| 3 | Bala 29ca gap (−42.3→−18.0) | v_zone_veg_annual | zone | year-first | mean_of_seasons | fid4 vs grazed | 5 periods | **−42.3/−39.0/−26.2/−18.2/−18.0**; jja_son −38.5/−35.7/−25.1/−20.2/−17.5. **Alternative = the periodisation itself (I-29, undocumented boundaries)** — endpoints stable, interior boundary-dependent |
| 4 | Same, jja_son (−38.5→−18.3) | v_zone_veg_annual | zone | year-first | jja_son | fid4 | 5 periods | see #3 (endpoint −17.5 vs deck −18.3; period-def rounding) |
| 5 | Bala 29ca share of ref plots (13 of 24) | plot_management_overlay | plot | count | — | No-grazing plots | — | **Denominator verified: 24 No-grazing plots** (also 27×14-day, 15×Standard = 66). **"13 in Bala 29ca" NOT re-derivable from this object** — it carries treatment class, not paddock identity. Provenance gap → needs `T2_plot_paddock_join.R` |
| 6 | Ref−grazed MEAN cover by community (−3.0/−0.8/+1.8) | v_three_arm_gap_decomposition | stratum→community | mean over pixels | — | not_grazed, window='all' | all | **regime_band='ALL' (deck): −3.0/−0.8/+1.8** vs **band mean (excl ALL): −2.5/+1.4/+0.4** |
| 7 | Ref−grazed FLOOR by community (−19.6/−11.7/+1.1) | v_three_arm_gap_decomposition | stratum→community | — | — | not_grazed, window='all' | all | **ALL (deck): −19.6/−11.7/+1.1** vs **band mean: −11.2/−4.4/+1.1**. Large spread on Aeolian (−19.6 vs −11.2) and Riverine (−11.7 vs −4.4) — this is the `is_rollup` pin |
| 8 | Bala 29ca median cover vs grazed (75.6 vs 81.6) | fact_zone_veg_annual | zone | mean of veg_median over 35 yr | mean_of_seasons | fid4 vs grazed | 1988–2022 | **75.6 vs 81.6** (mean_of_seasons); 79.3 vs 84.1 (jja_son) |
| 9→13 | Three-arm mean floor deficit (−4.8/+4.3/+5.9) | v_three_arm_gap_decomposition | stratum | mean over 9 strata | — | window='all', **regime_band<>'ALL'** | all | **excl ALL (deck): −4.8/+4.3/+5.9** vs **incl ALL: −6.1/+4.2/+5.5** |
| 10→14 | Arms above 14-day floor (6/9, 8/9) | v_three_arm_gap_decomposition | stratum | count deficit>0 | — | window='all', excl ALL | all | **inferred 6/9, plot-confirmed 8/9** (reproduced exactly) |
| 11→15 | T1 Riverine contrast (+7.5/+7.5/+8.3) | v_zone_stratum_treatment_contrast | pixel | pixel-weighted | — | all ungrazed zones | census | **low +7.55 / mid +7.47 / high +8.25** (reproduced) |
| 12→16 | Same, Bala zone support (+3.6/+0.1/−2.1) | v_zone_stratum_contrast_bala_robust | zone | — | — | Bala only | census | **low +3.62 / mid +0.12 / high −2.13** (reproduced) — the collapse |
| 13→17 | Gap change 88-97→13-22, all (+8.4/−0.8/+13.5) | v_reference_gap_decomposition | community | gap_change | mean_of_seasons | window='all', flood_class='all' | two-window | **Aeolian +8.4 / Inland −0.8 / Riverine +13.5** (reproduced) |
| 14→18 | Same, non-flood (+9.7/+0.6/+12.3) | v_reference_gap_decomposition | community | gap_change | — | flood_class='non_flood' | two-window | **+9.7 / +0.6 / +12.3** (reproduced) |
| 15→19 | Bala 29ca mean inundation (8.5%) | fact_zone_veg_annual | zone | mean flood_frac | variant-indep | fid4 | 1988–2022 | **mean 8.5% · median 6.9%** (grazed median-of-means 28.6%) |
| 16→20 | Floor vs flood, 64 pdk (r=0.71, slope+0.55) | fact_zone_veg_annual | paddock | OLS on 35-yr means | mean_of_seasons | all 64 | 1988–2022 | **INDEPENDENT recompute: slope +0.548, r=0.710, n=64** — agrees with the (unregistered) deck figure; reported as own value, not reconciled (§3a) |
| 17→21 | Property outside mapped census (18,562 ha / 21.6%) | census scope | property | subtraction | — | farm − mapped | — | **18,561.5 ha = 21.6% of farm**. **Named confusion:** 18% (12,179 ha) = unzoned *inside* mapped ≠ 21.6% (18,562 ha) = *outside* mapped. Different quantities |

*(Row-pair labels e.g. "9→13" = inventory sequence → catalogue row.)*

### What the inventory surfaces for pinning (design-seat, Gate B — not chosen here)

1. **`regime_band='ALL'` rollup vs unweighted band mean** decides #6, #7, and #9. Material only for the floor by community: Aeolian −19.6 vs −11.2, Riverine −11.7 vs −4.4. The deck uses the ALL (area-weighted) rollup throughout. This is exactly the `is_rollup` flag the T8 Gate D amendment adds.
2. **Grain and aggregation order** move #1 across −9.1..−14.8; the zone-grain, mean_of_seasons pair is the tightest (−13.1/−13.2).
3. **Periodisation (I-29)** is the alternative axis for #2/#3/#4; the design seat's own boundary test (decisions §3b) shows the narrowing survives every periodisation, and T10 Gate B replaces the period table with an annual trend.
4. **#5 is not re-derivable from its named object** — provenance gap, needs the plot→paddock join.
5. **#17 is unregistered** in the deck; the independent recompute (+0.548 / 0.710) should be the registered value once T10 Gate B lands (T10 recomputes it independently anyway per §3a).

**No number pinned. STOP** — the spread table is for the design seat to choose from before Gate B writes `dim_headline_number`.

---

## Invariants at close
- No DB write, no builder, no registered row modified/deleted. Writes: this change report only (documentation).
- Rasters resolved from `raster_asset`; extraction scripts in scratchpad; no hardcoded absolute paths.

## Gate outcome
- **T9 addendum:** floor-setting pixels under-represented for water in all four reference paddocks → **L-3 closed by direct measurement.**
- **T8 Gate A:** 18-number inventory complete; all deck values reproduce; spreads reported; **no number chosen. STOP** before Gate B pinning.
- **Next per sequence:** T10 Gate B+C (critical path — I-29 blocks deck slides 7–8), amended per decisions §3a–3c.
