# Gayini CC spec — EXEMPLAR-1

**Find what already answers the client, then close the small gap.**

Design seat, 8 August 2026. Deadline 10 August. Additive only.

---

## 0 · Why this task exists

The client changed his ask twice today. His words, verbatim, in order.

**4:39 PM** — the three steps:

> *"I'm struggling to work out how we can use the relationship between inundation and 'cover in the
> poorest patches'. I agree with your main point 'wetter country has more vegetation cover in its
> barest patches'. But I'm not sure that maps of the residuals are a good idea, as they are colouring
> large areas by values calculated from the barest areas.*
>
> *- Calculate temporal percentiles of cover for each pixel.*
> *- Calculate averages of percentiles for each area.*
> *- Plot percentiles vs inundation*
>
> *Have you done it this way?"*

**4:53 PM** — after the axes were explained, he stepped back:

> *"To be honest, I'm not sure what I think is best. It is very complicated, and I'm struggling to
> come up with a simplification that is still useful. I think it might be better I just concentrate
> on showing examples of areas with different veg cover and inundation time series."*

**And earlier, 4:39 PM, on what he wants to show:**

> *"I think you have made figures showing inundation and vegetation cover over time. For certain
> sites, or maybe for paddocks or vegetation community types. I cant find them, but I'd like to
> include some examples."*

Two things follow, and the task rests on both.

1. **The Monday deliverable is example units, not a scatter.** Contrasting areas, each showing
   cover over time and water over time, in language a Tribal Council audience reads without
   training.
2. **The per-pixel work is not cancelled.** His 4:39 reasoning about per-cell statistics stands on
   its own merits and he has not withdrawn it — he withdrew from the *complexity*, not from the
   idea. TEMPORAL-1 continues under amendment A1/A2 and is expected to land regardless.

**The suspicion this task tests: the existing dashboards may already be 80% of what he wants, and
the missing 20% may be labelling and selection rather than analysis.** Establish that before
building anything.

---

## 1 · Design-seat findings — predictions to check, not facts

Computed at the design seat on the shared rasters. **CC's independently computed values take
precedence wherever they disagree.**

- The client's step 3 reproduces the published finding at pixel support. Mean of each cell's
  35-year p05, by community, against between-year flood frequency: Inland Floodplain rises
  **37.9 → 77.1** across the flood-frequency range while the median rises **74.3 → 88.7**, and the
  median-minus-floor gap falls **36.4 → 11.3**. Riverine behaves the same way. **Aeolian is
  non-monotone** — it rises to roughly 35% flood frequency and then declines, on thin support
  (511 cells above 50%).
- Whole-census correlations: **r = 0.676** floor against water, **r = 0.566** median against water.
- `MIN_SEASONS = 50` removes **2 cells** of 988,831 inside the census. Both sit above 95% flood
  frequency, so the mechanism is real, but the extent is negligible. See Ruling BT.

---

## 2 · Gate 0 — recon, no writes

**Search the repo and `Output/` for anything that already pairs a cover time series with a water
time series for a named unit.** Report, do not build.

Suggested starting points, not a closed list: `gayini_dashboard_panels.R`,
`gayini_dashboard_compose.R`, `T2_gateE_figures.R`, the `U2_*` producer, `J-F4`'s producer,
`Output/figures/dashboards/`, `Output/figures/`, and any `D1_`/`D2_`/`D3_` family member.

For each candidate report:

| field | what to record |
|---|---|
| producer script and line range | where the panel is drawn |
| unit grain | site / paddock / stratum / community / whole property |
| support | plot or pixel — and which, explicitly |
| what the water panel actually computes | the expression, not the label |
| what the cover panel actually computes | the expression, not the label |
| registered? | `figure_asset` row, or absent |
| label defects | against Rulings AY/AZ/AZ-a and the fourth instance |
| how many units it exists for | count, verified against `dim_plot` / zone list both directions |

**Then answer one question in plain terms: what is the smallest change that turns an existing
product into the thing the client described?** If the answer is "extract two panels and relabel
them", say so. If it is "nothing existing fits", say that instead and give the reason.

**STOP and report. No writes, no registration, no commit.**

