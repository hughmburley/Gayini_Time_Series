# REPORTS — Gate 1, interim

**Session:** report batch, third concurrent seat · **Date:** 4 August 2026
**Worktree:** `D:\Github_repos\Gayini_reports` on `feature/reports`, from `main` @ `2088fad`
**Builder version:** 1.1 (`EXPECTED_OUTPUT.json:builder_version`)
**DB access:** read-only throughout. No write attempted, none planned.
**Status:** **Gate 1 incomplete — blocked on Node.** Data and figure layers reproduce; the
document layer cannot run. Two defects found, neither affecting a delivered document.

---

## 1. What v1.1 changed, and whether the code does it

Every claim in the v1.1 change block was checked against the code, not the prose. All four hold.

| v1.1 claim | verified |
|---|---|
| §8.4 added | present, lines 309–333 |
| `db`/`gpkg` repointed to `Output/database/` | `paths.json` — correct for this repo |
| `figure_source` split into `figure_source_c1` / `figure_source_d2` | `paths.json` + `config.py:19-20`; `report_figs.py:248` uses `FIGSRC_C1`, `:432` uses `FIGSRC_D2` |
| record span derived | `report_build.js` lines 86, 100, 177, 241–242, 255, 346, 390 all now read `year_first` / `year_last` / `n_years`; `report_data.py:184-186` derives them from `fact_zone_veg_annual` |
| `${'57'}` literal removed | `report_build.js:236` now reads `r.network.nontreed` and `r.network.zoned_nontreed` |
| `EXPECTED_OUTPUT.json` carries version + inventory | `builder_version: 1.1`, `built_with` present |

`paths.js` was **not** changed and did not need to be — it reads only `db`, `units_dir`,
`figs_dir`, `docs_dir`, so the split key does not reach the Node layer.

**The manifest was honestly re-fingerprinted.** Exactly **3 of 32** documents changed between v1.0
and v1.1 — `Bala_15`, `Bala_27ca`, `Dinan_10`, +34 chars each. Those are precisely the three
no-sites paddocks, the only documents that carry the rewritten `${'57'}` sentence. The other 29 are
byte-identical, which independently confirms the record-span change is a text no-op: `0.35` and
`35/100` agree, and the derived span really is 1988–2022.

**The derived network counts reconcile by an independent path.** `dim_plot` gives 57 non-treed /
9 treed / 66 total; a cross-tab of `plot_paddock.in_zone` against `treed_plot_flag` gives 39
non-treed in zone. Both match the sentence the builder now writes. The same cross-tab yields
39 + 9 = **48 plots in zone**, independently confirming handoff §8.2's own figure.

---

## 2. The data layer reproduces exactly

Run against the repo DB with `GAYINI_ROOT=D:\Github_repos\Gayini`:

```
registry OK — 101 rows; 4 constants asserted at 1e-4
  canary OK  rptscope_canary_p1_paddock_floor_bala29ca              40.52
  canary OK  rptscope_canary_p3_composition_share_bala29ca_inland   34.59
  canary OK  rptscope_canary_p5_recovering_parts_bala29ca            2.0
  canary OK  t10_bala29ca_xsec_residual                           -16.80
```

All 32 unit records were rebuilt and compared field-by-field against the delivered
`sample_units/`. **32 of 32 reproduce.** The only differences:

- the four v1.1 additions (`year_first`, `year_last`, `n_years`, `network`), on the 7 paddocks;
- `gap_slope_derived`, on all 7 paddocks, differing in the **15th–16th significant figure**
  (e.g. Bala 29ca 0.8603556258437381 vs 0.8603556258437373, relative ≈ 9 × 10⁻¹⁶).

That is double-precision noise from a different LAPACK ordering in `np.polyfit`, not data drift.
**It cannot reach a document:** `gap_slope_derived` is written at `report_data.py:182` and consumed
by nothing — neither `report_figs.py` nor `report_build.js` references it. It is carried as
evidence, which is consistent with §8.1: the figure draws the *registered* slope, not this one.

**The consequence for Gate 1 is the point.** Because every headline value reproduces, any document
difference is attributable to render inventory alone, exactly as §7.1 sets out.

---

## 3. The figure layer, and the render inventory it actually used

148 figures written (delivered: 133). The change is fully accounted for — 19 new, 4 superseded:

| change | count | detail |
|---|---|---|
| `_maploc.png` → `_mapc1.png` | 4 | Bala 26ca, Bala 28ca, Dinan 10, Dinan 8 now take the C1 path |
| new `_smap.png` | 15 | D2 now resolves for 25 sites, against 10 in the delivery |

`figs_meta.json` records what was drawn:

| paddock | map_kind |
|---|---|
| Bala 26ca, Bala 28ca, Bala 29ca, Dinan 10, Dinan 8 | `c1` |
| Bala 15, Bala 27ca | `locator` |

This matches the Gate 0 inventory exactly. Bala 29ca already used C1 in the delivery, so 4
paddocks switch, not 5.

### D-1 · `built_with.d2_renders_present` is 11; the delivered artefacts say 10

