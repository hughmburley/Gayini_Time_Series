# On-disk audit + census-summary extraction + deck inventory (Task H / I / J)

*Task spec for Claude Code. Design settled in the Claude.ai design seat, 20 Jul 2026, against the live `Gayini_Results.sqlite` (build with Task H rasters registered — newer than the 19 Jul audit snapshot). This is the **disk + parquet** counterpart to the design-seat spine audit, which reconciled the census against the DB but could not touch the large files.*

**Three phases, four gates. STOP at each gate.**
- Phase 1 (Gates A–B) is **read-only verification** — fix nothing, mutate nothing.
- Phase 2 (Gate C) is **additive extraction** — produces small results CSVs only; no DB writes, no census re-run, no fix to any D-defect.
- Phase 3 (Gate D) is **inventory** — read-only.

Branch `tier2h-ondisk-audit` off `main`; held for human review; **do not merge**. **You never appear as git author or co-author.** Commit **only** the report and the small summary CSVs to the repo. Never commit the parquet, rasters, or any large file.

**Run where the parquet and rasters actually live** (the 64 GB workstation with the repo `Output/` populated) — Gate C reads the 1.08 M-row parquet and the percentile rasters.

---

## 0. Read these first — before any code

State comes from the repo, not assumptions. Read, in order, and report which you found with commit SHAs:

1. `docs/Gayini_project_goals_and_logic.md` — what the census is *for*; DB-is-authoritative / consume-via-views.
2. `docs/Gayini_pixel_census_data_contract.md` — the H4 schema; the parquet columns; how the community cover means and percentiles are defined.
3. `docs/Tier2_TaskH_all_pixel_census_v4.md` — the authoritative spec. **If absent from `main`, that is defect D1 confirmed on disk — record it and continue against v3.**
4. `docs/tier2H_gate1_VERIFIED_20260715.md` — the C1–C9 correction ledger; the checksum-method trap (§5).
5. `docs/Gayini_output_structure.md` — the registry-tracks-the-wrong-generation finding (deck figures).
6. `docs/Gayini_established_data_facts.md` — the published community means, flood-zone crosstab, and refugia figure to reproduce in Gate C.

---

## 1. Objective

1. **Verify** the on-disk artefacts backing the census match what the DB claims (Gate B).
2. **Materialise** the census summaries that are missing from the relational store — community total-veg cover means, the five percentile zonal summaries, and the H6 flood-zone × community crosstab — as small committed CSVs so they can go into the summary workbook and close D3 (Gate C).
3. **Inventory** the deck figures on disk and the figure-registration gap (Gate D).

Secondary throughout: a light on-disk pass over Task J pre/post outputs (they may be minimal — Task J is gated on Jana).

---

## 2. Established values — verify, do not re-derive blind

Measured from the uploaded DB. Confirm each survives contact with the files. **`DIFFER` is a valid, useful outcome — never tune your method to force `MATCH`.**

| Claim | Value | Source |
|---|---|---|
| Parquet row count | **1,080,157** | `census_asset.n_rows` = `SUM(census_stratum.n_pixels)` |
| Parquet checksum (first 50 MB) | `6b23f6c0803b69af12345b6818ae2cd453a67fc7ec694a880b3be3681246f966` | `census_asset` |
| Parquet path / run | `Output/census/gayini_pixel_census_8058.parquet` / `tier2H_h4` | `census_asset` |
| Reconciliation to `census_stratum` | **diff = 0** across 11 strata | design-seat audit |
| Community total-veg means | Aeolian **6.08** · Riverine **12.91** · Inland **27.99** | facts doc — reproduce from parquet |
| Task H rasters registered | **9 × EPSG:8058**, all `legend_status = confirmed`, `path_exists = 1` | `raster_asset` (see list below) |
| Release checks | **32 / 32 PASS** | `v_database_release_checks` |
| **D1** | spec v4 **not committed** to `main` (v1–v3 only) | design-seat audit |
| **D2** | C1 area-basis correction **not landed**: `farm_area_ha = 67,349.332` (mapped) only; no `mapped_area_ha`/`farm_area_total_ha`; `pct_of_farm` reads high by **×1.276**; true farm = **85,910.8 ha** | this DB — confirmed |
| **D3** | refugia figure (~4,300 ha majority-green) has **no committed table** | Gate C closes this |
| Figure registry | `figure_asset` = **139** (superseded MODIS/MER generation); current ladder = **0 registered** | this DB |

**The 9 registered 8058 rasters:** `veg_regime_class_8058` (1) · `total_veg_percentile_8058` (5: p05/p10/p20/p30/p50) · `flood_zone_8058` (1) · `annual_inundation_stack_8058` (2: wet, valid).

---

## 3. Checksum-method trap — read before touching any checksum

The builder hashes `sha256(path, max_bytes = 50 * 1024 * 1024)` — **first 50 MB only**. A full-file hash compared against a builder checksum makes **every file over 50 MB mismatch spuriously**.
- Match the builder's method (first 50 MB) against recorded checksums; **state the method per row**.
- Large files that bite: `fc_intermediate` holds a **381 MB** and a **353 MB** file. The 5 percentile rasters (~17 MB) are safe. **Report the parquet's size**; if > 50 MB, hash first-50-MB to match `census_asset`, and also report a full-file hash in a separate column as a future baseline.

