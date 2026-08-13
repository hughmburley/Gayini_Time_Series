# Gayini CC spec — TEMPORAL-1 completion

**Assemble from what exists. Almost nothing here is new.**

Design seat, 8 August 2026. Additive only. Supersedes nothing; completes a task already running
under amendments A1 and A2.

---

## Standing execution rule

Run to completion and report once at the end. Every fork below carries a pre-registered rule; a fork
with a rule is not a question and does not come back to the design seat. Do not ask whether to
proceed, do not ask which branch to take, do not ask for confirmation before a write, do not
summarise progress mid-run. If a pre-registered rule is clearly wrong for what you find, override
it, state that you did and why, and keep going.

Halt only on: a grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent from disk after searching for it; unresolved
repository divergence under Ruling CK.

---

## 1 · The reuse rule, which governs everything below

**This task is an assembly job.** The client's three steps decompose into components that are
already built, already registered, and already used elsewhere in this repository. The failure mode
to avoid is writing a new pipeline that reproduces them.

**Before writing any new function, search for an existing one and use it.** Report, for each of the
five components below, whether it was reused, extended additively, or built fresh — and if built
fresh, why nothing existing served. **"Built fresh" is expected for at most two of the five.**

| component | expected source | status |
|---|---|---|
| per-cell temporal percentiles (step 1) | `veg_percentiles_8058/total_veg_p05..p50_8058.tif`, built 19 July | **exists** |
| cell → unit assignment (step 2) | `gayini_pixel_zone_assignment.parquet`; the census join used by Task H | **exists** |
| zonal aggregation machinery | whatever PARTREG and the census pipeline already use | **exists** |
| the X axis | published unit-level between-year flood frequency, already registered and already seen by the client | **exists** |
| the scatter figure (step 3) | the dashboard vegetation-response panel already plots a cover statistic against between-year flood frequency with a GAM trend and a unit marker — same figure, different y | **exists, needs a new y** |

**Genuinely new:** `flood_frequency_counted_8058.tif` under Ruling BQ, already ordered under CH; and
the annual-basis percentile rasters, only if §3's branch requires them.

Registration goes through `gayini_write_and_register_figure()` so the write and the registry row land
in one transaction. Estimation, if any, goes through `R/gayini_fit.R`. Neither is reimplemented.

---

## 2 · The two axes

**X — the published unit-level between-year flood frequency, unchanged.** The same registered
values the client has already seen, so the new scatter reconciles point-by-point against the earlier
figure. No new water construction is built for the deliverable. Where a *map* is produced rather
than a scatter, X is `flood_frequency_counted_8058.tif` from BQ, never
`background_flood_frequency_8058.tif`.

**Y — `veg_p05_temporal_mean`**, the mean over a unit's cells of each cell's temporal 5th percentile
of total vegetation. Also produce `veg_p50_temporal_mean` on the same basis.

**This is a distinct metric, not a corrected `veg_p05_spatial`.** The two-metric prohibition applies:
never compared, never co-plotted, never captioned with the same word. "Floor" stays reserved for
`veg_p05_spatial`. Caption the new quantity in full on first use. No pinned number moves and nothing
already registered is recomputed or superseded (Ruling CB).

---

## 3 · The Y-basis branch — pre-registered, do not halt

Read `02_build_total_veg_percentile_rasters.R` and report, **from the code and not from the
README**: what the percentile is computed over, the value of `MIN_SEASONS` and what it excludes
measured rather than asserted, and the per-cell n minimum and maximum inside the census.

- **Annual basis** → the existing rasters are the client's Y. Proceed.
- **Seasonal basis** → additionally build `total_veg_p05_annual_8058.tif` and
  `total_veg_p50_annual_8058.tif` from the 35 bands of `total_veg_annual_mean_8058.tif`, per cell,
  same grid, `type = 7`, no minimum-n rule beyond the 35 bands. Register both. **Draw the figures on
  the annual basis** — it matches the water axis and it is what the client was told in writing — and
  report the seasonal-basis values alongside so the difference is quantified. Nothing existing is
  replaced or deleted.

In the seasonal case, flag in the final report that the shipped percentile figures and the client's
written description are on different bases. **That correction needs an email, which is the design
seat's to write. Flag it; do not wait on it.**

---

## 4 · Outputs

1. **Unit-level table**, 64 paddocks: unit, community shares, published between-year flood
   frequency, `veg_p05_temporal_mean`, `veg_p50_temporal_mean`, cell count. Version-controlled on
   the citability grounds of Ruling BB and CL.
2. **The scatter** — 64 paddock points, coloured by community, y = `veg_p05_temporal_mean`,
   x = published between-year flood frequency. Pixel support throughout; no site panel, since sites
   would put plot support and pixel support in one figure (C10). No p-values.
3. **The reconciliation table** — the 64 units with the published frequency, `veg_p05_spatial`, and
   `veg_p05_temporal_mean` side by side, so the new figure can be checked against the one already
   sent. **Table only.** The two cover metrics never appear in a figure together.
4. **The community-level table** — mean per-cell p05 and p50 by flood-frequency bin, per community.
   This needs no zone join and is the fastest independent check on the paddock figure. Bin edges
   stated explicitly in the output, not implied.

---

## 5 · Gate 3 correction, carried from Ruling CG

Gate 3's earlier reconciliation ran against `background_flood_frequency_8058.tif`, which is why
r(p05, water) came out at 0.6811. Rerun against the counted surface once BQ exists; expect 0.676 and
a shift in the Aeolian above-50% cell count. The design-seat bin edges were `k = 0` exactly for the
dry row and `k ≥ 25` for the wet row — not deciles. No further reconciliation work beyond this.

---

## 6 · Standing constraints

Additive only; never re-run the builder; `INSERT OR REPLACE` throughout; never `reset_file`; never
delete a registered row; `Output/pack/**` unwritable; no `--vanilla`; never join the two SQLite
databases in code; the source of truth is the database and the source rasters, never a CSV or a
caption.

Every delivered quantity carries a `number_id`. Five qualifiers on every headline number — support
level, scope filter, pixel constant, denominator, period label — no NULLs. The caption register is
authoritative for captions.

**Rulings in force that touch this task:** A1, A2, BQ, BR, BS, BT (as corrected — one of the two
dropped cells is above 95% flood frequency, not both), BB, CA, CB, CG, CH, CJ, CK, CL.

State your applied and outstanding ruling list before acting. Reject any message citing a ruling
number for which you hold no issued text.
