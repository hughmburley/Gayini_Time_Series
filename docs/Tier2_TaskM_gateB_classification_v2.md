# Task M · Gate B — live / superseded classification (v2, post-execution)

*Design-seat draft, 24 July 2026. Input: `taskM_gateA_report.md` + `taskM_gateA_output_inventory.csv`
(1,894 rows). **Corrected 24 July after Gate C execution (`934eac7`).***

## v2 — five counts in v1 were wrong

Gate C applied v1's rules as written and reported five mismatches against disk. **All five are
confirmed. The errors were mine, in the Gate B document, not CC's.** CC applied each rule
literally and declined to infer past it — the correct behaviour.

| # | v1 claim | Actual | Effect |
|---|---|---|---|
| 1 | "all 54 `Latest_results/` have a root twin" | **15** at `Output/figures/` root | 39 left `framing_label = NULL` — correct |
| 2 | "register 44 `C1_veg_regime_paddock_*`" | **21 PNG + 21 PDF** | 44 counted PDF halves, contradicting my own Rule 2 |
| 3 | "S-series 15+15" | **10 PNG + 10 PDF** at root (+10 LR copies) | already registered |
| 4 | "Rule 4 → 31 rasters" | predicate matches **32** | `raster_00095` (MER `pre_vs_post`) sits outside the directory |
| 5 | "the two J-F figures" | **four** exist | J-F3, J-F4 live but unregistered |

**Root cause of #1, worth naming.** I matched `Latest_results/` filenames against *any* non-LR
figures path, then reported the result as if it meant the root directory. The twins are spread
across four locations:

| Twin location | n |
|---|---|
| `Output/figures/report_figures` | 20 |
| `Output/figures/dashboards` | 19 |
| **`Output/figures/` root** | **15** |
| `Output/figures/_archive/taskL_pre_rollout_20260722` | 12 |

And 12 of the 54 have twins in **two** locations simultaneously (all D1/D2 dashboards, twinned in
both `dashboards/` and `_archive/`). So "the root twin" was never a well-defined object.

This is the same failure as the refugia error in miniature: a check was run, the result was
restated imprecisely, and the restatement became the instruction. Corrected in Rule 1 below.

---

## 0. The correction Gate A forced

**Spec §1.5.2 was wrong, and so was my analysis behind it.**

The floor claim was never about `veg_p05 >= 50`. The committed `green_at_floor()` computes
**`100 × PV ÷ total_veg > 50`** — the *green share of remaining cover*, read paired in the season
that sets each pixel's total-veg 5th percentile. EPSG:3577, 30 m, 0.09 ha/px, n = 959,833.

"Majority-green floor" means **most of what is there is green**, not **cover exceeds 50%**.
Different question. That is the 6.34× gap — not a grid artefact.

| | Value | Status |
|---|---|---|
| 71,755 px × 0.09 ha (native 3577) | **6,458 ha** | internally consistent |
| 71,755 px × 0.0623512 ha (8058 pixel) | 4,474 ha | mismatched conversion — the original error |
| "~4,300 ha" as published | ≈ the 4,474 figure | roughly right, wrong pixel area |
| My "40,935.8 ha" refutation | — | **answering a different question; withdrawn** |
| "97% dead at median" | green-fraction median **3.03%** | **correct** for green share, not `veg_p50` |

I called the companion claim "false". It is not. My refutation was itself an interpretation
error — the exact failure §0.2 exists to prevent. Recorded here rather than quietly dropped.

**What genuinely remains broken is the paper trail**, and CC's `PARTIAL` verdict is right:

- No committed script performs the `>50` count or the hectare conversion — done interactively
  into scratch, by explicit instruction ("not a registered product")
- Nothing in the chain is registered: the CSV, the substrate CSV, and two ~400 MB native-3577
  FC stacks are all unregistered and untracked in git
- **A rebuild from git alone would not reproduce the number**

**D8 verdict: the result stands; the provenance does not.** Gate C closes the provenance.

---

## 1. Classification rules

Applied to all 1,894 inventory rows. Two fields: `framing_label`, `superseded_flag`.

### Rule 1 — `Latest_results/` is a duplicate export → **superseded** *(CORRECTED)*

54 files under `Output/figures/Latest_results/`. None is registered. It is an export convenience
folder, not a product.

**v1 said all 54 twin to `Output/figures/` root. Wrong — only 15 do.** The twins live in four
places (see v2 header), and 12 files twin to two places at once.

Corrected rule, as Gate C applied it:

- All 54 → `superseded_flag = 1`
- `framing_label` inherited **only** where a single unambiguous twin exists at
  `Output/figures/` root — **15 files**
- The other **39** → `framing_label = NULL`. **Do not infer a label from a twin in
  `dashboards/`, `report_figures/`, or `_archive/`** — those are different products with
  different statuses, and a wrong label is worse than none.
