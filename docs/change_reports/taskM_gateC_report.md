# Task M · Gate C — additive provenance and registration

*Spec: `docs/Tier2_TaskM_deck_evidence_audit_v2.md` §C.1–C.6, applied under
`docs/Tier2_TaskM_gateB_classification.md`. Branch `tier2m-deck-evidence`, continuing from
`9ea24a9`. Additive only — no deletes, no overwrites, no builder run. Not merged.*

**Reading this report.** Every number below names the `Output/` artefact it came from, per the
CLAUDE.md standing rule. This report states findings and where they live; it is the home of no
value. Where a number has no artefact, the pointer is given and the value omitted.

## 0. Run context

| Item | Value |
|---|---|
| Hostname | `DESKTOP-K2CLIB0` |
| Branch / base | `tier2m-deck-evidence` @ `9ea24a9` (cut from `origin/main` `71ac44d`) |
| **DB SHA-256 before** | `a8a92fb5d53324d9fa2dcce19ea59784ad2ba20046a4085475363156b24f42f7` (76,058,624 B) |
| **DB SHA-256 after** | `096c5a4343738372904729d1659cf6751fc43e709517e4e044904eb9f6d96271` (76,115,968 B) |
| Builder run? | **No.** `census_stratum` still 11 rows summing to 1,080,157 pixels. |
| R used | R 4.6.1, `terra` 1.9.34, `sf` 1.1.1 |

### 0.1 What Gate C added

| Artefact | Kind |
|---|---|
| `scripts/05_ground_cover/04_taskM_green_at_floor_area.R` | new script — Rule 8, closes D8 |
| `scripts/11_database/taskM_gateC_raster_metadata.R` | new script — raster geometry for registration |
| `scripts/11_database/register_taskM_gateC_assets.py` | new registrar — C.1–C.5 |
| `scripts/11_database/taskM_gateC_file_classification.py` | new script — file-level Gate B record |
| `Output/tables/taskM_green_at_floor_area.csv` | new — the number, rebuilt from git |
| `Output/tables/taskM_gateC_raster_meta.csv` | new |
| `Output/tables/taskM_gateC_registration_dryrun.csv` | new — pre-write audit |
| `Output/tables/taskM_gateC_file_classification.csv` | new — 2,341 rows |
| `docs/change_reports/taskM_gateC_report.md` | this file |

No existing file was modified. The four new `Output/` files did not previously exist (absent from
the 1,894-row Gate A inventory).

---

## 1. Rule 8 — D8's provenance gap is closed

### 1.1 The missing link is now in git

`scripts/05_ground_cover/04_taskM_green_at_floor_area.R` performs the `> 50` count and the hectare
conversion from the committed substrate, and writes `Output/tables/taskM_green_at_floor_area.csv`.

`green_at_floor()` is **not** reimplemented. The script carries a verbatim copy and, at §2 of the
script, extracts the function block from
`scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R` by marker, normalises whitespace and
comments, and **stops** unless the two are identical. The run log records the guard firing clean:

```
[guard] green_at_floor() verified verbatim against 03_h2_seasonal_gate_and_diagnostics.R
```

The threshold, the mask, the support rule and the pixel area are constants at the head of the
script (`GREEN_CUT <- 50`, `PIXEL_AREA_HA <- 0.09`, `MIN_SEASONS <- 50L`) and are asserted, not
adjusted.

### 1.2 It reproduces exactly

The script re-ran the complete paired per-pixel apply over the farm on EPSG:3577 and reconciled its
own output against the artefact Gate A traced. Both values are cited to their artefacts:

| Quantity | `Output/tables/taskM_green_at_floor_area.csv` | `Output/diagnostics/ondisk_review_20260720/refugia_area_check.csv` | Difference |
|---|---:|---:|---:|
| `n_valid_floor_px` | 959,833 | 959,833 | 0 |
| `n_majority_green_px_gt50` | 71,755 | 71,755 | 0 |
| `area_ha_native_30m_3577` | 6,457.95 | 6,457.95 | 0 |

The new CSV also carries `green_frac_pct_median` and `green_frac_pct_mean`, which match
`Output/diagnostics/tier2H_h2_green_fraction_at_floor.csv` (the committed substrate) exactly.

Every row of the new CSV carries the definition in its own columns — `variable`, `threshold`,
`mask`, `support_rule`, `grid_epsg`, `pixel_area_ha`, `method_source`, `not_this`. A hectare figure
lifted out of that table without those columns is not quotable, by construction.

