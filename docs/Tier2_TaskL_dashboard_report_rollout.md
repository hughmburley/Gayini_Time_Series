# Tier 2 · Task L — dashboard & report roll-out: propagate the all-pixel scatter to every unit

**Spec version: v11 · edited 2026-07-22 · status: Gates 0–2 CLOSED, Gate 3 RENDERED (held for merge), Gate 3.1 QUEUED · next: Gate 3.1 design-confirm → re-render.**
> **Standing rule — change reports:** every build gate (any gate that writes/moves files or touches the repo — e.g. Gate 3, Gate 5) ends with a change report to `docs/change_reports/`, written as `..._DRAFT.md` and left draft until human-reviewed. Read-only recon gates (0–2) record their outcomes in this spec's Gate-CLOSED blocks instead.
> **At the start of EVERY gate: re-read this WHOLE file (not a line-range) and echo this version line back verbatim before building.** If your copy shows an earlier version than the kickoff cites, or you cannot echo it, you have a stale/partial copy — STOP. (At Gate 2, CC read only lines 77–136 and skipped the echo — that is the exact gap this rule closes.) The spec changes as the design seat refines it; building from a stale copy reintroduces resolved decisions.
> *Changelog — v11: Gate 3.1 queued — site inset paddock highlight; retire paddock veg-map legend (full 2-D key moves to the main-report whole-farm map); site veg×water panel nests the paddock within the community cloud (not swapped); sparse-tail caption note. v10: Gate 3 rendered; Gate E found NOT merged (merge-order note); 10 sites unplaced kept with honest note; GA_022 mismatch logged. v9: standing change-report rule. v8: dominant-community area share on paddock panels. v7: Gate 2 closed. v6: Gate 1 closed. v5: Gate 0 closed. v4: Option B + two-scatter + Gate 0 + autocorrelation steer. v3: support-discipline + scope + nesting. v1–2: CC draft.*


*Build task for a fresh Claude Code session. Depends on the completed **Gate E figure build** (`Tier2_TaskH_gateE_figure_build.md`) — which established the all-pixel veg×water scatter method. **⚠ Gate E is NOT merged to main** (Gate 3 git finding, 22 Jul): its 10 commits live on branch `tier2h-gateE-figure-build` (PR open), and its `figure_asset` rows exist only in the gitignored working-tree DB. Task L is **independent of Gate E's commits** — it re-derives the substrate from on-disk rasters — so it branches off `main` cleanly. **Merge order for Hugh: Gate E's PR first, then Task L; verify the two branches don't touch the same files before either merges.** This task **propagates** the method — it does not redesign it. Recon-first, gated, STOP at each gate for review. Additive-only; branch-and-PR; **never re-run the builder** (`reset_file` destroys the 12 Task H census rows).*

> **Read first, do not re-derive:** `docs/Gayini_established_data_facts.md` (§9/§11), `docs/Gayini_project_lineage_and_learnings.md` (non-live provenance / trap-index), `docs/Tier2_TaskH_gateE_figure_build.md` (the method this task propagates — §F figure-style is the locked spec), and this file. Re-read this file at the start of every gate; it changes as the design seat refines it.

---

## What this task is

The Gate E build re-derived the veg×flooding response at **census (all-pixel) support** and produced a family of figures. The most audience-facing of these — the **veg-vs-water scatter** — was built at the deck/community level. This task takes that exact scatter method and applies it **per unit**, across two dashboard families, then folds every unit's figures into a per-unit **markdown report**.

**Three deliverable layers:**
1. **Site dashboards** (`GA_xxx`, 57 non-treed) — replace the "Vegetation response" panel (currently the n=1 plot version: "n = 1 plot… small n") with the **community cloud + site marker**. A site is a handful of census pixels, so it can only ever be a *marker on its community's cloud* — never its own cloud.
2. **Paddock dashboards** (Dinan / Bala / Mara / etc.) — **Option B (Hugh, 2026-07-22): build out the full paddock family, ~4 built → ~21.** Each paddock dashboard's veg panel is the **community cloud + paddock marker** (consistent with sites, degrades to 0 plots). Building the missing ~17 pulls in the **D1 paddock generator** and the **F5c flood-frequency dependency** — reconned first at Gate 0.
3. **Per-unit reports** (markdown, one per site and per paddock) — the Nari Nari deliverable. **Paddock reports get an extra, headline figure: the paddock's OWN all-pixel veg×water cloud.** A paddock is thousands of census pixels, so — unlike a site — its own cloud is well-populated and is the report's centrepiece ("how does cover in *this paddock* respond to water," not just where it sits in its community). Site reports use the community-marker figure only.

