# RPT-SCOPE R2 prep — the pin rule selects 10. STOP, as instructed.

**Date:** 3 August 2026 · **Prior:** `e774430` · **READ-ONLY. NO DB WRITES. NO PINS REGISTERED.**
**Producer:** `scripts/12_zone_stratum/build_RPTSCOPE_R2_prep.py`

Rulings 3 and 4 are applied. Ruling 1's rule was applied and **selects 10, above the threshold of
8**, so this stops before the write gate as directed.

---

## 1. Ruling 1 — the rule selects 10, but its real yield is 6

Rule: *pin a SOURCED number if it is quoted in more than one deliverable, or if it is a numbered
claim in register v3 §1.* Applied to the 12 SOURCED rows remaining after Ruling 4:

| # | claim | why selected | **verdict on inspection** |
|---|---|---|---|
| 1 | REG-C2a 29ca's improvement slope | register §1 | **ALREADY PINNED** — `t10_gap_annual_slope_C_29ca` |
| 2 | REG-C7 12 of 16 declining | register §1 | **ALREADY PINNED** — `t13_parts_declining_count` |
| 3 | BYQ-Q3a 29ca 17 pp shortfall | multi-item | **ALREADY PINNED** — `t10_bala29ca_xsec_residual` |
| 4 | REG-C4b improvement in the dry western parts | multi + §1 | **NOT PINNABLE** — qualitative, no scalar |
| 5 | REG-C6b five survive drop-two | multi + §1 | **NEW PIN** — `t13_parts_recovering_count` pins **8**, not the 5 |
| 6 | REG-C6c strongest improver is grazed (Bala 15) | multi + §1 | **NEW PIN** |
| 7 | REG-C4a 82% survives water adjustment | multi + §1 | **NEW PIN** |
| 8 | REG-C5 conserved paddock flood ranks | multi + §1 | **NEW PIN** (grouped, Ruling 2) |
| 9 | BYQ-Q1 cropping history 64 of 64 NULL | multi-item | **NEW PIN** |
| 10 | BYQ-Q4 standard grazing 6 of 9 | multi-item | **NEW PIN** — the `three_arm_*` pins are per-stratum deficits, not this count |

**Three of the ten are already pinned under existing `number_id`s.** Pinning them again would
create a second registered row for one quantity — discrepancy class #1, and worse than leaving them
SOURCED. **One is qualitative** and cannot carry a `pinned_value`.

> **The rule's real yield is 6, not 10.** The rule is sound; what it lacks is a "does a pin already
> exist for this quantity" step. **Recommend adding that clause** — it is the same defect class as
> I-17 and it would have selected 6 directly.

## 2. The full R2 pin list, deduplicated

| | pin | rows | source |
|---|---|---|---|
| a | annual three-paddock reference-grazed gap | 1 | spec R2 §3 |
| b | Riverine reference-set internal spreads 36.5 / 19.2 / 28.2 | **1 grouped or 3** — see §4 | R1 |
| c | six-of-seven restricted stratum count | 1 | R1b, left SOURCED by the rule |
| d | five of eight recovering survive drop-two | 1 | rule #5 |
| e | 82% of 29ca's improvement survives | 1 | rule #7 |
| f | conserved paddock flood ranks 3/6/31/61 | 1 grouped (Ruling 2) | rule #8 |
| g | Bala 15 residual / rank 1 | 1 | rule #6 |
| h | cropping history 64 of 64 NULL | 1 | rule #9 |
| i | standard grazing at or above rotational, 6 of 9 | 1 | rule #10 |

**9 distinct new pins** (11 if Riverine is registered as three rows).

Note **(c) is not selected by the rule** — BYQ-Q2b is a By_question cell carrying one item (F6), so
it fails both limbs. It is on the list because you named it. Worth seeing: the rule and the named
list disagree, and the rule is the narrower of the two.

## 3. ⚠ The coverage arithmetic — this is why the threshold fired