---

## 3 · Gate 1 — the exemplar figure

Contingent on Gate 0. Build only after the design seat rules on the Gate 0 report.

**Shape, unless Gate 0 shows a better existing candidate:** one unit per figure, two stacked panels
sharing a water-year x-axis — vegetation cover above, water below — plus a one-line locator so the
reader knows where on the property they are.

**Labelling is the substance of this task, not the trim.**

- The water panel is **"How much of the paddock went under water each year"**. Not "flood
  frequency". Not "wet / valid years". The quantity is a share of ground measured within each year.
- The cover panel is **"Total ground cover (green + dead)"**. Not "green cover".
- **No internal version stamps, no `veg_p05_spatial`, no `fit_id`, no metric slugs on the face.**
- One statistic per panel at most. Nuance goes in a note, not a headline.
- Where a panel shows the cover floor, name it in words — *cover in the poorest patches* — and do
  not use the word "floor" as if it were self-explanatory.

**Provenance rules unchanged.** R, not matplotlib. `gayini_write_and_register_figure()` so the write
and the registry row happen in one transaction. Every figure registered before it is shared.

---

## 4 · Gate 2 — which units

The client asked for **"areas with different veg cover and inundation time series"**. The selection
is the analysis here; a well-chosen set of units *is* the result.

**Proposal, to be checked against the data rather than assumed:** within each of the three
communities, one dry unit, one mid unit and one wet unit, chosen on between-year flood frequency
using the published unit-level values. Nine figures. Report the chosen units and their frequencies
before rendering, so the contrast can be seen to be real.

**Constraints on selection:**

- Do not mix plot support and pixel support in one figure, or across a set presented as comparable
  (C10). If unit-level cover comes from plot measurements, every unit in the set must have plots.
- Bala 27ca has no plots and cannot carry a plot-built cover panel. If the set is plot-built, say so
  and exclude it explicitly rather than silently.
- Prefer units that already have a sheet, so the work is extraction and relabelling rather than a
  new build.
- Record for each unit: support level, scope filter, pixel constant, denominator, period label. No
  NULLs.

---

## 5 · Gate 3 — the per-pixel work, held behind the above

TEMPORAL-1 is already running under amendments A1 and A2 and **must not be duplicated here.** If
Gate 0 finds code that would do the same thing, report it and stop — do not run it.

When the exemplar set is shipped and if time remains, the per-pixel deliverable follows in this
order: the community-level table of mean per-cell p05 and p50 by flood-frequency bin (no
management-zone join needed, fastest independent check), then the paddock-level scatter.

---

## 6 · Standing constraints

Unchanged and not restated as new: additive only; never re-run the builder; `INSERT OR REPLACE`
throughout, never `INSERT OR IGNORE`; never `reset_file`; never delete a registered row;
`Output/pack/**` unwritable; no `--vanilla`; no package installs while another R session is live;
never join the two SQLite databases in code; the source of truth is the database and the source
rasters, never a CSV or a caption; `Output/` is the record and `docs/` is never a result.

**Never compare or co-plot `veg_p05_spatial` and census `veg_p05_mean`.** Condition and cover are
both Landsat-derived and circular; inundation is the only permitted independent axis. No p-values
on annual series. Between-unit and within-unit slopes are never versions of one number.

**Rulings in force that touch this task:** BE (the 10 vs 15.9 scope check), BK (index rewrite),
BL (fourth AY/AZ instance is warn-and-leave), BM (code comments), BN (stratum dashboards),
BQ/BR/BS (counted flood-frequency surface and README), BT (permanent-water claim).

**Confirm receipt of this spec and state your applied and outstanding ruling list before acting.**
Reject any message citing a ruling number for which you hold no issued text.

---

## 7 · Halt conditions

Ruling AX applies — run to completion and report once — except at the Gate 0 stop, which is
mandatory, and at these two:

1. **Halt if Gate 0 finds that an existing shipped figure computes something other than its label
   says, beyond the four AY/AZ instances already known.** Report; do not fix in place.
2. **Halt if the exemplar selection cannot be made without mixing plot and pixel support.** Report
   the conflict rather than choosing.
