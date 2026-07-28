# T12 — DEA Land Cover Level 3 extraction to project vectors

*(Renumbered from T7 at v2 — `Gayini_reference_state_specs_T7_T11.md` already defines a
different T7. This document supersedes `T7_dea_landcover_l3_extraction.md`, which should be
archived with a superseded-by header. Task identifier is now **T12** everywhere.)*

**Version:** v4 · 28 July 2026 (v3, v2, v1 all 28 July 2026)
**Owner:** design seat (spec) → CC (build)
**Authority:** `Gayini_Results.sqlite` is the source of truth. Where this document and the
database disagree, the database wins.
**Changes at v4, after Gate B — NUMERIC CORRECTION ONLY, no rule changes.** The
false-positive floor stated at §1(c) and §4 was a **paddock-unweighted** mean of per-zone
values (6.72%) mislabelled as a farm mean. The **area-weighted** property figure is **10.57%**.
Corrected at §1(c) and §4. `dea_ctv_floor` (§2.2) is per-zone and unaffected; no threshold in
§2.4, §2.5, §2.7, §2.9 or §2.10 moves. **The §4 caveat text was already written into
`dim_source_product` at Gate A and must be corrected there by an explicit, recorded UPDATE.**

**Changes at v3, after the supply step and Gate A0 — all three affect Gate C only, not
Gate A or Gate B:** §2.9 added (persistence metric and denominator discipline); §2.10 added
(off-property positive control); §2.7 stopping rule rewritten to run on the §2.9 fraction and
on effect size rather than a significance test; §2.6 preamble extended with the
observation-density note; Gate C items 1 and 7 updated accordingly.

*New sections are numbered at the end of §2 deliberately, to keep every existing §2.x
cross-reference stable for the echo-verbatim check.*

**Changes at v2, after Gate 0:** task renumbered T7 → T12; §2.4 indeterminate rule corrected
(v1 made the 2019–2022 era indeterminate by construction); §2.3 era table annotated with actual
year coverage; §2.6 extended to cover the 1988–1999 single-sensor window; Gate A0 added for
8058 vector registration; §2.1 denominator note added.

**Spine anchor:** S5 (distance-to-reference / land-use history). Supplies the *backup*
land-use evidence line behind Ernest's nearmap interpretation.

---

## 0. What this task is, and what it is not

This task extracts **Digital Earth Australia Land Cover, Level 3** (`ga_ls_landcover_class_cyear_3`,
v2.0.0, CC BY 4.0) to the Gayini management zones and plots, as an **independent, clearly
labelled, secondary** line of evidence on land-use history.

**It is not cropping history.** DEA Land Cover is a modelled annual classification, not a
record of what was done to the ground. The five RESERVED columns in `dim_management_zone` —
`cropping_history`, `land_use_era`, `irrigation_status`, `history_source`,
`history_confidence` — are reserved for Ernest's ground-referenced land-use table and
**must remain NULL at the end of this task**. DEA output lives in its own `dea_`-prefixed
objects and nowhere else.

This is the single most important instruction in this document. A modelled inference written
into a column named `cropping_history` becomes recorded fact to the next reader, and that is
discrepancy class #1 — the failure mode that has already misled four readers on this project.

**Dependency and precedence.** GA's own use constraint for this product states it is intended
for national-scale application where more detailed information is unavailable, and that where
it conflicts with state or local datasets, those datasets should be treated as authoritative.
Ernest's nearmap interpretation is the local dataset. **Where the two disagree, Ernest wins**,
and the DEA value is retained as a recorded disagreement, not overwritten.

**Circularity.** DEA Land Cover's parent products include DEA Fractional Cover, FC Percentiles
and Water Observations — the same Landsat inputs the census is built from. DEA Land Cover
therefore **cannot corroborate** the floor result, the flood-frequency gradient, or the refugia
surface. The Cultivated Terrestrial Vegetation (CTV) class is the only component carrying
information not already in our stack, because it derives from a machine-learning model on
annual geomedians/MADs rather than from FC directly. Nothing in this task may be presented as
independent confirmation of an existing census result.

---

## 1. What the design seat has already established — do not re-derive

A pilot was run on the eight years supplied to the design seat (2013–2017, 2023–2025), clipped
to `gayini_boundary_epsg8058.gpkg`. CC should treat these as known and spend no gate time
reproducing them.

