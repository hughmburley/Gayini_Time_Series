# PACK-1 P3 — captions, filenames, claim-audit regeneration, T3 rows

**Date:** 3 August 2026 · **Prior:** `faf377f` · **NO DB WRITES.** Probe 101/297/191/4/59 at open and close.

---

## 0. Addendum correction applied first

`PACK1_P1_item_list.md`'s acceptance row amended **15 → 16 distinct non-null paths**, with a visible
correction block, not a silent edit. **Item list and assembly manifest both read 16, verified.**
Logged as the **seventh instance of I-40**, in its own shape: *an acceptance criterion that passed
because the check and the thing checked were wrong identically* — with the standing rule that **an
acceptance criterion stated as a literal is not a check; where a count is derivable, the criterion
must derive it.**

## 1. P3-2 — filename check: 17 items, 0 failures

Every `file_path` in `PACK1_item_list.csv` verified against **disk** and against the **registry** in
the same pass. All resolve. T3 correctly carries no file. **No filename defect** — the four
memory-written paths were caught and fixed at P1, and nothing new has appeared.

## 2. P3-5 — metric and support adjacency: reported, and it finds nothing

14 registered captions scanned for a `veg_p05_spatial` number beside a `veg_p05_mean` number, and
for a plot-support number beside a pixel-support number.

> **Violations: 0.** Every caption states one support level and one floor metric. **Reported as done
> even though it found nothing**, per P3-5.

## 3. P3-1 — clause-by-clause audit

**Verification mode is stated per item, because it differs and that matters.** Eight items were
opened and read in this session; nine were checked against their registered caption and producer
without re-opening the image. **P3-4 honoured throughout: files opened to read, never to rebuild.**

| item | clause | drawn? | evidence |
|---|---|---|---|
| **M3** | "for every 25 m square… share of observed years ground cover was high" | **YES** | title: *% of observed years total-veg mean > 70%* |
| **M3** | "forms broad connected areas **rather than following paddock boundaries**" | **NO — FAILS** | **the map draws no paddock boundaries at all.** A reader cannot see the comparison the clause asserts |
| **M3** | "areas with fewer than ten valid years are left blank" | **YES** | subtitle *NA where < 10*; white patch visible near 9000000 E / 4350000 N |
| **M3** | "the brightest shading saturates where cover was high in every observed year" | **YES** | legend tops out at 100; large saturated yellow regions |
| **M3** | *(missing)* threshold is a **chosen cut** | **ABSENT** | see P3-3 |
| M4 / F7 | five fill classes, hatching, core outline, no state asserted for Bala 29ca Inland | YES | opened at T13 Gate D and again this session |
| M4b | classification at 0.75 / 1.00 / 1.25, three equal panels | YES | opened at T13 Gate D |
| M5 | two rows × two grains, shared scale per row, out-of-scope fill | YES | opened at T11 Gate C |
| M5b | diverging residual scale, Bala 29ca and Dinan 10 labelled | YES | opened at T11 Gate C |
| F3 | three series, fitted trends, no p-values | YES | opened at the Adrian-pack build |
| F5 | 64 points, registered expectation line, band, two callouts | YES | opened at the Adrian-pack build |
| T1 / T1_render | four paddocks side by side, no summary row | YES | opened at the Adrian-pack build |
| M1 | "all 64 zones filled by treatment, labelled" | **not re-opened** | registered caption + producer |
| M2 | "66 plot centroids… 15 Standard-grazing plots unzoned" | **not re-opened** | registered caption; **the 15 agrees with R1b's independent count** |
| F1 | "veg_p05_spatial trajectories, reference vs grazed IQR, faceted" | **not re-opened** | registered caption |
| F2 | "veg_mean secondary variant" | **not re-opened** | registered caption |
| F4 | "ref_change vs grazed_change per community" | **not re-opened** | registered caption |
| F6 | "inferred-standard arm at/above 14-day floor" | **not re-opened** | REM-1's verified wording carried, per P3-4 |
| T2 | 115 rows, classification | YES | it is a CSV, read directly |
| T3 | — | n/a | no file; see P3-9 |

### The one failing clause — reported at P3, and APPLIED under Ruling S3

