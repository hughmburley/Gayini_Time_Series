# Task spec — Cuts locator slide for the pre/post deck

**Owner:** Hugh (design/review in chat) · **Executor:** Claude Code (CC) on the workstation
**Repo:** github.com/hughmburley/Gayini_Time_Series
**Deck:** `Gayini_prepost_methods_deck.pptx` (built last session, 9 slides)
**Type:** Additive deck edit + one new figure. Packaging, not analysis. No analysis to run.

---

## Purpose (one concern)

Add an **opening locator slide** — "where the 2018 bank-cut works are" — as the first content
slide after the title, before J-F1. A deck-quality version of the preview figure approved in chat
(`cuts_locator_slide_fig.png`). It must match the styling of J-F1/J-F2 (same boundary linework,
fonts, palette) — which is why it is rendered in the **R pipeline that made J-F1**, not reused from
the chat preview PNG (that preview parsed the gpkg by hand and is cartographically rougher).

## Source of truth

- Cut points: layer `irrigation_bank_cuts` in `gayini_vectors_8058.gpkg` (EPSG:8058).
  **Confirm this is the live/current vectors gpkg on the workstation** before rendering — the chat
  copy may be stale.
- Boundary: `gayini_boundary`; context polygons: `management_zones` (same gpkg).
- **Read from disk; render from the live layer.** Do not hardcode counts — compute them from the
  layer at render time and assert they match the numbers below. If they don't, STOP and report.

## Verified data facts (computed from the layer this session — CC must re-derive and assert)

- `irrigation_bank_cuts`: **1,158 rows**, one attribute field `Date`.
- `Date` takes **two values only**: `201805` (May 2018, 509 rows) and `201809` (Sept 2018, 649).
- **940 unique coordinates**; **218** coordinates carry *both* May and Sept.
- Distinct sites at 50 m linkage ≈ **645** (proper clustering/linkage, not grid-snap; a naive 50 m
  grid-snap over-counts to ~738 — use linkage, and report the method + the number it yields).

## FRAMING RULES (non-negotiable — from the limitations register)

1. **Headline/label uses "~645 distinct cut sites," never "1,158 cuts."** 1,158 = point records;
   940 = unique coordinates; ~645 = distinct sites (50 m linkage). If the linkage number differs
   from ~645, use the computed value and note it — do not paper over it with the memorized figure.
2. **Descriptive, not an effect.** This is a locator. Nothing on the slide may read as a claim about
   what the cuts did. Carry the same "descriptive only" discipline as J-F1.
3. **L07 is unresolved.** The `Date` field cannot be asserted to be a *cut* date vs a *survey* date.
   Any date language hedges accordingly (see notes text).
4. **Not our data.** The layer was supplied as a plain one-field point export; provenance is
   unconfirmed. Hedge freely in the notes.

## Figure spec

- **Points coloured by the `Date` field value** (two 2018 passes): May 2018 = Inland Floodplain
  blue `#2165AC`; Sept 2018 = Aeolian gold `#C79A3C` (both from the deck palette). ~0.75 alpha,
  small markers. Plot Sept first, May on top, so the 218 both-date overlap locations read.
- Legend labelled "Date field value" with counts: May 2018 (n=509), Sept 2018 (n=649).
- **CAVEAT DISCIPLINE — heightened by the colour split.** Colouring by date visually implies a
  cutting timeline (blue then gold). We cannot support that reading: `Date` may be survey passes,
  not cut dates (L07). The legend title deliberately says "Date field value," not "cut date," and
  the footnote + notes must carry the cut-vs-survey hedge prominently. Do not label the legend or
  axis anything that asserts these are cut dates.
- Boundary in the J-F1 boundary style; `management_zones` as light context fill behind points.
- EPSG:8058 grid, equal aspect. Match J-F1 font family/sizes.
- Title: **"Where the 2018 irrigation bank-cut works are"**
- Subtitle: **"~645 distinct cut sites across the property, coloured by mapped pass"**
- Figure footnote: **"Supplied bank-cut locations, EPSG:8058. Two 2018 passes; 218 locations carry
  both. Whether `Date` is a cut or survey date is unconfirmed. Descriptive locator — not an effect
  claim."**
- Save to the deck's figure output dir (same location J-F* figures are written), filenamed
  consistently with the J-F* set (e.g. `J-F0_cuts_locator.png`). Register nothing in `raster_asset`
  — this is a vector-derived figure, not a raster product.

## Slide spec

- Insert as the **first content slide after the title**, before the current J-F1 slide.
- Title + subtitle as above; figure placed to match J-F* slide layout.
- **Speaker notes are mandatory** (deck rule: every slide carries notes, nuance lives there). Notes
  text (adjust wording, keep all the substance):

  > These are the supplied 2018 irrigation bank-cut locations. **Counts:** the file holds 1,158
  > point records → 940 unique coordinates → ~645 distinct sites at 50 m linkage. Use "sites," not
  > "1,158 cuts." **Dates:** the single `Date` field takes two values only — May 2018 (509) and
  > Sept 2018 (649) — with 218 coordinates carrying both. We cannot yet tell whether `Date` records
  > when a cut was *made* or *surveyed* (limitation L07); this is an open query to the data provider
  > (Jana). **Provenance:** supplied to us as a plain point export with one attribute field — treat
  > as unconfirmed; this is not our data. **Framing:** nothing here is an effect claim; it is a
  > locator for the works, and context for the descriptive pre/post maps that follow.

## Gates

- **GATE 1 — render + STOP.** Re-derive the counts from the live layer and assert against the facts
  above (report the linkage-site number explicitly). Render the figure. Show Hugh the figure + the
  computed counts. **STOP** — do not touch the .pptx until Hugh approves the figure.
- **GATE 2 — insert slide.** Add the slide (title/subtitle/figure/notes) to a **working copy** of
  the deck. Additive: do not delete or reorder existing slides beyond inserting this one at
  position 2. Keep the original deck intact until Hugh confirms (save as a new file or on a branch).

## Commit / PR

- Branch `tier1j-cuts-locator-slide`. Commit the R render script, the figure, and the updated deck.
  Change report to `docs/change_reports/`, committed. Human review, then merge. No AI attribution.

## Verification-of-CC checklist (Hugh, against the artifacts — not CC's prose)
- [ ] Figure reads "~645 … sites"; the string "1,158 cuts" appears nowhere on the slide.
- [ ] Counts in notes match a fresh query of the layer (1,158 / 940 / 218 / ~645).
- [ ] Points coloured by Date; legend says "Date field value" (NOT "cut date"); counts 509 / 649.
- [ ] Slide has speaker notes; L07 cut-vs-survey hedge present and prominent (colour implies a
      timeline the data can't support).
- [ ] Existing 9 slides intact; new slide at position 2; original deck preserved.
- [ ] Figure styling matches J-F1 (boundary, fonts, palette).
