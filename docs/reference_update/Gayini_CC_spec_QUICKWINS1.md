# Gayini CC spec — QUICKWINS-1

**Three outputs from data already computed.** Design seat, 9 August 2026. Additive only.

---

## 0 · Standing execution rule

Run all three to completion in one pass and report once, in the `RUN_` schema of Ruling DP. Every
fork carries a pre-registered rule. Do not ask before writing. If a rule is clearly wrong for what
you find, override it, say so, and keep going.

Halt only on: grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent after searching; unresolved repository divergence.

**Nothing here requires new analysis.** All three draw on artefacts already built and registered. If
any of them turns out to need a new computation, stop that item, record why, and continue with the
others.

---

## 1 · The community × flood-bin figure

`TEMPORAL1_community_by_floodbin.csv` already holds it: 21 rows, three communities, seven wet-year
bins, mean per-cell temporal p05, with `LOW SUPPORT` flags and cell counts.

**This is the whole finding in one chart** — and unlike the paddock scatter it shows the three
communities side by side without the Inland-dominance problem.

- Three lines, community colours, x = wet-year bin using the explicit bin-edge columns already in
  the file, y = mean per-cell temporal p05.
- **Every point below 1,000 cells is drawn distinctly** — hollow, or greyed — and the caption says
  why. Aeolian's top bin is 60 cells and Riverine's is 69; the figure must not let them read as
  equal to Inland's 16,626.
- **Caption states DA's wording:** clear and monotone in Inland Floodplain, which carries the wet
  end; Riverine rises across its supported range; Aeolian is ragged and its wet end rests on 60
  cells. **Do not write "monotone in every community."**
- Seasonal-basis footnote in the same words as the scatters.

---

## 2 · Flood-frequency map

The client asked for the raster *"to use in some example maps"*. Giving him a finished one saves him
the QGIS session and guarantees the counted surface is what gets shown.

- Source is **`flood_frequency_counted_8058.tif`** — never `background_flood_frequency_8058.tif`.
  State the filename on the figure.
- Paddock boundaries overlaid, property boundary emphasised, north arrow and scale bar.
- Continuous ramp, 0–100%, legend labelled **"share of the 35 water years this ground was wet"** —
  not "flood frequency" as a bare term.
- Footnote: WY1988–WY2022, 24.97 m cells, counted on the analysis grid.

---

## 3 · Flood-zone map

`flood_zone_8058.tif` in its five named classes — never, rarely, occasionally, regularly,
frequently. **For a Council audience this is more legible than a continuous ramp** and the class
names carry their own meaning.

- Same overlays and furniture as §2.
- Legend uses the five names with their thresholds in plain words, e.g. *"regularly — between one
  year in four and one year in two"*.
- Footnote records that these are absolute breaks at 0 / 10 / 25 / 50%, the same everywhere, and
  **not** the per-community terciles used in the community × wetness classes — the two schemes answer
  different questions and must not be read as one.

---

## 4 · Common requirements

All three registered through `gayini_write_and_register_figure()` in one transaction, with
`support_level` populated and the five qualifiers recorded, no NULLs.

**Cultural sensitivity:** these are candidates for a Tribal Council audience. Place names, community
names and any language on the face follow existing usage in the report stream exactly — introduce no
new naming. Flag anything you are unsure of rather than deciding it.

No p-values. Edits containing escapes or newlines go through a file, never a heredoc (DS). Colour
assertion `gayini_assert_series_colour()` passes for any non-community series.

**Report:** each figure's path, registry row, checksum; the source raster named for each map; and any
item that could not be produced without new computation.

**Rulings in force:** AZ, BB, CX, CZ, DA, DB, DP, DQ, DS.
