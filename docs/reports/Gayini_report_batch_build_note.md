# Gayini report batch — design-seat build, 4 August 2026

**32 documents:** 7 paddock reports, 25 site reports. Built from `Gayini_Results.sqlite`
read-only, parameterised against `RPTSCOPE_number_contract.csv`.

**No number in these documents is typed as a literal.** Every value is read from the database
at render time, per the standing rule: *a number in a document is a copy; a number read at
render time is a fact.*

---

## 1. What is in the package

| | |
|---|---|
| `reports/` | 32 `.docx` plus PDF export |
| `code/report_data.py` | data layer — one JSON record per unit, contract SQL, registry reads, canaries |
| `code/report_figs.py` | figure builder — 11 figure families, parameterised |
| `code/report_build.js` | document builder — page model and degradation |
| `code/check_page_fill.py` | render QA |

Run order: `report_data.py --paddocks … --sites …` → `report_figs.py` → `report_build.js`
→ `check_page_fill.py`.

---

## 2. REP-PAGE4 — closed, and it was a live defect

The 29 July template **fitted its own regression** (`np.polyfit` over the 64 paddocks) to draw
page 4's expectation line. RS's 31 July note asked whether that was happening. It was. Had the
batch run unchanged, an unregistered fit would have gone into every client document.

Now:

- the line is drawn from `floor_flood_intercept_64pdk` and `floor_flood_slope_64pdk`, read at
  render and **printed in the caption** so a reader can see what was used;
- the band is `floor_flood_residual_sd_64pdk` (6.6208), not the 6.7 that was previously hardcoded;
- **the residual is read from `v_zone_floor_flood_residual`, never recomputed** — RS's item 2,
  and the reason M5b did not drift when the constants were re-pinned;
- all four constants are **asserted at 1e-4 before any document is written**. A re-pin halts the
  build rather than silently changing 32 documents.

```
registry OK — 101 rows; 4 constants asserted at 1e-4
```

**The stale README line 103 is deleted.** It claimed these numbers were unregistered; they had
been registered since 28 July.

### Canaries

All four contract canaries recompute from the builder's own path and are checked against the
registry before any document is written:

| canary | registered | builder |
|---|---|---|
| `rptscope_canary_p1_paddock_floor_bala29ca` | 40.52 | 40.52 |
| `rptscope_canary_p3_composition_share_bala29ca_inland` | 34.59 | 34.59 |
| `rptscope_canary_p5_recovering_parts_bala29ca` | 2 | 2 |
| `t10_bala29ca_xsec_residual` | −16.80 | −16.80 |

---

## 3. The four handoff corrections

| | status |
|---|---|
| **C-1** site count contradicts the dashboard | Applied. *"Ten of the thirteen monitoring sites here are reported. Three sit under tree canopy…"* — generated from `n_sites_total` and `treed_plot_flag`, so it degrades correctly where no sites are treed. |
| **C-2** drop the period comparison | Applied. The *first-ten-vs-last-ten* card is gone. Zero period-boundary statistics anywhere in the batch. |
| **C-3** Inland softened below its registered state | Applied. Part states now come from `fact_zone_community_part_classification.state_registered`. Bala 29ca's Inland part reads **Declining, marginally** — see §5. |
| **C-4** stale scope note | Applied. *"provisional pending pipeline registration"* is deleted and replaced with a statement that the line and the residual are read from the registry at render. |

Also applied from §4: no p-values anywhere; `veg_p05_spatial` only; the two flood rules stated as
different and both correct; support levels never merged in one figure.

---

## 4. Degradation, and why it is not conditional prose

Every branch is driven by a query result, not by a per-paddock exception.

