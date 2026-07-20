# Gayini — Output folder structure

*Contract and migration plan. Design seat, 17 July 2026. Current state measured from `Output/diagnostics/gayini_output_census_20260717.csv` joined against `Gayini_Results.sqlite` — **not estimated**.*

**This doc has two jobs: it is the target the restructure builds to, AND the standing rule for where new outputs go.**

---

## 1. The scene — why now

Three workstreams are live, and all three write to `Output/`:

| Workstream | State | Writes |
|---|---|---|
| **All-pixel census** (Task H) | **Complete.** Track A + Track B done, reconciled. | NN 8058 stack · 5 veg percentile rasters · flood-zone raster · the census parquet · H2/H6 diagnostics |
| **Slide deck** (Task I → J) | Stocktake done — **36 slides**, 4 DEAD, 7 RESTATE, 4 FRAME. Rebuild pending Adrian's ratification of 9/0/0. | the F1–F7 ladder · C1/D1/D2/D3 dashboards |
| **Pre/post bank cuts** (separate chat) | Starting. Adrian's 15 Jul email; 1,158 cut points, May + Sep 2018. | difference rasters · per-paddock figures · tables |

**And the actual driver:** **Deliverable 2 — "reports for all sites" — is at 5 of 66.** The deck claims *"all 66 sites in the folder."* Nothing catches that gap, because **nothing tracks those figures at all** (§2). A folder structure where `ls figures/site | wc -l` answers "how many are done" is the cheapest fix available.

## 2. Current state — measured

```
1,326 files · 1.57 GB

tracked (registered + on disk)   279
orphan  (on disk, unregistered) ~1,040     <- 79%
BROKEN POINTERS                     0      <- path_exists = TRUE is honest
```

**Zero broken pointers.** All 279 registered assets are where the DB says. That is the good news and it constrains the migration (§5).

### 🔴 The registry tracks the wrong generation

| | Where | Registered |
|---|---|---|
| **Old** — MODIS / MER / gauge / RS_coverage | `figures/maps/`, `figures/plots/`, `figures/review/` | **all 139** |
| **Current ladder** — F1–F7, C1×21, D1, D2, D3, H2, H6 | `figures/` **root** | **0 of 330** |

```
CURRENT LADDER                    files   registered
  F1 F2 F3 F4 F5 F5c F6 F7          108        0
  C1  (paddock checkerboard)         88        0
  D1 D2 D3  (dashboards)            126        0
  H2 H6  (Task H)                     8        0
                                    330        0
```

**Every figure in the deck is untracked. Every figure the registry knows is superseded.** That is why the current ladder landed flat at `figures/` root — the new work stopped using the old structure and nothing enforced anything.

### Completeness — what is actually built

| Product | Built | Target | Deck claims |
|---|---:|---:|---|
| C1 paddock checkerboard | **21** | 21 | "all 21" ✅ |
| D1 paddock dashboard | **4** | 21 | "all 21" ❌ |
| F5c paddock flood-frequency | **4** | 21 | (slides 14–17) |
| **D2 site dashboard** | **5** | **66** | **"all 66"** ❌ |
| D3 stratum dashboard | **3** | 9 | "all nine" ❌ |

### Where the weight is

```
Output/rasters/fc_intermediate          6 files   0.759 GB   <- 48% of everything
Output/rasters/inundation_background  142 files   0.077 GB   <- 3 retired pre/post scenarios
duplicate filenames                   382 files   102 MB     <- review_bundles copy figures
```

`fc_intermediate` is the 140-layer total-veg cube and friends — **regenerable from `Input/` in minutes.** The duplication is **by design** (a bundle must be self-contained when zipped), but **seven Tier-1 bundles** still hold copies of superseded figures.

## 3. The target

**Level is the organising axis, because level is what has a target and therefore a completeness.** Type (`maps/` vs `plots/`) tells you nothing about what's done. The prefixes already encode level — they just never became folders.

```
Output/
  rasters/
    inundation/       annual_{wet,valid}_any_1988_2023 (28355) · _8058 (NN)
    veg/              total_veg_p{05,10,20,30,50}_8058
    zones/            flood_zone_8058
    intermediate/     fc_intermediate — REGENERABLE. gitignored. safe to delete.
  figures/
    ladder/           F1-F7        the analytical ladder (concept + data pairs)
    site/             D2_*                    target 66
    paddock/          C1_*, D1_*, F5c_*       target 21
    stratum/          D3_*                    target 9
    diagnostics/      H2_*, H6_*, gate figs   ephemeral
  tables/             small results CSVs (committed per convention)
  census/             gayini_pixel_census_8058.parquet
  database/           Gayini_Results.sqlite · .gpkg
  spatial_8058/       gayini_vectors_8058.gpkg
  diagnostics/        QA jsons + per-task diagnostic tables
  review_bundles/     CURRENT bundles only
  logs/
  _archive/           <- the convention already exists; keep it
    figures_modis_mer/       the 139 registered old generation  ** move + re-register **
    rasters_pre_post/        inundation_background · inundation_pre_post
    review_bundles_tier1/    the 7 superseded Tier-1 bundles
    reports/                 (already present)
```

