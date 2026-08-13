# Gayini CC spec — MAP-1

**Where the scatterplot points are.** Design seat, 10 August 2026. Additive only.

---

## 0 · Standing execution rule

Run to completion in one pass and report once, in the `RUN_` schema of Ruling DP. Every fork carries
a pre-registered rule; a fork with a rule is not a question. Do not ask before writing. If a rule is
clearly wrong for what you find, override it, state that you did and why, and keep going.

Halt only on: grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent after searching; unresolved repository divergence.

**No new metric is computed and no raster is built.** Every value mapped here already exists as a
column behind an existing figure. If any panel would require a new computation, drop that panel,
record why, and continue with the rest.

---

## 1 · Why this exists

Four scatterplots now describe how ground cover relates to water — at paddock grain, at
paddock × vegetation community grain, and on unzoned standard-grazing tracts. **None of them shows
where any of it is.** The data has been spatial throughout and the reader has been given no way to
find a point on the ground.

Two things follow. A reader who wants to ask *which paddock is that* currently cannot. And the
single most useful comparison available — **the paddock system against the country outside it** — is
a geometric comparison that no scatter can carry.

**These maps answer "what is a point and where does it sit". They do not carry a new result.**

---

## 2 · Inputs

| input | source | note |
|---|---|---|
| paddock × community parts | `Gayini_Results.gpkg` | the 156 areas; 100 plotted in PARTSCATTER |
| unzoned tracts | `UNZONED_patches_epsg8058.gpkg` | written by UNZONED v3 §6 |
| part and tract attributes | the PARTSCATTER and UNZONED summary tables | water, floor, cell count, inclusion flags |
| property and paddock boundaries | existing report-stream layers | |
| vegetation community raster | `veg_regime_class_8058.tif` | context only |

**Pre-registered fork.** If `UNZONED_patches_epsg8058.gpkg` is not yet written, derive tract polygons
from the patch labelling already reproduced in the UNZONED v3 run — it reproduced against the Gate 1
inventory at zero mismatches on id, cell count and community. Record which route was taken.

Canonical CRS EPSG:8058 throughout. Community palette from `gayini_veg_regime_classes()`:
Aeolian `#C79A3C`, Riverine `#3FAE97`, Inland Floodplain `#2E6DB0`, Woodland/Forest grey `#7C837E`.

---

## 3 · Figure M1 — the units, and what was left out

**The primary figure. If only one is built, build this one.**

One map of the property. Every paddock × community area drawn as its own polygon, filled by
vegetation community, with **thin light boundaries between adjacent areas** so 156 discrete units read
as units rather than as a community surface. Colour alone cannot do this; the boundaries are the
point.

**Every area appears. Inclusion is shown, not applied by omission:**

| class | n | rendering |
|---|---:|---|
| plotted in PARTSCATTER | 100 | full community fill |
| woodland or forest — not analysed | 34 | grey `#7C837E`, hatched or stippled |
| outside the three open communities | 4 | same treatment as woodland |
| under the 500-cell floor | 18 | community hue, heavily lightened |

**Report the area of each class**, not only the count. The 18 small areas are 171 ha — 0.3% of the
open ground — and a map that shows them as a large share of the units while the caption says 0.3% of
the area is doing the reader a service, not creating a contradiction. State both numbers.

**Caption states, in plain words:** each shape is one point on the cover-and-water figures; the grey
areas carry tree canopy, where the satellite's ground-cover number does not mean what it means in the
open; the faint areas are too small for an average that stands beside one taken over thousands.

---

## 4 · Figure M2 — the paddock system against the country outside it

**The figure that earns this task.** Same basemap, same scale, same palette.

- **Paddock × community areas** — the 100 plotted, in community fill.
- **Unzoned standard-grazing tracts** — the 39 plotted, in community fill, distinguished by a
  **visually distinct boundary treatment** (heavier outline, or outline-only fill). Not by hue —
  hue carries community, as it does on every scatter.
- **Unzoned tracts below the 500-cell floor** drawn faintly, so the unzoned country is not made to
  look smaller than it is. **54 of 93 supported patches drop at that floor, but only 570 of 12,048
  hectares go with them.** That ratio is a fact about the shape of the country and the map is where it
  is legible. State both numbers on the face.

**What this figure shows and the caption says:** the paddock areas tile the managed country in blocks
cut by fences; the unzoned tracts are interstitial and irregular, wherever no management zone was
drawn. **They are different geometries covering the same country, and that is why the unzoned tracts
are a genuine held-out sample rather than a re-slicing of the same ground.**

**Naming, fixed:** *unzoned standard-grazing country*. Never unmanaged, ungrazed, control or
reference. All fifteen standard-grazing monitoring plots sit on this ground; say so in the caption,
because it is the join between this map and every plot-support result in the project.

