# FIG1-T1 — order the pack by argument · Rulings T, U, V

**Date:** 4 August 2026 · **Prior:** `6c31e4f` (FIG1-T1) · **Probe:** `101 / 297 / 191 / 5 / 60`
unchanged throughout. The only database writes are Ruling N's two rows, re-registered in place by
`INSERT OR REPLACE`; no count moves.

**Scope note:** FIG-1 Tier 2 does not run before 10 August. Nothing here re-renders a figure.

---

## 1 · FIG1-T1 — the ordering

`display_order` and `section` added to `PACK1_item_list.csv`. Both generated documents sort **in the
generator**, not by inheriting the CSV's physical row order, so re-saving the item list cannot
silently change the pack's reading order.

| section | items |
|---|---|
| **Read first** | T3 · T1 · T1_render · T2 |
| **The argument** | M1 · F5 · F3 · M5b · M4 · F7 · M4b |
| **Supporting detail** | M5 · F4 · F1 · F2 · F6 · M2 · M3 |

**Acceptance.** 17 pack items **byte-identical** against a fresh assemble — no figure re-rendered.
`00_START_HERE.md` and the workbook `Contents` sheet agree on **item, filename and order**, 18 rows
each, asserted by reading both rendered artefacts rather than checking a literal (I-40).

**Both new checks proved able to fail.** The ordering script converges — mutate a `display_order`,
re-run, the file is restored byte for byte. The order check needed **two** fixtures: reversing the
shared sort did *not* fire, because both documents moved together, which is the one-source design
working rather than the check failing; reversing only the `Contents` sheet fires the assertion and
the workbook is not registered.

## 2 · Ruling U — why F7 sits between M4 and M4b, and T1_render after T1

**Recorded so a later editor does not "fix" it.**

The spec's section table names 16 of the 18 rows; **F7 and T1_render are unplaced there**. Both are
placed immediately after their partner, and the reason is filename adjacency, not logical flow:

- **F7 *is* M4's file** — same `sha256`, `85502c156e81e825`. A reader meeting the same filename twice
  with an unrelated item between them infers an error. Adjacent, it reads as two readings of one
  image.
- **T1_render is T1 as a picture**, for the same reason.

**Filename adjacency beats logical flow here.** Do not separate either pair to make the argument
sequence tidier.

The ordering script refuses to run if any row is unplaced or unknown, so a future item cannot be
added without being positioned deliberately.

## 3 · Ruling T — re-sealed as v1.1, v1 kept and marked

The folder and the archive had come to differ in reading order — I-17's class, two versions of one
artefact with one stale — and an unsealed FIG1-T1 would have improved only files Adrian does not
have.

| | |
|---|---|
| **v1.1** `Gayini_Adrian_pack_v1.1_20260804.zip` | **`2206ec20319e1385…`** · 25 files · 4.47 MB |
| members re-hashed **out of** the archive | **25 / 25 identical** |
| **v1** `Gayini_Adrian_pack_20260803.zip` | **`090bdf27…` — kept on disk, unchanged, marked `zip_superseded`** |
| supersession reason, on the row | *"reading order changed by FIG1-T1; contents identical in substance, three files reordered"* |

**A re-seal now writes a new version file and never overwrites its predecessor** — overwriting is
deleting, and Ruling T keeps the superseded archive. The guard is proved:

```
STOP - Gayini_Adrian_pack_20260803.zip already exists. A re-seal writes a NEW version file;
it never overwrites a sealed archive.
```

v1 re-hashed after the attempt: still `090bdf27cb2f0494…`.

**The manifest-row regress still applies and stays documented:** the archive cannot contain the row
recording its own hash, so the manifest sealed inside v1.1 is one row short of the repo copy. The
repo manifest is the authority.

## 4 · Ruling V — I-46 logged, prose not reopened, rule made a lint

**Not added to the client page.** Marked a **candidate row for pack item T3's next revision**, per
the ruling: reopening client prose for a hash-ordering defect is not proportionate, and Part 2
already carries this shape through I-44.

**The standing rule is now in `CLAUDE.md`:**

> **Any artefact whose checksum is compared must be emitted in a deterministic order.** Sets, dicts
> and anything hash-ordered get `sorted()` before emission.

**And it is a lint.** `hash_order` is a fourth guardrail in `lint_guardrails.py`, proven to fire on a
broken fixture alongside the other three:

```
[fixture-test] lints that fired: ['hash_order', 'magic_number', 'or_ignore', 'whole_digest']
    FIRED [hash_order] scripts/_lint_fixture_order.py:2  for nm in set(names):
[fixture-test] all four lints fire on a broken fixture: True
```

**It runs ADVISORY, not enforcing, and that is a deliberate limit on "cheaply".** 97 sites exist
repo-wide. Enforcing would fail every run; baselining them would take the baseline from **15 to 112**
and turn it into the suppression file `BASELINE_LOCK` exists to prevent. Only loops feeding a
checksummed artefact actually matter, and a regex cannot tell which. **Triage the 97 by hand, fix the
emitters, then move it to enforcing and delete the advisory entry.**

## 5 · Two banned literals of mine, caught by the lint I had just added

Adding `hash_order` meant running `check` for the first time this session, and it found **two
`magic_number` violations I introduced at RT-1** — `1080157` and `988831`, typed into the
declared-sources table of `PACK1_build_workbook.py`.

The table that declares where numbers come from was the one place a census count was typed. Both are
now **queried at build time**, with the total reconciled against `gayini_params.TOTAL_CENSUS_PX` by
an assertion, and the non-treed share computed rather than written.

**18 pre-existing `magic_number` / `or_ignore` violations remain** in `write_RPTSCOPE_R2.py`,
`U1_register.py`, `build_T8_gateB_dim_headline_number.py`, `T3_gateCDE_vectors_and_figures.R` and
`build_T13_gateD_figures.R`. Most are constants quoted **inside `decision_note` / `caveat` prose**,
where naming the constant is the point — a class the lint cannot distinguish from typing a value.
**Outside FIG-1's scope and not touched.** Flagged for triage alongside the 97.

## 6 · Acceptance

| | |
|---|---|
| FIG1-T1 ordering, both documents | **done, 18 rows, identical, order included** |
| no figure re-rendered | **17 byte-identical** |
| Ruling T re-seal | **v1.1 `2206ec20…`, 25/25 verified, v1 kept and marked superseded** |
| Ruling U reasons recorded | **done — §2** |
| Ruling V rule + lint + candidate row | **done — CLAUDE.md, `hash_order` advisory, I-46 marked** |
| probes | **101 / 297 / 191 / 5 / 60 throughout** |

**The pack is closed.** FIG-1 Tier 2 is gated at Gate A; three decisions are the design seat's —
F1/F2 combine or separate · M3 re-render or promote T3_C · whether the F6 grid enlarges without
dropping panels.