| case | behaviour | seen in |
|---|---|---|
| 3 communities | full parts page, 3 rows | Bala 29ca, Dinan 8, Dinan 10 |
| 2 communities | parts page, 2 rows | Bala 26ca, Bala 28ca |
| 1 community | **no parts page** — the paddock's single part state moves to page 1 as prose | Bala 27ca, Bala 15 |
| sites present | 3-panel figure, site table, reading note | 26ca, 28ca, 29ca, Dinan 8 |
| ≥8 sites | figure and table scale; reading note suppressed | Bala 28ca, Bala 29ca |
| **no sites** | figure and table replaced by what the satellite still supports, plus the standard-grazing structural exclusion | Bala 27ca, Bala 15, Dinan 10 |
| no C1 map on disk | composition figure substituted, built from the census | all but Bala 29ca here |
| no D2 site map on disk | flood-record figure substituted, built from the plot spine | 14 of 25 sites |

The last two matter for the handoff: **the map fallbacks fire because this seat has only one C1
and ten D2 renders locally.** On the repository they will not fire. They are worth keeping
regardless — a paddock report should not depend on a pre-existing figure render.

Page counts follow the branch: 4 pages single-community, 5 pages multi-community, 2 pages site.

---

## 5. Two findings, not defects

**Bala 29ca's Inland part is `Declining` but marginal.** `trend_z` = −1.108 against a cut of
−1.000; `dist_to_nearest_cut` = 0.038; `robustness_changed` = 1. It is Declining at cuts 0.50,
0.75 and 1.00, **Unremarkable at 1.25 and 1.50, and Unremarkable when the two wettest years are
dropped.** The reports render it as *"Declining, marginally"* and add a sentence saying it sits
close to the boundary and would read differently under a slightly different cut. That satisfies
C-3 — the registered state is used — without asserting more confidence than the classification
carries. The other two parts are Recovering at every cut and under drop-two, which is what claim 4
in the handoff §5 rests on.

**The annual gap series does not reconcile.** `t10_gap_annual_slope_C_29ca` = 0.919. Re-deriving
from `fact_zone_veg_annual` with an area-weighted grazed baseline gives 0.860; equal-weighted
0.858; pixel-weighted 0.864. The reference-set figure does close (registered 0.273, area-weighted
0.277), so the difference is specific to the single-paddock series. **The registered slope is what
the figure draws and what the text quotes**; only the annual points are derived. CC should rebuild
the series from `Output/tables/T10_annual_gap_series.csv`, which this seat does not have, and
record the outcome. Flagged rather than reconciled, per the standing rule.

---

## 6. The document set — a discrepancy to settle

| source | paddocks | sites | total |
|---|---|---|---|
| handoff §2 | 21 | 31 | **52** |
| `RPTSCOPE_report_set.csv` | 7 | 25 | **32** |

Both are internally consistent. The handoff §2 rule — *conserved, plus every grazed paddock
containing a part classified Recovering or Declining* — **reproduces exactly** against
`fact_zone_community_part_classification`: 17 grazed paddocks, matching the named list member for
member, plus the 4 conserved, and 31 non-treed sites inside them.

This batch builds the **CSV set**, because it matches the handoff's own QA tier — *"full
design-seat read: the four conserved, plus Bala 15 and Dinan 10"* — plus Dinan 8, which the CSV
selects as the grazed paddock carrying the most reportable sites. That is the work this seat can
QA properly.

**The remaining 14 paddocks and 6 sites are CC's**, on automated checks, per the same tiering.
The builder needs no change to produce them: add the names to the `--paddocks` and `--sites`
arguments.

Which count governs is a design-seat decision that has not been taken. Recorded here rather than
resolved, per §5 of the handoff: *where a report says something different about the same quantity,
that is a finding to report, not a difference to reconcile.*

---

## 7. Where the reports and the pack agree

Checked against handoff §5.

1. **Removing grazing has not by itself produced a measurably different floor.** The conserved
   paddocks other than Bala 29ca carry residuals of −8.70, −8.31 and −0.91 against a registered
   residual SD of 6.62 — two just outside the ordinary range, one inside it, none in the same
   place. The reports say this per paddock and never assert a treatment effect.
2. **Bala 29ca's floor has been converging since 1988 at +0.92 pp a year, and conservation
   management began in 2019.** Page 4 carries this and the caution that the trend predates the
   change by three decades.
