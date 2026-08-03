# T3 — Persistent vegetation surfaces and the always-green threshold

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** **v3 · 27 July 2026** — supersedes v2 and v1. Overwrite in place.
**Depends on:** nothing (independent of T1 and T2 — may run in parallel)
**Blocks:** the LiDAR structural overlap; spine §6
**Status:** **HIGHEST PRIORITY.** Adrian's §7.1 — *"highest value, most immediately testable."* He is bringing the LiDAR shrub-height model to overlay against this output.

---

## Amendment log

### v2 → v3 — 27 July 2026

| # | Severity | What changed | Where |
|---|---|---|---|
| **A** | HIGH | **Gate A1 is rewritten from an investigation to a read.** v2 asked CC to reconcile three refugia lineages. **Task M already did this and the question is closed** — `green_at_floor()` measures the green share of remaining cover, not total cover, and the ~4,300 ha figure is withdrawn. v2 would have burned a session re-deriving a finished result. | Gate A1 |
| **B** | HIGH | **Two surfaces, not one.** Adrian's ask ("map the pixels that stay greenest for longest") is not satisfied by the total-veg floor alone. Both the total-veg floor and the green-share floor are produced, and the comparison between them is itself a result. | New Gate B2, Gate C |
| **C** | MED | **The metric question is pinned explicitly** rather than resolved in code. "Greenest for longest" is a third quantity, distinct from both metrics already in play. Gate A2 puts the choice in front of a human. | New Gate A2 |
| **D** | MED | `support_level` / `aggregation_unit` split applied — the closed-ladder fix already made in T1. | Gate C |
| **E** | LOW | Corrected the census p05 range. v2 repeated the spine's `[1.19, 97.00]`; 97.00 is the **`veg_p50`** max. p05 is `[1.19, 91.85]` all-pixel, `[1.19, 88.66]` non-treed. | Context |
| **F** | — | LiDAR overlay is now an explicit deliverable with a named output, not a follow-on note. | Gate E |

### v1 → v2 — 25 July 2026

| # | Severity | What v1 got wrong | Where |
|---|---|---|---|
| **F2** | HIGH | Every area in v1's sweep table was inflated 0.238% — v1 used 0.0625 ha/px; the grid is 24.970268 m = **0.062351428**. Now enforced by `gayini_params.PIXEL_AREA_HA`. | Context, Gate B |
| **F4** | MED | v1's non-treed scope was `treed_context_flag = 0`, which admits **ten** strata. | Context, Gate B |
| **F7** | MED | Gate A was to verify CRS/extent from `raster_asset`. Extents are in fact populated (126/126) — the "98 of 98" QA row is stale. | Gate A |
| **F11** | — | v1's FC-saturation hypothesis is **withdrawn**: no pile-up at the ceiling. | Context, Gate B |

---

## Spine anchor

| | |
|---|---|
| **Serves** | Spine §2 — **S3** (the floor headline) and **S6** (bounds); Adrian's §5.2 (refugia × LiDAR) |
| **Claim under test** | That a defensible, stated threshold identifies a persistent vegetation surface — and that the surface coincides with an independently sensed structural feature |
| **Why we are doing this** | The LiDAR overlap is the project's best route through the structure-versus-condition boundary. If a spectrally-derived persistence surface and an independent structural sensor agree, two different instruments corroborate each other and the central caveat weakens. Nothing else on the board attacks that limitation. |
| **What would falsify it** | If area is highly sensitive across plausible thresholds with no natural break, "refugia" is a chosen cut on a continuum and must be reported as a gradient surface, not an area figure. If the surfaces and the LiDAR lignum do **not** overlap, that is a real and reportable negative — it says the spectral floor is not picking up the structural feature. |
| **Spine return** | Confirms or revises the §4 refugia row; sets the threshold used in every downstream figure. |

---

## Context

### The FC legend gate is closed

All 18 `crs_epsg = 8058` rasters carry `legend_status = 'confirmed'`: percent, **no JRSRP +100 offset**. Independently confirmed — census `veg_p05` ranges **[1.186, 91.847]** all-pixel and **[1.186, 88.660]** non-treed.

