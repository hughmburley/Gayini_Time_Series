# T1 — Zone × stratum census join

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** **v3 · 25 July 2026** — supersedes v2 and v1 (same date). Overwrite in place.
**Depends on:** nothing (first build)
**Blocks:** T2 (zone dimension), S5 of the spine
**Gate 0:** **COMPLETE.** Inventory at `docs/change_reports/T1_gate0_inventory.md`. Do not re-run it.

---

## Amendment log

### v2 → v3 — corrections from the Gate 0 repo inventory, 25 July 2026

Gate 0 found that **v2's amendment F8 inspected the wrong layer.** Recorded here rather than silently fixed, so a later session sees the correction instead of re-finding it.

| # | Severity | What v2 got wrong | Where fixed |
|---|---|---|---|
| **C1** | HIGH | v2 stated that `Area_MW` and `ManagmentZ` do not exist, and renamed `area_ha_source → area_ha_computed` on that basis. **They do exist** — in `management_zones_epsg8058.gpkg`, which is the actual T1 input. v2 inspected `Gayini_Results.gpkg:management_zones` (the EPSG:28355 map companion) because the 8058 layer was not available to the design seat, then generalised beyond that evidence. The 8058 layer carries `fid, OBJECTID_1, OBJECTID_2, ManagmentZ, Area_MW, Treatment, Plots` — **capitalised ESRI names**. `ManagmentZ` holds real paddock names; `Area_MW` spans 99.49–2,712.56 ha. | Context, Gate B |
| **C2** | MED | v2 made NUL-stripping mandatory. NUL padding is a `Gayini_Results.gpkg` artefact; on the 8058 layer `Treatment` compares equal to `'No grazing'` directly. | Gate A, Gate B — demoted to defensive |
| **C3** | MED | v2 assumed the `dim_spatial_unit` link would probably have to be deferred. Gate 0 found MODIS `area_ha` for `zone_1` (2,062.5) matches gpkg `fid = 1` `Area_MW` (2,064.2) to 0.08% — the link is likely **provable**. But a naive 64-way area match can pass on a permuted mapping if areas cluster, so the test now carries a **margin** requirement. | Gate A step 5 |
| **C4** | LOW | v2 presented the 12,179 ha unzoned expectation without noting that the supporting arithmetic assumes zones ⊆ mapped area, which is untested. | Gate C |
| **C5** | MED | v2's figure requirement — "registered in `figure_asset` with level and support" — **is not satisfiable against the current schema.** `figure_asset` has no `level` and no `support_level` column. It has 255 rows (not 139; that figure was stale), all `path_exists = 1`, and the pre-July generation already carries `superseded_flag = 1`. | New **Gate B1** |
| **C6** | — | v2 did not say which language owns figure registration. Gate 0 identified the root cause of the unregistered backlog: figures are written in R and registered later in Python, so the two steps can land in different sessions. | Gate figures |

### v1 → v2 — corrections from the Gate A pre-flight against the live DB

| # | Severity | What v1 got wrong | Where fixed |
|---|---|---|---|
| **F5** | HIGH | v1 asserted a clean three-way `fid` alignment as **already verified**. It is not verifiable from the DB. `dim_spatial_unit`'s zones arrived via `Output/csv/MODIS/modis_context_units_summary.csv`; `source_feature_id` is the string `"management_zone_1"`; `source_crs` is NULL. | Context, Gate A |
| **F6** | HIGH | Gate A said resolve the zone layer from `spatial_layer_asset`; Gate C said STOP if not 8058. The registry holds it at **EPSG:28355** with an **absolute Windows path** into `shapefiles.zip`. Mutually unsatisfiable. | Gate A0 |
| **F7** | MED | CRS/extent verification was to come from `raster_asset`. `crs_epsg` is populated; the **extent columns are not**. | Gate A |
| **F8** | MED | *Superseded by C1 above — F8 was itself wrong.* | — |

**Git relaxed from v2 onward:** direct commits to `main`, no branch, no PR. Additive-only and no-builder-run are **not** relaxed.

---

## Spine anchor

| | |
|---|---|
| **Serves** | Spine §2 — **S4** (floor relationship replicates at paddock scale) and **S5** (distance-to-reference) |
| **Claim under test** | The grazed/ungrazed floor difference survives matching within census stratum — i.e. it is not a wetness artefact |
| **Why we are doing this** | The naive whole-farm comparison gives ungrazed p05 = 62.7 vs grazed 59.0 (+3.7), but ungrazed ground is 6.3 pp wetter. Unmatched, the number is uninterpretable. This task turns the eleven census strata from a *descriptive* product into the *control structure* of the design. |
| **What would falsify it** | If matched contrasts collapse to ~0 in every stratum, or if the sign is inconsistent within a community across its three wetness bands, the treatment signal is not separable from position and S5 must be reported as null. **That is an acceptable outcome and must be reported as readily as a positive one.** |
| **Spine return** | Replaces the *preliminary* grazed/ungrazed table in spine §4 with a pipeline-computed version, or reports no change. |