**Two scatter figures, by scale (Hugh, 2026-07-22):**
- **Community cloud + unit marker** — the dashboard-grid figure for *every* unit (site and paddock). Reuses the Gate E community computation; degrades to 0 plots.
- **Paddock's own all-pixel cloud** — a *new* per-paddock computation, the **report centrepiece for paddocks only**. Sites are too small to sustain their own cloud. Edge case to handle: a paddock spanning two communities can't be one clean community-hued cloud — flag at Gate 1.

**Client-usefulness steer (Hugh, 2026-07-22):** what helps Nari Nari is paramount. We build **no statistical machinery around spatial/temporal autocorrelation** (no effective-n, no corrected intervals — not a work item). The two locked Gate E captions are one line each and stay, because they *are* client-usefulness, not academic hedging: the **"cover, not condition"** line is what stops a management reader taking "high cover" as "healthy Country," and the **"not independent n"** line can be plain-language or pushed to a methods note. Keep them; do no further work on autocorrelation.

**This is propagation, not redesign.** The scatter styles, palette, metric, and honesty captions are already decided (below). Do not re-open them. If a unit breaks the design, that is a finding to report, not a licence to invent a new style.

---

## The locked scatter method (from Gate E §F — do NOT redesign)

The all-pixel veg×water scatter, as established and registered in Gate E:

- **Two forms exist** (both registered in `figure_asset`, `run_id='gateE_20260721'`):
  - **GAM cloud** — grey 2-D density (log count) + community-hue GAM central line ±95% CI, sparse-tail truncated. The intuitive "where the pixels sit + the rising trend" form. **This is the dashboard-panel form.**
  - **Quantile bands** — p50 line (community hue) + p25–p75 / p10–p90 grey bands, 10-pp bins, sparse-tail truncated. The conditional-spread form, for methods/report appendix.
- **Metric: veg_p05 (floor) is the headline** — "the worst-season cover a pixel holds." The Gate E finding is that the flood signal lives in the floor, not the median (p50 is flat-high). p50 (typical cover) versions exist as **supplementary**, not headline.
- **x-axis: between-year flood frequency (%)** — `100 × wet-valid-years ÷ valid-years`. NOT within-year wet-extent (the old dashboard panel used that; the census method uses between-year frequency).
- **Palette: the C1 checkerboard community set** — Aeolian `#C79A3C`, Riverine `#3FAE97`, Inland `#2E6DB0`, Woodland/context grey. Sourced from `gayini_veg_regime_classes()` in the repo — **never retype hexes.** (The biodiversity-config and F7-gradient palettes are NOT canonical — Gate E confirmed this; use checkerboard.)
- **Discipline (non-negotiable, from §F):** grey = density/spread, community hue = the line. Two honesty checks in every caption: (i) ~1M pixels collapse *sampling* uncertainty only — NOT independent n (spatial + temporal autocorrelation); (ii) Landsat FC measures **cover, not ecological condition** — a narrow band is not certainty. Percentiles are plotted, never differenced (§11).

---

## Support discipline on the composite dashboard (read before Gate 1 — design-seat addition)

The swap makes each dashboard carry **three different supports**, each with its own "this unit's flood frequency," and they must never be conflated:

1. **"Where it sits" gradient boxplot — plot support** (1 ha, any-water; e.g. GA_019 ≈ 49%). The red diamond is the unit's *plot-support* value.
2. **Annual-flooding series — 1 km neighbourhood** mean (e.g. GA_019 ≈ 37%).
3. **The NEW veg×water panel — pixel-census support.** The unit marker is the unit's *census* floor/flood-frequency (a third number), per the standing rule.

This is correct by design — three honest measures of different things — but it is exactly where a reader or a future builder mis-reads them as an inconsistency. **Non-negotiable:** the new panel's caption must name its support ("pixel census, between-year flood frequency"), and Gate 1 must state, per panel, which support it carries. The panel swap also changes the x-axis from within-year wet-extent (old plot n=1 scatter) to between-year flood frequency (census) — call this out so it isn't read as a data change.

## The design decision this task must confirm at Gate 1 (before any build)

The Gate E scatter used **all census pixels in a community** (~1M). A unit dashboard is about **one paddock/site**. The population question:

