# Adrian pack — T1, F3, F5

**Date:** 31 July 2026 · **Prior:** SHA 3dc5a4a
**Scope:** three pack items assembled from registered objects. No new analysis, no gates.
**Producer:** `scripts/12_zone_stratum/build_adrian_pack_T1_F3_F5.R` (tracked).
**Artefacts — these are the record, this report is a rendering:**
`Output/tables/T1_conserved_paddock_comparison.csv` · `Output/figures/T1_conserved_paddock_comparison.png` · `Output/figures/F3_annual_gap_series.png` · `Output/figures/F5_cover_vs_water_64_paddocks.png`

**Assembly only.** Every value is read from a registered object or a committed T10/REG-1 output.
**Nothing is refitted** — the F5 expectation line and band come from `dim_headline_number`, not from
a regression run in this script. The script **halts** rather than adjusting if a value misses.

---

## 1. Sources — what each column was read from

| field | source |
|---|---|
| community composition | `v_zone_community_composition`, denominator A (all-classes, per REG-2) |
| mean annual flood %, cover floor, cross-sectional residual + rank | `v_zone_floor_flood_residual` |
| water-adjusted floor trend + rank | `Output/tables/T10_gateC_temporal_table.csv` (T10 Gate C) |
| part states + `assert_state` | `fact_zone_community_part_classification` (T13 Gate E) |
| reportable monitoring sites | `plot_paddock`, excluding `Floodplain Woodland / Forest` |
| F5 line, slope, band | `dim_headline_number`: `floor_flood_intercept_64pdk`, `_slope_`, `_residual_sd_` |

Flood and cover **ranks are computed by ordering registered values** — no refit. The residual and
adjusted-trend ranks are the registered ones, unaltered.

All acceptance values reproduced: composition 98 / 100 / 83+17 / 35+33+32 · flood 45.3 / 29.7 /
43.3 / 8.5 · floor 68.8 / 68.0 / 68.1 / 40.5 · residuals −8.70 / −0.91 / −8.31 / −16.80 · adjusted
trends −0.108 / −0.337 / +0.080 / +0.556 · sites 3 / 0 / 8 / 10 · part states as predicted including
both not-asserted flags · F3 +0.273 (r 0.77) / +0.057 (r 0.22) / +0.919 (r 0.85) · F5 Bala 29ca
−16.80 rank 2, Dinan 10 −15.06 rank 3.

T1 carries **four rows and no summary row, mean, or rank-of-four**.

## 2. The `ifelse` defect — the finding, not a footnote

**Every acceptance check passed while the T1 figure rendered `45.3` in all four columns.**

`fmt()` used **`ifelse()`**, which returns a value the length of its **test**. The test (`sign`) is
length 1, so the formatted number collapsed to a single element and **`sprintf()` recycled it**
across all four paddocks. R does not warn: recycling a length-1 vector into length 4 is legal.

- The **CSV was correct** — it never passes through `fmt()`.
- All five value-level acceptance checks **passed** — they test the data frame, not the ink.
- **The PNG is what the client sees.**

### The fix is for the class, logged as I-32

`R/gayini_assert_rendered.R` (new): `gayini_assert_rendered_values()` asserts each drawn string
contains its source value; `..._varies()` fails when strings are uniform but sources differ;
`..._caption_number()` checks a number quoted in prose against its source at the precision the prose
states; `..._table()` sweeps a whole table.

**Standing rule: every figure that renders numbers as text asserts the rendered STRINGS against the
source values — not the data frame the plot was built from, the strings actually drawn.**