---

## 5 · Figure M3 — the water axis on the ground

Same units as M1. Fill carries **the area's own x-value** — the share of its cells seen wet, mean
over years — on a single continuous ramp, all units on one scale, both zoned and unzoned.

This shows where the x-axis comes from and how much of the fine-grained water pattern survives
aggregation to the analysis unit. Expect it to read as a coarsened flood-frequency surface; that
resemblance is informative and the caption should name it rather than leave the reader to notice.

**Excluded units keep M1's treatment** — not analysed is not the same as zero.

**Legend label per EC:** the quantity, the population and the time step, in the same words the
scatters use. Not "flood frequency" as a bare term.

---

## 6 · Figure M4 — the cover axis · **conditional, and the caption carries a burden**

Same units, fill carries the area's y-value — mean per-cell 5th-percentile ground cover.

**The risk is specific and it has already been raised by the client.** His objection to the earlier
residual maps was that they coloured large areas by values calculated from the barest areas. **That
objection was correct about the spatial floor and does not apply to this metric** — the temporal
percentile is computed per cell and averaged, so every cell contributes its own history and no subset
of ground is selected. **Say that on the face.** It is the answer to a question the client has already
asked and has not yet been given.

**But a continuous cover ramp still reads as a condition map**, and it will be screenshotted. The
caption must carry, in plain words: this is ground cover measured by satellite, not ecological
condition; it cannot separate a change in land use from a change in condition; and the map describes
how places differ from one another over the record, not what more water would do to any one place.

**Pre-registered rule: if that sentence cannot be fitted legibly on the face, M4 is not produced.**
Record the decision. M1, M2 and M3 do not depend on it.

---

## 7 · Common requirements

**North arrow, scale bar, property boundary emphasised, locator inset** — and the inset must not
overlap a panel title or clip an axis label. Verify by opening the rendered files, not by exit code
(I-60). Four locator paths exist in this codebase and the wrong one has been parameterised before;
confirm which path each map uses before adjusting any offset.

**Ruling EA** — no internal identifiers on any face: no `veg_p05`, no `fit_id`, no `number_id`, no
issue codes, no repository paths.

**Ruling EC** — every legend label names the quantity, the population it is computed over and the
time step, in the same words the corresponding scatter uses, so a reader moving between figure and
map meets one vocabulary. Register any new label in the caption register.

**"Vegetation community" written out.** No abbreviation.

**Cultural sensitivity.** These are the most directly place-naming artefacts the project has produced
and they are Council-facing. Place and vegetation community names follow existing report-stream usage
exactly; introduce no new naming; label no location the report stream does not already label. **Flag
anything uncertain rather than deciding it.**

Registration through `gayini_write_and_register_figure()` in one transaction, five qualifiers
populated, no NULLs. Edits containing an escape, a newline or a multi-line string go through a file,
never a heredoc (DS); parse-check before rendering.

---

## 8 · Report

- Counts **and areas** for every inclusion class, on both the zoned and unzoned sides, reconciling to
  the totals the scatters state.
- Which route §2's fork took for the tract polygons.
- Whether M4 was produced, and if not, why.
- Any label registered.
- Anything found and held under DJ.

---

## 9 · Ruling texts in force

**DA** — never "monotone in every community". Describe each community's own supported range.

**DB** — 795,602 of 988,831 non-treed cells are inside a management zone. The unit table and the
community table describe different populations and neither may stand in for the other.

**DJ** — a client-facing document is edited once per delivery cycle, never twice. Corrections found
between passes are recorded and held.

**DP** — every run writes `Output/runs/RUN_<TASK>_<DATE>.md` in the fixed schema: decisions needed,
checks, overrides, disagreements, artefacts, not done, rulings.

**DS** — any edit containing an escape, a newline, or a multi-line string goes through a file, never
a shell heredoc. Parse-check before rendering.

**EA** — internal identifiers do not appear on client-facing figure faces. This covers issue codes,
ruling letters, `number_id`, `fit_id`, and repository paths.

**EB** — a session running concurrently with another on the same repository performs no git
operation: no add, no commit, no `.gitignore` edit, no un-ignore. It writes its output to disk and
stops there.

**EC** — every axis or legend label on a client-facing figure names the quantity, the population it is
computed over, and the time step. No abbreviation of the quantity, no formula fragment in a
parenthetical, and no evaluative or interpretive wording. The same quantity is labelled identically
across every product. A figure that cannot be labelled precisely is not shipped until it can.

**I-60** — an instruction that never took effect while everything reported success. The exit code is
not the check; verifying the intended content is.