**RECOMMENDED (design-seat lean): community-context with the unit marked.** Show the full all-pixel **community** cloud (the same substrate as the Gate E deck scatter — reuse that computation) and **mark where THIS unit sits** on it — mirroring the existing "Where it sits (by community)" boxplot panel, which already places the unit as a red diamond on community context.

**Why this framing, not neighbourhood-only:**
- It **degrades gracefully to zero plots.** Critical: some paddocks have **0 monitoring plots** (e.g. Dinan 10 — its veg panel is already pure "community context, no plots in paddock"). A neighbourhood-only scatter is impossible for a 0-plot unit; a community-context scatter with the unit marked works for every unit from n=13 down to n=0.
- It's **consistent** with how the rest of the dashboard already contextualises the unit.
- It **reuses** the registered Gate E community computation rather than recomputing per unit.

**Gate 1 must confirm this framing and how "this unit's position" is defined.** Design-seat definition to confirm: the unit's position = (its between-year flood frequency, its veg_p05 floor), each a **census aggregate over that unit's own pixels** — the site footprint for a `GA_xxx`, the paddock polygon for a paddock — read from the census's stored per-pixel values so the marker reconciles to a printed number (standing rule), not recomputed ad hoc. This is also *why* the framing degrades to 0 plots: the marker is a census-pixel aggregate over the unit's polygon, which exists whether or not any monitoring plot falls inside it. Confirm, then STOP for review before building.

---

## Report-embeddability (decide at Gate 1, affects every render)

Every scatter panel must serve **both** the dashboard grid **and** an inline figure in a per-unit markdown report. So:
- Save each as a **standalone figure file** (not only as a dashboard sub-panel) that the report markdown can reference.
- Set dimensions / aspect to work in both contexts — a dashboard cell and a report column. Decide this once at Gate 1; a wrong choice multiplies across every unit. **Note the geometry is doubly constrained:** the new panel must fit the *existing dashboard cell* the old "Vegetation response" occupied (or the grid reflows) **and** read standalone as a report figure. Read the old panel's cell dimensions in the generator, match them, then verify standalone legibility — don't free-choose a report aspect that breaks the grid.
- Register report figures additively in `figure_asset` (never `reset_file`), tagged with a new `run_id` (e.g. `taskL_YYYYMMDD`), `path_exists=1`, existing rows untouched — the Gate E / D4 pattern.

---

## Gated plan

**Gate 0 — build-out recon *(CLOSED — passed read-only, 22 Jul)*.** Findings that reshape the task:
- **No separate D1 generator.** Paddocks/sites/strata all come from `scripts/07_figures_dashboards/12_build_dashboards.R` over shared `gayini_dashboard_compose.R` + `gayini_dashboard_panels.R`. "Paddock" is a **resolver variant** (`gayini_resolve_paddock` vs `_site`): footprint = management-zone polygon (not 1 km ring), community = area-weighted dominant, plots = plots-in-polygon (can be 0, `fallback=TRUE`), "where it sits" = polygon long-run `100·Σwet/Σvalid`. So building 17 more paddocks = **extend the hardcoded `TRIAL_PADDOCKS` (12_build_dashboards.R:46) from 4 to 21 + swap the panel.** Mechanical.
- **No F5c dependency.** The dashboard builds its map from the `veg_regime_class_8058` raster and computes flooding live from the wet/valid stacks; it reads no F5c or C1 files. F5c is an orthogonal presentation-only zoom set (`N_PADDOCK_ZOOMS=4`), not a per-paddock input. **The three-layer build the task feared does not exist. Task L stays one workstream.**
- **Parity PASS** on the 4 built paddocks (Bala 28ca 47.50 / 29ca 10.32 / Dinan 8 12.68 / Dinan 10 10.13, all 1988–2022). One cosmetic drift: the 4 on-disk PNGs read "Total vegetation (green cover)" vs main's "Total veg (green + dead)" — the same #21 label fix; Gate 3's re-render corrects it, no value change.
- **⚠ Pin the canonical 21.** The raw `management_zones` layer has **64 zones**; the deliverable set is the 21 C1 checkerboard paddocks (Bala 6/12/17/19/20/21/23/26ca/28ca/29ca/8/11; Dinan 1/3/6/8/10/12; Mara 7/8/13/21). Derive the paddock list from a **pinned canonical 21**, never from the layer, or the build silently triples to 64.
- **Panel cell geometry:** `gayini_panel_veg_response`, right column, ≈7.20 in wide; **two aspects** — paddock height ≈4.21 in (~1.71:1), site height ≈3.50 in (~2.05:1). The new scatter must render at both AND read standalone.
- **`figure_asset` now:** `gateE_20260721`=11, `d2_site_dashboard_batch_20260720`=57, `db_build_20260701_114458`=139 (stale). Task L adds `run_id='taskL_...'`.

