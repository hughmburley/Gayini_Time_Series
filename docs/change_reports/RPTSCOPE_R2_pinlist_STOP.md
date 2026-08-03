# RPT-SCOPE R2 — the final pin list, and a §6 STOP. Nothing written.

**Date:** 3 August 2026 · **Prior:** `f58a1fb` · **READ-ONLY. NO DB WRITES. NO PINS REGISTERED.**
**Producer:** `scripts/12_zone_stratum/build_RPTSCOPE_R2_pinlist.py` · list at `Output/tables/RPTSCOPE_R2_pin_list.csv`

D1, D2 and D3 are applied. The list is **14 rows — under the 16 threshold** — but **4 of them hit
the standing STOP in spec §6**, so the write is held.

---

## 1. ⚠ THE STOP — four pins derive from `veg_p05_mean` for a reference-state purpose

Spec §6: *"`census_by_zone_stratum.veg_p05_mean` is the census **temporal** p05 and is a different
quantity… **Any gate that reaches for `veg_p05_mean` for a reference-state purpose is a STOP, not a
judgement call.**"*

`v_zone_stratum_contrast_bala_robust` — the source for pin candidates **(b)** and **(c)** — is built
**entirely** on it. From its own definition:

```sql
SELECT s.community, s.regime_band, z.grazing_excluded,
       s.zone_fid, s.n_pixels, s.veg_p05_mean, s.flood_freq_mean
FROM census_by_zone_stratum s JOIN dim_management_zone z ...
...  MIN(veg_p05_mean) AS veg_min, MAX(veg_p05_mean) AS veg_max
```

`ungrazed_p05_min/max` — the endpoints the Riverine spreads are computed from — **are min and max of
`veg_p05_mean`.** Verified against the underlying rows: Riverine high conserved paddocks read 29.83,
58.71, 66.33, giving max − min = **36.5**, the stated spread exactly.

**Both blocked candidates are reference-state claims** — they exist to answer *"are the conserved
paddocks a usable reference set?"*. That is the purpose §6 names.

| blocked pin | value | why blocked |
|---|---|---|
| `ref_set_internal_spread_riverine_high` | 36.5 | built on `veg_p05_mean` |
| `ref_set_internal_spread_riverine_low` | 19.2 | " |
| `ref_set_internal_spread_riverine_mid` | 28.2 | " |
| `ref_set_spread_exceeds_contrast_multi_count` | 6 of 7 | " |

**This reaches further than R2.** `v_zone_stratum_contrast_bala_robust` and
`v_zone_stratum_treatment_contrast` are the only two views on `veg_p05_mean`, and **F6 draws the
six-of-nine claim from the first of them.** So a figure already in the pack rests on the temporal
p05 for a reference-state purpose. Not something R2 can fix, and reported rather than worked around.

**Three ways forward, none of them mine to choose:**
1. **Rebuild the contrast on `veg_p05_spatial`** and re-derive — the numbers will move, and F6 with them.
2. **Register the pins as-is with `source_object` naming `veg_p05_mean` explicitly** and a caveat that they are census-temporal, not the pinned floor metric — provenance-honest, but puts the forbidden metric in the registry.
3. **Drop (b) and (c)**, leave the claims SOURCED against the claim audit, and let claim 5's rewrite use the flood ranks instead — which are on the correct metric and already in the list.

## 2. The final pin list — 14 rows, 10 writable

Full qualifiers in `Output/tables/RPTSCOPE_R2_pin_list.csv`.

| # | `number_id` | value | support | independent derivation |
|---|---|---|---|---|
| a | `ref_grazed_gap_annual_3pdk_mean` | **−2.073** (−7.038 … +4.987) | zone | **Y** — separately-built `T10_annual_gap_series.csv` |
| b | `ref_set_internal_spread_riverine_high` | 36.5 | zone_stratum | **BLOCKED §6** |
| b | `ref_set_internal_spread_riverine_low` | 19.2 | zone_stratum | **BLOCKED §6** |
| b | `ref_set_internal_spread_riverine_mid` | 28.2 | zone_stratum | **BLOCKED §6** |
| c | `ref_set_spread_exceeds_contrast_multi_count` | 6 | zone_stratum | **BLOCKED §6** |
| d | `t13_recovering_survive_drop2wettest` | 5 | pixel | **N** — declared |
| e | `bala29ca_improvement_surviving_water_pct` | 81.6 | zone | **Y** — OLS re-run from `fact_zone_veg_annual` |
| f | `ref_paddock_flood_rank_bala26ca` | 3 | zone | **Y** — rank re-derived by mean-of-years |
| f | `ref_paddock_flood_rank_bala28ca` | 6 | zone | **Y** — " |
| f | `ref_paddock_flood_rank_bala27ca` | 31 | zone | **Y** — " |
| f | `ref_paddock_flood_rank_bala29ca` | 61 | zone | **Y** — " |
| g | `bala15_xsec_residual` | −17.62 | zone | **Y** — recomputed from the pinned constants |
| h | `cropping_history_null_count` | 64 | zone | **N** — declared |
| i | `three_arm_standard_at_or_above_count` | 6 | zone_stratum | **N** — declared |

