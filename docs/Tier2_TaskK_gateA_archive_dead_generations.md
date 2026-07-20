# Task K — Gate A: archive dead-generation outputs (MOVE-ONLY)

*Design seat, 19 July 2026. Execution: Claude Code on the **laptop**, branch-and-PR, held for human review. Gate 0 ran and passed on this machine; its findings are treated as verified fact below.*

**Read first, in this order:**
1. `docs/Gayini_project_goals_and_logic.md` — the audit lens. §7's four buckets (live / dormant / retired / untracked-but-current) explain *why* these files are archivable. **Caveat:** its "register the untracked figures" instruction is the project's end goal, **not a Gate A action** — Gate A registers nothing and runs no builder.
2. `docs/Tier2_TaskK_gate0_output_census.md` — the census spec Gate 0 executed.
3. `docs/change_reports/taskK_gate0_20260719.md` — the Gate 0 result. The archive set below was verified against it.
4. `docs/Gayini_output_structure.md` — the placement contract.
5. `docs/Gayini_established_data_facts.md` — §10 (Task F cancelled) and §11 (pre/post retired) are settled; do not re-open.

---

## 0. What this task is — and is not

**Is:** a pure **filesystem move** of 431 verified dead-generation files into `Output/_archive/`, preserving their relative structure.

**Is NOT:** it does not delete anything, edit any code, touch any database, run the builder, register or de-register any asset, or modify `.gitignore`. If a step seems to call for any of those, **stop — it's out of scope and belongs to a later gate.**

