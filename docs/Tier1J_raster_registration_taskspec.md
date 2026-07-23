# Task spec — Register Task J (2018 pre/post) rasters in `raster_asset`

**Owner:** Hugh (design/review in chat) · **Executor:** Claude Code (CC) on the workstation
**Repo:** github.com/hughmburley/Gayini_Time_Series
**Target DB:** `Gayini_Results.sqlite` (LIVE workstation copy — **not** any uploaded copy)
**Type:** Additive registration. Packaging, not analysis. No analysis is to be run or re-run.

---

## Purpose (one concern)

Register Task J's on-disk pre/post difference rasters as rows in the SQLite `raster_asset`
pointer table, so every figure in `Gayini_prepost_methods_deck.pptx` traces to a registered
file + checksum. `raster_asset` is a **relational table in `Gayini_Results.sqlite`**; the raster
binaries stay on disk as GeoTIFFs (never in SQLite, never in parquet).

**Disk is the source of truth.** Every registered row must describe bytes that exist on disk at
registration time, verified by checksum. No row may be written from an assumed path.

## Absolute constraints (violating any = stop and report)

1. **Do NOT run the builder.** No `reset_file`, no db rebuild. The builder rebuilds from scratch
   and would destroy the manually-added Task H census rows. This task only ever `INSERT`s.
2. **Additive only.** No `UPDATE`, no `DELETE`, no moves. Only `INSERT` of new rows into
   `raster_asset`. If a row appears to already exist for a target path, STOP and report — do not
   overwrite.
3. **Live DB only.** Operate on the workstation's live `Gayini_Results.sqlite`. The uploaded copy
   is stale.
4. **CRS labelling is mandatory.** Every row carries `crs` + `crs_epsg`. Never quote hectares/areas
   off the 28355 grid (it is +0.23% vs the 8058 census grid — MGA55 scale factor). This task
   registers rasters; it does not compute areas.
5. **No AI attribution in commits.** No `Co-Authored-By` trailer.

---

## GATE 0 — Idle check (live DB not mid-write)  · **STOP after, report to Hugh**

Registration was deferred last session because Task H was writing `raster_asset` concurrently, and
worktrees isolate files but **not** the shared SQLite DB. Before any read or write:

1. Confirm no builder / dashboard / Task H / P4.x job is currently running (Hugh confirms verbally
   **and** CC checks for evidence).
2. Check SQLite is not mid-transaction: report presence/size of `Gayini_Results.sqlite-wal` and
   `Gayini_Results.sqlite-journal`. A large or growing WAL suggests an active writer.
3. Report the current `raster_asset` row count and `MAX(rowid)` from the **live** DB (expect ~109+;
   the exact number will differ from the uploaded snapshot — that is fine and expected).

**Output:** short idle-state report. **STOP.** Do not proceed to Gate 1 until Hugh confirms idle.

---

## GATE 1 — Read-only enumeration + reconciliation (disk SOT)  · **STOP after, report**

**All read-only. No writes to disk or DB in this gate.**

1. **Enumerate** `Output/rasters/task_J/` (and any subfolders). List every `.tif`: filename, size,
   `gdalinfo` summary (CRS, EPSG, resolution x/y, extent xmin/ymin/xmax/ymax, band count, dtype,
   nodata).
2. **Map each file to the deck figure it backs.** Known target set from
   `Gayini_prepost_methods_deck.pptx`:
   - Slide 2 (J-F1): the authoritative 2018 difference map — expected
     `diff_pp_2018_28355.tif` (EPSG:28355, FLT4S).
   - Slide 4 (J-F2): the six-panel placebo ladder — expected six diff rasters for
     1994 / 1999 / 2004 / 2009 / 2014 / 2018.
   - Optional: an 8058 display reproject (bilinear) of the 2018 diff, **if kept on disk**.
   Report any file on disk not in this set, and any expected file missing from disk.
3. **Collision / provenance reconciliation** (this is the disk-vs-registry check, not re-analysis):
   `raster_asset` already contains `raster_00007` →
   `Output/rasters/inundation_pre_post/post_minus_pre_inundation_frequency_pct_points.tif`
   (EPSG:28355), a "post minus pre inundation frequency, pct points" quantity from the 1 Jul build.
   Determine whether Task J's `diff_pp_2018_28355.tif` is:
   - (a) the **same** underlying product at a different path (→ flag for Hugh: possible duplicate
     provenance; which one does the deck actually render?), or
   - (b) a **distinct** product (different pre/post window definition, different masking) → then it
     needs a distinct `metric_id` so the two are never conflated.
   Report the evidence (paths, extents, resolutions, and if feasible a checksum comparison), and
   your read of (a) vs (b). **Do not resolve it by writing anything** — surface it.
