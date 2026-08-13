# Gayini CC spec — INVENTORY-1

**A complete, accurate account of what exists, organised by what the client asked.**
Design seat, 9 August 2026. Read-only except for the output document.

---

## 0 · Standing execution rule

Run to completion in one pass and report once. Do not ask before writing. Halt only on: a required
input absent after searching; unresolved repository divergence.

**This task reads and writes one document.** It registers nothing, renders nothing, and computes no
new quantity. Every count in it comes from the database, the filesystem or the registry — **never
from a caption, a previous summary, or this spec.**

---

## 1 · What this is for, and the trap in it

The client presents to the Nari Nari Tribal Council and the Biodiversity Conservation Trust. He has
ten minutes and has said he wants to show that a lot of work is under way.

**The temptation is to inflate, and inflating would defeat the purpose.** A count that does not
reconcile, a figure listed that nobody can open, a claim of a result the data does not support —
any one of those, noticed in the room, costs more than the whole document gains. **The volume here
is genuinely large. Report it accurately and it will speak for itself.**

Two rules follow.

**Every number is verified against its source, both directions.** If the document says 318 figures,
`figure_asset` returns 318 and the files exist on disk. Report any count that does not reconcile,
with both numbers.

**Nothing is claimed as a result that is a description.** The description-versus-attribution boundary
holds throughout: the satellite measures cover, not ecological condition, and it cannot separate a
change in land use from a change in condition. Where the honest statement is a null, write the null.

---

## 2 · Structure — organised by the client's questions, not by our folders

The client's own words, from the email record, are the section headings. Under each, what exists.

1. **"Figures showing inundation and vegetation cover over time"** — the exemplar set, the paddock
   and site dashboards, the whole-property series, the epoch context figure. Unit, support and
   coverage for each family.
2. **"The raster of flood frequency… to use in some example maps"** — the counted surface, the zone
   surface, the annual stacks, the class raster, the percentile rasters. Filename, grid, span,
   registry status.
3. **"Calculate temporal percentiles… averages of percentiles… plot percentiles vs inundation"** —
   the three steps, what was built for each, and the tables that carry the numbers.
4. **"Maps of the residuals"** — withdrawn at the client's request. Say so; it shows the record is
   responsive, not that something failed.
5. **The reference-state question** — conserved against grazed, what was tested, and what the answer
   is including the null.
6. **What the data cannot say** — a short, plain section. This is not a weakness in the document; a
   study that states its limits reads as more trustworthy, not less, and the Council will ask.

---

## 3 · What to count, and how

For each of these, the exact number, the source queried, and the verification performed:

- Registered figures (`figure_asset`), and how many are current versus superseded
- Registered rasters (`raster_asset`), with total volume
- Tables and views in `Gayini_Results.sqlite`
- Census cells, and the area they cover
- Water years, seasonal composites, and the span in both conventions
- Monitoring plots, split by treed and non-treed, and how many carry a sheet
- Paddocks, parts, communities, wetness classes
- Analysis scripts, by language
- Pinned numbers in `dim_headline_number`

**Where a count has a caveat, the caveat travels with it.** 57 of 66 site sheets is not a shortfall
— the nine treed sites are out of scope by design because the satellite measures ground cover and
under a canopy that number does not mean what it means in the open. Say that where the count appears.

---

## 4 · Register of corrections

**A short section listing what was found wrong and fixed, with dates.** The interpolated flood
surface, the mislabelled water axis, the plot-versus-polygon support mismatch, the seasonal basis.

**This belongs in a document meant to build confidence, and it is not a liability.** Every one of
these was found internally before the client hit it. A record that shows the work is being checked
is stronger evidence of rigour than a record with no corrections in it.

Keep it factual and brief. No self-criticism, no apology, no dwelling.

---

## 5 · Form

Markdown, `Output/INVENTORY_20260809.md`, version-controlled — add a targeted un-ignore in the shape
of CL if needed, and verify it with `git check-ignore -v`, not by reading (I-60).

**Written for an intelligent reader who is not a remote-sensing specialist.** No slugs, no
`veg_p05_spatial`, no `fit_id`, no folder paths in the body — those belong in an appendix table if
anywhere. Where a technical term is unavoidable, define it once in plain words.

**Cultural sensitivity:** this may reach the Tribal Council. Place and community names follow
existing usage in the report stream exactly; introduce no new naming. Flag anything you are unsure
of rather than deciding it. The document carries a line stating it is internal and requires review
with the Nari Nari Tribal Council before external sharing.

**Report:** every count that did not reconcile on first query, with both numbers and the resolution.
That list is the evidence the document is accurate, and it matters more than the document's length.

**Rulings in force:** BB, CZ, DA, DB, DP, DS.
