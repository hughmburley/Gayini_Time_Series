# Stage 4 spine runner handoff

Generated: 2026-06-27

## Outcome

The active Gayini script tree is now grouped into logical folders and numbered sequentially within each folder. The root smoke runner validates structure, key inputs/outputs, helper sourcing, active R script parsing and heavy-workflow safety metadata without running extraction or raster builds.

## Main entry points

- Smoke test: `run_spine_smoke_test.R`
- Run order guide: `docs/run_order/README.md`
- Full rebuild metadata: `docs/run_order/01_full_rebuild_workflow.csv`
- Lightweight review refresh metadata: `docs/run_order/02_lightweight_review_refresh.csv`
- MER workflow metadata: `docs/run_order/03_mer_workflow.csv`

## Safety notes

- Heavy extraction steps remain explicit-run only.
- MER production raster build remains `scripts/06_mer/07_build_mer_annual_max_rasters.R`, marked heavy and not default.
- No biodiversity scripts were changed.
- Historical implementation scripts remain under `scripts/archive/`; active wrappers now point at the archive where needed.
- Package scaffold is intentionally lightweight and local; full package conversion remains future work.

## Verification

- Spine smoke test: pass, 68 checks, 0 failures, 0 warnings.
- Helper scaffold tests: pass, 15 tests.
- Python MER methods-note syntax: pass.
- PowerShell QA helper parse: pass.
- Git whitespace check: pass.
