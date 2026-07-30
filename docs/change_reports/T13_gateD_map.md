# T13 Gate D — the map, the continuous companion, and the sensitivity multiples

**Task:** T13 Gate D, per `Gayini_T13_spec.md` v1 §6, plus rulings 5 and 6 and corrections 1–2 (30 Jul 2026).
**Date:** 30 July 2026 · **Prior:** SHA 352c02d (Gate C)
**Scope:** build the paddock-part polygons; draw the state map, the `level_z`×`trend_z` scatter companion, and the 0.75/1.25 small multiples.
**Producers:** `scripts/12_zone_stratum/build_T13_gateD_part_polygons.R` · `build_T13_gateD_figures.R` (both tracked).
**Artefacts — these are the record, this report is a rendering:**
`Output/spatial_8058/T13_part_polygons_epsg8058.gpkg` · `figures/T13/T13_D1_part_state_map_and_scatter.png` · `figures/T13/T13_D2_part_state_map_sensitivity.png`

Session start: on `main`, up to date with `origin/main`, `main` has not moved.

**DB writes at this gate: `figure_asset` only**, via `gayini_write_and_register_figure()`. That is
deliberate and required — the one-transaction rule exists so a figure cannot land on disk
unregistered. No builder run, no existing object modified, no p-values.

---

## 0. Two rulings were never stated in this session — flagging the gap

Your message directs "GATE D PROCEEDS with rulings 5 and 6" and states the substance of **Ruling 6**
(the marginal band, hatched, calibrated to 0.15). **Rulings 5 and 6 were never given in full text in
this chat** — I have their substance only from the enumerated Gate D requirements in the same
message. I have built to that enumerated list:

1. five fill classes · 2. hatching for the marginal set · 3. heavier outline on the 3-part core ·
4. no state asserted for Bala 29ca Inland · 5. threshold lines and shaded marginal band on the
scatter panel · 6. the OLS identity in the methods section · 7. the registered client sentence ·
8. the community-SD scale line on the map, not only in methods.

If Ruling 5 contained anything beyond that list, it is not in this build. Please confirm.

---

## 1. The part polygons had to be built — and the route matters

**No part-grain geometry existed.** `spatial_layer_asset` holds `management_zones_8058` (64 paddock
polygons) and `vegetation_communities_8058` (5 community polygons). **Intersecting those two would
have been wrong.** The T13 communities come from the **census pixel assignment**
(`veg_regime_class_8058`, via the 795,602 in-scope centroids in `T2_in_scope_points.csv`), not from
the vegetation shapefile. A shapefile intersection would produce a *different partition* from the
one every T13 number was computed on — the wrong-layer family of error this project has hit before.

So the polygons are **dissolved from the census pixels themselves**: each in-scope centroid expanded
to its pixel square using `PIXEL_SIDE_M` from `gayini_params` (never a literal), then unioned per
`(zone_fid, community)`. **The polygon is the analysis unit by construction, not an approximation.**

Checks, all asserted in the script and all passing:

| check | result |
|---|---|
| parts built | **118** (the full zone × community set; 115 carry measures) |
| CRS | **EPSG:8058** |
| pixels enclosed | **795,602** — matches the in-scope set exactly |
| max relative \|geometric area − pixel-count area\| | **3.669e−11** (tolerance 1e−6) |
| overlapping part pairs | **0** — every pixel belongs to exactly one community |

The area check is the meaningful one: dissolving squares cannot change area, so any drift would
expose a geometry or constant error. Registration of the gpkg is Gate E.

### 1b. A second, RENDER-ONLY geometry was necessary — and it is never an analysis input

The exact polygons carry **3,098,448 vertices** across 118 parts, because every perimeter is a
pixel staircase and every out-of-scope pixel is a hole. **The first Gate D draft was unreadable
because of this**: at any visible outline width the staircase perimeter fills the polygon solid, so
the 3-part core rendered as black blobs rather than outlined areas, and the hatch intersection was
too slow to finish.

`build_T13_gateD_render_geom.R` therefore produces a **display copy** — morphological close at half
a pixel, then `st_simplify` at 0.6 pixel, `preserveTopology = TRUE`:

| | exact | render-only |
|---|---|---|
| vertices | 3,098,448 | **21,578 (0.7%)** |
| area drift vs exact | — | **median 0.73%, max 10.63%** |

**Nothing is measured off the display copy.** Every number in this gate comes from the Gate C CSVs;
the copy only decides where ink goes. Both captions state that boundaries are generalised for
display.

**A first attempt at `st_simplify` tolerance = 2 pixels was rejected**: it reached 4,646 vertices but
drifted one part's area by **50.07%**, which is a misleading map rather than a simplified one. The
script now **asserts `max(rel) < 0.15`** and prints the five worst parts, so that failure cannot
recur silently. *(That assertion is in the script because a first patch of it silently no-opped and
the check was absent while I believed it present — caught by grepping for it rather than trusting
the edit.)*