**M3, clause 2.** *"The most persistent country forms broad connected areas rather than following
paddock boundaries."* The first half is drawn. **The second half is not: the figure contains no
paddock boundaries**, so the comparison cannot be seen. The claim may well be true — M5 shows
exactly that at paddock and part grain — but **this figure does not show it.**

**Rewrite, reported at P3 and ACCEPTED AS DRAFTED at S3. Now applied to register v3 §3, with a visible note recording what the previous wording claimed and why it could not be seen:**

> *For every 25-metre square, the share of observed years in which total vegetation cover exceeded
> 70%. The most persistent country forms broad connected areas. **The 70% line is a chosen cut, not
> a natural boundary in the data** — a sweep across plausible thresholds shows a smooth decline with
> no break, so the area labelled "persistent" moves substantially with the cut. Squares with fewer
> than ten valid years are left blank, and the brightest shading saturates where cover exceeded the
> line in every observed year.*

**Also observed, not a clause failure:** M3 is rendered in **viridis**. That is consistent with the
standing exception for read-as-data appendix figures, and **M3 ships as-is** per P2 — recorded so it
is not mistaken for an oversight.

## 4. P3-3 — the chosen-cut clause, with its evidence

The rewrite above carries it. Supporting numbers from T3 Gate B1, already derived at R2 Ruling D:
smooth monotonic decline, **median elasticity −5.0**, no knee, no plateau, no bimodality, and **±5 pp
around the operational cut swings the area by a factor of 3** — 12,641 ha at 70, 8,300 at 75,
4,179 at 80. **M3 still ships.**

## 5. P3-6 — claim audit regenerated live, not edited

| state | before | after |
|---|---|---|
| PINNED | 6 | **11** |
| SOURCED | 12 | **7** |
| DERIVED | 1 | 1 |
| N/A_by_design | 2 | 2 |
| UNSUPPORTED | 1 | 1 |
| **total** | 22 | 22 |

**The inverse, as predicted.** All six R2-pinned quantities now read PINNED, re-derived by live
lookup against `dim_headline_number`:

`REG-C6b` → `t13_recovering_survive_drop2wettest` · `REG-C6c` → `bala15_xsec_residual` ·
`REG-C4a` → `bala29ca_improvement_surviving_water_pct` · `REG-C5` → the four
`ref_paddock_flood_rank_bala{26,27,28,29}ca` · `BYQ-Q1` → `cropping_history_null_count` ·
`BYQ-Q4` → `three_arm_standard_at_or_above_count`

## 6. P3-7 — both mis-mappings fixed

**BYQ-Q6** was PINNED to `t13_parts_recovering_count`, whose `pinned_value` is **8**, while the claim
reads *"between three and fifteen parts are improving"*. **The pin did not state the claim.**
Repointed to that row's **spread** (`spread_min` 3 → `spread_max` 15), which is what the claim
asserts — and because a spread is not a pinned value, the row is now **SOURCED**, not PINNED.

**REG-C3 and BYQ-Q5** both cite `floor_flood_r_64pdk`, pinned at **r = 0.71**, while both claims
quote **r² ≈ 0.50**. The arithmetic is right (0.71² = 0.5041) but **a reader looking up 0.504 will
not find it.** Derivation now noted on both rows.

## 7. P3-8 — pack item T3 candidate rows (Ruling K: scientific first)

Collected with sources. **No wording drafted.**

### Section 1 — what the analysis cannot tell you

