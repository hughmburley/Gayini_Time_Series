# TRACE-1 — which registered numbers can be re-derived

**Gate A. 10 August 2026, registry snapshot 18:57.** Read-only (`mode=ro`, `PRAGMA query_only=1`).
Registers nothing, renders nothing, re-derives nothing, rebuilds no missing producer.

**Rulings applied:** BB, CL, DA, DB, DP, DS. **Named patterns honoured:** I-29, I-42, I-46, I-53,
I-56, I-60.

---

## 1 · The three verdict counts, with coverage

**PRODUCED 117 · ORPHAN_SCRIPT 18 · NO_PRODUCER 21 — over 156 registry rows, all 156 examined.**

Coverage is total: `examined 156 of 156`, asserted by the tracer and re-asserted by re-reading the
CSV it wrote. Every row carries a verdict, a match kind and its search evidence; none was skipped,
sampled or defaulted (I-53).

**The registry is not 142.** The spec says 142; it read **143** at the first query and **156** at the
snapshot above. Two batches landed during the run — a 13-row `spat1_*` batch registered by a
concurrent session, and one `unzoned_*` row. Both numbers are reported rather than reconciled to the
spec, because the spec's figure was correct when written.

**The `spat1_*` batch moved verdict mid-run.** At 18:57 all 13 rows were `NO_PRODUCER` — the string
`spat1_` appeared in no tracked file of any kind. Commit `59d8914` then landed
`scripts/14_diag/SPAT1_stageA_effective_n.py` and all 13 became `PRODUCED`. Nothing about the trace
changed; the repository did. **A trace is only true as of its snapshot**, and this one demonstrates
it inside a single run.

---

## 2 · `NO_PRODUCER` — the deliverable, in full

**21 rows. Every one is `s11_*`, and they are the whole of the S11 registration batch.**

```
s11_bala27ca_area_ha                     s11_dinan10_area_riverine_ha
s11_bala27ca_share_inland                s11_dinan10_area_whole_ha
s11_bala29ca_level_rank_aeolian          s11_dinan10_riverine_part_trend_adj
s11_bala29ca_level_rank_inland           s11_dinan10_riverine_trend_rank_desc
s11_bala29ca_level_rank_riverine         s11_dinan10_water_adjusted_floor_trend
s11_bala29ca_share_aeolian               s11_median_adjusted_floor_trend
s11_bala29ca_share_inland                s11_paddocks_dominance_60_75
s11_bala29ca_share_riverine              s11_paddocks_dominance_75_90
s11_dinan10_adjusted_trend_rank_desc     s11_paddocks_dominance_90_100
s11_dinan10_area_aeolian_ha              s11_paddocks_negative_adjusted_trend
s11_dinan10_area_inland_ha
```

**Hand-verified, not merely classified.** `git grep -n "s11_" -- '*.py' '*.R' '*.r' '*.sql'` returns
nothing. `git grep -l "s11_bala29ca_share_inland"` returns nothing at all — not a script, not a
document, not a table. These 21 values exist in the database and nowhere else in the repository.

**Their `decided_by` cites a document that is not in the repository.** All 21 carry
*"S11 draft §4; verified and registered by CC 5 Aug 2026"*, and
`docs/reference_update/Gayini_S11_spatial_structure_draft.md` is **untracked**. So neither the
number's derivation nor its stated authority would survive a migration.

**This is the I-29 class, and it is twenty-one times larger than the known instance.** I-29 was found
by accident; this was found by asking the question of every row. Under the migration criterion —
nothing migrates which cannot be re-derived inside the new repository from migrated inputs — **these
21 are ineligible as they stand.**

**Nothing was rebuilt.** Per §2.3 the absent derivation is the finding. It belongs in the issues log
as an extension of I-29; opening it there is not this task.

**The near miss.** The `spat1_*` batch was in exactly this state at the snapshot and was rescued by a
producer committed hours later, by a different session, for its own reasons. The pattern that
produces this class is **compute inline in a session, register the result, commit no producer** — and
it is live, not historical.

---

## 3 · `ORPHAN_SCRIPT` — 18 rows, and what is missing in each