**File characteristics (as supplied):**

| Property | Value |
|---|---|
| CRS | **EPSG:7854** (GDA2020 / MGA zone 54) — *already reprojected from DEA native EPSG:3577* |
| Grid | 30 m, origin 747300.0 / 6201300.0, 2189 × 1545 |
| Type | uint8, single band, nodata **255** (v2.0.0 convention) |
| Class values present | **111, 112, 216, 220 only** — no 124 (NAV), no 215 (AS), no 255 inside extent |
| Coverage | Full property (86,122 ha clipped vs 85,910.8 ha true) |

Only valid LCCS codes are present, which is evidence the 3577 → 7854 reprojection used
nearest-neighbour. Confirm this holds for the full folder; a single intermediate value
(e.g. 113, 118) anywhere in any year means the series was resampled with interpolation and
**the whole series must be rebuilt from source**.

**Property-level Level 3 shares by calendar year:**

| Year | CTV 111 | NTV 112 | NS 216 | Water 220 |
|---|---|---|---|---|
| 2013 | 23.85% | 74.35% | 1.22% | 0.58% |
| 2014 | **44.97%** | 51.73% | 2.55% | 0.75% |
| 2015 | 35.12% | 59.55% | 4.69% | 0.63% |
| 2016 | **47.56%** | 48.74% | 0.74% | 2.96% |
| 2017 | 12.52% | 85.49% | 0.27% | 1.71% |
| 2023 | **5.86%** | 90.22% | 0.47% | 3.46% |
| 2024 | 13.17% | 84.13% | 0.69% | 2.00% |
| 2025 | 12.69% | 85.74% | 1.10% | 0.46% |

**Three findings that shape the whole design:**

**(a) The CTV persistence distribution is smooth and unimodal, not bimodal.** Within Gayini,
75.86% of the property is CTV in at least one of the eight years; 1.57% in ≥6 of 8; and
**0.01% — 9.4 ha — in all eight**. Real cultivation history produces a bimodal split
(paddocks cropped nearly every year, versus paddocks never cropped). A smooth decay is the
signature of per-year probabilistic misclassification.

**(b) CTV is not simply flood-driven — it is a spectral-instability detector.** At zone-year
support over 2013–2017 (n = 320), `corr(zone CTV%, zone flood_frac_pct) = 0.070` and
`corr(zone CTV%, zone veg_mean) = −0.268`. Farm-mean CTV was 39.3% in 2014 (flood 14.4%,
lowest mean cover 75.4%) and 39.2% in 2016 (flood **76.5%**, highest mean cover 88.1%). Two
opposite hydrological states produced the same CTV level. CTV is responding to within-year
bare↔green transitions, which occur in both drought dry-down and flood green-up. It is not
measuring one thing.

**(c) The false-positive floor is measurable, and it is large.** Cultivation at Gayini in
2023–2025 is known to be zero. DEA CTV nonetheless flags cultivated ground in those years.
**Two figures, two denominators, both correct — state which one you are using:**

| Figure | Denominator | Answers |
|---|---|---|
| **10.57%** | **area-weighted, property** | What fraction of Gayini is falsely flagged? **Use this for any property-level statement.** |
| 6.72% | paddock-unweighted mean of the 64 zone values | What does the typical paddock read? Use only when the paddock is the unit. |
| 28 of 64 | paddock count above 5% | How widespread across paddocks? No aggregation; unchanged. |

*Corrected at v4. v1–v3 gave 6.72% labelled as a farm mean — a paddock-unweighted mean
carrying a property-level label. The area-weighted figure is the honest property statement and
it is the larger of the two, so the correction weakens rather than strengthens the case for
DEA. Confirmed at Gate B: the two figures are a support distinction, not a discrepancy.*

This is the noise floor, and it is why every downstream metric in this task is defined as an
*excess over a zone-specific floor* (§2.2), never as a raw CTV percentage.

**What the pilot cannot address.** All eight pilot years fall in the last third of the record.
Bala 29ca's deficit is largest in **1988–1992** and closes monotonically thereafter. The
2013–2025 window is structurally incapable of testing the pre-record disturbance hypothesis.
**The 1988–2012 years are the reason this task exists**; the pilot years are the calibration
set, not the evidence.

---

## 2. Pre-registered decision rule