### 1.3 Chain state after Gate C

| Link | Gate A | Gate C |
|---|---|---|
| Method (`green_at_floor()`) | committed | committed, and now guarded against drift |
| Substrate rasters (2 × native-3577 FC stacks) | on disk, unregistered, untracked | **registered** — `raster_fc_total_veg_3577_stack`, `raster_fc_pv_3577_stack` |
| Substrate summary CSV | on disk, unregistered | **registered** — `report_green_at_floor_substrate` |
| **The counting step** | **BREAK — no script** | **committed script**, verbatim-guarded |
| Output file | scratch, unregistered | **registered** — `report_green_at_floor_area` (new) and `report_green_at_floor_area_scratch` (the traced 2026-07-20 artefact) |
| Registered asset | **BREAK — none** | five registrations, all carrying the Rule 8 note verbatim |

**The number now rebuilds from git.** No interpretation is offered on whether it belongs on a
slide, under what label, or at what threshold — human review required.

---

## 2. What was written

### 2.1 C.1 — provenance columns (11 added, all nullable, default NULL)

| Table | Columns added |
|---|---|
| `raster_asset` | `superseded_flag`, `framing_label`, `provenance_note` |
| `figure_asset` | `superseded_flag`, `framing_label`, `provenance_note`, `caption` |
| `report_asset` | `superseded_flag`, `framing_label`, `provenance_note` |
| `census_asset` | `qa_note` |

**Scope extension, flagged.** Spec C.1 names `raster_asset` and `figure_asset` only. Gate B Rules 5
and 8 and decision D-1 classify **CSV** assets, which live in `report_asset`; without the columns
there the classification could not be carried. `provenance_note` / `caption` / `qa_note` were added
because Rule 8's verbatim note, spec C.2's verbatim captions and spec C.4's evidence text each
require a field the schema did not have.

### 2.2 Registrations — 75 new rows

| Set | Table | n | `framing_label` | `superseded_flag` |
|---|---|---:|---|---:|
| D1 paddock dashboards (PNG) | `figure_asset` | 21 | `plot_support` | 0 |
| `C1_veg_regime_paddock_*` (PNG) | `figure_asset` | 21 | `census_8058` | 0 |
| J-F1, J-F2 (verbatim captions) | `figure_asset` | 2 | `bank_cut_2018` | 0 |
| Task J difference rasters | `raster_asset` | 12 | `bank_cut_2018` | 0 |
| Native-3577 FC stacks (Rule 8) | `raster_asset` | 2 | `census_8058` | 0 |
| Task J gate CSVs | `report_asset` | 10 | `bank_cut_2018` | 0 |
| Census summary CSVs (`Output/` copies) | `report_asset` | 3 | `census_8058` | 0 |
| Floor-chain CSVs (Rule 8) | `report_asset` | 3 | `census_8058` | 0 |
| F6 census verdicts CSV (C.5 dependency) | `report_asset` | 1 | `census_8058` | 0 |

Row counts: `figure_asset` 207 → **251**; `raster_asset` 112 → **126**; `report_asset` 40 → **57**.

Checksums use the builder's first-50-MB convention. `path_exists` is set by actual stat — every one
returned 1. Insertion is `INSERT OR IGNORE` on the primary key: **a second `execute` run inserts 0**,
verified.

### 2.3 Labellings — 239 rows

| Rule | Set | n | Applied |
|---|---|---:|---|
| Rule 3 | `figure_asset` `run_id='gateE_20260721'` | 11 | `census_8058` / 0 |
| Rule 3 | `figure_asset` `run_id='d2_site_dashboard_batch_20260720'` | 57 | `plot_support` / 0 |
| Rule 3 | `figure_asset` `run_id='db_build_20260701_114458'` | 139 | `context` / 1 |
| Rule 4 | `raster_asset` `period_label='pre_vs_post'` OR under `inundation_pre_post/` | 32 | `conservation_2019` / 1 |

`figure_asset` now has **0 rows with a NULL `framing_label`**. `raster_asset` retains 80 NULL and
`report_asset` 40 NULL — Gate B gives no rule for those, and spec C.1 forbids inferring one.

### 2.4 C.4 — census QA promotion

`census_asset.qa_status` for `census_pixel_8058`: `REVIEW` → **`PASS`**, one row. The evidence text
is recorded in the new `qa_note` column and cites its source artefact
(`Output/census/gayini_pixel_census_8058.parquet`).

### 2.5 C.5 — the live headline view