Current: **71 recomputed / 85 pinned = 83.5%.**

| scenario | pinned | recomputed | coverage | |
|---|---|---|---|---|
| do nothing | 85 | 71 | **83.5%** | |
| add 9 pins, **no** derivations | 94 | 71 | **75.5%** | ↓ 8.0 pp |
| add 11 pins, no derivations | 96 | 71 | **74.0%** | ↓ 9.5 pp |
| **add 9 pins + a derivation for each** | 94 | **80** | **85.1%** | ↑ 1.6 pp |
| add 9 + derivations + the 14 R4 backlog | 94 | 94 | **100%** | ↑ 16.5 pp |

**Improving provenance would make the headline coverage number worse** — exactly the trap Ruling 1
names. But the trap is avoidable, and cheaply: **write the derivation at the same time as the pin.**

**Recommendation: pin all 9 and write a derivation for each, in the same gate.** Coverage then
*rises* to 85.1%, the `How_we_know` sentence gets stronger rather than weaker, and R4's remaining
scope shrinks to the 14 pre-existing rows. Every one of the 9 is a single query already written and
verified in the claim audit — the derivations are transcription, not new analysis.

**Your call, because it changes R2's shape**: R2 as specified writes pins only; this adds
derivations to the same gate.

## 4. Two shape questions inside the list

1. **Riverine (b) — one grouped pin or three?** Ruling 2 grouped the four flood ranks into one pin,
   so grouping is the established precedent. Three separate rows would let each band be cited alone,
   which is how F6 uses them. **Recommend three** — they are three measurements, not one — but the
   ranks precedent points the other way, so it needs a word.
2. **(f) grouped ranks** — a grouped pin has no single `pinned_value`. Proposal: `pinned_value` =
   **61**, the widest rank, with `spread_min` 3 and `spread_max` 61 and the full set in
   `decision_note`. That makes the *span* the pinned quantity, which is what the restated claim
   asserts.

## 5. Rulings 3 and 4 — applied

**Ruling 3.** New column `agrees_at_stated_precision`, which rounds the computed value to the
precision the claim states before comparing. **Two rows flip from `agrees=0` to agreeing**:
REG-C4a (81.6 vs 82) and BYQ-Q3a (16.80 vs 17). `agrees` is retained unchanged so nothing moves
silently. **P4 filters on `agrees_at_stated_precision`, never on `agrees`.**

**Ruling 4.** BYQ-Q7a and Q7b → `N/A_by_design`. Q7b's note records Task J's external blocker
rather than a provenance gap.

**Q7a's 43.6% / 22.8% pair: recomputed, and it reproduces exactly.** Pixel-weighted
`SUM(wet_pixels)/SUM(valid_pixels)` over `fact_zone_veg_annual`, split at 2019 — **n = 4 and
n = 31**, matching the cell's own "four water years" and "the preceding thirty-one".

**The first attempt did not reproduce it**: mean-of-paddock-means gives **46.0 / 25.2**. The
difference is entirely `aggregation_order` — the qualifier `dim_headline_number` carries as a
column precisely for this. **The cell's number is sound and stays.** A good argument for pinning it
too, though it is not on the list.

## 6. Probes

| | `dim_headline_number` | `figure_asset` | `raster_asset` | `table_asset` | `report_asset` |
|---|---|---|---|---|---|
| open | 88 | 287 | 186 | 2 | 59 |
| close | 88 | 287 | 186 | 2 | 59 |

DB mtime `2026-08-02 12:09:44` at both ends. **No writable connection opened. No pin registered.**

## STOP — three decisions needed before R2 writes

1. **Pin 9 (deduplicated) rather than the rule's raw 10** — three are already pinned, one is qualitative.
2. **Write derivations in the same gate**, so coverage rises to 85.1% instead of falling to 75.5%.
3. **Riverine as three rows or one grouped**, and the grouped-rank `pinned_value` convention in §4.
