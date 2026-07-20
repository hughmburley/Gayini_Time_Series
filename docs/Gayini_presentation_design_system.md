# Gayini presentation — design system & cross-repo context

**Purpose.** Durable context for any Claude / Claude Code session working on Gayini
presentation outputs, across both repos. It carries the presentation design language,
the canonical vegetation grouping, and the biodiversity data model so a fresh session
does not have to rediscover them. Keep this in the Gayini project and reference it from
task specs. Last updated 2026-07-14.

---

## 1. Two repos, one project

| Repo | Role | Audience |
|---|---|---|
| `hughmburley/Gayini_Time_Series` (RS main) | Spatially explicit inundation + ground-cover assessment, 1988–2023, figure-driven ladder F1–F9. **Source of truth for the design language.** | Adrian / Kingsford / Nari Nari → Gayini community |
| Gayini Biodiversity / LOOC-B repo | Companion "bonus" analysis: LOOC-B / HCAS modelled habitat context (2004–2020) + natural-regeneration scenario (2021–2045). | Same; framed as an extra for the Gayini farmers |

The biodiversity deck must read as the **same project** as the RS deck — same palette,
same slide grammar, same restraint in claims. It is a *companion*, not independent proof
(see §6).

---

## 2. The shared visual language (RS deck is canonical)

**Backgrounds**
- Title / section dividers: deep petrol-teal `#0F3947`, light text.
- Content pages: warm cream `#F8F7F2` (never cool white).

**Type & framing (every content slide)**
- Small-caps **kicker** in rust `#9C5B2E` (e.g. "Habitat condition · 2020").
- Charcoal **headline** `#26302E`, sentence case, one line where possible.
- **No solid coloured header bar** — the kicker + headline replace it.
- Footer line in muted `#8A8378` for source / caveat.
- One figure = one file = one slide. Insets never overlap captions.
- Plain language for the community: no F-numbers, view names, or file paths on slides.

**Core tokens**
| Token | Hex |
|---|---|
| Ink / dark surface | `#0F3947` |
| Page background | `#F8F7F2` |
| Headline text | `#26302E` |
| Body / muted text | `#5F6B67` / `#8A8378` |
| Kicker (rust) | `#9C5B2E` |
| Rule accent (gold) | `#C79A3B` |
| Gain (positive) | `#2E6B2E` |
| Decline (negative) | `#9A6B5A` |

**Community palette — used to *encode* which community a bar / card / region belongs to**
| Community | Deep (text) | Mark (fill) | Tint (card/bg) |
|---|---|---|---|
| Aeolian Chenopod | `#8A5F1E` | `#C79A3B` | `#F3EBDA` |
| Riverine Chenopod | `#2A6560` | `#3B8A8F` | `#E4EFEC` |
| Inland Floodplain | `#1B4E86` | `#2165AC` | `#EEF5FD` |
| Woodland / Forest (context) | `#565B57` | `#7C837E` | `#ECEBE6` |

**Habitat-condition map ramp (fixed 0–100, `brown_yellow_green_fixed_0_100`)**
`#8A5A2B → #C9A96A → #B7C57A → #6E9E4B → #2E6B2E`. Fixed scale so every map reads the
same and slides are directly comparable.

**Stat cards.** Lightly *tinted* panels (community tint or warm paper), big number in the
community deep colour, 1-line label. Not filled solid-teal boxes.

---

## 3. Slide archetypes (templated; reuse for the whole deck)

1. **Title** — deep-teal, kicker, headline, subhead, community colour chips + labels.
2. **Executive summary** — cream, kicker+headline, 4 tinted stat cards, 1-line takeaway.
3. **Evidence chain** — horizontal flow Hydrology → Ground cover → Biodiversity → Scenario (mirrors the RS "evidence hierarchy / flow" slides).
4. **Map** — kicker+headline, single map on cream, fixed-scale legend, source/caveat footer.
5. **Community chart** — bars coloured by community (the direct analogue of RS F4).
6. **Headline table** — cream, subtle rules, right-aligned change column, gain green / decline rust.
7. **Bridge scatter** — 66 plots, coloured by community, zero lines; the RS ↔ LOOC-B link.
8. **Can / cannot** — two tinted columns; the honesty slide.

