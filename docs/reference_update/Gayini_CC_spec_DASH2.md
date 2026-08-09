# Gayini CC spec — DASH2

**Same dashboard, corrected inputs.** Design seat, 9 August 2026. Additive only.

---

## 0 · Standing execution rule

**Run to completion in one pass and report once at the end.** Every fork carries a pre-registered
rule; a fork with a rule is not a question. Do not ask whether to proceed, do not ask which branch to
take, do not ask for confirmation before a write, do not summarise progress mid-run.

**If a pre-registered rule is clearly wrong for what you find, override it, state that you did and
why, and keep going.**

**Halt only on:** a grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent after searching; unresolved repository divergence.

**Ruling BL is untouched.** The 21 existing `D1_paddock_*_slide_data` sheets and their PDFs are **not
re-rendered**. This is a new product, `D1v2_paddock_*`, written alongside them. Nothing existing is
replaced, deleted or superseded.

---

## 1 · The design does not change

The existing layout is correct and the client is used to it: locator inset, checkerboard map,
"Where it sits" boxplot, baseline gauge, annual flooding panel, cover panel, vegetation-response
panel. **Reuse `gayini_dashboard_panels.R` and `gayini_dashboard_compose.R` — extend additively, do
not reimplement.** Panel geometry, fonts, palette and arrangement stay as they are.

One data swap and five labelling fixes, below. Nothing else.

---

## 2 · The data swap — the cover panel

**Current:** mean `total_veg_pct` over the monitoring plots inside the paddock, seasonal
(~140 points), from `v_plot_timeseries_groundcover`. **A few hectares of plots against a few
thousand hectares of water panel, on a shared x-axis.** That is the C10 defect in substance, and it
is why relabelling alone will not do.

**Replacement:** the paddock's census cells, aggregated from
`Output/tables/PARTREG_part_year_floor_inund.csv` — area-weighted across the paddock's parts, one
value per water year, `veg_p50_spatial`. Label it **"Typical ground cover (green + dead)"**, subtitle
stating it is measured across every census cell in the paddock.

**The water panel is redrawn on the same cells.** Currently it is all valid pixels in the polygon;
it becomes `inund_pct` aggregated the same way, so both panels describe identical ground. **This will
move the printed 35-year means** — Bala 29ca's 10% among them. That is the correction, not a defect;
report the before-and-after for every paddock rendered.

**Do not draw `veg_p05_spatial` in this panel.** Ruling BX stands: the client asked for cover, the
median is what a lay reader means by it, and the floor carries the small-n exposure at part grain.

**If a paddock has parts covering less than 60% of its census cells**, render it anyway and state the
covered share in the subtitle. Do not silently show a partial paddock as if it were whole.

---

## 3 · The five labelling fixes

1. **Annual flooding panel** — title *"How much of the paddock went under water each year"*, y-axis
   *"Share under water (%)"*, and the parenthetical *"(wet / valid years)"* deleted. The plain-English
   half of the current subtitle is correct and stays.
2. **"Where it sits" boxplot** — y-axis *"Share of cells wet, mean over years (%)"* per Rulings AZ
   and CX.
3. **Vegetation-response panel** — **verify what the x-axis actually is before relabelling.** The
   footnote says *"Pixel census, between-year flood frequency (24.97 m); marker = mean over the
   unit's census pixels"*, which describes per-cell `flood_freq_pct` from the census parquet — a
   genuine between-year frequency, correctly labelled as it stands. **If that is what it draws, leave
   the x-axis alone.** Only if it draws `mean_flood` does it get the AZ/CX relabel. Report which.
4. **Baseline gauge** — same relabel as (2).
5. **Checkerboard map** — footnote that the wetness bands are per-community terciles cut on the
   interpolated flood-frequency surface, that this was the only route to balanced strata, and that
   4.9% of cells change band under the counted surface. Per Ruling DQ, frame it as a documented
   trade-off, not an error.
6. **Remove the Kruskal-Wallis p-value** from the "Where it sits" panel. No p-values anywhere, and
   the "(descriptive)" qualifier does not exempt it. Replace with nothing — the boxplot shows the
   separation without a test.

---

## 3a · The vegetation-response panel already answers the client's three steps

Worth stating plainly, because it changes what this panel needs. Grey = census cells; y = each
cell's temporal percentile; marker = the mean of those over the unit's cells. That is *calculate
temporal percentiles per pixel, average per area, plot against inundation* — already built, already
on every sheet. Two corrections, both small.

**State the basis.** The per-cell percentile is computed over **140 seasonal composites**, not 35
annual values, with per-cell n running 5 to 140. The y-axis must not read as a bare slug: use
**"Cover in the poorest seasons (%)"** and state the seasonal basis in the footnote. This is the
same correction going to the client by email, and the two must agree.

**Fix the scope statement.** The marker is drawn on the dominant community only — on Bala 29ca that
is 33% of the paddock, and the panel does not say the other 67% is absent. **Pre-registered choice:
draw one marker per community present above 10% share**, which makes the mixed-community case
visible rather than hidden and is the clearest available answer to why a fence line is not an
ecological boundary. If that is unreadable at this panel size, fall back to the single marker with
*"shown on <community> — N% of this paddock; the rest is not in this panel"* on the panel face, and
report which you did.

**`support_level` is populated on every registered row** — pixel throughout. The five qualifiers
travel with each sheet. No NULLs.

---

## 4 · Which paddocks

**Six, in this order:** Bala 26ca, 28ca, 29ca — the conserved units the client already holds — then
Bala 22, Bala 6 and Dinan 9, which span the wet-to-dry range and give him contrast if he wants it.

If all six render clean, **continue to all 21** paddocks that have an existing sheet. That is the
same producer with the same inputs and needs no further ruling.

---

## 5 · Standing constraints

Additive only; never re-run the builder; `INSERT OR REPLACE`; never `reset_file`; never delete a
registered row; `Output/pack/**` unwritable; no `--vanilla`. Registration through
`gayini_write_and_register_figure()` in one transaction. Estimation, if any, through
`R/gayini_fit.R`. No p-values. `veg_p05_spatial` and `veg_p05_temporal_mean` never appear together.
`number_id` at the point of quotation, not per row (CZ).

**Any edit containing an escape sequence, a newline, or a multi-line quoted string is written to a
file and applied from that file — never through a shell heredoc** (Ruling DS). Parse-check before
rendering.

**Rulings in force:** AZ, BB, BL, BX, CX, CZ, DA, DB, DQ, DS. State applied and outstanding before
acting.

---

## 6 · The report

`Output/runs/RUN_DASH2_20260809.md` under the DP schema: decisions needed; checks with measured
values; overrides; disagreements; artefacts with registry rows and checksums; not done; rulings.

**Two checks are required before any sheet is registered.**

**One table:** for every paddock rendered, the printed 35-year water mean before and after the
cell-set change, and the census coverage share. That table is how the client's question — *why does
this number differ from the sheet you sent me* — gets answered without rework.

**One equality:** the cover panel and the flooding panel must draw on the **same cell set** for every
unit. Report the count each uses; they must match exactly. This is the check that proves the C10 fix
landed rather than being asserted. If they differ for any unit, that unit is not registered and is
reported by name with both counts.
