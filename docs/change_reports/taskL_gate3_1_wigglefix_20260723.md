# Task L · Gate 3.1 — own-cloud wiggle fix (density-only) + p05 confirmation

**Date:** 2026-07-23 · **Branch:** `tier2L-gate3-rollout` (continued, off `main`) · **Spec:** v11.
**Status:** own-clouds re-rendered after the fix; established-facts + findings-log updated. Reviewed and committed with the Task L branch. No registration (Gate 5, separate). No AI-authorship trailers.

## Decision (i) — wiggle fix: DENSITY-ONLY when no bin clears 500 (applied now)
The own-clouds are the paddock report centrepieces; a fabricated oscillation cannot ship. The old cutoff logic **inverted the safeguard** — when *no* flood-freq bin reached the 500-pixel floor it fit the k=10 GAM across the **whole** range (worst support → most fitting).

**Audit first (read-only) — Mara 7 was not alone. 4 of 20 own-clouds had such a line (5 lines total),** all secondary-community lines with ≥500 px total but 0 bins ≥500:

| Paddock | ELSE-branch line(s) |
|---|---|
| Bala 26ca | Riverine (636 px, max bin 167) |
| Dinan 6 | Riverine (811 px, max bin 192) |
| Mara 7 | Riverine (686 px, max bin 282) |
| Mara 8 | Inland (658 px, max bin 149) · Riverine (1,232 px, max bin 437) |

**Fix** (`R/gayini_veg_water_census_panels.R`, `gayini_fit_community_gam`): if no bin clears `MIN_BIN_N`, **return NULL → the caller draws density only** (was: fit the full range). Full communities always have ≥500 low-flood bins, so **the dashboard community clouds/marker lines are unaffected — only these thin within-paddock own-cloud subsets change.** Verified: Mara 7 Riverine and Mara 8 Inland+Riverine are now density-only (each caption states "N communit(y/ies) shown as density only"); dominant lines (Inland / Aeolian) unchanged. Also fixed the density-only note pluralization ("2 community" → "2 communities").

**Re-rendered:** all **20 own-clouds** (the 16 unaffected render identically). Dashboards NOT re-rendered (community clouds never hit the ELSE branch). Mara 13 still deferred.

## Decision (ii) — p05 CONFIRMED as the shipping headline (evidence-based)
The percentile diagnostic backs it: the flood→floor response is largest at p05 (Inland dynamic range ~40 pp) and compresses toward the median (~27 pp at p20). Logged as evidence, not assumption. Metric unchanged.

## Promoted finding → `docs/Gayini_established_data_facts.md` §9
The **community FLOOR ordering is Inland ≫ {Aeolian ≈ Riverine}, not a clean dry<mid<wet** — a correction to a project-level belief, so it's recorded in the facts doc (not just the figure log), flagged as a Task L finding, with the p05/p10/p20 table and the note that the dry-vs-mid distinction is in **exposure** (flood freq 6.08/12.91/27.99 pixel · 9/22/50 plot), not floor level. Includes the p05-headline rationale.

## Findings log updated
`docs/Gayini_taskL_figure_observations.md` — Mara 7's "pending" line **replaced** with the resolved outcome (density-only fix; 4/20 own-clouds affected).

## Files touched (uncommitted)
- **M** `R/gayini_veg_water_census_panels.R` (density-only fix + plural note).
- **M** `docs/Gayini_established_data_facts.md` (§9 ordering finding), `docs/Gayini_taskL_figure_observations.md` (Mara 7 resolved).
- **New** this change report. 20 own-cloud PNGs refreshed (gitignored `Output/`).

## Not done here
- Gate 4 reports · Gate 5 registration · whole-farm 2-D key relocation (flagged).
