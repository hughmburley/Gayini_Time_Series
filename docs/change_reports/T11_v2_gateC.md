# T11 v2 — Gate A and Gate B, reported at Gate C

**Task:** T11 v2, per `docs/reference_update/Gayini_T11_v2_spec.md` (31 Jul 2026).
**Date:** 31 July 2026 · **Prior:** SHA 56276c6
**Scope:** the dual-grain 2×2 figure and the paddock-grain residual panel. **STOP at Gate C.**
**Producer:** `scripts/12_zone_stratum/build_T11_v2_dual_grain.R` (tracked).
**Artefacts:** `Output/figures/M5_dual_grain_floor_and_flood.png` · `Output/figures/M5b_paddock_residual_from_expectation.png`

**Assembly only.** No refit, no builder run, no existing object modified, no p-values.
DB writes: `figure_asset` only, via the one-transaction registrar.

---

## 1. §3.2 spread — verified, and it holds exactly

Independent recompute from `fact_zone_community_veg_annual` (support rule ≥25 years of ≥30 valid
pixels), against the design-seat prediction:

| | spec | recomputed |
|---|---|---|
| paddocks with >1 supported part | 37 | **37** |
| median within-paddock spread | 12.8 pp | **12.8 pp** |
| maximum | 40.2 pp | **40.2 pp** |

Five widest reproduce to the digit: Dinan 1 (56.7; 69/57/29; 40.2) · Bala 29ca (40.5; 67/35/29;
37.9) · Dinan 2 (69.3; 77/44; 32.2) · Dinan 3 (50.2; 73/64/42; 31.2) · Dinan 13 (52.9; 70/48/45;
24.6). **12.8 pp is therefore in the caption**, and is asserted against the live computation at
render time (I-32), not typed.

## 2. Colour breaks used

| row | limits | breaks | ramp |
|---|---|---|---|
| cover floor | 29.3 – 84.1 | 30, 40, 50, 60, 70, 80 | green, from committed `total_veg` `#2E7D32` |
| flood frequency | 1.0 – 58.9 | 10, 20, 30, 40, 50 | blue, from committed `flood` `#2171B5` |

**Each row shares one scale across both grains** — otherwise the columns are not comparable.

### The derived sequential ramps, recorded

No sequential deck ramp was committed (the audited palette is per-community; the T13 set is
categorical). These are derived from the committed semantic hues and are **now the reference for
any future continuous surface**:

```
floor  #F2F7F0  #C9E0C0  #8CC183  #4E9C55  #2E7D32  #14401A
flood  #EFF4FA  #C3D9EE  #7FB0DA  #3E86C4  #2171B5  #08306B
```

**Hue separation is load-bearing, not decorative.** The argument is that the two *rows* look alike,
so a reader must never need the legend to know which row they are in. Green/blue does that at a
glance.

**Blue for water** is consistent with every other map in this project — which is precisely why blue
was *refused* for "recovering" at T13 Gate D. Same reasoning, opposite conclusion.

## 3. Two defects found in the build, both fixed

### 3a. The caption promised a fill the figure did not contain

The first draft drew the not-assessed base as `foot` — but `foot` is the **union of the parts**, so
no pale ground could ever show beneath it, while the subtitle told the reader "pale fill = not
assessed (treed or outside the mapped census)". **A caption asserting something the figure does not
show.** Fixed by drawing the **full management zones** underneath, so the excluded treed and context
ground is visible in both columns — which additionally lets a reader see that the paddock column is
*not* drawn over its treed ground. Both non-data fills now carry **real legend entries** via a key
strip (`ggnewscale` is unavailable, so a second discrete scale is not possible).

### 3b. Gate B rendered on a transparent background

`theme_void()` supplies no `plot.background`, so `ggsave` wrote a transparent PNG. It renders as
**black** in most viewers, and took the black title and legend labels with it — the figure was
unreadable and the title invisible. Both figures now set `plot.background = element_rect(fill =
"white")`. Worth remembering: `theme_void()` + `ggsave` to PNG is transparent by default.

## 4. ⚠ Gate B — the pinned constants and the registered view disagree by 0.0135, and neither is wrong

The spec says compute `residual = floor − (intercept + slope × flood)` with both constants read from
`dim_headline_number`. Doing exactly that does **not** reproduce `v_zone_floor_flood_residual`:

| | |
|---|---|
| max abs difference | **0.01348** |
| computed rounding budget | 0.01575 |

**Cause, diagnosed rather than absorbed.** `dim_headline_number` pins **rounded** constants
(`0.548`, `52.6529`). The view was built from the fit's full precision — recovered by solving
`predicted_floor` on `mean_flood`, which is exactly linear: **slope 0.547823, intercept 52.653223**.
Recomputing with *those* reproduces the view to 0.00504, i.e. the view's own 2-dp column rounding.
So the gap is entirely **the rounding of the pinned constants**, not a disagreement about the data.
(Checked and excluded: the view's inputs *are* my full-precision means rounded to 2 dp — 0 of 64
mismatch.)

**What the figure draws, and why.** The **registered view's residual** is used for both the fill and
the two labels. Both routes satisfy "do not refit", but a client deliverable must not disagree with
the registry by 0.01, and the two values the spec asks to be labelled — **−16.80** and **−15.06** —
*are* the registered ones. The pinned-constant computation is retained in the script as a **check**
against a derived budget, so the discrepancy cannot silently grow.

**Flagged for your call:** if you want the figure to show the pinned-constant arithmetic literally
instead, it is a one-line change — but the labels would then read −16.81 / −15.07 against a registry
that says otherwise. Recommend leaving as built.

## 5. The support rule is stated on the figure, not in this report

**115 of 118 parts carry a value.** The 3 sub-support fragments are drawn in **their own grey with
their own legend entry** — a blank there would mean "no data" and "no cover" at once, which is the
white-fill defect from T13 Gate D in another coat. The subtitle carries the rule so a reader
comparing columns is never guessing.

## 6. Both columns share one footprint — a deliberate departure worth stating

The paddock column is drawn on the **paddock footprint dissolved from the part polygons**, not on
the raw management-zone polygons. The zone polygon covers treed and context ground that the paddock
mean is **not computed on**; colouring it whole would state a non-treed value over ground excluded
from it. Dissolving the parts makes both columns the same country, so the columns differ **only in
partition** — which is the entire comparison the figure exists to make.

## 7. Acceptance against §7

| criterion | status |
|---|---|
| Four panels, shared scale within each row, breaks stated | **met** (§2) |
| Both geometries from registered/verified sources; no re-derivation | **met** — T13 render-only part polygons; paddock footprint dissolved from them |
| Conserved paddocks outlined on all four panels | **met**, dashed, labelled once in the subtitle |
| Out-of-scope fill distinct from white, own legend entry | **met** (§3a) |
| Spread figures verified independently, agreement stated | **met** (§1) — agrees exactly |
| Residual panel uses registered intercept and slope; not refitted | **met**, with the §4 finding |
| Caption states why there is no part-grain residual | **met** — the line is fitted across 64 paddocks, no part-grain fit is registered, and T13's `level_z` is a different quantity |
| Both figures registered; written to `Output/figures/` | **met** — `figure_asset` 283 → 285 |
| No builder run, no existing object modified | **met** |

## 8. STOP

Both figures built, registered and written to `Output/figures/`. §3.2 verified exactly. One item
needs your call: **§4**, the pinned-constant versus registered-view residual. Everything else is
complete against §7.