**Gate 1 — design confirmation *(CLOSED — passed read-only, 22 Jul)*.** Confirmed design (durable):
- **Framing:** community cloud (dominant focus community, reused Gate E substrate) + single unit marker; one shared panel for sites and paddocks; **no plot-point overlay**, so it degrades to 0 plots by construction (treed-only ≡ truly-zero for the marker).
- **Marker = mean** over the unit's own census pixels (point-in-polygon, dominant-focus community, `!is.na(veg_p05)`): x = mean `flood_freq_pct` (reconciles exactly to the polygon `Σwet/Σvalid`, since valid_years==35 for focus pixels), y = mean `veg_p05` floor. Median printed alongside on the panel data sidecar. Red diamond, labelled value + "pixel census" support.
- **NaN filter (both functions):** 2 Inland focus pixels store `veg_p05`=NaN (permanently-wet swamp, D7) → `!is.na(veg_p05)` in both, per Gate E.
- **Support labelling:** three supports coexist by design (plot 1 ha / 1 km neighbourhood / pixel census); the new panel caption names its support (e.g. GA_019: 48.57% plot / ~37% neighbourhood / 41.6% census — different by design).
- **Geometry:** live ggplot flexes to both grid cells (aspect-tolerant: internal labels, short titles, in-panel caption); standalone report file fixed at **7.2 × 4.0 in, 300 dpi**, registered additively. Verify legibility at *rendered* report width (~6.5 in column).
- **Two functions:** (a) `gayini_veg_water_community_marker_panel` — shared marker panel (sites + paddocks); (b) `gayini_paddock_own_cloud` — per-paddock report centrepiece, **overlaid per-community GAM lines** on one grey density for mixed paddocks (lines < MIN_BIN_N dropped/logged), with an **in-panel line label** per community. Mixed-paddock dashboard panel (a) carries a "dominant community: X" note.
- **Gate 2 must assert** `dominant ∈ {Aeolian, Riverine, Inland}` for all 21 paddocks — a dominant-Woodland paddock has no focus cloud (context-only) → STOP-and-report finding. Also verify `arrow`/`duckdb` in R (raster fallback = Gate E method if absent).

**Gate 1 — recon + design confirmation (no build).** Read the spine docs + Gate E §F. Confirm: (a) the community-context-with-unit-marker framing **and the per-panel support labelling** (see "Support discipline" above — state which support each dashboard panel carries; the new panel is pixel-census); (b) metric = p05 floor, x = between-year flood frequency, GAM-cloud form for the panel; (c) report-embeddable file dimensions, matched to the existing panel's cell geometry; (d) the unit inventory (below); (e) **the paddock's-own-cloud computation** — how the per-paddock all-pixel cloud is built (the report centrepiece), and the multi-community-paddock edge case. Propose two functions: the community-cloud+marker wrapper (all units) and the paddock-own-cloud builder (paddocks). **STOP.**

**Gate 1 unit inventory — refined by Gate 0.** Sites land on **16 of the 21** canonical paddocks. **5 paddocks have zero non-treed plots: Dinan 1, 6, 10, 12, Mara 13** — and the nuance matters: only **Dinan 10 is truly zero-plot**; the other four have *treed-only* plots, which the veg×water cloud excludes. So the marker logic must handle "treed-only → no cloud contribution," not just "n=0." The community-marker design degrades cleanly for all five. Start from the Task-D2 `plot_paddock` lookup (`Output/tables/d2_batch_plot_paddock_20260720.csv`); print the final inventory.

**Gate 1 SCOPE — resolved: Option B (Hugh, 2026-07-22).** "Every site and paddock dashboard" is not symmetric, and the scope is now fixed:
- **Sites: 57 exist** (the non-treed set built in Task D2; treed sites have no dashboard and no veg×water cloud — Woodland is context-grey, excluded from the Gate E focus communities). Site count reconciles to **57, not 66**, across three focus communities only. Panel = community cloud + site marker.
- **Paddocks: build the full family, 4 → 21 (Option B).** Gate 0 confirmed the cost: **panel-swap + list-extension**, one generator (no separate D1, no F5c dependency). Pin the canonical 21 (not the 64-zone layer). Each paddock dashboard = community cloud + paddock marker; each paddock *report* additionally carries the paddock's own all-pixel cloud.

