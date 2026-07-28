# Reference-state follow-on specs — T7 to T11

**Version:** v1 · 28 July 2026
**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Depends on:** T1, T2, T6 (complete, merged)
**Context:** `Gayini_reference_state_methods.md`, `Gayini_reference_state_results_catalogue.xlsx`

Five specs. **T8 runs first and blocks the others** — it pins the definitions the rest read from.

Standing rules apply to every task: additive writes only · never re-run the builder · resolve
paths from the database, never hardcode · never merge support levels in one figure · branch
and PR with human merge · no AI attribution in commits · four-CRS discipline · re-read this
spec in full and echo it verbatim at the start of every gate.

---

# T8 — One number, one definition

**Priority:** FIRST. Blocks T7, T9, T10, T11.
**Status:** the reason this task exists is measured, not suspected.

## Spine anchor

| | |
|---|---|
| **Serves** | Every claim in the reference-state deck |
| **Claim under test** | That each headline number has exactly one defensible value |
| **Why we are doing this** | The reference-minus-grazed floor gap for 1988–92 takes eight values between −9.1 and −14.8 pp depending on grain, aggregation order and seasonal variant. All eight are defensible. All eight come from the same database. The deck reports −13.1 with two of the four qualifiers stated. The database is not wrong; the numbers are under-specified. |
| **What would falsify it** | If pinning the qualifiers still leaves material spread, the quantity is not estimable at this support and must be reported as a range, not a point |
| **Spine return** | A registered definition per headline number, and a reproduction test that fails loudly when a figure drifts from it |

## The measured problem

Same quantity, eight ways (verified 28 July against `Gayini_Results.sqlite`):

| grain | order | variant | gap |
|---|---|---|---|
| zone | year-first | mean_of_seasons | −13.1 |
| zone | zone-first | mean_of_seasons | −13.2 |
| zone | year-first | jja_son | −11.2 |
| zone | zone-first | jja_son | −11.3 |
| zone × community | year-first | mean_of_seasons | −14.8 |
| zone × community | zone-first | mean_of_seasons | −12.0 |
| zone × community | year-first | jja_son | −13.4 |
| zone × community | zone-first | jja_son | −9.1 |

A second instance of the same failure: the three-arm mean floor deficit reads
−4.8 / +4.3 / +5.9 over the nine real strata and −6.1 / +4.2 / +5.5 if the `regime_band = 'ALL'`
rollup rows are left in. The view returns both; nothing in the view says which to use.

A third: `18%` (unzoned inside the mapped census, 12,179 ha) and `21.6%` (outside the mapped
census, 18,562 ha) are different quantities that both describe "missing area" and are
routinely confused.

## Gates

### Gate A — Inventory · STOP

No writes. For every number that reaches a deliverable — start from the `Headline_numbers`
sheet of `Gayini_reference_state_results_catalogue.xlsx`, 18 rows — record:

- source object, and whether it is a table or a view
- grain (`aggregation_unit`)
- aggregation order where a mean and a median are composed
- `series_variant`
- scope filter, explicitly including whether `regime_band = 'ALL'` rows are in or out
- period boundaries
- denominator and pixel constant
- the value the deck currently reports

Then, for each, compute the value under every defensible alternative and report the spread.
**Report the spread; do not choose yet.** Choosing is a science decision for the design seat.

**STOP.** Review the spread table before anything is pinned.

### Gate B — Pin the definitions (additive)

New table. One row per headline number.

```
dim_headline_number
  number_id           TEXT PRIMARY KEY   -- 'ref_gap_floor_p1'
  label               TEXT NOT NULL      -- human-readable
  source_object       TEXT NOT NULL      -- view or table name
  grain               TEXT NOT NULL
  aggregation_order   TEXT NOT NULL      -- 'year_median_then_period_mean'
  series_variant      TEXT NOT NULL
  scope_filter        TEXT NOT NULL      -- verbatim SQL WHERE fragment
  period_label        TEXT
  denominator         TEXT
  pixel_constant      REAL
  pinned_value        REAL NOT NULL
  spread_min          REAL               -- from Gate A
  spread_max          REAL
  decided_by          TEXT               -- who chose, and when
  decision_note       TEXT               -- why this option and not the others
```

`spread_min` and `spread_max` are mandatory and must be populated from Gate A even where the
spread is zero. A reader must be able to see how much the choice mattered.

### Gate C — Reproduction test

