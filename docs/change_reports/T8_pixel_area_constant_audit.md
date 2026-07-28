# Pixel-area constant audit — `0.0625` hunt (REPORT ONLY, no fixes)

**Task:** design-seat request after the PIN 5 catch — grep all tracked code for the nominal `0.0625` pixel-area constant and for area derivations that bypass `gayini_params.PIXEL_AREA_HA` (0.062351428), covering the site/paddock report and dashboard path.
**Date:** 28 July 2026 · **Prior:** SHA 023d982 · **Outcome: no `0.0625` error in any computation.** No fixes applied (touches client deliverables — routed via the correct stream).

---

## Headline — the report/census area path is clean of the 0.238% error

**No computation anywhere in tracked code uses the nominal `0.0625`.** Every `0.0625` hit is either documentation *about* the error (CLAUDE.md, issues log, provenance audit, the T1/T2/T3/T5 specs, prior change reports) or the deliberate lint fixture (`lint_guardrails.py:177`, `_lint_fixture_magic.py`). The one CSV hit (`tier2H_h32_sample_power_1000draws.csv`) is the substring `0.0625` inside a p-value `0.062558` — data, not a constant.

Census/area derivations route correctly:
- `R/gayini_pixel_census_functions.R` — `pixel_area_ha <- prod(terra::res(freq_8058))/1e4` (derived from the raster), `area_ha = np * pixel_area_ha`.
- `04_taskM_green_at_floor_area.R` (canonical refugia area) — `PIXEL_AREA_HA <- 0.09` for the **30 m native EPSG:3577 grid** (30²/1e4 = 0.09, correct-for-grid, asserted `stopifnot(identical(..., 0.09))`).
- Dashboard builders (`gayini_dashboard_compose.R`, `gayini_dashboard_panels.R`, `12_build_dashboards.R`) compute area via `sf::st_area()` on the actual polygons — **true geometry, not pixel × constant** — so there is no pixel-area constant to get wrong.

## The report builders are NOT in this repo — cannot be audited from here

The 66 site / 21 paddock report **generators** are not tracked here; only the prototype doc `docs/Gayini_site_report_GA_019_prototype.md` exists (the `Bala26ca` paddock prototype is not in this repo at all). They run from the separate report stream. **That stream must confirm its own area derivation.** What this repo feeds them is clean: `dim_headline_number` area rows use `gayini_params.PIXEL_AREA_HA`, and `census_by_zone_stratum.area_ha` / dashboard areas are `terra::res`- or `sf::st_area`-derived.

## Secondary finding (report only) — three scripts hardcode the 8058 constant, evading the lint

Correct value, **but bypassing the single source of truth** and — the actionable part — **slipping the magic-number lint**:

| file:line | literal | note |
|---|---|---|
| `scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R:371` | `* 0.0623514` | seasonal-gate hole area (diagnostic) |
| `scripts/05_ground_cover/06_taskM_gateD_p05_ge80_contiguity.R:24` | `PIXEL_AREA_HA <- 0.0623512` | Task M Gate D contiguity areas |
| `scripts/11_database/taskM_gateD_p05_distribution.py:53` | `pixel_area_ha=0.0623512` | Task M Gate D p05 distribution |

These are **not** the `0.0625` error: the correct 8058 constant is `0.06235142`, so `0.0623514`/`0.0623512` are right to ~4–5 sig figs (max ~0.0004% off, vs the 0.238% inflation of `0.0625`). **No material area error, and none of these feeds the 66 site / 21 paddock reports** (they are Task M refugia/floor diagnostics). The canonical refugia number (6,457.95 ha) comes from `04_taskM_green_at_floor_area.R`, which uses the derived constant.

**The real finding is the lint gap.** `MAGIC_LITERALS` bans the exact strings `0.0625` and `0.062351428`, so a *rounded* correct literal (`0.0623512`, `0.0623514`) passes the lint while still bypassing `gayini_params`. The lint blocks two spellings; it does not enforce "pixel-area constants come from the param module." A hardened rule — flag any bare decimal in `[0.062, 0.063]` (and the 30 m `0.09`) outside the param module — would close the class. Logged as **I-30**; relates to I-21 (`hardcoded_path` lint). Not fixed here.

## Minor — cosmetic description strings
`09_build_pixel_census_view.R:177` and `01_build_results_database.py:173` describe the grid as "~0.0624 ha per **25 m** pixel" in a data-dictionary *description string* (the grid is 24.97 m). Display text, not a computation; no number affected.

## Out of scope
`R/modis_ground_cover_functions.R:610` / `R/vector_prep_functions.R:425` use `area_ha / 25` — the **500 m MODIS** pixel (25 ha), a separate (superseded) product, not the census/report path.

## Disposition
Report only, per instruction. **No fix applied.** If the design seat wants the three hardcoded 8058 literals routed through `gayini_params` and the lint hardened, that is a T5/tooling change (post-deadline, I-19/I-21 neighbourhood) and — for anything the report stream touches — routed through that stream.