Applied now to: the **T1 table** (all five numeric rows *and* all four rank strings), the **F5
callouts** (residual and rank), and the **T13 Gate D community-SD caption line** (the "about 12 pp /
about 6 pp" claim, checked against the live `SD(level_dev)` of 11.92 and 6.03).

### Proven to fire

Reintroducing the original `ifelse` in a fixture halts the build — **after every value-level check
has already reported OK**, which is the whole point:

```
  reportable sites             max |diff| = 0.0000  (tol 0.000)  OK
wrote Output/tables/T1_conserved_paddock_comparison.csv (4 rows, no summary row)
Error in gayini_assert_rendered_values(val[[2]], T1$mean_flood_pct, 1,  :
  [T1 flood %] 3 of 4 rendered strings do not contain their source value:
   want '29.7' in: '45.3   (rank 31 of 64)'
   want '43.3' in: '45.3   (rank 6 of 64)'
   want '8.5' in: '45.3   (rank 61 of 64)'
```

## 3. Rank directions are stated per column, on the figure

Two rank conventions sit in one table, so the direction now lives in the **row label**, beside the
numbers it governs, rather than once at the foot of a caption:

- *Mean annual flood % (rank 1 = wettest)*
- *Cover floor veg_p05 (rank 1 = highest cover)*
- *Residual vs expectation (rank 1 = largest shortfall)*
- *Water-adjusted trend (rank 1 = steepest decline)*

The consequence worth stating: Bala 29ca's adjusted-trend rank of **63 of 64** means a **rising**
trend, not a poor one. A bare rank column would have read the opposite way.

## 4. Two label-collision fixes

F5's two callouts landed on top of each other — Bala 29ca (8.5, 40.5) and Dinan 10 (5.1, 40.4) are
nearly the same point — and F3's trend labels sat on the lines. Both moved to empty regions with
leader lines. Insets never overlap the data.

## 5. Acceptance tolerance — corrected criterion

The adjusted-trend check fired on the first run. **Not a data disagreement.** The registered values
are 4 dp, the expectations were stated at 3 dp, and the tolerance was exactly **0.0005** — the
half-ulp. Bala 26ca's **−0.1085 is exactly half-way**, so the check turned on float representation
rather than on agreement.

The criterion is now what was always meant: **does the registered value round to the stated one at
the precision it was stated.** All four agree.

## 6. Version control — a narrow exception, with precedent

`Output/` is gitignored, which is right for rasters, the SQLite and review bundles. It is **not**
right for client-deliverable items: **a checksum in `figure_asset` without the file in history is
half a record** — if Adrian asks which version he received, there is no answer.

**Force-added (`git add -f`), these only:**

| item | |
|---|---|
| `Output/tables/T1_conserved_paddock_comparison.csv` | new |
| `Output/figures/T1_conserved_paddock_comparison.png` | new |
| `Output/figures/F3_annual_gap_series.png` | new |
| `Output/figures/F5_cover_vs_water_64_paddocks.png` | new |
| `Output/figures/T13_D1_part_state_map_and_scatter.png` | **moved** from `figures/T13/` |
| `Output/figures/T13_D2_part_state_map_sensitivity.png` | **moved** from `figures/T13/` |

**Precedent:** `Gayini_reference_state_results_catalogue.xlsx` was force-added past the global
`*.xlsx` ignore for exactly this reason — a deliverable that must be recoverable by version, not
merely by checksum.

**Scope limits, deliberately:** `Output/` is **not** force-added generally, and nothing is mirrored
to a second folder. **One canonical location.** The T13 figures moved to `Output/figures/` rather
than being copied, so `figures/T13/` no longer exists and `figure_asset` carries no stale path
(verified: 0 rows matching `figures/T13/%`; git recorded both as renames). The wider output-folder
question is **not** reopened here — this is a narrow exception for client-deliverable items, and
I-16 remains parked.

## 7. Invariants

- Assembly only: no refit, no new analysis, no builder run, no existing object modified, no p-values.
- Figures registered via `gayini_write_and_register_figure()` — `figure_asset` **278 → 283**.
- Deck palette (the T13 Gate D semantic set), not viridis.
- Captions written for a reader who has not seen the analysis; each states support level, and none attributes a cause.
