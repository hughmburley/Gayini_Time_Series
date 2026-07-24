# Tier 2 · Task M — deck evidence audit and figure build (v2)

*Branch `tier2m-deck-evidence`. Do not merge; hand back for human merge.*

## v2 — what changed from v1, read this first

| # | Change | Why | §|
|---|---|---|---|
| 1 | **New rule: a supersession is a new claim.** Replacing a wrong number carries the same verification burden as the original. | A changelog fix pushed on 2026-07-23 replaced ~4,300 ha with **~6,460 ha** using the same unverified reasoning that produced ~4,300 ha. | §0.2a |
| 2 | **~6,460 ha is now a second unverified claim**, recorded alongside ~4,300 ha. Neither may be quoted. | Cannot be reproduced from the census parquet; a grid change cannot account for a 6.3× difference. | §1.5 |
| 3 | **Gate A extended:** locate the artefact behind ~6,460 ha, and inventory every hectare claim about the floor variable across docs and the deck. | The number is in git on branch `fix-refugia-changelog`. | §A.6, §A.7 |
| 4 | **Gate D.2 now computes on BOTH grids** (24.97 m census and 30 m native FC). | So the two answers sit side by side and any discrepancy is visible, not inferred. | §D.2 |
| 5 | **Acceptance assertion 6 widened** from the word "refugia" to any un-sourced hectare claim about the floor. | The error mutated to a new number under a new label; banning one word is not enough. | §3 |
| 6 | **New §1.6** records what CC's read-only grep established: no code emits either figure. | Verified finding, prevents re-grepping. | §1.6 |

**Nothing in v1's §1 established facts is overturned.** The census parquet verification stands.

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

### 0.2a A supersession is a new claim

**Replacing a wrong number carries the same verification burden as making the original claim —
arguably more, because the replacement inherits the old claim's authority.**

This rule exists because the refugia error recurred one level up. On 2026-07-23 a changelog entry
was corrected to read *"~6,460 ha has a majority-green floor (native 30 m grid; supersedes the
earlier ~4,300 ha)"*. The correction was pushed. But ~6,460 ha was never verified against a source
artefact either — it was computed on a different grid and given the old claim's label. Two
unverified numbers are now in git instead of one.

Therefore:

- **Do NOT** replace a number flagged as wrong with another number, in any file, unless the
  replacement's full chain is resolvable: script → output file → registered asset → number.
- **Do NOT** treat "computed on a different grid / mask / subset" as an explanation for a
  discrepancy unless the arithmetic actually accounts for it. A grid change from 30 m to 24.97 m
  changes pixel area by ~1.44×. It cannot change a total by 6×.
- **DO** prefer removing an unverified claim over correcting it. "Unverified — see D8" is a
  legitimate and safe state for a document to be in.
- **DO** state the definition inline wherever a hectare figure appears: the variable, the
  threshold, the mask, the grid, and the pixel area used.

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

### 1.5 TWO unverified hectare claims — both withdrawn

Two different numbers have been attached to the phrase "majority-green floor". **Neither is
verified. Neither may appear on a slide or be quoted in a document.**

#### 1.5.1 Claim A — "~4,300 ha staying majority-green as refugia"

Generated in a chat session by looking at the distribution of `veg_p05`, picking a threshold, and
naming the result. No script produced it. **Does not reproduce.** Measured from the census parquet
(EPSG:8058, 24.97 m, pixel area 0.0623512 ha, focus pixels n = 988,829):

| Definition | Area |
|---|---|
| `veg_p05 >= 50`, focus pixels (**the claim as literally worded**) | **40,935.8 ha** |
| `veg_p05 >= 80`, focus pixels | 4,179.3 ha |
| `veg_p05 >= 50`, Riverine only | 4,084.1 ha |
| `veg_p50 >= 50`, focus pixels | 61,096.8 ha (99.1% of focus) |

The companion claim "floor ~97% dead at median" is **false**: 0.9% of focus pixels have
`veg_p50 < 50`.

#### 1.5.2 Claim B — "~6,460 ha has a majority-green floor (native 30 m grid)"

Pushed 2026-07-23 as commit `e87bd1a` on branch `fix-refugia-changelog`, amending L34 of the
changelog to supersede Claim A. **Also unverified.**

"Majority-green floor" means `veg_p05 >= 50`. On the census that is 40,935.8 ha. Claim B is
**6.3× smaller**. The stated qualifier — `native 30 m grid` — cannot account for this:

- 30 m pixel area = 0.09 ha; 24.97 m pixel area = 0.0623512 ha. Ratio ≈ **1.44×**.
- A grid change alters pixel *count*, not total *area*, for the same thresholded region.
- Same variable, same threshold, same property. A 6.3× gap means the **threshold, the mask, or
  the variable differs** — not the grid.

So ~6,460 ha may be correct for *something*, but the chain from it to "majority-green floor" is
not visible. **Claim B is Claim A's error repeated one level up**: a number computed by a
different route and given the old claim's label.

#### 1.5.3 Standing position until D8 is closed

