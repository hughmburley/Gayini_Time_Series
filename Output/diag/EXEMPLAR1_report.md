# EXEMPLAR-1 — example units for the client, and the checks behind them

**As of 8 August 2026.** Built to `docs/reference_update/Gayini_CC_spec_EXEMPLAR1.md`
under Rulings BE, BL, BM, BV, BW, BX, BY, BZ.

**Nine figures registered, all with support and figure level populated.** `figure_asset` stands at 317 rather than the 314 nine rows would imply: another session registered figures concurrently while this ran, so the delta is not mine to claim. Nothing else here was registered, no existing figure was re-rendered, and `Output/pack/**` was untouched.

---

## 1 · Gate 0 — what already existed, and why it was not enough

The D1 paddock and D2 site dashboards are already the client's shape: cover above,
water below, one shared x-axis, plus a locator map. **78 of them are registered.**

**But in D1 the two panels describe different ground.** The cover trace is the mean of
the 1-ha monitoring plots inside the paddock (`v_plot_timeseries_groundcover`, plot
support); the water trace is the whole polygon (native EPSG:28355 stack, pixel support).
For Bala 29ca that is a handful of hectares against roughly 16,000, sharing one axis and
inviting the reader to treat them as one place. `support_level` is NULL on all 78 rows,
so nothing on the artefact says otherwise.

**Ruling BW accepted this and superseded the extraction branch of the spec.** The
exemplars are built from `Output/tables/PARTREG_part_year_floor_inund.csv` instead —
115 parts × 35 years, cover and water from the *same cells*, pixel support throughout.

## 2 · Ruling BE — label defect, not value defect

BL held 81 PNGs and 81 PDFs unrendered unless BE returned a value defect. **It did not.**

| | Bala 26ca | Bala 28ca | Bala 29ca |
|---|---:|---:|---:|
| valid pixels per year | 33,033 | 25,086 | 38,825 |
| identical in all 35 years | yes | yes | yes |
| mean of the 35 annual values | 45.30% | 47.50% | 10.32% |
| long-run Σwet ÷ Σvalid | 45.30% | 47.50% | 10.32% |
| response marker: pixel set | none — **plot support** | none | none |
| plots in unit | 3 | 8 | 13 |
| **plots the marker draws** | **3** | **6** | **1** |
| community shown (area-dominant) | Inland | Inland | Inland |
| share on shown community | 98.1% non-treed / 98.1% all | 83.1% / 72.9% | 34.6% / **32.7%** |

**Σvalid is constant across all 35 years**, which follows from `annual_valid_any` holding
only 1 and 255. Because the denominator never varies, the mean of the annual line and
the long-run frequency **coincide exactly** — the identity is not an approximation here.
No plotted value is wrong. **BL stands; nothing was re-rendered.**

**The scope difference is severe at Bala 29ca**: the dashboard shows Inland (the
area-dominant community, 32.7% of the paddock) and only **1 of the paddock's 13 plots**
is Inland, so the vegetation-response marker for the most-studied paddock rests on a
single plot. Not a value defect. Worth knowing before anyone reads inference into it.

> **A correction to my own first pass.** I initially computed the shown community as the
> *modal community of the unit's plots*, which for Bala 29ca gives Aeolian. The dashboard
> uses `gayini_paddock_community_shares()` — **area-dominant** — which gives Inland. The
> two rules disagree for that paddock, and the script now records both plus both
> denominators, so a bare percentage cannot be misread again.

**Ruling BM was already applied** at `gayini_dashboard_panels.R:137–170` and
`gayini_dashboard_compose.R:117–123` by another session before I reached it. I did not
duplicate it. Their reconciliation (10.32 whole-unit against 15.92 shown-community) and
my share figures now agree at 32.7% of all cells.

## 3 · Gate 2 — the nine units

Eligibility: **≥ 500 cells**, so an exemplar is a real place rather than 33 cells
(100 of 115 parts qualify). Within each community: driest, middle, wettest by
across-year mean wetness.

| community | role | unit | area | water | cover |
|---|---|---|---:|---:|---:|
| Aeolian | driest | Dinan 3 | 151 ha | 1.0% | 73.6% |
| Aeolian | middle | Dinan 1 | 75 ha | 2.5% | 67.5% |
| Aeolian | wettest | Dinan 9 | 357 ha | 11.9% | 70.1% |
| Riverine | driest | Bala 2 | 122 ha | 3.0% | 72.6% |
| Riverine | middle | Dinan 3 | 167 ha | 13.5% | 63.5% |
| Riverine | wettest | Mara 21 | 204 ha | 33.3% | 79.8% |
| Inland | driest | Dinan 10 | 235 ha | 5.9% | 69.1% |
| Inland | middle | Mara 15 | 1,035 ha | 30.9% | 82.6% |
| Inland | wettest | Bala 22 | 328 ha | 58.9% | 88.8% |

**Dinan 3 appears twice** — its Aeolian country at 1.0% wet and its Riverine country at
13.5%. One paddock, two regimes. That is L-01 made visible rather than argued, and it is
the clearest available demonstration that the fence is not the unit.