**`ls figures/site | wc -l` → 5 against a target of 66 is the progress bar.** That is the whole point.

## 4. The standing rule — where new things go

| Output | Goes to | Prefix |
|---|---|---|
| A figure about **one site** | `figures/site/` | `D2_` |
| A figure about **one paddock** | `figures/paddock/` | `C1_` / `D1_` / `F5c_` |
| A figure about **one stratum** | `figures/stratum/` | `D3_` |
| A **whole-farm / conceptual** ladder figure | `figures/ladder/` | `F1_`–`F7_` |
| A **QA / gate** figure | `figures/diagnostics/` | task tag (`H2_`, `H6_`, …) |
| A raster product | `rasters/<domain>/` | — |
| A **regenerable** intermediate | `rasters/intermediate/` | — |
| A small results table | `tables/` | — |
| A QA json or diagnostic table | `diagnostics/` | — |
| Anything **superseded** | `_archive/<what>/` | — |

**Three rules:**

1. **Every figure that ships gets registered in `figure_asset`** — with a **level** and, where one exists, a **target count**. Then *"all 66 in the folder"* is caught by a release check, not by a stocktake three months later.
2. **`_archive/` is a move, never a delete.** Additive-only. The one exception is `rasters/intermediate/`, which is regenerable by definition.
3. **Nothing lands at `figures/` root.** That's how we got here.

**Pre/post cuts** inherit this: difference rasters → `rasters/`, per-paddock figures → `figures/paddock/` with a new prefix, tables → `tables/`. No new top-level folder.

## 5. Migration — the constraints that decide the order

### 🔴 The 139 old figures are registered. The 330 new ones are not.

That inverts the intuition:

- **Moving `figures/maps|plots|review` → `_archive/` breaks 139 relative paths.** `path_exists` is `TRUE` for all of them and it's honest. **Move and re-register in one transaction, or mark them superseded in place. Never move first and fix after.**
- **Moving the 330 ladder figures breaks nothing** — nothing knows they exist. That's the freedom, and it's also the bug being fixed.

### Order

1. **Census** — re-run the disk census against a **current** DB. *(The design seat's join used a post-Track-A snapshot: `raster_asset` = 102, pre-H2. ~7 orphans in §2 are false — the H2 percentile rasters and the parquet are registered now. The 330-figure finding is unaffected.)*
2. **`rasters/intermediate/`** — move `fc_intermediate` there and gitignore it. **Halves Output. No registry touched. Do this first; it's free.**
3. **Register the 330** in `figure_asset` with level + target. **Register before moving** — then the move is a path update on rows that exist, not a discovery exercise.
4. **Move the ladder** into `ladder/ site/ paddock/ stratum/ diagnostics/`, updating `figure_asset.path` in the same step.
5. **Archive the old generation** — move + re-register the 139.
6. **Archive** `inundation_background`, `inundation_pre_post`, the 7 Tier-1 bundles.
7. **Re-run the census and the checksum verify.** Zero broken pointers, before and after. **That's the acceptance test.**

### The verify that doesn't exist yet

`raster_asset` carries **100 SHA-256 checksums** and **nothing has ever verified them**. A restructure is exactly when you want that. Build it as a permanent release check, not a one-off:

```r
ra <- dbGetQuery(con, "SELECT raster_asset_id, path, checksum_sha256
                       FROM raster_asset WHERE checksum_sha256 IS NOT NULL") |>
  mutate(exists = file.exists(path),
         actual = ifelse(exists, vapply(path, digest, "", algo="sha256", file=TRUE), NA),
         ok     = !is.na(actual) & actual == checksum_sha256)
stopifnot(all(ra$exists), all(ra$ok))
```

## 6. Acceptance

1. **Broken pointers: 0 before and 0 after.** Non-negotiable.
2. **Checksum verify passes** — 100/100 rasters byte-identical.
3. **All 330 ladder figures registered** in `figure_asset` with a level; targets recorded where they exist (site 66, paddock 21, stratum 9).
4. **Nothing at `figures/` root.**
5. `_archive/` moves are **moves**. Nothing deleted except `rasters/intermediate/`, which is regenerable.
6. The 139 old figures **re-registered at their new paths** — not orphaned by the move.
7. Census re-run; the before/after diff **accounts for every file**.
8. `.gitignore` updated for `rasters/intermediate/`.
9. Branch-and-PR, **held**.

## 7. Out of scope

- **Building the missing dashboards** (site 5→66, paddock 4→21, stratum 3→9). That's Deliverable 2 and it's gated. **This task makes the gap visible; it does not close it.**
- **C11** — `map_asset_index` in the gpkg is stale (98 vs 102 rasters; 97 vs 38 reports). It is a denormalised copy of three live tables and **every registration here makes it wronger.** Either regenerate it in the post-build chain or drop it — but decide, don't leave it silently wrong.
- **C12** — `spatial_layer_asset` holds 5 absolute `D:\...` paths, the only registry pinned to one machine.
- Editing the deck. That's Task J.