- Both claims are **withdrawn from the headline set**.
- Neither appears on any deck slide produced by this task.
- Documents asserting either must be corrected to a **non-numeric** form (see §A.7), not to
  the other number.
- Gate D maps and tabulates the underlying variable so the human can decide whether any claim
  is warranted, and at what definition. **CC proposes nothing.**

### 1.6 Verified by read-only grep, 2026-07-23 — do not re-derive

A read-only search of the repo established:

- **No code emits either figure.** No `.R`, `.js`, `.ts` or `.py` file hardcodes ~4,300 or ~6,460.
  Specifically clean: `26_build_veg_water_scatter_deck.R`,
  `27_build_veg_water_quantile_bands_deck.R`, `07_figures_dashboards/06_refresh_main_deck_figures.R`.
  `build_deck3.js` does not exist in the repo.
- **Consequence:** once documents and the deck are corrected, neither number regenerates. This is
  a documentation and deck problem, not a pipeline problem.
- **Known stale doc sites** (assert ~4,300 as current, no supersession marker):
  `CLAUDE.md:44` · `docs/Tier2_TaskI_deck_stocktake_and_review_bundle.md:76` ·
  `docs/change_reports/taskI_deck_stocktake_20260717.md:83` ·
  `docs/Gayini_census_audit_kickoff.md:65` · `docs/Tier2_TaskH_ondisk_audit.md:54,104` ·
  `docs/Tier2_TaskH_ondisk_census_groundcover_review.md:106`.
- **`CLAUDE.md:44` is the highest-priority site** — it is loaded in full every session and is the
  mechanism by which the error propagates into new sessions.
- The main results deck is a binary `.pptx` and **cannot be grepped**. Two Task I stocktakes
  document a slide carrying "~4,300 ha (≈5%)", so the number is likely on a live slide.

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

### A.6 Trace the artefact behind Claim B (~6,460 ha) — READ ONLY

This is the highest-value item in Gate A. Commit `e87bd1a` on branch `fix-refugia-changelog`
asserts ~6,460 ha. §1.5.2 shows the stated grid qualifier cannot explain the 6.3× gap against
the census. Find what produced it.

Search read-only across the repo — scripts, `docs/`, `Output/`, change reports, git log and
commit messages, and any `.csv`/`.txt`/`.md` under `Output/` — for `6460`, `6,460`, `6458`,
`6,458`, and nearby values.

Report, in a table, for every hit:

| Column | Meaning |
|---|---|
| `location` | file:line, or commit hash |
| `context` | the surrounding sentence, verbatim |
| `states_definition` | does it state variable + threshold + mask + grid + pixel area? Y/N |
| `names_source` | does it name a script, table, or raster? If so, which? |

Then attempt to resolve the chain **script → output file → registered asset → number** and report
the result as exactly one of:

- `RESOLVED` — full chain found. State every link, and the definition (variable, threshold, mask,
  grid, pixel area). Do not judge whether the number is right; report the chain.
- `PARTIAL` — some links found, others missing. State precisely which link breaks.
- `UNRESOLVED` — no artefact found. The number exists only as prose.

**Do not compute a replacement number. Do not propose which definition is correct. Do not edit
the changelog.** If the chain is `UNRESOLVED`, that is a complete and acceptable finding.

Note for context: `docs/Tier2_TaskH_ondisk_census_groundcover_review.md:24` reportedly carries a
D8 row citing ~6,458 ha. If so, that is likely the origin of ~6,460 and is the first place to look.

### A.7 Inventory every hectare claim about the floor variable

Broader than §1.6's known list, because the error has already mutated once (Claim A → Claim B) and
may have mutated again.

Search read-only for **any** hectare figure attached to the floor variable or to the phrases
"majority-green", "majority green", "green floor", "refugia", "veg_p05", "5th percentile",
"floor". Include `docs/`, `CLAUDE.md`, change reports, `Output/`, and script comments.

Write `docs/change_reports/taskM_gateA_floor_claims_inventory.csv`:

| Column | Meaning |
|---|---|
| `path` | file |
| `line` | line number |
| `text` | the claim, verbatim |
| `hectare_value` | the number asserted, or empty |
| `label_used` | e.g. "majority-green floor", "refugia", "green floor" |
| `states_definition` | Y/N — variable + threshold + mask + grid all present? |
| `supersession_marked` | Y/N — does it flag itself as superseded or unverified? |
| `class` | `stale` (asserts as current, unmarked) / `marked` (cites only to supersede) / `definition_complete` |

**Report only. Change nothing.** The corrections are the human's, and §1.5.3 requires them to be
non-numeric, not a swap to another figure.

### A.8 Deck slide traceability

For each of the 36 slides in `docs/Gayini_Veg_samples.pptx`, report whether the numeric claims on
it are traceable to a registered asset:

- `traceable` — every numeric claim resolves to a registered asset or a §1 established fact
- `orphan` — carries a numeric claim with no resolvable source
- `superseded_framing` — carries a number from a retired framing (2019 pre/post, pre-census
  sampling, or either withdrawn floor claim)
