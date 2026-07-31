# T13 Gate E — register and bundle

**Task:** T13 Gate E, per `Gayini_T13_spec.md` v1 §7.
**Date:** 31 July 2026 · **Prior:** SHA bc39321 (Gate D fix)
**Scope:** register the classification table and the headline numbers; extend the reproduction test; build the exit bundle.
**Producer:** `scripts/11_database/register_T13_gateE.py` (tracked).
**Artefacts:** `fact_zone_community_part_classification` · 6 `dim_headline_number` rows · `Output/review_bundles/t13_paddock_part_classification.zip`

Session start: on `main`, up to date with `origin/main`, `main` has not moved.

**Additive only.** One new table, six new `dim_headline_number` rows, one `workflow_run` row.
`INSERT OR REPLACE` throughout — never `OR IGNORE`. **No builder run, no existing object modified,
no p-values.**

---

## 1. `fact_zone_community_part_classification` — 115 rows

One row per supported part, carrying **both continuous measures and the state at every swept cut**
(§7), so the categorical labelling can always be re-derived from, and checked against, the
continuous primary result.

Columns: `level`, `level_z`, `trend_raw`, `water_slope`, `trend_adj`, `trend_z`, `flood_sd` ·
`state_registered`, `pp_split` · `state_cut_050/075/100/125/150` · `state_drop2wettest`,
`robustness_changed` · `dist_to_nearest_cut`, `marginal_flag` · `cut_registered`, `marginal_band` ·
`support_level`, `aggregation_unit`, `run_id`. Primary key `(zone_fid, community)`.

Verified by independent re-read after commit:

| check | result |
|---|---|
| rows | **115** |
| state counts read back from the table | Recovering **8** · Persistently poor **14** · Declining **16** · Unremarkable **77** |
| Ruling-4 split read back | low and flat **10** · low and falling **4** |
| `marginal_flag = 1` | **23** |

`dist_to_nearest_cut` is computed against the **three active cuts only** — `level_z = −1.0`,
`trend_z = ±1.0`. **`level_z = +1.0` is excluded**, per the 31 July ruling; the column and the
`marginal_band` value are stored so the definition travels with the data rather than living in
prose.

### `assert_state` — the map's reticence is a data property, not a drawing decision

**The no-assert rule is a CRITERION, not a named part.** The earlier version named Bala 29ca Inland,
which was the ad-hoc-threshold problem this whole task exists to avoid, appearing in a ruling
instead of in a cut. The criterion:

> **State is not asserted where a part is BOTH inside the 0.15 marginal band AND changes state under
> the robustness run.**

**Nine of 115 qualify** — the 12 robustness movers less the 3 that sit outside the band (Dinan 7
0.188, Bala 2 0.205, Mara 18 0.391, whose states *are* asserted):

| part | state at the registered cut | dist to cut | state on drop-2 |
|---|---|---|---|
| Dinan 8 · Inland | Recovering | 0.111 | Persistently poor |
| Dinan 9 · Riverine | Recovering | 0.006 | Unremarkable |
| Dinan 13 · Riverine | Recovering | 0.027 | Unremarkable |
| Dinan 8 · Riverine | Persistently poor | 0.001 | Unremarkable |
| Mara 2 · Inland | Persistently poor | 0.008 | Unremarkable |
| Bala 5 · Inland | Declining | 0.040 | Unremarkable |
| Bala 12 · Inland | Declining | 0.040 | Unremarkable |
| Bala 26ca · Riverine | Declining | 0.072 | Unremarkable |
| Bala 29ca · Inland | Declining | 0.038 | Unremarkable |

Stored as `assert_state` (boolean) beside `marginal_band`, so what the map is willing to claim is a
**property of the data**, reproducible from the table, rather than a decision taken at drawing time.

**This is not cosmetic.** Three of the nine are *Recovering*, so the map's headline changes:

> **Eight parts meet the recovering criterion. Five of those survive dropping the two wettest
> years; three do not and are shown as unclassified. The three that recover at every swept cut are
> among the five.**

That sentence is now the Figure 1 title and caption, and it is the form the finding travels in.

