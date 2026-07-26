# T1 — Gate D: `v_zone_stratum_treatment_contrast` (matched grazed/ungrazed)

**Date:** 26 July 2026 · **Spec:** `T1_zone_stratum_census_join.md` v3, Gate D · **Status:** complete. **STOP — end of T1.**
Scripts: `build_T1_gateD_contrast.py`, `T1_gateD_figure.R`. Artefacts: `Output/tables/T1_gateD_contrast.csv`, `Output/figures/diagnostics/T1_D_matched_contrast.png`.

## What was built

`v_zone_stratum_treatment_contrast` — one row per (community, regime_band) over the **nine non-treed strata** (`treed_context_flag = 0 AND regime_band <> 'context'`), ungrazed−grazed pixel-weighted differences with **`flood_freq_delta` beside `veg_p05_delta` in the same row**, pixel counts both sides, `min_cell_n = 1` where either side < 3,000 px. `support_level = 'pixel'`, `aggregation_unit = 'zone_stratum'` (the split applied at Gate C). Grazed = 14-day grazing (60 zones); ungrazed = No grazing (4 zones); a zone spans several communities, so ungrazed pixels occur across all strata, not only Riverine.

## The contrast (from `v_zone_stratum_treatment_contrast`)

| community | band | ungrazed px | grazed px | veg_p05 Δ | flood_freq Δ | min_cell_n |
|---|---|---:|---:|---:|---:|:--:|
| Aeolian | low | 5,741 | 20,301 | −2.69 | 0.00 | |
| Aeolian | mid | 3,616 | 18,169 | +0.87 | −0.09 | |
| Aeolian | high | 2,501 | 14,138 | +10.52 | −4.96 | **⚠** |
| Inland | low | 19,834 | 147,996 | −0.24 | −2.70 | |
| Inland | mid | 22,878 | 174,538 | −0.33 | +0.61 | |
| Inland | high | 44,554 | 178,469 | +5.40 | **+10.96** | |
| Riverine | low | 7,877 | 32,850 | **+7.55** | +0.18 | |
| Riverine | mid | 6,381 | 43,594 | **+7.47** | −1.37 | |
| Riverine | high | 2,223 | 49,942 | **+8.25** | −1.59 | **⚠** |

`min_cell_n` flags Aeolian/high (ungrazed 2,501 px) and Riverine/high (ungrazed **2,223 px** — the spec's thinnest cell).

## The result (spine §4 / S4–S5)

The claim under test — *the grazed/ungrazed floor difference survives matching within census stratum, i.e. it is not a wetness artefact* — is **community-specific:**

- **Riverine Chenopod: SUPPORTED.** `veg_p05_delta` is **+7.5 to +8.3 pp, consistent in sign across all three bands**, while `flood_freq_delta` is small (+0.18 / −1.37 / −1.59) — the floor difference is **not** driven by a wetness gap. This survives the falsification test (consistent sign across bands) and is stronger than the naive whole-farm +3.7 (ungrazed 62.7 vs grazed 59.0), which was diluted by mixing strata.
- **Inland Floodplain: no clean signal.** ~0 in low and mid (−0.24, −0.33). Inland-**high** shows +5.40 pp floor, but ungrazed there is **+10.96 pp wetter** — the floor gap tracks the wetness confound, exactly what the side-by-side columns exist to expose. Not attributable to treatment.
- **Aeolian: not separable.** Sign flips across bands (−2.69 / +0.87 / +10.52), and the +10.52 high cell is small (flagged) and paired with ungrazed being 4.96 pp *drier* — inconsistent with a treatment story; the signal is not separable from position.

**Spine return:** replace the preliminary whole-farm grazed/ungrazed row with the pipeline-computed contrast. The treatment effect on the floor is **real and robust in Riverine Chenopod**, and **null or wetness-confounded elsewhere** — a community-specific S5, reported as readily as a positive whole-farm number would have been.

## Figure

`T1_D_matched_contrast.png` (via `write_and_register_figure()`, `support_level='pixel'`): one panel per community, green `veg_p05` delta beside blue `flood_freq` delta per band; cells < 3,000 px greyed at 0.35 alpha and labelled "n < 3,000 px". Reading it: Riverine's green bars stand alone (blue ≈ 0); Inland-high's green is dwarfed by its blue.

## Acceptance

- [x] `v_zone_stratum_treatment_contrast`: nine non-treed strata (`Other / minor units` absent — the `regime_band <> 'context'` filter).
- [x] `flood_freq_delta` beside `veg_p05_delta` in the same row; `min_cell_n` flag under 3,000 px.
- [x] `support_level = 'pixel'` (+ `aggregation_unit = 'zone_stratum'`) on every row.
- [x] `T1_D_matched_contrast.png` written and registered.
- [x] Idempotent; snapshot regenerated (`docs/..._20260726.xlsx`, as-of 12:15 UTC, 94 objects, sheet `14_Zone_stratum_contrast`).

**STOP — T1 complete.** Per your instruction, not starting Gate D follow-ons or T5 Gates 2–4. Next is the 66 D2 site dashboards and the 66-plot plot↔paddock join (reusing this gate's `st_intersects` on `dim_plot` centroids reprojected 9473→8058), with a "not within a mapped paddock" path for the two `Standard grazing` plots (incl. GA_032).
