# Task M · Gate D — deck figures, dual-grid distribution, and the D8 framing fix

*Spec: `docs/Tier2_TaskM_deck_evidence_audit_v2.md` §D.1–D.5, under
`docs/Tier2_TaskM_gateB_classification_v2.md`. Branch `tier2m-deck-evidence`, continuing from
`fb28ca5`. Additive only — no deletes, no overwrites, no builder run. Not merged.*

**Reading this report.** Every number cites the `Output/` artefact it came from, per the CLAUDE.md
standing rule. This report is the home of no value.

## 0. Run context

| Item | Value |
|---|---|
| Hostname | `DESKTOP-K2CLIB0` |
| Branch / base | `tier2m-deck-evidence` @ `fb28ca5` |
| **DB SHA-256 before Gate D** | `096c5a4343738372904729d1659cf6751fc43e709517e4e044904eb9f6d96271` (76,115,968 B) |
| **DB SHA-256 after Gate D** | `dcd5fbf96dd8778e212381cd4bfe9f048a09b4a95ff75127addf3cf9e16ead7b` (76,124,160 B) |
| D.0 commit (established facts) | `6f508db` — one commit, that concern only |
| Builder run? | **No.** `census_stratum` still 11 rows summing to 1,080,157 pixels |
| R / engines | R 4.6.1 (`terra` 1.9.34), duckdb 1.5.4 |

## 0.1 New artefacts

| Artefact | Kind |
|---|---|
| `Output/figures/M1_veg_percentile_maps_p05_p50.png` | figure — §D.1 |
| `Output/figures/M2_all_pixel_method.png` | figure — §D.4 |
| `Output/tables/taskM_gateD_veg_p05_distribution.csv` | evidence — §D.2 (authoritative; copy in `docs/change_reports/`) |
| `Output/tables/taskM_gateD_p05_ge80_contiguity.csv` | evidence — §D.3 (authoritative; copy in `docs/change_reports/`) |
| `Output/tables/taskM_gateD_native30m_p05_cells.csv` | intermediate — per-cell native-30 m extract (30 MB; reproducible; untracked) |
| `scripts/05_ground_cover/05_taskM_gateD_native30m_p05_extract.R` | new script |
| `scripts/05_ground_cover/06_taskM_gateD_p05_ge80_contiguity.R` | new script |
| `scripts/11_database/taskM_gateD_p05_distribution.py` | new script |
| `scripts/07_figures_dashboards/taskM_gateD_M1_percentile_maps.R` | new script |
| `scripts/07_figures_dashboards/taskM_gateD_M2_method.R` | new script |
| `scripts/11_database/register_taskM_gateD_assets.py` | new registrar |

---

## 1. D.0 — the D8 framing correction (committed `6f508db`)

`docs/Gayini_established_data_facts.md` framed D8 as a grid mismatch alone. Corrected there, in one
commit touching only that concern:

- **The variable comes first.** `green_at_floor()` computes `100 × PV ÷ total_veg > 50` — the green
  share of remaining cover, read paired at each pixel's total-veg 5th percentile — **not**
  `veg_p05 >= 50`. No grid argument closes the gap between the two, because they are different
  questions.
- **The grid mismatch is kept where it applies:** the same 71,755 pixels give 6,457.95 ha at 0.09 ha
  (native 3577) and 4,474.03 ha at the 8058 pixel; the ratio is exactly the pixel-area ratio
  (1.443). The published "~4,300 ha" is approximately the second, superseded by the first — not by
  any `veg_p05` figure.
- **"~97% dead at the median"** is stated to read off the green-fraction median of 3.03%, not
  `veg_p50`.
- Every hectare figure in the file now cites `Output/tables/taskM_green_at_floor_area.csv` and
  carries the full definition; the changelog row gives the pointer and omits the value, because a
  one-line row cannot carry the definition the value requires. The lake figure gets its artefact
  pointer and a note that it sits on a different grid.

No number was computed. No flagged number was replaced by another number without its definition.
`CLAUDE.md:40`/`:44` untouched.

