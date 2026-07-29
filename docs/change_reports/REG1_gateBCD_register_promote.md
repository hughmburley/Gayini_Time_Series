# REG-1 Gate B/C/D — register the intercept + SDs, promote the three tables

**Task:** REG-1, per `Gayini_REG1_REG2_spec.md` v1 + the design-seat residual-SD ruling (29 Jul).
**Date:** 29 July 2026 · **Prior:** SHA bb448b0 (Gate A)
**Scope:** Gate B (register), Gate C (promote), Gate D (extend test, STOP).
**Additive only:** 3 new `dim_headline_number` rows, 3 new fact tables + 3 views, test extended. No builder run, no existing object modified, no row deleted, no rename.

Session start: on `main`, up to date with `origin/main`, main has not moved.

## Gate B — three rows registered (per the ruling, not two)

`build_REG1_gateB_register.py`. All values computed live from the 64-paddock bivariate fit.

| number_id | pinned | spread | note |
|---|---|---|---|
| `floor_flood_intercept_64pdk` | **52.6529** | 52.6529 … 54.7363 | alt-fit intercepts: bivariate 52.6529, +community 54.7363, within-Inland 54.5840. Draws the page-4 expectation line with the slope. |
| `floor_flood_residual_sd_64pdk` | **6.6208** (ddof=0) | 6.6208 | descriptive scale; caveat explains why not ddof=1 |
| `floor_flood_rse_64pdk` | **6.7268** (ddof=2) | 6.7268 | regression residual standard error; pairs with SE(slope)=0.0691 |

**The residual-SD ruling implemented in full:**
- **6.6208 (÷n)** registered as the *descriptive* scale — the 64 paddocks are every management zone on Gayini, a census, so the population SD honestly describes the spread a report reader needs beside a −16.8.
- **6.7268 (÷n−2)** registered *separately* as `floor_flood_rse_64pdk` — the regression's own residual standard error, the pair to `SE(slope)`; the number for a prediction interval on the expectation line. **Not folded into the descriptive row.**
- **6.6732 (÷n−1)** recorded in the descriptive row's caveat *with the reason it is not used*: Task J pre-registered ddof=1 ranking because its 24 placebo dates were a genuine sample from a larger set of possible dates; 64 of 64 paddocks are not a sample. Different situation, different convention — stated so a future reader does not read one as an error.
- `decision_note` carries the settling line: **Bala 29ca sits 2.50–2.54 SD below expectation under all three conventions** (ddof 0/1/2 = **2.54 / 2.52 / 2.50**, verified live; residual −16.80). The choice is a convention question, not a result question.

## Gate C — three tables promoted (additive, columns preserved)

`build_REG1_gateC_promote.py`. Each CSV → a new fact table (every CSV column preserved by name — the report stream reads them by name — plus `support_level`/`aggregation_unit`/`series_variant`/`run_id`) and a labelled passthrough view.

| table | view | rows | cols | grain |
|---|---|---|---|---|
| `fact_zone_floor_flood_residual` | `v_zone_floor_flood_residual` | 64 | 12 | paddock |
| `fact_zone_floor_temporal` | `v_zone_floor_temporal` | 64 | 17 | paddock |
| `fact_zone_community_part_summary` | `v_zone_community_part_summary` | 115 | 20 | paddock × community |

`support_level='pixel'`, `series_variant='mean_of_seasons'`, `run_id='REG1_gateC_20260729'`; `aggregation_unit` = `zone` / `zone` / `zone_community` (matching the existing `fact_zone_*` convention). `fact_zone_community_part_summary` is the T13 substrate — now a first-class object, not a file.

## Gate D — reproduction test extended · STOP

`test_T8_headline_reproduction.py` gains `recompute_reg1()` (intercept, residual SD ddof=0, RSE ddof=2 from an independent re-derivation).

```
$ python scripts/11_database/test_T8_headline_reproduction.py
T8 reproduction: PASS - all 59 pinned numbers reproduce within tolerance   (exit 0)
$ python ... --break
[--break fixture] checked 59; DRIFT rows: 1   (drift caught; real DB untouched)
```

**Count is 59, not the 58 the spec states — flagged so it does not read as drift later.** The spec anticipated 2 new rows (intercept + residual SD); the ruling added a third (`floor_flood_rse_64pdk`), so 56 + 3 = **59**. This is the ruling's consequence, recorded here per instruction.

## Acceptance
- Gate A expected values hit (prior report); intercept/SDs reproduce exactly.
- Intercept and both SD rows registered with spread, scope, denominator named.
- Three tables promoted, 64 / 64 / 115, **no column dropped or renamed** (asserted in the builder), views created.
- Reproduction test passes at **59** and fires on the fixture.
- `dim_headline_number`: 59 → **62 rows**. No builder run, no row deleted, no rename. Idempotent.

## STOP (Gate D)
REG-1 complete. Proceeding to REG-2 (pre-authorised) — the composition view at three denominators and the 14/16/17 reconciliation — reporting at its STOPs.
