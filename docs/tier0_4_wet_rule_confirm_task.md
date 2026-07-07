# Gayini Tier 0.4 — Confirm & document the wet-rule (ORS = wet, cloud masked)

**Task ID:** `tier0.4-wet-rule-confirm`
**Branch:** `feature/tier0.4-wet-rule-confirm` (cut from the merged Tier 0 baseline on `main`)
**Owner model:** Claude Code (agentic, iterative)
**Prepared:** 7 July 2026

---

## 0. Read this first — what this task is (and is NOT)

Adrian has confirmed the wet-rule: **off-river storage (value 2) is counted as wet, the same
as natural inundation (value 1)** — "those pixels were wet just the same." The current Tier
0.1 stack already implements this (its rule is `value > 0`, which counts both 1 and 2), so
**the occurrence numbers are already correct and DO NOT need regenerating.**

This task therefore does **not** rebuild the stack or the database. It does two small things:

1. **Make the wet-rule explicit and robust** — replace the implicit `value > 0` with an
   explicit `value IN (1, 2)` and an explicit mask of **value 3 (cloud shadow)**. This
   changes **zero numbers** for the current Landsat data (the 35 `lo_*.img` sources contain
   no value 3), but it guards against value 3 silently counting as wet if it ever appears —
   notably in the Sentinel-2 layers (Tier 3), which can contain cloud shadow.
2. **Record the decision** so the wet-rule is documented and auditable and never silently
   re-litigated.

> Why bother if the numbers don't change: `value > 0` is a latent trap. The day a value-3
> pixel appears (Sentinel-2 work), it would count as wet with no error. `value IN (1,2)` +
> explicit cloud mask closes that hole now, while it's fresh.

### Confirmed value legend (NSW SEED metadata + Adrian's ruling, 7 Jul 2026)
```
0 = not inundated        -> dry (valid observation)
1 = inundated            -> WET
2 = off-river storage    -> WET   (Adrian: treat same as inundation)
3 = cloud shadow         -> MASK  (failed observation: neither wet nor valid)
```

### Scope guards
- **No stack rebuild.** Do not regenerate `annual_wet_any_1988_2023.tif` /
  `annual_valid_any_1988_2023.tif` unless the verification in 0.4a reveals the current stack
  does NOT already match `value IN (1,2)` (it should — see 0.4a).
- **No database rebuild.** The occurrence numbers are unchanged, so `fact_plot_year` and
  `v_plot_year_analysis_spine` stay as they are.
- Extend existing code; don't rewrite. Confirm paths resolve (`GAYINI_ROOT`, default
  `D:/Github_repos/Gayini`). Branch + PR; human merges; commit code + small docs only.

---

## Step A — Branch

```bash
cd "$GAYINI_ROOT"
git switch main
git pull --ff-only
git switch -c feature/tier0.4-wet-rule-confirm
```

---

## Sub-step 0.4a — Make the wet-rule explicit, and VERIFY it changes nothing

**Goal.** Replace the implicit `value > 0` with an explicit, self-documenting rule
(`wet = value IN (1,2)`; `value 3 -> masked from valid`), and prove it produces an identical
stack to the one already built — so we know the clarification is safe and no numbers moved.

**File:** `scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R`

**Steps**
1. Locate the wet derivation (currently `wet_any = (src > 0)`). Replace with an explicit,
   commented rule:
   - `wet_any  = src %in% c(1, 2)`   # 1 = inundation, 2 = ORS (both wet, per Adrian 2026-07-07)
   - cloud handling: where `src == 3`, set `valid_any = NA` (mask — failed observation).
   - `valid_any` otherwise unchanged; ORS (2) and dry (0) remain valid observations.
   - Branch on presence: do not assume value 3 exists in a given raster.
2. **Verification, not regeneration.** Compute the wet/valid cell counts the *new* rule would
   produce for all 35 years, and compare against the **existing committed manifest**
   (`Output/csv/annual_stack_manifest.csv`). They must match exactly, because for the current
   Landsat data `value > 0` and `value IN (1,2)` are identical (no value 3 present).
   - If they match: the code clarification is safe; the on-disk stack is already correct; do
     **not** rewrite the GeoTIFFs.
   - If they do NOT match: STOP and report — it means value 3 (or some other value) is present
     after all, and the old `>0` rule was miscounting. Do not proceed without flagging.
3. Add a one-line data note to the manifest header/README or the script comment recording that
   the 35 Landsat sources contain values `{0,1,2}` only (no cloud shadow), so the mask is a
   no-op here but active for future Sentinel-2 data.

