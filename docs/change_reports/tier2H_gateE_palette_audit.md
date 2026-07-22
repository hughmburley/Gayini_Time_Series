# Change report — Gate E palette audit: the deck's community palette

*Tier 2 · Task H · Gate E. 2026-07-21. Corrects a palette claim in the Gate E task
spec (§F) and settles which community palette is canonical for the deck.*

## Finding

The Gate E figure-style spec (§F of `Tier2_TaskH_gateE_figure_build.md`) recommended
the **"biodiversity-config"** community hues — Aeolian `#C79A3B`, Riverine `#3B8A8F`,
Inland `#2165AC` — and asserted they are "the one committed in code."

**That is wrong against disk.** A grep for `#3B8A8F` / `#2165AC` / `#C79A3B` across all
`.R` returns **nothing** — the biodiversity-config palette is **not committed anywhere**.

What *is* committed are **two** community palettes, and they differ:

| Community | ① C1 checkerboard `gayini_veg_regime_classes()` (mid band) | ② F7 gradient `gayini_gradient_palette()` |
|---|---|---|
| Aeolian | `#C79A3C` | `#C2A25A` |
| Riverine | `#3FAE97` | `#5AB4AC` |
| Inland | `#2E6DB0` | `#2166AC` |

① drives the C1 checkerboard map and the flood-zone raster; ② drives the F7 response
figures. Aeolian and Riverine differ visibly between them; Inland is nearly the same blue.

## Decision (Hugh, 2026-07-21)

**Canonical community palette = ① the C1 checkerboard set** (`gayini_veg_regime_classes()`
mid band: Aeolian `#C79A3C` · Riverine `#3FAE97` · Inland `#2E6DB0`). §F names the C1
checkerboard as the consistency target, it drives the map figures Adrian/Nari Nari see
most, and it is committed.

All Gate E deck figures (S12/S21/S24/S25/S26, the veg-water scatters, the percentile fan)
source the hue from `gayini_veg_regime_classes()` — never hardcoded. Fig A stays **viridis**
deliberately (the appendix/"read as data" signature; not community-coloured).

## Residual actions (not code)

- **§F wording** in the task spec is stale ("biodiversity-config … the one committed") —
  correct to: *docs cited an uncommitted palette; canonical = the C1 checkerboard set.*
- The **F7-gradient palette (②)** remains committed and in use by the older F7 figures. It is
  a *second* committed set — a future pass may repoint the F7 figures onto ① for one deck
  palette, but that is out of Gate E scope.
- Nothing to "fix" in the checkerboard palette itself — it is correct and now canonical.