4. **Checksums.** For each task_J `.tif`, compute SHA-256 using the **builder's first-50-MB
   convention** (match how existing `raster_asset.checksum_sha256` values were produced). State the
   method in the report so Hugh can confirm it matches convention.

**Output:** a table — filename · deck figure · CRS/EPSG · res · extent · dtype · nodata · sha256 ·
proposed `metric_id` · proposed `product` · collision flag. Plus the (a)/(b) provenance read.
**STOP.** Hugh reviews and confirms the exact set + the id/metric scheme before any INSERT.

---

## GATE 2 — Additive registration + independent verification (live SQLite)

Only after Hugh signs off on the Gate 1 set and scheme.

### Row scheme (confirm with Hugh at Gate 1, values illustrative)
- `raster_asset_id`: explicit, semantic, collision-free — e.g. `tier1j_diff_pp_2018_28355`,
  `tier1j_diff_pp_2018_8058`, `tier1j_placebo_1994_28355` … (do **not** assume a `raster_000NN`
  counter — the table mixes counter ids and semantic ids; explicit semantic ids keep Task J rows
  self-identifying and reversible).
- `run_id`: a single distinct tag for all Task J rows, e.g. `tier1j_prepost` — makes the whole set
  filterable and trivially reversible if needed.
- `path`: exact on-disk relative path as enumerated (disk SOT).
- `crs` + `crs_epsg`: from `gdalinfo` (`EPSG:28355`/28355; `EPSG:8058`/8058 for the reproject).
- `resolution_x/y`, `xmin/ymin/xmax/ymax`: from `gdalinfo`.
- `checksum_sha256`: first-50-MB convention value from Gate 1.
- `path_exists`: `1` (verified this run).
- `qa_status`: `REVIEW` (matches every existing row).
- `metric_id` / `product`: per Gate 1 decision. If provenance case (b), a Task-J-specific
  `metric_id` (e.g. `diff_pp_2018_prepost`); the placebo panels get a placebo-year metric so they
  are never read as real treatment years.
- `period_label`: e.g. `pre_vs_post` for 2018; a placebo label for the ladder years.
- `legend_semantics`: one honest sentence carrying the deck's **"descriptive, not an effect"**
  discipline — e.g. "Post-2018 minus pre-2018 annual inundation frequency, percentage points, on
  the EPSG:28355 grid. DESCRIPTIVE difference — not an estimate of the cuts' effect (see Task J:
  ~86% explained by window wetness, 2018 rank 2/25)." Placebo rasters state plainly they are
  counterfactual dates where nothing was cut.
- `legend_status`: `confirmed` only if Hugh confirms the semantics string; else leave `NULL`.

### Steps
1. Wrap all INSERTs in a **single transaction**. Insert only the Gate-1-confirmed set.
2. Immediately **read back from disk** and verify (do not trust the write):
   - re-`SELECT` each new row; assert `path_exists=1` and that the file at `path` exists on disk;
   - re-hash each file and assert it equals the stored `checksum_sha256`;
   - assert no pre-existing row was modified: `raster_asset` count increased by exactly the number
     of Task J rows, and the pre-existing rows are byte-for-byte unchanged (compare row count +
     a checksum/hash of the untouched rows before/after).
3. **DB integrity:** report `PRAGMA integrity_check` and `PRAGMA foreign_key_check` = ok.
4. **Deck traceability closeout:** produce a small table — deck figure → registered
   `raster_asset_id` → path → sha256 — confirming every pre/post deck figure now resolves to a
   registered on-disk file. This is the artifact that satisfies "deck claims verified against disk
   SOT."

### Commit / PR
- Branch `tier1j-raster-registration`. Commit the registration script + the Gate 2 traceability
  table (to `docs/change_reports/`, committed to repo as cross-session memory). Human review, then
  merge. No AI attribution.

**Output:** verification report + traceability table. If any assertion fails, STOP, leave the
transaction rolled back, and report.

---

## Verification-of-CC checklist (Hugh, in chat, against the live DB — not CC's prose)
- [ ] Row count rose by exactly the confirmed number; nothing else changed.
- [ ] Each new `path` exists on disk and its re-hash matches the stored checksum.
- [ ] Every row has non-null `crs` + `crs_epsg`; no area/ha was ever quoted off 28355.
- [ ] `raster_00007` and other pre-existing rows untouched.
- [ ] Provenance (a)/(b) for the 2018 diff was resolved deliberately, not by silent duplication.
- [ ] Every pre/post deck figure resolves to one registered row.
