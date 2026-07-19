# Task K — Gate A: archive dead-generation outputs (MOVE-ONLY) — report

*Execution seat, workstation, 19 July 2026. Branch `tier2k-gateA-archive` (stacked on `tier2k-gate0-output-census`). **Held for human review — no merge.***

> Note on machine: the Gate A spec names the laptop as the execution seat, but Gate 0 ran and passed on **this workstation**, so the verified census and the 431 files live here. Gate A was therefore executed here, against the live disk that Gate 0 measured. The pre-move drift check (§3.2) is exactly the safeguard for running where the verified state actually is.

---

## 1. Result — one line

**431 dead-generation files moved into `Output/_archive/`, byte-identical, fully reversible. Nothing deleted, no code/DB/builder/`.gitignore` touched. Every pre- and post-move assertion passed. The database is byte-identical to Gate 0.**

---

## 2. Before → after

| | Files under `Output/` | Notes |
|---|---:|---|
| Total (incl. `_archive/`) | **1,356 → 1,356** | nothing deleted — this is a move |
| Non-archive "live" working set | **1,323 → 892** | −431 |
| `Output/_archive/` | **33 → 464** | +431 (33 pre-existing were `_archive/reports/adrian_review_png_assets`) |
| Empty source dirs removed | **45** | 12 top-level + 33 emptied children |

**On the "~920" estimate.** The spec's §6 expected roughly 1,351 → 920. The live pre-count was **1,356** (the 1,351 Gate 0 census files + the 5 committed `taskK_gate0_*` deliverables written after the census walk). The exact post-move live set is **892**, not ~920, because the ~920 estimate did not subtract the **33 files already sitting in `_archive/`** before this gate (the Gate 0 census counted them). The arithmetic that matters: **1,323 live − 431 moved = 892 live**, and total Output is unchanged at 1,356. Nothing is unaccounted for.

---

## 3. Pre-move verification (§3) — all passed, read-only

Ran against `Output/diagnostics/taskK_gate0_census_20260719.csv` before touching a single file:

| Check | Result |
|---|---|
| Select the 431 by the three §2 prefixes; **count == 431** | **431** (274 `review_bundles/tier1*` · 138 `rasters/inundation_background` · 19 `figures/review_refresh`) |
| Every selected file `registered_in` null | **0 registered** across all 431 |
| Every selected file `essential == "no"` | **0 essential** across all 431 |
| Live disk set == census set under the 3 prefixes (drift guard) | **0 missing on disk · 0 extra on disk** — no drift since Gate 0 |
| Recompute SHA-256, compare to census `sha256` | **431/431 match** — pre-move manifest built |

No abort condition was hit, so the move proceeded. Had the live set differed from the census by even one file, the rule was **move zero and report** — it did not fire.

---

## 4. The move (§4)

Each file moved with its **full path preserved below `Output/`**, via a same-drive filesystem rename (`shutil.move` → atomic, no window with two copies):

```
Output/review_bundles/tier1_pixel_census/…  -> Output/_archive/review_bundles/tier1_pixel_census/…
Output/rasters/inundation_background/…       -> Output/_archive/rasters/inundation_background/…
Output/figures/review_refresh/…              -> Output/_archive/figures/review_refresh/…
```

### ⚠️ One spec inconsistency, flagged — path of the `review_refresh` group

The spec §4 states the rule twice as *"preserving its path below `Output/`"* / *"preserving their relative structure"*, and its first two worked examples do exactly that. **Its third example, however, maps `Output/figures/review_refresh/baz.pdf → Output/_archive/review_refresh/baz.pdf` — dropping the `figures/` component.** That single example contradicts the stated rule.

**I followed the stated rule (kept `figures/`): `→ Output/_archive/figures/review_refresh/…`.** Reasons: (a) it is the rule written twice; (b) both other examples preserve the full path; (c) the **existing** `_archive/` tree already follows it — `Output/_archive/reports/adrian_review_png_assets` came from `Output/reports/…`, preserving `reports/`. Placing `review_refresh` under `_archive/figures/` keeps the archive self-describing and consistent with precedent.

This is **fully reversible** — the moved-manifest CSV records the exact `old_path → new_path` for all 431. If you intended the literal example (`_archive/review_refresh/`), say so and it is a 30-second re-move of 19 files.

### Empty dirs removed (45 total; 12 top-level)

All source subtrees emptied completely and were removed bottom-up:
`figures/review_refresh` · `rasters/inundation_background` · and the 10 tier1 bundles (`tier1G_figures_dashboards`, `tier1_dashboards_trial`, `tier1_pixel_census`, `tier1_veg_regime_checkerboard`, `tier1b_descriptive_figures`, `tier1c2_f5_legibility`, `tier1c3_f5_figures`, `tier1c_stratified_sampling`, `tier1d_trend_test`, `tier1e_f7_groundcover_response`). Parents that still hold files were **not** removed — `Output/review_bundles/` remains (holds `tier2H_all_pixel_census/` + zips, correctly not in the archive set), as do `Output/rasters/` and `Output/figures/`.

---

## 5. Post-move verification (§5) — all passed

| Check | Result |
|---|---|
| **Byte identity:** all 431 exist at new `_archive/` path with SHA-256 matching the pre-move manifest | **431/431 identical** |
| **Nothing stranded:** no source path still exists | **0 stranded** |
| **DB untouched:** `Gayini_Results.sqlite` SHA-256 == Gate 0 value | **`37c5d72d…695e7` — unchanged** |
| **Registry still valid:** all 287 registered paths still exist (re-derived) | **broken pointers = 0** |
| **Nothing else touched:** live non-archive count | 892 (= 1,323 − 431); registered assets none moved |

---

## 6. Scope confirmation (acceptance §8.4)

**No code edited · no `.gitignore` edited · no database written · builder not run · nothing deleted · nothing registered or de-registered.** `git status` shows only two tracked additions (this report + the manifest CSV under `docs/`); the 431 moved files live under the gitignored `Output/_archive/` and are intentionally **not** committed (spec deliverable 1: present on disk, not in git).

**Explicitly deferred (§7), untouched here:** the builder `_archive/` scan exclusion; the 139 registered old-generation figures under `figures/maps|plots|review` (moving them breaks 139 live paths — needs the builder fix first); code archiving (`scripts/_deprecated/`, retired pre/post wrappers, dead-writer dirs); registering the 330 untracked ladder figures. All belong to later gates.

---

## 7. Deliverables

| # | Path | Committed? |
|---|---|---|
| 1 | `Output/_archive/…` (431 moved files) | No — gitignored, present on disk |
| 2 | `docs/change_reports/taskK_gateA_20260719.md` (this report) | Yes |
| 3 | `docs/change_reports/taskK_gateA_moved_manifest_20260719.csv` (431 rows: old_path, new_path, sha256) | Yes |

**Reversibility:** the move is a pure rename tree recorded row-for-row in the manifest with SHA-256. Re-running the manifest in reverse restores the exact prior state; no information was lost.

**Held at the gate for human review. No merge.**
