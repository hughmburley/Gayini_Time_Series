# CLAUDE.md — addendum block

Paste this into `CLAUDE.md`. It replaces nothing; it adds a section and fixes one existing contradiction.

---

## Provenance discipline (added 25 July 2026)

Twelve number discrepancies were found during the T1 cycle (`docs/Gayini_number_provenance_audit.md`). **None came from the database disagreeing with itself.** Every one came from reading a stale copy, opening the wrong object, or asking an underspecified question. These rules exist because the prose versions of them were already present and were violated anyway — including by their own author.

### The database is the authority. Nothing else is.

- **Never establish a fact from a workbook, a change report, a spec, or a prior chat.** Those are renderings. Re-derive from the DB.
- **This includes the DB's own QA and release tables.** A row asserting "98 of 98 raster assets lack CRS/extent", dated 2026-07-01, is still present while all 126 are populated. It misled four separate readers. Read QA verdicts through `v_qa_freshness`, which reports anything older than the newest `workflow_run` as STALE.
- `Gayini_Results_DB_contract_snapshot_*.xlsx` is authoritative for **object existence, schema and row counts**. It is **not** authoritative for QA verdicts. Check the as-of date on the sheet.
- Project knowledge silently corrupts binaries — every byte ≥ 0x80 becomes the UTF-8 replacement character. `.sqlite`, `.parquet` and `.gpkg` cannot live there. `.xlsx` and `.md` survive. That is why the snapshot workbook exists.

### No number travels without five qualifiers

1. **support_level** — pixel · paddock · stratum · property · plot · zone_month
2. **scope_filter_sql** — the literal filter, e.g. `treed_context_flag = 0 AND regime_band <> 'context'`
3. **pixel_area_ha** — the constant used
4. **denominator_ha** — mapped 67,349.332 or true farm 85,910.8
5. **period_label** — `1988-2023` or `post_conservation` or similar

Store them as columns, never as prose. Eight of the twelve discrepancies would have been caught on sight.

### Constants come from `gayini_params`, never from a literal

`R/gayini_params.R` and `scripts/lib/gayini_params.py` are the only place a project constant may appear. `PIXEL_AREA_HA` is **derived** from `PIXEL_SIDE_M`, never typed. A smoke-test lint fails the run on a bare `0.0625`, `0.062351428`, `24.970268`, `67349`, `85910`, `1080157`, `988831` or `993782` anywhere else.

**`0.0625` is wrong.** The census grid is 24.970268 m → `0.062351428` ha/px. The 25 m nominal inflates every area by 0.238% and has already contaminated one spec and one manuscript figure.

### Scope: nine strata, not ten

`treed_context_flag = 0` **alone admits ten strata** — it lets `Other / minor units` in (4,951 px, 308.7 ha). Non-treed means `treed_context_flag = 0 AND regime_band <> 'context'` (988,831 px).

### Registration: `INSERT OR REPLACE`, never `OR IGNORE`

`OR IGNORE` does not error and does not duplicate, so it looks idempotent — but it never updates a changed checksum. That makes the acceptance test *"re-run twice, identical checksums"* **pass while the DB is wrong**. The existing `register_taskM_gateC_assets.py` template uses `OR IGNORE`; do not propagate it.

**Idempotence is tested by convergence, not stability.** Mutate an input, re-run, confirm the DB moves to the new checksum. A test that only checks stability cannot distinguish converged from frozen.

### One checksum convention

First-50-MB SHA-256 (`50*1024*1024`, 1 MB chunks), as in `sha256_first50()`. The R registrars' whole-file `digest::digest(algo="sha256")` is a **different** convention and must not be used for asset registration — including in `write_and_register_figure()`.

### Figures: write and register in one transaction

~330 figures went unregistered because every path wrote in R and registered later in Python, so the two steps could land in different sessions. **R owns both halves** via `write_and_register_figure()`. `register_taskM_gateC_assets.py` remains the template for rasters and parquet.

`figure_asset` carries `support_level` and `figure_level`. Every caption states the support level.

### Spatial layers: read through the registry

Use `read_registered_layer(layer_name)`, which resolves the path from `spatial_layer_asset`, asserts the CRS, and compares the file's actual fields to the registered `field_list`. Two zone layers exist and they differ:

| | `management_zones_8058` | `Gayini_Results.gpkg:management_zones` |
|---|---|---|
| CRS | EPSG:8058 — **the input** | EPSG:28355 — map companion |
| Fields | `ManagmentZ, Area_MW, Treatment, Plots` | `management_zone, treatment, plots` |
| Text | clean | NUL-padded |

A spec once declared `Area_MW` non-existent after inspecting the wrong one.

### Every check must be able to fail

`scripts/archive/` does not exist, so the smoke test that validates the `scripts/archive/` convention passes vacuously. **A green test that cannot fail is worse than a red one**, because nobody looks at it again.

When you add a check, prove it fires on a deliberately broken fixture and record the failure output in the change report.

### Support levels are never merged

Results at different supports are not plotted together, not compared numerically, and not summed. A view combining two supports must set `support_level = 'mixed'` and carry a `mixed_support_note`. The `9 / 22 / 50 / 44` flood-frequency gradient reached the spine labelled "Support: stratum, pixel" while being plot-support, post-period — that is the failure this rule prevents.

Plot support and pixel support can invert: Task J's "two placebos beat 2018" at plot support became rank 2 of 25 at pixel support.

---

## Correction to an existing rule

The current text says change reports stay local and uncommitted. **That is superseded.** Change reports go in `docs/change_reports/` and are **committed**. They are the cross-session memory that replaces a database too large to carry in project knowledge. Keep them short: what changed, what the numbers were, what is still open.

---

## Git — deliberately minimal (2.5-week deadline, single operator)

Direct commits to `main`. No branch, no PR. Review happens at the STOP points. No AI attribution in commit messages. Do not spend time on history tidying or rebases.

**Not relaxed:** additive-only, never re-run the builder (`reset_file` destroys 12 unreproducible Task H rows), idempotence, paths from the DB.
