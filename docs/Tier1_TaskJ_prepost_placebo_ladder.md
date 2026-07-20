# Tier 1 · Task J — pre/post inundation change and the placebo ladder

*Task spec for Claude Code. Responds to Adrian's 15 Jul email (irrigation bank cut locations from Jana). Design settled in Claude.ai session 16 Jul 2026; evidence in `Gayini_limitations_register_20260716_v2.xlsx`.*

**Workflow: recon first — report and STOP at Gate 1 before writing analysis code.** Then branch-and-PR into `main`, held for human review. Do not merge.

**Priority: this is additive and secondary. Task H remains the priority — H2 (veg percentile rasters) is the long pole. Do not let Task J displace it.**

---

## Objective

Adrian asked for a pre/post inundation difference image around the May/September 2018 bank cuts. **Build it — and build it at every other feasible date too.**

The deliverable is not an effect estimate. It is a demonstration, using Adrian's own method, that the method cannot answer his question — because what it produces is largely determined by how wet the two windows happened to be. That demonstration is a real, reportable, publishable result. It is also cheap: everything below runs off the existing annual stack. No rebuild from source scenes.

**Additive only.** Nothing is deleted. The retired pre/post framing is not being revived as a project direction — it is being run once, deliberately, bounded, to answer a specific question and close it.

## Scope decisions already made (do not re-litigate)

- **This is descriptive, not causal.** No claim of a management effect will be made from any output of this task. See §"What must not be claimed".
- **The estimand is not the total effect.** A property-wide change is unidentifiable here: the cuts span essentially the whole farm (points span 50.35 × 31.25 km against a 55.01 × 34.51 km property), so there is no untreated control region (**L03**).
- **No temporal estimator.** Pre/post means, ITS, and flow-conditioned ITS are all dead: n = 5 post-years, one year is 20% of the sample, and the sign flips when it is dropped (**L01**, **L02**, **L12**). Do not propose one.
- **The May-vs-Sept cohort test is retired — do not propose it.** It is dead three ways: the cohorts overlap (218 of 940 locations carry both dates), June 2018 is missing from the imagery, and 2018 has no real daily flow resolution (**L36**).
- **The matched near/far DiD is NOT in this task.** It is parked behind two blocking questions to Jana (**L07**, **L10**). If `Date` turns out to be a survey date, that design was never viable. Do not build it.
- **Run off the annual stack, not the per-scene catalogue.** The stack is already collapsed to binary (§5 of `Gayini_established_data_facts.md`), which sidesteps the sensor-dependent wet-rule branch entirely (**L17**). This is a reason to prefer it, not an incidental.
- **Source of truth for measured properties is `Gayini_established_data_facts.md`.** If a number here disagrees with it, that doc wins — report the drift, do not absorb it.

---

## Gate 1 — Recon (report, then STOP)

Answer these before any analysis code. Report findings and proposed decisions; wait for sign-off.

1. **Confirm the annual stack against §5.** `Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif`. Verify from the rasters themselves, not the catalogue: EPSG:28355, 25.0 m, 35 layers, `uint8`, nodata 255; `annual_wet_any ⊆ {0,1,255}`; **`annual_valid_any ⊆ {1,255}` — there is no zero**; `wet ⊆ valid` exactly. Report any drift.

2. **Layer → water-year mapping.** Report how the 35 layers map to water years, and confirm the convention: water years start **1 July**, and are labelled here by their **start year** (WY2018-19 → "2018"). Confirm layer 1 = WY1988-89 and layer 35 = WY2022-23. **This is load-bearing** — an off-by-one silently shifts every window and every placebo.

3. **`MIN_VALID` per window — propose, don't guess.** With a 5-year post window, a pixel with few valid post-years produces a noisy or undefined frequency. §5 says `valid_count` is 22–35 with 95.768% at exactly 35, so this should bite few pixels — but report the actual distribution *within* the shortest windows, and propose thresholds (suggested default: **≥ 4 of 5 valid in post, ≥ 80% valid in pre**). Report how many pixels fail at the proposed threshold, per date.