---

## 4. Gate A — recon + doc reads → STOP

Report the six docs found (§0) with SHAs, the parquet size, and confirm the branch is clean off `main`. **STOP for review.** Do not proceed to Gate B until cleared.

---

## 5. Gate B — on-disk verification (read-only) → STOP

### B1 · Parquet vs `census_asset`
Resolve the path from `census_asset` (never hardcode). Confirm `path_exists`. Row count from parquet metadata (do not load 1.08 M rows to count). Checksum per §3. Report `measured / recorded / expected` and `checksum_recorded / actual / method / ok`.

### B2 · Reconciliation FROM the parquet
Group parquet by `community × regime_band` → pixel counts vs `census_stratum`; emit the 11-row `parquet_n / stratum_n / diff` table (expect 0).

### B3 · Rasters vs `raster_asset`
For each of the 9 8058 rasters: `path_exists`; `crs_epsg == 8058`; `compareGeom()` against `veg_regime_class_8058.tif`; checksum per §3. Confirm all remain registered with `legend_status = confirmed`. List any 8058 Task H product on disk with no `raster_asset` row.

### B4 · DB state — do D1/D2 still stand?
- **D1:** is `Tier2_TaskH_all_pixel_census_v4.md` on `main`? Do v1–v3 carry superseded banners? Report; **do not add banners**.
- **D2:** does `census_stratum` still have only `farm_area_ha = 67,349.332` and no true-farm column? Confirm `v_pixel_census_by_veg_regime.pct_of_farm` on Aeolian low = 2.4798% (mapped) vs 1.944% (true). Report; **do not fix**.
- Run `v_current_qa_issues` and `v_database_release_checks` read-only; report any non-PASS.

**STOP for review.** If B1/B2/B3 surface any corruption or `DIFFER`, do **not** proceed to Gate C — report and stop.

---

## 6. Gate C — materialise the missing census summaries (additive) → STOP

These three summaries exist only in the parquet/rasters, not the relational store. Produce each as a **small committed CSV** under `Output/census/summaries/`, using the definitions in the data contract and facts doc. **No DB writes** (DB materialisation is a later builder change, out of scope). Reproduce the published values and report measured vs published.

### C1 · Community total-veg cover means
From the parquet, per community, the total-veg cover summary as the census defines it. Reproduce Aeolian 6.08 / Riverine 12.91 / Inland 27.99; report `measured / published / MATCH|DIFFER`.
→ `census_community_total_veg_means.csv` (`community, n_pixels, mean_total_veg_pct, [median, sd]`).

### C2 · Percentile zonal summaries + the refugia table (closes D3)
Zonal stats of the five percentile rasters (p05/p10/p20/p30/p50) by community. Include the majority-green area (the ~4,300 ha refugia figure) as an explicit derived row/column so D3 has a committed table.
→ `census_percentile_by_community.csv` and `census_refugia_majority_green.csv`.

### C3 · H6 flood-zone × community crosstab
Zonal cross-tab of `flood_zone_8058` (Z0–Z4, fixed breaks) × community. Reproduce the facts-doc crosstab; report max pp deviation.
→ `census_flood_zone_by_community.csv`.

Commit the CSVs (small results tables — allowed) and reference them in the change report. **STOP for review.**

---

## 7. Gate D — deck figure inventory + registration gap (read-only) → STOP

- Inventory the current ladder figures on disk (`F1`–`F7`, `F5c`, `C1`, `D1`, `D2`, `D3`, `H2`, `H6`): count present, and which deck slides they back. Confirm the design-seat completeness numbers (C1 21/21 · D2 sites 5/66 · D3 strata 3/9).
- Quantify the registration gap: `figure_asset` = 139 (old generation) vs current-ladder registered = 0. List, don't fix.
- Task J: list any pre/post artefacts on disk (difference rasters, per-paddock figures, tables) and whether registered; confirm the limitations register on disk is **v10 (20260718)**. Absence of finished Task J outputs is expected — do not advance the analysis.

**STOP.** Report.

---

## 8. The report — `docs/change_reports/taskH_ondisk_audit_<date>.md`

For a human deciding what happens next. **Lead with what's wrong.**
1. Docs found (§0) with SHAs; parquet size.
2. Parquet: row count + checksum (method).
3. 11-row reconciliation re-derived from parquet.
4. Raster table: existence, crs, `compareGeom`, checksum (method), registered y/n.
5. D1 / D2 state — still standing? evidence. QA-view output.
6. Gate C: the three summaries, measured vs published, paths to the committed CSVs.
7. Gate D: figure inventory + registration gap; Task J on-disk inventory.
8. One-line **verdict**: does every census headline trace to a present, uncorrupted, correctly-registered file, and are the missing summaries now materialised — yes/no, with the exact blocker if no.

---

## 9. Guardrails

- Phase 1 read-only; Phase 2 additive (small CSVs only); never fix D1–D6, never mutate the DB, never re-run the census/builder, never regenerate rasters.
- Match the builder's 50 MB checksum method; state the method per row.
- `DIFFER` is a finding, not an error to tune away.
- Resolve paths from the DB / path module — do not hardcode `D:/Github_repos/Gayini`.
- STOP at every gate. Commit only the report + the Gate C CSVs. No git authorship attribution.
