# Tier 2 · Task M — deck evidence audit and figure build

*Branch `tier2m-deck-evidence`. Do not merge; hand back for human merge.*

**Purpose:** produce a defensible spine of findings for the Adrian deck, where every number on a
slide traces to a script, an output file, and a registered asset. Clean up the tracking problem
along the way — additively.

---

## 0. Read this before doing anything

### 0.1 The rule this task exists to enforce

> **A finding must name the artefact that produced it.**
> script → output file → registered asset → the number on the slide.
> If the chain breaks anywhere, it is an **observation**, not a finding, and it does not go on a slide.

### 0.2 Absolute prohibition on interpretation

**CC does not interpret. CC reports.**

This task was triggered by an interpretation failure. A claim ("~4,300 ha staying majority-green
as refugia") was generated in a chat session by looking at the distribution of a stored column,
picking a threshold, and naming the result. No script produced it. It propagated through project
docs for weeks and was only caught when the parquet was read directly. The number does not
reproduce: `veg_p05 >= 50` over focus pixels is **40,935.8 ha**, not ~4,300 ha, and the companion
claim "~97% dead at median" is false (0.9% of focus pixels have `veg_p50 < 50`).

Therefore, in every gate of this task:

- **Do NOT** name, label, or characterise any spatial pattern. Not "refugia", not "corridor",
  not "hotspot", not "degraded", not "resilient", not "healthy", not "stressed".
- **Do NOT** propose a threshold that is not already specified in this document.
- **Do NOT** describe a result as ecologically meaningful, surprising, expected, consistent,
  or inconsistent with anything.
- **Do NOT** explain *why* a pattern exists.
- **DO** report counts, areas, percentages, distributions, and checksums.
- **DO** write "no interpretation offered — human review required" wherever an interpretation
  would naturally go.

If a gate report feels like it is missing a conclusion, that is correct. The conclusion is the
human's to draw.

### 0.3 Standing conventions that bind this task

From `CLAUDE.md` — do not re-litigate:

- Canonical analytical CRS is **EPSG:8058**. Reproject to new files or on read; never mutate originals.
- Headline metric is **between-year annual flood frequency** = `100 × wet-valid-years ÷ valid-years`.
  `annual_occurrence_pct` is the SECONDARY wet-extent metric and is never presented as the headline.
- **Additive only.** No deletes. Moves go to `_archive/`. No file is overwritten in place.
- **Never re-run the builder.** `reset_file` rebuilds the DB from scratch and would destroy the
  12 Task H census rows and 68 figure registrations it cannot reproduce.
- Consume via **views**, not raw `fact_*` tables.
- Archived scripts go to `scripts/archive/`, never `scripts/_deprecated/`.
- `dim_plot` centroids are **EPSG:9473** — reproject before any spatial join or raster extraction.
- **Percentiles do not subtract.** No p50−p05 difference raster, ever (§11 rule).
- One figure = one file = one slide.
- No AI attribution in git commits. No `Co-Authored-By:` trailers.

### 0.4 Retired framings — must not be revived

- **2019/2020 pre/post management split is RETIRED.** Any product with
  `period_label = 'pre_vs_post'` or `run_id = 'db_build_20260701_114458'` in the inundation
  pre/post family belongs to this retired framing.
- **Critical collision:** `Output/rasters/inundation_pre_post/post_minus_pre_inundation_frequency_pct_points.tif`
  (raster_00007, EPSG:28355, retired 2019 framing) has a title nearly identical to the **live**
  2018 bank-cut difference map `J-F1_2018_difference_map.png`. These are different analyses.
  **The 2018 bank-cut work is live. The 2019 raster is dead.** Never build a deck figure from
  raster_00007.

---

## 1. Established facts — verified, do not re-derive

Verified by direct read of `gayini_pixel_census_8058.parquet` on 2026-07-24. These are settled.

### 1.1 Census parquet is validated end to end

| Check | Result |
|---|---|
| SHA-256 (full file) | `6b23f6c0803b69af12345b6818ae2cd453a67fc7ec694a880b3be3681246f966` |
| SHA-256 vs `census_asset` registered value | **exact match** |
| Rows | 1,080,157 — matches contract and `census_stratum` |
| Columns | 16, all contract fields and types present |
| Per-stratum reconciliation vs `census_stratum` | **diff = 0 across all 11 strata** |
| Compression | ZSTD |

The file is at `Output/census/gayini_pixel_census_8058.parquet`.

Note the file is 26.7 MB, so the builder's "first 50 MB" hashing convention and a full-file
hash produce the same digest here. Do not read that as a general equivalence.

### 1.2 Gate E figures reconcile against the parquet

The Gate E figures were built **from the rasters, not the parquet** (R lacked arrow/duckdb).
That workaround is now confirmed sound — the following figure claims were checked against
the parquet directly and all reconcile:

| Claim (as printed on figure) | Parquet value | Status |
|---|---|---|
| S24/S26: response measurable on 58% / 86% / 97% | 58.41 / 86.00 / 97.25 | PASS |
| 41.59% of Aeolian never flooded | 41.5893% | PASS |
| Aeolian low is vacuous (flat-zero) | 100.0% never-wet, max `wet_years` = 0 | PASS |
| Community means 6.08 / 12.91 / 27.99 | 6.0806 / 12.9070 / 27.9896 | PASS |
| FigA: 988,829 census focus pixels | 988,831 focus − 2 null-`veg_p05` = 988,829 | PASS |

`valid_years == 35` for **every** focus pixel — the focus set has no partial-record heterogeneity.

### 1.3 Pixel area

`0.0623512` ha/pixel (24.97 m grid). Cross-checked against stratum-derived area
(`1670.145 / 26786 = 0.0623514`). Agreement to 7 dp. Use `0.0623512`.

### 1.4 D2 is FIXED

`v_pixel_census_by_veg_regime` now carries **both** bases: `pct_of_farm` (divides by the true
85,910.8 ha farm, sums to 78.39%) and `pct_of_mapped` (divides by 67,349.332 ha mapped, sums
to 100.0%). Fixed by `30_fix_d2_census_view_farm_basis.R`. Do not re-apply the C1 correction.

### 1.5 The claim that FAILED verification

"~4,300 ha staying majority-green as refugia" — **does not reproduce.** Recorded here so it is
not silently reintroduced:

| Definition | Area |
|---|---|
| `veg_p05 >= 50`, focus pixels (the claim as literally worded) | 40,935.8 ha |
| `veg_p05 >= 80`, focus pixels | 4,179.3 ha |
| `veg_p05 >= 50`, Riverine only | 4,084.1 ha |
| `veg_p50 >= 50`, focus pixels | 61,096.8 ha (99.1% of focus) |

The companion claim "floor ~97% dead at median" is **false**: 0.9% of focus pixels have
`veg_p50 < 50`.

**This claim is withdrawn from the headline set** and is not to appear on any deck slide
produced by this task. Gate C maps the underlying variable so the human can decide whether
any claim is warranted. CC proposes nothing.

---

## 2. Scope

**In scope:** evidence audit of `Output/`; additive provenance labelling in the DB;
registration of unregistered live assets; two new deck figures.

**Out of scope:** any change to analysis; any new statistical result; any builder re-run;
any merge to `main`; any interpretation.

---

## GATE A — recon only, read-only

**No writes of any kind. No new files except the gate report itself.**

### A.1 Date-stratified inventory of `Output/`

The human has established that **files from 2026-07-17 onward supersede earlier work**.
The Gate E figure generation is 2026-07-23.

Produce `docs/change_reports/taskM_gateA_output_inventory.csv` with one row per file under
`Output/` (recursive, excluding `Output/_archive/`):

| Column | Meaning |
|---|---|
| `path` | path relative to repo root |
| `bytes` | file size |
| `mtime_utc` | modification time, ISO 8601 |
| `date_class` | `current` if mtime >= 2026-07-17, else `prior` |
| `ext` | file extension |
| `registered_in` | `raster_asset` / `figure_asset` / `census_asset` / `report_asset` / `spatial_layer` / `none` |
| `asset_id` | the registering id, or empty |
| `path_exists_flag` | the registered `path_exists` value, or empty |

### A.2 Registration gap analysis

In the gate report, state counts for:

1. **Orphans** — files on disk under `Output/` registered nowhere.
2. **Broken pointers** — registered assets whose `path` does not exist on disk.
3. **Stale-input risk** — files with `date_class = prior` that are referenced as an input by any
   script that produced a `date_class = current` output. Determine by grepping script sources for
   the filename. Report the referencing script for each. **Report only — do not resolve.**

### A.3 Registry generation split

`figure_asset` holds 207 rows. Break down by `run_id` and report:
- how many belong to `db_build_20260701_114458` (the superseded generation)
- how many to `d2_site_dashboard_batch_20260720`
- how many to `gateE_20260721`
- any other `run_id`

### A.4 Known-unregistered live assets

Confirm presence on disk and report registration status for each:

- `J-F1_2018_difference_map.png`
- `J-F2_placebo_ladder_six_panel.png`
- `task_J_gate2_2018_assertions.csv`
- `task_J_gate2_2018_by_community.csv`
- `task_J_gate2_2018_summary.csv`
- `task_J_gate3_assertions.csv`
- `task_J_gate3_J_T1.csv`
- `task_J_gate3_shape_vs_reference.csv`
- `task_J_gate4_heteroscedasticity.csv`
- `task_J_gate4_law_summary.csv`
- `task_J_gate4_raster_assertions.csv`
- `task_J_gate4_residual_ranking.csv`
- `census_community_flood_freq_means.csv`
- `census_flood_zone_by_community.csv`
- `census_percentile_by_community.csv`

### A.5 Defect status check

Report current state, evidence only:

- **D1** — is `Tier2_TaskH_all_pixel_census_v4.md` committed to `main`? (`git log --oneline -- <path>`)
- **D7** — does `v_presentation_headlines` still return `mean_inundation_change_pp = 9.23`?
  Confirm whether that value derives from `v_plot_current_summary.post_minus_pre_inundation_frequency_pct_points`.
- **`census_asset.qa_status`** — current value.
- **`scripts/_deprecated/`** — does it exist? How many files?

### A.6 Gate A report

Write `docs/change_reports/taskM_gateA_report.md`. Facts, counts, tables. No recommendations
beyond flagging what needs a human decision.

### ⛔ STOP — GATE A ACCEPTANCE

Hand back. Do not proceed to Gate B. The human classifies live vs superseded.

---

## GATE B — human classification (no CC work)

The human reviews Gate A and supplies a classification list. CC waits.

---

## GATE C — additive provenance and registration

**Additive only. No deletes. No overwrites. No builder run.**

Proceed only with the Gate B classification in hand.

### C.1 Provenance columns

Add to `raster_asset` and `figure_asset` (via `ALTER TABLE ADD COLUMN`, nullable, default NULL):

- `superseded_flag` — `INTEGER`, 1 = superseded, 0 = live, NULL = unclassified
- `framing_label` — `TEXT`, controlled vocabulary:
  - `census_8058` — all-pixel census work
  - `bank_cut_2018` — Task J 2018 bank-cut analysis
  - `conservation_2019` — **RETIRED** 2019/2020 pre/post framing
  - `plot_support` — plot-support analyses
  - `context` — basemaps, locators, non-analytical

Populate **only** from the Gate B classification. Where the human has not classified an asset,
leave NULL. Do not infer.

### C.2 Register the Task J assets

Register the two J-F figures in `figure_asset` and the ten Task J gate CSVs in the appropriate
asset table, with `framing_label = 'bank_cut_2018'`, `superseded_flag = 0`, `run_id = 'taskM_gateC'`.

Compute SHA-256 for each using the builder convention. Set `path_exists` by actual stat.

Captions for the two figures must carry, verbatim:
- J-F1: `Pixel support. 2018 bank-cut pre/post. Descriptive only — not causal.`
- J-F2: `Pixel support. Placebo ladder, 25 dates. 2018 residual rank 2 of 25. Flow law R² = 0.864; +7.51 pp above law. 86% of the pre/post difference is explained by window wetness. Suggestive, not causal.`

Do not paraphrase these.

### C.3 Register the three census summary CSVs

`census_community_flood_freq_means.csv`, `census_flood_zone_by_community.csv`,
`census_percentile_by_community.csv` — register with `framing_label = 'census_8058'`,
`superseded_flag = 0`.

### C.4 Promote `census_asset.qa_status`

Set `census_asset.qa_status` from `REVIEW` to `PASS` for `census_pixel_8058`.

**Evidence, to be recorded in the QA note field:** full-file SHA-256 match against the registered
value; 1,080,157 rows; 16 contract columns; per-stratum reconciliation diff = 0 across all 11
strata; five Gate E figure claims reconciled (§1.2). Verified 2026-07-24 by direct parquet read.

### C.5 Live headline view

Create `v_presentation_headlines_live`. It must:

- **Exclude** anything with `framing_label = 'conservation_2019'`
- **Exclude** `mean_inundation_change_pp` (the 9.23 pp value — retired framing)
- Include, sourced from the census: total census pixels, mapped area ha, true farm area ha,
  the three community flood-frequency means, and the F6 census verdict counts
- Carry a `support` column on every row, valued `pixel_census` or `plot`, never both in one row

**Do not drop or alter `v_presentation_headlines`.** Leave it in place; the new view is additive.
Instead, log D7 as an open defect in the gate report, noting that the legacy view still publishes
a retired-framing number and needs a human decision about deprecation.

### C.6 Gate C report

`docs/change_reports/taskM_gateC_report.md` — what was added, with before/after row counts and
the SHA-256 of the DB before and after. Commit to the repo (change reports are cross-session memory).

### ⛔ STOP — GATE C ACCEPTANCE

Hand back.

---

## GATE D — the two deck figures

Build only after Gate C is accepted. Both are new files; neither overwrites anything.

### D.1 Veg percentile maps — p05 and p50

**Source rasters** (already registered, `legend_status = 'confirmed'`, EPSG:8058) —
resolve paths from `raster_asset`, do not hardcode.

**Output:** `Output/figures/M1_veg_percentile_maps_p05_p50.png`

Requirements:

- **Two panels side by side**, p05 left, p50 right. Not five panels.
- **One shared colour scale, fixed 0–100**, single legend. Both panels on identical breaks.
- Property boundary and paddock lines as in `H6_flood_zone_data.png`.
- Titles: left `5th-percentile total cover (the floor)`, right `50th-percentile total cover (typical)`.
- Subtitle: `All-pixel census, EPSG:8058, 24.97 m. Across-series percentiles, 1988–2023, one value per pixel.`
- Footer, verbatim: `Landsat fractional cover measures COVER, not ecological condition. Percentiles are plotted as measured and are never differenced.`
- Design system: cream `#F8F7F2` page, petrol-teal `#0F3947` titles. Sequential ramp for the
  cover scale — **do not** use the four-community categorical palette for a continuous variable.
- **No p50 − p05 difference panel.** §11.

### D.2 Distribution report for the floor variable

Alongside D.1, produce `docs/change_reports/taskM_gateD_veg_p05_distribution.csv`.

For `veg_p05` over focus pixels (`treed_context_flag = FALSE`, the three focus communities,
`veg_p05` non-null; n = 988,829):

- Overall: min, p05, p10, p25, p50, p75, p90, p95, max, mean, sd
- The same, broken down by community
- The same, broken down by `flood_zone` (0–4)
- A cumulative area table: for thresholds 40, 45, 50, 55, 60, 65, 70, 75, 80, 85 — pixel count,
  area ha, and % of focus, for `veg_p05 >= threshold`

**Report the numbers only. Do not name any threshold as meaningful. Do not use the word
"refugia" anywhere in the output. No interpretation.**

### D.3 Contiguity report

For the single threshold `veg_p05 >= 80` (chosen by the human purely to make the existing
4,179.3 ha figure checkable — **it carries no ecological meaning and must not be described
as a class**):

- Number of connected components (8-connectivity)
- Component size distribution: count, min, median, p90, max in pixels and ha
- Area in the largest 10 components, and their share of the 4,179.3 ha total
- Cross-tab of component area by community and by `flood_zone`

Write to `docs/change_reports/taskM_gateD_p05_ge80_contiguity.csv`.

State in the gate report: `Contiguity reported as measured. No interpretation offered —
human review required.`

This exists so the human can see whether the high-floor pixels form coherent patches or are
scattered. **CC does not answer that question.**

### D.4 All-pixel method figure

**Output:** `Output/figures/M2_all_pixel_method.png`

A single explainer figure — the method slide the deck lacks. It must convey, using only
verified numbers from §1 and the DB:

- The shift from 66 one-hectare plots to 1,080,157 census pixels
- The 11 strata: 3 communities × 3 regime bands, plus 2 context strata
  (Floodplain Woodland / Forest, Other / minor units)
- Mapped area 67,349.3 ha of the 85,910.8 ha farm (78.4%)
- That the census removes sampling uncertainty **only** — pixels are not independent n
  (spatial and temporal autocorrelation)

Footer, verbatim: `The census removes sampling uncertainty only. ~1M pixels are NOT independent n
(spatial and temporal autocorrelation). Landsat fractional cover measures COVER, not condition.`

Design system as D.1. Schematic, not a chart of results. No new numbers — every figure on this
slide must appear in §1 or come from a named DB view.

### D.5 Register and bundle

Register both figures in `figure_asset` with `framing_label = 'census_8058'`,
`superseded_flag = 0`, `run_id = 'taskM_gateD'`, SHA-256 computed, `path_exists` set by stat.

Copy deliverables to `Output/review_bundles/tier2m_deck_evidence/` and zip.

### ⛔ STOP — GATE D ACCEPTANCE

Hand back for human merge. **Do not merge.**

---

## 3. Acceptance assertions

The gate reports must assert, with evidence:

1. No file under `Output/` was deleted or overwritten. Additive only.
2. The builder was not run. `census_stratum` still holds 11 rows summing to 1,080,157 pixels.
3. DB SHA-256 recorded before and after each writing gate.
4. No product derived from `raster_00007` or any `period_label = 'pre_vs_post'` asset.
5. No p50 − p05 difference raster or panel exists in any output.
6. The word "refugia" appears nowhere in any Gate C or Gate D output.
7. Every new `figure_asset` row has a non-null `framing_label` and `superseded_flag`.
8. `v_presentation_headlines` is unaltered and still present.
9. Every figure caption stating a numeric claim cites a source resolvable to §1 or a DB view.

---

## 4. What this task does NOT settle

Listed so they are not silently assumed closed:

- **D1** — Task H spec v4 commitment (Gate A reports status only)
- **D7** — the legacy headline view still publishes the retired 9.23 pp
- **D8** — whether any claim about the floor variable is warranted at all (human decision,
  informed by D.1–D.3)
- The Jana email (L07 cut-date provenance, L10 bank geometry) — still the sole blocker on Task J
- Which of the five `S_veg_water_*` variants is canonical for the deck
- The 16 migration blockers and the `scripts/_deprecated/` convention violation
- Whether Adrian holds the plot-support or pixel-support version of the 2018 analysis
