# Task — restyle the Biodiversity / LOOC-B deck to the Gayini RS design language

**Repo:** Gayini Biodiversity / LOOC-B (open inside the Gayini project).
**Companion doc (read first):** `Gayini_presentation_design_system.md` — palette tokens,
slide grammar, vegetation grouping, DB drivers, guardrails. This spec assumes it.
**Workflow:** recon first → confirm plan → branch → build → stop at each gate → commit →
PR → merge on GitHub → `git pull --ff-only`. Change report at
`docs/change_reports/deck_restyle_<date>.md`. Commit code + small tables only, never rasters.

---

## Goal

Rebuild the 20-slide LOOC-B review deck so it reads as the same project as the RS deck:
RS palette + slide grammar, and biodiversity **group** products aggregated to the four RS
communities. Continuous maps are reframed only, not recomputed.

---

## Step 0 — Recon (no code yet)

1. `dbListTables()` on `OUTPUT/Gayini/database/Gayini_Biodiversity.sqlite`; confirm the
   objects in the companion doc §5 exist and match row counts.
2. List `OUTPUT/Gayini/maps_final/` and diff filenames against `final_map_index.map_path`.
   Expect a `_single.png` vs `_final.png` mismatch — record every path that needs syncing.
3. Read `Gayini_vegetation_crosswalk_biodiversity_to_main_groups.csv`. Confirm it stops at
   six broad groups (Woodlands / Forests separate).
   **Gate R:** report the map-path reconciliation list + the crosswalk state; wait before coding.

---

## Step 1 — Vegetation aggregation (the one data change)

Extend the crosswalk to a **4-community** map (companion doc §4):
Aeolian → gold · Riverine → teal · Inland Floodplain (Shrublands + Swamps) → blue ·
**Inland Floodplain Woodlands + Inland Riverine Forests → one grey "Woodland / Forest
(context, treed)"** · the three minor classes → appendix (excluded from main figures).

- Add a view `v_vegetation_community_summary` that aggregates `v_vegetation_type_summary`
  to these four communities (area-weighted means for condition / threatened species /
  persistence; summed areas). Keep the 9-class view intact.
- Do **not** recompute continuous rasters — aggregation is for charts + per-group tables only.

---

## Step 2 — Deck build

Use pptxgenjs (existing deck convention). Every slide: tokens + archetype from companion
doc §2–§3. Sentence case; no F-numbers / view names / paths on slides.

**Slide → archetype → data source**
| Slide | Archetype | Source |
|---|---|---|
| 1 Title | Title (deep teal) | — |
| 2 Executive summary | 4 tinted stat cards | `v_presentation_headlines` (both modes) |
| 3 Companion / evidence chain | Evidence-chain flow | — |
| 4 Ecological context | Bulleted context on cream | — |
| 5 Method & indicators | Indicator cards (tinted) | — |
| 6 Input areas | 2 stat cards | `run_metadata` / areas |
| 7 Monitoring headlines | Headline table | `v_presentation_headlines WHERE mode='monitoring'` |
| 8–11 Condition / change / threatened / persistence maps | Map | `final_map_index` (`used_in_deck`), polished PNGs |
| 12 Scenario headlines | Headline table | `... mode='planning'` |
| 13 Scenario maps | **One combined figure**, shared legend | 3 planning-change PNGs |
| 14 Grazing vs no grazing | Comparison (bars/table) | `v_treatment_collapsed_summary` |
| 15 Community grouping | Community bar chart | `v_vegetation_community_summary` (Step 1) |
| 16–17 Hydrology / ground-cover bridge | Bridge scatter, community-coloured | `rs_loocb_joined_plot_summary` (66) |
| 18 Can / cannot | Two tinted columns | — |
| 19 SQLite export | Technical → appendix or drop for community version | — |
| 20 Next steps | Bullets on cream | — |

**Gate A:** render slides 1, 2, 7, 8, 15, 17 first (one of each archetype) and stop for review
before building the rest.

---

## Step 3 — Maps

- Reframe polished PNGs with kicker + charcoal headline + fixed-scale legend + source footer.
  No recompute. Sync `final_map_index` paths to the `_single.png` filenames (Step 0 list).
- **Vegetation-groups context map** is the exception: recolouring to the 4-community palette
  needs the **class raster** (not yet packaged). Options: (a) re-render from the local class
  raster with the four-community palette; (b) leave the current broad-group map as context
  for now and flag. **Gate M:** confirm which before touching this map.

---

## Out of scope / open items
- No new attribution claims; keep every guardrail from companion doc §6.
- Class-raster packaging for the veg-groups recolour (registry item) — separate task.
- Final external cut (which slides ship to the community vs stay review-only) — Adrian / Nari Nari call.

## Deliverables
- Restyled `.pptx` (+ per-figure files, one-figure-one-slide).
- `v_vegetation_community_summary` view + reconciled `final_map_index` paths.
- Change report; figures manifest updated.
