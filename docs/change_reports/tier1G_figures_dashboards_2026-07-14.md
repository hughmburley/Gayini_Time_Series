# Change report — Tier 1 · Task G (figures + dashboards refresh)

**Branch:** `feature/tier1g-figures-dashboards`
**Date:** 2026-07-14
**Scope:** Presentation-only. Four workstreams (G1–G4) on one branch, plus a
foundational restore (Finding 0). **No analysis numbers change** — verified: F6
gate untouched; F7 verdict tally re-ran to 6 responds / 3 weak / 0 mixed and
median r 0.17 / 0.26 / 0.42 (unchanged). Branch-and-PR into `main`, **held at the
gate for human review — NOT merged.**

---

## Finding 0 (recon) — two helpers the trial dashboards depend on were missing from `main`

The untracked dashboard trial code (`R/gayini_dashboard_panels.R`,
`R/gayini_dashboard_compose.R`) calls **`gayini_area_map_core()`** and
**`gayini_bivariate_legend_mini()`**. Both were written on
`feature/tier1e-f7-groundcover-response` (commit `5efa322`) but **never landed on
`main`** when that branch merged — only the *new* untracked dashboard files
survived. So the dashboards could not render against the current working tree.

Restored (matching `5efa322`, non-breaking):

- **`gayini_area_map_core()`** extracted out of `gayini_plot_area_map()` in
  `R/gayini_area_map.R` — the bare map (fill + outline + neighbours + points +
  `extra_layers`); `gayini_plot_area_map()` now wraps it with the title / inset /
  caption bands. Same rendering path → C1 / F5c reconcile unchanged.
- **`gayini_bivariate_legend_mini()`** re-added to
  `R/gayini_veg_regime_functions.R` — the compact 3×3 community × wetness key.
- **`gayini_locator_inset()`** (new, `R/gayini_area_map.R`) — the property-scale
  farm-locator mini-map, factored out of `gayini_plot_area_map()` so both the
  slide wrapper and the dashboard map panels share it (used by G4).

The spec's inferred function homes were otherwise correct.

---

## G1 — F5 concept figure → 4 panels (`gayini_build_f5_concept`, `R/gayini_stratified_sampling_figures.R`)

Replaced the 3-panel concept (which ended at "N random points per band", equal N,
single draw) with a **4-panel** "proportional + repeated" concept:

- **A · near the plots** — 2 km neighbourhood, footprints + 100 m excluded;
  caption states candidate headroom is ample / non-binding (audit), not the
  limiting constraint.
- **B · within-community terciles** — one community patch split into
  flood-frequency terciles (low/mid/high, light→dark), stratified points coloured
  by band, plot footprints haloed and kept empty.
- **C · proportional + floor** — three community boxes with **area proportional to
  allocation** so drawn point counts scale with area (Aeolian ~100 · Riverine
  ~270 · Inland ~1,000 pts/band); floor = 50 marked.
- **D · repeat ×N seeded → across-draw band** — each community's across-draw
  median flood frequency (Aeolian 9% · Riverine 22% · Inland ~50%, gold/teal/blue)
  with a 10–90th percentile band; bands overlap by design. Caption: uncertainty =
  across-draw spread, **not** a single-draw CI.

`n_draws` is a **parameter (default 100, `stopifnot(>= 100)`)** — never hardcoded.
The real-data companion (checkerboard / sampling map, `F5_fullfarm_map_data`) is
unchanged. Also registered the F5 concept in `figures_manifest.csv` (it was
previously unregistered).

## G2 — Vegetation-response scatter rescale (dashboard panel + standalone F7)

New shared primitives in `R/gayini_ground_cover_response_functions.R`:
`gayini_veg_response_scale()` (sqrt-x with ticks 0·1·5·25·50·100, zeros kept;
`coord_cartesian(ylim = c(35, 100))` — zoom not clip) and
`gayini_veg_response_trend()` (binned conditional mean ±95% CI). Applied in **both**
homes:

- `gayini_panel_veg_response()` (`R/gayini_dashboard_panels.R`) — sqrt-x, points
  `alpha = 0.1`, binned-mean trend, `n = … plots` annotation moved to the clear
  bottom-right corner.