---

## 2. ⚠ The marginal band as calibrated includes a boundary that does not exist

**Your counts reproduce exactly — from a definition that counts distance to `level_z = +1.0`.**

I could not reproduce 28 / 30 / 40 from the cuts in the §5 rule. Testing candidate definitions:

| definition | 0.10 | 0.15 | 0.20 |
|---|---|---|---|
| **A** — distance to an **active** cut: `min(\|level_z+1\|, \|trend_z+1\|, \|trend_z−1\|)` | 22 | **23** | 31 |
| **B** — A **plus `\|level_z−1\|`** | **28** | **30** | **40** |

**B reproduces your three numbers exactly.** But **`level_z = +1.0` is not a cut in the §5 rule.**
The level axis has exactly one threshold, −1.0. A part at `level_z` +0.9 and one at +1.1 classify
identically; nothing happens at +1.0. Distance to it is not a distance to anything.

Under B, **7 of the 30 hatched parts are hatched solely by that phantom boundary**:

| part | `level_z` | `trend_z` | state | distance to a **real** cut |
|---|---|---|---|---|
| Mara 13 · Aeolian | +0.947 | −0.330 | Unremarkable | 0.670 |
| Mara 6 · Inland | +0.978 | +0.000 | Unremarkable | 1.000 |
| Bala 14/16 · Inland | +1.027 | +0.731 | Unremarkable | 0.269 |
| Bala 18 · Inland | +1.032 | +0.130 | Unremarkable | 0.870 |
| Mara 19 · Inland | +1.095 | +0.295 | Unremarkable | 0.705 |
| Mara 13 · Riverine | +1.025 | +0.644 | Unremarkable | 0.356 |
| Dinan 14 · Riverine | +1.118 | +0.786 | Unremarkable | 0.214 |

All seven are *Unremarkable*, and **the closest of them is 0.214 from any real cut** — none is
remotely marginal. Hatching them tells a reader "this part might be something else" when nothing
about its classification is close to changing. That is the opposite of what the hatching is for.

**Built as specified on the band width, corrected on the boundary set.** Band stays at **0.15** as
ruled. Using definition A, the 0.15 union is **23 of 115 (20%)** — which also **improves** on your
own stated criterion, since 23 hatched reads more cleanly than 30. **Mara 18 is hatched by the movers union rather than by
the band, exactly as you predicted** — and it is not alone: Dinan 7 (0.188) and Bala 2 (0.205) are
also union-only, the same three parts that Correction 2 identified as the non-marginal movers.

**Say the word and I will switch to definition B.** I have not, because hatching a part that cannot
change state is a claim the data does not support.

**Union definition as built and as stated in the caption:** a part is hatched if it is **within 0.15
of an active cut OR changes state under the drop-two-wettest robustness run**. The caption says this
explicitly, so no reader infers that every hatched part is near a boundary — Mara 18 (0.391 from any
cut) is the standing counter-example.

---

## 3. What the figures show

**Figure 1 — `T13_D1_part_state_map_and_scatter.png`.** The state map beside the continuous scatter,
so the classification and the measures under it sit side by side (§6).

- **Five fill classes**, the pre-registered four with *Persistently poor* split per Ruling 4 into
  **low-and-flat** (10) and **low-and-falling** (4). The split is a labelling refinement; no
  membership or threshold changed.
- **Hatching** on the 23 marginal parts (§2).
- **Heavier black outline** on the **3-part core** — recovering at every swept cut.
- **Bala 29ca · Inland is drawn with no state asserted** (white, its own legend entry). It is
  marginal on both axes (`level_z` −0.962, 0.038 from the cut; `trend_z` −1.108) and changes state
  under robustness. Asserting *Declining* on a map would overstate what the data supports.
- **Four reference paddocks** distinguished by a dashed heavy outline; paddock boundaries drawn and
  labelled; **north arrow and scale bar** drawn from geometry; **deck palette, not viridis**.
- **Scatter**: threshold lines at `level_z` −1.0 and `trend_z` ±1.0, with the ±0.15 marginal band
  shaded, and the core ringed.

**Figure 2 — `T13_D2_part_state_map_sensitivity.png`.** The same map at **0.75** and **1.25** against
the registered ±1.0, so the sensitivity is visible rather than asserted. Core outline and hatching
are omitted there so the cut is the only thing varying.

**Three equal panels in one row, registered cut in the middle.** A first draft put the registered
map below at larger size; an unequal grid makes the eye read the biggest panel as the important one,
which defeats a sensitivity comparison. At equal size **the nesting is legible directly from the
figure** — the green shrinks 10 → 8 → 4 *in place* as the cut tightens, rather than moving around
the property. That is the §2 finding rendered rather than asserted.

