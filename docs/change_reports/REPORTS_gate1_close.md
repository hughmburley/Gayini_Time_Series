# REPORTS — Gate 1 CLOSED · builder v1.3

**Session:** report batch, third concurrent seat · **Date:** 4 August 2026
**Worktree:** `D:\Github_repos\Gayini_reports` on `feature/reports`, from `main` @ `2088fad`
**Builder:** v1.1 (inherited) → **v1.3** (this session)
**DB access:** read-only throughout — `mode=ro`, `PRAGMA query_only=1`. No write attempted.

**Gate 1 result:** `32 match · 0 changed · 0 missing`, after a documented re-fingerprint.
`lint_builder.py`: `0 error · 1 warn`. Render QA: no regression, 0 pages at Word-spill risk.

> `verify_batch.py` proves nothing moved between two builds. It does **not** prove any number
> is right. That is Gate 2. This section reports reproduction, not verification.

---

## 0. Code ownership

Accepted. Versioning, defect fixes, re-fingerprinting, parameterisation and tooling are now
this seat's. Page model, register, caption assertions, degradation rules, the 32-vs-52 set and
the Bala 29ca marginal wording remain design-seat and are listed in §7.

**There is no v1.2.** The transfer note names v1.2 as the last drop and the baseline. The only
delivery on disk is `docs/reports/Gayini_Paddock_reports_V2/`, whose `EXPECTED_OUTPUT.json`
reads `builder_version: 1.1` and whose handoff header reads *"Version 1.1 · second issue"* — as
does the design seat's own copy at `docs/reports/Gayini_report_batch_CC_handoff_v1.1.md`. So the
actual parent of this work is **1.1**, and 1.2 is either unissued or was never written to disk.
I have numbered this session **1.3** as instructed rather than 1.2, which leaves the gap
visible instead of silently closing it. Flagged, not resolved.

## 1. Toolchain — all four blockers cleared

Node 24.19.0 · npm 11.17.0 · `docx` 20 packages · LibreOffice · Poppler 25.07 ·
matplotlib / geopandas / pillow. `pandas 3.0.5` and `numpy 2.5.1` already met the floors and
were **not** touched, so the other two sessions are unaffected.

---

## 2. Defects fixed

Six inherited, one of my own. Every fix is proven to fire; none was accepted on inspection.

### D-1 · `built_with.d2_renders_present` overstated by one
Delivered `*_smap.png` = **10**; the manifest and handoff §7.1 both said 11, and the build note
said *"14 of 25"* fell back where 10 renders means **15**. The manifest reconciled two
disagreeing prose numbers by picking the wrong one. `built_with` is now **counted off disk** by
`fingerprint_batch.py`, so it cannot drift from the build it describes.

### D-2 · A caption branch that could not fire
`report_build.js` read a `{slug}_maploc.flags` sidecar that `report_figs.py` never writes, so
`drawn` was permanently false. Now reads `FMETA[g].sites_drawn` from `figs_meta.json`, which is
the record §7 always said it used.

**The negative control is worse than my Gate 1 characterisation.** With the old logic and
`sites_drawn=true`, the document does not merely omit the sentence — it prints *"they are not
drawn here because the stored paddock outline is too simplified to place them reliably"* **on a
figure that drew the markers.** An assertion to a client that is the opposite of the truth.

```
pre-v1.3 (negative control)      v1.3
  sites_drawn=True  -> FAIL        sites_drawn=True  -> OK
     present=False                    present=True
     contaminated=True                contaminated=False
  sites_drawn=False -> OK          sites_drawn=False -> OK
  exit 1                           exit 0 · both caption branches fire · 2 pass
```

`tests/test_caption_branches.py` drives the real builder over a fixture and asserts both
captions. **No document in the 32-set changed** — both locator paddocks have zero sites — so
this is a latent fix. It becomes live in the 52-set. *Client-facing text changes when it fires:
flagged for ratification per the transfer note, not held behind it.*

### D-3 · The C1 lookup used the wrong slug
`slug()` maps `/`→`-`, but the renders are named by
`10_build_veg_regime_checkerboard.R:209`, `gsub("[^A-Za-z0-9]+","_")`. So `Bala 8/11` was looked
up as `Bala_8-11` while the file is `Bala_8_11`, and the paddock silently fell to the locator
**even though its C1 render exists**. Finding someone else's file and naming your own are
different jobs; one slug cannot do both. Added `c1_slug()` for source lookup only.

Checked across all 64 `zone_name`s: no collisions under either rule, and they disagree on
exactly three — `Bala 7/10`, `Bala 8/11`, `Bala 14/16`. No effect on the 32-set (no slash-named
paddock is in it); it recovers a map in the 52-set.

