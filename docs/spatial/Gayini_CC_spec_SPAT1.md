# Gayini CC spec — SPAT-1

**Measure the thing every figure in this project asserts.** Design seat, 10 August 2026.
Additive only.

---

## 0 · Standing execution rule

Run each stage to completion and report once per stage, in the `RUN_` schema of Ruling DP.
Every fork carries a pre-registered rule; a fork with a rule is not a question. Do not ask before
writing. If a rule is clearly wrong for what you find, override it, state that you did and why, and
keep going.

Halt only on: grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent after searching; unresolved repository divergence; a
quantity that will not reproduce. An expected commit named in a brief is a prior to report against,
not a gate.

**One STOP, after Stage A.** Stage B's interpretation depends on what the variogram returns.

**No client clock.** This is methods work.

---

## 1 · Why this exists

Every figure this project has produced carries a version of the same sentence: *intervals are display
only*; *~1M pixels is sampling uncertainty, not independent n*; *neighbouring patches may share
conditions, so the band is if anything too narrow*.

**Every one of those is an assertion. None has been measured.** That is I-40 at the scale of the
whole project, and it is the first thing a reviewer will stop on.

Two things follow, and they are different questions:

**How far does spatial structure reach?** If residuals decorrelate over 100 m, the analysis units are
effectively independent and the intervals are roughly honest. If they decorrelate over kilometres,
the effective sample size collapses to tens and every interval in the project is far too narrow.
**We do not know which, and one number settles it.**

**Does the relationship hold across grain, or only across the three unit types we happened to
build?** The paddock-grain line (+0.547838) and the part-grain line (+0.547274) differ by 0.0005
across a roughly fifteen-fold change in unit size — a striking result, but paddocks, parts and tracts
differ in **size and in how they were drawn** at the same time. A regular grid varies size while
holding construction constant, which is the only way to separate them.

---

## 2 · Metric, fixed for the whole task

**`veg_p05_temporal_mean` throughout. `veg_p05_spatial` does not appear in this task at all.**

The reason is structural, not preference. The spatial floor is a quantile **across** a unit's cells,
so its meaning changes as the unit changes size — on a scale ladder that is not a confound to
measure, it is a definitional change that makes the ladder meaningless. The temporal metric is a
per-cell value averaged over whatever cells the unit contains, so **the same quantity exists at every
rung, including the pixel.**

This is the first task in the project where the choice between the two metrics is forced rather than
argued.

---

## 3 · Stage 0 — the registered fit on the temporal metric

There is no registered line on this metric. PARTSCATTER's and UNZONED's curves are display smoothers
and no coefficient may be taken from one, so residuals cannot currently be computed against anything.
**Stage A needs residuals. Build the fit first.**

**Grain: the pixel census.** One row per non-treed census cell.

- **y:** that cell's temporal 5th percentile of total vegetation cover.
- **x:** that cell's counted between-year flood frequency, `flood_freq_pct`.
- **Form:** OLS, one fit **per vegetation community**, unweighted (each cell is one observation).
  Pooled is additionally reported and **labelled as composition-bearing** — DB and the PARTSCATTER
  finding both apply: a pooled line is lifted by differences between communities as much as by
  response within them.
- Additionally fit and register a GAM of the same form per community, for shape. The OLS line is the
  registered expectation used for residuals; the GAM is reported alongside and **not** used to
  compute residuals in Stage A, so the residual field carries no smoother's flexibility.

**Register the coefficients — slope, intercept, r, residual SD, n — and deliberately withhold any
interval.** An interval at pixel grain before Stage A would be the exact error this task exists to
correct. Write `interval_pending_spat1_stage_a` in the interval columns rather than a number, and
state the reason in the coefficient table. **Stage A supplies the effective n; the interval is
computed then and not before.**

**Report** the fitted lines against the display smoothers they replace — do they agree in the region
where both are supported? If they diverge materially, the linear form is inadequate and that is a
finding to report, not to fix by switching forms.

