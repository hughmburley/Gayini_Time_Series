# PARTREG · Figure 25 at part grain — regression, per-year fits, period summaries

**Design seat · 6 August 2026.**
**Three gated stages. STOP after each.** Stage 1 must be seen before Stage 2 begins.

Figure 25 currently plots 64 points, one per paddock. This recomputes it on the **paddock ×
community part** — the unit Section 11 of the methods document argues is the honest one — giving
~115 points, then tests how stable the relationship is over time.

**No new metric object is created.** Every quantity below is an existing registered series
summarised over a different window.

---

## 0 · Standing conditions

Read-only on the database except where a stage authorises registration. `mode=ro`,
`PRAGMA query_only=1` for all reads. Additive registration only. Render to scratch and report before
any registry write. Recon first — `git fetch`, `git status`, `git log --oneline -10`.

**No p-values anywhere.** Report slope, r, residual SD, and bootstrap intervals. See §4.

---

## 1 · The unit and the two axes

**Unit:** paddock × community part. 118 exist; **115 carry sufficient record** (≥25 years of ≥30
valid cells). The three below support are Bala 15 · Riverine (23 cells), Bala 28ca · Aeolian (10
cells), Mara 3 · Aeolian (1 cell).

**Both axes are per-part-per-year series, then summarised across years.**

| axis | per part, per year | source |
|---|---|---|
| **y — cover floor** | 5th percentile of total vegetation cover **across the part's pixels, within that water year** | `veg_p05_spatial`, existing annual series |
| **x — inundation** | share of the part's pixels wet that year | annual wet/valid stack, 35 bands |

**This is the spatial floor, not the census temporal `veg_p05`.** The two differ by up to 17
percentage points at fine grain and must never be compared. The spatial floor is required here
because it is the only one that keeps a time axis — a temporal p05 recomputed on a shorter window is
a different quantity, not the same quantity in a different period.

**Inundation is deliberately absent from the stratification.** The unit is paddock × community only.
Stratifying by wetness band and then regressing on wetness would be circular — the same error class
as the excluded condition-versus-floor correlation.

---

## 2 · Stage 1 — the full-period fit · **STOP**

**2.1 · Build the part × year table.** One row per part per water year, 115 × 35 = 4,025 rows.
Columns: `part_id`, `zone_id`, `community`, `water_year`, `n_pixels`, `n_valid`, `veg_p05_spatial`,
`inund_pct`. Report row count, any part-year missing, and how missing years are treated.

**2.2 · Summarise across all 35 years**, one row per part. For **each axis** report **mean, median,
SD and IQR** — central tendency and variability on both, as specified.

**2.3 · Fit.** `floor_mean ~ inund_mean`, ordinary least squares.

- **Pixel-weighted, and unweighted, and report both.** Parts run from 636 cells to tens of
  thousands; an unweighted fit gives a 1.9%-of-paddock fragment the same leverage as a 32,000-cell
  part. Weighted is the headline; the unweighted slope is reported beside it as a robustness figure.
- Report slope, intercept, r, residual SD, and n.
- **Compare against the registered 64-paddock line, 52.7 + 0.548 × flood %, r = 0.71.** Report both
  on one panel. **A materially different slope at part grain is a finding**, not an error — it would
  mean the paddock-grain expectation line is an aggregation artefact, which is Section 11's argument
  arriving as evidence.

**2.4 · Also fit on the median summaries**, `floor_median ~ inund_median`, and report whether the
choice of central-tendency measure changes the slope. One sentence if it does not.

**2.5 · The percentile sweep.** Repeat 2.3 with the cover floor at **p05, p10, p20, p30 and p50**,
reporting slope, r and residual SD for each. `Gayini_established_data_facts.md` §12 still lists
*"which veg percentile becomes canonical"* as an open decision. **This closes it with evidence
rather than preference** — and answers any reviewer who asks why the 5th.

**2.6 · Colour by community, and test it.** Fit one pooled line and three community lines. Report
all four slopes. **If the community slopes diverge materially, the pooled expectation line is
misspecified**, and every residual in the delivery pack is measured against it. Report the
divergence; propose nothing.

