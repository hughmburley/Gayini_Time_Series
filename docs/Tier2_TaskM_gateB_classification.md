# Task M · Gate B — live / superseded classification

*Design-seat draft, 24 July 2026. Input: `taskM_gateA_report.md` + `taskM_gateA_output_inventory.csv`
(1,894 rows). For human approval before Gate C executes.*

**This is a proposal.** Gate B is a human decision. Every rule below is written so CC can apply it
mechanically, but the rules themselves need your sign-off.

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

### Rule 1 — `Latest_results/` is a duplicate export → **superseded**

54 files under `Output/figures/Latest_results/`. **All 54 have a byte-twin at `Output/figures/`
root by filename; none is registered.** It is an export convenience folder, not a product.

- `superseded_flag = 1`, `framing_label` inherited from the root twin
- **Do not register.** Register the root copies instead.
- Do not delete. Additive-only; leave in place or move to `_archive/` in a later task.

*Verified: 54/54 filenames present at root; 0 registered.*

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
| `C1_veg_regime_paddock_*` (44) | 0 reg | `census_8058` | 0 — **register** |

**The 139 `db_build` rows are MODIS / gauge / MER-era, not the ladder.** Gate A confirmed this.
They are superseded as *deck* assets but are legitimate historical products — hence
`framing_label = 'context'`, not deletion.

### Rule 4 — retired 2019 framing → **superseded**

Anything with `period_label = 'pre_vs_post'` or under `Output/rasters/inundation_pre_post/`:

- `framing_label = 'conservation_2019'`, `superseded_flag = 1`
- **31 rasters**, including `raster_00007`
- These must never feed a deck figure. J-F1 is the live 2018 equivalent.

### Rule 5 — Task J → **live**

`Output/rasters/task_J` (12 unregistered rasters), the two J-F figures, the ten gate CSVs:

- `framing_label = 'bank_cut_2018'`, `superseded_flag = 0`, register all

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

## 5. Proposed Gate C scope after this classification

| Action | n |
|---|---|
| Register S-series PNGs already registered — no-op | 11 |
| Register D1 paddock dashboard PNGs | 21 |
| Register `C1_veg_regime_paddock_*` | 44 |
| Register Task J rasters + 2 figures + 10 gate CSVs | 24 |
| Register refugia provenance chain (Rule 8) | ~4 |
| Register 3 census summary CSVs (`Output/` copies) | 3 |
| Label `conservation_2019` superseded | 31 |
| Label `Latest_results/` superseded | 54 |
| Label `db_build` figure rows `context` + superseded | 139 |
| Promote `census_asset.qa_status` → PASS | 1 |
| Create `v_presentation_headlines_live` | 1 |

**~107 new registrations, ~224 labellings.** All additive. No deletes, no builder run.

**Not in Gate C:** the 126 background rasters (D-2), `Output/csv/` (D-3), `scripts/_deprecated/`
(D-4), and the 1,262 `prior` diagnostics/review-bundle files (Rule 7).

That takes "registered nowhere" from 1,534 to roughly 1,430 — but the *current, deck-relevant*
set goes to fully registered, which is what the deck needs.
