# T13 Gate A — annual flood at part grain

**Task:** T13, per `Gayini_T13_spec.md` v1.
**Date:** 29 July 2026 · **Prior:** SHA 66efd53
**Scope:** Gate A — build the part-grain annual flood table, reconcile, STOP.
**Additive:** one NEW table. No builder run, `fact_zone_community_veg_annual` untouched.
**Verification:** live extraction + reconciliation output below.

Session start: on `main`, up to date with `origin/main`, main has not moved.

**Pre-registration honoured:** nothing in §5/§6 is touched at this gate; this is the flood substrate only. The design-seat pilot cuts (8 pp / 0.25 pp/yr → 7/17/8/83) are abandoned and not reproduced.

## What was built

`fact_zone_community_flood_annual` — wet/valid annual counts at **paddock × community × water year**, extracted at the 795,602 in-scope zoned census centroids (`T2_in_scope_points.csv`), same encoding as `T2_gateB_extract.R`: `valid_any == 1`, `wet_any == 1`. Rasters resolved from `raster_asset` (`raster_08058_wet` / `raster_08058_valid`; I-21). One additional grouping key (community) over the existing T2 inundation pass.

- **118 parts** (zone × community with in-scope pixels) × 35 water years = **4,130 rows**.
- Columns: `zone_fid, community, water_year, wet_pixels, valid_pixels, flood_frac_pct`, + `support_level='pixel'`, `aggregation_unit='zone_community_year'`, `run_id='T13_gateA_20260729'`.
- `fact_zone_community_veg_annual` **not modified**; builder **not run**.

## Reconciliation — exact

Summing part-grain wet/valid across communities within each paddock-year against `fact_zone_veg_annual` (paddock grain, `mean_of_seasons`):

| check | result | expected |
|---|---|---|
| max \|wet diff\| | **0** | 0 |
| max \|valid diff\| | **0** | 0 |
| unmatched paddock-years | **0** | 0 |

The part grain partitions the paddock exactly — every in-scope pixel belongs to exactly one community, so the community counts sum to the paddock counts with no residual. No difference to absorb.

## Coverage note

Parts meeting the Gate B support rule (≥25 years of ≥30 valid pixels): **115** — matching `fact_zone_community_part_summary` (115) exactly. The 3 additional parts in the flood table (118 − 115) are sub-support fragments (e.g. Mara 3's single-pixel Aeolian) that fall out at Gate B's support filter; they are retained in the raw flood series and excluded downstream by the same rule.

## Why this table is necessary (from §3)

`fact_zone_community_veg_annual` carries no wet/valid columns and `census_by_zone_stratum` holds only a static 35-year flood frequency. Without an annual flood series at part grain, a part that is merely getting wetter is indistinguishable from one recovering — the confound T10 removed at paddock grain. This table is the input to Gate B's `water_slope` / `trend_adj`.

## STOP
Part-grain flood table built; reconciliation exact (0/0/0). No writes beyond the new table. Waiting for review before Gate B (the continuous measures: `level`/`level_z`, `trend_adj`/`trend_z`, per 115 parts, community-scaled, current vs lagged water).
