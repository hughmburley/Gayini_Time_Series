# scripts/15_reports — the per-unit report builder

Generates the Gayini paddock and site reports as A4 landscape `.docx` (PDF by export), fully
parameterised from `Gayini_Results.sqlite`. **No number is typed as a literal**; every value is
read at render time, and registered constants are asserted before any document is written.

This is working code, not a sketch. It produced the 32 documents delivered 4 August 2026, and
`verify_batch.py` proves a rebuild reproduces them.

---

## Quick start

```bash
pip install -r requirements.txt
npm  install                      # docx
export GAYINI_ROOT=/path/to/Gayini    # or edit paths.json
./run_batch.sh                    # run_batch.ps1 on Windows
python verify_batch.py            # must print "32 match · 0 changed · 0 missing"
```

If `verify_batch.py` reports **changed**, something moved — a number, a caption, or a degradation
branch. Investigate before shipping. **Do not update the manifest to make it pass.**

---

## Files

| file | role |
|---|---|
| `paths.json` | **the only place paths live.** Repoint `repo_root` here, or set `GAYINI_ROOT` |
| `config.py` / `paths.js` | path resolution for Python and Node; both read `paths.json` |
| `report_data.py` | data layer — contract SQL, registry reads, canaries → one JSON per unit |
| `report_figs.py` | 11 figure families, parameterised → PNGs + `figs_meta.json` |
| `report_build.js` | page model, degradation, document assembly |
| `check_page_fill.py` | render QA — flags pages outside the 70–90% fill band |
| `verify_batch.py` | proves a rebuild reproduces `EXPECTED_OUTPUT.json` |
| `run_batch.sh` / `.ps1` | the full chain for the 32-document set |
| `sample_units/` | the 32 unit records from the 4 Aug build — the data contract, materialised |

## Data flow

```
Gayini_Results.sqlite ─┐
Gayini_Results.gpkg  ──┼─► report_data.py ─► units/*.json ─┐
dim_headline_number  ──┘                                    ├─► report_figs.py ─► figs/*.png
                                                            │                     figs_meta.json
                                                            └─► report_build.js ─► reports/*.docx
```

`sample_units/` lets you inspect or modify the document layer without re-running the data layer.

---

## Safety rails already in place — do not weaken

- **Four registered constants asserted at `1e-4`** before any write — `floor_flood_slope_64pdk`,
  `_intercept_64pdk`, `_r_64pdk`, `_residual_sd_64pdk`. A re-pin halts the build. Assert tighter
  than the precision you depend on: a `1e-2` guard would have slept through the 31 July correction.
- **Four contract canaries** recomputed through the builder's own path and checked against
  `dim_headline_number` before any write.
- The expectation line is **read**, never refitted. The residual is **read** from
  `v_zone_floor_flood_residual`, never recomputed.
- Part states read from `fact_zone_community_part_classification.state_registered`.
- DB opened `mode=ro` with `PRAGMA query_only=1`.
- Captions generated from `figs_meta.json`, so a caption cannot promise what a figure did not draw.

## Three rendering traps — they look like cruft and are load-bearing

1. **Tables need `TableLayoutType.FIXED`** and a grid summing exactly to the table width, or Word
   autofit collapses the figure column. Invisible in LibreOffice.
2. **Image paragraphs must carry no line-spacing rule** — `spacing.line` clamps the line box and
   renders pictures at ~⅓ height while the XML extent stays correct.
3. **Never `bbox_inches='tight'`** on a matplotlib save — it changes the aspect ratio, so the
   width→height calculation in `img()` no longer matches and axis labels clip.

---

See `docs/reports/Gayini_report_template_spec.md` for the page model and degradation rules, and
`docs/reports/Gayini_report_batch_CC_handoff.md` for outstanding work and known defects.
