#!/usr/bin/env python3
"""T5 Gate 1 guardrail lints. Spec: docs/T5_guardrails_and_checks.md 1.2-1.4.

Three lints, each of which MUST be able to fail (proven by `fixture-test`):
  magic_number  - a banned bare literal (gayini_params.MAGIC_LITERALS) outside the
                  params modules, anywhere under scripts/ or R/.
  or_ignore     - `INSERT OR IGNORE` in scripts/11_database/ or any register_*.
  whole_digest  - `digest::digest(file=...)` (whole-file, wrong convention) in the
                  same registrar scope.

Baseline: existing (pre-T5) violations that cannot be safely rewritten now - the
Task-M registrars' OR IGNORE and the gate-E whole-file digest would invalidate
already-registered checksums - are recorded in lint_baseline.json. The lint fails
only on violations NOT in the baseline, so it prevents NEW debt while the legacy
debt stays visible and tracked. (`baseline-write` regenerates it deliberately.)

Usage:
  python scripts/utils/lint_guardrails.py check         # exit 1 if any NEW violation
  python scripts/utils/lint_guardrails.py report        # list everything, exit 0
  python scripts/utils/lint_guardrails.py baseline-write # snapshot current as baseline
  python scripts/utils/lint_guardrails.py fixture-test   # prove each lint can fire
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
import gayini_params  # single source of the banned-literal list  # noqa: E402

BANNED = gayini_params.MAGIC_LITERALS
PARAM_FILES = {"R/gayini_params.R", "scripts/lib/gayini_params.py"}
SELF = "scripts/utils/lint_guardrails.py"
BASELINE_PATH = ROOT / "scripts" / "utils" / "lint_baseline.json"
CODE_EXTS = {".r", ".py", ".ps1", ".sql"}

# The baseline is legacy debt, not a suppression file. This lock is the ceiling;
# `check` FAILS if the baseline has grown beyond it. To grow it you must bump this
# constant in code - a visible, reviewable change - so nobody can silently append
# a new violation to lint_baseline.json to hide it. Lower it as debt is paid down.
BASELINE_LOCK = 15


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def iter_code_files(subdirs):
    for sub in subdirs:
        base = ROOT / sub
        if not base.exists():
            continue
        for p in base.rglob("*"):
            if p.is_file() and p.suffix.lower() in CODE_EXTS and "/archive/" not in p.as_posix():
                yield p


def in_registrar_scope(p: Path) -> bool:
    # under scripts/11_database/, or any file whose name marks it a registrar
    # ('register' anywhere - catches register_*.py AND NN_register_*.R).
    r = rel(p)
    return r.startswith("scripts/11_database/") or "register" in p.name.lower()


def _lines(p: Path):
    return enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1)


def magic_number_violations():
    pats = {b: re.compile(r"(?<![\d.])" + re.escape(b) + r"(?![\d])") for b in BANNED}
    out = []
    for p in iter_code_files(["scripts", "R"]):
        r = rel(p)
        if r in PARAM_FILES or r == SELF:
            continue
        for i, line in _lines(p):
            for b, pat in pats.items():
                if pat.search(line):
                    out.append(dict(lint="magic_number", file=r, line=i, token=b, text=line.strip()))
    return out


def or_ignore_violations():
    pat = re.compile(r"insert\s+or\s+ignore", re.I)
    out = []
    for p in iter_code_files(["scripts"]):
        if not in_registrar_scope(p) or rel(p) == SELF:
            continue
        for i, line in _lines(p):
            if pat.search(line):
                out.append(dict(lint="or_ignore", file=rel(p), line=i, token="INSERT OR IGNORE", text=line.strip()))
    return out


def whole_digest_violations():
    pat = re.compile(r"digest::digest\s*\(")
    out = []
    for p in iter_code_files(["scripts"]):
        if not in_registrar_scope(p) or rel(p) == SELF:
            continue
        for i, line in _lines(p):
            if pat.search(line) and "file" in line:
                out.append(dict(lint="whole_digest", file=rel(p), line=i, token="digest::digest(file=", text=line.strip()))
    return out


def all_violations():
    return magic_number_violations() + or_ignore_violations() + whole_digest_violations()


def vkey(v) -> str:
    # content-based so it survives line-number shifts
    return f"{v['file']}::{v['lint']}::{v['text']}"


def load_baseline() -> set:
    if BASELINE_PATH.is_file():
        return set(json.loads(BASELINE_PATH.read_text(encoding="utf-8")).get("keys", []))
    return set()


def summarise(vs, label):
    by = {}
    for v in vs:
        by.setdefault(v["lint"], []).append(v)
    print(f"--- {label}: {len(vs)} ---")
    for lint in ("magic_number", "or_ignore", "whole_digest"):
        for v in by.get(lint, []):
            print(f"  [{v['lint']}] {v['file']}:{v['line']}  {v['token']}  | {v['text'][:70]}")


def main(mode: str) -> int:
    vs = all_violations()
    baseline = load_baseline()
    new = [v for v in vs if vkey(v) not in baseline]

    # Fail closed on baseline growth: a baseline that can be appended to silently
    # becomes a suppression file.
    grown = len(baseline) > BASELINE_LOCK
    if mode in ("check", "report"):
        print(f"[baseline] {len(baseline)} entries (locked at {BASELINE_LOCK})"
              + ("  << GROWN — bump BASELINE_LOCK deliberately or fix the violation"
                 if grown else ("  (below lock — lower BASELINE_LOCK as debt is paid)"
                                if len(baseline) < BASELINE_LOCK else "")))

    if mode == "baseline-write":
        BASELINE_PATH.write_text(json.dumps(
            {"note": "Pre-T5 guardrail-lint debt. The lint fails on NEW violations only. "
                     "Pay down when the owning asset is next re-registered.",
             "keys": sorted(vkey(v) for v in vs)}, indent=2), encoding="utf-8")
        print(f"[baseline-write] wrote {rel(BASELINE_PATH)} with {len(vs)} entries")
        return 0

    if mode == "fixture-test":
        return fixture_test()

    summarise(vs, "all violations")
    summarise(new, "NEW (non-baselined) violations")
    if mode == "check" and (new or grown):
        if new:
            print(f"\nFAIL: {len(new)} new guardrail violation(s). Use gayini_params, "
                  "INSERT OR REPLACE, and first-50-MB SHA-256.")
        if grown:
            print(f"\nFAIL: baseline grew to {len(baseline)} > lock {BASELINE_LOCK}. "
                  "Fix the violation instead of baselining it, or bump BASELINE_LOCK on purpose.")
        return 1
    print("\nPASS: no new guardrail violations." if not new else "")
    return 0


def fixture_test() -> int:
    """Create throwaway violating files, confirm each lint fires on them, delete."""
    fixtures = {
        ROOT / "scripts" / "_lint_fixture_magic.py": "area = 0.0625  # banned literal\n",
        ROOT / "scripts" / "11_database" / "register__lint_fixture.py":
            "sql = 'INSERT OR IGNORE INTO t VALUES (1)'\nx = 'digest::digest(file=p)'\n",
    }
    baseline = load_baseline()
    try:
        for path, body in fixtures.items():
            path.write_text(body, encoding="utf-8")
        vs = all_violations()
        new = [v for v in vs if vkey(v) not in baseline]
        got = {v["lint"] for v in new if "_lint_fixture" in v["file"]}
        need = {"magic_number", "or_ignore", "whole_digest"}
        print("[fixture-test] lints that fired on the broken fixtures:", sorted(got))
        for v in new:
            if "_lint_fixture" in v["file"]:
                print(f"    FIRED [{v['lint']}] {v['file']}:{v['line']}  {v['text']}")
        ok = need <= got
        print(f"[fixture-test] all three lints fire on a broken fixture: {ok}")
        return 0 if ok else 1
    finally:
        for path in fixtures:
            if path.exists():
                path.unlink()
        print("[fixture-test] fixtures removed.")


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "check"))
