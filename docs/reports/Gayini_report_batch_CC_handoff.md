# Report batch — handoff spec for Claude Code

**From:** design seat (report stream) · **Date:** 29 July 2026
**Scope:** 4 conservation paddock reports + 21 site reports = **25 documents**
**Template status:** stable. Bala 29ca and GA_036 are the reference implementation.
**Rule for this task:** the template is the specification. Do not redesign it.

---

## 0. Division of labour

| design seat (chat) | Claude Code |
|---|---|
| page structure, figure grammar, wording, degradation rules | parameterisation, batch execution |
| — settled, in this spec | reconciliation of every number against the SOT |
| | per-figure methods documentation |
| | figure registration, review bundle |

**Why CC and not the design seat:** the batch needs the repository on disk — `Output/tables/`,
the FC and inundation rasters, `T10_annual_gap_series.csv`, `T10_gateC_percommunity.csv`,
`write_and_register_figure()`, and `test_T8_headline_reproduction.py`. The design seat has a
database snapshot and nothing else. Every number in the current drafts is a design-seat
derivation and must be re-derived by CC from source before publication.

---

## 1. Gate structure

Recon first. No document generation before Gate 0 passes.

| gate | output | stop condition |
|---|---|---|
| **0** | inventory: which inputs exist for all 4 paddocks and 21 sites | any missing input listed, not worked around |
| **A** | parameterisation layer — one query module returning a per-unit record | every field traced to a source object |
| **B** | figure batch — 9 paddock figures × 4, 3 site figures × 21 | aspect ratios match §5; nothing clipped |
| **C** | methods document (§6) | every figure has an entry; every number reconciles |
| **D** | document batch — 25 files | page counts and fill within §4 tolerance |
| **E** | registration + review bundle | additive writes only |

Re-read this spec in full and echo it verbatim at the start of every gate.

---

## 2. Gate 0 — inventory

Confirm on disk, do not assume:

- `C1_veg_regime_paddock_{Bala_26ca,Bala_27ca,Bala_28ca,Bala_29ca}_data.png` — the page-1 map
  source. Only Bala 29ca is known to the design seat.
- `D2_site_{plot}_slide_data.png` for all 21 reportable plots — the site-report map panel.
- `Output/tables/T10_annual_gap_series.csv` — page 4.
- `Output/tables/T10_gateC_percommunity.csv` — page 3 (115 rows).
- The registered intercept for the expectation line. RS said on 29 July it was not yet
  registered and they would add it. **Without it page 4's line cannot be drawn.** If absent at
  Gate 0, stop and report.

---

## 3. Gate A — the parameterisation contract

One record per unit. Every field names its source object.

### Paddock record

| field | source | notes |
|---|---|---|
| area_ha_nontreed, area_ha_treed | `v_census_by_zone_stratum` | treed excluded from all headline figures |
| composition (share per community) | `v_census_by_zone_stratum`, `treed_context_flag = 0` | **two denominators** — see §3.1 |
| flood_frac_pct, rank of 64 | `fact_zone_veg_annual`, `mean_of_seasons` | |
| veg_p05_spatial, rank of 64 | `fact_zone_veg_annual` | never called "floor" in client text |
| band areas and flood frequency | `v_census_by_zone_stratum` | low / mid / high |
| expectation, residual | registered T10 Gate D objects | do **not** refit |
| annual gap series | `T10_annual_gap_series.csv` | page 4 — see §7.1 |
| per-part level, rank, trend | `fact_zone_community_veg_annual` | `n_pixels_valid >= 30`, ≥25 years |
| sites | `plot_paddock` ⋈ `dim_plot.treed_plot_flag = 0` | |

### Site record

| field | source |
|---|---|
| community, area, parent paddock | `dim_plot`, `plot_paddock` |
| flood frequency (any-water rule) | `v_plot_year_analysis_spine.annual_wet_any` |
| total / green / dead / bare | `v_plot_year_analysis_spine` |
| rank within its own community | same, restricted to `treed_plot_flag = 0` |
| spatial_review_flag, cultural_sensitivity | `dim_plot` — banner logic |

