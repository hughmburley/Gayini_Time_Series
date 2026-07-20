# D2 area-basis fix + current-ladder figure re-registration

*Task spec for Claude Code. Design seat, 20 Jul 2026. Two coupled defects that both touch the builder / registration path: **D2** (the C1 area-basis correction never landed) and the **Gate D figure gap** (`figure_asset` holds 139 old-generation rows, 0 current-ladder registered).*

**THE GOVERNING CONSTRAINT — read first.** **The builder is destructive.** It rebuilds the DB from scratch (unlink + rebuild) and re-scans `figure_asset` from an unfiltered `rglob`; a run would wipe the ~12 manually-registered Task H rows (`census_asset`, the 9 EPSG:8058 rasters) and reinstate the stale 139-row figure snapshot. **Do NOT run the builder in this task.** Both fixes are applied as **additive changes to the live DB** *plus* **source-code fixes so a future rebuild is correct** — never via a rebuild.

**Workflow: recon-first, gated, additive-only, held.** Branch `taskh-d2-and-figure-reg` off `main`. No deletes (mark superseded, never drop). No AI authorship attribution. Branch-and-PR, held — do not merge.

---

## 0. Read first

`CLAUDE.md` (the builder-is-destructive rule, the four-CRS discipline), `docs/Gayini_output_structure.md` (the figure-registry generation gap **and the output-folder migration plan**), `docs/Tier2_TaskH_all_pixel_census_v4.md` §6 C1 (the area-basis correction as specified), and the change report from the on-disk audit (the confirmed D2 state and figure inventory).

---

## 1. Gate A — recon → STOP

**Report, do not change:**

### 1.1 D2 state
- `PRAGMA table_info(census_stratum)` — confirm no `mapped_area_ha` / `farm_area_total_ha`; `farm_area_ha` distinct = 67,349.332.
- The **exact SQL** of `v_pixel_census_by_veg_regime` (the `pct_of_farm` expression).
- The **builder source** that (a) populates `census_stratum` and (b) defines the view — name file:line for both.
- **Blast radius:** grep the repo for every consumer of `farm_area_ha` and `pct_of_farm` (code, figures, decks, CSVs). List them. **Do not change any.**

### 1.2 Figure landscape
- `figure_asset`: row count, generation (confirm 139 old-gen MODIS/MER, 0 current-ladder), and whether it has a `qa_status` / `legend_status` / generation-style column usable to mark rows superseded **without deleting**.
- Current-ladder files on disk: counts by prefix (`F1`–`F7`, `F5c`, `C1`, `D1`, `D2`, `D3`, `H2`, `H6`) and their paths.
- The two shadow registries: `gayini_gradient_helpers.R:166` (`figures_manifest.csv`) and `gayini_figure_manifest.R` (richer schema). Report which, if either, is intended to feed `figure_asset`.
- **The migration question (decisive for Part 3):** per `Gayini_output_structure.md`, has the output-folder migration been **executed**, or are the current-ladder figures still at `figures/` root? **Report which.** Registering figures at paths that a pending migration will move is wasted work and creates broken pointers.

**STOP for review.** Part 3 (figures) is gated on the migration finding.

---

## 2. Gate B — D2 area-basis fix (additive + source) → STOP

### 2.1 Source code (so a future rebuild is correct)
- In the builder's `census_stratum` populate step: add `mapped_area_ha` (= the current mapped 67,349.332 ha) and `farm_area_total_ha` (= **85,910.8 ha**, the true farm area per v4 §3.2). Keep `farm_area_ha` for backward compatibility but document it in-code as the **mapped** area (the deprecated misnomer, C1).
- In the view definition: `pct_of_farm` = `area_ha / farm_area_total_ha * 100` (was `/ farm_area_ha`).

### 2.2 Live DB (additive — no rebuild)
- `ALTER TABLE census_stratum ADD COLUMN mapped_area_ha REAL;` and `ADD COLUMN farm_area_total_ha REAL;`
- `UPDATE census_stratum SET mapped_area_ha = 67349.332, farm_area_total_ha = 85910.8;`
- `CREATE VIEW ... OR REPLACE` (drop + recreate) `v_pixel_census_by_veg_regime` with the corrected `pct_of_farm`. (A view is derived — dropping/recreating it is non-destructive and does not touch the census rows.)

### 2.3 Reverify numerically
- Aeolian low `pct_of_farm`: **2.4798% (before) → 1.944% (after)**; confirm the ×1.276 inflation is gone across all strata (sum of `pct_of_farm` over focus strata should fall from the mapped basis to the true-farm basis).
- Confirm `census_stratum` still has 11 rows and `SUM(n_pixels) = 1,080,157` — the additive columns changed nothing else.
- `v_database_release_checks` still 32/32 PASS; no new `v_current_qa_issues`.

### 2.4 Do not touch downstream
Any figure/slide/CSV that quoted the old "% of farm" (the Gate A blast radius) is **flagged, not fixed** — those are separate deliverable edits. Report them.

**STOP for review.**

---

## 3. Gate C — current-ladder figure re-registration → STOP

**Gated on Gate A's migration finding. Do not register blindly.**

- **If the output-folder migration is PENDING:** do **not** register at `figures/` root — those paths will move. Report this and **recommend sequencing figure registration after the migration** (register at final paths, once). Register now only if Hugh explicitly wants it for the deck rebuild and accepts a re-point pass after migration. Present the choice; do not decide it silently.
- **If the migration is DONE:** register at the final paths.

When registering (either case):
- **`figure_asset` is the canonical registry.** Register the current-ladder figures additively (targeted `INSERT`, current generation only) with path / prefix / crs where applicable. **Do not run the builder to do this.**
- **The two shadow registries:** if `gayini_figure_manifest.R`'s richer schema is to be the manifest source (a design choice — surface it, don't assume), reconcile it to `figure_asset`; otherwise register directly. Report the approach chosen and why.
- **The 139 stale old-gen rows:** additive-only → **mark them superseded** (via the status/generation column found in Gate A), never delete. If no such column exists, report that and stop before touching them.
- **Builder source fix:** the 139 came from an *unfiltered* `rglob`. Fix the builder's figure-registration step so a future rebuild registers the **current generation, filtered** — not the 1-July unfiltered snapshot. (Recall `map_asset_index` has **two** `rglob` scan sites — check whether the figure registration shares that pattern and needs both edited.)

**STOP for review.**

---

## 4. Report — `docs/change_reports/taskH_d2_and_figure_reg_<date>.md`

Lead with what changed. (1) Gate A recon: D2 state, figure landscape, migration status, blast radius. (2) D2: source edits (file:line), the additive SQL applied, before/after `pct_of_farm`, release-check state. (3) Figures: migration decision taken, what was registered, how the 139 were marked superseded, the builder rglob fix. (4) Explicit list of downstream "% of farm" consumers flagged for separate fixing.

Commit the report + code changes. **Never commit the DB, parquet, or rasters.**

## 5. Guardrails

- **Never run the builder.** Additive to the live DB; source-fixed for the future.
- Additive-only: no deletes anywhere — mark superseded.
- Reverify D2 numerically (1.944% Aeolian low; 1,080,157 preserved; 32/32 PASS).
- Figure registration is gated on the migration finding — surface the decision, don't pre-empt it.
- Don't touch downstream figures/slides that quote "% of farm" — flag them.
- Branch-and-PR, held. No AI authorship attribution.
