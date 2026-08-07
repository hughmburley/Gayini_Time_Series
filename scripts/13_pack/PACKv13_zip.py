#!/usr/bin/env python
"""Pack v1.3 - zip. A ONE-OFF that takes the manifest as its item list.

RULING AR STANDS AND PACK1_zip.py IS NOT TOUCHED. That script seals by globbing the
pack tree, which would now sweep DATA (649 MB), PARTREG (56 MB) and three undeclared
root files into the archive. This script never looks at the directory: it reads
PACKv13_manifest.csv and writes exactly the files listed there.

TWO FILES ARE ADDED EXPLICITLY because they cannot be in the manifest by necessity -
a manifest cannot checksum itself, and SUPERSESSION.md is written after it. Both are
named here rather than discovered, which is the whole point.

Every member is re-hashed from disk against its manifest entry before it is written,
so a file that changed after assembly cannot be sealed silently.
"""
import csv, hashlib, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "Output" / "pack" / "v1_3"
MAN = PACK / "PACKv13_manifest.csv"
EXTRA = ["PACKv13_manifest.csv", "SUPERSESSION.md"]
OUT = ROOT / "Output" / "Gayini_Adrian_pack_v1.3_20260807.zip"

def sha_full(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(4 << 20), b""): h.update(c)
    return h.hexdigest()

rows = list(csv.DictReader(open(MAN, encoding="utf-8-sig")))
members, bad = [], []
for r in rows:
    p = ROOT / r["pack_path"]
    if not p.exists():
        bad.append((r["file"], "MISSING")); continue
    if sha_full(p) != r["sha256_full"]:
        bad.append((r["file"], "CHANGED SINCE ASSEMBLY")); continue
    members.append(p)
for name in EXTRA:
    p = PACK / name
    if not p.exists():
        bad.append((name, "MISSING")); continue
    members.append(p)

if bad:
    print("REFUSING TO SEAL:")
    for f, why in bad: print(f"   {f}: {why}")
    raise SystemExit(1)

expected = len(rows) + len(EXTRA)
assert len(members) == expected, f"{len(members)} members against {expected} expected"

if OUT.exists(): OUT.unlink()
with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for p in sorted(members, key=lambda q: q.relative_to(PACK).as_posix()):
        z.write(p, f"Gayini_Adrian_pack_v1.3/{p.relative_to(PACK).as_posix()}")

with zipfile.ZipFile(OUT) as z:
    names = z.namelist()
    assert len(names) == expected, f"archive holds {len(names)}, expected {expected}"
print(f"[sealed] {OUT.name}")
print(f"  members {len(names)}  =  {len(rows)} manifested + {len(EXTRA)} added explicitly")
print(f"  size    {OUT.stat().st_size/1024/1024:.1f} MB")
print(f"  sha256  {sha_full(OUT)}")
print("\n  member list:")
for n in sorted(names): print(f"    {n.split('/',1)[1]}")