*The spine's §5 C-3 states this range as `[1.19, 97.00]`. The minimum is right; **97.00 is the `veg_p50` maximum, not p05**. The conclusion stands. Flag for T4; do not act on it here.*

### Scope definitions — use `gayini_params`, never a literal

| Scope | Filter | n pixels |
|---|---|---|
| `non_treed` | `SCOPE_NON_TREED` = `treed_context_flag = 0 AND regime_band <> 'context'` | **988,831** |
| `all_pixel` | `SCOPE_ALL_PIXEL` | **1,080,157** |

`treed_context_flag = 0` **alone gives 993,782 px across ten strata** — it admits `Other / minor units`. Do not use it.

Pixel area comes from `gayini_params.PIXEL_AREA_HA` (derived). The magic-number lint fails the run on a bare `0.0625`.

### The corrected sweep — total-veg floor, `non_treed`

| p05 ≥ | pixels | area (ha) | % of mapped | % of true farm | mean flood freq |
|---|---|---|---|---|---|
| 50 | 656,536 | 40,935.96 | 60.78% | 47.65% | 29.81 |
| 55 | 564,620 | 35,204.86 | 52.27% | 40.98% | 31.91 |
| 60 | 454,688 | 28,350.45 | 42.10% | 33.00% | 34.58 |
| 65 | 321,499 | 20,045.92 | 29.76% | 23.33% | 38.38 |
| 70 | 202,734 | 12,640.75 | 18.77% | 14.71% | 43.27 |
| 75 | 133,123 | 8,300.41 | 12.32% | 9.66% | 47.86 |
| 78 | 97,685 | 6,090.80 | 9.04% | 7.09% | 49.48 |
| **80** | **67,028** | **4,179.29** | **6.21%** | **4.87%** | **49.34** |
| 85 | 1,702 | 106.12 | 0.16% | 0.12% | 46.97 |

`all_pixel` for reference: ≥ 50 → 744,408 px / 46,414.90 ha; ≥ 80 → 88,462 px / 5,515.73 ha.

Two structural features survive and are still the interesting part:

- **The 80→85 collapse is real** — 4,179 ha to 106 ha. **Not instrument saturation** (F11 withdrawn); treat it as a distribution tail.
- **Mean flood frequency stops rising at ~78–80** (49.48 → 49.34 → 46.97). Above that the surface no longer selects for wetness. Either the interesting part of the result or a small-*n* effect.

### The two floor metrics — and why they must never be conflated

This is the most-confused pair of numbers in the project. Both are legitimate; they measure different things.

| | **Total-cover floor** | **Green-share floor** |
|---|---|---|
| Definition | `veg_p05` — across-series 5th percentile of total veg (green + dead) per pixel | `100 × PV ÷ total_veg > 50`, evaluated at each pixel's total-veg p05 season |
| Question it answers | *How much cover survives the worst seasons?* | *When cover is at its worst, is what remains still alive?* |
| Built by | This task (percentile rasters) | **Task M, already complete** |
| Lives in | `v_always_green_sweep` (this task) | `Output/tables/taskM_green_at_floor_area.csv` |
| Withdrawn figure | — | ~4,300 ha (a mismatched 8058 conversion of a native-30 m count) |

**Every caption, table and slide must name which one it uses.**

---

## Gates

### Gate A — Recon (read-only) · **STOP**

1. **Paths from the DB.** Resolve the five percentile rasters from `raster_asset` where `product = 'total_veg_percentile_8058'`. Confirm `path_exists`.
2. **Geometry from headers, not the registry.** Verify CRS, resolution (≈ 24.970268 m) and extent with `terra::crs()/res()/ext()` and `compareGeom()` against `veg_regime_class_8058.tif` per data contract §8. *Note: `raster_asset` extents are already populated on all 126 rows — the "98 of 98 lack extent" QA row is stale. No backfill needed.*
3. **Legend.** Report `legend_semantics` verbatim, including that the percentiles are natively **30 m bilinear-resampled onto the 24.97 m census grid**. **This caveat travels with every area figure this task produces** — the polygons will have edges finer than the source supports.
4. **Pooling depth.** Confirm the percentiles pooled over **140** seasonal composites (WY1988–2023, 4 seasons/WY), not 153. The 153-date figure is the *plot* series to 2026 — a different lineage.
5. **Nulls — confirm, don't re-derive.** `veg_p05` non-null = 1,080,002; **155 nulls, 153 in the treed Woodland stratum and 2 in Inland Floodplain.** The null pattern is identical across all five percentile columns, so `non_treed` carries only 2 nulls.
6. **Constants.** State in the recon note that areas come from `gayini_params.PIXEL_AREA_HA`.

