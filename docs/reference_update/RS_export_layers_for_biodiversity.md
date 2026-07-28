# Task — export RS spatial layers for the Biodiversity / LOOC-B analysis

*Small, self-contained **export** task for the RS session (`D:\Github_repos\Gayini`). It does not
change any analysis, does not touch the census or the DB beyond reads, and produces no figures.
Do it when convenient between other work — nothing here is on the Aug 10 critical path.*

**Why:** the companion biodiversity repo needs three RS layers to (a) recolour its vegetation
context map to the four-community palette and (b) run the one comparison the circularity rule
permits — modelled habitat condition against **inundation** (never against ground cover, which
is Landsat-derived on both sides and therefore tautological). All three layers already exist in
this repo; this is packaging, not new analysis.

---

## Deliverables — write to `Output/exports_for_biodiversity/`

Create the folder if absent. `Output/` is gitignored, which is correct — **do not commit the
rasters.** Commit only the export script and the manifest (below).

### 1. Community classification raster — `rs_community_class.tif`
Per-pixel **four-community** classification, the canonical `simplified_vegetation_group`
(never the legacy 5-class `vegetation_adrian_group`):
`1 = Aeolian Chenopod · 2 = Riverine Chenopod · 3 = Inland Floodplain · 4 = Woodland/Forest (context)`,
plus a distinct code for Other/minor and a set nodata. This is the layer behind the `C1`
checkerboard's hue channel — export the **hue channel alone, unbanded**.
Write a `.csv` sidecar mapping code → label.

### 2. Flood-frequency raster — `rs_flood_frequency.tif`
**Continuous** between-year flood frequency (%, 0–100), the surface behind `H6` — i.e.
`100 × wet-valid-years ÷ valid-years`, 1988–2023, per pixel.
**Export it continuous, NOT pre-classified into bands.** The consuming side must apply class
breaks *after* aggregating to a coarser grid; classifying first and then aggregating would mix
class codes and is wrong.

### 3. Paddock boundaries — `rs_paddocks.gpkg`
Paddock polygons with the paddock name/ID field used in the dashboards.

**Carry the reference-state metadata as attributes** — the biodiversity condition analysis must
respect the 27 Jul reference-state finding (`Gayini_reference_state_finding.md`) and cannot do so
without these fields:
- `zone_group` (Bala / Mara / Dinan), `treatment` (No grazing / 14-day / …), `grazing_excluded`.
- `is_reference` — the four `No grazing` zones, **fids 1–4 = Bala 26ca / 27ca / 28ca / 29ca**.
- `is_bala_29ca` — flag the outlier explicitly. It holds 54% of reference plots, is the sole
  Aeolian reference (n=1), and drives every reference-state result; the biodiversity analysis
  must be able to report the reference set **with and without it**.
- `cropping_history` and the other RESERVED land-use columns from `dim_management_zone` **if
  Ernest's history has since populated them** (currently NULL). If still NULL, export the column
  anyway so the consumer sees the gap. This is the field that would settle whether Bala 29ca is a
  degraded-recovering paddock rather than a reference.
- **Run `st_make_valid()` first** on the 12 invalid zone polygons (fids 4, 24, 25, 26, 48, 51,
  52, 53, 55, 56, 58, 60 — Bala 29ca is among them) before export, per the paddock-report
  prerequisite.
- If the wetness-matched neighbour pairing table exists (`reference_fid, neighbour_fid,
  distance_m, adjacency_flag, ff_diff_pp, best_wetness_match_flag`), export it as a CSV sidecar —
  the biodiversity treatment comparison must pair on **wetness, not distance** (see the paddock
  prototype).

### 4. Bonus (only if trivial) — `rs_community_wetness_checkerboard.tif`
The pre-classified `C1` community × wetness raster, as a cross-check and for context mapping.
Include the code → (community, band) sidecar, and state in the manifest whether the bands are
**within-community relative terciles** or **absolute fixed breaks** — the consuming analysis
needs to know, and `S12` notes these are not interchangeable.

---

## Export rules

- **Native resolution and CRS. Do not reproject, resample, or resize.** Export exactly as the
  layers exist (expected EPSG:8058 at 24.97 m). The consuming side owns the regridding — see the
  aggregation note below. Reprojecting here would double-resample.
- **Set nodata explicitly** on every raster and state the value in the manifest. Do not rely on
  a default; unset nodata has bitten this project before.
- Deflate compression is fine; keep them single-band except where noted.

## Manifest — `Output/exports_for_biodiversity/manifest.csv` (commit this)
One row per exported file: `filename, what_it_is, crs, resolution_m, nodata, n_classes,
source_table_or_script, sha256_first50mb, exported_utc`.
Use the builder's first-50-MB SHA-256 hashing convention so the checksums are comparable with
the rest of the project's asset registry.

---

## Note for the consuming side (state it in the manifest header, don't act on it here)
LOOC-B is **EPSG:4326 at ~0.001° (~100 m)**; these layers are **EPSG:8058 at 24.97 m**. The
overlay must **aggregate the RS layers UP to the LOOC-B grid — never resample LOOC-B down to
25 m**, which would manufacture precision the modelled product does not have.

---

## Guardrails
Read-only on the census, the DB and all existing outputs. No changes to any analysis script,
no re-runs, no figure regeneration. Additive only: a new export folder, a new export script
(`scripts/` per the usual convention), and the manifest. Branch-and-PR as normal; leave commits
local for Hugh (TortoiseGit); no AI authorship attribution. Report the manifest contents and
stop.

---

## Amendment (23 Jul) — confirmed downstream use

The consuming figures are now specified (`Biodiversity_deck_GateM_and_figures_addendum.md`):
- **Layer 1** (community class) → the flat 4-hue context map **and** a condition-composition
  chart per community (main deck).
- **Layer 2** (continuous flood frequency) → a community × wetness condition matrix and a
  condition-vs-flood-frequency figure (appendix). The consuming side will derive **absolute**
  flood-frequency bands (fixed breaks, as in `H6`) **after** aggregating — which is exactly why
  this layer must stay continuous on export. Within-community terciles must not be used: they
  make "high" mean something different per community and destroy cross-community comparability.
- **Item 4** (pre-classified checkerboard) therefore remains genuinely **optional** — useful as a
  cross-check only.

**Grid template for the consuming side** (informational; do not regrid to it here):
`D:\Github_repos\Gayini_Biodiversity\OUTPUT\Gayini\rasters\monitoring\Gayini_monitoring_habitat_condition_allyears_2004_2020.tif`
— 604 x 307, EPSG:4326, res ~0.001 deg, nodata -9999. Worth confirming in recon that it is
readable from this machine, since the biodiversity session will align to it.

**Sequencing:** queued, not an interrupt. Finish whatever RS work is in flight first; nothing
here is on the Aug 10 critical path.