**Registration at Stage 1:** the part × year table and the part summary table, additive, with
`number_id`s for the headline slope, intercept, r and residual SD. **Nothing else until the design
seat has seen the plot.**

---

## 3 · Stage 2 — the same fit, every year · **STOP**

Run only after Stage 1 is approved.

**35 separate regressions**, one per water year: that year's `inund_pct` against that year's
`veg_p05_spatial`, across the 115 parts. Then **plot slope and intercept against year**, with
bootstrap intervals per year.

**This supersedes the three-period design as the primary sensitivity test**, because it has no
boundaries at all. A trend in the annual slope answers the management question directly and cannot
be attributed to where a period boundary fell — which is the objection that retired the pre/post
framing and cut Figure 24 from the pack.

**Two things to expect and to flag rather than discover:**

- **Dry years carry almost no spread on x.** In a year where little floods, the slope is unstable.
  Report the x-range per year and **flag rather than interpret** years below a stated spread
  threshold.
- **The annual slope will likely be weaker than the long-run r = 0.71.** The long-run fit is an
  equilibrium relationship; cover responds to water with lag. **Say this in the figure text before
  anyone reads it as a failure.**

---

## 4 · Bootstrap, in place of p-values

115 parts nested in 64 paddocks are not independent, and 35 consecutive years are not 35
independent observations. **No p-values.**

Instead: **resample paddocks with replacement — clustered on `zone_id`, not on part** — refit, and
build the slope distribution. 2,000 draws. Report the 2.5th, 50th and 97.5th percentiles, and plot
the fitted slope against the distribution.

Base R is sufficient; no package needed. Apply the same procedure to the three community slopes in
2.6, and report whether their intervals overlap — **that is the proper answer to the geographic
gradient question.**

---

## 5 · Stage 3 — the three periods · **STOP**

Run only after Stage 2 is approved. **These are now summaries of the annual series, not separate
analyses.**

| period | years | note |
|---|---|---|
| Whole record | 1988–2023 | 35 years — the Stage 1 fit |
| Cropping era | 1988–2013 | 26 years — NNTC took control in 2013 |
| Post-management | 2018–2023 | 6 years — irrigation bank cuts dated 2018 |

**2014–2017 sits in neither window, deliberately.** Management-change timing is uncertain — control
transferred in 2013, the cuts are dated 2018 — so the four years between are excluded as a
transition. **State this on the figure**, or it reads as an artefact.

**5.1 · Common part set — this is the item that decides whether the panels are comparable.** Fit on
the parts meeting support in **all three** periods. Report how many are dropped and which. **Also
report the full-period fit on both the common set and the full 115**, so the cost of the restriction
is visible rather than assumed.

**5.2 · Post-2018 support.** Six years is a much weaker basis than 35 for any summary. Report the
per-part year count and state the weakness in the figure text. **Do not compare period *levels*** —
only the fitted relationships. A slope is robust to window wetness in a way a mean is not, because
both axes move together; that distinction is why this analysis survives the period-boundary
objection that cut Figure 24, and it must be stated explicitly.

**5.3 · Three residual maps**, one per period, at part grain, joinable to the paddock boundaries and
the community polygons. Same colour convention as the existing residual map. **Direction stated in
every rank field name**, per §4.6(c).

---

## 6 · Outputs

- `part_year_floor_inund.csv` — 4,025 rows, the analysis spine
- `part_summary_by_period.csv` — one row per part per period, both axes, mean / median / SD / IQR
- `part_regression_coefficients.csv` — every fit run: period, weighting, percentile, community,
  slope, intercept, r, residual SD, n, bootstrap interval
- three scatter figures, coloured by community, with the registered 64-paddock line shown for
  comparison on the full-period panel
- the annual slope-and-intercept series figure from Stage 2
- three residual attribute tables, joinable on part id

**Every output carries its support level, its aggregation order, its period label and its weighting
in the file, not only in the filename.**

---

## 7 · What this is not

It does not use inundation as a stratifier. It does not compare period levels. It does not create a
third p05 object. It does not re-run the census builder. **And it makes no management claim** — a
change in the water–cover relationship is a change in the relationship, and attributing it requires
the land-use history that is still outstanding.
