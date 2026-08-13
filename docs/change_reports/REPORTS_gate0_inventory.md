# REPORTS — Gate 0 inventory

**Session:** report batch, third concurrent seat · **Date:** 4 August 2026
**Worktree:** `D:\Github_repos\Gayini_reports` on `feature/reports`, created from `main` @ `2088fad`
**DB access this session:** read-only. No write attempted, none planned.
**Status:** STOP at Gate 0. Nothing built. Four blockers, five findings.

---

## 0. Recon

`main` @ `2088fad`, level with `origin/main` (0 ahead, 0 behind). Worktree created clean.

Untracked in `main` at session start: `David_wright_notes.{md,txt}`, `Gayini_Notes.txt`,
`Output/audit/Gayini_LiDAR_section_handoff_to_methods.md`,
`docs/reports/Gayini_paddock_report_pack_update/`. The last of these is the delivery being
landed; the others belong to the other two seats and were not touched.

**Consequence of the ignore rules for this session.** `.gitignore` excludes `Output/*` except
`Output/audit/` and `Output/pack/*.{csv,md}`. The worktree therefore contains **no database, no
C1/D2 renders, and no `Output/tables/T10_annual_gap_series.csv`** (untracked). The builder must
read from the main working directory. Build products land under `Output/`, which is ignored, so
they create no staging collision — the worktree isolates the *commit*, which is where the
collisions happened.

---

## 1. The four registered constants — ALL PRESENT

Read from `Output/database/Gayini_Results.sqlite`, `mode=ro`, `PRAGMA query_only=1`.

| number_id | pinned_value | support | period |
|---|---|---|---|
| `floor_flood_slope_64pdk` | 0.547838 | paddock | 1988-2022 |
| `floor_flood_intercept_64pdk` | 52.652934 | paddock | 1988-2022 |
| `floor_flood_r_64pdk` | 0.71 | paddock | 1988-2022 |
| `floor_flood_residual_sd_64pdk` | 6.6208 | paddock | 1988-2022 |

Slope and intercept carry the 31 July precision correction in `decided_by`. The values match
those the build note quotes, so the `1e-4` assertion should pass unchanged.

**The four contract canaries are also present**, at the registered values the build note names:
`rptscope_canary_p1_paddock_floor_bala29ca` 40.52 · `rptscope_canary_p3_composition_share_bala29ca_inland`
34.59 · `rptscope_canary_p5_recovering_parts_bala29ca` 2 · `t10_bala29ca_xsec_residual` −16.8.

`dim_headline_number` holds **101 rows**, matching the build note's `registry OK — 101 rows`.
(CLAUDE.md still states 59; it is stale on that count, as it is on table/view counts — live is
93 tables / 35 views against the documented 86/30. Recorded, not acted on.)

All source objects the builder depends on exist: `v_zone_floor_flood_residual` (view),
`fact_zone_community_part_classification`, `fact_zone_veg_annual`, `dim_management_zone`.
`Output/tables/RPTSCOPE_number_contract.csv` and `RPTSCOPE_report_set.csv` are present, as is
`Output/tables/T10_annual_gap_series.csv` (4,679 bytes, 28 July) — the file §8.1 says the design
seat did not have.

---

## 2. C1 renders — 5 of 7 selected paddocks

Builder path: `Output/figures/C1_veg_regime_paddock_{slug}_data.png`, `slug = s.replace(' ','_').replace('/','-')`.

| paddock | C1 | note |
|---|---|---|
| Bala 26ca | **FOUND** | |
| Bala 28ca | **FOUND** | |
| Bala 29ca | **FOUND** | |
| Dinan 10 | **FOUND** | |
| Dinan 8 | **FOUND** | |
| Bala 27ca | **MISSING** | single-community, 4-page report |
| Bala 15 | **MISSING** | single-community, 4-page report |

21 paddocks have a C1 render on disk, but **they are not the same 21** as the paddock-report set:
the C1 set includes Bala 6/12/17/19/20/21/23, Dinan 1/3/6/12, Mara 7/8/13/21 and excludes
Bala 15, Bala 27ca and Bala 7/10.

This is a **material improvement on the delivered build**, which fell back to the composition
figure for six of seven paddocks (build note §4: *"no C1 map on disk — all but Bala 29ca here"*).
Five of seven will now take the C1 path. Handoff §8.3 asked for exactly this check and warned the
C1 path is under-exercised; it is about to be exercised five times.

**It also guarantees `verify_batch.py` will report `changed`** for at least those four paddock
documents, because the map, its caption and `figs_meta.json` all change. That is a correct and
explained difference, not drift — see §5.

## 3. D2 renders — 25 of 25 exist, 0 of 25 findable

Builder path: `report_figs.py:432`, `f"{UP}/D2_site_{r['unit']}_slide_data.png"` where `UP` is
`figure_source` = `Output/figures`.

| | count |
|---|---|
| selected sites with a D2 render **at the builder's path** | **0 / 25** |
| selected sites with a D2 render **on disk** | **25 / 25** |

Every one is at `Output/figures/dashboards/D2_site_{unit}_slide_data.png` — one directory below
where the builder looks. C1 sits directly in `Output/figures/` and resolves correctly, so a single
`figure_source` key cannot serve both.

The build note predicted the opposite: *"the map fallbacks fire because this seat has only one C1
and ten D2 renders locally. On the repository they will not fire."* As delivered, on this
repository, **the D2 fallback fires for all 25 sites** — worse than the design seat's 14 of 25,
not better. Fixing it needs either a second path key or a subdirectory in the pattern; both are
code changes and both change 25 documents. Held for the Gate 1 decision, not made here.

