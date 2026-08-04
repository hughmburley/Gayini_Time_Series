# DOC-1 Gate D — substitution check

**Read-only.** 4 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · **nothing substituted.**
Searched: `figure_asset` (297 rows, 158 not superseded), `table_asset` (5 rows), and the figure manifest
committed at Gate C.

**Scope held.** Every candidate below serves a claim the document **already makes**. No new analysis, no new
figure, no new content is proposed. Where no alternative exists, that is stated in one line and left there.

**Result: one substitution worth making, one worth explicitly refusing, and two captions that already exist
in better form in the registry.**

---

## 1 · Figure 8 → `M1_veg_percentile_maps_p05_p50.png` — **the one substitution to make**

| | |
|---|---|
| **Claim served** | §7.4 / DOC1-124: *"Per-cell 5th-percentile total cover (left) and 50th-percentile total cover (right), across-series percentiles 1988–2023, on one shared 0–100 scale."* |
| **Currently** | `S_floor_and_typical_mapped.png`, extracted from `Gayini_Veg_samples_ALLPIXEL_v6_20260724.pptx` — **no `figure_asset` row by checksum or filename** (issues log D1-I4) |
| **Candidate** | `Output/figures/M1_veg_percentile_maps_p05_p50.png` — registered, `superseded_flag = 0`, path exists |

**Why it is better.** It is the same figure content — the registered caption reads *"Two-panel veg-percentile
map: p05 (the floor) and p50 (typical), one shared 0–100 cover scale. All-pixel census, EPSG:8058, 24.97 m.
Percentiles plotted as measured and never differenced"* — and it is **registered**, so it carries provenance,
a checksum and the §4.3 never-differenced qualifier the document states separately. The current figure is an
unregistered extract of a deck.

**One check before substituting, which I have not done and am not doing here.** The current filename says
`_mapped`; M1 is described as all-pixel census. If the current figure is drawn on the mapped extent
(1,080,157 cells) and M1 on a different footprint, the two are not interchangeable and the caption's scope
would need to follow. **Confirm the extent matches before swapping.** Flagging rather than choosing.

## 2 · Figure 6 — **an available substitution that should be refused**

`FigA_floor_gradient_density.png` is registered and draws the same relationship (veg floor against flood
frequency, with a GAM). It would look like a natural alternative to the percentile fan.

**Do not substitute it.** It is the second GAM figure from Gate C defect **M-1**, and it truncates with
`ff_cut <- max(supported)` — the last bin *anywhere* meeting 2,000 cells — not the cumulative rule §6.6
describes. Swapping it in would put a figure under a rule the document does not state, in the section that
was just corrected to state the rule precisely.

Recorded here so it is not proposed later by someone reading the registry without the code.

## 3 · Figure 7 (S26) — **no substitution; the figure already carries the fix the text needs**

The §7.3 contradiction found at Gate B — *"six of the eight measurable strata"* against five at census
support — did **not** come from a deficient figure. `21_build_s26_response_matrix_figure.R` draws **both
supports on purpose**: a filled marker for the census/pixel *r*, and a **hollow diamond explicitly labelled
"Plot-support r (reference)"**. Its own subtitle states *"Pixel support (census, 24.97 m)"*, and its caption
names the exact stratum that makes the difference:

> *"note Aeolian high (plots 'responds', census does not), and Aeolian low (a plot r exists where the
> per-pixel census is undefined — the plot-vs-pixel support difference)"*

**This is the best available figure for the claim, and no alternative improves on it.** `S24_response_singles`
is per-community and shows less; `S25_lag_profile` is plot support and answers a different question. The
error came from reading the figure without carrying its caption — which is the failure mode the caption was
written to prevent. **Keep the figure; the correction belongs in the text.**

## 4 · Figures 9 and 10 — no substitution, but **the better captions already exist in the registry**

Both are already the registered T3 artefacts (`T3_B2_green_share_map.png`, `T3_C_persistence_map.png`, both
`support_level = 'pixel'`, neither superseded). There is nothing better to swap in.

What the registry holds that the document does not is the **caption**:

- `T3_B2`'s registered caption carries the green-share **order-statistic** definition in full —
  *"k = max(1, ceiling(0.05·m)) of m valid paired seasons"* — where the document gives the definition in prose.
- `T3_C`'s registered caption opens *"NO HEADLINE THRESHOLD … refugial extent is a CONTINUUM and every cut
  here is a chosen one"*, with the measured elasticities.

That second one bears directly on Gate C defect **F-2** (the 500 ha drawn against 6,458 ha quoted). The
registered caption is the more careful text and it is already written. **In scope as a substitution of
caption, not of figure** — the document's captions could be replaced by the registered ones for these two.

## 5 · Where no registered alternative exists — named, not developed

- **Figure 2** (`C1_checkerboard_farm.png`, §3.1 stratification) — unregistered; no registered stratification figure found.
- **Figure 3** (`S_annual_wet_extent_flow.png`, §7.1) — unregistered; the only flow-related registered figure is `J-F3_the_law.png`, which is Task J's bank-cut flow law and a different object.
- **Figure 5** (`H6_absolute_flood_zones.png`, §7.1) — unregistered; **no registered absolute-zones figure exists at all**. This is the load-bearing one: §3.1 and §7.1 both cite it as the comparable alternative to the within-community terciles.

Three gaps, named. Not developed.

---

## Two structural observations

**`table_asset` holds 5 rows.** Against 297 figures. The "does a better registered *table* exist" half of
this gate has almost no search space — the four candidates are the T13 classification, the T1 paddock
comparison, and two RPT-SCOPE audit tables, all already serving their own sections. Tables are not registered
in this project at anything like the rate figures are, so the absence of table substitutions is a property of
the registry, not a finding about the document.

**139 of 297 `figure_asset` rows are superseded.** All candidates above were filtered to
`superseded_flag = 0`. Worth knowing that a naive registry search returns a nearly 50% superseded rate.

## Counts

**Claims examined for a better-suited registered artefact: the 25 figure claims plus the section claims they
support.** One substitution recommended (Figure 8), one explicitly refused (Figure 6), one confirmed
already-best (Figure 7), two caption substitutions available (Figures 9, 10), three gaps with no alternative
(Figures 2, 3, 5). **Nothing was substituted.**
