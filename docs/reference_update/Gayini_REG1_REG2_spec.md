# REG-1 and REG-2 — registration and plumbing for the report batch

**Version:** v1 · 29 July 2026
**Spine:** `docs/reference_update/Gayini_path_to_Aug10_tracker.xlsx`, Tasks sheet, P-rank 1 and 2
**Depends on:** T8, T10 (complete). Nothing else.
**Blocks:** pages 3 and 4 of every paddock report, and the report batch's dominance branching.
**Deadline context:** 10 August is hard. These two are the highest-consequence items on the
board because two of the five pages of every paddock report cannot ship without them.

**Gates carry expected values.** Where a number is stated below, that is the target — hit it and
say so, miss it and **STOP and report the difference. Do not adjust the method to reach the
expected value.** A mismatch is a finding.

Standing rules: additive writes only · never re-run the builder · resolve paths from the
database · never merge support levels in one figure · commit to main and push per gate per
CLAUDE.md · re-read this spec in full and echo it verbatim at the start of every gate.

---

# REG-1 — register the intercept, promote the T10 tables

## Why

The report stream's pages 3 and 4 currently draw an expectation line whose intercept is not
registered, and read per-paddock residuals out of a CSV rather than the database. Both are
blockers on a client deliverable. Neither is analysis — the numbers exist and reproduce; they
need to become queryable objects.

## Gate A — recon · STOP

No writes.

1. Confirm `dim_headline_number` holds `floor_flood_slope_64pdk` and `floor_flood_r_64pdk`,
   and report their `pinned_value`, `spread_min`, `spread_max` and `scope_filter` verbatim.
2. Recompute the bivariate fit from `fact_zone_veg_annual` (`series_variant = 'mean_of_seasons'`,
   paddock means over all 35 years, n = 64) and report **intercept, slope, r, SE(slope) and
   residual SD**.

**Expected:** intercept **52.6529**, slope **0.5478**, r **0.7096**, SE(slope) **0.0691**,
residual SD **6.6208**. Sanity check: predicted floor at flood = 8.5% is **57.31**, against Bala
29ca's observed 40.5.

3. Confirm the three T10 output CSVs exist and report their row counts:
   `T10_gateC_crosssectional_residuals.csv` (**expect 64**),
   `T10_gateC_temporal_table.csv` (**expect 64**),
   `T10_gateC_percommunity.csv` (**expect 115**).

**STOP.**

## Gate B — register the intercept

Additive row in `dim_headline_number`:

```
number_id      floor_flood_intercept_64pdk
label          Expectation-line intercept, paddock floor on mean annual inundation
source_object  fact_zone_veg_annual
grain          paddock (64), 35-year means
aggregation_order   paddock mean then OLS across paddocks
series_variant mean_of_seasons
scope_filter   series_variant='mean_of_seasons'; all 64 zones
pinned_value   52.6529
spread_min/max from the same three alternative fits used for the slope
               (bivariate / +community / within-Inland) — report all three intercepts
decided_by     CC
decision_note  Companion to floor_flood_slope_64pdk. Together these draw the expectation line
               used on paddock report page 4. Predicted floor = intercept + slope * flood_frac_pct.
```

Also register **residual SD (6.6208)** as its own row — the report needs it to say whether an
individual residual is large, and quoting a residual without its scale is the failure mode this
table exists to prevent.

## Gate C — promote the three tables

Additive, one table each, plus a labelled view. Follow the naming and column conventions of the
existing `fact_*` / `v_*` pairs.

| new object | from | rows | grain |
|---|---|---|---|
| `fact_zone_floor_flood_residual` | cross-sectional CSV | 64 | paddock |
| `fact_zone_floor_temporal` | temporal CSV | 64 | paddock |
| `fact_zone_community_part_summary` | per-community CSV | 115 | paddock × community |

Every row carries `support_level`, `aggregation_unit`, `series_variant` and `run_id`, per the
existing pattern. **Do not drop or rename any column present in the CSVs** — the report stream is
already reading them by name.

`fact_zone_community_part_summary` is the substrate T13 will consume, so it matters that it is a
first-class object rather than a file.

## Gate D — extend the reproduction test · STOP

`test_T8_headline_reproduction.py` gains the intercept and residual-SD rows. Confirm it still
passes and still fires on `--break`.

**Expected after this gate:** 58 reproducible rows (56 + 2). Report the count.

**STOP.**

## Acceptance

