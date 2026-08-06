# PARTREG — findings, Stages 1 and 2

**6 August 2026.** Cross-session record for the paddock × community part-grain analysis.
Spec: `Gayini_CC_spec_SCHEM1.md`'s sibling, `Gayini_CC_spec_PARTREG.md`, with design-seat
amendments of 6 Aug (Parts 3–6).

**Every value here cites a `number_id` or the `Output/` artefact that produced it.** This document
is not a home for a value.

---

## 1 · What the part grain is, and is not

The paddock × community part is a **parallel output of the T2 Gate B extraction**, not a step below
paddock grain. One extraction produced both: `fact_zone_veg_annual` (64 paddocks × 35 years) and
`fact_zone_community_veg_annual` (118 parts × 35 years). Switching between them is switching
branches.

**118 parts exist; 115 carry sufficient record** (≥25 years of ≥30 valid cells). The three that do
not are Bala 15 · Riverine (23 cells), Bala 28ca · Aeolian (10) and Mara 3 · Aeolian (1).

---

## 2 · The result that matters most — the paddock line survives

`partreg_s1_slope_115parts` against the registered `floor_flood_slope_64pdk`.

**Cutting Figure 25 to the ecological unit does not move the expectation line.** The two slopes
differ by 0.0005. The paddock-grain line is **not** an aggregation artefact, which is the opposite
of what the spec anticipated and is a finding in its own right.

The cost of the finer grain is visible and honest: `partreg_s1_r_115parts` is below the registered
paddock-grain r, and `partreg_s1_residual_sd_115parts` is wider. A smaller unit should do that.

## 3 · The counter-finding — the pooled line does two jobs

**All three community slopes sit below the pooled slope**, and the pooled slope lies **outside the
Inland interval** on 61 of the 115 parts. See `Output/tables/PARTREG_part_regression_coefficients.csv`,
fits `2.6_aeolian`, `2.6_riverine`, `2.6_inland` against `2.3_weighted`.

The pooled line is steepened by **between**-community differences in level and wetness, not by
**within**-community response to water. §2.6's misspecification condition is met.

**No published number becomes wrong.** It means a residual partly measures which community a part
sits in. **Logged, not corrected** — design-seat ruling, 6 Aug 2026: the pack is sealed at v1.2 and
the methods document at V13, three days from the deadline. **This is an article finding.**

The caveat travels with the number: it is written into `partreg_s1_slope_115parts.caveat`, so
anyone reading the value without the figure still meets it.

## 3a · Bala 29ca — the argument in three rows

**The clearest single demonstration that the management zone is not an ecological unit** (L-01),
and the most article-ready thing in this work. Whole-record residuals, from
`Output/tables/PARTREG_part_residuals.csv`:

| part | residual | rank of 115 | cells |
|---|---:|---:|---:|
| Bala 29ca · **Aeolian** | **−24.85 pp** | 2 | 11,848 |
| Bala 29ca · **Riverine** | **−21.58 pp** | 3 | 12,141 |
| Bala 29ca · **Inland** | **+5.87 pp** | 84 | 12,687 |

One paddock, one management category, three near-equal thirds. **Its Inland third holds more cover
than its water predicts, while the other two thirds are the 2nd and 3rd worst on the property.**

The registered paddock-grain residual for Bala 29ca is −16.80 pp
(`v_zone_floor_flood_residual`). **It describes none of the three.** It is an average across
ecological contexts that behave oppositely — which is exactly what L-01 says a paddock-grain number
does where a fence encloses several communities, now measured rather than asserted.

## 4 · The percentile question is closed with evidence

The sweep at p05 / p10 / p20 / p30 / p50 is **monotonic in slope, r and residual SD together** —
the slope falls and the fit tightens as the percentile rises. See fits `2.5_p05` … `2.5_p50`.

**p05 is the metric that carries the signal, not the one that fits best.** That is the answer to a
reviewer who asks why the 5th, and it rests on measured behaviour rather than preference. It closes
the open decision listed in `Gayini_established_data_facts.md` §12.

---

## 5 · Stage 2 — the eras

`partreg_s2_slope_cropping_era` (1988–2013, 26 water years) · `partreg_s2_slope_post_management`
(2018–2022, **five** water years) · whole record = `partreg_s1_slope_115parts`.

**2014–2017 is in no period.** Control passed to the Nari Nari Tribal Council in 2013 and the
irrigation bank cuts are dated 2018, so the four years between are excluded as a transition rather
than assigned to a side. 26 + 4 + 5 = 35.

**All three slope intervals overlap.** The flatter post-management relationship is **reported, not
claimed**, and it rests on five water years.

**Only the fitted relationships are compared. Period levels never are.** A slope is robust to how
wet a window happened to be, because both axes move together; a mean is not. That distinction is
why this analysis survives the period-boundary objection that cut Figure 24 from the pack.

### 5.1 · The restriction costs nothing

All 115 supported parts meet support in **all three** periods, so the common-set restriction drops
none. The whole-record fit on the common set and on the full 115 are identical to four decimals —
shown rather than assumed.

### 5.2 · The spread ratio, as a result in its own right

