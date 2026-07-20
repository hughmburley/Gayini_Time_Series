# Gayini Remote Sensing — Project Goals, Logic & Repo Orientation

*North-star reference for the Gayini (Nimmie-Caira) remote-sensing environmental-change assessment. Written 19 July 2026 as a stable summary of WHY the work exists and WHAT each part of the repo is for — so the code and outputs can be audited and streamlined against the actual analytical goals.*

*This document explains intent and logic. It is deliberately not a rules file. For authoritative rules see `CLAUDE.md`; for measured data properties see `Gayini_established_data_facts.md`; for the canonical ladder see `Gayini_Figure_Driven_Project_Ladder.docx`. Where this doc and those disagree on a rule or a number, they win — this doc is the map, not the territory.*

---

## 1. What we are trying to find out

Gayini is an 85,911 ha floodplain on the lower Murrumbidgee (Lowbidgee), returned to Nari Nari Tribal Council management and now run for conservation alongside grazing. The Biodiversity Conservation Trust contracts UNSW (via the Nari Nari–BCT agreement) to assess how the property's flooding and vegetation have behaved over the satellite era, as a deliverable for the Nari Nari as land managers.

The scientific work is organised as **three nested questions**, simplest first:

- **Q-A — Is flooding directional or variable-but-stable over 1988–2023?** Is the amount of inundation trending, or is it episodic (driven by a few big flood years) around a stable long-run level?
- **Q-B1 — Does inundation organise by vegetation community into a dry→wet gradient?** Do the mapped vegetation communities sit at systematically different positions on the wetness spectrum?
- **Q-B2 (the headline) — Does vegetation ground-cover response to inundation vary along that gradient, and with what temporal lag?** Where, and how quickly, does the vegetation "green up" after water arrives?

The organising principle is **evidence-gated escalation**: check whether a trend exists, and whether it is linear and roughly stationary, *before* modelling it. A continuous probability/trend surface is only built if a real, stationary trend is found. **"No robust trend here" is a legitimate, reportable result — not a failure.** This is the single most important piece of project logic and it explains most of what has and hasn't been built.

---

## 2. The answer so far (why the repo looks the way it does)

The evidence gate (F6) came back: across the vegetation × wetness strata, the verdict was **no directional trend** — the system is **flood-pulse driven, not trending**. Flooding is highly variable year to year, dominated by a handful of big flood years (2010–11, 2016–17, 2022–23), around a stable long-run level. The major structural decline in Lowbidgee flooding happened *before* our 1988 window (river regulation), so a stable record inside the regulated, now-managed era is the expected and reportable finding.

**Consequences that shape the repo:**
- The **trend/change surface (F9) is retired.** The static background flood-frequency surface (F5) *is* the flood-probability product. Any code or outputs building toward a trend surface are superseded.
- The **pre/post-2019 framing is retired.** The transition date to Nari Nari management is genuinely uncertain (2013 control vs ~2019 management change), and the analysis is full-record and spatially explicit, not a before/after contrast. Pre/post code is archive-only; the `period` column must not leak into analysis outputs.
- The **strongest, most novel result is Q-B2** — the community-structured ground-cover response and its characteristic lag — not the (null) trend result. The paper should lead with B2 and treat A as the enabling baseline.

---

## 3. The two analytical eras — sampling, then census

The project pivoted once, and understanding the pivot is essential to auditing the repo, because **code from both eras coexists on `main`**.

**Era 1 — stratified sampling (Tasks A–F, the "figure ladder").** The original design sampled points within each vegetation × inundation-regime stratum, near the plots but excluding their footprints, and tested each stratum for a trend. This produced the F1–F7 ladder of paired concept + data figures. A planned refinement was a proportional-with-floor Monte-Carlo resampling (to fix over-representation of small dry strata and under-sampling of the large wet Inland Floodplain).

**Era 2 — all-pixel census (Task H, current).** At Adrian Fisher's 15 July review, the direction changed: rather than *sample*, use **all valid pixels** in each vegetation × wetness class — a pure geospatial census, not a statistical sample. This removes the sampling problem entirely (and with it the "thinly-sampled wet end" caveat), and it is now complete. The census is the substrate for re-running the trend, lag, and response analyses across every pixel.

**Audit implication:** the Monte-Carlo sampling rebalance (Task F resampling) is **largely superseded** by the census. Task F code stays on `main` but uncalled (additive-only, nothing deleted); its spec is archived with a superseded-by header. When streamlining, the census path (Task H products, `v_pixel_census_by_veg_regime`) is the live one; the sampling-rebalance path is dormant and should be clearly marked as such rather than silently carried as if current.

