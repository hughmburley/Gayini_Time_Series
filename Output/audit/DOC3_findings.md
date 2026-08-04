# DOC-3 — v10 methods document, contradiction check

**Read-only.** 4 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · no registry write, no rebuild, no
re-render, no producer edit, no document edit.

**Recon.** `git fetch` · head was `d279edd`, **5 behind `origin/main`**; pulled fast-forward to
**`f1204ab`**, now in sync. The DOC-2 worktree (`task/doc2-review`, all commits pushed) was removed to
satisfy §0.7. One other worktree remains — `D:/Github_repos/Gayini_reports` on `feature/reports` — not this
session's.

**Source document.** `docs/reports/Gayini_RS_methods_doc_V10.docx` · 10,985,450 bytes ·
2026-08-04T18:57:43 · SHA-256 `f78467fadceb377fe0b4fc8226332c931d01f8e2e3e56e60b5daad83ad9d030a` ·
28 embedded images · 28 figure captions, 1–28, each once (the repeated `Figure 6` is a body cross-reference).

**A Word lock file `~$yini_RS_methods_doc_V10.docx` is present** — the document is open at the design seat.
Read-only here, so it does not block; noted because a mid-task save would stale the extraction.

**Missing cross-stream input.** `Gayini_report_stream_handoff_20260804.md` **is not in the repository** —
not under `docs/`, `docs/reports/` or `docs/reference_update/`. Its §3 and §4 content is quoted in this spec
and has been used as quoted; the file itself could not be read. Same defect class as the DOC-1 spec's
absence, now recurring for a second governing document.

---

## Summary

| Item | Verdict | Gate-stopping |
|---|---|:--:|
| **C4** · Bala 29ca flood frequency at two values | **CONFIRMED** — both values reproduce exactly, on two different pixel sets; neither states its basis | **yes** |
| **C5** · a third property-area base | **CONFIRMED** — 61,655 and 86,385 both reproduce; **86,385 is not registered** | no (reproducible) |
| **C3** · nested-set claim | **CONFIRMED** — nesting holds strictly; §M4's wording is the defect | no |
| **C2** · ungrazed ranks | **CONFIRMED** — 3 / 6 / 31 / 61; the roadmap sentence overstates | no |
| **C9** · fitted window for Figure 4 | **CONFIRMED** — Figure 4 is 1988–2023 and complete; §1's blanket wording is the defect | no |
| **C11** · persistence percentages | **CONFIRMED** on the drawn filtered surfaces — but **no producer emits them** | no |
| **C12** · dashboard p-value | **CONFIRMED — the p-value still renders, by default, in the shipped dashboards** | **yes** |
| **C7** · "reference" as an arm label | **CONFIRMED** — three locations | no |
| **C6b** · bare "floor" in figure annotation | **CONFIRMED** — 23 rendered strings, 8 of them in-figure | no |
| **C-minor** · ranked residual shortfalls | **CONFIRMED** — Bala 29ca is 2nd, not the largest | no |
| **§4** · figure canvas | reported; **STOP** | — |

**Two gate-stoppers: C4 and C12.**

---

## C4 · Bala 29ca flood frequency stated at two values — **CONFIRMED, two bases**

**Both printed values are exactly right, and they are measurements of different pixel sets.**

### 1 · The standing basis

Pixel-weighted mean over non-treed strata, `census_by_zone_stratum`:

| paddock | value | pixels |
|---|---|---|
| **Bala 29ca** | **8.5273%** | 36,676 non-treed |
| Bala 23 | 38.6037% | 24,369 non-treed |

Registered: **`bala29ca_mean_flood_freq` = 8.5** (`support_level = zone`, `scope_filter = fid4`,
`period_label = 1988-2022`). Bala 23 has **no registered flood-frequency `number_id`.**

### 2 · The basis the dashboard producer actually uses — Figure 12's caption

`R/gayini_dashboard_compose.R:117-124`, `gayini_unit_flood_series()`:

```r
w  <- terra::extract(ctx$wet_stack,   v, fun = sum, na.rm = TRUE, ID = FALSE)
vv <- terra::extract(ctx$valid_stack, v, fun = sum, na.rm = TRUE, ID = FALSE)
data.frame(year = yr, freq_pct = ifelse(vv > 0, 100 * w / vv, NA_real_), n_valid = vv)
```