`partreg_s2_water_spread_ratio`. Within a part, **year-to-year movement in wetness is about twice
the differences in mean wetness between parts**; five parts, all Inland, have a water IQR above 92
points. Source: `Output/tables/PARTREG_S2_spread_ratio.csv`.

**This is the strongest single argument in the analysis for comparing cover at like wetness rather
than between periods**, and it is why the water axis on the Stage 2 figure carries no spread marks:
drawn raw, every point would be a bar wider than the plot's meaningful range.

**Spread, never uncertainty.** No interval is placed on it. 35 consecutive years are not 35
independent observations, and 2.5–97.5 is deliberately not computed — on 35 values those
percentiles are min and max under a false label.

---

## 6 · One interpretation, carried as a HYPOTHESIS

> **This is not a finding. The intervals overlap. It is not in any figure.**

The cropping era is steeper than post-management. **If that difference is real rather than sampling,
the reading is not that cover got worse — it is that cover became less tied to water.** Which is
what you would expect if the bank cuts put water onto ground that had not been watered for decades,
so the historical relationship no longer predicts it.

Recorded here, before anyone reaches for it under time pressure, because it is the sentence the
article will need and the shape of the claim matters more than its wording. **Testing it requires
the land-use history that is still outstanding with Ernest** — a change in a relationship is a
change in a relationship, and attributing it is a separate act.

---

## 7 · Two things this work has made stale

**7.1 · The registered caption on `M5b_paddock_residual_from_expectation.png` is now false in
one clause.** It states: *"There is deliberately NO part-grain version of this map: the expectation
line is fitted across the 64 paddocks and **no part-grain fit has been registered**."* Three
part-grain fits are now registered and three part-grain residual maps now exist. The rest of that
caption still holds — in particular its warning that T13's `level_z` is a different quantity. **The
pack is sealed at v1.2 and the methods document at V13, so this is flagged, not edited.** Design-seat
call.

**7.2 · Two part-polygon objects exist and they are not interchangeable.**

| | features | size | use |
|---|---:|---:|---|
| `T13_part_polygons_epsg8058.gpkg` | 118 | 55 MB | **cell-accurate — the export** |
| `T13_part_polygons_render_only_epsg8058.gpkg` | 118 | 532 KB | simplified — **drawing only** |

Identical attributes, different geometry. Shipping the render-only set as the deliverable would hand
over a simplification under an accurate name. Same family as the three management-zone objects in
CLAUDE.md, and named here so the next reader does not have to rediscover it.

---

## 8 · The deliverable

`Output/spatial_8058/PARTREG_part_residuals.gpkg` — 115 part polygons, EPSG:8058, the full
attribute table joined. A GeoPackage rather than a CSV because a CSV he cannot map is a table.
Beside it, `Output/tables/PARTREG_part_residuals.csv` with `part_id`, `zone_fid`, `paddock_name`
and `community` as join keys so it can also join many-to-one to the 64 paddock polygons, and
`PARTREG_part_residuals_DATA_DICTIONARY.md` — every column, its units, its support, its period.

**Residuals are against each period's own line**, so each reads as *who beat their water in this
era* and the three are comparable as a set.

**The GeoPackage is registered in `table_asset`, not `spatial_layer_asset`** — the latter is an
import registry and a build-output row there is a category error. Recorded on the row.

---

## 9 · Two reconciliations a reviewer will ask for

Both were raised at the design seat on inspecting the GeoPackage, and both resolve exactly rather
than approximately. They belong here as well as in the data dictionary, because they are the kind
of thing a co-author needs to be able to hand over without re-deriving.

### 9.1 · Why the export totals 49,604.8 ha and the footprint ladder says 49,606.9

**Both are right, at different scopes, and the gap is not a polygon-against-raster discrepancy.**

| | cells | ha |
|---|---:|---:|
| all zoned non-treed ground — **118 parts** (the SCHEM-1 ladder) | 795,602 | 49,606.9 |
| the **115 supported** parts (this export) | 795,568 | 49,604.8 |
| difference | **34** | **2.1** |

Thirty-four cells is **exactly** the three sub-support parts: Bala 15 · Riverine (23) + Bala 28ca ·
Aeolian (10) + Mara 3 · Aeolian (1) = 34. The polygonisation contributes nothing — geometry area and
attribute area agree.

**For the analysis footprint the ladder is authoritative; for this table the 115-part total is.**
Anything that differences the two is measuring the support rule, not an error.

### 9.2 · Why the residuals do not sum to zero

Their **unweighted** means are about **+0.82**, **+0.23** and **+0.70** percentage points for the
cropping era, post-management and whole record.

**The fit is pixel-weighted, so it is the *weighted* residual mean that is guaranteed to vanish —
and it does, to within 1e-6 in all three periods.** That is the proof, not a reassurance. An
unweighted average of a weighted fit's residuals carries no such guarantee, and the sign of the gap
just says that the smaller parts sit above the line slightly more often than the large ones.

**This is a property of the estimator, not a defect in the table.** Source:
`Output/tables/PARTREG_part_residuals.csv`, weights in `n_pixels_part`.