### D-4 · Cell size typed into client prose
Four sites read `25 m` / `25-metre`. `PIXEL_SIDE_M` is **24.970268** — the value CLAUDE.md warns
inflates areas by 0.238% when nominalised. Now derived from `gayini_params` and rounded for the
reader, so prose and constant cannot drift. Text is unchanged (`round(24.970268) = 25`).

**Verified independently, because its own guard is dead:** `gayini_params` warns
*"DB not found … self-check skipped"* — it resolves the DB by a **relative** path, so the
self-check silently skips whenever it is imported from anywhere but the repo root. I checked the
constant against `raster_asset` directly: `resolution_x` for the EPSG:8058 census rasters is
24.970268001081525 / …827, matching to 1e-6. **The constant is right; its guard is another check
that cannot fire.** Belongs in the issues log — it is not this module's to fix.

### D-5 · The record span, still typed in the figure layer
v1.1 derived the span in `report_build.js` prose but left `f'35-year average …'` at
`report_figs.py:75`. A figure annotation is client-facing text too. Now `f'{len(yr)}-year …'`.

### D-6 · `check_page_fill.py` could not run, could not scan, and could not fail
Five defects in thirty lines, in the one check that sees the image-height trap:

| | |
|---|---|
| `SOFFICE = "/mnt/skills/public/docx/scripts/office/soffice.py"` | the design seat's own sandbox path, against PLACEMENT.md's *"nothing else hardcodes a path"* |
| `glob("*_DRAFT.docx")` with no args | matches nothing this batch produces — it would scan **zero pages and exit 0** |
| never read `DOCS_DIR` | |
| wrote PDFs and PNGs into the CWD | |
| no exit code | a fill failure could not fail a batch |

Rewritten: resolves soffice/pdftoppm, defaults to `DOCS_DIR`, uses a temp dir, exits non-zero.
**Measurement logic byte-for-byte unchanged** — non-white < 750, rows > 10 px, `rows.max()/height`.

### D-7 · Mine, caught by verification
Deriving the cell size, I put `${Math.round(r.pixel_side_m)}` inside a **single-quoted** JS
string, where it is not a substitution. The characters `${Math.round(r.pixel_side_m)}-metre`
rendered into two client documents. No error, no exception — silent.

It surfaced because the run produced **21 CHANGED against my recorded prediction of 19**, and I
diffed rather than re-fingerprinted. **Had I regenerated the manifest to make verify pass,
template source would have shipped to a client page.** This is the whole argument for the rule.
Now covered by `lint_builder.py` check D, proven to fire on the reintroduced defect.

---

## 3. Gate 1 — reproduction

**The prediction was recorded in `REPORTS_gate1_interim.md` §5 before the build ran:** 19
CHANGED, 13 match. After fixing D-7 the run produced **exactly that**, and the CHANGED set was
exactly the predicted units — 4 paddocks gaining a C1 map, 15 sites gaining a D2 map.

Per handoff §7.1 step 1, every CHANGED document was diffed and the change classified:

| units | change | anything else? |
|---|---|---|
| Bala 26ca, Bala 28ca, Dinan 8 | map caption: locator → C1 | none |
| Dinan 10 | map caption, **plus** the v1.1 network sentence | none — the second is a v1.0→v1.1 change, present because the only documents on disk to diff against are v1.0 |
| 15 site reports | page-1 caption: flood-record fallback → D2 crop | none |

**No number moved in any document.** The unit records were also compared field-by-field against
the delivered `sample_units/`: 32 of 32 reproduce, differing only in the v1.1 additions and in
`gap_slope_derived`, now removed (§4).

Only then was the manifest regenerated, by a script that **refuses without `--confirm`**:

```
32 match · 0 changed · 0 missing  (expected 32, built 2026-08-04)
re-fingerprinted 32 documents at version 1.3
19 fingerprint(s) moved · 0 document(s) new
inventory: 5 C1 · 25 D2
```

Render inventory recorded in `built_with`: **5 C1 · 25 D2**, against the delivery's 1 C1 · 10 D2.

---

## 4. `gap_slope_derived` — removed

Written at `report_data.py:182`, read by nothing — not the figure layer, not the document
layer — and differing in the 15th significant figure between machines through `np.polyfit`'s
ordering. It was noise in every unit-record diff and could not reach a page. The §8.1
reconciliation derives the slope explicitly from `Output/tables/T10_annual_gap_series.csv`
(present, 4,679 bytes), where it will have a reader and a stated method. **That is Gate 2 and is
not done.**

---

## 5. New tooling — and each check proven able to fail

`lint_builder.py` generalises the pre-batch grep past prose, as the transfer note asked. Four
checks. **Every one was tested by reintroducing the defect it targets.**

