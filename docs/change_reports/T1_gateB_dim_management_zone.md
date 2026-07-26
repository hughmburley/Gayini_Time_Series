# T1 — Gate B: `dim_management_zone` built

**Date:** 25 July 2026 · **Spec:** `T1_zone_stratum_census_join.md` v3 + the 25 Jul verify-method refinement · **Status:** table built (additive, idempotent, convergent). **STOP before Gate B1 / Gate C.**
Script: `scripts/11_database/build_T1_gateB_dim_management_zone.py`. Sources: `Output/tables/T1_gateA_zone_areas.csv`, `Output/csv/MODIS/modis_context_units_summary.csv`. Evidence artefact: `Output/tables/T1_gateB_identity_assignment.csv`.

---

## What was built

`dim_management_zone`, **64 rows**, new table (nothing existing modified). Verified against the DB:

| check | result |
|---|---|
| rows | 64 |
| `zone_name` nulls | 0 — all real paddock names from `ManagmentZ` |
| `zone_group` | Bala 26 · Mara 24 · Dinan 14 |
| `grazing_treatment` | `14-day grazing` 60 · `No grazing` 4 (fids 1–4, Bala 26ca–29ca) |
| `has_rap_plots=1` | 19 (the `Plots='Sample'` zones) |
| both area columns + `area_ha_diff_pct` | populated on all 64; diff −0.277…−0.211% (the systematic projection offset, Gate A step 6) |
| `unit_id` / `unit_id_verified` / `unit_id_margin_pct` / `unit_id_verify_method` | populated on all 64 |
| RESERVED land-use columns (5) | present and NULL on all 64 |

**Idempotence — by convergence, not stability** (per CLAUDE.md, using `INSERT OR REPLACE`):
- `execute` twice → 0→64 then 64→64.
- `convergence` mode: mutated `zone_fid=1` area to 2183.10, re-ran → DB **moved to** the new value; re-ran the true build → **converged back** to 2059.65. Confirms the upsert converges; `OR IGNORE` would have frozen the stale value and silently passed a stability-only test.

---

## Zone identity — how it was verified, and a finding that overturns a v3 assumption

**Verdict: all 64 `unit_id_verified = 1`.** The method column records *which* evidence carries each zone — a distinction that is the whole reason the column exists:
- **`provenance+area` — 62 zones.** Held by two independent lines: the assignment uniquely pins them to identity *and* provenance.
- **`provenance_only` — fid 9 (Bala 5), fid 21 (Bala 23).** Area-twins the assignment cannot orient; held by provenance alone. A future reader can find them in one query: `WHERE unit_id_verify_method = 'provenance_only'`.

Two independent lines, and they matter individually:

**1 · Provenance (by construction).** The MODIS `management_zone_i` units are built in `R/vector_prep_functions.R::gayini_make_modis_context_units` by `st_intersection` of the **same source shapefile the 8058 gpkg derives from** (`CA0561_ManagementZones.shp`) with the farm boundary, then labelled `management_zone_<seq_len(nrow)>` because **no id field matched** the candidate list. The CSV's `source_name = "1".."64"` (integers, not paddock names) confirms the `seq_len` branch was taken. So `management_zone_i` = positional feature *i* = gpkg `fid i`, by construction — contingent only on order preservation.

**2 · Global assignment (empirical anchor + the finding).** The 64×64 area-error matrix (MODIS `area_ha` vs `area_ha_computed`, not `Area_MW`) solved by `linear_sum_assignment`:
- **62 of 64 zones are uniquely pinned to identity.**
- **The LP-optimal is *not* the identity permutation** — it swaps exactly one mutual pair, **`9↔21`** (Bala 5 ↔ Bala 23), because those two are area-twins (both ≈1520 ha to within 1 ha). The swap is cheaper by **0.000033 pp** — numerical noise.