Fixed **before** any pre-2013 data is loaded. The design seat has seen the 2013–2025 subset
(§1) and no other year. This section is the pre-registration for the full-record run.
**Do not amend it after seeing Gate B output.** If it needs amendment, amend it in a dated
revision that states what was already seen, and say so in the change report.

### 2.1 Metric

Per zone (or plot) per DEA calendar year:

```
dea_ctv_pct = 100 × (pixels with level3 = 111) / (pixels with level3 ≠ 255)
```

Same form for `dea_ntv_pct` (112), `dea_ns_pct` (216), `dea_water_pct` (220). Shares sum
to 100 within rounding.

**Denominator note (Gate 0 finding).** The supplied rasters carry no header nodata flag and
value 255 never occurs — they are a filled bounding rectangle around the property, not a
boundary-masked cutout. `n_pixels_nodata` will therefore be 0 for every zone-year, and it is
the geometry mask at Gate B, not a nodata value, that restricts the extraction to the
property. Retain the column anyway, and state this explicitly in the change report so that a
later reader does not read `n_pixels_nodata = 0` as evidence of complete observation.

### 2.2 Zone false-positive floor

```
dea_ctv_floor = mean(dea_ctv_pct) over calendar years 2023, 2024, 2025
```

The floor window is fixed at 2023–2025 because cultivation is known to be zero there. It is
zone-specific because the pilot shows the floor ranges from 0.0% (Bala 22) to 18.0%
(Bala 29ca, 2024) across paddocks.

### 2.3 Era excess

```
dea_ctv_excess(era) = mean(dea_ctv_pct over era) − dea_ctv_floor
```

Eras, aligned to the reference-state period table already in use:

| Era | Calendar years | Present at Gate 0 | If 1988–1999 is supplied |
|---|---|---|---|
| `1988–1992` | 5 | **0** — uncomputable | 5 / 5 |
| `1993–2002` | 10 | **3** (2000–02) | 10 / 10 |
| `2003–2012` | 10 | 10 | 10 / 10 |
| `2013–2018` | 6 | 6 | 6 / 6 |
| `2019–2022` | 4 | 4 | 4 / 4 |
| `2023–2025` | 3 | 3 | floor window (§2.2), not classified |

### 2.4 Classification thresholds — `dea_cultivation_class`

| Class | Rule |
|---|---|
| `dea_likely_cultivated` | `dea_ctv_excess ≥ 25` pp **and** ≥ 4 **consecutive** years with `dea_ctv_pct ≥ 30` **and** era mean `dea_ctv_pct ≥ 40` |
| `dea_possible_cultivated` | `dea_ctv_excess ≥ 10` pp **and** ≥ 2 consecutive years with `dea_ctv_pct ≥ 30` |
| `dea_no_evidence` | neither of the above |
| `dea_indeterminate` | fewer than **4** valid years in the era, **or** fewer than **60%** of the era's calendar years present, **or** zone valid pixel count < 3,000, **or** era overlaps an artefact window (§2.6) for > 50% of its years |

*Corrected at v2.* The v1 rule ("< 5 valid years") made the 2019–2022 era indeterminate by
construction, since that era is only four calendar years long — a defect in the rule, not in
the data. The floor window 2023–2025 is exempt: it is a calibration input under §2.2, never
classified.

### 2.5 Mandatory falsification test

For every zone, compute `corr(dea_ctv_pct, flood_frac_pct)` and `corr(dea_ctv_pct, veg_mean)`
across all years with a matching record in `fact_zone_veg_annual`. **If a zone's CTV
correlates with its flood record at |r| ≥ 0.5, downgrade that zone one confidence tier**
(`likely` → `possible` → `no_evidence`). Record the correlation and the downgrade in the
output table; never apply it silently.

### 2.6 A-priori suspect years

**Standing note — absence of nodata is not evidence of observation.** DEA Land Cover emits a
class for every pixel regardless of how many usable Landsat observations that pixel had in
that year, and v2.0.0 ships **no confidence layer**; GA describe one as a future release. A
pixel with three usable scenes in a year receives a class indistinguishable from a pixel with
thirty. The series therefore reads as complete — 38 contiguous years, zero nodata — when the
underlying observation density varies by a factor of several across the record. This is the
substantive reason the years below are flagged, and it must be stated in these terms in the
methods document rather than as a generic single-sensor caveat.

