#!/usr/bin/env python
"""Ruling EP - provenance protection is defined by the REGISTRY, not by a directory.

**EP (design seat, 10 Aug 2026).** Any file named in any `decided_by` value in
`dim_headline_number` is protected from the archive sweep **wherever it sits**. The sweep
resolves that set by querying the registry and fails loudly if it would touch a member,
rather than relying on a directory whitelist. **A protected path that does not exist
protects nothing; a protected set derived from the thing it protects cannot drift from it.**

WHY IT EXISTS. CLAUDE.md number rule 3 said the documents named in `decided_by` "live in
`docs/decisions/` and the archive sweep does not touch them". **`docs/decisions/` does not
exist and has no git history.** The two documents it named sit in `docs/reference_update/`,
which IS swept. So the rule protecting the provenance chain for 143 pinned numbers
protected a path that was not there. The fix is not to create the directory or move the
files - moving files to satisfy a rule breaks every path reference to them and solves the
wrong problem.

WHAT THIS MODULE IS FOR. Any code that archives, moves or deletes project files calls
`assert_sweep_safe(candidates)` FIRST. There is currently no archive-sweep script - the
sweep is a manual process - so this is the guard that process must run, and
`--check <paths>` is how it runs it.

TWO CHECKS, AND THEY FAIL FOR DIFFERENT REASONS:

  resolve   every file named in a decided_by value must EXIST somewhere in the repo.
            A named document that has gone missing is the exact failure mode EP was
            issued for, and it is silent unless something looks.
  guard     a proposed sweep must not touch a protected file. Fails loudly, naming the
            file AND the number_id(s) that protect it - so the message says why.

The fixture test proves the guard CATCHES, not merely that it runs (I-42 / Ruling J), and
carries a NEGATIVE CONTROL: an unprotected candidate list must PASS. Without that, a guard
that rejected everything would score as working.
"""
from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DB = ROOT / "Output" / "database" / "Gayini_Results.sqlite"

# a filename token inside free-text provenance: bare basename or a repo-relative path
FILE_TOKEN = re.compile(r"[A-Za-z0-9_][\w./\\-]*\.(?:md|py|R|csv|xlsx|docx|sql|Rmd)",
                        re.IGNORECASE)
SKIP_DIRS = {".git", "__pycache__", "node_modules"}


def _norm(p: Path) -> str:
    """Windows paths are case-insensitive; compare on a normalised form."""
    return str(p.resolve()).replace("\\", "/").lower()


def decided_by_values(db: Path = DB) -> list[str]:
    con = sqlite3.connect(f"file:{db.as_posix()}?mode=ro", uri=True)
    try:
        con.execute("PRAGMA query_only=1")
        return [(nid, dv) for nid, dv in con.execute(
            "SELECT number_id, decided_by FROM dim_headline_number "
            "WHERE decided_by IS NOT NULL")]
    finally:
        con.close()


def _index_repo() -> dict[str, list[Path]]:
    """basename (lowercased) -> every path in the repo carrying it."""
    idx: dict[str, list[Path]] = {}
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        idx.setdefault(p.name.lower(), []).append(p)
    return idx


def protected_set(db: Path = DB):
    """Resolve the protected set from the registry.

    Returns (path -> {number_id, ...}, unresolved -> {number_id, ...}).
    A token containing a separator is treated as a repo-relative path; a bare basename is
    matched anywhere in the repo, and EVERY copy is protected. Protecting more than the
    minimum is the safe direction for a sweep guard.
    """
    idx = _index_repo()
    protected: dict[str, set] = {}
    unresolved: dict[str, set] = {}
    for nid, dv in decided_by_values(db):
        for m in FILE_TOKEN.finditer(dv):
            tok = m.group(0).rstrip(").,;:")
            hits: list[Path] = []
            if "/" in tok or "\\" in tok:
                cand = ROOT / tok.replace("\\", "/")
                if cand.is_file():
                    hits = [cand]
                else:                       # fall back to the basename
                    hits = idx.get(Path(tok).name.lower(), [])
            else:
                hits = idx.get(tok.lower(), [])
            if hits:
                for h in hits:
                    protected.setdefault(_norm(h), set()).add(nid)
            else:
                unresolved.setdefault(tok, set()).add(nid)
    return protected, unresolved


