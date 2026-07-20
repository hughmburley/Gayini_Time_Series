# Claude Code task — dashboards (paddock · site · stratum), 3 layouts, trial → production

**Goal.** Build the Gayini dashboards, evolving the old `GA_###` design: **drop pre/post entirely**, add a **map** panel, a **baseline gauge**, and an **F4-style "where it sits" boxplot**. **Trial three layouts** on a small subset, review, then **produce the chosen layout(s)** for all units. Three unit types: **paddock**, **site** (radius neighbourhood), **stratum** (community × wetness).

## Reuse principle (do first)
One **dashboard composer** with **modular panel functions** — do not hand-build each figure. Reuse:
- `gayini_plot_area_map()` (from C1) for every map panel.
- the **F4 by-community boxplot** for the "where it sits" panel.
- the **F7 response** logic for the vegetation panel.

## Conventions
- EPSG:8058. **No pre/post anywhere** — no dashed 2019 line, no `drier_post`/`GC interpretation set` label, no pre/post boxplot.
- Flood frequency = wet ÷ valid years (headline); within-year occurrence % = secondary. Label distinctly.
- **Trend language is provisional** (per the census: wet-end strata are thinly sampled) — "no trend detected so far", never a settled "no trend".
- Bands are **within-community relative and OVERLAP across communities** — cross-unit comparison uses **absolute** flood frequency, never band label.
- Register every figure in `figures_manifest.csv`; `*_qa.json` per figure; one-line deck-slide mapping.

## Panels (modular; a layout is an arrangement of these)
1. **Map** — unit-specific (see sets).
2. **Annual flooding, 1988–2023** — unit aggregate, line + 35-yr mean, **no transition line**.
3. **Total vegetation** — unit ground-cover series.
4. **Vegetation response** — ground cover vs wet-extent intensity; the unit's plots + the community-level fit as context; **state the plot count**.
5. **Baseline gauge** — recent window vs the unit's own long-run average → wetter / same / drier; labelled **snapshot, not trend**.
6. **"Where it sits" boxplot** — F4-style: flood frequency (and optionally total vegetation) boxed **by community** (3 focus, dry→wet + Woodland context), **this unit's value(s) highlighted**. Caption may carry a Kruskal–Wallis across communities as **descriptive** context. This replaces the old pre/post boxplot.

## Layouts (build all three for the trial)
- **A · map-led** — map hero + stacked series + gauge. (paddock default)
- **B · evolved-classic** — stacked series spine (gauge / flooding / vegetation) + right rail holding the map, baseline gauge, and the boxplot. Familiar to Adrian, minus pre/post. (site default)
- **C · card-grid** — 2×N equal tiles; cleanest, scales best to A3.

## Unit sets
- **D1 · paddock (21):** map = the F5f checkerboard / flood-frequency zoom; flooding = the paddock's valid pixels; vegetation response limited by in-paddock plots → fall back to community context and say so.
- **D2 · site (66):** map = flood-frequency centred on the plot with the **radius ring drawn** (radius default = the F5 sampling-neighbourhood radius, **parameterised** ~500 m–2 km; include the footprint since descriptive); add **gauge flow context** (background); RS inundation = the **neighbourhood**; vegetation = the plot itself; baseline gauge; boxplot places the site in its community.
- **D3 · stratum (9 focus; context optional):** map = the checkerboard with **this class highlighted, others muted**; flooding = the stratum's sample-point aggregate; **trend = the F6 verdict for this stratum (provisional wording)**; vegetation = the stratum's 3–8 plots + community fit (flag small-n); boxplot = this stratum vs the others.

## Formats
- `slide` (default, deck aspect) and an **`a3` poster preset** (297×420 mm portrait or 420×297 landscape, ~300 dpi, scaled type/margins). Same panels; layout C scales to A3 best.

## Phase 1 — trial (build the composer + all 3 layouts on a subset)
- Paddocks: **Bala 28ca, Bala 29ca, Dinan 8, Dinan 10**.
- Sites: **GA_001, GA_003** (benchmark vs the old dashboards), **GA_019** (Inland/wet), **GA_052** (Riverine/mid), **GA_032** (Aeolian/dry).
- Strata: **Aeolian · low**, **Riverine · mid**, **Inland Floodplain · high** (span dry/mid/wet).
- Output each in layouts A, B, C (slide format), plus one A3 example, for review. **Then pick a layout per set.**

## Phase 2 — production (after the layout choice)
Chosen layout(s) for **all** paddocks (21), sites (66), strata (9), in `slide`; A3 for the agreed display set.

## Priority & done
Composer + panel fns → **D2 site trial** (closest to the old design) → D1 paddock trial → D3 stratum trial → review → production. **Done** = trial figures generated in all three layouts + registered; QA passes (no pre/post artefacts; site neighbourhood pixels within R; plot counts stated; provisional trend wording; boxplot compares on absolute frequency); deck-slide mapping noted.
