# REPORTS — Rulings R-1 to R-5 applied · builder v1.4

**Session:** report batch, third concurrent seat · **Date:** 4 August 2026
**Worktree:** `D:\Github_repos\Gayini_reports` on `feature/reports`
**Builder:** v1.3 → **v1.4** · **DB read-only throughout.** No write attempted.

```
lint_builder.py    0 error · 0 warn · clean      exit 0
verify_batch.py    32 match · 0 changed · 0 missing   exit 0
check_page_fill.py 0 above 92% · 12 below 70%    exit 0
tests/             6 assertions · 3 files · 0 fail    exit 0
```

**Gate 4 is closed with no work in it (R-4). Gate 2 is next.**

---

## R-1 · The page-fill band — applied

`SPILL = .92` is an **ERROR and fails the build**. `DEAD = .70` is a **WARN and never fails**.
Between them, nothing is reported. Handoff §7 and the template spec both corrected, each stating
that this supersedes the 70–90% band and why.

**The third statement is now on the record.** I found two — 70–90% documented, 80–92% in the
script. You supplied the third: 68–93% in the in-session QA, which is what produced *"0 of 32
outside tolerance"*. One instrument measured, a second was documented, a third asserted the pass.
Both corrected documents say so, because a band stated three ways is the finding, not a footnote.

**Proven in both directions** — `tests/test_page_fill_fires.py`, because R-1 makes this the only
build-failing check in the module and it had never fired on real output:

```
over-full page   -> exit 1  OK   FIXTURE_overfull-1.png   95%  may spill in Word
real reports     -> exit 0  OK   12 below 70% (warn - dead space, not a defect)
```

The fixture is a real docx built by the `docx` package and put through the real
docx→PDF→PNG path, not a synthetic number handed to the threshold. A threshold that has only
ever been under-run is a constant, not a threshold.

## R-2 · Colour by `regime_band` — applied, and it was live in five of seven documents

Ruled wrong in kind, and the empirical check is worse than "typed": **10 of 21 bars were coloured
against their own label.**

| paddock | band | ff | ff-cutoff gave | label says |
|---|---|---|---|---|
| Dinan 10 | **Wetter ground** | 12.52 | TEAL (mid) | BLUE (wet) |
| Dinan 10 | **Middle** | 3.29 | GOLD (dry) | TEAL (mid) |
| Bala 15 / 26ca / 27ca / 28ca | **Middle** | 22–29 | BLUE (wet) | TEAL (mid) |
| Bala 15 / 26ca / 27ca / 28ca | **Drier ground** | 5.2–11.7 | TEAL (mid) | GOLD (dry) |

On Dinan 10's page, *Middle* and *Drier ground* rendered **the same colour**; on four other
paddocks, *Middle* was **indistinguishable from Wetter ground**. A reader holding two reports saw
the colour that means "middle" on one page meaning "wetter" on the next.

`regime_band` is now carried through the unit record and the bars are coloured by it. Bala 29ca
and Dinan 8 are unaffected — their cutoffs happened to agree, which is exactly why this survived
review.

**The literals disappeared rather than being registered, and `lint_builder.py` is now `0 error ·
0 warn` — clean for the first time.** The last outstanding warning in the module was this defect.

## R-3 · D-2's caption change — ratified

Recorded. Already implemented and proven in both directions; fires first in the 52-set.

## R-4 · 32, not 52 — recorded, Gate 4 closed

`RPTSCOPE_report_set.csv` governs: 7 paddock reports, 25 site reports. **Gate 4 closes with no
work in it.** The §2 rule is deferred on capacity, not rejected, and governs any post-deadline
extension — not a fresh selection made with results in view. Handoff §6 and §9 both need this
written in; they still describe it as unresolved. **That edit is in this commit.**

Two v1.3 fixes are therefore latent rather than live, and both stay: the `c1_slug` fix (recovers
the `Bala 8/11` render) and D-2 (locator caption). Neither has a live case in the 32-set.

## R-5 · V8 read — one disagreement to report

Read via `zipfile`, not Word. `WINWORD` (PID 31868, since 31 July) is still live but holds
`docs/reference_update/~$Gayini_reference_state_review_v3.pptx`; **no lock file exists for V8**,
and no Word process was launched. 452 paragraphs, 25 figures.

Context only, and the V6 caution transfers: V8's own header states 48 of 175 claims checked,
46 confirmed — so 127 remain unchecked.

