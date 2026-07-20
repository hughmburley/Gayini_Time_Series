# Task H — on-disk audit + census-summary extraction + deck inventory

*Change report, 20 July 2026. Branch `tier2h-ondisk-audit` off `main` (`51aeaa3`). Held for human review — not merged. Phase 1 (Gates A–B) read-only; Phase 2 (Gate C) additive small CSVs only; Phase 3 (Gate D) read-only inventory. No DB writes, no census re-run, no raster regeneration, no fix to any D-defect.*

---

## Lead — what's wrong (for the human deciding next steps)

1. **D1 stands** — spec `Tier2_TaskH_all_pixel_census_v4.md` is **not on disk / not committed**; only v1–v3 exist. v1 carries no superseded banner; v2/v3 carry backward "*Supersedes vN*" headers but none is marked forward-superseded.
2. **D2 stands** — `census_stratum` still holds only `farm_area_ha = 67,349.332` (the *mapped* area) with **no** `mapped_area_ha` / `farm_area_total_ha`. `v_pixel_census_by_veg_regime.pct_of_farm` reads **×1.276 high** (Aeolian-low 2.4798% mapped vs 1.9440% true).
3. **D3 partially closed** — the refugia "~4,300 ha majority-green" table is **not reproducible from the parquet** (needs paired green-at-floor over the >50 MB FC cube). Committed the existing farm-level floor *distribution* instead (Option B). True closure is a scoped step in the next H2 build (see Gate C).
4. **Figure registration gap** — `figure_asset` = **139**, all superseded MODIS/MER/gauge generation; **0** of the ~330 current-ladder figures are registered.
5. **Spec/doc wording corrections** — (a) the builder checksum method is **whole-file ≤ 50 MB, NULL above** — *not* "first 50 MB"; (b) Gate C1's "community total-veg cover means" is a **mislabel** — 6.08/12.91/27.99 are **flood-frequency** pixel-support means, not veg cover.
6. **Everything the census depends on verified sound** — parquet checksum + row count MATCH, 11-strata reconciliation diff = 0, all 9 registered 8058 rasters clean, 32/32 release checks PASS.

---

## 1. Docs found (§0) and parquet size

Five of six §0 docs present. All are **untracked in git** (local-only per standing preference), so identity is content SHA-256, not a commit SHA. **`v4` absent → D1 confirmed on disk.**

| # | Doc | On disk | SHA-256 |
|---|---|---|---|
| 1 | `Gayini_project_goals_and_logic.md` | yes | `663a8140…830f11bc` |
| 2 | `Gayini_pixel_census_data_contract.md` | yes | `238e4376…045ee7e9` |
| 3 | `Tier2_TaskH_all_pixel_census_v4.md` | **NO (D1)** | — |
| 4 | `tier2H_gate1_VERIFIED_20260715.md` | yes | `236c34a4…47a9ef8d` |
| 5 | `Gayini_output_structure.md` | yes | `9e589c3f…006a2396` |
| 6 | `Gayini_established_data_facts.md` | yes | `b7fe48af…d232b69` |

**Parquet size: 26,724,747 bytes (25.49 MB) — under 50 MB**, so the checksum trap does not bite it (see §2).

## 2. Parquet — row count + checksum

Path resolved from `census_asset` (not hardcoded); exists; DB `path_exists = 1`.

| | measured | recorded | expected | ok |
|---|---|---|---|---|
| row count *(parquet metadata, not loaded)* | 1,080,157 | 1,080,157 | 1,080,157 | ✅ |
| checksum sha256 | `6b23f6c0803b69af12345b6818ae2cd453a67fc7ec694a880b3be3681246f966` | *(identical)* | — | ✅ |

**Checksum method — correction to the spec/VERIFIED-doc wording.** The builder's `sha256(path, max_bytes=50 MB)` (`scripts/11_database/01_build_results_database.py:195`) reads in 1 MB chunks and **returns `None` (NULL) once the file exceeds 50 MB; otherwise it hashes the whole file.** It is **not** "first 50 MB." Verified by calling the builder's own function. Consequences: the parquet (25.49 MB) and the ≤ 50 MB rasters carry **whole-file** digests (all matched); the `fc_intermediate` 381 MB / 353 MB files have **NULL** recorded checksums (out of scope), not truncated hashes.

## 3. 11-row reconciliation re-derived FROM the parquet

Grouped the parquet on `community × regime_band` (via R `arrow`) against `census_stratum`. **diff = 0 across all 11 strata; total 1,080,157.**