3. **Flood ranks 3, 6, 31 and 61 of 64.** Each paddock's rank is on its own page-1 card, so a
   reader holding two reports sees the spread rather than being told about it.
4. **Eight of 115 parts recovering, two of them in Bala 29ca.** The parts page states each part's
   registered state; the canary asserts the count.

---

## 8. Two rendering traps — still load-bearing

Both cost a full session in July and both look like cruft.

1. **Every table needs `TableLayoutType.FIXED`** and a grid summing exactly to the table width.
   Word applies autofit otherwise and collapses the figure column. Invisible in LibreOffice.
2. **Image paragraphs must carry no line-spacing rule.** A `spacing.line` value clamps the line
   box and renders every picture at roughly a third of its declared height while the XML extent
   stays correct — pages then look two-thirds empty and content spills to phantom pages.

Also: never save a matplotlib figure with `bbox_inches='tight'`. It changes the output aspect
ratio, so the width→height calculation in `img()` no longer matches and axis labels clip.

**Page fill target 70–90%**, measured by `check_page_fill.py` against non-white pixels — the
figure canvas is warm cream and a dark-ink threshold reads it as an empty page. All 32 documents
are inside that band. Above ~93% Word will spill and produce a blank page.

---

## 9. Every paddock now has a map — and a GeoPackage defect found doing it

Maps are built in preference order: the registered **C1 checkerboard** render if it is on disk
(best — it carries vegetation), otherwise a **locator** generated from
`Gayini_Results.gpkg → management_zones` showing the paddock in its neighbourhood with a property
inset, scale bar and monitoring sites. All 7 paddocks have one; on the repository, where all 21 C1
renders exist, the locator will rarely fire.

Building it surfaced three defects in `Gayini_Results.gpkg`. The README describes it as the
"map-ready spatial companion"; for two of its four layers that is not currently true.

| layer | state |
|---|---|
| `management_zones` | **12 of 64 stored invalid** (repaired on load with `buffer(0)`). Heavily simplified — median 18 vertices, and **4 zones are bare quadrilaterals**. **`Bala 29ca` is degenerate**: 5 coincident vertices, 1 m extent, so it cannot be drawn at all. |
| `vegetation_units` | **20 features for the whole property**, 17 invalid. Cannot support a vegetation map; the reports use the census composition figure instead. |
| `gayini_boundary` | single polygon, 9 vertices, 204 m extent against a property ~30 km across. Not usable as a boundary; the locator inset uses the union of `management_zones`. |
| `plots_current_summary` | sound — 66 valid 1 ha footprints. |

**The consequence that reaches a client page:** of the 48 plots that `plot_paddock` places inside
a zone, **19 fall outside their stored zone polygon** — including all of Bala 29ca's and all of
Dinan 8's. The database is the source of truth, so a map drawn from the polygon would contradict
the site table on the same page.

The builder therefore **only draws site markers when every site validates inside the drawn
polygon**, and otherwise prints *"site locations not shown — stored outline too simplified to
place them"*. Bala 29ca is unaffected because its C1 render exists and is used instead.

This is worth an issues-log entry. The fix is upstream: re-export `management_zones` and
`vegetation_units` from source at full vertex density.

---

## 10. Outstanding for CC

1. Rebuild the annual gap series from `T10_annual_gap_series.csv` and reconcile §5.
2. Run `test_T8_headline_reproduction.py` before the batch — it is not in the smoke test (I-19)
   and must be invoked explicitly.
3. Produce the per-figure methods document: source object, exact filter, query, aggregation order
   and weighting, every on-figure number traced, independent-path reconciliation.
4. Register the 11 figure families in `figure_asset`, additive, new `run_id`.
5. Build the remaining 14 paddocks and 6 sites if the 52-document set is confirmed.
6. Confirm the C1 and D2 renders exist for every selected unit; the fallbacks are good but the
   registered renders are better.
7. **Re-export the GeoPackage geometry** — see §9. Until then the locator map cannot show
   monitoring sites for roughly 40% of zoned plots, and Bala 29ca cannot be drawn from it at all.
