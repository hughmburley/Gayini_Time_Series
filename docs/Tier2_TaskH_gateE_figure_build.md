# Tier 2 · Task H — Gate E figure build: the all-pixel veg×wetness response

*Build task for Claude Code. **Separate session** from the on-disk review (`Tier2_TaskH_ondisk_census_groundcover_review.md`), which is complete and green-lit this work. That review's verdict: the census spine is sound; S12/S21 are figure-renders on existing computations; **S24/S25/S26 + the dashboard scatter are new per-pixel analysis** (the per-pixel veg×wet-extent response does not exist yet — only the plot version from script 08).*

**This is a BUILD session**, unlike the review. It computes new analysis and renders committed figures — but still gated, recon-first, STOP at each gate for review. Additive-only; branch-and-PR; no builder re-run (it destroys the 12 Task H census rows).

> **STATUS: figure-style section locked (below). Remaining gates stubbed — to be fleshed out when Hugh scopes the build. Do not start building from the stubs.**

---

## Locked decisions (from the review + the style discussion, 2026-07-20)

1. **The census spine is verified sound** — build on it directly; do not re-audit.
2. **S24/25/26 are the veg×wetness response census**, not a restyle of plot data. Same-year response = fully all-pixel; the **S25 lag is record-limited** (seasonal FC + recent monthly inundation) — label the two support levels separately, never merge into one "F7 is all-pixel" claim.
3. **Two honesty checks ride on every all-pixel figure caption:** (i) ~1M pixels collapse *sampling* uncertainty but not the structure-vs-condition limit (FC = cover, not ecological condition) or spatial autocorrelation — pixels are **not** independent *n*; (ii) narrow density/CI ≠ certainty.
4. **Open defects to fold in as small cleanups** (from the review ledger): **D2** (add `farm_area_total_ha` = 85,910.8, repoint `v_pixel_census_by_veg_regime.pct_of_farm` off the mapped 67,349 basis); **D8** (restate refugia hectares on the native 30 m grid ~6,460 ha, or reproject the floor to 8058 before counting — state the pixel basis); **D1/D7** (correct CLAUDE.md's stale "v4 not committed" line; add the `veg_p*` NaN-not-NULL data-dictionary caveat). Each is one concern — do them as discrete commits, not a bundle.

---

## §F — Figure-style section (LOCKED — build to this exactly)

Two figures come out of the POC choice, with different jobs. **Fig A is the technical companion; Fig B is the deck/report figure.** They are deliberately styled differently.

### The canonical community palette (use verbatim — do not invent shades)

**CANONICAL = the C1 checkerboard set** (`gayini_veg_regime_classes()` mid band — committed; drives the C1 checkerboard map + flood-zone raster). Source it programmatically; never hardcode.

| Community | Canonical (C1 checkerboard) |
|---|---|
| Aeolian Chenopod (dry) | `#C79A3C` gold |
| Riverine Chenopod | `#3FAE97` teal |
| Inland Floodplain (wet) | `#2E6DB0` blue |
| Woodland / Forest (context) | `#9E9E9E` grey |

> **Correction (2026-07-21 palette audit).** An earlier draft recommended a "biodiversity-config" set (`#C79A3B` / `#3B8A8F` / `#2165AC`) as "the one committed in code" — those hexes are **committed nowhere**. The committed sets are the C1 checkerboard (above, now canonical) and the F7-gradient palette (`gayini_gradient_palette()`, a distinct second set). See `docs/change_reports/tier2H_gateE_palette_audit.md`.

### Fig A — the analysis / companion figure (viridis density + GAM trend)

- **Style:** 2-D density (the `geom_bin2d` field from POC1) with the **GAM central-tendency line ±95% CI** over it (POC2). This is the "show the whole cloud" figure a remote-sensing reviewer expects.
- **Palette: stays viridis — deliberately NOT the deck palette.** Its job is to look like data/QA, colour-blind-safe, distinct from the styled deck figure. Do not community-colour it.
- **Fix carried from the POC:** the GAM's high-flood-frequency wiggle (the dip-and-rise past ~75%) is fitting noise in the sparse tail. Either extend the CI honestly so it visibly widens there, or truncate/flag the fit where bin counts fall below a threshold — do **not** let the wiggle read as a finding. Fit on a sample or on binned summaries, not the raw million.
- **Role:** appendix / methods / journal-supplement. Not the headline slide.

### Fig B — the deck & site-report figure (quantile bands, community-keyed)

- **Style:** quantile bands (POC3) — p50 line with p10/p25/p50/p75/p90 bands per flood-freq bin. The most honest for a skewed floor and the most readable.
- **THE COLOUR RULE (this is the locked nuance — split the two roles by hue):**
  - **Central tendency (p50) line = the community's own hue** from the canonical palette above (Inland `#2E6DB0`, Riverine `#3FAE97`, Aeolian `#C79A3C`). So the figure is visually keyed to the community it's about — consistent with the C1 checkerboard, F6 panels, and dashboards where that community is already that colour.
  - **Quantile bands (p10–p90) = graded NEUTRAL GREY**, not tints of the community colour. Darker grey for the inner p25–p75 band, lighter grey for the outer p10–p90. Grey = "spread / uncertainty", the universal statistical convention.
  - **Why:** the bold coloured line says *which community* (identity); the grey bands say *this is the distribution* (uncertainty). The two never fight, and it fixes the POC3 problem where line and bands were the same blue and separated only by lightness. Hue separates them cleanly.
- **Do NOT use red/pink/orange for the central tendency.** A rising veg floor (more flooding → greener) is a good-news story; warm "alert" colours send a subtly wrong signal, especially for a Nari Nari audience reading country health. Community-hue keeps the meaning neutral.
- **Both honesty checks** printed in the caption (see Locked decision 3). Keep the "sparse-bin honesty" visible — where a bin thins, the bands widen; don't smooth that away. Explain any conspicuous wobble (the POC had one near flood-freq ≈ 47% — a thin bin; label it rather than hide it).

### Build order — MATRIX FIRST

- **Build the 3×3 community×wetness matrix (S26) first.** Nine cells, each p50 line in its community hue, grey bands throughout — the whole dry→wet × community response gradient in one figure. This is the "biggest win" object.
- **Derive the per-community singles (S24) by collapsing the matrix** (pool wetness bands within community). Same data, same style, fewer facets — so build the matrix, then reduce, rather than building singles separately.
- **S25 (lag) reuses the same styles** but on the record-limited lagged computation — with its support caveat prominent.

### Crucial scope note — the POC is cross-sectional; the real S24/26 is temporal

The POC substrate is floor-`veg_p05` vs **between-year flood frequency** — a *spatial* gradient across pixels (this is the §9 40.68 pp gradient, and it's a fine figure in its own right). The actual **F7 response** question is veg vs **within-year wet-extent, per pixel, over time** — the same-year *temporal* response, which is the new-analysis piece that does not yet exist. **The styles (Fig A / Fig B) carry over unchanged, but the underlying computation is different and may be noisier than the clean POC curve.** State this plainly so nobody expects the POC's exact shape back. Both figures (cross-sectional gradient AND temporal response) may be worth keeping — they answer related but distinct questions.

---

## §G — Remaining build gates *(STUBBED — flesh out when Hugh scopes the build)*

> These are placeholders so the handoff is complete. Do not build from them yet.

- **G1 — Compute the per-pixel same-year veg×wet-extent response** (the new analysis underpinning S24/26). New script alongside `12_run_census_trend_test.R`; per-pixel correlation of total-veg vs within-year wet-extent intensity over the record; summarise per stratum and per community. Emit a committed table (the C9 lesson: table, not prose). Define the intensity metric and axis transform (the old panel used sqrt-x on within-year wet-extent — decide and document).
- **G2 — Compute the per-pixel lagged response** (S25), record-limited. Establish the usable pixel-month footprint honestly; report effective *n* per lag.
- **G3 — Render S21** — the census F6 (9/0/0) figure that doesn't exist yet, from `tier2H_h32_census_f6_verdicts.csv` (script 12). Re-tint the verdict, drop the plot-era "provisional/thinly-sampled" caveat. This is a render, not a compute.
- **G4 — Simplify S12** — keep the area coverage bar, drop the sampling-density half. Keep "66.44% of mapped farm" as written (held trap).
- **G5 — Render Fig A + Fig B** per §F, for the matrix-then-singles order.
- **G6 — Cleanups** — D2, D8, D1/D7 per Locked decision 4, as discrete commits.
- **G7 — Registration** — register the new figures/tables in `figure_asset`/`raster_asset` (this closes part of D4). **Non-destructive registration only** — the builder re-run destroys the 12 Task H census rows; use an additive registration path, never `reset_file`.

**Each gate STOPs for review. Nothing merges without Hugh's PR review.**