This is the reversible, load-bearing-free slice of Task K. Everything risky (the builder's `reset_file`, the registered-figure moves, the code archive) is deliberately excluded and gated separately.

## 1. Standing rules

- **ADDITIVE-ONLY. Nothing is deleted.** `_archive/` is a move. A moved file must be byte-identical at its new path.
- **Verify against data, not appearance.** Gate 0 already proved these 431 files carry 0 registry rows and 0 `essential=yes`. Re-confirm that from the census before moving (§3), don't assume it.
- Canonical CRS EPSG:8058 (not exercised here, but the discipline stands).
- Claude never appears as git author or co-author. No AI attribution in commit messages.
- `Output/` is **gitignored** (Gate 0 finding). These files are not tracked by git now, so the move is a filesystem operation, not a git operation. Do **not** edit `.gitignore` to make `_archive/` tracked — that's a separate decision.
- Recon first. Stop at the gate. No merge without human review.

## 2. The archive set — 431 files, 43 folders, 0 registered, 0 essential

Three groups, all verified in Gate 0 (`gate_a` block, and re-derived from the census CSV by the design seat this session):

| Group | Files | Folders | Registered | essential=yes |
|---|---:|---:|---:|---:|
| `Output/review_bundles/tier1*` (10 bundles) | 274 | 32 | 0 | 0 |
| `Output/rasters/inundation_background/` | 138 | 6 | 0 | 0 |
| `Output/figures/review_refresh/` | 19 | 5 | 0 | 0 |
| **Total** | **431** | **43** | **0** | **0** |

The ten `tier1*` bundles (match `Output/review_bundles/tier1` prefix): `tier1_dashboards_trial`, `tier1_veg_regime_checkerboard`, `tier1G_figures_dashboards`, `tier1c3_f5_figures`, `tier1b_descriptive_figures`, `tier1c2_f5_legibility`, `tier1e_f7_groundcover_response`, `tier1c_stratified_sampling`, `tier1d_trend_test`, `tier1_pixel_census`.

**Why these are safe (from the goals doc §7):** tier1 bundles are superseded review packages; `inundation_background` is retired scenario rasters; `review_refresh` is old-deck figures. None is consumed by the live census path, the database views, or the current ladder. All are bucket-3 (retired) or bucket-2 (dormant) — never bucket-1 or bucket-4.

## 3. Pre-move verification — prove the set before touching it

Do this first, read-only, and **abort if any check fails** rather than proceeding:

1. Load the Gate 0 census CSV (`Output/diagnostics/taskK_gate0_census_20260719.csv`).
2. Select the 431 files by the three prefixes in §2. **Assert count == 431.** If the live disk now differs from the census (possible — the laptop is active; Task J drifted the totals once already), report the delta by name and **stop**. Do not move a set that doesn't match what was verified.
3. **Assert every selected file has `registered_in` null** and **`essential == "no"`.** If even one is registered or essential, stop and report it by name — the Gate 0 guarantee has broken and the move is unsafe.
4. Record the SHA-256 of each of the 431 files (from the census `sha256` column, or recompute). This is the pre-move manifest for the byte-identity check in §5.

## 4. The move

For each of the 431 files, move it to `Output/_archive/` **preserving its path below `Output/`**:

```
Output/review_bundles/tier1_pixel_census/foo.png
  -> Output/_archive/review_bundles/tier1_pixel_census/foo.png
Output/rasters/inundation_background/bar.tif
  -> Output/_archive/rasters/inundation_background/bar.tif
Output/figures/review_refresh/baz.pdf
  -> Output/_archive/review_refresh/baz.pdf
```

- Create `Output/_archive/` and the needed subtree. Use a real filesystem move (`git mv` is irrelevant — files are gitignored), not copy-then-delete, so there's no window with two copies. If the platform forces copy+delete, verify the destination SHA-256 matches **before** removing the source.
- Move files only. Do not create, rewrite, or "tidy" anything else.
- After moving, if a source folder (e.g. `Output/rasters/inundation_background/`) is now empty, leave it or remove the empty dir — but **only if it is genuinely empty**. Report which empty dirs you removed. Do not remove a parent that still holds other files.

## 5. Post-move verification

1. **Byte identity:** every one of the 431 files exists at its new `_archive/` path with a SHA-256 matching the §3 pre-move manifest. Any mismatch is a failure — report and stop.
2. **Nothing stranded:** none of the 431 source paths still exists.
3. **Nothing else touched:** the other ~920 files under `Output/` are unchanged — same count, and spot-check SHA-256 on the registered assets (all 287 must be untouched; none was in the archive set).
4. **DB untouched:** record `Gayini_Results.sqlite` SHA-256; it must equal the Gate 0 value `37c5d72de77ac9b10e7d38a787d32e725268624ed9d60f7890b5c0b4cca695e7`. The builder was not run; the DB must be byte-identical.
5. **Registry still valid:** re-run the census→registry join. Broken pointers must still be **0** — none of the 287 registered paths moved, so none should break. A non-zero count means something registered was moved by mistake; that's a stop-and-report.

## 6. Deliverables

1. `Output/_archive/…` — the 431 moved files (gitignored; not committed, but present on disk).
2. `docs/change_reports/taskK_gateA_20260719.md`, committed. Contents:
   - Files moved: count, folders removed, before→after `Output/` totals (expect ~1,351 → ~920; state the actual live pre-count).
   - The §3 pre-move assertions and their pass/fail.
   - The §5 post-move verification: byte-identity result, DB SHA-256 before/after, broken-pointer count.
   - Any empty dirs removed, listed.
   - Explicit confirmation: no code edited, no DB written, no builder run, `.gitignore` untouched.
3. A small manifest table `docs/change_reports/taskK_gateA_moved_manifest_20260719.csv` (old_path, new_path, sha256), committed — so the move is auditable and reversible from the repo.

## 7. Out of scope — explicitly deferred

- The builder `_archive/` scan exclusion (two `rglob` sites). **Not in Gate A.** It belongs with the builder fix (reset→upsert, learn `census_asset`), because the builder is not run here and the exclusion only matters when it next is.
- Moving the **registered** old-generation figures (`figures/maps`, `figures/plots`, `figures/review`, `review_deck` — 139 registered rows). These need the builder fixed first. Not here.
- Any **code** archiving — `scripts/_deprecated/`, retired pre/post wrappers + impls, dead-writer dirs. That's the separate code-audit recon.
- Registering the 330 untracked ladder figures. Later gate.
- Editing `.gitignore`, deleting anything, building dashboards.

## 8. Acceptance

1. Exactly 431 files moved (or, if the live set differs from the census, **zero moved** and a discrepancy report instead).
2. All 431 byte-identical at their new paths; all 431 source paths gone.
3. DB SHA-256 unchanged from Gate 0. Broken pointers still 0.
4. No code, no `.gitignore`, no DB, no builder touched — confirmed in the report.
5. Change report + moved-manifest CSV committed on a branch. Held for review. No merge.
