# REG-2 Gate A/B — composition view at three denominators; the 14/16/17 reconciliation

**Task:** REG-2, per `Gayini_REG1_REG2_spec.md` v1.
**Date:** 29 July 2026 · **Prior:** SHA 8a033dc (REG-1 complete)
**Scope:** Gate A (build the view, verify counts — STOP) and Gate B (reconcile 14/16/17 — STOP).
**Additive:** one NEW view, no table, no existing object modified.
**Verification:** live output of `build_REG2_gateA_view.py` and the reconciliation queries.

Session start: on `main`, up to date with `origin/main`, main has not moved.

## Gate A — `v_zone_community_composition` (paddock × community, three denominators)

156 rows, 64 paddocks. Per (paddock, community): `n_pixels_a/b/c`, `share_a/b/c`, and per-paddock `dominance_a/b/c` + `dominance_class_a/b/c`. Denominators:

| | scope filter | total px | expected |
|---|---|---|---|
| **A** focus-3 non-treed | `treed_context_flag=0 AND regime_band<>'context'` | **795,602** | 795,602 ✓ |
| **B** all non-treed | `treed_context_flag=0` (adds *Other / minor units*) | **800,340** | 800,340 ✓ |
| **C** whole paddock | no filter (adds *Floodplain Woodland / Forest*) | **885,292** | 885,292 ✓ |

Dominance counts — **`<75%` and `<60%` reproduce exactly under all three denominators:**

| denom | <75% | <60% | single | (expected) |
|---|---|---|---|---|
| A | **14** | **9** | 25 | 14 / 9 / **26** |
| B | **16** | **9** | 23 | 16 / 9 / **25** |
| C | **22** | **15** | 18 | 22 / 15 / **19** |

**One definitional flag (not a data disagreement) — the "single-community" count.** The substantive dominance thresholds all hit; the single count differs by 1–2 because "single" needs a definition. My view uses the literal **"exactly one community present"** → 25 / 23 / 18. The expected 26 / 25 / 19 reproduces only under **"dominant community ≥ 99.9%"** (a <0.1% trace of a second community tolerated). Per the spec's rule ("do not adjust the method to reach the expected value; a mismatch is a finding") I kept the literal definition and did **not** tune to 99.9%. The `dominance` numeric in the view is identical either way, so the report stream can apply whichever boundary the design seat rules — **please rule, as with the residual-SD ddof.** My recommendation: `single` = exactly one community; a paddock that is 99.95% one community and 0.05% another is genuinely two-community and "high", not "single".

`dominance_class` uses `single` / `high (≥90)` / `moderate (≥75)` / `mixed (<75)`; the `<60` count is read from the numeric (the L-01 "genuinely mixed" threshold), not a separate class.

**STOP** — view built, counts verified, single-definition flagged for ruling.

## Gate B — the 14 / 16 / 17 reconciliation

**Our 16 (denom B) is fully accounted for and reproduces the report stream's own two named paddocks. The report stream's 17 is one over its own accounting and is not reproducible from any denominator.**

The 16 paddocks `<75` under denom B are the RS stream's **14** (every one has `dom_A = dom_B` — unaffected by adding *Other*) **plus exactly two**:

| paddock | dom_A | dom_B | why it moves |
|---|---|---|---|
| **Mara 5a** | 100.0 | **70.7** | single under A; *Other / minor* (29%) splits it under B |
| **Bala 1** | 96.9 | **71.5** | *Other / minor* (26%) pushes it below 75 under B |

These are **precisely the two the report stream named** (they quoted Bala 1 "72% Inland, 26% Other", Mara 5a "71% Inland, 29% Other" — matching dom_B 71.5 and 70.7). So `14 + Bala 1 + Mara 5a = 16`, which is denominator B.

**The 17th is not in the data.** No paddock sits at the 75 boundary — the nearest above are Mara 4 (75.8), Mara 21 (76.0), Bala 20 (76.3), and **none is exactly 75.00**, so an inclusive `≤75` cut does not produce a 17th either. Denominator C jumps straight to 22 (six paddocks flip only when treed *Floodplain Woodland/Forest* is added — Bala 28ca, Dinan 1/2/6/12, Mara 4/10/12), so 17 is not a C-scope count.

**Finding (per spec — reported, not adjusted):** the report stream's 17 exceeds its own named accounting (14 + 2 = 16) by one, and no fourth paddock or defensible scope/boundary rule in the data yields 17. The most likely explanation is a miscount (14 + 2 read as 17) or a rule we have not reproduced. **Our 16 is right and fully justified; I have not adjusted either count to force agreement.** Recommendation: the report stream re-derives dominance from `v_zone_community_composition`, which now carries all three denominators explicitly, so the count can never again be quoted without its denominator.

**STOP.**

## Not yet done (Gate C)
REG-2 Gate C (register the dominance counts, A pinned with B/C as spread, denominator named in `decision_note`) is **held** behind two rulings: (1) the single-community definition, and (2) acknowledgement of the 17th-paddock finding. Registering the counts before the single boundary is ruled would pin a disputed value. Awaiting both.

## Invariants
- Additive: one new view; no table, no existing object modified, no builder run. Producing script tracked.
