# Tier1F change report — foundation guardrails + rebalance mechanics

Internal review only (not committed). Work done 2026-07-13 preparing for the F5
allocation rebalance + F6 re-run. Two independent branches off `main`, both **held
for review, NOT merged**. The production 100-draw run is **NOT** done — gated on the
Wednesday Adrian sync.

## Branches / PRs

| Branch | Commit | Files | PR (compare) |
|---|---|---|---|
| `feature/tier1f-foundation-guard-validation` | `d725a30` | 10 | `main...feature/tier1f-foundation-guard-validation?expand=1` |
| `feature/tier1f-rebalance-mechanics` | `286100b` | 4 | `main...feature/tier1f-rebalance-mechanics?expand=1` |

Both rebased onto `main`, so each PR shows **only** its own work (the pre-existing
`5efa322` veg-regime tweak from the F7 branch is deliberately excluded; it remains
on `feature/tier1e-f7-groundcover-response`). The two branches touch **disjoint**
files → mergeable in either order.

---

## Branch 1 — foundation guardrails (`d725a30`)

Un-gated reproducibility pre-work. No analysis numbers change.

**New files**
- `R/gayini_inundation_wet_rule.R` — the confirmed wet/valid rule
  `gayini_make_binary_inundation_layers()`, moved verbatim out of the archivable
  pre/post file (B6). Value-3 (cloud) masking verified unchanged.
- `R/gayini_db_validation.R` — `gayini_assert_post_build_objects()` (B4 guard) +
  `gayini_validate_spine()` (shape / 4-class / no-leakage / headline).
- `run_db_validation.R` — runnable DB-state companion to `run_spine_smoke_test.R`
  (which is structure-only); exits 1 on failure.
- `demo_spine.R` — read-only, no-raster ~1s reproduction of the headline
  (9.1/22.3/49.6/44.1) + F7 gradient (0.17/0.26/0.42) from the shipped DB.

**Modified**
- `R/inundation_pre_post_raster_functions.R` — wet-rule fn removed (pointer comment
  left); its aggregation helper retained.
- `scripts/.../internal/05_build_unified_annual_stack_impl.R` — **swapped** to source
  ONLY the neutral wet-rule file (active stack no longer depends on the pre/post file).
- `scripts/.../internal/{01,02,04}_*impl.R` — source the neutral wet-rule file
  alongside the pre/post file (their aggregation helpers still call it).
- `scripts/03_inundation_products/09_build_pixel_census_view.R` — **B3**: acceptance
  gate reads the actual allocation (`sample_summary.csv` `target_n`) and asserts
  `total_points == sum(allocation)` / `strata == n_focus_expected + 2` instead of the
  hardcoded 360/40/9. Also calls the B4 guard as the last post-build step, and records
  `allocation_total` / `n_focus_expected` in `pixel_census_qa.json`.

**Verified** (all passing): guard PASS on live DB + fails loudly naming missing objects
on an empty DB; 5/5 spine checks; demo reproduces headline+F7; B3 gates track a
simulated rebalance (3290) not the stale 360; wet-rule value-3 masking correct; all 10
files parse.

---

## Branch 2 — rebalance mechanics (`286100b`)

Mechanics only; **smoke-validated, not run to production.**

**New files**
- `R/gayini_sampling_allocation.R` — `gayini_stratum_allocation()`: per-stratum
  `target_n` from a documented `budget`/`min_n`/`max_n` (equal or proportional,
  largest-remainder integer). Numbers derived, never hardcoded.
- `R/gayini_monte_carlo_sampling.R` — `gayini_draw_monte_carlo()` (seed loop,
  per-seed ids `SP_<seed>_0001`, per-seed output fan-out) + `gayini_f6_verdicts_for_points()`
  (per-draw F6 wiring reusing the script-07 pipeline).
- `scripts/03_inundation_products/13_run_sampling_rebalance_smoke.R` — 5-draw smoke
  with a PLACEHOLDER proportional allocation (budget=90, min_n=5).

**Modified**
- `R/gayini_stratified_sampling_functions.R` — `gayini_draw_stratified_sample()` gains
  `allocation=` (per-stratum target lookup; `NULL` → old scalar behaviour, backward
  compatible) and `id_prefix=`; fallback keys on the community's largest stratum target.

**Verified**: allocation unit tests (equal=360, proportional sums to budget with min_n
honoured + larger strata larger, cap binds); draw fn backward-compatible; smoke 8/8 —
5 draws, allocation sums to budget, ids unique + seed-namespaced, each draw hits target
(0 shortfall), per-draw F6 wiring returns 9 stratum verdicts.

---

## Generated-but-gitignored artefacts (not committed; under `Output/`)
- `Output/diagnostics/sampling_rebalance_smoke/mc_sample_{points,summary}_seed{1..5}.{gpkg,csv}` — smoke fan-out.
- `Output/reports/db_validation/db_validation_results.csv` — from `run_db_validation.R`.

## Database / state mutations
- **None to any committed artefact.** All DB access was read-only (SELECT/PRAGMA); the
  real `census_stratum` / `stratified_sample_points.gpkg` were **not** rebuilt (script 09
  and the production draw were not run). The B4 guard call now embedded in 09 will fire
  only when 09 is next run.

## Out-of-repo changes (auto-memory)
- Stale fixes: corrected the retired "F2→F9 / F8–F9 probability surface" wording in
  `gayini-headline-occurrence-metric.md` + `gayini-tier1c-sampling-frame.md` (F9 retired;
  F5 background surface IS the flood-probability product).
- Dedup: trimmed the metric contract / CRS-9473 / 4-class / post-build-ordering /
  commit-code-only restatements now owned by CLAUDE.md, from `gayini-headline-occurrence-metric`,
  `gayini-tier0-facts`, `gayini-tier1e-f7-response`, `gayini-tier1-pixel-census`, + MEMORY.md index.

## Explicitly NOT done (held for Wednesday / out of scope)
- **No production 100-draw run** and **no F6 re-run** — gated on the Adrian sync (final
  per-stratum allocation via Q1/Q3a). Allocation numbers in the smoke are throwaway.
- **B5 (archive-convention contradiction) untouched** — human decision with Adrian.
- CLAUDE.md's post-build phrasing (`03 → 05`) vs the verified working order
  (`builder → 05 → 03 → 09`) — flagged in the audit; not edited here.