**Acceptance gate 0.4a (must pass before commit)**
```r
# Recompute counts under the explicit rule from the 35 sources and compare to the committed manifest.
man <- readr::read_csv("Output/csv/annual_stack_manifest.csv")
stopifnot(
  nrow(man) == 35L,
  # the explicit-rule recomputation matches the existing manifest exactly (no numbers moved)
  all(recomputed$n_wet_cells   == man$n_wet_cells),
  all(recomputed$n_valid_cells == man$n_valid_cells),
  # confirm the sources really are {0,1,2} only (mask is a no-op but must be justified)
  all(observed_source_values %in% c(0L, 1L, 2L))
)
message("0.4a gate PASSED — explicit rule verified identical to committed stack")
```
> `recomputed` and `observed_source_values` are produced by the verification in step 2.
> The whole point of this gate is to prove the clarification changed nothing.

**Commit & push**
```bash
git add scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R
git commit -m "Tier0.4a: make wet-rule explicit (wet = value 1|2, mask value 3); verified no change to counts"
git push -u origin feature/tier0.4-wet-rule-confirm
```
> Only the script changes. The stack GeoTIFFs are unchanged and stay gitignored — nothing to
> regenerate.

---

## Sub-step 0.4b — Record the wet-rule decision

**Goal.** Turn the legend confirmation sheet into a decision record capturing Adrian's ruling,
so the wet-rule is documented and auditable.

**File:** `scripts/01_prepare_inputs/03_populate_raster_metadata.R` (+ the emitted report)

**Steps**
1. In `raster_asset` / the catalogue, set `legend_status = confirmed` for the
   `landsat_inundation` family and record the rule in the semantics field:
   `wet = value 1 or 2 (inundation + off-river storage); value 3 (cloud) masked`.
2. Write `Output/reports/legend_decision_record.md` capturing:
   - the confirmed legend (0/1/2/3 meanings, from NSW SEED metadata);
   - **the decision**: ORS (2) counted as wet per Adrian, 7 Jul 2026 ("those pixels were wet
     just the same"); cloud shadow (3) masked;
   - the data note: the 35 Landsat sources contain `{0,1,2}` only, so the cloud mask is
     currently a no-op but is active for Sentinel-2 (Tier 3);
   - the open item: confirm the same legend applies to the Sentinel-2 rasters before Tier 3.
3. Leave `sentinel2_inundation` flagged `needs_legend_check` until confirmed for that family
   (do not assume Adrian's Landsat ruling transfers, though it likely does).

**Acceptance gate 0.4b (must pass before commit)**
```r
ra <- DBI::dbReadTable(con, "raster_asset")
stopifnot(
  all(ra$legend_status[ra$product == "landsat_inundation"] == "confirmed"),
  file.exists("Output/reports/legend_decision_record.md")
)
message("0.4b gate PASSED")
```
> This writes `legend_status` back to the DB (a small in-place update, not a rebuild). If a
> future full DB rebuild wipes it, that is covered by the separate metadata-survival hardening
> task noted below — it is not re-run here.

**Commit & push (then open PR)**
```bash
git add scripts/01_prepare_inputs/03_populate_raster_metadata.R \
        Output/reports/legend_decision_record.md
git commit -m "Tier0.4b: record wet-rule decision (ORS = wet per Adrian; cloud masked)"
git push
# open PR feature/tier0.4-wet-rule-confirm -> main ; do NOT merge (human review)
```

---

## Done criteria for Tier 0.4

- [ ] 0.4a: wet-rule made explicit (`value IN (1,2)`, value 3 masked); recomputation verified
      **identical** to the committed manifest (no numbers moved); sources confirmed `{0,1,2}`.
- [ ] 0.4b: legend confirmed; `legend_decision_record.md` written capturing Adrian's ruling.
- [ ] No stack GeoTIFFs regenerated; no database rebuilt (occurrence numbers unchanged).
- [ ] Short change report written to `docs/change_reports/` (standing convention).
- [ ] PR opened to `main`; **do not merge** — human reviews and merges.

## What NOT to do
- Do not rebuild the stack or the database — the numbers are already correct under Adrian's
  rule. If 0.4a's verification shows a mismatch, STOP and report rather than regenerating.
- Do not apply the Landsat legend to Sentinel-2 without confirmation (Tier 3).
- Do not build trend surfaces or any model — still Tier 1.
- Do not auto-merge or push to `main`.

## If a gate fails
Stop and report observed vs expected. Specifically, if 0.4a's recomputation does **not** match
the committed manifest, that means the sources contain a value the old `>0` rule mishandled
(e.g. a value 3 that was being counted as wet) — flag it to the human before doing anything
else; it would mean the current stack needs regenerating after all.

---

## Note — future hardening task (NOT part of Tier 0.4)

The `legend_status` write in 0.4b (and the CRS/metric_id population from Tier 0.2) are
post-build mutations that a full Python DB rebuild would wipe, because the builder does
`path.unlink()` + rebuild and can't read CRS at build time. The durable fix is to make this
metadata survive a rebuild — fold it into the build sequence or have the builder preserve the
columns. Log as a separate task (`hardening-raster-metadata-survives-rebuild`); do not fold it
into 0.4.
