# DOC-1 Gate B — value and structural claims (partial)

**Read-only.** 4 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · no writes.
**Status: PARTIAL.** Eight of the ten priority groups are verified below. Two remain — see §Remaining.

Verdicts: **CONFIRMED** = reproduced from a named source object. Values below are the found values.

---

## 1 · Expectation line constants — CONFIRMED (5 of 5)

Source: `dim_headline_number`, registered by `scripts/11_database/build_REG1_gateB_register.py`.

| doc | pinned | verdict |
|---|---|---|
| intercept 52.65 | `floor_flood_intercept_64pdk` = 52.65 | CONFIRMED |
| slope 0.548 | `floor_flood_slope_64pdk` = **0.5478** | CONFIRMED at stated precision |
| r 0.71 | `floor_flood_r_64pdk` = 0.71 | CONFIRMED |
| residual SD 6.62 | `floor_flood_residual_sd_64pdk` = **6.621** | CONFIRMED |
| RSE 6.73 | `floor_flood_rse_64pdk` = **6.727** | CONFIRMED |

The document rounds; the registry carries more digits. No precision conflict — every rounding is correct.

## 2 · The three largest residuals — CONFIRMED (3 of 3, plus the derived claims)

| doc | pinned | verdict |
|---|---|---|
| Bala 15 −17.6 | `bala15_xsec_residual` = **−17.62** | CONFIRMED |
| Bala 29ca −16.8 | `t10_bala29ca_xsec_residual` = −16.8 | CONFIRMED |
| Dinan 10 −15.1 | `t10_dinan10_xsec_residual` = −15.1 | CONFIRMED |

Two derived statements also check out against the registered residual SD of 6.621:

- §M5b *"All three lie between two and three residual standard deviations below the line"* → 2.66 / 2.54 / 2.28. **CONFIRMED.**
- §6.1 *"a residual of −16.8 is about 2.5 typical misses"* → 16.8 ÷ 6.621 = 2.538. **CONFIRMED.**
- Ranks: with Bala 15 the largest shortfall, F5's *"Bala 29ca … ranking 2nd of 64"* and *"Dinan 10 … ranks 3rd"* are internally consistent. **CONFIRMED.**

## 3 · The gap series — CONFIRMED (8 of 8)

| doc | pinned |
|---|---|
| +0.057 pp/yr, r 0.22 | `t10_gap_annual_slope_B_excl29ca` = 0.057 · `..._r_B_excl29ca` = **0.222** |
| +0.919 pp/yr, r 0.85 | `..._slope_C_29ca` = 0.919 · `..._r_C_29ca` = **0.846** |
| +0.273 pp/yr, r 0.77 | `..._slope_A_all4` = 0.273 · `..._r_A_all4` = 0.77 |
| mean gap −2.07 | `ref_grazed_gap_annual_ref3_excl29ca_mean` = **−2.073** |
| range −7.04 to +4.99 | same pin, `spread_min` −7.038 / `spread_max` 4.987 |

F3's nomenclature note — that "three paddocks" means 26ca/27ca/28ca and a different three exists in the results store — matches the pin's own `scope_filter`. **CONFIRMED.**

## 4 · Part classification counts — CONFIRMED (5 of 5)

`t13_parts_recovering_count` 8 · `t13_parts_declining_count` 16 · `t13_parts_persistently_poor_count` 14 · `t13_parts_unremarkable_count` 77 · `t13_recovering_survive_drop2wettest` 5.

Internally consistent: 8 + 16 + 14 + 77 = **115**, and `t13_parts_low_and_falling_count` 4 + `t13_parts_low_and_flat_count` 10 = 14 persistently poor.

**One structural wording flag.** §M4 opens *"Of 118 parts, 8 meet the recovering criterion, 16 are declining…"* — but the four counts sum to 115, the **supported** parts. The three unsupported parts are excluded from every count while 118 is the stated base. T2's limitation states the rule correctly. Not a wrong number; a denominator that does not match its counts in the same sentence.

## 5 · Community standard deviations (§6.4) — CONFIRMED (9 of 9), and they are sample SD

Recomputed from `Output/tables/T13_gateC_classification.csv`, 115 rows, columns `community` / `level` / `trend_adj`:

| community | n | doc level SD | found (ddof=1) | doc trend SD | found (ddof=1) |
|---|---|---|---|---|---|
| Aeolian | **17** ✓ | 11.92 | **11.920** | 0.241 | **0.2412** |
| Riverine | **37** ✓ | 10.86 | **10.860** | 0.330 | **0.3303** |
| Inland | **61** ✓ | 6.03 | **6.029** | 0.179 | **0.1790** |

All nine CONFIRMED. Your derivation from the CSV was right.

**Convention note, not an error.** These are **sample** SD (ddof = 1). Population SD would give 11.564 / 10.712 / 5.979 — visibly different at the stated precision. The registered `floor_flood_residual_sd_64pdk` is explicitly the **population** convention (ddof = 0). So the document carries two spread statistics under two different conventions, each correct as computed, neither stated. Worth one clause in §6.4.