`taskM_headline_source` (new table, 9 rows) + `v_presentation_headlines_live` (new view). Every row
carries `support` (`pixel_census` on all 9; **0 rows with a null or blank support**) and names the
`Output/` artefact and registered asset id it was read from:

| Rows | Source artefact | Asset id |
|---|---|---|
| census pixel count · mapped area · true farm area | `Output/census/gayini_pixel_census_8058.parquet` (values read from `census_stratum`) | `census_pixel_8058` |
| three community flood-frequency means | `Output/census/summaries/census_community_flood_freq_means.csv` | `report_census_summary_community_flood_freq_means` |
| F6 verdict counts (no-trend / non-stationary / directional) | `Output/diagnostics/tier2H_h32_census_f6_verdicts.csv` | `report_census_f6_verdicts` |

The `conservation_2019` exclusion is written as an explicit predicate rather than left to absence,
so it is testable. `mean_inundation_change_pp` has no row: verified 0.

**`v_presentation_headlines` is unaltered and still present**, and still returns the retired
9.23 pp. **D7 remains open** — the legacy view continues to publish a retired-framing number and
needs a human decision about deprecation. Gate C did not touch it, per spec C.5.

### 2.6 The file-level classification record

Gate B classifies *files*; the DB carries `framing_label` / `superseded_flag` on *asset rows*. Most
classified files have no asset row, and Rules 1, 6 and 7 explicitly forbid registering them — so
their classification cannot go in the DB without breaking those same rules.

`Output/tables/taskM_gateC_file_classification.csv` (2,341 rows) is that record, in `Output/` where
the standing rule puts it. Its `db_labelled` column says, per row, whether the DB also carries the
classification: **102 Y, 2,239 N**. By rule: Rule 7 1,303 · Rule 2 158 · Rule 6 138 · Rule 3 42 ·
Rule 4 31 · Rule 5 26 · Rule 8 5 · D-3 72 · D-1 3 · unclassified 563.

---

## 3. Where Gate B's stated counts did not match disk

Verified against disk before writing, per the recon-before-code rule. Gate C applied each rule **as
written**; where the rule's premise did not hold, nothing was inferred.

| # | Gate B says | Disk says | What Gate C did |
|---|---|---|---|
| 1 | Rule 1: "**all 54** `Latest_results/` files have a byte-twin at `Output/figures/` root by filename" | All 54 have a same-name file *somewhere*, but only **15** at the `Output/figures/` root. The rest are twinned across `figures/dashboards` (19), `figures/report_figures` (20), `_archive/taskL_pre_rollout_20260722` (12), `review_bundles/d2_site_dashboard_batch` (10), and two more directories | Marked all 54 `superseded_flag = 1`, not registered. **`framing_label` left NULL for all 54** — "inherit from the root twin" resolves for only 15, and no label was inferred for the other 39 |
| 2 | Scope table: "Register `C1_veg_regime_paddock_*` — **44**" | 21 PNG + 21 PDF at `Output/figures/`, plus 21+21 inside a review bundle | Registered the **21 PNGs**. Rule 2 (PNG canonical, PDF a print companion, not registered) governs; 44 counts both halves of the pair and contradicts Rule 2 |
| 3 | Rule 2 verification: "S-series = **15+15**" | **11 PNG + 11 PDF** at `Output/figures/` (plus 11 PNG in `Latest_results/`); the 11 PNGs were already registered under `gateE_20260721` | No registration needed; the 11 were labelled `census_8058` / live |
| 4 | Rule 4: "**31 rasters**, including `raster_00007`" | The rule's own predicate matches **32**: 31 under `inundation_pre_post/` plus `raster_00095` (`Output/rasters/MER/period_summaries/mer_post_minus_pre_annual_max_frequency_pct_points.tif`, `period_label='pre_vs_post'`) | Applied as written → **32 labelled** |
| 5 | Rule 5: "the **two** J-F figures" | **Four** exist: J-F1 and J-F2 under `Output/figures/maps/task_J/`, plus `J-F3_the_law.png` and `J-F4_annual_series.png` under `Output/figures/plots/task_J/` | Registered **2**. Spec C.2 supplies verbatim captions for J-F1/J-F2 only; J-F3/J-F4 are recorded in the classification CSV as live, unregistered, pending a caption decision |
| 6 | Scope: "~107 new registrations, ~224 labellings" | **75 registrations, 239 labellings** | Reconciliation below |