Every remaining slide type (input areas, method/indicator cards, scenario headlines,
grazing-vs-no-grazing, next steps) is a variant of one of these — apply the same tokens,
no new design needed. The one open layout choice is scenario maps (3 panels): make it
**one combined figure with a shared legend**, not three images.

---

## 4. Canonical vegetation grouping (align biodiversity to RS)

RS uses **four communities**; the 4-class `simplified_vegetation_group` is canonical
(the legacy 5-class `vegetation_adrian_group` must never be used). Three communities are
the analytical focus; Woodland / Forest is treed **context** (grey), shown but excluded
from the analytical focus — exactly as in RS slide F4.

**9 biodiversity classes → 4 RS communities**
| Biodiversity class | RS community | Palette |
|---|---|---|
| Aeolian Chenopod Shrublands | Aeolian Chenopod | gold |
| Riverine Chenopod Shrublands | Riverine Chenopod | teal |
| Inland Floodplain Shrublands | Inland Floodplain | blue |
| Inland Floodplain Swamps | Inland Floodplain | blue |
| Inland Floodplain Woodlands | Woodland / Forest (context, treed) | grey |
| Inland Riverine Forests | Woodland / Forest (context, treed) | grey |
| Riverine Plain Grasslands | Other / minor → appendix | — |
| Riverine Sandhill Woodlands | Other / minor → appendix | — |
| Sand Plain Mulga Shrublands | Other / minor → appendix | — |

> Note: the existing `Gayini_vegetation_crosswalk_biodiversity_to_main_groups.csv` stops at
> **six** broad groups (keeps Woodlands and Forests separate). The RS-aligned scheme adds
> one collapse: **Woodlands + Forests → a single grey "Woodland / Forest (context)"**.
> Aggregation applies only to *group* products (bar charts, per-group tables, the
> vegetation-groups map). Continuous surfaces (habitat condition, threatened species,
> persistence) are pixel maps and are group-independent.

---

## 5. Biodiversity data model (SQLite drivers — never hardcode)

`Gayini_Biodiversity.sqlite` — 14 tables + 6 views. Rasters are **paths only** (files live
on disk). Slide-driving objects:

| Object | Feeds |
|---|---|
| `v_presentation_headlines` (8 rows) | Both headline tables (filter `mode = 'monitoring' / 'planning'`) |
| `monitoring_headline` / `planning_headline` | Same numbers, per-mode |
| `v_vegetation_type_summary` (9 rows) | Community chart + per-group tables → aggregate per §4 |
| `final_map_index` / `v_map_assets` (18) | Map slides: `map_path`, `legend_title`, `units`, `scale_min/max`, `palette_name`, `used_in_deck` |
| `plot_loocb_context` / `rs_loocb_joined_plot_summary` (66) | Bridge scatter (inundation change × veg/habitat change) |
| `output_manifest`, `run_metadata` | Provenance |

Verified headline values (monitoring 2004→2020 / planning 2021→2045):
- Effective habitat area 44,213 ha (+43) · scenario +306 ha
- Threatened species habitat 310,140 species·ha (−634) · scenario +2,089
- Plant persistence 229.6 (−1.35) · scenario +0.0015
- High-quality habitat 37,516 ha (−59); scenario mean condition 65.1 → 69.2 % (+4.1 ppt)

**Map files.** Polished single-panel PNGs and source .tif rasters live under
`D:\Github_repos\Gayini_Biodiversity\OUTPUT\Gayini` (`maps_final` / `rasters`). The 10
polished PNGs use a `..._single.png` suffix; `final_map_index` paths use `..._final.png` —
reconcile the index to the polished filenames. Recolouring the vegetation-groups map to
the 4-community palette needs the **class raster**, which is not yet packaged (open item:
"cataloguing class raster in asset registry").

---

## 6. Guardrails (carry into every biodiversity slide)

- **Companion, not proof.** LOOC-B / HCAS is *modelled* biodiversity context, read beside
  observed inundation and ground cover — not instead of them.
- **Not independent validation.** HCAS uses Landsat-derived variables (incl. fractional
  cover), so it cannot validate the RS fractional-cover outputs. Keep this caveat wherever
  LOOC-B sits beside Landsat-derived outputs.
- **Order of the story:** hydrology first, ground cover second, biodiversity context third.
- Small vegetation / inundation groups are not headlines → appendix.
- Trend language stays tempered ("no clear trend so far (provisional)"); pre/post language
  is fully retired.