A test that, for every row in `dim_headline_number`, recomputes the value from
`source_object` under the recorded qualifiers and asserts it equals `pinned_value` to 0.05 pp.
Wire it into the existing smoke test alongside the magic-number and OR-IGNORE lints.

Any figure or deck number that cannot be traced to a `number_id` is a defect. Add a lint that
greps `docs/` and the deck build scripts for bare decimal-pp strings and flags any not
present in `dim_headline_number`.

### Gate D — Retire the ambiguous view returns · STOP

Add `is_rollup INTEGER` to `v_three_arm_gap_decomposition` (1 where `regime_band = 'ALL'`),
so a consumer cannot silently average rollups with strata. Do not delete the rows.

Rename nothing. Additive only.

**STOP.** Report before the change report.

## Acceptance criteria

- [ ] `dim_headline_number` populated for all 18 catalogue numbers, `spread_min`/`spread_max` non-null
- [ ] Reproduction test passes and is wired into the smoke test
- [ ] `is_rollup` present on the three-arm view; row count unchanged
- [ ] No existing table or view modified or dropped
- [ ] Change report in `docs/change_reports/`

---

# T7 — Persistence surface: recolour, overlay, vectorise

**Depends on:** T8 Gate B (for the threshold provenance fields)

## Spine anchor

| | |
|---|---|
| **Serves** | Adrian's 24 July §5.2 — the refugia × LiDAR overlap |
| **Claim under test** | None. This produces a shareable spatial product, not a science claim |
| **Why we are doing this** | The persistence surface exists only as a PNG in viridis with no paddock context and no vector form. Adrian cannot overlay his LiDAR model on a PNG. A GeoPackage he can open in QGIS is the deliverable that unblocks the two-sensor test. |
| **What would falsify it** | If the polygonised surface has so many fragments that it is unusable, report the fragment-size distribution and offer a minimum-mapping-unit cut rather than shipping it |
| **Spine return** | Registers a vector asset in `spatial_layer_asset` and a reworked figure |

## Context

`veg_persistence_duration_8058.tif`, band `pct_above_70`. Percent of observed years in which
mean total vegetation exceeded 70%. Denominator `veg_valid_years`, NA below 10. Currently
rendered by `T2_gateE_figures.R` at `aggregate(dur, 12)` — a 12× downsample used only for
display speed.

**The current colour ramp puts yellow at the maximum.** Yellow reads as dry to anyone who has
looked at a satellite image, and this surface's maximum means permanently vegetated. The ramp
is inverted against intuition.

## Gates

### Gate A — Recon · STOP

- Resolve the raster path from `raster_asset`. Confirm `path_exists`, CRS 8058, resolution.
- Report the value distribution of `pct_above_70`: min, max, deciles, NA count and where the
  NAs are.
- Report at what aggregation factor the display raster stops being faithful. **The map must be
  rendered at native resolution or at the mildest aggregation that still renders** — 12× was a
  speed choice, not a cartographic one, and it should be revisited now the figure is a
  deliverable rather than a diagnostic.

**STOP.**

### Gate B — The figure

Rebuild `T2_B2_duration_map` with:

1. **A sequential ramp running pale to emerald green, emerald at the maximum.** Suggested:
   low `#F1EDE2` (warm cream, the deck background) → mid `#7FB09A` → high `#0E7A5F`
   (emerald). Do not use viridis. Do not put yellow at either end.
2. **Management zone boundaries overlaid** — thin, unfilled, and in a neutral that reads over
   both ends of the ramp (`#3A3A3A` at 0.3 pt, or white at 0.4 pt; test both and pick by
   legibility, do not guess).
3. **The four reference paddocks outlined more heavily and labelled** (Bala 26ca, 27ca, 28ca,
   29ca). This is the whole point of the overlay — the reader must be able to see whether the
   ungrazed paddocks sit on persistently green ground.
4. A north arrow and a scale bar. The current map has neither and is axis-labelled in raw
   eastings and northings, which is unreadable for a non-technical audience.
5. Caption stating the threshold, the denominator, and that this is a **persistence** measure,
   distinct from `veg_p05`.

Produce two variants, both registered: one full-property, one cropped to the four reference
paddocks with a generous buffer.

### Gate C — Vectorise

Polygonise `pct_above_70` into a GeoPackage for external use.