**Where V8 and the reports agree**, checked against the registry rather than against each other:
the expectation line `52.65 + 0.548 × flood frequency` and residual SD `6.62` are the registered
constants rounded; the Bala 29ca residual `−16.8` matches `t10_bala29ca_xsec_residual`; *"8 meet
the recovering criterion"* matches canary p5 (2 of them in Bala 29ca); Bala 29ca's gap slope
`+0.9…` matches the registered `0.919`. V8 has also fixed the DOC-1 §6.6 support finding — it now
says the Kruskal–Wallis *"is computed at plot support"*, where the audited version signalled no
change of support.

**The disagreement — cell size, and V8 disagrees with itself.**

| | value |
|---|---|
| V8 §3, analysis substrate | *"a common analysis grid in EPSG:8058 at **24.97 m**"*, and *"24.97 m cell"* |
| V8 §11, limitations | *"can describe, at **25 m** resolution across 35 years"* |
| the reports | **25 m**, derived from `PIXEL_SIDE_M` = 24.970268 and rounded for the client register |

Reported, not reconciled. The reports and V8 §11 agree; V8 §3 differs from V8 §11. Rounding for
a client page is defensible and the underlying constant is identical in both — but the visible
number differs between two documents that will be read together, and V8 carries both values
itself. **A design-seat call, not a build one.**

---

## Also fixed — found by the canary test before it could test a canary

`report_data.py` resolved `gayini_params` through `GAYINI_ROOT`, i.e. it located **source code via
the data root**. `GAYINI_ROOT` points at data — the database, the figure renders, the output tree;
`scripts/lib/` is source that ships beside `scripts/15_reports/`. Coupling them meant pointing
`GAYINI_ROOT` at a data-only fixture broke the import rather than the fixture, and the canary test
died on `ModuleNotFoundError` before reaching a single canary.

Now resolved module-relative first, `ROOT` second. Same family as the other four: a thing located
by the wrong authority.

## Canaries — they can now be made to fail

Your endorsement taken first, since a canary that has never fired is the same object as check C
before it was rewritten.

```
control - unmutated copy:      exit 0  OK   (canaries pass)
drift   - veg_p05_spatial x1.05 on 35 rows for Bala 29ca:
                               exit 1  OK   CANARY FAIL:
        rptscope_canary_p1_paddock_floor_bala29ca registered 40.52, builder produced 42.55
live DB untouched (mtime and size unchanged)
```

**Ruling J governs the fixture.** Breaking the schema would prove only that the code path is
reachable, so this mutates **data, not structure**: every query still runs and every column still
exists, and the canary rejects a *wrong value*. The fixture is a copy in a temp directory; the
test asserts the live database's mtime and size are unchanged, and that assertion is part of the
pass condition rather than a comment.

Every check in the module now has a proof it can fail: four lint checks, the caption branch, the
spill threshold, and the four canaries.

---

## Issues log — three entries added

`RB-I1` · **reachability checks must be empirical, not syntactic** — logged as a method, per your
note. The syntactic version could not see a path built on one line and used on the next, and it
failed its own negative control, which is the only reason the weakness surfaced. Ruling J applied
to a lint rather than to a canary.
`RB-I2` · `gayini_params`' relative-path self-check silently skips outside the repo root, so the
single source of project constants validates them under one working directory only.
`RB-I3` · the GeoPackage geometry from §8.2 — 19 of 48 zoned plots fall outside their stored
polygon, which is why the locator suppresses markers for ~40% of them.

ID prefix `RB-I` was checked against the on-disk log before use, per the ID-hygiene rule: no
collision with `I-` (…I-47), `C-` (…C-16), `U-I`, `T3-I` or `D1-I`.

---

## Not done — Gate 2

- **§8.1 gap-series rebuild** from `Output/tables/T10_annual_gap_series.csv`. The registered
  `t10_gap_annual_slope_C_29ca` = 0.919; the builder's own derivation was 0.8604 before it was
  removed as unread. This is the open non-reconciliation and it is the next piece of work.
- `test_T8_headline_reproduction.py` before the batch (§3 item 1).
- Scope-lock string read from `RPTSCOPE_number_contract.csv` rather than the constant in
  `report_build.js` (§3 item 3).
- **§8.4's two audit checks re-run rather than assumed** — Gate 0 F1. Still outstanding, and
  still the item I would not want carried forward on the strength of "checked 4 Aug".
- Methods document (§4); figure registration (§5) — session 1, additive, new `run_id`.
