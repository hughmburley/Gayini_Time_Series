"""Pre-batch lint for the report builder — run before every batch.

Generalises the grep that has now caught four defects, all the same shape: a typed
literal standing in for a derived value, or a branch that could not fire.

  1. the '57' non-treed site count, typed into client prose
  2. the record span (1988-2022, 35, and the 0.35 multiplier), typed into client prose
  3. built_with.d2_renders_present = 11 against 10 renders actually delivered — metadata,
     not prose, so a prose-only grep would never have seen it
  4. the {slug}_maploc.flags sidecar, read by report_build.js and written by nothing, so
     the caption's true branch was unreachable

So this checks three things, not one: PROSE, METADATA, and REACHABILITY.

What it does NOT do, stated so the exit code is not over-read: it cannot tell a derived
value from a coincidentally-correct literal, it does not execute anything, and check C
reasons about file extensions rather than full paths. It is a tripwire, not a proof.
Findings are advisory where marked; only ERROR rows set the exit code.

Run:  python lint_builder.py            (from scripts/15_reports)
      python lint_builder.py --strict   (WARN also fails)
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
JS   = ['report_build.js']
PY   = ['report_data.py', 'report_figs.py']

# Numbers that are legitimately typed: layout geometry, colours, DPI, CRS codes, and the
# registered constants the builder asserts against (those are the contract, not results).
LAYOUT_CALL = re.compile(r'\b(gap|spacing|after|before|width|height|size|margin|pad|padx|'
                         r'w|h|dpi|fontsize|linewidth|markersize|alpha|crop|Image|new)\b')
ALLOW_TOKEN = re.compile(r'^(0|1|2|8058|28355|3577|9473|7854|7855|100|200|486|470)$')
# Assertion tolerances are the contract, not a result. '1e-4' must not read as a bare 4.
SCI = re.compile(r'\d+(?:\.\d+)?[eE][-+]?\d+')

findings = []


def add(level, check, where, msg):
    findings.append((level, check, where, msg))


# ------------------------------------------------------------------ A. prose literals
def check_prose():
    """Digit literals inside strings that reach a reader."""
    for fn in JS:
        p = os.path.join(HERE, fn)
        for i, line in enumerate(open(p, encoding='utf8'), 1):
            if line.lstrip().startswith('//'):
                continue
            for tpl in re.findall(r'`([^`]*)`', line):
                # strip ${...} — those are derived, which is the point
                lit = SCI.sub('', re.sub(r'\$\{[^}]*\}', '', tpl))
                for n in re.findall(r'(?<![\w.])(\d[\d,]*(?:\.\d+)?)', lit):
                    if ALLOW_TOKEN.match(n.replace(',', '')):
                        continue
                    if LAYOUT_CALL.search(line[:line.find('`')]):
                        continue
                    add('ERROR', 'prose', f'{fn}:{i}',
                        f'digit literal {n!r} inside client text — derive it or justify it')
    for fn in PY:
        p = os.path.join(HERE, fn)
        for i, line in enumerate(open(p, encoding='utf8'), 1):
            s = line.lstrip()
            if s.startswith('#'):
                continue
            for tpl in re.findall(r"f'([^']*)'|f\"([^\"]*)\"", line):
                lit = SCI.sub('', re.sub(r'\{[^}]*\}', '', tpl[0] or tpl[1]))
                for n in re.findall(r'(?<![\w.])(\d[\d,]*(?:\.\d+)?)', lit):
                    if ALLOW_TOKEN.match(n.replace(',', '')):
                        continue
                    add('WARN', 'prose', f'{fn}:{i}',
                        f'digit literal {n!r} in an f-string')


# ------------------------------------------------------------------ D. dead interpolation
# Added after this check was needed. Deriving the cell size, I put ${Math.round(...)} inside a
# SINGLE-QUOTED JS string, where it is not a substitution at all — so the literal characters
# "${Math.round(r.pixel_side_m)}-metre" rendered into two client documents. verify_batch.py
# caught it only because the fingerprints were compared rather than regenerated.
# The failure is silent: no error, no exception, just template source in the prose.
DEAD_INTERP = re.compile(r"""(['"])(?:\\.|(?!\1)[^\\])*?\$\{[^}]*\}(?:\\.|(?!\1)[^\\])*?\1""")


def check_dead_interpolation():
    """A ${...} inside a quoted (non-template) JS string is text, not a value."""
    for fn in JS:
        for i, line in enumerate(open(os.path.join(HERE, fn), encoding='utf8'), 1):
            if line.lstrip().startswith('//'):
                continue
            # remove template literals first, so a legitimate `${x}` is not re-flagged
            stripped = re.sub(r'`(?:\\.|[^`\\])*`', '``', line)
            if DEAD_INTERP.search(stripped):
                add('ERROR', 'interp', f'{fn}:{i}',
                    '${...} inside a quoted string — renders literally, use backticks')


# ------------------------------------------------------------------ B. metadata
def check_metadata():
    """A count recorded ABOUT the build must match the build. This is where the 11-vs-10
    lived: no prose grep would have seen it, and built_with is the record used to justify
    a CHANGED verdict, so it has to be right."""
    mp = os.path.join(HERE, 'EXPECTED_OUTPUT.json')
    if not os.path.exists(mp):
        add('WARN', 'metadata', 'EXPECTED_OUTPUT.json', 'absent — cannot check built_with')
        return
    m = json.load(open(mp, encoding='utf8'))
    bw = m.get('built_with')
    if not bw:
        add('WARN', 'metadata', 'EXPECTED_OUTPUT.json', 'no built_with block')
        return

    n_docs = len(m.get('documents', []))
    if m.get('n') != n_docs:
        add('ERROR', 'metadata', 'EXPECTED_OUTPUT.json',
            f'n={m.get("n")} but {n_docs} document entries')

    try:
        sys.path.insert(0, HERE)
        from config import FIGS_DIR
        if os.path.isdir(FIGS_DIR):
            smaps = len([f for f in os.listdir(FIGS_DIR) if f.endswith('_smap.png')])
            c1s = sorted(f[:-len('_mapc1.png')] for f in os.listdir(FIGS_DIR)
                         if f.endswith('_mapc1.png'))
            d2 = bw.get('d2_renders_present')
            if isinstance(d2, int) and d2 != smaps:
                add('ERROR', 'metadata', 'EXPECTED_OUTPUT.json',
                    f'built_with.d2_renders_present={d2} but {smaps} *_smap.png on disk')
            c1r = bw.get('c1_renders_present')
            if isinstance(c1r, list) and sorted(x.replace(' ', '_').replace('/', '-')
                                                for x in c1r) != c1s:
                add('WARN', 'metadata', 'EXPECTED_OUTPUT.json',
                    f'built_with.c1_renders_present={c1r} but *_mapc1.png on disk = {c1s}')
    except Exception as e:                                   # pragma: no cover
        add('WARN', 'metadata', 'config', f'could not inspect figures: {e}')


# ------------------------------------------------------------------ C. reachability
# A first version matched the file extension inside the read call — readFileSync(`....flags`).
# It did not fire on the real defect, because the path was BUILT on one line and USED on the
# next via a variable:
#     const flg=`${FIG}/${g}_maploc.flags`;
#     const drawn=has(flg)&&fs.readFileSync(flg,'utf8')...
# A syntactic check tied to call sites cannot see that, so this one is empirical instead:
# every file extension the code names in a literal must actually appear in the output the
# batch produces. That does not care how the path reaches the call.
# Must look like a PATH, not merely like dotted.text: a separator or an interpolation has
# to appear before the extension. Without this, matplotlib rcParams keys ('axes.grid',
# 'font.family') read as filenames and bury the real finding in noise.
EXT_LIT = re.compile(r'[\'"`]([^\'"`]*?(?:/|\\\\|\$\{|\{)[^\'"`]*?)\.([A-Za-z][A-Za-z0-9]{1,7})[\'"`]')
# inputs by nature, plus extensions that are module names or code files, not companions
EXTERNAL = {'sqlite', 'gpkg', 'csv', 'db', 'shp', 'parquet', 'py', 'js', 'json5', 'md'}


def check_reachability():
    """A companion file the code reads but the batch never produces makes its branch dead.

    Requires a completed batch to compare against — with empty output directories every
    extension would look absent, so the check reports that it could not run rather than
    inventing findings."""
    from config import FIGS_DIR, UNITS_DIR, DOCS_DIR
    produced, populated = set(), False
    for d in (FIGS_DIR, UNITS_DIR, DOCS_DIR):
        if os.path.isdir(d):
            for f in os.listdir(d):
                e = f.rsplit('.', 1)
                if len(e) == 2:
                    produced.add(e[1].lower()); populated = True
    if not populated:
        add('WARN', 'reachable', 'output dirs',
            'no build output present — reachability not checked. Run the batch first.')
        return

    refs = {}
    for fn in JS + PY:
        for i, line in enumerate(open(os.path.join(HERE, fn), encoding='utf8'), 1):
            s = line.lstrip()
            if s.startswith('//') or s.startswith('#'):
                continue
            for _path, ext in EXT_LIT.findall(line):
                refs.setdefault(ext.lower(), []).append(f'{fn}:{i}')

    for ext, sites in sorted(refs.items()):
        if ext in produced or ext in EXTERNAL:
            continue
        add('ERROR', 'reachable', ', '.join(sites[:3]),
            f'code names *.{ext} but the batch produces none — '
            f'any branch gated on it cannot fire')


def main():
    check_prose(); check_dead_interpolation(); check_metadata(); check_reachability()
    strict = '--strict' in sys.argv
    err = [f for f in findings if f[0] == 'ERROR']
    warn = [f for f in findings if f[0] == 'WARN']
    for level, check, where, msg in findings:
        print(f'  {level:5s} [{check:9s}] {where:28s} {msg}')
    print(f'\n{len(err)} error · {len(warn)} warn')
    if not findings:
        print('  clean — prose, metadata and reachability all pass')
    sys.exit(1 if (err or (strict and warn)) else 0)


if __name__ == '__main__':
    main()
