# Gayini CC spec — UNZONED-1

**The out-of-sample test.** Design seat, 9 August 2026. Additive only.

---

## 0 · Standing execution rule

Run to completion in one pass and report once, in the `RUN_` schema of Ruling DP. Every fork carries
a pre-registered rule; a fork with a rule is not a question. Do not ask before writing. If a rule is
clearly wrong for what you find, override it, state that you did and why, and keep going.

Halt only on: grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent after searching; unresolved repository divergence.

---

## 1 · Why this is worth more than another figure

**Only 795,602 of the 988,831 non-treed census cells fall inside a management zone (Ruling DB).** The
remaining **193,229 cells — 19.5% of the mapped country — have never entered any fit, any
stratification or any published number.**

That makes them a genuine held-out sample. Every result so far rests on zoned country; if the
water-and-cover relationship holds on ground the analysis has never seen, that is evidence the
relationship is a property of the country rather than of the paddock set. **This is the strongest
scientific move available today and it costs one groupby.**

**Pre-register the reading before looking:**

- **If the unzoned points fall on or near the zoned relationship**, the finding generalises beyond
  managed land. Report it plainly.
- **If they sit systematically off it**, that is the more important result and it leads the report.
  Do not soften it, do not fit it away, and do not attribute a cause — the description-versus-
  attribution boundary holds here as everywhere.
- **If the unzoned country does not span enough water range to distinguish the two**, say so and draw
  no conclusion either way.

---

## 2 · Defining the unit — the one real decision

Unzoned country has no paddocks, so the unit must be built. **Pre-registered rule, in order:**

1. **If a patch layer already exists** — the memory of this project records unzoned standard-grazing
   country as roughly 12,048 ha in 93 patches — **use it.** Search before building. Report where it
   came from and whether its counts reproduce.
2. **If none exists**, derive contiguous patches of unzoned non-treed cells, then split each by
   community so patches are community-pure, matching PARTSCATTER's unit.

Either way: **drop patches below 500 cells**, report the number dropped and their combined area, and
report the surviving n, cell-count range and total area by community.

---

## 3 · Build

Same metric, same axes, same producer as PARTSCATTER. **No raster opened, no new metric.**

- **y:** mean over the patch's cells of each cell's temporal 5th percentile of total vegetation.
  Seasonal basis, footnoted in identical words to the other two scatters.
- **x:** the same water quantity, labelled per Rulings AZ and CX.
- **Colour:** community.

**Two figures, both registered:**

1. **Unzoned alone**, one point per patch, one smoother per community where the range supports it.
2. **Zoned and unzoned together**, with the unzoned points in a visually distinct shape — not merely
   a different colour, since colour already carries community. The zoned smoother is drawn; **the
   unzoned points are overlaid without being fitted**, so the figure shows held-out points against a
   line they did not inform. That is the whole point and it must be visible on the face.

The combined figure's caption states that the unzoned points entered no fit.

---

## 4 · Report

- Patch count, area and cell-count range, by community, before and after the 500-cell filter.
- The water-axis range of unzoned country against zoned country. **If unzoned country is
  systematically drier or wetter, say so first** — it conditions everything else in the figure.
- Mean residual of the unzoned points against the zoned smoother, by community, with the sign. **No
  p-value, no test.** A number and its direction.
- Whether the unzoned country is standard-grazing throughout or of mixed and unknown status. If its
  management status is not established in the data, say so and do not call it grazed.

---

## 5 · Constraints

Additive only; nothing existing replaced. Pixel support throughout; no plot measurement (C10).
`veg_p05_spatial` and `veg_p05_temporal_mean` never in one figure. No p-values. Five qualifiers, no
NULLs. `number_id` at the point of quotation (CZ). Registration in one transaction. Edits with
escapes or newlines go through a file, never a heredoc (DS).

**"Conserved" and "grazed" are management categories, not condition states**, and unzoned country
must not be described as either unless the data establishes it.

**Rulings in force:** AZ, BB, CX, CZ, DA, DB, DP, DS.
