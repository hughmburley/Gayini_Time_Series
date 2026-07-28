#!/usr/bin/env python3
"""T12 supply step — extend the DEA Land Cover Level 3 pull to 1988-1999.

Gate 0 found the supplied folder held only 2000-2025; 1988-1999 (the window the
task exists to test) were missing because the original notebook
Input/landsat_landcover/gayini_landuse.ipynb hard-set start_date="2000-01-01".

This reproduces that notebook's EXACT route — DEA Explorer STAC -> odc.stac.load
(crs=EPSG:7854, resolution=30, groupby="solar_day", same bbox) -> write_cog of the
level3 band -> LLC3_{year}_MGA54.tif in the same folder. The ONLY change is the
date window. Nearest-neighbour is odc.stac's default (confirmed by the Gate 0
integrity pass on the existing files, which contain only valid LCCS codes).
Homogeneity across the series is the priority: same route, not a second resample.
dea_tools is NOT required (the notebook used it only for plotting).

Verified on 28 Jul 2026: 24 STAC items -> 12 timesteps (1988-1999), grid
byte-identical to the existing series (GeoBox 2189x1545, origin 747300/6201300,
Affine 30m, EPSG:7854; terra::compareGeom TRUE against every existing file).

Env: pip install pystac-client odc-stac odc-geo rasterio xarray  (base Python had
only numpy; the notebook itself ran on the DEA Sandbox).

Usage: python scripts/13_dea_landcover/T12_supply_repull_1988_1999.py
"""
import sys

import numpy as np  # noqa: F401  (kept to mirror the source notebook imports)
import pystac_client
import odc.stac
from odc.geo.xr import write_cog

OUT_DIR = r"D:\Github_repos\Gayini\Input\landsat_landcover\level3"

# --- identical parameters to the notebook, except the date window ---
bbox = [143.7, -34.7, 144.4, -34.3]          # lon/lat, EPSG:4326
collections = ["ga_ls_landcover_class_cyear_3"]
start_date = "1988-01-01"
end_date = "1999-12-31"

catalog = pystac_client.Client.open("https://explorer.dea.ga.gov.au/stac")
odc.stac.configure_rio(cloud_defaults=True, aws={"aws_unsigned": True})

query = catalog.search(bbox=bbox, collections=collections,
                       datetime=f"{start_date}/{end_date}")
items = list(query.items())
print(f"STAC items found {start_date}..{end_date}: {len(items)}")
if not items:
    print("NO ITEMS RETURNED — product may not cover this window. STOP.")
    sys.exit(2)

ds = odc.stac.load(
    items,
    crs="EPSG:7854",
    resolution=30,
    groupby="solar_day",
    bbox=bbox,
)
print("loaded dims:", dict(ds.sizes), "| spatial_ref:", int(ds.spatial_ref.values))
print("geobox:", ds.odc.geobox)
years = ds.time.dt.strftime("%Y").values
print("timesteps -> years:", list(years))

written = []
for t in range(len(ds.time)):
    yr = str(years[t])
    if not (1988 <= int(yr) <= 1999):
        print(f"  skip {yr} (outside supply window)")
        continue
    write_cog(ds["level3"].isel(time=t), f"{OUT_DIR}\\LLC3_{yr}_MGA54.tif", overwrite=True)
    written.append(yr)
    print(f"  wrote LLC3_{yr}_MGA54.tif")

print(f"\nDONE. {len(written)} files written: {written}")
