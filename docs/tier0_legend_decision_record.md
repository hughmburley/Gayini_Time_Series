# Tier 0 decision record — landsat inundation wet-rule legend

**Status:** ✅ CONFIRMED
**Decided by:** Adrian, 7 July 2026
**Recorded by:** Tier 0.4b (`scripts/01_prepare_inputs/03_populate_raster_metadata.R`)
**Scope:** `landsat_inundation` product family (the 35 canonical `lo_YYYY_YYYY.img`
annual inundation rasters and every product derived from them — the unified annual
wet/valid stack, the pre/post annual inundation layers, and the inundation
frequency / year-count surfaces).

---

## Confirmed value legend

Source: NSW SEED raster metadata, ratified by Adrian's ruling below.

| Value | Meaning | Classification |
|------:|---------|----------------|
| 0 | not inundated | **dry** — valid observation |
| 1 | inundated | **WET** |
| 2 | off-river storage (ORS) | **WET** |
| 3 | cloud shadow | **MASK** — failed observation (neither wet nor valid) |

## The decision

**Off-river storage (value 2) is counted as wet, identically to natural inundation
(value 1).** In Adrian's words (7 Jul 2026): *"those pixels were wet just the same."*

**Cloud shadow (value 3) is masked** — it is a failed observation, so it is excluded
from both the wet count and the valid count (it does not count as dry).

Formally, the rule applied in
`gayini_make_binary_inundation_layers()` (`R/inundation_pre_post_raster_functions.R`)
for `product = "landsat_inundation"` is:

```
wet   = value IN (1, 2)
valid = value IN (0, 1, 2)
value 3 (and any documented no-data code) -> excluded from both
```

This replaced the earlier implicit `value > 0`, which would have silently counted a
value-3 cloud-shadow pixel as wet. See `docs/tier0_4_wet_rule_confirm_task.md` and the
Tier 0.4a commit.

## Data note — the mask is currently a no-op (but not for long)

The 35 canonical Landsat sources contain values **{0, 1, 2} only** — no value-3 cloud
shadow. This was verified directly in Tier 0.4a:

- Recomputing the wet/valid cell counts for all 35 water years under the explicit
  `value IN (1,2)` rule reproduced the committed `annual_stack_manifest.csv`
  **exactly** — the clarification moved zero numbers.
- The only "extra" value that surfaced (160) was a **colour-table artifact**: several
  `.img` files are categorical with an RGB colour map, and value 2's swatch is
  purple = RGB(160, 32, 240); `terra::freq()` reported the Red channel (160) rather
  than the cell value. The underlying pixel values are strictly {0, 1, 2}.

So the value-3 cloud mask changes nothing for Landsat today. It is retained because it
**will** matter for the **Sentinel-2 inundation** rasters (Tier 3), which can contain
cloud shadow — closing the trap now, while the legend is fresh.

## Open item — Sentinel-2 (Tier 3)

`sentinel2_inundation` remains flagged **`needs_legend_check`**. Do **not** assume this
Landsat ruling transfers to Sentinel-2 without confirmation (though it very likely
does). Confirm the Sentinel-2 value legend and wet rule with Adrian before Tier 3.

## Where this is recorded

- **Catalogue** (`data_intermediate/raster_catalog/raster_catalog.csv`):
  `landsat_inundation` → `legend_status = confirmed`, `needs_legend_check = FALSE`.
- **Database** (`raster_asset`): landsat inundation assets →
  `legend_status = confirmed`, `legend_semantics =` the rule above.
- **This record** (durable, tracked) + a generated copy at
  `Output/reports/legend_decision_record.md`.

> **Durability caveat.** The catalogue/`raster_asset` writes are post-build mutations;
> a full DB/catalogue rebuild wipes them (the builder unlinks + rebuilds and cannot
> read CRS/legend at build time). This markdown record is the durable source of truth.
> Making the metadata survive a rebuild is a separate hardening task
> (`hardening-raster-metadata-survives-rebuild`).
