# Ruling U — blast-radius report

**Read-only.** 4 August 2026 · required by Ruling U before authorising U-a. Nothing changed.
Head `d3d0616`.

**Answer in one line: the radius is the dashboard family and three figures in the methods document.
It does not reach the report batch. But a re-render is not provably clean, and a live session holds
the report worktree.**

---

## 1 · How many rendered dashboards carry the panel

**All 78.** `p_box <- gayini_panel_where_it_sits(...)` is called unconditionally at
`R/gayini_dashboard_compose.R:365` and placed in the **shared left column** at line 380:

```r
left <- cowplot::plot_grid(p_map, p_box, p_base, ncol = 1, rel_heights = c(11, 6, 3))
```

There is no site/paddock branch and no caller-level suppression — `show_kw = TRUE` is the default at
`gayini_dashboard_panels.R:321` and the token appears repo-wide only at its definition and its own `if`.

| set | count | run_id |
|---|---:|---|
| D1 paddock | **21** | `taskM_gateC` |
| D2 site | **57** | `d2_site_dashboard_batch_20260720` |
| **total** | **78** | |

Matches the project's recorded state (site 57/57, paddock 21/21).

## 2 · Which `figure_asset` rows

**78 rows**, all in `Output/figures/dashboards`, all `superseded_flag = 0`, all `qa_status = REVIEW`,
across the two `run_id`s above. A re-render changes 78 checksums and requires 78 `INSERT OR REPLACE`
re-registrations.

Additional **copies** exist outside the live family and are not registered as such: 57 in
`Output/review_bundles/d2_site_dashboard_batch`, 28 in `review_bundles/tier1_dashboards_trial/figures`,
10 in `review_bundles/tier1G_figures_dashboards/figures`, 10 in `Output/figures/dashboards/29c`, plus
archived sets under `Output/_archive/` and `Output/figures/_archive/`. These are bundle snapshots; they
would go stale rather than break.

## 3 · Which documents embed them

**The methods document only.** V10 holds 28 embedded images and **zero are byte-identical** to a live
dashboard render — consistent with the resampling recorded for the dashboard figures. Ruling U names
Figures 12, 13 and 14; that is the embedding set.

## 4 · Does the report batch regenerate them or read from disk — and does the p-value reach it?

**It reads from disk, and it crops the p-value out. The 57 site reports do not carry it.**

- `docs/reports/Gayini_Paddock_reports_V2/report_figs.py:432`, `fig_site_map()`:
  ```python
  src = f"{FIGSRC_D2}/D2_site_{r['unit']}_slide_data.png"
  im = Image.open(src).convert('RGB'); W, H = im.size
  im = im.crop((0, int(.03*H), int(.40*W), int(.60*H)))
  ```
  It takes the **left column, top 60%** — the locator map.

- **Where the caption sits.** `kw_cap` is a ggplot **`caption`** (`gayini_dashboard_panels.R:359`), so it
  renders at the **bottom of `p_box`**. With `rel_heights = c(11, 6, 3)` under a header at
  `rel_heights = c(0.07, 1)`, `p_box` spans roughly **59%–75%** of figure height and its caption sits at
  ≈**74%**. The crop ends at **60%**. The caption is outside it by ~14 points of figure height.

- **D1 paddock dashboards are not read by the batch at all** — `D1_paddock` appears nowhere in
  `Gayini_Paddock_reports_V2/`. The 21 paddock reports build their own matplotlib figures from the DB.

- **The batch computes no p-value of its own.** No `kruskal`, no `scipy.stats`, no p-value anywhere in
  `report_figs.py` / `report_data.py` / `config.py`.

**So by Ruling U's stated criterion the answer is: not more than the dashboard family.** The radius is
78 renders + 78 registry rows + 3 embedded figures in one document.

---

## Two things that bear on the decision and are not in the four questions

### A · A re-render is not a clean p-value removal

**All 78 renders predate the last commit to every file that produces them.** All three sources —
`gayini_dashboard_panels.R`, `gayini_dashboard_compose.R`, `gayini_veg_water_census_panels.R` — were last
committed in **`5d78ce0`, 23 July 14:28**. The renders are dated **D1 23 July 12:09** and **D2 20 July**.

`R/gayini_veg_water_census_panels.R` — which supplies the **response panel**, the tall right-column panel
of every dashboard — carries an mtime of **23 July 12:59**, *after* the D1 renders at 12:09 and eleven
days after the D2 batch.

**A re-render today therefore reproduces neither set byte-for-byte.** It would emit the response panel from
a code state that has moved since the current figures were made. Whether that drift is cosmetic or material
cannot be established without re-rendering, which is out of scope under §0.2.

**The edit is one line. The action is regenerating 78 client-facing figures from drifted code, six days
out.** Those are different sizes of risk, and only the first is small.

### B · A live session holds the report worktree

`D:/Github_repos/Gayini_reports` on `feature/reports` is **active, not abandoned**:

- last commit **`48e8ada`, today 20:12** — *"REPORTS v1.4: rulings R-1 to R-5 applied; canaries now proven able to fail"*
- **two uncommitted modified files**: `scripts/15_reports/report_build.js`, `scripts/15_reports/report_data.py`

That session is working on **the report build** — the same subsystem U-a would touch. Four collision
incidents have already occurred on this project, and the collision is at commit time.

**U-a should not be executed while that worktree holds uncommitted report-build changes.**

---

## Summary against Ruling U's decision rule

| question | answer |
|---|---|
| how many dashboards carry the panel | **78** — 21 paddock, 57 site; unconditional, shared left column |
| which `figure_asset` rows | **78**, all REVIEW, none superseded, two run_ids |
| which documents embed them | **the methods document only** — Figures 12, 13, 14 |
| batch: regenerate or read from disk | **reads from disk, and crops the p-value out** — the 57 site reports do not carry it |

**The stated trigger for U-b — "more than the dashboard family" — is not met.**

**Reported, not decided.** The two items above are offered because they change the cost of U-a without
changing its radius: the re-render is not provably clean, and the report worktree is currently held.