Flag, do not drop. These are documented in GA's product limitations and must be carried as a
column so a reader can exclude them:

- **2010** — GA state that anomalously high national rainfall in 2010 produced CTV false
  positives that reduced the precision of the class in that year. 2010 is also a major
  Murrumbidgee flood year. Treat 2010 CTV as suspect by default.
- **2003–2011** — Landsat 7 SLC-off striping, substantially increased in Collection 3.
- **2011–2012** — Landsat 7 the only sensor available, with impaired data quality.
- **1988–1999** — **Landsat 5 TM only.** GA record this as a period where a single data source
  is available, so annual observation density is at its lowest across the whole record. This
  matters more here than anywhere else: CTV responds to *within-year* bare↔green transitions,
  so a thin observation record can suppress or inflate the class unpredictably. Flag the entire
  1988–1999 block as suspect on supply. Any conclusion about Bala 29ca drawn from this window
  is low-confidence by construction, and must be reported as such.
- **1999–2003** — single-sensor period, reduced observation density.

### 2.7 Stopping rule — what counts as a null

Pre-registered so that a negative result is a result, not a failure. Evaluated on the §2.9
persistence **fraction** over the full 1988–2025 record, never on a raw year count.

> If, over the full record, the property-wide CTV persistence-fraction distribution shows **no
> separated high-persistence mode** as defined in §2.9.3, **and** fewer than five zones reach
> `dea_likely_cultivated`, **and** the farm-mean CTV continues to swing by more than a factor
> of three between adjacent years, then DEA Land Cover carries no usable land-use signal at
> Gayini. The task closes as a **documented negative**: one methods slide, one limitations-
> register row, and no contribution to S5.

That outcome is fully acceptable and must not be worked around.

**The §2.10 positive control informs how the null is reported, not whether it fires.** A null
that comes with a working positive control is a much stronger result than a bare null, but the
stopping rule itself is unchanged by it.

### 2.8 Hard promotion rule

**No zone may be described as cultivated on DEA evidence alone**, in any deliverable, at any
confidence level. `dea_cultivation_class` is a DEA-derived label. Promotion to
`dim_management_zone.cropping_history` requires Ernest's nearmap interpretation and is a
separate, later, human decision — not part of T12.

### 2.9 Persistence metric and denominator discipline — *added at v3*

**2.9.1 The metric.** Per pixel, over a stated window:

```
dea_ctv_persistence_frac = (years classified CTV) / (valid years in window)
```

**Never report a raw count of CTV years.** "Ever CTV" rises toward 100% and "CTV in every
year" falls toward 0% mechanically as the window lengthens. The pilot figures in §1 — 75.86%
ever, 0.01% in all years — are **8-year** figures. Placing them beside a 38-year equivalent
without conversion would manufacture a dramatic finding out of a change of support. This is
the same error class as C10 (plot support versus pixel support) and carries the same rule.

**2.9.2 Two windows, two figures, never merged.**

| Window | Years | Purpose |
|---|---|---|
| **Full record** | 1988–2025 (38) | The result |
| **Pilot subset** | 2013–17, 2023–25 (8) | Reconciliation only, against `T7_pilot_dea_zone_year_2013_2025.csv` |

Both are computed and both are reported, on separate axes, each labelled with its window and
its denominator. The pilot subset exists to prove the pipeline reproduces the design seat's
numbers; it is not evidence about the property.

**2.9.3 Operational definition of a separated high-persistence mode.**

Bin `dea_ctv_persistence_frac` into twenty bins of 0.05 over [0, 1] and smooth. A separated
high-persistence mode exists if **both**:

- the smoothed density has a **local minimum somewhere in [0.30, 0.70]**; and
- the mass **above that minimum** is **≥ 1%** of valid pixels.

