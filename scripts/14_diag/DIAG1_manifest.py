#!/usr/bin/env python
"""Manifest every DIAG-1 output: path, size, rows, checksum.

Also runs the section 7 audit that matters: EVERY output table must carry its support
level, its unit, its period, its weighting and its ESTIMAND in the file, not only in
the filename. Estimand is the one that is non-negotiable - a between-unit and a
within-unit output must never be distinguishable by filename alone - so a table
missing it is reported as a failure here rather than discovered by a reader later.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
DIAG = ROOT / "Output" / "diag"

REQUIRED = ["support_level", "unit", "period_label", "weighting", "estimand"]

# Tables that are deliberately exempt, each with the reason recorded rather than
# silently skipped.
EXEMPT = {
    "DIAG1_inputs.csv": "provenance ledger of file checksums; describes files, not estimates",
    "DIAG1_reproduction_checks_stageA.csv": "check ledger; each row names its own target and section",
    "DIAG1_reproduction_checks_stageC.csv": "check ledger; each row names its own target and section",
    "DIAG1_reproduction_checks_stageE.csv": "check ledger; each row names its own target and section",
    "DIAG1_unzoned_between_not_applicable.csv": "a recorded absence, not an estimate",
    "DIAG1_manifest.csv": "the manifest itself",
}


def sha256_first50(path: Path) -> str:
    cap, h = 50 * 1024 * 1024, hashlib.sha256()
    with open(path, "rb") as f:
        while cap > 0:
            b = f.read(min(1 << 20, cap))
            if not b:
                break
            h.update(b)
            cap -= len(b)
    return h.hexdigest()


def main() -> int:
    rows, problems = [], []
    for p in sorted(DIAG.rglob("*")):
        if not p.is_file() or p.name == "DIAG1_manifest.csv":
            continue
        rel = p.relative_to(ROOT).as_posix()
        n_rows, cols_ok, missing = None, "", ""
        if p.suffix == ".csv":
            d = pd.read_csv(p)
            n_rows = len(d)
            if p.name in EXEMPT:
                cols_ok = "exempt"
                missing = EXEMPT[p.name]
            else:
                miss = [c for c in REQUIRED if c not in d.columns]
                cols_ok = "yes" if not miss else "NO"
                missing = ", ".join(miss)
                if miss:
                    problems.append(f"{p.name}: missing {missing}")
        rows.append({"file": rel, "name": p.name, "kind": p.suffix.lstrip("."),
                     "bytes": p.stat().st_size, "rows": n_rows,
                     "carries_section7_columns": cols_ok, "note": missing,
                     "sha256_first50": sha256_first50(p)})

    m = pd.DataFrame(rows)
    m.to_csv(DIAG / "DIAG1_manifest.csv", index=False, lineterminator="\n")

    n_csv = int((m.kind == "csv").sum())
    n_png = int((m.kind == "png").sum())
    print(f"  {len(m)} files  ({n_csv} csv, {n_png} png, "
          f"{len(m) - n_csv - n_png} other)  {m.bytes.sum() / 1024 / 1024:.2f} MB")
    print(f"  section 7 columns: {int((m.carries_section7_columns == 'yes').sum())} carry them, "
          f"{int((m.carries_section7_columns == 'exempt').sum())} exempt, "
          f"{int((m.carries_section7_columns == 'NO').sum())} missing")
    for q in problems:
        print(f"  PROBLEM  {q}")
    print(f"  [wrote] DIAG1_manifest.csv")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
