# Tier 0.4 — change report

**Task:** `tier0.4-wet-rule-confirm` — confirm & document the wet-rule (ORS = wet, cloud masked)
**Branch:** `feature/tier0.4-wet-rule-confirm` (cut from updated `main` `bdd7734`; pushed to origin; PR to `main` pending, do-not-merge)
**Date:** 2026-07-07
**Commits:** `0fadf6a` (0.4a) → `b266214` (0.4b)

Both acceptance gates passed. This was a **confirm-and-document** task: no stack rebuild, no
database rebuild — the occurrence numbers were already correct under Adrian's rule and are
**unchanged**.

---

## Outcome in one line

Adrian's ruling — **off-river storage (value 2) counts as wet, cloud shadow (value 3) is
masked** — was made explicit in code, **verified to move zero numbers**, and recorded as a
durable decision record with `legend_status = confirmed`.

---

## Setup deviation (surfaced before any change)

Step A said to branch from "the merged Tier 0 baseline on `main`", but at task start local
`main` (`0da0bfb`) did **not** contain Tier 0. Confirmed with the user that `origin/main` had
the Tier 0 merge (`bdd7734`); pulled it and cut `feature/tier0.4-wet-rule-confirm` from the
updated `main`. Two further spec/reality gaps were flagged and resolved inline (see each
sub-step).

---

## Sub-step 0.4a — make the wet-rule explicit · commit `0fadf6a`

**Where the rule actually lived.** The task pointed at `05_build_unified_annual_stack_impl.R`
(`wet_any = (src > 0)`), but that script only *calls* the wet derivation. The rule lives in
`gayini_make_binary_inundation_layers()` — so the change was made in its natural home.

- `R/inundation_pre_post_raster_functions.R` — **+18/-2**: the `landsat_inundation` branch
  changed from the implicit `x > 0` to an explicit, documented legend:
  `wet = value IN (1,2)`, `valid = value IN (0,1,2)`, value 3 (cloud shadow) excluded from
  both. Vectorised `%in%` needs no branch on whether value 3 is present.
- `scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R` — **+9/-2**:
  header "Wet rule" note updated to the explicit legend + data note (sources are `{0,1,2}`
  only; mask is a no-op for Landsat, active for Sentinel-2).

**Verification (the point of 0.4a).** A read-only harness re-ran the exact build pipeline
(CRS assign → new explicit rule → 25 m nearest-neighbour resample → cell counts) for all 35
water years — **writing no GeoTIFFs** — and compared to the committed
`annual_stack_manifest.csv`:

- **All 35 years identical** — zero rows diverge. The clarification moved no numbers.
- Native source values confirmed **`{0,1,2}` only**. The `160` that first appeared was a
  colour-table artifact: several `.img` files are categorical with an RGB colour map, and
  value 2's swatch is purple = RGB(160,32,240); `terra::freq()` reported the Red channel, not
  the cell value. Reading the underlying numeric resolved it.

Because counts match, the on-disk stack is already correct — **no GeoTIFFs regenerated**.

**Gate 0.4a:** PASSED (35 rows; recomputed == manifest for wet & valid; sources ⊆ {0,1,2}).

---

## Sub-step 0.4b — record the decision · commit `b266214`

**Schema reality.** `raster_asset` had no `product`/`legend_status` columns and holds *derived*
outputs; the raw `{0,1,2,3}` legend + `product` family live in the catalogue on the 35 *source*
rasters. Recorded the confirmation in both places.

- `scripts/01_prepare_inputs/03_populate_raster_metadata.R` — **+86/-9**:
  - **Catalogue** (`data_intermediate/raster_catalog/raster_catalog.csv`): `landsat_inundation`
    (35 sources) → `legend_status = confirmed`, `needs_legend_check = FALSE`, dropping it from
    the legend-confirmation sheet. `sentinel2_inundation` (247) left `needs_legend_check` for
    Tier 3.
  - **`raster_asset`**: added `product` / `legend_status` / `legend_semantics` columns; 33
    landsat inundation assets → `legend_status = confirmed` with the rule in `legend_semantics`;
    67 MER assets labelled `mer_inundation` (own family, not confirmed here).
  - Publishes the decision record to `Output/reports/legend_decision_record.md`; refreshed the
    Adrian legend sheet's notes.
- `docs/tier0_legend_decision_record.md` — **new (+82)**: the durable, tracked decision record
  (confirmed legend, Adrian's ruling, 0.4a evidence, the Sentinel-2 open item, durability
  caveat).

**Gate 0.4b:** PASSED (all `landsat_inundation` assets `legend_status = confirmed`;
`legend_decision_record.md` exists).

---

## Committed vs. runtime state

**Committed to git** (Output/, database, catalogue are all gitignored — code + tracked docs
only):

| Commit | Files |
|---|---|
| `0fadf6a` | `R/inundation_pre_post_raster_functions.R`, `…/05_build_unified_annual_stack_impl.R` |
| `b266214` | `scripts/01_prepare_inputs/03_populate_raster_metadata.R`, `docs/tier0_legend_decision_record.md` |

**Runtime mutations (not committed; wiped by a full rebuild):** the catalogue CSV and
`raster_asset` legend columns. Re-running `03_populate_raster_metadata.R` restores them. Their
durable source of truth is `docs/tier0_legend_decision_record.md`.

---

## Done criteria

- [x] 0.4a: wet-rule explicit (`value IN (1,2)`, value 3 masked); recomputation **identical** to
      the manifest (no numbers moved); sources confirmed `{0,1,2}`.
- [x] 0.4b: legend confirmed; `legend_decision_record.md` written capturing Adrian's ruling.
- [x] No stack GeoTIFFs regenerated; no database rebuilt.
- [x] Change report written.
- [ ] PR opened to `main` — **human reviews and merges** (do not auto-merge).

## Follow-ups (logged, not part of 0.4)

- `hardening-raster-metadata-survives-rebuild` — make the catalogue/`raster_asset` legend +
  CRS/metric_id metadata survive a full DB rebuild (currently post-build mutations).
- **Sentinel-2 legend** — confirm the value legend / wet rule for `sentinel2_inundation` with
  Adrian before Tier 3; do not assume the Landsat ruling transfers.