---

## 4. Remote-sensing concepts and methods (what the code actually does)

**Inundation detection.** Annual flooding is derived from the NSW DCCEEW Landsat/Sentinel inundation record over 1988–2023. The headline metric is **between-year annual flood frequency = 100 × wet-valid-years ÷ valid-years** — computed per pixel, then summarised by stratum. This is the metric that *defines the strata*. A separate field, `annual_occurrence_pct`, is a **secondary "wet-extent coverage" metric** — despite the word "occurrence" it is NOT the headline and must never be presented as such.

**Validity masking.** Observation support changes across the Landsat→Sentinel record, so pixels/years below a minimum valid-coverage threshold are masked before any trend statistic (default `MIN_VALID_COVERAGE = 40`). This prevents sparse early-record coverage from manufacturing false trends.

**Ground cover.** Vegetation is from JRSRP fractional cover (green + dead = total vegetation). Per Adrian's direction, the response analysis uses **lower percentiles of total vegetation** (5th/10th/20th/30th/50th) across the time series, as rasters — not the mean or median. The logic is ecological: the lower percentile is the *floor* of the system, so if something persists when vegetation is generally struggling, that signals resilience — a different and more informative question than average cover. Bare ground is dropped everywhere (it is near-redundant with total veg).

**The census.** Task H computes, for every valid pixel: the inundation frequency, the total-veg percentile surfaces, and an absolute flood-zone raster — stored as a parquet census keyed to the canonical grid, plus a set of veg × wetness strata. Every census pixel has full 35/35-year support (verified). This is the "pure geospatial" substrate Adrian asked for.

**Trend testing (F6 / Q-A).** Each stratum's flood-frequency series is tested with a linear fit plus LOESS, and classified as trend / no-trend / non-stationary, with the two biggest flood years dropped as a robustness check. The verdict drives the gate (see §2).

**Lag and response (F7 / Q-B2).** Ground-cover response is related to inundation at a lag, per vegetation × wetness cell, producing a matrix of correlation lags — the census version replaces per-plot medians with all-pixel estimates. The open scientific question worth testing: does the lag *itself* vary along the dry→wet gradient?

**Display discipline for census figures.** All-pixel figures must not render thousands of points; they use confidence-interval bands and/or heat-map / kernel-density displays. One figure = one file = one slide; concept figure paired with data figure.

**Not yet in scope (parked, deliberately):** rainfall/ENSO decomposition (only after a trend is found); a gauge × RS mixed-effects model (predict inundation from gauge flow, read residuals as a management signal — the RESTREND logic); management attribution. These are research directions, not current deliverables.

---

## 5. Ecology concepts (the interpretive frame)

**The dry→wet vegetation gradient.** Three non-treed communities are treated as an inundation gradient, verified from the flood-frequency data:

| Community | Mean annual flood frequency | Role |
|---|---|---|
| Aeolian Chenopod Shrublands | ~9% | Dry end |
| Riverine Chenopod Shrublands | ~22% | Intermediate |
| Inland Floodplain Shrublands / Swamps | ~50% | Wet end (≈ two-thirds of the mapped farm) |
| Floodplain Woodland / Forest (treed) | ~44% | Context only — excluded from ground-cover interpretation (canopy confounds the signal) |

**Why this isn't circular:** strata are defined by *background* (long-run) wetness — where a location sits on the gradient — and then tested for a *trend over time* within that stratum. Those are two different quantities.

**Flood-pulse ecology.** The whole causal chain rests on the flood-pulse concept: the flood pulse (not standing water) drives floodplain productivity, and vegetation responds after a lag. The ~3-month green-up lag and the "response strengthens toward the wet end" pattern are the project's expression of this, and they connect to the antecedent-flooding literature (river red gum inundation requirements, resistance/resilience by landscape position).

**The structure-vs-condition caveat (critical).** Landsat fractional cover measures *cover*, not vegetation *structure* or *identity*. The same total-veg value can mean irrigated cropping (wheat/cotton) early in the record and re-established native chenopod later, as land use shifted from cropping to grazing under changing management. A trend in cover could therefore be a trend in *land use*, not condition — a potential confound for the entire ground-cover time series. This is now independently confirmed by CSIRO's own published limitation statements (Landsat condition misses understory structure). It reshapes the likely paper framing: if Landsat FC cannot resolve management effects, the null result is itself the story, and higher-resolution data (LiDAR, nearmap) would be the next-resort route. Adrian has pre-authorised a null result as publishable.

