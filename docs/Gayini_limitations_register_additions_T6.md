# Limitations register — staged additions (T6)

Same reason as the T2 staging file: `Gayini_limitations_register_*.xlsx` (v10) is **not
in the repo working tree** (gitignored, project knowledge). These entries are staged in
tracked Markdown for merge into the register. Do **not** create a competing .xlsx.

---

## L-T6-a — TOP EXTERNAL DATA REQUEST: is the unzoned land grazed more, less, or not at all?

| field | value |
|---|---|
| **Question** | **Is the unzoned mapped area grazed *more* heavily than the 14-day paddocks, *less* heavily, or *not at all*?** |
| **Why it is the top request** | It decides between two **opposite** conclusions from the same T6 data. The inferred-standard arm sits **at or above** the 14-day floor within stratum (above in 6 of 9 strata; the plot-confirmed subset above in 8 of 9). Reading (a): grazing intensity does not register — the ordering is noise. Reading (b): the unzoned land is **less** grazed (outside the rotational system — remote, unwatered, unfenced, harder to muster), so the ordering is a real intensity gradient with the *inference inverted*. (b) explains the monotonic ordering that (a) must treat as coincidence, and the plot-confirmed subset being highest is the hardest part for (a) to absorb. |
| **Who can answer** | **Nari Nari — in one conversation.** This is the single cheapest question with the highest bearing on the conclusion. |
| **Testable from RS?** | No. Remote sensing sees cover, not stocking. |
| **Evidence** | `v_three_arm_gap_decomposition`, figures `T6_A_three_arm_grid.png` / `_deck.png`. |
| **Status** | **Open — top external data request.** Promoted from a caveat. |

## L-T6-b — 7 of 15 standard plots, and 21.6% of the property, are outside the mapped census

| field | value |
|---|---|
| **Limitation** | **7 of 15 standard-grazing plots** (GA_037/038/042/044/047/048/049) sit **outside the 67,349.332 ha mapped census** — confirmed at Gate B (all 15 have `management_zone_coverage_pct = 0`, so none are on zoned pixels; the 7 unplaced by component are exactly the 7 outside the census mask — same set). More broadly, **18,561.5 ha (21.6%)** of the true farm (85,910.8 ha − 67,349.332 ha) has **never been in any analysis** — not the census, not T1/T2, not T6. |
| **Why it matters** | The standard-grazing arm is anchored by only the **8** standard plots that fall inside the mapped area, in **3 of 18** components. And a fifth of the property is simply unrepresented in every product to date. |
| **Why the census stops where it does** | Not established from the data available here. The mapped 67,349 ha is the census/analysis extent; the 18,562 ha gap is between it and the `gayini_boundary` true-farm area. Candidate causes (unverified): FC / inundation data availability, an analysis-boundary clip, or masked non-target land. **Flag to establish with the data owners.** |
| **Testable from RS?** | The extent boundary is inspectable; the *reason* needs provenance from whoever set the census extent. |
| **Status** | Open. Bounds every property-level claim. |

## L-T6-c — The third arm is INFERRED, not confirmed from a management layer

| field | value |
|---|---|
| **Limitation** | The unzoned area is inferred to be standard grazing from plot locations plus Hugh's confirmation the category exists — **not** from a management layer. Label everywhere: **`unzoned mapped area (8 of 15 standard-grazing plots)`**, never `standard grazing` unqualified. |
| **Also** | Unzoned land is not necessarily all grazed (Gate A composition: 99.2% vegetation, no water/roads, but grazing status unconfirmed per component). Grazing intensity unknown throughout — any dose-response is ordinal, not quantitative. |
| **Status** | Open. Travels with every T6 output. Resolved only by L-T6-a. |