| number(s) | resolves into | what is missing |
|---|---|---|
| `ref_paddock_flood_rank_bala26ca / 27ca / 28ca / 29ca` | `scripts/13_pack/PACK1_build_workbook.py` | a **consumer**, not a producer — the workbook reads these to print them. Nothing in the repository writes them |
| `dinan13_xsec_residual` | `scripts/13_pack/PACK1_build_workbook.py` | same shape |
| `three_arm_mean_deficit_unzoned_{inferred,plot}_{aeolian,riverine,inland}` (6) | `scripts/12_zone_stratum/T6_gateE_figures.R` | the figure script names them for labelling; the registration is elsewhere and is not in the corpus |
| `cropping_history_null_count`, `three_arm_standard_at_or_above_count` | `regen_RPTSCOPE_claim_audit.py`, `PACK1_build_workbook.py` | audit and pack consumers only |
| `taskU_denominator_both_valid_ha`, `taskU_denominator_census_x_lidar_ha` | `scripts/14_lidar/U1_register.py` | the script registers **rasters**, not headline numbers — it names the denominators without writing these rows |
| `bala15_xsec_residual`, `bala29ca_improvement_surviving_water_pct`, `rptscope_canary_p3_composition_share_bala29ca_inland` | `test_T8_headline_reproduction.py` and pack consumers | **only the test and its consumers.** A check is not a producer |

**The distinction that matters:** these 18 are not orphaned *scripts*. They are numbers whose only
resolving code **reads** them. A consumer proves the number is used; it proves nothing about where it
came from. For migration purposes these sit with the 21, not with the 117 — **39 of 156 rows have no
demonstrated producer.**

---

## 4 · Reconciliation against T8 coverage

`test_T8_headline_reproduction.py`, run read-only at the snapshot:

```
T8 reproduction: 72 DRIFTED of 81 checked
```

**That message is misleading and the correction matters more than the count.** Reading the loop
(`run()`, lines 277–284): a row with no derivation path is appended to `fails` and `checked` is
**not** incremented. So the 72 are *not among* the 81 — 81 + 72 = 153 = the pinned rows. The honest
statement is:

> **Of 153 pinned numbers, 81 have a derivation path and all 81 reproduce within tolerance. 72 have
> no derivation path in the test. Zero numbers disagree with their recomputation.**

**Every one of the 72 reads `recomputed = NOT RECOMPUTED`. There is not a single numeric
disagreement.** The spec's "14 DRIFTED of 71" has become 72 of 81 — the registry grew and the
recompute function did not follow. That is a coverage gap widening, **not** a correctness problem.

### The four-way split

| | covered by T8 | not covered |
|---|---|---|
| **traced to a producer** (117) | **74** — 74 passing, 0 drifted | **43** |
| **no producer / orphan** (39) | **7** — 7 passing, 0 drifted | **32** |

Two asymmetries are worth naming.

**43 numbers have a producer but no test.** Registration confers no coverage, and nothing enforces the
second step after the first — as §3 anticipated.

**7 numbers have no producer but do have a test.** The inverse gap, and it is the more interesting
one: `bala15_xsec_residual`, `bala29ca_improvement_surviving_water_pct`,
`rptscope_canary_p3_composition_share_bala29ca_inland`, and the four `ref_paddock_flood_rank_bala*`
rows. **The test can re-derive them; no committed script writes them.** The re-derivation exists —
inside a check. Whether that satisfies the migration criterion is a design-seat call, and it is not
made here.

**Do not close the 72 by copying registration logic into the test.** CLAUDE.md requires an
independent second derivation; a copied path passes by construction. Where a genuine second
derivation is needed, that is a separate task, and **it stops here** (§3).

---

## 5 · The three corrections from INVENTORY-1

### `path_exists` is not evidence

Checked live against disk at the snapshot:

| | rows | absent from disk | stored flag disagrees |
|---|---:|---:|---:|
| `raster_asset` | 192 | **0** | **0** |
| `figure_asset` | 351 | **7** | **7** |

The seven are the T12 land-cover figures, **all still reading `path_exists = 1`** eleven days after
the files moved to `Output/review_bundles/tier2_T12_dea_landcover/outputs/`. The flag can report
presence and never absence, because nothing revisits it — the I-42 shape, in a registry column.
**Never consult it; check live.** The rasters are clean, which is worth stating: the defect is in one
table, not in the convention.

### `file_bytes` has never been a computed quantity

**NULL on 171 of 192 raster rows.** The registered total of **13.39 GB** is a sum over the 21
populated rows, and **13.03 GB of it is two LiDAR digital elevation products**
(`raster_taskU_bb0_dem_2009_8058_50cm`, `raster_taskU_bb0_dem_2021_8058_50cm`). The remaining 19 rows
contribute about 0.36 GB, and 171 rows contribute nothing.

**Populated nothing.** Recording only that any "registered volume" figure quoted from this column is
a sum over 11% of the rows, and has never been a measurement of the whole.

### Amendment to I-60 — surface 2 recurring

**Do not open a new entry.** The staging check that reported success while executing nothing is
I-60's second surface, not a new pattern.