**Biodiversity condition data (HCAS / LOOC-B).** CSIRO condition/biodiversity variables can be compared with **inundation** (independent) but **never with ground cover** (circular — both derive from the same Landsat reflectance). Any such comparison is a "consistency check," not validation, and is kept in an appendix with the circularity stated.

---

## 6. What the repo contains, and what each part is FOR

*This section is the orientation Claude Code needs. It maps intent onto the actual structure so files can be audited against current goals. Measured repo facts (file counts, registry state) live in `Gayini_output_structure.md`; this is the "what is it for" layer.*

**Repositories.** `hughmburley/Gayini_Time_Series` (main RS analysis); `hughmburley/Gayini_Biodiversity` (biodiversity companion).

**The database (`Output/database/Gayini_Results.sqlite`) is authoritative.** Consume it via **views, not raw `fact_*` tables**: `v_plot_year_analysis_spine` (the modelling spine, 66 plots × 35 years) and `v_pixel_census_by_veg_regime` (the census substrate). The `.gpkg` is the map companion; rasters are external, registered in `raster_asset`. The Python builder rebuilds from scratch, so raster metadata, the annual stack, and the census are **post-build steps that must be re-run in order** after any full rebuild — a DB missing `raster_asset` rows or `v_pixel_census_by_veg_regime` has not had them applied. Check `v_database_release_checks` and `v_current_qa_issues` before trusting a build.

**Code, by purpose:**
- **Live analysis pipeline (R):** builds the database, the figure ladder (F1–F7), and the census products. This is the current path.
- **Task H census code:** computes the all-pixel census, percentile rasters, and flood-zone raster. **This is the current analytical substrate** — the thing most downstream work should now consume.
- **Sampling / Monte-Carlo rebalance code (Task F):** **dormant.** On `main`, uncalled, kept additive-only. Superseded by the census. Should be clearly flagged as dormant, not silently carried.
- **Pre/post code:** **archive-only.** Retired framing. Must not run in the active pipeline; `period` must not reach analysis outputs.
- **Dashboards (D1 paddock / D2 site / D3 stratum):** in trial, held at the gate, not committed. Intended as a Nari Nari deliverable (per-site reports = narrative context + dashboard).

**Outputs, by purpose:** figures follow "one figure = one file = one slide," paired concept + data. The `Output/` tree is mid-restructure (see `Gayini_output_structure.md`) because the figure registry currently tracks the *superseded* generation while the current ladder (F1–F7, dashboards, Task H) sits untracked at `figures/` root. **This registry/reality mismatch is the core audit problem** the streamlining needs to fix.

**Archive convention:** archived scripts go to `scripts/archive/` (enforced), not `scripts/_deprecated/`.

---

## 7. The audit lens — how to use this doc to streamline

When auditing a file or output, ask which bucket it falls into:

1. **Live and current** — serves Q-A / Q-B1 / Q-B2 via the census path, the database views, or the figure ladder. Keep, and ensure it's tracked/registered.
2. **Dormant but retained** — the sampling/Monte-Carlo rebalance. Superseded by the census; keep on `main` (additive-only) but mark clearly as not-current so it isn't mistaken for the live path.
3. **Retired / archive-only** — pre/post framing, the F9 trend surface, MER-as-headline. Must not run in the active pipeline; belongs in `scripts/archive/`.
4. **Untracked-but-current** — the biggest real problem: current-ladder figures and Task H products that exist on disk but aren't in the registry. These need *registering*, not archiving.

The evolving goal the streamline serves: a repo where the live census-based analysis for the three questions is cleanly separated from the two dead ends (sampling rebalance, trend surface) and the retired framing (pre/post), and where what's on disk matches what the registry claims — so a fresh session (human or Claude Code) can tell what each file is for without re-deriving the project's history.

---

## 8. One-paragraph synthesis

Gayini's flooding shows **no directional trend** over 1988–2023 — it is variable-but-stable, flood-pulse driven, inside an already-regulated and now Indigenous-managed floodplain. Inundation and vegetation response are strongly **organised by vegetation community along a dry→wet gradient**, and ground-cover response follows the water with a **characteristic lag** that strengthens toward the wet end. The method moved from stratified sampling to an **all-pixel census**, and from a planned trend surface to a **gated null result** reported honestly. The main live caveat is **structure-vs-condition**: Landsat cover may not resolve management effects, which could make the null itself the paper's contribution. The repo should be streamlined so the census-based analysis for the three nested questions is the visible, tracked core, with the sampling rebalance and trend surface clearly retired.