**Scope reconciliation.** 107 = 11 S-series no-ops + 21 D1 + 44 C1 + 24 Task J + ~4 Rule 8 + 3
census. Actual 75 = 21 D1 + 21 C1 (Rule 2, not 44) + 24 Task J (12 rasters + 2 figures + 10 CSVs) +
5 Rule 8 (2 rasters + 3 CSVs) + 3 census + 1 F6 verdicts; the 11 S-series were already registered,
so they were a no-op as Gate B anticipated. 224 → 239 is the Rule 4 count moving 31 → 32 and the
Rule 3 sets summing to 207 rather than 193.

### 3.1 Two further deviations, both deliberate

- **D-1 implemented asymmetrically.** The three `Output/census/summaries/` copies are registered as
  canonical. The three `docs/census_summaries/` duplicates are recorded as
  `superseded_flag = 1` in `Output/tables/taskM_gateC_file_classification.csv` and **not**
  registered — registering `docs/` paths into the product registry would cut against the standing
  rule that `docs/` is never a result. Gate B's intent (mark them superseded) is met; the location
  of the mark differs.
- **One registration beyond Gate B's scope.**
  `Output/diagnostics/tier2H_h32_census_f6_verdicts.csv` was registered because
  `v_presentation_headlines_live` publishes counts derived from it, and the standing rule requires a
  published number to cite a registered artefact.

---

## 4. Findings — reported, not resolved

Per §0.2a: where a number or a document needs correcting, this gate reports it. Nothing was
replaced, and no document outside `docs/change_reports/` was edited.

1. **A result that exists only in `docs/`.**
   `docs/census_summaries/census_green_at_floor_farm_distribution.csv` has **no `Output/`
   counterpart** — the only file in that directory without one. Under the new standing rule this is
   a result living where results may not live. Not moved (moving is not additive and is the human's
   call); recorded in the classification CSV.

2. **`CLAUDE.md` disagrees with Gate B on the nature of the D8 correction.**
   `CLAUDE.md:40` describes D8 as *"refugia restated on the native 30 m grid (~6,460 ha, not
   ~4,300)"*, and `docs/Gayini_established_data_facts.md:273` frames the correction as a **grid
   mismatch**. Gate B §0 establishes that the 6.34× gap is a **variable** difference — green share
   of remaining cover versus total cover at the floor — not a grid artefact. Gate B wins; the
   disagreement is flagged, not resolved. **Not edited**, per instruction.

3. **`CLAUDE.md:40` and `:44` state the claim two different ways** (~6,460 ha and ~4,300 ha), and
   neither states variable, threshold, mask or grid. On this branch
   `docs/Gayini_established_data_facts.md:34` still reads ~4,300 ha (the branch is cut from
   `origin/main`, which predates `e87bd1a`). **Not edited**, per instruction — these are the
   human's. The full site list is `docs/change_reports/taskM_gateA_floor_claims_inventory.csv`.

4. **Four retired-framing rasters left unlabelled.** `raster_00093`, `raster_00094`, `raster_00096`,
   `raster_00097` (`Output/rasters/MER/period_summaries/`, `period_label` `pre_conservation` /
   `post_conservation`) belong to the same retired 2019 framing but do not match Rule 4's literal
   predicate. Left NULL rather than inferred. Candidates for a Rule 4 extension — human call.

5. **`workflow_run` is not maintained by the registrars.** It holds one row
   (`db_build_20260701_114458`); `tier2H_h2`, `tier2H_h6`, `tier2H_h30`, `gateE_20260721` and
   `d2_site_dashboard_batch_20260720` all appear as `run_id` values on asset rows with no matching
   run row. Gate C added a `taskM_gateC` row for its own writes and **did not backfill** the others.

6. **`Output/` is gitignored by default, so "Output/ is the record" is not automatically a
   *versioned* record.** `.gitignore:33` ignores `Output/`; individual evidence tables have been
   force-added before (commit `f6f78a0`, "Track D2 registrar and evidence tables"). Gate C followed
   that precedent and force-added the small text artefacts it depends on — the four new
   `Output/tables/` CSVs plus the two Rule 8 chain CSVs that Gate A recorded as untracked
   (`tier2H_h2_green_fraction_at_floor.csv`, 207 B; `refugia_area_check.csv`, 201 B). The DB, the
   rasters and the two ~400 MB FC stacks remain ignored and are registered rather than tracked.
   **The general policy — which `Output/` artefacts must be versioned for the standing rule to
   hold — is a human decision, not one Gate C should set by precedent.**