| community | band | parquet_n | stratum_n | diff |
|---|---|---:|---:|---:|
| Aeolian Chenopod Shrublands | low / mid / high | 26,786 / 23,720 / 27,038 | = | 0 |
| Riverine Chenopod Shrublands | low / mid / high | 65,781 / 64,326 / 63,551 | = | 0 |
| Inland Floodplain Shrublands / Swamps | low / mid / high | 238,328 / 239,666 / 239,635 | = | 0 |
| Floodplain Woodland / Forest | context | 86,375 | = | 0 |
| Other / minor units | context | 4,951 | = | 0 |
| **TOTAL** | | **1,080,157** | **1,080,157** | **0** |

**Reader note (not corruption):** pyarrow failed a column-projected read (`Repetition level histogram size mismatch`) — a known pyarrow incompatibility with parquet written using newer repetition-level-histogram metadata (R `arrow` wrote this file). Not a data defect: whole-file checksum matched, both readers agree on row count, and R `arrow` reads all 16 columns and reconciles cleanly. **Use `arrow`/`duckdb`, not this pyarrow build, for projected reads.**

## 4. Raster table — existence / crs / compareGeom / checksum / registered

Reference grid `veg_regime_class_8058`: 4037 × 2422, res 24.970268 m, origin (8,982,659.6538, 4,385,054.4832) — matches facts §2. compareGeom done component-wise (crs + dims + res + origin + bounds) via rasterio; checksums via the builder's own `sha256`.

| raster_asset_id | exist | crs=8058 | geom vs ref | checksum | legend_status | size |
|---|:--:|:--:|:--:|:--:|---|--:|
| raster_veg_regime_class_8058 | ✔ | ✔ | ref | MATCH | confirmed | 0.4 MB |
| raster_vegpct_p05 | ✔ | ✔ | ✔ | MATCH | confirmed | 17.9 MB |
| raster_vegpct_p10 | ✔ | ✔ | ✔ | MATCH | confirmed | 17.7 MB |
| raster_vegpct_p20 | ✔ | ✔ | ✔ | MATCH | confirmed | 17.4 MB |
| raster_vegpct_p30 | ✔ | ✔ | ✔ | MATCH | confirmed | 17.2 MB |
| raster_vegpct_p50 | ✔ | ✔ | ✔ | MATCH | confirmed | 16.7 MB |
| raster_flood_zone_8058 | ✔ | ✔ | ✔ | MATCH | confirmed | 0.4 MB |
| raster_08058_wet | ✔ | ✔ | ✔ | MATCH | confirmed | 16.4 MB (35 bands) |
| raster_08058_valid | ✔ | ✔ | ✔ | MATCH | confirmed | 2.2 MB (35 bands) |

**9 / 9 clean.** All ≤ 50 MB → whole-file checksums. **No unregistered *Task H* 8058 product.** Two 8058 `.tif` families on disk are unregistered but are **not** Task H products: `background_flood_frequency_8058.tif` (F5/Task-C surface) and the Task J `diff_pp_*_8058.tif` set (§7). Listed, not fixed.

## 5. D1 / D2 state + QA views

- **D1 — STANDS.** v4 not on disk (§1). Banner texture reported; **no banners added**.
- **D2 — STANDS exactly.** `census_stratum`: `mapped_area_ha` absent, `farm_area_total_ha` absent, single `farm_area_ha = 67,349.332`. Aeolian-low `pct_of_farm` = **2.4798%** (view, mapped) vs **1.9440%** (true 85,910.8 ha); ratio **1.2756 ≈ ×1.276**. Reported; **not fixed**.
- **`v_database_release_checks`: 32 / 32 PASS.**
- **`v_current_qa_issues`: 11 rows, all `REVIEW`/`WARN` moderate**, all from `run_id db_build_20260701` — pre-Task-H design-brief flags (plot overlays, CRS mixing, geometry repairs). None concerns census/parquet/8058-raster integrity. `qa_0040` ("98/98 raster assets lack CRS/extent") is legitimately still flagging the **100 old-generation 28355 rasters**; the 9 Task H 8058 products *are* populated (`raster_asset` = 109 rows, the 8058 set carries crs/extent) — so the check is not simply stale, it correctly points at the old generation.

## 6. Gate C — the three summaries (measured vs published)

Additive small CSVs. Committed under **`docs/census_summaries/`** (tracked cross-session memory), **not** force-added into gitignored `Output/` (avoids the C9 anti-pattern of a tracked file under an ignored path). Working copies also written to `Output/census/summaries/`.

