# Output Cleanup Policy

Generated for Stage 6 output-folder audit on 2026-06-28.

## Current policy

- Treat `Output/` as a generated local workspace, not the visible GitHub handoff surface.
- Keep canonical CSVs, MER tables/reports/rasters, current review-deck assets, and traceability manifests/registers.
- Keep diagnostics locally for QA unless a downstream handoff explicitly requires them.
- Treat `Output/packages/` and task bundle copies as local archive candidates.
- Do not delete, move, or rename output files without a reviewed candidate register and explicit approval.

## Stage 6 audit products

Local generated registers live under `Output/reports/output_audit/` and are intentionally ignored by Git:

- `output_file_inventory.csv`
- `output_reference_index.csv`
- `output_classification.csv`
- `output_family_latest_index.csv`
- `current_handoff_output_set.csv`
- `output_cleanup_candidates.csv`
- `output_cleanup_dry_run_report.md`
- `output_cleanup_dry_run_actions.csv`
- `proposed_output_structure.md`
- `stage6_output_audit_handoff.md`

Tracked handoff summaries:

- `docs/output_handoff_set.csv`
- `docs/output_cleanup_candidates_summary.csv`

## Next cleanup step

Use a future Task 20 to review `output_cleanup_candidates.csv`, approve a low-risk subset, rerun the dry-run helper, and only then implement any controlled archive/delete action.