**STOP.**

### Gate A1 — Read the Task M result and align · **STOP** · *rewritten in v3*

**Do not re-derive anything in this gate.** Task M closed the provenance question that v2 asked about. This gate reads that result and makes sure T3's language cannot re-open it.

1. Read `Output/tables/taskM_green_at_floor_area.csv` and report the green-share floor area **with its full definition columns**, exactly as recorded there.
2. Confirm from the Task M change report that the metric is `100 × PV ÷ total_veg > 50` paired at each pixel's total-veg p05 season — **not** `veg_p05 ≥ 50`.
3. Confirm the ~4,300 ha figure is marked withdrawn, and that the grid mismatch explained only the 6,458 ↔ 4,474 ha pair.
4. **Report the two numbers side by side** — the Task M green-share area and this task's total-cover area at the candidate threshold — with a one-line statement of what each measures.

**STOP.** The only decision here is whether the language separating the two metrics is tight enough to survive a deck rebuild.

### Gate A2 — Pin the persistence metric · **STOP** · *new in v3*

Adrian's ask is to *"map the pixels that stay greenest for longest."* That phrase names a **third** quantity, and it must be chosen by a human before code runs.

| Option | Definition | Cost | What it answers |
|---|---|---|---|
| **1 — Total-cover floor** | `veg_p05` (already built) | zero | Level exceeded in 95% of seasons. Magnitude with duration implicit |
| **2 — Green-share floor** | Task M `green_at_floor` (already built) | zero | Whether surviving cover is alive at the worst point |
| **3 — Duration count** | Count of years where annual veg > threshold, from the 35-layer `total_veg_annual_8058` stack | small, **but the stack is T2's input** | Literally "for how many years" |

**Recommendation: options 1 and 2 in this task; option 3 as a T2 by-product.** Options 1 and 2 exist now and cover both halves of Adrian's phrase — *greenest* (green share) and *for longest* (the floor is the level held 95% of the time). Option 3 is a genuine duration measure but requires the annual stack T2 is already reading, so building it here would duplicate T2's raster access.

**Report the recommendation and stop.** Do not implement option 3 in T3 under any circumstance.

**Also confirm at this stop: is the reference set three paddocks or four?** T1 found **four** `No grazing` zones — `Bala 26ca, 27ca, 28ca, 29ca` (fids 1–4). Verbal accounts have said three. Adrian's §5.2 places the lignum swamp inside "the pink paddocks." **This set defines the reference state for S5 and for T2's panel, so it must be pinned once, in the DB, not carried verbally.** Report which zones are in and out, and whether the fourth is a definitional difference or a miscount.

### Gate B1 — Full sweep and break characterisation

Sweep `veg_p05` from 40 to 90 in steps of 1, `non_treed` and `all_pixel` **separately**, using `gayini_params` scopes and `PIXEL_AREA_HA`.

Per threshold: pixel count, area, % of mapped (67,349.332), % of true farm (85,910.8) — **both bases, never rebased** — mean and median flood frequency, and count of distinct connected components ≥ 5 ha.

Then characterise:

- Plot area against threshold; identify whether a natural break exists **or report honestly that the decline is smooth.** A smooth curve means "refugia" is a chosen cut on a continuum and the manuscript must say so.
- **Characterise the 80→85 collapse.** Saturation is ruled out. Test whether the upper tail is simply thin and whether the drop is consistent with its shape. Report the p05 histogram above 75 with counts.
- Report **elasticity** of area to threshold around the candidate cut, so the manuscript can state how fragile the headline is.
- Report where mean flood frequency peaks and whether enough pixels support the peak.

### Gate B2 — The green-share surface · *new in v3*

Produce the green-share floor as a **raster surface** on the canonical 8058 grid, matching the Task M table definition exactly. Task M produced the area; this produces the map Adrian needs for the overlay.