**Do not use a significance test for this.** With ~957,000 valid pixels on the property, any
formal test of unimodality (Hartigan's dip and its relatives) will reject at any threshold
regardless of effect size, and a p-value would be a decoration rather than a decision.
Hartigan's dip statistic may be reported as a supporting descriptive, with its p-value
explicitly marked as uninformative at this n. The decision rule is the effect-size rule above.

**2.9.4 Zone-level equivalent.** The same fraction, computed per paddock, is what feeds the
`max_consecutive_ge30` term in §2.4. Consecutive-year runs are counted on **valid years
present**, so a run is not broken by an absent year — but any run spanning an absent year must
be recorded with `run_has_gap = 1` and reported alongside the classification.

### 2.10 Positive control — off-property contrast — *added at v3, approved 28 July*

**Purpose.** To distinguish *"the CTV class does not work"* from *"the CTV class works, and
Gayini has no cultivation to find."* Only the second is publishable.

**The control area.** The supplied rasters cover a bounding box (approx. 143.7–144.4 E,
−34.7 to −34.3) substantially larger than the property. The off-property remainder includes
irrigated cropping country toward Hay and Maude. The pilot already shows the contrast:
persistent CTV (≥ 6 of 8 years) ran **5.09%** across the full raster window against **1.57%**
inside Gayini.

**Why this control is unusually good, and the point to make in the writeup.** The off-property
remainder is the *same floodplain* — broadly the same flood regime, the same soils, the same
sensor history. It differs from Gayini principally in land use. The comparison therefore holds
the flood-driven false-positive mechanism approximately constant while varying the thing being
tested. It is close to a matched control on the confound identified in §1(b), which is exactly
what a bare on-property null cannot supply.

**Definition.**

- Control area = raster extent **minus** the property boundary **minus a 500 m buffer** outside
  the boundary, to exclude edge-mixed pixels and any spillover management.
- Same years, same metric, same bins, same §2.9.3 rule as the on-property analysis.
- Report side by side: persistence-fraction distribution, and the adjacent-year CTV swing
  factor, for on-property versus control.

**Hard scope stop — one panel.** This is a **single Gate C diagnostic panel** and nothing else.
Specifically excluded, and not to be added without a new spec revision:

- no per-pixel accuracy assessment against any external land-use layer (ABARES CLUM included);
- no attempt to identify, name or map which off-property holdings are irrigated;
- no extension of the control area beyond the existing raster extent;
- no classification of off-property pixels under §2.4.

If the panel is ambiguous, it is **reported as ambiguous**. It is not escalated, not refined,
and not re-cut. The value of a positive control comes from having specified it in advance;
iterating on it until it separates would destroy that value entirely.

**Support and scope discipline.** Control-area pixels are a different scope filter and must
**never** enter any Gayini denominator, any zone or plot fact table, or any headline figure.
They carry `scope = 'off_property_control'` wherever they appear, and they appear only in this
one panel.

**Pre-registration integrity.** §2.10 touches no threshold in §2.4 and no rule in §2.5 or §2.7.
It adds a diagnostic, not a decision rule. Pre-registration is intact.

---

## 3. Inputs

| Input | Location | Notes |
|---|---|---|
| DEA LC Level 3 rasters | `D:\Github_repos\Gayini\Input\landsat_landcover\level3` | Full year range — inventory at Gate 0 |
| Management zones | `management_zones_epsg8058.gpkg` (64 features) | Resolve path from `spatial_layer_asset` (`spatial_006`), not hardcoded |
| Plots | `gayini_hectare_plots_epsg8058.gpkg` (66 features) | For site reports |
| Property boundary | `gayini_boundary_epsg8058.gpkg` (1 feature) | Farm-level denominators |
| Vegetation communities | `vegetation_communities_epsg8058.gpkg` (5 features) | Community-level summary only |
| Flood / veg record | `fact_zone_veg_annual` (`series_variant = 'mean_of_seasons'`) | For §2.5; water years 1988–2022 |
| Census parquet | `census_asset.path` (`census_pixel_8058`, 1,080,157 rows) | Gate D only |

---

## 4. Naming and labelling contract

Every object created by this task carries a `dea_` prefix or an explicit DEA label. No
exceptions, including intermediate files and figure filenames.

**New tables (all additive):**

```
dim_dea_landcover_class
  level3_code        INTEGER PRIMARY KEY   -- 111,112,124,215,216,220,255
  class_code         TEXT                  -- 'CTV','NTV','NAV','AS','NS','Water','nodata'
  class_name         TEXT                  -- 'Cultivated Terrestrial Vegetation'
  is_nodata          INTEGER
  caveat             TEXT                  -- per-class limitation, verbatim in spirit from GA docs

fact_dea_landcover_zone_year
  zone_fid           INTEGER
  dea_calendar_year  INTEGER
  n_pixels_valid     INTEGER
  n_pixels_nodata    INTEGER
  area_ha            REAL
  dea_ctv_pct        REAL
  dea_ntv_pct        REAL
  dea_ns_pct         REAL
  dea_water_pct      REAL
  dea_nav_pct        REAL
  dea_as_pct         REAL
  suspect_year_flag  INTEGER               -- per §2.6
  suspect_reason     TEXT
  support_level      TEXT                  -- literal 'pixel_within_zone_dea_l3'
  source_product_id  TEXT                  -- 'dea_landcover_l3'
  run_id             TEXT
  PRIMARY KEY (zone_fid, dea_calendar_year)

fact_dea_landcover_plot_year   -- same columns, keyed (plot_id, dea_calendar_year)

fact_dea_cultivation_assessment
  zone_fid                 INTEGER
  era_label                TEXT
  mean_ctv_pct             REAL
  dea_ctv_floor            REAL
  dea_ctv_excess           REAL
  max_consecutive_ge30     INTEGER
  n_years_in_era           INTEGER
  n_suspect_years          INTEGER
  corr_ctv_flood           REAL
  corr_ctv_vegmean         REAL
  downgraded_flag          INTEGER
  dea_cultivation_class    TEXT            -- §2.4, pre-downgrade
  dea_cultivation_class_final TEXT         -- post-§2.5 downgrade
  rule_version             TEXT            -- 'T12_prereg_v2_20260728'
  support_level            TEXT
  run_id                   TEXT
  PRIMARY KEY (zone_fid, era_label)
```

**New row in `dim_source_product`:**

```
product_id      = 'dea_landcover_l3'
product_name    = 'DEA Land Cover Level 3 (ga_ls_landcover_class_cyear_3 v2.0.0)'
sensor_family   = 'Landsat (DEA derivative)'
method_summary  = 'FAO LCCS v2 annual classification, 30 m, calendar year. Derived from
                   DEA Fractional Cover, FC Percentiles, Water Observations, geomedian/MAD ML.'
caveat          = 'NOT cropping history. Shares parent products with the Gayini census —
                   cannot independently corroborate census results. CTV is the weakest class
                   in the product; in semi-arid and floodplain settings, drought dry-down and
                   flood green-up both mimic the cultivation signature. Measured false-positive
                   floor at Gayini 2023-2025, when cultivation is known to be zero: 10.57% of
                   property (area-weighted); 6.72% as an unweighted mean across the 64
                   paddocks; 28 of 64 paddocks above 5%. Always state the denominator.
                   GA use constraint: national scale; local datasets are authoritative.'
```

**Forbidden writes.** `dim_management_zone.cropping_history`, `.land_use_era`,
`.irrigation_status`, `.history_source`, `.history_confidence` must be NULL on all 64 rows at
the end of this task. Add an acceptance check that asserts this.

**Figure naming.** Every figure filename and every figure title begins with `DEA` —
e.g. `T12_DEA_ctv_by_zone_era.png`, title "DEA Land Cover (modelled) — CTV by paddock and era".
Every DEA figure caption carries the sentence: *"DEA Land Cover is a modelled national product,
not a record of land use. Not independent of the Gayini census."*

---

## 5. Gates

### Gate 0 — Inventory and recon (read-only) · **STOP**

No writes. Produce a recon note, then stop.

1. Inventory `D:\Github_repos\Gayini\Input\landsat_landcover\level3`: file count, filename
   pattern, **year range and any missing years**, file sizes.
2. For every file report: CRS (EPSG), pixel size, origin, dimensions, dtype, nodata value.
   **Report any file whose CRS is not uniform with the rest.**
3. **Resampling integrity check.** Across all files, list the complete set of distinct pixel
   values. Expected: a subset of {111, 112, 124, 215, 216, 220, 255}. **Any other value is a
   hard stop** — it means interpolated resampling, and the series must be rebuilt from DEA
   native EPSG:3577 source.
4. **Ask before proceeding: are DEA-native EPSG:3577 tiles or continental mosaics available?**
   The supplied files have already been resampled once (3577 → 7854). Sampling from native
   3577 would avoid compounding a second resampling error. If native files exist, prefer them
   and record the decision.
5. Confirm every year's extent covers the full property boundary; report any year that does not.
6. Report the coverage of `fact_zone_veg_annual` (water years 1988–2022) against the DEA
   calendar-year range, and state the overlap available for the §2.5 falsification test.
7. Confirm `dim_management_zone` history columns are still NULL on 64 of 64 (baseline evidence).

**STOP.** Do not proceed until the recon note is reviewed.

### Gate A0 — Register the 8058 vector inputs (additive) — *added at v2*

Gate 0 found that only the zone layer (`spatial_006`) is registered at EPSG:8058. The 8058
boundary, plots and vegetation-community layers exist only inside the unregistered
`Input/gayini_vectors_8058.gpkg`; the registered `spatial_002` / `spatial_001` / `spatial_003`
rows are EPSG:4283 / 7854 and, in the case of `vegetation_units`, the 20-feature layer rather
than the 5-feature community layer.

Register the three 8058 layers into `spatial_layer_asset` following the T1 Gate A0 pattern —
additive, one row each, with SHA-256, feature count, geometry validity and `field_list`. Do not
reproject the registered 4283/7854 shapefiles as a substitute, and do not read from the
unregistered GeoPackage without registering it first. The "paths from the DB" rule exists so
that a later reader can reproduce the extraction; an unregistered input defeats it.

**Also log, do not fix:** `gayini_vectors_8058.gpkg` contains `irrigation_bank_cuts`
(1,158 features), which is Task J input and is likewise unregistered. That is outside T12's
scope but belongs in the issues log.

### Gate A — Register rasters (additive)

Register every DEA raster in `raster_asset` with SHA-256 (builder's first-50-MB convention),
`product = 'dea_landcover_l3'`, `crs_epsg`, bounds, resolution, `path_exists`,
`legend_semantics = 'FAO LCCS v2 Level 3 categorical'`, and
`provenance_note` recording the reprojection lineage (3577 → 7854, nearest neighbour, by whom).

Insert `dim_source_product` and `dim_dea_landcover_class` rows per §4.

**Additive only. `INSERT OR REPLACE` keyed on `raster_asset_id`. Never `reset_file`.**

### Gate B — Zonal extraction (additive)

Build `fact_dea_landcover_zone_year` and `fact_dea_landcover_plot_year`.

**Method — this matters:**

- Reproject **vectors to the raster CRS**, never the raster to the vector CRS. The raster is
  categorical and has already been resampled once; do not resample it again. (Verified in the
  pilot: `management_zones_epsg8058` → 7854, then `rasterio.mask` per feature.)
- All-touched **off**. Pixel-centroid containment only, so zone shares are comparable to the
  census convention.
- Retain `n_pixels_nodata` per zone-year explicitly. Never let nodata silently inflate a share.
- Compute farm-level and community-level equivalents into the same tables using reserved
  sentinel keys, or separate views — CC's call, but state which in the change report.
- Populate `suspect_year_flag` per §2.6 during this gate, from the year alone. No thresholds
  from §2.4 are applied yet.

**Do not compute `dea_cultivation_class` in this gate.**

### Gate C — Diagnostics and falsification · **STOP**

Before applying any classification, produce the diagnostic pack:

1. **Persistence distribution** per §2.9 — as a **fraction of valid years**, never a count.
   Two separate figures, never on shared axes: the full 1988–2025 record (the result), and the
   8-year pilot subset (reconciliation against `T7_pilot_dea_zone_year_2013_2025.csv` only).
   Apply the §2.9.3 effect-size rule and state whether a separated high-persistence mode
   exists. This is the §2.7 stopping-rule test and it must be reported before anything else.
2. **Farm-mean CTV by year**, plotted against `flood_frac_pct` and `veg_mean` on the same
   time axis, 1988–2025.
3. **Zone-level correlations** `corr(dea_ctv_pct, flood_frac_pct)` and
   `corr(dea_ctv_pct, veg_mean)` — full table, 64 zones.
4. **Floor table** — `dea_ctv_floor` per zone, sorted, with the count of zones above 5%.
5. **Suspect-year sensitivity** — every headline recomputed with §2.6 years excluded, shown
   side by side with the all-years version.
6. **The four reference paddocks** (Bala 26ca, 27ca, 28ca, 29ca) as a standalone table, full
   record, with Bala 29ca broken out — because that is the paddock the whole reference-state
   result rests on, and 1988–1992 is the window that matters.

7. **Positive control panel** per §2.10 — one panel, on-property versus off-property control,
   same metric and same bins. Observe the hard scope stop in §2.10.

**STOP.** Report the diagnostic pack. The §2.7 stopping rule is evaluated by a human at this
gate, not by code, and not by CC.

### Gate D — Classification (additive) · runs only if Gate C clears

Apply §2.4 and §2.5 exactly as pre-registered. Build `fact_dea_cultivation_assessment` with
`rule_version = 'T12_prereg_v2_20260728'`.

Write a `v_dea_zone_landuse_summary` view joining the assessment to `dim_management_zone` for
reading convenience. **The view must not write to the zone table.**

### Gate E — Optional per-pixel sidecar · only on explicit instruction

If per-pixel DEA class is wanted alongside the census, sample the DEA raster at census pixel
centroids (`x_8058`, `y_8058` → reproject points to 7854 → nearest sample) and persist as
`Output/census/gayini_pixel_dea_landcover_l3.parquet`, columns `pixel_id`, `dea_calendar_year`,
`level3_code` only. Register in `census_asset` with SHA-256.

**Do not widen the primary census parquet.** Sidecar only, following the T1 Gate C pattern.
Reconciliation must show `Σ rows = 1,080,157 × n_years`, diff = 0.

---

## 6. Calendar year versus water year — do not resolve silently

DEA Land Cover is a **calendar-year** product (Jan–Dec). `fact_zone_veg_annual.water_year` is
labelled by **start year** (1988 = WY1988–89). DEA calendar 2016 straddles WY2015–16 and
WY2016–17.

**Rule:** store `dea_calendar_year` and only `dea_calendar_year` in the fact tables. Never
write a column named `water_year` in any DEA table. Where a join to the project record is
needed (§2.5), build a view that exposes **both** candidate alignments —
`water_year = dea_calendar_year` and `water_year = dea_calendar_year − 1` — and report the
falsification-test correlation under both. If they disagree materially, that disagreement is
a finding and goes in the change report.

---

## 7. Acceptance criteria

- [ ] Gate 0 recon note reviewed and signed off before any write.
- [ ] Distinct pixel values across the full series ⊆ {111, 112, 124, 215, 216, 220, 255}.
- [ ] `dim_management_zone` history columns NULL on 64 of 64 rows — asserted by an explicit check.
- [ ] Every new table, view, figure and file carries a `dea_` prefix or explicit DEA label.
- [ ] `dim_source_product` row present with the full caveat text from §4.
- [ ] `support_level` populated on every fact row.
- [ ] Zone shares sum to 100 ± 0.01 per zone-year; `n_pixels_nodata` populated, never assumed zero.
- [ ] `dea_ctv_floor` computed from 2023–2025 only, per zone.
- [ ] §2.5 correlations computed and any downgrade recorded with `downgraded_flag = 1`.
- [ ] `rule_version` populated on every assessment row.
- [ ] Registration re-run twice → identical row counts and identical checksums (idempotence proof).
- [ ] No existing table, view or column modified or dropped.
- [ ] Change report in `docs/change_reports/`, committed.

---

## 8. Standing rules

Additive only · **never re-run the builder** (destroys 12 unreproducible Task H rows) ·
never `reset_file` · never delete registered rows · paths resolved from the DB, not hardcoded ·
branch and PR with human merge · commits authored solely by Hugh, no AI attribution trailers ·
rasters and large spatial data never committed · CRS discipline: reproject vectors to raster,
never raster to vector, nearest-neighbour only for categorical · do not rebase mapped area
(67,349 ha) against true farm area (85,910.8 ha) · every headline number carries five
qualifiers (support level, scope filter, pixel constant, denominator, period label).

**Note on CRS.** EPSG:7854 is not new to the project — `spatial_layer_asset.spatial_001`
(`plots_source`) is already recorded as EPSG:7854. Add DEA's 7854 usage to the CRS section of
the methods document rather than treating it as a new coordinate system.

---

## 9. Spine return

On completion, append one row to the spine return log recording: whether the §2.7 stopping rule
fired, how many zones reached each `dea_cultivation_class_final`, whether the persistence
distribution was bimodal, and whether S5 gained or did not gain a usable land-use variable.

**A documented negative is a complete and successful outcome of this task.**
