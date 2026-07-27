# T1 — Gate D: `v_zone_stratum_treatment_contrast` (matched grazed/ungrazed) + robustness

**Date:** 27 July 2026 · **Spec:** `T1_zone_stratum_census_join.md` v3, Gate D (+ the 27 Jul block/zone-support ask) · **Status:** complete. **STOP — end of T1.**
Scripts: `build_T1_gateD_contrast.py`, `T1_gateD_figure.R`. Artefacts: `Output/tables/T1_gateD_contrast.csv`, `Output/tables/T1_gateD_robustness.csv`, `Output/figures/diagnostics/T1_D_matched_contrast.png`.

## Views

- **`v_zone_stratum_treatment_contrast`** — one row per non-treed stratum (`treed_context_flag = 0 AND regime_band <> 'context'`), ungrazed−grazed `veg_p05_delta` beside `flood_freq_delta`, **`n_ungrazed_zones` / `n_grazed_zones`** and pixel counts both sides, `min_cell_n` (pixels < 3,000). `support_level='pixel'`, `aggregation_unit='zone_stratum'`.
- **`v_zone_stratum_contrast_bala_robust`** — the robustness view (below).

## The block confound (why the headline table is not the answer)

**All four ungrazed zones are Bala paddocks** (`dim_management_zone`: Bala 4 / Mara 0 / Dinan 0). The headline "grazed" side is 60 zones **including Mara and Dinan**, so the all-zones contrast **confounds treatment with the Bala-vs-rest difference**. And because a zone spans several communities, those same four Bala polygons supply the ungrazed side of *every* stratum — **nine rows, one treatment group, sliced nine ways.** So "consistent sign across bands" cannot support anything here: three Riverine bands are three wetness slices of the same four paddocks, and if those four are greener for *any* non-grazing reason the sign is consistent **by construction.** (That argument is withdrawn from the prior version of this report.)

## Headline table — all-zones, pixel-weighted (confounded; for reference only)

| community | band | nU / nG | veg_p05 Δ | flood_freq Δ | min_cell_n |
|---|---|---|---:|---:|:--:|
| Aeolian | low / mid / high | 1 / 1 / 2 vs 15 / 17 / 15 | −2.69 / +0.87 / +10.52 | 0.00 / −0.09 / −4.96 | high ⚠ |
| Inland | low / mid / high | 4 / 4 / 4 vs 53 / 57 / 57 | −0.24 / −0.33 / +5.40 | −2.70 / +0.61 / +10.96 | |
| Riverine | low / mid / high | 3 / 3 / 3 vs 25 / 34 / 34 | +7.55 / +7.47 / +8.25 | +0.18 / −1.37 / −1.59 | high ⚠ |

## Robustness — Bala-only, block-controlled and at zone support

`v_zone_stratum_contrast_bala_robust`: 4 ungrazed Bala vs ≤22 grazed **Bala** paddocks. (a) pixel-weighted; (b) **zone-support** (unweighted mean of per-zone means — n = zones, the honest denominator; pixels are spatially autocorrelated, so pixel n overstates precision by ~3 orders of magnitude for a treatment contrast).

| community | band | nU_bala / nG_bala | (a) Bala px Δ | (b) zone-support Δ | ungrazed paddock veg_p05 range |
|---|---|---|---:|---:|---|
| Aeolian | low / mid / high | 1 / 1 / 2 vs 1 / 1 / 1 | +21.2 / +22.8 / +22.6 | +21.2 / +22.8 / +24.3 | one paddock (Bala 29ca) — n meaningless |
| Inland | low / mid / high | 4 / 4 / 4 vs 21 / 22 / 22 | −2.46 / −1.51 / +2.61 | −2.47 / −1.16 / +3.27 | 46.9–59.0 / 57.7–66.4 / 68.1–79.4 |
| Riverine | low / mid / high | 3 / 3 / 3 vs 6 / 12 / 11 | +9.03 / +10.86 / +0.90 | **+3.62 / +0.12 / −2.13** | **27.9–47.1 / 24.5–52.7 / 29.8–66.3** |

