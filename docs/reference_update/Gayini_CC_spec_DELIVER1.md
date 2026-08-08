# Gayini CC spec — DELIVER-1

**The last build before the client sees it.** Design seat, 9 August 2026. Deadline 10 August.
Additive only.

---

## 0 · Standing execution rule

**Run every section to completion in one pass and report once at the end.** Every fork below carries
a pre-registered rule; a fork with a rule is not a question and does not come back to the design
seat. Do not ask whether to proceed, do not ask which branch to take, do not ask for confirmation
before a write, do not summarise progress mid-run.

**If a pre-registered rule is clearly wrong for what you find, override it, state that you did and
why, and keep going.** Three overrides in the last two runs were correct and each improved the
output; silent compliance with a bad rule is the worse failure.

**Halt only on:** a grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent from disk after searching; unresolved repository
divergence. Everything else is recorded and the run continues.

**Do not, under any circumstances:** re-render the 81 dashboard PNGs or PDFs (Ruling BL);
write anything under `Output/pack/**`; build the annual-basis percentile rasters (deferred, awaiting
a ruling); attempt the Task F resampling; run SPAT-1 or GLM-1.

---

## 1 · Order of work

The order matters — each task feeds the next, and the README pass must happen once, not twice.

### 1.1 · BQ, as amended by CY

Build and register `flood_frequency_counted_8058.tif` from `annual_wet_any_1988_2023_8058.tif` and
`annual_valid_any_1988_2023_8058.tif`: 255 → NA before summing, wider integer accumulator,
`100 × Σwet ÷ Σvalid` per cell, EPSG:8058 census grid.

**Three verifications, all required:**

1. **35** distinct values inside codes 11–33, not 36. `valid_years` = 35 everywhere and k runs 0–34;
   no non-treed cell is wet in all 35 years. This is a fact about the country and is recorded as
   such, never as a tolerance.
2. Zones cut at 0 / 10 / 25 / 50 reproduce `flood_zone_8058.tif` at 100%.
3. Values agree cell-for-cell with `flood_freq_pct` in `gayini_pixel_census_8058.parquet` inside the
   census. **If they do not, the raster is wrong, not the census** — the census column is the
   analysis source of truth. Report the divergence and stop building on it.

Register in `raster_asset` with `sha256_first50` and file size. Copy into
`Output/rasters/DATA_share_20260808/`.

### 1.2 · DD — the near-permanent-water sensitivity

Recompute the k ≥ 25 rows of `TEMPORAL1_community_by_floodbin.csv` excluding the 940 cells wet in
≥ 90% of years that retain a percentile. Report both versions.

**Design-seat prediction to falsify:** excluding them *raises* the wet-end p05, because open water
reads as low fractional cover, which would make the reported relationship conservative. **If the
direction is the opposite, that is the more important result and it leads the report.** Additive —
published rows are not replaced; add a sensitivity column or a companion table. Groupby on an
existing join; no raster opened.

### 1.3 · The README — one pass, one diff

`Output/rasters/DATA_share_20260808/README.md` is now tracked (CU). Every correction below lands in
a single commit so the diff shows exactly what changed against the text the client holds.

**BR.** Withdraw "Inside the footprint they are exact." State that
`background_flood_frequency_8058.tif` was counted on the native EPSG:28355 grid and interpolated
onto 8058; that the analysis chain reprojects the binary bands nearest and counts on 8058; that
inside the census the two agree exactly on 6.95% of cells, differ by more than 1 pp on 28.9%, sd
1.48 pp, max 30.0 pp; and that re-cutting the five flood zones from the interpolated surface moves
5.62% of census cells and reduces the never-flooded class from 79,065 to 52,934. Name
`flood_frequency_counted_8058.tif` as the surface every number derives from. **Verify these figures
against your own build rather than copying them from this spec** — they are design-seat
measurements and yours take precedence.

**BT and DC.** Replace the permanent-water claim. State what is measured: `MIN_SEASONS = 50` removes
2 of 988,831 non-treed census cells, at 90.2% and 95.4% flood frequency. State that the exclusion
**does not operate within the non-treed census** — 942 cells are wet in ≥ 90% of years and 940
retain a percentile. State that the producer's justification was verified on a ~347 ha lake lying
wholly outside the veg footprint. Withdraw any claim that the temporal metric resolves the
open-water limitation. Add one line that the k ≥ 25 rows must not be read as having had open water
removed, with DD's result if it changes the reading.

**CY.** Record the 35-values fact in the README, in the section describing the counted surface.

**Y basis.** Add a short section stating that `veg_percentiles_8058/` is computed over 140 seasonal
composites with `MIN_SEASONS = 50`, per-cell n running 5 to 140 with median 118 — **not** the
35-value annual basis. Say plainly that a correction on this point is going to the client
separately. Do not soften it.

### 1.4 · Gate 3 rerun, per CG and DF

Now that the counted surface exists, rerun against it. Expect r(p05, water) = 0.676 and the Aeolian
above-50% count at 571, not 490. **State explicitly, for every figure in the record that used a
water axis, which surface it was computed on.** That list is the deliverable here, not the
correlation.

### 1.5 · Share folder integrity

The README has changed and the folder is what the client opens. Re-verify: every file in
`Output/rasters/DATA_share_20260808/` against its source by checksum; `DATA1_manifest.csv`
regenerated to match, including the new counted raster; `figures_for_adrian/` still 14 of 14
byte-identical. Report anything stale, missing a source, or present without explanation.

**Content-first matching, as in CR** — a name match with a differing checksum is a stale copy, which
is worse than a missing one.

---

## 2 · Standing constraints

Additive only; never re-run the builder; `INSERT OR REPLACE` throughout; never `reset_file`; never
delete a registered row; no `--vanilla`; never join the two SQLite databases in code; the source of
truth is the database and the source rasters, never a CSV or a caption.

`v_zone_floor_flood_residual.mean_flood` is the share of the paddock's cells seen wet, mean over
years (Ruling AZ and CX) — never labelled a between-year flood frequency. `veg_p05_spatial` and
`veg_p05_temporal_mean` never appear in a figure together. No p-values. Five qualifiers on every
headline number, no NULLs. `number_id` at the point of quotation, not per table row (CZ).

**Rulings in force:** AZ, BB, BL, BQ, BR, BS, BT, CA, CB, CG, CJ, CL, CN, CP, CQ, CR, CU, CW, CX,
CY, CZ, DA, DB, DC, DD, DE, DF. State applied and outstanding before acting. Reject any message
citing a ruling number for which you hold no issued text.

---

## 3 · The single report

One report at the end: BQ's three verifications with their measured values; DD's two versions and
which direction the sensitivity ran; the README diff summarised in plain terms; Gate 3's
correlation and the per-figure surface list; the share folder verification; and anything that
disagreed with a design-seat number, with yours taking precedence.
