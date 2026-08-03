# PACK-1 — item list restored, pack re-assembled by a REWRITTEN producer

**Date:** 3 August 2026 · **Prior:** `61f968f` · **No DB writes.** Probe 101/297/191/4/59 unchanged.

---

## 1. Ruling M2 — this is a REWRITE, not a re-run

`scripts/13_pack/PACK1_assemble.py` is **new code**. The original producer was ad-hoc and **never
saved**: the pack folder and `PACK1_assembly_manifest.csv` existed on disk with no code behind them,
and a search of every `.py`, `.R`, `.sh` and `.md` including untracked files found only two
*documents* referencing `01_maps`, no script.

**Ruling M1, recorded as directed:** L4's *"re-run, do not rewrite"* rested on a fact inferred from
the manifest's column quality and asserted without verification. **Logged as the sixth instance of
I-40, with the source named as the design seat** — the rule binds upward or it does not bind.

## 2. Ruling M3 — the column contract is read, not typed

The producer **reads the header of the existing manifest at run time** and aborts if it differs from
the build's expectation. Derived contract, 9 columns:

```
item_id · type · source_path · pack_path · sha256_source · sha256_pack_copy
verified_after_copy · shares_file_with · source_still_present
```

**No divergence** — the rebuild produces exactly this set, so there is nothing to report under M3.

## 3. Ruling M4 — the diff that makes a rewrite as safe as a re-run

Built into a scratch directory against the restored list and diffed against the folder as the other
session left it:

| | result | expected |
|---|---|---|
| byte-identical | **14** | 14 |
| **content differs** | **0** | 0 |
| new files | **2** | 2 |
| lost files | **0** | 0 |

The two new files are exactly the two L3 names:

```
+ 01_maps/T13_D2_part_state_map_sensitivity.png      (M4b)
+ 03_tables/T1_conserved_paddock_comparison.csv      (T1)
```

**Verdict: matches M4 exactly.** Only then was the pack folder replaced.

## 4. L1 + L3 — one commit, as ruled

`Output/pack/PACK1_item_list.csv` restored from `6aa345b`: **18 rows · 17 items · 16 distinct files.**
M4b present, T1 → the `.csv`, `T1_render` present.

Re-assembled: **17 manifest rows carrying 16 physical files** — `01_maps` 7, `02_figures` 6,
`03_tables` 3.

| item | pack path |
|---|---|
| T1 | `03_tables/T1_conserved_paddock_comparison.csv` |
| T1_render | `03_tables/T1_conserved_paddock_comparison.png` |
| M4b | `01_maps/T13_D2_part_state_map_sensitivity.png` |

**M6 behaviours all verified:** copy-never-move with `source_still_present = 1` on every row · SHA-256
first-50-MB taken before and after with `verified_after_copy = 1` on all 17 · abort-before-manifest
wired · F7 copied **once** into `01_maps` with mutual `shares_file_with` between M4 and F7 · **both
frozen inputs byte-unchanged** (checksums re-verified against the R1 record).

## 5. Ruling L9 / I-43 — an unattributed ruling reached the pack

Recorded and logged as **I-43**, in the I-37 family, with the standing rule added to CLAUDE.md:

> **A ruling is only a ruling if it can be quoted from a design-seat message. If it cannot be quoted,
> it is a proposal and it stops at a STOP.**

Second occurrence of one shape, and this one reached a client deliverable:

1. the AUD-1 delta's `reason_detail` asserted a 2 August T1 ruling **that was never issued**;
2. `PACK1_P4_assembly.md` cites design-seat rulings **"3 August §2 §3 §5"** which this seat did not
   issue — and the item list was then overwritten into **exactly** the state the unattributed
   `reason_detail` had asserted.

The pack was assembled from that reverted list and shipped **14 files instead of 16**.

## 6. Both rulings restated with their reasons (L2)

- **T1 ships both.** The `.png` delivers four rows side by side in a meeting with nothing to open;
  the `.csv` keeps the numbers checkable. **There is no trade-off to make.**
- **M4b is in.** The recovering count reads 8 at the pin, 5 under drop-two-wettest and 5 under a
  within-community expectation, with **only three parts surviving all three**. A reader must see the
  cut varying on its own: M4's hatching shows one sensitivity, M4b shows the classification at
  looser and stricter cuts.

## 7. P4 §5 reasoning received — held for the captions

Recorded for P3: **T2 is a lookup table** (115 rows, searched not read — its caption must say so, and
a 115-row PNG would be unreadable) and **T1 is four rows to be read** (ships rendered *and* as data;
its caption names the csv as the item and the png as its rendering). Not yet applied — captions are
P3-1, which is still held.

## 8. Still outstanding

- **L8** — T3 as `Gayini_what_we_dont_know.md`, a prose page in the pack root, superseding P1's
  `TEXT_ONLY` and AD-D's "P4 sheet". **The item list still carries the old resolution** and needs
  updating once the page exists; the register caption *"Every limitation, what it means, and whether
  it can be fixed"* is a promise that cannot be kept and is flagged for replacement at the design seat.
- **P3-1 to P3-5** — held at the last STOP pending the restored list, which now exists. Ready to run.
- **P3-6 onward** — awaiting Part 2.

## STOP
