# Report batch — handoff to Claude Code

**From:** design seat · **Date:** 4 August 2026 · **Deadline:** 10 August
**Delivered:** working builder, 32 documents, 11 figure families
**Your job:** land it in the repository, reconcile every number against the source of truth,
document the figures, and extend the batch if the 52-document set is confirmed.

**Version 1.1 · 4 August 2026, second issue.** Check this block before quoting any section.
A v1.0 copy was circulated earlier the same day and **does not contain §8.4**; if the copy you hold
stops at §8.3, it is stale — replace it before proceeding. Builder version in
`scripts/15_reports/EXPECTED_OUTPUT.json` must read `1.1`.

**Supersedes** the 29 July handoff, written before T10 Gate D and REG-1 registered the expectation
apparatus, and the v1.0 issue of this file.

### Changes in 1.1 — all from the REPORTS Gate 0 inventory, 4 August

| | |
|---|---|
| §8.4 added | the DOC-1 audit findings and the checks the reports must keep |
| `paths.json` | `db`/`gpkg` repointed to `Output/database/`; **`figure_source` split into `figure_source_c1` and `figure_source_d2`** — C1 paddock renders and D2 site dashboards are in different folders and one key cannot serve both |
| record span derived | `1988–2022`, `35 years`, and `Math.round(r.ff*0.35)` were typed literals in paddock prose. Now `year_first` / `year_last` / `n_years` from `fact_zone_veg_annual`, matching what the site report already did |
| `EXPECTED_OUTPUT.json` | carries `builder_version` and the **render inventory it was built against** — see §7.1 |

---

## 0. Where things go

Follow the existing numbered-stage convention (`scripts/13_pack`, `scripts/14_lidar`):

```
scripts/15_reports/                 <- NEW. The builder.
    report_data.py                  data layer: contract SQL, registry reads, canaries
    report_figs.py                  figure builder: 11 families, parameterised
    report_build.js                 document builder: page model, degradation
    check_page_fill.py              render QA
    README.md                       copy of §7 below, as the module's own doc

docs/reports/                       <- documentation only
    Gayini_report_batch_CC_handoff.md    this file
    Gayini_report_template_spec.md       page model, degradation, rendering traps (from §7)
    Gayini_report_batch_methods.md       the per-figure methods document you will write (§4)

Output/reports/                     generated documents — .docx plus PDF export
Output/figures/reports/             generated figures (registered, §5)
docs/change_reports/                your change report for this build
```

**Do not put generated documents in `docs/`.** `docs/reports/` is the written record of how the
reports are built; the reports themselves are build output and belong under `Output/`.

Node dependency: `docx` (npm). Python: `matplotlib`, `pandas`, `geopandas`, `pillow`.
The render check needs LibreOffice (`soffice`) and Poppler (`pdftoppm`, `pdfinfo`, `pdfimages`).

---

## 1. Run order

```
python  scripts/15_reports/report_data.py  --paddocks "Bala 26ca" … --sites GA_001 …
python  scripts/15_reports/report_figs.py
node    scripts/15_reports/report_build.js
python  scripts/15_reports/check_page_fill.py
```

`report_data.py` writes one JSON per unit; `report_figs.py` reads those and writes figures plus
`figs_meta.json`; `report_build.js` reads both and writes the documents. Paths are constants at the
top of each file — repoint them once, do not scatter them.

---

## 2. Gate structure

Recon first. Echo this spec at the start of each gate.

| gate | output | stop condition |
|---|---|---|
| **0** | inventory: C1 and D2 renders per selected unit; registry constants present | anything missing is listed, not worked around |
| **1** | builder relocated and running from the repo; the 32 documents reproduced | any number differs from this delivery without an explanation |
| **2** | reconciliation (§3) | any number that cannot be traced by an independent path |
| **3** | methods document (§4) | any figure without a complete entry |
| **4** | remaining units, if the 52 set is confirmed (§6) | — |
| **5** | registration and review bundle (§5) | non-additive write attempted |

---

## 3. Reconciliation — the part that matters

The builder already reads at render rather than embedding literals, and asserts before writing.
Your job is to prove it end to end.

**Already in place, do not weaken:**

- Four registered constants asserted at `1e-4` before any document is written:
  `floor_flood_slope_64pdk`, `_intercept_64pdk`, `_r_64pdk`, `_residual_sd_64pdk`. A re-pin halts
  the build. **Assert tighter than the precision you depend on** — a `1e-2` guard would have slept
  through the 31 July precision correction.
