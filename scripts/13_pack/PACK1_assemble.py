#!/usr/bin/env python
"""PACK-1 — assemble the delivery pack by COPY from PACK1_item_list.csv.

*** THIS IS A REWRITE, NOT A RE-RUN (Ruling M2). ***
The original producer was ad-hoc and was never saved. The pack folder and
PACK1_assembly_manifest.csv exist on disk with no code behind them. This script
reconstructs the producer, and its column contract is DERIVED FROM THE EXISTING
MANIFEST HEADER (Ruling M3), not from a description of it.

Safety, all per Ruling M6:
  copy never move · source_still_present recorded per row · SHA-256 (first 50 MB, the
  project convention) taken on the source BEFORE copy and on the pack copy AFTER, both
  recorded · ABORT before the manifest is written if any pair differs · a file shared by
  two items copied ONCE with mutual shares_file_with · the frozen inputs never touched.

Usage:
  PACK1_assemble.py --out <dir>     assemble into <dir> (use a scratch dir to diff first)
"""
import csv, hashlib, shutil, sys, argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ITEMS = ROOT / "Output" / "pack" / "PACK1_item_list.csv"
REFERENCE_MANIFEST = ROOT / "Output" / "pack" / "PACK1_assembly_manifest.csv"

# --- Ruling M3: the column contract is READ from the existing manifest, never typed here
with open(REFERENCE_MANIFEST, encoding="utf-8") as f:
    COLUMNS = next(csv.reader(f))
EXPECTED = ["item_id", "type", "source_path", "pack_path", "sha256_source",
            "sha256_pack_copy", "verified_after_copy", "shares_file_with", "source_still_present"]
if COLUMNS != EXPECTED:
    raise SystemExit(f"STOP - manifest column contract differs from the build's expectation.\n"
                     f"  on disk: {COLUMNS}\n  expected: {EXPECTED}\n"
                     f"This is a reported finding (Ruling M3), not something to reconcile.")

FOLDER = {"map": "01_maps", "figure": "02_figures", "table": "03_tables", "render": "03_tables"}

def sha50(p: Path) -> str:
    """First-50-MB SHA-256 - the one project checksum convention."""
    h = hashlib.sha256(); cap = 50 * 1024 * 1024; n = 0
    with open(p, "rb") as f:
        while n < cap:
            b = f.read(1024 * 1024)
            if not b: break
            h.update(b); n += len(b)
    return h.hexdigest()

def main(outdir: Path):
    items = list(csv.DictReader(open(ITEMS, encoding="utf-8")))
    withfile = [r for r in items if r["file_path"]]
    print(f"item list: {len(items)} rows, {len(withfile)} carrying a file, "
          f"{len(set(r['file_path'] for r in withfile))} distinct source files")

    # which items share a source file
    by_src = {}
    for r in withfile: by_src.setdefault(r["file_path"], []).append(r["item_id"])

    # a shared file is routed by the FIRST item's type, so both rows point at one copy
    dest_of = {}
    for src, ids in by_src.items():
        first = next(r for r in withfile if r["file_path"] == src)
        dest_of[src] = f"{outdir.as_posix()}/{FOLDER[first['type']]}/{Path(src).name}"

    rows, copied = [], {}
    for r in withfile:
        src = ROOT / r["file_path"]
        if not src.exists():
            raise SystemExit(f"STOP - source missing: {r['file_path']}")
        dst = Path(dest_of[r["file_path"]])
        s_sha = sha50(src)                                   # BEFORE copy
        if r["file_path"] not in copied:                     # copy ONCE per source file
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)                           # COPY, never move
            copied[r["file_path"]] = True
        p_sha = sha50(dst)                                   # AFTER copy
        others = [i for i in by_src[r["file_path"]] if i != r["item_id"]]
        rows.append({
            "item_id": r["item_id"], "type": r["type"], "source_path": r["file_path"],
            "pack_path": dst.as_posix().replace(ROOT.as_posix() + "/", ""),
            "sha256_source": s_sha, "sha256_pack_copy": p_sha,
            "verified_after_copy": int(s_sha == p_sha),
            "shares_file_with": ",".join(others),
            "source_still_present": int(src.exists()),       # copy-never-move, verified
        })

    bad = [r for r in rows if not r["verified_after_copy"]]
    gone = [r for r in rows if not r["source_still_present"]]
    if bad or gone:
        raise SystemExit(f"ABORT before manifest write - {len(bad)} checksum mismatch, "
                         f"{len(gone)} source missing after copy. Manifest NOT written.")

    man = outdir / "PACK1_assembly_manifest.csv"
    with open(man, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS); w.writeheader(); w.writerows(rows)

    nfiles = sum(1 for _ in outdir.rglob("*") if _.is_file()) - 1
    print(f"assembled: {len(rows)} manifest rows, {nfiles} physical files")
    for folder in ("01_maps", "02_figures", "03_tables"):
        n = len(list((outdir / folder).glob("*"))) if (outdir / folder).exists() else 0
        print(f"   {folder}: {n} files")
    shared = [r for r in rows if r["shares_file_with"]]
    print(f"shared-file rows: {[(r['item_id'], r['shares_file_with']) for r in shared]}")
    print(f"all checksums verified: {all(r['verified_after_copy'] for r in rows)}")
    print(f"all sources still present: {all(r['source_still_present'] for r in rows)}")
    print(f"wrote {man}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    main(Path(ap.parse_args().out).resolve())