4. **Vector inputs.** Confirm present and readable: `gayini_boundary_epsg8058.gpkg` (85,910.8 ha), `management_zones_epsg8058.gpkg` (64 zones), `vegetation_communities_epsg8058.gpkg`, `cuts.shp` (EPSG:4326, 1,158 rows). Report the CRS of each as read.

5. **Gauge series.** Confirm `gauge_water_year_flow` station **410040** (Downstream Maude Weir) has 35 water years with `mean_flow_mld` non-null, and report the water-year labelling convention of that table (it appears to store the **end** year — 410040's `water_year` = 2019 corresponds to WY2018-19). **Confirm this before joining.** A one-year misalignment here destroys the flow law silently.

   - **Use 410040, not Redbank 410041.** Redbank is the structurally relevant gauge but is missing 1993–2006 — 4,930 days, of which **0 were recoverable**. Closed out 2026-06-24; the companion `gayini_murrumbidgee_gauges.sqlite` is identical to the main DB and adds nothing. Standing ruling in `gauge_sites`: *"use outside 1993-2006 only; exclude from continuous historical gap-sensitive analyses."* **Do not attempt recovery** (**L30**, settled).
   - **Do NOT use `daily_flow_wide` for anything in this task.** It is monthly data replicated across days before ~2020 — 92.7% of station-months carry one repeated value, and **2018 is 0.0% real daily**. Its quality flags do not disclose this: every row reads `original_waternsw_valid_positive` / *"Original WaterNSW observation retained."* (**L34**, **L35**). Annual means are unaffected — they reconcile to the stored `mean_flow_mld` at 0.0000 ML/d — so `gauge_water_year_flow` is safe. Detect smearing by counting distinct values per station-month, never by reading flags.
   - **Delivery fraction: use `gauge_kingsford_flow_ratios_water_year.ratio_downstream_over_upstream`** rather than recomputing. Respect `insufficient_overlap_flag`.

---

## Gate 2 — Single-date build (2018) and assertions

Build the 2018 product first, alone, and verify it before touching the ladder.

### Windows

For a cut date `C` (labelled by water-year start year):

```
PRE         WY1988-89  ...  WY(C-2)-(C-1)
TRANSITION  WY(C-1)-C                       <-- DROPPED, always
POST        WY C-(C+1) ...  WY(C+4)-(C+5)
```

For **C = 2018**: PRE = WY1988-89 … WY2016-17 (29 years) · TRANSITION = **WY2017-18, dropped** · POST = WY2018-19 … WY2022-23 (5 years).

> **Why the transition year is dropped, and why it is not optional.** Water years start 1 July, so the **May 2018 cuts fall inside WY2017-18** — the last PRE year. 509 of 1,158 rows (44%) are `201805`. Leaving that year in the baseline contaminates it with nearly half the treatment (**L09**). The existing code already carries this concept (`period = "transition_year"`, filtered out) — reuse it.

### Metric

Per pixel, per window:

```
freq_pct = 100 * sum(annual_wet_any) / sum(annual_valid_any)
diff_pp  = freq_post - freq_pre
```

This is the **between-year** annual flood frequency — the project headline metric. **Do not use `annual_occurrence_pct`**, which is a within-year area metric despite its name (**L25**, correction C8). Do not compute hydroperiod, duration or depth; the stack cannot support them.

### 🔴 The trap that will silently destroy this build

`annual_valid_any` is **presence-only: `{1, 255}`, with no zero**. Therefore:

- **A `⊆ {0,1}` assertion on `valid` passes vacuously.** It proves nothing. Assert **`valid ⊆ {1} + NA`**.
- **One 255 entering `app(sum)` adds 255 per year and destroys every count** — with no crash, and plausible-looking output. This is the single most dangerous thing in this task (**L31**).
- **255 must survive as NA, never as a value**, through every read, mask and write. Assert immediately before and immediately after any operation that could reintroduce it.

Assert, and fail loudly:

```
wet   ⊆ {0,1} + NA
valid ⊆ {1}   + NA
wet ⊆ valid                       (0 pixels wet-but-not-valid, all layers)
0 ≤ freq_pre, freq_post ≤ 100     (guaranteed only if wet ⊆ valid holds)
sum(valid) > 0 wherever freq is not NA
```

Reuse `gayini_check_prepost_inundation_outputs()` — its wet ≤ valid, range, and no-frequency-without-valid checks are sound. **Do not reuse `gayini_classify_plot_inundation_change()`** (that is the retired `inundation_change_class`) or `gayini_add_period_metadata_to_plot_summary()` (it reaches for the banned 5-class `vegetation_adrian_group`).

### CRS

**Compute natively in EPSG:28355. Do not reproject the binary layers at all** — binary masks are nearest-neighbour only (§11), and every reprojection is a chance to reintroduce 255 as a value.

- **All statistics are computed on the native 28355 rasters.** No number in any table or figure is affected by resampling.
- **Reproject only the final continuous `diff_pp` raster to EPSG:8058** for display and registration. It is continuous, so bilinear is legitimate on this step — unlike the binary inputs. Reproject to **new files only; never mutate originals**.
- Register outputs in `raster_asset` with CRS/extent/res populated. Note in the change report that the existing `pre_post_comparison` products are 28355 and cover WY2014–2025 on a 2013→2019→2026 window — they are **not** full-record, and this task's outputs are not the same thing (**L18**).

### Gate 2 acceptance

Report before proceeding: the assertion results; the 2018 whole-farm mean `diff_pp`; the mean by `simplified_vegetation_group` (4-class canonical — **never** the 5-class legacy); pixel counts contributing; pixels failing `MIN_VALID`. **STOP.**

---

## Gate 3 — The placebo ladder

Repeat the Gate 2 build for **every feasible cut date: C = 1994 … 2018 (25 dates)**.

Feasibility: `C + 4 ≤ 2022` (needs a full 5-year post window) and `C - 2 ≥ 1992` (needs ≥ 5 pre-years). This yields exactly 25.

For each date, emit one row of `J-T1`:

| field | definition |
|---|---|
| `cut_year` | C |
| `n_pre_years`, `n_post_years` | window sizes (post is always 5) |
| `freq_pre_pct`, `freq_post_pct` | whole-farm means, native 28355 |
| `diff_pp` | `freq_post − freq_pre` |
| `diff_pp_<community>` | same, per 4-class community |
| `n_px`, `n_px_failed_minvalid` | support |
| `flow_pre_mld`, `flow_post_mld` | window means, gauge 410040 |
| `q_ratio` | `flow_post / flow_pre` |
| `is_real` | TRUE only for C = 2018 |

**Expected scale:** 25 dates × a 35-layer stack subset. Cheap. If it is slow, the windows are being re-read per date — read the stack once.

### Gate 3 acceptance

`J-T1` complete, 25 rows. **Report `diff_pp` for all 25 and STOP.**

**Verify against `TaskJ_plot_support_reference_20260716.csv`** — the same 25 dates computed at plot support, shipped with this spec. It is not a target to hit; it is a shape to match. Pixel support runs roughly 1.5–1.8× lower in magnitude than plot support (**L15**), so the *values* must differ. But the **ordering across dates, the sign pattern, and the position of the turning point around C=2007** should track. Plot `diff_pp` pixel vs plot for all 25 and report the correlation.

If the shape does not track, the window mapping or the water-year alignment is wrong. Say so and stop. A report is a claim; this table is evidence.

---

## Gate 4 — The law and the figures

### The law

Fit on the **24 placebo dates only** — never including 2018:

```
diff_pp  ~  a + b * log(q_ratio)
```

Then **predict C = 2018 from that law** and report the residual, in pp and in units of the placebo residual sd.

At plot support: `diff_pp = +2.195 + 18.272 × log(q_ratio)`, R² = 0.865, residual sd 3.95 pp. It predicts +5.20 pp for 2018 against +11.47 observed, leaving **+6.27 pp unexplained (1.59 sd)** — which ranks **3rd of 25**, behind two placebo dates. Report the pixel-support equivalent and the same ranking. **Do not tune the model to make the residual vanish, and do not tune it to make the residual grow.** Report what it is.

Also report, as robustness:

- **Two-variable refit** `~ log(q_ratio) + n_pre_years`. Pre-window length runs 5→29 across the ladder and correlates +0.72 with the bias, collinear with flow at r = 0.632 (**L32**). At plot support the flow coefficient is stable (12.72 → 10.67) and R² rises 0.845 → 0.878. Confirm at pixel support.
- **Refit on the 5 independent dates only** — 1994, 1999, 2004, 2009, 2014 — the only ones with fully non-overlapping post windows (**L27**).

> 🔴 **Do not compute a p-value or CI from the placebo spread.** Consecutive dates share four of five post-years. 25 dates is not 25 tests; only 5 are independent. The spread is not a sampling distribution. Fitting the law on all 25 is legitimate; treating the scatter as an error model is not.

### Figures

**Style is fixed — match `inundation_post_minus_pre_change_with_paddocks.png` exactly.** The chain already exists; reuse it, do not re-invent:

```
theme        gayini_theme_map(13)          # theme_void, Arial, white bg, legend bottom,
                                            # title bold #1f2d2a, subtitle #4d5652,
                                            # caption hjust=0 grey35 rel(0.75), margin 14/18/14/18
scale        gayini_change_scale_fill(60)  # scale_fill_gradient2, low #b84a4a, mid white,
                                            # high #2f74b5, midpoint 0, limits c(-60,60),
                                            # oob = scales::squish
boundary     geom_sf(colour = "#222f2d", linewidth = 0.6,  fill = NA)
paddocks     geom_sf(colour = "#6d706b", linewidth = 0.16, fill = NA)
ggsave       width = 12, height = 7.4, dpi = 220
```

**`J-F1` — the 2018 difference map.** What Adrian asked for. Full size, paddock context, the styling above.

- title: `Post-minus-pre inundation change with paddock context`
- subtitle: `Annual occurrence frequency change, percentage points` → **change to** `Between-year flood frequency change, percentage points` (the existing subtitle names the wrong metric — see **L25**)
- caption: `Red = less frequent post; blue = more frequent post. Not hydroperiod or duration.` → **append** ` Descriptive only: see J-F3.`

**`J-F2` — the six-panel ladder.** The five independent placebo dates (1994, 1999, 2004, 2009, 2014) plus 2018. `patchwork`, **one shared legend**, identical ±60 scale on every panel. Panel titles = the cut year and its post window, e.g. `2004  (post 2004–2008)`. The real date's panel gets a distinguishing marker — a heavier panel border, not a different colour scale.

- This is the punchline figure. Six panels, not 25: the five are the *independent* set, which is a defensible selection, and 25 panels is unreadable.
- Caption must state plainly: **no cuts occurred at any date except 2018.**

**`J-F3` — the law.** Scatter, all 25 dates: x = `log(q_ratio)`, y = `diff_pp`. Fitted line and ribbon from the **24 placebos only**. 2018 marked distinctly. Annotate R², the predicted vs observed value for 2018, and the residual in pp and sd.

- This is the figure that carries the argument. If only one thing survives to the deck, it is this.

**`J-F4` — the annual series.** 35 years of whole-farm between-year frequency with flow overlaid (secondary axis or paired panel), post-2018 window shaded, WY2022-23 marked.

All four registered in the figures manifest. **One figure = one file = one slide.** Insets never overlap captions. Plain language on anything Adrian-facing: no `J-` numbers, no view names, no file paths in slide text.

---

## Gate 5 — Register and change report

- **Update `Gayini_limitations_register_20260716_v2.xlsx`** with the pixel-support numbers, replacing the plot-support placeholders in the Evidence log for **L26**, **L33**. Add rows if the build surfaces anything new. Keep the provenance line on every row.
- **Change report** at `docs/change_reports/task_J_prepost_placebo_<date>.md`.
- Diagnostic figures during the build are gitignored; reference them in the change report.
- **Commit code and small results tables only. Never large spatial data.** Suppress co-author attribution.

---

## What must not be claimed

Copy this into the change report verbatim. It is the point of the task.

- ❌ "The cuts increased inundation." Not identifiable (**L01**, **L02**, **L03**, **L12**).
- ❌ "The 2018 difference map shows a management effect." A law fitted only on dates when nothing happened predicts the 2018 near/far result to within 0.09 pp (**L26**).
- ❌ Any p-value from the placebo spread (**L27**).
- ❌ "The unexplained +6 pp is the cuts." It is uniform, and uniform is unattributable. Delivery is a live alternative and **cannot be ruled out — permanently**: the Redbank/Maude delivery fraction rose from 0.650 to 0.729, and Redbank's 1993–2006 gap is closed out as unrecoverable (0 of 4,930 days). This is not pending work (**L29**, **L30**, **L33**).
- ✅ "Inundation was higher in 2018–2022 than in 1988–2017" — **only** when shown beside the drop-2022 number, which reverses the sign.
- ✅ "The pre/post difference is largely determined by how wet the two windows were; R² = 0.86 across 25 dates."
- ✅ "There is no detectable effect at plot support; the detection floor is roughly ±4 pp."
- ❌ "The farm was wetter after 2018 than flow explains, which is suggestive." **It is not suggestive.** Ranked across all 25 dates, the 2018 residual is **third largest** — 2009 (+8.04 pp, 2.04 sd) and 1994 (−7.37 pp, 1.86 sd) both exceed it, and nothing happened at either. It is an ordinary residual for this estimator (**L33**).
- ✅ "The 2018 residual is within the range this estimator produces at dates when nothing happened, and smaller than two of them."

---

## Open questions — flag, do not guess

**None of these block this task.** Task J needs the annual stack, the vectors and gauge 410040. It does not need `cuts.shp` for any arithmetic — the cuts supply the date and the map context only. Questions 1 and 2 gate the *matched near/far DiD*, which this spec excludes. **Start now; do not wait on answers.**

1. **Gates the matched DiD, not this task — to Jana (L07):** does the cuts `Date` record when the cut was **made** or when it was **surveyed**? 218 of 940 unique locations carry *both* 201805 and 201809. If it is a survey date, the event date is soft for 23% of locations and Adrian's email does not fix the problem it was thought to fix.
2. **Gates the matched DiD, not this task — to Jana (L10):** are bank **lines** or **compartment polygons** available? A cut changes hydraulic connectivity, not a radial neighbourhood. `management_zones` was tested as a proxy and **rejected** (cuts are 3.7× enriched within 25 m of a zone boundary, but the median distance is 257 m and at 500 m the enrichment is 1.1× — chance). Without this, treatment can only be a distance proxy.
3. **To Adrian:** the cuts question is *"did the cuts change how much floodplain a given river flow wets?"* — which flow-conditioning answers. It is **not** *"did management put more water out there?"* — which flow-conditioning would absorb, because flow at Maude is partly a release decision. If he wants the second question, the design changes and an exogenous climate index (ENSO) earns a place. Confirm which question he is asking.
4. **Report, do not fix:** correction **C1** — `census_stratum.farm_area_ha` holds the *mapped* area (67,349.332 ha), not the farm (85,910.8 ha). Blast radius unresolved: does any shipped figure quote a "% of farm" derived from it?

## Handoff

Fresh Claude Code session (`/clear`), branch check, hand over this file with a short framing line. Stop at every gate. Commit at each. Merge on GitHub after human review; then `git pull --ff-only` locally.