- [ ] Gate A expected values hit, or the difference reported
- [ ] Intercept and residual SD registered with spread and scope
- [ ] Three tables promoted, row counts 64 / 64 / 115, no column dropped or renamed
- [ ] Views created and labelled
- [ ] Reproduction test passes at 58 rows and fires on the fixture
- [ ] No builder run, no row deleted, no rename of existing objects
- [ ] Change report in `docs/change_reports/`

---

# REG-2 — paddock composition view, with dominance, at three denominators

## Why

The report batch has to branch on how mixed a paddock is — page 3 shrinks to a single line for a
single-community paddock and expands to three parts for Bala 29ca. Without a view it re-derives
composition, and two streams deriving the same quantity differently is precisely how this
project acquired a provenance audit.

There is also a live disagreement to settle. The reference-state stream counted **14** paddocks
below 75% dominance; the report stream counted **17**. Both are correct for their own
denominator, and neither stated it.

## Gate A — build the view · STOP

One view, `v_zone_community_composition`, at **paddock × community**, carrying the share under
**three denominators side by side**, because different consumers need different ones:

| denominator | scope filter | what it answers |
|---|---|---|
| **A · focus-3 non-treed** | `treed_context_flag=0 AND regime_band<>'context'` | the analysis scope — what every RS number is computed on |
| **B · all non-treed** | `treed_context_flag=0` | adds *Other / minor units* |
| **C · whole paddock** | no filter | adds *Floodplain Woodland / Forest*; sums to the whole paddock |

Columns: `zone_fid`, `zone_name`, `community`, `n_pixels_a/b/c`, `share_a/b/c`, plus per-paddock
`dominance_a/b/c` (the maximum share) and `dominance_class_a/b/c` in
`{single, high, moderate, mixed}` at cuts 100 / 90 / 75 / 60.

**Expected paddock counts** (all 64 zoned paddocks):

| denominator | < 75% dominance | < 60% | single-community | total px zoned |
|---|---|---|---|---|
| A focus-3 non-treed | **14** | **9** | **26** | 795,602 |
| B all non-treed | **16** | **9** | **25** | 800,340 |
| C whole paddock | **22** | **15** | **19** | 885,292 |

**STOP.**

## Gate B — reconcile the 14 / 16 / 17 · STOP

The report stream reported 17 and named **Bala 1** (72% Inland, 26% Other) and **Mara 5a** (71%
Inland, 29% Other) as the two that move from 14. That gives 16, and denominator B above also
gives 16.

**One paddock is unaccounted for.** Identify it, or establish that the count of 17 came from a
fourth scope we have not reproduced.

**Report which. Do not adjust either count to make them agree.** If the report stream's 17 is
right and our 16 is wrong, that is the finding and we want it before the batch runs, not after.

**STOP.**

## Gate C — register the counts

Additive rows in `dim_headline_number` for the dominance counts at denominator A, with B and C as
`spread_min`/`spread_max`, and `decision_note` naming which denominator each consumer should use:

- **A for analysis.** Every RS number is computed on this scope.
- **C for client text.** Shares that sum to the whole paddock are more honest than shares
  renormalised onto the analysed subset. A reader told "58% Riverine, 37% Inland" will take that
  to be the paddock, not the part of it we chose to analyse.

This is a recommendation to record, not a decision to enforce — the report stream chooses, and
the view gives them all three.

## Acceptance

- [ ] `v_zone_community_composition` exists, 64 paddocks, three denominators, dominance and class
- [ ] Gate A expected counts hit, or differences reported
- [ ] The 17th paddock identified, or the discrepancy explained
- [ ] Dominance counts registered with denominator named in `decision_note`
- [ ] No existing object modified
- [ ] Change report in `docs/change_reports/`

---

## Exit condition for both

One review bundle, `Output/review_bundles/reg1_reg2_report_plumbing.zip`:
`dim_headline_number` rows added, the three promoted tables as CSV, the composition view as CSV,
the Gate reports, and the reproduction-test output at 58 rows.

**Then STOP.** T14 (part-grain expectation) and T13 (paddock-part classification) are specified
separately and follow. Do not start either from this session.

## Note on what comes next, so the shape is visible

T13 must run **before** the land-use history arrives from Ernest — it classifies paddock-parts
using only cover and water, and a classification fixed before the land-use labels exist makes
the coincidence test blind. `fact_zone_community_part_summary` from REG-1 Gate C is its
substrate, which is why that table is worth promoting properly rather than reading a CSV.