def assert_sweep_safe(candidates, db: Path = DB, quiet: bool = False) -> int:
    """Fail loudly if a proposed sweep would touch a registry-protected file.

    `candidates` is whatever the sweep intends to archive, move or delete.
    Returns 0 when safe; raises SystemExit(1) when not.
    """
    protected, _ = protected_set(db)
    hits = []
    for c in candidates:
        p = Path(c)
        p = p if p.is_absolute() else (ROOT / p)
        key = _norm(p)
        if key in protected:
            hits.append((p, sorted(protected[key])))
    if hits:
        print("RULING EP - SWEEP REFUSED. These files are named in "
              "dim_headline_number.decided_by and are the provenance chain for pinned "
              "numbers. They are protected wherever they sit.", file=sys.stderr)
        for p, nids in hits:
            try:
                shown = p.relative_to(ROOT)
            except ValueError:
                shown = p
            print(f"  {shown}", file=sys.stderr)
            print(f"      protected by: {', '.join(nids[:6])}"
                  + (f" (+{len(nids) - 6} more)" if len(nids) > 6 else ""),
                  file=sys.stderr)
        raise SystemExit(1)
    if not quiet:
        print(f"[EP] sweep safe: {len(list(candidates))} candidate(s), none protected")
    return 0


def cmd_list() -> int:
    protected, unresolved = protected_set()
    vals = decided_by_values()
    print(f"[EP] {len(vals)} registry rows carry a decided_by value")
    print(f"[EP] protected set: {len(protected)} file(s), resolved from the registry")
    for k in sorted(protected):
        try:
            shown = Path(k).relative_to(_norm(ROOT))
        except ValueError:
            shown = Path(k).name
        print(f"    {str(shown):<70s} <- {len(protected[k])} number_id(s)")
    if unresolved:
        print(f"\n[EP] FAIL - {len(unresolved)} name(s) in decided_by resolve to NO file "
              f"in the repo. A protected path that does not exist protects nothing:")
        for tok, nids in sorted(unresolved.items()):
            print(f"    {tok}   named by {', '.join(sorted(nids)[:4])}")
        return 1
    print("\n[EP] PASS - every file named in decided_by resolves to a real file")
    return 0


def cmd_check(paths) -> int:
    return assert_sweep_safe(paths)


def cmd_fixture_test() -> int:
    """Prove the guard CATCHES, and that it does not catch everything.

    Two fixtures, because one alone proves nothing:
      POSITIVE  a sweep list containing a genuinely protected file must be REFUSED.
      NEGATIVE  a sweep list of ordinary files must be ALLOWED. Without this, a guard
                that rejected every input would pass the positive case and be useless.
    """
    protected, unresolved = protected_set()
    if not protected:
        print("[fixture-test] FAIL: the protected set is empty, so the positive fixture "
              "cannot be built. That is itself the defect EP guards against.")
        return 1

    victim = Path(sorted(protected)[0])
    try:
        victim_rel = victim.relative_to(Path(_norm(ROOT)))
    except ValueError:
        victim_rel = victim
    print(f"[fixture-test] POSITIVE: proposing a sweep that includes a protected file")
    print(f"               {victim_rel}")
    caught = False
    try:
        assert_sweep_safe([victim], quiet=True)
    except SystemExit as e:
        caught = int(e.code) == 1
    print(f"[fixture-test] guard REFUSED the sweep: {caught}")

    # a throwaway file that no registry row names
    decoy = ROOT / "Output" / "_ep_fixture_unprotected.md"
    decoy.write_text("throwaway fixture; named by no registry row\n", encoding="utf-8")
    allowed = False
    try:
        assert_sweep_safe([decoy], quiet=True)
        allowed = True
    except SystemExit:
        allowed = False
    finally:
        decoy.unlink(missing_ok=True)
    print(f"[fixture-test] NEGATIVE: an unprotected file was ALLOWED: {allowed}")

    ok = caught and allowed and not unresolved
    print(f"[fixture-test] resolution check (every named file exists): "
          f"{'PASS' if not unresolved else 'FAIL'}")
    print(f"[fixture-test] {'PASS' if ok else 'FAIL'} - the guard catches a protected "
          f"file, allows an unprotected one, and the registry resolves")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="Ruling EP provenance guard")
    ap.add_argument("mode", choices=["list", "check", "fixture-test"])
    ap.add_argument("paths", nargs="*", help="candidate paths, for `check`")
    a = ap.parse_args()
    if a.mode == "list":
        return cmd_list()
    if a.mode == "check":
        if not a.paths:
            print("check needs at least one candidate path", file=sys.stderr)
            return 2
        return cmd_check(a.paths)
    return cmd_fixture_test()


if __name__ == "__main__":
    sys.exit(main())