---

## 4 · Stage A — how far spatial structure reaches

### 4.1 · The residual field

Residuals from Stage 0's per-community OLS, at pixel grain, with coordinates from the census parquet.
One residual per non-treed cell, EPSG:8058.

### 4.2 · Empirical variogram

Per vegetation community, on the residuals.

**Subsampling is required and its stability must be shown, not assumed.** A full variogram over
~1M points is not computable. Draw random subsamples of 10,000 cells, compute the empirical
variogram, and **repeat 10 times with different seeds**. Report the range across the ten runs, not
a single fit. If the estimated range varies by more than a factor of two across seeds, the estimate
is not stable — say so and report the spread rather than a number.

- **Lag binning:** to a maximum distance of at least 20 km, so the ladder's top rung (4 km) sits well
  inside the measured range of the variogram itself.
- **Fit** spherical and exponential models; report both and the better-fitting one, with **nugget,
  partial sill and range** for each.
- **The headline is the range** — the distance at which residuals stop covarying.

### 4.3 · Anisotropy

This is a floodplain and water moves along paths. **Directional variograms at 0°, 45°, 90° and
135°**, same procedure. Report whether the range differs materially by direction and in which
direction it is longest.

**If it is strongly anisotropic, say so and do not average it away.** A single isotropic range on
directional country would understate structure along the flow direction and overstate it across.

### 4.4 · Effective sample size — the number this task exists to produce

From the fitted range, compute an effective independent sample size for each community and for the
analysed area as a whole, by a stated method (Clifford–Richardson or Dutilleul; name which and cite
it in the run report). Report **n, n_eff, and the ratio** for:

- the pixel census
- the 100 paddock × community areas
- the 39 unzoned tracts
- the 64 paddocks

**Pre-registered reading, recorded before the variogram is seen:**

- **If the range is under ~250 m**, the analysis units are large relative to the structure, the
  existing intervals are roughly honest, and the caveat on every figure can be replaced by a measured
  statement.
- **If the range is between ~250 m and ~2 km**, the pixel-grain intervals are badly too narrow but
  the unit-grain intervals are defensible. Report which figures are affected and by roughly how much.
- **If the range exceeds ~2 km**, the unit-grain intervals are also too narrow, `n_eff` at part grain
  may be in the tens, and **that is a finding that changes how every interval in the project is
  reported.** Report it plainly and do not soften it.

**No result is adjusted toward any of these. They are predictions to check.**

### 4.4.1 · The effective n is pinned, not written down

**Ruling ER applies with unusual force here.** Three rulings in this project — EP, EQ and EI — record
the same failure independently: the registry held the right value and the prose drifted from it. That
makes prose the least reliable layer this project has, and the effective sample size is about to be
quoted in prose more often than any number the project has produced. Every interval statement from
here rests on it.

**So it does not live in a findings note.** Pin each effective sample size in `dim_headline_number`
with a `number_id`: one row per unit set per community, plus the analysed-area total. The caveat
carries the method by name, the fitted range it derives from, the model form, the ten-seed spread,
and the maximum lag beyond which the range is not extrapolated (EN).

Any interval computed anywhere in this project from these numbers **cites the `number_id` at the
point of quotation** (CZ). A figure that widens an interval on the basis of an effective n and does
not name which one is not traceable.

### 4.5 · What Stage A must not do

**No interval is widened, no estimate is corrected, no figure is re-rendered in this stage.** Stage A
produces a measurement of structure and an effective n. What is done with them is a design-seat
decision after the STOP.

**No cause is attributed.** A range is a distance over which residuals covary. It is not soil, not
position, not management.

---

## 5 · STOP

Report Stage 0's coefficients, Stage A's ranges by community and direction, the effective sample
sizes with their ratios, the ten-seed stability spread, and which of §4.4's three branches the result
falls in.

**Stage B does not start until this is signed off.**