- Do not register. Do not delete.

*Verified against `taskM_gateA_output_inventory.csv`: 15 root twins, 20 in `report_figures`,
19 in `dashboards`, 12 in `_archive/taskL_pre_rollout_20260722`; 12 files multi-twinned.*

**Open for a later task:** the 39 unlabelled files need a per-source decision. Not a deck blocker.

### Rule 2 — PNG is canonical, PDF is a companion → **live, unregistered**

Every S-series, D1 and D2 figure exists as a PNG + PDF pair. Only PNGs are registered.

- PNG → `superseded_flag = 0`, register
- PDF → `superseded_flag = 0`, `framing_label` same as its PNG, **do not register**
- Rationale: one figure = one file = one slide. The PDF is a print artefact of the same figure.

*Verified: D2 = 57 png + 57 pdf, 57 sites; D1 = 21 png + 21 pdf, 21 paddocks; S-series = 15+15.*

### Rule 3 — ladder generation split by `run_id` and date

| Set | n | `framing_label` | `superseded_flag` |
|---|---|---|---|
| `gateE_20260721` figures (S-series) | 11 reg | `census_8058` | 0 |
| `d2_site_dashboard_batch_20260720` | 57 reg | `plot_support` | 0 |
| `db_build_20260701_114458` figure rows | 139 | `context` | **1** |
| D1 paddock dashboards (21 png) | 0 reg | `plot_support` | 0 — **register** |
| `C1_veg_regime_paddock_*` (**21 png**, not 44) | 0 reg | `census_8058` | 0 — **register** |

*(**CORRECTED.** v1's "44" counted the 21 PDF companions, contradicting Rule 2. Register the
21 PNGs only. Same error would have applied to D1 had v1 stated a number there.)*

*(**CORRECTED.** The S-series is **10 PNG + 10 PDF** at `Output/figures/` root, not 15+15 —
plus 10 duplicate PNGs in `Latest_results/` covered by Rule 1. All 10 root PNGs were already
registered by `gateE_20260721`; the registration line is a no-op.)*

**The 139 `db_build` rows are MODIS / gauge / MER-era, not the ladder.** Gate A confirmed this.
They are superseded as *deck* assets but are legitimate historical products — hence
`framing_label = 'context'`, not deletion.

### Rule 4 — retired 2019 framing → **superseded**

Anything with `period_label = 'pre_vs_post'` or under `Output/rasters/inundation_pre_post/`:

- `framing_label = 'conservation_2019'`, `superseded_flag = 1`
- **32 rasters** (v1 said 31), including `raster_00007` and `raster_00095` — the latter is the
  MER `pre_vs_post` product, which carries the predicate but sits **outside** the
  `inundation_pre_post/` directory
- These must never feed a deck figure. J-F1 is the live 2018 equivalent.

**Rule 4 is too narrow and must be widened.** Gate C reported four further MER rasters labelled
`pre_conservation` / `post_conservation` that are the *same retired framing* but miss the literal
predicate. They were correctly left `NULL`. Extend the predicate to catch
`pre_conservation` / `post_conservation` as well, and re-run the labelling — additively.

### Rule 5 — Task J → **live** *(CORRECTED)*

`Output/rasters/task_J` (12 unregistered rasters), the J-F figures, the ten gate CSVs:

- `framing_label = 'bank_cut_2018'`, `superseded_flag = 0`, register all

**There are four J-F figures, not two** (v1 said two, and spec §C.2 supplied verbatim captions
for J-F1/J-F2 only, so Gate C correctly registered only those):

| Figure | Path | Status |
|---|---|---|
| J-F1 difference map | `Output/figures/maps/task_J/` | registered |
| J-F2 placebo ladder | `Output/figures/maps/task_J/` | registered |
| **J-F3 the law** | `Output/figures/plots/task_J/` | **live, unregistered — needs a caption** |
| **J-F4 annual series** | `Output/figures/plots/task_J/` | **live, unregistered — needs a caption** |

J-F3 is the flow-law figure (R² = 0.864) and J-F4 the annual series. Both are live Task J
products. **Captions required before registration** — they carry the same causal-inference risk
as J-F1/J-F2 and must not go in uncaptioned.

### Rule 6 — inundation background sensitivity sets → **live, unregistered, not deck**

126 unregistered rasters under `Output/rasters/inundation_background/` in three variants
(`background_strict_1989_2014`, `background_pre2015_sensitivity_1989_2015`,
`recent_landsat_only_2014_2023`).

- `framing_label = 'context'`, `superseded_flag = 0`
- **Do not register in this task.** These are sensitivity-analysis intermediates, not products.
  Registering 126 rasters inflates the registry without improving traceability.
- Flag for a later decision on whether one variant is canonical.

