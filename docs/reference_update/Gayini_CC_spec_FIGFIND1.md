# CC spec FIGFIND-1 — find the time-series figures Adrian is asking for

**Design seat · 8 August 2026. Urgent, small, read-only.**

**This runs in a SECOND session while the main seat is mid-run on TEMPORAL-1.**

---

## 0 · Session discipline — read first

**A second seat on `D:\Github_repos\Gayini` is a git-collision risk.** This task is constructed so it
cannot collide:

- **Read-only. No writes to the repository at all.** No commits, no staging, no branch operations,
  no `git add`, no `git checkout`.
- **Do not run any producer, any build, any R script.** Nothing is rendered or regenerated.
- **Copy only**, and only into `Output/rasters/DATA_share_20260808/figures_for_adrian/` — a new
  folder outside any tracked deliverable. Never `Output/pack/**`.
- **Do not touch `Output/temporal/`, `Output/diag/`, or anything the main seat is writing.**
- If `git status` shows the other seat mid-work, **that is expected — leave it alone and do not
  report it as a problem.**

Ruling AX applies: run to completion, report once. **No gates.**

---

## 1 · What he asked for, in his words

> *"I think you have made figures showing inundation and vegetation cover over time. For certain
> sites, or maybe for paddocks or vegetation community types. I cant find them, but I'd like to
> include some examples."*

He presents on Monday. **He wants files he can drop into a deck**, not a rebuild.

---

## 2 · Candidates, best first

| candidate | what it is | where to look |
|---|---|---|
| **`T2_E_paddock_trajectories`** | **the strongest match.** One line per conserved paddock, faceted by community, middle half of the 60 grazed paddocks as a grey band with their median, wettest years striped | `Gayini_reference_state_review_v3.pdf`; find the source PNG and its producer |
| `figure_f3_annual_gap_series` | annual gap series, registered in `figure_asset` | `build_adrian_pack_T1_F3_F5.R` |
| `D1_paddock_*_slide_data.png` | paddock dashboards — cover and inundation over time | `Output/figures/` |
| `D2_site_*_slide_data.png` | site dashboards. **Built for only 5 of 66** — GA_001, GA_003, GA_019, GA_032, GA_052 | `Output/figures/` |
| `T2_B2_duration_map`, `H6_flood_zone_data` | inundation context, not time series | `Output/figures/` |

**Do not stop at this list.** Search `figure_asset` for any registered figure whose caption or
filename indicates a time axis — "annual", "trajectory", "series", "over time", "35 years", "by
year". Report everything found, including candidates not listed above.

---

## 3 · For every figure found, report

Filename and full path · whether it is registered in `figure_asset` and its `figure_id` ·
its registered caption · its producer script · the unit — site, paddock, part or community ·
**whether it plots cover, inundation, or both** · pixel dimensions and file size · last modified.

**Flag any figure whose axis label carries a denominator of years on a within-year quantity.**
Rulings AY and AZ found three instances of that family and the sweep covered producers and captions,
**not older rendered PNGs.** Anything going to Adrian now must be checked. **Report, do not fix.**

**Flag any figure carrying an internal version stamp**, `INTERNAL`, `DRAFT`, or a pack version
number on its face. He may put these on a screen in front of the Nari Nari Tribal Council.

---

## 4 · Copy the shortlist

Into `Output/rasters/DATA_share_20260808/figures_for_adrian/`.

**Copy, never move.** Verify by checksum both sides.

Shortlist rule, in order: shows a time axis · shows cover, inundation or both · is registered ·
carries no internal stamp · is legible at presentation size.

**Include the paddock dashboards for the four conserved paddocks if they exist** — Bala 26ca, 27ca,
28ca, 29ca. They are the ones he is most likely to want, and Bala 29ca's three communities behaving
differently is the project's clearest single story.

Write `FIGFIND1_index.md` in that folder: one line per figure, plain language, no jargon, saying what
it shows and at what unit. **He will read this instead of asking.**

---

## 5 · The gap, reported honestly

**Site dashboards exist for 5 of 66 plots.** If he asks for a site not in that five, it does not
exist and would need building. **Say so in the index rather than letting him discover it.**

Report anything referenced in project documents that you cannot find on disk. A figure that exists
only inside a PDF is a figure whose producer may have been lost — **that is worth knowing now**, and
it is exactly the SCHEM-2 situation from yesterday.

---

## 6 · Report

Every candidate found, with its metadata. The shortlist copied, with checksums. Any AY/AZ label
family instance found in a rendered figure. Any internal stamp found. Anything referenced but
missing. Total folder size.

**Nothing registered. Nothing rendered. Nothing committed. No writes to the repository.**
