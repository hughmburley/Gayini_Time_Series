# Gayini Biodiversity — workstation onboarding & fresh-environment audit

*Task spec for Claude Code, run **on the workstation**, inside the companion repo
`D:\Github_repos\Gayini_Biodiversity` (with the main repo `D:\Github_repos\Gayini` present
as sibling context). Design seat, 20 Jul 2026. Purpose: make the workstation a **trusted,
reproducible** environment for the biodiversity repo before any deck/figure work — a fresh
machine introduces sync, dependency, and cross-repo-path risks that the earlier static code
stocktake did not cover. **This does NOT re-audit the code** (the stocktake stands); it
audits the environment.*

**Recon-first and safety-critical. STOP at each gate. Report and wait for clearance before
any write, commit, install, pull, or rebuild.**

**Absolute guardrails**
- **Never** `git reset --hard`, `git checkout -- <file>`, `git stash drop/clear`, or
  `git clean` on anything uncommitted. Uncommitted work is precious until explicitly committed.
- `fetch` freely; **`pull --ff-only` only**; never force-push; **never merge to `main`
  locally** (branch-and-PR — merges happen via GitHub PR, by Hugh).
- **No AI authorship attribution** on any commit (no `Co-Authored-By:`, no "Generated with…").
  Leave commits **local** for Hugh to push/merge via TortoiseGit unless told otherwise.