**Gate 2 — proof renders *(CLOSED — passed, 22 Jul)*.** Outcomes (durable):
- **Render path:** no `arrow`/`duckdb`/`nanoparquet` in R — substrate **re-derived from the three rasters** (Gate E path, `compareGeom()` asserted), reconciles to the parquet by construction. **No parquet dependency in Task L** — carry the raster path into Gate 3.
- **Reconciliation PROVEN:** marker-x = polygon `100·Σwet/Σvalid` exactly (Δ=0.0000, GA_007/Bala 28ca/Dinan 10). Marker at mean; median on sidecar. Both cell aspects render clip-free; standalone 7.2×4.0 legible at 6.5 in column; all three caption lines present (support + 2 honesty), incl. "cover, not condition."
- **Functions:** `gayini_veg_water_census_panels.R` — (a) shared marker panel, (b) paddock own-cloud with **in-panel legend** for mixed paddocks (switched from on-line labels — collision-safe, no ggrepel dep). Both `!is.na(veg_p05)`.
- **Decision 1 — Mara 13 (dominant Woodland 54.3%):** dashboard panel marks it on its dominant *focus* community (Riverine 25%), with a **title-level** flag. Its **own-cloud/report is DEFERRED to the Gate 4 treed-report decision** (majority context/treed — an own-cloud centrepiece would misrepresent it).
- **Decision 1b — dominant-share on ALL paddock panels (v8):** the marker panel marks a paddock on its *dominant* community's cloud, but several paddocks are barely majority (Bala 29ca Inland 33%, Dinan 3 36%, Mara 8 50%, Dinan 8 52%). Every paddock marker panel must **state its dominant community's area share** ("shown on Inland — 33% of this paddock") so the marker isn't misread as representing the whole paddock. Not a Mara-13 special.
- **Decision 2 — site marker thin-n:** show "n = X census px" on-panel (a site is a handful of pixels; honest, and it's the exact census of those pixels, not a sample).
- **Decision 3 — three flood-freq numbers per unit** (plot / neighbourhood / census) accepted — each labelled with its support. *Report* leads with ONE headline (plot-support, per prototype); the other two are panel context. Prove the range with a small set: one **site** (an Inland one — GA_001 or GA_007, strong response) → community cloud + site marker; one **paddock with real plots** (Bala 28ca, n=6) → community cloud + paddock marker **and** its own all-pixel cloud (the report centrepiece); one **paddock with ZERO plots** (Dinan 10) → proves the marker works with no plots. The panel must render at **both** cell aspects (paddock ~1.71:1, site ~2.05:1) and read standalone. Confirm each in the dashboard grid AND standalone. **STOP for sign-off before rolling out.**

**Gate 3 — roll-out *(RENDERED — held for human merge, 22 Jul)*.** Outcomes (durable):
- Branch `tier2L-gate3-rollout` off `main` (uncommitted, per the human-stages-commits pattern). **78 dashboards** (57 sites + 21 paddocks: 17 new + 4 refreshed) + **20 own-clouds** (Mara 13 deferred). Δ=0 marker-x reconciliation for all **68 placed** units. Archive-first: 124 files → `_archive/taskL_pre_rollout_20260722/`.
- **Panel swap is conditional** — sites & paddocks with a census context get the marker panel; D3 strata and any census-less caller keep the legacy `gayini_panel_veg_response` (backward-compatible).
- **Decision (10 unplaced sites):** GA_018/022/024/037/038/044/045/047/048/049 have 0 census pixels of their community in-footprint (7 off the mapped grid, GA_022 a label/pixel mismatch, 2 edge-clip). **Kept, not dropped** — panel shows the community cloud with NO marker + honest note ("no census pixels of this community in the footprint — edge/unmapped"). Their **Gate 4 reports** carry the "off the mapped census grid" line plainly. Never fabricate a marker.
- **Decision (GA_022):** logged as a **separate data-side task** — dim_plot community (Inland) disagrees with its footprint pixel classification; determine which is authoritative (affects its "where it sits" placement + community rollups). Not fixed in Task L.
- **Gate E not merged:** see the header ⚠. Merge Gate E's PR first, then Task L; verify no file overlap.

**Gate 3 — roll out across all units.** Swap the veg panel in the **57 site** dashboards; build/refresh the **~21 paddock** dashboards (Option B) with the marker panel; render every **paddock's own all-pixel cloud** for the reports. Additive outputs; report before/after counts and the paddock build-out count (X newly built vs Y refreshed); list any unit where the design didn't apply cleanly (a finding, not a silent skip). **STOP.**

**Gate 3.1 — dashboard refinements (Hugh, 22 Jul, from the Gate 3 render review).** Small generator changes to the shared panel/inset, then re-render the 78 (the Gate 3 render is uncommitted/unregistered, so re-rendering over it needs no new archive — the pre-Task-L originals are already in `_archive/`). **Design-confirm the paddock-highlight rendering (below) before re-rendering; STOP for that sub-step.**
- **(a) Site inset — highlight the site's paddock** (in red), reusing the mechanism the paddock dashboards already have (their insets highlight the management zone in red). Fallback: a site in no management zone gets no highlight (just its location) — honest, ~18 sites.
- **(b) Retire the veg-map legend on PADDOCK dashboards** — it obscures the map (sits over the paddock on Mara 21). The "Where it sits" boxplot serves as the community-hue key. **Note:** this drops the *wetness-band* (low/mid/high) dimension of the 2-D key from sub-reports; that full community×wetness key must live on the **whole-farm map at the front of the main report/deck** (its one home). Accepted by Hugh.
- **(c) Site veg×water panel — NESTED, not swapped.** Keep the *community* cloud as the base and **highlight the site's paddock's pixels within it** (community → paddock → site marker in one figure), the same geography-in-management nesting the paddock board already shows, viewed from the site. **Do NOT swap the site cloud to a paddock cloud** — ~18 sites have no paddock (GA_024 has no census pixels at all), so a swap can't be uniform; the highlight degrades cleanly (no paddock → community + marker; no census px → community + note). **Design-confirm HOW to draw the paddock highlight** (tinted second density / contour / hull) before re-render.
- **(d) Caption note — explain the dashed line.** The per-unit veg panel dropped Gate E's "sparse-tail boundary; GAM not fit beyond" note, so readers wonder why the line stops. Add a one-liner: the GAM is drawn only where the community has ≥500 pixels per flood-frequency bin (dashed = beyond there, too few pixels to fit — it marks the community's well-supported flood range).
- **Pre-render count (report first):** how many of the 57 sites resolve to a canonical paddock (get the inset highlight + paddock-in-cloud highlight) vs none (fallback); and how many have census pixels (get a marker) vs none. Size the fallbacks before rendering. **Then STOP.**

