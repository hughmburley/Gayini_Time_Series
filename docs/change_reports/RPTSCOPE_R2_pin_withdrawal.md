# RPTSCOPE R2 — the four held pins withdrawn, and the dependency scan

**Status:** DRAFT · 3 August 2026 · read-only against the database
**Ruling applied:** design seat, 3 August — route 3, *withdrawn, not deferred*
**Probe (single, read-only; no write gate opened):** DB mtime 2026-08-03T17:37:09 · `dim_headline_number` 101 · `figure_asset` 297 · `raster_asset` 191 · `table_asset` 4 · `report_asset` 59

---

## 1 · What was withdrawn

| `number_id` | quantity | held value | source |
|---|---|---|---|
| `ref_set_internal_spread_riverine_low` | internal spread of cover floor among the conserved paddocks, Riverine low | 19.2 | `v_zone_stratum_contrast_bala_robust` |
| `ref_set_internal_spread_riverine_mid` | same, Riverine mid | 28.2 | " |
| `ref_set_internal_spread_riverine_high` | same, Riverine high | 36.5 | " |
| `ref_set_spread_exceeds_contrast_multi_count` | strata where internal spread exceeds the conserved–grazed difference, n_ungrazed > 1 | 6 of 7 | " |

All four are built on `census_by_zone_stratum.veg_p05_mean` — the census **temporal** p05 — reached for a reference-state purpose, which spec §6 makes a STOP rather than a judgement call.

## 2 · The withdrawal is clean — nothing depends on them

**Finding → check → number.**

- **Never registered.** `select count(*) from dim_headline_number where number_id = …` returns **0 for each of the four**. R2's write gate registered 10 of its 14 candidates; these were the 4 it held. There is no registered row to retire, no `superseded_flag` to set, and no consumer to repoint.
- **Not carried by any pack item.** `PACK1_item_list.csv` names none of them.
- **Recorded, as intended.** They survive as `BLOCKED` rows in `Output/tables/RPTSCOPE_R2_pin_list.csv`, and claims BYQ-Q2a / BYQ-Q2b remain `SOURCED` in `RPTSCOPE_claim_audit.csv` (registered in `table_asset`). The work is on the record; nothing unsupported ships.

## 3 · Repository-wide scan for live code on the retired path

Required by spec §6: *retiring a number in the registry does not retire it in the code.*

| site | what it does | verdict |
|---|---|---|
| `scripts/12_zone_stratum/build_RPTSCOPE_R2_pinlist.py:57-77` | constructs the four candidates and marks them `BLOCKED` | **benign** — the block is the behaviour; re-running reproduces four blocked rows and writes nothing to the DB |
| `scripts/12_zone_stratum/build_RPTSCOPE_R1.py:145-156` | queries the view for BYQ-Q2a | **benign** — claim-audit provenance, not a pin |
| `scripts/utils/build_db_contract_snapshot.py:134` | `SELECT * FROM v_zone_stratum_contrast_bala_robust` | **benign** — snapshot rendering of every object |

No live code path turns any of the four into a registered value or a drawn number. **The view itself is not retired** and should not be — it remains a valid census-metric object; what is retired is its use for a reference-state pin.

## 4 · What the scan found that the ruling did not cover — FLAG, not fixed

**Three pins already in `dim_headline_number` draw from the same blocked view:**

| `number_id` | `pinned_value` | `period_label` | `source_object` |
|---|---|---|---|
| `t1_riverine_contrast_bala_low` | 3.62 | Riverine low | `v_zone_stratum_contrast_bala_robust` |
| `t1_riverine_contrast_bala_mid` | 0.12 | Riverine mid | " |
| `t1_riverine_contrast_bala_high` | −2.13 | Riverine high | " |

All three: `support_level = zone`, `decided_by = design-seat T8_gateA_pin_decisions.md v1 (Hugh); built by CC 2026-07-28`, `caveat = "the collapse: the apparent effect was block structure."`

They are the same view, the same `veg_p05_mean` metric, and the same reference-state purpose that the four candidates were withdrawn for — registered on 28 July, five days before the §6 rule was written. **Two mitigations, which is why this is a flag and not an alarm:** they appear in no pack item and no claim-audit row (only in `RPTSCOPE_reproduction_status.csv`), and their caveat already records the quantity as a collapsed effect rather than a finding.

**Not fixed here.** Spec §7 forbids modifying a registered row, and `decided_by` names a `docs/decisions/` file that number rule 3 protects. The design seat should decide whether these three need a superseding note. **They do not block assembly.**

## 5 · Logged, not fixed

**The 6-of-9 denominator error.** BYQ-Q2a's "six of nine strata" includes two strata with n = 1 conserved paddock, whose internal spread is 0.0 by construction and which therefore could never qualify. **Seven is the honest denominator.** Moot while the pin is withdrawn; recorded so it does not return if the conserved-set spread analysis is ever revived.

**The numeral collision (I-37) is resolved by the withdrawal itself.** With BYQ-Q2a's "6 of 9" gone, only F6's remains — a positional count from `v_three_arm_gap_decomposition` on `veg_p05_spatial`, without the degeneracy problem. No further action.

## 6 · What now carries claim 5

The four `ref_paddock_flood_rank_bala*` pins, verified live and registered:

| paddock | flood rank of 64 |
|---|---|
| Bala 26ca | 3 |
| Bala 28ca | 6 |
| Bala 27ca | 31 |
| Bala 29ca | 61 |

Two of the conserved paddocks are among the wettest handful on the property and one is 61st of 64 — claim 5 in four numbers, on compatible support.

**By_question Q2 remains UNSUPPORTED with no wording attempted.** No drafting around it.

## 7 · Nothing changed

No database write was made by this gate. No registered row was created, modified or deleted. `dim_headline_number` stands at 101 as found.
