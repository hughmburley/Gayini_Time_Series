# T10 Gate C (+ amendment A1) — what remains after water

**Task:** T10 v2 §5 as amended by `Gayini_T10_v2_amendment_A1_gateC.md` (A1).
**Date:** 28 July 2026 · **Prior:** SHA a104661 (Gate B)
**Scope:** Gate C. **READ-ONLY** — cross-sectional fits + the temporal arm; no DB write (register is Gate D). STOP at §5.5.
**Verification:** live output of `scripts/12_zone_stratum/T10_gateC_residuals.py`.

Session start: on `main`, up to date with `origin/main`, main has not moved.

## Headline — NOT a null; the reference-state story reduces to one genuinely-recovering paddock

Bala 29ca's residual is **not** near zero, so the deck's central claim is not withdrawn — but it is heavily qualified. **Cross-sectionally**, Bala 29ca sits −16.8 pp below what its dryness predicts (rank 2 of 64) — **40% of the raw −42.3 pp gap survives** wetness adjustment. **Temporally**, after removing its own year-to-year water response, **82% of its floor recovery survives (+0.556 of +0.682 pp/yr)** — the recovery is *not* hydrological. Combined with Gate B (series B flat: no reference-vs-grazed trajectory without this paddock), the whole reference-state result is **one degraded paddock genuinely recovering for non-water reasons** — most consistent with historical disturbance predating the record. **Ernest's land-use history is the decisive outstanding input.**

---

## §5.1 Cross-sectional fits — the wetness relationship is not a community artefact

| fit | result | prediction | verdict |
|---|---|---|---|
| (1) bivariate floor~flood, n=64 | slope **+0.548**, r **0.710** | registered | reproduces |
| (2) + dominant community | **flood coef +0.498**, Aeolian −2.89, Riverine −6.09, R²=0.538 | — | flood survives community control |
| (3) within Inland, n=55 | slope **+0.503**, r **0.680** | +0.503 / 0.680 | AGREE (exact) |

The flood coefficient barely moves adding community (+0.548 → +0.498) and holds within Inland alone (+0.503) — the floor–flood relationship is a real wetness effect, not a community difference in disguise.

## §5.2 Dominant-community quality — and a DIFFER against the spec

Assignment (max non-treed pixels): Inland 55 / Riverine 6 / Aeolian 3; **9 paddocks below 60% dominance.** The Aeolian term rests on **3 paddocks — Mara 8, Dinan 10, Dinan 14, all grazed.**

**DIFFER (reported, not tuned — CLAUDE.md):** §5.2 assumes "Bala 29ca is one of the three Aeolian." It is not. Bala 29ca is a near-perfect three-way split — **Inland 34.6% / Riverine 33.1% / Aeolian 32.3%** — the **lowest dominance of all 64 paddocks**, so by max-pixel it is Inland-plurality. The spec's premise is not reproduced. The conclusion it was reaching for is *strengthened*: a dominant-community adjustment is meaningless for the one paddock under test not because the Aeolian term is n=3, but because **Bala 29ca has no dominant community at all.** Accordingly the §5.3 residual table uses the **bivariate** model, with this caveat stated (per §5.2's instruction to prefer the bivariate residual when the community adjustment is unstable).

## §5.3 Cross-sectional residual table (bivariate model) — residual SD = 6.67 pp

| paddock | floor | flood | predicted | residual | rank | treatment |
|---|---|---|---|---|---|---|
| Bala 29ca | 40.5 | 8.5 | 57.3 | **−16.8** | **2/64** | ungrazed |
| Dinan 10 | 40.4 | 5.1 | 55.4 | **−15.1** | **3/64** | grazed |
| Bala 28ca | 68.1 | 43.3 | 76.4 | −8.3 | 9/64 | ungrazed |
| Bala 26ca | 68.8 | 45.3 | 77.5 | −8.7 | 8/64 | ungrazed |
| Bala 27ca | 68.0 | 29.7 | 68.9 | −0.9 | 20/64 | ungrazed |