**The Riverine +7.5..+8.3 pp does not survive.**
- **Block control (a)** already collapses Riverine-high (+8.25 → +0.90).
- **Zone support (b)** collapses the rest: Riverine **low +3.62, mid +0.12, high −2.13**. The one weakly-positive cell (low) rests on **Bala 29ca**, which supplies 7,295 of its 7,877 ungrazed px (93 %).
- The **ungrazed paddocks are wildly heterogeneous**: Bala 29ca is consistently green (47 / 53 / 66) and Bala 26ca consistently bare (28 / 24 / 30) across the three bands — a within-treatment range (24.5–66.3) far wider than any delta. The pixel-weighted "effect" is whichever paddock has more pixels in that stratum, not grazing.
- **Aeolian** rests on n = 1 ungrazed zone (Bala 29ca alone) — the +21..+24 is one paddock, not a contrast.

## Corrections to the earlier reading

- **Aeolian:** "ungrazed 4.96 pp drier" is **not** a reason to discount the +10.52 — drier-and-greener runs *against* the wetness explanation and would *strengthen* a real effect. The reasons to discount are **n = 2,501 px on a single ungrazed paddock and the sign flip across bands** (−2.69 / +0.87 / +10.52).
- **Riverine-mid** is, on the all-zones view, the *strongest* cell, not a weak one: +7.47 floor with flood_freq −1.37 (ungrazed slightly *drier* yet greener — the confound runs the wrong way). Yet it still collapses to **+0.12 at zone support** — which is the point: even the cleanest-looking cell does not survive an honest denominator.

## Result (spine §4 / S4–S5)

**No grazing effect on the floor is demonstrable.** The apparent Riverine signal is an artefact of pixel-weighting one green paddock (Bala 29ca); it collapses under block control and at zone support, and the four ungrazed paddocks are too heterogeneous (24.5–66.3 veg_p05) to attribute to treatment rather than paddock identity. **S5 is reported as null / not separable.** Inland-high's +5.4 is wetness-confounded (+11 pp wetter); Aeolian is a single paddock. The naive whole-farm +3.7 does not survive matching.

**Spine return:** *"Grazed/ungrazed floor difference not separable from paddock identity — the pixel-weighted Riverine signal is one paddock (Bala 29ca) and collapses at zone support (low +3.6, mid +0.1, high −2.1 pp, n = 3–4 ungrazed paddocks). S5 null pending block-controlled land-use data."*

## Limitation (for the limitations register)

**Prior land use cannot be excluded** as the source of the Bala-vs-rest and Bala 29ca-vs-26ca differences: `dim_management_zone.cropping_history` (and the four other history columns) are **NULL pending Ernest's land-use table**. Until that table exists, a paddock-identity difference cannot be separated from a treatment difference, so even a surviving contrast would be uninterpretable. This is the binding limitation on any S4/S5 grazing claim.

## Figure

`T1_D_matched_contrast.png` (via `write_and_register_figure()`, `support_level='pixel'`): per community, `veg_p05_delta` three ways — all-zones px (grey, confounded), Bala-only px (light green), Bala zone-support (dark green) — with the blue ✕ = `flood_freq_delta` and `nU=` labels. Riverine's grey +7.5..+8.3 visibly falls to the dark-green +3.6/+0.1/−2.1; Aeolian's tall bars carry `nU=1`.

## Acceptance

- [x] `v_zone_stratum_treatment_contrast`: nine non-treed strata; `flood_freq_delta` beside `veg_p05_delta`; `min_cell_n`; **`n_ungrazed_zones`/`n_grazed_zones` added**; `support_level='pixel'` + `aggregation_unit='zone_stratum'`.
- [x] Block-controlled (a) and zone-support (b) contrasts computed and reported beside the headline; `v_zone_stratum_contrast_bala_robust`.
- [x] `T1_D_matched_contrast.png` shows the collapse and the zone counts.
- [x] Idempotent; snapshot regenerated.

**STOP — T1 complete.** Not starting Gate D follow-ons or T5 Gates 2–4. Next: 66 D2 site dashboards + the 66-plot plot↔paddock join (reuse the Gate C `st_intersects` on `dim_plot` centroids reprojected 9473→8058; "not within a mapped paddock" path for the two `Standard grazing` plots incl. GA_032).
