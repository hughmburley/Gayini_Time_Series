# Additional CC specs arising from the biodiversity session — 30 July 2026

*Design-seat output. Five new tasks (O–S) plus amendments to Task N. Every number quoted below was
computed in a **design-seat sandbox** and is **unregistered** — the specs are written so that CC's
gates are verification against stated expected values, not rediscovery.*

---

## READ FIRST — this work spans two repositories

**The biodiversity work has a home repo and an integration repo. They are not interchangeable, and
CC must know which seat it is in before it does anything.**

| | Path | Role |
|---|---|---|
| **Working repo** | `D:\Github_repos\Gayini_Biodiversity` | Where the LOOC-B analysis happens. Tasks **N, O, P, S**. |
| **Integration repo** | `D:\Github_repos\Gayini` | Where the RS census, inundation stack, paddock reports and the main results DB live. Tasks **Q, R**. |

**Do not run this whole file in one session.** Split it: a biodiversity session takes N, O, P, S;
an RS session takes Q and R. A session that opens the wrong working directory will either fail its
guarded reads or, worse, write into the wrong repo.

### Why the split is not negotiable

Tasks Q and R cannot be done in the biodiversity repo even though they close biodiversity findings:

- **Task Q** must run on the **native RS 30 m census grid**. Doing it on the LOOC-B ~100 m grid
  coarsens both sets before comparing them and would manufacture agreement — which is the exact
  thing the test exists to check.
- **Task R** needs Jana's irrigation bank-cut shapefiles and Ernest's land-use history, which are
  RS-side and are not to be copied.

### The four crossings, and their direction

Each crossing has a direction and a form. Nothing else crosses.