---

## 2. D.2 — dual-grid distribution of the floor variable `veg_p05`

**D.2's job changed** (spec note): Rule 8's committed script is now the authoritative source for the
green-share hectare figure. This table **reports the `veg_p05` distribution, not the settlement**,
and does not restate that number. `veg_p05` here is **total cover at the floor** — a different
variable from the green-share measure. Both grids computed through one duckdb engine so columns are
identical. Source: `Output/tables/taskM_gateD_veg_p05_distribution.csv` (authoritative), copy in
`docs/change_reports/`.

- **Grid 1 — census 24.97 m**, `Output/census/gayini_pixel_census_8058.parquet`, focus = non-treed
  three focus communities, `veg_p05` finite, **n = 988,829**, pixel area 0.0623512 ha.
- **Grid 2 — native 30 m**, `Output/rasters/fc_intermediate/total_veg_percentiles_3577.tif` (p05),
  focus mask carried nearest-neighbour from `veg_regime_class_8058.tif`, **n = 685,940 cells**,
  pixel area 0.09 ha, **EPSG:3577** (code inferred from proj4 — the file carries no authority node).
  Grid 2 **was** producible; it is not a resampled census.

### 2.1 Cumulative area, `veg_p05 >= threshold`, both grids (from the CSV)

| Threshold | Census 24.97 m (ha) | Native 30 m (ha) | ratio native ÷ census |
|---:|---:|---:|---:|
| 40 | 50,853.39 | 50,877.09 | 1.0005 |
| 45 | 46,022.79 | 46,111.50 | 1.0019 |
| 50 | 40,935.81 | 41,087.25 | 1.0037 |
| 55 | 35,204.73 | 35,425.17 | 1.0063 |
| 60 | 28,350.34 | 28,649.07 | 1.0105 |
| 65 | 20,045.85 | 20,437.11 | 1.0195 |
| 70 | 12,640.71 | 12,999.69 | 1.0284 |
| 75 | 8,300.38 | 8,497.62 | 1.0238 |
| 80 | 4,179.28 | 4,489.47 | 1.0742 |
| 85 | 106.12 | 237.78 | 2.2407 |

**Ratios reported, not explained.** The two grids agree within ~1% down to the 65 threshold and
diverge in the sparse tail (the 85 row is 106 vs 238 ha — small counts on two grids).

**Whether any threshold reproduces the withdrawn figures, as a plain observation:**
- **~6,460 ha is not reproduced at any threshold on either grid.** The nearest cumulative values
  bracket it between the 75 and 80 thresholds, but no threshold lands on it — consistent with §1:
  6,460 ha is a green-share count, not a `veg_p05` count.
- **~4,300 ha is not reproduced exactly.** The `veg_p05 >= 80` census value is 4,179.28 ha and the
  native value 4,489.47 ha; ~4,300 sits between them. No conclusion is drawn that this validates the
  claim — it does not; the variables differ (§1).

The overall / by-community / by-flood-zone distribution blocks (min, p05, p10, p25, p50, p75, p90,
p95, max, mean, sd) are in the CSV, one row per grid × section × group, each carrying `grid`,
`pixel_area_ha`, `crs_epsg`, `source_artefact`. **No interpretation offered — human review
required.**

---

## 3. D.3 — contiguity of `veg_p05 >= 80`

Source: `Output/tables/taskM_gateD_p05_ge80_contiguity.csv`. The threshold 80 was chosen by the human
**purely to make the existing 4,179.3 ha figure checkable — it carries no ecological meaning and is
not a class.** Census grid (8058, 24.97 m), 8-connectivity.

| Measure | Value |
|---|---|
| Focus pixels with `veg_p05 >= 80` | 67,028 (**4,179.28 ha** — reproduces the 4,179.3 target) |
| Connected components (8-conn) | **745** |
| Component size — min / median / p90 / max (px) | 1 / 4 / 93.6 / 12,630 |
| Component size — min / median / p90 / max (ha) | 0.062 / 0.249 / 5.836 / 787.50 |
| Largest 10 components | 36,890 px = 2,300.14 ha = **55.04% of the total** |
| Largest single component | 12,630 px = 787.50 ha = 18.84% |