### Rule 7 — `_archive/`, `review_bundles/`, `diagnostics/` → **leave alone**

- `Output/_archive/` (138 files) — already archived. `superseded_flag = 1`, no other change.
- `Output/review_bundles/` (366) — frozen point-in-time snapshots. `superseded_flag = 1`.
  Their contents intentionally duplicate live docs; they are the audit record.
- `Output/diagnostics/` (309) — working scratch. Leave `NULL`, unclassified, **except** the
  refugia artefacts in Rule 8.

### Rule 8 — the refugia provenance chain → **register, live**

Close the D8 paper trail:

- `Output/diagnostics/ondisk_review_20260720/refugia_area_check.csv` → register,
  `framing_label = 'census_8058'`, `superseded_flag = 0`
- The green-fraction substrate CSV → register alongside it
- The two ~400 MB native-3577 FC stacks → register in `raster_asset` with
  `framing_label = 'census_8058'`; they are the source and are currently invisible to git

**Required in the registration note, verbatim:**

> Variable: `100 × PV ÷ total_veg > 50` (green share of remaining cover), read paired in the
> season setting each pixel's total-veg 5th percentile. EPSG:3577, 30 m, 0.09 ha/px, support
> ≥ 50 seasons, n = 959,833. Count 71,755 px = 6,458 ha native-grid. NOT `veg_p05 >= 50`.

**Also add a committed script** performing the `>50` count and hectare conversion, so the number
rebuilds from git. Without it the chain stays `PARTIAL` no matter what is registered.

#### Rule 8 outcome — D8 provenance CLOSED

Gate C delivered `scripts/05_ground_cover/04_taskM_green_at_floor_area.R`, writing
`Output/tables/taskM_green_at_floor_area.csv`. It exceeds what was specified in two ways worth
recording:

1. **The definition cannot drift silently.** The script extracts the `green_at_floor()` block from
   `03_h2_seasonal_gate_and_diagnostics.R` **by marker at run time** and halts rather than compute
   under a changed definition. The guard fired clean.
2. **The number is not quotable without its definition.** Every output row carries `variable`,
   `threshold`, `mask`, `support_rule`, `grid_epsg`, `pixel_area_ha`. A figure lifted out of this
   table without them is incomplete by construction.

Reconciled against the traced scratch artefact at **difference 0** on `n_valid_floor_px`,
`n_majority_green_px_gt50`, and `area_ha_native_30m_3577`.

**D8 status: the result rebuilds from git.** Whether it belongs on a slide is a separate question,
untouched — and it stays out of this deck cut regardless (§3).

---

## 2. Decisions you need to make

### D-1 · The three census summary CSVs exist in two locations

`Output/census/summaries/` and `docs/census_summaries/`.

**Recommendation: `Output/census/summaries/` is canonical.** `Output/` is the product tree;
`docs/` is documentation. Register the `Output/` copies; mark the `docs/` copies
`superseded_flag = 1` and leave them in place.

### D-2 · Should the 126 background rasters be registered?

**Recommendation: no** (Rule 6). They are intermediates. Registering them makes the registry
less useful, not more.

### D-3 · `Output/csv/` — 72 files, all prior, none registered

Not inspected in detail. **Recommendation: leave `NULL`** and defer. None is current, so none
feeds this deck cut.

### D-4 · `scripts/_deprecated/` (1 file) vs missing `scripts/archive/`

**Recommendation: fix in a separate task.** It is a convention violation, not a deck blocker,
and Task M is already four gates.

### D-5 · **NEW — `Output/` is gitignored (`.gitignore:33`)**

Raised by Gate C. The standing rule says *"`Output/` is the record"* — but `Output/` is not
under version control, so **the record is currently untracked**.

This is the refugia failure one level up again: Rule 8's script is committed, but the substrate
it reads is not, so "rebuilds from git" holds only if the inputs survive independently.

**Recommendation: do not track `Output/` wholesale.** It holds ~400 MB native-3577 FC stacks and
270 rasters. The workable line is the architecture already in use, stated explicitly:

- **Text artefacts in git** — add `.gitignore` exceptions for `Output/tables/*.csv`,
  `Output/census/summaries/*.csv`, and `Output/diagnostics/**/*.md`
- **Binaries registered in the DB with SHA-256** — never in git

Gate C force-added six small text artefacts following the `f6f78a0` precedent. That precedent
should become the rule rather than staying a precedent.

**Human decision required.** Until it is made, "Output/ is the record" is aspirational.

### D-6 · **NEW — a result living only in `docs/`**

`docs/census_summaries/census_green_at_floor_farm_distribution.csv` is a **result** with no
`Output/` counterpart — a direct violation of the new standing rule, and the only known instance.

**Recommendation: move it to `Output/census/summaries/`, then register it.** Labelling it
superseded is not enough; it has nowhere to be superseded *to*.