| check | targets | proven |
|---|---|---|
| **A prose** | digit literals in client text | fired on `25`/`35`; `1e-4` excluded as a contract tolerance after a false positive |
| **B metadata** | counts recorded *about* the build | fired on `d2_renders_present=11` |
| **C reachability** | a companion file read but never produced | **first version did not fire** — see below |
| **D interpolation** | `${…}` in a quoted JS string | fired on D-7 |

**Check C failed its own test, which is why it was tested.** The first version matched the
extension inside the read call. The real defect builds the path on one line and uses it via a
variable on the next, so a call-site check cannot see it. Rewritten to be empirical — every
extension named in a path-like literal must appear in what the batch produces — after which it
fired correctly. A syntactic check for this class gives false confidence.

`fingerprint_batch.py` — regenerates the manifest, `--confirm` mandatory, inventory counted off
disk. `tests/test_caption_branches.py` — drives the real builder over a fixture.

Remaining lint output is **1 WARN**: `report_figs.py:370`, the `>20` / `>5` flood-frequency
colour cutoffs. Those are band thresholds — design-owned, and band definitions are an open
Adrian-gate item — so they are flagged, not changed.

---

## 6. Render QA — no regression, and a claim that was never true

83 pages measured in both builds with the same instrument.

| | delivered v1.0 | this build v1.3 |
|---|---|---|
| pages | 83 | 83 |
| min · median · max | 64% · 79% · 87% | 64% · **80%** · 87% |
| outside 80–92% (script band) | **42** | **42** |
| outside 70–90% (handoff band) | **12** | **12** |
| **above 93% — Word spill risk** | **0** | **0** |

**No regression:** identical outlier counts, median up one point. Of 17 pages differing by more
than 1.5 pp, 15 are site page-1s rising 82% → 87% because they gained the D2 map, and 2 are
paddock page-1s falling ~2 pp on the C1 map's different aspect ratio.

**The image-height trap is not present.** It renders pictures at roughly a third height; nothing
is near that, and all three load-bearing traps verify intact: exactly one `new Table(` — the
`table()` helper — carrying `TableLayoutType.FIXED` with `width` computed by `widths.reduce()`
from the same array passed as `columnWidths`, so the grid sums exactly **by construction**; no
image paragraph carries a `line` rule; no `bbox_inches` anywhere.

**But handoff §7 says *"All 32 documents in this delivery sit inside the band"*, and that was
never true of the delivered documents** — 42 of 83 pages sit outside the script's own 80–92%
band and 12 outside the handoff's stated 70–90%. Measured on the delivery, with the delivery's
own instrument. Two separate problems, and only the second is mine to fix:

1. **The band is stated two ways.** Handoff §7 and the template spec say **70–90%, spill above
   ~93%**; `check_page_fill.py` has always used **80–92%**. Under one, most pages pass; under
   the other, half fail. I preserved the script's thresholds rather than retune silently.
   **Which band governs is a design-seat question** (§7).
2. Under either band the risk the band exists to manage — Word spilling to a phantom page above
   ~93% — **does not occur on any page of either build.**

---

## 7. For the design seat

- **Which page-fill band governs**, 70–90 or 80–92 (§6). Until this is settled the check exits 1
  on a build with no spill risk, and a permanently-red check is ignored exactly like a
  permanently-green one (I-11).
- **D-2's caption change**, fixed and flagged: a locator that draws markers will now say so
  instead of denying it. Live only in the 52-set.
- **The `>20` / `>5` flood-frequency colour cutoffs** (`report_figs.py:370`) — typed, and
  possibly not the registered band definitions.
- **32 vs 52** — unresolved, unchanged.
- **v1.2 does not exist** (§0).

## 8. Not done — Gate 2 onward

- §8.1 gap-series rebuild from `T10_annual_gap_series.csv`.
- `test_T8_headline_reproduction.py` before the batch (§3 item 1).
- **Prove the four contract canaries can fail** (§3 item 2) — they pass, and passing is not the
  same as being able to fail. The caption branch and all four lint checks now have that proof;
  the canaries do not.
- Scope-lock string read from `RPTSCOPE_number_contract.csv` (§3 item 3).
- §8.4's two audit checks re-run rather than assumed — see Gate 0 F1, still outstanding.
- Methods document (§4), figure registration (§5, session 1), issues-log entries for the
  GeoPackage (§8.2) and the dead `gayini_params` self-check.
- `Gayini_RS_methods_doc_V6.docx` not opened; `WINWORD` PID 31868 was live at session start.
  Note a **V8** now exists (`Gayini_RS_methods_doc_V8.docx`, 4 Aug 16:36) — the kickoff named V6.