**Nothing is reclassified.** `state_registered` is untouched, the rule is untouched, and **the
registered counts stand at 8 / 14 / 16 / 77**. `assert_state` governs what the *map asserts*, not
what the data says — the distinction is recorded in the column comment and asserted in the script
(`assert_state = 0` count must be 9; *Recovering* must split 5 asserted / 3 not; and **no part that
recovers at every swept cut may be unasserted** — verified 0).

## 2. `dim_headline_number` — six rows, sweep range as spread

Registry now **74 rows** (68 before). All six carry the full five qualifiers as columns.

| `number_id` | pinned | spread (sweep 0.50–1.50) |
|---|---|---|
| `t13_parts_recovering_count` | **8** | 3 – 15 |
| `t13_parts_persistently_poor_count` | **14** | 8 – 21 |
| `t13_parts_declining_count` | **16** | 3 – 19 |
| `t13_parts_unremarkable_count` | **77** | 60 – 101 |
| `t13_parts_low_and_flat_count` | **10** | 7 – 14 |
| `t13_parts_low_and_falling_count` | **4** | 1 – 11 |

The last two are **beyond the literal §7 requirement** (which names the four states). They are
registered because the Ruling-4 split is a client-facing distinction — "low and getting worse" is
the state a land manager most needs — and an unregistered number is exactly what the three number
rules exist to prevent. Both `caveat` fields record that the split is an **additive labelling, not a
threshold or membership change**.

Every row's `caveat` carries: the count is cut-dependent while the membership is not; the
community-SD scale (`z` = −1.0 is ~12 pp of ground in Aeolian/Riverine, ~6 pp in Inland); that 12 of
115 parts change state when 2022 and 2016 are dropped; that the states are a labelling of continuous
measures; and that **no cause is attributed**. `decision_note` records that the cut was
pre-registered, that no threshold moved after the result, and that the abandoned pilot is not
reconciled to.

**The spread is doing real work here.** A bare "8 parts are recovering" is not defensible; the
registered form is the §5 range. The client sentence stands as ruled:

> **Between 3 and 15 parts depending on strictness, 8 at the registered cut — and the same parts
> throughout.**

## 3. Reproduction test extended — and proven to fire

`recompute_t13()` added to `test_T8_headline_reproduction.py`. **It re-derives the counts by
applying the §5 rule to the stored `level_z` / `trend_z`, not by counting `state_registered`.**
Counting the state column would only prove the table agrees with itself; re-running the rule catches
a **mislabelled state** as well as a drifted count.

```
T8 reproduction: PASS - all 71 pinned numbers reproduce within tolerance
```

(65 before, 71 now.) Counts inherit the existing `_count` tolerance of **0.0** — exact.

**Proof both failure modes fire** (CLAUDE.md: a check that has never failed has only been run). Two
fixtures on throwaway copies; the real DB untouched:

```
=== FIXTURE 1: corrupt a T13 PINNED count (8 -> 9) ===
  checked 71; drift rows 1
    DRIFT t13_parts_recovering_count: pinned=9.0 recomputed=8.0

=== FIXTURE 2: corrupt a stored MEASURE so the RULE yields a different state ===
  checked 71; drift rows 3
    DRIFT t13_parts_recovering_count: pinned=8.0 recomputed=7.0
    DRIFT t13_parts_persistently_poor_count: pinned=14.0 recomputed=15.0
    DRIFT t13_parts_low_and_flat_count: pinned=10.0 recomputed=11.0
```

Fixture 2 is the one that matters: moving a single part's `trend_z` below the cut is caught in
**three** places at once, and a test that merely counted the stored state column would have passed.

> ### Precedent — do NOT "simplify" this test by counting the state column
>
> The obvious-looking simplification is
> `SELECT state_registered, COUNT(*) ... GROUP BY 1`. **Do not make it.** That would only prove the
> table agrees with itself — a tautology, not a test. It cannot detect a mislabelled state, a
> misapplied cut, or a rule that drifted from the spec, because it never evaluates the rule.
>
> Re-deriving from the stored `level_z` / `trend_z` by **applying §5** is what makes it a test.
> Fixture 2 is the proof: corrupting one part's measure trips three registry rows, and the
> count-the-column version passes it silently. The same principle sank an earlier check in this
> project — the 1 July QA row that returns PASS from a stored snapshot rather than from the data,
> and so cannot notice being wrong. **Verdicts that are derivable must be computed, not stored.**

