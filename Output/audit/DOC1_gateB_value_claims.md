# DOC-1 Gate B — value and structural claims

**Read-only.** 4 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · no writes.
**Status: COMPLETE for the priority list.** §§1–9 were verified in the first pass against the
pre-correction draft. §§10–11 complete the two items that remained; the third remaining item
(the three-arm gap pair) is carried to Gate C by the spec and is not guessed at here.

**Audited input** (spec v2 requires this recorded): `docs/reports/Gayini_RS_methods_doc_V6.docx` ·
9,821,125 bytes · modified 2026-08-04T13:15:07 ·
SHA-256 `63177e5fc45a9a02072abd654349d8d2eb75d9fb111db2c6260e4751e78e584b`.
Re-hashed at the end of the gate: unchanged, so nothing below rests on a stale extraction.

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

## 10 · §7.3 response values — the first CONTRADICTED claim

Source: `Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv`, 9 stratum rows.
Rule constants read from the producer, `scripts/03_inundation_products/20_run_census_veg_wet_response.R`
— `R_RESPOND = 0.20` (54), `SIGN_FRAC = 0.70` (55), `MIN_RESP_COVERAGE = 0.50` (56), verdict at 218.

| stratum | median_r | sign_frac_pos | cov % | census verdict | wet−dry pts | plot verdict |
|---|---|---|---|---|---|---|
| Aeolian low | NA | NA | 0.00 | undetermined | — | weak_or_none |
| Aeolian mid | 0.1641 | 0.912 | 77.09 | weak_or_none | 10.129 | weak_or_none |
| Aeolian high | 0.1754 | 0.861 | 99.32 | weak_or_none | 5.336 | **responds** |
| Riverine low | 0.1484 | 0.901 | 58.76 | weak_or_none | **11.096** | weak_or_none |
| Riverine mid | 0.2244 | 0.943 | 99.99 | responds | 9.159 | responds |
| Riverine high | 0.3211 | 0.970 | 100.00 | responds | 7.245 | responds |
| Inland low | 0.2562 | 0.973 | 91.73 | responds | 9.246 | responds |
| Inland mid | 0.3860 | 0.996 | 100.00 | responds | 6.756 | responds |
| Inland high | 0.3891 | 0.989 | 100.00 | responds | **4.008** | responds |

**Three of the four §7.3 claims are CONFIRMED, and they are exact.**

- *"from r = 0.16 in Aeolian mid country to r = 0.39 in Inland Floodplain mid and high bands"* —
  0.1641 → 0.16; 0.3860 and 0.3891 → 0.39. The document names the strata rather than asserting a
  range over all of them, so the true minimum (Riverine low, 0.1484) is not miscounted as the floor.
  *"Response strengthens toward the wet end of each community"* holds monotonically in all three.
  **CONFIRMED.**
- *"Riverine low … largest per-flood cover gain at +11.1 percentage points but a correlation of only
  0.15; Inland Floodplain high … smallest gain at +4.0 with a correlation of 0.39"* — 11.096 and
  4.008 are the true maximum and minimum; 0.1484 → 0.15 and 0.3891 → 0.39. All four values match,
  and the document states 0.15 for Riverine low where §7.3's opening sentence quotes 0.16 for a
  different stratum, so the two sentences are consistent rather than in conflict. **CONFIRMED.**
- *"Aeolian low country does not flood at all across the 35-year record"* — `n_never_flood` = 26,786
  = `n_pixels_focus`, response pixels 0. Undefined by construction, not thinned by data loss.
  **CONFIRMED.**

### **CONTRADICTED — §7.3: "Six of the eight measurable strata meet the 0.20 reporting threshold"**

**Found: five of eight.** Eight strata have a defined `median_r`; five reach 0.20 — Riverine mid and
high, Inland low, mid and high. The census `verdict` column reads `responds` for exactly those five.

**The 6 is the plot-support count.** `plot_verdict = 'responds'` holds for **six of nine** strata,
adding Aeolian high, whose plot-support `plot_median_r_veg` is 0.2644 against a census `median_r` of
0.1754. So the sentence pairs a **plot-support numerator with a census-support denominator**. The
source CSV's own header warns that the `plot_*` columns are a *"PLOT-support benchmark (reference,
not a target)"*, and CLAUDE.md's C10 rule forbids merging the two supports in one statement.

Correct at census support: **five of the eight measurable strata**, or **five of nine** if the
never-flooding Aeolian low band is counted in the base.