## 6 · Census structure — CONFIRMED (all)

`census_by_zone_stratum`, summed:

- **1,080,157 cells** — exact.
- Per-stratum, non-treed: Aeolian 27,038 / 26,786 / 23,720 (§3.1's *"approximately 25,000"* ✓); Inland 239,635 / 238,328 / 239,666 (*"approximately 239,000 cells per band"* ✓); Riverine 63,551 / 65,781 / 64,326.
- Context strata: Floodplain Woodland/Forest **86,375** and Other/minor units **4,951** — both stated exactly in §3.1 and both exact.

## 7 · Persistence threshold sweep — CONFIRMED (3 of 3)

`Output/tables/T3_gateB1_threshold_sweep.csv`, `metric = total_cover_floor`, `scope = non_treed`:

| threshold | found area_ha | doc |
|---|---|---|
| 70 | 12,640.75 | 12,641 ✓ |
| 75 | 8,300.41 | 8,300 ✓ |
| 80 | 4,179.29 | 4,179 ✓ |

The 71,755 cells / 6,458 ha green-share pair is corroborated by `Output/rasters/persistence_8058/README.md`, which states the measured area as **6,457.95 ha (71,755 px × 0.09 ha at native 30 m EPSG:3577, `green_frac_pct > 50`)** — matching the document, and carrying the warning that the 8058 reprojected area (3,744.20 ha) is **not** the measured area and must not be quoted as one. The document correctly quotes the native-grid figure.

## 8 · Bala 29ca — CONFIRMED (6 of 6)

| doc | source | found |
|---|---|---|
| raw trend 0.682 | `t10_bala29ca_raw_floor_trend` | 0.682 |
| water slope 0.414 | `t10_bala29ca_within_paddock_water_slope` | 0.414 |
| adjusted 0.556 | `t10_bala29ca_water_adjusted_floor_trend` | 0.556 |
| 81.6% surviving | `bala29ca_improvement_surviving_water_pct` | 81.6 |
| spatial floor 40.5 | `rptscope_canary_p1_paddock_floor_bala29ca` | **40.52** |
| temporal floor 51.1 | `census_by_zone_stratum`, pixel-weighted | **51.05** |

The temporal floor needed a query rather than a pin. **The aggregation matters and the document does not state it:** pixel-weighted across the paddock's non-treed strata gives 51.05 (→ 51.1 ✓), but the *unweighted* mean of the same strata gives **55.64**. §4.4 quotes 51.1 without saying it is pixel-weighted, and the unweighted alternative differs by 4.6 points.

Also confirmed in passing: T1's *"Bala 29ca floods in 8.5% of years and ranks 61st"* — `bala29ca_mean_flood_freq` 8.5, `ref_paddock_flood_rank_bala29ca` 61. And *"Bala 26ca … ranks 3rd of 64"* — `ref_paddock_flood_rank_bala26ca` 3.

## 9 · Three-arm figures — PARTIAL

- *"six of nine strata"* → `three_arm_unzoned_inferred_above_14day_count` = **6** (spread 6–6). **CONFIRMED.**
- *"eight of nine"* → `three_arm_unzoned_plot_above_14day_count` = **8**. **CONFIRMED.**
- *"raw gap of −32.0 … becomes −10.5"* → **NOT YET RESOLVED.** Neither value appears as a pin under that description. The nearest registered quantities are `t10_bala29ca_aeolian_level_deficit` = **−32.1** (a T10 Bala-29ca quantity, not a three-arm one) and the `three_arm_floor_deficit_*` family, whose Aeolian entries are **positive** (+5.99 inferred, +10.16 plot-confirmed). Since Bala 29ca is the only ungrazed paddock in Aeolian country (F4's n = 1 limitation), the −32.0 is plausibly the ungrazed-arm raw gap and −32.1 its registered form — but that is inference, not verification. This is precisely the Gate C check the spec calls for on Figure 24, and it is carried there rather than guessed at here.

---

## Remaining at Gate B

- **§7.3 response values** — r 0.16 to 0.39 and the wet-minus-dry deltas +4.0 to +11.1. Source object identified at Gate A (`Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv`, 9 rows) but not yet read. These are the values you flagged as read off the figure rather than queried, so they are the highest-value remaining item.
- **The −32.0 / −10.5 pair**, above, together with the area-weighting check — carried to Gate C.
- **The 3.03% median green share** — the cell count and area are corroborated; the median itself is not yet re-derived.

## Counts so far

**41 priority values checked · 40 CONFIRMED · 0 CONTRADICTED · 1 unresolved.** No stated value has yet been found wrong. Three notes have been raised that are not errors but unstated conventions or mismatched denominators: the ddof split between §6.4 and §6.1, the unstated pixel-weighting behind 51.1, and §M4's "of 118" against counts summing to 115.
