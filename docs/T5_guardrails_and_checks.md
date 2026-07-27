# T5 — Guardrails and executable checks

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** **v2 · 27 July 2026** — text corrections only; no gate redesign.
**Depends on:** nothing.
**Status:** **Gate 1 COMPLETE** (executed 26 July with T1 Gate C). **Gates 2–4 deferred until after Aug 10** — see "Scheduling" below.

---

## Amendment log — v1 → v2

| # | What changed | Where |
|---|---|---|
| **A** | **Gate 3.1 named the wrong field convention.** v1 said the 28355 companion gets lowercase names in `field_list`. Wrong: `spatial_004`'s registered file is `Input/shapefiles.zip::CA0561_ManagementZones.shp`, which carries the **capitalised ESRI names** — the same schema as `spatial_006`, because both derive from that shapefile. The lowercase names belong to `Gayini_Results.gpkg:management_zones`, a **build output that is registered nowhere.** CC populated `field_list` correctly; the spec text would have misled a re-run. | Gate 3.1 |
| **B** | **The archive smoke-test description was wrong.** v1 said it "passes because the directory it validates does not exist." The real situation is worse: `run_spine_smoke_test.R:104-112` (`folder_scripts/archive_absent`) **hard-fails if `scripts/archive/` exists** — the check's polarity is inverted against the convention it appears to enforce. Replaced with the 1 July QA row as the illustration, which is the cleaner example. | Governing principle |
| **C** | `aggregation_unit` added to the qualifier set and the vocabulary check, since T1, T2 and T3 all now carry it. `mixed` added to the closed ladder. | Gate 4.3, 4.4 |
| **D** | Gate 1 marked complete with its delivered state recorded. | Gate 1 |

---

## Why this task exists

The T1 design and build cycle produced twelve number discrepancies (`docs/Gayini_number_provenance_audit.md`). **None** were caused by the database disagreeing with itself:

| Cause | Count |
|---|---|
| Stale copy read as live | 4 |
| Wrong object opened | 1 |
| Unstated parameter | 3 |
| Underspecified test | 2 |
| Genuinely different measurements under one label | 2 |

Every one of those classes was already covered by a written rule in a spec or in `CLAUDE.md`. The rules did not work. **This task replaces the rules that failed with checks that fail.**

### The governing principle

> A rule a human must remember is not a control. A check that errors is.

And its corollary, learned from the 1 July QA row that asserted "98 of 98 raster assets lack CRS/extent" while all 126 were populated — and misled **four separate readers**, including the author of this spec, twice:

> **Every check must be demonstrated to fail on a broken fixture.** A check that has never failed has not been tested; it has only been run.