- Four contract canaries recompute through the builder's own path and are checked against
  `dim_headline_number` before any document is written:
  `rptscope_canary_p1_paddock_floor_bala29ca` (40.52),
  `rptscope_canary_p3_composition_share_bala29ca_inland` (34.59),
  `rptscope_canary_p5_recovering_parts_bala29ca` (2),
  `t10_bala29ca_xsec_residual` (−16.80).
- The residual is read from `v_zone_floor_flood_residual`, never recomputed.
- Part states are read from `fact_zone_community_part_classification.state_registered`.

**To add:**

1. **Run `test_T8_headline_reproduction.py` before every batch.** Deliberately not wired into the
   smoke test (I-19); it must be invoked explicitly. Exits non-zero on drift.
2. **Prove the canaries can fail.** Mutate a fixture so a canary returns a wrong value and confirm
   the build halts. A check that has never fired is not a check — and a fixture that merely makes
   the code crash proves only that the code path is reachable.
3. **Read the scope-lock string from the contract** rather than the constant in `report_build.js`.
   `RPTSCOPE_number_contract.csv` carries it as a text constant precisely because a string that
   asserts scope can drift like any number.

---

## 4. The methods document — `docs/reports/Gayini_report_batch_methods.md`

One section per figure family. Eleven families: `map` (C1 and locator variants), `comp`, `series`,
`parts`, `scatter`, `gap`, `effect`, `sites`, `sseries`, `speers`, `sflood`.

Each section:

1. **What it shows**, in the words used in the report caption.
2. **Source objects** — table or view, and the exact filter (`series_variant`, `n_pixels_valid`,
   `treed_context_flag`, `regime_band`, water-year span).
3. **The query**, reproduced verbatim.
4. **Aggregation order and weighting** — year-first or unit-first, equal / area / pixel. This is
   where the gap series diverges; see §8.1.
5. **Every number that appears on the figure**, with its value and provenance. Axis limits excepted.
6. **Reconciliation** — the value re-derived by an independent path, and whether it matches. Where a
   registered value exists, the figure must use the registered value and the section must say so.
7. **Support, denominator, pixel constant, period label.**
8. **Limitations** carried into the caption.

Not a narrative — a reconciliation table with prose around it. **If a number on a figure cannot be
traced to a source object by an independent path, the figure does not ship.**

---

## 5. Registration

- Figures via `write_and_register_figure()`, **additive only**, new `run_id`.
- Nothing in `dim_headline_number` is modified. If a report needs a number that is not registered,
  that is a gate stop, not a reason to compute one.
- DB reads: `mode=ro`, `PRAGMA query_only=1`. The builder already does this.
- Never re-run the RS builder. Never join the two SQLite databases in code.
- Commits authored by Hugh. No AI attribution trailers. Rasters and large spatial data not
  committed. Branch and PR; the human merges.

---

## 6. The document set — unresolved, needs a design-seat ruling

| source | paddocks | sites | total |
|---|---|---|---|
| handoff §2 (4 Aug) | 21 | 31 | **52** |
| `RPTSCOPE_report_set.csv` | 7 | 25 | **32** |

Both internally consistent. The §2 rule — conserved, plus every grazed paddock containing a part
classified Recovering or Declining — **reproduces exactly** against
`fact_zone_community_part_classification`: 17 grazed paddocks matching the named list member for
member, plus 4 conserved, and 31 non-treed sites inside them.

This delivery builds the **CSV set**, because it matches the handoff's own QA tiering — *full
design-seat read: the four conserved, plus Bala 15 and Dinan 10* — plus Dinan 8, the grazed paddock
carrying the most reportable sites.

**Do not resolve this yourself.** If the design seat confirms 52, the extension is arguments only:

```
--paddocks "Dinan 9" "Dinan 13" "Dinan 7" "Bala 8/11" "Bala 20" "Bala 12" "Bala 1" \
           "Bala 2" "Bala 5" "Bala 13" "Bala 7/10" "Mara 4" "Mara 7" "Mara 18"
--sites    <the 6 remaining non-treed sites in those paddocks>
```

No code change needed. Note `Bala 8/11` and `Bala 7/10` contain a slash — the builder slugs it to
`-`, so check the C1 render filenames match.

---

## 7. The template is the specification

**Do not redesign it.** Three things look like cruft and are load-bearing:

1. **Every table needs `TableLayoutType.FIXED`** and a grid summing exactly to the table width.
   Word applies autofit otherwise and collapses the figure column. Invisible in LibreOffice, so it
   will pass your render check and fail on Hugh's screen.
2. **Image paragraphs must carry no line-spacing rule.** A `spacing.line` value clamps the line box
   and renders every picture at roughly a third of its declared height while the XML extent stays
   correct. Symptom: pages look two-thirds empty and content spills to phantom pages.
3. **Never save a matplotlib figure with `bbox_inches='tight'`.** It changes the output aspect
   ratio, so the width→height calculation in `img()` no longer matches and axis labels clip.

### 7.1 What `verify_batch.py` does and does not prove

It proves the visible text of a rebuild matches the recorded fingerprint. It does **not** prove any
number is correct — that is what Gate 2 and the methods document are for. Do not report "32 match"
as verification of the reports; report it as evidence that nothing moved between two builds.

**Fingerprints depend on the render inventory.** The map caption differs between the C1 checkerboard
and the locator fallback, and the site page-1 figure differs between the D2 crop and the flood-record
fallback. A different inventory therefore produces `CHANGED` on the affected units. That is an
**explained input difference, not drift**. The procedure:

1. confirm the diff is confined to the map caption and the site page-1 figure for exactly the units
   whose render availability changed — nothing else;
2. re-fingerprint, recording the new inventory in `built_with`;
3. state the inventory in the change report.

`EXPECTED_OUTPUT.json` as shipped was built with **1 C1 render and 11 D2 renders**. Gate 0 reports
5 C1 and 25 D2 available on the repo, so `CHANGED` on those units is expected and correct.

**Page fill target 70–90%**, measured against non-white pixels — the figure canvas is warm cream
and a dark-ink threshold reads it as an empty page. Above ~93% Word spills and produces a blank
page. All 32 documents in this delivery sit inside the band.

### Page model

| page | paddock report |
|---|---|
| 1 | title · in plain terms · country it covers · the water · band table · map · summary cards |
| 2 | the 35-year record — flood extent and cover · reading notes · year cards |
| 3 | **the parts**, each against its own community · part table · what this changes |
| 4 | how it compares — expectation and residual · annual gap series · the conserved set |
| 5 | monitoring sites — 3-panel figure · what we don't know · site table · footer |

Site report is 2 pages. Single-community paddocks drop page 3 and run to 4.

### Degradation — all query-driven, no per-paddock exceptions

| case | behaviour |
|---|---|
| 1 community | no parts page; the single part's registered state moves to page 1 as prose |
| 2–3 communities | parts figure and table scale to the row count |
| ≥8 sites | sites figure and table scale; the reading note is suppressed |
| no sites | figure and table replaced by what the satellite still supports, plus the standard-grazing structural exclusion |
| no C1 render | locator map from `management_zones`; if that is degenerate, the composition figure |
| no D2 render | site flood-record figure from the plot spine |

### Content rules the reports inherit

- `veg_p05_spatial` only. Reaching for `census_by_zone_stratum.veg_p05_mean` for a reference-state
  purpose is a **STOP**, not a judgement call.
- The word *floor* is never used bare in client text — two different objects carry that name, and
  they differ by up to 17 pp at part grain in opposite directions by community.
- No p-values anywhere. No period-boundary statistics.
- Support levels never merged in one figure.
- The two flood rules differ and both are correct; every report says so. Keep that sentence.
- DEA cultivation calls never appear, at any confidence level (T12 §2.8).
- **A caption must never promise something the figure did not draw.** `figs_meta.json` records what
  each map actually rendered and the builder captions from it. This was a live bug: the locator
  caption read *"White squares are the monitoring sites reported here"* on a figure that had
  suppressed them for the reason in §8.2.

---

## 8. Three known defects — resolve, do not inherit

### 8.1 The annual gap series does not reconcile

| series | registered | design-seat re-derivation |
|---|---|---|
| `t10_gap_annual_slope_C_29ca` | 0.919 | 0.858 equal · 0.860 area · 0.864 pixel-weighted |
| `t10_gap_annual_slope_A_all4` | 0.273 | 0.277 area-weighted |
| `t10_gap_annual_slope_B_excl29ca` | 0.057 | −0.004 equal · 0.001 area |

The reference-set figure closes under area weighting; the single-paddock one does not. The figure
currently draws the **registered** slope and the text quotes it; only the annual points are derived.

