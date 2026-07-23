# Tier 2 · Task H — on-disk review: reproduce the census & ground-cover PPT figures

*Task spec for Claude Code, run on the **workstation** (large files local). Design-and-review seat wrote this; CC executes. Recon-first, gated, **report-and-STOP** at each gate. Verify against the data, never against a prose report.*

**Goal (one sentence):** confirm that the census and ground-cover **figures shown in the main-results PPT** can be reproduced from the database, R scripts, and on-disk outputs as they currently stand on `main` — and report any figure whose number cannot be reproduced, or whose evidence is missing on disk.

**This is a REVIEW, not a BUILD.** No new figures, no rebuilds, no deck edits, no re-opening settled decisions. If a figure is stale or unreproducible, that is a **finding to report**, not a licence to fix it here. The census is complete and merged (commit `51aeaa3`).

---

## Running defect ledger (updated as gates report; the final verdict draws from this)

Status as of Gate D (2026-07-20). "Resolved-on-disk" means the last chat's audit flagged it, but the workstation shows it has since been fixed — verified here, not assumed.

| # | Sev | Status | Defect |
|---|---|---|---|
| **D1** | HIGH | ✅ **RESOLVED (Gate A)** | Task H spec v4 **is** committed and clean on `main` (`git ls-files` returns it, clean tree). The audit's "v4 not committed" is superseded by disk. **Residual action:** CLAUDE.md still asserts "v4 not committed / confirmed absent on disk" — that prose is now **stale**; flag for correction, don't edit here. |
| **C2** | MED | ✅ **RESOLVED (Gate B)** | Census rasters now registered in `raster_asset` with crs/extent/checksum populated (`raster_veg_regime_class_8058`, `raster_vegpct_p05–p50`, `raster_flood_zone_8058`, NN `raster_08058_wet/valid`). Audit's "NOT registered" superseded. Only the native-28355 stack rows carry NULL checksum — **expected pre-completion state, not a blocker.** |
| **D2** | MED | 🔴 **CONFIRMED OPEN (Gate D)** | C1 area-basis: `census_stratum` carries only `farm_area_ha = 67,349.332` (mapped) — **no** `mapped_area_ha`/`farm_area_total_ha` column. `v_pixel_census_by_veg_regime.pct_of_farm` divides by mapped, not true farm (85,910.8). Recomputed Aeolian low: **2.4798% (mapped) vs 1.9440% (true) = ×1.2757**. **Unlike D1/C2/D3, this did NOT self-resolve on disk** — it's the one substantive DB defect still standing. Blocks any shipped "% of farm" from that view. **Fix (separate build session):** add `farm_area_total_ha`, repoint the view. |
| **D3** | LOW | ✅ **RESOLVED (Gate C)** | ~4,300 ha refugia computed from the green-fraction substrate (reused `green_at_floor()` verbatim). Result written to `refugia_area_check.csv`. The area exists and reproduces — **but see D8** for the convention issue it surfaced. |
| **D4** | LOW | ⏳ Gate E | Figure-registry gap: `figure_asset` holds 139 stale rows, 0 current-ladder figures — confirm ownership (Task K) not lost. |
| **D5** | INFO | noted | Smoke test is 99 pass / 1 fail / 3 warn, not "99 pass" — fail is out-of-scope `scripts/10_downstream_optional/`; warnings pre-existing. Not a census defect. |
| **D7** | LOW (new) | 🆕 **Gate B** | `veg_p*` nulls (155 each) are stored as float **NaN, not parquet NULL** — a consumer testing `WHERE veg_p05 IS NULL` gets 0 rows; must use `isnan()`/`is.na()`. Functionally correct (the NaN rows are permanently-wet Woodland context pixels below MIN_SEASONS, per §9). **Residual action:** one-line data-dictionary caveat; flag, don't edit the dictionary. |
| **D8** | LOW–MED (new) | 🆕 **Gate C** | **Refugia hectare convention is a grid mismatch.** The paired-floor count (71,755 majority-green pixels) is made on the **native 3577 30 m** grid, but §9's "~4,300 ha" converts it with the **8058 24.97 m** census pixel — understating true ground area by (24.97/30)² = 0.693, i.e. ~31%. Honest figures: **~6,458 ha (7.48%)** native-grid consistent, **or ~4,474 ha** faithful to §9's (mismatched) convention. **The refugia *story* is unaffected** (thousands of ha, skew-tail, ~5–7.5% of farm); only the headline hectares move. Touches a number that may go to Adrian / Nari Nari. **Residual action:** state the pixel basis explicitly on any refugia slide, and prefer the native-grid ~6,460 ha (or reproject the floor to 8058 before counting). Flag; don't edit §9 here. |
| **BLK** | — | ✅ **CLEARED (Gate D)** | **FC band semantics** — the standing hard blocker — is **resolved for the products in use**: percentile + regime-class rasters `legend_status='confirmed'`, 0 `needs_check`; +100 offset settled as *no offset* (§10); nodata correct. Raw FC composites in `Input/` remain unregistered, but **Gate E consumes finished parquet/percentile products, not raw bands — so it is NOT blocked.** Only *new raw-FC arithmetic* would reopen it. |
| **CSV** | INFO | noted (Gate D) | `plot_rs_analysis_base.csv` absent from `Output/csv/`. **Not a git restore** (`Output/` is gitignored; never on `main`) — regenerate from producer `03_curate_rs_hydrology_analysis_base.R`. **Off the census critical path** (feeds retired pre/post wrapper, DB builder, old dashboards — not scripts 05/02–03). Doesn't block Gate E; would block a full DB rebuild / pre-post path. |