```
Output/spatial/gayini_veg_persistence_8058.gpkg
  layer: persistence_classes   (polygons)
    class_id      INTEGER      -- 1..n
    class_label   TEXT         -- e.g. '90-100% of years'
    pct_min       REAL
    pct_max       REAL
    area_ha       REAL
    n_pixels      INTEGER
  layer: persistence_high      (polygons)
    -- single class at the selected high threshold, for the LiDAR overlay
    threshold_pct REAL         -- the cut used, stated not implied
    area_ha       REAL
    part_id       INTEGER
  layer: management_zones      (copy, for convenience in QGIS)
```

Decisions that must be explicit, not silent:

- **Class breaks.** Propose breaks at 0–25 / 25–50 / 50–75 / 75–90 / 90–100 and report the
  area in each. If a natural break exists in the distribution, use it and say so; if not, say
  the breaks are arbitrary. Do not invent a break that isn't there.
- **The high-persistence cut** for `persistence_high`. Report area at 80, 85, 90 and 95 so the
  choice is visible, and record the selected value in the layer attributes.
- **Minimum mapping unit.** Report the fragment-size distribution before applying one. If a
  MMU is applied, record it in the layer metadata and report how much area it removed.
- **No smoothing.** Polygon edges will be blocky at 24.97 m. That is honest. Do not simplify
  geometry to make it look better — the source is 30 m data bilinearly resampled, and smooth
  edges would imply precision that isn't there.

Register in `spatial_layer_asset` with CRS, extent, SHA-256, and a `legend_semantics` string
stating the threshold, the denominator, the source raster, and the 30 m native-resolution
caveat.

### Gate D — STOP

Report class areas, the fragment distribution, and both figure variants for review.

## Acceptance criteria

- [ ] Emerald at maximum; no yellow at either end of the ramp
- [ ] Management zones overlaid; four reference paddocks outlined and labelled
- [ ] North arrow and scale bar present
- [ ] GeoPackage opens in QGIS with all three layers, CRS 8058, correct extent
- [ ] `persistence_high` carries `threshold_pct` as an attribute
- [ ] Registered in `spatial_layer_asset` with checksum and legend semantics
- [ ] Area totals reconcile against the raster within 0.1 ha

---

# T9 — Open-water masking sensitivity

## Spine anchor

| | |
|---|---|
| **Serves** | The mean-versus-floor result, and every floor number in the deck |
| **Claim under test** | That the reference paddocks' longer low-cover tails are sparse vegetation rather than standing water |
| **Why we are doing this** | `T2_gateB_extract.R` filters the vegetation raster on `!is.na(v)` and nothing else. The wet/valid stacks are extracted in a separate loop and used only for counts. Open water reads as low fractional cover, so it sits inside every `veg_p05_spatial` value. Bala 26ca and 28ca are 45% and 43% inundated and carry internal tails of 18–20 pp against a grazed median of 11.6. Dawson et al. (2016) excluded flooded images for exactly this reason. |
| **What would falsify it** | If masking water changes the floor by less than 1 pp in every paddock, the concern is closed and the standing caveat can be retired |
| **Spine return** | Either a corrected floor series, or a registered sensitivity result closing limitation L-3 |

## Gates

### Gate A — Recon · STOP

Report, per paddock-year, the count and share of in-scope pixels flagged wet in that year.
Report the distribution of `veg_mean` for wet pixels against dry pixels. **If wet pixels are
not materially lower in cover, the premise is wrong and the task stops here.**

**STOP.**

### Gate B — Masked re-run

Re-run the T2 Gate B extraction with a second variant in which pixels flagged wet in that
water year are excluded before the percentile is taken. Write to a new
`series_variant` value — `mean_of_seasons_drymask` — stacked into the same table.

**Do not overwrite the existing variants.** This is a sensitivity arm, not a correction, until
the design seat decides it is one.

Record the pixel count dropped per paddock-year; a paddock-year that falls below the existing
minimum support after masking must be dropped by the same rule and logged.

### Gate C — Report · STOP

For every headline floor number in `dim_headline_number`, report the masked value beside the
pinned value and the difference. Report separately for the four reference paddocks, since
they are the ones the claim rests on.

**STOP.** Do not update any figure until the difference is reviewed.

## Acceptance criteria

- [ ] New `series_variant` present; existing variants byte-identical
- [ ] Masked-versus-unmasked comparison for all headline floor numbers
- [ ] Per-paddock dropped-pixel log
- [ ] Change report

---

# T10 — Wetness-controlled re-cut of the headline

**Depends on:** T8 Gate B

## Spine anchor