- `gayini_build_f7_response_by_community()` (`R/gayini_ground_cover_response_figures.R`)
  — same rescale; the linear community fit is replaced by the empirical binned
  mean (shows the ~78%→~90% rise-then-plateau on the sqrt axis); per-plot spaghetti
  kept but faint; `median r / n plots` annotation moved to bottom-right; facet
  spacing widened so seam tick labels don't collide. The `annual_occurrence_pct =
  SECONDARY / wet-extent intensity` labelling is retained.

## G3 — Time-series alignment (shared date axis)

`gayini_year_to_date()` + `gayini_series_date_scale()` (new,
`R/gayini_dashboard_panels.R`). The three time panels (annual flooding, total
vegetation, gauge-flow context) now plot on a **Date axis** with **identical
limits + 5-yearly breaks** (computed once by the composer as the union of all time
inputs). The series column is stacked with **`patchwork`** so panel widths / left
edges align — a year reads straight down. Only the last date panel (total veg)
keeps its x-axis labels; the upper date panels have theirs stripped (gridlines
still align). The vegetation-response panel keeps its sqrt-x and aligns on the left
edge only.

## G4 — Dashboard layouts converged (site / paddock / stratum)

The A/B/C bake-off is **resolved into one converged layout family** in
`gayini_build_dashboard()` (`R/gayini_dashboard_compose.R`): **big map left ·
aligned time-series column right (G3) · compact horizontal baseline-gauge bar ·
"where it sits" boxplot · sqrt-x vegetation response (G2)**. Per type:

- **Site** — flood-frequency map (1 km ring + footprint + **farm-locator inset**)
  top-left, community boxplot bottom-left under it; right = gauge-flow → flooding →
  total veg → response (aligned); compact gauge bar bottom-right.
- **Paddock** — community × wetness checkerboard map + **locator inset**, with the
  3×3 key moved to a **strip under the map** (off the map's side, so it stops
  stealing width); right = flooding → total veg → response; gauge bar; boxplot
  bottom-right.
- **Stratum** — whole-farm map, class highlighted, **enlarged** (full left-column
  height); right = flooding → total veg (**green line only, bare ground dropped**)
  → response; gauge bar; boxplot bottom-right.

New panel options: `gayini_panel_baseline_gauge(compact = TRUE)` (thin bar);
`gayini_panel_total_veg(green_only = TRUE)`; locator inset on site + paddock map
panels. Driver `scripts/07_figures_dashboards/12_build_dashboards_trial.R` updated
to build one converged layout per unit (13 figures: 5 sites, 4 paddocks, 3 strata,
1 A3), register the manifest, and pass the acceptance gate (`all_pass = TRUE`).

## Hard rules honoured

4-class `simplified_vegetation_group` only; no `period` / `vegetation_adrian_group`
leakage; no pre/post language; EPSG:8058 throughout; flood frequency headline,
`annual_occurrence_pct` labelled SECONDARY on the response x; community palette =
`gayini_gradient_palette()` (Aeolian gold · Riverine teal · Inland blue · Woodland
grey). One figure = one file = one slide; insets/legends never overlap
titles/captions.

---

## Open items — flagged, not guessed (built with the documented default)

| # | Item | Default built | How to switch |
|---|------|---------------|---------------|
| 1 | **Site vegetation panel** bare ground | **Kept** (spec-recommended; informative at plot level) | `gayini_panel_total_veg(green_only = TRUE)` for the site call in the composer |
| 2 | **Stratum locator inset** | **Omitted** (map already shows the whole farm with the class highlighted) | add `add_locator()` to the stratum branch of `gayini_panel_map()` |
| 3 | **F5 panel D** exemplars vs facet | **3 community exemplars** | `gayini_build_f5_concept(facet_all = TRUE)` → all 9 strata |
| 4 | **F5 layout** 2×2 vs horizontal | **2×2 grid** (as mocked) | `gayini_build_f5_concept(layout = "horizontal")` → 4-wide strip |

---

## Verification

- Parse-checked all changed files.
- **F5 concept** rendered in all three variants (grid / facet_all / horizontal) —
  visually confirmed.
- **F7 response** re-run via `08_run_groundcover_response_f7.R` end-to-end: gate
  passed, verdict tally + median r unchanged, rescale reads the ~78→90% rise.
- **Dashboards** — full driver run: 13 units, QA `all_pass = TRUE`, acceptance
  gate passed; site / paddock / stratum each visually confirmed (inset, legend
  strip, enlarged stratum + green-only veg, shared date axis, compact gauge bar).

## Handoff

- Deliverables copied to `Output/review_bundles/tier1G_figures_dashboards/`
  (13 dashboards + F5 concept + F7 response + manifest + QA) and zipped.
- Diagnostic renders are gitignored (`Output/`); code + this report committed.
- **Held at the gate — do NOT merge.** Hand back for human review + merge.
  No dependency on the Wednesday Adrian sync.

---

## Addendum — dashboard layout revision (final geometry), 2026-07-14

Second commit on the same branch. **Layout-only** rewrite of the dashboard
composer to the final agreed geometry (`docs/Tier1_TaskG_dashboard_layout_revision.md`).
G1 / G2 / G3 untouched. No analysis numbers change (13 dashboards rebuilt, QA
`all_pass = TRUE`).

- **One shared skeleton for all three** (`gayini_build_dashboard`, one function +
  a `has_gauge_flow` site variant — no per-type layout branches). Two columns,
  left ≈ 46% / right ≈ 54%.
  - **Left (identical):** map → "where it sits" boxplot → compact gauge bar,
    stacked, heights **11 : 6 : 3**. The map is shorter so the boxplot has room;
    **the gauge is on the LEFT for all three** (was bottom-right on site/paddock).
  - **Right:** aligned temporal series (shared date axis, G3) with a **tall
    sqrt-x response scatter** at the bottom. Row ratios **1 : 1 : 3** (paddock /
    stratum) and **1 : 1 : 1 : 3** (site, with the gauge-flow row). The 3× response
    row is the point of the revision — it gives the G2 scatter vertical room.
- **Total vegetation is green-only on ALL three** now (bare-ground line dropped
  everywhere; `gayini_panel_total_veg(green_only = TRUE)` for every unit). Veg
  data unchanged — only the brown series is removed.
- **Paddock legend is now a map-corner inset** (boxed 3×3 key, bottom-right of the
  raster) via `gayini_bivariate_legend_mini(boxed = TRUE)`, not the under-map strip.
  Locator inset stays top-left on site + paddock; none on stratum.
- **Driver renamed** `12_build_dashboards_trial.R` → `12_build_dashboards.R`
  (no other references existed — not in run-order CSVs, smoke tests, or CLAUDE.md).

Superseded from the first pass: the earlier per-type layouts (gauge bottom-right,
paddock legend strip under the map, stratum-only green-veg, enlarged stratum map)
are replaced by the single shared skeleton above.

---

## Addendum — branch reconciliation / merge to main, 2026-07-14

Authorised merge of this branch to `main` (the usual hold-at-the-gate was lifted).

- `feature/tier1g-figures-dashboards` rebased onto `origin/main` (was `45310d2`,
  which already had tier1f-rebalance-mechanics + the CLAUDE.md post-build-order
  fix) — **clean, zero conflicts** — then `main` fast-forwarded to it.
- **Finding 0 resolved on merge:** `gayini_area_map_core()` +
  `gayini_bivariate_legend_mini()` (+ the new `gayini_locator_inset()`) now live
  on `main` with a single home each. The tier1e versions are superseded.
- **`feature/tier1e-f7-groundcover-response` deleted (local + remote).** Its one
  unique commit was **`5efa3229a89d31435db7c0105cf2e70834d0c27e`** ("veg map
  functions") — recorded here so it is recoverable if ever needed. Its F7 analysis
  was already on `main`; the map/legend helpers it introduced are superseded by
  the evolved versions on tier1g.
- `feature/tier1g-figures-dashboards` deleted after the fast-forward (it *is*
  `main` now).

Task F resampling production run is untouched — still gated on the Wednesday sync.
