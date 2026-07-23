# D2 site-dashboard batch build — all non-treed sites (57 of 66)

*Design seat, 20 July 2026. Execution: Claude Code, branch-and-PR, **held for human review — do not merge**. Branch `d2-site-dashboard-batch` off `main`.*

**Gate 0 CLOSED (0a + 0b passed, 20 Jul).** Generator located: `scripts/07_figures_dashboards/12_build_dashboards.R` (driver) + `R/gayini_dashboard_compose.R` (DB access, correctness logic) + `R/gayini_dashboard_panels.R` (panels). Both correctness checks confirmed from source (spine aggregate, plot support). **Key finding: the 5 shipped PNGs are STALE** — they predate the committed #21 label fix (commit `67977bd`, 15 Jul) and therefore are *not* the canonical reference. **Current `main` is canonical.** Parity re-run reproduces `main` on values + layout; the only difference is the corrected label. Consequence: scope is now **57 built fresh**, with the 5 stale PNGs archived — see §0, §2 panel 6, Gate 2.

**Gate 1 CLOSED (passed, read-only, 20 Jul).** Roster asserts pass: 57 non-treed, 9 treed named. Three findings revised the spec: (a) the generator resolves inputs off `root_dir`, not the DB registries — acceptance #5 relaxed to existence-checks; (b) `spatial_review_flag=1` is **23 sites, not 5** (the 5 known-review ∪ 18 sites outside mapped paddock coverage), and the generator has **no banner/flag render path at all** (GA_032 is a positive control) — the on-image banner is deferred to a deliberate fast-follow (see §7); (c) 18 sites land outside all paddocks — a report-assembly gap, no D2 impact. Output now lands in `Output/figures/dashboards/`.
`CLAUDE.md` (conventions, builder-is-destructive, four-CRS discipline) · `docs/Gayini_established_data_facts.md` (§10 settled — do not re-open; §11 support traps) · `docs/Gayini_Results_database_overview.md` (consume via views) · `docs/Gayini_site_report_GA_019_prototype.md` (the report these dashboards embed; its BATCH-BUILD NOTES are the field contract) · `docs/Gayini_presentation_design_system.md` (palette/community colours).

---

## 0. What this task is

Scale the **existing** D2 site-dashboard generator to **all 57 non-treed sites**, so each per-site report (Deliverable 1) can embed its dashboard. This is a **reproduce-the-existing-generator** task, **not a redesign**. The **authority is current `main`** (the generator as it stands today), **not** the 5 shipped PNGs — those predate the #21 label fix and are stale (Gate 0 finding). So all 57 are built fresh from `main`, and the 5 stale PNGs are archived, not preserved.

**Additive only. The builder is NOT run at any point.** Figure registration is a targeted additive insert (Gate 3), never a builder rebuild — a rebuild is destructive and would also re-trip the `figure_asset` stale-snapshot trap.

**Scope: 57 non-treed sites.** Treed sites are **out** of this batch (design-seat decision, 20 Jul). The 9 treed-context sites — `treed_plot_flag = 1` / `simplified_vegetation_group = 'Floodplain Woodland/Forest'` — are excluded and named in Gate 1. *Downstream flag (not resolved here): excluding them leaves 9 sites without a D2 dashboard, so their reports cannot embed one. That is a report-assembly decision, raised now, out of scope for this task.*

---

## 1. Standing rules

- **ADDITIVE ONLY.** Nothing deleted. The 5 stale shipped PNGs are **moved to `Output/figures/_archive/`** (a move, never a delete) before the fresh 57 are written, so no canonical file is overwritten in place. All 57 are then built fresh from `main`.
- **The builder is destructive — do not run it.** No `reset_file`, no full rebuild. If the only figure-registration path available is the builder, **STOP and hand back** rather than run it.
- **Resolve every path from the DB, never hardcode.** Raster/figure/layer paths come from `raster_asset` / `figure_asset` / `spatial_layer_asset`; assert `path_exists` per asset before consuming.
- **Canonical CRS EPSG:8058.** `dim_plot` centroids are **EPSG:9473** — reproject before any spatial join or extraction.
- **Consume via views, not raw `fact_*`.** Per-site drivers: `v_plot_current_summary` (one row/plot metadata) and `v_plot_year_analysis_spine` (66×35 series).
- **4-class `simplified_vegetation_group` only.** Never `vegetation_adrian_group`. Never let the pre/post `period` column leak into any output.
- Claude never appears as git author or co-author. No AI attribution in commit messages.
- Commit **code and small results tables/markdown only** — never PNGs, rasters, or large spatial files.
- Archive convention is `scripts/archive/`, not `scripts/_deprecated/`.
- **Stop at each gate. Do not proceed past a STOP without human review. Do not merge; hand back for the human to merge.**