### **CONTRADICTED — §6.5: "Applying the 0.20 cut without the sign-consistency condition would classify some strata differently"**

**Found: no stratum is classified differently.** `SIGN_FRAC = 0.70`, and the minimum `sign_frac_pos`
across the eight measurable strata is **0.861** (Aeolian high). The sign condition therefore never
binds on this data: the 0.20 cut alone and the full two-part rule both return the same five strata.

This is not the same defect as the §6.5 rule description, which v6 states correctly as a two-part
rule — Gate C confirms that text. It is a claim about the rule's *consequence*, and the consequence
does not occur. The two-part rule is real and should be described; what cannot be said is that it
changes any answer here.

## 11 · The 3.03% median green share — CONFIRMED, on a scope the document does not state

**CONFIRMED from two independent artefacts.** `Output/tables/taskM_green_at_floor_area.csv` gives
`green_frac_pct_median` = **3.03** (mean 11.773), and
`Output/diagnostics/tier2H_h2_green_fraction_at_floor.csv` row *"green fraction of the floor (%)"*
gives median **3.03**, mean 11.773, p95 55.556 over `n_farm_px` = 959,833. The two agree to every
stated digit.

**Unstated convention — the scope is the farm boundary, not the census extent.** The median is taken
over the 959,833 valid floor pixels inside the **Gayini farm boundary at native 30 m EPSG:3577**, an
implied **86,384.97 ha**. That footprint includes treed Floodplain Woodland. The persistence areas
quoted in the same passage — 12,641 / 8,300 / 4,179 ha — are **non-treed** scope, nine strata. So one
paragraph carries two different denominators:

| | pixels | ha | treed included |
|---|---|---|---|
| green share at the floor (3.03%; 71,755 px, 6,458 ha) | 959,833 @ 30 m EPSG:3577 | 86,384.97 | **yes** |
| census mapped extent | 1,080,157 @ 24.97 m EPSG:8058 | 67,349.33 | yes, as context |
| non-treed persistence sweep | 988,829 @ 24.97 m EPSG:8058 | 61,655.3 | no |

Calling 3.03% *"the property median"* is not wrong, but "the property" here is a footprint about 28%
larger than the census extent and 40% larger than the non-treed scope that every adjacent area figure
uses. One clause, in the pattern of the three conventions already raised.

**A trap in the source artefact, not in the document.** `taskM_green_at_floor_area.csv` is tidy-long
and repeats `threshold` / `mask = green_frac_pct > 50` on **every** row, including the
`green_frac_pct_median` row. The median is over all 959,833 valid floor pixels, not over the
majority-green subset — a median of that subset would exceed 50 by construction. Anyone re-deriving
3.03 from that row's stated mask will not reproduce it. It is a source-metadata defect, changes no
number, and belongs in the issues log.

The cell count and area (71,755 px, 6,457.95 ha, native 30 m) are re-confirmed against the same table,
with the persistence README's standing warning that the 8058 reprojected area (3,744.20 ha) and the
older 4,474.03 ha count-conversion are **not** the measured area. The document quotes the native-grid
figure, which is the correct one.

---

## Carried to Gate C

**The three-arm raw and adjusted gap pair** (−32.0 becoming −10.5). Unchanged from the first pass:
no pin exists under that description; the nearest registered values are the Bala 29ca T10 quantity
(−32.1) and the positive `three_arm_floor_deficit_*` entries. Settled at Gate C check C3 together
with the area-weighting check. Not guessed at.

## Counts

**48 priority values and structural claims checked · 46 CONFIRMED · 2 CONTRADICTED · 1 carried to Gate C.**

Both contradictions are in the same family, and both were found by querying a source that had
previously been read off a rendered figure. Neither is a transcription slip: one merges two support
levels in a single ratio, the other asserts a consequence of a rule that the data does not produce.

**Coverage, stated plainly for Gate E.** The v6 extraction holds **224 claims**, of which **96 are
`value` and 79 are `structural`** — 175 in Gate B's nominal scope. The priority list covers 48 of
them. The remaining 127 are **unchecked, not confirmed**, and the Gate E report must say so rather
than present 46 CONFIRMED as the coverage figure.

**Five unstated conventions now recorded** (spec v2 requires these even where the number is right):
the ddof split between §6.4 and §6.1; the pixel-weighting behind 51.1, since stated in v6's §4.4;
§M4's "of 118" against counts summing to 115; the farm-boundary scope behind 3.03%; and the
plot-versus-census support split exposed by the §7.3 contradiction.
