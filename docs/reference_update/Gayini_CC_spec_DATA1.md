# CC spec DATA-1 — the raster companion folder

**Design seat · 8 August 2026.** Small, urgent, runs alongside TEMPORAL-1. Adrian has asked for the
flood frequency surface and should also receive the temporal cover percentiles.

**Copy, never move. Nothing is deleted, renamed or re-derived.** Every source file stays where it is.

---

## 0 · Two things to settle before copying

### 0.1 · The destination

**`Output/rasters/DATA_share_20260808/`** — a new folder beside the sources.

Beside the sources, no permission rule in the way, and no pack manifest to break. **Do not write into
`Output/pack/`** — it is unwritable under the deny rule in `.claude/settings.json`, and pack v1.4 is
sealed at `7c5ec74daf747cd0…` with a 22-member manifest that a new subfolder would contradict.

**Do not copy `total_veg_annual_mean_8058.tif`.** It is 581 MB, it is already on the Drive link Adrian
has, and copying it inside the same tree duplicates it on disk for nothing. **List it in the README
as already shared, with its checksum**, so the folder is still a complete account of what he has.

**Report the folder's total size** before and after — the same reasoning may apply to another file.

### 0.2 · The year-span question — check this before anything ships

The plot-locator map's subtitle reads **"100 × wet-valid years ÷ valid years, 1988–2023"**. The
analysis convention is **WY1988–WY2022, 35 water years**.

**If `background_flood_frequency_8058.tif` spans 36 years and every registered number spans 35, that
is an inconsistency between a published map and the whole analysis**, and Adrian is the person most
likely to find it. Report the band count, the year span the producer used, and whether it matches
the 35-year convention. **Do not fix it. Report it.**

---

## 1 · What to copy

**Adrian may mean the derived surface or the original source stack — send both rather than guessing.**

| file | why |
|---|---|
| `background_flood_frequency_8058.tif` | **what he asked for** — the single-band per-cell surface behind the map |
| `inundation_annual_stack/` — **native EPSG:28355** | **the source, before any reprojection.** If "the flood freq data" means the original, this is it |
| `inundation_annual_stack_8058/` | the same stack on the census grid, which is what the analysis reads |
| `veg_percentiles_8058/` — the whole folder | the temporal cover percentiles. His metric, at 25 m, mappable, built 19 July |
| `flood_zone_8058.tif` | the wetness banding the community classes rest on |
| `veg_regime_class_8058.tif` | the community × wetness classes; the footprint everything is masked to |
| `annual_wet_any_1988_2023_8058.tif` | already sent by Drive link — include so the folder is coherent |
| `annual_valid_any_1988_2023_8058.tif` | as above |

**Enumerate every folder before copying and report what is in it** — `veg_percentiles_8058/` and both
inundation stacks are unknown at the design seat. If a folder holds intermediates as well as
products, copy only the products and say which is which.

**Report the provenance of the inundation source.** The record names Kingsford as co-author on the
inundation-mapping methodology. **If the source stack originates with UNSW, Adrian may already hold
it**, and that changes what is worth sending — state where it came from rather than assuming.

---

## 1B · The code that builds these layers

**Adrian will try to reproduce this.** That is the best possible outcome and the bundle should make
it easy rather than merely possible.

### 1B.1 · Copy the producers into a `code/` subfolder

Named where known; **identify the rest from the metadata records' chunk lineage** rather than
guessing:

| chain | script |
|---|---|
| annual cover stack, chunks 1–2 | `scripts/05_ground_cover/04_build_annual_total_veg_stack_8058.R` |
| temporal cover percentiles | `scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R` |
| extraction and within-year percentile | `scripts/12_zone_stratum/T2_gateB_extract.R` |
| inundation chain | **identify from the inundation record's chunks 2–4** — the two-step nearest-neighbour resample |
| `background_flood_frequency_8058.tif` | **identify its producer and report the path** |
| constants | `gayini_params.R` |

**Three checks before any code ships.** No credentials, tokens, or absolute paths beyond the repo
root. **No DEA CTV reference** — the ground-cover record states it must never appear in a
deliverable. No AI attribution anywhere.

**Say plainly in the README that the scripts will not run outside our tree.** They read the project
database and helper functions. They are there to be read, not executed, and pretending otherwise
wastes his afternoon.