- Reuse the Task M `green_at_floor()` implementation. **Do not re-implement the metric** — if the code is not reusable as a surface generator, report that rather than writing a second version.
- Verify the surface's area reconciles with `taskM_green_at_floor_area.csv` at the same threshold and grid. **A mismatch here means one of the two is wrong; report it, do not adjust to match.**
- Register in `raster_asset` with CRS, extent, resolution, checksum, and a `legend_semantics` string stating the **metric definition, the threshold, the scope filter, the pixel constant, and the 30 m native-resolution caveat.**

### Gate C — Persist

```
v_always_green_sweep
  threshold, scope,              -- scope: 'non_treed' | 'all_pixel'
  metric,                        -- NEW: 'total_cover_floor' | 'green_share_floor'
  n_pixels, area_ha, pct_of_mapped, pct_of_farm_total,
  flood_freq_mean, flood_freq_median,
  n_components_ge_5ha,
  pixel_area_ha,                 -- the constant used, stored per row
  scope_filter_sql,              -- the literal filter
  is_selected_threshold,         -- 1 on exactly one row per (scope, metric)
  support_level,                 -- 'pixel'        (closed ladder)
  aggregation_unit               -- 'pixel'        (free text)
```

`metric` is new in v3 and is the column that makes the two floors impossible to conflate in a query. `pixel_area_ha` and `scope_filter_sql` exist because the two things that went wrong in v1 were an unstated constant and an unstated scope.

Plus a per-pixel boolean surface **for each metric** at the selected threshold, on the canonical 8058 grid, registered in `raster_asset` with full metadata and a legend string that states threshold, metric definition, scope filter, pixel constant and the 30 m caveat. A future reader must recover the whole decision from the raster alone.

Additive `INSERT OR REPLACE` keyed on `(threshold, scope, metric)`. **No builder re-run.**

### Gate D — Threshold decision · **STOP**

Present the sweep, the break characterisation, the Gate A1 alignment and a recommendation with reasoning, **for each metric separately**. **Do not set `is_selected_threshold` without human sign-off** — this sets a number that goes in the abstract.

Carry into the decision: the LiDAR overlap needs enough area to overlap meaningfully. A threshold yielding 106 ha cannot test anything; one yielding 41,000 ha tests nothing either. **State the operational range explicitly.**

### Gate E — LiDAR overlay package · *new in v3*

Adrian's deliverable. Produce, at the selected thresholds:

1. `Output/rasters/persistence_8058/` — both boolean surfaces, registered.
2. A **GeoPackage** of the persistence polygons (both metrics as separate layers, dissolved, components ≥ 5 ha) in EPSG:8058, ready for direct overlay in his GIS.
3. `Output/tables/T3_persistence_vs_hydrology.csv` — per component: area, mean flood frequency, distance to nearest mapped channel if a channel layer is registered (report absent if not), which metric flagged it, and whether it falls inside the reference paddocks.
4. A short README stating CRS, threshold, metric definitions, the 30 m caveat and the pixel constant.

**Point 3 is the substantive test of Hugh's expectation** that persistence concentrates around channels and the lignum swamp. If the components are *not* channel-associated, that is a real finding and must be reported as readily as confirmation.

**Do not attempt the overlay itself** — the LiDAR model is Adrian's and has not arrived. This gate makes the overlay a five-minute job when it does.

---

## Gate figures — mandatory

A gate does not close until its figure exists **and is registered in `figure_asset` in the same transaction** via `write_and_register_figure()` (R, first-50-MB SHA-256). Output to **`Output/figures/diagnostics/`** with the `T3_` prefix. **Every caption states the support level and the 30 m native-resolution caveat.**

*Amended 3 August 2026 (Gate D decisions, approved). v3 said `figures/diagnostics/`; that directory does not exist. The live convention is `Output/figures/diagnostics/`, which is where all ten T3 gate figures were written.*

