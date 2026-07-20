# Tier 1 · Task G — dashboard layout revision (final geometry)

*Task spec for Claude Code. **Layout-only revision** of the three dashboards, applied as a commit on the existing `feature/tier1g-figures-dashboards` branch (held for review, not merged). G1 (F5 concept), G2 (sqrt-x scatter), and G3 (time-series alignment) from the earlier Task G are unchanged — this only rewrites the dashboard layout composer to the final agreed geometry. The branch-reconciliation item (Finding 0) is being handled separately and does not block this.*

**The text grids below are the source of truth.** The embedded wireframes are a visual aid for the *arrangement only* — they are schematic (grey boxes / placeholder sketches), NOT target styling. Render the real panels in the existing dashboard style; just place and size them per the grids.

---

## 1. One shared skeleton for all three dashboards

Two columns, **left ≈ 46% / right ≈ 54%** (small gutter).

- **Left column (identical across all three):** map → "Where it sits" boxplot → baseline gauge, stacked top-to-bottom. Relative heights **map : boxplot : gauge = 11 : 6 : 3** (≈ 0.55 / 0.30 / 0.15). The map is deliberately *shorter* than the previous version so the boxplot gets real room; the gauge is a thin bar. **The gauge is on the LEFT for all three** (this replaces the earlier gauge-bottom-right on site/paddock).
- **Right column:** the time series stacked with a **tall vegetation-response scatter at the bottom**, sharing one aligned date x-axis (G3) for the temporal panels.

**Paddock and stratum are geometrically identical** — only map content and titles differ. **Site is the same skeleton plus one extra row** (gauge-flow context) at the top of the right column. So implement one layout function with a `has_gauge_flow` (site) variant, not three bespoke layouts.

## 2. Right-column row ratios

- **Paddock & stratum:** Annual flooding : Total vegetation : Vegetation-response = **1 : 1 : 3** (≈ 0.20 / 0.20 / 0.60).
- **Site:** Gauge-flow : Annual flooding : Total vegetation : Vegetation-response = **1 : 1 : 1 : 3** (≈ 0.16 / 0.16 / 0.16 / 0.52).

The 3× response row is the point of the whole revision — it gives the sqrt-x scatter the vertical room to actually show the relationship. Tune slightly for legibility, but keep the response panel clearly the tallest on the right.

## 3. Per-dashboard specifics

**All three:** Total-vegetation panel is **green line only — drop the bare-ground (brown) line everywhere** (previously green-only on stratum only; now universal). The vegetation *data* is unchanged; only the brown series is removed from the time-series panel. Bare ground is not needed elsewhere.

- **Paddock** — left map = community × wetness checkerboard with the **bivariate legend as a small inset in the map corner** (not a side or under-map strip) and the **farm-locator inset** top-left; right = flooding → green-veg → tall response.
- **Site** — left map = flood-frequency neighbourhood (1 km ring + footprint + **farm-locator inset**); right = **gauge-flow context** → flooding → green-veg → tall response.
- **Stratum** — left map = farm map with the stratum highlighted (others muted); right = flooding → green-veg → tall response. (No locator inset — the map already shows the whole farm.)

## 4. Layout wireframes (geometry only — not target styling)

![Paddock layout wireframe](mocks/layout_paddock.png)

![Site layout wireframe](mocks/layout_site.png)

![Stratum layout wireframe](mocks/layout_stratum.png)

## 5. Carried through unchanged (do not touch)

- G2 scatter treatment (sqrt-x 0/1/5/25/50/100, y-zoom ~35–100, α ≈ 0.1, binned-mean ±95% CI, annotation in a clear corner) — it just now sits in a taller panel.
- G3 shared/aligned date x-axis across the temporal panels.
- G1 F5 concept figure.
- Headline-metric discipline; `annual_occurrence_pct` stays labelled SECONDARY on the response x.

## 6. Acceptance gate

- All three dashboards share the one skeleton (left: map/boxplot/gauge; right: series + tall response); gauge on the left on all three.
- Total-vegetation panel green-only on all three (no bare-ground line anywhere).
- Response panel is the tallest right-column panel and renders the G2 sqrt-x treatment legibly.
- Map shortened, boxplot not squashed.
- Paddock legend is a map inset; locator inset on site + paddock; none on stratum.
- One layout function + site variant (not three); no analysis numbers change.
- Full driver run: all dashboards build, QA passes; register any renamed/changed figures in the manifest.
- Branch-and-PR (commit on `feature/tier1g-figures-dashboards`), **held for review — do not merge**.

## 7. Handoff

- Review bundle refreshed under `Output/review_bundles/tier1G_figures_dashboards/` and zipped.
- Update the change report `docs/change_reports/tier1G_figures_dashboards_<date>.md` with the layout revision. Commit code + small tables only.
- If the `12_build_dashboards_trial.R` rename to `12_build_dashboards.R` wasn't done in the prior pass, do it here (update references: smoke-test expected files, manifest paths, run-order CSV, CLAUDE.md).

---
*Presentation-only. No dependency on the Wednesday Adrian sync.*