*(D6 from the last audit — the Riverine-low 116-px valid-year masking gap in `sample_power` — is INFO-level and re-checked at Gate C, not re-listed here.)*

---

## 0. Standing rules (inherit from CLAUDE.md; restated so this file stands alone)

- **Additive-only.** No deletes, no moves, no writes to tracked files. Any scratch output goes to `Output/diagnostics/ondisk_review_20260720/` (create if absent).
- **The existing code is the object under review — do NOT code from scratch.** The committed R pipeline (the `scripts/` files and figure builders named below) is what this task exists to check. "Reproduce a figure" means **run or read the committed script and confirm its output**, not re-derive the number with fresh extraction logic. A number you compute with your own new code proves only that you agree with yourself; it does not confirm the pipeline works. **If you find yourself writing extraction code from scratch to hit a target number, STOP — you have left the review and started a rebuild.** An independent spot-check to catch a suspected bug is allowed, but it is a **cross-check against the script's own output, labelled as such** — never a substitute for exercising the real code. Where a number can only be gotten by running a script, run that script (read-only inputs) and report what it emitted.
- **Verify against data, not reports.** Three prose claims were wrong across Task H; every one was caught by reading a table. Where you assert a reconciliation, **print the number you computed and the number you checked against.**
- **Do not run the builder.** `reset_file` rebuilds the DB from scratch and destroys the 12 manually-registered Task H census rows. Read-only DB access only (`PRAGMA`, `SELECT`).
- **Four-CRS discipline.** EPSG:8058 canonical; 28355 inundation stack; 3577 FC source; 9473 dim_plot centroids. Assert CRS before any raster arithmetic; never reproject a binary mask with anything but `method="near"`.
- **Plot support ≠ pixel support.** Never mix them in one figure or one reconciliation. 9/22/50 is correct at plot support; 6.08/12.91/27.99 is correct at pixel support. Both are right; label, never "correct."
- **No AI attribution in commits.** This task should produce no commits anyway (review only) — but if a change report is written, no `Co-Authored-By` trailer.

---

## Gate A — Read the spine docs AND inventory the existing code FIRST, report, STOP

Two parts before touching data: read the docs, then take stock of the code that already exists. **Nothing in this gate reconciles a number — it establishes what is already written so the later gates hang off the real pipeline, not a fresh one.**

**A1 — Required reads (in this order).** Confirm each is the current version; report version/date and anything describing cancelled work as live.
1. `docs/Gayini_established_data_facts.md` — the measured-facts reference. **§9 (measured properties) and §11 (known traps) are the reconciliation targets for this task.** §10 is settled; a disagreement is a finding, not a re-open.
2. `docs/Tier2_TaskH_all_pixel_census_v4.md` — the authoritative spec. **Confirmed on `main` and clean (Gate A, 20 Jul): D1 is RESOLVED, not open** — the last chat's audit predates the commit. The remaining D1-adjacent action is that **CLAUDE.md still asserts "v4 not committed / confirmed absent on disk" — that prose is now stale and wrong against the data.** Flag it for correction (don't edit it here). If for any reason v4 is *not* found on `main`, that reopens D1 — report precisely.
3. `docs/Gayini_pixel_census_data_contract.md` — the parquet schema (16 cols, `pixel_census_data_contract/2026-07-16`).
4. `docs/Tier2_TaskI_deck_stocktake_and_review_bundle.md` — the slide→figure→support map. This is the list of what the deck actually claims.
5. `docs/Gayini_output_structure.md` — where outputs live and the registry state (139 stale rows, 0 current-ladder figures registered).
6. `Gayini_project_goals_and_logic.md` §6 — what each script/product is *for*.