A second copy of ten D2 renders exists at `Output/figures/dashboards/29c/` — GA_008, 009, 010,
034, 035, 036, 043, 055, 056, 058. Ten, which is the count the design seat says it had locally.
Duplicate-artefact class (I-17); flagged, not resolved.

---

## 4. Blockers — the batch cannot run

| # | blocker | effect | fix |
|---|---|---|---|
| **B1** | **`node` and `npm` are not installed** — absent from both PowerShell and Git Bash | `report_build.js` cannot run. **No document can be produced.** | install Node; `npm install` for `docx` |
| **B2** | **LibreOffice absent** (`soffice` not found in either Program Files) | no PDF export; `check_page_fill.py` cannot measure the 70–90% fill band | install LibreOffice |
| **B3** | **Poppler absent** (`pdftoppm`, `pdfinfo`, `pdfimages`) | render QA cannot run | install Poppler |
| **B4** | **`matplotlib`, `geopandas`, `pillow` not installed** for `python 3.12.10` | `report_figs.py` cannot run | `pip install -r requirements.txt` |

B4 is routine. **B1 is the hard one** — without Node there is no document layer at all, so Gate 1
cannot be reached. B2/B3 block only the render QA, and the fill band is the check that catches the
image-height trap, so shipping without them is not advisable.

**`paths.json` is wrong for this repo on two of its six keys** — anticipated by PLACEMENT.md
(*"adjust those four keys if the repo puts them elsewhere"*), so this is configuration, not a defect:

| key | in `paths.json` | actual |
|---|---|---|
| `db` | `{repo_root}/Output/Gayini_Results.sqlite` | `{repo_root}/Output/database/Gayini_Results.sqlite` |
| `gpkg` | `{repo_root}/Output/Gayini_Results.gpkg` | `{repo_root}/Output/database/Gayini_Results.gpkg` |

---

## 5. Findings to carry forward

**F1 · The kickoff cites a handoff §8.4 that does not exist.** The brief attributes two error
classes — support-level mixing (C10), and quoting an area without naming its footprint — to
"handoff §8.4", and states the report batch has been checked against both and is clean. **§8 is
titled "Three known defects" and contains 8.1, 8.2, 8.3 only.** Both copies of the handoff (pack
root and `Gayini_reports_for_CC_20260804/docs/reports/`) are byte-identical, so this is not a
stale-copy problem; no §8.4 was written. Per I-43 — *a ruling is only a ruling if it can be
quoted* — **the "checked and clean" claim has no quotable basis and is not treated as
established.** Both error classes are real and are documented, but in the DOC-1 audit
(`DOC1_gateB_value_claims.md` §11 and the §7.3 CONTRADICTED entry;
`DOC1_gateC_figures_methods.md:215`), not in the handoff. The check is therefore **outstanding**,
not done, and is scheduled into Gate 2 rather than assumed.

**F2 · The record span is a typed literal in paddock prose; the site report reads it from data.**
`report_build.js` types 35 years and 1988–2022 at lines 86, 100, 177, 241, 242 and 255 —
including the arithmetic `Math.round(r.ff*0.35)` that turns a flood-frequency percentage into
*"about N years in 35"*. Line 346, in the **site** report, uses `${r.n_years}`. So one half of the
batch derives the span and the other half asserts it. This is the class the standing rule names:
*a criterion stated as a typed literal is not a check, and that applies to prose too.* It changes
no number today — the span genuinely is 35 years — but it is the same construction as the literal
found and fixed on 4 August. Recorded for Gate 2.

**F3 · "every 25 m cell"** (lines 241–242) is the nominal grid, not the census grid of 24.970268 m.
It is a plain-language size label, not an area computation, so it corrupts nothing. Noted at low
priority against CLAUDE.md's standing warning about the 25 m nominal.

**F4 · The slug will not find two C1 renders in the 52-set extension.** `slug` maps `/` to `-`,
giving `Bala_8-11`; disk carries `C1_veg_regime_paddock_Bala_8_11_data.png` with an underscore.
`Bala 7/10` has no C1 render at all. Handoff §6 asked for this check — it fails for both
slash-named paddocks. Only relevant if the design seat confirms 52.

**F5 · Word is running** (`WINWORD`, PID 31868). The kickoff requires it closed before V6 is
opened. **V6 has not been opened.** The only Office lock file in the repo is on
`docs/reference_update/~$Gayini_reference_state_review_v3.pptx`, not on V6 — but the process is
live and the instruction was explicit, so V6 stays shut until it is confirmed closed.

---

## 6. What I have not done

- Not opened `Gayini_RS_methods_doc_V6.docx` (F5).
- Not run any part of the batch (B1–B4).
- Not modified `paths.json`, the builder, or `EXPECTED_OUTPUT.json`.
- Not written to the database, and not copied the delivery into `scripts/15_reports/`.
- Not resolved the 32-vs-52 document set, which is design-seat (§9).

## 7. Recommended Gate 1 sequence, once B1–B4 clear

1. Relocate the delivery to `scripts/15_reports/`, `docs/reports/`, with `paths.json` corrected on
   `db` and `gpkg` only.
2. Run the batch **with the D2 path left as delivered**, so the only inputs that differ from the
   4 August build are the five C1 renders. Record `verify_batch.py` verbatim.
3. Expect `changed` on the paddock documents that gain a C1 map, and account for each one against
   `figs_meta.json`. Expect the 25 site documents to match, since their D2 fallback is unchanged.
4. Only then, as a separate and separately-recorded step, fix the D2 lookup and re-run — so the
   C1 effect and the D2 effect never land in the same diff.

The manifest is not regenerated at any point.