---

## 2. The design contract — confirmed against current `main` (Gate 0)

The generator emits one dense analytical dashboard per site. Gate 0 confirmed this contract against the real code on `main`; where the stale shipped PNGs differ from `main`, **`main` wins** (the difference is the #21 label — see panel 6).

**Header.** `Site dashboard - {plot_id}` (plain bold charcoal). Subline: `{plot_id} | 1.0 km neighbourhood | community: {community_label}`. In the examples the community label reads as the full string (e.g. *Inland Floodplain Shrublands / Swamps*, *Aeolian Chenopod Shrublands*) — preserve whatever display mapping the generator uses off `simplified_vegetation_group`.

**Left column (top→bottom):**
1. **Flood-frequency map** — `Flood freq. (%)` 0–100 blue ramp, dashed **1.0 km neighbourhood ring**, plot footprint outline, a small **farm-outline locator inset** top-left, lat/long graticule.
2. **"Where it sits (by community)"** — per-community boxplots of **per-plot annual wet frequency** across all plots, ordered Aeolian (dry) · Riverine · Inland (wet) · Woodland/Forest (context, grey). This site marked as a red diamond: `this unit X%`. Kruskal–Wallis p annotation ("descriptive"). **This panel is plot support — community reference ≈ 9.1 / 22.3 / 49.6 (Woodland 44, context).** It must never use the census 6.08 / 12.91 / 27.99.
3. **Baseline gauge strip** — `long-run X%` vs `recent Y%` with a `(+N pp)` callout.

**Right column (top→bottom):**
4. **Gauge flow context (background)** — Murrumbidgee water-year mean flow (Downstream Maude Weir), contextual only (not a driver).
5. **Annual flooding, 1988–2023** — `Share of the unit wet each year (wet / valid years) - site neighbourhood`, with the `35-yr mean X%` dashed reference. **This is the 1 km neighbourhood series** (see the two-support note below).
6. **Total veg (green + dead)** — the plot's seasonal ground-cover series (RS). *(This is the corrected #21 label on `main`; the stale shipped PNGs still read "Total vegetation (green cover)", which was factually wrong — the trace includes dead material. All 57 fresh builds carry the corrected label.)*
7. **Vegetation response** — total veg vs wet-extent intensity (secondary metric, sqrt-x), binned mean ±95% CI, footnote `n = 1 plot in {community} (small n)`.

### Two supports coexist on the dashboard — do not reconcile them
- **Gradient panel "this unit X%"** = **plot support** (1 ha, any-water rule) = `AVG(annual_wet_any)*100` from the spine. This is the report headline (GA_019 → 49% ≈ 48.6%).
- **Annual-flooding series "35-yr mean"** = **1 km neighbourhood** mean (GA_019 → 37%; GA_001 → 44% while its plot value is 91%).

These differ by construction. Forcing them equal is an error.

### Full-record framing
1988–2023, all 35 years. **No pre/post language anywhere** — not in titles, captions, or footnotes. The `pre_/post_` and `delta_` columns in `v_plot_current_summary` are provenance-only; the site flood frequency comes from the **spine aggregate**, not those columns. (Confirm the generator does this in Gate 0.)

---

## 3. Deliverables

| # | Path | What |
|---|---|---|
| 1 | `Output/figures/dashboards/D2_site_{plot_id}_slide_data.png` × **57** | all non-treed dashboards, built fresh from `main` into the new `dashboards/` subfolder; the 5 stale flat PNGs first moved to `Output/figures/_archive/` |
| 2 | `Output/review_bundles/d2_site_dashboard_batch/` (+ `.zip`) | all **57** dashboards copied for one-look review, plus the QA tables below |
| 3 | `Output/tables/d2_batch_roster_<date>.csv` | one row per plot: in/out, community, flags, resolved input paths, path_exists, computed flood_freq, community rank |
| 4 | `Output/tables/d2_batch_plot_paddock_<date>.csv` | the materialised `plot_paddock` lookup (§Gate 1) + whether each paddock's `C1_veg_regime_paddock_{key}` figure exists |
| 5 | `Output/tables/d2_batch_qa.json` | machine-readable acceptance-gate verdicts (§6) |
| 6 | `docs/change_reports/d2_site_dashboard_batch_<date>.md` | the report a human reads |

Committed: the generator/wrapper code, tables 3–6, and the small `plot_paddock` lookup. Tables 3–5 go in `Output/tables/` (the repo's tracked-tables home — 12 already tracked there) and are **force-added** (`git add -f`), matching existing precedent, since `Output/` is gitignored. **Not** committed: the PNGs, the 57 PDF siblings (a gitignored print byproduct of the writer — kept, not a deliverable), and the zip.

---

## 4. Gates

### Gate 0 — Locate and confirm the generator *(CLOSED — passed 20 Jul)*

Recorded outcome:
- **Generator:** `scripts/07_figures_dashboards/12_build_dashboards.R` (driver, D2 loop) · `R/gayini_dashboard_compose.R` (DB access + correctness logic) · `R/gayini_dashboard_panels.R` (panels). DB read via `DBI`/`RSQLite` on `v_plot_year_analysis_spine`, `v_plot_timeseries_groundcover`, `dim_plot`, `v_gauge_context_by_water_year`; vectors/rasters via `sf`/`terra` (GDAL); F5/F6 diagnostics via `readr` CSVs. Output hardcoded to `Output/figures`, basename `D2_site_{pid}_slide_data`.
- **Correctness (both PASS, quote-confirmed from source):** flood frequency = `100 * wet_years / valid_years` over valid years (`gradient_helpers.R`); `v_plot_current_summary` is **never queried**, so no pre/post leak. "Where it sits" boxes the same per-plot spine aggregate by `simplified_vegetation_group` — **plot support**; no census source read anywhere, so 6/13/28 cannot appear.
- **Parity:** fresh render of the 5 reproduces `main` — dimensions identical (3999×2250), sizes within ≤1 KB, all values/layout match; anchor GA_019 gradient 48.57→49%, 35-yr mean 36.74→37% (matches prototype 48.6%). **One systematic difference: the total-veg title** — stale PNGs "Total vegetation (green cover)" vs `main` "Total veg (green + dead)" (the committed #21 fix). Not a toolchain divergence.
- **Remote:** `hughmburley/Gayini_Time_Series` (the `hughmurley` spelling in CLAUDE.md/memory is the typo).
- **Toolchain:** R 4.6.1 was base-only; all deps installed as CRAN **binaries** (no source builds), incl. `sf` (GDAL 3.14.1) and `terra`, plus `ragg`/`svglite` (the data-PNG writer — missed in 0a). This R never built the shipped 5, which is *why* the stale label surfaced.

### Gate 1 — Roster, paths, plot→paddock, flags *(CLOSED — passed 20 Jul)*

Recorded outcome:
- **Roster PASS:** 66 plots in `v_plot_current_summary`; non-treed (`treed_plot_flag=0`) = **57**. 9 treed excluded (all "Floodplain Woodland / Forest"): GA_011, 012, 014, 015, 021, 023, 029, 030, 065. The 5 previously-shipped are inside the 57. (Note GA_029 was on the old spatial-review guess but is treed → correctly out.)
- **Path resolution:** the generator resolves inputs off `root_dir`, **not** the asset registries. Registered: `veg_regime_class_8058.tif`, `annual_wet_any/valid_any` stacks (EPSG:28355, correct). **Unregistered "shadow inputs"** (exist on disk, hardcoded): `background_flood_frequency_8058.tif`, the 4 derived `*_epsg8058.gpkg` vectors, the 3 F5/F6 CSVs. → acceptance #5 relaxed (below); shadow-input registration logged as a **separate additive task** (§7), not done here.
- **plot→paddock:** join against `management_zones_epsg8058.gpkg` (centroids reprojected 9473→8058). **39/57 land on a paddock, and every one of those has its C1 figure** (0 sites on a paddock-without-figure). **18/57 land outside all zones** (NA paddock) — GA_018/024/031/032/033/037/038/042/044/045/047/048/049/059/060/061/062/064. Does **not** block the D2 render (dashboard uses the flood-freq ring, not a checkerboard — GA_032 is in the 18 and rendered fine). Report-assembly gap only (§7).
- **Flags:** all 57 are `internal_review` / `public_release_ok=0` / `review_required`. `spatial_review_flag=1` = **23/57** — exactly the 5 known-review sites (GA_006/007/016/022/066) ∪ the 18 paddock-gap sites. **The generator has no render path for any flag or banner** (confirmed by grep + GA_032 positive control). → banner deferred (§7); acceptance #10 revised.

### Gate 1 lookups → promote at Gate 2
Roster, input table, and `plot_paddock` (66 + the 57) are staged in `scratch_parity/gate1/`; promote to the `Output/diagnostics/d2_batch_*` deliverable paths during Gate 2.

### Gate 2 — Batch build *(ADDITIVE)*

1. **Archive the 5 stale PNGs first:** move `D2_site_GA_{001,003,019,032,052}_slide_data.png` (and any `.pdf` siblings) from `Output/figures/` to `Output/figures/_archive/`. Move, never delete. Record the moves.
2. Run the confirmed generator (as on `main`) for **all 57** non-treed sites → **`Output/figures/dashboards/D2_site_{plot_id}_slide_data.png`**. Use a scratch harness that calls the identical code path (`gayini_dashboard_context → gayini_resolve_site → gayini_build_dashboard`) with a controlled 57-site list and `out_dir = Output/figures/dashboards/` — **do not edit the generator**; the subfolder is set purely via the `out_dir` argument. Do not use the driver's built-in "all 13 units" loop.
3. Each dashboard matches the §2 grammar and carries the **corrected #21 label**. **No banner is rendered** — the generator has no banner path and adding one is a deliberate fast-follow (§7), not part of this batch.
4. Copy all **57** into `Output/review_bundles/d2_site_dashboard_batch/`, add a **README** listing all 57 as `internal_review` / `review_required` and naming the 23 `spatial_review_flag=1` sites, and zip.
5. Promote the Gate 1 lookups from `scratch_parity/gate1/` to `Output/tables/d2_batch_*`.
6. **Builder not invoked.**

### Gate 2 — Batch build *(CLOSED — passed 20 Jul)*

Recorded outcome: 5 stale PNGs + 5 PDF siblings moved to `Output/figures/_archive/` (none git-tracked; 0 flat `D2_site_*` remain). 57 PNG + 57 PDF built via the generator's own code path (files unedited; subfolder set via `out_dir`) into `Output/figures/dashboards/`, all 3999×2250. All 57 carry "Total veg (green + dead)"; no banner (GA_006 `spatial_review_flag=1` positive control confirms). 114 muffled warnings = the benign 2/site edge-NA pair from Gate 0. Spot-checks across communities pass; community means 9.1 / 22.3 / 49.6 (n=16/19/22) confirm plot support. Bundle + README + roster + `plot_paddock` produced. Builder not invoked; DB unchanged; writes confined to `dashboards/`, `_archive/`, `review_bundles/`, `tables/`.

Two items handed to Gate 3: (i) deliverable tables relocate to `Output/tables/` and force-add (§3); (ii) 57 PDFs kept as gitignored byproduct.

### Gate 3 — Additive registration + paddock-coverage report *(split; 3a READ-ONLY · STOP, then 3b on go)*

**This is the only gate that writes to the DB, and `figure_asset` is coupled to the destructive builder — so recon before any write.**

**3a (read-only, STOP):**
1. Inspect how the existing `D2_site_*` rows in `figure_asset` were registered — is there a **sanctioned additive registrar** (function/script), or only the builder? Report the mechanism, the row schema, and the checksum convention (builder's first-50-MB method).
2. Produce the **57 proposed rows as a dry-run table** (paths at `Output/figures/dashboards/`, checksums, all columns) — do not write them.
3. Produce the **paddock-coverage report** (distinct paddocks across the 57, and whether each site's paddock has its `C1` figure — the kickoff's coverage check) and a **draft change report**.
4. **STOP.** If no additive registrar exists → hand back; do **not** run the builder to register.

**3b (execute, on human go):**
1. **Register/refresh all 57 figures additively** in `figure_asset` — a targeted, idempotent upsert of 57 rows at the **new `Output/figures/dashboards/` paths** (checksums via the builder's first-50-MB method), matching the schema/convention the existing `D2_site_*` rows use. Point the 5 previously-registered rows at their new subfolder path (their flat originals now sit in `_archive/`). **No delete, no full rebuild.** If no additive registrar exists, **STOP and hand back** — do not run the builder to register.
2. **Paddock-coverage report:** the distinct paddocks across the 57 sites and whether each site's referenced paddock figure exists; flag any site whose paddock lacks a figure. (This is the kickoff's "confirm the paddock maps cover every site's paddock" check.)
3. Write the change report (deliverable 6) and `qa.json` (deliverable 5).

**STOP — hand back for human merge. Do not merge.**

---

## 5. Acceptance gate — CC asserts and reports each

1. **57** non-treed dashboards exist in `Output/figures/dashboards/`, all built fresh from `main`; the **5 stale flat PNGs are in `Output/figures/_archive/`** (moved, not deleted); **9** treed excluded and named.
2. Gradient panel uses plot support (**9.1 / 22.3 / 49.6**); assert it is **not** 6.08 / 12.91 / 27.99.
3. Site flood frequency derives from the spine (`AVG(annual_wet_any)*100`); no pre/post column read; **no pre/post string** in any title/caption/footnote.
4. `simplified_vegetation_group` used throughout; `vegetation_adrian_group` absent.
5. Every consumed input is **existence-checked** (`path_exists=1`) at its `root_dir`-relative path. *(Full DB-registry resolution is out of scope — the generator resolves off `root_dir`, and the unregistered shadow inputs are a separate additive task, §7. Do not edit the generator to force registry resolution.)*
6. Centroids reprojected from 9473 before the paddock join.
7. **Builder not invoked** — DB unchanged except the additive `figure_asset` upsert for the 57 `D2_site_*` rows (row-count / SHA-256 guard).
8. All 57 carry the corrected **"Total veg (green + dead)"** label; no dashboard reads "green cover". The 5 stale PNGs preserved in `_archive/` (not overwritten in place, not deleted).
9. `plot_paddock` lookup materialised; paddock-coverage report produced; gaps flagged.
10. **Banner deferred (not a pass/fail for this batch).** The generator draws no flag/banner; the 23 `spatial_review_flag=1` sites and the all-57 internal-review/review-required status are surfaced instead in the roster CSV and the review-bundle README. The on-image banner is a §7 fast-follow.

---

## 6. Traps carried in

- **C10 (support mixing):** the census means (`census_community_flood_freq_means.csv`, 6/13/28) are pixel support — keep them out of the gradient panel. Plot support 9/22/50 only.
- **Two supports on one dashboard** (§2): plot 1 ha vs 1 km neighbourhood differ by design — do not reconcile.
- **Builder is destructive** and the `figure_asset` 139-row snapshot is stale — registration is additive, never a rebuild.
- **Pre/post is retired** but the columns still exist in the view — provenance-only.
- **Centroids are 9473**, not 8058.
- **Treed = out** for this batch, but their reports still need a plan — raised as a downstream flag, not fixed here.
- **Shipped ≠ canonical.** The 5 shipped PNGs predate the #21 fix; `main` is the source of truth. Parity is judged on values + layout against `main`, *not* byte-identity against the shipped files.

---

## 7. Deferred — spun out of Gate 1, not done in this batch

- **Cultural-sensitivity / spatial-review banner (own task).** All 57 are internal-review / review-required; 23 carry `spatial_review_flag=1`. The generator renders no banner. Wording and placement of a Nari Nari–facing sensitivity notice should be decided **deliberately** (likely with Adrian / Tribal Council input), not batch-stamped. When it lands, re-render all 57 (minutes). Interim protection: the report already carries the banner (prototype top), and the review bundle README lists the status.
- **Shadow-input registration (own additive task).** Register the unregistered on-disk inputs — `background_flood_frequency_8058.tif`, the 4 `*_epsg8058.gpkg` vectors, the 3 F5/F6 CSVs — in `raster_asset` / `spatial_layer_asset`. This is the known shadow-registry issue; keep it out of the build.
- **18 paddock-gap sites (report assembly).** GA_018/024/031/032/033/037/038/042/044/045/047/048/049/059/060/061/062/064 land outside mapped paddock coverage, so their reports have no C1 checkerboard to embed. Decide the stand-in per report. No D2 impact.
