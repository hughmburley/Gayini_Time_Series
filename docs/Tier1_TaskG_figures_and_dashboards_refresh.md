# Tier 1 · Task G — Figures + dashboards refresh

*Task spec for Claude Code. Design agreed in chat (mockups). **Recon first, then one branch, branch-and-PR into `main`, human-reviewed. Do not merge.** Four workstreams (G1–G4) on a single "figures + dashboards refresh" branch. Function homes below are inferred from the repo stocktake — confirm in recon before editing, and flag in the PR if a home differs.*

---

## Objective

Refresh four presentation artefacts to the designs agreed in chat: the F5 concept figure, the vegetation-response scatter, cross-panel time-series alignment, and the three dashboard layouts (site / paddock / stratum). No analysis numbers change — this is figures and layout only.

## G1 — F5 concept figure (replace the current 3-panel version)

Current concept ends at *"N random points per band"* (equal N, single draw). Replace with a **4-panel** concept:

- **A · near the plots** — 2 km neighbourhood, plot footprints + 100 m excluded. Caption notes headroom is ample / non-binding (audit result), not the limiting constraint.
- **B · within-community terciles** — *one community, spatial*: a patch shaded into three flood-frequency zones (low/mid/high, light→dark), sample points coloured by band, plot footprints with halos. Scope = within one community.
- **C · proportional + floor** — *across communities*: Aeolian ~100 · Riverine ~270 · Inland ~1,000 points per band, point-count/area scaling visible, floor = 50 marked. Scope = across the three communities (this is where proportionality lives; terciles within a community are ~equal area).
- **D · repeat ×N seeded (≥100) → across-draw band** — three community medians (Aeolian gold ~9% · Riverine teal ~22% · Inland blue ~50%), each with a percentile band; bands overlap (truthful — matches the "compare on frequency" point). Caption: uncertainty = across-draw spread, **not** a single-draw CI.

Notes: do **not** hardcode the draw count (N is a parameter, ≥100). The real-data companion stays the existing checkerboard / sampling map (F5 data figure) — unchanged. Likely home: `R/gayini_stratified_sampling_figures.R`.

## G2 — Vegetation-response scatter rescale

Everywhere the "Vegetation response" panel is drawn (dashboard panel + any standalone F7 figure):

- **x: sqrt scale** (`scale_x_sqrt`), ticks relabelled at 0 · 1 · 5 · 25 · 50 · 100. Keep the zeros — they're real dry years.
- **y: `coord_cartesian(ylim = c(~35, 100))`** — zoom, not clip (rare low outliers still plot at the edge).
- **points**: `alpha ≈ 0.1`, small; add a **binned-mean + 95% CI trend** (or `geom_smooth`) so the relationship is legible through the overplotting.
- **move the `n = … plots` annotation** to a clear corner (it currently collides with the plot edge).

Verified on real data (Inland Floodplain, n = 767, r = 0.43): the rescale surfaces total veg rising from ~78% (dry) to ~90% (high wet extent) — currently invisible. Keep the existing `annual_occurrence_pct = SECONDARY / wet-extent intensity` annotation. Likely homes: `R/gayini_dashboard_panels.R`, `R/gayini_ground_cover_response_figures.R`.

## G3 — Time-series alignment

The *Annual flooding*, *Total vegetation*, and *Gauge flow context* panels must share one x date axis so a year reads straight down:

- Common `scale_x_date` limits across all three (they currently end at different years); identical breaks.
- `patchwork` alignment (`plot_layout(axes = "collect")` / aligned widths) so left edges and ticks coincide.

The vegetation-response panel's x is wet-extent (sqrt), so it aligns on left edge only — not on x-values. Likely homes: `R/gayini_dashboard_compose.R`, `R/gayini_dashboard_panels.R`.

## G4 — Dashboard layouts (site / paddock / stratum)

All three converge on one family: **big map on the LEFT · aligned time-series column on the right · compact baseline-gauge bar · "where it sits" boxplot retained · vegetation-response = sqrt-x (G2) · series aligned (G3).** The baseline gauge becomes a thin horizontal bar (it carries one number — no full panel). A **farm-locator inset** (mini farm outline, this unit highlighted) sits in the top-left of the big map.

- **Site** — neighbourhood flood-freq map (1 km ring + footprint + **locator inset**) spans the left column; right column = gauge flow → annual flooding → total vegetation → vegetation-response (sqrt-x), aligned; community boxplot **bottom-left, under the map**; compact gauge bottom-right. (Four series: sites carry the gauge-flow context panel.)
- **Paddock** — community × wetness checkerboard map (**+ locator inset, NEW**) top-left; the community × wetness legend moves to a **strip under the map** (remove it from the map's side — it was stealing width); right column = annual flooding → total vegetation → vegetation-response (sqrt-x), aligned; compact gauge; boxplot bottom-right.
- **Stratum** — farm map with the stratum highlighted, **enlarged**, spanning the full left column height; right column = annual flooding → total vegetation (**green line only — drop bare ground**) → vegetation-response (sqrt-x), aligned; compact gauge; boxplot bottom-right.

Likely homes: `R/gayini_dashboard_compose.R` (layout grids), `R/gayini_dashboard_panels.R` (panels), `R/gayini_area_map.R` (map + inset); driven by `scripts/07_figures_dashboards/12_build_dashboards_trial.R`. Do **not** touch the archivable Task-15 dashboard code (`R/gayini_dashboard_figures.R`, `drier_post`).

## Open items (flag in the PR — don't guess)

- **Site vegetation panel**: keep bare ground (recommended — informative at plot level) or drop it for full visual consistency with stratum?
- **Stratum locator inset**: the stratum map already shows the whole farm with the stratum highlighted, so an inset may be redundant — confirm whether to add one.
- **F5 panel D**: three community exemplars (default) vs facet to all nine strata.
- **F5 layout**: 2×2 (as mocked) vs horizontal strip to match the deck's current F5 slide.

## Conventions / acceptance gate

- One figure = one file = one slide; register new/changed figures in `figures_manifest.csv`; insets/legends never overlap titles/captions.
- Community palette: Aeolian gold · Riverine teal · Inland Floodplain blue · Woodland/Forest grey.
- Headline-metric discipline: flood frequency is headline; `annual_occurrence_pct` stays labelled SECONDARY on the response x.
- 4-class `simplified_vegetation_group` only; no `period` / `vegetation_adrian_group` leakage; no pre/post language.
- Branch-and-PR into `main`, **held for review, not merged**. Recon (confirm function homes) → short plan → implement → stop at the gate.

## Handoff

- Copy deliverables to `Output/review_bundles/tier1G_figures_dashboards/` and **zip**.
- Change report at `docs/change_reports/tier1G_figures_dashboards_<date>.md`; diagnostic renders gitignored, referenced there. Commit code + small tables only.

---
*No dependency on the Wednesday Adrian sync — this is presentation work and can land independently of the Task F resampling run.*
