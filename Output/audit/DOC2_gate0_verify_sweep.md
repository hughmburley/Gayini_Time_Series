# DOC-2 Gate 0 — the VERIFY sweep

**Read-only.** 4 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · no writes to the document.
**Run in an isolated git worktree** (`D:/Github_repos/Gayini_doc2`, branch `task/doc2-review`), per the
standing rule made mandatory on 4 August after the fourth commit collision.

## Input, recorded rather than assumed

| | |
|---|---|
| filename | `docs/reports/Gayini_RS_methods_doc_V8.docx` |
| size | 9,827,449 bytes |
| modified | 2026-08-04T16:36:09 |
| **SHA-256** | `d4b95bd9ca5a2f1e49d698f0f5bea141997384dac162366c17afd57562fc56b7` |

**No Word lock file present** — precondition met. A `WINWORD.EXE` process is running but holds no lock on
this document. `Gayini_RS_methods_doc_V6.docx` is gone from `docs/reports/`, so v8 is unambiguously the
current document; no version-string trust was required.

**Extraction:** 260 claims (v6 held 224) — 111 value, 90 structural, 51 method, 8 interpretive.
**Figure numbering is clean:** 25 captions, 1–25, each used exactly once, every body cross-reference
resolves, no orphans. The repeated `Figure 6` string is a body cross-reference, confirmed by parse.

---

## The inventory differs from expectation — and that is the first finding

**Seven distinct VERIFY passages in v8, against the six DOC-1 established in v6.**

The change is not a regression. The references section has been **restructured and partly sourced**: what
was one References flag is now two — `Data products` and `Software` — and the previously bare citation list
is now split into *Data products · Regional context · Vegetation and grazing · Required and not yet sourced ·
Software*.

**Citations have moved forward materially since DOC-1.** Six were unsourced; **three remain**, and they are
now named individually with what each supports. The Dawson et al. (2016) question is now framed in the
document itself exactly as the repository evidence supports — *"whether this citation is required is a
question for the authors"* — which was DOC-1's conclusion and is now the document's own position.

---

## The seven flags

| # | Section | Flag (verbatim, abridged) | Status | Evidence | Effort |
|---|---|---|---|---|---|
| 1 | §2 Data sources | *"The fractional cover algorithm version, cross-sensor calibration … and the treatment of the Landsat 7 scan-line failure … cannot be established from the analysis code"* | **OPEN** | No code here computes FC; repo-wide search for `SLC`, `scan.?line`, `calibration`, `JRSRP`, `fc_version` returns nothing. `dim_source_product` is one line deep | Provider product metadata. Not obtainable from the repository |
| 2 | §6.1 | *"Regression diagnostics are neither reported nor computed anywhere"* | **OPEN** | Repo-wide search for `shapiro`, `breusch`, `leverage`, `hat_`, `cooks`: zero hits | Running them — new analysis. Established unclosable at DOC-1; not re-litigated |
| 3 | §6.5 | *"Two seasonal reductions are computed … the cross-check result is not reported"* | **CLOSEABLE → CLOSED IN THIS GATE** | See below | Reporting one existing artefact's columns |
| 4 | §6.5 | *"The sign-consistency proportion … is not stated here and should be taken from the producing code"* | **CLOSED** | `SIGN_FRAC = 0.70`, `20_run_census_veg_wet_response.R:55`, established DOC-1 Gate A and re-confirmed Gate C | State the number; remove the flag |
| 5 | §12.3 | *"This section is a draft and its priorities have not been agreed"* | **OPEN** | Whether a priority ordering has been agreed is not a property of the code or database | A decision, not a verification |
| 6 | References → Data products | *"Formal citations, product identifiers and version strings are required for all four"* | **OPEN** | No bibliography in the repository | External sourcing. **Substantially duplicates flag 1** — see below |
| 7 | References → Software | *"Version numbers for all software and packages should be recorded before circulation"* | **CLOSEABLE → CLOSED IN THIS GATE** | See below | Assembling versions already recorded in the repository |

**Two closed by earlier work or in this gate, one closed by statement, four open.** Of the four open, two are
external (provider metadata, citations), one needs new analysis, one is a design-seat decision. **None is
closable by this task**, and the spec's instruction not to attempt them is correct.

---

## Flag 3 — closed, with a result that matters

The flag asks for the growing-season cross-check to be reported. It is computable from a registered
artefact — `Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv` carries `median_r_B`
(JJA/SON) and `median_r_A_on_Bset` (the base series recomputed on the same cells, for like-for-like).

