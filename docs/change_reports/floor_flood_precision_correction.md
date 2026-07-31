# `floor_flood_*` constants re-registered at 6 dp — a precision correction

**Date:** 31 July 2026 · **Prior:** SHA 24e073e
**Trigger:** T11 v2 Gate B §4 — the pinned constants could not reproduce `v_zone_floor_flood_residual`.
**Ruling:** design seat, 31 Jul. **Producer:** `scripts/11_database/repin_floor_flood_constants_precision.py` (tracked).

> **THIS IS A PRECISION CORRECTION, NOT A VALUE CHANGE.** The fitted constants are unchanged; only
> the number of decimals stored moves, and both new figures round back to the old ones exactly.
> That is why it is safe ten days from the deadline, and why it is a different thing from the PIN 2
> revisit, which would change the grain and therefore the number.

---

## 1. What changed

| `number_id` | before | after | rounds back to |
|---|---|---|---|
| `floor_flood_slope_64pdk` | 0.548 | **0.547838** | 0.548 ✓ |
| `floor_flood_intercept_64pdk` | 52.6529 | **52.652934** | 52.6529 ✓ |

The fit was **re-derived in the script** — bivariate OLS on the 64 paddock means, 1988–2022,
`mean_of_seasons` — giving **slope 0.547837594, intercept 52.652933834**. That matches the
design-seat direct fit to **5e-10**, and the script **asserts** it before writing: if the
re-derivation ever stops producing the registered value, the repin halts.

**Display convention unchanged: 3 significant figures in prose.** Nobody quotes more than "0.55" or
"about 0.5 pp per pp", and every rendered subtitle still prints `52.7 + 0.548 × flood %`. **No
client-facing number moves.**

## 2. Why it needed fixing — not the size, the inconsistency

Recomputing residuals from the pinned constants missed the registered residuals in
`v_zone_floor_flood_residual` by up to **0.0135 pp**. Recomputing from the full-precision fit missed
them by **0.0048 pp**, which is exactly the view's own 2-dp column rounding and nothing more.

**A registry whose pinned constants cannot reproduce its own derived view has a latent
inconsistency**, and reproducibility is the entire purpose of `dim_headline_number`.

The concrete consequence: the report stream draws the page-4 expectation line from these two rows.
Using the pinned 0.548 while the registered residuals came from full precision would have put, in
**all 21 paddock reports**, a line marginally inconsistent with the residual printed beside it —
the same ~0.01 pp, 21 times, in a client deliverable.

## 3. Verification — the registry now reproduces its own view

```
reproduce v_zone_floor_flood_residual from the PINNED constants:
  before: max |diff| 0.01348
  after : max |diff| 0.00478   budget 0.00503 (view 2-dp columns + 6-dp half-ulp)
```

The **derived-budget check is kept** in `build_T11_v2_dual_grain.R`, now expressed as the view's
2-dp columns plus a 6-dp half-ulp, so the gap cannot silently return if either row is ever
re-rounded.

## 4. Spread — updated where it is the same fit, and *only* there

Each row's spread carries the bivariate fit at one end and a **different model** at the other
(REG-1 Gate B: bivariate / +community / within-Inland).

| `number_id` | endpoint that IS the bivariate primary | updated to | other endpoint |
|---|---|---|---|
| `floor_flood_slope_64pdk` | `spread_max` 0.548 | **0.547838** | `spread_min` **0.498 — unchanged** |
| `floor_flood_intercept_64pdk` | `spread_min` 52.6529 | **52.652934** | `spread_max` **54.584 — unchanged** |

**The two alternative-model endpoints were deliberately left at their registered precision.**
Re-deriving them would mean refitting the +community and within-Inland models, which is a value
operation, not a precision one — and this correction is explicitly not that. **Flagged:** if you
want those two at 6 dp as well, it is a separate small task with its own re-derivation.

## 5. The reproduction test — its tolerance *was* tuned to the rounded values

The test recomputed these two by rounding to the old stored precision (`round(slope, 3)`,
`round(inter, 4)`) and checked them against a `floor_flood_*` tolerance of **0.005** — which cannot
see the sixth decimal at all. Both updated:

- recompute now rounds to **6 dp** for these two rows;
- tolerance for these two rows tightened to **5e-6** (a 6-dp half-ulp). The other `floor_flood_*`
  rows keep 0.005, since they are still stored at 4 dp.

**Proven to discriminate** (fixtures on throwaway copies):

```
perturb slope by 1e-5 (should FIRE)                -> drift rows 1
perturb slope by 1e-6 (below tolerance, PASS)      -> drift rows 0
```

The old 0.005 tolerance would have passed **both**. Full suite: **71 pinned numbers PASS**, and the
pre-existing `--break` fixture still fires.

## 6. Downstream — the consumer guards did their job

Both figure scripts assert the constants they read. **Both fired on the repin**, which is precisely
what they exist for:

```
Error: abs(SLP - 0.548) < 1e-04 is not TRUE
```

Updated to the new values at 1e-6 and rebuilt. Which artefacts actually changed is itself the
verification:

| figure | checksum | why |
|---|---|---|
| `M5_dual_grain_floor_and_flood.png` | **unchanged** | does not use the constants |
| `M5b_paddock_residual_from_expectation.png` | **unchanged** | draws the **registered view's** residual, per the Gate C ruling |
| `F5_cover_vs_water_64_paddocks.png` | **changed** | draws the expectation **line** from the constants |

**Exactly one figure moved, and it is the one that should have.** The shift is 0.0002–0.0095 pp
across the observed flood range — invisible at plotting resolution, which is why the subtitle text
is byte-identical.

## 7. Invariants

- Two existing rows' `pinned_value`, one spread endpoint each, `decision_note` and `decided_by` updated by explicit `UPDATE`. No row added or deleted; no other object touched; no builder run.
- `decision_note` records: the value did not change, only its stored precision; the display convention stays at 3 significant figures; and the reason — the rounded constants could not reproduce `v_zone_floor_flood_residual`, and the report stream computes from them.
- `decided_by` now names this report, so the provenance chain points at the reasoning.
- Reproduction test extended and proven to discriminate at the new precision.

## 8. For the report stream

`floor_flood_intercept_64pdk` = **52.652934** and `floor_flood_slope_64pdk` = **0.547838**. Read
them from `dim_headline_number` as before — nothing about how to consume them changes, and the
printed line still reads `52.7 + 0.548 × flood %`. Residuals computed from these now agree with
`v_zone_floor_flood_residual` to within that view's own 2-dp rounding.