**A2 — Inventory the existing census & ground-cover code, and map each script to the figures/outputs it produces.** This is the "what is already written" step — do it *before* any reconciliation, so Gate C confirms the committed pipeline rather than a rewrite. List what is actually on disk (verify these exist; note any absent) and read the head of each to record its declared inputs and outputs:
- `scripts/03_inundation_products/12_run_census_trend_test.R` — census matrix, F6 verdicts, per-year cut
- `scripts/03_inundation_products/14_build_flood_zone_raster.R` — flood-zone raster + crosstab
- `scripts/03_inundation_products/15_build_pixel_census_parquet.R` — the census parquet
- `scripts/03_inundation_products/11_reproject_annual_stack_8058_nn.R` — the NN 8058 stack
- `scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R` — the 5 veg-percentile rasters
- `scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R` — H2 seasonal gate, floor/green-fraction, monotonicity, seasonal-bias diagnostics
- the F-ladder / dashboard figure builders (e.g. `R/gayini_descriptive_figures.R`, `R/gayini_dashboard_panels.R`) — F1–F7, C1, D1–D3, H2/H6 figures
- **Report any census/ground-cover output for which you can find no producing script** (an orphan output is a finding), and any script whose declared outputs are missing from disk.

**Gate A deliverable:** (a) the doc table — doc · version/date · current? · cancelled-work-as-live; and (b) the **script→figure/output inventory** — script · exists? · declared outputs · outputs-present-on-disk? · which PPT figure(s) it feeds. **STOP for review.** Every later reconciliation must reference a script from this inventory; if a target has no script here, say so rather than writing one.

---

## Gate B — Census spine reconciles on disk (independent path), STOP

The design seat already reconciled the DB summaries and the committed CSVs. **What only the workstation can do is check the actual parquet and rasters.** Do that.

**B1 — the parquet itself** (`Output/census/gayini_pixel_census_8058.parquet`):
- row count == **1,080,157**; cols == **16** (match the data contract).
- `diff = 0` vs `census_stratum.n_pixels` for **all 11 strata** — recompute the group-by from the parquet, don't read `tier2H_h4_census_reconciliation.csv` and trust it. (This is the *real* independent-path check. The `veg_regime_class` identity is vacuous — do not accept it.)
- `valid_years == 35` for every focus row (9 quantitative strata; 988,831 px).
- monotone `p05 ≤ p10 ≤ p20 ≤ p30 ≤ p50`, **0 violations**.
- `pixel_id` → x/y round-trip **dx = dy = 0 m**.
- null counts: **155** per `veg_p*` column (the §9 reconciliation: 111 FC pixels dropped at `MIN_SEASONS=50` × (30/24.970268)² ≈ 160 ≈ 155).
- **checksum:** SHA-256 (builder-method first-50-MB convention) == `census_asset.checksum_sha256` (`6b23f6c0…46f966`). Report match/mismatch.

**B2 — community means from the parquet** reproduce facts §9: Aeolian **6.08** · Riverine **12.91** · Inland **27.99** (Σ wet-px-years ÷ Σ valid-px-years). Print all three to 4 dp.