The pre-existing `--break` fixture still fires (`ref_grazed_floor_gap_4pdk_1988_92`, exit 0 = the
check fired as expected).

## 4. What was deliberately NOT registered

**The two part-polygon gpkgs are not in `spatial_layer_asset`, and should not be.** That table is an
**import registry** — it records layers read in from `Input/`. Both gpkgs are **build outputs**
derived from the census, so a row there would be the same category error as registering the
`Gayini_Results.gpkg` `management_zones` companion, which CLAUDE.md names explicitly. §7 does not ask
for it either.

**This leaves a real gap, flagged not solved:** the exact part polygons are the geometry behind a
registered classification, and there is currently **no registry for a derived vector build output**
(`raster_asset` is rasters, `census_asset` is the parquet, `spatial_layer_asset` is imports). Both
gpkgs are in the exit bundle and both producing scripts are tracked, so the provenance chain is
complete — but it is complete *outside* the DB. A `vector_output_asset` registry would close it.

**Logged as `I-31`** in `docs/Gayini_issues_log.md` (IMPROVE, post-deadline), with the explicit
instruction not to improvise a home for it: putting build outputs in `spatial_layer_asset` would
corrupt an import registry and break `read_registered_layer()`'s contract.

`fact_zone_community_flood_annual` was created and reconciled at Gate A (4,130 rows, verified again
here) and needs no further registration — there is no table-of-tables registry.

## 5. Exit bundle

`Output/review_bundles/t13_paddock_part_classification.zip` — **23 files, 9.7 MB**:

- **tables/** — the Gate B measures and residual series; the Gate C classification, sweep, robustness and Bala 29ca raw-vs-adjusted CSVs
- **figures/** — both registered Gate D figures
- **reports/** — the spec plus all five gate reports
- **code/** — all seven producing scripts and the reproduction test
- **spatial/** — both gpkgs (exact and render-only)

## 6. Acceptance against §9

| criterion | status |
|---|---|
| Part-grain annual flood table; reconciliation reports max diff 0 | **met** — 0/0/0, Gate A |
| 115 parts with both measures, SEs, flood-variance flags, lag comparison | **met** — Gate B; 0/115 flagged; lag better for 34/115 |
| Classification at the pre-registered ±1.0 cut, plus the five-point sweep | **met** — 8/14/16/77; sweep registered as spread |
| Robustness excluding the two wettest years, with state changes listed | **met** — WY2022/WY2016 dropped; 12 of 115 listed |
| Map at the registered cut, plus small multiples at 0.75 and 1.25 | **met** |
| Continuous scatter panel alongside the classified map | **met** |
| Registered; reproduction test extended and firing on the fixture | **met** — 71 checked; two T13 fixtures fire |
| No builder run, no existing object modified, no p-values anywhere | **met** |

## 7. Carried forward — not resolved at this gate

1. **`Bala 26ca · Riverine`** is marginal on trend (0.072) and a robustness mover, i.e. in Bala 29ca
   Inland's position rather than Bala 27ca's, but is still drawn and stored as *Declining* because
   the abstention ruling named only 29ca. Hatched, so the map claims no certainty. **Your call.**
2. **No registry for derived vector build outputs** (§4).
3. **`CLAUDE.md` is stale in three places** found this gate: `dim_headline_number` is **74** rows,
   not 59; the DB is past the stated 86 tables / 30 views; and number rule 3 points at
   **`docs/decisions/`, which does not exist** — the pin-decision documents it protects
   (`T8_gateA_pin_decisions.md`, `T8_T9_T10_gateA_decisions.md`) live in `docs/reference_update/`.
   The rule is therefore currently unenforceable as written. Not edited here — a CLAUDE.md rewrite
   is a design-seat job, and this gate already carries a correction to it.
4. **PIN 2 revisit** (L-01) is still open and T13 is the task that sharpens it: headline number #1 is
   pinned at paddock grain, and this gate registers the part-grain alternative.

## STOP

Classification table and six headline numbers registered; reproduction test extended to 71 and
proven to fire on two distinct T13 failure modes; exit bundle built. **T13 is complete against §9.**
Waiting for review before the task is closed.
