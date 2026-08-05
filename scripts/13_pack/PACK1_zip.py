#!/usr/bin/env python
"""PACK-1 RT-4 / Ruling Q — zip the delivery pack, hash it, record the hash.

The zip is written OUTSIDE Output/pack/ so it cannot contain itself. It is a build product
and is gitignored (*.zip); only its HASH is version-controlled, in PACK1_assembly_manifest.csv.

  --record  append the PACK_ZIP row to PACK1_assembly_manifest.csv.
            WITHOUT it the zip is built and hashed but nothing is recorded. That default is
            deliberate: a hash written into the manifest asserts "this is the delivered state",
            and asserting that over a pack with an outstanding amendment is exactly the
            looks-finished-but-is-not failure this project keeps catching.

Ordering note, stated rather than hidden: the manifest lives inside the pack, so the copy
sealed in the zip necessarily predates the row recording that zip's hash. The repo copy is
the authority; the zipped copy is one row short by construction.
"""
import csv, hashlib, sys, zipfile, argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "Output" / "pack"
MANIFEST = PACK / "PACK1_assembly_manifest.csv"
# One file per version. A re-seal NEVER overwrites its predecessor - overwriting is deleting, and
# Ruling T says the superseded archive is kept (I-17: two versions of one artefact, one stale, is
# the project's most common discrepancy - the fix is to keep both and MARK one, not to keep one).
ZIPS = {"v1":   ROOT / "Output" / "Gayini_Adrian_pack_20260803.zip",
        "v1.1": ROOT / "Output" / "Gayini_Adrian_pack_v1.1_20260804.zip",
        "v1.2": ROOT / "Output" / "Gayini_Adrian_pack_v1.2_20260805.zip"}
SUPERSEDE_REASON = ("v1.2: F4 cut (period-boundary statistic, barred elsewhere); the three "
                    "reference-state figures re-copied from rebuilt registered sources; the "
                    "twelve outstanding captions written, so no item is PENDING_P3")

def sha50(p: Path) -> str:
    """First-50-MB SHA-256 - the one project checksum convention."""
    h = hashlib.sha256(); cap = 50 * 1024 * 1024; n = 0
    with open(p, "rb") as f:
        while n < cap:
            b = f.read(1024 * 1024)
            if not b: break
            h.update(b); n += len(b)
    return h.hexdigest()

def main(record: bool, version: str):
    ZIP = ZIPS[version]
    if ZIP.exists():
        raise SystemExit(f"STOP - {ZIP.name} already exists. A re-seal writes a NEW version file; "
                         f"it never overwrites a sealed archive. Bump the version or remove nothing.")
    files = sorted(p for p in PACK.rglob("*") if p.is_file())
    if not files: raise SystemExit("STOP - pack folder is empty.")

    # every member hashed BEFORE it goes in, so the zip's contents are verifiable against the pack
    before = {p.relative_to(PACK).as_posix(): sha50(p) for p in files}
    with zipfile.ZipFile(ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for p in files: z.write(p, arcname=f"Gayini_Adrian_pack/{p.relative_to(PACK).as_posix()}")

    # and read back OUT of the zip and re-hashed, so "it zipped" is not mistaken for "it is intact"
    bad = []
    with zipfile.ZipFile(ZIP) as z:
        names = z.namelist()
        for rel, want in before.items():
            h = hashlib.sha256(); n = 0
            with z.open(f"Gayini_Adrian_pack/{rel}") as f:
                while n < 50 * 1024 * 1024:
                    b = f.read(1024 * 1024)
                    if not b: break
                    h.update(b); n += len(b)
            if h.hexdigest() != want: bad.append(rel)
    if len(names) != len(files) or bad:
        ZIP.unlink(missing_ok=True)
        raise SystemExit(f"ABORT - {len(files)} in, {len(names)} out, {len(bad)} mismatched. "
                         f"Zip DELETED, nothing recorded.")

    zhash = sha50(ZIP)
    print(f"  {ZIP.name}: {len(files)} files, {ZIP.stat().st_size/1024/1024:.2f} MB")
    print(f"  every member re-hashed OUT of the zip: {len(files)}/{len(files)} identical")
    print(f"  sha256 (first 50 MB): {zhash}")

    if not record:
        print("  NOT recorded in the manifest (no --record). Re-run with --record to seal it.")
        return
    with open(MANIFEST, encoding="utf-8") as f:
        cols = next(csv.reader(f)); rows = list(csv.DictReader(open(MANIFEST, encoding="utf-8")))
    # Every prior zip row is MARKED superseded, not dropped (Ruling T). Idempotent: re-running this
    # version replaces only its own row.
    me = f"PACK_ZIP_{version}"
    for r in rows:
        if r["item_id"].startswith("PACK_ZIP") and r["item_id"] != me:
            r["type"] = "zip_superseded"
            r["shares_file_with"] = f"SUPERSEDED by {me} - {SUPERSEDE_REASON}"
    rows = [r for r in rows if r["item_id"] != me]
    rows.append({"item_id": me, "type": "zip",
                 "source_path": "Output/pack/ (all files)",
                 "pack_path": ZIP.relative_to(ROOT).as_posix(),
                 "sha256_source": zhash, "sha256_pack_copy": zhash,
                 "verified_after_copy": 1, "shares_file_with": "",
                 "source_still_present": int(ZIPS["v1"].exists())})
    with open(MANIFEST, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(rows)
    print(f"  recorded PACK_ZIP in {MANIFEST.name} ({len(rows)} rows)")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--record", action="store_true")
    ap.add_argument("--version", default="v1.2", choices=sorted(ZIPS))
    a = ap.parse_args(); main(a.record, a.version)