---

## 3. What Gate A changed in the deck plan

Three corrections to `Gayini_deck_rewrites_all_pixel_cut_REVIEW.md`:

1. **§4 is wrong.** It says neither floor number reproduces. The number reproduces; the paper
   trail does not. Rewrite §4 to state the definition and the provenance gap.
2. **The floor claim is not in the deck.** CC searched all 72 slide + notes XML parts:
   **0 hits** for `4,300` / `6,460` / `97%` / `≈5% of the farm` / `refugia` / `majority-green`.
   My §1.6 premise misread the stocktake — line 83 lists it under *"What is NOT in the deck but
   should be."* **There is no deck slide to fix.**
3. **Slides 30/31 now hold.** Paddock dashboards moved 4/21 → **21/21**. The "all 21 paddocks"
   claim is true. Site dashboards 5 → 57 of 66 (57 non-treed — the claim needs the denominator
   fixed, as drafted). Stratum unchanged at 3 of 9 — supports the recommendation to cut 32/33.

---

## 4. The finding that matters most for Adrian

**No deck slide can be traced to a source file by checksum.** Gate A: 131 ladder-named figures on
disk, 11 registered; **0 of 27 embedded slide images are byte-identical to anything on disk.**

This is the "backed up by code and files on disk" requirement failing at the last step. Every
number on a slide may be correct and still not be *demonstrably* correct, because the image on
the slide cannot be matched to the file that produced it.

**Cause is benign** — PowerPoint re-encodes images on insert, so byte-identity was never going to
hold. **Consequence is not.** The fix is forward-looking: figures registered before insertion,
and slides rebuilt from registered assets. That is a deck-build discipline question, not
something Gate C can retrofit.

**Recommendation:** accept this for the Adrian cut. Traceability runs *figure file → registered
asset → number*, and the slide cites the figure by name. Byte-matching the embedded image is a
stricter standard than the deliverable needs.

---

## 5. Gate C — EXECUTED (`934eac7`)

Superseding v1's estimate. **Actual: 75 registrations, 239 labellings** against v1's
~107 / ~224. The gap is the five count errors in the v2 header — v1 over-counted registrations
(C1's PDFs, the S-series no-op) and under-counted labellings.

| Delivered | |
|---|---|
| Registrations | **75** |
| Labellings | **239** |
| Nullable provenance columns added | 11 |
| `census_asset.qa_status` | REVIEW → **PASS** |
| New: `taskM_headline_source` | 9 rows |
| New: `v_presentation_headlines_live` | created |
| `v_presentation_headlines` | **unaltered** — still 9.23 pp, D7 open |
| DB SHA-256 | `a8a92fb5…` → `096c5a43…` |
| Builder run? | **No.** `census_stratum` still 11 rows / 1,080,157 px |
| Idempotent? | Yes — re-running `execute` inserts 0 |

### Two deliberate deviations by Gate C — both accepted

1. **`C.1` columns extended to `report_asset`.** Rules 5 and 8 and decision D-1 all classify CSV
   assets, which live in `report_asset`. Without the extension those rules could not be applied.
2. **D-1 implemented asymmetrically.** `Output/` copies registered; `docs/` duplicates marked
   superseded **in the `Output/` classification record** rather than registered as `docs/` paths.
   Registering `docs/` paths would cut against the new standing rule. This is the better reading
   of D-1 than the one I wrote.

### Still open after Gate C

| Item | Status |
|---|---|
| **D7** | `v_presentation_headlines` still publishes 9.23 pp (retired framing) |
| **D-5** | `Output/` gitignored — human decision |
| **D-6** | `census_green_at_floor_farm_distribution.csv` lives only in `docs/` |
| **Rule 1 residue** | 39 `Latest_results/` files unlabelled |
| **Rule 4 widening** | 4 MER `pre_conservation`/`post_conservation` rasters left NULL |
| **J-F3 / J-F4** | live, unregistered, need captions |
| **`CLAUDE.md:40`/`:44`** | untouched by design; **the human's `CLAUDE.md` edit is uncommitted** |
| **Established facts** | frames D8 as a *grid mismatch*; Gate B establishes it as a *variable difference*. Gate B wins — now two files needing the same correction |

### The `CLAUDE.md` / established-facts disagreement

Both documents describe D8 as a grid mismatch — 71,755 px converted with the wrong pixel area.
That was the diagnosis before Gate A traced the artefact. **It is not the whole story:** the
deeper difference is the *variable*. `green_at_floor()` computes green share of remaining cover
(`100 × PV ÷ total_veg > 50`), not total cover ≥ 50%.

The grid mismatch is real and explains the 6,458 ↔ 4,474 pair. It does **not** explain the gap to
any `veg_p05`-based figure, because that is a different question entirely.

Both files need the same correction, and CC correctly declined to make it.