---

## Reuse — found by Gate 0, do not rewrite these

Roughly 60–75% of T1 already exists on `main`. Adapt these; do not reimplement.

| Need | Existing implementation | Status |
|---|---|---|
| Point-in-polygon | `scripts/03_inundation_products/10_build_veg_regime_checkerboard.R:198-200` — `st_intersects(pc, management)` | Directly adaptable: swap 66 plot centroids for 1.08M census points |
| `census_stratum` reconciliation | `scripts/03_inundation_products/09_build_pixel_census_view.R:224-306` — full recon accounting with computed pixel area | Callable pattern |
| SHA-256 first-50-MB + additive registration | `scripts/11_database/register_taskM_gateC_assets.py` | **Gold-standard template.** Check/execute modes, idempotent, dry-run CSV. Copy its structure |
| Parquet read | `scripts/11_database/taskM_gateD_p05_distribution.py:57` (DuckDB); `arrow` already a dependency | Either route fine |

**Genuinely new: ~4–6 small scripts, plus one integration piece** — `write_and_register_figure()`, which no existing path provides. See Gate figures.

---

## Context

An in-chat feasibility join (25 Jul 2026) established that stratum-matched overlap exists in **all nine non-treed strata**, thinnest cell 2,223 px (Riverine-high ungrazed). Riverine Chenopod showed +7.5 to +8.3 pp across all three bands at matched wetness; Inland Floodplain ~0 in low and mid.

That computation is **not a result**. It was run outside the pipeline, on an uploaded copy, with no registration and no reproducibility. T1 makes it real.

### The input layer — `management_zones_epsg8058.gpkg`

This is the T1 input, registered by Gate A0. Verified by Gate 0:

- CRS is genuinely **EPSG:8058**. No reprojection needed.
- 64 features.
- Fields: `fid, OBJECTID_1, OBJECTID_2, ManagmentZ, Area_MW, Treatment, Plots` — **capitalised ESRI names.**
- `ManagmentZ` holds the real paddock name (`Bala 26ca`, `Bala 1`, …).
- `Area_MW` spans **99.49–2,712.56 ha**, matching the expected zone-size range.
- `Treatment` ∈ {`14-day grazing` (60), `No grazing` (4)}, **no NUL padding** — it compares equal to `'No grazing'` directly.

**Do not read lowercase `management_zone` / `treatment` / `plots` from this layer.** Those are the field names in the *other* gpkg, and the read will fail or return NULL.

### The map companion — `Gayini_Results.gpkg:management_zones`

Different layer: EPSG:28355, lowercase field names, **NUL-padded** text. Not the T1 input. Referenced only if a cross-check needs it, in which case strip `\x00` first.

### What is still open about zone identity

`dim_spatial_unit`'s 64 management-zone rows came in through the **MODIS context lineage**:

- `unit_id` = `management_zone_1` … `management_zone_64`
- `unit_name` = the bare index `"1"` … `"64"` — **not** the paddock name. Any figure labelled off `unit_name` today is unreadable. T1 fixes this.
- `source_layer` = `Output/csv/MODIS/modis_context_units_summary.csv`
- `source_feature_id` = the string `"management_zone_1"`, not an integer `fid`
- `source_crs` = **NULL**
- The MODIS `source_name` is only the integer index, so **name-matching is unavailable.** Area is the only usable evidence.

Gate 0 found one encouraging data point: MODIS `area_ha` for `zone_1` is 2,062.5 against `Area_MW` 2,064.2 for `fid = 1` — 0.08%. That is one zone. Gate A step 5 tests all 64 with a margin requirement, because a 64-way area match can pass on a permuted mapping if areas cluster.

---

## Gates

### Gate A0 — Register the 8058 zone layer (additive, prerequisite) · **STOP**

`spatial_layer_asset` holds five rows. The zone layer is registered as `layer_name = management_zones`, `source_crs = target_crs = EPSG:28355`, `path = D:\Github_repos\Gayini\Input\shapefiles.zip`. Wrong CRS, absolute path, zip archive. `management_zones_epsg8058.gpkg` is registered nowhere.