| Gate | Figure | What it must show | Passes if |
|---|---|---|---|
| A | `T3_A_percentile_alignment.png` | Five percentile raster extents over `veg_regime_class_8058.tif` | All six coincide exactly |
| A | `T3_A_null_map.png` | The 155 nulls located, coloured by stratum | 153 sit inside the treed stratum; 2 are isolated |
| A1 | `T3_A1_two_metrics.png` | The two floor areas side by side, each labelled with its full definition | A reader cannot mistake one for the other |
| B1 | `T3_B_area_vs_threshold.png` | Area vs threshold, both scopes, log-y, candidate cut marked, elasticity annotated | Whether a break exists is visually answerable |
| B1 | `T3_B_p05_upper_tail.png` | `veg_p05` histogram above 75, bin width 1, counts labelled | The 80→85 collapse is explained by tail shape, or it is not |
| B1 | `T3_B_floodfreq_vs_threshold.png` | Mean flood frequency vs threshold, *n* on a secondary axis | The ~78–80 peak is either supported by *n* or exposed as noise |
| B2 | `T3_B2_green_share_map.png` | The green-share surface over the property | Spatially coherent patches |
| C | `T3_C_persistence_map.png` | **THE MAP.** Both surfaces over the property, zone boundaries and channels overlaid, thresholds in the title | Persistence is coherent, and its relationship to channels is visible |
| D | `T3_D_threshold_sensitivity.png` | Small multiples at 70 / 75 / 80 / 85 | The reader sees what the threshold choice buys |
| E | `T3_E_components_vs_floodfreq.png` | Component area against mean flood frequency, reference paddocks marked | The channel/lignum expectation is tested, not assumed |

`T3_C_persistence_map.png` and `T3_E_components_vs_floodfreq.png` are the two Adrian will open first.

---

## Acceptance criteria

- [ ] Sweep covers 40–90 step 1, both scopes, **both metrics**; `metric` populated on every row.
- [ ] Total-cover values reproduce the Context table: 40,935.96 / 20,045.92 / 8,300.41 / **4,179.29** ha at 50/65/75/80 within rounding. *(v1's 41,338 / 20,339 / 8,355 / 4,193 are wrong — do not match them.)*
- [ ] Areas derived from `gayini_params.PIXEL_AREA_HA`; magic-number lint passes.
- [ ] `scope_filter_sql` populated; `non_treed` rows carry the nine-stratum filter.
- [ ] Both area bases present; neither rebased.
- [ ] `support_level = 'pixel'` (closed ladder) and `aggregation_unit` populated on every row.
- [ ] Exactly one `is_selected_threshold = 1` per (scope, metric), set only after sign-off.
- [ ] Green-share surface area reconciles with `taskM_green_at_floor_area.csv`, or the mismatch is reported unadjusted.
- [ ] Both rasters registered with checksum and a legend string stating metric, threshold, scope, pixel constant and the 30 m caveat.
- [ ] The 155 nulls confirmed as 153 treed / 2 non-treed.
- [ ] **Gate A1 delivered as a read of the Task M result — nothing re-derived.**
- [ ] **Gate A2 recommendation delivered, and the reference-set question (3 vs 4 paddocks) answered from the DB.**
- [ ] Gate E package complete: rasters, GeoPackage, component table, README.
- [ ] All ten gate figures written and registered.
- [ ] Re-run produces identical outputs. No existing table or view modified or dropped.
- [ ] Change report in `docs/change_reports/`, committed.

## Standing rules

- **Additive only.** No deletes; moves to `_archive/` only.
- **Never re-run the builder.** `reset_file` would destroy 12 unreproducible Task H rows.
- **Idempotence by convergence, not stability** — mutate an input, re-run, confirm the DB moves to the new value. `INSERT OR REPLACE`, never `OR IGNORE`.
- **Paths from the DB**; constants from `gayini_params`.
- **Do not rebase** mapped area (67,349.332 ha) against true farm (85,910.8 ha).
- **Never merge supports.** Closed ladder in `support_level`; precision goes in `aggregation_unit`.
- **Verify against data, not prose — including this spec.** v1 and v2 each carried a confident claim the repo contradicted. If a stated number disagrees with the table, the table wins and you report it.
- **Respect the STOP points.** Gate A1 and A2 in particular: a metric chosen before the definitions are separated is a number that will be withdrawn.
- **Git:** direct commits to `main`. No branch, no PR. Review happens at the STOP points. No AI attribution in commit messages.
- **Change reports committed** to `docs/change_reports/` — they are cross-session memory, not paperwork. Short: what changed, what the numbers were, what is open.
