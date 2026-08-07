#!/usr/bin/env python
"""Read caption text out of Gayini_caption_register.md.

THE REGISTER IS THE SOURCE. A figure producer holds no copy of its own caption text;
it asks for it by figure filename and section heading. That is what makes a number
that changes traceable to every sentence carrying it, which is the whole reason the
register exists.

Structure parsed:
    # Figure · <anything>
    **File:** `NAME.png`
    **Status:** ...
    ## <Section>
    > blockquote line
    > blockquote line
    >
    > next block

blocks(file, section) returns the blockquote as a list of paragraphs, blank-line
separated, with the leading "> " stripped and soft-wrapped lines rejoined.
"""
from __future__ import annotations

import re
from pathlib import Path

REGISTER = (Path(__file__).resolve().parents[2]
            / "docs" / "reference_update" / "Gayini_caption_register.md")


def _parse(path: Path = REGISTER) -> dict[str, dict[str, list[str]]]:
    out: dict[str, dict[str, list[str]]] = {}
    cur_file = cur_sec = None
    buf: list[str] = []

    def flush():
        if cur_file and cur_sec:
            paras, cur = [], []
            for ln in buf:
                if ln.strip() == "":
                    if cur:
                        paras.append(" ".join(cur)); cur = []
                else:
                    cur.append(ln.strip())
            if cur:
                paras.append(" ".join(cur))
            if paras:
                out.setdefault(cur_file, {})[cur_sec] = paras

    for line in path.read_text(encoding="utf-8").splitlines():
        m_file = re.match(r"\*\*File:\*\*\s*`([^`]+)`", line.strip())
        m_sec = re.match(r"^##\s+(.*?)\s*$", line)
        if m_file:
            flush(); buf = []
            cur_file, cur_sec = m_file.group(1), None
            continue
        if line.startswith("# Figure"):
            flush(); buf = []
            cur_file = cur_sec = None
            continue
        if m_sec:
            flush(); buf = []
            cur_sec = m_sec.group(1)
            continue
        if line.startswith(">"):
            buf.append(line[1:].lstrip() if line[1:2] == " " else line[1:])
    flush()
    return out


_CACHE: dict | None = None


def blocks(figure_file: str, section_startswith: str) -> list[str]:
    """Paragraphs of one caption section. Raises if the register has no such entry."""
    global _CACHE
    if _CACHE is None:
        _CACHE = _parse()
    if figure_file not in _CACHE:
        raise KeyError(f"caption register has no entry for {figure_file}; "
                       f"it knows: {sorted(_CACHE)}")
    secs = _CACHE[figure_file]
    hits = [k for k in secs if k.lower().startswith(section_startswith.lower())]
    if not hits:
        raise KeyError(f"{figure_file}: no section starting '{section_startswith}'; "
                       f"sections are: {sorted(secs)}")
    return secs[hits[0]]


def section_name(figure_file: str, section_startswith: str) -> str:
    """The register's own heading text, so a figure's panel titles are not re-typed."""
    global _CACHE
    if _CACHE is None:
        _parse.__wrapped__ if False else None
        blocks(figure_file, section_startswith)
    hits = [k for k in _CACHE[figure_file]
            if k.lower().startswith(section_startswith.lower())]
    return hits[0]


def strip_md(t: str) -> str:
    """Markdown emphasis and code ticks out; the figure has no bold."""
    t = re.sub(r"\*\*(.+?)\*\*", r"\1", t)
    t = re.sub(r"\*(.+?)\*", r"\1", t)
    return t.replace("`", "")


def wrap(t: str, width: int) -> str:
    import textwrap
    return "\n".join(textwrap.wrap(t, width))


if __name__ == "__main__":
    reg = _parse()
    for f, secs in reg.items():
        print(f"{f}")
        for k, v in secs.items():
            print(f"   {k:<34s} {len(v)} paragraph(s), {sum(len(p) for p in v):>5} chars")