**Cross-sectionally, Bala 29ca (−16.8) and grazed Dinan 10 (−15.1) are near-twins** — a dry ungrazed and a dry grazed paddock sitting at nearly the same residual and rank (2 and 3). Per §5.3 that is itself an answer to the deck's question: at the level of "how low for how dry," grazing does not distinguish them. (Full 64-row table: `Output/tables/T10_gateC_crosssectional_residuals.csv`.)

## §5.6 Temporal arm (A1) — and where the twins diverge

A1 flood-trend predictions, independently recomputed — **all AGREE**: Bala 29ca **+0.304** (r 0.268), Bala 26ca −0.301, 27ca −0.099, 28ca −0.424, grazed median −0.117. Bala 29ca is the only reference paddock getting wetter, but weakly (r 0.268).

### Bala 29ca's three numbers (§5.6.2)

| | value |
|---|---|
| raw floor trend | **+0.682 pp/yr** |
| within-paddock water response | +0.414 pp cover per pp flood (r 0.458) |
| **water-adjusted floor trend** | **+0.556 pp/yr (SE 0.126)** — **82% of the raw trend survives** |

*(The paddock's own floor trend +0.682 differs from Gate B's series-C gap trend +0.919 because series C is 29ca-floor minus the grazed median, and the grazed median floor itself declines ~−0.24 pp/yr — the gap widens faster than the paddock rises. Consistent, not contradictory.)*

**The recovery is not hydrological.** Bala 29ca's weak wetting (+0.304 pp/yr flood) explains only ~18% of its floor rise; 82% is something else. Per §5.6.2 the historical-disturbance reading survives, and Ernest's land-use table becomes the decisive input.

### The twins diverge temporally

| paddock | raw floor trend | water-adj floor trend | rank (adj) |
|---|---|---|---|
| Bala 29ca (ungrazed) | +0.682 | **+0.556** | 63/64 |
| Dinan 10 (grazed) | +0.222 | **+0.020** | 55/64 |

Cross-sectionally identical (−16.8 vs −15.1); **temporally opposite.** Dinan 10's slight rise is almost entirely its own wetting (adjusted trend +0.020, near zero); Bala 29ca's is not. **The A1 temporal arm distinguishes the wetness twins where the cross-section cannot** — the amendment earned its place. Bala 29ca is one of the strongest improvers-beyond-water on the property (rank 63/64; property adjusted-trend distribution min −0.704 / median −0.148 / max +0.646).

### §5.6.4 diagnostics
- **Low flood variance:** 0 paddocks below SD 2 pp — every within-paddock water response is estimated from real variance; none flagged unreliable.
- **Lag:** the one-year-lagged fit beats the current-year fit for only **18/64** paddocks — current-year adjustment is appropriate property-wide; lag is not materially better overall, so the current-year adjusted trend stands as primary.

## §5.4 The two deck claims, each against the raw figure it qualifies

| deck claim | slide | test | result |
|---|---|---|---|
| Bala 29ca sits 42 pp below the grazed median | 7 | cross-sectional residual | **−16.8 pp — 40% survives** dryness; a near-twin of grazed Dinan 10 |
| The gap has been narrowing since 1988 | 8 | water-adjusted floor trend | **+0.556 pp/yr — 82% survives** water; but Gate B showed the narrowing is *only* Bala 29ca (series B flat) |

Neither claim is withdrawn; both are real but reduce to Bala 29ca, whose low floor and recovery both substantially survive water adjustment. The deck should say so: this is one paddock's genuine recovery from a low base, not a reference-vs-grazed convergence.

## §5.5 STOP
Reported: three cross-sectional fits, the Aeolian-term diagnostic + the Bala-29ca-not-Aeolian DIFFER, the 64-paddock cross-sectional table, the temporal arm (Bala 29ca's three numbers, the twin divergence, low-variance and lag diagnostics), and both §5.4 numbers. **Not proceeding to Gate D without review.**

Outputs (gitignored, for the Gate D bundle): `Output/tables/T10_gateC_crosssectional_residuals.csv`, `T10_gateC_temporal_table.csv`.

## Invariants
No DB write, no builder, no registered row touched. Writes: this report + the producing script (tracked).
