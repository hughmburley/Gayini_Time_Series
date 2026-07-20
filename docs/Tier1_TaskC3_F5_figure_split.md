# Tier 1 · Task C3 — F5 figures: one file per slide + inset fix

**Branch:** `feature/tier1c3-f5-figure-split`
**Type:** one Claude Code task · branch-and-PR into `main`
**Depends on:** C2 (reads the same F5 products/figures). **Presentation-only — no data, sampling, or band changes.**
**If C2 is not yet merged, fold this into the C2 branch instead of a new one.**

---

## Why

New standing convention: **one figure = one file = one slide.** The current `F5_stratified_sampling_map_data` file composites the full-farm map *and* the band tables into one image, which is too much for a single slide; and the paddock locator inset overlaps the title on Bala 29ca. The data is correct — this only re-carves and cleans the figures.

## Steps

1. **Split the F5 map file into standalone, single-slide files:**
   - `F5_fullfarm_map_data` — the whole-property background-frequency surface + band-coloured points + legend + scale bar + north arrow **only**. No tables. This is the one-slide farm overview.
   - `F5_band_reference_data` — the points-per-community × band matrix **and** the within-community tercile-break table (the "bands are relative / they overlap" reference). Its own file / slide.
   - `F5b_community_facets_data` — keep as is (the 3 community panels are one deliberate small-multiple = one figure/slide); just confirm it isn't cramped at slide size.
   - Paddock zooms (`F5c_paddock_*`) — already one-per-file; keep.
   Do **not** re-composite the farm map with zooms or tables.
2. **Fix inset placement (all inset figures).** Move the locator inset (or reserve a clear title band) so it never overlaps the title, subtitle or caption. Verify on **Bala 29ca**, where the inset currently covers the paddock name. Prefer an inset corner sitting over low-information area, fully clear of all text.
3. **Sanity at slide size.** For each figure, confirm nothing is cut off and text is legible when the file fills one 16:9 slide (no cramming).
4. **Re-register** in `figures_manifest.csv`; re-package `Output/review_bundles/tier1c3_f5_figures.zip`; change report local.

## Acceptance gate

```r
stopifnot(
  # the farm map file is map-only (no tables composited in)
  fullfarm_has_tables == FALSE,
  # band reference is its own file
  file.exists("Output/figures/F5_band_reference_data.pdf"),
  # no inset overlaps title/caption on any inset figure (checked + logged)
  all(inset_overlap_check$clear == TRUE),
  file.exists("Output/review_bundles/tier1c3_f5_figures.zip")
)
```

## Commit & push

```
git add R/ scripts/
git commit -m "Tier1C3: F5 figures one-per-file (farm map / band reference / facets / paddocks) + inset fix"
git push   # PR feature/tier1c3-f5-figure-split -> main
```
Code only; change report local.

## Notes

- Standing convention now recorded in the ladder: one figure = one file = one slide; insets never overlap captions. Apply it to every figure from here on, not just F5.
- Presentation-only; the F5 data products and bands are untouched.
- Stop at the acceptance gate; the zip is what we open.
