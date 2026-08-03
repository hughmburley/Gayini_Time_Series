# RPT-SCOPE Gate R2 — THE WRITE. 10 pins registered.

**Date:** 3 August 2026 · **Prior:** `b459f76` · **Producer:** `scripts/11_database/write_RPTSCOPE_R2.py`

---

## 1. Ruling B — my F6 finding is WITHDRAWN. You were right.

`scripts/12_zone_stratum/T6_gateE_figures.R` **line 162**, quoted:

```
"floor within stratum (above in 6 of 9 strata; plot-confirmed above in 8 of 9), inconsistent with heavier grazing degrading\n",
```

The matched pair, exactly as you said. And the producer:

- references `v_zone_stratum_contrast_bala_robust` and `veg_p05_mean` **zero times**
- reads `fact_three_arm_stratum_veg_annual` … `veg_p05_spatial` (line 18) and `fact_three_arm_gap_decomposition` (line 33)
- touches `census_by_zone_stratum` **only** for `SUM(area_ha)` (line 36) — an area weight, not a veg metric

The two pins it pairs are `three_arm_unzoned_inferred_above_14day_count = 6.0` and
`three_arm_unzoned_plot_above_14day_count = 8.0`, both `source_object = v_three_arm_gap_decomposition`.

**F6 is on `veg_p05_spatial` throughout. It ships unchanged, and the contingent ruling never fires.**

**What I actually hit was a numeral collision** — two different "6 of 9"s: F6's, from
`v_three_arm_gap_decomposition` on `veg_p05_spatial`, and BYQ-Q2a's, from
`v_zone_stratum_contrast_bala_robust` on `veg_p05_mean`. I conflated them. **Appended to I-37.**
The claim audit's BYQ-Q2a note said "F6's caption re-verifies it" — **corrected**; F6 draws a
different number.

## 2. Ruling A — the four withdrawn, gate settled at 10

`ref_set_internal_spread_riverine_{high,low,mid}` and `ref_set_spread_exceeds_contrast_multi_count`
are **withdrawn, not deferred**. They remain SOURCED in `RPTSCOPE_claim_audit.csv`, now registered
in `table_asset` — that is their provenance record. By_question Q2 stays in the UNSUPPORTED queue
with no wording attempted.

## 3. The write — one transaction

```
PROBE before: dim_headline_number=88 · figure_asset=297 · raster_asset=191 · table_asset=2 · report_asset=59
              db_mtime=2026-08-03 13:35:58
  target tables at 88 and 2 as expected - proceeding
  inserted 10 pins
  number contract: 12 rows, 6 UNPINNED
  registered 2 table_asset rows
  COMMIT
```

| acceptance | result |
|---|---|
| `dim_headline_number` 88 → **98** | **OK** |
| `table_asset` 2 → **4** | **OK** |
| no existing row modified | OK — inserts only |
| no new `number_id` duplicates an existing one | OK — pre-checked, and 0 duplicates registry-wide |
| five qualifiers, no NULLs and no blanks | **OK — 0 rows** |
| every derivation states its route or declares none | OK — 7 routes, 3 declared |
| contract resolves every page 1–5 number | OK — 12 rows, 6 pinned, 6 UNPINNED |

**Post-write probe:** 98 · 297 · 191 · 4 · 59. `figure_asset`, `raster_asset` and `report_asset`
unmoved — this gate touched only its two target tables.

## 4. ⚠ Coverage — I predicted 82.1%, first got 75%, and the gap was mine

The 7 independent derivations were written into `decision_note` **but never wired into the test**,
so all 10 pins initially counted as `NO_DERIVATION_PATH` and coverage fell to 71/95 = 75%.
**Documenting a derivation is not implementing one.** Fixed by adding `recompute_rptscope_r2()` to
`test_T8_headline_reproduction.py`.

| | pinned | recompute + agree | coverage |
|---|---|---|---|
| before R2 | 85 | 71 | 83.5% |
| after the write, derivations **documented only** | 95 | 71 | 75.0% |
| **after wiring them in** | **95** | **78** | **82.1%** |

**COVERAGE = 78 of 95 pinned rows = 82.1%** (78/98 = 80% of registered rows).

**VALUE DRIFTS = 0.** All 17 failures are missing derivations. **That is the figure that says
nothing has moved**, and it must sit beside the coverage fraction on `How_we_know`.

## 5. Ruling C — sentinel applied

`pixel_constant = 'n/a - no pixel-to-area conversion in this quantity'` on all 9 zone-support rows;
`t13_recovering_survive_drop2wettest` carries the real `0.062351428`. **Zero blanks.**

*Note: `pixel_constant` is declared `REAL`. SQLite stores the sentinel as TEXT without complaint,
but the column type and its contents now disagree. Flagged, not fixed — changing a registry column
type mid-delivery is not a R2 operation.*

## 6. Ruling D — T3 threshold sensitivity, derived

From `t3_always_green_sweep`, scope `non_treed`, metric `total_cover_floor`, 51 thresholds 40–90.

| statistic | value |
|---|---|
| area at threshold 40 → 88 | 50,854 ha → 0.4 ha; **zero at 89** |
| monotonic non-increasing | **yes**, strictly decreasing wherever area > 0 |
| elasticity d(log A)/d(log T) | median **−5.0** (min −172, max −0.7) |
| plateau in the interior | **none** — every 1 pp step changes the area |
| **band 50–80** | **40,936 → 4,179 ha · 9.8× · a 36,757 ha range** |
| band 60–80 | 28,350 → 4,179 ha · 6.8× |
| band 70–80 | 12,641 → 4,179 ha · 3.0× |
| at the operational 75 | **8,300 ha** |

**The condition fired.** A 1% rise in the threshold moves the area by ~5%. Around the operational
cut, ±5 pp swings the answer by a factor of **3** (12,641 ha at 70, 8,300 at 75, 4,179 at 80). No
knee, no plateau, no bimodality — a smooth monotonic decline. `is_selected_threshold` carries
`selection_role = 'operational_lidar_input'` only; **no headline threshold was set.**

**This is a P4 input and it is stronger than the reproduction test**: reproduction shows the numbers
are stable, this shows they were **not fitted**. Numbers reported; **no pack wording drafted** — that
is P4, at the design seat.

## 7. Probes

| | `dim_headline_number` | `figure_asset` | `raster_asset` | `table_asset` | `report_asset` |
|---|---|---|---|---|---|
| before | 88 | 297 | 191 | 2 | 59 |
| after | **98** | 297 | 191 | **4** | 59 |

No unexpected movement. The audit session did not write during the window.

## STOP — end of R2.
