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

## 0. Rulings 5 and 6 — RESOLVED

Gate D was built before Rulings 5 and 6 had been stated in full text, from the enumerated
requirements only. **Both have since been given and nothing was missed.**

**Ruling 5** — *the sweep nesting is the headline rather than the count*: strictly nested, 15 at some
cut, 3 at every cut, "the cut controls how many, not which", and the registered client sentence
always carries the range. Built as §2 of the Gate C report and §5 below, and **rendered rather than
asserted** in the sensitivity figure, where the recovering set shrinks 10 → 8 → 4 *in place*.

**Ruling 6** — the marginal band, hatched, at 0.15. Built; see §2 for the boundary-set correction,
now ruled on.

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

**RULED, 31 July 2026: definition A stands.** `level_z = +1.0` is not a cut, the calibrated
28 / 30 / 40 came from a phantom boundary, and 22 / 23 / 31 are correct. Band stays 0.15, boundary
set = the three real cuts, **23 hatched**. Definition B is not to be used: seven *Unremarkable*
parts hatched by a boundary that cannot change their state would have been **a false claim of
uncertainty**, which is worse than the legibility gain.

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
- **Nine parts are drawn with no state asserted** (white, own legend entry) — **superseding the
  earlier single named part.** The rule is a criterion, not a chosen part: *both* inside the 0.15
  marginal band *and* a robustness mover. Read from `assert_state` in the DB, so the map's reticence
  is a data property. Three of the nine are *Recovering*, so **the map's headline is 8 meeting the
  criterion and 5 asserted** — stated in the title, not buried. Full list and rationale in the Gate E
  report §1.
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

### White meant two things — fixed

**The defect.** The legend read white = *State not asserted*, which is one part (Bala 29ca Inland).
But white also filled **every out-of-scope area** — treed country, the context band, the unzoned
gaps — which was most of the white on the map. A reader could not tell the single deliberate
abstention from ninety holes. **One appearance, two meanings: the same class of error as the two
floors.**

**The fix.** Out-of-scope ground now carries its own fill, `#E5E0D6`, distinctly not white, with its
own legend entry — *"Not assessed (treed / outside census)"* — drawn through `aes()` so it enters
the manual scale rather than being a silent background. Bala 29ca Inland stays white and keeps its
entry, and now also carries a grey outline so a white polygon reads as deliberate rather than as a
gap. **Both captions state that the two are different things.**

### The state palette — RATIFIED, with the reasoning recorded here

**Recorded for the future, per the ruling: no state palette existed in this project before T13.**
The audited deck palette (`docs/change_reports/tier2H_gateE_palette_audit.md`) is per-**community**,
and states are not communities — so a set had to be derived. **This set is now the reference for any
future state map.**

| class | hue | provenance |
|---|---|---|
| Recovering | `#2E7D32` | committed `total_veg` green |
| Unremarkable | `#9E9E9E` | committed neutral grey |
| Declining | `#B2182B` | committed "drier" red |
| Persistently poor — flat | `#8D6E63` | committed `bare` brown |
| Persistently poor — falling | `#4A2C22` | **DERIVED** — darker bare; the only non-committed hue |
| State not asserted | `#FFFFFF` | deliberate abstention |
| Not assessed | `#E5E0D6` | out-of-scope ground |

**Blue was refused for *Recovering* on purpose.** Blue is the committed "good / wetter" pole in the
dashboard palette, but on every other map in this project blue reads as **water** (`flood = #2171B5`),
and a blue "recovering" class beside a flood-frequency surface would be actively misleading. Not
viridis (§6).

---

## 3b. The geography is a finding — stated, never explained

Independently verified from `Output/tables/T13_gateC_classification.csv` (as of 31 July 2026);
reproduces the design-seat table exactly. Groups are the three paddock families by name, which map
onto east / centre / south-west; all 115 parts fall in one of the three.

| state | Bala (E) | Mara (C) | Dinan (SW) | total |
|---|---|---|---|---|
| Recovering | 3 | **0** | 5 | 8 |
| Declining | **12** | 3 | 1 | 16 |
| Persistently poor | 2 | 2 | **10** | 14 |
| Unremarkable | 25 | **32** | 20 | 77 |
| **total** | 42 | 37 | 36 | 115 |

**Declining is an eastern phenomenon — 12 of 16 sit in the Bala group.** Recovering *and*
persistently-poor are both south-western: Dinan holds 5 of 8 recovering and 10 of 14 persistently
poor. The centre is almost entirely unremarkable — **Mara has no recovering parts at all**, and 32
of its 37 are unremarkable.

This is legible from the map before a reader reaches the legend, and it is the most client-usable
statement the task produces. One sentence of it is now in the Figure 1 caption.

**No cause is attributed, on the map or here.** We do not know why the east is declining. The
south-west pattern in particular sits on top of the Bala 29ca / Dinan cluster that L-01 and T10
already identified as compositionally unusual, and the eastern group contains the largest paddocks;
neither observation is an explanation. Nothing in the classification refers to grazing, treatment or
zones by construction (§8), so this is a spatial pattern in cover and water, and stops there.

## 3c. Three conserved paddocks are in the declining set — not two

| part | `level_z` | `trend_z` | dist to level cut | dist to trend cut | robustness mover? | state on drop-2 |
|---|---|---|---|---|---|---|
| Bala 29ca · Inland | −0.962 | −1.108 | **0.038** | 0.108 | **yes** | Unremarkable |
| Bala 27ca · Inland | −0.842 | −1.038 | 0.158 | **0.038** | **no** | **Declining** |
| Bala 26ca · Riverine | −0.322 | −1.072 | 0.678 | 0.072 | **yes** | Unremarkable |

**Two corrections to the ruling as written:**

1. **There are three, not two.** **Bala 26ca · Riverine** (`level_z` −0.322, `trend_z` −1.072) also
   classifies as *Declining*. So **three of the four reference paddocks** carry a declining part —
   which sharpens rather than softens the standing "conserved is a management category, not a
   condition state" finding.
2. **Bala 27ca is *more* marginal on trend than Bala 29ca is, not less.** 27ca sits **0.038** from
   the `trend_z` cut; 29ca sits **0.108** from it. 29ca's 0.038 is on the **level** axis. So the
   stated reason for asserting 27ca does not hold as written.

**But the conclusion holds, on stronger ground.** Bala 27ca is **the only one of the three that is
not a robustness mover** — it stays *Declining* when the two wettest years are dropped, while 29ca
and 26ca both fall to *Unremarkable*. Surviving the robustness run is a better warrant for asserting
a state than distance to a cut, so **27ca's state is asserted** and 29ca's is not, exactly as ruled.

**RESOLVED, 31 July 2026.** The asymmetry flagged here — that **Bala 26ca · Riverine** is in 29ca's
position rather than 27ca's — was fixed by **replacing the named part with a criterion**: state is
not asserted where a part is both inside the marginal band and a robustness mover. Bala 26ca
Riverine and Bala 29ca Inland are both unasserted under it; **Bala 27ca Inland is asserted**,
because it is not a mover. Nine parts qualify in total. See Gate E report §1.

**On Bala 27ca specifically:** this is a third independent route to the same conclusion — no
monitoring sites, the smallest cross-sectional residual, a negative water-adjusted paddock trend at
T10, and now a part-grain *Declining* that survives dropping the two biggest floods.

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
