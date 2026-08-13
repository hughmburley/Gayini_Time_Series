# REPORTS — the 32-document set: R-15 applied, cleared, shipped

**Session:** report batch, third concurrent seat · **Date:** 5 August 2026
**Builder:** v1.7 → **v1.8** · **DB read-only.** No write attempted.
**Shipped: 32 documents — 7 paddock, 25 site.**

```
lint_builder.py        0 error · 0 warn                       exit 0
verify_batch.py        32 match · 0 changed · 0 missing        exit 0
check_scope_claims.py  clean (7 checks)                        exit 0
check_page_fill.py     83 pages · 0 above 92% · 12 below 70%   exit 0
tests/                 14 assertions · 4 files · 0 fail        exit 0
```

**R-9, R-11, R-13 and R-14 are NOT in this build.** They are complete-but-unverified on branch
`hold/r13-r9-r11` (`2ecde5f`, pushed), required before the other 57 ship, and deliberately
excluded from today.

**R-14 and R-15 never reached me as issued text** — the same relay gap as R-9 and R-11. R-15 was
implemented from the four requirements stated in your descope note; the wording is mine and
needs ratification. R-14 was not implemented at all, and is held with the rest.

---

## 1. R-15 — one report manifested it, exactly as you said

Confirmed independently across all five parts pages in the set before changing anything:

| paddock | bare (rank ≤ 2) | recovering | branch |
|---|---|---|---|
| Bala 26ca | — | — | neither; no claim made |
| Bala 28ca | — | — | neither; no claim made |
| **Bala 29ca** | Aeolian, Riverine | **Aeolian, Riverine** | sets **identical** — the count test was right by coincidence |
| **Dinan 8** | — | Aeolian, Inland Floodplain | no bare parts, so the other branch |
| **Dinan 10** | Aeolian, Inland Floodplain | **Riverine** | **set mismatch — the defect** |

The old line asked `rec.length === low.length` and then said *"they are coming back"*. Dinan 10's
bare parts are Aeolian and Inland Floodplain, **both Persistently poor**; its one recovering part
is Riverine, rank 6 of 37. It rendered:

> Two of this paddock's three parts are among the most bare country of their kind anywhere on the
> property — **and one of them are coming back.**

Three faults in one sentence: recovery attributed to parts that are not recovering, a singular
subject with a plural verb, and no sense of scale. Now:

> Two of this paddock's three parts are among the most bare country of their kind anywhere on the
> property, **and neither is coming back. Riverine is coming back, but that is 59 ha — 7% of the
> paddock — and the whole-paddock figure does not move with it.**

Set membership decides the wording; the area is stated whenever recovery falls **outside** the
bare set, which is precisely the case where a reader would otherwise scale 7% to the paddock.
Bala 29ca and Dinan 8 are untouched — verified, not assumed.

### The same defect class, in the same function, in a report shipping today

Dinan 8's marginal-parts sentence read:

> **Aeolian and Inland Floodplain and Riverine sits** close to the boundary … **it is** reported
> as classified

A chained `join(' and ')` and a singular verb over three subjects. R-15's second requirement is
*agree the verb*, `andList()` already existed, and Dinan 8 is the only paddock in the set with
more than one marginal part. Fixed:

> **Aeolian, Inland Floodplain and Riverine sit** close to the boundary … **they are** reported
> as classified

*Client-facing wording, so flagged for ratification — not held behind it.*

### Proven to fire on the pre-fix sentence

`check_scope_claims.py` gains check G, computing set membership from the unit record and testing
it against the document. The fixture injects the **pre-fix Dinan 10 sentence verbatim**:

```
r15_parts_verdict  exit 1  OK   ERROR [R-15] Dinan 10
                   the bare-parts sentence claims recovery among them,
                   but bare=['Aeolian','Inland Floodplain'] and recovering=['Riverine']
```

Seven scope-claim cases now, all correct, `none` still passing.

---

## 2. The diff, classified against a control