| row | source |
|---|---|
| the two p05 objects are different quantities and must never be compared numerically | `T2_zone_annual_veg_extraction.md` §94; spec §6 |
| the reference set spans flood ranks **3, 6, 31, 61 of 64** — not one condition. **This is Gate E** | `ref_paddock_flood_rank_bala{26,27,28,29}ca` |
| not-grazed is not conserved: `cropping_history` NULL on **64 of 64** | `cropping_history_null_count` |
| L-01 — the management zone is not an ecological unit | `Gayini_learning_L01_unit_of_analysis.md` |
| all four conserved paddocks sit in the Bala block, so **treatment is perfectly confounded with block** | `dim_management_zone.reference_set_caveat` |
| the standard-grazing arm has **15 sites and no paddock parent** — excluded from the report set by construction | R1b §3; `RPTSCOPE_report_set.csv` EXCLUDED rows |
| refugia is a **chosen cut on a continuum**, not a discovered class | T3 Gate B1; R2 Ruling D derivation |
| **the floor analysis excludes the treed stratum entirely** — nine of eleven strata, **988,831 of 1,080,157 pixels (91.55%)** — so it is a ground-layer measurement and says nothing about tree or shrub structure. Floodplain Woodland / Forest **86,375 px (8.00%)** and Other / minor units **4,951 px (0.46%)** are outside every floor number in this pack | `census_by_zone_stratum`, verified independently 3 Aug — **replaces a withdrawn 13.33% figure, see below** |
| 35 consecutive years are not independent — **no p-values** on the annual series | spec §6; T10/T13 |
| the channel-association result is **proxy-based; no channel layer exists** | **T3-I5**, `docs/change_reports/T3_gateCDE_20260803.md` — no channel or watercourse layer is registered or present; the only hydrological geometry is Task J irrigation infrastructure, which is not natural channel, so flood frequency is a proxy |
| reproduction coverage, and the numbers with **no derivation path** | `RPTSCOPE_reproduction_status.csv` — live, never typed |
| the whole-project rows of the v10 limitations register, **once it lands** | not in the repo (Ruling H) |

### Section 2 — how we know our own checks work

| row | source |
|---|---|
| **I-36** the test's exit string has mismatched denominators | issues log |
| **I-37** numeral collisions — the eighteens, the six-of-nines, the two T3s, the three threes | issues log |
| **I-40** recording a decision is not executing it — **seven instances, one of them the design seat's** | issues log |
| **I-42** a check that errors is not a check that catches | issues log |
| **I-43** a ruling is only a ruling if it can be quoted | issues log |
| the rewritten **L-T12-b**, paired with T3 Gate B1's rule firing — one pre-registered rule fired and was honoured, another was aimed wrongly and caught nothing | Ruling I |

### Both unsourced rows resolved, 3 August

**The channel row is sourced** — T3-I5 in `T3_gateCDE_20260803.md`. Cited on the row.

**The 13.33% woody-cover row is WITHDRAWN. It does not reproduce.** Verified independently against
`census_by_zone_stratum`, and every figure matches the design seat's:

| | pixels | share | seat |
|---|---|---|---|
| Floodplain Woodland / Forest | **86,375** | **8.00%** | 86,375 / 8.0% ✓ |
| Other / minor units | **4,951** | **0.46%** | 0.5% ✓ |
| **non-treed analysis scope** | **988,831** | **91.55%** | 988,831 / 91.5% ✓ |
| sum | **1,080,157** | 100% | reconciles exactly |

**Nothing in the database yields 13.33%.** The 988,831 also matches the standing non-treed scope
(`treed_context_flag = 0 AND regime_band <> 'context'`) and therefore T3 Gate E's baseline. The
figure entered via the R6 LiDAR review — a TaskU product at `qa_status = REVIEW`, **unshippable by
its own registration** — and reached the T3 draft from a review document without a database check.

**Logged as the eighth instance of I-40, source named as the design seat.** Replaced with the
statement the analysis actually supports, now in Section 1 above.

## 8. P3-9 — T3's register caption: **REPLACE**

Current wording, `Gayini_deliverables_register.md` line 141:

> *"Every limitation, what it means, and whether it can be fixed. Written so a reader can judge for
> themselves how far to trust each result."*

**Marked REPLACE. Not drafted.** *"Every limitation"* is a promise the page cannot keep — the v10
register is not in the repo, and two Section-1 rows have no locatable source. *"Whether it can be
fixed"* commits to a disposition for each, which several rows do not have.

**Also stale:** the line reads *"EXISTS (limitations register)"*, but **L8 makes T3 a written page**,
`Gayini_what_we_dont_know.md` in the pack root — not the limitations register and not a workbook
sheet. The item list still carries P1's `TEXT_ONLY` resolution and needs updating once the page exists.

## STOP — end of P3