1. Read the 8058 gpkg's CRS from its header. Gate 0 confirms EPSG:8058. **If it is not, STOP and report — do not reproject.**
2. Add one row to `spatial_layer_asset`: relative path, `layer_name = management_zones_8058`, `source_crs = target_crs = EPSG:8058`, `feature_count = 64`, SHA-256 (first-50-MB convention), `path_exists`, `import_status`.
3. Leave the 28355 row untouched.

Every later gate resolves the zone layer from this new row.

**STOP.** Report the registered row.

### Gate A — Recon (read-only) · **STOP**

1. **Paths from the DB.** `census_asset.path` for the parquet; the Gate A0 row for the zone layer. Report any `path_exists = 0`.
2. **Census parquet.** 1,080,157 rows, 16 contract columns, checksum matches. Gate 0 confirms the checksum — re-verify, do not rebuild.
3. **Geometry verification — read headers, not the registry.** `raster_asset.crs_epsg` is populated but the extent columns are empty. Verify CRS, resolution (≈ 24.970268 m) and extent with `terra::crs()`, `terra::res()`, `terra::ext()`, and `compareGeom()` against `veg_regime_class_8058.tif` per the data contract §8. **Backfill `raster_asset` `xmin/ymin/xmax/ymax` additively for the 8058 products** — a free fix to a release-check failure.
4. **Zone layer.** 64 features, EPSG:8058, `Treatment` ∈ {`14-day grazing` (60), `No grazing` (4)}. Apply a defensive `\x00` strip on read — a no-op here, but harmless, and it protects any path that touches the companion layer.
5. **Zone identity — the margin test. This is the gate's most important step.**

   Compute `area_ha_computed` from the 8058 geometry for all 64 zones. Then, for each MODIS zone *i* in `modis_context_units_summary.csv`, report:

   - the area ratio error against its assumed partner `fid = i`;
   - the area ratio error against **every other** `fid`;
   - the **margin** — error to the assumed partner versus error to the nearest *other* zone.

   The link is proved for zone *i* only where the assumed partner is the **unique nearest match by a clear margin**. Report the margin distribution and name every zone whose second-nearest competitor sits within 2%.

   **Verification is per-zone, not all-or-nothing.** Zones that pass get `unit_id` populated and `unit_id_verified = 1`. Zones that do not get `unit_id = NULL` and `unit_id_verified = 0`, and are named in the recon note.

   Run the comparison against **`area_ha_computed`**, not `Area_MW`. Matching two inherited attributes to each other proves less than matching one of them to geometry.

6. **Area fields.** Report `Area_MW` and `area_ha_computed` side by side for all 64 with the percentage difference. A systematic offset indicates `Area_MW` was computed in a different projection — report it, do not correct it.
7. **Land-use fields.** Confirm no field matching `crop|land_use|landuse|history|irrig|former` exists in any table or view. **Expected zero; recorded as evidence, not as a defect to fix.**

**STOP.**

### Gate B — Build `dim_management_zone` (additive)

**Additive `INSERT OR REPLACE` keyed on `zone_fid`. Never invoke the builder's `reset_file` path.**

```
dim_management_zone
  zone_fid            INTEGER PRIMARY KEY   -- 1..64, from gpkg fid
  zone_name           TEXT NOT NULL         -- from ManagmentZ, e.g. 'Bala 26ca'
  zone_group          TEXT                  -- 'Bala' | 'Dinan' | 'Mara', parsed from zone_name
  area_ha_source      REAL                  -- Area_MW as supplied. ESRI-computed; projection unknown.
  area_ha_computed    REAL                  -- from 8058 geometry. Known provenance.
  area_ha_diff_pct    REAL                  -- 100*(computed-source)/source
  grazing_treatment   TEXT NOT NULL         -- from Treatment
  grazing_excluded    INTEGER NOT NULL      -- 1 if 'No grazing'
  has_rap_plots       INTEGER               -- from Plots; 1 if 'Sample'
  unit_id             TEXT                  -- FK to dim_spatial_unit, NULL where unproved
  unit_id_verified    INTEGER NOT NULL      -- 1 if proved by the Gate A margin test, else 0
  unit_id_margin_pct  REAL                  -- the margin that proved it, for audit
  -- RESERVED for Ernest's land-use table; created empty, deliberately:
  cropping_history    TEXT                  -- NULL
  land_use_era        TEXT                  -- NULL
  irrigation_status   TEXT                  -- NULL
  history_source      TEXT                  -- NULL
  history_confidence  TEXT                  -- NULL
```

Three points that have already caused one wrong spec:

- **Read the capitalised ESRI field names** — `ManagmentZ`, `Area_MW`, `Treatment`, `Plots`. Lowercase names belong to the other gpkg.
- **Both area columns are kept.** `Area_MW` is inherited and its projection is unstated; `area_ha_computed` has known provenance. `area_ha_diff_pct` surfaces any disagreement as a column rather than as a silently wrong area.
- **`unit_id_verified` and `unit_id_margin_pct` are the audit trail** for a link that was asserted as verified in v1 and turned out not to be.

The five `RESERVED` columns are created **now and left NULL on purpose**, so Ernest's land-use table becomes a data problem later rather than a schema migration.

### Gate B1 — Extend `figure_asset` (additive) · new

The current schema cannot record support level, so the figure requirement below is unsatisfiable without this step.

Current columns: `figure_asset_id, path, title, domain, metric_id, recommended_use, checksum_sha256, path_exists, qa_status, run_id, superseded_flag, framing_label, provenance_note, caption`. 255 rows, all `path_exists = 1`; the pre-July generation already carries `superseded_flag = 1`.

Add two columns, additively:

```sql
ALTER TABLE figure_asset ADD COLUMN support_level TEXT;  -- spine §9 rule 2: support is data, not a comment
ALTER TABLE figure_asset ADD COLUMN figure_level  TEXT;  -- 'site'|'paddock'|'stratum'|'ladder'|'diagnostics'
```

Populate both on every row T1 writes, and populate the existing `caption` field, which is currently NULL on all 255.

**Record this in the post-build chain.** A full rebuild would drop both columns; the project already carries post-build mutations for exactly this reason. **Do not backfill the existing 255** — out of scope, one concern per task.

### Gate C — Point-in-polygon join and `v_census_by_zone_stratum`

Assign every census pixel to a zone by point-in-polygon on `(x_8058, y_8058)` against the Gate A0 layer. Both inputs 8058 — **no reprojection**. If either is not 8058, stop and report.

Adapt `10_build_veg_regime_checkerboard.R:198-200`. Do not write a new join.

Pixels outside every zone are retained with `zone_fid = NULL` and surfaced as an explicit `unzoned` class. **Silently dropping them is the failure mode this instruction exists to prevent.**

**On the expected unzoned figure.** An in-chat estimate gives 194,865 px / 12,179 ha / 18% of mapped. Gate 0 offered corroboration — zone area totals 55,348 ha against 67,349 ha mapped, implying ~12,001 ha — but **that arithmetic assumes zones ⊆ mapped area, which is untested**; zones likely include treed and unmapped ground. Treat both figures as comparisons, not targets. **Report your own number and flag a material difference rather than forcing agreement.**

Persist the assignment as `Output/census/gayini_pixel_zone_assignment.parquet` (`pixel_id`, `zone_fid` only), registered in `census_asset` with SHA-256 (first-50-MB convention). Do not widen the primary census parquet.

```
v_census_by_zone_stratum
  zone_fid, zone_name, grazing_treatment, grazing_excluded,
  community, regime_band, treed_context_flag,
  n_pixels, area_ha,
  flood_freq_mean, flood_freq_median, flood_freq_p10, flood_freq_p90,
  veg_p05_mean, veg_p05_median, veg_p10_mean, veg_p50_mean,
  support_level        -- literal 'pixel_within_zone_stratum', per spine §9 rule 2
```

Rows with `zone_fid IS NULL` appear as `zone_name = 'unzoned'`.

**Area constant: `0.062351428` ha/px** (24.970268 m grid). **Not 0.0625** — the 25 m nominal inflates every area by 0.238% and has already contaminated one spec.

### Gate D — Matched contrast table · **STOP**

Build `v_zone_stratum_treatment_contrast`: one row per (community, regime_band) with ungrazed-minus-grazed differences in `veg_p05_mean` and `flood_freq_mean`, pixel counts on both sides, and a `min_cell_n` flag where either side < 3,000 px.

Restrict to the **nine non-treed strata**: `treed_context_flag = 0 AND regime_band <> 'context'`. The flag alone admits ten — it lets `Other / minor units` in (4,951 px, 308.7 ha).

Include `flood_freq_delta` **next to** `veg_p05_delta` in the same row. The whole point of the design is that a reader sees immediately whether the wetness confound is doing the work; splitting those columns across tables would defeat the task.

**STOP.** Report the contrast table before writing the change report.

---

## Gate figures — mandatory

**A gate does not close until its figure exists and is registered in `figure_asset` in the same transaction that writes it.**

Gate 0 identified why ~330 figures went unregistered: figures are written in R and registered later in Python, so the two steps can land in different sessions. **The fix is that R owns both halves.** Build one function:

```r
write_and_register_figure(plot, path, title, caption,
                          support_level, figure_level, run_id)
  # ggsave -> SHA-256 -> RSQLite INSERT OR REPLACE into figure_asset
  # one call, one transaction, no Python step
```

`register_taskM_gateC_assets.py` remains the template for rasters and parquet. Figures move to R.

Output to `figures/diagnostics/` with the `T1_` prefix. **Every caption states the support level.**

| Gate | Figure | What it must show | Passes if |
|---|---|---|---|
| A0 | `T1_A0_zone_layer_extent.png` | 8058 zone layer over the census grid extent, both outlines drawn | Extents coincide; no offset |
| A | `T1_A_zone_map_named.png` | All 64 zones filled by `Treatment`, **labelled with `ManagmentZ` paddock names** | Names legible and are paddock names, not indices |
| A | `T1_A_identity_margin.png` | Per zone: area error to assumed partner vs to nearest other zone; 2% margin line drawn | Every zone either clears the margin or is visibly named as unproved |
| B | `T1_B_area_source_vs_computed.png` | `Area_MW` against `area_ha_computed`, 1:1 line, `area_ha_diff_pct` annotated | Points on the 1:1 line; any systematic offset is obvious |
| C | `T1_C_pixel_assignment_map.png` | Every census pixel coloured by `zone_fid`, **`unzoned` in a distinct hard-to-miss colour** | The unzoned area is spatially coherent, not scattered noise |
| C | `T1_C_reconciliation_bar.png` | Stacked bar: zoned + unzoned vs 1,080,157, diff annotated | Diff = 0 |
| D | `T1_D_matched_contrast.png` | One panel per community; paired bars of `veg_p05_delta` and `flood_freq_delta` per band; cells under 3,000 px greyed and labelled | The wetness confound is visible beside every floor difference |

`T1_C_pixel_assignment_map.png` earns its place: an 18% unzoned share looks identical in a table whether it is a real geometry gap or a join bug, and completely different on a map.

---

## Acceptance criteria

- [ ] `spatial_layer_asset` has a new 8058 zone row; the 28355 row untouched.
- [ ] `figure_asset` has `support_level` and `figure_level`; the post-build chain records the mutation.
- [ ] `dim_management_zone` = 64 rows; every `zone_name` a real paddock name from `ManagmentZ`; both area columns populated with `area_ha_diff_pct`; five history columns present and NULL.
- [ ] `unit_id_verified` and `unit_id_margin_pct` populated on every row; unproved zones named in the change report.
- [ ] Pixel assignment reconciles: `Σ zoned + unzoned = 1,080,157`, diff = 0.
- [ ] `v_census_by_zone_stratum` area sums to `census_stratum` per stratum, diff < 0.1 ha, **using 0.062351428 ha/px**.
- [ ] `unzoned` class present with non-zero area; the observed figure reported against both prior estimates.
- [ ] `support_level` populated on every view row.
- [ ] Contrast table restricted to the nine non-treed strata; `Other / minor units` absent.
- [ ] Registration re-run twice: identical row counts and checksums.
- [ ] **All seven gate figures written and registered via `write_and_register_figure()`**, each with `support_level`, `figure_level` and a caption.
- [ ] No existing table or view modified or dropped. *(`ALTER TABLE ADD COLUMN` on `figure_asset` is additive and is the one sanctioned exception.)*
- [ ] `docs/change_reports/T1_change_report.md` written and committed.
- [ ] `CLAUDE.md` updated so its change-report rule no longer contradicts this spec.

## Standing rules

**Kept — these prevent data loss:**

- **Additive only.** No deletes; moves to `_archive/` only.
- **Never re-run the builder.** `reset_file` rebuilds from scratch and would destroy 12 Task H census rows it cannot reproduce.
- **Idempotence.** Every registration step survives a second run.
- **Paths from the DB**, never hardcoded.
- **Four-CRS discipline:** 8058 canonical · 28355 inundation · 3577 FC source · 9473 plot centroids.
- **Never rebase** mapped area (67,349.332 ha) against true farm area (85,910.8 ha). Report both.
- **Verify against data, not prose — including this spec.** v1 and v2 each carried a confident claim that the repo contradicted. If a stated number disagrees with the table, the table wins and you report it.
- **Respect the STOP points.**

**Relaxed — 2.5 weeks to deadline, single operator, no external reviewers:**

- **No branch, no PR.** Commit directly to `main`. Review happens at the STOP points.
- **No AI attribution in commits.**
- **Change reports stay.** One short markdown file per task in `docs/change_reports/`, committed — they are the cross-session memory that replaces a database too large to carry. What changed, what the numbers were, what is still open.