7. **The two FC stacks carry no EPSG authority code.** `terra::crs(describe = TRUE)$code` returns
   `NA` for both; their WKT is `GDA94_Australian_Albers` with no authority node. Gate C resolved
   them to **EPSG:3577 by proj4 parameter identity against `EPSG:3577` itself**, and recorded that
   basis in `Output/tables/taskM_gateC_raster_meta.csv` (`crs_epsg_source =
   inferred_from_proj4_parameters`) and in each raster's `legend_semantics`. The 12 Task J rasters
   carry declared codes (28355 / 8058) and needed no inference.

---

## 5. Acceptance assertions — evidence

| # | Assertion | Evidence |
|---:|---|---|
| 1 | No file under `Output/` deleted or overwritten; additive only | Four new files under `Output/tables/`, none of which existed in the 1,894-row Gate A inventory. No existing file was rewritten. The DB grew 76,058,624 → 76,115,968 B by `ALTER TABLE ADD COLUMN` / `INSERT` / targeted `UPDATE` only |
| 2 | Builder not run; `census_stratum` = 11 rows summing to 1,080,157 | Verified post-write: `(11, 1080157)`. The registrar contains no rebuild path |
| 3 | DB SHA-256 before and after | before `a8a92fb5…f42f7`; after `096c5a43…d96271` — both in §0 |
| 4 | No product derived from `raster_00007` or any `pre_vs_post` asset | `raster_00007` is now labelled `conservation_2019` / superseded. **0** `taskM_gateC` rows reference `inundation_pre_post`. The Task J rasters are the live 2018 analysis and carry `legend_semantics` stating the distinction explicitly |
| 5 | No p50 − p05 difference raster or panel | None produced. The Rule 8 script computes a paired per-pixel statistic and subtracts no percentiles; `green_at_floor()` is unmodified |
| 6 | No un-sourced hectare claim about the floor in any Gate C output; the word "refugia" appears nowhere | Every hectare figure Gate C emits sits in `Output/tables/taskM_green_at_floor_area.csv` with `variable`, `threshold`, `mask`, `support_rule`, `grid_epsg`, `pixel_area_ha` on the same row. Word check: **0** occurrences in any Gate C-authored text — the only residue is the pre-existing filename `refugia_area_check.csv`, which appears in paths and in code that points at it. Renaming it would not be additive, so it stands; its registered `title` states the variable instead |
| 10 | No number flagged as wrong was replaced by another number | No document outside `docs/change_reports/` was edited. `CLAUDE.md:40`, `:44` and `Gayini_established_data_facts.md` are untouched. Findings §4 reports; it does not substitute |
| 7 | Every new `figure_asset` row has non-null `framing_label` and `superseded_flag` | 0 `taskM_gateC` figure rows with either NULL; and 0 across all 251 rows |
| 8 | `v_presentation_headlines` unaltered and still present | Present; still returns `mean_inundation_change_pp = 9.23`. The new view is additive and separately named |
| 9 | Every figure caption stating a numeric claim cites a resolvable source | The two captions carrying numbers (J-F2: `R² = 0.864`, `+7.51 pp`, `86%`, rank 2 of 25) are stored verbatim per spec C.2 and resolve to the registered Task J gate CSVs — `report_taskJ_gate4_law_summary`, `report_taskJ_gate4_residual_ranking`, `report_taskJ_gate3_J_T1`. J-F1's caption states no number |

---

## 6. Still open after Gate C

- **D7** — `v_presentation_headlines` still publishes the retired 9.23 pp. Deliberately untouched;
  needs a human decision on deprecation.
- **D8** — the provenance is closed (§1); whether any claim about the variable is warranted, under
  what label and at what threshold, is not. Gate D's D.1–D.3 inform it. **CC proposes nothing.**
- **D9** — the `fix-refugia-changelog` PR. Gate A resolved the chain `PARTIAL`; Gate C makes the
  compute reproducible, but the changelog line itself still states a hectare figure without its
  definition. Human's edit.
- The six items in §4, and Gate B's deferred D-2 (126 background rasters), D-3 (`Output/csv/`) and
  D-4 (`scripts/_deprecated/`).
- 563 files under `Output/` remain unclassified by any Gate B rule (see the classification CSV).

---

## ⛔ Gate C acceptance — handing back

C.1–C.6 complete under the Gate B rules. 75 registrations, 239 labellings, 11 columns, 1 QA
promotion, 1 table, 1 view. Rule 8's script closes the D8 compute gap and reconciles at
difference 0. Gate D is not started. **Not merged.**