| | |
|---|---|
| **Serves** | The deck's central claim |
| **Claim under test** | That the reference-grazed floor gap survives control for wetness |
| **Why we are doing this** | The five-period table compares whole paddocks. Across 64 paddocks the floor tracks mean annual inundation at r = 0.71. Bala 29ca is the fourth-driest paddock at 8.5% against a grazed median of 28.6%. T6 controls this by stratum; T1 reports the flood delta alongside; the headline table does neither. |
| **What would falsify it** | If the gap vanishes entirely under control, the headline is a wetness artefact and the deck's central slide must be withdrawn. **That is an acceptable outcome and must be reported as readily as a positive one.** |
| **Spine return** | Replaces or confirms the five-period table |

## Context

An in-chat regression on 28 July gave slope +0.55 pp per pp of flood frequency, r = 0.71, and
a Bala 29ca residual of about −17 pp against a raw gap of −42 pp. **That computation is not a
result** — it was run outside the pipeline with no registration. This task makes it real, or
disproves it.

## Gates

### Gate A — Locate the missing derivation · STOP

The five-period split (1988–92 / 1993–2002 / 2003–12 / 2013–18 / 2019–22) is not produced by
any script in the repo. `T2_gateE_figures.R` writes a two-window report instead. Find the
script, or establish that it does not exist.

**Report which. Do not rebuild it silently** — if the deck's central table has no script, that
is a finding in its own right and belongs in the issues log.

**STOP.**

### Gate B — Stratum-grain re-cut

Recompute the five-period gap within each of the nine community × wetness strata, then roll up
area-weighted. Report both the per-stratum gaps and the rollup.

### Gate C — Residual approach

Fit the paddock-level floor against mean annual flood frequency and report each paddock's
residual, with the four reference paddocks identified. Report r, slope, and the residual
standard error. Include a paddock-level table so any reader can see where every paddock sits.

Report the two comparators explicitly: Bala 29ca's residual, and Dinan 10's — a grazed paddock
at 5.1% inundation and a 40.4% floor, which appears to be Bala 29ca's near-twin on wetness.

### Gate D — STOP

Report the raw gap, the stratum-controlled gap and the residual gap side by side, for all five
periods.

## Acceptance criteria

- [ ] Five-period derivation located or its absence recorded in the issues log
- [ ] Per-stratum and rolled-up gaps for all five periods
- [ ] Paddock-level residual table, all 64 paddocks
- [ ] Three-way comparison table
- [ ] Registered; no existing object modified

---

# T11 — Paddock choropleths

**Depends on:** T8 Gate B

## Spine anchor

| | |
|---|---|
| **Serves** | The deck's spatial claims, which currently have no map |
| **Claim under test** | Whether the floor pattern is a management pattern or a hydrological one |
| **Why we are doing this** | The deck argues that wetness organises the floor more strongly than management does, and shows no map of either. Both quantities are already in `fact_zone_veg_annual`; this is two joins and two renders. |
| **What would falsify it** | Nothing — this is descriptive. But if the two maps look alike, that *is* the finding, rendered. |
| **Spine return** | Two registered figures |

## Gate A — Build

Two choropleths on the management zone polygons, same classification method and the same
number of classes so they are directly comparable:

1. **Mean vegetation floor per paddock** (`veg_p05_spatial`, mean over 35 years,
   `mean_of_seasons`, pinned per T8)
2. **Mean annual inundation per paddock** (`flood_frac_pct`, same span)

Requirements: the four reference paddocks outlined and labelled on both · a diverging or
sequential ramp consistent with the deck palette, not viridis · north arrow and scale bar ·
identical class breaks between the two maps where the units allow, or clearly different
legends where they do not · state the classification method in the caption.

Produce a third panel showing the **residual** from T10 Gate C once that lands, so a reader
can see which paddocks are better or worse than their wetness predicts.

## Acceptance criteria

- [ ] Both maps at paddock support, reference paddocks labelled
- [ ] Classification method stated
- [ ] Registered via `write_and_register_figure()`
- [ ] Area and value totals reconcile against `fact_zone_veg_annual`

---

## Not for Claude Code

These are design-seat or human tasks and must not be sent to a build session:

- Email Ernest for the Bala 29ca land-use history
- Ask Nari Nari whether the unzoned country is grazed more, less or not at all
- Ask about stocking rates or DSE per hectare
- Decide which of the four ways forward the project is taking, before 10 August
- Choose the pinned option for each number at T8 Gate B
