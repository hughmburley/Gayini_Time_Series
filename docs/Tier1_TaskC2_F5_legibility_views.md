# Tier 1 · Task C2 — F5 legibility views

**Branch:** `feature/tier1c2-f5-legibility`
**Type:** one Claude Code task · branch-and-PR into `main`
**Depends on:** Task C (F5) merged — reads `Output/spatial_8058/stratified_sample_points.gpkg`, `Output/rasters/background_flood_frequency_8058.tif`, `Output/diagnostics/regime_band_breaks.csv`, and the 8058 community + management-zone vectors. **No new sampling or analysis** — this is a presentation-only pass so the F5 result reads clearly for Adrian and Nari Nari.

---

## Why

The whole-property F5 map is dense, and the regime bands are **within-community terciles** — so "high" means a different absolute frequency in each community (Aeolian high = 5.7–76%, Inland low = 0–18.7%; they overlap). A single property-wide regime split would mislead. This task adds views that make the relative banding legible and can't be misread, plus paddock-level detail.

## Steps

1. **Fix the relative-band labelling (all F5 figures).** Rename the legend from "low / mid / high" to **"low / mid / high (within-community, relative)"**, and print the tercile-break table (from `regime_band_breaks.csv`) on or beside every figure that shows bands — so a reader sees that Aeolian "high" ≈ 6–76% while Inland "high" ≈ 34–97%.
2. **F5b · Community facets** — a 3-panel figure (one per focus community: Aeolian, Riverine, Inland Floodplain). Each panel: the background flood-frequency surface clipped to that community, its points coloured by band, and its three tercile breakpoints annotated on the panel. Self-contained panels = "split by regime" that can't be read across communities. Save PNG + PDF.
3. **F5c · Paddock zooms** — pick 3–4 management zones (paddocks) that are point-dense and span communities/bands (choose by point count × community spread; log which were chosen and why). One zoomed map per paddock: surface + points by band + paddock outline, with a locator inset. Save PNG + PDF. Treat these as the seed of the future Nari Nari paddock-review panels.
4. **Register** the new figures in `figures_manifest.csv` (kind = `data`, step `F5b` / `F5c`); write `docs/change_reports/tier1c2_f5_legibility.md` (local).
5. **Package** → `Output/review_bundles/tier1c2_f5_legibility.zip`.

## Acceptance gate

```r
stopifnot(
  # relative-band labelling present on band figures
  grepl("within-community|relative", legend_label, ignore.case = TRUE),
  # community facets: 3 panels, each with its own tercile breaks annotated
  n_facet_panels == 3,
  # paddock zooms: chosen paddocks logged with rationale
  nrow(paddock_choice_log) >= 3,
  file.exists("Output/review_bundles/tier1c2_f5_legibility.zip")
)
```

## Commit & push

```
git add R/ scripts/
git commit -m "Tier1C2: F5 legibility views — community facets, paddock zooms, relative-band labels"
git push   # PR feature/tier1c2-f5-legibility -> main
```
Code only; change report stays local.

## Notes

- Presentation only — do **not** re-sample, re-band, or alter the F5 data products.
- Bands are within-community relative by design (Q1 to Adrian may change this to absolute; if so it's a one-line change in F5, and these figures inherit it). Label them so the relative choice is explicit, never implied.
- Paddock zooms feed forward into the Nari Nari paddock-review panels — build them reusably.
- Stop at the acceptance gate; the zip is what we open.
