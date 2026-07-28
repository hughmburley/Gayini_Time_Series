# T8 Gate B — pre-write checks; sixth pin raised (STOP)

**Task:** reference-state T8, per `T8_gateA_pin_decisions.md` v1 (auth) > `T8_T9_T10_gateA_decisions.md` v1 > spec v1.
**Date:** 28 July 2026 · **Prior:** SHA ec81bdc
**Scope:** PIN 4 re-derivation + PIN 1/PIN 5 pre-write checks. **READ-ONLY — no DB write.** Gate B write **halted at the PIN 1 sixth-pin STOP.**
**Verification:** live query / spatial-join / raster output; paths from `raster_asset` / `spatial_layer_asset`.

Session start: on `main`, up to date with `origin/main`, main has not moved.

---

## PIN 1 — sixth pin raised → **STOP before Gate B writes**

PIN 1 pinned the band mean for #6/#7/#9 and required reporting it **equal-weighted and area-weighted** across the three bands, with the rule: *if they differ by >1 pp, that is a sixth pin — stop before Gate B writes.* Result (not_grazed unless noted, `window='all'`, bands only; area weights = non-treed census area per community×band from `census_by_zone_stratum`):

| number | community / arm | equal-weighted | area-weighted | diff |
|---|---|---|---|---|
| **#6 mean cover** | Aeolian | −2.47 | −2.32 | −0.16 |
| | Riverine | +1.43 | +1.41 | +0.02 |
| | Inland | +0.45 | +0.45 | −0.00 |
| **#7 floor** | Aeolian | −11.17 | −10.46 | −0.70 |
| | Riverine | −4.38 | −4.49 | +0.11 |
| | Inland | +1.08 | +1.08 | +0.00 |
| **#9 floor, mean over 9 strata** | not_grazed | **−4.82** | **−0.92** | **−3.91** |
| | unzoned_inferred_standard | **+4.26** | **+1.17** | **+3.10** |
| | unzoned_plot_confirmed | **+5.92** | **+1.32** | **+4.60** |

**#6 and #7 agree** under either weighting (≤0.70 pp) — those pin cleanly. **#9 does not** — the three-arm floor-deficit headline moves from **−4.8/+4.3/+5.9 (equal)** to **−0.9/+1.2/+1.3 (area)**, a 3.9–4.6 pp swing. Cause: equal weighting gives each of the 9 strata equal say, so the small Aeolian strata (large deficits) count fully; area weighting pulls toward the large near-zero Inland strata. Both are defensible (both average already-within-band-controlled deficits), so this is a genuine curation choice, not a confound.

**Consequence:** the equal-weighted values reproduce the current deck (−4.8/+4.3/+5.9). Area weighting would strengthen the qualitative story ("grazing intensity does not order the floor" — all three arms near zero) but change the printed numbers materially. **This is a sixth pin. Gate B is halted per PIN 1 until the design seat chooses equal or area weighting for #9.**

---

## PIN 4 — re-derived; deck confirmed (no error)

Independent centroid-in-polygon join: `dim_plot` centroids reprojected **EPSG:9473 → 8058** (per the four-CRS rule), point-in-polygon against `management_zones_8058.gpkg` (`spatial_006`; `fid`=`zone_fid`, `ManagmentZ`=`zone_name` confirmed):

| reference paddock | plots (independent join) |
|---|---|
| Bala 26ca (fid 1) | 3 |
| Bala 27ca (fid 2) | 0 |
| Bala 28ca (fid 3) | 8 |
| **Bala 29ca (fid 4)** | **13** |
| **total** | **24** |

**13 of 24 (54%) in Bala 29ca is correct** — deck slide 5 and the T2_G annotation stand. The join reproduces the existing `plot_paddock` table with **zero mismatches** across all 66 plots, so `plot_paddock` is a valid spatial join (not the class-based `plot_management_overlay`). The additive paddock-identity column on `plot_management_overlay` is deferred to the Gate B write (halted).

---

## PIN 5 — three numbers, discrepancy resolved (read-only; write deferred to Gate B)

| number_id (proposed) | value | source | check |
|---|---|---|---|
| unzoned **inside** mapped census | 194,865 px · **12,150.1 ha** · 18.0% of mapped | `census_by_zone_stratum`, `zone_fid IS NULL` | live |
| property **outside** mapped census | 18,561.5 ha · 21.6% of property | 85,910.8 − 67,349.332 | live |
| total in **no** management zone (derived) | **30,711.6 ha · 35.7% of property** | (inside)+(outside), disjoint | 12,150.1 + 18,561.5 |

**The 12,179 vs 12,150 discrepancy is the pixel-area constant.** 194,865 × **0.0625** = 12,179.1 ha (the T1-spec figure, using the *wrong* nominal 25 m); 194,865 × **0.062351428** (`gayini_params.PIXEL_AREA_HA`, derived from 24.970268 m) = **12,150.1 ha**. **12,150 ha is correct**; the T1 spec's 12,179 rode in on the `0.0625` error (C-08). The 35.7% "over a third of the property is in no paddock" figure is new to both deck and methods and should appear in both (design-seat action).

---

## State at STOP
- **No DB write.** `dim_headline_number` not created; `is_rollup` not yet added; no additive column written. All deferred behind the sixth pin.
- Writes this session: this change report only.
- PIN 2 (#1 → −13.1, spread −9.1..−14.8) and PIN 3 (#2/#3/#4 → NULL, blocked I-29) are unaffected and ready to write once the sixth pin clears.

## What I need
**Sixth pin (#9):** equal-weighted (−4.8/+4.3/+5.9, matches deck) or area-weighted (−0.9/+1.2/+1.3) mean over the 9 strata? This is the only blocker on the Gate B write; #6/#7 pin cleanly either way. On your answer I write `dim_headline_number` (Gate B), add `is_rollup` (Gate D), add the paddock-identity column (PIN 4), then proceed to T10 Gate B+C.