| # | Direction | What crosses | Rule |
|---|---|---|---|
| 1 | RS → bio | Export layers (`rs_flood_frequency.tif`, community class, paddocks, `manifest.csv`) | **Guarded read from `D:\Github_repos\Gayini\Output\exports_for_biodiversity\`. Never duplicate into the bio repo.** `Output/` is gitignored, so a second copy is untracked, undated and will silently drift. |
| 2 | bio → RS | **One number per paddock** — median condition + `share_ge_0.5` (Task N Gate 5) | An **appended column** on the existing RS paddock dashboard. **Not** a parallel biodiversity paddock product with its own maps. |
| 3 | bio → RS | A **caveat**, not data (Task P Gate 4) | If the modelled product and the measured floor disagree, any RS text citing biodiversity as corroboration must be weakened. **Hugh decides the wording; CC only reports where the citations are.** |
| 4 | RS → bio | Verification results (Tasks Q, R) | Findings flow back to close the refugia and always-zero questions in the bio findings doc. |

### Hard rules for the boundary

- **Separate git histories. Never open a PR spanning both repos.** One branch, one repo, one PR.
- **Two separate SQLite databases.** `Gayini_Results.sqlite` (RS) and `Gayini_Biodiversity.sqlite`
  (bio). **Never join across them in code** — if a number needs both, it crosses as a written
  value in a change report, not as a query.
- **Never commit rasters** in either repo.
- Read-only on the census, the DB and all cross-repo paths. Guard every cross-repo read with
  `file.exists()` and a clear error. **If a layer is missing → STOP and report.** Do not
  approximate or fall back.
- Crossings 2 and 3 **modify RS deliverables on the 10 Aug critical path.** Neither ships on CC's
  judgement — both need Hugh's explicit sign-off before merge.

### Prerequisite that still has not landed

`RS_export_layers_for_biodiversity.md` has **not** been run, so
`D:\Github_repos\Gayini\Output\exports_for_biodiversity\` does not yet exist. The design-seat
session bypassed it by reading uploaded layer copies directly — **do not repeat that.** Either the
export lands first (an RS-session task), or the biodiversity tasks stop at their first guarded read.

### Priority given the 10 Aug RS deadline

1. **Task P** (bio) — the only task that could change an RS deliverable. Do it first.
2. **Task O** (bio) — closes a live provenance hole on four circulating numbers.
3. **Tasks Q, R** (RS) and **S** (bio) — post-deadline.

---

## Session review — what was established, and what it costs

| # | Finding | Status | Consequence |
|---|---|---|---|
| 1 | The exactly-zero question is answered: structural (15,084 cells zero in all 17 yrs), 40% in unmapped/unzoned country, 41× more common in non-treed than treed | **Closed**, needs reproduction | Do not mask; change the language |
| 2 | §1.3's "condition runs opposite to the flood gradient" is a between-community reading; within the floodplain the relationship inverts (29% → 96%) | **Closed**, needs reproduction | Headline wording changes |
| 3 | Condition responds to flooding as a **threshold near 40%**, not a gradient | **Closed**, needs reproduction | New headline result |
| 4 | Bala 27ca is 67% hard zero, median 0.000, static across 17 years, and has no monitoring plots | **Closed**, needs verification | RS reference design |
| 5 | The four ungrazed paddocks span **10%–47%** flood frequency | **Closed** | Reference set is unmatched on the driver |
| 6 | The `threatened_species` raster is **100 × condition** (58.9% exact, median \|diff\| 0.13) | **Closed** | Task O |
| 7 | Persistence is **250 m**, spans only 0.839–0.915, r = −0.07 with condition | **Closed** | Out of headlines |
| 8 | The three LOOC-B products sit on **three different grids** | **Closed** | No per-cell cross-product maths |
| 9 | The headline 310,140 species·ha **cannot be reproduced** from any raster in hand (raster sum ≈ 3.71 M) | **Open** | Task O |
| 10 | Condition vs the measured vegetation floor is **weak** (ρ = 0.37 property-wide; 0.07 in chenopod, 0.57 in floodplain) | **Open** | Task P |
| 11 | Upward aggregation excludes nodata correctly — constant-value fixture returned exactly 50.0 across all 185,428 cells | **Verified** | Fold into Task N |

**What this session did not do.** Nothing was written to either repository, nothing registered,
no checksums, no change reports. Every figure and table lives outside version control. That is the
gap Tasks N–S close.

---

## Task N — three amendments

**Repo: `D:\Github_repos\Gayini_Biodiversity`**

1. **Gate 1 R2 is discharged.** The nodata fixture has been run: a constant-value raster (every
   valid source pixel = 50.0) aggregated up returned **exactly 50.000000 on all 185,428
   destination cells**, worst deviation 0.000000. CC should still wire the fixture into the smoke
   test, but it is a regression guard, not an open question.
2. **Add a `veg_p05` column** to `condition_vs_inundation.csv`: the mean aggregated
   `total_veg_p05_8058.tif` per bin. Cheap, and it lets the circularity question (Task P) be
   answered from the same table.
3. **Gate 4 gains a wetness row.** Report mean flood frequency per ungrazed paddock alongside
   condition. Expected: 26ca **45.3%**, 27ca **29.8%**, 28ca **47.4%**, 29ca **10.4%**. This is
   what makes the reference set demonstrably unmatched on the driver, and it is a stronger
   statement than the condition spread alone.

---

## Task O — reproduce the LOOC-B headline numbers, or retire them

**Repo: `D:\Github_repos\Gayini_Biodiversity`**

*Small, self-contained, **highest provenance priority**. No new science.*

**Why.** Four headline numbers are in circulation — effective habitat area 44,213 ha, threatened
species habitat 310,140 species·ha, high-quality habitat 37,516 ha, plant persistence 229.6 —
and **none has a traced path back to a file in the repository.** Worse, summing the
threatened-species raster over its own cells gives ≈ 3.71 M species·ha against a headline of
310,140: an order of magnitude apart. Under the standing five-qualifier rule these numbers
currently fail on support and denominator.

- **Gate 1.** For each of the four, locate the originating artefact — API response, CSIRO summary
  table, or raster — and record the exact file, sheet, cell or endpoint. **STOP and report.**
- **Gate 2.** Attempt to reproduce each from rasters in hand. Document the formula used, the
  denominator, and the cell-area constant. Expected outcome for EHA: mean condition × area
  = 0.5139 × 86,031 ≈ **44,213 ha** — this one should close cleanly.
- **Gate 3.** For TSH, resolve the order-of-magnitude gap. Hypotheses to test in order: (a) the
  raster is a percentage, not species·ha, so the headline applies a different normalisation;
  (b) the headline uses a subset area; (c) the headline came from an API call against a different
  vintage. Note the count is **version-dependent — 1,466 (LOOC-B API docs) vs 1,518 (Mokany et al.
  2025)** — and record which vintage. **STOP and report.**
- **Gate 4.** Any number that cannot be reproduced is **retired from every deliverable** and
  replaced by one that can. Do not carry an unreproducible number with a caveat.

**Also request from CSIRO in this task:** the species-richness layer **`n_i`** as a standalone
raster. The layer currently named `threatened_species` is not it — tested cell by cell it is
100 × condition. `n_i` is SDM-derived from DCCEEW grids, ALA occurrences, elevation limits and
IBRA × NVIS, with **no Landsat input**, and is the only genuinely non-circular biodiversity layer
available. It is the single highest-value acquisition for this workstream.

---

## Task P — quantify the circularity instead of assuming it

**Repo: `D:\Github_repos\Gayini_Biodiversity`** — reads RS exports (crossing 1); Gate 4 reports into RS (crossing 3).

***Do this before 10 Aug** — it can change an RS caveat.*

**Why.** The circularity rule has governed the whole biodiversity deck: condition versus ground
cover was excluded outright on the grounds that both are Landsat-derived and the comparison is
tautological. Measured, it is not. Sandbox result on the LOOC-B grid, n = 84,363:

| Scope | Pearson | Spearman |
|---|---:|---:|
| Whole property | 0.210 | 0.369 |
| Aeolian Chenopod | −0.145 | 0.065 |
| Riverine Chenopod | −0.116 | 0.073 |
| Inland Floodplain | 0.410 | 0.567 |
| Woodland / Forest | 0.506 | 0.521 |
| Non-treed, mapped, always-zero blocks removed | 0.110 | 0.380 |
| Cover normalised by community 85th percentile | 0.261 | 0.427 |

The structure is interpretable: **the link is moderate where condition has variance (floodplain,
woodland) and absent where condition saturates near 1 (both chenopod communities).** It is *not*
a Simpson artefact — the within-community values are mostly weaker than the pooled one.

- **Gate 1.** Reproduce the table above against the stated values. Use `total_veg_p05_8058.tif`
  aggregated up by mean (Rule 2). **STOP and report.**
- **Gate 2.** Test saturation directly as the proposed mechanism: report the variance of condition
  per community, and re-run the correlation restricted to cells with condition < 0.95. If the
  chenopod correlations rise once saturated cells are dropped, the mechanism is confirmed and
  should be stated as such.
- **Gate 3.** Report a recommendation on the rule itself, with reasoning either way. **This is a
  judgement for Hugh and Adrian, not for CC to settle** — CC supplies the numbers and the argument
  on both sides.
- **Gate 4 — the part that touches RS.** A modelled continental-benchmark product and a 35-year
  measured record disagree across most of this property. The measured record has local validity;
  the modelled one does not. If the biodiversity deck is cited anywhere in the RS deliverables as
  corroboration, that citation needs weakening or removing. Search the RS repo for such citations
  and report them.

---

## Task Q — the refugia coincidence test

**Repo: `D:\Github_repos\Gayini`** — must run here, on the native 30 m grid.

*Two independent routes appear to converge on the same ground. Test it.*

Three-way intersection on the LOOC-B grid — condition > 0.75, `veg_p05` > 75%, flood frequency
≥ 40% — coincides on **6,308 ha**. The RS census refugia figure (`green_at_floor`, PV share of
remaining cover > 50%, native 30 m grid) is **6,460 ha**. Within 3%.

That is almost certainly partly coincidence: the definitions differ, the grids differ, and one
route uses modelled condition. But if the two sets are largely the *same pixels*, it is
two-sensor, two-method agreement on the property's drought refugia — a genuinely strong result.

- **Gate 1.** Compute the intersection on the **native RS grid**, not the LOOC-B grid, to avoid
  the coarsening. Report area.
- **Gate 2.** Cross-tabulate the two sets pixel by pixel: overlap area, Jaccard index, and the
  area unique to each. **A similar total with low overlap is a negative result and must be
  reported as one** — do not report the area agreement alone.
- **Gate 3.** If overlap is high, this becomes a headline RS result and should also be tested
  against Adrian's LiDAR lignum extent, which would make it three independent lines.

---

## Task R — the always-zero blocks against land-use history

**Repo: `D:\Github_repos\Gayini`** — needs Jana's bank-cuts and Ernest's history, which are RS-side.

*Closes the last open part of the exactly-zero finding.*

15,084 LOOC-B cells score exactly zero in all 17 years; 84% sit in 8 compact interior blocks;
**40.4% fall in country carrying neither a vegetation community nor a management zone.** The
working hypothesis is cleared or formerly irrigated land, currently unconfirmed.

- Overlay the always-zero mask on **Jana's irrigation bank-cut shapefiles** and on Ernest's
  land-use history. Report the share of the always-zero area falling inside historically
  cleared or irrigated country.
- Cross-check against `total_veg_p05_8058.tif`: if these blocks are genuinely degraded, the
  measured floor should also be low there. If the measured floor is *normal* while modelled
  condition is zero, the blocks are a model artefact and the finding reverses.
- **This is the decisive test and it cuts both ways. Specify the interpretation before running it.**

---

## Task S — register this session's outputs, or discard them

**Repo: `D:\Github_repos\Gayini_Biodiversity`**

*Housekeeping, but it is what makes any of the above citable.*

Fifteen figures, two tables and a 22-slide deck exist entirely outside version control. Either
they enter the repository properly or they must not be cited.

- Re-generate each figure from repository code — **do not import the sandbox PNGs.** Any figure
  that cannot be regenerated from committed code is discarded.
- Register through `write_and_register_figure()`, one transaction each.
- Reconcile the two versions of `Gayini_LOOCB_findings_and_caveats.md` (a 23 Jul copy is still in
  project knowledge; the 28 Jul copy is current) and append the §7 amendment.
- Restore the `## Operational learnings` heading deleted when §6 was rewritten — its bullets
  currently dangle under §6.6.
- Remove `Gayini_fig_habitat_condition_vs_ground_cover_non_treed.png` from the asset manifest.
  **Note:** if Task P recommends relaxing the circularity rule, this figure may be reinstated —
  but on the strength of the measured correlation, not by default.

---

## Standing guardrails for all of the above

Recon-first; STOP at every gate; additive only; branch-and-PR; commits local for Hugh
(TortoiseGit); no AI authorship attribution. Read-only on the census, the DB and cross-repo
exports, via guarded paths — never duplicate. Never re-run the RS builder. Do not run `05`. Never
install packages while another R session is live. No `--vanilla`.

**Confirm the working directory before the first tool call of every session, and echo it.** A
session that has opened the wrong repo will produce plausible output in the wrong place, and
`Output/` being gitignored means that mistake is not visible in a diff.

**A mismatch against any expected value in this document is a finding to report, not a target to
tune toward.**