**Layout defect fixed:** the scale bar was initially placed at the bottom-left of the bounding box,
where it sat **on top of** the Mara / Bala 29ca cluster. The property runs SW–NE, so the free corner
is bottom-right; both scale bar and north arrow now sit there. Insets never overlap the map.

### Two tooling notes

`ggpattern` and `ggspatial` are **not installed**. Hatching is built by intersecting a rotated line
grid with the marginal polygons, and the north arrow and scale bar are drawn as annotations in
projected metres. Both are exact rather than approximate, and neither adds a dependency eleven days
from the deadline. Flagging rather than installing packages on your workstation mid-gate.

### The state palette is not a ratified object

**No committed *state* palette exists.** The audited deck palette
(`docs/change_reports/tier2H_gateE_palette_audit.md`) is per-**community**, and the states are not
communities. The five hues are taken from the committed semantic set in
`R/gayini_dashboard_panels.R` / `gayini_dashboard_figures.R` so the map reads with the rest of the
deck: **veg-green `#2E7D32`** = recovering, **neutral grey `#9E9E9E`** = unremarkable, the committed
**"drier" red `#B2182B`** = declining, **bare-brown `#8D6E63`** = low-and-flat. Only
**low-and-falling `#4A2C22`** is derived (a darker bare-brown) and is the one non-committed hue.

**Deliberately not blue for recovering**, despite blue being the committed "good/wetter" pole in the
dashboard palette: blue reads as **water** on every other map in this project (`flood = #2171B5`),
and a blue "recovering" class beside a flood-frequency surface would be actively misleading. Flagged
for ratification rather than presented as settled.

---

## 4. Methods — the OLS identity

The water adjustment decomposes exactly. For any part, with `trend_adj` the slope of the residuals
from the water regression on year:

```
trend_raw  =  trend_adj  +  water_slope × own_flood_trend
```

Verified numerically to ~4e−05 on all three Bala 29ca parts, e.g. its Inland part:

```
−0.2160  =  −0.3500  +  (+0.3442 × +0.3892 = +0.1340)
```

This is why a part can look typical on the raw scale and underperform once adjusted: the middle term
is the lift its own water gave it. Bala 29ca Inland's raw deviation from the Inland median is
**−0.0048 pp/yr** — genuinely typical — while its adjusted deviation is **−0.1984 pp/yr**. Both are
correct; they answer different questions.

**The mechanism correction from Gate C stands and belongs in the methods text:** that part is
**drier** than typical Inland country (own mean flood **15.92%** vs community median **30.93%**), not
wetter. What is elevated is its flood **trend** (**+0.389** pp/yr against a community median of
**−0.280**). It has been wetting while its community dried, and its cover still fell at the typical
rate.

---

## 5. The registered client sentence

> **Between 3 and 15 parts depending on strictness, 8 at the registered cut — and the same parts
> throughout.**

This is the form the count must travel in. A bare "8 parts are recovering" is not defensible on its
own: the count is cut-dependent, and the sweep's value is that the *membership* is not. Both figure
captions carry the nesting statement.

**And it must travel with the scale caveat**, now stated on the map itself rather than only in
methods: the z-scores are scaled to each community's own spread, so **a `z` of −1.0 is about 12 pp
of ground in Aeolian or Riverine but only about 6 pp in Inland**.

---

## 6. Invariants

- Additive: one new gpkg, two new figures. **No builder run, no existing object modified.**
- DB writes confined to `figure_asset` via the one-transaction registrar (`INSERT OR REPLACE`, first-50-MB SHA-256).
- **No p-values** anywhere.
- Pre-registration intact: ±1.0 unchanged, no threshold moved for any part including Bala 29ca Inland; the pilot 7/17/8/83 not computed, compared to, or referenced.
- Corrections 1 and 2 folded into `T13_gateC_classification.md` with the superseded text retained visibly.
- **Defect found and fixed at source:** the Gate C classification CSV emitted `state_cut_1.00` **twice** (the registered column collided with the sweep column of the same name). Values were identical, but a duplicated header means a reader silently keeps one. The registered column is now `state_registered`; the CSV was regenerated and all counts are unchanged (8/14/16/77, split 10/4).

## STOP

Part polygons built and checked; both figures written and registered; rulings 4 and 6 applied with
the boundary-set deviation in §2 flagged for your call; corrections 1 and 2 folded into Gate C.
**Waiting for review before Gate E** (register the flood table, the part polygons and
`fact_zone_community_part_classification`; `dim_headline_number` rows for the four counts with the
sweep range as spread; extend the reproduction test; exit bundle).
