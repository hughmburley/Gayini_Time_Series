# REM-1 — remediation of the pack-item defects

**Task:** REM-1 · **Date:** 1–2 August 2026 · **Owner:** RS / CC
**Input:** AUD-1 (`Output/audit/`), `Gayini_deliverables_register.md` v2
**Scope:** the seven AUD-1 render-currency suspects, the two unregistered pack items, a PIN 3 recon.
**Out of scope and deliberately untouched:** the 144 files at `Output/figures/` root, the seven T12
broken pointers, the registry's wrong-generation inversion. PACK-1 assembles by copy, so file
location does not need fixing before the tenth.

**Commits:** `d248e9e`, `3cf023e`, and this report's commit. Straight to `main` per CLAUDE.md
(REM-1's "branch and PR" instruction was stale and was withdrawn by the design seat).

Artefacts, not values, are the record. Numbers below cite the object they come from.

---

## 1. The headline finding: F6 was not a stale render

`T6_A_three_arm_grid` (register v2 **F6**, claim 6) drew its nine per-panel deficit labels from
`fact_three_arm_gap_decomposition WHERE regime_band='ALL'`. **PIN 1 retired that rollup** for the
deficit statistic — pooling the wetness bands reintroduces the drier-skew confound T6 exists to
remove — and the rollup **still returns the superseded values**.

So F6 was a **live render of a retired aggregation**, not a stale render. Re-rendering it reproduced
the wrong numbers byte-for-byte. The remediation Gate B originally specified would have completed
successfully and changed nothing.

This distinction matters beyond F6 and is logged as **I-33**.

### The fix, and the trap inside it

The design seat's stated preference was to read `dim_headline_number`. That covers only **three of
the nine** labels: the registry held per-community pins for the `not_grazed` arm only
(`ref_grazed_floor_*`), and for the two unzoned arms only a per-arm 9-strata aggregate.

The fallback — "band-mean aggregation in the query" — is **ambiguous, and the obvious reading is
wrong**. Three numbers are in play for Aeolian `not_grazed`:

| Aggregation | Aeolian | Standing |
|---|---:|---|
| `regime_band='ALL'` rollup | −19.65 | **retired** by PIN 1 |
| equal-weighted band mean | −11.17 | the `spread_min`/`spread_max` endpoint, **not** the pin |
| **area-weighted band mean** | **−10.46** | **pinned** (`denominator = 'stratum area (non-treed)'`) |

Equal-weighting would have replaced a retired number with a *different wrong number*, on the pack's
most exposed figure, in a way no downstream check could see. The pin's `denominator` column is what
distinguishes them — the reason that column exists.

**Implemented:** area-weighted band mean over `low/mid/high`, weighted by non-treed stratum area from
`census_by_zone_stratum` — the PIN 1 method — with **all nine labels asserted against
`dim_headline_number`, failing the render on drift**.

**Twelve rows registered** (`run_id = rem1_rerender_20260801`, `INSERT OR REPLACE`, additive): six
per-community floor deficits for the two unzoned arms, and six mean-cover equivalents for `T6_B`.
`register_REM1_three_arm_community_pins.py` re-derives the **six already-pinned** `not_grazed` cells
by the same method and **aborts before writing** if any fails to reproduce. All six matched.
`dim_headline_number` 76 → 88.

### Before / after

Full table in the commit message of `d248e9e`; source is
`fact_three_arm_gap_decomposition` via `v_three_arm_gap_decomposition`.

- **Floor (F6): all nine labels keep their sign. No directional claim changes.** The reference
  deficits roughly halve, which if anything strengthens register-v2 claim 1.
- **Mean (`T6_B`): three sign flips**, including `ref_grazed_mean_cover_riverine` — one of the ten
  pinned changes. A figure carrying a sign-flipped unregistered number was the reason these were
  registered rather than left.
- **F6's caption claims re-verified, not assumed:** the inferred-standard arm is above the 14-day
  comparator in **6 of 9** strata and plot-confirmed in **8 of 9**, computed live from
  `regime_band <> 'ALL'`. Both reproduce exactly. **Caption not edited.**

### The two-quantity relabel

The corrected label widened a pre-existing gap between what the figure *shows* and what it *says*:
the eye reads the raw distance between the arm line and the grey median, while the label is that
distance adjusted for water. On Aeolian those are ≈ −32 pp and −10.5 pp.

Because pack figures travel **without their captions** — they are lifted into presentation slides —
the structure had to be inside the rendered image. Every panel now carries **both** numbers, and the
subtitle states plainly that they are different quantities. The trajectory line was **not** changed:
no pinned number covers the series, so altering it would have been analysis rather than remediation.

`raw_gap` is the mean per-year vertical distance between two already-plotted lines — a description of
what is drawn, not a new quantity, so it needs no pin.

**A defect caught inside this change:** the first version hardcoded the raw gap into the subtitle
from an out-of-script estimate, and disagreed with the panel's computed value on the first render.
Subtitle numbers are now computed from the same object the labels use and checked with
`gayini_assert_caption_number()`. This is the I-32 class, found and fixed before commit.

### Siblings

`T6_gateE_figures.R` produces three figures and the defective query fed all three. `T6_B_three_arm_mean`
and `T6_A_three_arm_deck` were corrected, relabelled, re-rendered and re-registered in the same pass.
Fixing F6 alone would have left the script and two of its registered outputs disagreeing — a worse
state, and an invisible one.

A repository-wide scan found **no other live display code** reading the retired rollup. The three
other `regime_band='ALL'` occurrences are correct by design: the T8 builder reading it deliberately
to record it as the superseded value in each caveat, the `is_rollup` flag, and a builder stdout
diagnostic.

### Checks proven to fire

Per CLAUDE.md, a check that has never failed has only been run. All three were fired on deliberate
fixtures and the output recorded:

```
FIRED: [T6 panel labels FIXTURE] 1 of 3 rendered strings do not contain their source value
FIRED: [T6 panel labels FIXTURE] all 4 rendered strings are identical — recycling bug
FIRED: REM-1 assert FAILED: not_grazed / Aeolian ... drawn -19.6500 vs pinned -10.46
```

The third is the important one: **if the retired value is ever drawn again, the render dies.** The
defect is guarded against regression, not merely corrected.

Renders are deterministic — two consecutive runs produced identical checksums.

---

## 2. Six of seven suspects were false positives

Each remaining suspect was resolved by scratch-rendering with `write_and_register_figure()` shimmed
to a plain `ggsave` into a temp directory — **no registry write, no live file touched** (original
mtimes verified intact afterwards).

| Item | Verdict | Resolution |
|---|---|---|
| F1 `T2_E_paddock_trajectories` | byte-IDENTICAL | flag cleared on evidence |
| F2 `T2_E_paddock_trajectories_mean` | byte-IDENTICAL | flag cleared on evidence |
| F4 `T2_F_gap_decomposition` | byte-IDENTICAL | flag cleared; **not** re-stamped |
| M3 `T2_B2_duration_map` | byte-IDENTICAL | bonus — same script |
| M5, M5b, F5 | byte-IDENTICAL | flags cleared on evidence |
| F3, T1 `.png`/`.csv` | byte-IDENTICAL | unchanged |

**Group B needed no re-render.** Both scripts read the constants at render time and print what they
read — `intercept 52.6529 slope 0.548 residual SD 6.6208`, the registered 6 dp values. The 62-second
gap between those renders and the `floor_flood` precision-correction record was harmless, and this now
rests on evidence rather than on trusting the commit message. M5b's own internal check passes at
`max |diff| 0.00478` against a `0.00503` rounding budget.

F4 was deliberately **not** re-rendered despite the instruction: re-rendering would have changed only
the `run_id` while the artefact stayed byte-identical, adding churn and no information.

---

## 3. Gate C — `table_asset` created

`Output/tables/` had **no registry at all**. The two register-v2 pack items among its files were
AUD-1 Category C and blocked from shipping by REP-6.

Putting results tables into `report_asset` would be a category error — that registry is for
documents, and this database is meant to outlive the contract. **`table_asset` was created** on the
existing registry pattern (`path`, `product`, `n_rows`, `checksum_sha256`, `path_exists`,
`qa_status`, `run_id`, `superseded_flag`, `framing_label`, `provenance_note`, `support_level`), so it
reads as an obvious member of the family. Creating a table is additive; nothing modified or dropped.

Registered: `T13_gateC_classification.csv` (item T2, 115 rows) and
`T1_conserved_paddock_comparison.csv` (item T1's table component, 4 rows).

**Which of the `.png` and `.csv` is pack item T1 is a design-seat decision and was deliberately not
made.** Both are now registered; the manifest carries the `.csv` as DECIDE.

**Idempotence tested by convergence, not stability** (CLAUDE.md): on a throwaway copy of the DB, a
re-run was stable, then the input was mutated and the DB **followed** to the new checksum. A
stability-only test would have passed at run 2 and learned nothing. The copy and mutated input were
deleted; the live DB was never involved.

Two limits recorded, not fixed: **I-34** (`table_asset` is not builder-integrated) and **I-35**
(91 of 93 files in `Output/tables/` remain unregistered — deliberately **not** bulk-registered).

---

## 4. Gate D — PIN 3 recon: nothing supports claim 1 as written

Recon only. No replacement computed, none chosen.

Register v2 claim 1 — *"Three of the four conserved paddocks are indistinguishable from grazed ground
across thirty-five years — **within 1.5 to 3.3 percentage points**"* — is the pack's opening sentence.

**The values 1.5 and 3.3 appear nowhere in `dim_headline_number` as a pinned value.** They exist only
inside the `caveat` text of `ref_grazed_floor_gap_3pdk_periodwise`, whose `pinned_value` is **NULL**,
whose `period_label` is the five-period split, and whose `decision_note` reads *"BLOCKED on I-29;
SUPERSEDED by T10 Gate B annual trend `t10_gap_annual_slope_B_excl29ca`. **Not to be revived.**"*

### Every candidate, and why each is a near-miss

| `number_id` | pinned | scope_filter | period_label | support | Why it does not support claim 1 |
|---|---:|---|---|---|---|
| `ref_grazed_floor_gap_3pdk_periodwise` | **NULL** | `ref3=fids 1-3 ; grazed=60` | 5 periods | zone | **Exactly the right scope** — and deliberately unpinned, blocked, superseded, marked not to be revived. This is the register's actual source. |
| `t10_gap_annual_slope_B_excl29ca` | **+0.057** | reference vs 60 grazed | 1988-2022 | zone | **The designated successor.** Right paddocks, right 35 years. But it is a **trend (pp per year)**, not a **distance (pp)**. Supports "no trend towards or away from grazed country"; says nothing about "within 1.5 to 3.3 pp". |
| `t10_gap_annual_r_B_excl29ca` | 0.222 | reference vs 60 grazed | 1988-2022 | zone | Correlation, not a distance. Confirms flatness. |
| `ref_grazed_floor_gap_4pdk_1988_92` | −13.07 | `fids 1-4` vs 60 grazed | **1988-1992** | zone | **Four** paddocks (includes Bala 29ca) over **one** period. Wrong on both counts. |
| `ref_grazed_floor_{aeolian,riverine,inland}` | −10.46 / −4.49 / +1.08 | `treatment_arm='not_grazed'` | all | **stratum** | Community grain, and `not_grazed` is all four reference paddocks — not "three excluding 29ca". Wrong unit and wrong scope. |
| `ref_grazed_mean_cover_*` | −2.32 / +1.41 / +0.45 | as above | all | stratum | Mean cover, not the floor; same scope problem. |
| `bala29ca_*`, `t10_bala29ca_*` | various | Bala 29ca | 1988-2022 | zone/stratum | The **fourth** paddock — the opposite of claim 1's subject. |

### The finding, stated plainly

**No pinned quantity supports claim 1 as written.** The qualitative half — that the three paddocks do
not move towards or away from grazed country over 35 years — **is** supported, by
`t10_gap_annual_slope_B_excl29ca` (+0.057 pp/yr, r 0.222), and register v2's own **F3** caption states
it correctly in those terms. The quantitative half — the "within 1.5 to 3.3 percentage points" range —
rests on a deliberately unpinned five-period number that the project has resolved not to revive.

The register therefore states a supported claim and an unsupported one about the same three paddocks,
one sentence apart. **Resolution is the design seat's.** No substitute is proposed here, because the
nearest pinned quantity measures a different thing and offering it would be exactly the substitution
this recon exists to avoid.

---

## 5. M3 caption check (reported, not adjusted)

Design-seat ruling: M3 ships as-is, conditional on whether register v2's caption describes the file.

Caption: *"For every 25-metre square on the property, how often its ground cover was high. The
pattern follows the channels and low ground, and it crosses paddock fences without noticing them."*

The rendered figure is titled *"vegetation persistence: % of observed years total-veg mean > 70%"*,
subtitle *"'Greenest for longest'. Denominator = veg_valid_years (NA where < 10). All-pixel."*

| Clause | Verdict |
|---|---|
| "how often its ground cover was high" | **Accurate.** = % of observed years with total-veg mean > 70%. |
| "For every 25-metre square" | **Approximate.** The census grid is 24.970268 m (CLAUDE.md's 0.238% trap). Plain-language rounding, but it is the nominal, not the grid. |
| "it crosses paddock fences without noticing them" | **Not shown.** **No paddock boundaries are drawn on the figure.** The claim is well supported elsewhere (L-01), but a reader cannot see it here. |
| "The pattern follows the channels and low ground" | **Not demonstrated.** No channel or elevation layer is drawn; plausible from the pattern, but the figure does not show it. |

One further observation, not a caption matter: the colour scale saturates — large areas sit at 100%
and render as flat yellow, compressing the very variation the caption describes. This is presumably
what the T7 recolour was for. The file also carries a small NA hole (`veg_valid_years < 10`) that the
caption does not mention.

**Not adjusted.** Two of four clauses describe things the figure does not show, which is a caption
problem and the design seat's to fix.

---

## 6. Gate E — manifest delta

`Output/audit/AUD1_manifest_delta_REM1.csv` — **12 rows**, each carrying the **reason** it changed
state so PACK-1 can tell the three cases apart:

| Reason | Rows | Items |
|---|---:|---|
| `FLAG_WAS_WRONG` | 6 | F1, F2, F4, M5, M5b, F5 — verified byte-identical |
| `DEFECT_FIXED` | 3 | F6, plus siblings `T6_B` and `T6_A_deck` |
| `NEWLY_REGISTERED` | 2 | T2, and item T1's `.csv` component |
| `DESIGN_SEAT_RULING` | 1 | M3 ships as-is |

Net effect on the pack: **M3 moves the pack from 15 shippable items to 16**, and eight items move off
HOLD. PACK-1 consumes `AUD1_pack_manifest_draft.csv` plus this delta.

---

## 7. Concurrency

TaskU ran alongside REM-1 throughout and advanced **U1 → U2 → U3**. Its writes were confined to
`Output/rasters/task_U/`, `Output/figures/task_U/` and `Output/tables/taskU_*`; REM-1 stayed out of
all three. `figure_asset` 286 → 287 is accounted for entirely by `figure_u3_sensor_step_change`, and
**zero duplicate paths** exist after REM-1's three replacements (keyed on `figure_asset_id`).

`Output/tables/` grew 83 → 93 during AUD-1/REM-1, all TaskU — which is why I-35 quotes both counts.

---

## 8. Issues logged

- **I-33** — mtime-based render currency is a screening tool: 6 of 7 false positives, and the one
  real defect was invisible to it. QA-2b is rebuilt on render-and-diff plus reading the query.
- **I-34** — `table_asset` is not builder-integrated; joins the post-build manual registration list.
- **I-35** — `Output/tables/` provenance gap: 91 of 93 unregistered, deliberately not bulk-registered.

Also carried from Gate 0: `test_T8_headline_reproduction.py` reports `2 DRIFTED of 71`, both TaskU
rows with **no recompute path** — a coverage gap, not value drift. Exit 0; 69 of 71 reproduce.
Nothing in REM-1's scope depends on them. **A test that silently stops covering new rows will
eventually pass while missing the thing that matters.**

---

## 9. Acceptance

- [x] Producing script located for all seven; inline-constant scripts flagged (4 of 4 Group A, 0 of 2 Group B)
- [x] `test_T8_headline_reproduction.py` passes before any re-render (exit 0)
- [x] Group B verified against registered constants; **not** re-rendered — values already matched
- [x] Group A: F6 fixed with a complete before/after; F1/F2/F4 cleared on byte-identical evidence
- [x] F6's "six of nine" claim re-verified live and stated explicitly; caption untouched
- [x] New renders pass the QA-2a guard — now **wired into** both label paths, not merely postdating it
- [x] T2 and T1 `.csv` registered, additive, new `run_id`, in a new `table_asset`
- [x] PIN 3 recon reports every candidate without choosing one
- [x] Manifest delta emitted, with a reason per row
- [x] No file moved or deleted; no registry row deleted; builder not re-run
- [x] Change report committed