called at `R/gayini_dashboard_compose.R:251` (`flood_note = "paddock valid pixels"`), consumed by
`gayini_panel_baseline_gauge()` at `R/gayini_dashboard_panels.R:252-264`:

```r
longrun <- mean(series$freq_pct, na.rm = TRUE)
recent  <- mean(utils::tail(series$freq_pct[order(series$year)], recent_n), na.rm = TRUE)   # recent_n = 5
lab = c(sprintf("long-run %.0f%%", longrun), sprintf("recent %.0f%%", recent))
```

**This extracts every valid raster cell inside the zone polygon** — regardless of whether the cell is in the
mapped vegetation census, and regardless of treed status.

**Reproduced by polygon extraction over `management_zones_8058` and the annual wet/valid stacks:**

| paddock | long-run | prints as | recent 5-yr | prints as |
|---|---|---|---|---|
| **Bala 29ca** | **10.32%** | **"10%"** | **17.17%** | **"17%"** |
| Bala 23 | 38.60% | "39%" | 59.71% | "60%" |

**Figure 12's caption is reproduced exactly.** The body's *"7 percentage points wetter"* is 17.17 − 10.32 =
**6.85 → 7** ✓.

### 3 · The basis for the Figure 28 value

`census_by_zone_stratum`, pixel-weighted, `treed_context_flag = 0` — the standing basis in §1 above,
registered at 8.5 and reproducing at **8.5273%**.

### 4 · Does either equal the pixel-weighted non-treed mean?

| | Bala 29ca | Bala 23 |
|---|---|---|
| census, non-treed | **8.53%** | **38.60%** |
| polygon, all valid cells | **10.32%** | **38.60%** |
| **agree?** | **NO — 1.79 pp apart** | **YES — identical** |

**The two bases coincide for Bala 23 and diverge for Bala 29ca.** Bala 23's polygon lies wholly within
mapped, non-treed country, so the pixel sets are the same. Bala 29ca's boundary encloses unmapped and
context cells that are **wetter** than its mapped non-treed country, lifting the polygon figure.

**Neither number is wrong. The words are.** Both are printed as "flood frequency", which is the name of the
headline between-year metric, and neither states which pixel set it was measured over. The paddock where it
matters is the one the pack quotes most.

*(Note: the two are the same metric in form — a mean of annual wet/valid ratios equals the pixel-weighted
between-year frequency when the valid mask is stable — so this is a footprint difference, not the
`annual_occurrence_pct` metric confusion of C8.)*

### 5 · Bala 23 and the ratio

On the standing basis: **38.60% ÷ 8.53% = 4.52**. On the dashboard basis: 38.60 ÷ 10.32 = **3.74**.
Figure 13's *"roughly four times as often"* holds on both.

---

## C12 · Dashboard p-value — **CONFIRMED, still rendering** · **GATE-STOPPING**

`R/gayini_dashboard_panels.R:321,326-333`, in `gayini_panel_where_it_sits()`:

```r
gayini_panel_where_it_sits <- function(..., show_kw = TRUE) {
  if (show_kw) {
    kw <- tryCatch(stats::kruskal.test(flood_frequency_pct ~ simplified_vegetation_group,
                                       data = freq_by_plot), error = function(e) NULL)
    if (!is.null(kw))
      kw_cap <- sprintf("Kruskal-Wallis across communities: p = %s (descriptive)", ...)
```

- **Panel:** the community-position / "where it sits" panel.
- **Label as rendered:** `Kruskal-Wallis across communities: p = <value> (descriptive)`.
- **`show_kw = TRUE` is the default and no caller anywhere overrides it** — repo-wide, `show_kw` appears only
  at its definition (321) and its own `if` (327).

**Same rendered objects, one generation.** `Output/figures/dashboards/D1_paddock_Bala_{23,29ca}_slide_data.png`
are dated **23 July 12:09**; `gayini_dashboard_panels.R` is dated **23 July 11:45** — the renders postdate
the code by 24 minutes and are its output. Registered under `run_id = taskM_gateC`, `qa_status = REVIEW`.
The dashboards described by §6.6 and those in the report batch are **the same files**, resampled for
embedding.

**So a p-value is rendering, in the figures, in a document going to Adrian.** Not removed, per §2's
instruction. Design-seat decision.

---

## C5 · A third property-area base — **CONFIRMED**

### 1 · 61,655 ha — confirmed

`SUM(n_pixels) WHERE treed_context_flag = 0 AND regime_band <> 'context'` = **988,831 px** ×
`PIXEL_AREA_HA 0.062351428` = **61,655.0 ha**.

