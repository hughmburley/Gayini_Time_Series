# Gayini per-unit reports — template specification

**Status:** authoritative. The builder in `scripts/15_reports/` implements this.
**Rule:** the template is the specification. Changes come from the design seat, not from a build
session.

## The template is the specification

**Do not redesign it.** Three things look like cruft and are load-bearing:

1. **Every table needs `TableLayoutType.FIXED`** and a grid summing exactly to the table width.
   Word applies autofit otherwise and collapses the figure column. Invisible in LibreOffice, so it
   will pass your render check and fail on Hugh's screen.
2. **Image paragraphs must carry no line-spacing rule.** A `spacing.line` value clamps the line box
   and renders every picture at roughly a third of its declared height while the XML extent stays
   correct. Symptom: pages look two-thirds empty and content spills to phantom pages.
3. **Never save a matplotlib figure with `bbox_inches='tight'`.** It changes the output aspect
   ratio, so the width→height calculation in `img()` no longer matches and axis labels clip.

**Page fill — R-1, 4 August 2026. Supersedes the 70–90% band.**

Measured against non-white pixels: the figure canvas is warm cream, and a dark-ink threshold
reads it as an empty page.

| | |
|---|---|
| **above 92%** | **ERROR — fails the build.** Word spills content to a phantom page |
| 70–92% | not reported |
| **below 70%** | **WARN — never fails the build.** Dead space is a design observation, not a defect |

Only the upper bound has a failure mode behind it. The band was previously stated three
different ways — 70–90% here, 80–92% in `check_page_fill.py`, 68–93% in the design seat's
in-session QA — and the claim that all 32 documents sat inside it held under none of them. No
page of any build has exceeded 92%. Full reasoning in the handoff §7; both directions proven by
`tests/test_page_fill_fires.py`.

### Page model

| page | paddock report |
|---|---|
| 1 | title · in plain terms · country it covers · the water · band table · map · summary cards |
| 2 | the 35-year record — flood extent and cover · reading notes · year cards |
| 3 | **the parts**, each against its own community · part table · what this changes |
| 4 | how it compares — expectation and residual · annual gap series · the conserved set |
| 5 | monitoring sites — 3-panel figure · what we don't know · site table · footer |

Site report is 2 pages. Single-community paddocks drop page 3 and run to 4.

### Degradation — all query-driven, no per-paddock exceptions

| case | behaviour |
|---|---|
| 1 community | no parts page; the single part's registered state moves to page 1 as prose |
| 2–3 communities | parts figure and table scale to the row count |
| ≥8 sites | sites figure and table scale; the reading note is suppressed |
| no sites | figure and table replaced by what the satellite still supports, plus the standard-grazing structural exclusion |
| no C1 render | locator map from `management_zones`; if that is degenerate, the composition figure |
| no D2 render | site flood-record figure from the plot spine |

### Content rules the reports inherit

- `veg_p05_spatial` only. Reaching for `census_by_zone_stratum.veg_p05_mean` for a reference-state
  purpose is a **STOP**, not a judgement call.
- The word *floor* is never used bare in client text — two different objects carry that name, and
  they differ by up to 17 pp at part grain in opposite directions by community.
- No p-values anywhere. No period-boundary statistics.
- Support levels never merged in one figure.
- The two flood rules differ and both are correct; every report says so. Keep that sentence.
- DEA cultivation calls never appear, at any confidence level (T12 §2.8).
- **A caption must never promise something the figure did not draw.** `figs_meta.json` records what
  each map actually rendered and the builder captions from it. This was a live bug: the locator
  caption read *"White squares are the monitoring sites reported here"* on a figure that had
  suppressed them for the reason in §8.2.

---