Counted directly from the delivery: `Output/figures/reports/*_smap.png` = **10 files**. So the
inventory recorded in `EXPECTED_OUTPUT.json`, and repeated in handoff §7.1 (*"1 C1 render and 11
D2 renders"*), is **one too many**. The build note §4 says *"ten D2 renders locally"* — correct —
but also *"14 of 25 sites"* fell back, which should be **15**. The manifest reconciled the two
disagreeing prose numbers by picking 11, and picked the wrong one.

Changes no document. It matters because `built_with` is the record used to justify a `CHANGED`
verdict, so it is exactly the kind of number that has to be right. **Correct to 10 D2 / 15
fallbacks when the manifest is re-fingerprinted.**

### D-2 · The caption flag is wired to a file nothing writes

Handoff §7 states: *"`figs_meta.json` records what each map actually rendered and the builder
captions from it."* **The builder does not.** `report_build.js:17` loads it into `FMETA` and no
other line in the file references `FMETA`. The locator caption instead reads a sidecar:

```js
const flg=`${FIG}/${g}_maploc.flags`;
const drawn=has(flg)&&fs.readFileSync(flg,'utf8').trim()==='sites_drawn';
```

`report_figs.py` never writes a `.flags` file — it writes `sites_drawn` into `figs_meta.json`
(lines 254, 337). No `.flags` file exists after a full figure run. **`drawn` is therefore
permanently `false`.**

The July bug — a locator captioned *"White squares are the monitoring sites reported here"* on a
figure that had suppressed them — is fixed, but by making the true branch unreachable rather than
by wiring the record. The failure mode is now mirrored: a locator that **does** draw site markers
is captioned *"they are not drawn here because the stored paddock outline is too simplified to
place them reliably"* — denying something the figure did draw. §7's rule is stated one way round;
this breaks it the other way, and misinforms the reader either way.

**No document in the 32-set is affected.** Both locator paddocks are Bala 15 and Bala 27ca, and
both have `n_sites = 0`, so the caption appends nothing and `figs_meta` agrees (`sites_drawn:
false`). The defect is latent.

**It becomes live in the 52-set.** Of the 14 extension paddocks, only Bala 12, Bala 20 and Mara 7
have a C1 render, so the rest take the locator. Any one of them holding sites that validate inside
its polygon gets a caption denying markers that were drawn.

The fix is one line — replace the sidecar read with `FMETA[g] && FMETA[g].sites_drawn` — but it
changes caption text, so it is **flagged, not applied**. Recommend it before Gate 4.

---

## 4. Blocked: the document layer cannot run

**Node and npm are not installed on this machine.** Confirmed absent from PowerShell and Git Bash
`PATH`, from `C:\Program Files\nodejs`, `C:\Program Files (x86)\nodejs`, `%LOCALAPPDATA%\Programs`,
and via every version manager checked (`nvm`, `fnm`, `volta`, `choco` — none present). `winget` is
available, so `winget install OpenJS.NodeJS.LTS` would resolve it.

Without Node, `report_build.js` cannot run, so **no document is produced and `verify_batch.py`
cannot be run at all** — it fingerprints `.docx` files that do not exist. Gate 1 cannot close.

Still outstanding from Gate 0, unchanged:

| blocker | effect |
|---|---|
| LibreOffice absent | no PDF export; `check_page_fill.py` cannot measure the 70–90% fill band |
| Poppler absent | render QA cannot run |

`matplotlib`, `geopandas`, `pillow` were installed this session. `pandas 3.0.5` and `numpy 2.5.1`
already satisfied the floors and were **not** touched, so the other two sessions are unaffected.

The fill-band check is the one that catches the image-height trap, and that trap is invisible in
LibreOffice anyway — so B2/B3 should be cleared before anything ships to Hugh's screen, not
treated as optional.

---

## 5. Expected `verify_batch.py` outcome, recorded before it is run

Stated now so it cannot be retrofitted to whatever appears.

| documents | expectation |
|---|---|
| Bala 26ca, Bala 28ca, Dinan 10, Dinan 8 | **CHANGED** — map switches locator → C1; caption changes with it |
| 15 site reports gaining a D2 map | **CHANGED** — page-1 figure switches flood-record fallback → D2 crop |
| Bala 15, Bala 27ca, Bala 29ca | **match** — render inventory unchanged for these |
| 10 site reports that already had D2 | **match** |

That is **19 CHANGED, 13 match**. Per §7.1 the diff must then be confined to the map caption and
the site page-1 figure for exactly those 19 units and nothing else; only then is it re-fingerprinted,
with the corrected inventory (5 C1, 25 D2) recorded in `built_with`. **The manifest is not
regenerated to make anything pass.**

---

## 6. Not done

- Node-dependent: documents, `verify_batch.py`, `check_page_fill.py`.
- `test_T8_headline_reproduction.py` — not yet run (§3 item 1).
- Canary failure proof (§3 item 2) — the canaries pass, but have not been shown to *fail*.
- Scope-lock string read from `RPTSCOPE_number_contract.csv` (§3 item 3).
- Annual gap series rebuild from `T10_annual_gap_series.csv` (§8.1) — the file is present.
- §8.4's two checks, re-run rather than assumed (see Gate 0 F1).
- `Gayini_RS_methods_doc_V6.docx` not opened; `WINWORD` PID 31868 still live.
- Nothing committed yet.
