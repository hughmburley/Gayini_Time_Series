# Gayini remote sensing — Tier 0 complete: handoff to Tier 1

**Date:** 7 July 2026
**Repo:** `hughmburley/Gayini_Time_Series` (branch `main`, Tier 0 + 0.4 merged)
**Purpose of this doc:** carry the state of the project into the Tier 1 chat, so the
within-plot inundation→vegetation modelling can start from a known, trustworthy foundation
without re-deriving any of the Tier 0 work.

---

## 1. The one-paragraph orientation

This project is repositioning the Gayini (Nari Nari Country, Lowbidgee floodplain, Murray–
Darling Basin) remote-sensing analysis **away from a 2019 pre/post design and toward a
spatially explicit, annual time-series analysis** across 1988–2023. The pre/post design was
dropped because the management-change date is uncertain, and because the data showed the
pre/post estimator was throwing the signal away (see §5). Tier 0 built and verified the
**annual foundation**: a unified inundation raster stack, resolved metadata, a modelling-ready
database view, and a confirmed wet-rule. Tier 0 is now complete and merged. Tier 1 is the
science this foundation was built to enable.

---

## 2. What Tier 0 delivered (all on `main`, verified)

**0.1 — Unified annual inundation stack (1988–2023).** One continuous per-year wet/valid
raster stack, built directly from the 35 canonical `lo_YYYY_YYYY.img` source rasters (not the
older overlapping background windows). Single CRS **EPSG:28355 (GDA94/MGA zone 55)**, 25 m
grid, water year 1 Jul–30 Jun. 35 layers each, no gaps. Verified: recomputed wet-cell counts
match the manifest exactly for all 35 years.
- `Output/rasters/inundation_annual_stack/annual_wet_any_1988_2023.tif` (35 layers)
- `Output/rasters/inundation_annual_stack/annual_valid_any_1988_2023.tif` (35 layers)
- `Output/csv/annual_stack_manifest.csv` (per-year source, CRS, resample, wet/valid counts,
  mean occurrence %)
- `Output/csv/annual_stack_crosscheck.csv` (vs the old background rasters)

**0.2 — Raster metadata resolved.** CRS/extent populated for all 100 `raster_asset` rows
(0 null CRS), `metric_id` parser added, ~100% metric_id coverage. Legend-confirmation sheet
generated for Adrian.

**0.3 — Modelling-ready spine view.** `v_plot_year_analysis_spine` in the SQLite DB — **this
is the table Tier 1 reads from.** One row per plot × water year, **2,310 rows (66 plots × 35
years)**, verified. Columns:
```
plot_id, water_year,
annual_occurrence_pct, annual_valid_coverage_pct, annual_wet_any, annual_valid_any,
mean_total_veg_pct, mean_pv_pct, mean_npv_pct, mean_bare_ground_pct,
simplified_vegetation_group, treed_plot_flag, ground_cover_exclusion_flag, spatial_review_flag
```
Ground-cover join coverage: 99.8%. Occurrence values in [0,100], no wet-without-valid.