- **Do not re-run `05`** (or anything that reads the main repo's `plot_rs_analysis_base.csv`)
  until Gate B confirms that file is present and current — it degrades silently to empty.
- **renv caution:** the goal is a **lockfile as documentation**, not to rebuild a library
  mid-crunch. If renv proposes reinstalling packages (esp. terra/sf/exactextractr, which need
  system GDAL/GEOS/PROJ), **STOP and report** — do not let it disrupt a working environment.

---

## 0. FIRST — confirm the machine (external signal)

Confirm this session is on the **workstation** from an **external signal** (hostname, or a
path that genuinely differs between laptop and workstation) — **not** from an assumed path.
This project has previously confabulated "workstation" from a path identical on both machines.
If you cannot positively confirm workstation identity, **STOP and report**. State the signal
used and its value.

---

## 1. Gate A — sync & context state (READ ONLY) → STOP

### 1.1 Context docs (report which exist on disk, with content/commit SHAs)
- `docs/Gayini_Biodiversity_repo_stocktake.md` — the static audit.
- `docs/Gayini_presentation_design_system.md` — shared design system (4-community grouping,
  palette tokens, DB drivers, guardrails).
- `docs/Biodiversity_Task_deck_restyle_spec.md` — the deck restyle task (still pending).
- Latest `docs/change_reports/biodiversity_p1_community_4class_*.md` — the P1 change report.
- A repo-local `CLAUDE.md`, if one exists (report presence; do not assume).

### 1.2 Working tree
- `git status --porcelain` — list every modified / staged / untracked path. Confirm whether
  the P1 docs + change report are committed here or still local. Note any uncommitted work
  that needs a home (do not act on it).
- Confirm `OUTPUT/` and diagnostic figures are gitignored (expected).

### 1.3 Branches & origin — **is P1 actually merged?**
- `git fetch --all --prune` (safe).
- Current branch + upstream; ahead/behind for each local branch.
- Is `feature/biodiversity-p1-community-4class` (last known complete at `fc620d0`) **merged
  into `origin/main`**? Report merged / open; if open, the compare URL for Hugh's PR.
- `git log --oneline -8` for local `main` **and** `origin/main` — is the workstation behind
  origin (Hugh merged, workstation hasn't pulled) or ahead?
- **Sentinel check** that P1 content is actually present at `HEAD` (not just that a merge
  commit exists): `GAYINI_RS_COMMUNITY_LOOKUP` + `GAYINI_RS_COMMUNITY_PALETTE` in config,
  `gayini_assert_community_coverage` in checks, `polished_deck_row` in `07`, the loud
  bridge-skip warning in `05`, `rs_community` column in the crosswalk CSV.

### 1.4 The picture in one paragraph
Is the workstation **ahead of / behind / in sync with** origin; is P1 present and complete
here; and what uncommitted work (if any) needs a home. **Do not act. STOP and report §0–§1.**

---

## 2. Gate B — environment & dependency audit (READ ONLY) → STOP

### 2.1 R + packages
- `R.version.string` and `Sys.getenv("R_LIBS_USER")`.
- For the pipeline's 17 packages (terra, sf, ggplot2, dplyr, tidyr, purrr, patchwork, scales,
  readr, tibble, stringr, jsonlite, httr, gridExtra, exactextractr, DBI, RSQLite): report
  installed version + whether each loads. Flag any missing / failing to load — those are
  fresh-env blockers.
- `renv::dependencies()` **(read-only discovery)** — report the dependency set it detects.
  Report whether `renv.lock` / `renv/` / an renv-aware `.Rprofile` already exist (expected: no).

### 2.2 Cross-repo file + token
- Does `D:\Github_repos\Gayini\Output\csv\plot_rs_analysis_base.csv` exist on this machine?
  If **missing**, is it **gitignored** in the main repo (→ needs regeneration from the main
  pipeline) or genuinely lost? Also report the intermediate `*_REVISED.csv` the bridge last
  ran on, and whether the two would agree.
- LOOC-B token: does `docs/LOOC-B_Key_2025.txt` (or legacy `docs/LOOC-B_key.txt`) exist?
  (Not needed for the deck refresh — assets are cached — but confirm for completeness.)

### 2.3 SQLite state — does it reflect P1?
- `OUTPUT/Gayini/database/Gayini_Biodiversity.sqlite` present? `PRAGMA quick_check`.
- Confirm P1 landed in the live DB: `v_vegetation_community_summary` exists with **4 rows**
  (Inland Floodplain = Shrublands+Swamps ≈ 44,822 ha; Woodland/Forest = 2 treed classes,
  `analytical_focus=0`); `v_map_assets` = **9** (all `_single.png`, all paths resolve; zero
  `_final` in the deck set). Report if the on-disk DB predates P1.

### 2.4 OUTPUT — regenerated here, or carried over?
- Do `OUTPUT/Gayini/maps_polished/` (9 PNGs), `figures_polished/`, `maps_final/`, and the
  intermediate tables/CSVs that `07`/`09` consume exist on disk?
- Determine whether `OUTPUT` was **regenerated on this machine** or **copied over** — check
  file timestamps vs the repo's last build, and whether `07`'s input tables are present.
  (Reproducibility is confirmed in Gate C, non-destructively.)

### 2.5 Paths resolve on this machine
- Report `GAYINI_BIODIVERSITY_ROOT`, `GAYINI_MAIN_ROOT`, `LOOCB_API_ENV` (set? or falling back
  to the `D:\` defaults?). Grep the repo for any remaining **absolute** paths that would not
  resolve on a different machine.

**STOP. Report §2 and wait for clearance.**

---

## 3. Gate C — remediate (only the steps Hugh clears)

1. **Sync.** If the workstation is behind and P1 is merged on origin: `git pull --ff-only` on
   `main`. If fast-forward isn't possible (diverged), **STOP and report** — do not force. If
   P1 is not yet merged, report the PR URL (Hugh merges via GitHub), then pull once merged.

2. **Stand up renv (lockfile as documentation).** The natural moment to close the P2
   reproducibility gap. Capture the lockfile **from the existing, working library** — do not
   force reinstalls:
   - `renv::init(bare = TRUE)` then `renv::snapshot(type = "all")`, OR `renv::snapshot()` if
     init is undesired — whichever captures current versions without rebuilding the library.
   - **If renv proposes to reinstall packages (esp. terra/sf/exactextractr), STOP and report**
     rather than proceed — a working geospatial toolchain must not be disturbed three weeks out.
   - Commit `renv.lock` + the renv activate scaffolding **only** (never `renv/library/`).
     Add `renv/library/` to `.gitignore` if not already covered.

3. **Run the check layer end-to-end** to prove the environment is functional:
   `gayini_check_packages()`, `gayini_validate_core_inputs()`, `gayini_assert_community_coverage()`.
   Report pass/fail. This is the "does it actually run here" gate.

4. **Reproducibility proof (non-destructive, optional).** If `07`'s input tables are present
   (Gate B §2.4), re-run `07` with the SQLite output **redirected to a temp path**, then diff
   table/view row counts and the 4-community view against the live DB; **discard the temp**.
   Confirms `OUTPUT` regenerates on this machine rather than only having been copied. Do **not**
   overwrite the live DB, and do **not** run `05`.

5. **Change report** at `docs/change_reports/biodiversity_workstation_onboarding_<date>.md`:
   machine-identity signal, sync end-state, dependency inventory + renv lockfile status, the
   cross-repo/token findings, check-layer result, reproducibility result. Commit the report +
   `renv.lock` (leave local for TortoiseGit). No AI attribution.

---

## 4. Report — short
Machine-identity signal + value · context docs found · Gate A sync paragraph (is P1 merged &
present) · Gate B environment findings (packages, cross-repo file, DB reflects P1, OUTPUT
provenance, path resolution) · then (after Gate C) what was synced/snapshotted/verified and
the clean end-state. Call out anything that could not fast-forward, any missing dependency,
and whether `plot_rs_analysis_base.csv` needs regenerating before bridge work.

## 5. Guardrails (restated)
Recon-first; STOP at Gate 0/A/B. Never discard uncommitted work; never `reset --hard` /
`checkout --` / `stash drop` / `clean`. `fetch` freely; `pull --ff-only` only; never
force-push; never merge to `main` locally (PR via GitHub). renv must not trigger reinstalls
without a STOP. Do not re-run `05`. No AI authorship attribution; leave commits local for
TortoiseGit.

---

### After this lands
Environment is trusted → the **deck/figure refresh** (restyle spec Step 2+) can branch off the
updated `main`: regenerate the PPT asset manifest to post-P1 state, keep bridge figures in the
appendix, build from the reconciled assets + DB, no `05` re-run — stopping at a gate once the
first archetype slides render. Note (not for this task): the biodiversity numbers are the
~250 m / 2004–2020 HCAS vintage; HCAS 3.3 is a parked, post-Aug-10 re-baseline.
