# Gayini LOOC-B GeoJSON input preparation

This pack prepares the two GeoJSON files needed by the LOOC-B farm pipeline:

```text
INPUT/Gayini/Gayini_polygon.json
INPUT/Gayini/Gayini_planning_areas.json
```

The attached example `INPUT.zip` shows the required pattern:

- one folder per farm under `INPUT/`
- one property-boundary file named `<Farm>_polygon.json`
- one intervention / planning-area file named `<Farm>_planning_areas.json`
- each file is a GeoJSON `FeatureCollection`
- each file normally contains one dissolved polygon or multipolygon feature
- coordinates are longitude / latitude in WGS84 / EPSG:4326

For Gayini, use:

- `Gayini_polygon.json` = full Gayini property / analysis boundary
- `Gayini_planning_areas.json` = grazing-exclusion / restoration area, dissolved to one feature if it has multiple polygons

## What is still needed

The current uploaded `INPUT.zip` contains example farm files only. It does not contain the actual Gayini boundary or grazing-exclusion geometry. To create the final two GeoJSONs, place the source vector files in a local folder and edit `config/gayini_loocb_geojson_config_template.csv` or the config block at the top of `scripts/prepare_gayini_loocb_geojsons.R`.

Accepted source formats include shapefile, GeoPackage, GeoJSON, ESRI JSON, or any other vector format that `sf::st_read()` can read.

## Recommended source files

Use the cleanest available project files:

1. full Gayini boundary, preferably a single outer boundary polygon; and
2. grazing-exclusion / restoration planning area polygon(s).

If planning areas contain several separate polygons, the script can dissolve them to one multipolygon feature, which matches the example LOOC-B input style.

## Run order

```r
source("scripts/prepare_gayini_loocb_geojsons.R")
source("scripts/validate_loocb_geojson_inputs.R")
```

The preparation script writes the two GeoJSONs and a validation report. The validation script can be run again after manual edits.

## Suggested first API test

Once the files are created, test the monitoring mode first with the full property boundary. Then test planning mode with `Gayini_planning_areas.json`. Keep API request/response dumps enabled in the LOOC-B pipeline.