**0.4 — Wet-rule confirmed and documented (Adrian's ruling).** See §3 — this is the most
important interpretive decision and it's now locked.

---

## 3. The wet-rule (CONFIRMED — do not re-litigate)

The NSW DCCEEW inundation rasters use a four-class legend (confirmed from NSW SEED metadata
and verified in the source data):

| Value | Meaning | Classification |
|------:|---------|----------------|
| 0 | not inundated | dry (valid observation) |
| 1 | inundated | **WET** |
| 2 | off-river storage (ORS / irrigation) | **WET** |
| 3 | cloud shadow | **MASK** (neither wet nor valid) |

**Adrian ruled (7 Jul 2026): off-river storage counts as wet, same as inundation** — *"those
pixels were wet just the same."* Cloud shadow is masked.

Formal rule (`gayini_make_binary_inundation_layers()`): `wet = value IN (1,2)`,
`valid = value IN (0,1,2)`, value 3 + no-data excluded.

Notes for Tier 1:
- The 35 Landsat sources contain **{0,1,2} only** (no cloud shadow), so the mask is currently
  a no-op; occurrence numbers are as built.
- **`annual_occurrence_pct` in the spine view already reflects this rule** — nothing to adjust.
- Durable record: `docs/tier0_legend_decision_record.md`.

---

## 4. The dataset Tier 1 will model (from `v_plot_year_analysis_spine`)

- **66 plots × 35 water years = 2,310 plot-years.** 1988–2023 inundation; ground cover
  1987–2026.
- **Vegetation groups (plots):** Inland Floodplain Shrublands / Swamps = 22 · Riverine
  Chenopod Shrublands = 19 · Aeolian Chenopod Shrublands = 16 · Floodplain Woodland / Forest
  = 9.
- **Treed plots:** 9 flagged (`treed_plot_flag = 1`); 57 non-treed used for ground-cover
  interpretation.
- **Inundation range across years:** driest 2006-07 (0.4% occurrence, Millennium Drought
  trough) → wettest 2022-23 (42.1%, major flood). Big wet years: 2010-11 (29%), 2016-17
  (33%), 2021-22 (21%), 2022-23 (42%). Ecologically coherent — a good sanity signal the
  extraction is behaving.
- **Duration constraint (important):** annual *occurrence* has the full 35-year record.
  Daily/MER (duration/hydroperiod-type metrics) exist **only for 2014–2025** (Sentinel era).
  So long-baseline claims rest on occurrence; duration is a recent-era supplement, not a
  35-year metric.

---

## 5. Why Tier 1 matters — the finding that reframes the paper

Reproduced directly from the database during the review:

- **Cross-plot pre/post** correlation (one Δinundation and one Δvegetation per plot, across 66
  plots) = **r ≈ 0.21** — the "no real relationship" the review deck honestly reported.
- **Within-plot annual** correlation (annual occurrence vs annual total vegetation, within
  each plot) = **positive for all 61 non-degenerate plots** (mean 0.32, up to 0.70), and
  strongest exactly where ecology predicts: Inland Floodplain Shrublands/Swamps (0.39) and
  Floodplain Woodland (0.37), weakest in dry Aeolian Chenopod (0.22).

**Interpretation:** the pre/post design wasn't measuring a weak signal — it was the wrong
estimator. Collapsing 35 years into two numbers per plot averaged the signal away. The annual
time series recovers a coherent, community-structured inundation→vegetation relationship. That
is the analytical backbone of the new paper, and it's what Tier 1 formalises.

---

## 6. Tier 1 — the task to design next (the actual science)

**Task 1.2 (the headline): within-plot, community-stratified inundation→ground-cover model.**
Mixed-effects model of total vegetation ~ inundation occurrence, with plots grouped by
vegetation community. This is the conceptual heart and should be **designed in chat before it
becomes a Claude Code task.** Three open design questions to resolve:

1. **Lag structure** — same-year vs 1–2 year lagged vegetation response to inundation?
   (Flood-pulse literature suggests some lag; the annual data can test it.)
2. **Random-effects specification** — random slope by plot; is vegetation community a grouping
   factor, a fixed interaction, or both?
3. **The persistently dry plots** — the ~zero-inundation Aeolian/dry-edge plots: how to
   include them so they *inform* the community slopes rather than distort them (they're
   ecologically real, not noise).

**Also in Tier 1 (design after 1.2):** Task 1.1 — per-pixel trend & rolling-frequency surfaces
on the unified stack (Theil–Sen / linear slope + 5-yr rolling occurrence), the mapped "where
has inundation changed" result that replaces the pre/post maps.

Full tier ranking (2 landscape stratification, 3 response/duration) is in the review doc
`Gayini_RS_review_and_task_ranking.docx` if needed.

---

## 7. Open items carried forward (not blocking Tier 1)

- **Sentinel-2 legend** — `sentinel2_inundation` still flagged `needs_legend_check`. Confirm
  with Adrian before Tier 3; don't assume the Landsat ruling transfers (though it likely does).
- **Metadata-survival hardening** (`hardening-raster-metadata-survives-rebuild`) — the
  catalogue/`raster_asset` CRS + legend writes are post-build mutations a full DB rebuild
  wipes. Durable truth lives in `docs/tier0_legend_decision_record.md`. Low priority.
- **Spatial review flags** (DB `qa_check` rows with status REVIEW): six plots carry
  vegetation-overlay / boundary / area flags (GA_006, GA_007, GA_016, GA_022, GA_029, GA_066),
  plus mixed-CRS-reprojected and repaired-geometry notes. Confirm with NNTC before
  area-weighted or community-stratified summaries. Relevant to Task 1.2 stratification.
- **MER** treated as its own `mer_inundation` family (separate lineage, not confirmed here);
  ties to the deck's "rename MER" decision. Tier 2/3.
- **Cross-cutting decisions** still open for the client-facing version: water-year definition,
  gauge anchor, treed-plot handling in final figures. None block Tier 1.

---

## 8. Working conventions established (carry into Tier 1)

- **Foundation-first, verified.** Every coding step ends with a runnable **acceptance gate**
  (assertions that must pass before commit) and a **change report** in `docs/change_reports/`.
- **Conceptual work in chat, execution in Claude Code.** Design the model spec here; hand a
  tight, gated task file to Claude Code to implement.
- **Git workflow (solo, fast):** Claude Code commits + pushes; PRs opened via GitHub compare
  link, merged on GitHub, then local main fast-forwarded (`git pull --ff-only`). Commit code +
  small docs only; rasters/DB gitignored. Co-author attribution suppressed.
- **The spine view is the single source of truth for modelling** — read from
  `v_plot_year_analysis_spine`, don't re-join raw tables ad hoc.