- `no_numeric_claim` — title, section divider, photo, schematic

Cross-reference `docs/taskI_deck_stocktake_20260717.md` and report where your classification
disagrees with its OK/LABEL/RESTATE/FRAME/DEAD/SUPERSEDED call.

**Flag explicitly any slide carrying ~4,300 ha, ~6,460 ha, "≈5% of the farm", or "97% dead at
median".** Per §1.6 these cannot be found by grep, so this is the only way they surface.

Report only. Do not edit the deck. Do not propose slide changes.

### A.9 Gate A report

Write `docs/change_reports/taskM_gateA_report.md`. Facts, counts, tables. No recommendations
beyond flagging what needs a human decision.

Lead the report with the §A.6 chain resolution (`RESOLVED` / `PARTIAL` / `UNRESOLVED`) — it is the
single finding that most changes what the human does next.

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

### D.2 Distribution report for the floor variable — on BOTH grids

Alongside D.1, produce `docs/change_reports/taskM_gateD_veg_p05_distribution.csv`.

**This is the table that settles D8.** It must be computed twice — once on each grid — so the
24.97 m and 30 m answers sit side by side and any discrepancy is *visible* rather than inferred.
§1.5.2 shows the ~6,460 ha claim rests on an unexamined grid qualifier; this removes the ambiguity.

**Grid 1 — census, EPSG:8058, 24.97 m.** Source: `gayini_pixel_census_8058.parquet`.
Focus pixels (`treed_context_flag = FALSE`, three focus communities, `veg_p05` non-null;
n = 988,829). Pixel area **0.0623512 ha** (§1.3).

**Grid 2 — native FC grid, 30 m.** Source: the FC-derived p05 raster at its native resolution,
path resolved from `raster_asset` — do not hardcode, and do not resample the census to fake it.
Apply the equivalent focus mask. Pixel area **0.09 ha**. State the CRS you found and the exact
raster used.

If Grid 2 cannot be produced — the native-resolution product is absent, or the focus mask cannot
be applied at 30 m — **say so plainly and produce Grid 1 only.** Do not substitute a resampled
census and label it "30 m". A missing Grid 2 is a finding.

For each grid, report:

- Overall: min, p05, p10, p25, p50, p75, p90, p95, max, mean, sd
- The same, by community
- The same, by `flood_zone` (0–4)
- A cumulative area table: thresholds 40, 45, 50, 55, 60, 65, 70, 75, 80, 85 — pixel count,
  area ha, and % of focus, for `veg_p05 >= threshold`

Include a `grid` column (`census_24_97m` / `native_30m`) on every row, plus `pixel_area_ha`,
`crs_epsg`, and `source_artefact`.

Then add a short comparison block to the gate report: for each threshold, the two areas and their
ratio. **Report the ratios. Do not explain them.** If any threshold reproduces ~6,460 ha or
~4,300 ha on either grid, state which threshold and which grid, as a plain observation — do not
conclude that it validates the claim.

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
6. **No un-sourced hectare claim about the floor variable appears in any Gate C or Gate D output.**
   Specifically: the word "refugia" appears nowhere; and no hectare figure for `veg_p05` appears
   without its full definition inline (variable, threshold, mask, grid, pixel area). Reporting a
   value inside the §D.2 cumulative table — where the threshold is the row label — satisfies this.
   Asserting one in prose does not.
10. **No number flagged as wrong was replaced by another number.** Per §0.2a, corrections to
    unverified claims are non-numeric. If any output or commit substitutes one hectare figure for
    another, the gate fails.
7. Every new `figure_asset` row has a non-null `framing_label` and `superseded_flag`.
8. `v_presentation_headlines` is unaltered and still present.
9. Every figure caption stating a numeric claim cites a source resolvable to §1 or a DB view.

---

## 4. What this task does NOT settle

Listed so they are not silently assumed closed:

- **D1** — Task H spec v4 commitment (Gate A reports status only)
- **D7** — the legacy headline view still publishes the retired 9.23 pp
- **D8** — whether any claim about the floor variable is warranted at all, and at what definition
  (human decision, informed by D.1–D.3 and the dual-grid table in D.2)
- **D9 (new)** — the ~6,460 ha supersession pushed as `e87bd1a` on `fix-refugia-changelog`.
  Gate A §A.6 reports whether its chain resolves; **the PR should not be merged until it does.**
  If `UNRESOLVED`, the changelog entry needs a non-numeric correction, not a third number.
- **The stale doc sites in §1.6**, including `CLAUDE.md:44`. These are the human's edits.
  Per §1.5.3 they are corrected to a non-numeric form — not swapped to ~6,460 ha.
- The Jana email (L07 cut-date provenance, L10 bank geometry) — still the sole blocker on Task J
- Which of the five `S_veg_water_*` variants is canonical for the deck
- The 16 migration blockers and the `scripts/_deprecated/` convention violation
- Whether Adrian holds the plot-support or pixel-support version of the 2018 analysis
