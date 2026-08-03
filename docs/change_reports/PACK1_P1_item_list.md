# PACK-1 Gate P1 — the corrected item list · and Ruling E

**Date:** 3 August 2026 · **Prior:** `e8c2624`
**DB writes:** 2 canary pins only (Ruling E3), one transaction with probes either side.

---

## 1. Ruling E — parameterised, not unpinned

`RPTSCOPE_number_contract.csv`: **12 rows — 6 pinned · 5 parameterised · 1 text constant · ZERO UNPINNED.**
The queue is empty, and that is the finding.

**E2 — all 5 parameterised rows carry executable SQL**, not a description, so the report builder
reads the query *from the contract* rather than embedding its own. That is REP-PAGE4 generalised
from three constants to five queries.

**E3 — existence test first (I-39). 3 of the 5 canaries already existed and were NAMED, not duplicated:**

| page / panel | canary | |
|---|---|---|
| 1 · cover headline | `rptscope_canary_p1_paddock_floor_bala29ca` = **40.52** | **NEW** |
| 2 · flood frequency | `bala29ca_mean_flood_freq` = 8.5 | existed |
| 3 · community composition | `t10_refset_inland_share_bala29ca` = 34.6 | existed |
| 4 · this paddock's residual | `t10_bala29ca_xsec_residual` = −16.8 | existed |
| 5 · part states | `rptscope_canary_p5_recovering_parts_bala29ca` = **2** | **NEW** |

**Only 2 registered.** `dim_headline_number` **98 → 100**; `figure_asset`, `raster_asset`,
`table_asset`, `report_asset` all unmoved.

*Page 3's canary is registered against `census_by_zone_stratum` while the contract row queries
`v_zone_community_composition.share_a`. They agree (34.59 vs 34.6), so naming it is also a
cross-object check. Recorded rather than duplicated.*

**E4 reason recorded on both new rows** — Bala 29ca carries every reference-state result, is already
the most heavily pinned zone (24 rows), and is where a drift would be noticed first.

### The canaries are wired into the test, and one is proven to fire

Registering a canary the test never recomputes would have repeated **I-40** in the same session it
was logged. `recompute_rptscope_r2()` now runs **the exact contract SQL**. Fixture — flip one
Bala 29ca part out of *Recovering* on a throwaway copy:

```
DRIFT rptscope_canary_p5_recovering_parts_bala29ca: pinned=2.0 recomputed=1.0
```

**Coverage after E: 80 of 97 pinned = 82.5%. Value drifts: 0.**

## 2. P1-1 — register v3 §6 audited line by line

| candidate strike | verdict | evidence |
|---|---|---|
| P1: *"§6 says one item of eighteen / ships with seventeen"* | **STRIKE CONFIRMED** | §6 reads "sixteen items" / "fourteen distinct files". The only occurrence of "eighteen" in the file is the changelog recording the fix |
| P4 §3: *"do not use within 1.5 to 3.3 pp"* | **STRIKE CONFIRMED** | the string survives only in the changelog line recording its removal; asserted nowhere in the body |
| P3: M3's two undrawn clauses | **STRIKE CONFIRMED (partial)** | the caption now describes drawn content and **does note the saturation** — *"the brightest shading saturates where cover was high in every observed year"*. Clause-by-clause verification is P3's job; the rewrite has happened |
| P4 §2: the reproduction sentence | **REFUTED — NOT a strike** | see below |

### ⚠ §5's reproduction figures were wrong, and are corrected

v3 asserted **"88 rows"** and **"57 of 71 numbers independently re-derived"**, twice — in the
apparatus table and in the plain-language answer. **Both wrong**, and now stale as well.

**57 appears nowhere in the data**, and 71 was the count that *reproduces*, not the denominator.
Corrected in place, read from `RPTSCOPE_reproduction_status.csv` and **not** from the test's summary
string (I-36):

> **100 registered · 97 pinned · 80 recomputed and agreeing · 82.5% coverage · 0 value drifts**

A visible correction block is left in §5 rather than a silent edit. Note this moved during the
session: 98/95/78/82.1% after R2, 100/97/80/82.5% after E's two canaries.

**This is the fourth instance of I-40** in a different form: v3's changelog said "§5 counts updated",
and they *were* updated — to figures that were themselves wrong. **Recording the act is not the same
as the act being correct.**

## 3. P1-2 to P1-5 — the item list

`Output/pack/PACK1_item_list.csv` — **18 rows: 17 items + T1_render.**

| acceptance | result |
|---|---|
| 17 items | **OK** |
| 15 distinct non-null paths | **OK** |
| every path `exists = 1` on disk | **OK** |
| every path resolves in the registry | **OK — 0 unregistered** |
| no path under `docs/` | **OK — 0** |
| F7 shares M4's file | **OK — confirmed identical** |
| T3 carries no file | OK — `TEXT_ONLY`, the item is a table rendered in the workbook |

**M4b is in the list from the start** (D1/A3), not added at P2. **T1 is the `.csv`**; the `.png` is
row 18 as `T1_render`, marked *"listed as the rendering, NOT an eighteenth item"*.

**`ship_flag`** reads from `PACK1_input_delta_FROZEN.csv` for the 8 delta-backed rows; T1 takes SHIP
by the 2 August ruling; the two `(unlisted)` T6 rows are excluded as not pack items.

### ⚠ Four paths were guessed, and all four failed the disk check

The first run stopped with `M1`, `M2`, `F1`, `F2` **NOT ON DISK** — I had written plausible-looking
paths from memory instead of resolving them. **P1-5 is exactly the check that caught it.** All four
re-resolved from `PACK1_input_manifest_FROZEN.csv` and register v3 §3:

| item | guessed | actual |
|---|---|---|
| M1 | `T2_A_sampling_map.png` | `T1_A_zone_map_named.png` |
| M2 | `T2_C_regime_checkerboard.png` | `T2_G_plot_paddock_coverage.png` |
| F1 | `T2_E_paddock_floor_ranked.png` | `T2_E_paddock_trajectories.png` |
| F2 | `T2_E_paddock_floor_vs_flood.png` | `T2_E_paddock_trajectories_mean.png` |

Noted in the producer so the next reader knows the paths are resolved, not remembered.

### P1-5 — T3's post-freeze writes, recorded not re-frozen

Task T3 registered **10 figures and 5 rasters** after the manifest was frozen (`figure_asset`
287 → 297, `raster_asset` 186 → 191). **None is a pack item** — all are
`Output/figures/diagnostics/T3_*` sweep diagnostics. **The frozen manifest stays correct for P1's
purpose and was not re-frozen.**

## 4. Probes

| | `dim_headline_number` | `figure_asset` | `raster_asset` | `table_asset` | `report_asset` |
|---|---|---|---|---|---|
| before E3 | 98 | 297 | 191 | 4 | 59 |
| after E3 | **100** | 297 | 191 | 4 | 59 |

## STOP — end of P1.