**This overturns the v3 expectation** that the bijection would "resolve idx 21 / idx 30 by exclusion." It does not: `{9,21}` are *mutually* exchangeable at equal area-cost, so the assignment has two near-degenerate optima and picked the swapped one. (Note idx 30 *did* resolve to identity globally — the Gate A per-zone flag on it was a per-zone artefact.) **Relying on the assignment alone would fail exactly the two zones provenance is needed for**, and a literal "`verified = 1` iff assignment == identity" rule would have failed **all 64** on a 3×10⁻⁵ pp tie.

**The closure that makes it airtight.** Two arguments, either sufficient:
- **Mechanism.** The seq→fid map is whatever permutation the derivation steps (reproject, clean, gpkg import) induce. Those steps either preserve all ordering (reprojection, format conversion) or reorder everything (a sort). **No ordinary operation produces a 2-cycle and nothing else.** A step that preserved order on 62 features and transposed exactly two is not a plausible mechanism — so the map is the identity, and the `9↔21` LP swap is degeneracy in the *scoring*, not evidence of a real transposition.
- **Combinatorial.** The assignment fixing 62 of 64 positions means the permutation is identity on 62 elements; a bijection fixing 62 of 64 either fixes or swaps the remaining two, and the monotonic `seq_len` construction forbids the swap.
- **Empirical (added at review).** The EPSG:28355 map companion in `Gayini_Results.gpkg` — a *separately derived* product — agrees with the 8058 layer on `fid → name → treatment → plots` for all 64, including fids 1–4, 9, 21. Two independent derivations agreeing on `fid` confirms `gpkg fid = source position`, the one step provenance-by-construction could not prove on its own.

**Therefore identity holds for all 64**, with provenance load-bearing precisely on `{9,21}`. The assumed-partner residuals are a tight band (0.131–0.152 pp) — a scrambled permutation would give a ragged spread, not a band; that tightness is the evidence, and it belongs on `T1_A_identity_margin.png`.

**Queryable homes (not prose-only).** The global assignment gap (`+0.000033 pp`), the twin fids, the residual band, and the `unit_id_margin_pct` sign convention are stored in a new one-row table **`t1_zone_identity_check`** (additive). The per-zone evidence is in `Output/tables/T1_gateB_identity_assignment.csv`. `unit_id_margin_pct`'s sign convention is also in the `dim_management_zone` DDL comment: **negative = a competitor fid is closer in area than the assumed partner** (an area-twin), which beside `unit_id_verified = 1` is expected, not a bug.

---

## Judgment calls — resolved at review

1. **Verification policy — split the method** (as directed). All 64 `verified = 1`; `unit_id_verify_method` is `provenance+area` on the 62 area-pinned zones and `provenance_only` on fids 9, 21. This overrides the literal v3 "`verified = 1` iff the global assignment is the identity" rule, which the `9↔21` degeneracy would fail on numerical noise.
2. **`unit_id_margin_pct` = per-zone area margin — accepted as-is.** v3's "global cost gap per row" would read ≈0 everywhere and imply "all weak"; the per-zone margin instead surfaces the twins (fid 9 +0.0585, fid 21 −0.0585). Sign convention documented (above and in the DDL). The global gap lives in `t1_zone_identity_check`.

---

## Deferred to Gate B1 (per your sequencing — not done here)

- `ALTER TABLE figure_asset ADD COLUMN support_level TEXT, figure_level TEXT`.
- `ALTER TABLE spatial_layer_asset ADD COLUMN checksum_sha256 TEXT, path_exists INTEGER`, then **migrate `spatial_006`'s checksum + `path_exists` out of the `note` field** into the real columns.
- Record both ALTERs in the post-build chain (a rebuild would drop them).
- `write_and_register_figure()` (R, first-50-MB SHA-256, `INSERT OR REPLACE`), then the A0/A/B gate figures — which is why **no figures were written in Gate B**.

**STOP.** Awaiting review before Gate B1 writes or Gate C begins.