---

## 6 · Stage B — the regular-grid scale ladder

### 6.1 · The grid

Square blocks on EPSG:8058 at **250 m, 500 m, 1 km, 2 km and 4 km**, with the **pixel census itself
as rung 0** (24.97 m). Blocks are anchored to a single origin so each coarser rung is an exact
aggregation of the finer ones — nested, not independently tiled.

**Blocks are not community-pure.** The unit is therefore **block × vegetation community**: for each
block and each community present in it, compute the two axes over that block's cells of that
community. This keeps community purity, which every other figure in the project maintains, while the
*size* of the unit is set by the grid rather than by how the country was drawn.

**Support rule, one rule at every rung:** at least 500 cells, the PARTSCATTER floor. Report at each
rung the block × community count before and after, and the area retained.

**Expect the fine rungs to lose most of their units.** A 250 m block holds about 100 cells, so no
250 m unit can meet a 500-cell floor. **Pre-registered rule:** rungs whose blocks cannot physically
reach the floor are reported with their counts and **not fitted**; the ladder's fitted range begins
at the first rung that can. Report where that is. Rung 0 — the pixel census — is fitted separately
and is not subject to the floor, since a cell is the unit.

### 6.2 · The two things the ladder measures

**Slope against grain — the invariance question.** Fit the same form as Stage 0, per community, at
each rung. Report slope, r and n_blocks per rung per community.

- **If the slope is flat across the ladder**, the relationship is scale-invariant on a neutral unit.
  That is a far stronger claim than holding across three bespoke unit types, and it is the result
  that would carry a methods section.
- **If the slope climbs with block size**, that is the modifiable areal unit effect, and its shape
  names the scale at which the process operates. **Report it as the finding, not as a nuisance.**
- Compare the fitted range against the paddock line (+0.547838) and the part line (+0.547274). Those
  are on the spatial floor and **are not directly comparable** — say so, and compare shapes rather
  than values.

**Level against grain — the size effect, measured cleanly for the first time.** UNZONED §1.1 found
the temporal metric's level rises with unit size: +2.68 pp per decade pooled, +3.57 within Inland.
That was measured on irregular parts where size and geography vary together and could not be
separated.

**A regular grid varies size by construction while holding geography.** Report the mean level per
rung per community. **Pre-registered reading:**

- **If the level rises with block size on a regular grid**, the effect is a property of aggregation
  itself and UNZONED §1.1's +3.57 has a mechanical component after all.
- **If it is flat on a regular grid**, the +3.57 is geographic — bigger irregular units genuinely sit
  in different country — and UNZONED's reading stands strengthened.

**This is the cleanest available test of a finding the project currently cannot explain.** Report it
against both branches.

### 6.3 · Intervals

Intervals at every rung use the effective n from Stage A, by the method Stage A names, **not the
block count.** Report both the nominal n and n_eff on every row. This is the whole reason Stage A
comes first.

---

## 7 · Constraints

Additive only; nothing existing is re-rendered, re-registered or superseded. **`veg_p05_spatial` does
not appear in this task** (§2). Pixel support throughout; no plot measurement enters (C10).
**No p-values anywhere** — report slope, r, residual SD, range, nugget, sill, n, n_eff and
bootstrap or analytic quantiles with their basis named.

**No size adjustment and no interval widening are applied to any existing output.** Everything here
is measurement; what follows from it is a design-seat decision.

**Ruling EN applies throughout:** a coefficient is applied only within the range over which it was
estimated. This binds the ladder — a slope fitted at 4 km blocks is not applied at 250 m — and the
variogram range, which is not extrapolated beyond the maximum lag computed.

**Ruling EQ applies to every statement of extent:** the analysed area and the property area are named
together, or neither is. The analysed extent here is the non-treed census, not the property.

**Ruling EI is held, not fixed:** the five qualifiers ride in `provenance_note` as prose.