By community (share of the >=80 area): Inland Floodplain 98.78% · Riverine 1.21% · Aeolian 0.007%.
By flood zone: zone 3 (1:4–1:2) 57.21% · zone 4 (>1:2) 41.01% · zones 0–2 together 1.77%.
The community × flood-zone joint crosstab is in the CSV.

**Contiguity reported as measured. No interpretation offered — human review required.** Whether the
high-floor pixels form coherent patches or are scattered is the human's question; CC does not answer
it.

---

## 4. D.1 — `M1_veg_percentile_maps_p05_p50.png`

Two panels side by side, p05 left / p50 right, **one shared sequential 0–100 cover scale, single
legend**, identical breaks. Property boundary (petrol) and paddock lines (white,
`management_zones_epsg8058.gpkg`, as in `H6_flood_zone_data.png`). Source rasters resolved from
`raster_asset` (`raster_vegpct_p05` → `total_veg_p05_8058.tif`, `raster_vegpct_p50` →
`total_veg_p50_8058.tif`), cropped + masked to the boundary. Design system: cream `#F8F7F2` page,
petrol-teal `#0F3947` titles, sequential YlGn-family ramp — **not** the community categorical
palette. Titles, subtitle and footer are the spec strings verbatim. **No p50 − p05 difference
panel** (§11).

## 5. D.4 — `M2_all_pixel_method.png`

Single schematic, not a chart of results. Every number is read live from the DB
(`census_stratum`, `dim_plot`) or is a §1 fact; the script hardcodes no result. Conveys: 66
one-hectare plots → 1,080,157 census pixels; the 11 strata (3 communities × 3 wetness bands + 2
context — Floodplain Woodland/Forest 86,375 px, Other/minor 4,951 px, each with per-stratum
`n_pixels`/`area_ha`); mapped 67,349.3 ha of the 85,910.8 ha farm (78.4%); and the honest caveat.
Footer is the spec string verbatim. Insets/legends do not overlap titles or captions (CLAUDE.md).

---

## 6. D.5 — registration, captions, bundle

### 6.1 Registered (6 rows, additive; re-running the registrar inserts 0)

| Asset | Table | `framing_label` | Note |
|---|---|---|---|
| `figure_taskM_M1_percentile_maps` | `figure_asset` | `census_8058` | M1 |
| `figure_taskM_M2_all_pixel_method` | `figure_asset` | `census_8058` | M2 |
| `figure_taskJ_F3` | `figure_asset` | `bank_cut_2018` | **DRAFT caption** |
| `figure_taskJ_F4` | `figure_asset` | `bank_cut_2018` | **DRAFT caption** |
| `report_taskM_gateD_p05_distribution` | `report_asset` | `census_8058` | D.2 table |
| `report_taskM_gateD_p05_ge80_contiguity` | `report_asset` | `census_8058` | D.3 table |

`figure_asset` 251 → 255; `report_asset` 57 → 59. All checksums first-50-MB; `path_exists` set by
stat (all 1). `run_id = taskM_gateD`.

### 6.2 J-F3 / J-F4 captions — DRAFT, flagged for human review

Gate B v2 Rule 5: J-F3 and J-F4 are live Task J products left unregistered because spec C.2 supplied
verbatim captions for J-F1/J-F2 only. Draft captions were written carrying the same
causal-inference discipline — **descriptive, not causal, pixel support labelled** — and stored in
`figure_asset.caption` with a `provenance_note` marking them DRAFT. They are **proposals, not
settled text.** As stored:

- **J-F3** — *"DRAFT — pixel support. 2018 bank-cut pre/post placebo law. Between-year
  flood-frequency change against log(post/pre flow ratio) across 25 cut dates; law fitted on the 24
  placebos with 2018 excluded, R² = 0.864. 2018 residual +7.51 pp, rank 2 of 25. The band is ±1
  residual SD (descriptive spread), NOT a confidence interval — only 5 of 25 dates are independent.
  Suggestive, not causal."* Numbers resolve to the registered `report_taskJ_gate4_law_summary` and
  `report_taskJ_gate4_residual_ranking`.