> **Amendment (10 Aug 2026).** Ruling DS routes *edits* through a file. The INVENTORY-1 failure was a
> **check** inside a chained command — `git add … && git status --porcelain --cached | head && git
> commit` — where `--cached` is not a valid `git status` option. The check errored, the pipeline's
> exit status was `head`'s, the chain continued, and the commit proceeded unverified. It happened to
> be correct; nothing detected that it had not been confirmed.
>
> **The file-routing rule extends to any chained command whose result is relied upon, not only to
> commands that write.** A check that cannot run is indistinguishable from a check that passed, and a
> pipeline launders the exit code of everything upstream of the last stage. **The exit code is not
> the check; querying the result is** — which is why the commit's contents were confirmed afterwards
> with `git show --stat`, and why that confirmation, not the chain, is what established the commit
> was clean.

---

## 6 · The search method, stated so it can be re-run

**Corpus.** `git ls-files` — tracked files only — filtered to
`{.py .R .r .sql .md .csv .txt .json .ps1 .Rmd}`. **815 files, of which 336 are scripts.** Binary
extensions (`.png .xlsx .xlsm .pptx .pdf .rproj .namespace .description .license .gitignore`) are
excluded because they cannot be grepped as text. **No other exclusions.** Untracked files are outside
the corpus by design — a producer that is not committed is not a producer for migration purposes,
which is exactly why the S11 draft's absence is a finding rather than a blind spot.

**Matching is by identity, never by value (I-56).** Three kinds, in precedence order:

1. **literal** — the `number_id` occurs verbatim as a quoted string literal.
2. **template** — a quoted literal containing `{…}`, `%s`, `%d`, `%f` is converted to a regex with
   placeholders as `.+` and full-matched against the `number_id`. This is essential:
   `build_T8_gateB_dim_headline_number.py:168` writes 6 rows as `f"gap_change_{tag}_{SHORT[cm]}"`,
   and a literal-only search finds none of them.
3. **prefix** — a literal of ≥ 8 characters ending in `_` that the `number_id` starts with; the
   `paste0("stem_", var)` form.

**The template rule is anchored on its fixed prefix, and this was corrected during the run.** The
first implementation required the literal characters to cover ≥ 50% of the id. That threshold is
arbitrary and it split a family that shares one producer: `gap_change_all_inland` (57%) matched and
`gap_change_non_flood_inland` (44%) did not, **though line 168 writes both.** The rule now requires a
fixed prefix of ≥ 8 characters that the id starts with, plus a full regex match. It still rejects
`f"{a}_{b}"` (empty prefix) and SQL fragments (prefix not at the id's head), and it no longer depends
on a tuned constant.

**Registrar test.** A matching script is a producer only if its text also writes the table —
`INSERT/REPLACE/UPDATE/DELETE INTO dim_headline_number`, `to_sql`, or `dbWriteTable`.
`test_T8_headline_reproduction.py` is **excluded by name**: its only match is the `UPDATE` inside its
own `--break` fixture, which mutates a temporary copy. A check is not a producer.

**Verdicts.** `PRODUCED` — at least one registrar matches. `ORPHAN_SCRIPT` — the id resolves into a
script that does not write the table, or `decided_by` names a script absent from the corpus.
`NO_PRODUCER` — the id resolves into no script at all.

### Checks on this task's own checks

**Wrong-verdict fixtures, 3 of 3 pass.** Each returns a wrong *answer* if the tracer is broken; none
crashes it (I-42).

| fixture | expected | got |
|---|---|---|
| synthetic id present nowhere | `NO_PRODUCER` | `NO_PRODUCER` |
| a real registrar withheld from the corpus | not `PRODUCED` | `ORPHAN_SCRIPT` |
| corpus restored | `PRODUCED` | `PRODUCED` |

The second and third are a convergence pair: the verdict must **move** when evidence is removed and
**return** when it is restored. A tracer that had frozen its answer would pass a stability test and
fail this one.

**T8's own fixture fires.** `--break` perturbs one pinned value by +5 on a temporary copy and the
check catches it — `ref_grazed_floor_gap_4pdk_1988_92: pinned=-8.07 recomputed=-13.07`. That is a
wrong-value fixture, not a crash, and it is the reason the 81 passing rows can be believed.

**Assertions are on the written file, not on the logic (I-53).** `TRACE1_number_producers.csv` is
re-read after writing and checked for row count, sort order, uniqueness of `number_id`, a legal
verdict and coverage value on every row, a non-empty `producer_path` on every `PRODUCED` row and an
empty one on every other. All passed.

**Deterministic emission (I-46).** Corpus listing, string-literal sets and output rows are `sorted()`
before use or emission; the CSV is written with an explicit `\n` terminator.

---

## 7 · What this is not

It re-derived nothing, registered nothing, fixed no producer and selected no claim for the article.
The `NO_PRODUCER` list is the deliverable and it is not empty.

**STOP at Gate A.**