**Gate 4 — assemble per-unit reports.** For each unit, build a markdown report embedding its figures + narrative. **Paddock reports lead with the paddock's own all-pixel veg×water cloud** (the management-scale centrepiece); site reports use the community-marker figure. Establish the report template on ONE paddock and ONE site first, STOP for review, then generate the rest. Reports are the Nari Nari deliverable — plain-language, with the **"cover, not condition"** caption carried through so "high cover" is never read as "healthy Country," and the unit framed as one point on a community relationship.

**Report nesting (design-seat note).** The site+paddock structure maps onto `plot_paddock`: **paddock report as parent, its member site reports as children.** Two consequences to confirm at the template stage: (i) a **0-plot paddock** report carries community context but has **no child site reports** — consistent with the graceful-degradation design; (ii) the **9 treed sites** have no dashboard and no veg×water cloud, so they get a **reduced report or none** — a decision to make here, not a silent gap (this is the same treed-exclusion gap flagged in Task D2). Confirm the parent/child file layout (nested directories vs a flat set with links) at the template stage.

**Gate 5 — registration.** Register all new dashboard/report figures additively in `figure_asset` (`run_id='taskL_...'`), non-destructive, before/after counts. This also continues closing the D4 registry gap (the pre-Gate-E 139 stale rows remain a separate reconciliation).

---

## Standing rules (inherit from CLAUDE.md)

- Additive-only; scratch to `Output/diagnostics/taskL_.../`; no `reset_file`; branch-and-PR with human merge (Hugh, TortoiseGit).
- Verify against data, not prose — print numbers where you assert a reconciliation.
- One concern per commit; no AI-authorship trailers.
- The unit marker must use the **same** floor/flood-frequency values the census reports for that unit — establish from the DB/census, not recomputed ad hoc.
- Grid ≠ farm; four-CRS discipline; do not re-open settled §10 decisions.
- If a unit has 0 plots, the panel shows community context + unit position ONLY — never fabricate plot data or a neighbourhood cloud that doesn't exist.