Full provenance per unit, with no NULLs, in `Output/tables/EXEMPLAR1_units.csv`: support level, scope filter, pixel constant, denominator, period label. **That path is gitignored**, so the table is reproducible but not version-controlled; if it needs citing the way DIAG-1's tables do under Ruling BB, it needs its own un-ignore line.

## 4 · Gate 1 — what the figures say

Cover is **`veg_p50_spatial`** (Ruling BX) — the floor does not appear. Water is
**`inund_pct`** (Ruling BY). Units are named for a lay reader (Ruling BZ): *the Inland
Floodplain country in Bala 22*. No metric slugs, no `fit_id`, no version stamps.

**Ruling CM applied, and Ruling CE withdrawn — no second cover line.** Three changes:

- **The water series left the community palette.** It was `#2E6DB0`, which *is* Inland
  Floodplain's mid-band colour, so on an Inland figure one blue carried both a community
  identity and a water quantity. It is now `#5B6E7C`, a desaturated slate — all three
  community hues are saturated, so desaturation is what separates a quantity from an
  identity. **Checked rather than eyeballed:** the producer asserts a minimum RGB
  distance to all 11 class colours and halts below 40. Measured **59.7** (nearest
  `#27725F`), and 46.6 to the three cover-line colours.
- **A one-line locator**, computed from each part's centroid against the property's own
  bounding box rather than typed: *"151 hectares within Dinan 3, in the north-west of
  Gayini"*.
- **Years with no detected water are drawn as an explicit zero** — a tick on the
  baseline — because a zero-height bar draws nothing and is indistinguishable from a
  missing year, which for the driest units is most of the record. The caption states the
  count either way.

The contrast the client asked for is stark. **Bala 22's Inland country holds ~89% cover
through everything while water swings 0–100%. Dinan 3's Aeolian country swings 31–90%,
collapsing in the 2008 drought, on essentially no flooding at all.** Wet country is
buffered; dry country tracks the drought.

> **A rendering defect caught and fixed.** The first render used
> `scale_x_continuous(limits =)`, which **drops** data rather than zooming: the 1988 and
> 2022 bars extended past the limits and were silently deleted — 2 of 35 years missing
> from every water panel. `coord_cartesian()` instead. Every checksum changed, which is
> how the fix was confirmed to have taken.

## 5 · Gate 3 — the design-seat predictions, checked

Spec §1 says these are predictions and that independently computed values take
precedence. **The finding reproduces; the exact numbers do not.**

**Confirmed exactly.** The census footprint is 988,831 cells (and `treed_context_flag = 0`
alone gives 993,782 — the ten-strata trap, live). All four rasters share one grid.
**Ruling BT reproduces precisely: `MIN_SEASONS = 50` removes 2 cells of 988,831.** Their
flood frequencies are 90.2% and 95.4% — so the mechanism is real and the extent
negligible, though the spec's "both sit above 95%" is true of only one of them.

**Correlations.** r(p50, water) = **0.566**, exactly as predicted. r(p05, water) =
**0.6811** against 0.676 — a 0.005 miss, just outside tolerance.

**The direction and magnitude hold under both binning rules**: Inland's floor rises
further than its median, and the median-minus-floor gap narrows with water. That is the
substance of the client's step 3 and it does not depend on the binning.

**The endpoints do not reproduce under either rule**, and the rule matters:

| | p05 dry → wet | p50 dry → wet | gap dry → wet |
|---|---|---|---|
| design-seat prediction | 37.9 → 77.1 | 74.3 → 88.7 | 36.4 → 11.3 |
| deciles of flood frequency | **40.1 → 75.0** | 75.1 → 87.6 | 35.0 → 12.7 |
| fixed 10-point bins | 45.2 → 78.4 | 76.7 → 90.8 | 31.5 → 12.4 |

Deciles are much closer, so the design seat used a quantile-type rule, but nothing
reproduces within 0.5. **Aeolian's cell count above 50% flood frequency is 490, not 511**
(identical under `>` and `>=`), which points at a scope difference rather than a
threshold one.

**Aeolian is non-monotone, as predicted** — but its peak sits later than "roughly 35%",
and its support is thin enough that the wettest bins carry 43 to 375 cells.

## 6 · Outputs

| file | what |
|---|---|
| `Output/figures/exemplars/EX1_*.png` | the nine figures, all registered |
| `Output/tables/EXEMPLAR1_units.csv` | the selection with full provenance, no NULLs |
| `Output/diag/BE_dashboard_scope_check.csv` | Ruling BE |
| `Output/diag/EX1_gate3_community_by_floodbin.csv` | 56 rows, both binnings |
| `Output/diag/EX1_gate3_checks.csv` | 19 checks with targets and tolerances |
| `Output/diag/analysis/EX1_gate3_census_cells.csv.gz` | 988,831 cells |

**Producers.** `scripts/12_zone_stratum/BE_dashboard_scope_check.R` ·
`scripts/12_zone_stratum/EXEMPLAR1_build.R` · `scripts/14_diag/EX1_gate3_extract.py`
(preparation only) → `R/diag/EX1_gate3_check.R` (all statistics).

**TEMPORAL-1 was not duplicated.** Gate 3 uses the existing seasonal-basis rasters, the
same ones the design seat used, and says so on every output row. The annual-basis series
remains TEMPORAL-1's.