### 1B.2 · The rebuild recipe — worth more than the code

**He will be in QGIS, not R.** `code/REBUILD.md`, one short section per layer, in plain terms:

**Flood frequency.** Sum the wet stack across bands, sum the valid stack across bands, divide,
multiply by 100 — **state the raster-calculator expression explicitly.** Note that the valid layer
holds 1 and 255 with no zeros, so inside the census footprint the denominator is simply the band
count, and outside it is not.

**Annual cover.** Average the usable seasons of each water year — **no minimum-season threshold**, a
year survives on one season of four — then reproject to EPSG:8058 **bilinear**, because cover is a
continuous surface.

**Temporal cover percentiles.** Per cell, the percentile across the record, `MIN_SEASONS = 50`.
**State that this rule also excludes permanent water** — otherwise he rebuilds it without that and
gets a different surface in exactly the wet country he is mapping.

**Inundation to the census grid.** **Nearest neighbour, and it is resampled twice.** Bilinear on a
binary mask would invent half-wet cells.

**The footprint.** `treed_context_flag = 0 AND regime_band <> 'context'`, with the 11-class legend.
Give the resulting count — **988,831 non-treed cells, 61,655.0 ha** — so he can check his mask against
ours with a single number.

Every recipe names the one parameter that would silently change the answer if he chose differently.

---

## 2 · Verification

For every file, both sides: **size in bytes, `sha256_first50()`, band count, CRS, cell size, extent.**
Copy is verified by checksum, not by the copy command returning success.

`Output/rasters/DATA_share_20260808/DATA1_manifest.csv` — filename, source path, bytes, checksum, bands, CRS,
year span, and one line on what the file is.

**Report any file whose CRS is not EPSG:8058** — everything in this folder should be on the canonical
grid, and one that isn't needs explaining rather than shipping quietly.

---

## 3 · The README — four things, and they are the point

`Output/rasters/DATA_share_20260808/README.md`. Adrian will open these in QGIS without reading a metadata
record first.

**Band-to-year mapping.** 35 bands, WY1988 to WY2022. **State whether the bands are named internally
in the TIF** — if they are not, an off-by-one is silent and this README is the only defence.

**The class lookup for `veg_regime_class_8058.tif`.** 11 classes, and the non-treed selection is
`treed_context_flag = 0 AND regime_band <> 'context'`. Without the legend the footprint cannot be
reproduced, and the footprint is what every number rests on. **Also report the raster's
`legend_status`** — 16 of the 45 registered 8058 rasters are unconfirmed and cover arithmetic on an
unconfirmed raster is gated.

**What `annual_valid_any` is.** It holds only 1 and 255 — no zeros anywhere — so within the census
footprint every cell is valid in every year and the denominator never bites. **Opened cold it looks
broken.** One line: it is a safeguard, not a filter, and the inundation record explains it.

**What the temporal percentiles are, and what they are not.** Computed across the **140 seasonal
composites**, not the 35 annual means, with `MIN_SEASONS = 50`. **So they are not the same series the
regression uses** — TEMPORAL-1 is building the annual-basis version to match. And `MIN_SEASONS = 50`
does two jobs: it makes p05 a true percentile **and excludes permanent water**, which matters to
anyone mapping the wetter country.

**Also state the extent caveat on `background_flood_frequency_8058.tif`:** it covers the full raster
window, not just the census footprint, and outside the property the denominator does vary. Values
beyond the boundary are indicative.

---

## 4 · One comparison, if TEMPORAL-1 has produced it

Once TEMPORAL-1's Gate 2 output exists, report the correlation between the **existing seasonal-basis
`total_veg_p05_8058`** and the **new annual-basis temporal p05**, at cell level on a sample and at
part level on all 115.

**If they are close**, the July rasters can go to Adrian as they stand and the new build is simply
the matched-series version. **If they diverge**, that matters beyond this task — the existing rasters
are already in shipped figures.

---

## 5 · Report

Total folder size. Every file with its checksum and band count. The year-span answer from §0.2. What
`veg_percentiles_8058/` contained and what was excluded. The folder's total size, and whether any
file was omitted as a duplicate of something Adrian already has.

**Nothing registered. Nothing moved. Nothing deleted.**