**(a) reproduces the design-seat prediction exactly**: mean **−2.073** against −2.07, range
**−7.038 to +4.987** against −7.04 to +4.99. The gap crosses zero, as predicted.

### The three declared N's, per D2 — no manufactured derivations

- **(d)** the drop-two states are *stored*; recomputing them re-runs the T13 Gate C chain that produced them. Same operation sequence, so not a derivation.
- **(h)** a NULL count has no second route in the schema. T12 corroborates the *gap*, not the count.
- **(i)** the arm deficits are the view's own output; recomputing re-runs its logic.

Each is registered with **no derivation** and counts as `NO_DERIVATION_PATH`, rather than a check
that can only pass.

## 3. Coverage arithmetic — it falls slightly, and that is the honest number

| scenario | pinned | recomputed | coverage |
|---|---|---|---|
| now | 85 | 71 | **83.5%** |
| **write the 10, 7 with independent derivations** | 95 | 78 | **82.1%** ↓ 1.4 pp |
| write all 14 (if §6 resolved), 7 independent | 99 | 78 | 78.8% ↓ 4.7 pp |

**Writing the 10 lowers coverage by 1.4 points**, because 3 of them honestly have no independent
route. That is the correct outcome under D2 — a derivation that re-runs the pin's own query would
have shown 85.1% and meant nothing. **The `How_we_know` sentence should carry both numbers: the
coverage fraction and the zero value-drifts**, since the second is the one that says nothing has
moved.

## 4. D1, D3 and the admissions, applied

**D1** — pinned 9 quantities, not 10. The three already-pinned rows were not re-registered;
REG-C4b stays SOURCED. **The missing rule clause is logged as I-39** in the I-17 family: *any rule
that adds rows to a registry needs an existence test before a merit test.*

**(c) admitted on a claim that does not exist yet** — recorded as instructed. It is on the list
because claim 5 is being rewritten around reference-set heterogeneity, and six-of-seven is its
numeric form. **It is now blocked for a different reason**, which makes the note sharper: the claim
it was admitted for would, if written today, rest on the temporal p05.

**D3 — nothing grouped.** Riverine is three rows, the ranks are four. Ruling 2's grouped-pin wording
is withdrawn and no `pinned_value` does double duty as a bound.

**One qualifier is deliberately empty.** `pixel_constant` is blank on every zone-support row — no
pixel-to-area conversion occurs in a rank, a count, or a paddock-grain gap. Rather than write
`0.062351428` where it plays no part, it is left empty. **Say if you want it populated regardless**;
it is a one-line change and the ruling said no NULLs.

## 5. Also applied

**I-38 logged** — `aggregation_order` as the mechanism behind the historical discrepancies, with the
43.6/22.8 versus 46.0/25.2 case as the worked example. Every pin in the list carries the column
populated.

## 6. Probes

| | `dim_headline_number` | `figure_asset` | `raster_asset` | `table_asset` | `report_asset` |
|---|---|---|---|---|---|
| open | 88 | 287 | 186 | 2 | 59 |
| close | 88 | 287 | 186 | 2 | 59 |

DB mtime `2026-08-02 12:09:44` at both ends. **No writable connection opened.**

## STOP — the write is held on one ruling

**The 10 unblocked pins are built, verified and ready to write in a single transaction.** I have not
written them, because §6's STOP changes the shape of the gate and R2's acceptance criterion
("increases by exactly the number Ruling 1 selects plus the six named") cannot hold at 10 of 14.

**Needed:** which of the three routes in §1 for the blocked four — and whether to write the 10 now
or hold the whole gate until that is settled.