A stored verdict cannot notice being wrong. A related and worse case sits in the repo already: `folder_scripts/archive_absent` **hard-fails if `scripts/archive/` exists**, inverted against the archive convention it appears to enforce (B5, unresolved, Adrian's call). A green light with the wrong polarity is more dangerous than a red one, because nobody looks at it again.

---

## Gates

### Gate 1 — Single source of constants, and a lint that enforces it · **COMPLETE 26 July**

Delivered:

- **`R/gayini_params.R` and `scripts/lib/gayini_params.py`** — `PIXEL_AREA_HA` **derived** from `PIXEL_SIDE_M`, never typed; load-time DB self-check errors on disagreement and warns if the DB is absent.
- **Three lints** in `lint_guardrails.py`, wired into `run_spine_smoke_test.R`, with the banned list imported from `gayini_params` so there is a single source: `magic_number`, `or_ignore`, `whole_digest`.
- **All three proven to fire on a broken fixture** and fail closed; output recorded in the change report.
- **`lint_baseline.json`** — 15 legacy entries with `BASELINE_LOCK = 15`. The lint prints the count every run and errors if it grows, so appending a suppression requires a visible code change. Demonstrated: a 16th entry → exit 1.
- The Task-M `OR IGNORE` and Gate-E whole-file `digest` are tracked as **debt**, not exemptions — they cannot be rewritten without invalidating registered checksums. The author's own `gateA0` `OR IGNORE` was **fixed, not baselined.**

Reference values, for the record:

```
PIXEL_SIDE_M      = 24.970268          -- raster_asset.resolution_x
PIXEL_AREA_HA     = PIXEL_SIDE_M^2/1e4 -- derived, never typed
MAPPED_AREA_HA    = 67349.332          -- census_stratum.farm_area_ha
TRUE_FARM_HA      = 85910.8            -- census_stratum.farm_area_total_ha
TOTAL_CENSUS_PX   = 1080157            -- census_asset.n_rows
SCOPE_NON_TREED   = "treed_context_flag = 0 AND regime_band <> 'context'"
SCOPE_ALL_PIXEL   = "1=1"
CRS_CANONICAL     = 8058
CRS_INUNDATION    = 28355
CRS_FC_SOURCE     = 3577
CRS_PLOT_CENTROID = 9473
```

Banned bare literals outside `gayini_params.*`: `0.0625` `0.062351428` `24.970268` `67349` `85910` `1080157` `988831` `993782`.

**Gate 1 also delivered Gate 2.4 early** (`scripts/utils/build_db_contract_snapshot.py`), pulled forward because the design seat had lost the ability to verify CC's reports against the DB. It stamps an as-of timestamp on every sheet header and a point-in-time banner on QA-derived sheets. **Run it at the end of every gate.**

### Gate 2 — Make staleness structurally impossible · *deferred*

**2.1 Convert stored QA verdicts to live views.** A verdict that is *computed* cannot go stale. For every QA and release check derivable from current tables, replace the stored row with a view:

```sql
CREATE VIEW v_qa_raster_extent_populated AS
SELECT COUNT(*) AS n_total,
       SUM(CASE WHEN xmin IS NULL THEN 1 ELSE 0 END) AS n_missing_extent,
       CASE WHEN SUM(CASE WHEN xmin IS NULL THEN 1 ELSE 0 END) = 0
            THEN 'PASS' ELSE 'FAIL' END AS status
FROM raster_asset;
```

Report which of the 32 release checks and 11 QA issues are derivable this way, and which genuinely require a point-in-time record.

**2.2 Stamp what cannot be converted.** Add `computed_at` and `computed_run_id`, then:

```
v_qa_freshness  -- any check whose computed_at predates MAX(workflow_run.started_at)
                -- is reported STALE, with its age in days
```

Anything reading a QA verdict reads it through this view.

**2.3 Mark the known-stale rows now.** The 1 July rows are not merely old, they are contradicted. Set `superseded_flag` additively and note the superseding evidence. **Do not delete.**

**2.4 Snapshot generator — DELIVERED at Gate 1.**

### Gate 3 — Make the wrong object unopenable · *deferred; 3.1 delivered*

**3.1 Register field fingerprints — DELIVERED at T1 Gate B1.** `spatial_layer_asset.field_list` populated on all six rows, plus `checksum_sha256` and `path_exists` at 6/6.

**Correction to v1's instruction, for the record:** `spatial_004` (`management_zones`, EPSG:28355) resolves to `Input/shapefiles.zip::CA0561_ManagementZones.shp` and carries the **capitalised** ESRI names — `OBJECTID_1, OBJECTID_2, ManagmentZ, Area_MW, Treatment, Plots` — identical to `spatial_006`, because both derive from that shapefile.

**Three management-zone objects exist, not two:**

| Object | CRS | Fields | Status |
|---|---|---|---|
| `spatial_006` `management_zones_8058` | 8058 | caps ESRI | **the analysis input** |
| `spatial_004` `management_zones` → `shapefiles.zip` | 28355 | **caps ESRI** | registered source shapefile |
| `Gayini_Results.gpkg:management_zones` | 28355 | **lowercase**, NUL-padded | **build output, unregistered — cross-check only, never an analysis input** |

The lowercase names are the builder's normalisation on import. Registering the gpkg companion in `spatial_layer_asset` would be a **category error** — that table is an import registry, carrying `import_status` and `invalid_geometry_count_*`.

**3.2 Assertion helper.**

```r
read_registered_layer(layer_name)
  # resolves path from spatial_layer_asset
  # reads the file, compares actual fields to registered field_list
  # ERRORS on mismatch, naming both field sets
  # asserts CRS matches registered source_crs
  # returns the layer
```

**3.3 Fixture test.** Call it against the wrong layer name and confirm it errors. Record the output.

### Gate 4 — Make a support merge impossible to ship · *deferred*

Discrepancies #6 and #10 are the two that are not bookkeeping: numbers in the manuscript that are wrong or unattributable, both because a support level or a lineage travelled silently.

**4.1 `support_level` NOT NULL.** Every fact table and every view T1–T4 creates carries it. Smoke-test check fails if any `v_*` view exposing a count or a mean lacks the column.

**4.2 Figure support.** `figure_asset.support_level` must be non-null for every row written from now on. Smoke test fails on a NULL among rows with `run_id` later than `T1_gateA0`. **Do not backfill the historical 255.**

**4.3 The qualifiers.** Any table holding a headline number carries these as columns, not prose:

```
support_level      -- CLOSED LADDER: pixel | paddock | stratum | property | plot | zone_month | mixed
aggregation_unit   -- free text: what it was aggregated TO, e.g. 'zone_stratum', 'zone_year'
scope_filter_sql   -- the literal filter
pixel_area_ha      -- the constant used
denominator_ha     -- 67349.332 or 85910.8
period_label       -- '1988-2023' | 'post_conservation' | ...
```

**`support_level` and `aggregation_unit` are separate on purpose.** A composite — `'pixel_within_zone_stratum'`, `'zone_year_pixel'` — conflates what the support *is* with what it is aggregated *to*, and defeats 4.4 by forcing a hardcoded synonym list. That error was specced four times before it was caught. `support_level` stays enumerable; precision goes in `aggregation_unit`.

**4.4 Vocabulary and mixed-support checks.**

- A trigger or smoke-test check that rejects any `support_level` outside the closed ladder. Additive; record in the post-build chain; **prove it fires on a fixture.**
- A check that fails if a view joins two sources whose `support_level` differs without an explicit `support_level = 'mixed'` and a `mixed_support_note`. This is the check that would have stopped 9 / 22 / 50 / 44 being labelled "Support: stratum, pixel".

---

## Scheduling

**Gate 1 is done and earned its place** — it caught a stray literal in its own author's build script within hours of landing.

**Gates 2–4 are deferred until after 10 August.** Fourteen days remain and four client deliverables have not moved. The errors these gates guard against are now known and caught by other means: the snapshot generator restores independent verification, the closed-ladder rule is written into T1/T2/T3, and the stale QA row is documented in `CLAUDE.md`. Hardening can wait; the site reports cannot.

---

## What stays manual, and why

Automation has a boundary and pretending otherwise is its own risk.

- **Threshold selection** (T3 Gate D) sets a number in the abstract. It stays a STOP.
- **Metric definition** (T3 Gate A2, and the distance-to-reference metric) requires judgement about what a quantity means. A check can flag a disagreement; only a person decides what to measure.
- **Falsification calls** — deciding that S5 is null — stay human.
- **The STOP points themselves.** They caught the F8 error, the twin degeneracy and the Bala block confound. Do not automate them away.

What automation buys is that **no number reaches a STOP carrying an unstated constant, a stale verdict, or a merged support.** The judgement then happens on clean inputs.

---

## Acceptance criteria

**Gate 1 — met:**

- [x] `gayini_params.R` and `.py` exist; `PIXEL_AREA_HA` derived; load-time DB self-check.
- [x] Three lints in the smoke test: magic numbers, `OR IGNORE`, whole-file `digest`.
- [x] Every lint demonstrated to fail on a fixture, output in the change report.
- [x] `lint_baseline.json` fails closed on growth (`BASELINE_LOCK = 15`).
- [x] `build_db_contract_snapshot.py` stamps an as-of date on every sheet.

**Gates 2–4 — outstanding:**

- [ ] Derivable QA verdicts converted to live views; the count reported.
- [ ] `computed_at` and `v_qa_freshness` in place; the 1 July rows marked superseded.
- [ ] `read_registered_layer()` exists and errors on a field or CRS mismatch, demonstrated.
- [ ] `support_level` non-null on every T1–T4 view and every new `figure_asset` row.
- [ ] Closed-ladder vocabulary check and mixed-support detector, both demonstrated on fixtures.
- [ ] No existing table dropped; all schema changes `ADD COLUMN`, recorded in the post-build chain.
- [ ] `docs/change_reports/T5_change_report.md` committed.

## Standing rules

Additive only · never re-run the builder · idempotence by **convergence** via `INSERT OR REPLACE` · paths from the DB · constants from `gayini_params` · four-CRS discipline · both area bases · **direct commits to `main`, no branch, no PR** · change reports committed.

One addition, and it is the point of this task:

> **Verify against data, not prose — and prefer a check to a rule.** If a constraint can be expressed as something that errors, express it that way. Every specification in this project that relied on a human remembering a rule has been violated at least once, including by its own author.