The stated derivation also checks: 67,349.3 − (91,326 × 0.062351428) = **61,655.0**, where
91,326 = 86,375 + 4,951, the two context strata. **CONFIRMED both ways.**

### 2 · 86,385 ha — reproducible, and it is a fourth footprint

Producer: `scripts/05_ground_cover/04_taskM_green_at_floor_area.R`, emitting
`Output/tables/taskM_green_at_floor_area.csv` row **`implied_farm_ha_30m = 86,384.97`**.

**Footprint: the Gayini farm boundary on the native 30 m EPSG:3577 grid** — 959,833 valid floor pixels ×
0.09 ha/px. Not the 8058 analysis grid, not the mapped census.

So the document carries **four** area bases, not the two §1 declares:

| base | value | object |
|---|---|---|
| property | 85,910.8 ha | property boundary |
| mapped census | 67,349.3 ha | 1,080,157 px @ 24.97 m EPSG:8058 |
| non-treed | 61,655.0 ha | 988,831 px @ 24.97 m EPSG:8058 |
| **farm boundary at native 30 m** | **86,384.97 ha** | 959,833 px @ 30 m EPSG:3577 |

`property_outside_mapped_ha` = 18,561.5 is registered and reconciles the first two
(67,349.3 + 18,561.5 = 85,910.8).

### 3 · Registration

**86,385 is NOT registered.** No `number_id` in `dim_headline_number` carries it. It exists only as a CSV
row in a task output.

### 4 · 86,375 against 86,385

**Independent quantities.** 86,375 is a **cell count** (Floodplain Woodland and Forest, §3.1); 86,384.97 is a
**hectare figure** on a different grid, derived from a different pixel count (959,833). Neither is a
transcription of the other — but they agree to four significant figures and sit four sections apart, which
is a live confusion risk in a document that already carries two "two floors" pairs.

---

## C3 · Nested-set claim — **CONFIRMED**, and Figure 18 is the correct wording

From `Output/tables/T13_gateC_classification.csv`, 115 rows, `state_cut_*` columns:

| cut | recovering |
|---|---:|
| 0.50 | **15** |
| 0.75 | **10** |
| 1.00 (registered) | **8** |
| 1.25 | **4** |
| 1.50 | **3** |

**Range 3–15 CONFIRMED. Drawn counts 10 / 8 / 4 at ±0.75 / ±1.00 / ±1.25 CONFIRMED.**

**Nesting is strict.** Every stricter set is a subset of every looser set, tested pairwise across the full
ladder including `state_registered` and `state_drop2wettest`:

```
1.50 (3) ⊂ 1.25 (4) ⊂ drop2wettest (5) ⊂ registered (8) ⊂ 1.00 (8) ⊂ 0.75 (10) ⊂ 0.50 (15)
```

**No part is present at a stricter cut and absent at a looser one.** Nesting does not fail.

**Figure 18's wording is right** — *"parts enter and leave as the cut moves but are never exchanged"*
describes exactly this. **§M4's *"it is the same parts throughout"* is the defect:** it is not the same
parts, it is a nested family running 3 to 15.

---

## C2 · Ungrazed flood-frequency ranks — **CONFIRMED**

| paddock | rank of 64 | `number_id` |
|---|---:|---|
| Bala 26ca | 3 | `ref_paddock_flood_rank_bala26ca` |
| Bala 28ca | 6 | `ref_paddock_flood_rank_bala28ca` |
| Bala 27ca | 31 | `ref_paddock_flood_rank_bala27ca` |
| Bala 29ca | 61 | `ref_paddock_flood_rank_bala29ca` |

All four registered with `scope_filter = "64 management zones, treed_context_flag = 0 AND regime_band <>
'context'"`, `period_label = 1988-2022`.

**31st of 64 is above the median rank of 32.5 — by one and a half places.** It is the 31st-wettest of 64,
i.e. essentially at the midpoint of the property, not in the wettest country. The roadmap sentence's *"three
of the four sit in the wettest country"* holds for ranks 3 and 6 and does not hold for rank 31.

**Figure 15 carries no hydrological variable** — it is the treatment map (zones filled by grazing
treatment). **The ranks are carried by Figure 28**, the four-ungrazed comparison table, which prints each
paddock's rank of 64.

---

## C9 · Fitted window for Figure 4 — **CONFIRMED, both correct**

