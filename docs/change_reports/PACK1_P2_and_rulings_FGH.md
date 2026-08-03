# PACK-1 P2 · Rulings F, G, H — Part 1 applied. Part 2 (P3) awaited.

**Date:** 3 August 2026 · **Prior:** `523ae38`
**DB writes:** 1 canary inserted, 1 `decision_note` amended. Probes either side.

---

## Ruling F — recorded in the standing rules and logged as I-41

Spec §7's *never modify a registered row* is **refined, not overridden**:

| | fields |
|---|---|
| **Amendable in place**, under explicit direction, logged each time | `caveat` · `decision_note` · `label` |
| **Never amendable — a change is a NEW ROW and a supersession** | `pinned_value` · `spread_min` · `spread_max` · `support_level` · `scope_filter` · `pixel_constant` · `denominator` · `period_label` · `source_object` · `number_id` |

Added to CLAUDE.md's standing conventions and logged as **I-41**.

**Consequences, stated so the rule is not eroded again:** AD-C is **not** an exception — it amended a
`caveat`. The **31 July `floor_flood_*` precision correction remains the single genuine one-off**,
because it changed `pinned_value` and `spread_*`, exactly the class that now requires supersession.
Two amendments have been made under this rule so far and both are logged: AD-C's caveat, and Ruling
G's `decision_note` below.

## Ruling G — option (i) taken. One row cannot be both.

**I-39 existence test run first:** `rptscope_canary_p3_composition_share_bala29ca_inland` absent.

| role | `number_id` | value | source |
|---|---|---|---|
| **CANARY** — computed by the contract's own SQL | `rptscope_canary_p3_composition_share_bala29ca_inland` | **34.59** | `v_zone_community_composition.share_a` |
| **CROSS-OBJECT CHECK** — role now stated | `t10_refset_inland_share_bala29ca` | 34.6 | `census_by_zone_stratum` |

The two agree to rounding, which is what makes the second a real cross-object check — and precisely
why it could never be the canary: **it cannot detect drift in a query it does not run.**

The cross-check's `decision_note` was amended in place (permitted under Ruling F) to state its role
and to name the canary. The contract row now lists both, labelled.

### Proven to fire — and the first fixture was rejected as invalid

A first fixture renamed `share_a` inside the view; the recompute **errored** rather than returning a
wrong value. That is a crash, not drift detection, so it was discarded. A realistic data-level drift
instead — double the underlying census pixels for Bala 29ca Inland:

```
contract SQL now returns 51.40 (was 34.59)
DRIFT rptscope_canary_p3_composition_share_bala29ca_inland: pinned=34.59 recomputed=51.4
```

**All three parameterised canaries are now wired and individually proven to fire.**

**Coverage: 81 of 98 pinned = 82.7%. Value drifts: 0.** (Registry 101 rows.)

## Ruling H — proceeding without v10, and the T12 caution fired

**The caution was right.** `docs/Gayini_limitations_register_additions_T12.md` carries **DEA
cultivation material throughout** — its own header says *"Task T12 closed as a documented negative …
these rows are the durable record of why"*, and all three rows (L-T12-a/b/c) are DEA Land Cover CTV.
CLAUDE.md: *T12 DEA cultivation results never appear in a client deliverable, at any confidence level.*

**It does not go on the T3 sheet.** Excluded whole.

**One judgement flagged rather than taken:** **L-T12-b** is titled *"WORKED EXAMPLE: a pre-registered
falsification test aimed at the wrong hypothesis catches nothing"* — a **methodological** lesson that
names no cultivation call, and a close relative of T3's own falsification finding. Ruling H bars
"T12 material", which reads broader than "T12 results", so it is **excluded as written**. If the
design seat wants the methodological row admitted on its own merits, that is a separate call.

**The finding recorded as it stands:** three additions files (T2, T6, T12) are committed against a
base document the repo does not contain, so a repo-only reader sees amendments and infers an
original that is not there. Same shape as I-17. The v10 file itself contributes nothing to T3 beyond
its whole-project rows — 21 of 43 are bank-cut scoped and **zero are reference-state** — so **T3 is
not blocked on it.**

## P2 — applied, verified against the item list, nothing reopened

| ruling | verified |
|---|---|
| M3 ships as-is, caption notes the saturation | `ship_flag = SHIP`; saturation clause present in the v3 caption |
| T1 = the `.csv` | `Output/tables/T1_conserved_paddock_comparison.csv` |
| the `.png` is row 18, `T1_render` | `Output/figures/T1_conserved_paddock_comparison.png` |
| M4b in the list from P1 | present |
| D1 / D2 excluded as internal apparatus | absent |
| `Gayini_reference_state_methods.md` must not ship | **absent — no path anywhere in the list** |
| no path under `docs/` | **0** |

Nothing in P2 required a change: P1 already built the list under these rulings.

## Probes

| | `dim_headline_number` | `figure_asset` | `raster_asset` | `table_asset` | `report_asset` |
|---|---|---|---|---|---|
| before | 100 | 297 | 191 | 4 | 59 |
| after | **101** | 297 | 191 | 4 | 59 |

## STOP — awaiting Part 2 (P3)