**Ruling EB** — if another session is live on this repository, perform no git operation: write to
disk and stop.

Any edit containing an escape, a newline or a multi-line string goes through a file, never a shell
heredoc (DS); parse-check before running.

---

## 8 · Outputs

- `SPAT1_stage0_coefficients.csv` — the registered fits, per community and pooled, intervals
  deliberately absent with the reason in-file.
- `SPAT1_variogram_empirical.csv` · `_models.csv` · `_directional.csv` — lag, semivariance, counts;
  fitted nugget, partial sill, range per model and per direction; ten-seed spread.
- `SPAT1_effective_n.csv` — n, n_eff and ratio for each of the four unit sets, with the method named.
  **Every value in this table is also pinned in `dim_headline_number` per §4.4.1**, and the CSV
  carries the `number_id` of each row so the file and the registry cannot drift apart.
- `SPAT1_ladder_slopes.csv` · `_levels.csv` — per rung, per community: n_blocks, n_eff, area
  retained, slope, r, mean level.
- Figures: the empirical variogram per community with fitted models; the directional variogram; the
  ladder as slope against block size with a point per community per rung.
- **A data dictionary** on the UNZONED v3 pattern: every column, its units, its support, its metric,
  its period. One page.
- A findings note carrying every pre-registered prediction in §4.4 and §6.2 against what happened.

**Every figure follows EC and EA**: canonical labels from the caption register where the quantity
already has one, new labels registered where it does not; no internal identifiers on any face;
"vegetation community" written out.

**Cultural sensitivity:** place and vegetation community names follow existing report-stream usage
exactly; introduce no new naming.

---

## 9 · Ruling texts in force

**DA** — never "monotone in every community". Describe each community's own supported range.

**DB** — 795,602 of 988,831 non-treed cells are inside a management zone. The unit table and the
community table describe different populations and neither may stand in for the other.

**DP** — every run writes `Output/runs/RUN_<TASK>_<DATE>.md` in the fixed schema: decisions needed,
checks, overrides, disagreements, artefacts, not done, rulings.

**DS** — any edit containing an escape, a newline, or a multi-line string goes through a file, never
a shell heredoc. Parse-check before rendering.

**EA** — internal identifiers do not appear on client-facing figure faces.

**EB** — a session running concurrently with another on the same repository performs no git
operation: no add, no commit, no `.gitignore` edit, no un-ignore.

**EC** — every axis or legend label names the quantity, the population it is computed over, and the
time step. The same quantity is labelled identically across every product.

**EH** — a per-community smoother is fitted only where the community's central 10th–90th percentile
of the axis spans a usable range; min-to-max does not qualify a fit.

**EI** — the five qualifiers are a schema obligation, not a prose one. Held; not fixed here.

**EJ** — where a visual channel's direction carries meaning, the producer asserts the direction on
the built plot, not on the source.

**EN** — a coefficient may be applied only within the range over which it was estimated. Where a unit
falls outside that range the expectation is absent, not extrapolated.

**EO** — a manifest does not list itself.

**EQ** — any client-facing statement of extent names the analysed area and the property area
together, or names neither.

**ER** — where a defect has a structural fix that removes the failure mode, prefer it to correcting
the instance, when it is available and proportionate to the defect. A corrected value is true on the
day and free to drift; a value derived from its source cannot drift from it. The test is whether,
after the fix, the defect still has somewhere to live. This is a preference, not a licence to
rebuild.

**CZ** — `number_id` at the point of quotation, not per table row.

**C10** — plot support and pixel support are both correct at different scales and must never be mixed
in one figure.

**I-40** — recording a decision is not executing it; asserting a fact is not verifying it.

**I-42** — a check that errors is not a check that catches. A check must be shown able to fail.

**I-60** — an instruction that never took effect while everything reported success. The exit code is
not the check; verifying the intended content is. Includes: `theme_void()` sets no background and
`ggsave()` writes transparent — set all four background elements explicitly and open the file.