| Summary | File (committed under `docs/census_summaries/`) | Result |
|---|---|---|
| **C1** community mean flood frequency | `census_community_flood_freq_means.csv` | Aeolian **6.08** · Riverine **12.91** · Inland **27.99** — **all MATCH** (facts §9); +context Woodland 33.80 / Other 22.92. Exact medians on the k/35 grid. |
| **C2** total-veg percentile by community | `census_percentile_by_community.csv` | veg_p05–p50 × 5 communities; **nulls reconcile: 153 (Woodland) + 2 (Inland) = 155** (facts §7a). Census footprint 1,080,157 = classified-veg subset of the 1,382,300 farm-masked diagnostic — different by design. |
| **C3** flood-zone × community crosstab | `census_flood_zone_by_community.csv` | vs pre-existing `tier2H_h6_flood_zone_crosstab.csv`: **max \|Δn\| = 0, max \|Δpct\| = 0.0000 pp** (25 cells); matches facts §9. |
| **C2 refugia (Option B)** | `census_green_at_floor_farm_distribution.csv` | Farm-level floor **distribution** (3 rows: total-veg, PV, green-fraction at the floor season; green-fraction median 3.03 / mean 11.77 / p95 55.56, n = 959,833). **This is NOT the ~4,300 ha refugia count.** |

**Spec correction (C1 label).** The spec calls 6.08/12.91/27.99 "community total-veg cover means" and names the file `census_community_total_veg_means.csv`. Those values are **mean `flood_freq_pct` (pixel support)** — the *flooding gradient*, not veg cover (the total-veg floor is ~58). Renamed to `census_community_flood_freq_means.csv` with columns `community, n_pixels, mean_flood_freq_pct, median_flood_freq_pct, sd_flood_freq_pct`. Approved in the design seat, 20 Jul.

**Pre-existing inventory (checked before writing, per protocol).** `Output/census/summaries/` was absent (created). No prior community-level C1 table or by-community C2 table existed. C3's equivalent existed and **reconciled MATCH** (refreshed, not blind-skipped). No relevant row in `report_asset`.

**D3 closure path (not this task).** The refugia "~4,300 ha majority-green (total + by-community)" requires a **paired** green-fraction-at-floor per pixel (facts §11 — percentiles do not subtract), whose only source is the >50 MB `fc_intermediate` FC cube (out of scope here; a one-off recompute was explicitly declined). **Real closure = a scoped step in the next H2 build: persist a per-pixel green-at-floor product on the census grid; the refugia table then becomes reproducible and registerable.** D3 stays open until then.

## 7. Gate D — figure inventory + registration gap; Task J

**Current-ladder figures on disk (`Output/figures/` root):** F1 = 1 · F2 = 1 · F3 = 2 · F4 = 1 · F5 = 3 · F5c = 4 · F6 = 2 · F7 = 4 · **C1 = 22** (21 paddock checkerboards **21/21 ✓** + 1 farm-wide bivariate) · **D1 = 5 files / 4 paddocks** (Bala_29ca carries an A3 + slide variant) · **D2 = 5/66 ✓** · **D3 = 3/9 ✓** · H2 = 3 · H6 = 1. Design-seat completeness (C1 21/21, D2 5/66, D3 3/9) **confirmed**.

**Registration gap:** `figure_asset` = **139**, all superseded MODIS/MER/gauge generation (`figures/review|maps|plots/`); **0** current-ladder figures registered. Listed, not fixed — this is the core registry/reality mismatch the output-structure restructure will close.

**Task J on-disk (gated on Jana — minimal output expected and confirmed):**
- Rasters: 12 `diff_pp_{1994,1999,2004,2009,2014,2018}` (6 × EPSG:8058 + 6 × 28355) — **0 registered** in `raster_asset`.
- Figures: 1 `figures/maps/task_J/J-F2_placebo_ladder_six_panel.png` — unregistered.
- No per-paddock Task J figures, no committed Task J tables. A large **retired pre/post generation** (2019 framing) exists separately (`csv/*prepost*`, `diagnostics/*pre_post*`, `_archive/…`) — archive-only, not new Task J.
- **Limitations register v10 (20260718): NOT present in the repo tree** (broad search for `*limitation*`/`*caveat*`/`*20260718*` found none). Cannot confirm v10 on disk — it lives chat-side, consistent with other design-seat specs being uncommitted.

## 8. Verdict

**Yes** — every census headline traces to a **present, uncorrupted, correctly-registered** file (parquet checksum + rows MATCH; 11-strata diff = 0; 9/9 rasters clean; 32/32 release checks PASS), and the three relational-store summaries are now **materialised and committed** (C1/C2-percentile/C3, all reproducing published values). **One gap remains: D3's refugia count**, deferred by design to the next H2 build (persist per-pixel green-at-floor), with the farm-level floor distribution committed in the interim. D1 and D2 persist unchanged, by scope.

---

### Files committed by this task
- `docs/change_reports/taskH_ondisk_audit_2026-07-20.md` (this report)
- `docs/census_summaries/census_community_flood_freq_means.csv`
- `docs/census_summaries/census_percentile_by_community.csv`
- `docs/census_summaries/census_flood_zone_by_community.csv`
- `docs/census_summaries/census_green_at_floor_farm_distribution.csv`

Nothing else. No parquet, rasters, or large files committed. No DB mutation. Not merged.
