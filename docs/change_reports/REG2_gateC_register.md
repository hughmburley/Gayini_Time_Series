# REG-2 Gate C — register the dominance counts and the supported-parts field

**Task:** REG-2 Gate C, per `Gayini_REG1_REG2_spec.md` v1 + design-seat rulings 1 & 2 (29 Jul).
**Date:** 29 July 2026 · **Prior:** SHA 16e492a (REG-2 Gate A/B)
**Additive:** `v_zone_community_composition` gains one column; six `dim_headline_number` rows; test extended. No existing object modified, no builder run.

Session start: on `main`, up to date with `origin/main`, main has not moved.

## Ruling 1 — dominance registered literally; the report branches on supported parts

The single-community definition dispute was **one paddock, one pixel**: **Mara 3** is Inland 99.98% + Aeolian **1 pixel** (0.019%) — a vegetation-mapping edge effect, not a recognisable second part. Verified live.

- **(a) `dominance` registered literally, no threshold.** `reg2_paddocks_single_community` pinned **25** (denom A; B=23, C=18 in the spread). No 99.9% cut adopted — thresholds chosen after seeing the data are the project's recurring defect (I-29, the hand-picked paddock-part cuts).
- **(b)** `decision_note` records that the sole literal-vs-99.9% disagreement is Mara 3 at one pixel, and that no threshold was adopted deliberately.
- **(c) `n_parts_supported` added to `v_zone_community_composition`** — count of communities per paddock meeting the *existing* support rule (`n_pixels_valid>=30` in `>=25` years, from `fact_zone_community_part_summary`). Distribution **27 / 23 / 14** (one / two / three parts), 64 paddocks, 115 parts — matches `fact_zone_community_part_summary` exactly. Registered as `reg2_paddocks_{1,2,3}part_supported`.
- **(d)** The report batch must branch page 3 on **`n_parts_supported`, not `dominance_class`.** Dominance is descriptive; supported parts is operational and needs no threshold. **Mara 3 has 1 supported part → single-line page 3 regardless of the dominance definition** — the one-pixel question is moot, not adjudicated. (Recorded in the operational rows' `decision_note`; design seat is telling the report stream the same.)

## Ruling 2 — the <75 count registered at 16 (denom B), 17th finding recorded

`reg2_paddocks_lt75_dominance`: pinned **14** (denom A, the analysis scope), spread **14 … 22** (A/B/C = 14/16/22). `decision_note` records: the report stream reported 17; their two named paddocks (Bala 1, Mara 5a) reconcile our 14 to **B = 16** exactly; the seventeenth could not be reproduced from any denominator or boundary rule. **Counts not adjusted.** Denominator guidance registered per spec: **A for analysis** (every RS number is on this scope), **C for client text** (shares that sum to the whole paddock, not renormalised onto the analysed subset) — recommendation, not enforced; the view carries all three.

## Registered rows (6; `dim_headline_number` 62 → 68)

| number_id | pinned (denom A) | spread (A…C) |
|---|---|---|
| `reg2_paddocks_lt75_dominance` | 14 | 14 … 22 |
| `reg2_paddocks_lt60_dominance` | 9 | 9 … 15 |
| `reg2_paddocks_single_community` | 25 | 18 … 25 |
| `reg2_paddocks_1part_supported` | 27 | 27 |
| `reg2_paddocks_2part_supported` | 23 | 23 |
| `reg2_paddocks_3part_supported` | 14 | 14 |

## Reproduction test

Extended with `recompute_reg2()` (dominance counts re-derived from `census_by_zone_stratum`, parts from `fact_zone_community_part_summary` — independent of the view).

```
$ python scripts/11_database/test_T8_headline_reproduction.py
T8 reproduction: PASS - all 65 pinned numbers reproduce within tolerance   (exit 0)
$ python ... --break  ->  DRIFT flagged (real DB untouched)
```

**65 reproducible rows** (REG-1 took it to 59; +6 REG-2 = 65). The spec's exit condition names "58 rows"; the true figure has grown to 65 through the REG-1 RSE row (ruling) and the six REG-2 rows — flagged so it does not read as drift.

## Acceptance (REG-2)
- `v_zone_community_composition` exists, 64 paddocks, three denominators, dominance + class + `n_parts_supported`.
- Gate A expected counts hit (`<75`/`<60`/totals exact); single-count registered literally with the Mara 3 note.
- 17th paddock: reconciled to 16, discrepancy recorded, not adjusted.
- Dominance counts registered with the denominator named in `decision_note`.
- No existing object modified.

## Exit bundle
`Output/review_bundles/reg1_reg2_report_plumbing.zip` — the REG-1+REG-2 `dim_headline_number` rows, the three promoted tables and the composition view as CSV, all four gate reports, and the reproduction-test output at 65.

## STOP
REG-1 and REG-2 complete. T13 (paddock-part classification) and T14 (part-grain expectation) are specified separately and **not started** from this session. `fact_zone_community_part_summary` is now the first-class T13 substrate.