**(a) Figure 4's inundation trend series.** `scripts/03_inundation_products/12_run_census_trend_test.R`
reads `annual_{wet,valid}_any_1988_2023_8058.tif` (lines 91–92) and takes its years directly from the stack:
`years <- gayini_stack_water_years(names(wet))` (line 109). **No filter to 2022 is applied anywhere.** The
stack carries **35 bands = water years 1988-89 through 2022-23**, so the series is **1988–2023 and the final
water year is present and complete for inundation.** Figure 4's caption is right.

**(b) The annual cover trend series** is fitted **1988–2022**, as every trend `number_id` records
(`period_label = '1988-2022'`, including `floor_flood_slope_64pdk`).

**Both are correct on their own series. §1's blanket statement — that trend statistics are fitted 1988–2022
because the final cover year is incomplete — is true of the cover series and false of the inundation
series**, and Figure 4 is an inundation trend. The defect is §1's scope, exactly as anticipated.

---

## C11 · Basis of the two persistence-surface percentages — **CONFIRMED, no producer**

**Both percentages are computed on the drawn, reprojected, component-filtered EPSG:8058 surfaces**, from
`Output/rasters/persistence_8058/persistence_{total_cover_floor_ge75,green_share_floor_ge50}_8058.tif`:

| layer | pixels | area |
|---|---:|---:|
| total-cover floor ≥ 75 | 127,819 | 7,969.70 ha |
| green-share floor ≥ 50 | 8,020 | **500.06 ha** |
| both | 6,513 | 406.09 ha |

406.09 ÷ 7,969.70 = 5.096% → **94.90% "does not retain living cover"** ✓
406.09 ÷ 500.06 = **81.21% "sits inside the total-cover surface"** ✓

**No producer in the repository emits either percentage.** Repo-wide search across `scripts/` and `R/` for
`94.9`, `81.2`, `overlap` and `intersect` in the persistence producers returns nothing that computes them.
They reproduce exactly from the shipped rasters but have **no build artefact, no CSV row and no
`number_id`** — they entered the document from an audit computation, not from a producing script.

### The lineage: 500 / 3,744 / 4,474 / 6,458 are four values across three operations plus a filter

| value | object | status |
|---|---|---|
| **6,457.95 ha** | **the measurement** — 71,755 px × 0.09 ha, native 30 m EPSG:3577, `green_frac_pct > 50` | canonical (issues log C-15); `Output/tables/taskM_green_at_floor_area.csv` |
| 4,474.03 ha | the native pixel **count** × the 8058 pixel area — an arithmetic conversion of a count | not a reprojection; recorded in the persistence README as not the measured area |
| 3,744.20 ha | the correct 8058 reprojection, thresholded on the 8058 grid, over the raster extent | not the measured area |
| **500.06 ha** | **that 8058 surface after the ≥ 5 ha connected-component filter** | what Figure 10 draws |

**They are not three measurements of one surface.** 6,458 and 4,474 are the pair C-06 explains by grid
mismatch. **500 ha is a distinct object** — the component-filtered 8058 surface — and is **not** the
withdrawn "~4,300 ha", which C-06/D8 withdrew as a mismatched conversion of the green-share count.
**The gate-stop condition is not met.**

---

## C7 · "Reference" as an arm label — **CONFIRMED, three locations**

`scripts/12_zone_stratum/T6_gateE_figures.R`, unchanged:

| line | string as it renders |
|---|---|
| **85** | `ARMS <- c(not_grazed = "not grazed (reference)", …)` — the arm label, rendered in the **facet strip and legend** |
| **99** | `acols <- c("not grazed (reference)" = "#238b45", …)` — the colour map, **keyed on the same literal**, so the two must change together |
| **236** | figure title: `"T6 A (deck) - Floor vs the 14-day comparator: reference below, inferred-standard above"` |

Line 99 is the one worth flagging: the colour lookup is keyed on the label text, so editing the label at 85
without 99 silently drops the arm's colour.

---

## C6b · Bare "floor" in producer-generated annotation — **CONFIRMED**

**23 rendered strings contain `floor` without `spatial`, `temporal` or `cover` adjacent.** Of these, the
**in-figure** ones — titles, subtitles, captions and per-panel annotation that reach a rendered image — are:

| script:line | string as it renders |
|---|---|
| `R/gayini_veg_water_census_panels.R:156` | `flood freq %.1f%% · floor %.0f%%\nn = %s census px` — **per-unit annotation on the dashboard response panel** |
| `scripts/12_zone_stratum/T2_gateE_figures.R:85` | `T2 E paddock floor trajectories` (Figure 21's registered title) |
| `scripts/12_zone_stratum/T2_gateE_figures.R:94` | `Support: pixel. veg_mean secondary variant of the floor panel;` |
| `scripts/12_zone_stratum/T6_gateE_figures.R:176` | `T6 A three-arm floor grid` (Figure 26's registered title) |
| `scripts/12_zone_stratum/T6_gateE_figures.R:236` | `T6 A (deck) - Floor vs the 14-day comparator: …` |
| `scripts/12_zone_stratum/T1_gateD_figure.R:38` | `T1 D · Grazed/ungrazed floor contrast collapses under block control and zone support` |
| `scripts/03_inundation_products/24_build_figA_floor_gradient_density.R:141` | `Fig A · Vegetation floor vs flood frequency — the all-pixel gradient (companion / appendix)` |
| `scripts/05_ground_cover/T3_gateB2_green_share_surface.R:229` | `T3 Gate B2 - green-share-at-floor surface over the property` |

The remaining 15 are **console diagnostics** (`message()` / `cat()` in
`02_build_total_veg_percentile_rasters.R`, `03_h2_seasonal_gate_and_diagnostics.R`,
`T12_gateC_diagnostics.R`, `build_T11_v2_dual_grain.R`, `T3_gateB2_green_share_surface.R:113`) and
`R/gayini_stratified_sampling_figures.R:294,297`, where "floor 50" means a **sampling minimum**, an entirely
different sense of the word.

**Nothing changed.**

---

## C-minor · Ranked residual shortfalls — **CONFIRMED**

Top five paddock residuals from the registered expectation line, `fact_zone_floor_flood_residual`:

| rank | paddock | residual | `number_id` |
|---:|---|---:|---|
| 1 | **Bala 15** | **−17.62** | `bala15_xsec_residual` |
| 2 | Bala 29ca | −16.80 | `t10_bala29ca_xsec_residual` |
| 3 | Dinan 10 | −15.06 | `t10_dinan10_xsec_residual` |
| 4 | Dinan 13 | −15.04 | **not registered** |
| 5 | Dinan 4 | −13.22 | **not registered** |

**Bala 29ca is second, not the largest**, so §10's *"supplies most of the signal in Figure 20"* overstates
against Figure 20's own text — which correctly gives Bala 15 as the largest.

**Worth recording:** ranks 3 and 4 are separated by **0.02 pp** (Dinan 10 −15.06, Dinan 13 −15.04). Dinan
10's "3rd" is correct and is effectively a tie; any re-fit could exchange them, and Dinan 13 carries no
`number_id`.

---

## §4 · Figure canvas — reported, nothing changed

Device settings, from the `gayini_write_and_register_figure()` calls. **DPI is not set at any call site**;
all four inherit the helper default **`dpi = 150`** (`R/gayini_figure_register.R:29`, applied at line 36).

| figures | script | line | width × height (in) | dpi | layout |
|---|---|---|---|---|---|
| **21, 22** | `scripts/12_zone_stratum/T2_gateE_figures.R` | 90, 97 | **14 × 6** | 150 | **facet** — `facet_wrap(~comm, nrow = 1)` (line 60), three communities across |
| **26, 27** | `scripts/12_zone_stratum/T6_gateE_figures.R` | 181, 191 | **13 × 9** | 150 | **facet** — `facet_grid(arm_lab ~ comm, switch = "y")` (line 156), arms as rows × communities as columns |

*(The T6 deck cut at line 249 is a separate 11 × 7 render and is not one of Figures 26/27.)*

**Both layouts are set by facet, not by an explicit grid**, so a row-per-community restack is a
`facet_wrap`/`facet_grid` change rather than a re-composition.

**Note against §4's arithmetic:** both figures are authored **wider than the usable landscape text box**
(14 in and 13 in against ~10.30 in), so they are already being scaled down on placement. The 5.26 in height
ceiling therefore binds on a figure whose native aspect is 14:6 (2.33:1) for Figures 21/22 and 13:9 (1.44:1)
for Figures 26/27 — which is why the three-across layout survives the constraint and a stacked one would not.

**Neither script was changed. STOP.**

---

## Items not actioned, per §3

C1, C6a, C10, and the wording fixes following from C3, C2 and C9 are design-seat only. No CC action taken on
any of them.