- **J-F4** — *"DRAFT — pixel support. Whole-farm per-water-year wet extent and gauge 410040 mean
  flow, 1988–2022. Wet extent is per-year spatial coverage, NOT the headline between-year flood
  frequency. Shaded = the post-2018 window. Descriptive context only — not causal."*

**Human decision required:** accept, edit, or replace these captions before the figures go on a
slide.

### 6.3 Review bundle

`Output/review_bundles/tier2m_deck_evidence/` — the four figures, the D.2/D.3/green-at-floor tables,
and the Gate A/C/D reports; zipped to `Output/review_bundles/tier2m_deck_evidence.zip`. The 30 MB
native-cells intermediate is excluded (reproducible from the R script).

---

## 7. Acceptance assertions — evidence

| # | Assertion | Evidence |
|---:|---|---|
| 1 | No file under `Output/` deleted or overwritten; additive only | All new paths; none existed before. DB grew by `INSERT` only |
| 2 | Builder not run; `census_stratum` = 11 rows / 1,080,157 px | Verified post-write: `(11, 1080157)` |
| 3 | DB SHA-256 before/after | `096c5a43…` → `dcd5fbf9…` (§0) |
| 4 | No product derived from `raster_00007` or any `pre_vs_post` asset | Task J rasters are the live 2018 analysis; M1/M2 derive from the census percentile rasters and the DB. Nothing reads `inundation_pre_post/` |
| 5 | No p50 − p05 difference raster or panel | M1 plots p05 and p50 on one shared scale; no difference panel. No difference raster produced |
| 6 | No un-sourced hectare claim about the floor in any Gate D output; "refugia" appears nowhere | Every hectare value sits in a table row whose columns state grid, threshold and pixel area, or in D.0's cited prose. Word check across all Gate D scripts and outputs: **0** occurrences of "refugia" (the only residue is the pre-existing `refugia_area_check.csv` filename, not re-authored here) |
| 10 | No flagged number replaced by another number | D.0 replaced no number without its definition; the withdrawn hectare figures are not restated as headlines |
| 7 | Every new `figure_asset` row has `framing_label` and `superseded_flag` | 4/4 Gate D figure rows have both non-null |
| 8 | `v_presentation_headlines` unaltered and present | Confirmed present after execute |
| 9 | Every figure caption stating a numeric claim cites a resolvable source | M1/M2 captions cite the census rasters / DB; J-F3's numbers cite the registered Task J gate CSVs; J-F4 states no result number |

---

## 8. Still open after Gate D

- **J-F3 / J-F4 captions** are DRAFT — human review (§6.2).
- **D7** — `v_presentation_headlines` still publishes the retired 9.23 pp.
- **D8** — whether any floor claim belongs on a slide, at what threshold: **CC proposes nothing.**
  D.1–D.3 and the Rule 8 table inform it.
- **D9** — the `fix-refugia-changelog` PR.
- **Gate B v2 leftovers:** Rule 4 widening (4 MER `pre/post_conservation` rasters), the 39 unlabelled
  `Latest_results/` files, D-2 (126 background rasters), D-3 (`Output/csv/`), D-5 (`Output/`
  gitignore policy), D-6 (`census_green_at_floor_farm_distribution.csv` lives only in `docs/`).
- The `taskM_gateD_native30m_p05_cells.csv` intermediate is unregistered and untracked (30 MB,
  reproducible).

---

## ⛔ Gate D acceptance — handing back

D.0–D.5 complete. Two deck figures built to the design system, a dual-grid distribution and a
contiguity report (both reported, not interpreted), the D8 framing corrected in established facts,
6 assets registered, J-F3/J-F4 captioned as DRAFT for review, and a zipped review bundle. Not
merged. **Hand back for human merge.**