**B3 — the rasters exist, align, and are registered.** For the NN 8058 stack, the 5 veg-percentile rasters (p05/p10/p20/p30/p50), and the flood-zone raster:
- `compareGeom()` against `veg_regime_class_8058.tif` — same grid, extent, CRS (8058), pixel **24.970268 m** (not "25 m").
- `PV + NPV + BS ≈ 100` on the FC-derived products; **147-overshoot pixels set to NA, not clamped** (15 in 350M — immaterial, but confirm the handling).
- nodata/255 survived reprojection **as NA, never as a value**.
- **registry check (C2):** are `veg_regime_class_8058.tif`, the 5 percentile rasters, and the flood-zone raster in `raster_asset` with crs/extent/checksum populated? The audit flagged these as **NOT registered**. Report exactly which are present/absent — do not register them (that's a build).

**Gate B deliverable:** the B1 table (computed vs expected), B2 three means, B3 raster×check matrix with registry status. **STOP for review.**

---

## Gate C — Reproduce the PPT census & ground-cover figures, STOP

**Reference deck:** `docs/Gayini_Veg_samples.pptx` (26 slides). Figure PNGs live in `Output/figures/` (the census/ground-cover set: `F5d_pixel_census`, `F6_strata_trends`, `F7_lag_profile`, `F7_strata_panel`, `C1_veg_regime_*`, `D1_paddock_*`, the `H2_*`/`H6_*` set). **These are the figures the deck shows.** For each, trace to the script that builds it and the table/raster it consumes, then **recompute the headline number from the on-disk source** (by running/reading the committed script per the standing rule — not fresh code) and confirm it matches. Named slides from the stocktake:

| PPT slide | Figure | Number to reproduce (from source, not the slide) | Source to check |
|---|---|---|---|
| **7** (F2, SUPERSEDED) | per-year flood extent | **0.04% (2006) → 84.67% (2022)** across 988,831 px | `tier2H_h33_per_year_cut.csv` ← `12_run_census_trend_test.R` |
| **21** (F6, RESTATE) | is flooding trending? | **9 no-trend / 0 / 0** across 9 focus strata | `tier2H_h32_census_f6_verdicts.csv` ← `12_run_census_trend_test.R` |
| **21 caveat** | why the F5 flag retired | 40-pt design → p<0.05 in **541/1000 = 54.1%** vs nominal 5% | `Output/tables/tier2H_h32_sample_power_summary.csv` (**confirm it's under `tables/`, committed — the C9 prose-only trap recurred twice**) |
| **18/19** (checkerboard/staircase) | absolute flood zones | crosstab within **0.05 pp** of facts §9 (5 zones × 5 communities) | `tier2H_h6_flood_zone_crosstab.csv` ← `14_build_flood_zone_raster.R` |
| **ground cover — the floor** | floor is ~97% dead | median total-veg **58** / green **1** / **green-fraction 3.03%**, n=**959,833**, PAIRED | `tier2H_h2_green_fraction_at_floor.csv` ← `03_h2_seasonal_gate_and_diagnostics.R` |
| **ground cover — refugia** | ~4,300 ha majority-green | **~4,300 ha (≈5%)** floor is majority-green | ⚠️ **no standalone committed table found** — see C-note |
| **ground cover — gradient** | floor tracks flooding | p05 varies **40.68 pp** across the flood gradient | veg-percentile rasters + `02_build_total_veg_percentile_rasters.R` |
| **ground cover — seasonal** | floor is seasonally sensitive | p05 delta **+10.85 pp** (~2× p50); mixture gate **PASS**, confound **0.31%** | `tier2H_h2_gate_season_mix.csv`, `..._seasonal_bias_test.csv`, `gate_verdict.json` |
| **F7 lag (24–26)** | response by community | per-**plot** r **0.17 / 0.26 / 0.42**, ~3-month lag — **plot support, unchanged by census** | per-plot lag script (Task H §2 keeps this on the plot method) |

**Reconciliation targets — critical distinctions to preserve as you go:**
- **Grid ≠ farm.** Veg-percentile rasters are **FC-extent masked** (2,550 km², 66.3% not Gayini). Report **grid median p05 = 58.206 AND farm-masked = 59.348** — both, always. A single unqualified median is a defect.
- **Percentiles do not subtract** (§11). The floor's "97% dead" is a **paired** measurement (the PV value in the season that sets the total floor). If any figure derives composition by subtracting marginal p05(total) − p05(PV), that reproduces the retired "99% dead" error — flag it.
- **F6 support:** the F6 slide must be **pixel/census** support (9/0/0). F7 lag stays **plot** support (0.17/0.26/0.42) by design. If a single figure mixes them, that's the C10 error — flag it.

**C-note (the one genuine gap to resolve on disk):** the **~4,300 ha refugia** number has **no committed standalone table** — it lives in facts §9 prose and the stocktake. On the workstation you can settle it: from the green-fraction-at-floor computation (n=959,833), count pixels with floor green-fraction > 50%, convert to ha (× 24.970268² / 10⁴ per pixel), and report the area. **Confirm it lands near 4,300 ha.** Write the result to `Output/diagnostics/ondisk_review_20260720/refugia_area_check.csv` (additive scratch, not a registered product — registering it is Adrian's call per §12).

**Gate C deliverable:** the table above with a **computed** column beside each expected number, a ✓/✗ per row, the refugia area result, and any figure that (a) can't be reproduced, (b) mixes support, or (c) subtracts percentiles. **STOP for review.**

---

## Gate E — The all-pixel figure reframe *(scope & propose; build only the POCs)*

**The framing for this gate — read this first, it changes how you read every slide below.** Do **not** approach these as "restyle the old figure." Approach each by its **question**, and ask: *can that question be answered using all relevant pixels instead of the ~40 plots near the sites?* The design decision to pivot from sampling to an all-pixel census was made precisely so headline claims ("no trend", "veg responds / doesn't respond to flooding") rest on maximum data, not a subsample. Several of these deck figures still show the 40-plot version; the job is to move each to all-pixel **where the question and the data allow**, and to be explicit where they don't.

**Key principle Hugh raised:** more pixels don't manufacture a relationship — they tighten the estimate. That cuts both ways, which is exactly what we want: an all-pixel "weak/no response" is a *strong, defensible* statement ("and we're sure"), not a hedge. All-pixel removes the "maybe we just didn't sample enough" escape hatch in **both** directions — for "there is a relationship" and for "there genuinely isn't one." That is the whole reason to do it before making the big statements.

**This gate does NOT commit figures.** It (a) classifies each figure by question → all-pixel feasibility, (b) checks on disk whether the all-pixel version already exists or is new analysis, and (c) renders 2–3 POC scatter styles on one stratum. Then STOP for Hugh.

### E1 — Figure-by-question table (the reframe)

For each, the question is what matters, not the old code path. **The split is: figures about *flooding alone* are already all-pixel; figures about the *veg×flooding relationship* can go all-pixel for the same-year response, with the lag being the one record-limited exception.**

| Slide | The question it asks | Old support | All-pixel version | Effect on the claim |
|---|---|---|---|---|
| **S12** (`F5d_pixel_census`) | how much farm does each stratum cover, vs how densely sampled | area bars + sampling density (pts/1000 ha) | **Simplify, don't rebuild.** The sampling-density half is the very worry the census dissolves — drop it. Keep the **area** half as a clean all-pixel coverage bar. The "two-thirds of mapped farm" (66.44%) is a **held trap** — correct as written, do not "fix". | Retires the density question rather than strengthening it. |
| **S21** (`F6_strata_trends`) | **is flood frequency trending?** (hydrology only — no veg) | shown as census τ/p already, but deck text hedges "thinly sampled / provisional" | **Already all-pixel.** The τ/p per stratum are computed over census pixels, not 40 plots. Rebuild = **drop the 40-plot caveat, re-tint the 9/0/0 verdict.** | **Strengthens directly.** "No directional trend" becomes robust, not provisional. The easy win. |
| **S24** (F7 response by community) | **does veg respond to flooding, per community?** | median of 3–8 plot correlations (r 0.17/0.26/0.42) | **Per-pixel same-year response** (veg vs wet-extent, per pixel, over 35 yr) pooled to community — thousands of pixels per community, not a handful of plots. | **Strengthens strongly.** Community response goes from "median of a few" to a real distribution. |
| **S25** (F7 lag profile ~3 mo) | **how long after a wet pulse does cover respond?** | per-plot cross-correlation | **All-pixel where the record allows.** ⚠️ The lag needs *sub-annual* veg (FC is seasonal) and *monthly* inundation (daily gauge product is recent) — so the lag has genuinely fewer usable pixel-months than the same-year response. Still far more than 40 plots, but **record-limited**. | Strengthens, but **be explicit about the record limit** — don't let a shiny all-pixel figure imply the lag is as well-supported as the same-year response. |
| **S26** (F7 strata panel, 3×3) | **response per community×wetness cell** | 3–8 plots per cell → "small-n caution, don't over-read a cell" | **Per-pixel same-year r summarised per stratum** — the 9-cell matrix with thousands of pixels per cell. **This is the biggest win.** | **Strengthens most.** The "don't over-read a single cell" caveat largely disappears. |
| **Dashboard "Vegetation response" scatter** (`gayini_dashboard_panels.R::gayini_panel_veg_response`) | veg vs wet-extent for this unit | **1 plot** ("n = 1 plot… small n") | All relevant pixels for the stratum as a density scatter + trend (see E3). | **Clearest single win** — n=1 → the whole conditional distribution. |

**The reframe in one line:** stop calling S24/25/26 "the F7 plot figures" and start calling them **the veg×wetness response census** — a 3×3 community×wetness matrix where each cell's response is estimated from thousands of pixels. That object dissolves the "small-n, don't over-read a single cell" caveat visible on both F7 images. (One caveat replaces another, honestly: thousands of pixels per cell are **not** thousands of *independent* samples — they're spatially autocorrelated — so report the pixel count but don't treat it as raw n for significance. The gain is real coverage of the stratum, not inflated degrees of freedom.)

**Two honesty checks to carry into the rebuild (Hugh asked for these explicitly, *before* the big statements):**
1. **Narrow CIs ≠ certainty.** Going from 40 plots to ~1M pixels collapses *sampling* uncertainty but not the **structure-vs-condition** limitation (Landsat FC cannot separate land-use change from ecological condition) or pixel-level temporal autocorrelation. Keep the honest footnote even on the all-pixel version; do not let tight intervals oversell what FC can see.
2. **Same-year vs lag are different support levels** — never merge them into one "F7 is all-pixel now" claim. Same-year: fully all-pixel. Lag: record-limited. Label each.

### E2 — Rebuild vs new analysis: check the disk FIRST

Hugh's recollection: *"I think we may have done some of this work already."* Before scoping any build effort, **find out whether the per-pixel veg×wetness response already exists in the pipeline** (the way the census trend test `12_run_census_trend_test.R` already computes F6 at all pixels), or whether it only exists at plot support so far.

- Search `scripts/` and `Output/` for an existing **per-pixel same-year correlation** of total-veg vs wet-extent (candidates: anything alongside `12_run_census_trend_test.R`, the `05_ground_cover/` scripts, or a `tier2H_*response*` / `*veg_wetness*` table). Report the exact path if found, or "not found — this is new analysis" if not.
- Do the same for a **per-pixel lagged** correlation (the S25 question).
- **Deliverable per slide: `rebuild` (all-pixel computation exists, figure just needs building/restyling) vs `new-analysis` (the per-pixel response must be computed first).** This is the single fact that decides how big the F7 rebuild is — get it from disk, don't guess.

### E3 — The all-pixel scatter design — you cannot plot 1.08M points

Overplotting 1M pixels gives a black blob that hides the central tendency. Options, roughly in order of preference for a remote-sensing deck; **prototype 2–3 on ONE stratum and show Hugh before committing to all panels:**

1. **2-D density / binned heat** — `geom_bin2d()` or `geom_hex()` (hexbin reads well for continuous fields). Density *is* the message: where the mass of pixels sits. Pair with a viridis/Cividis fill (colour-blind safe) and a log-count scale so sparse tails stay visible. Ref: r-graph-gallery.com/2d-density-plot-with-ggplot2.html (Hugh's link).
2. **Density + trend overlay** — the heat/contour layer for the cloud, **plus a bold central-tendency line**: `geom_smooth(method="gam", formula = y ~ s(x))` for a data-driven curve, or `method="lm"` if a straight line is defended. Show the CI ribbon (`se=TRUE`) or a manual 95%-of-points band. This is the "grey shading for the interval + bold line for the trend" pattern Hugh described, and it's the standard RS-journal look.
3. **Contour lines** — `stat_density_2d(geom="polygon")` or contour lines over a light point layer; cleaner than hexbin when you want to show *shape* rather than *count*.
4. **Quantile bands** — bin x (e.g. wet-extent deciles), plot the p10/p25/p50/p75/p90 of veg per bin as a fan. Reads as "here's the whole conditional distribution, not just the mean" — arguably the most honest for a skewed veg response, and it echoes the percentile language already in the census.

**Design constraints to honour (from the project, not optional):**
- **Palette:** keep the canonical four-community hues (Aeolian gold `#C79A3C`, Riverine teal `#3FAE97`, Inland blue `#2E6DB0`, Woodland grey `#9AA79E`) for community identity; use a **sequential** fill (viridis) for *density*, so density and identity don't fight. Don't recolour communities.
- **Support label:** an all-pixel panel is **pixel support** — label it as such, and **do not place it in the same figure as a plot-support panel** without a clear divider. Mixing 1.08M-pixel density against 40-plot dots in one visual is the exact plot-vs-pixel confusion the project keeps flagging (C10).
- **Grid ≠ farm:** if the scatter is built from the veg-percentile rasters, it's FC-extent masked — mask to farm first, or the cloud includes 66% non-Gayini pixels.
- **Sqrt/secondary x:** the current panel uses `sqrt`-x on within-year wet-extent as a *secondary* intensity metric. Keep the axis transform decision explicit; a density plot on a transformed axis needs the bins computed post-transform.
- **Performance:** 1.08M rows × several panels — bin server-side (compute the 2-D histogram / hex counts in `data.table`/`dplyr` once), don't hand ggplot the raw million per facet. For contours/GAM, fit on a sensible sample or on the binned summary, not all points.

**Look-and-feel:** Hugh wants these to look great — worth pulling 2–3 exemplar figures from recent remote-sensing papers (e.g. *Remote Sensing of Environment*, *RSE*; density-scatter of fractional cover vs a hydrological covariate) as visual targets before finalising. Note the reference in the plan; don't reproduce copyrighted figures, just cite the style.

**Gate E deliverable (no committed figures):**
- **E1 — the figure-by-question table**, filled in: each slide classified by its question → all-pixel version → effect on the claim, with the same-year-vs-lag support level called out for S24/25/26.
- **E2 — rebuild vs new-analysis per slide**, decided from disk: does the per-pixel same-year response (and the lagged response) already exist? Give the path if yes, "new analysis" if no. This is the fact that sizes the F7 work.
- **E3 — a proof-of-concept**: 2–3 candidate all-pixel scatter styles rendered for **one** stratum (e.g. Inland Floodplain) to `Output/diagnostics/ondisk_review_20260720/poc_scatter/` (scratch, not registered), so Hugh can pick a look.
- the script/function that would own each rebuild (`gayini_dashboard_panels.R::gayini_panel_veg_response` for the Property Matrix scatter; the F6/F7 builders for the deck slides).
**STOP for Hugh's sign-off before any figure is committed or registered.** The two honesty checks (narrow-CI ≠ certainty; same-year vs lag) must appear in the rebuild plan, not just here.

---

## Gate D — Ground-cover code & output health, report and STOP

A light pass over the ground-cover pipeline specifically (script folder `scripts/05_ground_cover/`):

- **Script inventory:** `02_build_total_veg_percentile_rasters.R`, `03_h2_seasonal_gate_and_diagnostics.R` — do they run clean read-only checks (no missing inputs)? Do their declared outputs exist on disk?
- **FC band semantics — the known hard blocker.** Facts §9 / C3 / C7: the 153 FC rasters had `legend_status = needs_check` and the JRSRP percentage-plus-100 offset convention was unresolved. **Report the current state**: is `legend_status = confirmed` now? Is nodata set (255)? This gates any *future* veg arithmetic — confirm whether it's resolved or still open. **Do not resolve it here.**
- **`MIN_SEASONS = 50` does two jobs** (percentile validity AND open-water exclusion). Confirm the script comment/guard records both, and that the lake (346.9 ha, 5,564 cells at 8,999,545 / 4,349,484, 91.4% inundation) is **NA in the veg products, never a fabricated floor**. Confirm via `tier2H_h2_blob_probe.csv` + a direct raster read at those coordinates.
- **`plot_rs_analysis_base.csv`** — the smoke test flags this **missing** from `Output/csv/`. It must be restored before `05` can re-run. Confirm present/absent on the workstation; if present here but not on `main`, that's a "restore + commit" finding.
- **D2 — the C1 area-basis check (carried from Gate C, still open).** `PRAGMA table_info` on `census_stratum` and `v_pixel_census_by_veg_regime`: do they now carry `mapped_area_ha` / `farm_area_total_ha` columns, or is `farm_area_ha` still the lone 67,349.332 (mapped) basis? Recompute one row's `pct_of_farm` (e.g. Aeolian low) and report whether it divides by mapped (67,349) or true farm (85,910.8). **D1 and C2 both turned out already-fixed on disk — establish whether D2 has too, or is genuinely still open.** Read-only; don't add the columns here.

**Gate D deliverable:** script-runs-clean ✓/✗, FC band-semantics current state (resolved/open), lake-NA confirmation, `plot_rs_analysis_base.csv` present/absent, and the **D2 verdict** (resolved-on-disk / still-open, with the recomputed `pct_of_farm` basis). **STOP.**

---

## Final deliverable

A one-page **on-disk review verdict**:
- **Gate A:** docs current? any cancelled-work-as-live? **plus the script→figure/output inventory** and any orphan outputs / missing declared outputs.
- **Gate B:** parquet + rasters reconcile independently? checksum match? registry gaps (C2)?
- **Gate C:** every PPT census/ground-cover figure reproduced from source ✓/✗; refugia area; any support-mixing or percentile-subtraction.
- **Gate D:** ground-cover code health; FC band-semantics status; lake NA; missing base CSV; **D2 area-basis verdict**.
- **Gate E:** the figure-by-question table (each slide → its all-pixel version → effect on the claim), the rebuild-vs-new-analysis verdict per slide from disk, and 2–3 candidate all-pixel scatter POCs on one stratum.
- **A per-script code-health readout** (this is a code review, not only a numbers match): for every script in the Gate A inventory, mark it **run-clean** (exercised read-only, emitted its declared output) · **bug-found** (with the specific discrepancy) · or **not-exercised** (and why — e.g. missing input, gated on FC band semantics). A figure whose number matches but whose script was never exercised is **not** a pass — say so.
- **The finalised defect ledger** — take the running ledger at the top, resolve every ⏳ (D2/D3/D4 at Gate C, band-semantics at D), and present the closed table: each defect with final status (resolved-on-disk / open / new) and its residual flag-only action. This is the clean list Hugh works from.
- **One explicit line:** *"census + ground-cover figures reproduce from the committed code on disk, safe for the PPT rebuild"* **or** *"these N figures/products do not reproduce and block."*

Then the review is done. Write the verdict to `Output/diagnostics/ondisk_review_20260720/verdict.md` (scratch) and **also** paste it back to the chat. **Gates A–D commit nothing.** Gate E may render POC scatters to the scratch folder only — **no deck edits, no figure committed to `Output/figures/`, no `raster_asset`/`figure_asset` registration** until Hugh signs off on the rebuild plan. Those are a separate, gated build session.

---

## Notes for the executing session

- If a required doc (esp. **v4**) or table is genuinely absent from `main`, that is itself the highest-value finding — report the absence precisely (path checked, not found), don't work around it silently.
- If the parquet is on the USB/laptop rather than the workstation, report the path you looked at and stop B1 — don't reconcile against the committed summary CSV as a substitute and call it done.
- Everything analytical is **EPSG:8058**. If a raster reads as a different CRS, stop and report — do not reproject to "fix" it.
- Keep plot-support and pixel-support numbers in separate columns end-to-end. When in doubt about which a figure uses, read the script that builds it, not the slide caption.
- **On S24–S26 (Gate E): the reframe is resolved — these move to all-pixel, deliberately.** The old stocktake said F7 "stays per-plot"; that has been superseded by the decision to answer the veg×flooding question at all relevant pixels (the same logic that made F6 a census). Do **not** treat S24/26 as a restyle of plot data — they become the per-pixel **veg×wetness response census**. The one nuance: the **same-year response is fully all-pixel; the S25 lag is record-limited** (seasonal FC + recent sub-annual inundation). Label the two support levels separately; never merge them into a single "F7 is all-pixel" claim.
- **Check the disk before scoping (E2).** Hugh thinks some per-pixel response work may already exist. Whether S24/25/26 are a `rebuild` (computation exists) or `new-analysis` (must be computed) is a fact to establish from `scripts/`+`Output/`, not to assume. That verdict sizes the whole effort.
- **All-pixel strengthens both directions.** A weak/no response measured at ~1M pixels is a *strong* statement, not a failure — it removes the "undersampled" escape hatch for both "relationship" and "no relationship". But keep the honesty checks: narrow CIs from a million pixels do **not** shrink the structure-vs-condition limitation or temporal autocorrelation.
- **The all-pixel scatter is where the design effort belongs** — prototype 2–3 styles on one stratum and let Hugh choose before building all panels. Don't hand ggplot a raw million points; bin first.