### 3.1 Composition denominators

Carry both, per RS §3. **Client text uses the all-classes denominator** so shares sum to the
whole paddock; analysis uses the three focus communities. Verified 29 July:

| paddock | all classes | focus only | parts with ≥25 yr | reportable sites |
|---|---|---|---|---|
| Bala 26ca | Inland 98 · Riverine 2 | Inland 98 | 2 | 3 |
| Bala 27ca | Inland 100 | Inland 100 | 1 | 0 |
| Bala 28ca | Inland 83 · Riverine 17 | Inland 83 | 2 | 8 |
| Bala 29ca | Inland 35 · Riverine 33 · Aeolian 32 | same | 3 | 10 |

---

## 4. Page model and tolerances

Paddock report, 5 pages A4 landscape. Site report, 2 pages.

| page | content |
|---|---|
| 1 | title · in plain terms · country it covers · the water · band table · community map · summary cards |
| 2 | the 35-year record — flood extent and cover · reading notes · year cards |
| 3 | **the parts** — each against its own community · part table · what this changes |
| 4 | how it compares — expectation and residual · the annual gap series · the four not-grazed |
| 5 | monitoring sites — 3-panel figure · what we don't know · site table · footer |

**Page fill must land 82–90%** measured by `check_page_fill.py`. Above 92% Word will spill and
produce a blank page; below 80% there is visible dead space. The band is deliberate headroom
for Word's line metrics differing from LibreOffice's.

### 4.1 Degradation rules — mandatory

Per RS §5, **page 3 runs in all four reports** and shrinks rather than disappearing.

| case | behaviour |
|---|---|
| single community (Bala 27ca) | page 3 becomes three lines: *"this paddock is entirely Inland floodplain country, so the figures in this report describe it directly."* No figure, no table. |
| two parts (26ca, 28ca) | figure with two rows; table with two parts plus the whole-paddock row |
| three parts (29ca) | as the reference implementation |
| **zero sites (Bala 27ca)** | page 5 drops the 3-panel figure and the site table; keeps "what we don't know" and the footer. State plainly that no monitoring sites fall inside this paddock and name the nearest. |

### 4.2 Narrative must not be templated

RS §6 is explicit: Bala 27ca has the smallest residual (−0.91) and is **declining** relative to
water (−0.337 pp/yr adjusted). It is a different story from Bala 29ca and must not inherit the
recovery narrative. The "in plain terms" paragraph and the page-4 text are per-paddock prose,
written from that paddock's numbers — not a fill-in-the-blanks string.

---

## 5. Figures

| name | aspect | grain |
|---|---|---|
| `P_map_country` | ~1.64 | composite: C1 map + community×wetness legend, grey context legend removed |
| `P_series` | 2.50 | paddock |
| `P_parts` | 3.14 | paddock × community |
| `P_scatter` | 1.54 | 64 paddocks |
| `P_gap` | 1.59 | paddock, annual |
| `P_effect` | 3.54 | the four not-grazed |
| `P_sites` | 2.90 | 3 panels — wetness · composition · community boxplot |
| `S_series`, `S_peers`, `S_map` | 2.86 / 1.64 / 1.25 | site |

### Two rendering traps — both load-bearing, do not "simplify"

1. **Tables need `TableLayoutType.FIXED`** and every cell needs an explicit width, with the grid
   summing exactly. Word autofit otherwise collapses the figure column. Invisible in LibreOffice.
2. **Image paragraphs must carry no line-spacing rule.** A `spacing.line` value clamps the line
   box and renders every picture at roughly a third of its declared height while the XML extent
   stays correct.

Also: never save a figure with `bbox_inches='tight'` — it changes the output aspect, which
breaks the width→height calculation and clips axis labels.

---

## 6. Gate C — the methods document

**One markdown file, one section per figure.** Required for every figure in §5. Each section:

1. **What it shows**, in the words used in the report caption.
2. **Source objects** — table or view name, and the exact filter (`series_variant`,
   `n_pixels_valid`, `treed_context_flag`, scope).
3. **The query**, reproduced.
4. **Aggregation order** — year-first or unit-first, and weighting (equal / area / pixel). This
   is where the current drafts are weakest; see §7.1.
5. **Every number that appears on the figure**, listed with its value and where it came from —
   axis limits excepted.
6. **Reconciliation** — the value re-derived by an independent path, and whether it matches.
   Where a registered value exists in `dim_headline_number`, the figure must use the registered
   value and the section must state it.
7. **Support and denominator** — pixel constant, denominator, period label, support level.
8. **Known limitations** carried into the report caption.

The document is not a narrative. It is a reconciliation table with prose around it. If a number
on a figure cannot be traced to a source object by an independent path, the figure does not ship.

**Run `test_T8_headline_reproduction.py` before the batch**, per RS §7. It is not in the smoke
test (I-19) so it must be invoked explicitly. It exits non-zero on drift.

---

## 7. Known defects CC must resolve — do not inherit

### 7.1 The annual gap series does not reconcile

The design seat could not reproduce the registered T10 Gate B values:

| series | registered (RS) | design-seat re-derivation |
|---|---|---|
| reference set | +0.273 pp/yr, r 0.770 | +0.211 equal-weighted · **+0.277 area-weighted**, r 0.83 |
| Bala 29ca alone | +0.919, r 0.846 | +0.858 equal · +0.860 area · +0.864 pixel |
| excluding Bala 29ca | +0.057, r 0.222 | −0.004 equal · +0.001 area |

Area-weighting the grazed baseline closes the reference-set figure and does **not** close
Bala 29ca. The remaining difference is an aggregation-order or scope question. **Use
`T10_annual_gap_series.csv` directly rather than recomputing**, and record the discrepancy in
the methods document. Do not reconcile to the design-seat number — it is a prediction, not a
target.

### 7.2 The five-period trajectory is gone and must stay gone

PIN 3, `pinned_value` NULL, blocked on I-29, no producing script, boundaries without provenance.
RS: *"it will never be registered."* It has been removed from the template. If it reappears in
any figure or table, that is a regression.

### 7.3 DEA cultivation calls never appear

T12 §2.8 — the 2 `likely` and 40 `possible` zone-era calls are recorded false positives and must
not be described as cultivated anywhere, at any confidence level. The "what we don't know" panel
states that land-use history is unrecorded and that a satellite product was tested and cannot
supply it.

### 7.4 Two objects are both called "the floor"

`veg_p05_spatial` (within-year, across pixels) and census `veg_p05` (temporal, per pixel) are not
comparable. Client text uses plain-language descriptions and never the bare word. Reports use
`veg_p05_spatial`.

### 7.5 Scope lock

One scope per document, declared in the footer: **non-treed ground, whole paddock, full record
1988–2023**. Any figure on a different scope states it in its own caption. RS §7 proposes
enforcing this by reading `scope_filter` from `dim_headline_number` rather than by convention —
adopt that if the plumbing lands in time.

---

## 8. Open question back to the report stream

RS §4.3 asks whether anything on site-report page 2 needs a paddock-grain number it cannot have.
**Answer: no.** Page 2 carries the site's own cover composition series, the "paddock it sits in"
cross-reference (prose only, no numbers), and the "what we don't know" panel. The only
paddock-grain figure on the site report is the qualitative statement that the parent paddock's
wettest corner floods eleven times as often as its driest, which is sourced from
`v_census_by_zone_stratum` band figures and carries no support conflict.

---

## 9. Deliverables

- 25 documents in `Output/reports/`, `.docx` plus PDF export
- one methods document covering all figure families
- figures registered via `write_and_register_figure()`, additive only, new `run_id`
- change report in `docs/change_reports/`
- review bundle per the standing convention

Commits authored by Hugh, no AI attribution trailers. Rasters and large spatial data never
committed. Branch and PR; the human merges.