**Rebuild the series from `Output/tables/T10_annual_gap_series.csv`** — the design seat does not
have it — and record the outcome in the methods document. Do not reconcile to the design-seat
number: it is a prediction, not a target.

### 8.2 The GeoPackage is not map-ready

`README_Gayini_Results_database.md` calls `Gayini_Results.gpkg` the "map-ready spatial companion".
For two of its four layers that is not currently true.

| layer | state |
|---|---|
| `management_zones` | 12 of 64 stored invalid (repaired on load with `buffer(0)`); heavily simplified — median 18 vertices, 4 are bare quadrilaterals; **`Bala 29ca` is degenerate**: 5 coincident vertices, 1 m extent |
| `vegetation_units` | 20 features for the whole property, 17 invalid — cannot support a vegetation map |
| `gayini_boundary` | 9 vertices, 204 m extent, against a property ~30 km across |
| `plots_current_summary` | sound — 66 valid 1 ha footprints |

**The consequence that reaches a client page:** of the 48 plots `plot_paddock` places inside a zone,
**19 fall outside their stored zone polygon** — all of Bala 29ca's and all of Dinan 8's. The
database is the source of truth, so a map drawn from the polygon contradicts the site table on the
same page.

The builder therefore draws site markers only when every site validates inside the drawn polygon,
and otherwise prints a note on the figure and adjusts the caption. **Raise this as an issues-log
entry.** The fix is upstream: re-export `management_zones` and `vegetation_units` from source at
full vertex density. Until then the locator cannot show sites for roughly 40% of zoned plots.

### 8.3 The C1 renders are the better map and should be preferred

The builder prefers `C1_veg_regime_paddock_{slug}_data.png` where it exists, because it carries
vegetation and wetness banding the locator cannot. Confirm at Gate 0 which selected paddocks have
one. The design seat had only Bala 29ca locally, so the locator path is better-exercised than it
will be on the repo — check the C1 path renders correctly for several paddocks before the batch.

---

## 8.4 Two audit findings from the methods-doc stream that the reports must not repeat

DOC-1 Gate B (4 August) found two CONTRADICTED claims in the methods document, **both support-level
errors, both in numbers previously read off a rendered figure rather than queried**. The report
batch has been checked against the same two classes and is clean, but the checks must stay:

**Never pair a plot-support numerator with a pixel-support denominator.** DOC-1 §7.3 said *"six of
the eight measurable strata meet the 0.20 threshold"* — six is the plot count, eight the census
count. This is the C10 rule. In the reports, plot support (`v_plot_year_analysis_spine`, the site
figures and the site table) and pixel support (`fact_zone_veg_annual`, `v_census_by_zone_stratum`,
every paddock headline) must never share a numerator and denominator. **Checked 4 Aug: no such
construction in the batch.**

**Name the footprint whenever an area or a share is quoted.** DOC-1's 3.03% green share is over
86,385 ha — farm boundary, native 30 m, treed included — while persistence areas in the same
paragraph are over 61,655 ha non-treed. A footprint 40% larger than the scope beside it, unstated.
In the reports, *"the property"* must always denote a countable set (the 64 paddocks, the 57
non-treed sites), never an area. **Checked 4 Aug: band areas reconcile to the stated in-scope area
to 0.0 ha in all seven paddocks, and "the property" is used only as a set.**

**One typed literal was found and fixed.** The no-sites page carried `${'57'}` — the non-treed site
count as a string constant. It is now derived from `dim_plot` and `plot_paddock` alongside the zoned
count (57 non-treed, 39 zoned), and the sentence states both. *A criterion stated as a typed literal
is not a check* — the rule applies to prose as much as to acceptance tests. **Grep the builder for
digit literals in template strings before every batch.**

---

## 9. What the design seat still owns

Do not decide these in a build session; return them:

- the 32-vs-52 document set (§6);
- any change to the page model, section order, or the plain-language register;
- whether the marginal wording on Bala 29ca's Inland part is right — it is `Declining` at `trend_z`
  −1.108 against a −1.000 cut, `dist_to_nearest_cut` 0.038, and it flips to `Unremarkable` at cuts
  1.25 and 1.50 and under drop-two-wettest. The reports render it as *"Declining, marginally"* with
  a sentence on the boundary;
- any wording where a report and the Adrian pack describe the same quantity differently — that is a
  finding to report, not a difference to reconcile.