| stratum | A (base) | A on B's cells | B (JJA/SON) | ≥ 0.20 under A | ≥ 0.20 under B |
|---|---:|---:|---:|:--:|:--:|
| Aeolian low | NA | NA | NA | — | — |
| Aeolian mid | 0.1641 | 0.1671 | 0.1340 | no | no |
| Aeolian high | 0.1754 | 0.1760 | 0.1527 | no | no |
| Riverine low | 0.1484 | 0.1485 | 0.1254 | no | no |
| **Riverine mid** | 0.2244 | 0.2259 | **0.1882** | **yes** | **no** |
| Riverine high | 0.3211 | 0.3214 | 0.2716 | yes | yes |
| Inland low | 0.2562 | 0.2563 | 0.2078 | yes | yes |
| Inland mid | 0.3860 | 0.3860 | 0.3327 | yes | yes |
| Inland high | 0.3891 | 0.3894 | 0.3258 | yes | yes |

**The cross-check result, stated:** the growing-season series runs **lower in 8 of 8 measurable strata**,
mean gap **0.0415**. **The responding count is not robust to the seasonal reduction — five strata reach 0.20
under the base series, four under the growing-season cross-check, with Riverine mid the one that moves.**

**The comparison is like-for-like and the thinning is not the cause.** A and A-on-B's-cells differ by at most
0.003 in every stratum, so the drop is a genuine seasonal effect and not a selection artefact of B's smaller
cell set. That is exactly what the `A_on_Bset` column exists to establish, and it does.

**Consequence for §7.3.** DOC-1 found §7.3's *"six of the eight measurable strata"* contradicted at five.
This gate adds that **five is itself the base-series answer, and the cross-check gives four.** Whatever number
the corrected text carries should name the reduction it belongs to.

---

## Flag 7 — closed, with a caveat about what "the software" means here

The versions exist in the repository; they are simply not gathered in one place.

| component | recorded | source |
|---|---|---|
| R | **4.6.1** | `T12_gate0_recon.md`, `taskM_gateC_report.md`, `taskM_gateD_report.md` |
| `terra` | **1.9.34** | `taskM_gateC_report.md`, `taskM_gateD_report.md` |
| `sf` | **1.1.1** | `taskM_gateC_report.md` |
| `mgcv` | version not recorded | named in the document; no version anywhere |
| Python | **3.12.10** | `T12_supply_and_gateA0.md` |
| `duckdb` | **1.5.4** | `taskM_gateD_report.md` |
| `rasterio` | **1.5.0** (bundled GDAL 3.12.1) | `scripts/13_dea_landcover/requirements.txt`, pinned |
| DEA pull stack | `pystac-client==0.9.0`, `odc-stac==0.5.2`, `odc-geo==0.5.3`, `xarray==2026.7.0`, `odc-loader==0.6.4`, `pystac==1.15.2`, `pyproj==3.7.2` | same, pinned |

**The caveat, and it should travel with any statement built from this.** There is **no project-wide
environment lock**: no `renv.lock`, and `DESCRIPTION` pins nothing (`Version: 0.0.0.9000`, only
`testthat (>= 3.0.0)` under Suggests). What the repository holds is **per-task toolchain records**, written
at the gate that used them. A single "software used" statement assembled from these is a **reconstruction
across tasks, not a captured environment** — accurate for the tasks named, and not a guarantee that every
figure in the document was produced under it.

**`mgcv` is the one gap that matters**, because §6.6 names it explicitly as the fitting engine and no version
is recorded anywhere in the repository.

---

## Two findings from the sweep itself

**Flags 1 and 6 are substantially the same flag in two places.** Flag 6's second sentence —
*"The fractional cover and water-observation products in particular need provider metadata covering algorithm
version, cross-sensor calibration between Landsat 5, 7, 8 and 9, and treatment of the Landsat 7 scan-line
failure after 2003"* — restates flag 1 almost verbatim. One requirement, flagged twice, in two sections. A
reader meeting the second will not know whether it is the same outstanding item or a second one. **Merging
them, or making the second a pointer to the first, removes a duplicate obligation from the document.**

**The reference list has advanced further than the flags suggest.** Three citations remain outstanding, not
six, and each is now named with what it supports. Flag 6's *"required for all four"* refers to the four data
products, not to the citation backlog — but sitting immediately below a list of resolved citations, it reads
as though nothing has been resolved.