`verify_batch` reported **6 changed** against the shipped manifest. The manifest predates R-8 and
R-12 as well as R-15, so the diff had to be separated from the cumulative one. **Bala 27ca is the
control**: it matches the manifest, and its only differences from the delivered v1.0 pack are the
v1.1 network sentence and R-6's 24.97 m — both pre-manifest. Subtracting those classes:

| document | what moved since the manifest |
|---|---|
| Bala 15 | R-8 — "almost entirely" + trace clause |
| Bala 26ca | R-12 — "two", and-list |
| Bala 28ca | R-8 — "spans two", trace clause · R-12 |
| Bala 29ca | R-12 |
| Dinan 10 | R-12 · **R-15 parts verdict** |
| Dinan 8 | R-12 · **R-15 verb and join** |

**Nothing unaccounted.** Then re-fingerprinted **once**, at v1.8: `6 fingerprint(s) moved · 0 new
· inventory 5 C1 · 25 D2`, after which `32 match · 0 changed · 0 missing`.

---

## 3. CLEARED LIST — what has been read and passed, not merely built

Every row derived from the built document, not from the unit record.

| paddock | pages | map source | sites | parts | cover | residual caveat |
|---|---|---|---|---|---|---|
| **Bala 26ca** | 5 | C1 render | 3/3 | 2 | 100.0% | marginal classification flagged in text |
| **Bala 27ca** | 4 | **locator** | 0/0 | 1 | 100.0% | single-community, no parts page; no sites; marginal flagged |
| **Bala 28ca** | 5 | C1 render | 8/8 | 2 | 87.7% | trace community named, not counted (R-8) |
| **Bala 29ca** | 5 | C1 render | **10/13** | 3 | 94.5% | 3 treed sites excluded; Inland part marginal |
| **Bala 15** | 4 | **locator** | 0/0 | 1 | 99.8% | single-community, no parts page; no sites; trace community (R-8) |
| **Dinan 10** | 5 | C1 render | 0/0 | 3 | 83.4% | no sites; **R-15 applied**; lowest cover in the set |
| **Dinan 8** | 5 | C1 render | 4/4 | 3 | 98.8% | all three parts marginal; **R-15 verb fix** |
| **25 site reports** | 2 each | D2 crop, 25/25 | — | — | — | none |

**Two residual caveats that are not defects but are the reader-facing limits of this set:**

- **Bala 27ca and Bala 15 carry a locator, not a checkerboard** — no C1 render exists for either.
  Those two readers are told where the paddock sits but not what country it is. R-13 fixes this
  and is held.
- **Dinan 10 reports 83.4% of its ground**, the lowest here; the other six run 87.7–100%. The
  header does not yet carry that second figure — that is R-9, held. The set does not contain a
  bad case (Mara 1 at 15%, Mara 2 at 24% are both outside it), which is why holding is safe.

Coverage above is reported ground ÷ (reported + woodland). R-9's finding that the paddock is
**three** components — `Other / minor units` sits outside both — does not bite here: none of
these seven carries any.

---

## 4. Also fixed today

**`run_batch.ps1` aborted on a warning.** `$ErrorActionPreference = "Stop"` makes *any* native
command that writes to stderr raise a terminating error even when it exits 0 — and
`gayini_params` emits a `UserWarning` about its own skipped self-check (RB-I2). The batch died at
step 1 with everything working. Now `Continue`, with exit codes checked explicitly, which is the
thing that actually distinguishes a warning from a failure.

---

## 5. State

- **Shipped:** 32 documents at `Output/reports/`, `.docx` + PDF, manifest v1.8.
- **Held:** the other 57 paddock documents and their figures moved to
  `Output/reports/_held_57/` and `Output/figures/reports/_held_57/` — moved, not deleted, and
  regenerable from `hold/r13-r9-r11` in any case.
- **Not started:** per-paddock output folders; methods document; figure registration; the
  scope-lock string from `RPTSCOPE_number_contract.csv`.
- **Outstanding relay:** R-14's text, and R-15's as issued.
